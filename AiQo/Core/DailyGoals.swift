import Foundation   // ⬅️ أهم سطر

struct DailyGoals: Codable {
    var steps: Int
    var activeCalories: Double   // تقدر تخليها intake إذا تحب
}

final class GoalsStore {
    static let shared = GoalsStore()
    
    private let key = "aiqo.dailyGoals"
    
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
        }
    }
}
