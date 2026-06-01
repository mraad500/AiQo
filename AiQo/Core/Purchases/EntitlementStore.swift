import Foundation
import Combine

@MainActor
final class EntitlementStore: ObservableObject {
    static let shared = EntitlementStore()

    @Published var activeProductId: String? {
        didSet {
            persist(activeProductId, key: Keys.activeProductId)
            if !isApplyingEntitlement { updateCurrentTier() }
        }
    }

    @Published var expiresAt: Date? {
        didSet {
            persist(expiresAt, key: Keys.expiresAt)
            if !isApplyingEntitlement { updateCurrentTier() }
        }
    }

    @Published var currentTier: SubscriptionTier = .none

    var isActive: Bool {
        guard let expiresAt else { return false }
        return expiresAt > nowProvider()
    }

    var hasIntelligenceProAccess: Bool {
        isActive && SubscriptionProductIDs.unlocksIntelligenceProFeatures(productID: activeProductId)
    }

    var canCreateTribe: Bool {
        isActive && SubscriptionProductIDs.unlocksTribeCreation(productID: activeProductId)
    }

    private let defaults: UserDefaults
    private let nowProvider: () -> Date

    /// True only while `setEntitlement` is mutating both `activeProductId` and
    /// `expiresAt`. Without this, the first property's `didSet` would run
    /// `updateCurrentTier()` while the second value is still stale — for a
    /// first-time subscriber `expiresAt` is still `nil`, so `isActive` reads
    /// false and the tier wrongly stays `.none` until the next cold launch
    /// (where `init` recomputes with both values present). We suppress the
    /// interim recompute and run a single correct one after both land.
    private var isApplyingEntitlement = false

    init(
        defaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.nowProvider = nowProvider
        self.activeProductId = defaults.string(forKey: Keys.activeProductId)
        self.expiresAt = defaults.object(forKey: Keys.expiresAt) as? Date

        // Restore currentTier from UserDefaults
        let savedTierRaw = defaults.integer(forKey: Keys.currentTier)
        self.currentTier = SubscriptionTier(rawValue: savedTierRaw) ?? .none

        // Reconcile tier from active product if available
        updateCurrentTier()
    }

    func setEntitlement(productId: String?, expiresAt: Date?) {
        isApplyingEntitlement = true
        activeProductId = productId
        self.expiresAt = expiresAt
        isApplyingEntitlement = false
        updateCurrentTier()
        diag.info("Entitlement saved productId=\(productId ?? "nil") expiresAt=\(expiresAt?.description ?? "nil")")
    }

    func clear() {
        setEntitlement(productId: nil, expiresAt: nil)
        currentTier = .none
        defaults.removeObject(forKey: Keys.currentTier)
    }

    private func updateCurrentTier() {
        let newTier: SubscriptionTier
        if isActive, let productId = activeProductId {
            newTier = SubscriptionTier.from(productID: productId)
        } else {
            newTier = .none
        }

        guard currentTier != newTier else { return }

        // Persist before publishing: `TierGate.currentTier` reads this
        // UserDefaults key directly, and SwiftUI views (e.g. the Captain gate
        // in MainTabScreen) re-query it the moment the `@Published` change
        // invalidates them. Writing the key first keeps both in lockstep.
        defaults.set(newTier.rawValue, forKey: Keys.currentTier)
        currentTier = newTier
    }

    private func persist(_ value: Any?, key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private enum Keys {
        static let activeProductId = "aiqo.purchases.activeProductId"
        static let expiresAt = "aiqo.purchases.expiresAt"
        static let currentTier = "aiqo.purchases.currentTier"
    }
}
