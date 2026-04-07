import Foundation

enum SubscriptionProductIDs {
    // Live App Store Connect catalog — 3-tier model.
    static let standardMonthly = "com.mraad500.aiqo.standard.monthly"
    static let proMonthly = "com.mraad500.aiqo.pro.monthly"
    static let intelligenceProMonthly = "com.mraad500.aiqo.intelligencepro.monthly"

    // Legacy product IDs kept only to preserve entitlement decoding for older installs.
    static let legacyCoreMonthly = "aiqo_core_monthly_9_99"
    static let legacyProMonthly = "aiqo_pro_monthly_19_99"
    static let legacyIntelligenceMonthly = "aiqo_intelligence_monthly_39_99"

    static let allCurrentIDs: Set<String> = [
        standardMonthly,
        proMonthly,
        intelligenceProMonthly
    ]

    static let allKnownIDs: Set<String> = allCurrentIDs.union([
        legacyCoreMonthly,
        legacyProMonthly,
        legacyIntelligenceMonthly
    ])

    static let orderedCurrentIDs: [String] = [
        standardMonthly,
        proMonthly,
        intelligenceProMonthly
    ]

    static let standardFallbackPrice = "$9.99"
    static let proFallbackPrice = "$19.99"
    static let intelligenceProFallbackPrice = "$39.99"

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
        case proMonthly, legacyProMonthly,
             intelligenceProMonthly, legacyIntelligenceMonthly:
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
        case standardMonthly, legacyCoreMonthly:
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
        case standardMonthly, legacyCoreMonthly:
            return standardFallbackPrice
        case proMonthly, legacyProMonthly:
            return proFallbackPrice
        case intelligenceProMonthly, legacyIntelligenceMonthly:
            return intelligenceProFallbackPrice
        default:
            return standardFallbackPrice
        }
    }
}
