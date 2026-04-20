import XCTest
@testable import AiQo

final class TriggerTests: XCTestCase {

    private func makeBio(
        sleep: Double? = 7.0,
        steps: Int = 5000,
        timeOfDay: BioSnapshot.TimeOfDay = .morning
    ) -> BioSnapshot {
        BioSnapshot(
            timestamp: Date(),
            stepsBucketed: steps,
            heartRateBucketed: 70,
            hrvBucketed: nil,
            sleepHoursBucketed: sleep,
            caloriesBucketed: 200,
            timeOfDay: timeOfDay,
            dayOfWeek: 2,
            isFasting: false
        )
    }

    // MARK: - SleepDebtTrigger

    func testSleepDebtTriggerFiresOnLowSleep() async {
        let ctx = TriggerContext(
            bio: makeBio(sleep: 4.5),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await SleepDebtTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.score, 0.1)
        XCTAssertEqual(result!.intent.kind, .sleepDebtAcknowledgment)
    }

    func testSleepDebtTriggerSilentOnGoodSleep() async {
        let ctx = TriggerContext(
            bio: makeBio(sleep: 8.0),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await SleepDebtTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    func testSleepDebtTriggerSilentOnMissingSleep() async {
        let ctx = TriggerContext(
            bio: makeBio(sleep: nil),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await SleepDebtTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    // MARK: - InactivityTrigger

    func testInactivityTriggerFiresOnAfternoonLowSteps() async {
        let ctx = TriggerContext(
            bio: makeBio(steps: 800, timeOfDay: .afternoon),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await InactivityTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.intent.kind, .inactivityNudge)
    }

    func testInactivityTriggerSilentAtMorning() async {
        let ctx = TriggerContext(
            bio: makeBio(steps: 500, timeOfDay: .morning),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await InactivityTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    // MARK: - PRTrigger

    func testPRTriggerFiresOnHighSteps() async {
        let ctx = TriggerContext(
            bio: makeBio(steps: 12000, timeOfDay: .evening),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await PRTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.intent.priority, .high)
    }

    func testPRTriggerSilentWhenAlreadyCelebratedToday() async {
        let ctx = TriggerContext(
            bio: makeBio(steps: 12000, timeOfDay: .evening),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading(),
            recentDeliveryKinds: [.personalRecord]
        )
        let result = await PRTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    // MARK: - StreakRiskTrigger

    func testStreakRiskFiresOnEveningLowSteps() async {
        let ctx = TriggerContext(
            bio: makeBio(steps: 1500, timeOfDay: .evening),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await StreakRiskTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
    }

    func testStreakRiskSilentInMorning() async {
        let ctx = TriggerContext(
            bio: makeBio(steps: 1500, timeOfDay: .morning),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await StreakRiskTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    // MARK: - EngagementMomentumTrigger

    func testEngagementMomentumFiresOnHotStreak() async {
        let emotion = EmotionalReading(
            primary: .joy,
            intensity: 0.7,
            confidence: 0.8
        )
        let ctx = TriggerContext(
            bio: makeBio(sleep: 7.5, steps: 9000, timeOfDay: .afternoon),
            cultural: CulturalContextEngine.current(),
            emotion: emotion
        )
        let result = await EngagementMomentumTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
    }

    func testEngagementMomentumSilentOnNeutralEmotion() async {
        let ctx = TriggerContext(
            bio: makeBio(sleep: 7.5, steps: 9000, timeOfDay: .afternoon),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await EngagementMomentumTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    // MARK: - DisengagementTrigger (placeholder — BATCH 8 will wire)

    func testDisengagementReturnsNilForNow() async {
        let ctx = TriggerContext(
            bio: makeBio(),
            cultural: CulturalContextEngine.current(),
            emotion: EmotionalReading()
        )
        let result = await DisengagementTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }
}
