import Foundation

struct BioSnapshot: Codable, Hashable {
    let timestamp: Date
    let stepsBucketed: Int
    let heartRateBucketed: Int?
    let hrvBucketed: Int?
    let sleepHoursBucketed: Double?
    let caloriesBucketed: Int
    let timeOfDay: TimeOfDay
    let dayOfWeek: Int
    let isFasting: Bool

    enum TimeOfDay: String, Codable {
        case dawn
        case morning
        case midday
        case afternoon
        case evening
        case night
        case lateNight
    }
}

struct EmotionalSnapshot: Codable, Hashable {
    let primaryMood: EmotionKind?
    let intensity: Double
    let confidence: Double
    let signals: [MoodSignalSummary]
}

struct MoodSignalSummary: Codable, Hashable {
    let kind: String
    let value: Double
}
