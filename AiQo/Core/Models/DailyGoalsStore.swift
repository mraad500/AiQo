import Foundation

// موديل خاص بأهداف النشاط اليومية (خطوات + سعرات)
// سميناه ActivityDailyGoals حتى ما يتعارض ويا DailyGoals الموجود مسبقاً بالمشروع
struct ActivityDailyGoals: Codable {
    var steps: Int
    var calories: Int
}

final class DailyGoalsStore {
    static let shared = DailyGoalsStore()
    
    private let defaults = UserDefaults.standard
    private let key = "aiqo.dailyGoals.v1"
    
    private init() {}
    
    var current: ActivityDailyGoals {
        get {
            if let data = defaults.data(forKey: key),
               let decoded = try? JSONDecoder().decode(ActivityDailyGoals.self, from: data) {
                return decoded
            }
            // قيم افتراضية مبدئية
            return ActivityDailyGoals(steps: 8000, calories: 2200)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }
}
