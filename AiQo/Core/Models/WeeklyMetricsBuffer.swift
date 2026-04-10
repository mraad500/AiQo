import Foundation
import SwiftData

/// Daily HealthKit metric snapshot. Buffered for up to 7 days, then consolidated
/// into a WeeklyReportEntry and deleted. Lives in the Captain ModelContainer
/// but does NOT count toward the user-facing Captain Memory limit.
@Model
final class WeeklyMetricsBuffer {
    #Index<WeeklyMetricsBuffer>([\.dayStart])

    var id: UUID
    @Attribute(.unique) var dayStart: Date
    var steps: Int
    var activeCalories: Double
    var restingHeartRate: Double?
    var sleepHours: Double?
    var workoutMinutes: Int
    var workoutCount: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        dayStart: Date,
        steps: Int = 0,
        activeCalories: Double = 0,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil,
        workoutMinutes: Int = 0,
        workoutCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dayStart = dayStart
        self.steps = steps
        self.activeCalories = activeCalories
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
        self.workoutMinutes = workoutMinutes
        self.workoutCount = workoutCount
        self.createdAt = createdAt
    }
}
