import Foundation
import Combine

@MainActor
final class EntitlementStore: ObservableObject {
    static let shared = EntitlementStore()

    @Published var activeProductId: String? {
        didSet {
            persist(activeProductId, key: Keys.activeProductId)
        }
    }

    @Published var expiresAt: Date? {
        didSet {
            persist(expiresAt, key: Keys.expiresAt)
        }
    }

    var isActive: Bool {
        guard let expiresAt else { return false }
        return expiresAt > nowProvider()
    }

    var isFamily: Bool {
        SubscriptionProductIDs.isFamily(productID: activeProductId)
    }

    var canCreateTribe: Bool {
        isActive && isFamily
    }

    private let defaults: UserDefaults
    private let nowProvider: () -> Date

    init(
        defaults: UserDefaults = .standard,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.nowProvider = nowProvider
        self.activeProductId = defaults.string(forKey: Keys.activeProductId)
        self.expiresAt = defaults.object(forKey: Keys.expiresAt) as? Date
    }

    func setEntitlement(productId: String?, expiresAt: Date?) {
        activeProductId = productId
        self.expiresAt = expiresAt
        print("🛒 Saved entitlement. productId=\(productId ?? "nil"), expiresAt=\(expiresAt?.description ?? "nil")")
    }

    func clear() {
        setEntitlement(productId: nil, expiresAt: nil)
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
    }
}
