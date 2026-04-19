import XCTest
@testable import AiQo

final class EmotionalEngineAPITests: XCTestCase {

    func testReadingWithoutMessageStillReturns() async {
        let reading = await EmotionalEngine.shared.currentReading(message: nil)
        XCTAssertGreaterThanOrEqual(reading.confidence, 0)
    }

    func testNegativeMessageShiftsPrimary() async {
        let reading = await EmotionalEngine.shared.currentReading(
            message: "I'm so tired and exhausted, nothing is working"
        )
        XCTAssertGreaterThan(reading.intensity, 0.3)
    }

    func testPositiveMessageRaisesIntensity() async {
        let reading = await EmotionalEngine.shared.currentReading(
            message: "Amazing workout today, I feel great and happy!"
        )
        XCTAssertGreaterThan(reading.intensity, 0.3)
    }

    func testReadingWithSignals() async {
        let reading = await EmotionalEngine.shared.currentReading(message: "hello")
        XCTAssertGreaterThanOrEqual(reading.signals.count, 1)
    }

    func testReadingIntensityClamped() async {
        let reading = await EmotionalEngine.shared.currentReading(message: "ok")
        XCTAssertLessThanOrEqual(reading.intensity, 1.0)
        XCTAssertGreaterThanOrEqual(reading.intensity, 0.0)
    }
}
