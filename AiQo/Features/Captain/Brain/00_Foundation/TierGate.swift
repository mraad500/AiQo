import Foundation

final class TierGate {
    enum Feature: Sendable {
        case captainChat
        case captainNotifications
        case captainMemory
        case photoAnalysis
        case multiWeekPlan(weeks: Int)
        case weeklyInsightsNarrative
        case premiumVoice

        var logName: String {
            switch self {
            case .captainChat:
                return "captainChat"
            case .captainNotifications:
                return "captainNotifications"
            case .captainMemory:
                return "captainMemory"
            case .photoAnalysis:
                return "photoAnalysis"
            case .multiWeekPlan(let weeks):
                return "multiWeekPlan(\(weeks)w)"
            case .weeklyInsightsNarrative:
                return "weeklyInsightsNarrative"
            case .premiumVoice:
                return "premiumVoice"
            }
        }
    }

    static let shared = TierGate()

    private enum Keys {
        static let currentTier = "aiqo.purchases.currentTier"
        static let previewEnabled = "aiqo.tribe.preview.enabled"
        static let previewPlan = "aiqo.tribe.preview.plan"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentTier: SubscriptionTier {
#if DEBUG
        if defaults.bool(forKey: Keys.previewEnabled),
           let previewPlanRaw = defaults.string(forKey: Keys.previewPlan),
           let previewPlan = PremiumPlan.fromStoredValue(previewPlanRaw) {
            return previewPlan == .intelligencePro ? .intelligencePro : .core
        }
#endif
        if FreeTrialManager.shared.isTrialActive {
            return .intelligencePro
        }

        return SubscriptionTier(rawValue: defaults.integer(forKey: Keys.currentTier)) ?? .none
    }

    func requiredTier(for feature: Feature) -> SubscriptionTier {
        switch feature {
        case .captainChat, .captainNotifications, .captainMemory:
            return .core
        case .photoAnalysis, .weeklyInsightsNarrative, .premiumVoice:
            return .intelligencePro
        case .multiWeekPlan(let weeks):
            return max(weeks, 1) > 1 ? .intelligencePro : .core
        }
    }

    func canAccess(
        _ feature: Feature,
        file: String = #fileID,
        line: Int = #line
    ) -> Bool {
        let tier = currentTier
        let requiredTier = requiredTier(for: feature)
        let allowed = tier >= requiredTier
        diag.logTierGate(
            feature: feature.logName,
            tier: tier,
            requiredTier: requiredTier,
            allowed: allowed,
            file: file,
            line: line
        )
        return allowed
    }

    func memoryFactLimit() async -> Int {
        await MainActor.run {
            AccessManager.shared.captainMemoryLimit
        }
    }

    func cappedMemoryFetchLimit(requested: Int, fallback: Int) async -> Int {
        let normalized = requested > 0 ? requested : fallback
        let tierLimit = await memoryFactLimit()
        return max(1, min(normalized, tierLimit))
    }
}
