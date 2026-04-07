import Foundation

// MARK: - User's Active Project

struct LegendaryProject: Identifiable, Codable {
    let id: String
    let recordId: String
    let startDate: Date
    let targetWeeks: Int
    var weeklyCheckpoints: [WeeklyCheckpoint]
    var dailyTasks: [DailyTask]
    var personalBest: Double
    var isCompleted: Bool

    /// Current week number (1-based)
    var currentWeek: Int {
        let daysSinceStart = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return min(max(daysSinceStart / 7 + 1, 1), targetWeeks)
    }

    /// Progress fraction 0…1
    var progressFraction: Double {
        guard targetWeeks > 0 else { return 0 }
        return Double(currentWeek) / Double(targetWeeks)
    }
}

// MARK: - Weekly Checkpoint

struct WeeklyCheckpoint: Identifiable, Codable {
    let id: String
    let weekNumber: Int
    var recordedValue: Double?
    var date: Date?
}

// MARK: - Daily Task

struct DailyTask: Identifiable, Codable {
    let id: String
    let dayNumber: Int
    let titleAr: String
    let targetValue: String
    var isCompleted: Bool
}
