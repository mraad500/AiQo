import XCTest
@testable import AiQo

final class PurchasesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AiQoTests.Purchases.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create isolated UserDefaults suite for tests.")
        }
        defaults.removePersistentDomain(forName: suiteName)
        self.defaults = defaults
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testEntitlementStorePersistsIntelligenceProExpiryAcrossLaunches() {
        let now = date(year: 2026, month: 2, day: 28, hour: 10)
        let expectedExpiry = calendar.date(byAdding: .day, value: 30, to: now) ?? now

        let store = EntitlementStore(defaults: defaults, nowProvider: { now })
        store.setEntitlement(
            productId: SubscriptionProductIDs.intelligenceProMonthly,
            expiresAt: expectedExpiry
        )

        let reloadedStore = EntitlementStore(defaults: defaults, nowProvider: { now })

        XCTAssertEqual(reloadedStore.activeProductId, SubscriptionProductIDs.intelligenceProMonthly)
        XCTAssertEqual(reloadedStore.expiresAt, expectedExpiry)
        XCTAssertTrue(reloadedStore.isActive)
        XCTAssertEqual(reloadedStore.currentTier, .intelligencePro)
        XCTAssertTrue(reloadedStore.hasIntelligenceProAccess)
        XCTAssertTrue(reloadedStore.canCreateTribe)
    }

    @MainActor
    func testExpiredIntelligenceProPlanIsNotActiveAfterRelaunch() {
        let now = date(year: 2026, month: 2, day: 28, hour: 10)
        let expiredAt = calendar.date(byAdding: .day, value: -1, to: now) ?? now

        let store = EntitlementStore(defaults: defaults, nowProvider: { now })
        store.setEntitlement(
            productId: SubscriptionProductIDs.intelligenceProMonthly,
            expiresAt: expiredAt
        )

        let reloadedStore = EntitlementStore(defaults: defaults, nowProvider: { now })

        XCTAssertFalse(reloadedStore.isActive)
        XCTAssertFalse(reloadedStore.hasIntelligenceProAccess)
        XCTAssertFalse(reloadedStore.canCreateTribe)
    }

    @MainActor
    func testLegacyProProductMapsToIntelligenceProTier() {
        let now = date(year: 2026, month: 2, day: 28, hour: 10)
        let expectedExpiry = calendar.date(byAdding: .day, value: 30, to: now) ?? now

        let store = EntitlementStore(defaults: defaults, nowProvider: { now })
        store.setEntitlement(
            productId: SubscriptionProductIDs.legacyProMonthly,
            expiresAt: expectedExpiry
        )

        XCTAssertEqual(store.currentTier, .intelligencePro)
        XCTAssertTrue(store.hasIntelligenceProAccess)
        XCTAssertFalse(store.canCreateTribe)
    }

    func testNextExpiryAfterPurchaseExtendsExistingActiveWindow() {
        let now = date(year: 2026, month: 2, day: 28, hour: 10)
        let currentExpiry = calendar.date(byAdding: .day, value: 12, to: now) ?? now
        let nextExpiry = PurchaseManager.nextExpiryAfterPurchase(
            currentExpiresAt: currentExpiry,
            now: now,
            calendar: calendar
        )

        let expectedExpiry = calendar.date(byAdding: .day, value: 30, to: currentExpiry) ?? currentExpiry
        XCTAssertEqual(nextExpiry, expectedExpiry)
    }

    func testPremiumExpiryNotifierPlansExpectedNotificationDates() {
        let now = date(year: 2026, month: 2, day: 1, hour: 9)
        let expiresAt = date(year: 2026, month: 3, day: 3, hour: 9)

        let notifications = PremiumExpiryNotifier.plannedNotifications(
            for: expiresAt,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(
            notifications.map(\.identifier),
            [
                PremiumExpiryNotifier.twoDaysBeforeIdentifier,
                PremiumExpiryNotifier.oneDayBeforeIdentifier,
                PremiumExpiryNotifier.expiredIdentifier
            ]
        )
        XCTAssertEqual(notifications[0].fireDate, date(year: 2026, month: 3, day: 1, hour: 9))
        XCTAssertEqual(notifications[1].fireDate, date(year: 2026, month: 3, day: 2, hour: 9))
        XCTAssertEqual(notifications[2].fireDate, expiresAt)
    }

    func testPremiumExpiryNotifierSkipsPastReminderDates() {
        let now = date(year: 2026, month: 3, day: 2, hour: 12)
        let expiresAt = date(year: 2026, month: 3, day: 3, hour: 9)

        let notifications = PremiumExpiryNotifier.plannedNotifications(
            for: expiresAt,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(
            notifications.map(\.identifier),
            [PremiumExpiryNotifier.expiredIdentifier]
        )
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )
        return calendar.date(from: components) ?? Date()
    }
}
