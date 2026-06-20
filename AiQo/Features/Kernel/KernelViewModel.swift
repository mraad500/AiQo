import SwiftUI
import Combine
import FamilyControls

/// Drives `KernelView`. Owns the user's `FamilyActivitySelection`, resolves the
/// gate (flag → tier → authorization), and persists the encoded selection into
/// `KernelSharedStore` so the extensions can read it. Phase 1: no shielding.
@MainActor
final class KernelViewModel: ObservableObject {
    @Published var selection = FamilyActivitySelection()
    @Published private(set) var gateState: KernelGateState = .featureDisabled
    @Published var isPresentingPicker = false

    // Protection state (mirrored from KernelSharedStore).
    @Published private(set) var isProtectionEnabled = false
    @Published private(set) var mode: KernelProtectionMode = .smart
    @Published private(set) var usageThresholdMinutes = 30
    @Published private(set) var isLocked = false
    @Published private(set) var isUnlocked = false

    /// Set true for a moment when a capped (free) user picks more apps than
    /// `appLimit` allows, so the View can surface the upgrade paywall. One-shot —
    /// the View resets it after presenting.
    @Published var didHitAppLimit = false

    private let auth = FamilyControlsAuthorizationService.shared
    private let store = KernelSharedStore.shared
    private let scheduler = KernelScheduler.shared
    /// The bio engine drives live step progress + doomscroll state (observe it in the View).
    let bio = KernelBioEngine.shared

    private var cancellables = Set<AnyCancellable>()

    /// The current challenge-screen state, computed live from the store + engine.
    var challengeState: KernelChallengeUIState {
        let s = store.load()
        guard s.isProtectionEnabled, s.isLocked else { return .none }
        guard let challenge = s.activeChallenge else { return .preparing }
        let walked = bio.stepsSinceBlock
        // From the 5th shield on, lead with the gentle "enough for today" message;
        // the hard challenge stays available beneath it (never a jail).
        if KernelEscalation.isEnoughForToday(shield: store.triggeredTodayCount()) {
            return .enoughForToday(challenge, stepsWalked: walked)
        }
        return .challenge(challenge, stepsWalked: walked)
    }

    /// Earned coin balance (real `CoinManager`) — shown to gate the spend option.
    var coinBalance: Int { CoinManager.shared.balance }

    /// Energy earned today from real activity — read from the existing mining
    /// loop's daily tally (`HealthKitManager.calculateAndAwardCoins`). No new currency.
    var todayEnergy: Int { UserDefaults.standard.integer(forKey: "aiqo.mining.lastAwardedCoins") }

    /// Kernel charge level (0...1) — grows when the user completes a challenge.
    var chargeLevel: Double { store.load().chargeLevel }

    /// Step target for the active shield — shown on the big unlock card. Falls back
    /// to the escalation base for the current shield if the challenge isn't resolved yet.
    var lockedStepTarget: Int {
        if let challenge = store.load().activeChallenge { return challenge.stepTarget }
        return KernelEscalation.baseSteps(forShield: max(1, store.triggeredTodayCount()))
    }

    /// Minutes remaining in the current earned access session, if any.
    var activeSessionRemainingMinutes: Int? {
        let s = store.load()
        guard s.isUnlocked, let exp = s.unlockExpiry, exp > Date() else { return nil }
        return max(1, Int(exp.timeIntervalSinceNow / 60) + 1)
    }

    /// Total chosen tokens across apps, categories, and web domains.
    var selectedCount: Int { Self.tokenCount(selection) }

    /// How many apps this tier may shield. Free = 1, paid = unlimited (`Int.max`).
    var appLimit: Int { TierGate.shared.kernelAppLimit }

    /// True for the free tier — drives the in-hub "unlimited apps" upgrade card.
    var isAppLimited: Bool { appLimit != .max }

    var isAuthorized: Bool { auth.isAuthorized }

    init() {
        loadPersistedSelection()
        refreshFromStore()
        refreshGate()
        // Re-resolve the gate whenever Family Controls authorization changes — e.g. a
        // persisted approval that loads just after launch — so the feature never gets
        // stuck on the "authorize" card after a relaunch.
        auth.$status
            .receive(on: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in self?.refreshGate() }
            .store(in: &cancellables)
    }

    func onAppear() {
        auth.refresh()
        loadPersistedSelection()
        store.setLanguageCode(AppSettingsStore.shared.appLanguage == .english ? "en" : "ar")
        // Re-shield (layer a) + verify any met challenge so opening AiQo is instant.
        KernelShieldController.shared.reshieldIfNeeded()
        if store.load().isProtectionEnabled { bio.start() }
        Task { await bio.refresh() }
        refreshFromStore()
        refreshGate()
    }

    func requestAuthorization() async {
        do {
            try await auth.requestAuthorization()
        } catch {
            // Phase 1: surface status only; no behavior on failure.
        }
        refreshGate()
    }

    /// Accept the picker's live selection as-is so the system picker stays
    /// responsive; the free-tier app cap is enforced when the picker closes, in
    /// `commitSelection()`. (A `FamilyActivitySelection`'s app/token sets are all
    /// read-only, so we can't subset one — the cap is all-or-nothing per change.)
    func updateSelection(_ newValue: FamilyActivitySelection) {
        selection = newValue
    }

    /// Called when the app picker dismisses. Persists the chosen selection so the
    /// DeviceActivityMonitor extension can decode the same tokens — unless a free
    /// user picked more than `appLimit`, in which case we revert to their last
    /// valid set (or none) and raise `didHitAppLimit` so the View offers Max.
    func commitSelection() {
        if Self.tokenCount(selection) > appLimit {
            didHitAppLimit = true
            selection = Self.decodeSelection(store.selectionData) ?? FamilyActivitySelection()
            refreshFromStore()
            return
        }
        store.setSelectionData(try? JSONEncoder().encode(selection))
        if isProtectionEnabled { scheduler.reapplyIfActive() }
        refreshFromStore()
    }

    /// Total chosen tokens across apps, categories, and web domains.
    private static func tokenCount(_ s: FamilyActivitySelection) -> Int {
        s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    }

    private static func decodeSelection(_ data: Data?) -> FamilyActivitySelection? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    // MARK: - Protection actions (Phase 2)

    func setProtection(_ on: Bool) {
        if on { scheduler.enableProtection(mode: mode) } else { scheduler.disableProtection() }
        refreshFromStore()
    }

    func setMode(_ newMode: KernelProtectionMode) {
        store.setMode(newMode)
        if isProtectionEnabled { scheduler.enableProtection(mode: newMode) }
        refreshFromStore()
    }

    func setThreshold(_ minutes: Int) {
        store.setUsageThreshold(minutes: minutes)
        if isProtectionEnabled, mode == .smart { scheduler.reapplyIfActive() }
        refreshFromStore()
    }

    // MARK: - Unlock actions (Phase 3)

    /// Spend earned coins (real `CoinManager`) to open instead of moving.
    @discardableResult
    func spendToUnlock() -> Bool {
        let ok = bio.spendToUnlock()
        refreshFromStore()
        return ok
    }

    /// Complete a non-step challenge (breathing finished / heart stayed calm).
    /// Steps challenges auto-complete inside the engine from real step data.
    func completeActiveChallenge() {
        guard let challenge = store.load().activeChallenge else { return }
        bio.completeChallengeUnlock(challenge)
        refreshFromStore()
    }

    /// Re-verify against live HealthKit data (e.g. when the challenge appears).
    func refreshChallenge() {
        Task {
            await bio.refresh()
            refreshFromStore()
        }
    }

    /// Tight live tick for the in-app Captain trainer: verify real steps (cheap) and
    /// re-mirror state so an auto-unlock propagates to the challenge screen at once.
    func liveTick() async {
        await bio.liveTick()
        refreshFromStore()
    }

    // MARK: - Private

    private func refreshFromStore() {
        let s = store.load()
        isProtectionEnabled = s.isProtectionEnabled
        mode = s.mode
        usageThresholdMinutes = s.usageThresholdMinutes
        isLocked = s.isLocked
        isUnlocked = s.isUnlocked
    }

    private func loadPersistedSelection() {
        guard let data = store.selectionData,
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }
        selection = decoded
    }

    private func refreshGate() {
        guard FeatureFlags.kernelEnabled else { gateState = .featureDisabled; return }
        // Every tier may USE the Kernel — free is capped to one app (`appLimit`) with
        // an in-hub upgrade card, paid tiers are unlimited. No door paywall: we
        // monetize the NUMBER of protected apps, not access to the feature itself.
        gateState = auth.isAuthorized ? .ready : .needsAuthorization
    }
}
