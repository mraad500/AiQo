import Foundation

enum SubscriptionProductIDs {
    // Current active product IDs — must match App Store Connect exactly
    static let coreMonthly = "aiqo_core_monthly_9_99"
    static let proMonthly = "aiqo_pro_monthly_19_99"
    static let intelligenceMonthly = "aiqo_intelligence_monthly_39_99"

    // Legacy IDs — kept for migration reference, do not use for new purchases
    static let legacyIndividual = "aiqo_nr_30d_individual_5_99"
    static let legacyFamily = "aiqo_nr_30d_family_10_00"

    static let allCurrentIDs: Set<String> = [
        coreMonthly,
        proMonthly,
        intelligenceMonthly
    ]

    // Fallback display prices shown before StoreKit loads
    static let coreFallbackPrice = "$9.99"
    static let proFallbackPrice = "$19.99"
    static let intelligenceFallbackPrice = "$39.99"

    // Legacy compatibility — all IDs StoreKit should look up (current + legacy for migration)
    static let storeKitLookupIDs: [String] = [
        coreMonthly,
        proMonthly,
        intelligenceMonthly,
        legacyIndividual,
        legacyFamily
    ]

    static func isFamily(productID: String?) -> Bool {
        productID == legacyFamily
    }

    static func isAnyPremium(productID: String?) -> Bool {
        guard let productID else { return false }
        return allCurrentIDs.contains(productID) || productID == legacyIndividual || productID == legacyFamily
    }

    static func displayOrderIndex(for productID: String) -> Int {
        let order = [coreMonthly, proMonthly, intelligenceMonthly, legacyIndividual, legacyFamily]
        return order.firstIndex(of: productID) ?? order.count
    }

    static func displayName(for productID: String) -> String {
        switch productID {
        case coreMonthly:
            return "AiQo Core"
        case proMonthly:
            return "AiQo Pro"
        case intelligenceMonthly:
            return "AiQo Intelligence"
        case legacyFamily:
            return "عائلي"
        default:
            return "فردي"
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
        case legacyFamily:
            return "$10.00"
        default:
            return "$5.99"
        }
    }
}
