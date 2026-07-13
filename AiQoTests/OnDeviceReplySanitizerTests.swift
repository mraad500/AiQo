import XCTest
@testable import AiQo

/// Locks in the on-device reply sanitizer — the deterministic safety net that
/// turns a derailed small-model generation (role labels + repetition loops) back
/// into clean Captain text. Reproduces the exact failure seen live (the Captain
/// echoing "Captain:" / "User:" and looping "هههه…").
final class OnDeviceReplySanitizerTests: XCTestCase {

    private let sanitizer = OnDeviceReplySanitizer()

    // MARK: - The live bug

    func testScreenshotGarbageBecomesCleanGreeting() {
        // What the model actually produced: a good greeting, then it derailed
        // into a fake transcript + a runaway "ه" loop.
        let garbage = "مرحبا يا محمد رعد، شخبيك\nCaptain: اليوم بالخطوات؟\n\nUser:\n"
            + String(repeating: "ه", count: 220)

        let cleaned = sanitizer.clean(garbage)

        XCTAssertTrue(cleaned.contains("مرحبا يا محمد رعد"), "the real greeting must survive")
        XCTAssertTrue(cleaned.contains("اليوم بالخطوات؟"), "Captain's own words after the label are kept")
        XCTAssertFalse(cleaned.contains("Captain:"), "the self-label must be stripped")
        XCTAssertFalse(cleaned.contains("User:"), "the fake user turn must be cut")
        XCTAssertFalse(cleaned.contains(String(repeating: "ه", count: 6)), "the loop must be collapsed")
    }

    // MARK: - Label handling

    func testFakeUserTurnAndEverythingAfterIsDropped() {
        let input = "زين هذا هدفك.\nUser: شنو اكلت؟\nCaptain: اكلت زين"
        let cleaned = sanitizer.clean(input)

        XCTAssertTrue(cleaned.hasPrefix("زين هذا هدفك"))
        XCTAssertFalse(cleaned.contains("User:"))
        XCTAssertFalse(cleaned.contains("اكلت زين"), "nothing after the fake user turn survives")
    }

    func testArabicRoleLabelsAreStripped() {
        let input = "كابتن: هلا بيك يا بطل، شلونك؟"
        let cleaned = sanitizer.clean(input)

        XCTAssertFalse(cleaned.contains("كابتن:"))
        XCTAssertTrue(cleaned.contains("هلا بيك يا بطل"))
    }

    // MARK: - Repetition

    func testRunawayCharacterLoopIsCollapsed() {
        let input = "ممتاز" + String(repeating: "ه", count: 80)
        let cleaned = sanitizer.clean(input)

        XCTAssertTrue(cleaned.contains("ممتاز"))
        XCTAssertFalse(cleaned.contains(String(repeating: "ه", count: 6)))
    }

    func testRepeatedWordLoopIsCollapsed() {
        let input = "ما واصلني ما واصلني ما واصلني ما واصلني خطوة"
        let cleaned = sanitizer.clean(input)

        XCTAssertEqual(cleaned, "ما واصلني خطوة")
    }

    // MARK: - Clean text is left alone

    func testCleanReplyIsUnchanged() {
        let good = "هلا يا بطل، شلونك هسه؟ نمشي Zone 2 لو نسوي Ego-Reset؟"
        XCTAssertEqual(sanitizer.clean(good), good)
    }

    func testShortLaughterSurvives() {
        // 4 repeats is human laughter, not a degenerate loop — keep it.
        let input = "هههه عاشت ايدك"
        let cleaned = sanitizer.clean(input)
        XCTAssertTrue(cleaned.contains("هههه"))
        XCTAssertTrue(cleaned.contains("عاشت ايدك"))
    }
}
