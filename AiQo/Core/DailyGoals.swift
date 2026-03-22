import Foundation   // ⬅️ أهم سطر

struct DailyGoals: Codable {
    var steps: Int
    var activeCalories: Double   // تقدر تخليها intake إذا تحب
}

final class GoalsStore {
    static let shared = GoalsStore()

    private let key = "aiqo.dailyGoals"
    private let appGroupDefaults = UserDefaults(suiteName: "group.aiqo")

    var current: DailyGoals {
        get {
            if let data = UserDefaults.standard.data(forKey: key),
               let goals = try? JSONDecoder().decode(DailyGoals.self, from: data) {
                return goals
            }
            // قيم افتراضية لليوم الأول
            return DailyGoals(steps: 8000, activeCalories: 400)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            }
            // Sync to App Group for widgets
            syncToAppGroup(newValue)
        }
    }

    /// Sync goals to App Group UserDefaults so widgets can read them
    private func syncToAppGroup(_ goals: DailyGoals) {
        appGroupDefaults?.set(goals.steps, forKey: "widget_steps_goal")
        appGroupDefaults?.set(goals.activeCalories, forKey: "widget_calories_goal")
    }

    /// Called on app launch to ensure App Group is up-to-date
    func syncCurrentGoalsToAppGroup() {
        syncToAppGroup(current)
    }
}
