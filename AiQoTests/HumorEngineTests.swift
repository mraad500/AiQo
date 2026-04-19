import XCTest
@testable import AiQo

final class HumorEngineTests: XCTestCase {

    func testOffDuringGrief() {
        let emotion = EmotionalReading(primary: .grief, intensity: 0.8, confidence: 0.9)
        let cultural = CulturalContextEngine.current()
        let intensity = HumorEngine.intensity(emotion: emotion, cultural: cultural)
        XCTAssertEqual(intensity, .off)
    }

    func testPlayfulDuringHighJoy() {
        let emotion = EmotionalReading(
            primary: .joy,
            intensity: 0.8,
            confidence: 0.9,
            trend: .improving
        )
        let cultural = CulturalContextEngine.current()
        let intensity = HumorEngine.intensity(emotion: emotion, cultural: cultural)
        XCTAssertEqual(intensity, .playful)
    }

    func testSubtleDuringFasting() {
        let emotion = EmotionalReading(primary: .peace, intensity: 0.3, confidence: 0.7)
        let cultural = CulturalContextEngine.State(
            isRamadan: true,
            isFastingHour: true,
            isJumuah: false,
            isEid: .none,
            isWeekend: false,
            timeOfDay: .midday,
            region: .gulf
        )
        let intensity = HumorEngine.intensity(emotion: emotion, cultural: cultural)
        XCTAssertEqual(intensity, .subtle)
    }

    func testPlayfulDuringEid() {
        let emotion = EmotionalReading(primary: .peace, intensity: 0.3, confidence: 0.7)
        let cultural = CulturalContextEngine.State(
            isRamadan: false,
            isFastingHour: false,
            isJumuah: false,
            isEid: .eidFitr,
            isWeekend: false,
            timeOfDay: .morning,
            region: .gulf
        )
        let intensity = HumorEngine.intensity(emotion: emotion, cultural: cultural)
        XCTAssertEqual(intensity, .playful)
    }

    func testPlayfulFlourishReturnsPhrase() {
        let phrase = HumorEngine.playfulFlourish(dialect: .iraqi)
        XCTAssertNotNil(phrase)
        XCTAssertFalse(phrase!.isEmpty)
    }
}

final class WisdomLibraryTests: XCTestCase {

    func testNoWisdomDuringGrief() {
        let emotion = EmotionalReading(primary: .grief, intensity: 0.8, confidence: 0.9)
        let cultural = CulturalContextEngine.current()
        let wisdom = WisdomLibrary.appropriate(emotion: emotion, cultural: cultural)
        XCTAssertNil(wisdom)
    }

    func testJumuahReturnsReflective() {
        let emotion = EmotionalReading(primary: .peace, intensity: 0.3, confidence: 0.7)
        let cultural = CulturalContextEngine.State(
            isRamadan: false,
            isFastingHour: false,
            isJumuah: true,
            isEid: .none,
            isWeekend: true,
            timeOfDay: .midday,
            region: .gulf
        )
        let wisdom = WisdomLibrary.appropriate(emotion: emotion, cultural: cultural)
        XCTAssertNotNil(wisdom)
    }

    func testDecliningTrendProducesWisdom() {
        let emotion = EmotionalReading(
            primary: .frustration,
            intensity: 0.5,
            confidence: 0.7,
            trend: .declining
        )
        let cultural = CulturalContextEngine.current()
        let wisdom = WisdomLibrary.appropriate(emotion: emotion, cultural: cultural)
        XCTAssertNotNil(wisdom)
    }
}
