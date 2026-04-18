import Foundation

struct EntitlementSnapshot: Equatable {
    var hasTribeAccess: Bool
    var hasIntelligenceProAccess: Bool
    var activePlan: PremiumPlan?
    var activeProductId: String?
    var isPreviewOverride: Bool

    static let locked = EntitlementSnapshot(
        hasTribeAccess: false,
        hasIntelligenceProAccess: false,
        activePlan: nil,
        activeProductId: nil,
        isPreviewOverride: false
    )
}

@MainActor
protocol EntitlementProvider {
    func snapshot() -> EntitlementSnapshot
}

@MainActor
struct StoreKitEntitlementProvider: EntitlementProvider {
    private let entitlementStore: EntitlementStore

    init(entitlementStore: EntitlementStore? = nil) {
        self.entitlementStore = entitlementStore ?? .shared
    }

    func snapshot() -> EntitlementSnapshot {
        let productId = entitlementStore.activeProductId
        let activePlan = resolvedPlan(for: productId)

        return EntitlementSnapshot(
            hasTribeAccess: entitlementStore.isActive,
            hasIntelligenceProAccess: entitlementStore.hasIntelligenceProAccess,
            activePlan: activePlan,
            activeProductId: productId,
            isPreviewOverride: false
        )
    }

    private func resolvedPlan(for productId: String?) -> PremiumPlan? {
        guard let productId, SubscriptionProductIDs.isAnyPremium(productID: productId) else {
            return nil
        }

        switch SubscriptionTier.from(productID: productId) {
        case .max:
            return .core
        case .pro:
            return .intelligencePro
        case .none, .trial:
            return nil
        }
    }
}

@MainActor
struct PreviewEntitlementProvider: EntitlementProvider {
    let selectedPlan: PremiumPlan

    func snapshot() -> EntitlementSnapshot {
        EntitlementSnapshot(
            hasTribeAccess: true,
            hasIntelligenceProAccess: selectedPlan == .intelligencePro,
            activePlan: selectedPlan,
            activeProductId: selectedPlan.canonicalProductID,
            isPreviewOverride: true
        )
    }
}
