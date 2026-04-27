import XCTest
@testable import AiQo

/// Covers the text-bucketing layer added in P0.3.
/// Semantics: integer buckets floor, float buckets round-half-to-nearest.
/// PII redaction is exercised inline to ensure vitals + PII pipelines compose correctly.
final class PrivacySanitizerTests: XCTestCase {

    private let sanitizer = PrivacySanitizer()

    // MARK: - Heart Rate

    func testHeartRateBucketing_English() {
        let out = sanitizer.sanitizePromptForCloud("My heart rate was 187 bpm during peak", knownUserName: nil)
        XCTAssertTrue(out.contains("185 bpm"))
        XCTAssertFalse(out.contains("187 bpm"))
    }

    func testHeartRateBucketing_ArabicUnit() {
        let out = sanitizer.sanitizePromptForCloud("نبضي كان 187 نبضة", knownUserName: nil)
        XCTAssertTrue(out.contains("185"))
        XCTAssertFalse(out.contains("187"))
    }

    func testHeartRateBucketing_ArabicIndicDigits() {
        let out = sanitizer.sanitizePromptForCloud("نبضي ١٨٧ نبضة", knownUserName: nil)
        XCTAssertFalse(out.contains("١٨٧"))
        XCTAssertTrue(out.contains("185"))
    }

    func testHeartRateBucketing_ExtendedArabicIndicDigits() {
        // Persian/Urdu digit range ۰-۹ should also normalize.
        let out = sanitizer.sanitizePromptForCloud("HR ۱۴۲ bpm", knownUserName: nil)
        XCTAssertTrue(out.contains("140 bpm"))
    }

    // MARK: - Steps

    func testStepsBucketing() {
        let out = sanitizer.sanitizePromptForCloud("I walked 7823 steps today", knownUserName: nil)
        XCTAssertTrue(out.contains("7500 steps"))
    }

    func testStepsBucketing_Arabic() {
        let out = sanitizer.sanitizePromptForCloud("مشيت 8453 خطوة", knownUserName: nil)
        XCTAssertTrue(out.contains("8000"))
    }

    func testStepsBucketing_FloorDirection() {
        // 7999/500 = 15.998, floor = 15, *500 = 7500 — floor must not round up.
        let out = sanitizer.sanitizePromptForCloud("hit 7999 steps", knownUserName: nil)
        XCTAssertTrue(out.contains("7500 steps"))
    }

    // MARK: - Distance

    func testDistanceBucketing_Round() {
        // 5.27/0.1 = 52.7, round → 53, *0.1 → 5.3
        let out = sanitizer.sanitizePromptForCloud("ran 5.27 km", knownUserName: nil)
        XCTAssertTrue(out.contains("5.3 km"))
    }

    func testDistanceBucketing_Arabic() {
        let out = sanitizer.sanitizePromptForCloud("ركضت 5.3 كيلو", knownUserName: nil)
        XCTAssertTrue(out.contains("5.3"))
    }

    // MARK: - Calories

    func testCaloriesBucketing() {
        let out = sanitizer.sanitizePromptForCloud("burned 487 kcal", knownUserName: nil)
        XCTAssertTrue(out.contains("480 kcal"))
    }

    func testCaloriesBucketing_ShortUnit() {
        let out = sanitizer.sanitizePromptForCloud("burned 487 cal", knownUserName: nil)
        XCTAssertTrue(out.contains("480 cal"))
    }

    // MARK: - Duration

    func testDurationBucketing() {
        let out = sanitizer.sanitizePromptForCloud("worked out for 47 minutes", knownUserName: nil)
        XCTAssertTrue(out.contains("45 minutes"))
    }

    func testDurationBucketing_ShortForm() {
        let out = sanitizer.sanitizePromptForCloud("rested 12 min", knownUserName: nil)
        XCTAssertTrue(out.contains("10 min"))
    }

    func testDurationBucketing_NoFalsePositiveOnMints() {
        // "mints" must not match "min" — prior regex lacked word boundary.
        let out = sanitizer.sanitizePromptForCloud("I ate 3 mints", knownUserName: nil)
        XCTAssertTrue(out.contains("3 mints"))
    }

    // MARK: - Sleep

    func testSleepBucketing_RoundUp() {
        // 6.3/0.5 = 12.6, round → 13, *0.5 → 6.5
        let out = sanitizer.sanitizePromptForCloud("slept 6.3 hours", knownUserName: nil)
        XCTAssertTrue(out.contains("6.5 hours"))
    }

    func testSleepBucketing_RoundDown() {
        // 6.2/0.5 = 12.4, round → 12, *0.5 → 6.0
        let out = sanitizer.sanitizePromptForCloud("slept 6.2 hours", knownUserName: nil)
        XCTAssertTrue(out.contains("6.0 hours"))
    }

    func testSleepBucketing_ShortUnit() {
        let out = sanitizer.sanitizePromptForCloud("slept 7.2 hrs", knownUserName: nil)
        XCTAssertTrue(out.contains("7.0 hrs"))
    }

    // MARK: - Zone %

    func testZonePercentBucketing() {
        let out = sanitizer.sanitizePromptForCloud("workout: 47% peak and 23% below", knownUserName: nil)
        XCTAssertTrue(out.contains("45% peak"))
        XCTAssertTrue(out.contains("20% below"))
    }

    // MARK: - Multi-vital Composition

    func testMultipleVitalsInOnePrompt() {
        let input = "Today: 8453 steps, 6.2 hours sleep, 142 bpm max, burned 623 kcal over 47 minutes"
        let out = sanitizer.sanitizePromptForCloud(input, knownUserName: nil)
        XCTAssertTrue(out.contains("8000 steps"))
        XCTAssertTrue(out.contains("6.0 hours"))
        XCTAssertTrue(out.contains("140 bpm"))
        XCTAssertTrue(out.contains("620 kcal"))
        XCTAssertTrue(out.contains("45 minutes"))
    }

    // MARK: - PII Redaction

    func testPIIRedaction_Email() {
        let out = sanitizer.sanitizePromptForCloud("Contact me at john@example.com please", knownUserName: nil)
        XCTAssertFalse(out.contains("john@example.com"))
    }

    func testPIIRedaction_Phone() {
        let out = sanitizer.sanitizePromptForCloud("Call +971501234567 tomorrow", knownUserName: nil)
        XCTAssertFalse(out.contains("501234567"))
    }

    func testKnownUserNameRedaction() {
        let out = sanitizer.sanitizePromptForCloud("Hey Mohammed, how are you?", knownUserName: "Mohammed")
        XCTAssertFalse(out.contains("Mohammed"))
        XCTAssertTrue(out.contains("User"))
    }

    // MARK: - False-Positive Guards

    func testEmptyInput() {
        XCTAssertEqual(sanitizer.sanitizePromptForCloud("", knownUserName: nil), "")
    }

    func testNonVitalNumbersUnchanged() {
        // No units → no bucketing. "age" keyword IS in the profile-field list, so input avoids it.
        let out = sanitizer.sanitizePromptForCloud("I work in building 7 on floor 3", knownUserName: nil)
        XCTAssertTrue(out.contains("building 7"))
        XCTAssertTrue(out.contains("floor 3"))
    }

    func testPlainGreetingUnchanged() {
        let input = "Good morning captain"
        let out = sanitizer.sanitizePromptForCloud(input, knownUserName: nil)
        XCTAssertEqual(out, input)
    }

    // MARK: - Structured Context Bucketing (via sanitizeForCloud)

    func testSanitizeForCloud_BucketsStructuredHeartRateAndSleep() {
        let ctx = CaptainContextData(
            steps: 8453,
            calories: 623,
            vibe: "anxious-spiral-after-breakup",
            level: 7,
            sleepHours: 6.3,
            heartRate: 147,
            timeOfDay: "evening",
            toneHint: "recovery",
            stageTitle: "stage-5",
            bioPhase: .recovery
        )
        let req = HybridBrainRequest(
            conversation: [CaptainConversationMessage(role: .user, content: "hi")],
            screenContext: .mainChat,
            language: .english,
            contextData: ctx,
            userProfileSummary: "",
            intentSummary: "",
            workingMemorySummary: "",
            attachedImageData: nil
        )
        let out = sanitizer.sanitizeForCloud(req, knownUserName: nil)
        XCTAssertEqual(out.contextData.heartRate, 145)
        XCTAssertEqual(out.contextData.sleepHours, 6.5, accuracy: 0.001)
        XCTAssertEqual(out.contextData.vibe, "General")
        XCTAssertEqual(out.contextData.timeOfDay, "evening")
        XCTAssertEqual(out.contextData.stageTitle, "stage-5")
        XCTAssertEqual(out.contextData.steps, 8000)  // floor-bucketed at 500
    }

    func testSanitizeForCloud_DropsEmotionalAndTrendSignals() {
        var ctx = CaptainContextData(steps: 0, calories: 0, vibe: "x", level: 1)
        ctx.recentInteractions = "User mentioned divorce, job loss"
        let req = HybridBrainRequest(
            conversation: [CaptainConversationMessage(role: .user, content: "hi")],
            screenContext: .mainChat,
            language: .english,
            contextData: ctx,
            userProfileSummary: "",
            intentSummary: "",
            workingMemorySummary: "",
            attachedImageData: nil
        )
        let out = sanitizer.sanitizeForCloud(req, knownUserName: nil)
        XCTAssertNil(out.contextData.emotionalState)
        XCTAssertNil(out.contextData.trendSnapshot)
        XCTAssertNil(out.contextData.messageSentiment)
        XCTAssertNil(out.contextData.recentInteractions)
    }

    // MARK: - Conversation Sanitization (length + char budget)

    /// Two-stage cap: at most 16 messages OR ~6000 chars (whichever hits first),
    /// then per-message PII redaction. Order preserved chronologically.
    func testSanitizeConversation_keepsLast16OrCharBudget() {
        // 30 messages each ~500 chars. 30 × 500 = 15,000 chars total.
        // The char budget (6000) hits first → expect ~12 messages kept.
        var conversation: [CaptainConversationMessage] = []
        for i in 0..<30 {
            let role: CaptainConversationRole = (i % 2 == 0) ? .user : .assistant
            // Pad to ~500 chars — lorem-ish content with the index so we can
            // assert the *newest* turns survive trimming.
            let body = String(repeating: "Lorem ipsum dolor sit amet, ", count: 18)
            let content = "msg-\(i) \(body)"
            conversation.append(CaptainConversationMessage(role: role, content: content))
        }

        // Inject a known PII fragment into the newest user turn so we can
        // assert per-message redaction still runs.
        conversation[29] = CaptainConversationMessage(
            role: .user,
            content: "msg-29 contact me at user@example.com please " + String(repeating: "x", count: 400)
        )

        let req = HybridBrainRequest(
            conversation: conversation,
            screenContext: .mainChat,
            language: .english,
            contextData: CaptainContextData(steps: 0, calories: 0, vibe: "x", level: 1),
            userProfileSummary: "",
            intentSummary: "",
            workingMemorySummary: "",
            attachedImageData: nil
        )

        let out = sanitizer.sanitizeForCloud(req, knownUserName: nil)
        let kept = out.conversation

        // Bounded by message count cap.
        XCTAssertLessThanOrEqual(kept.count, 16, "should never exceed maxConversationMessages=16")
        // Bounded by char budget (allow up to one over-budget message from the always-keep-last-2 rule).
        let totalChars = kept.reduce(0) { $0 + $1.content.utf8.count }
        XCTAssertLessThanOrEqual(totalChars, 6000 + 1500, "should respect ~6000 char budget within a small overshoot")
        // Always retains at least the last 2 messages.
        XCTAssertGreaterThanOrEqual(kept.count, 2)

        // Chronological order preserved: every kept message must be a strict
        // suffix of the input, in the original order.
        let lastN = Array(conversation.suffix(kept.count))
        for index in kept.indices {
            // Roles must match position-for-position with the input suffix.
            XCTAssertEqual(kept[index].role, lastN[index].role,
                           "kept[\(index)].role lost chronological alignment")
        }
        // Newest turn (msg-29) must be present — proves we keep from the end.
        XCTAssertTrue(kept.last?.content.contains("msg-29") ?? false,
                      "newest turn must survive trimming")

        // PII redaction still runs on the kept messages.
        let combined = kept.map(\.content).joined(separator: "\n")
        XCTAssertFalse(combined.contains("user@example.com"),
                       "email PII should be redacted by per-message pipeline")
    }
}
