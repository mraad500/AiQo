import Foundation

/// The runtime subscription tiers of AiQo.
///
/// Raw values are stable and persisted (`aiqo.purchases.currentTier` UserDefault):
/// `.none = 0`, `.max = 1`, `.trial = 2`, `.pro = 3`. Never renumber — rename only.
nonisolated enum SubscriptionTier: Int, Codable, Sendable, Comparable {
    case none = 0
    case max = 1
    case trial = 2
    case pro = 3

    nonisolated static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rank < rhs.rank
    }

    /// Hierarchy for ≥ comparisons. `.trial` is ranked at Pro-equivalent.
    nonisolated private var rank: Int {
        switch self {
        case .none:  return 0
        case .max:   return 1
        case .trial: return 2
        case .pro:   return 2
        }
    }

    /// Trial gets Pro-equivalent access; otherwise self.
    nonisolated var effectiveAccessTier: SubscriptionTier {
        self == .trial ? .pro : self
    }

    nonisolated var isPaid: Bool { self != .none }

    nonisolated static func from(productID: String) -> SubscriptionTier {
        switch productID {
        case SubscriptionProductIDs.coreMonthly,
             SubscriptionProductIDs.legacyCoreMonthly,
             SubscriptionProductIDs.legacyStandardMonthly:
            return .max
        case SubscriptionProductIDs.intelligenceProMonthly,
             SubscriptionProductIDs.proMonthly,
             SubscriptionProductIDs.legacyIntelligenceProMonthly,
             SubscriptionProductIDs.legacyProMonthly,
             SubscriptionProductIDs.legacyIntelligenceMonthly:
            return .pro
        default:
            return .none
        }
    }

    nonisolated var displayName: String {
        switch self {
        case .none:
            return ""
        case .max:
            return "AiQo Max"
        case .trial:
            return "تجربة مجانية"
        case .pro:
            return "AiQo Intelligence Pro"
        }
    }

    nonisolated var arabicDisplayName: String {
        displayName
    }

    nonisolated var monthlyPrice: String {
        switch self {
        case .none, .trial:
            return ""
        case .max:
            return SubscriptionProductIDs.coreFallbackPrice
        case .pro:
            return SubscriptionProductIDs.intelligenceProFallbackPrice
        }
    }

    nonisolated var productID: String {
        switch self {
        case .none, .trial:
            return ""
        case .max:
            return SubscriptionProductIDs.coreMonthly
        case .pro:
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
    nonisolated var memoryFactLimit: Int {
        switch self {
        case .none: return 50
        case .max: return 200
        case .trial, .pro: return 500
        }
    }

    /// Hard upper bound on Captain-originated local notifications per 24h.
    nonisolated var dailyNotificationBudget: Int {
        switch self {
        case .none: return 2
        case .max: return 4
        case .trial, .pro: return 7
        }
    }

    /// How many memory entries the retriever may surface per Captain turn.
    nonisolated var memoryRetrievalDepth: Int {
        switch self {
        case .none: return 5
        case .max: return 10
        case .trial, .pro: return 25
        }
    }

    /// Rolling window (days) that pattern-mining may reach into.
    nonisolated var patternMiningWindowDays: Int {
        switch self {
        case .none, .max: return 14
        case .trial, .pro: return 56
        }
    }

    /// Approximate Gemini prompt byte budget available to the tier.
    nonisolated var geminiContextBudget: Int {
        switch self {
        case .none: return 2_000
        case .max: return 8_000
        case .trial, .pro: return 32_000
        }
    }
}
