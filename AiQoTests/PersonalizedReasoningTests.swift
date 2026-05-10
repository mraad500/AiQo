// ===============================================
// File: PersonalizedReasoningTests.swift
// Brain Refactor §38–§40 — coverage for HabitDetector, UserProfileLens,
// and MicroInsightGenerator. Together they upgrade the Captain from
// "context-aware" to "user-aware".
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class HabitDetectorTests: XCTestCase {

    private func makeWorkout(
        daysAgo: Int,
        title: String,
        hourOfDay: Int = 18,
        durationMinutes: Int = 30
    ) -> WorkoutHistoryEntry {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hourOfDay
        let baseDate = Calendar.current.date(from: components) ?? Date()
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: baseDate)!
        return WorkoutHistoryEntry(
            date: date,
            title: title,
            durationSeconds: durationMinutes * 60,
            activeCalories: 200,
            heartRate: nil,
            distanceMeters: 0
        )
    }

    private func makeDailyPoint(
        daysAgo: Int,
        steps: Int = 5_000,
        sleepHours: Double = 7.0
    ) -> DailyHealthPoint {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return DailyHealthPoint(
            date: date, steps: steps, sleepHours: sleepHours,
            caloriesBurned: 200, workoutCount: 0, workoutMinutes: 0,
            waterIntakePercent: 0, ringCompletion: 0, restingHeartRate: 60
        )
    }

    // MARK: - Training day-of-week detection

    func testTuesdayThursdayPatternDetected() {
        // Build a 4-week history of Tue + Thu workouts (8 sessions).
        var workouts: [WorkoutHistoryEntry] = []
        for week in 0..<4 {
            // Tuesday → daysAgo offset depends on today's weekday; we just
            // build dates 2 days apart and trust the calendar lookup below.
            let tueOffset = week * 7 + 2
            let thuOffset = week * 7 + 4
            workouts.append(makeWorkout(daysAgo: tueOffset, title: "Walking"))
            workouts.append(makeWorkout(daysAgo: thuOffset, title: "Walking"))
        }
        let patterns = HabitDetector.detect(dailyPoints: [], recentWorkouts: workouts)
        XCTAssertTrue(patterns.contains { pattern in
            if case .trainsOnDays = pattern.kind { return true }
            return false
        })
    }

    // MARK: - Time-of-day preference

    func testMorningExerciserDetectedWhen70PercentMorning() {
        let workouts: [WorkoutHistoryEntry] = (0..<5).map { i in
            makeWorkout(daysAgo: i, title: "Walking", hourOfDay: 7)
        }
        let patterns = HabitDetector.detect(dailyPoints: [], recentWorkouts: workouts)
        XCTAssertTrue(patterns.contains { pattern in
            if case .morningExerciser = pattern.kind { return true }
            return false
        })
    }

    // MARK: - Family preference

    func testWalkingFamilyPreferenceDetected() {
        var workouts: [WorkoutHistoryEntry] = []
        for i in 0..<5 { workouts.append(makeWorkout(daysAgo: i, title: "مشي")) }
        // One outlier — still 5/6 = 83% walking, above the 60% threshold.
        workouts.append(makeWorkout(daysAgo: 6, title: "تمارين قوة"))
        let patterns = HabitDetector.detect(dailyPoints: [], recentWorkouts: workouts)
        XCTAssertTrue(patterns.contains { pattern in
            if case .prefersFamily(let family, _) = pattern.kind {
                return family == .walking
            }
            return false
        })
    }

    // MARK: - Sleep consistency

    func testConsistentSleeperDetected() {
        let points = (0..<7).map { i in
            makeDailyPoint(daysAgo: 6 - i, sleepHours: 7.0 + Double(i % 2) * 0.3)
        }
        let patterns = HabitDetector.detect(dailyPoints: points, recentWorkouts: [])
        XCTAssertTrue(patterns.contains { pattern in
            if case .consistentSleeper = pattern.kind { return true }
            return false
        })
    }

    func testErraticSleeperDetected() {
        let hours: [Double] = [4.5, 8.0, 5.0, 9.0, 4.0, 8.5, 5.5]
        let points = hours.enumerated().map { i, h in
            makeDailyPoint(daysAgo: 6 - i, sleepHours: h)
        }
        let patterns = HabitDetector.detect(dailyPoints: points, recentWorkouts: [])
        XCTAssertTrue(patterns.contains { pattern in
            if case .erraticSleeper = pattern.kind { return true }
            return false
        })
    }

    // MARK: - No-rest streak

    func testSevenDayActivityWithNoRestDetected() {
        let points = (0..<7).map { i in
            makeDailyPoint(daysAgo: 6 - i, steps: 4_000)
        }
        let patterns = HabitDetector.detect(dailyPoints: points, recentWorkouts: [])
        XCTAssertTrue(patterns.contains { pattern in
            if case .neverRests = pattern.kind { return true }
            return false
        })
    }
}

@MainActor
final class UserProfileLensTests: XCTestCase {

    func testYouthAdvancedHasHigherStepsFloor() {
        let lens = UserProfileLensBuilder.build(
            ageString: "22", weightString: "70",
            level: 30, recentWorkoutCount: 7,
            primaryGoal: .improveFitness
        )
        XCTAssertEqual(lens.ageBracket, .youth)
        XCTAssertEqual(lens.experience, .advanced)
        XCTAssertGreaterThanOrEqual(lens.stepsPersonalBestFloor, 8_000)
    }

    func testSeniorBeginnerHasLowerStepsFloor() {
        let lens = UserProfileLensBuilder.build(
            ageString: "62", weightString: "82",
            level: 3, recentWorkoutCount: 1,
            primaryGoal: .improveFitness
        )
        XCTAssertEqual(lens.ageBracket, .senior)
        XCTAssertEqual(lens.experience, .novice)
        XCTAssertLessThanOrEqual(lens.stepsPersonalBestFloor, 5_000)
    }

    func testEstablishedHasHigherSleepThreshold() {
        let lens = UserProfileLensBuilder.build(
            ageString: "48", weightString: "78",
            level: 12, recentWorkoutCount: 4,
            primaryGoal: .cutFat
        )
        XCTAssertEqual(lens.ageBracket, .established)
        XCTAssertGreaterThan(lens.lowSleepThresholdHours, 6.0)
    }

    func testCoachingDirectiveIncludesAgeAndGoal() {
        let lens = UserProfileLensBuilder.build(
            ageString: "33", weightString: "75",
            level: 14, recentWorkoutCount: 4,
            primaryGoal: .buildMuscle
        )
        let directive = lens.coachingDirectiveArabic
        XCTAssertTrue(directive.contains("25-39") || directive.contains("بناء"))
    }

    func testMissingAgeStillProducesDirective() {
        let lens = UserProfileLensBuilder.build(
            ageString: nil, weightString: nil,
            level: 5, recentWorkoutCount: 0,
            primaryGoal: nil
        )
        // No demographics → no age fragment, but experience still infers
        // from level + workout count.
        XCTAssertNil(lens.ageBracket)
        XCTAssertEqual(lens.experience, .novice)
        XCTAssertFalse(lens.coachingDirectiveArabic.isEmpty,
                       "Even with no age/goal, novice directive should exist")
    }
}

@MainActor
final class MicroInsightGeneratorTests: XCTestCase {

    private func makeDailyPoint(
        daysAgo: Int,
        steps: Int = 5_000,
        sleepHours: Double = 7.0
    ) -> DailyHealthPoint {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return DailyHealthPoint(
            date: date, steps: steps, sleepHours: sleepHours,
            caloriesBurned: 200, workoutCount: 0, workoutMinutes: 0,
            waterIntakePercent: 0, ringCompletion: 0, restingHeartRate: 60
        )
    }

    // MARK: - First active after rest

    func testFirstActiveAfterRestSurfaces() {
        let points: [DailyHealthPoint] = [
            makeDailyPoint(daysAgo: 4, steps: 6_000),  // active
            makeDailyPoint(daysAgo: 3, steps: 500),    // rest
            makeDailyPoint(daysAgo: 2, steps: 700),    // rest
            makeDailyPoint(daysAgo: 1, steps: 600),    // rest
            makeDailyPoint(daysAgo: 0, steps: 5_000)   // today — back
        ]
        let insights = MicroInsightGenerator.generate(
            steps: 5_000, sleepHoursLastNight: 7.0,
            recentActivity: nil, dailyPoints: points,
            recentWorkouts: [], hour: 14, currentStreak: 0
        )
        XCTAssertTrue(insights.contains { insight in
            if case .firstAfterRest(let days) = insight.kind {
                return days >= 3
            }
            return false
        })
    }

    // MARK: - Streak milestone

    func testSevenDayStreakFiresMilestone() {
        let insights = MicroInsightGenerator.generate(
            steps: 5_000, sleepHoursLastNight: 7.0,
            recentActivity: nil, dailyPoints: [],
            recentWorkouts: [], hour: 14, currentStreak: 7
        )
        XCTAssertTrue(insights.contains { insight in
            if case .streakMilestone(let days) = insight.kind {
                return days == 7
            }
            return false
        })
    }

    func testNonMultipleOfSevenStreakDoesNotFireMilestone() {
        let insights = MicroInsightGenerator.generate(
            steps: 5_000, sleepHoursLastNight: 7.0,
            recentActivity: nil, dailyPoints: [],
            recentWorkouts: [], hour: 14, currentStreak: 6
        )
        XCTAssertFalse(insights.contains { insight in
            if case .streakMilestone = insight.kind { return true }
            return false
        })
    }

    // MARK: - Best sleep in window

    func testBestSleepInWindowFires() {
        let points: [DailyHealthPoint] = [
            makeDailyPoint(daysAgo: 4, sleepHours: 5.5),
            makeDailyPoint(daysAgo: 3, sleepHours: 6.0),
            makeDailyPoint(daysAgo: 2, sleepHours: 5.8),
            makeDailyPoint(daysAgo: 1, sleepHours: 6.2),
            makeDailyPoint(daysAgo: 0, sleepHours: 8.0)  // today — best
        ]
        let insights = MicroInsightGenerator.generate(
            steps: 5_000, sleepHoursLastNight: 8.0,
            recentActivity: nil, dailyPoints: points,
            recentWorkouts: [], hour: 14, currentStreak: 0
        )
        XCTAssertTrue(insights.contains { insight in
            if case .bestSleepInWindow = insight.kind { return true }
            return false
        })
    }
}
