import Foundation

/// Determines whether the current time falls in the user's quiet window.
/// Defaults: 22:00 - 07:00 local. Respects user preferences if set.
public actor QuietHoursManager {
    public static let shared = QuietHoursManager()

    private var startHour: Int = 22
    private var endHour: Int = 7

    private init() {}

    /// Set the quiet window. start=22, end=7 means 10pm→7am.
    public func configure(startHour: Int, endHour: Int) {
        self.startHour = max(0, min(23, startHour))
        self.endHour = max(0, min(23, endHour))
    }

    public func isQuietNow(now: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        // Overnight window (e.g., 22-7): hour >= 22 OR hour < 7
        if startHour > endHour {
            return hour >= startHour || hour < endHour
        }
        // Same-day window (edge case: e.g., 13-14): startHour <= hour < endHour
        return hour >= startHour && hour < endHour
    }

    /// Next wake time in local time (used to defer quiet-hour notifications).
    public func nextWakeDate(after now: Date = Date()) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = endHour
        comps.minute = 0
        comps.second = 0
        let todayEnd = cal.date(from: comps) ?? now
        if todayEnd > now {
            return todayEnd
        }
        return cal.date(byAdding: .day, value: 1, to: todayEnd) ?? now
    }
}
