import Foundation

enum AiQoSharedStore {
    // غيرها حسب App Group عندك
    static let suiteName = "group.aiqo"
    
    static let stepsKey = "aiqo_steps"
    static let calKey   = "aiqo_active_cal"
    static let goalKey  = "aiqo_steps_goal"
    
    static func read() -> (steps: Int, cal: Int, goal: Int) {
        guard let shared = UserDefaults(suiteName: suiteName) else {
            // إذا App Group مو متفعل، رجّع قيم افتراضية حتى لا يطلع أبيض
            return (steps: 8500, cal: 450, goal: 10000)
        }
        
        let steps = shared.integer(forKey: stepsKey)
        let cal   = shared.integer(forKey: calKey)
        let goal  = max(shared.integer(forKey: goalKey), 1)
        
        // إذا بعدك ما خزنت شي، لا ترجع أصفار تخلي الويدجت فاضي
        let safeSteps = (steps == 0 ? 8500 : steps)
        let safeCal   = (cal == 0 ? 450 : cal)
        let safeGoal  = (goal == 0 ? 10000 : goal)
        
        return (safeSteps, safeCal, safeGoal)
    }
}
