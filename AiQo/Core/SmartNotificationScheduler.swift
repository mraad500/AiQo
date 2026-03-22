import Foundation
import UserNotifications

/// يجدول إشعارات ذكية حسب سلوك المستخدم — بشخصية كابتن حمّودي
final class SmartNotificationScheduler {
    static let shared = SmartNotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Schedule All Smart Notifications

    /// يجدول كل الإشعارات الذكية — ينادى من AppDelegate
    func scheduleSmartNotifications() {
        Task {
            let granted = await requestPermission()
            guard granted else { return }

            scheduleWaterReminders()
            scheduleWorkoutMotivation()
            scheduleSleepReminder()
            scheduleStreakProtection()
            scheduleWeeklyReportReminder()
        }
    }

    // MARK: - 💧 تذكير شرب الماء

    /// تذكير كل ساعتين من 8 صباحاً لـ 10 مساءً
    private func scheduleWaterReminders() {
        cancelCategory("water_reminder")

        let messages = [
            "\(UserProfileStore.shared.current.name)! جسمك يحتاج ماء 💧 اشرب كوب الحين",
            "وقت الماء! 💧 خلّي جسمك رطب",
            "كابتن حمّودي يقول: اشرب ماي يا بطل 💧",
            "هيدريشن تايم! 💧 كوب ماء وكمّل يومك",
            "ما تنسى الماء! جسمك يشكرك 💧",
        ]

        let hours = [10, 12, 14, 16, 18, 20] // كل ساعتين

        for (index, hour) in hours.enumerated() {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "💧 وقت الماء"
            content.body = messages[index % messages.count]
            content.sound = .default
            content.categoryIdentifier = "water_reminder"
            content.threadIdentifier = "aiqo.hydration"

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "water_reminder_\(hour)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - 💪 تحفيز التمرين

    /// إشعار يومي بوقت التمرين المفضل
    private func scheduleWorkoutMotivation() {
        cancelCategory("workout_motivation")

        let messages = [
            "يلا يا بطل! وقت التمرين 💪 جسمك ينتظرك",
            "كابتن حمّودي جاهز! يلا نتمرن 🔥",
            "30 دقيقة بس وبتحس بفرق هائل 💪",
            "التمرين اليوم يبني جسم الغد 🏋️",
            "ما في عذر اليوم! يلا قوم 🔥",
            "جسمك يستاهل أحسن نسخة منك 💪",
            "كابتن حمّودي يقول: يلا نشغّل المحرك! 🚀"
        ]

        // إشعار يومي الساعة 5 العصر
        var dateComponents = DateComponents()
        dateComponents.hour = 17
        dateComponents.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "💪 وقت التمرين!"
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default
        content.categoryIdentifier = "workout_motivation"
        content.threadIdentifier = "aiqo.workout"

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "workout_motivation_daily",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - 😴 تذكير النوم

    /// تذكير بوقت النوم
    private func scheduleSleepReminder() {
        cancelCategory("sleep_reminder")

        var dateComponents = DateComponents()
        dateComponents.hour = 22
        dateComponents.minute = 30

        let content = UNMutableNotificationContent()
        content.title = "😴 وقت النوم"
        content.body = "كابتن حمّودي يقول: النوم أهم من التمرين! خلّي جسمك يسترد. تصبح على خير 🌙"
        content.sound = .default
        content.categoryIdentifier = "sleep_reminder"
        content.threadIdentifier = "aiqo.sleep"

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "sleep_reminder_nightly",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - 🔥 حماية الـ Streak

    /// إشعار المساء إذا المستخدم ما حقق هدفه بعد
    private func scheduleStreakProtection() {
        cancelCategory("streak_protection")

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "🔥 الـ Streak بخطر!"
        content.body = "لسه ما حققت هدفك اليوم! مشي سريع 15 دقيقة يكفي. لا تخلي الـ streak ينكسر 💪"
        content.sound = .default
        content.categoryIdentifier = "streak_protection"
        content.threadIdentifier = "aiqo.streak"
        content.interruptionLevel = .timeSensitive

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "streak_protection_evening",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - 📊 تذكير التقرير الأسبوعي

    /// إشعار كل جمعة بالتقرير
    private func scheduleWeeklyReportReminder() {
        cancelCategory("weekly_report")

        var dateComponents = DateComponents()
        dateComponents.weekday = 6  // الجمعة
        dateComponents.hour = 10
        dateComponents.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "📊 تقريرك الأسبوعي جاهز!"
        content.body = "كابتن حمّودي حضّر ملخص أسبوعك. تعال شوف شلون كان أداءك! 🏆"
        content.sound = .default
        content.categoryIdentifier = "weekly_report"
        content.threadIdentifier = "aiqo.report"

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly_report_friday",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // MARK: - Helpers

    private func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    private func cancelCategory(_ category: String) {
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .filter { $0.content.categoryIdentifier == category }
                .map(\.identifier)
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// يلغي كل الإشعارات الذكية
    func cancelAllSmartNotifications() {
        let categories = ["water_reminder", "workout_motivation", "sleep_reminder", "streak_protection", "weekly_report"]
        for category in categories {
            cancelCategory(category)
        }
    }
}
