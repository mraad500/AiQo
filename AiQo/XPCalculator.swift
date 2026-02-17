import Foundation
import HealthKit

struct XPCalculator {
    struct XPResult {
        let totalXP: Int
        let truthNumber: Int
        let activeCalories: Int
        let durationMinutes: Int
        let luckyNumber: Int
        let totalHeartbeats: Int
        let heartbeatDigits: [Int]
    }

    static func calculateCoins(
        steps: Int,
        activeCalories: Double,
        averageHeartRate: Double,
        durationMinutes: Int
    ) -> Int {
        var minedCoins = 0

        // 100 steps = 1 coin
        minedCoins += steps / 100
        // 50 active calories = 1 coin
        minedCoins += Int(activeCalories / 50)
        // Turbo bonus for workout intensity
        if averageHeartRate > 115 {
            minedCoins += durationMinutes * 2
        }

        return minedCoins
    }

    static func calculateSessionStats(
        samples: [HKQuantitySample],
        duration: TimeInterval,
        averageHeartRate: Double,
        activeCalories: Double
    ) -> XPResult {
        let calories = Int(activeCalories)
        let minutes = Int(duration / 60)
        let truthNumber = calories + minutes

        var totalBeats: Double = 0

        if !samples.isEmpty {
            let sorted = samples.sorted { $0.startDate < $1.startDate }

            for idx in sorted.indices {
                let sample = sorted[idx]
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

                let segmentDuration: TimeInterval
                if idx < sorted.count - 1 {
                    segmentDuration = sorted[idx + 1].startDate.timeIntervalSince(sample.startDate)
                } else {
                    segmentDuration = 5
                }

                let safeDuration = min(segmentDuration, 15)
                totalBeats += (bpm / 60) * safeDuration
            }
        } else {
            totalBeats = averageHeartRate * Double(minutes)
        }

        let totalHeartbeats = Int(totalBeats)
        let heartbeatDigits = String(totalHeartbeats).compactMap(\.wholeNumberValue)
        let luckyNumber = heartbeatDigits.reduce(0, +)
        let totalXP = truthNumber + luckyNumber

        return XPResult(
            totalXP: totalXP,
            truthNumber: truthNumber,
            activeCalories: calories,
            durationMinutes: minutes,
            luckyNumber: luckyNumber,
            totalHeartbeats: totalHeartbeats,
            heartbeatDigits: heartbeatDigits
        )
    }
}
