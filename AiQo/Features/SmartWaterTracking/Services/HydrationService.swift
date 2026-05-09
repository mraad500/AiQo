import Foundation
import Combine
import HealthKit
import UserNotifications

/// Smart Water Tracking orchestrator.
/// Reads dietaryWater from HealthKit (already deduplicated by HealthKit across
/// sources via HKStatisticsQuery.cumulativeSum), computes pace via
/// `HydrationEvaluator`, and schedules a single pace-based reminder through
/// `NotificationBrain`. Free feature — no paywall gating.
///
/// Why one reminder and not a ladder: `GlobalBudget.recordDelivered` records
/// the kind's cooldown at schedule time, so a second same-kind submit in the
/// same re-evaluation tick is rejected by the 2h global / 6h per-kind cooldown.
/// A follow-up reminder would always be dead code. Instead we re-evaluate
/// naturally on every app-active + water-log, and `CooldownManager` enforces
/// the 6h spacing between actual deliveries.
@MainActor
final class HydrationService: ObservableObject {
    static let shared = HydrationService()

    @Published private(set) var state: HydrationDailyState = .zero
    @Published var settings: HydrationSettings {
        didSet {
            HydrationSettingsStore.save(settings)
            writeSettingsToMemory()
            // Keep the widget's goal in sync when the user edits the Stepper.
            publishWidgetSnapshot()
        }
    }

    /// Stable identifier so rescheduling replaces the pending reminder cleanly.
    private let reminderIdentifier = "aiqo.hydration.smart.reminder"

    /// Persisted key for the user's preferred Captain dialect. Matches the
    /// fallback that `NotificationBrain` uses when composing notifications.
    private let dialectUserDefaultsKey = "aiqo.captain.dialect"

    private init() {
        var initial = HydrationSettingsStore.load()

        // First-launch bootstrap: seed a weight-based goal if the user hasn't
        // committed one yet. Subsequent launches preserve whatever the user
        // sets via the Stepper in SmartHydrationSection.
        if !HydrationSettingsStore.isGoalUserSet() {
            let weightKg = UserProfileStore.shared.current.weightKg
            initial.goalML = HydrationSettings.recommendedGoalML(forWeightKg: weightKg)
            HydrationSettingsStore.save(initial)
        }

        self.settings = initial

        // Mirror the preference shape (not raw logs) into Captain memory so
        // other parts of the brain can reference it. Raw hydration history
        // is never written — MemoryStore would treat it as PII.
        writeSettingsToMemory()
    }

    // MARK: - Captain memory write

    /// Mirrors the user's hydration PREFERENCES (goal, smart-tracking toggle)
    /// into `MemoryStore` so the Captain persona has access to them.
    /// Intentionally does NOT write individual drink events or timestamps —
    /// that would be raw log data, not a preference.
    private func writeSettingsToMemory() {
        let goalLiters = settings.goalML / 1000.0
        let goalValue = String(format: "%.2f L", goalLiters)
        MemoryStore.shared.set(
            "hydration_goal",
            value: goalValue,
            category: "hydration",
            source: "user_explicit",
            confidence: 0.9
        )
        MemoryStore.shared.set(
            "hydration_smart_enabled",
            value: settings.smartTrackingEnabled ? "on" : "off",
            category: "hydration",
            source: "user_explicit",
            confidence: 0.9
        )
    }

    // MARK: - Public API

    /// Refresh `state` from HealthKit. Cheap; safe to call on app-active and after water logs.
    func refreshState(now: Date = Date()) async {
        let consumedML = await HealthKitService.shared.getWaterIntake()
        let (lastDrinkDate, lastDrinkSource) = await lastDrinkInfo()
        let snapshot = HydrationEvaluator.dailyState(
            consumedML: consumedML,
            lastDrinkDate: lastDrinkDate,
            lastDrinkSource: lastDrinkSource,
            now: now,
            settings: settings
        )
        self.state = snapshot
    }

    /// Re-evaluate pace and schedule / cancel the pending hydration reminder.
    /// Call on app-active and after every water log. Idempotent — cancels any
    /// existing pending hydration reminder before optionally scheduling a new one.
    ///
    /// Also drains any widget "+0.25 L" taps that accumulated while the app
    /// was backgrounded, and publishes a fresh snapshot to the widget.
    func reevaluateAndSchedule(now: Date = Date()) async {
        // 1. Drain widget taps into HealthKit FIRST so refreshState reads the
        //    complete committed total.
        await drainWidgetTapsIntoHealthKit()

        // 2. Refresh from HealthKit source of truth.
        await refreshState(now: now)

        // 3. Publish a fresh widget snapshot (committed + goal + language).
        publishWidgetSnapshot()

        // 4. Run the pace evaluator and (re)schedule.
        let evaluation = HydrationEvaluator.evaluate(
            state: state,
            now: now,
            settings: settings
        )

        cancelPendingReminder()

        if case .remind(let intensity) = evaluation {
            await scheduleReminder(intensity: intensity, now: now)
        }
    }

    // MARK: - Scheduling

    private func scheduleReminder(
        intensity: HydrationReminderIntensity,
        now: Date
    ) async {
        let language = AppSettingsStore.shared.appLanguage
        let dialect = currentDialect()
        let phrase = HydrationPhrases.phrase(
            for: intensity,
            language: language,
            dialect: dialect
        )

        let signals = IntentSignals(
            customPayload: [
                "language": language.rawValue,
                "dialect": dialect.rawValue,
                "intensity": intensity == .gentle ? "gentle" : "stronger"
            ]
        )
        let intent = NotificationIntent(
            kind: .hydrationReminder,
            priority: .low,
            signals: signals,
            requestedBy: "HydrationService",
            expiresAt: now.addingTimeInterval(6 * 3600)
        )

        _ = await NotificationBrain.shared.request(
            intent,
            fireDate: now.addingTimeInterval(reminderDelaySeconds(for: intensity)),
            precomposedTitle: phrase.title,
            precomposedBody: phrase.body,
            userInfo: ["source": "hydration"],
            identifier: reminderIdentifier
        )
    }

    /// Dynamic delay: the further behind the user is, the sooner we prompt.
    private func reminderDelaySeconds(for intensity: HydrationReminderIntensity) -> TimeInterval {
        switch intensity {
        case .gentle:   return 30 * 60   // behind → 30 min
        case .stronger: return 10 * 60   // very behind → 10 min
        }
    }

    private func cancelPendingReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    // MARK: - Widget drain + snapshot

    /// Drains any "+0.25 L" taps recorded by the HydrationWidget into HealthKit.
    /// Each pending tap becomes one 250 mL `dietaryWater` sample so per-sip
    /// granularity survives. Safe against concurrent widget taps: the counter
    /// we capture is the drain horizon; newer taps stay unseen for next cycle.
    private func drainWidgetTapsIntoHealthKit() async {
        let (counter, seen) = HydrationWidgetBridge.currentPendingTapCount()
        let diff = counter - seen
        guard diff > 0 else { return }

        let incrementLiters = Double(HydrationWidgetBridge.tapIncrementML) / 1000.0
        for _ in 0..<diff {
            try? await HealthKitService.shared.logWater(
                ml: Double(HydrationWidgetBridge.tapIncrementML)
            )
        }
        HydrationWidgetBridge.advanceTapCounterSeen(to: counter)
        _ = incrementLiters // silence unused-let if logging is ever guarded
    }

    /// Publishes the current committed state to the App Group so the widget
    /// can render without any hydration logic of its own.
    private func publishWidgetSnapshot() {
        HydrationWidgetBridge.publishSnapshot(
            consumedML: Int(state.consumedML),
            goalML: Int(settings.goalML),
            appLanguage: AppSettingsStore.shared.appLanguage.rawValue
        )
    }

    // MARK: - Captain language routing

    /// Resolve the user's current dialect from the same source NotificationBrain
    /// falls back to. Default is `.iraqi` to match NotificationBrain's own default.
    private func currentDialect() -> DialectLibrary.Dialect {
        let raw = UserDefaults.standard.string(forKey: dialectUserDefaultsKey) ?? "iraqi"
        return DialectLibrary.Dialect(rawValue: raw) ?? .iraqi
    }

    // MARK: - HealthKit last-drink probe

    /// Returns the most recent dietaryWater sample's end date and its source
    /// (manual = written by this app; appleHealth = any other source).
    private func lastDrinkInfo() async -> (Date?, HydrationSource?) {
        do {
            let sample = try await HealthKitService.shared
                .fetchMostRecentQuantitySample(for: .dietaryWater)
            guard let sample else { return (nil, nil) }
            let source: HydrationSource = isFromThisApp(sample)
                ? .manual
                : .appleHealth
            return (sample.endDate, source)
        } catch {
            return (nil, nil)
        }
    }

    private func isFromThisApp(_ sample: HKSample) -> Bool {
        let appBundle = Bundle.main.bundleIdentifier ?? ""
        return sample.sourceRevision.source.bundleIdentifier == appBundle
    }
}
