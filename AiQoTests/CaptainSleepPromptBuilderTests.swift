import XCTest
@testable import AiQo

final class CaptainSleepPromptBuilderTests: XCTestCase {
    func testSleepAnalysisPromptDemandsEvidenceBasedReply() {
        let builder = PromptComposer()
        let request = HybridBrainRequest(
            conversation: [
                CaptainConversationMessage(role: .user, content: "حلل نومي")
            ],
            screenContext: .sleepAnalysis,
            language: .arabic,
            contextData: CaptainContextData(
                steps: 4200,
                calories: 310,
                vibe: "calm",
                level: 7
            ),
            userProfileSummary: "",
            intentSummary: "",
            workingMemorySummary: "",
            attachedImageData: nil
        )

        let prompt = builder.build(for: request)

        XCTAssertTrue(prompt.contains("هذا وضع تحليل نوم صارم"))
        XCTAssertTrue(prompt.contains("الرد العام مثل"))
        XCTAssertTrue(prompt.contains("quickReplies لازم تكون null"))
        XCTAssertTrue(prompt.contains("نسبة النوم العميق"))
        XCTAssertTrue(prompt.contains("جودة مراحل النوم"))
    }
}
