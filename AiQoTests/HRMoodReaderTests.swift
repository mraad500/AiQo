// ===============================================
// File: HRMoodReaderTests.swift
// Brain Refactor §49 — coverage for the live-HR mood inference layer.
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class HRMoodReaderTests: XCTestCase {

    // MARK: - Helpers

    private func freshActivity(minutesSinceEnd: Int) -> RecentActivitySnapshot {
        RecentActivitySnapshot(
            title: "مشي",
            family: .walking,
            durationMinutes: 30,
            activeCalories: 150,
            distanceKm: 2.0,
            endedAt: Date().addingTimeInterval(Double(-minutesSinceEnd * 60)),
            minutesSinceEnd: minutesSinceEnd
        )
    }

    // MARK: - Calm baseline

    func testHRNearRestingClassifiesAsCalm() {
        let reading = HRMoodReader.read(
            currentHR: 67,
            restingHR: 65,
            recentActivity: nil,
            hour: 14
        )
        XCTAssertEqual(reading.arousal, .calm)
        XCTAssertEqual(reading.mood, .relaxed)
        XCTAssertTrue(reading.hasSignal)
    }

    func testCalmAtNightClassifiesAsWindingDown() {
        let reading = HRMoodReader.read(
            currentHR: 62,
            restingHR: 65,
            recentActivity: nil,
            hour: 22
        )
        XCTAssertEqual(reading.mood, .windingDown)
    }

    // MARK: - Activated → excited / stressed

    func testNotablyElevatedNoActivityClassifiesAsExcited() {
        let reading = HRMoodReader.read(
            currentHR: 85,   // +20 from resting
            restingHR: 65,
            recentActivity: nil,
            hour: 14
        )
        XCTAssertEqual(reading.arousal, .activated)
        XCTAssertEqual(reading.mood, .excited)
    }

    /// The bug-of-record: high HR right after a workout must NOT be flagged
    /// as stress. The reader crosses recent-activity context to suppress
    /// the false positive.
    func testHighHRPostWorkoutClassifiesAsPostEffortNotStressed() {
        let reading = HRMoodReader.read(
            currentHR: 105,  // +40 from resting
            restingHR: 65,
            recentActivity: freshActivity(minutesSinceEnd: 10),
            hour: 14
        )
        XCTAssertEqual(reading.mood, .postEffort,
                       "High HR within 30 min of a session must classify as postEffort")
    }

    func testVeryHighHRWithoutActivityClassifiesAsStressed() {
        let reading = HRMoodReader.read(
            currentHR: 105,  // +40 from resting
            restingHR: 65,
            recentActivity: nil,
            hour: 11
        )
        XCTAssertEqual(reading.arousal, .highlyAroused)
        XCTAssertEqual(reading.mood, .stressed)
    }

    /// 35 minutes past the workout — should no longer count as fresh
    /// "post effort" context, so high HR drops back to stress signal.
    func testHighHRWellPastWorkoutFallsThroughToStressed() {
        let reading = HRMoodReader.read(
            currentHR: 100,
            restingHR: 65,
            recentActivity: freshActivity(minutesSinceEnd: 40),
            hour: 14
        )
        XCTAssertEqual(reading.mood, .stressed,
                       "Beyond 30 min the post-effort halo should expire")
    }

    // MARK: - Missing data

    func testNilHRReturnsUnknownReading() {
        let reading = HRMoodReader.read(
            currentHR: nil,
            restingHR: 65,
            recentActivity: nil,
            hour: 14
        )
        XCTAssertEqual(reading.mood, .unknown)
        XCTAssertEqual(reading.arousal, .unknown)
        XCTAssertFalse(reading.hasSignal)
    }

    func testMissingRestingFallsBackToDefaultButLowersConfidence() {
        let withResting = HRMoodReader.read(
            currentHR: 70,
            restingHR: 60,
            recentActivity: nil,
            hour: 14
        )
        let withoutResting = HRMoodReader.read(
            currentHR: 70,
            restingHR: nil,
            recentActivity: nil,
            hour: 14
        )
        XCTAssertGreaterThan(withResting.confidence, withoutResting.confidence,
                             "Confidence must drop when we use the default resting fallback")
    }

    // MARK: - Tone directives

    func testStressedDirectiveSuggestsCalmTone() {
        let reading = HRMoodReader.read(
            currentHR: 110,
            restingHR: 65,
            recentActivity: nil,
            hour: 11
        )
        XCTAssertTrue(reading.toneDirectiveArabic.contains("هاد")
                      || reading.toneDirectiveArabic.contains("تجنب"),
                      "Stressed directive must steer toward calming tone")
    }

    func testExcitedDirectiveSuggestsMatchingEnergy() {
        let reading = HRMoodReader.read(
            currentHR: 85,
            restingHR: 65,
            recentActivity: nil,
            hour: 14
        )
        XCTAssertTrue(reading.toneDirectiveArabic.contains("حماس")
                      || reading.toneDirectiveArabic.contains("جاريه"),
                      "Excited directive must steer toward matching energy")
    }

    func testPostEffortDirectiveAcknowledgesFatigue() {
        let reading = HRMoodReader.read(
            currentHR: 105,
            restingHR: 65,
            recentActivity: freshActivity(minutesSinceEnd: 10),
            hour: 14
        )
        XCTAssertTrue(reading.toneDirectiveArabic.contains("تعب")
                      || reading.toneDirectiveArabic.contains("ترطيب"),
                      "Post-effort directive must acknowledge fatigue / hydration")
    }

    // MARK: - Elevation calc

    func testElevationFromRestingComputedCorrectly() {
        let reading = HRMoodReader.read(
            currentHR: 80,
            restingHR: 60,
            recentActivity: nil,
            hour: 14
        )
        XCTAssertEqual(reading.elevationFromResting, 20)
    }
}
