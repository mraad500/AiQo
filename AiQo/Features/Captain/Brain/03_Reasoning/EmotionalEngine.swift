// ===============================================
// File: EmotionalStateEngine.swift
// Phase 1 — Captain Hamoudi Brain V2
// Computes estimated emotional/energy state from
// biometric signals. 100% on-device. No PII.
// ===============================================

import Foundation

// MARK: - Models

enum EstimatedMood: String, Codable, Sendable {
    case highEnergy = "high_energy"
    case neutral = "neutral"
    case lowEnergy = "low_energy"
    case stressed = "stressed"
    case recovering = "recovering"
}

enum RecommendedTone: String, Codable, Sendable {
    case energetic
    case neutral
    case gentle
    case celebratory
}

struct EmotionalState: Codable, Sendable {
    let estimatedMood: EstimatedMood
    let confidence: Double
    let signals: [String]
    let recommendedTone: RecommendedTone
    let computedAt: Date
}

// MARK: - Engine

final class EmotionalStateEngine: Sendable {

    static let shared = EmotionalStateEngine()
    private init() {}

    /// Computes emotional state from available biometric signals.
    /// All computation is on-device. No data leaves the device.
    func evaluate(
        stepsToday: Int,
        steps7DayAvg: Int,
        sleepLastNightHours: Double?,
        sleep7DayAvgHours: Double?,
        restingHeartRate: Double?,
        hrvLatest: Double?,
        hrv7DayAvg: Double?,
        lastWorkoutDate: Date?,
        messageLength: Int?,
        messageTimestamp: Date,
        userPreferredBedtime: String?,
        userPreferredWakeTime: String?
    ) -> EmotionalState {
        var signals: [String] = []

        // 1. Sleep signals
        if let sleepLast = sleepLastNightHours {
            let sleepAvg = sleep7DayAvgHours ?? sleepLast
            if sleepLast < sleepAvg * 0.75 || sleepLast < 5.0 {
                signals.append("poor_sleep")
            }
            if sleepLast >= sleepAvg * 1.1 && sleepLast >= 7.0 {
                signals.append("good_sleep")
            }
        }

        // 2. Step signals
        if steps7DayAvg > 0 {
            if stepsToday < Int(Double(steps7DayAvg) * 0.6) {
                signals.append("below_avg_steps")
            }
            if stepsToday > Int(Double(steps7DayAvg) * 1.3) {
                signals.append("above_avg_steps")
            }
        }

        // 3. Heart rate signal
        if let rhr = restingHeartRate, rhr > 85 {
            signals.append("high_resting_hr")
        }

        // 4. HRV signals
        if let hrvNow = hrvLatest, let hrvAvg = hrv7DayAvg {
            if hrvNow < hrvAvg * 0.7 {
                signals.append("low_hrv")
            }
            if hrvNow > hrvAvg * 1.2 {
                signals.append("high_hrv")
            }
        }

        // 5. Late night message
        if let bedtime = userPreferredBedtime, let wakeTime = userPreferredWakeTime {
            if isWithinSleepWindow(
                timestamp: messageTimestamp,
                bedtime: bedtime,
                wakeTime: wakeTime
            ) {
                signals.append("late_night_message")
            }
        }

        // 6. Short message
        if let length = messageLength, length < 5 {
            signals.append("short_message")
        }

        // 7. Workout signals
        if let lastWorkout = lastWorkoutDate {
            let daysSince = Calendar.current.dateComponents(
                [.day], from: lastWorkout, to: messageTimestamp
            ).day ?? Int.max
            if daysSince > 3 {
                signals.append("no_recent_workout")
            }
            if daysSince == 0 || messageTimestamp.timeIntervalSince(lastWorkout) < 86400 {
                signals.append("recently_active")
            }
        } else {
            signals.append("no_recent_workout")
        }

        // Mood determination (priority order)
        let mood: EstimatedMood
        if signals.contains("low_hrv") && signals.contains("poor_sleep") {
            mood = .stressed
        } else if signals.contains("poor_sleep") && signals.contains("below_avg_steps") {
            mood = .lowEnergy
        } else if signals.contains("late_night_message") && signals.contains("poor_sleep") {
            mood = .lowEnergy
        } else if signals.contains("good_sleep") && signals.contains("above_avg_steps") {
            mood = .highEnergy
        } else if signals.contains("high_hrv") && signals.contains("recently_active") {
            mood = .highEnergy
        } else if signals.contains("good_sleep") && signals.contains("below_avg_steps") {
            mood = .recovering
        } else if signals.contains("high_resting_hr") && sleepLastNightHours == nil {
            mood = .stressed
        } else {
            mood = .neutral
        }

        // Tone mapping
        var tone: RecommendedTone
        switch mood {
        case .highEnergy:  tone = .energetic
        case .neutral:     tone = .neutral
        case .lowEnergy:   tone = .gentle
        case .stressed:    tone = .gentle
        case .recovering:  tone = .neutral
        }

        // Celebratory override: 3+ strong positive signals = exceptional day
        let strongPositiveSignals = ["good_sleep", "above_avg_steps", "high_hrv", "recently_active"]
        let strongPositiveCount = signals.filter { strongPositiveSignals.contains($0) }.count
        if strongPositiveCount >= 3 {
            tone = .celebratory
        }

        // Confidence calculation
        let optionalInputs: [Any?] = [
            sleepLastNightHours, sleep7DayAvgHours,
            restingHeartRate, hrvLatest, hrv7DayAvg,
            lastWorkoutDate, messageLength,
            userPreferredBedtime, userPreferredWakeTime
        ]
        let nonNilCount = optionalInputs.compactMap { $0 }.count

        var confidence = 0.5
        confidence += Double(nonNilCount) * 0.08
        confidence = min(confidence, 0.95)
        if nonNilCount < 3 {
            confidence = min(confidence, 0.4)
        }

        return EmotionalState(
            estimatedMood: mood,
            confidence: confidence,
            signals: signals,
            recommendedTone: tone,
            computedAt: Date()
        )
    }

    // MARK: - Private Helpers

    private func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func isWithinSleepWindow(
        timestamp: Date,
        bedtime: String,
        wakeTime: String
    ) -> Bool {
        guard let bed = parseTime(bedtime),
              let wake = parseTime(wakeTime) else {
            return false
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: timestamp)
        let minute = calendar.component(.minute, from: timestamp)

        let tsMinutes = hour * 60 + minute
        let bedMinutes = bed.hour * 60 + bed.minute
        let wakeMinutes = wake.hour * 60 + wake.minute

        if bedMinutes <= wakeMinutes {
            // Same-day window (e.g. 22:00 - 06:00 does NOT apply here;
            // this is e.g. 01:00 - 09:00)
            return tsMinutes >= bedMinutes && tsMinutes < wakeMinutes
        } else {
            // Overnight window (e.g. 23:00 - 07:00 or 02:30 - 12:30)
            return tsMinutes >= bedMinutes || tsMinutes < wakeMinutes
        }
    }
}
