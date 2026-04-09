import XCTest
@testable import AiQo

final class AppleIntelligenceSleepAgentTests: XCTestCase {
    func testArabicSummaryIncludesStagePercentages() {
        let agent = AppleIntelligenceSleepAgent()
        let session = SleepSession(
            totalSleep: 6 * 60 * 60,
            deepSleep: 72 * 60,
            remSleep: 84 * 60,
            coreSleep: 204 * 60,
            awake: 18 * 60
        )

        let summary = agent.buildArabicSummary(for: session)

        XCTAssertTrue(summary.contains("نوم عميق"))
        XCTAssertTrue(summary.contains("نوم أساسي"))
        XCTAssertTrue(summary.contains("REM"))
        XCTAssertTrue(summary.contains("20.0%"))
        XCTAssertTrue(summary.contains("56.7%"))
        XCTAssertTrue(summary.contains("23.3%"))
    }

    func testArabicAvailabilityFallbackEndsWithStageQualityAdvice() {
        let agent = AppleIntelligenceSleepAgent()
        let session = SleepSession(
            totalSleep: 5 * 60 * 60 + 30 * 60,
            deepSleep: 36 * 60,
            remSleep: 54 * 60,
            coreSleep: 240 * 60,
            awake: 24 * 60
        )

        let fallback = agent.availabilityFallback(
            for: session,
            reasonDescription: "test",
            language: .arabic
        )

        XCTAssertTrue(fallback.contains("العميق عندك"))
        XCTAssertTrue(fallback.contains("REM عندك"))
        XCTAssertTrue(fallback.contains("جودة المراحل"))
    }
}
