// ===============================================
// File: BehavioralStageEngineTests.swift
// Brain Refactor §44 — coverage for stages-of-change detection.
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class BehavioralStageEngineTests: XCTestCase {

    private func makeDailyPoint(
        daysAgo: Int,
        steps: Int = 5_000,
        workoutCount: Int = 0
    ) -> DailyHealthPoint {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return DailyHealthPoint(
            date: date, steps: steps, sleepHours: 7.0,
            caloriesBurned: 200, workoutCount: workoutCount,
            workoutMinutes: workoutCount > 0 ? 30 : 0,
            waterIntakePercent: 0, ringCompletion: 0, restingHeartRate: 60
        )
    }

    private func makeWorkout(daysAgo: Int) -> WorkoutHistoryEntry {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return WorkoutHistoryEntry(
            date: date, title: "مشي",
            durationSeconds: 1800, activeCalories: 150,
            heartRate: nil, distanceMeters: 1500
        )
    }

    private func makeUserMessage(_ content: String) -> CaptainConversationMessage {
        CaptainConversationMessage(role: .user, content: content)
    }

    // MARK: - Maintenance

    func testLongStreakWithConsistentWorkoutsDetectsMaintenance() {
        let workouts = (0..<10).map { makeWorkout(daysAgo: $0) }
        let reading = BehavioralStageDetector.detect(
            currentStreak: 45,
            dailyPoints: [],
            recentWorkouts: workouts,
            coherence: nil,
            conversation: [makeUserMessage("شلونك")]
        )
        XCTAssertEqual(reading?.stage, .maintenance)
        XCTAssertGreaterThanOrEqual(reading?.confidence ?? 0, 0.8)
    }

    // MARK: - Action

    func testModerateStreakWithRecentWorkoutsDetectsAction() {
        let workouts = (0..<5).map { makeWorkout(daysAgo: $0) }
        let reading = BehavioralStageDetector.detect(
            currentStreak: 8,
            dailyPoints: [],
            recentWorkouts: workouts,
            coherence: nil,
            conversation: [makeUserMessage("شنو تمرين اليوم")]
        )
        XCTAssertEqual(reading?.stage, .action)
    }

    // MARK: - Preparation

    func testEarlyActivityWithCommitmentLanguageDetectsPreparation() {
        let dailyPoints = [
            makeDailyPoint(daysAgo: 2, steps: 3_500),
            makeDailyPoint(daysAgo: 1, steps: 2_800),
            makeDailyPoint(daysAgo: 0, steps: 4_000)
        ]
        let reading = BehavioralStageDetector.detect(
            currentStreak: 1,
            dailyPoints: dailyPoints,
            recentWorkouts: [],
            coherence: nil,
            conversation: [makeUserMessage("راح أبدي تمارين هاي الأسبوع")]
        )
        XCTAssertEqual(reading?.stage, .preparation)
    }

    // MARK: - Relapse

    func testTenDayInactiveGapFollowedByActiveDayDetectsRelapse() {
        // Build 14 days: first 2 active, then 11 inactive, then today active.
        var points: [DailyHealthPoint] = []
        points.append(makeDailyPoint(daysAgo: 13, steps: 6_000))
        points.append(makeDailyPoint(daysAgo: 12, steps: 5_500))
        for daysAgo in (1...11).reversed() {
            points.append(makeDailyPoint(daysAgo: daysAgo, steps: 500))
        }
        points.append(makeDailyPoint(daysAgo: 0, steps: 4_000))

        let reading = BehavioralStageDetector.detect(
            currentStreak: 1,
            dailyPoints: points,
            recentWorkouts: [],
            coherence: nil,
            conversation: [makeUserMessage("رجعت")]
        )
        XCTAssertEqual(reading?.stage, .relapse)
    }

    // MARK: - Contemplation

    func testActiveSessionWithNoActivityDetectsContemplation() {
        let reading = BehavioralStageDetector.detect(
            currentStreak: 0,
            dailyPoints: [],
            recentWorkouts: [],
            coherence: nil,
            conversation: [makeUserMessage("شنو هاي التحديات؟")]
        )
        XCTAssertEqual(reading?.stage, .contemplation)
    }

    // MARK: - No signal

    func testEmptyConversationWithNoDataReturnsNil() {
        let reading = BehavioralStageDetector.detect(
            currentStreak: 0,
            dailyPoints: [],
            recentWorkouts: [],
            coherence: nil,
            conversation: []
        )
        XCTAssertNil(reading)
    }

    // MARK: - Cascade priority

    /// Relapse must beat action even when the user has technically resumed
    /// some activity — the long gap is the dominant signal.
    func testRelapseBeatsActionWhenGapIsLong() {
        var points: [DailyHealthPoint] = []
        points.append(makeDailyPoint(daysAgo: 13, steps: 6_000))
        for daysAgo in (1...11).reversed() {
            points.append(makeDailyPoint(daysAgo: daysAgo, steps: 400))
        }
        points.append(makeDailyPoint(daysAgo: 0, steps: 5_500))

        let reading = BehavioralStageDetector.detect(
            currentStreak: 1,
            dailyPoints: points,
            recentWorkouts: [makeWorkout(daysAgo: 0)],
            coherence: nil,
            conversation: [makeUserMessage("رجعت")]
        )
        XCTAssertEqual(reading?.stage, .relapse,
                       "10-day gap must dominate stage selection")
    }

    // MARK: - Directive content

    func testDirectiveArabicMatchesStage() {
        let reading = BehavioralStageReading(stage: .relapse, confidence: 0.8)
        XCTAssertTrue(reading.directiveArabic.contains("توبيخ"))
    }

    func testDirectiveEnglishMatchesStage() {
        let reading = BehavioralStageReading(stage: .maintenance, confidence: 0.8)
        XCTAssertTrue(reading.directiveEnglish.contains("MAINTENANCE"))
    }
}
