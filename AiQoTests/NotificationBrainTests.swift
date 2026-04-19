import XCTest
@testable import AiQo

final class NotificationBrainTests: XCTestCase {

    override func setUp() async throws {
        #if DEBUG
        await GlobalBudget.shared._resetForTesting()
        await CooldownManager.shared.resetAll()
        #endif
        await MainActor.run {
            TierGate.shared._setTierForTesting(.max)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            TierGate.shared._clearTestOverride()
        }
    }

    func testRequestProducesResult() async {
        let intent = NotificationIntent(
            kind: .inactivityNudge,
            requestedBy: "unit_test"
        )
        let result = await NotificationBrain.shared.request(intent)
        XCTAssertEqual(result.intentID, intent.id)
    }

    func testRejectedIntentReturnsNoDelivery() async {
        let past = Date().addingTimeInterval(-60)
        let expired = NotificationIntent(
            kind: .inactivityNudge,
            requestedBy: "unit_test",
            expiresAt: past
        )
        let result = await NotificationBrain.shared.request(expired)
        XCTAssertNil(result.deliveredAt)
        XCTAssertNil(result.systemRequestID)
    }

    func testDailyCapBlocksFurtherRequests() async {
        await MainActor.run {
            TierGate.shared._setTierForTesting(.max)  // cap 4
        }
        // Simulate 4 already delivered
        for _ in 0..<4 {
            let i = NotificationIntent(kind: .inactivityNudge, requestedBy: "test")
            await GlobalBudget.shared.recordDelivered(i)
        }
        let intent = NotificationIntent(kind: .streakRisk, requestedBy: "test")
        let result = await NotificationBrain.shared.request(intent)
        // Decision should reflect rejection
        if case .rejected(.dailyLimitReached) = result.decision { /* ok */ } else {
            XCTFail("expected daily cap rejection")
        }
    }
}
