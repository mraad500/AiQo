import Foundation
import Combine

@MainActor
final class AccessManager: ObservableObject {
    static let shared = AccessManager()

    @Published private(set) var previewEnabled = false
    @Published private(set) var selectedPreviewPlan: PremiumPlan = .intelligencePro
    @Published private(set) var configurationVersion = 0
    @Published private(set) var entitlementSnapshot: EntitlementSnapshot = .locked

    var allowsDeveloperOverrides: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    var isPreviewModeActive: Bool {
        allowsDeveloperOverrides && previewEnabled
    }

    // MARK: — Tier helpers

    var activeTier: SubscriptionTier {
        let liveTier = EntitlementStore.shared.currentTier
        if liveTier != .none { return liveTier }
        if FreeTrialManager.shared.isTrialActive { return .pro }
        return .none
    }

    // MARK: — Core tier features

    var canAccessCaptain: Bool { activeTier >= .max }
    var canAccessGym: Bool { activeTier >= .max }
    var canAccessKitchen: Bool { activeTier >= .max }
    var canAccessMyVibe: Bool { activeTier >= .max }
    var canAccessChallenges: Bool { activeTier >= .max }
    var canAccessDataTracking: Bool { activeTier >= .max }
    var canReceiveCaptainNotifications: Bool { activeTier >= .max }

    // MARK: — Feature gates that stay inside Max

    var canAccessHRRAssessment: Bool { activeTier >= .max }
    var canAccessWeeklyAIWorkoutPlan: Bool { activeTier >= .max }
    var canAccessRecordProjects: Bool { activeTier >= .max }

    // MARK: — Legendary Challenges access

    enum LegendaryChallengeAccess {
        case full      // can browse and start projects
        case viewOnly  // can browse, but starting a project triggers the paywall
        case none      // hidden entirely
    }

    var legendaryChallengeAccess: LegendaryChallengeAccess {
        switch activeTier {
        case .none, .max:         return .viewOnly
        case .trial, .pro:        return .full
        }
    }

    // MARK: — Pro exclusives

    var canAccessPeaks: Bool { activeTier >= .pro }
    var canAccessExtendedMemory: Bool { activeTier >= .pro }
    var canAccessIntelligenceModel: Bool { activeTier >= .pro }

    // MARK: — Memory limit based on tier

    var captainMemoryLimit: Int {
        switch activeTier.effectiveAccessTier {
        case .pro:
            return 500
        default:
            return 200
        }
    }

    // MARK: — Tribe (existing logic, kept as-is)

    var canAccessTribe: Bool {
        entitlementSnapshot.hasTribeAccess || FreeTrialManager.shared.isTrialActive
    }

    var canCreateTribe: Bool {
        entitlementSnapshot.hasIntelligenceProAccess || FreeTrialManager.shared.isTrialActive
    }

    var activePlan: PremiumPlan? {
        entitlementSnapshot.activePlan
    }

    var activeProductId: String? {
        entitlementSnapshot.activeProductId
    }

    var configurationSignature: String {
        [
            String(configurationVersion),
            isPreviewModeActive ? "preview" : "live",
            selectedPreviewPlan.rawValue
        ].joined(separator: "|")
    }

    private let defaults: UserDefaults
    private let storeKitProvider: StoreKitEntitlementProvider
    private var cancellables: Set<AnyCancellable> = []

    private init(
        defaults: UserDefaults = .standard,
        storeKitProvider: StoreKitEntitlementProvider? = nil
    ) {
        self.defaults = defaults
        self.storeKitProvider = storeKitProvider ?? StoreKitEntitlementProvider()
        restorePersistedOverrides()
        bind()
        rebuildSnapshot()
    }

    func setPreviewEnabled(_ enabled: Bool) {
        guard allowsDeveloperOverrides else {
            forceDisablePreviewOverrides()
            return
        }

        guard previewEnabled != enabled else { return }
        previewEnabled = enabled
        persist(enabled, key: Keys.previewEnabled)
        bumpConfiguration()
    }

    func setSelectedPreviewPlan(_ plan: PremiumPlan) {
        guard allowsDeveloperOverrides else {
            forceDisablePreviewOverrides()
            return
        }

        guard selectedPreviewPlan != plan else { return }
        selectedPreviewPlan = plan
        persist(plan.rawValue, key: Keys.selectedPreviewPlan)
        bumpConfiguration()
    }

    func resetPreviewData() {
        guard allowsDeveloperOverrides else {
            forceDisablePreviewOverrides()
            return
        }

        selectedPreviewPlan = .intelligencePro
        persist(PremiumPlan.intelligencePro.rawValue, key: Keys.selectedPreviewPlan)
        bumpConfiguration()
    }

    func forceDisablePreviewOverrides() {
        let hadPreviewOverride = defaults.bool(forKey: Keys.previewEnabled)
        let hadStoredPlan = defaults.string(forKey: Keys.selectedPreviewPlan) != nil

        previewEnabled = false
        selectedPreviewPlan = .intelligencePro

        defaults.removeObject(forKey: Keys.previewEnabled)
        defaults.removeObject(forKey: Keys.selectedPreviewPlan)

#if !DEBUG
        if hadPreviewOverride || hadStoredPlan {
            assertionFailure("Preview subscription overrides are not available outside DEBUG builds.")
        }
#endif

        bumpConfiguration()
    }

    private func restorePersistedOverrides() {
#if DEBUG
        previewEnabled = defaults.bool(forKey: Keys.previewEnabled)

        if let storedPlan = defaults.string(forKey: Keys.selectedPreviewPlan),
           let plan = PremiumPlan.fromStoredValue(storedPlan) {
            selectedPreviewPlan = plan
        } else {
            selectedPreviewPlan = .intelligencePro
        }
#else
        previewEnabled = false
        selectedPreviewPlan = .intelligencePro
        forceDisablePreviewOverrides()
#endif
    }

    private func bind() {
        EntitlementStore.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildSnapshot()
            }
            .store(in: &cancellables)
    }

    private func bumpConfiguration() {
        configurationVersion += 1
        rebuildSnapshot()
    }

    private func rebuildSnapshot() {
        if TribeFeatureFlags.subscriptionGateEnabled == false {
            entitlementSnapshot = EntitlementSnapshot(
                hasTribeAccess: true,
                hasIntelligenceProAccess: true,
                activePlan: .intelligencePro,
                activeProductId: nil,
                isPreviewOverride: false
            )
            return
        }

        let provider: any EntitlementProvider

        if isPreviewModeActive {
            provider = PreviewEntitlementProvider(selectedPlan: selectedPreviewPlan)
        } else {
            provider = storeKitProvider
        }

        entitlementSnapshot = provider.snapshot()
    }

    private func persist(_ value: Any?, key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private enum Keys {
        static let previewEnabled = "aiqo.tribe.preview.enabled"
        static let selectedPreviewPlan = "aiqo.tribe.preview.plan"
    }
}
