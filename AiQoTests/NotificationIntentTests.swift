import XCTest
@testable import AiQo

final class NotificationIntentTests: XCTestCase {

    func testPriorityOrdering() {
        XCTAssertLessThan(Priority.low, Priority.high)
        XCTAssertLessThan(Priority.medium, Priority.critical)
        XCTAssertGreaterThan(Priority.high, Priority.ambient)
    }

    func testIntentExpiresAfterDeadline() {
        let past = Date().addingTimeInterval(-60)
        let intent = NotificationIntent(
            kind: .morningKickoff,
            requestedBy: "test",
            expiresAt: past
        )
        XCTAssertTrue(intent.isExpired())
    }

    func testIntentWithoutExpirationNeverExpires() {
        let intent = NotificationIntent(kind: .streakRisk, requestedBy: "test")
        XCTAssertFalse(intent.isExpired())
    }

    func testIntentDefaultsToMediumPriority() {
        let intent = NotificationIntent(kind: .inactivityNudge, requestedBy: "test")
        XCTAssertEqual(intent.priority, .medium)
    }

    func testAllNotificationKindsAreStable() {
        // Raw values are stable identifiers — any accidental rename
        // breaks persisted delivery history.
        XCTAssertEqual(NotificationKind.memoryCallback.rawValue, "memoryCallback")
        XCTAssertEqual(NotificationKind.morningKickoff.rawValue, "morningKickoff")
        XCTAssertEqual(NotificationKind.ramadanMindful.rawValue, "ramadanMindful")
    }

    func testBudgetDecisionIsAllowed() {
        XCTAssertTrue(BudgetDecision.allowed.isAllowed)
        XCTAssertTrue(BudgetDecision.allowedWithOverride(reason: "critical").isAllowed)
        XCTAssertFalse(BudgetDecision.rejected(.cooldown).isAllowed)
        XCTAssertFalse(BudgetDecision.deferredToMorning.isAllowed)
    }
}
