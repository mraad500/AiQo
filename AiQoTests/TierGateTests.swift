import XCTest
@testable import AiQo

final class TierGateTests: XCTestCase {

    override func tearDown() {
        TierGate.shared._clearTestOverride()
        super.tearDown()
    }

    // MARK: - Access

    func testFreeUserHasNoCaptainAccess() {
        TierGate.shared._setTierForTesting(.none)
        XCTAssertFalse(TierGate.shared.canAccess(.captainChat))
        XCTAssertFalse(TierGate.shared.canAccess(.captainMemory))
        XCTAssertFalse(TierGate.shared.canAccess(.captainNotifications))
    }

    func testMaxUserHasChatButNotProOnly() {
        TierGate.shared._setTierForTesting(.max)
        XCTAssertTrue(TierGate.shared.canAccess(.captainChat))
        XCTAssertTrue(TierGate.shared.canAccess(.captainMemory))
        XCTAssertTrue(TierGate.shared.canAccess(.captainNotifications))
        XCTAssertFalse(TierGate.shared.canAccess(.monthlyReflection))
        XCTAssertFalse(TierGate.shared.canAccess(.premiumVoice))
        XCTAssertFalse(TierGate.shared.canAccess(.weeklyInsightsNarrative))
        XCTAssertFalse(TierGate.shared.canAccess(.advancedCulturalAwareness))
    }

    func testProUserUnlocksEveryFeature() {
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertTrue(TierGate.shared.canAccess(.captainChat))
        XCTAssertTrue(TierGate.shared.canAccess(.captainMemory))
        XCTAssertTrue(TierGate.shared.canAccess(.monthlyReflection))
        XCTAssertTrue(TierGate.shared.canAccess(.premiumVoice))
        XCTAssertTrue(TierGate.shared.canAccess(.photoAnalysis))
        XCTAssertTrue(TierGate.shared.canAccess(.advancedCulturalAwareness))
    }

    func testTrialUserGetsProEquivalentAccess() {
        TierGate.shared._setTierForTesting(.trial)
        XCTAssertTrue(TierGate.shared.canAccess(.monthlyReflection))
        XCTAssertTrue(TierGate.shared.canAccess(.premiumVoice))
        XCTAssertEqual(TierGate.shared.currentTier.effectiveAccessTier, .pro)
    }

    // MARK: - Multi-week plans

    func testMaxUserBlockedFromMultiWeekPlan() {
        TierGate.shared._setTierForTesting(.max)
        XCTAssertTrue(TierGate.shared.canAccess(.multiWeekPlan(weeks: 1)))
        XCTAssertFalse(TierGate.shared.canAccess(.multiWeekPlan(weeks: 4)))
    }

    func testProUserUnlocksMultiWeekPlans() {
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertTrue(TierGate.shared.canAccess(.multiWeekPlan(weeks: 4)))
    }

    // MARK: - Limit getters

    func testContextTokenLimits() {
        TierGate.shared._setTierForTesting(.none)
        XCTAssertEqual(TierGate.shared.maxContextTokens, 0)
        TierGate.shared._setTierForTesting(.max)
        XCTAssertEqual(TierGate.shared.maxContextTokens, 8_000)
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertEqual(TierGate.shared.maxContextTokens, 32_000)
        TierGate.shared._setTierForTesting(.trial)
        XCTAssertEqual(TierGate.shared.maxContextTokens, 32_000)
    }

    func testMemoryRetrievalDepthLimits() {
        TierGate.shared._setTierForTesting(.max)
        XCTAssertEqual(TierGate.shared.maxMemoryRetrievalDepth, 10)
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertEqual(TierGate.shared.maxMemoryRetrievalDepth, 25)
    }

    func testSemanticFactLimits() {
        TierGate.shared._setTierForTesting(.none)
        XCTAssertEqual(TierGate.shared.maxSemanticFacts, 0)
        TierGate.shared._setTierForTesting(.max)
        XCTAssertEqual(TierGate.shared.maxSemanticFacts, 200)
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertEqual(TierGate.shared.maxSemanticFacts, 500)
    }

    func testNotificationCapsPerTier() {
        TierGate.shared._setTierForTesting(.max)
        XCTAssertEqual(TierGate.shared.maxNotificationsPerDay, 4)
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertEqual(TierGate.shared.maxNotificationsPerDay, 7)
    }

    func testMemoryCallbackLookback() {
        TierGate.shared._setTierForTesting(.max)
        XCTAssertEqual(TierGate.shared.memoryCallbackLookbackDays, 30)
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertNil(TierGate.shared.memoryCallbackLookbackDays)
    }

    func testPatternMiningWindow() {
        TierGate.shared._setTierForTesting(.max)
        XCTAssertEqual(TierGate.shared.patternMiningWindowDays, 14)
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertEqual(TierGate.shared.patternMiningWindowDays, 56)
    }

    func testEmotionalMiningCadence() {
        TierGate.shared._setTierForTesting(.none)
        XCTAssertEqual(TierGate.shared.emotionalMiningCadence, .never)
        TierGate.shared._setTierForTesting(.max)
        XCTAssertEqual(TierGate.shared.emotionalMiningCadence, .weekly)
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertEqual(TierGate.shared.emotionalMiningCadence, .daily)
    }

    func testMaxWeeksInPlan() {
        TierGate.shared._setTierForTesting(.max)
        XCTAssertEqual(TierGate.shared.maxWeeksInPlan, 1)
        TierGate.shared._setTierForTesting(.pro)
        XCTAssertEqual(TierGate.shared.maxWeeksInPlan, 4)
    }

    // MARK: - Comparable + effectiveAccessTier

    func testTierOrdering() {
        XCTAssertTrue(SubscriptionTier.none < SubscriptionTier.max)
        XCTAssertTrue(SubscriptionTier.max < SubscriptionTier.pro)
        XCTAssertFalse(SubscriptionTier.pro < SubscriptionTier.trial)
        XCTAssertFalse(SubscriptionTier.trial < SubscriptionTier.pro)
    }

    func testEffectiveAccessTierElevatesTrialToPro() {
        XCTAssertEqual(SubscriptionTier.trial.effectiveAccessTier, .pro)
        XCTAssertEqual(SubscriptionTier.pro.effectiveAccessTier, .pro)
        XCTAssertEqual(SubscriptionTier.max.effectiveAccessTier, .max)
        XCTAssertEqual(SubscriptionTier.none.effectiveAccessTier, .none)
    }

    // MARK: - Async back-compat hooks

    func testCappedMemoryFetchLimitRespectsTier() async {
        TierGate.shared._setTierForTesting(.pro)
        let proLimit = await TierGate.shared.cappedMemoryFetchLimit(requested: 100, fallback: 50)
        XCTAssertEqual(proLimit, 100)

        TierGate.shared._setTierForTesting(.max)
        let maxLimit = await TierGate.shared.cappedMemoryFetchLimit(requested: 1_000, fallback: 50)
        XCTAssertEqual(maxLimit, 200) // capped at max tier ceiling

        TierGate.shared._setTierForTesting(.none)
        let noneLimit = await TierGate.shared.cappedMemoryFetchLimit(requested: 100, fallback: 50)
        XCTAssertEqual(noneLimit, 1) // floors at 1 even when tier limit is 0
    }
}
