import Foundation
import SwiftData

/// A consolidated 7-day report. Permanent. Shown in the "ذاكرة الأسبوع" section.
/// Does NOT count toward the user-facing Captain Memory limit (separate UI section).
@Model
final class WeeklyReportEntry {
    #Index<WeeklyReportEntry>([\.weekNumber], [\.generatedAt])

    var id: UUID
    @Attribute(.unique) var weekNumber: Int    // 1, 2, 3 ... per user, monotonic from trial start
    var rangeStart: Date
    var rangeEnd: Date
    var generatedAt: Date

    var avgSteps: Int
    var avgCalories: Int
    var avgSleepHours: Double
    var avgRestingHeartRate: Double?
    var totalWorkoutMinutes: Int
    var workoutCount: Int

    var bestDayLabelAr: String?
    var bestDayLabelEn: String?
    var summaryAr: String
    var summaryEn: String

    init(
        id: UUID = UUID(),
        weekNumber: Int,
        rangeStart: Date,
        rangeEnd: Date,
        generatedAt: Date = Date(),
        avgSteps: Int,
        avgCalories: Int,
        avgSleepHours: Double,
        avgRestingHeartRate: Double? = nil,
        totalWorkoutMinutes: Int,
        workoutCount: Int,
        bestDayLabelAr: String? = nil,
        bestDayLabelEn: String? = nil,
        summaryAr: String,
        summaryEn: String
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.generatedAt = generatedAt
        self.avgSteps = avgSteps
        self.avgCalories = avgCalories
        self.avgSleepHours = avgSleepHours
        self.avgRestingHeartRate = avgRestingHeartRate
        self.totalWorkoutMinutes = totalWorkoutMinutes
        self.workoutCount = workoutCount
        self.bestDayLabelAr = bestDayLabelAr
        self.bestDayLabelEn = bestDayLabelEn
        self.summaryAr = summaryAr
        self.summaryEn = summaryEn
    }
}
