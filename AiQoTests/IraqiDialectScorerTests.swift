// ===============================================
// File: IraqiDialectScorerTests.swift
// Brain Refactor §48 — coverage for the Iraqi-vs-MSA dialect scorer.
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class IraqiDialectScorerTests: XCTestCase {

    // MARK: - Pure Iraqi passes cleanly

    func testPureIraqiReplyScoresHigh() {
        let reply = "هسة شلونك يا محمد؟ توك خلصت المشي مال 45 دقيقة. خوش، خل نشرب ماي ونريح شوية."
        let score = IraqiDialectScorer.score(reply: reply)
        XCTAssertGreaterThanOrEqual(score.iraqiTokens, 4)
        XCTAssertEqual(score.msaTokens, 0)
        XCTAssertGreaterThan(score.iraqiRatio, 0.8)
        XCTAssertTrue(IraqiDialectScorer.passes(reply: reply))
    }

    // MARK: - Pure MSA fails

    func testPureMSAReplyFailsGate() {
        let reply = "إنه لمن الجدير بالذكر أنّ هذا التمرين يُعدّ من أفضل ما يمكنك القيام به. أود أن أنوّه أنّك تستحق الراحة."
        let score = IraqiDialectScorer.score(reply: reply)
        XCTAssertGreaterThanOrEqual(score.msaTokens, 3)
        XCTAssertEqual(score.iraqiTokens, 0)
        XCTAssertLessThan(score.iraqiRatio, 0.4)
        XCTAssertFalse(IraqiDialectScorer.passes(reply: reply))
    }

    // MARK: - Mixed register — Iraqi wins

    func testMixedReplyWithIraqiMajorityPasses() {
        // Three Iraqi tokens vs one MSA tell — should pass (75% Iraqi).
        let reply = "هسة، توك خلصت تمرين زين. إنه شي حلو إنك ثبتت."
        let score = IraqiDialectScorer.score(reply: reply)
        XCTAssertGreaterThan(score.iraqiRatio, 0.5)
        XCTAssertTrue(IraqiDialectScorer.passes(reply: reply))
    }

    // MARK: - Short reply — no signal, gate stays quiet

    func testShortReplyWithOneTokenDoesNotFireGate() {
        // Only one MSA tell, total = 1, below low-confidence floor.
        let reply = "أود أن أساعدك."
        let score = IraqiDialectScorer.score(reply: reply)
        XCTAssertLessThan(score.totalDialectTokens, DialectScore.lowConfidenceTokenFloor)
        XCTAssertTrue(IraqiDialectScorer.passes(reply: reply),
                      "Replies under the confidence floor should not trip the gate")
    }

    // MARK: - Empty / no Arabic

    func testEmptyReplyReturnsNeutralRatio() {
        let score = IraqiDialectScorer.score(reply: "")
        XCTAssertEqual(score.iraqiTokens, 0)
        XCTAssertEqual(score.msaTokens, 0)
        XCTAssertEqual(score.iraqiRatio, 0.5)
        XCTAssertTrue(IraqiDialectScorer.passes(reply: ""))
    }

    func testEnglishReplyReturnsNoSignal() {
        let score = IraqiDialectScorer.score(reply: "Today was a great session, well done.")
        XCTAssertEqual(score.totalDialectTokens, 0)
        // Falls back to neutral ratio; passes by virtue of low signal.
        XCTAssertTrue(IraqiDialectScorer.passes(reply: "Today was a great session"))
    }

    // MARK: - Specific Iraqi tells

    func testIraqiInterrogativesDetected() {
        let reply = "شلونك اليوم؟ شصار وية تمرينك؟ شكو نسوي بعد؟"
        let score = IraqiDialectScorer.score(reply: reply)
        XCTAssertGreaterThanOrEqual(score.iraqiTokens, 3)
    }

    func testIraqiVerbsDetected() {
        let reply = "گال محمد إنه گاعد يتمرن. تكدر تخل التمرين قصير."
        let score = IraqiDialectScorer.score(reply: reply)
        XCTAssertGreaterThanOrEqual(score.iraqiTokens, 3)
    }
}
