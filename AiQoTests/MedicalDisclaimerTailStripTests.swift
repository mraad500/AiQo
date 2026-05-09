import XCTest
@testable import AiQo

/// Regression coverage for the Apple v1.1 rejection fix (submission 49728905,
/// Guideline 1.4.1). `stripInlineMedicalDisclaimerTail` is the client-side
/// backstop that removes any lingering "⚕️ This is educational info — consult
/// your doctor" / "استشر طبيبك" trailer from cached or remote-config prompts
/// before the bubble renders. The persistent `CaptainSafetyBanner` above the
/// chat carries the medical framing; trailing sentences inside bubbles are
/// redundant and were flagged by App Review.
final class MedicalDisclaimerTailStripTests: XCTestCase {

    // MARK: - Arabic trailer removal

    func test_stripTail_removesArabicDisclaimerTrailer() {
        let input = """
        تمام، ممكن نبدي بخمس دقائق مشي كل يوم.
        ⚕️ هذي معلومات تثقيفية — استشر طبيبك قبل البدء.
        """
        let out = CaptainViewModel.stripInlineMedicalDisclaimerTail(input)
        XCTAssertEqual(out, "تمام، ممكن نبدي بخمس دقائق مشي كل يوم.")
        XCTAssertFalse(out.contains("⚕️"))
        XCTAssertFalse(out.contains("هذي معلومات تثقيفية"))
        XCTAssertFalse(out.contains("استشر طبيب"))
    }

    // MARK: - English trailer removal

    func test_stripTail_removesEnglishDisclaimerTrailer() {
        let input = """
        Got it. Start with a 10-minute walk today.
        ⚕️ This is educational info — consult your doctor before starting.
        """
        let out = CaptainViewModel.stripInlineMedicalDisclaimerTail(input)
        XCTAssertEqual(out, "Got it. Start with a 10-minute walk today.")
        XCTAssertFalse(out.contains("⚕️"))
        XCTAssertFalse(out.contains("educational info"))
        XCTAssertFalse(out.lowercased().contains("consult your doctor"))
    }

    // MARK: - Preservation

    /// A reply that has no trailer must pass through unchanged except for
    /// trailing whitespace (the function trims).
    func test_stripTail_preservesLegitContent() {
        let input = "Let's schedule the walk for 6pm — evening light feels good."
        let out = CaptainViewModel.stripInlineMedicalDisclaimerTail(input)
        XCTAssertEqual(out, input)
    }

    // MARK: - Multiple trailers

    /// A cached prompt could stack both the Arabic and English trailer, or
    /// repeat the same trailer twice. All instances must be stripped.
    func test_stripTail_handlesMultipleTrailers() {
        let input = """
        المشي المنتظم ممتاز للضغط.
        ⚕️ هذي معلومات تثقيفية — استشر طبيبك.
        ⚕️ Consult your doctor before starting.
        """
        let out = CaptainViewModel.stripInlineMedicalDisclaimerTail(input)
        XCTAssertEqual(out, "المشي المنتظم ممتاز للضغط.")
        XCTAssertFalse(out.contains("⚕️"))
        XCTAssertFalse(out.contains("طبيب"))
        XCTAssertFalse(out.lowercased().contains("consult"))
    }

    // MARK: - Emoji inside message is preserved

    /// The ⚕️ sigil only anchors the trailer pattern — emoji used elsewhere
    /// in the message (celebration, tone, etc.) must survive. This verifies
    /// the regex is anchored to the disclaimer wording, not to the emoji in
    /// isolation.
    func test_stripTail_preservesEmojiInsideMessage() {
        let input = "Nice streak 🎉 — three days in a row, keep going."
        let out = CaptainViewModel.stripInlineMedicalDisclaimerTail(input)
        XCTAssertEqual(out, input)
        XCTAssertTrue(out.contains("🎉"))
    }
}
