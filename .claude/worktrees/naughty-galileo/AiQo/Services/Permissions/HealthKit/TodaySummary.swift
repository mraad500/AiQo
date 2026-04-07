import Foundation

struct TodaySummary: Sendable {
    let steps: Double
    let activeKcal: Double
    let standPercent: Double
    let waterML: Double
    let sleepHours: Double
    let distanceMeters: Double

    static let zero = TodaySummary(
        steps: 0,
        activeKcal: 0,
        standPercent: 0,
        waterML: 0,
        sleepHours: 0,
        distanceMeters: 0
    )
}

struct AllTimeSummary: Sendable {
    let steps: Double
    let activeKcal: Double
    let distanceMeters: Double
    let waterML: Double
    let sleepHours: Double
    let standHours: Double

    static let zero = AllTimeSummary(
        steps: 0,
        activeKcal: 0,
        distanceMeters: 0,
        waterML: 0,
        sleepHours: 0,
        standHours: 0
    )
}
