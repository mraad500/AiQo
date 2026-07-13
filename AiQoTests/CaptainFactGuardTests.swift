import XCTest
@testable import AiQo

/// Locks in the health-number fact-guard: the Captain must never state a metric
/// that contradicts the real HealthKit snapshot, yet must not robotically
/// "correct" legitimate rounding or references to other days.
final class CaptainFactGuardTests: XCTestCase {

    private let guardEngine = CaptainFactGuard()

    // MARK: - Corrections (hallucinations caught)

    func testGrosslyWrongStepsAreCorrected_arabic() {
        let facts = CaptainFactGuard.Facts(steps: 4962)
        let result = guardEngine.corrected("عاشت ايدك! اليوم مشيت ١٢ ألف خطوة 🔥", facts: facts)

        XCTAssertTrue(result.didCorrect)
        XCTAssertTrue(result.message.contains("٤٩٦٢"), "should inject the real step count")
        XCTAssertFalse(result.message.contains("ألف"), "the invented '12 thousand' must be gone")
    }

    func testGrosslyWrongStepsAreCorrected_english() {
        let facts = CaptainFactGuard.Facts(steps: 5000)
        let result = guardEngine.corrected("Great job — you walked 12,000 steps today!", facts: facts)

        XCTAssertTrue(result.didCorrect)
        XCTAssertTrue(result.message.contains("5000 steps"))
        XCTAssertFalse(result.message.contains("12,000"))
    }

    func testWrongCaloriesCorrected() {
        let facts = CaptainFactGuard.Facts(activeCalories: 300)
        let result = guardEngine.corrected("حرقت ٩٠٠ سعرة اليوم", facts: facts)
        XCTAssertTrue(result.didCorrect)
        XCTAssertTrue(result.message.contains("٣٠٠"))
    }

    func testWrongHeartRateCorrected() {
        let facts = CaptainFactGuard.Facts(heartRate: 78)
        let result = guardEngine.corrected("نبضك هسه ١٢٠ نبضة", facts: facts)
        XCTAssertTrue(result.didCorrect)
        XCTAssertTrue(result.message.contains("٧٨"))
    }

    // MARK: - Tolerated (no false positives)

    func testRoundedValueIsLeftAlone() {
        let facts = CaptainFactGuard.Facts(steps: 4962)
        let result = guardEngine.corrected("تقريباً 5000 خطوة اليوم، حلو", facts: facts)
        XCTAssertFalse(result.didCorrect, "5000 for 4962 is rounding, not a hallucination")
        XCTAssertTrue(result.message.contains("5000"))
    }

    func testPastDayReferenceIsSkipped() {
        let facts = CaptainFactGuard.Facts(steps: 4962)
        let result = guardEngine.corrected("امبارح مشيت ٨٠٠٠ خطوة، اليوم نكمل", facts: facts)
        XCTAssertFalse(result.didCorrect, "yesterday's figure is out of scope for today's snapshot")
        XCTAssertTrue(result.message.contains("٨٠٠٠"))
    }

    func testUnknownMetricNeverRewrites() {
        let facts = CaptainFactGuard.Facts(steps: nil, activeCalories: 0, heartRate: nil)
        let result = guardEngine.corrected("اليوم مشيت ١٢ ألف خطوة", facts: facts)
        XCTAssertFalse(result.didCorrect, "no snapshot → never overwrite the number")
    }

    func testReplyWithoutNumbersUnchanged() {
        let facts = CaptainFactGuard.Facts(steps: 4962)
        let original = "هلا بالذيب، شلونك اليوم؟ جاهز نبدأ؟"
        let result = guardEngine.corrected(original, facts: facts)
        XCTAssertFalse(result.didCorrect)
        XCTAssertEqual(result.message, original)
    }

    func testNumberWithoutKnownUnitIsIgnored() {
        // "المستوى 12" — a level, not a guarded metric. Must not be touched.
        let facts = CaptainFactGuard.Facts(steps: 4962)
        let result = guardEngine.corrected("وصلت المستوى 12، عاشت ايدك", facts: facts)
        XCTAssertFalse(result.didCorrect)
        XCTAssertTrue(result.message.contains("12"))
    }
}
