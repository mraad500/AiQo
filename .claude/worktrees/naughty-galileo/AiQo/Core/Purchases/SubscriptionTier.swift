import Foundation

/// The runtime subscription tiers of AiQo.
///
/// Raw-value ordering: none(0) < standard(1) < pro(2) < intelligencePro(3).
/// Existing `>= .standard` gates keep working; pro features use `>= .pro`.
enum SubscriptionTier: Int, Comparable, Sendable {
    case none = 0
    case standard = 1
    case pro = 2
    case intelligencePro = 3

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(productID: String) -> SubscriptionTier {
        switch productID {
        case SubscriptionProductIDs.standardMonthly,
             SubscriptionProductIDs.legacyCoreMonthly:
            return .standard
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
        case .standard:
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
        case .standard:
            return SubscriptionProductIDs.standardFallbackPrice
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
        case .standard:
            return SubscriptionProductIDs.standardMonthly
        case .pro:
            return SubscriptionProductIDs.proMonthly
        case .intelligencePro:
            return SubscriptionProductIDs.intelligenceProMonthly
        }
    }
}
