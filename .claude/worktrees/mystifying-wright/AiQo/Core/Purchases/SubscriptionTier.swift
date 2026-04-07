import Foundation

/// The runtime subscription tiers of AiQo.
enum SubscriptionTier: Int, Comparable {
    case none = 0
    case standard = 1
    case intelligencePro = 2

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(productID: String) -> SubscriptionTier {
        switch productID {
        case SubscriptionProductIDs.standardMonthly,
             SubscriptionProductIDs.legacyCoreMonthly:
            return .standard
        case SubscriptionProductIDs.intelligenceProMonthly,
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
        case .standard:
            return "AiQo Standard"
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
        case .standard:
            return SubscriptionProductIDs.standardFallbackPrice
        case .intelligencePro:
            return SubscriptionProductIDs.intelligenceProFallbackPrice
        }
    }

    var productID: String {
        switch self {
        case .none:
            return ""
        case .standard:
            return SubscriptionProductIDs.standardMonthly
        case .intelligencePro:
            return SubscriptionProductIDs.intelligenceProMonthly
        }
    }
}
