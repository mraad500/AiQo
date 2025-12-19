import Foundation

struct WorkoutLiveMetrics: Codable, Equatable {
    var elapsed: TimeInterval      // ثواني
    var distanceKm: Double         // كم
    var activeCalories: Double     // kcal
    var bloodOxygenPercent: Double?
}
