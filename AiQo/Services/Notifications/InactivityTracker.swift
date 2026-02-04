import Foundation

final class InactivityTracker {
    static let shared = InactivityTracker()
    
    private let lastActiveKey = "aiqo.inactivity.lastActiveDate"
    
    private init() {}
    
    // تسجل أن المستخدم تحرك الآن
    func markActive() {
        UserDefaults.standard.set(Date(), forKey: lastActiveKey)
    }
    
    // ترجع عدد الدقائق من آخر حركة (حتى لو التطبيق انغلق ورجع انفتح)
    var currentInactivityMinutes: Int {
        let lastDate = UserDefaults.standard.object(forKey: lastActiveKey) as? Date ?? Date()
        let diff = Date().timeIntervalSince(lastDate)
        return Int(diff / 60)
    }
}
