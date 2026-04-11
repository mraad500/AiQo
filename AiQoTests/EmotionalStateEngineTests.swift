import XCTest
@testable import AiQo

final class EmotionalStateEngineTests: XCTestCase {

    private let engine = EmotionalStateEngine.shared
    private let now = Date()

    // MARK: - Helpers

    private func evaluate(
        stepsToday: Int = 5000,
        steps7DayAvg: Int = 5000,
        sleepLastNight: Double? = nil,
        sleep7DayAvg: Double? = nil,
        restingHR: Double? = nil,
        hrvLatest: Double? = nil,
        hrv7DayAvg: Double? = nil,
        lastWorkout: Date? = nil,
        messageLength: Int? = nil,
        messageTimestamp: Date? = nil,
        bedtime: String? = nil,
        wakeTime: String? = nil
    ) -> EmotionalState {
        engine.evaluate(
            stepsToday: stepsToday,
            steps7DayAvg: steps7DayAvg,
            sleepLastNightHours: sleepLastNight,
            sleep7DayAvgHours: sleep7DayAvg,
            restingHeartRate: restingHR,
            hrvLatest: hrvLatest,
            hrv7DayAvg: hrv7DayAvg,
            lastWorkoutDate: lastWorkout,
            messageLength: messageLength,
            messageTimestamp: messageTimestamp ?? now,
            userPreferredBedtime: bedtime,
            userPreferredWakeTime: wakeTime
        )
    }

    // MARK: - Mood: Stressed

    func testStressed_lowHRVAndPoorSleep() {
        let result = evaluate(
            sleepLastNight: 4.0,
            sleep7DayAvg: 7.0,
            hrvLatest: 20,
            hrv7DayAvg: 50
        )
        XCTAssertEqual(result.estimatedMood, .stressed)
        XCTAssertEqual(result.recommendedTone, .gentle)
        XCTAssertTrue(result.signals.contains("low_hrv"))
        XCTAssertTrue(result.signals.contains("poor_sleep"))
    }

    func testStressed_highRestingHRAndNoSleepData() {
        let result = evaluate(restingHR: 90)
        XCTAssertEqual(result.estimatedMood, .stressed)
        XCTAssertEqual(result.recommendedTone, .gentle)
        XCTAssertTrue(result.signals.contains("high_resting_hr"))
    }

    // MARK: - Mood: Low Energy

    func testLowEnergy_poorSleepAndBelowAvgSteps() {
        let result = evaluate(
            stepsToday: 2000,
            steps7DayAvg: 8000,
            sleepLastNight: 4.0,
            sleep7DayAvg: 7.0
        )
        XCTAssertEqual(result.estimatedMood, .lowEnergy)
        XCTAssertEqual(result.recommendedTone, .gentle)
    }

    func testLowEnergy_lateNightMessageAndPoorSleep() {
        // 2:00 AM message, bedtime 23:00, wake 07:00
        var cal = Calendar.current
        cal.timeZone = .current
        let components = DateComponents(hour: 2, minute: 0)
        let lateTime = cal.date(from: components)!

        let result = evaluate(
            sleepLastNight: 3.5,
            sleep7DayAvg: 7.0,
            messageTimestamp: lateTime,
            bedtime: "23:00",
            wakeTime: "07:00"
        )
        XCTAssertEqual(result.estimatedMood, .lowEnergy)
        XCTAssertTrue(result.signals.contains("late_night_message"))
        XCTAssertTrue(result.signals.contains("poor_sleep"))
    }

    // MARK: - Mood: High Energy

    func testHighEnergy_goodSleepAndAboveAvgSteps() {
        let result = evaluate(
            stepsToday: 12000,
            steps7DayAvg: 8000,
            sleepLastNight: 8.5,
            sleep7DayAvg: 7.0
        )
        XCTAssertEqual(result.estimatedMood, .highEnergy)
        XCTAssertEqual(result.recommendedTone, .energetic)
    }

    func testHighEnergy_highHRVAndRecentlyActive() {
        let result = evaluate(
            hrvLatest: 70,
            hrv7DayAvg: 50,
            lastWorkout: now
        )
        XCTAssertEqual(result.estimatedMood, .highEnergy)
        XCTAssertTrue(result.signals.contains("high_hrv"))
        XCTAssertTrue(result.signals.contains("recently_active"))
    }

    // MARK: - Mood: Recovering

    func testRecovering_goodSleepButBelowAvgSteps() {
        let result = evaluate(
            stepsToday: 2000,
            steps7DayAvg: 8000,
            sleepLastNight: 8.5,
            sleep7DayAvg: 7.0
        )
        XCTAssertEqual(result.estimatedMood, .recovering)
        XCTAssertEqual(result.recommendedTone, .neutral)
    }

    // MARK: - Mood: Neutral

    func testNeutral_noSignificantSignals() {
        let result = evaluate()
        XCTAssertEqual(result.estimatedMood, .neutral)
        XCTAssertEqual(result.recommendedTone, .neutral)
    }

    // MARK: - Celebratory Override

    func testCelebratoryTone_threeOrMoreStrongPositiveSignals() {
        let result = evaluate(
            stepsToday: 12000,
            steps7DayAvg: 8000,
            sleepLastNight: 8.5,
            sleep7DayAvg: 7.0,
            hrvLatest: 70,
            hrv7DayAvg: 50,
            lastWorkout: now
        )
        // 4 strong positive signals: good_sleep, above_avg_steps, high_hrv, recently_active
        XCTAssertEqual(result.recommendedTone, .celebratory)
    }

    func testNotCelebratory_onlyTwoStrongPositiveSignals() {
        let result = evaluate(
            stepsToday: 12000,
            steps7DayAvg: 8000,
            sleepLastNight: 8.5,
            sleep7DayAvg: 7.0
        )
        // 2 strong positive signals: good_sleep, above_avg_steps
        XCTAssertNotEqual(result.recommendedTone, .celebratory)
    }

    // MARK: - Confidence

    func testConfidence_capsAt095() {
        let result = evaluate(
            sleepLastNight: 7.0,
            sleep7DayAvg: 7.0,
            restingHR: 60,
            hrvLatest: 50,
            hrv7DayAvg: 50,
            lastWorkout: now,
            messageLength: 20,
            bedtime: "23:00",
            wakeTime: "07:00"
        )
        // All 9 optional inputs provided: 0.5 + 9*0.08 = 1.22 → capped at 0.95
        XCTAssertEqual(result.confidence, 0.95, accuracy: 0.001)
    }

    func testConfidence_capsAt04_whenFewerThanThreeInputs() {
        // Only stepsToday/steps7DayAvg are non-optional (always provided).
        // Zero optional inputs: 0.5 + 0*0.08 = 0.5 → capped at 0.4 (< 3 inputs)
        let result = evaluate()
        XCTAssertEqual(result.confidence, 0.4, accuracy: 0.001)
    }

    func testConfidence_exactlyThreeInputs_notCapped() {
        let result = evaluate(
            sleepLastNight: 7.0,
            sleep7DayAvg: 7.0,
            restingHR: 60
        )
        // 3 optional inputs: 0.5 + 3*0.08 = 0.74
        XCTAssertEqual(result.confidence, 0.74, accuracy: 0.001)
    }

    // MARK: - Signal Detection

    func testPoorSleep_belowAbsoluteThreshold() {
        let result = evaluate(sleepLastNight: 4.5)
        XCTAssertTrue(result.signals.contains("poor_sleep"))
    }

    func testPoorSleep_below75PercentOfAverage() {
        let result = evaluate(sleepLastNight: 5.0, sleep7DayAvg: 8.0)
        // 5.0 < 8.0 * 0.75 = 6.0 → poor_sleep
        XCTAssertTrue(result.signals.contains("poor_sleep"))
    }

    func testGoodSleep_above110PercentOfAverageAndAbove7() {
        let result = evaluate(sleepLastNight: 8.0, sleep7DayAvg: 7.0)
        // 8.0 >= 7.0 * 1.1 = 7.7 AND >= 7.0 → good_sleep
        XCTAssertTrue(result.signals.contains("good_sleep"))
    }

    func testShortMessage() {
        let result = evaluate(messageLength: 3)
        XCTAssertTrue(result.signals.contains("short_message"))
    }

    func testNoRecentWorkout_neverWorkedOut() {
        let result = evaluate(lastWorkout: nil)
        XCTAssertTrue(result.signals.contains("no_recent_workout"))
    }

    func testNoRecentWorkout_moreThan3DaysAgo() {
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: now)!
        let result = evaluate(lastWorkout: fourDaysAgo)
        XCTAssertTrue(result.signals.contains("no_recent_workout"))
    }

    func testRecentlyActive_workedOutToday() {
        let result = evaluate(lastWorkout: now)
        XCTAssertTrue(result.signals.contains("recently_active"))
    }
}
