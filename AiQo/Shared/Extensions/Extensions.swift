import Foundation
import HealthKit

// تنسيق وقت للواجهات
extension TimeInterval {
    var aiqoClockString: String {
        let total = Int(self)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// بداية اليوم
extension Date {
    var aiqoStartOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

// HKHealthStore مشترك لو حبيت تستخدمه بنفس الشكل بكل مكان
extension HKHealthStore {
    static let aiqoShared = HKHealthStore()
}
