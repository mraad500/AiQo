import Foundation
import UserNotifications

final class ActivityNotificationEngine {

    static let shared = ActivityNotificationEngine()
    private init() {}

    #if DEBUG
    private let isNotificationDebugMode = true
    #else
    private let isNotificationDebugMode = false
    #endif

    private let lastProgressKey = "aiqo.activity.lastProgress"
    private let lastGoalCompletedDateKey = "aiqo.activity.lastGoalCompletedDate"

    // ✅ الدالة الرئيسية: لازم تستدعيها كل ما تتحدث بيانات الصحة
    func evaluateAndSendIfNeeded(
        steps: Int,
        calories: Double,
        stepsGoal: Int,
        caloriesGoal: Double,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) {
        // 1. حساب الخمول
        let inactivityMinutes = InactivityTracker.shared.currentInactivityMinutes
        
        // 2. حساب التقدم
        let stepsProgress = getActivityPercentage(current: Double(steps), goal: Double(stepsGoal))
        let caloriesProgress = getActivityPercentage(current: calories, goal: caloriesGoal)
        let progress = max(stepsProgress, caloriesProgress)

        print("📊 [AiQo ENG] Progress: \(String(format: "%.2f", progress)), Inactive: \(inactivityMinutes)m")

        // 3. اتخاذ القرار
        guard let type = getNotificationTypeBasedOnProgress(
            progress: progress,
            inactivityMinutes: inactivityMinutes
        ) else { return }

        // 4. منع التكرار لرسالة "اكتمل الهدف"
        if type == .goalCompleted, hasSentGoalCompletedToday() { return }

        // 5. جلب النص المناسب من المخزن
        guard let notification = NotificationRepository.shared.getNotification(
            type: type,
            gender: gender,
            language: language
        ) else { return }

        // 6. الإرسال الفعلي
        print("🚀 [AiQo ENG] Sending: \(notification.text)")
        NotificationService.shared.sendImmediateNotification(body: notification.text, type: type.rawValue)

        if type == .goalCompleted {
            markGoalCompletedSent()
        }
    }

    // ... (باقي دوال الـ Logic والـ Percentage تبقى نفسها) ...
    // فقط تأكد أن دالة getNotificationTypeBasedOnProgress موجودة كما في ملفك الأصلي
    
    private func getActivityPercentage(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.5)
    }
    
    private func getNotificationTypeBasedOnProgress(progress: Double, inactivityMinutes: Int) -> ActivityNotificationType? {
        // استخدم نفس المنطق اللي بملفك الأصلي (Production/Debug)
        // هذا الكود مختصر للتذكير:
        if progress >= 1.0 { return .goalCompleted }
        if progress >= 0.6 && progress < 0.9 { return .almostThere }
        
        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: lastProgressKey)
        defaults.set(progress, forKey: lastProgressKey)
        
        // منطق الخمول
        let threshold = isNotificationDebugMode ? 2 : 60 // دقيقتين للتجربة، 60 دقيقة للحقيقة
        if inactivityMinutes >= threshold, progress <= last {
            return .moveNow
        }
        
        return nil
    }

    private func hasSentGoalCompletedToday() -> Bool {
        guard let date = UserDefaults.standard.object(forKey: lastGoalCompletedDateKey) as? Date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func markGoalCompletedSent() {
        UserDefaults.standard.set(Date(), forKey: lastGoalCompletedDateKey)
    }
}
