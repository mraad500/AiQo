import Foundation

final class InactivityTracker {
    static let shared = InactivityTracker()
    
    private var lastActiveDate: Date = Date()
    
    private init() {}
    
    func markActive() {
        lastActiveDate = Date()
    }
    
    var currentInactivityMinutes: Int {
        let diff = Date().timeIntervalSince(lastActiveDate)
        return Int(diff / 60)
    }
}
