// ===============================================
// File: PersonalityStyleVectorTests.swift
// Brain Refactor §42 — coverage for the communication-style analyzer.
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class PersonalityStyleVectorTests: XCTestCase {

    private func makeMessages(_ texts: [String]) -> [CaptainConversationMessage] {
        texts.map { CaptainConversationMessage(role: .user, content: $0) }
    }

    // MARK: - Sample size threshold

    func testSingleMessageProducesEmptyDirective() {
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages(["مشيت اليوم"])
        )
        XCTAssertFalse(vector.hasEnoughSignal,
                       "Single message must not produce a stable style signal")
        XCTAssertTrue(vector.directiveArabic.isEmpty)
    }

    func testTwoMessagesUnlockDirective() {
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages(["مشيت", "تعبت"])
        )
        XCTAssertTrue(vector.hasEnoughSignal)
        XCTAssertFalse(vector.directiveArabic.isEmpty)
    }

    // MARK: - Length bucket

    func testTerseUserProducesTerseDirective() {
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages([
                "مشيت", "تعبت", "ها؟", "اوكي", "زين"
            ])
        )
        XCTAssertLessThan(vector.avgWordsPerMessage, 6)
        XCTAssertTrue(vector.directiveArabic.contains("مختصر"),
                      "Terse style must be reflected in the directive")
    }

    func testVerboseUserProducesExpressiveDirective() {
        let longMessage = "اليوم سويت تمرين كامل بالنادي مع كارديو ومقاومة وتعبت كلش بس حسيت إنه جان مفيد ومحتاجه"
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages([longMessage, longMessage, longMessage])
        )
        XCTAssertGreaterThanOrEqual(vector.avgWordsPerMessage, 14)
        XCTAssertTrue(vector.directiveArabic.contains("معبّر") || vector.directiveArabic.contains("مسهب"))
    }

    // MARK: - Emoji frequency

    func testEmojiUserUnlocksEmojiDirective() {
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages([
                "اليوم زين 💪", "متحمس 🔥🔥", "نمشي يلا 🚶"
            ])
        )
        XCTAssertGreaterThanOrEqual(vector.emojiPerMessage, 0.5)
        XCTAssertTrue(vector.directiveArabic.contains("إيموجي"))
    }

    func testNoEmojiUserProducesAvoidDirective() {
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages([
                "اليوم زين", "متحمس", "نمشي يلا", "تعبت"
            ])
        )
        XCTAssertEqual(vector.emojiPerMessage, 0, accuracy: 0.01)
        XCTAssertTrue(vector.directiveArabic.contains("تجنب الإيموجي"))
    }

    // MARK: - Punctuation intensity

    func testHighEnergyUserUnlocksMatchEnergyDirective() {
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages([
                "يلا!! متحمس!", "كلش زين!!", "هياااا!"
            ])
        )
        XCTAssertGreaterThanOrEqual(vector.punctuationIntensity, 1.5)
        XCTAssertTrue(vector.directiveArabic.contains("الطاقة"))
    }

    // MARK: - Opening style

    func testGreetingOpenerDetected() {
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages([
                "اهلا، شلون اليوم", "هلا حمودي", "السلام عليكم", "أهلا"
            ])
        )
        XCTAssertEqual(vector.preferredOpening, .greeting)
        XCTAssertTrue(vector.directiveArabic.contains("تحية"))
    }

    func testDirectOpenerDetected() {
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages([
                "خل نسوي تمرين", "اليوم تعبت", "نمشي ولا نقعد"
            ])
        )
        XCTAssertEqual(vector.preferredOpening, .direct)
        XCTAssertTrue(vector.directiveArabic.contains("مباشرة"))
    }

    func testQuestionOpenerDetected() {
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages([
                "شنو هدفي اليوم؟", "ها شلون؟", "كم سعرة حرقت؟"
            ])
        )
        XCTAssertEqual(vector.preferredOpening, .question)
        XCTAssertTrue(vector.directiveArabic.contains("سؤال"))
    }

    // MARK: - Window size

    func testOnlyLastEightUserMessagesAreUsed() {
        // Inject 12 short messages then 4 long ones — the analyzer should
        // weight the recent (long) ones more heavily.
        let short = Array(repeating: "هلا", count: 12)
        let long = Array(repeating: "اليوم سويت تمرين كامل وتعبت كلش", count: 4)
        let vector = PersonalityAnalyzer.analyze(
            conversation: makeMessages(short + long)
        )
        // Sample size capped at 8. The 8 most recent are: 4 short + 4 long.
        XCTAssertEqual(vector.sampleSize, 8)
    }

    // MARK: - Defaults safety

    func testEmptyConversationReturnsDefaults() {
        let vector = PersonalityAnalyzer.analyze(conversation: [])
        XCTAssertEqual(vector.sampleSize, 0)
        XCTAssertFalse(vector.hasEnoughSignal)
        XCTAssertTrue(vector.directiveArabic.isEmpty)
    }

    func testCaptainTurnsAreIgnored() {
        let convo: [CaptainConversationMessage] = [
            CaptainConversationMessage(role: .user, content: "اهلا"),
            CaptainConversationMessage(role: .assistant, content: "هلا حبيبي شلونك اليوم؟"),
            CaptainConversationMessage(role: .user, content: "زين")
        ]
        let vector = PersonalityAnalyzer.analyze(conversation: convo)
        XCTAssertEqual(vector.sampleSize, 2,
                       "Captain (assistant) turns must not contaminate the user's vector")
    }
}
