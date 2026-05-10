// ===============================================
// File: PredictiveIntentEngineTests.swift
// Brain Refactor §45 — coverage for follow-up question anticipation.
// ===============================================

import XCTest
@testable import AiQo

@MainActor
final class PredictiveIntentEngineTests: XCTestCase {

    private func makeWalkSnapshot(
        durationMinutes: Int,
        activeCalories: Int,
        minutesSinceEnd: Int = 15
    ) -> RecentActivitySnapshot {
        RecentActivitySnapshot(
            title: "مشي",
            family: .walking,
            durationMinutes: durationMinutes,
            activeCalories: activeCalories,
            distanceKm: 3.0,
            endedAt: Date().addingTimeInterval(Double(-minutesSinceEnd * 60)),
            minutesSinceEnd: minutesSinceEnd
        )
    }

    // MARK: - Fresh high-intensity → nutrition prediction

    func testHardSessionPredictsNutritionAfterEffort() {
        let activity = makeWalkSnapshot(durationMinutes: 50, activeCalories: 300)
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .general,
            emotionalSignal: .neutral,
            recentActivity: activity,
            sleepHoursLastNight: 7.0,
            hour: 14,
            coherence: nil,
            behavioralStage: nil
        )
        XCTAssertEqual(prediction?.topic, .nutritionAfterEffort)
        XCTAssertGreaterThanOrEqual(prediction?.confidence ?? 0, 0.7)
    }

    // MARK: - Fresh light session → next-step prediction

    func testLightSessionPredictsNextStepGuidance() {
        let activity = makeWalkSnapshot(durationMinutes: 18, activeCalories: 90)
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .general,
            emotionalSignal: .neutral,
            recentActivity: activity,
            sleepHoursLastNight: 7.0,
            hour: 14,
            coherence: nil,
            behavioralStage: nil
        )
        XCTAssertEqual(prediction?.topic, .nextStepGuidance)
    }

    // MARK: - Tired + late → sleep concern

    func testTiredAndLateInDayPredictsSleepConcern() {
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .general,
            emotionalSignal: .tired,
            recentActivity: nil,
            sleepHoursLastNight: 7.0,
            hour: 21,
            coherence: nil,
            behavioralStage: nil
        )
        XCTAssertEqual(prediction?.topic, .sleepConcern)
    }

    func testTiredEarlyDoesNotForceSleepPrediction() {
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .general,
            emotionalSignal: .tired,
            recentActivity: nil,
            sleepHoursLastNight: 7.0,
            hour: 11,
            coherence: nil,
            behavioralStage: nil
        )
        XCTAssertNotEqual(prediction?.topic, .sleepConcern,
                          "Tiredness mid-morning shouldn't immediately predict sleep")
    }

    // MARK: - Low sleep + morning → plan tomorrow

    func testLowSleepInMorningPredictsLighterDay() {
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .general,
            emotionalSignal: .neutral,
            recentActivity: nil,
            sleepHoursLastNight: 5.0,
            hour: 9,
            coherence: nil,
            behavioralStage: nil
        )
        XCTAssertEqual(prediction?.topic, .planTomorrow)
    }

    // MARK: - Challenge intent → timeline estimate

    func testChallengeIntentPredictsTimelineEstimate() {
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .challenge,
            emotionalSignal: .neutral,
            recentActivity: nil,
            sleepHoursLastNight: 7.0,
            hour: 14,
            coherence: nil,
            behavioralStage: nil
        )
        XCTAssertEqual(prediction?.topic, .timelineEstimate)
    }

    // MARK: - Workout intent without recent activity → form check

    func testWorkoutIntentNoRecentActivityPredictsFormCheck() {
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .workout,
            emotionalSignal: .neutral,
            recentActivity: nil,
            sleepHoursLastNight: 7.0,
            hour: 14,
            coherence: nil,
            behavioralStage: nil
        )
        XCTAssertEqual(prediction?.topic, .formCorrection)
    }

    // MARK: - Preparation stage → progress assessment

    func testPreparationStagePredictsProgressAssessment() {
        let stage = BehavioralStageReading(stage: .preparation, confidence: 0.7)
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .general,
            emotionalSignal: .neutral,
            recentActivity: nil,
            sleepHoursLastNight: 7.0,
            hour: 14,
            coherence: nil,
            behavioralStage: stage
        )
        XCTAssertEqual(prediction?.topic, .progressAssessment)
    }

    // MARK: - Cascade priority — fresh activity wins over emotion

    func testFreshActivityBeatsTiredSignal() {
        let activity = makeWalkSnapshot(durationMinutes: 50, activeCalories: 300)
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .general,
            emotionalSignal: .tired,
            recentActivity: activity,
            sleepHoursLastNight: 7.0,
            hour: 21,
            coherence: nil,
            behavioralStage: nil
        )
        XCTAssertEqual(prediction?.topic, .nutritionAfterEffort,
                       "Fresh activity must dominate the cascade over tiredness")
    }

    // MARK: - No signal → nil

    func testNoSignalsReturnsNil() {
        let prediction = PredictiveIntentEngine.anticipate(
            currentIntent: .general,
            emotionalSignal: .neutral,
            recentActivity: nil,
            sleepHoursLastNight: 7.0,
            hour: 14,
            coherence: nil,
            behavioralStage: nil
        )
        XCTAssertNil(prediction)
    }
}
