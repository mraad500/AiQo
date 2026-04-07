import WidgetKit
import SwiftUI

struct AiQoProvider: TimelineProvider {

    // ✅ نفس الـ App Group اللي عندك بالـ Signing & Capabilities
    private let suiteName = "group.aiqo"

    func placeholder(in context: Context) -> AiQoEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (AiQoEntry) -> Void) {
        completion(loadEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AiQoEntry>) -> Void) {
        let entry = loadEntry(date: Date())

        // تحديث كل 15 دقيقة (تقدر تغيّره)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    // MARK: - Load from App Group

    private func loadEntry(date: Date) -> AiQoEntry {
        let shared = UserDefaults(suiteName: suiteName)

        let steps = shared?.integer(forKey: "aiqo_steps") ?? 0
        let calories = shared?.integer(forKey: "aiqo_active_cal") ?? 0
        let standPercent = shared?.integer(forKey: "aiqo_stand_percent") ?? 0
        let rawStepsGoal = shared?.integer(forKey: "aiqo_steps_goal") ?? 0
        let goal = rawStepsGoal > 0 ? rawStepsGoal : 10000
        let rawCaloriesGoal = shared?.integer(forKey: "aiqo_active_cal_goal") ?? 0
        let caloriesGoal = rawCaloriesGoal > 0 ? rawCaloriesGoal : 400

        let bpm = shared?.integer(forKey: "aiqo_bpm") ?? 0
        let km = shared?.double(forKey: "aiqo_km") ?? 0

        let progress = goal > 0 ? Double(steps) / Double(goal) : 0

        return AiQoEntry(
            date: date,
            steps: steps,
            activeCalories: calories,
            standPercent: standPercent,
            stepsGoal: goal,
            caloriesGoal: caloriesGoal,
            progress: progress,
            heartRate: bpm,
            distanceKm: km
        )
    }
}
