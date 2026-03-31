import Foundation

/// The three subscription tiers of AiQo.
/// Raw value matches the product ID suffix for easy comparison.
enum SubscriptionTier: Int, Comparable {
    case none = 0
    case core = 1
    case pro = 2
    case intelligence = 3

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(productID: String) -> SubscriptionTier {
        switch productID {
        case SubscriptionProductIDs.coreMonthly:        return .core
        case SubscriptionProductIDs.proMonthly:         return .pro
        case SubscriptionProductIDs.intelligenceMonthly: return .intelligence
        default:                                         return .none
        }
    }

    var displayName: String {
        switch self {
        case .none:         return ""
        case .core:         return "AiQo Core"
        case .pro:          return "AiQo Pro"
        case .intelligence: return "AiQo Intelligence"
        }
    }

    var arabicDisplayName: String {
        switch self {
        case .none:         return ""
        case .core:         return "AiQo Core"
        case .pro:          return "AiQo Pro"
        case .intelligence: return "AiQo Intelligence"
        }
    }

    var monthlyPrice: String {
        switch self {
        case .none:         return ""
        case .core:         return SubscriptionProductIDs.coreFallbackPrice
        case .pro:          return SubscriptionProductIDs.proFallbackPrice
        case .intelligence: return SubscriptionProductIDs.intelligenceFallbackPrice
        }
    }

    var productID: String {
        switch self {
        case .none:         return ""
        case .core:         return SubscriptionProductIDs.coreMonthly
        case .pro:          return SubscriptionProductIDs.proMonthly
        case .intelligence: return SubscriptionProductIDs.intelligenceMonthly
        }
    }
}
