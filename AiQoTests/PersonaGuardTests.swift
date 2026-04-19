import XCTest
@testable import AiQo

final class PersonaGuardTests: XCTestCase {

    func testPassesCleanMessage() {
        let result = PersonaGuard.validate(
            title: "صباحك نور",
            body: "جاهز لخطواتك اليوم؟",
            kind: .morningKickoff
        )
        XCTAssertTrue(result.passed)
        XCTAssertTrue(result.violations.isEmpty)
    }

    func testDetectsForbiddenLecturingPhrase() {
        let result = PersonaGuard.validate(
            title: "Test",
            body: "you should drink more water",
            kind: .inactivityNudge
        )
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.violations.contains { $0.contains("forbidden_pattern") })
    }

    func testRejectsEmojiOnNonCelebration() {
        let result = PersonaGuard.validate(
            title: "🎉 Reminder",
            body: "Time to move",
            kind: .inactivityNudge
        )
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.violations.contains("emoji_on_non_celebration"))
    }

    func testAllowsEmojiOnCelebration() {
        let result = PersonaGuard.validate(
            title: "رقم شخصي 🔥",
            body: "كسرت رقمك",
            kind: .personalRecord
        )
        XCTAssertTrue(result.passed)
    }

    func testRejectsTitleTooLong() {
        let longTitle = String(repeating: "a", count: 80)
        let result = PersonaGuard.validate(
            title: longTitle,
            body: "body",
            kind: .inactivityNudge
        )
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.violations.contains { $0.contains("title_too_long") })
    }

    func testRejectsProfanity() {
        let result = PersonaGuard.validate(
            title: "Hey",
            body: "damn that's rough",
            kind: .moodShift
        )
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.violations.contains("profanity"))
    }

    func testRejectsHaramContent() {
        let result = PersonaGuard.validate(
            title: "Reminder",
            body: "Skip the alcohol tonight",
            kind: .weeklyInsight
        )
        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.violations.contains("haram_content"))
    }
}

final class MessageComposerRichTests: XCTestCase {

    func testComposeRichWithPersona() async {
        let intent = NotificationIntent(kind: .morningKickoff, requestedBy: "test")
        let emotion = EmotionalReading()
        let cultural = CulturalContextEngine.current()
        let persona = await PersonaAdapter.shared.richDirective(
            emotion: emotion,
            cultural: cultural
        )
        let composed = await MessageComposer.shared.composeRich(
            intent: intent,
            persona: persona,
            dialect: .iraqi
        )
        XCTAssertFalse(composed.title.isEmpty)
        XCTAssertFalse(composed.body.isEmpty)
    }
}
