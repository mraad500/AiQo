import Foundation

struct EntitlementSnapshot: Equatable {
    var hasTribeAccess: Bool
    var hasFamilyPlanAccess: Bool
    var activePlan: PremiumPlan?
    var activeProductId: String?
    var isPreviewOverride: Bool

    static let locked = EntitlementSnapshot(
        hasTribeAccess: false,
        hasFamilyPlanAccess: false,
        activePlan: nil,
        activeProductId: nil,
        isPreviewOverride: false
    )
}

protocol EntitlementProvider {
    func snapshot() -> EntitlementSnapshot
}

struct StoreKitEntitlementProvider: EntitlementProvider {
    private let entitlementStore: EntitlementStore

    init(entitlementStore: EntitlementStore = .shared) {
        self.entitlementStore = entitlementStore
    }

    func snapshot() -> EntitlementSnapshot {
        let productId = entitlementStore.activeProductId
        let activePlan = resolvedPlan(for: productId)

        return EntitlementSnapshot(
            hasTribeAccess: entitlementStore.isActive,
            hasFamilyPlanAccess: entitlementStore.canCreateTribe,
            activePlan: activePlan,
            activeProductId: productId,
            isPreviewOverride: false
        )
    }

    private func resolvedPlan(for productId: String?) -> PremiumPlan? {
        guard SubscriptionProductIDs.isAnyPremium(productID: productId) else {
            return nil
        }

        return SubscriptionProductIDs.isFamily(productID: productId) ? .family : .individual
    }
}

struct PreviewEntitlementProvider: EntitlementProvider {
    let selectedPlan: PremiumPlan

    func snapshot() -> EntitlementSnapshot {
        EntitlementSnapshot(
            hasTribeAccess: true,
            hasFamilyPlanAccess: selectedPlan == .family,
            activePlan: selectedPlan,
            activeProductId: selectedPlan.canonicalProductID,
            isPreviewOverride: true
        )
    }
}
