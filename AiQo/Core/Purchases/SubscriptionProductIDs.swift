import Foundation

enum SubscriptionProductIDs {
    // Live App Store Connect catalog.
    // The existing StoreKit "standard" SKU now maps to the Core tier.
    static let coreMonthly = "com.mraad500.aiqo.standard.monthly"
    static let intelligenceProMonthly = "com.mraad500.aiqo.intelligencepro.monthly"

    // Retired middle-tier SKU kept only to grandfather older entitlements.
    static let proMonthly = "com.mraad500.aiqo.pro.monthly"

    // Legacy product IDs kept only to preserve entitlement decoding for older installs.
    static let legacyCoreMonthly = "aiqo_core_monthly_9_99"
    static let legacyProMonthly = "aiqo_pro_monthly_19_99"
    static let legacyIntelligenceMonthly = "aiqo_intelligence_monthly_39_99"

    // Compatibility alias for older callsites.
    static let standardMonthly = coreMonthly

    static let allCurrentIDs: Set<String> = [
        coreMonthly,
        intelligenceProMonthly
    ]

    static let allKnownIDs: Set<String> = allCurrentIDs.union([
        proMonthly,
        legacyCoreMonthly,
        legacyProMonthly,
        legacyIntelligenceMonthly
    ])

    static let orderedCurrentIDs: [String] = [
        coreMonthly,
        intelligenceProMonthly
    ]

    static let coreFallbackPrice = "$9.99"
    static let intelligenceProFallbackPrice = "$29.99"

    static let standardFallbackPrice = coreFallbackPrice

    static func unlocksIntelligenceProFeatures(productID: String?) -> Bool {
        guard let productID else { return false }

        switch productID {
        case intelligenceProMonthly,
             proMonthly,
             legacyProMonthly,
             legacyIntelligenceMonthly:
            return true
        default:
            return false
        }
    }

    static func unlocksTribeCreation(productID: String?) -> Bool {
        unlocksIntelligenceProFeatures(productID: productID)
    }

    static func isAnyPremium(productID: String?) -> Bool {
        guard let productID else { return false }
        return allKnownIDs.contains(productID)
    }

    static func displayOrderIndex(for productID: String) -> Int {
        orderedCurrentIDs.firstIndex(of: productID) ?? orderedCurrentIDs.count
    }

    static func displayName(for productID: String) -> String {
        switch productID {
        case coreMonthly, legacyCoreMonthly:
            return "AiQo Core"
        case intelligenceProMonthly,
             proMonthly,
             legacyProMonthly,
             legacyIntelligenceMonthly:
            return "AiQo Intelligence Pro"
        default:
            return "AiQo Premium"
        }
    }

    static func fallbackDisplayPrice(for productID: String) -> String {
        switch productID {
        case coreMonthly, legacyCoreMonthly:
            return coreFallbackPrice
        case intelligenceProMonthly,
             proMonthly,
             legacyProMonthly,
             legacyIntelligenceMonthly:
            return intelligenceProFallbackPrice
        default:
            return coreFallbackPrice
        }
    }
}
