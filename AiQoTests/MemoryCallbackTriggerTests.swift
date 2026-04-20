import XCTest
@testable import AiQo

final class MagicTriggerTests: XCTestCase {

    private func makeBio(
        timeOfDay: BioSnapshot.TimeOfDay = .evening
    ) -> BioSnapshot {
        BioSnapshot(
            timestamp: Date(),
            stepsBucketed: 5000,
            heartRateBucketed: 70,
            hrvBucketed: nil,
            sleepHoursBucketed: 7.0,
            caloriesBucketed: 200,
            timeOfDay: timeOfDay,
            dayOfWeek: 3,
            isFasting: false
        )
    }

    private func makeCultural(
        isEid: CulturalContextEngine.State.EidState = .none,
        isRamadan: Bool = false,
        isFastingHour: Bool = false,
        isJumuah: Bool = false,
        timeOfDay: BioSnapshot.TimeOfDay = .morning,
        region: CulturalContextEngine.State.Region = .gulf
    ) -> CulturalContextEngine.State {
        CulturalContextEngine.State(
            isRamadan: isRamadan,
            isFastingHour: isFastingHour,
            isJumuah: isJumuah,
            isEid: isEid,
            isWeekend: false,
            timeOfDay: timeOfDay,
            region: region
        )
    }

    // MARK: - MemoryCallbackTrigger

    func testMemoryCallbackSilentOnDistressing() async {
        let emotion = EmotionalReading(
            primary: .grief,
            intensity: 0.8,
            confidence: 0.8
        )
        let ctx = TriggerContext(
            bio: makeBio(),
            cultural: makeCultural(),
            emotion: emotion
        )
        let result = await MemoryCallbackTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    func testMemoryCallbackSilentWhenOtherNotifsCompeting() async {
        let ctx = TriggerContext(
            bio: makeBio(),
            cultural: makeCultural(),
            emotion: EmotionalReading(),
            recentDeliveryKinds: [.morningKickoff, .inactivityNudge]
        )
        let result = await MemoryCallbackTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    // MARK: - CulturalTrigger

    func testCulturalTriggerFiresOnEidFitr() async {
        let ctx = TriggerContext(
            bio: makeBio(timeOfDay: .morning),
            cultural: makeCultural(isEid: .eidFitr),
            emotion: EmotionalReading()
        )
        let result = await CulturalTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.intent.kind, .eidCelebration)
        XCTAssertEqual(result!.intent.priority, .high)
    }

    func testCulturalTriggerFiresOnEidAdha() async {
        let ctx = TriggerContext(
            bio: makeBio(timeOfDay: .morning),
            cultural: makeCultural(isEid: .eidAdha),
            emotion: EmotionalReading()
        )
        let result = await CulturalTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.intent.kind, .eidCelebration)
    }

    func testCulturalTriggerRamadanFastingHour() async {
        let ctx = TriggerContext(
            bio: makeBio(),
            cultural: makeCultural(isRamadan: true, isFastingHour: true),
            emotion: EmotionalReading()
        )
        let result = await CulturalTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.intent.kind, .ramadanMindful)
    }

    func testCulturalTriggerSilentOnNormalDay() async {
        let ctx = TriggerContext(
            bio: makeBio(),
            cultural: makeCultural(),
            emotion: EmotionalReading()
        )
        let result = await CulturalTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    func testCulturalEidPrecedenceOverRamadan() async {
        // Both Eid and Ramadan set — Eid wins.
        let ctx = TriggerContext(
            bio: makeBio(),
            cultural: makeCultural(
                isEid: .eidFitr,
                isRamadan: true,
                isFastingHour: true
            ),
            emotion: EmotionalReading()
        )
        let result = await CulturalTrigger().evaluate(context: ctx)
        XCTAssertEqual(result!.intent.kind, .eidCelebration)
    }

    // MARK: - MoodShiftTrigger

    func testMoodShiftFiresOnDecliningTrend() async {
        let emotion = EmotionalReading(
            primary: .frustration,
            intensity: 0.7,
            confidence: 0.8,
            trend: .declining
        )
        let ctx = TriggerContext(
            bio: makeBio(timeOfDay: .afternoon),
            cultural: makeCultural(),
            emotion: emotion
        )
        let result = await MoodShiftTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
    }

    func testMoodShiftSilentOnStableTrend() async {
        let emotion = EmotionalReading(
            primary: .frustration,
            intensity: 0.7,
            confidence: 0.8,
            trend: .stable
        )
        let ctx = TriggerContext(
            bio: makeBio(),
            cultural: makeCultural(),
            emotion: emotion
        )
        let result = await MoodShiftTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    // MARK: - MorningKickoffTrigger

    func testMorningKickoffFiresInMorning() async {
        let ctx = TriggerContext(
            bio: makeBio(timeOfDay: .morning),
            cultural: makeCultural(),
            emotion: EmotionalReading()
        )
        let result = await MorningKickoffTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
    }

    func testMorningKickoffSilentIfAlreadyDeliveredToday() async {
        let ctx = TriggerContext(
            bio: makeBio(timeOfDay: .morning),
            cultural: makeCultural(),
            emotion: EmotionalReading(),
            recentDeliveryKinds: [.morningKickoff]
        )
        let result = await MorningKickoffTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }

    // MARK: - CircadianNudgeTrigger

    func testCircadianNudgeFiresAtNightWithLowSleep() async {
        let ctx = TriggerContext(
            bio: BioSnapshot(
                timestamp: Date(),
                stepsBucketed: 5000,
                heartRateBucketed: 70,
                hrvBucketed: nil,
                sleepHoursBucketed: 5.5,
                caloriesBucketed: 200,
                timeOfDay: .night,
                dayOfWeek: 3,
                isFasting: false
            ),
            cultural: makeCultural(),
            emotion: EmotionalReading()
        )
        let result = await CircadianNudgeTrigger().evaluate(context: ctx)
        XCTAssertNotNil(result)
    }

    // MARK: - TrialDayTrigger (placeholder)

    func testTrialDayReturnsNilUntilBatch8() async {
        let ctx = TriggerContext(
            bio: makeBio(),
            cultural: makeCultural(),
            emotion: EmotionalReading()
        )
        let result = await TrialDayTrigger().evaluate(context: ctx)
        XCTAssertNil(result)
    }
}
