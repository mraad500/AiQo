import Foundation

/// The runtime subscription tiers of AiQo.
enum SubscriptionTier: Int, Comparable {
    case none = 0
    case core = 1
    case intelligencePro = 3

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(productID: String) -> SubscriptionTier {
        switch productID {
        case SubscriptionProductIDs.coreMonthly,
             SubscriptionProductIDs.legacyCoreMonthly,
             SubscriptionProductIDs.legacyStandardMonthly:
            return .core
        case SubscriptionProductIDs.intelligenceProMonthly,
             SubscriptionProductIDs.proMonthly,
             SubscriptionProductIDs.legacyIntelligenceProMonthly,
             SubscriptionProductIDs.legacyProMonthly,
             SubscriptionProductIDs.legacyIntelligenceMonthly:
            return .intelligencePro
        default:
            return .none
        }
    }

    var displayName: String {
        switch self {
        case .none:
            return ""
        case .core:
            return "AiQo Max"
        case .intelligencePro:
            return "AiQo Intelligence Pro"
        }
    }

    var arabicDisplayName: String {
        displayName
    }

    var monthlyPrice: String {
        switch self {
        case .none:
            return ""
        case .core:
            return SubscriptionProductIDs.coreFallbackPrice
        case .intelligencePro:
            return SubscriptionProductIDs.intelligenceProFallbackPrice
        }
    }

    var productID: String {
        switch self {
        case .none:
            return ""
        case .core:
            return SubscriptionProductIDs.coreMonthly
        case .intelligencePro:
            return SubscriptionProductIDs.intelligenceProMonthly
        }
    }

    // MARK: - Tier-scaled capacity (P1.3)
    //
    // Additive: these computeds let TierGate + other consumers ask the tier
    // directly instead of hard-coding numbers at each gate. Raw values and case
    // names are unchanged to preserve UserDefaults-persisted EntitlementStore
    // state and avoid a 30+ callsite rename.

    /// Captain memory fact cap (user-visible count in Captain Memory settings).
    var memoryFactLimit: Int {
        switch self {
        case .none: return 50
        case .core: return 200
        case .intelligencePro: return 500
        }
    }

    /// Hard upper bound on Captain-originated local notifications per 24h.
    var dailyNotificationBudget: Int {
        switch self {
        case .none: return 2
        case .core: return 4
        case .intelligencePro: return 7
        }
    }

    /// How many memory entries the retriever may surface per Captain turn.
    var memoryRetrievalDepth: Int {
        switch self {
        case .none: return 5
        case .core: return 10
        case .intelligencePro: return 25
        }
    }

    /// Rolling window (days) that pattern-mining may reach into.
    var patternMiningWindowDays: Int {
        switch self {
        case .none, .core: return 14
        case .intelligencePro: return 56
        }
    }

    /// Approximate Gemini prompt byte budget available to the tier.
    var geminiContextBudget: Int {
        switch self {
        case .none: return 2_000
        case .core: return 8_000
        case .intelligencePro: return 32_000
        }
    }
}
