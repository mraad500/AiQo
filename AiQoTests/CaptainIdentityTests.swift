import XCTest
@testable import AiQo

final class CaptainIdentityTests: XCTestCase {

    func testIdentityHasRequiredTraits() {
        XCTAssertTrue(CaptainIdentity.traits.contains("warm"))
        XCTAssertTrue(CaptainIdentity.traits.contains("direct"))
    }

    func testEmojiAllowedOnlyForCelebration() {
        XCTAssertTrue(CaptainIdentity.canUseEmoji(for: .personalRecord))
        XCTAssertTrue(CaptainIdentity.canUseEmoji(for: .eidCelebration))
        XCTAssertFalse(CaptainIdentity.canUseEmoji(for: .inactivityNudge))
        XCTAssertFalse(CaptainIdentity.canUseEmoji(for: .sleepDebtAcknowledgment))
    }

    func testSystemPromptContainsName() {
        let prompt = CaptainIdentity.systemPrompt(
            dialect: "iraqi",
            emotion: EmotionalReading(),
            cultural: CulturalContextEngine.current()
        )
        XCTAssertTrue(prompt.contains("حمودي"))
        XCTAssertTrue(prompt.contains("iraqi"))
    }

    func testSystemPromptRespectsCulturalContext() {
        let cultural = CulturalContextEngine.State(
            isRamadan: true,
            isFastingHour: true,
            isJumuah: false,
            isEid: .none,
            isWeekend: false,
            timeOfDay: .midday,
            region: .gulf
        )
        let prompt = CaptainIdentity.systemPrompt(
            dialect: "iraqi",
            emotion: EmotionalReading(),
            cultural: cultural
        )
        XCTAssertTrue(prompt.contains("Ramadan") || prompt.contains("رمضان"))
    }
}

final class DialectLibraryTests: XCTestCase {

    func testIraqiGreetingReturnsPhrase() {
        let phrase = DialectLibrary.phrase(dialect: .iraqi, context: .greeting)
        XCTAssertFalse(phrase.isEmpty)
    }

    func testEachDialectHasAllContexts() {
        for dialect in DialectLibrary.Dialect.allCases {
            for context in DialectLibrary.Context.allCases {
                let phrase = DialectLibrary.phrase(dialect: dialect, context: context)
                XCTAssertFalse(
                    phrase.isEmpty,
                    "Empty phrase for dialect=\(dialect.rawValue) context=\(context.rawValue)"
                )
            }
        }
    }

    func testMSAFallbackExists() {
        let phrase = DialectLibrary.phrase(dialect: .msa, context: .greeting)
        XCTAssertFalse(phrase.isEmpty)
    }

    func testDialectsProduceVariety() {
        let iraqi = DialectLibrary.phrase(dialect: .iraqi, context: .encouragement)
        let levantine = DialectLibrary.phrase(dialect: .levantine, context: .encouragement)
        XCTAssertFalse(iraqi.isEmpty)
        XCTAssertFalse(levantine.isEmpty)
    }
}
