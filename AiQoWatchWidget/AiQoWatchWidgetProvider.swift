import WidgetKit
import Foundation

struct AiQoWatchEntry: TimelineEntry {
    let date: Date
    let activeCalories: Int
    let standPercent: Int
    let heartRate: Int
    let distanceKm: Double
    let weeklyTotalKm: Double
    let weeklyDailyKm: [Double]
}

struct AiQoWatchWidgetProvider: TimelineProvider {
    private let suiteName = "group.aiqo"

    func placeholder(in context: Context) -> AiQoWatchEntry {
        AiQoWatchEntry(
            date: .now,
            activeCalories: 857,
            standPercent: 77,
            heartRate: 101,
            distanceKm: 2.30,
            weeklyTotalKm: 23.06,
            weeklyDailyKm: [2.1, 2.5, 2.9, 3.2, 3.5, 4.1, 4.76]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AiQoWatchEntry) -> Void) {
        completion(loadEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AiQoWatchEntry>) -> Void) {
        let entry = loadEntry(date: .now)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry(date: Date) -> AiQoWatchEntry {
        let shared = UserDefaults(suiteName: suiteName)
        let daily = (shared?.array(forKey: "aiqo_week_daily_km") ?? []).compactMap { value -> Double? in
            if let d = value as? Double { return d }
            if let n = value as? NSNumber { return n.doubleValue }
            return nil
        }
        let weekTotal = shared?.double(forKey: "aiqo_week_km_total") ?? daily.reduce(0, +)
        let currentKm = shared?.double(forKey: "aiqo_km_current")
        let fallbackKm = shared?.double(forKey: "aiqo_km")
        return AiQoWatchEntry(
            date: date,
            activeCalories: shared?.integer(forKey: "aiqo_active_cal") ?? 0,
            standPercent: shared?.integer(forKey: "aiqo_stand_percent") ?? 0,
            heartRate: shared?.integer(forKey: "aiqo_bpm") ?? 0,
            distanceKm: currentKm ?? fallbackKm ?? 0,
            weeklyTotalKm: weekTotal,
            weeklyDailyKm: daily
        )
    }
}
