import Foundation
internal import Combine

@MainActor
final class AccessManager: ObservableObject {
    static let shared = AccessManager()

    @Published private(set) var previewEnabled = false
    @Published private(set) var useMockTribeData = true
    @Published private(set) var selectedPreviewPlan: PremiumPlan = .family
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

    var canAccessTribe: Bool {
        entitlementSnapshot.hasTribeAccess
    }

    var canCreateTribe: Bool {
        entitlementSnapshot.hasFamilyPlanAccess
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
        storeKitProvider: StoreKitEntitlementProvider = StoreKitEntitlementProvider()
    ) {
        self.defaults = defaults
        self.storeKitProvider = storeKitProvider
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
        selectedPreviewPlan = .family
        persist(true, key: Keys.useMockTribeData)
        persist(PremiumPlan.family.rawValue, key: Keys.selectedPreviewPlan)
        bumpConfiguration()
    }

    func forceDisablePreviewOverrides() {
        let hadPreviewOverride = defaults.bool(forKey: Keys.previewEnabled)
        let hadStoredPlan = defaults.string(forKey: Keys.selectedPreviewPlan) != nil
        let hadStoredMockFlag = defaults.object(forKey: Keys.useMockTribeData) != nil

        previewEnabled = false
        useMockTribeData = true
        selectedPreviewPlan = .family

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
           let plan = PremiumPlan(rawValue: storedPlan) {
            selectedPreviewPlan = plan
        } else {
            selectedPreviewPlan = .family
        }
#else
        previewEnabled = false
        useMockTribeData = true
        selectedPreviewPlan = .family
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
                hasFamilyPlanAccess: true,
                activePlan: .family,
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
