import XCTest
@testable import AiQo

final class SentimentDetectorTests: XCTestCase {

    private let detector = SentimentDetector.shared

    // MARK: - Empty / Neutral

    func testEmptyMessage_returnsNeutral() {
        let result = detector.detect(message: "")
        XCTAssertEqual(result.sentiment, .neutral)
        XCTAssertEqual(result.confidence, 0.3, accuracy: 0.001)
        XCTAssertTrue(result.detectedKeywords.isEmpty)
    }

    func testWhitespace_returnsNeutral() {
        let result = detector.detect(message: "   \n  ")
        XCTAssertEqual(result.sentiment, .neutral)
    }

    func testNoKeywords_returnsNeutralWithLowConfidence() {
        let result = detector.detect(message: "hello there")
        XCTAssertEqual(result.sentiment, .neutral)
        XCTAssertEqual(result.confidence, 0.3, accuracy: 0.001)
    }

    // MARK: - Questions (Arabic)

    func testArabicQuestionMark() {
        let result = detector.detect(message: "شلون الحال\u{061F}")
        XCTAssertEqual(result.sentiment, .question)
        XCTAssertEqual(result.confidence, 0.85, accuracy: 0.001)
    }

    func testArabicQuestionKeyword_شلون() {
        let result = detector.detect(message: "شلون أتمرن")
        XCTAssertEqual(result.sentiment, .question)
    }

    func testArabicQuestionKeyword_ليش() {
        let result = detector.detect(message: "ليش ما أقدر أنام")
        XCTAssertEqual(result.sentiment, .question)
    }

    func testArabicQuestionKeyword_وين() {
        let result = detector.detect(message: "وين أروح أتمرن")
        XCTAssertEqual(result.sentiment, .question)
    }

    // MARK: - Questions (English)

    func testEnglishQuestionMark() {
        let result = detector.detect(message: "What should I eat?")
        XCTAssertEqual(result.sentiment, .question)
    }

    func testEnglishQuestionKeyword_how() {
        let result = detector.detect(message: "how do I improve my sleep")
        XCTAssertEqual(result.sentiment, .question)
    }

    func testEnglishQuestionKeyword_shouldI() {
        let result = detector.detect(message: "should I run today")
        XCTAssertEqual(result.sentiment, .question)
    }

    // MARK: - Question Priority Over Sentiment

    func testQuestionTakesPriority_overPositive() {
        // "how" triggers question before "great" triggers positive
        let result = detector.detect(message: "how was my great workout?")
        XCTAssertEqual(result.sentiment, .question)
    }

    // MARK: - Positive (Arabic)

    func testArabicPositive_الحمدلله() {
        let result = detector.detect(message: "الحمدلله تمرنت اليوم")
        XCTAssertEqual(result.sentiment, .positive)
        XCTAssertTrue(result.detectedKeywords.contains("الحمدلله"))
    }

    func testArabicPositive_خوش() {
        let result = detector.detect(message: "خوش تمرين كان")
        XCTAssertEqual(result.sentiment, .positive)
    }

    func testArabicPositive_ماشاءالله() {
        let result = detector.detect(message: "ماشاءالله نتائج حلوة")
        XCTAssertEqual(result.sentiment, .positive)
    }

    // MARK: - Positive (English)

    func testEnglishPositive() {
        let result = detector.detect(message: "feeling great and amazing today")
        XCTAssertEqual(result.sentiment, .positive)
        XCTAssertTrue(result.detectedKeywords.contains("great"))
        XCTAssertTrue(result.detectedKeywords.contains("amazing"))
    }

    // MARK: - Positive (Emoji)

    func testEmojiPositive() {
        let result = detector.detect(message: "let's go 💪🔥")
        XCTAssertEqual(result.sentiment, .positive)
    }

    // MARK: - Negative (Arabic)

    func testArabicNegative_تعبان() {
        let result = detector.detect(message: "اليوم تعبان مرة")
        XCTAssertEqual(result.sentiment, .negative)
        XCTAssertTrue(result.detectedKeywords.contains("تعبان"))
    }

    func testArabicNegative_ماأكدر() {
        let result = detector.detect(message: "ما اكدر أتمرن اليوم")
        XCTAssertEqual(result.sentiment, .negative)
    }

    func testArabicNegative_قلقان() {
        let result = detector.detect(message: "قلقان من الامتحان")
        XCTAssertEqual(result.sentiment, .negative)
    }

    // MARK: - Negative (English)

    func testEnglishNegative() {
        let result = detector.detect(message: "I am so tired and stressed out")
        XCTAssertEqual(result.sentiment, .negative)
        XCTAssertTrue(result.detectedKeywords.contains("tired"))
        XCTAssertTrue(result.detectedKeywords.contains("stressed"))
    }

    // MARK: - Negative (Emoji)

    func testEmojiNegative() {
        let result = detector.detect(message: "today was rough 😔😢")
        XCTAssertEqual(result.sentiment, .negative)
    }

    // MARK: - Mixed Sentiment

    func testMixed_positiveWins() {
        // 2 positive vs 1 negative
        let result = detector.detect(message: "I feel great and amazing but tired")
        XCTAssertEqual(result.sentiment, .positive)
    }

    func testMixed_negativeWins() {
        // 1 positive vs 2 negative
        let result = detector.detect(message: "I feel good but tired and stressed")
        XCTAssertEqual(result.sentiment, .negative)
    }

    func testMixed_equalCounts_neutral() {
        // 1 positive, 1 negative → neutral
        let result = detector.detect(message: "I feel great but tired")
        XCTAssertEqual(result.sentiment, .neutral)
    }

    // MARK: - Confidence

    func testConfidence_scalesWithMatches() {
        let oneMatch = detector.detect(message: "feeling great")
        let threeMatches = detector.detect(message: "great awesome amazing day")

        XCTAssertEqual(oneMatch.confidence, 0.6, accuracy: 0.001)   // 0.5 + 1*0.1
        XCTAssertEqual(threeMatches.confidence, 0.8, accuracy: 0.001) // 0.5 + 3*0.1
    }

    func testConfidence_capsAt09() {
        // 5+ keywords should cap at 0.9
        let result = detector.detect(message: "great good awesome amazing perfect nice love")
        XCTAssertEqual(result.confidence, 0.9, accuracy: 0.001)
    }

    // MARK: - Case Insensitivity

    func testCaseInsensitive() {
        let result = detector.detect(message: "GREAT DAY")
        XCTAssertEqual(result.sentiment, .positive)
    }
}
