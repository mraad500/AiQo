// ===============================================
// File: CognitiveReasonerTests.swift
// Brain Refactor §37 — coverage for the executive-function reasoner that
// produces the per-turn ReasoningBrief.
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class CognitiveReasonerTests: XCTestCase {

    private var reasoner: CognitiveReasoner { .shared }

    // MARK: - Helpers

    private func makeInput(
        recentActivity: RecentActivitySnapshot? = nil,
        coherence: ConversationContextTags? = nil,
        steps: Int = 4_000,
        sleepLastNight: Double = 7.0,
        hour: Int = 14,
        dailyPoints: [DailyHealthPoint] = [],
        recentWorkouts: [WorkoutHistoryEntry] = [],
        trend: TrendSnapshot? = nil
    ) -> ReasonerInput {
        ReasonerInput(
            language: .arabic,
            hour: hour,
            steps: steps,
            calories: 200,
            sleepHoursLastNight: sleepLastNight,
            restingHeartRate: 60,
            level: 5,
            bioPhase: .energy,
            trend: trend,
            recentActivity: recentActivity,
            coherence: coherence,
            dailyPoints: dailyPoints,
            recentWorkouts: recentWorkouts
        )
    }

    private func makeSnapshot(
        family: RecentActivityFamily,
        minutesSinceEnd: Int,
        durationMinutes: Int = 45
    ) -> RecentActivitySnapshot {
        RecentActivitySnapshot(
            title: family.arabicLabel,
            family: family,
            durationMinutes: durationMinutes,
            activeCalories: 250,
            distanceKm: family == .walking ? 3.1 : nil,
            endedAt: Date().addingTimeInterval(Double(-minutesSinceEnd * 60)),
            minutesSinceEnd: minutesSinceEnd
        )
    }

    private func makeDailyPoint(
        daysAgo: Int,
        steps: Int = 5_000,
        sleepHours: Double = 7.0,
        workoutCount: Int = 0
    ) -> DailyHealthPoint {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return DailyHealthPoint(
            date: date, steps: steps, sleepHours: sleepHours,
            caloriesBurned: 200, workoutCount: workoutCount,
            workoutMinutes: workoutCount > 0 ? 30 : 0,
            waterIntakePercent: 0, ringCompletion: 0, restingHeartRate: 60
        )
    }

    // MARK: - Angle: repair (frustration with Captain)

    func testFrustrationWithCaptainPicksRepairAngle() {
        let coherence = ConversationContextTags(
            completedClaims: [],
            refusals: [],
            latestEmotion: .frustrated,
            userIsFrustratedWithCaptain: true
        )
        let brief = reasoner.reason(input: makeInput(coherence: coherence))
        XCTAssertEqual(brief.angle, .repair)
        XCTAssertFalse(brief.thesis.isEmpty)
        XCTAssertNotNil(brief.openingHook)
    }

    /// Even if the user has a fresh personal best, repair beats celebrate.
    func testRepairWinsOverCelebrate() {
        let coherence = ConversationContextTags(
            completedClaims: [], refusals: [],
            latestEmotion: nil, userIsFrustratedWithCaptain: true
        )
        let priorDays = (1...6).map { makeDailyPoint(daysAgo: $0, steps: 4_000) }
        let today = makeDailyPoint(daysAgo: 0, steps: 12_000)
        let brief = reasoner.reason(
            input: makeInput(
                coherence: coherence,
                steps: 12_000,
                dailyPoints: priorDays + [today]
            )
        )
        XCTAssertEqual(brief.angle, .repair)
    }

    // MARK: - Angle: recovery (very fresh activity)

    func testVeryFreshWalkPicksRecoveryAngle() {
        let snapshot = makeSnapshot(family: .walking, minutesSinceEnd: 20)
        let brief = reasoner.reason(input: makeInput(recentActivity: snapshot))
        XCTAssertEqual(brief.angle, .recovery)
        XCTAssertTrue(brief.thesis.contains("مشي") || brief.thesis.contains("walking"))
        XCTAssertFalse(brief.smartCallbacks.isEmpty,
                       "Recovery angle must surface a callback referencing the workout")
    }

    func testStrengthRecoveryAddsNextDayHint() {
        let snapshot = makeSnapshot(family: .strength, minutesSinceEnd: 15, durationMinutes: 50)
        let brief = reasoner.reason(input: makeInput(recentActivity: snapshot))
        XCTAssertEqual(brief.angle, .recovery)
        XCTAssertNotNil(brief.nextDayHint, "Strength sessions should imply a next-day easy hint")
    }

    // MARK: - Angle: gentle (low-sleep streak)

    func testThreeDaysLowSleepPicksGentleAngle() {
        let dailyPoints = [
            makeDailyPoint(daysAgo: 3, sleepHours: 5.5),
            makeDailyPoint(daysAgo: 2, sleepHours: 5.3),
            makeDailyPoint(daysAgo: 1, sleepHours: 5.0),
            makeDailyPoint(daysAgo: 0, sleepHours: 5.4)  // today
        ]
        let brief = reasoner.reason(
            input: makeInput(sleepLastNight: 5.4, dailyPoints: dailyPoints)
        )
        XCTAssertEqual(brief.angle, .gentle)
        XCTAssertTrue(brief.observedPatterns.contains { pattern in
            if case .lowSleepStreak(let days, _) = pattern { return days >= 3 }
            return false
        })
    }

    // MARK: - Angle: celebrate (steps personal best)

    func testStepsAboveSevenDayMaxPicksCelebrate() {
        let prior = (1...6).map { makeDailyPoint(daysAgo: $0, steps: 4_000) }
        let today = makeDailyPoint(daysAgo: 0, steps: 11_000)
        let brief = reasoner.reason(
            input: makeInput(steps: 11_000, dailyPoints: prior + [today])
        )
        XCTAssertEqual(brief.angle, .celebrate)
        XCTAssertTrue(brief.observedPatterns.contains { pattern in
            if case .stepsPersonalBest = pattern { return true }
            return false
        })
    }

    // MARK: - Angle: factual (default — no acute signals)

    func testNoSignalsFallsBackToFactual() {
        let brief = reasoner.reason(input: makeInput())
        XCTAssertEqual(brief.angle, .factual)
        XCTAssertNil(brief.openingHook,
                     "Factual angle should not force an opening hook")
    }

    // MARK: - Pattern: activity monotony

    func testFiveDaysSameFamilyTriggersMonotony() {
        let workouts: [WorkoutHistoryEntry] = (0..<5).map { i in
            WorkoutHistoryEntry(
                date: Date().addingTimeInterval(Double(-i * 86400)),
                title: "مشي",
                durationSeconds: 1800,
                activeCalories: 200,
                heartRate: nil,
                distanceMeters: 2000
            )
        }
        let brief = reasoner.reason(input: makeInput(recentWorkouts: workouts))
        XCTAssertTrue(brief.observedPatterns.contains { pattern in
            if case let .activityMonotony(family, days) = pattern {
                return family == .walking && days >= 5
            }
            return false
        })
    }

    // MARK: - Avoidances mirror coherence

    func testAvoidancesMirrorCoherenceTags() {
        let snapshot = makeSnapshot(family: .walking, minutesSinceEnd: 10)
        let coherence = ConversationContextTags(
            completedClaims: [
                CompletedActivityClaim(family: .walking, userQuote: "مشيت 45د")
            ],
            refusals: [],
            latestEmotion: nil,
            userIsFrustratedWithCaptain: false
        )
        let brief = reasoner.reason(
            input: makeInput(recentActivity: snapshot, coherence: coherence)
        )
        XCTAssertTrue(brief.avoidances.contains("مشي"),
                      "Brief avoidances must mirror coherence familiesToAvoid")
    }

    // MARK: - Brief is empty when nothing actionable

    func testEmptyInputProducesFactualAngleWithMinimalBrief() {
        let brief = reasoner.reason(input: makeInput())
        // factual + no patterns + no callbacks = thesis still present, but
        // the brief overall is allowed to be near-empty.
        XCTAssertEqual(brief.angle, .factual)
        XCTAssertTrue(brief.smartCallbacks.isEmpty)
        XCTAssertTrue(brief.avoidances.isEmpty)
    }
}
