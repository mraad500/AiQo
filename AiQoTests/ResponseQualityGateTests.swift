// ===============================================
// File: ResponseQualityGateTests.swift
// Brain Refactor §41 — coverage for the post-generation quality gate.
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class ResponseQualityGateTests: XCTestCase {

    private var gate: ResponseQualityGate { ResponseQualityGate() }

    // MARK: - Helpers

    private func makeRequest(
        language: AppLanguage = .arabic,
        steps: Int = 5_000,
        recentActivity: RecentActivitySnapshot? = nil,
        coherence: ConversationContextTags? = nil,
        reasoningBrief: ReasoningBrief? = nil
    ) -> HybridBrainRequest {
        var contextData = CaptainContextData(
            steps: steps,
            calories: 200,
            vibe: "Energy",
            level: 5,
            sleepHours: 7.0,
            heartRate: 65,
            timeOfDay: "afternoon",
            toneHint: "focused and supportive",
            stageTitle: "Comfort Zone Break",
            bioPhase: .energy
        )
        contextData.recentActivity = recentActivity
        contextData.coherenceTags = coherence
        contextData.reasoningBrief = reasoningBrief

        return HybridBrainRequest(
            conversation: [],
            screenContext: .mainChat,
            language: language,
            contextData: contextData,
            userProfileSummary: "Age: 30",
            intentSummary: "general_coaching",
            workingMemorySummary: "",
            attachedImageData: nil
        )
    }

    private func makeWalkSnapshot(minutesSinceEnd: Int) -> RecentActivitySnapshot {
        RecentActivitySnapshot(
            title: "مشي",
            family: .walking,
            durationMinutes: 45,
            activeCalories: 261,
            distanceKm: 3.11,
            endedAt: Date().addingTimeInterval(Double(-minutesSinceEnd * 60)),
            minutesSinceEnd: minutesSinceEnd
        )
    }

    private func makeWalkAvoidCoherence() -> ConversationContextTags {
        ConversationContextTags(
            completedClaims: [
                CompletedActivityClaim(family: .walking, userQuote: "مشيت 45 دقيقة")
            ],
            refusals: [],
            latestEmotion: nil,
            userIsFrustratedWithCaptain: false
        )
    }

    private func makeBrief(angle: ReasoningAngle = .recovery) -> ReasoningBrief {
        ReasoningBrief(
            thesis: "User just walked 45 min — recovery angle.",
            angle: angle,
            observedPatterns: [],
            smartCallbacks: ["توه مشى 3.1 كم"],
            openingHook: "Open with the workout reference",
            nextDayHint: nil,
            avoidances: ["مشي"],
            habitPatterns: [],
            profileDirective: "User 25–39 — capable",
            microInsights: []
        )
    }

    // MARK: - The bug-of-record: avoid-list violation

    /// Reproduces the screenshot bug exactly: avoid-list contains walking,
    /// reply suggests walking. Gate must flag as critical.
    func testReplySuggestingAvoidedFamilyFlagsCritical() {
        let request = makeRequest(
            recentActivity: makeWalkSnapshot(minutesSinceEnd: 20),
            coherence: makeWalkAvoidCoherence(),
            reasoningBrief: makeBrief()
        )
        let reply = "محمد، شرايك اليوم نمشي مشية خفيفة بزون 2؟"
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertTrue(score.hasCriticalViolation,
                      "Suggesting walking when walking is on avoid-list must be critical")
        XCTAssertFalse(score.isAcceptable,
                       "Critical violations must always be unacceptable")
        XCTAssertTrue(score.violations.contains { v in
            if case .usedAvoidedFamily(let family, _) = v {
                return family == .walking
            }
            return false
        })
    }

    func testReplyAvoidingTheAvoidedFamilyPasses() {
        let request = makeRequest(
            recentActivity: makeWalkSnapshot(minutesSinceEnd: 20),
            coherence: makeWalkAvoidCoherence(),
            reasoningBrief: makeBrief()
        )
        let reply = "أحسنت محمد، 45 دقيقة مشي قوي. خل نسوي إطالة 5 دقايق ونشرب ماء."
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertFalse(score.hasCriticalViolation)
        XCTAssertTrue(score.isAcceptable)
    }

    // MARK: - Missed fresh activity reference

    func testReplyIgnoringVeryFreshWorkoutFlagsViolation() {
        let request = makeRequest(
            recentActivity: makeWalkSnapshot(minutesSinceEnd: 15),
            reasoningBrief: makeBrief()
        )
        let reply = "أهلاً، شلون أگدر أساعدك اليوم؟"
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertTrue(score.violations.contains { v in
            if case .missedFreshActivityReference = v { return true }
            return false
        })
    }

    func testReplyMentioningFreshWorkoutPasses() {
        let request = makeRequest(
            recentActivity: makeWalkSnapshot(minutesSinceEnd: 15),
            reasoningBrief: makeBrief()
        )
        let reply = "بعد المشي، خل نهتم بالاستشفاء."
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertFalse(score.violations.contains { v in
            if case .missedFreshActivityReference = v { return true }
            return false
        })
    }

    // MARK: - Vague close

    func testVagueCloseFlagsViolationWhenAngleIsNotFactual() {
        let request = makeRequest(reasoningBrief: makeBrief(angle: .recovery))
        let reply = "هلا. شنو تحب نسوي؟"
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertTrue(score.violations.contains { v in
            if case .vagueClose = v { return true }
            return false
        })
    }

    func testVagueCloseAcceptedWhenAngleIsFactual() {
        let request = makeRequest(reasoningBrief: makeBrief(angle: .factual))
        let reply = "تحديات المرحلة 1 خمسة. شنو تحب نسوي؟"
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertFalse(score.violations.contains { v in
            if case .vagueClose = v { return true }
            return false
        })
    }

    // MARK: - No specific number

    func testGenericReplyWithRichContextFlagsNoNumber() {
        let request = makeRequest(
            steps: 8_500,
            recentActivity: makeWalkSnapshot(minutesSinceEnd: 30),
            reasoningBrief: makeBrief()
        )
        let reply = "أحسنت بالمشي اليوم، تستحق راحة الآن."
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertTrue(score.violations.contains { v in
            if case .noSpecificNumber = v { return true }
            return false
        })
    }

    func testReplyWithSpecificNumberPasses() {
        let request = makeRequest(
            steps: 8_500,
            recentActivity: makeWalkSnapshot(minutesSinceEnd: 30),
            reasoningBrief: makeBrief()
        )
        let reply = "45 دقيقة مشي قوي. خل نسوي 5 دقايق إطالة."
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertFalse(score.violations.contains { v in
            if case .noSpecificNumber = v { return true }
            return false
        })
    }

    // MARK: - Excessive length

    func testTooManySentencesFlagsLength() {
        let request = makeRequest()
        let reply = (0..<10).map { "جملة \($0)." }.joined(separator: " ")
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertTrue(score.violations.contains { v in
            if case .excessiveLength = v { return true }
            return false
        })
    }

    // MARK: - Dialect drift

    func testEnglishHeavyReplyInArabicModeFlagsDrift() {
        let request = makeRequest(language: .arabic)
        let reply = "Today is a great day for some walking and stretching, you know?"
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertTrue(score.hasCriticalViolation,
                      "Severe dialect drift in Arabic mode must be critical")
    }

    func testEnglishReplyInEnglishModePasses() {
        let request = makeRequest(language: .english)
        let reply = "Great walking session today — try a 5-minute hip flexor stretch."
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertFalse(score.violations.contains { v in
            if case .dialectDrift = v { return true }
            return false
        })
    }

    // MARK: - Empty reply

    func testEmptyReplyDoesNotCrashAndScoresHigh() {
        let request = makeRequest()
        let score = gate.evaluate(replyMessage: "", request: request)

        XCTAssertEqual(score.score, 1.0)
        XCTAssertTrue(score.violations.isEmpty)
    }

    // MARK: - Score arithmetic

    func testCriticalViolationDropsBelowAcceptanceThreshold() {
        let request = makeRequest(
            recentActivity: makeWalkSnapshot(minutesSinceEnd: 20),
            coherence: makeWalkAvoidCoherence()
        )
        let reply = "خل نمشي 20 دقيقة بزون 2."
        let score = gate.evaluate(replyMessage: reply, request: request)

        XCTAssertLessThan(score.score, 0.6,
                          "A single critical violation must drop below the 0.6 acceptance floor")
    }

    func testCorrectivePrefixIncludesViolationCodes() {
        let request = makeRequest(
            recentActivity: makeWalkSnapshot(minutesSinceEnd: 20),
            coherence: makeWalkAvoidCoherence()
        )
        let reply = "خل نمشي 20 دقيقة."
        let score = gate.evaluate(replyMessage: reply, request: request)

        let prefix = score.correctivePromptPrefix(language: .arabic)
        XCTAssertTrue(prefix.contains("used_avoided_family"),
                      "Corrective prefix must surface the specific violation code")
        XCTAssertTrue(prefix.contains("Brain §41"))
    }
}
