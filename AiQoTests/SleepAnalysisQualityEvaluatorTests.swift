import XCTest
@testable import AiQo

final class SleepAnalysisQualityEvaluatorTests: XCTestCase {
    private let evaluator = SleepAnalysisQualityEvaluator()

    func testRejectsShortSleepReplyWithoutActionableGuidance() {
        let session = SleepSession(
            totalSleep: 5 * 60 * 60,
            deepSleep: 40 * 60,
            remSleep: 50 * 60,
            coreSleep: 210 * 60,
            awake: 18 * 60
        )

        let message = "تقريباً 5 ساعات نوم مو خوش."

        XCTAssertFalse(evaluator.isUseful(message: message, session: session))
    }

    func testAcceptsSpecificSleepReplyWithVerdictImpactAndAction() {
        let session = SleepSession(
            totalSleep: 5 * 60 * 60 + 53 * 60,
            deepSleep: 44 * 60,
            remSleep: 51 * 60,
            coreSleep: 238 * 60,
            awake: 21 * 60
        )

        let message = """
        نومك اليوم 5 ساعات و53 دقيقة، وهذا أقل من المطلوب فتعافيك مو كامل.
        النوم العميق عندك 44 دقيقة، فممكن تحس إن طاقتك وتركيزك أضعف اليوم.
        الليلة حاول تنام أبچر بنص ساعة ووقف الكافيين بعد الظهر.
        """

        XCTAssertTrue(evaluator.isUseful(message: message, session: session))
    }
}
