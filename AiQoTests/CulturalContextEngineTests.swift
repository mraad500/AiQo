import XCTest
@testable import AiQo

final class CulturalContextEngineTests: XCTestCase {

    func testCurrentReturnsState() {
        let state = CulturalContextEngine.current()
        XCTAssertFalse(state.promptSummary.isEmpty)
    }

    func testOrdinaryWeekdayDetection() {
        // Wednesday 2026-05-13 at 15:00 — not Friday, not Ramadan in our sample
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 13
        comps.hour = 15
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        let state = CulturalContextEngine.current(now: date)
        XCTAssertFalse(state.isJumuah)
    }

    func testJumuahDetection() {
        // Friday 2026-05-15 at 12:00
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 15
        comps.hour = 12
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        let state = CulturalContextEngine.current(now: date)
        XCTAssertTrue(state.isJumuah)
    }

    func testGulfWeekendIncludesSaturday() {
        // Saturday 2026-05-16
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 16
        comps.hour = 10
        let date = Calendar(identifier: .gregorian).date(from: comps)!
        let state = CulturalContextEngine.current(now: date)
        XCTAssertTrue(state.isWeekend)
    }

    func testPromptSummaryNonEmpty() {
        let state = CulturalContextEngine.current()
        XCTAssertGreaterThan(state.promptSummary.count, 3)
    }
}

final class PersonaAdapterTests: XCTestCase {

    private func cultural(
        ramadan: Bool = false,
        fasting: Bool = false,
        jumuah: Bool = false,
        eid: CulturalContextEngine.State.EidState = .none,
        weekend: Bool = false,
        tod: BioSnapshot.TimeOfDay = .midday
    ) -> CulturalContextEngine.State {
        CulturalContextEngine.State(
            isRamadan: ramadan,
            isFastingHour: fasting,
            isJumuah: jumuah,
            isEid: eid,
            isWeekend: weekend,
            timeOfDay: tod,
            region: .gulf
        )
    }

    func testReflectiveToneOnJumuah() async {
        let emotion = EmotionalReading(primary: .peace, intensity: 0.3, confidence: 0.8, trend: .stable)
        let directive = await PersonaAdapter.shared.directive(
            emotion: emotion,
            cultural: cultural(jumuah: true, weekend: true)
        )
        XCTAssertEqual(directive.tone, .reflective)
    }

    func testHumorSuppressedDuringFasting() async {
        let emotion = EmotionalReading(primary: .peace, intensity: 0.3, confidence: 0.8, trend: .stable)
        let directive = await PersonaAdapter.shared.directive(
            emotion: emotion,
            cultural: cultural(ramadan: true, fasting: true)
        )
        XCTAssertFalse(directive.humorAllowed)
        XCTAssertTrue(directive.avoidTopics.contains("food"))
    }

    func testGentleToneForGrief() async {
        let emotion = EmotionalReading(primary: .grief, intensity: 0.7, confidence: 0.8, trend: .stable)
        let directive = await PersonaAdapter.shared.directive(
            emotion: emotion,
            cultural: cultural(tod: .evening)
        )
        XCTAssertEqual(directive.tone, .gentle)
    }

    func testEncouragingToneForDecliningTrend() async {
        let emotion = EmotionalReading(primary: .frustration, intensity: 0.4, confidence: 0.8, trend: .declining)
        let directive = await PersonaAdapter.shared.directive(
            emotion: emotion,
            cultural: cultural(tod: .evening)
        )
        XCTAssertEqual(directive.tone, .encouraging)
    }

    func testCelebratoryToneForHighJoy() async {
        let emotion = EmotionalReading(primary: .joy, intensity: 0.85, confidence: 0.9, trend: .improving)
        let directive = await PersonaAdapter.shared.directive(
            emotion: emotion,
            cultural: cultural(tod: .evening)
        )
        XCTAssertEqual(directive.tone, .celebratory)
    }

    func testEidAllowsHumorEvenWhenFasting() async {
        let emotion = EmotionalReading(primary: .joy, intensity: 0.5, confidence: 0.8, trend: .improving)
        let directive = await PersonaAdapter.shared.directive(
            emotion: emotion,
            cultural: cultural(ramadan: true, fasting: true, eid: .eidFitr)
        )
        XCTAssertTrue(directive.humorAllowed)
    }

    func testPromptSuffixIncludesTone() async {
        let emotion = EmotionalReading(primary: .peace, intensity: 0.2, confidence: 0.7, trend: .stable)
        let directive = await PersonaAdapter.shared.directive(
            emotion: emotion,
            cultural: cultural()
        )
        let suffix = directive.promptSuffix()
        XCTAssertTrue(suffix.contains("Tone:"))
        XCTAssertTrue(suffix.contains("Dialect:"))
    }
}
