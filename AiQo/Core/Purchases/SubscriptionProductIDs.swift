import Foundation

enum SubscriptionProductIDs {
    // Live App Store Connect catalog.
    // The existing StoreKit "standard" SKU now maps to the Core tier.
    static let coreMonthly = "com.mraad500.aiqo.standard.monthly"
    static let proMonthly = "com.mraad500.aiqo.pro.monthly"
    static let intelligenceProMonthly = "com.mraad500.aiqo.intelligencepro.monthly"

    // Legacy product IDs kept only to preserve entitlement decoding for older installs.
    static let legacyCoreMonthly = "aiqo_core_monthly_9_99"
    static let legacyProMonthly = "aiqo_pro_monthly_19_99"
    static let legacyIntelligenceMonthly = "aiqo_intelligence_monthly_39_99"

    // Compatibility alias for older callsites while the runtime tier names move to Core / Pro / Intelligence.
    static let standardMonthly = coreMonthly

    static let allCurrentIDs: Set<String> = [
        coreMonthly,
        proMonthly,
        intelligenceProMonthly
    ]

    static let allKnownIDs: Set<String> = allCurrentIDs.union([
        legacyCoreMonthly,
        legacyProMonthly,
        legacyIntelligenceMonthly
    ])

    static let orderedCurrentIDs: [String] = [
        coreMonthly,
        proMonthly,
        intelligenceProMonthly
    ]

    static let coreFallbackPrice = "$9.99"
    static let proFallbackPrice = "$19.99"
    static let intelligenceProFallbackPrice = "$39.99"

    static let standardFallbackPrice = coreFallbackPrice

    static func unlocksIntelligenceProFeatures(productID: String?) -> Bool {
        guard let productID else { return false }

        switch productID {
        case intelligenceProMonthly, legacyIntelligenceMonthly:
            return true
        default:
            return false
        }
    }

    static func unlocksProFeatures(productID: String?) -> Bool {
        guard let productID else { return false }

        switch productID {
        case proMonthly, intelligenceProMonthly, legacyProMonthly, legacyIntelligenceMonthly:
            return true
        default:
            return false
        }
    }

    static func unlocksTribeCreation(productID: String?) -> Bool {
        guard let productID else { return false }

        switch productID {
        case intelligenceProMonthly, legacyIntelligenceMonthly:
            return true
        default:
            return false
        }
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
        case proMonthly, legacyProMonthly:
            return "AiQo Pro"
        case intelligenceProMonthly, legacyIntelligenceMonthly:
            return "AiQo Intelligence"
        default:
            return "AiQo Premium"
        }
    }

    static func fallbackDisplayPrice(for productID: String) -> String {
        switch productID {
        case coreMonthly, legacyCoreMonthly:
            return coreFallbackPrice
        case proMonthly, legacyProMonthly:
            return proFallbackPrice
        case intelligenceProMonthly, legacyIntelligenceMonthly:
            return intelligenceProFallbackPrice
        default:
            return coreFallbackPrice
        }
    }
}
