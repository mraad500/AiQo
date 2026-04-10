// ===============================================
// File: TrendAnalyzer.swift
// Phase 1 — Captain Hamoudi Brain V2
// Computes 7-day health trends from daily data.
// 100% on-device. No network calls.
// ===============================================

import Foundation

// MARK: - Models

enum TrendDirection: String, Codable, Sendable {
    case improving
    case stable
    case declining
}

enum StreakMomentum: String, Codable, Sendable {
    case building
    case holding
    case breaking
    case broken
}

struct TrendSnapshot: Codable, Sendable {
    let stepsTrend: TrendDirection
    let stepsChangePct: Int

    let sleepTrend: TrendDirection
    let sleepChangePct: Int

    let workoutFrequencyTrend: TrendDirection
    let workoutsThisWeek: Int
    let workoutsLastWeek: Int

    let consistencyScore: Double
    let streakMomentum: StreakMomentum

    let waterTrend: TrendDirection
    let waterChangePct: Int

    let ringCompletionAvg7d: Double

    let heartRateTrend: TrendDirection
    let heartRateChangePct: Int

    let computedAt: Date
}

struct DailyHealthPoint: Codable, Sendable {
    let date: Date
    let steps: Int
    let sleepHours: Double
    let caloriesBurned: Int
    let workoutCount: Int
    let workoutMinutes: Int
    let waterIntakePercent: Double
    let ringCompletion: Double
    let restingHeartRate: Double?
}

// MARK: - Analyzer

final class TrendAnalyzer: Sendable {

    static let shared = TrendAnalyzer()
    private init() {}

    func compute(
        dailyPoints: [DailyHealthPoint],
        currentStreak: Int,
        yesterdayStreak: Bool
    ) -> TrendSnapshot {

        // Handle empty input
        guard !dailyPoints.isEmpty else {
            return TrendSnapshot(
                stepsTrend: .stable, stepsChangePct: 0,
                sleepTrend: .stable, sleepChangePct: 0,
                workoutFrequencyTrend: .stable, workoutsThisWeek: 0, workoutsLastWeek: 0,
                consistencyScore: 0.0, streakMomentum: streakMomentum(current: currentStreak, yesterday: yesterdayStreak),
                waterTrend: .stable, waterChangePct: 0,
                ringCompletionAvg7d: 0.0,
                heartRateTrend: .stable, heartRateChangePct: 0,
                computedAt: Date()
            )
        }

        let sorted = dailyPoints.sorted { $0.date < $1.date }

        // Split into this week (last 7) and last week (8-14)
        let thisWeek: [DailyHealthPoint]
        let lastWeek: [DailyHealthPoint]

        if sorted.count <= 7 {
            thisWeek = sorted
            lastWeek = []
        } else if sorted.count <= 14 {
            let splitIndex = sorted.count - 7
            thisWeek = Array(sorted[splitIndex...])
            lastWeek = Array(sorted[..<splitIndex])
        } else {
            thisWeek = Array(sorted.suffix(7))
            lastWeek = Array(sorted.suffix(14).prefix(7))
        }

        let insufficientLastWeek = lastWeek.count < 2

        // Steps
        let (stepsTrend, stepsPct) = computeTrend(
            thisWeek: thisWeek.map { Double($0.steps) },
            lastWeek: lastWeek.map { Double($0.steps) },
            insufficient: insufficientLastWeek,
            invertDirection: false
        )

        // Sleep
        let (sleepTrend, sleepPct) = computeTrend(
            thisWeek: thisWeek.map { $0.sleepHours },
            lastWeek: lastWeek.map { $0.sleepHours },
            insufficient: insufficientLastWeek,
            invertDirection: false
        )

        // Water
        let (waterTrend, waterPct) = computeTrend(
            thisWeek: thisWeek.map { $0.waterIntakePercent },
            lastWeek: lastWeek.map { $0.waterIntakePercent },
            insufficient: insufficientLastWeek,
            invertDirection: false
        )

        // Heart rate (inverted: lower is better)
        let thisWeekHR = thisWeek.compactMap { $0.restingHeartRate }
        let lastWeekHR = lastWeek.compactMap { $0.restingHeartRate }
        let (heartRateTrend, heartRatePct) = computeTrend(
            thisWeek: thisWeekHR,
            lastWeek: lastWeekHR,
            insufficient: insufficientLastWeek || lastWeekHR.count < 2,
            invertDirection: true
        )

        // Workouts
        let workoutsThisWeek = thisWeek.reduce(0) { $0 + $1.workoutCount }
        let workoutsLastWeek = lastWeek.reduce(0) { $0 + $1.workoutCount }
        let workoutFrequencyTrend: TrendDirection
        if insufficientLastWeek {
            workoutFrequencyTrend = .stable
        } else if workoutsLastWeek == 0 {
            workoutFrequencyTrend = workoutsThisWeek > 0 ? .improving : .stable
        } else {
            let wPct = Double(workoutsThisWeek - workoutsLastWeek) / Double(workoutsLastWeek) * 100
            workoutFrequencyTrend = direction(from: Int(wPct), inverted: false)
        }

        // Consistency score
        let availableDays = max(1, min(7, thisWeek.count))
        let daysAboveThreshold = thisWeek.filter { $0.ringCompletion >= 0.8 }.count
        let consistencyScore = Double(daysAboveThreshold) / Double(availableDays)

        // Ring completion average
        let ringCompletionAvg7d: Double
        if thisWeek.isEmpty {
            ringCompletionAvg7d = 0.0
        } else {
            ringCompletionAvg7d = thisWeek.map(\.ringCompletion).reduce(0, +) / Double(thisWeek.count)
        }

        // Streak momentum
        let momentum = streakMomentum(current: currentStreak, yesterday: yesterdayStreak)

        return TrendSnapshot(
            stepsTrend: stepsTrend, stepsChangePct: stepsPct,
            sleepTrend: sleepTrend, sleepChangePct: sleepPct,
            workoutFrequencyTrend: workoutFrequencyTrend,
            workoutsThisWeek: workoutsThisWeek, workoutsLastWeek: workoutsLastWeek,
            consistencyScore: consistencyScore, streakMomentum: momentum,
            waterTrend: waterTrend, waterChangePct: waterPct,
            ringCompletionAvg7d: ringCompletionAvg7d,
            heartRateTrend: heartRateTrend, heartRateChangePct: heartRatePct,
            computedAt: Date()
        )
    }

    // MARK: - Private Helpers

    private func computeTrend(
        thisWeek: [Double],
        lastWeek: [Double],
        insufficient: Bool,
        invertDirection: Bool
    ) -> (TrendDirection, Int) {
        guard !insufficient, !lastWeek.isEmpty else {
            return (.stable, 0)
        }

        let thisAvg = thisWeek.isEmpty ? 0.0 : thisWeek.reduce(0, +) / Double(thisWeek.count)
        let lastAvg = lastWeek.reduce(0, +) / Double(lastWeek.count)

        guard lastAvg != 0 else { return (.stable, 0) }

        let changePct = Int(((thisAvg - lastAvg) / lastAvg) * 100)
        return (direction(from: changePct, inverted: invertDirection), changePct)
    }

    private func direction(from changePct: Int, inverted: Bool) -> TrendDirection {
        let effective = inverted ? -changePct : changePct
        if effective > 10 { return .improving }
        if effective < -10 { return .declining }
        return .stable
    }

    private func streakMomentum(current: Int, yesterday: Bool) -> StreakMomentum {
        if current >= 3 { return .building }
        if current >= 1 { return .holding }
        if yesterday { return .breaking }
        return .broken
    }
}
