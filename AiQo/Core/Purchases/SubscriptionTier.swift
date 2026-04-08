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
             SubscriptionProductIDs.legacyCoreMonthly:
            return .core
        case SubscriptionProductIDs.intelligenceProMonthly,
             SubscriptionProductIDs.proMonthly,
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
            return "AiQo Core"
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
}
