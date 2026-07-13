import Foundation
import HealthKit
import CoreMotion
import Combine
import os

/// The Kernel's "soul": the bio engine. Runs in the **app** (HealthKit isn't
/// available to the extensions). It:
///  1. observes real step data (`HKObserverQuery` + `.immediate` background
///     delivery) and recent heart signals (Watch enhancement only),
///  2. computes a live `DoomscrollState` and writes the sedentary gate flag the
///     monitor reads (walk-while-using must NOT block),
///  3. verifies the **steps** unlock challenge against real steps-since-block and
///     lifts the shield when met (honest delay — completes on the next HealthKit
///     wake, or immediately when AiQo is opened),
///  4. enforces the daily "loving stop" + once-a-day emergency exit,
///  5. lets the user spend EARNED coins (real `CoinManager`) as an alternative.
///
/// No fake data, ever. No new currency: steps already earn coins via the
/// existing mining loop; completing a challenge adds `chargeLevel` + ONE fixed
/// coin bonus (not per-step).
@MainActor
final class KernelBioEngine: ObservableObject {
    static let shared = KernelBioEngine()

    // Live, real-data state for the challenge screen.
    @Published private(set) var stepsSinceBlock: Int = 0
    @Published private(set) var doomscroll: DoomscrollState = .calm
    @Published private(set) var restingBPM: Int?
    @Published private(set) var latestBPM: Int?

    private let store = KernelSharedStore.shared
    private let shield = KernelShieldController.shared
    private let health = HKHealthStore()
    private let log = Logger(subsystem: "com.mraad500.aiqo.kernel", category: "BioEngine")

    // Tunables.
    private let sedentaryWindowMinutes = 3      // window used to judge "sedentary"
    private let sedentaryStepFloor = 20         // < this many steps in the window = sedentary
    private let stressBPMMargin = 15            // BPM over resting that reads as stressed
    private let heartRecencyMinutes = 30        // HR newer than this ≈ Watch present
    private let unlockCoinBonus = 5             // the single fixed completion bonus
    private let chargePerUnlock = 0.2           // kernel-charge growth per unlock

    // De-dup markers for the Captain "new shield dropped" notification (app-only).
    private static let lastShieldNotifiedKey = "aiqo.kernel.lastShieldNotified"
    private static let lastShieldNotifiedDayKey = "aiqo.kernel.lastShieldNotifiedDay"

    private var observerQuery: HKObserverQuery?
    private var sedentarySince: Date?
    private var isStarted = false

    // Real-time live step counting for the in-app trainer. HealthKit step writes lag
    // by tens of seconds, so the ring would sit at 0 while the user walks — CMPedometer
    // is instant. Active only while the trainer is on screen; the background path keeps
    // using HealthKit (Core Motion needs the app foregrounded).
    private let pedometer = CMPedometer()
    private(set) var liveStepsActive = false

    private init() {}

    // MARK: - Lifecycle

    /// Begin observing steps (idempotent). Safe to call on launch / view-appear /
    /// protection-enable; only registers the observer once.
    func start() {
        guard !isStarted, HKHealthStore.isHealthDataAvailable() else { return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        isStarted = true

        health.enableBackgroundDelivery(for: stepType, frequency: .immediate) { [weak self] ok, err in
            if let err { self?.log.error("background delivery failed: \(err.localizedDescription, privacy: .public)") }
            else { self?.log.notice("background delivery enabled (.immediate) ok=\(ok, privacy: .public)") }
        }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completion, err in
            if let err { self?.log.error("observer error: \(err.localizedDescription, privacy: .public)") }
            Task { @MainActor in
                await self?.refresh()
                completion()
            }
        }
        observerQuery = query
        health.execute(query)
        log.notice("KernelBioEngine started")
    }

    /// Start only if Kernel protection is currently enabled (used at launch).
    func startIfEnabled() {
        if store.load().isProtectionEnabled { start() }
    }

    func stop() {
        if let q = observerQuery { health.stop(q); observerQuery = nil }
        isStarted = false
    }

    // MARK: - The loop

    /// Recompute the live state, refresh the sedentary gate flag, and verify the
    /// steps challenge. Called by the observer (background wake) and on app
    /// foreground (so opening AiQo completes a met challenge immediately).
    func refresh() async {
        let ds = await computeDoomscroll()
        doomscroll = ds
        store.setDoomscrollSedentary(ds.sedentary)

        let state = store.load()
        guard state.isProtectionEnabled, state.isLocked else {
            stepsSinceBlock = 0
            return
        }

        // Freeze a challenge for this lock if the app hasn't yet (the monitor
        // can't generate one — no HealthKit in the extension).
        if state.activeChallenge == nil {
            resolveChallenge(for: ds)
        }
        maybeNotifyShieldDropped()

        // Verify a steps challenge against real steps walked since the block.
        let current = store.load()
        guard let challenge = current.activeChallenge,
              let baseline = current.unlockBaselineAt else { return }
        if case let .steps(target) = challenge.kind {
            guard !liveStepsActive else { return }   // CMPedometer owns the live count during a trainer session
            let walked = await stepsSince(baseline)
            stepsSinceBlock = walked
            if walked >= target {
                completeChallengeUnlock(challenge)
            }
        }
    }

    // MARK: - Live trainer session (in-app, tight polling)

    /// Begin REAL-TIME live step counting via Core Motion for the in-app trainer.
    /// Counts from now (the moment the user presses "ابدأ التحدي"), updates
    /// `stepsSinceBlock` instantly as they walk, and auto-unlocks at the target —
    /// fixing the HealthKit lag that left the ring at 0. No fabricated data: these are
    /// real device pedometer steps.
    func startLiveSteps() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        liveStepsActive = true
        stepsSinceBlock = 0
        pedometer.startUpdates(from: Date()) { [weak self] data, _ in
            guard let data else { return }
            let steps = data.numberOfSteps.intValue
            Task { @MainActor in
                guard let self, self.liveStepsActive else { return }
                let state = self.store.load()
                guard state.isLocked, let challenge = state.activeChallenge,
                      case let .steps(target) = challenge.kind else { return }
                self.stepsSinceBlock = steps
                if steps >= target { self.completeChallengeUnlock(challenge) }
            }
        }
    }

    func stopLiveSteps() {
        guard liveStepsActive else { return }
        liveStepsActive = false
        pedometer.stopUpdates()
    }

    /// Lightweight live refresh for the in-app Captain trainer: reads ONLY real
    /// steps-since-block (no full doomscroll recompute) and auto-completes when the
    /// steps target is met. Cheap enough to run every ~2s while the trainer is on
    /// screen. Heart rate is refreshed separately via `refreshLiveHeartRate()`.
    func liveTick() async {
        let state = store.load()
        guard state.isProtectionEnabled, state.isLocked,
              let challenge = state.activeChallenge,
              let baseline = state.unlockBaselineAt,
              case let .steps(target) = challenge.kind else { return }
        let walked = await stepsSince(baseline)
        stepsSinceBlock = walked
        if walked >= target { completeChallengeUnlock(challenge) }
    }

    /// Refresh the live heart-rate reading from the most-recent REAL sample. Sets
    /// `latestBPM` only when a recent sample exists (≈ Apple Watch present);
    /// otherwise nil so the UI shows an honest "not available" state — never a
    /// fabricated number. (Live streaming needs a Watch workout session, which only
    /// the watchOS app can start; on iPhone this honest periodic read is the floor.)
    func refreshLiveHeartRate() async {
        guard let sample = try? await HealthKitManager.shared.fetchMostRecentQuantitySample(for: .heartRate) else {
            latestBPM = nil
            return
        }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        latestBPM = Date().timeIntervalSince(sample.endDate) < Double(heartRecencyMinutes) * 60
            ? Int(sample.quantity.doubleValue(for: bpmUnit))
            : nil
    }

    /// Fire the Captain's "new shield dropped" notification at most once per fresh
    /// shield (de-duped by a per-day marker in app-only UserDefaults). Runs whenever
    /// the engine wakes (observer / foreground) and sees a shield it hasn't announced.
    private func maybeNotifyShieldDropped() {
        let shield = store.triggeredTodayCount()
        guard shield > 0 else { return }
        let dayKey = store.todayKey()
        let defaults = UserDefaults.standard
        let sameDay = defaults.string(forKey: Self.lastShieldNotifiedDayKey) == dayKey
        if sameDay, shield <= defaults.integer(forKey: Self.lastShieldNotifiedKey) { return }
        defaults.set(dayKey, forKey: Self.lastShieldNotifiedDayKey)
        defaults.set(shield, forKey: Self.lastShieldNotifiedKey)
        KernelCaptainBridge.sendShieldDroppedNotification(shield: shield)
    }

    /// Freeze the escalating challenge for the current shield. The old daily-wall /
    /// once-a-day emergency branch is replaced by the ramp: there is ALWAYS a
    /// challenge (the in-app screen leads with "enough for today" from shield 5, but
    /// the challenge stays available beneath it — never a hard stop / jail).
    private func resolveChallenge(for ds: DoomscrollState) {
        let shield = max(1, store.triggeredTodayCount())
        store.setActiveChallenge(UnlockChallengeGenerator.make(for: ds, shieldNumber: shield))
    }

    // MARK: - Unlock paths

    /// Session length granted on a successful unlock — shrinks with the current
    /// shield number (5 → 4 → 3 → 2 → 1.5 min, then a 1.5-min floor past shield 5).
    private func sessionMinutesForCurrentShield() -> Double {
        KernelEscalation.sessionMinutes(forShield: max(1, store.triggeredTodayCount()))
    }

    /// Completed a real challenge (walk/breath/calm) → earn an access session +
    /// chargeLevel + the single fixed coin bonus.
    func completeChallengeUnlock(_ challenge: UnlockChallenge) {
        KernelScheduler.shared.grantSession(minutes: sessionMinutesForCurrentShield())  // clear shield + open window + layer-b re-block
        store.recordShieldOpened()
        store.addCharge(chargePerUnlock)
        CoinManager.shared.addCoins(unlockCoinBonus)         // the ONE fixed bonus
        notifyUnlocked()
        stepsSinceBlock = 0
        log.notice("unlock by challenge (\(challenge.difficulty.rawValue, privacy: .public))")
    }

    /// Spend EARNED coins (real `CoinManager`) to open instead of moving. No coin
    /// bonus and no charge — they spent rather than moved. Returns false if there is
    /// no active challenge, the energy path is OFF (shield > 5 → physical effort
    /// only), or the balance is insufficient.
    @discardableResult
    func spendToUnlock() -> Bool {
        let state = store.load()
        guard state.isLocked, let challenge = state.activeChallenge else { return false }
        // Energy path is OFF past shield 5 (coinPrice == 0) — physical effort only.
        guard challenge.coinPrice > 0 else { return false }
        guard CoinManager.shared.spendCoins(challenge.coinPrice) else { return false }
        KernelScheduler.shared.grantSession(minutes: sessionMinutesForCurrentShield())
        store.recordShieldOpened()
        notifyUnlocked()
        log.notice("unlock by spend (\(challenge.coinPrice, privacy: .public) coins)")
        return true
    }

    // MARK: - HealthKit reads (all real samples)

    /// Cumulative real steps from `start` until now.
    func stepsSince(_ start: Date) async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let steps = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(steps))
            }
            health.execute(q)
        }
    }

    private func computeDoomscroll() async -> DoomscrollState {
        // Sedentary from real recent steps.
        let recent = await stepsSince(Date().addingTimeInterval(-Double(sedentaryWindowMinutes) * 60))
        let isSedentary = recent < sedentaryStepFloor
        if isSedentary {
            if sedentarySince == nil { sedentarySince = Date() }
        } else {
            sedentarySince = nil
        }
        let sedentaryMinutes = sedentarySince.map { Int(Date().timeIntervalSince($0) / 60) } ?? 0

        // Heart signals — Watch enhancement only.
        let hr = try? await HealthKitManager.shared.fetchMostRecentQuantitySample(for: .heartRate)
        let resting = try? await HealthKitManager.shared.fetchMostRecentQuantitySample(for: .restingHeartRate)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        var latest: Int?
        var hasHeart = false
        if let hr, Date().timeIntervalSince(hr.endDate) < Double(heartRecencyMinutes) * 60 {
            latest = Int(hr.quantity.doubleValue(for: bpmUnit))
            hasHeart = true
        }
        let restingValue = resting.map { Int($0.quantity.doubleValue(for: bpmUnit)) }
        latestBPM = latest
        restingBPM = restingValue

        let stressed: Bool = {
            guard let latest, let restingValue else { return false }
            return latest > restingValue + stressBPMMargin
        }()

        let hour = Calendar.current.component(.hour, from: Date())
        let lateNight = hour >= 23 || hour < 5

        return DoomscrollState(
            sedentary: isSedentary,
            sedentaryMinutes: sedentaryMinutes,
            stressed: stressed,
            lateNight: lateNight,
            hasHeartData: hasHeart
        )
    }

    // MARK: - Notification

    private func notifyUnlocked() {
        // Reframed in the Captain's voice + routed through the existing Captain
        // notification brain (budget / quiet-hours), with a plain-local fallback —
        // see KernelCaptainBridge.sendUnlockNotification().
        KernelCaptainBridge.sendUnlockNotification()
    }
}
