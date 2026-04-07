import Foundation
import Combine

/// يتابع streak الالتزام اليومي — كل يوم المستخدم يحقق أهدافه يزيد الـ streak
/// الأهداف: 5000+ خطوات أو تمرين واحد أو 30+ دقيقة نشاط
final class StreakManager: ObservableObject {
    static let shared = StreakManager()

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var lastActiveDate: Date?
    @Published private(set) var todayCompleted: Bool = false

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let currentStreak = "aiqo.streak.current"
        static let longestStreak = "aiqo.streak.longest"
        static let lastActiveDate = "aiqo.streak.lastActive"
        static let streakHistory = "aiqo.streak.history"
    }

    private init() {
        loadState()
        checkStreakContinuity()
    }

    // MARK: - Public

    /// يسجّل يوم نشط — ينادى لما المستخدم يحقق هدف يومي
    func markTodayAsActive() {
        let today = Calendar.current.startOfDay(for: Date())

        // إذا سبق سجّلنا اليوم
        if let last = lastActiveDate, Calendar.current.isDate(last, inSameDayAs: today) {
            todayCompleted = true
            return
        }

        // هل اليوم يوم متتالي؟
        if let last = lastActiveDate {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
            if Calendar.current.isDate(last, inSameDayAs: yesterday) {
                // يوم متتالي — كمّل الـ streak
                currentStreak += 1
            } else {
                // انقطع — ابدأ من جديد
                currentStreak = 1
            }
        } else {
            // أول مرة
            currentStreak = 1
        }

        lastActiveDate = today
        todayCompleted = true

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        saveState()
        addToHistory(date: today)
    }

    /// يتحقق هل الـ streak لسه مستمر (يُنادى عند فتح التطبيق)
    func checkStreakContinuity() {
        let today = Calendar.current.startOfDay(for: Date())

        guard let last = lastActiveDate else {
            todayCompleted = false
            return
        }

        if Calendar.current.isDate(last, inSameDayAs: today) {
            todayCompleted = true
            return
        }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        if !Calendar.current.isDate(last, inSameDayAs: yesterday) {
            // انقطع — reset
            currentStreak = 0
            saveState()
        }
        todayCompleted = false
    }

    /// تاريخ الأيام النشطة (آخر 30 يوم)
    var recentHistory: [Date] {
        guard let data = defaults.data(forKey: Keys.streakHistory),
              let dates = try? JSONDecoder().decode([Date].self, from: data) else { return [] }

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return dates.filter { $0 > thirtyDaysAgo }.sorted()
    }

    /// نسبة الالتزام آخر 7 أيام
    var weeklyConsistency: Double {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let activeDays = recentHistory.filter { $0 > sevenDaysAgo }.count
        return Double(activeDays) / 7.0 * 100
    }

    /// رسالة تحفيزية حسب الـ streak
    var motivationMessage: String {
        switch currentStreak {
        case 0: return "ابدأ streak اليوم! 🌱"
        case 1: return "يوم واحد! البداية أحلى شي 💫"
        case 2...3: return "الزخم يبدأ! خلّيه مستمر 🔥"
        case 4...6: return "أسبوع كامل تقريباً! 💪"
        case 7...13: return "أسبوع+ كامل! أنت وحش 🏆"
        case 14...29: return "أسبوعين! هالالتزام أسطوري ⭐️"
        case 30...59: return "شهر كامل! ما يوقفك أحد 🚀"
        case 60...89: return "شهرين! أنت قدوة 👑"
        case 90...364: return "\(currentStreak) يوم! هذا إنجاز تاريخي 🎖️"
        default: return "سنة+! أنت أسطورة حية 🏅"
        }
    }

    #if DEBUG
    func resetStreak() {
        currentStreak = 0
        longestStreak = 0
        lastActiveDate = nil
        todayCompleted = false
        defaults.removeObject(forKey: Keys.streakHistory)
        saveState()
    }
    #endif

    // MARK: - Private

    private func saveState() {
        defaults.set(currentStreak, forKey: Keys.currentStreak)
        defaults.set(longestStreak, forKey: Keys.longestStreak)
        if let date = lastActiveDate {
            defaults.set(date, forKey: Keys.lastActiveDate)
        }
    }

    private func loadState() {
        currentStreak = defaults.integer(forKey: Keys.currentStreak)
        longestStreak = defaults.integer(forKey: Keys.longestStreak)
        lastActiveDate = defaults.object(forKey: Keys.lastActiveDate) as? Date
    }

    private func addToHistory(date: Date) {
        var history = recentHistory
        let startOfDay = Calendar.current.startOfDay(for: date)

        // ما نضيف نفس اليوم مرتين
        if !history.contains(where: { Calendar.current.isDate($0, inSameDayAs: startOfDay) }) {
            history.append(startOfDay)
        }

        // نحتفظ بآخر 90 يوم فقط
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        history = history.filter { $0 > ninetyDaysAgo }

        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: Keys.streakHistory)
        }
    }
}
