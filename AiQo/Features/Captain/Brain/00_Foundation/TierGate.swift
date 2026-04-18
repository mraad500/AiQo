import Foundation

/// Single source of truth for which paid features and limits apply to the current user.
///
/// Reads two live sources:
/// 1. UserDefaults key `aiqo.purchases.currentTier` — written by `EntitlementStore` on every
///    StoreKit 2 transaction update. Read here instead of calling `EntitlementStore` directly
///    so `TierGate` remains callable from any isolation (actors, background tasks, views).
/// 2. `FreeTrialManager.isTrialActiveSnapshot` — nonisolated snapshot backed by UserDefaults + Keychain.
///
/// `AccessManager` continues to serve legacy consumers; this class is the canonical gate
/// for the Brain stack and any new code.
final class TierGate {

    // MARK: - Feature catalogue

    enum Feature: Hashable, Sendable {
        // Captain core (Max-tier and above)
        case captainChat
        case captainMemory
        case captainNotifications

        // Intelligence Pro exclusives
        case multiWeekPlan(weeks: Int)
        case weeklyInsightsNarrative
        case monthlyReflection
        case photoAnalysis
        case premiumVoice
        case advancedCulturalAwareness

        var logName: String {
            switch self {
            case .captainChat:               return "captainChat"
            case .captainMemory:             return "captainMemory"
            case .captainNotifications:      return "captainNotifications"
            case .multiWeekPlan(let w):      return "multiWeekPlan(\(w)w)"
            case .weeklyInsightsNarrative:   return "weeklyInsightsNarrative"
            case .monthlyReflection:         return "monthlyReflection"
            case .photoAnalysis:             return "photoAnalysis"
            case .premiumVoice:              return "premiumVoice"
            case .advancedCulturalAwareness: return "advancedCulturalAwareness"
            }
        }
    }

    enum MiningCadence: Sendable { case daily, weekly, never }

    // MARK: - Singleton

    static let shared = TierGate()

    private enum Keys {
        static let currentTier = "aiqo.purchases.currentTier"
    }

    private let defaults: UserDefaults
    private let trialProvider: @Sendable () -> Bool

    #if DEBUG
    /// DEBUG-only override used by tests. `nil` = fall through to real sources.
    private var testOverride: SubscriptionTier?
    #endif

    init(
        defaults: UserDefaults = .standard,
        trialProvider: @escaping @Sendable () -> Bool = { FreeTrialManager.isTrialActiveSnapshot }
    ) {
        self.defaults = defaults
        self.trialProvider = trialProvider
    }

    // MARK: - Current tier

    var currentTier: SubscriptionTier {
        #if DEBUG
        if let testOverride { return testOverride }
        #endif

        if trialProvider() { return .trial }

        let raw = defaults.integer(forKey: Keys.currentTier)
        return SubscriptionTier(rawValue: raw) ?? .none
    }

    // MARK: - Feature access

    func requiredTier(for feature: Feature) -> SubscriptionTier {
        switch feature {
        case .captainChat, .captainMemory, .captainNotifications:
            return .max
        case .multiWeekPlan(let weeks):
            return weeks > 1 ? .pro : .max
        case .weeklyInsightsNarrative, .monthlyReflection,
             .photoAnalysis, .premiumVoice, .advancedCulturalAwareness:
            return .pro
        }
    }

    func canAccess(
        _ feature: Feature,
        file: String = #fileID,
        line: Int = #line
    ) -> Bool {
        let tier = currentTier
        let required = requiredTier(for: feature)
        let allowed = tier.effectiveAccessTier >= required
        diag.logTierGate(
            feature: feature.logName,
            tier: tier,
            requiredTier: required,
            allowed: allowed,
            file: file,
            line: line
        )
        return allowed
    }

    // MARK: - Tier limits (Master Plan §5.2)

    var maxContextTokens: Int {
        switch currentTier.effectiveAccessTier {
        case .pro: return 32_000
        case .max: return 8_000
        default:   return 0
        }
    }

    var maxMemoryRetrievalDepth: Int {
        switch currentTier.effectiveAccessTier {
        case .pro: return 25
        case .max: return 10
        default:   return 0
        }
    }

    var maxSemanticFacts: Int {
        switch currentTier.effectiveAccessTier {
        case .pro: return 500
        case .max: return 200
        default:   return 0
        }
    }

    var maxNotificationsPerDay: Int {
        switch currentTier.effectiveAccessTier {
        case .pro: return 7
        case .max: return 4
        default:   return 0
        }
    }

    /// `nil` = unlimited lookback (Pro). Free tiers also return `nil` because they have no memory access.
    var memoryCallbackLookbackDays: Int? {
        switch currentTier.effectiveAccessTier {
        case .pro: return nil
        case .max: return 30
        default:   return nil
        }
    }

    var emotionalMiningCadence: MiningCadence {
        switch currentTier.effectiveAccessTier {
        case .pro: return .daily
        case .max: return .weekly
        default:   return .never
        }
    }

    var patternMiningWindowDays: Int {
        switch currentTier.effectiveAccessTier {
        case .pro: return 56
        case .max: return 14
        default:   return 0
        }
    }

    var maxWeeksInPlan: Int {
        switch currentTier.effectiveAccessTier {
        case .pro: return 4
        case .max: return 1
        default:   return 0
        }
    }

    // MARK: - Back-compat async hooks (existing callers: EpisodicStore, SemanticStore)

    func memoryFactLimit() async -> Int {
        maxSemanticFacts
    }

    func cappedMemoryFetchLimit(requested: Int, fallback: Int) async -> Int {
        let normalized = requested > 0 ? requested : fallback
        let limit = maxSemanticFacts
        return max(1, min(normalized, limit))
    }

    // MARK: - Testing helpers (DEBUG only)

    #if DEBUG
    func _setTierForTesting(_ tier: SubscriptionTier) {
        testOverride = tier
    }

    func _clearTestOverride() {
        testOverride = nil
    }
    #endif
}
