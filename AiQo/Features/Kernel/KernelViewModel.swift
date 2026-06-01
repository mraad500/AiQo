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

    private let auth = FamilyControlsAuthorizationService.shared
    private let store = KernelSharedStore.shared
    private let scheduler = KernelScheduler.shared
    /// The bio engine drives live step progress + doomscroll state (observe it in the View).
    let bio = KernelBioEngine.shared

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

    /// Minutes remaining in the current earned access session, if any.
    var activeSessionRemainingMinutes: Int? {
        let s = store.load()
        guard s.isUnlocked, let exp = s.unlockExpiry, exp > Date() else { return nil }
        return max(1, Int(exp.timeIntervalSinceNow / 60) + 1)
    }

    /// Total chosen tokens across apps, categories, and web domains.
    var selectedCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    var isAuthorized: Bool { auth.isAuthorized }

    init() {
        loadPersistedSelection()
        refreshFromStore()
        refreshGate()
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

    /// Update the in-memory selection and persist its encoded blob so the
    /// DeviceActivityMonitor extension can decode the same tokens.
    func updateSelection(_ newValue: FamilyActivitySelection) {
        selection = newValue
        store.setSelectionData(try? JSONEncoder().encode(newValue))
        if isProtectionEnabled { scheduler.reapplyIfActive() }
        refreshFromStore()
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
        guard TierGate.shared.canAccess(.kernel) else { gateState = .tierLocked; return }
        gateState = auth.isAuthorized ? .ready : .needsAuthorization
    }
}
