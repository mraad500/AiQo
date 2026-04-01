import Foundation
import Combine

@MainActor
final class AccessManager: ObservableObject {
    static let shared = AccessManager()

    @Published private(set) var previewEnabled = false
    @Published private(set) var useMockTribeData = true
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
        if FreeTrialManager.shared.isTrialActive { return .intelligencePro }
        return EntitlementStore.shared.currentTier
    }

    // MARK: — Standard tier features

    var canAccessCaptain: Bool { activeTier >= .standard }
    var canAccessGym: Bool { activeTier >= .standard }
    var canAccessKitchen: Bool { activeTier >= .standard }
    var canAccessMyVibe: Bool { activeTier >= .standard }
    var canAccessChallenges: Bool { activeTier >= .standard }
    var canAccessDataTracking: Bool { activeTier >= .standard }
    var canReceiveCaptainNotifications: Bool { activeTier >= .standard }

    // MARK: — Intelligence Pro feature gates

    var canAccessPeaks: Bool { activeTier >= .intelligencePro }
    var canAccessHRRAssessment: Bool { activeTier >= .intelligencePro }
    var canAccessWeeklyAIWorkoutPlan: Bool { activeTier >= .intelligencePro }
    var canAccessRecordProjects: Bool { activeTier >= .intelligencePro }

    // MARK: — Intelligence Pro intelligence features

    var canAccessExtendedMemory: Bool { activeTier >= .intelligencePro }
    var canAccessIntelligenceModel: Bool { activeTier >= .intelligencePro }

    // MARK: — Memory limit based on tier

    var captainMemoryLimit: Int {
        switch activeTier {
        case .intelligencePro:
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
            useMockTribeData ? "mock" : "liveData",
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

    func setUseMockTribeData(_ enabled: Bool) {
        guard allowsDeveloperOverrides else {
            forceDisablePreviewOverrides()
            return
        }

        guard useMockTribeData != enabled else { return }
        useMockTribeData = enabled
        persist(enabled, key: Keys.useMockTribeData)
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

        useMockTribeData = true
        selectedPreviewPlan = .intelligencePro
        persist(true, key: Keys.useMockTribeData)
        persist(PremiumPlan.intelligencePro.rawValue, key: Keys.selectedPreviewPlan)
        bumpConfiguration()
    }

    func forceDisablePreviewOverrides() {
        let hadPreviewOverride = defaults.bool(forKey: Keys.previewEnabled)
        let hadStoredPlan = defaults.string(forKey: Keys.selectedPreviewPlan) != nil
        let hadStoredMockFlag = defaults.object(forKey: Keys.useMockTribeData) != nil

        previewEnabled = false
        useMockTribeData = true
        selectedPreviewPlan = .intelligencePro

        defaults.removeObject(forKey: Keys.previewEnabled)
        defaults.removeObject(forKey: Keys.useMockTribeData)
        defaults.removeObject(forKey: Keys.selectedPreviewPlan)

#if !DEBUG
        if hadPreviewOverride || hadStoredPlan || hadStoredMockFlag {
            assertionFailure("Preview Tribe overrides are not available outside DEBUG builds.")
        }
#endif

        bumpConfiguration()
    }

    private func restorePersistedOverrides() {
#if DEBUG
        previewEnabled = defaults.bool(forKey: Keys.previewEnabled)

        if defaults.object(forKey: Keys.useMockTribeData) != nil {
            useMockTribeData = defaults.bool(forKey: Keys.useMockTribeData)
        } else {
            useMockTribeData = true
        }

        if let storedPlan = defaults.string(forKey: Keys.selectedPreviewPlan),
           let plan = PremiumPlan.fromStoredValue(storedPlan) {
            selectedPreviewPlan = plan
        } else {
            selectedPreviewPlan = .intelligencePro
        }
#else
        previewEnabled = false
        useMockTribeData = true
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
        static let useMockTribeData = "aiqo.tribe.preview.useMockData"
        static let selectedPreviewPlan = "aiqo.tribe.preview.plan"
    }
}
