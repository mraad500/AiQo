import XCTest
@testable import AiQo

/// Health vitals are now forwarded to the cloud **exactly** — the Captain must
/// report the user's real numbers (matching the app dashboard), never rounded.
/// These tests lock in that exact pass-through while proving the PII-redaction
/// pipeline still runs unchanged alongside the untouched numbers.
final class PrivacySanitizerTests: XCTestCase {

    private let sanitizer = PrivacySanitizer()

    // MARK: - Heart Rate (exact)

    func testHeartRate_PreservedExactly_English() {
        let out = sanitizer.sanitizePromptForCloud("My heart rate was 187 bpm during peak", knownUserName: nil)
        XCTAssertTrue(out.contains("187 bpm"))
    }

    func testHeartRate_PreservedExactly_ArabicUnit() {
        let out = sanitizer.sanitizePromptForCloud("نبضي كان 187 نبضة", knownUserName: nil)
        XCTAssertTrue(out.contains("187"))
    }

    func testHeartRate_ArabicIndicDigits_PreservedVerbatim() {
        // Arabic-Indic digits are no longer normalized or bucketed — kept as typed.
        let out = sanitizer.sanitizePromptForCloud("نبضي ١٨٧ نبضة", knownUserName: nil)
        XCTAssertTrue(out.contains("١٨٧"))
    }

    func testHeartRate_ExtendedArabicIndicDigits_PreservedVerbatim() {
        let out = sanitizer.sanitizePromptForCloud("HR ۱۴۲ bpm", knownUserName: nil)
        XCTAssertTrue(out.contains("۱۴۲"))
    }

    // MARK: - Steps (exact)

    func testSteps_PreservedExactly() {
        let out = sanitizer.sanitizePromptForCloud("I walked 7823 steps today", knownUserName: nil)
        XCTAssertTrue(out.contains("7823 steps"))
    }

    func testSteps_PreservedExactly_Arabic() {
        let out = sanitizer.sanitizePromptForCloud("مشيت 8453 خطوة", knownUserName: nil)
        XCTAssertTrue(out.contains("8453"))
    }

    func testSteps_NoRounding_OddValue() {
        // The exact value must survive — previously 7999 floor-bucketed to 7500.
        let out = sanitizer.sanitizePromptForCloud("hit 7999 steps", knownUserName: nil)
        XCTAssertTrue(out.contains("7999 steps"))
    }

    // MARK: - Distance (exact)

    func testDistance_PreservedExactly() {
        let out = sanitizer.sanitizePromptForCloud("ran 5.27 km", knownUserName: nil)
        XCTAssertTrue(out.contains("5.27 km"))
    }

    // MARK: - Calories (exact)

    func testCalories_PreservedExactly() {
        let out = sanitizer.sanitizePromptForCloud("burned 487 kcal", knownUserName: nil)
        XCTAssertTrue(out.contains("487 kcal"))
    }

    func testCalories_PreservedExactly_ShortUnit() {
        let out = sanitizer.sanitizePromptForCloud("burned 487 cal", knownUserName: nil)
        XCTAssertTrue(out.contains("487 cal"))
    }

    // MARK: - Duration (exact)

    func testDuration_PreservedExactly() {
        let out = sanitizer.sanitizePromptForCloud("worked out for 47 minutes", knownUserName: nil)
        XCTAssertTrue(out.contains("47 minutes"))
    }

    func testDuration_PreservedExactly_ShortForm() {
        let out = sanitizer.sanitizePromptForCloud("rested 12 min", knownUserName: nil)
        XCTAssertTrue(out.contains("12 min"))
    }

    // MARK: - Sleep (exact)

    func testSleep_PreservedExactly() {
        let out = sanitizer.sanitizePromptForCloud("slept 6.3 hours", knownUserName: nil)
        XCTAssertTrue(out.contains("6.3 hours"))
    }

    func testSleep_PreservedExactly_ShortUnit() {
        let out = sanitizer.sanitizePromptForCloud("slept 7.2 hrs", knownUserName: nil)
        XCTAssertTrue(out.contains("7.2 hrs"))
    }

    // MARK: - Zone % (exact)

    func testZonePercent_PreservedExactly() {
        let out = sanitizer.sanitizePromptForCloud("workout: 47% peak and 23% below", knownUserName: nil)
        XCTAssertTrue(out.contains("47% peak"))
        XCTAssertTrue(out.contains("23% below"))
    }

    // MARK: - Multi-vital Composition (all exact, PII still redacted)

    func testMultipleVitals_AllPreservedExactly() {
        let input = "Today: 8453 steps, 6.2 hours sleep, 142 bpm max, burned 623 kcal over 47 minutes"
        let out = sanitizer.sanitizePromptForCloud(input, knownUserName: nil)
        XCTAssertTrue(out.contains("8453 steps"))
        XCTAssertTrue(out.contains("6.2 hours"))
        XCTAssertTrue(out.contains("142 bpm"))
        XCTAssertTrue(out.contains("623 kcal"))
        XCTAssertTrue(out.contains("47 minutes"))
    }

    func testVitalsPreserved_WhilePIIStillRedacted() {
        // The exact numbers survive, but an email in the same sentence is gone.
        let out = sanitizer.sanitizePromptForCloud(
            "I walked 9614 steps — email me at coach@example.com",
            knownUserName: nil
        )
        XCTAssertTrue(out.contains("9614 steps"), "exact vitals must be preserved")
        XCTAssertFalse(out.contains("coach@example.com"), "PII must still be redacted")
    }

    // MARK: - PII Redaction (unchanged)

    func testPIIRedaction_Email() {
        let out = sanitizer.sanitizePromptForCloud("Contact me at john@example.com please", knownUserName: nil)
        XCTAssertFalse(out.contains("john@example.com"))
    }

    func testPIIRedaction_Phone() {
        let out = sanitizer.sanitizePromptForCloud("Call +971501234567 tomorrow", knownUserName: nil)
        XCTAssertFalse(out.contains("501234567"))
    }

    func testKnownUserName_PreservedInText_WhileEmailRedacted() {
        // The user's first name is intentionally NOT redacted from conversation
        // text: it is carried to the cloud via `CloudSafeProfile` under the
        // cloud-AI consent gate, and stripping it here would contradict the
        // system prompt's "Preferred name" line (Apple v1.1 rejection fix).
        // PII like an email in the same sentence is still redacted.
        let out = sanitizer.sanitizePromptForCloud(
            "Hey Mohammed, email me at coach@example.com",
            knownUserName: "Mohammed"
        )
        XCTAssertTrue(out.contains("Mohammed"), "first name is preserved for natural addressing")
        XCTAssertFalse(out.contains("coach@example.com"), "email PII is still redacted")
    }

    // MARK: - False-Positive Guards

    func testEmptyInput() {
        XCTAssertEqual(sanitizer.sanitizePromptForCloud("", knownUserName: nil), "")
    }

    func testNonVitalNumbersUnchanged() {
        let out = sanitizer.sanitizePromptForCloud("I work in building 7 on floor 3", knownUserName: nil)
        XCTAssertTrue(out.contains("building 7"))
        XCTAssertTrue(out.contains("floor 3"))
    }

    func testPlainGreetingUnchanged() {
        let input = "Good morning captain"
        let out = sanitizer.sanitizePromptForCloud(input, knownUserName: nil)
        XCTAssertEqual(out, input)
    }

    // MARK: - Structured Context (exact, via sanitizeForCloud)

    func testSanitizeForCloud_ForwardsExactStructuredVitals() {
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
        // Vitals forwarded exactly — no bucketing.
        XCTAssertEqual(out.contextData.steps, 8453)
        XCTAssertEqual(out.contextData.calories, 623)
        XCTAssertEqual(out.contextData.heartRate, 147)
        XCTAssertEqual(out.contextData.sleepHours, 6.3, accuracy: 0.001)
        // Non-vital privacy transforms still apply.
        XCTAssertEqual(out.contextData.vibe, "General")
        XCTAssertEqual(out.contextData.timeOfDay, "evening")
        XCTAssertEqual(out.contextData.stageTitle, "stage-5")
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
