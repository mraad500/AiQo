import Foundation
import UserNotifications

final class ActivityNotificationEngine {

    static let shared = ActivityNotificationEngine()
    private init() {}

    // ✅ فعّال بس بالـ DEBUG build
    #if DEBUG
    private let isNotificationDebugMode = true
    #else
    private let isNotificationDebugMode = false
    #endif

    private let lastProgressKey = "aiqo.activity.lastProgress"
    private let lastGoalCompletedDateKey = "aiqo.activity.lastGoalCompletedDate"

    // MAIN ENTRY
    func evaluateAndSendIfNeeded(
        steps: Int,
        calories: Double,
        stepsGoal: Int,
        caloriesGoal: Double,
        inactivityMinutes: Int,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) {

        let stepsProgress = getActivityPercentage(current: Double(steps), goal: Double(stepsGoal))
        let caloriesProgress = getActivityPercentage(current: calories, goal: caloriesGoal)
        let progress = max(stepsProgress, caloriesProgress)

        print("📊 [AiQo ENG] progress=\(progress), inactivity=\(inactivityMinutes), DEBUG=\(isNotificationDebugMode)")

        guard let type = getNotificationTypeBasedOnProgress(
            progress: progress,
            inactivityMinutes: inactivityMinutes
        ) else {
            print("⚠️ [AiQo ENG] No type selected")
            return
        }

        // goalCompleted مرة وحدة باليوم فقط (حتى بالـ debug)
        if type == .goalCompleted, hasSentGoalCompletedToday() {
            print("ℹ️ [AiQo ENG] goalCompleted already sent today")
            return
        }

        guard let notification = NotificationRepository.shared.getNotification(
            type: type,
            gender: gender,
            language: language
        ) else {
            print("⚠️ [AiQo ENG] Repository returned nil notification")
            return
        }

        let text = notification.text

        print("✅ [AiQo ENG] Will send notification type=\(type) text=\(text)")
        sendNotification(body: text)

        if type == .goalCompleted {
            markGoalCompletedSent()
        }
    }

    // MARK: - PROGRESS

    private func getActivityPercentage(current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(current / goal, 1.5)
    }

    // MARK: - LOGIC (Production + Debug)

    private func getNotificationTypeBasedOnProgress(
        progress: Double,
        inactivityMinutes: Int
    ) -> ActivityNotificationType? {

        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: lastProgressKey)
        defaults.set(progress, forKey: lastProgressKey)

        if isNotificationDebugMode {
            // 🔥 DEBUG MODE:
            // 20% → almostThere
            // 40% → goalCompleted
            // 2 دقائق خمول → moveNow

            if progress >= 0.4 {
                return .goalCompleted
            }

            if progress >= 0.2 {
                return .almostThere
            }

            if inactivityMinutes >= 2,
               progress <= last {
                return .moveNow
            }

            return nil
        } else {
            // 🧊 PRODUCTION MODE (المنطق الحقيقي)
            if progress >= 1.0 {
                return .goalCompleted
            }

            if progress >= 0.6 && progress < 0.9 {
                return .almostThere
            }

            let hour = Calendar.current.component(.hour, from: Date())
            let dayProgress = Double(hour) / 24.0
            let inactivityThreshold = 20

            if inactivityMinutes >= inactivityThreshold,
               progress < dayProgress,
               progress <= last {
                return .moveNow
            }

            return nil
        }
    }

    // MARK: - SEND LOCAL NOTIFICATION

    private func sendNotification(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "AiQo"
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ [AiQo ENG] Notification failed:", error)
            } else {
                print("✅ [AiQo ENG] Notification sent!")
            }
        }
    }

    // MARK: - GOAL COMPLETED LIMITER

    private func hasSentGoalCompletedToday() -> Bool {
        guard let date = UserDefaults.standard.object(forKey: lastGoalCompletedDateKey) as? Date else {
            return false
        }
        return Calendar.current.isDateInToday(date)
    }

    private func markGoalCompletedSent() {
        UserDefaults.standard.set(Date(), forKey: lastGoalCompletedDateKey)
    }
}
