import Foundation
import Combine
import os.log

// MARK: - AI Model Routing

enum AIModelTier: String, Sendable {
    case flash = "gemini-3.0-flash"
    case standard = "gemini-3.0-pro"
    case reasoning = "gemini-3.0-ultra"
}

@MainActor
final class AccessManager: ObservableObject {
    static let shared = AccessManager()

    @Published private(set) var previewEnabled = false
    @Published private(set) var useMockTribeData = true
    @Published private(set) var selectedPreviewPlan: PremiumPlan = .intelligencePro
    @Published private(set) var configurationVersion = 0
    @Published private(set) var entitlementSnapshot: EntitlementSnapshot = .locked

    private let quotaLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "AIQuota"
    )

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

    // MARK: — Standard (Core) tier features

    var canAccessCaptain: Bool { activeTier >= .standard }
    var canAccessGym: Bool { activeTier >= .standard }
    var canAccessKitchen: Bool { activeTier >= .standard }
    var canAccessMyVibe: Bool { activeTier >= .standard }
    var canAccessChallenges: Bool { activeTier >= .standard }
    var canAccessDataTracking: Bool { activeTier >= .standard }
    var canReceiveCaptainNotifications: Bool { activeTier >= .standard }

    // MARK: — Pro tier feature gates

    var canAccessPeaks: Bool { activeTier >= .pro }
    var canAccessKitchenScanner: Bool { activeTier >= .pro }
    var canAccessHRRAssessment: Bool { activeTier >= .pro }

    // MARK: — Intelligence tier feature gates

    var canAccessWeeklyAIWorkoutPlan: Bool { activeTier >= .intelligencePro }
    var canAccessRecordProjects: Bool { activeTier >= .intelligencePro }
    var canAccessExtendedMemory: Bool { activeTier >= .intelligencePro }
    var canAccessIntelligenceModel: Bool { activeTier >= .intelligencePro }

    // MARK: — Memory limit based on tier

    var captainMemoryLimit: Int {
        switch activeTier {
        case .intelligencePro:
            return 500
        case .pro:
            return 350
        default:
            return 200
        }
    }

    // MARK: — AI Quota & Model Routing

    /// Maximum cloud AI messages allowed per calendar day.
    var dailyCloudAIQuota: Int {
        switch activeTier {
        case .standard:       return 20
        case .pro:            return 100
        case .intelligencePro: return .max
        case .none:           return 0
        }
    }

    /// The preferred AI model(s) for the active tier, ordered by priority.
    var allowedAIModels: [AIModelTier] {
        switch activeTier {
        case .standard:       return [.flash]
        case .pro:            return [.standard, .flash]
        case .intelligencePro: return [.reasoning, .standard, .flash]
        case .none:           return [.flash]
        }
    }

    /// Primary model the routing engine should target.
    var preferredAIModel: AIModelTier {
        allowedAIModels.first ?? .flash
    }

    /// Whether the user still has cloud AI budget remaining today.
    var hasCloudQuotaRemaining: Bool {
        activeTier == .intelligencePro || dailyCloudAIUsage < dailyCloudAIQuota
    }

    /// Number of cloud AI messages consumed today.
    var dailyCloudAIUsage: Int {
        guard isCurrentDay(storedDate) else {
            resetDailyUsageIfNeeded()
            return 0
        }
        return defaults.integer(forKey: Keys.dailyCloudUsageCount)
    }

    /// Call this **after** every successful cloud AI response.
    /// Returns `true` if the request was counted, `false` if quota was already exhausted.
    @discardableResult
    func recordCloudAIUsage() -> Bool {
        resetDailyUsageIfNeeded()

        let current = defaults.integer(forKey: Keys.dailyCloudUsageCount)

        guard activeTier == .intelligencePro || current < dailyCloudAIQuota else {
            quotaLogger.warning("cloud_quota_exhausted tier=\(self.activeTier.displayName, privacy: .public) used=\(current)")
            return false
        }

        let newCount = current + 1
        defaults.set(newCount, forKey: Keys.dailyCloudUsageCount)
        defaults.set(Date(), forKey: Keys.dailyCloudUsageDate)

        quotaLogger.info("cloud_usage_recorded count=\(newCount)/\(self.dailyCloudAIQuota) tier=\(self.activeTier.displayName, privacy: .public)")
        return true
    }

    /// Remaining cloud messages for today (capped at Int.max for intelligence tier).
    var remainingCloudMessages: Int {
        guard activeTier != .intelligencePro else { return .max }
        return max(0, dailyCloudAIQuota - dailyCloudAIUsage)
    }

    /// Tier-aware system prompt hint appended to all AI requests.
    var tierSystemPromptFlag: String {
        switch activeTier {
        case .standard:
            return "[TIER:CORE] Respond concisely and efficiently. Prioritize actionable coaching."
        case .pro:
            return "[TIER:PRO] Provide detailed coaching with structured plans. Vision analysis available."
        case .intelligencePro:
            return "[TIER:INTELLIGENCE] Deep analytical reasoning enabled. Provide comprehensive, nuanced analysis with multiple perspectives."
        case .none:
            return "[TIER:FREE] Respond concisely."
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

    // MARK: — Daily Quota Helpers

    private var storedDate: Date? {
        defaults.object(forKey: Keys.dailyCloudUsageDate) as? Date
    }

    private func isCurrentDay(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func resetDailyUsageIfNeeded() {
        guard !isCurrentDay(storedDate) else { return }
        defaults.set(0, forKey: Keys.dailyCloudUsageCount)
        defaults.set(Date(), forKey: Keys.dailyCloudUsageDate)
        quotaLogger.info("daily_cloud_usage_reset")
    }

    private enum Keys {
        static let previewEnabled = "aiqo.tribe.preview.enabled"
        static let useMockTribeData = "aiqo.tribe.preview.useMockData"
        static let selectedPreviewPlan = "aiqo.tribe.preview.plan"
        static let dailyCloudUsageCount = "aiqo.ai.dailyCloudUsageCount"
        static let dailyCloudUsageDate = "aiqo.ai.dailyCloudUsageDate"
    }
}
