import Foundation

nonisolated struct BioSnapshot: Codable, Hashable, Sendable {
    let timestamp: Date
    let stepsBucketed: Int
    let heartRateBucketed: Int?
    let hrvBucketed: Int?
    let sleepHoursBucketed: Double?
    let caloriesBucketed: Int
    let timeOfDay: TimeOfDay
    let dayOfWeek: Int
    let isFasting: Bool

    enum TimeOfDay: String, Codable, Sendable {
        case dawn
        case morning
        case midday
        case afternoon
        case evening
        case night
        case lateNight
    }
}

nonisolated struct EmotionalSnapshot: Codable, Hashable, Sendable {
    let primaryMood: EmotionKind?
    let intensity: Double
    let confidence: Double
    let signals: [MoodSignalSummary]
}

nonisolated struct MoodSignalSummary: Codable, Hashable, Sendable {
    let kind: String
    let value: Double
}
