import XCTest
@testable import AiQo

final class GlobalBudgetTests: XCTestCase {

    /// Deterministic daytime instant — avoids quiet-hours flakiness on
    /// machines that happen to run tests late at night.
    private func noonToday() -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 12
        comps.minute = 0
        return cal.date(from: comps) ?? Date()
    }

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

    func testAllowedWhenUnderCap() async {
        let intent = NotificationIntent(kind: .inactivityNudge, requestedBy: "test")
        let decision = await GlobalBudget.shared.evaluate(intent, now: noonToday())
        XCTAssertTrue(decision.isAllowed)
    }

    func testExpiredIntentRejected() async {
        let past = Date().addingTimeInterval(-60)
        let intent = NotificationIntent(
            kind: .inactivityNudge,
            requestedBy: "test",
            expiresAt: past
        )
        let decision = await GlobalBudget.shared.evaluate(intent, now: noonToday())
        if case .rejected(.expired) = decision { /* ok */ } else {
            XCTFail("expected .rejected(.expired), got \(decision)")
        }
    }

    func testDailyCapEnforced() async {
        await MainActor.run {
            TierGate.shared._setTierForTesting(.max)  // cap = 4
        }
        // Consume cap
        for _ in 0..<4 {
            let intent = NotificationIntent(kind: .inactivityNudge, requestedBy: "test")
            await GlobalBudget.shared.recordDelivered(intent)
        }
        // 5th should be rejected
        let intent = NotificationIntent(kind: .inactivityNudge, requestedBy: "test")
        let decision = await GlobalBudget.shared.evaluate(intent, now: noonToday())
        if case .rejected(.dailyLimitReached) = decision { /* ok */ } else {
            XCTFail("expected .rejected(.dailyLimitReached), got \(decision)")
        }
    }

    func testCriticalOverridesDailyCap() async {
        await MainActor.run {
            TierGate.shared._setTierForTesting(.max)  // cap = 4
        }
        for _ in 0..<4 {
            let intent = NotificationIntent(kind: .inactivityNudge, requestedBy: "test")
            await GlobalBudget.shared.recordDelivered(intent)
        }
        // Critical priority can override one above the cap
        let critical = NotificationIntent(
            kind: .recoveryReminder,
            priority: .critical,
            requestedBy: "test"
        )
        let decision = await GlobalBudget.shared.evaluate(critical, now: noonToday())
        if case .allowedWithOverride = decision { /* ok */ } else {
            XCTFail("expected .allowedWithOverride, got \(decision)")
        }
    }

    func testMonthlyReflectionRequiresPro() async {
        await MainActor.run {
            TierGate.shared._setTierForTesting(.max)
        }
        let intent = NotificationIntent(kind: .monthlyReflection, requestedBy: "test")
        let decision = await GlobalBudget.shared.evaluate(intent, now: noonToday())
        if case .rejected(.tierDisabled) = decision { /* ok */ } else {
            XCTFail("expected .rejected(.tierDisabled), got \(decision)")
        }
    }

    func testMonthlyReflectionAllowedForPro() async {
        await MainActor.run {
            TierGate.shared._setTierForTesting(.pro)
        }
        let intent = NotificationIntent(kind: .monthlyReflection, requestedBy: "test")
        let decision = await GlobalBudget.shared.evaluate(intent, now: noonToday())
        XCTAssertTrue(decision.isAllowed)
    }
}

final class CooldownManagerTests: XCTestCase {

    override func setUp() async throws {
        await CooldownManager.shared.resetAll()
    }

    func testFreshKindNotOnCooldown() async {
        let result = await CooldownManager.shared.isOnCooldown(.inactivityNudge)
        XCTAssertFalse(result)
    }

    func testRecentDeliveryPutsKindOnCooldown() async {
        await CooldownManager.shared.recordDelivery(.inactivityNudge)
        let result = await CooldownManager.shared.isOnCooldown(.inactivityNudge)
        XCTAssertTrue(result)
    }

    func testOldDeliveryAllowsAgain() async {
        #if DEBUG
        let oldDate = Date().addingTimeInterval(-24 * 3600)
        await CooldownManager.shared._force(lastDelivery: oldDate, forKind: .inactivityNudge)
        let result = await CooldownManager.shared.isOnCooldown(.inactivityNudge)
        XCTAssertFalse(result)
        #endif
    }
}

final class QuietHoursManagerTests: XCTestCase {

    func testQuietAtMidnight() async {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 15; comps.hour = 0; comps.minute = 30
        let midnight = cal.date(from: comps)!
        let isQuiet = await QuietHoursManager.shared.isQuietNow(now: midnight)
        XCTAssertTrue(isQuiet)
    }

    func testNotQuietAtNoon() async {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 15; comps.hour = 12
        let noon = cal.date(from: comps)!
        let isQuiet = await QuietHoursManager.shared.isQuietNow(now: noon)
        XCTAssertFalse(isQuiet)
    }

    func testNextWakeDateReturnsFutureDate() async {
        let wake = await QuietHoursManager.shared.nextWakeDate()
        XCTAssertGreaterThan(wake, Date())
    }
}
