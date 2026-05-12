import XCTest
@testable import AiQo

/// Verifies `paywall_viewed` event registration. The full `.onAppear` →
/// `didEmitViewed` guard cycle is a SwiftUI behavior that requires a
/// `UIHostingController` host + window to exercise reliably; that's
/// integration scope, not unit. These tests cover the analytics contract
/// (event name + tracking pipeline + coexistence with `paywall_shown`).
@MainActor
final class Paywall_Event_Test: XCTestCase {

    private var mock: MockAnalyticsProvider!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockAnalyticsProvider()
        AnalyticsService.shared.register(provider: mock)
    }

    override func tearDown() async throws {
        mock.clear()
        try await super.tearDown()
    }

    // MARK: - Event shape

    func testPaywallViewedEventNameIsStable() {
        XCTAssertEqual(AnalyticsEvent.paywallViewed.name, "paywall_viewed",
                       "Event name is a public analytics contract.")
    }

    func testPaywallShownEventNameIsStable() {
        // paywall_shown coexists with paywall_viewed by design — verify
        // both names so a rename would surface here, not in prod.
        let event = AnalyticsEvent.paywallShown(source: "captainGate")
        XCTAssertEqual(event.name, "paywall_shown")
        XCTAssertEqual(event.properties["source"] as? String, "captainGate")
    }

    // MARK: - Tracking pipeline

    func testPaywallViewedReachesProviders() {
        AnalyticsService.shared.track(.paywallViewed)
        XCTAssertTrue(mock.eventNames.contains("paywall_viewed"))
    }

    func testPaywallViewedAndShownAreSeparateEvents() {
        AnalyticsService.shared.track(.paywallViewed)
        AnalyticsService.shared.track(.paywallShown(source: "manual"))

        XCTAssertEqual(mock.eventCount(named: "paywall_viewed"), 1)
        XCTAssertEqual(mock.eventCount(named: "paywall_shown"), 1)
    }

    // MARK: - Idempotency expectation (guards the @State pattern)

    func testTrackingTheSameEventTwiceProducesTwoRecords() {
        // AnalyticsService itself is dumb — it forwards every track().
        // The `didEmitViewed` guard lives in PaywallView.onAppear, which
        // is what prevents double-counts at the source. This test
        // documents that the service is intentionally non-dedup'ing, so
        // a missed @State guard in a future paywall variant would surface
        // as duplicate events in dashboards (the right detection layer).
        AnalyticsService.shared.track(.paywallViewed)
        AnalyticsService.shared.track(.paywallViewed)
        XCTAssertEqual(mock.eventCount(named: "paywall_viewed"), 2,
                       "Idempotency is enforced in the View layer, not in AnalyticsService.")
    }
}
