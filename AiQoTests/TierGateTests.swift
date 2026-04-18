import XCTest
@testable import AiQo

/// P1.3 — TierGate access-gating contracts.
///
/// Uses the DEBUG-only `TierGate.forceTier(_:)` hook so we don't have to
/// mock `AccessManager` + `FreeTrialManager` + StoreKit just to drive tier.
@MainActor
final class TierGateTests: XCTestCase {

    override func tearDown() async throws {
        // Leave the singleton in free tier between tests so they're order-independent.
        TierGate.shared.forceTier(.free)
        try await super.tearDown()
    }

    // MARK: - Captain chat

    func testFreeUserCannotAccessCaptain() {
        TierGate.shared.forceTier(.free)
        XCTAssertFalse(TierGate.shared.canAccess(.captainChat))
    }

    func testMaxUserCanAccessCaptain() {
        TierGate.shared.forceTier(.max)
        XCTAssertTrue(TierGate.shared.canAccess(.captainChat))
    }

    func testProUserCanAccessCaptain() {
        TierGate.shared.forceTier(.pro)
        XCTAssertTrue(TierGate.shared.canAccess(.captainChat))
    }

    func testTrialUserCanAccessCaptain() {
        TierGate.shared.forceTier(.trial)
        XCTAssertTrue(TierGate.shared.canAccess(.captainChat))
    }

    // MARK: - Extended memory / Pro-only

    func testProUserHasExtendedMemory() {
        TierGate.shared.forceTier(.pro)
        XCTAssertTrue(TierGate.shared.canAccess(.extendedMemory))
    }

    func testMaxUserDoesNotHaveExtendedMemory() {
        TierGate.shared.forceTier(.max)
        XCTAssertFalse(TierGate.shared.canAccess(.extendedMemory))
    }

    func testFreeUserDoesNotHaveMonthlyReflection() {
        TierGate.shared.forceTier(.free)
        XCTAssertFalse(TierGate.shared.canAccess(.monthlyReflection))
    }

    // MARK: - Memory callback lookback rules

    func testMemoryCallbackLookbackRules() {
        TierGate.shared.forceTier(.max)
        XCTAssertTrue(TierGate.shared.canAccess(.memoryCallback(lookbackDays: 20)))
        XCTAssertTrue(TierGate.shared.canAccess(.memoryCallback(lookbackDays: 30)))
        XCTAssertFalse(TierGate.shared.canAccess(.memoryCallback(lookbackDays: 45)))

        TierGate.shared.forceTier(.pro)
        XCTAssertTrue(TierGate.shared.canAccess(.memoryCallback(lookbackDays: 365)))

        TierGate.shared.forceTier(.free)
        XCTAssertFalse(TierGate.shared.canAccess(.memoryCallback(lookbackDays: 1)))
    }

    // MARK: - Multi-week plan

    func testMultiWeekPlanWeekRules() {
        TierGate.shared.forceTier(.max)
        XCTAssertTrue(TierGate.shared.canAccess(.multiWeekPlan(weeks: 1)))
        XCTAssertFalse(TierGate.shared.canAccess(.multiWeekPlan(weeks: 4)))

        TierGate.shared.forceTier(.pro)
        XCTAssertTrue(TierGate.shared.canAccess(.multiWeekPlan(weeks: 12)))
    }

    // MARK: - Pattern mining window

    func testPatternMiningDepthScalesWithTier() {
        TierGate.shared.forceTier(.max)
        XCTAssertTrue(TierGate.shared.canAccess(.patternMiningDepth(days: 14)))
        XCTAssertFalse(TierGate.shared.canAccess(.patternMiningDepth(days: 30)))

        TierGate.shared.forceTier(.pro)
        XCTAssertTrue(TierGate.shared.canAccess(.patternMiningDepth(days: 56)))
        XCTAssertFalse(TierGate.shared.canAccess(.patternMiningDepth(days: 60)))
    }

    // MARK: - Trial semantics

    func testTrialActsAsProEquivalent() {
        TierGate.shared.forceTier(.trial)
        XCTAssertTrue(TierGate.shared.canAccess(.extendedMemory))
        XCTAssertTrue(TierGate.shared.canAccess(.monthlyReflection))
        XCTAssertTrue(TierGate.shared.canAccess(.photoAnalysis))
        XCTAssertEqual(TierGate.shared.memoryFactLimit, 500)
        XCTAssertEqual(TierGate.shared.dailyNotificationBudget, 7)
        XCTAssertEqual(TierGate.shared.memoryRetrievalDepth, 25)
    }

    // MARK: - Budget scaling

    func testMemoryFactLimitScales() {
        TierGate.shared.forceTier(.free)
        XCTAssertEqual(TierGate.shared.memoryFactLimit, 50)

        TierGate.shared.forceTier(.max)
        XCTAssertEqual(TierGate.shared.memoryFactLimit, 200)

        TierGate.shared.forceTier(.pro)
        XCTAssertEqual(TierGate.shared.memoryFactLimit, 500)
    }

    func testDailyNotificationBudgetScales() {
        TierGate.shared.forceTier(.free)
        XCTAssertEqual(TierGate.shared.dailyNotificationBudget, 2)

        TierGate.shared.forceTier(.max)
        XCTAssertEqual(TierGate.shared.dailyNotificationBudget, 4)

        TierGate.shared.forceTier(.pro)
        XCTAssertEqual(TierGate.shared.dailyNotificationBudget, 7)
    }

    func testGeminiContextBudgetScales() {
        TierGate.shared.forceTier(.max)
        XCTAssertEqual(TierGate.shared.geminiContextBudget, 8_000)

        TierGate.shared.forceTier(.pro)
        XCTAssertEqual(TierGate.shared.geminiContextBudget, 32_000)
    }

    // MARK: - Required tier

    func testRequiredTierPointsAtRightUpsell() {
        XCTAssertEqual(TierGate.shared.requiredTier(for: .captainChat), .max)
        XCTAssertEqual(TierGate.shared.requiredTier(for: .extendedMemory), .pro)
        XCTAssertEqual(TierGate.shared.requiredTier(for: .monthlyReflection), .pro)
        XCTAssertEqual(TierGate.shared.requiredTier(for: .memoryCallback(lookbackDays: 15)), .max)
        XCTAssertEqual(TierGate.shared.requiredTier(for: .memoryCallback(lookbackDays: 90)), .pro)
        XCTAssertEqual(TierGate.shared.requiredTier(for: .multiWeekPlan(weeks: 1)), .max)
        XCTAssertEqual(TierGate.shared.requiredTier(for: .multiWeekPlan(weeks: 4)), .pro)
    }

    // MARK: - Fail-closed default

    func testInitialStateDefaultsToFree() {
        // Not guaranteed across tests because tearDown resets to .free, but
        // we verify that .free rejects every premium feature.
        TierGate.shared.forceTier(.free)
        XCTAssertFalse(TierGate.shared.canAccess(.captainChat))
        XCTAssertFalse(TierGate.shared.canAccess(.captainNotifications))
        XCTAssertFalse(TierGate.shared.canAccess(.extendedMemory))
        XCTAssertFalse(TierGate.shared.canAccess(.monthlyReflection))
        XCTAssertFalse(TierGate.shared.canAccess(.premiumVoice))
        XCTAssertFalse(TierGate.shared.canAccess(.peaksAccess))
    }
}
