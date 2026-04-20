import XCTest
@testable import AiQo

final class IntentClassifierTests: XCTestCase {

    func testCrisisPhraseEnglishFiresImmediately() {
        let result = IntentClassifier.classify("I want to kill myself")
        XCTAssertEqual(result.primary, .crisis)
        XCTAssertGreaterThan(result.confidence, 0.9)
    }

    func testCrisisPhraseArabicFires() {
        let result = IntentClassifier.classify("ما أبي أعيش بعد")
        XCTAssertEqual(result.primary, .crisis)
    }

    func testQuestionWithMark() {
        let result = IntentClassifier.classify("are you ready today?")
        XCTAssertEqual(result.primary, .question)
    }

    func testQuestionArabicMark() {
        let result = IntentClassifier.classify("ok now what؟")
        XCTAssertEqual(result.primary, .question)
    }

    func testQuestionStartsWithWhat() {
        let result = IntentClassifier.classify("what should I eat")
        XCTAssertEqual(result.primary, .question)
    }

    func testGreetingDetection() {
        let result = IntentClassifier.classify("Hi there")
        XCTAssertEqual(result.primary, .greeting)
    }

    func testGoalDetection() {
        let result = IntentClassifier.classify("i want to lose 10 kilos")
        XCTAssertEqual(result.primary, .goal)
    }

    func testVentingDetection() {
        let result = IntentClassifier.classify("i'm so exhausted and nothing is working")
        XCTAssertEqual(result.primary, .venting)
        XCTAssertTrue(result.flags.contains("venting_language"))
    }

    func testSocialReferenceWithFamily() {
        let result = IntentClassifier.classify("my mom is sick")
        XCTAssertEqual(result.primary, .social)
        XCTAssertTrue(result.flags.contains("family_reference"))
    }

    func testRequestDetection() {
        let result = IntentClassifier.classify("give me a workout plan")
        XCTAssertEqual(result.primary, .request)
    }

    func testUnknownReturnsLowConfidence() {
        let result = IntentClassifier.classify("asdf qwerty zxcv")
        XCTAssertEqual(result.primary, .unknown)
        XCTAssertLessThan(result.confidence, 0.5)
    }

    func testCrisisBeatsQuestion() {
        let result = IntentClassifier.classify("why would I kill myself?")
        XCTAssertEqual(result.primary, .crisis)
    }
}

final class ContextualPredictorTests: XCTestCase {

    func testPredictionReturnsValidNeed() async {
        let prediction = await ContextualPredictor.shared.predict()
        XCTAssertGreaterThanOrEqual(prediction.confidence, 0)
        XCTAssertLessThanOrEqual(prediction.confidence, 1)
    }
}
