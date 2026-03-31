import Foundation

enum SubscriptionProductIDs {
    static let coreMonthly = "aiqo_core_monthly_9_99"
    static let proMonthly = "aiqo_pro_monthly_19_99"
    static let intelligenceMonthly = "aiqo_intelligence_monthly_39_99"

    static let allCurrentIDs: Set<String> = [
        coreMonthly,
        proMonthly,
        intelligenceMonthly
    ]

    static let orderedCurrentIDs: [String] = [
        coreMonthly,
        proMonthly,
        intelligenceMonthly
    ]

    static let coreFallbackPrice = "$9.99"
    static let proFallbackPrice = "$19.99"
    static let intelligenceFallbackPrice = "$39.99"

    static func isFamily(productID: String?) -> Bool {
        // Compatibility bridge for legacy tribe-capability checks.
        productID == intelligenceMonthly
    }

    static func isAnyPremium(productID: String?) -> Bool {
        guard let productID else { return false }
        return allCurrentIDs.contains(productID)
    }

    static func displayOrderIndex(for productID: String) -> Int {
        orderedCurrentIDs.firstIndex(of: productID) ?? orderedCurrentIDs.count
    }

    static func displayName(for productID: String) -> String {
        switch productID {
        case coreMonthly:
            return "AiQo Core"
        case proMonthly:
            return "AiQo Pro"
        case intelligenceMonthly:
            return "AiQo Intelligence"
        default:
            return "AiQo Premium"
        }
    }

    static func fallbackDisplayPrice(for productID: String) -> String {
        switch productID {
        case coreMonthly:
            return coreFallbackPrice
        case proMonthly:
            return proFallbackPrice
        case intelligenceMonthly:
            return intelligenceFallbackPrice
        default:
            return coreFallbackPrice
        }
    }
}
