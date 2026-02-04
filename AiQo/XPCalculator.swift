import Foundation
import HealthKit
import SwiftUI

// MARK: - XP Logic Engine 🧠 (Truth & Lucky System)
struct XPCalculator {
    
    // هيكل النتيجة النهائية
    struct XPResult {
        let totalXP: Int
        let truthNumber: Int
        let activeCalories: Int
        let durationMinutes: Int
        let luckyNumber: Int
        let totalHeartbeats: Int
        let heartbeatDigits: [Int]
    }
    
    // MARK: - ⛏️ Mining Logic (نظام التعدين الجديد)
    /// دالة حساب العملات بناءً على الجهد
    static func calculateCoins(
        steps: Int,
        activeCalories: Double,
        averageHeartRate: Double,
        durationMinutes: Int
    ) -> Int {
        
        var minedCoins = 0
        
        // 1. المشي: كل 100 خطوة = 1 عملة AiQo
        let stepCoins = steps / 100
        minedCoins += stepCoins
        
        // 2. الحرق: كل 50 سعرة = 1 عملة AiQo
        let calorieCoins = Int(activeCalories / 50)
        minedCoins += calorieCoins
        
        // 3. التعدين المكثف (Turbo Mining) 🔥
        // هذا يتفعل فقط اثناء التمرين (Workouts) وليس المشي العادي
        if averageHeartRate > 115 {
            let turboBonus = durationMinutes * 2
            minedCoins += turboBonus
        }
        
        return minedCoins
    }
    
    // MARK: - Legacy XP Logic
    static func calculateSessionStats(
        samples: [HKQuantitySample],
        duration: TimeInterval,
        averageHeartRate: Double,
        activeCalories: Double
    ) -> XPResult {
        
        // 1. حساب "رقم الحق"
        let calories = Int(activeCalories)
        let minutes = Int(duration / 60)
        let truthNumber = calories + minutes
        
        // 2. حساب إجمالي عدد دقات القلب
        var totalBeats: Double = 0.0
        
        if !samples.isEmpty {
            let sortedSamples = samples.sorted { $0.startDate < $1.startDate }
            
            for i in 0..<sortedSamples.count {
                let sample = sortedSamples[i]
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                
                let sampleDuration: TimeInterval
                if i < sortedSamples.count - 1 {
                    sampleDuration = sortedSamples[i+1].startDate.timeIntervalSince(sample.startDate)
                } else {
                    sampleDuration = 5.0
                }
                
                let safeDuration = min(sampleDuration, 15.0)
                let beatsInSegment = (bpm / 60.0) * safeDuration
                totalBeats += beatsInSegment
            }
        } else {
            totalBeats = averageHeartRate * Double(minutes)
        }
        
        let totalHeartbeatsInt = Int(totalBeats)
        
        // 3. حساب "رقم الحظ"
        let digits = String(totalHeartbeatsInt).compactMap { $0.wholeNumberValue }
        let luckyNumber = digits.reduce(0, +)
        
        // 4. النتيجة النهائية
        let totalXP = truthNumber + luckyNumber
        
        return XPResult(
            totalXP: totalXP,
            truthNumber: truthNumber,
            activeCalories: calories,
            durationMinutes: minutes,
            luckyNumber: luckyNumber,
            totalHeartbeats: totalHeartbeatsInt,
            heartbeatDigits: digits
        )
    }
}
