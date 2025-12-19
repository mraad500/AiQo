import Foundation

/// لايف مِتريكس من تمرين الساعة → للتطبيق

/// ملخّص نشاط اليوم – يعرضه التطبيق
struct DailyActivitySummary: Codable, Equatable {
    var date: Date
    var steps: Int
    var moveCalories: Double
    var distanceKm: Double
}
