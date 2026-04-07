import Foundation

/// نموذج بيانات التقرير الأسبوعي
struct WeeklyReportData: Sendable {
    let weekStartDate: Date
    let weekEndDate: Date

    // البيانات الحالية
    let totalSteps: Int
    let totalCalories: Int
    let totalDistanceKm: Double
    let totalSleepHours: Double
    let totalWaterLiters: Double
    let totalStandHours: Int
    let workoutCount: Int
    let totalWorkoutMinutes: Int

    // بيانات الأسبوع الماضي للمقارنة
    let previousSteps: Int
    let previousCalories: Int
    let previousDistanceKm: Double
    let previousSleepHours: Double
    let previousWaterLiters: Double
    let previousStandHours: Int
    let previousWorkoutCount: Int
    let previousWorkoutMinutes: Int

    // المعدلات اليومية
    var avgStepsPerDay: Int { totalSteps / max(daysInWeek, 1) }
    var avgCaloriesPerDay: Int { totalCalories / max(daysInWeek, 1) }
    var avgSleepPerNight: Double { totalSleepHours / Double(max(daysInWeek, 1)) }
    var avgWaterPerDay: Double { totalWaterLiters / Double(max(daysInWeek, 1)) }

    // البيانات اليومية للشارت
    let dailySteps: [Int]
    let dailyCalories: [Int]

    private var daysInWeek: Int { 7 }

    // نسبة التغيير عن الأسبوع الماضي
    var stepsChange: Double { percentChange(current: totalSteps, previous: previousSteps) }
    var caloriesChange: Double { percentChange(current: totalCalories, previous: previousCalories) }
    var distanceChange: Double { percentChange(current: totalDistanceKm, previous: previousDistanceKm) }
    var sleepChange: Double { percentChange(current: totalSleepHours, previous: previousSleepHours) }
    var waterChange: Double { percentChange(current: totalWaterLiters, previous: previousWaterLiters) }
    var workoutChange: Double { percentChange(current: workoutCount, previous: previousWorkoutCount) }

    /// النتيجة الإجمالية (0-100)
    var overallScore: Int {
        var score = 0
        // خطوات: 10,000 يومياً = 100%
        score += min(Int(Double(avgStepsPerDay) / 10_000.0 * 25), 25)
        // سعرات: 500+ يومياً = 100%
        score += min(Int(Double(avgCaloriesPerDay) / 500.0 * 25), 25)
        // نوم: 7-9 ساعات = 100%
        let sleepScore = avgSleepPerNight >= 7 && avgSleepPerNight <= 9 ? 25 :
                         avgSleepPerNight >= 6 ? 20 :
                         avgSleepPerNight >= 5 ? 15 : 10
        score += sleepScore
        // تمارين: 3+ بالأسبوع = 100%
        score += min(Int(Double(workoutCount) / 3.0 * 25), 25)
        return min(score, 100)
    }

    private func percentChange<T: BinaryInteger>(current: T, previous: T) -> Double {
        guard previous > 0 else { return current > 0 ? 100 : 0 }
        return Double(Int(current) - Int(previous)) / Double(previous) * 100
    }

    private func percentChange<T: BinaryFloatingPoint>(current: T, previous: T) -> Double {
        guard previous > 0 else { return current > 0 ? 100 : 0 }
        return Double(current - previous) / Double(previous) * 100
    }
}

/// عنصر واحد من بطاقات الإحصائيات
struct ReportMetricItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let unit: String
    let icon: String
    let changePercent: Double
    let tint: ReportTint

    enum ReportTint {
        case mint, sand

        var color: (r: Double, g: Double, b: Double) {
            switch self {
            case .mint: return (0.77, 0.94, 0.86)
            case .sand: return (0.97, 0.84, 0.64)
            }
        }
    }
}
