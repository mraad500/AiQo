import XCTest
@testable import AiQo

final class TrendAnalyzerTests: XCTestCase {

    private let analyzer = TrendAnalyzer.shared

    // MARK: - Helpers

    private func makePoint(
        daysAgo: Int,
        steps: Int = 5000,
        sleepHours: Double = 7.0,
        calories: Int = 300,
        workoutCount: Int = 0,
        workoutMinutes: Int = 0,
        waterPercent: Double = 0.0,
        ringCompletion: Double = 0.5,
        restingHR: Double? = 65
    ) -> DailyHealthPoint {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return DailyHealthPoint(
            date: date,
            steps: steps,
            sleepHours: sleepHours,
            caloriesBurned: calories,
            workoutCount: workoutCount,
            workoutMinutes: workoutMinutes,
            waterIntakePercent: waterPercent,
            ringCompletion: ringCompletion,
            restingHeartRate: restingHR
        )
    }

    /// Build 14 days: days 0-6 = thisWeek, days 7-13 = lastWeek
    private func makeTwoWeeks(
        thisWeekSteps: Int = 5000,
        lastWeekSteps: Int = 5000,
        thisWeekSleep: Double = 7.0,
        lastWeekSleep: Double = 7.0,
        thisWeekWorkouts: Int = 0,
        lastWeekWorkouts: Int = 0,
        thisWeekRingCompletion: Double = 0.5,
        thisWeekHR: Double? = 65,
        lastWeekHR: Double? = 65
    ) -> [DailyHealthPoint] {
        var points: [DailyHealthPoint] = []
        for day in 0..<7 {
            points.append(makePoint(
                daysAgo: day,
                steps: thisWeekSteps,
                sleepHours: thisWeekSleep,
                workoutCount: day < thisWeekWorkouts ? 1 : 0,
                ringCompletion: thisWeekRingCompletion,
                restingHR: thisWeekHR
            ))
        }
        for day in 7..<14 {
            points.append(makePoint(
                daysAgo: day,
                steps: lastWeekSteps,
                sleepHours: lastWeekSleep,
                workoutCount: (day - 7) < lastWeekWorkouts ? 1 : 0,
                restingHR: lastWeekHR
            ))
        }
        return points
    }

    // MARK: - Empty Input

    func testEmptyInput_returnsStableDefaults() {
        let result = analyzer.compute(dailyPoints: [], currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.stepsTrend, .stable)
        XCTAssertEqual(result.sleepTrend, .stable)
        XCTAssertEqual(result.workoutFrequencyTrend, .stable)
        XCTAssertEqual(result.consistencyScore, 0.0)
        XCTAssertEqual(result.stepsChangePct, 0)
    }

    // MARK: - Steps Trend

    func testSteps_improving() {
        let points = makeTwoWeeks(thisWeekSteps: 10000, lastWeekSteps: 5000)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 3, yesterdayStreak: true)
        XCTAssertEqual(result.stepsTrend, .improving)
        XCTAssertEqual(result.stepsChangePct, 100) // (10000-5000)/5000 * 100
    }

    func testSteps_declining() {
        let points = makeTwoWeeks(thisWeekSteps: 3000, lastWeekSteps: 5000)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.stepsTrend, .declining)
        XCTAssertEqual(result.stepsChangePct, -40) // (3000-5000)/5000 * 100
    }

    func testSteps_stable_withinThreshold() {
        let points = makeTwoWeeks(thisWeekSteps: 5200, lastWeekSteps: 5000)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 1, yesterdayStreak: true)
        XCTAssertEqual(result.stepsTrend, .stable)
        XCTAssertEqual(result.stepsChangePct, 4) // 4% change → stable (within ±10%)
    }

    // MARK: - Sleep Trend

    func testSleep_improving() {
        let points = makeTwoWeeks(thisWeekSleep: 8.0, lastWeekSleep: 6.0)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.sleepTrend, .improving)
    }

    func testSleep_declining() {
        let points = makeTwoWeeks(thisWeekSleep: 5.0, lastWeekSleep: 7.5)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.sleepTrend, .declining)
    }

    // MARK: - Heart Rate (Inverted)

    func testHeartRate_improving_whenLower() {
        let points = makeTwoWeeks(thisWeekHR: 60, lastWeekHR: 75)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        // HR went down → improving (inverted)
        XCTAssertEqual(result.heartRateTrend, .improving)
    }

    func testHeartRate_declining_whenHigher() {
        let points = makeTwoWeeks(thisWeekHR: 80, lastWeekHR: 60)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        // HR went up → declining (inverted)
        XCTAssertEqual(result.heartRateTrend, .declining)
    }

    // MARK: - Workout Frequency

    func testWorkouts_improving() {
        let points = makeTwoWeeks(thisWeekWorkouts: 4, lastWeekWorkouts: 1)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.workoutFrequencyTrend, .improving)
        XCTAssertEqual(result.workoutsThisWeek, 4)
        XCTAssertEqual(result.workoutsLastWeek, 1)
    }

    func testWorkouts_fromZeroToSome_isImproving() {
        let points = makeTwoWeeks(thisWeekWorkouts: 2, lastWeekWorkouts: 0)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.workoutFrequencyTrend, .improving)
    }

    func testWorkouts_zeroToZero_isStable() {
        let points = makeTwoWeeks(thisWeekWorkouts: 0, lastWeekWorkouts: 0)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.workoutFrequencyTrend, .stable)
    }

    // MARK: - Consistency Score

    func testConsistency_allDaysAboveThreshold() {
        let points = makeTwoWeeks(thisWeekRingCompletion: 0.9)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 7, yesterdayStreak: true)
        XCTAssertEqual(result.consistencyScore, 1.0, accuracy: 0.001)
    }

    func testConsistency_noDaysAboveThreshold() {
        let points = makeTwoWeeks(thisWeekRingCompletion: 0.3)
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.consistencyScore, 0.0, accuracy: 0.001)
    }

    // MARK: - Streak Momentum

    func testStreakMomentum_building() {
        let result = analyzer.compute(dailyPoints: [], currentStreak: 5, yesterdayStreak: true)
        XCTAssertEqual(result.streakMomentum, .building)
    }

    func testStreakMomentum_holding() {
        let result = analyzer.compute(dailyPoints: [], currentStreak: 1, yesterdayStreak: true)
        XCTAssertEqual(result.streakMomentum, .holding)
    }

    func testStreakMomentum_breaking() {
        let result = analyzer.compute(dailyPoints: [], currentStreak: 0, yesterdayStreak: true)
        XCTAssertEqual(result.streakMomentum, .breaking)
    }

    func testStreakMomentum_broken() {
        let result = analyzer.compute(dailyPoints: [], currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.streakMomentum, .broken)
    }

    // MARK: - Insufficient Last Week Data

    func testInsufficientLastWeek_returnsStable() {
        // Only 7 days → no lastWeek data
        let points = (0..<7).map { makePoint(daysAgo: $0) }
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.stepsTrend, .stable)
        XCTAssertEqual(result.stepsChangePct, 0)
    }

    // MARK: - Ring Completion Average

    func testRingCompletionAverage() {
        // thisWeek all at 0.6 ring completion
        var points: [DailyHealthPoint] = []
        for day in 0..<7 {
            points.append(makePoint(daysAgo: day, ringCompletion: 0.6))
        }
        let result = analyzer.compute(dailyPoints: points, currentStreak: 0, yesterdayStreak: false)
        XCTAssertEqual(result.ringCompletionAvg7d, 0.6, accuracy: 0.001)
    }
}
