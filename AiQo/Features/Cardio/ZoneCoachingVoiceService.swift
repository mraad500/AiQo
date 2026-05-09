import AVFoundation
import Combine
import Foundation

/// Voice coaching for Zone 2 cardio. Subscribes to
/// `LiveWorkoutSession.captainVoiceZoneTransitions` (a static app-global
/// subject, since the workout session is per-instance not a singleton) and
/// speaks a short pre-scripted phrase via
/// `CaptainVoiceRouter.shared.speak(text:, tier: .realtime)` when the zone
/// transition is material (e.g. dropping below, going above, re-entering
/// after drift).
///
/// Debouncing:
/// - Global cooldown: at most one coaching line every 15 seconds.
/// - Per-category cooldown: the same event category cannot fire twice
///   within 30 seconds. The category is a coarse grouping —
///   "aboveZone" events share a bucket regardless of BPM arguments.
///
/// Phrases are deterministic (no LLM call). In commit 3 they will be
/// swapped for `NSLocalizedString` lookups so translation can happen
/// in the `.strings` files — for now the Arabic/English pair is
/// inlined to keep commit 1 end-to-end testable without requiring the
/// commit 3 localization work.
///
/// Time-based events (`.halfway`, `.cooldownStart`) are exposed via the
/// public `handle(_:)` method so the cardio session can trigger them
/// when the workout duration crosses those boundaries — the zone
/// transition subscription does not emit those directly because they
/// are not heart-rate driven.
@MainActor
final class ZoneCoachingVoiceService: ObservableObject {
    static let shared = ZoneCoachingVoiceService.makeShared()

    /// Static factory used only by the singleton. Wrapping the convenience
    /// init behind a function lets Swift 6 reason about main-actor isolation
    /// at the property-initialization site without complaining about
    /// nonisolated default-argument expressions.
    private static func makeShared() -> ZoneCoachingVoiceService {
        ZoneCoachingVoiceService(router: CaptainVoiceRouter.shared, autoSubscribe: true)
    }

    enum CoachingEvent: Equatable {
        case aboveZone(currentBPM: Int, targetMax: Int)
        case belowZone(currentBPM: Int, targetMin: Int)
        case enteredZone
        case workoutStart
        case warmupEnd
        case halfway(totalMinutes: Int)
        case cooldownStart
    }

    // MARK: - Cooldown configuration

    /// Per-category cooldown. Overridable for tests.
    var perCategoryCooldown: TimeInterval = 30
    /// Global cooldown across all events. Overridable for tests.
    var globalCooldown: TimeInterval = 15

    /// Clock source — overridable for deterministic tests.
    var now: () -> Date = { Date() }

    // MARK: - Debounce state (exposed for test introspection)

    private(set) var lastSpokenAt: [String: Date] = [:]
    private(set) var lastGlobalSpokenAt: Date?

    // MARK: - Subscription state

    private var cancellables: Set<AnyCancellable> = []
    private var previousZoneState: WorkoutActivityAttributes.HeartRateState = .neutral
    private let router: CaptainVoiceRouter

    /// Designated initializer. Prod uses `shared` (via `makeShared()`) which
    /// auto-subscribes. Tests pass `autoSubscribe: false` + a mock router to
    /// avoid touching the real `LiveWorkoutSession` broadcast subject and
    /// Apple TTS singleton.
    ///
    /// Default arguments were intentionally dropped — referencing
    /// `CaptainVoiceRouter.shared` from a default-argument expression tripped
    /// Swift 6 strict-concurrency because the expression is evaluated in a
    /// nonisolated context. Callers must supply the router explicitly.
    init(router: CaptainVoiceRouter, autoSubscribe: Bool) {
        self.router = router
        if autoSubscribe {
            subscribeToLiveWorkoutSession()
        }
    }

    // MARK: - Public API

    /// Emit a coaching event. Returns silently if the cooldown windows
    /// are still active or if silent mode is inferred to be on. Exposed
    /// so callers can trigger time-based events (`.halfway`, `.cooldownStart`,
    /// `.warmupEnd`) that are not driven by heart-rate transitions.
    func handle(_ event: CoachingEvent) {
        guard respectsSilentMode() else { return }
        guard canSpeak(event: event) else { return }

        let phrase = phraseFor(event: event)
        recordSpoken(event: event)

        let router = self.router
        Task {
            await router.speak(text: phrase, tier: .realtime)
        }
    }

    // MARK: - Transition subscription

    private func subscribeToLiveWorkoutSession() {
        LiveWorkoutSession.captainVoiceZoneTransitions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.handleZoneSnapshot(snapshot)
            }
            .store(in: &cancellables)
    }

    private func handleZoneSnapshot(_ snapshot: CaptainVoiceZoneSnapshot) {
        defer { previousZoneState = snapshot.state }

        guard let event = Self.eventFor(
            from: previousZoneState,
            to: snapshot.state,
            currentBPM: snapshot.currentBPM,
            targetMin: snapshot.zone2LowerBPM,
            targetMax: snapshot.zone2UpperBPM
        ) else {
            return
        }

        handle(event)
    }

    /// Pure transition → event mapping. Separated from the subscription
    /// path so the transition logic can be unit-tested without a real
    /// `LiveWorkoutSession`.
    static func eventFor(
        from previous: WorkoutActivityAttributes.HeartRateState,
        to newState: WorkoutActivityAttributes.HeartRateState,
        currentBPM: Int,
        targetMin: Int,
        targetMax: Int
    ) -> CoachingEvent? {
        // No-op transitions — don't fire.
        if previous == newState { return nil }

        switch (previous, newState) {
        case (.neutral, .warmingUp):
            return .workoutStart

        case (.warmingUp, .zone2):
            return .warmupEnd

        case (_, .aboveZone2):
            return .aboveZone(currentBPM: currentBPM, targetMax: targetMax)

        case (_, .belowZone2):
            return .belowZone(currentBPM: currentBPM, targetMin: targetMin)

        case (.aboveZone2, .zone2), (.belowZone2, .zone2):
            return .enteredZone

        case (_, .neutral) where previous != .neutral:
            return .cooldownStart

        default:
            return nil
        }
    }

    // MARK: - Cooldown logic (internal visibility for test introspection)

    func canSpeak(event: CoachingEvent) -> Bool {
        let current = now()

        if let last = lastGlobalSpokenAt,
           current.timeIntervalSince(last) < globalCooldown {
            return false
        }

        let category = Self.categoryKey(for: event)
        if let last = lastSpokenAt[category],
           current.timeIntervalSince(last) < perCategoryCooldown {
            return false
        }

        return true
    }

    func recordSpoken(event: CoachingEvent) {
        let current = now()
        lastGlobalSpokenAt = current
        lastSpokenAt[Self.categoryKey(for: event)] = current
    }

    static func categoryKey(for event: CoachingEvent) -> String {
        switch event {
        case .aboveZone:    return "aboveZone"
        case .belowZone:    return "belowZone"
        case .enteredZone:  return "enteredZone"
        case .workoutStart: return "workoutStart"
        case .warmupEnd:    return "warmupEnd"
        case .halfway:      return "halfway"
        case .cooldownStart: return "cooldownStart"
        }
    }

    // MARK: - Silent mode

    /// iOS does not expose a direct silent-mode API for the `.playback`
    /// audio category (which CaptainVoiceService uses so coaching is
    /// audible even when the ringer is silenced — this is the intended
    /// behavior for workout audio). The only system hint we can read is
    /// `secondaryAudioShouldBeSilencedHint`, which is a soft signal from
    /// another app (e.g. Music) that it prefers silence. We honor that
    /// hint for coaching — the user is clearly consuming audio from
    /// another app and we don't want to talk over it.
    private func respectsSilentMode() -> Bool {
        let hint = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
        return !hint
    }

    // MARK: - Phrases

    /// Deterministic bilingual phrase table. Will be swapped for
    /// `NSLocalizedString` lookups in commit 3 (privacy + localization
    /// commit) — kept inline here so commit 1 is end-to-end testable
    /// without requiring the commit 3 string-file additions.
    private func phraseFor(event: CoachingEvent) -> String {
        let isArabic = AppSettingsStore.shared.appLanguage == .arabic
        switch event {
        case .aboveZone:
            return isArabic
                ? "خفف شوية، نبضك فوق الزون"
                : "Ease up, you're above the zone"
        case .belowZone:
            return isArabic
                ? "زيد السرعة، رجعنا للزون"
                : "Push a bit, let's get back in zone"
        case .enteredZone:
            return isArabic
                ? "ممتاز، أنت بالزون الحين"
                : "Perfect, you're in the zone now"
        case .workoutStart:
            return isArabic
                ? "يالله نبدي، ركّز على نفسك"
                : "Let's go, focus on your breathing"
        case .warmupEnd:
            return isArabic
                ? "انتهى الإحماء، هسه المرحلة الأساسية"
                : "Warmup done, main set starting"
        case .halfway(let minutes):
            return isArabic
                ? "وصلنا النص، باقي \(minutes) دقيقة"
                : "Halfway there, \(minutes) minutes left"
        case .cooldownStart:
            return isArabic
                ? "نبرّد الحين، خفف تدريجي"
                : "Cooldown time, slow it down"
        }
    }
}
