import Foundation

enum SubscriptionProductIDs {
    static let aiqo_nr_30d_individual_5_99 = "aiqo_nr_30d_individual_5_99"
    static let aiqo_nr_30d_family_10_00 = "aiqo_nr_30d_family_10_00"
    static let legacy_aiqo_30d_individual_5_99 = "aiqo_30d_individual_5_99"
    static let legacy_aiqo_30d_family_10_00 = "aiqo_30d_family_10_00"

    static let all = [
        aiqo_nr_30d_individual_5_99,
        aiqo_nr_30d_family_10_00
    ]

    static let storeKitLookupIDs = [
        aiqo_nr_30d_individual_5_99,
        aiqo_nr_30d_family_10_00,
        legacy_aiqo_30d_individual_5_99,
        legacy_aiqo_30d_family_10_00
    ]

    static func isFamily(productID: String?) -> Bool {
        canonicalID(for: productID) == aiqo_nr_30d_family_10_00
    }

    static func isAnyPremium(productID: String?) -> Bool {
        canonicalID(for: productID) != nil
    }

    static func displayOrderIndex(for productID: String) -> Int {
        let canonical = canonicalID(for: productID) ?? productID
        return all.firstIndex(of: canonical) ?? all.count
    }

    static func displayName(for productID: String) -> String {
        switch canonicalID(for: productID) {
        case aiqo_nr_30d_family_10_00:
            return "عائلي"
        default:
            return "فردي"
        }
    }

    static func fallbackDisplayPrice(for productID: String) -> String {
        switch canonicalID(for: productID) {
        case aiqo_nr_30d_family_10_00:
            return "$10.00"
        default:
            return "$5.99"
        }
    }

    static func canonicalID(for productID: String?) -> String? {
        guard let productID else { return nil }

        switch productID {
        case aiqo_nr_30d_individual_5_99, legacy_aiqo_30d_individual_5_99:
            return aiqo_nr_30d_individual_5_99
        case aiqo_nr_30d_family_10_00, legacy_aiqo_30d_family_10_00:
            return aiqo_nr_30d_family_10_00
        default:
            return nil
        }
    }

    static func matches(_ productID: String, canonical canonicalID: String) -> Bool {
        self.canonicalID(for: productID) == canonicalID
    }
}
