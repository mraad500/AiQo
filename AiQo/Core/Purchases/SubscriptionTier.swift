import Foundation

/// The runtime subscription tiers of AiQo.
enum SubscriptionTier: Int, Comparable {
    case none = 0
    case core = 1
    case pro = 2
    case intelligencePro = 3

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(productID: String) -> SubscriptionTier {
        switch productID {
        case SubscriptionProductIDs.coreMonthly,
             SubscriptionProductIDs.legacyCoreMonthly:
            return .core
        case SubscriptionProductIDs.proMonthly,
             SubscriptionProductIDs.legacyProMonthly:
            return .pro
        case SubscriptionProductIDs.intelligenceProMonthly,
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
        case .pro:
            return "AiQo Pro"
        case .intelligencePro:
            return "AiQo Intelligence"
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
        case .pro:
            return SubscriptionProductIDs.proFallbackPrice
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
        case .pro:
            return SubscriptionProductIDs.proMonthly
        case .intelligencePro:
            return SubscriptionProductIDs.intelligenceProMonthly
        }
    }
}
