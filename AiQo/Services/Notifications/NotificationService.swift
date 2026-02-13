import UserNotifications
import UIKit
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermissions() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                self.configureCategories()
                return
            }

            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("❌ Permission error: \(error)")
                }
                if granted {
                    self.configureCategories()
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
    }

    func configureCategories() {
        ActivityNotificationEngine.shared.registerNotificationCategories()
        CaptainSmartNotificationService.shared.registerNotificationCategories()
    }

    func sendImmediateNotification(body: String, type: String) {
        let content = UNMutableNotificationContent()
        content.title = "AiQo"
        content.body = body
        content.sound = .default
        content.userInfo = ["notification_type": type]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // دالة جديدة لمعالجة البيانات القادمة من الخلفية (اختياري)
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        // إذا كنت تريد تنفيذ شيء معين عند وصول إشعار صامت
        print("Handling remote data: \(userInfo)")
    }

    func handle(response: UNNotificationResponse) {
        guard
            let typeRaw = response.notification.request.content.userInfo["notification_type"] as? String,
            let type = NotificationType(rawValue: typeRaw)
        else { return }
        routeFromNotification(type: type)
    }

    // ✅✅ هاي الدالة الضرورية للـ SceneDelegate
    func handleInitial(response: UNNotificationResponse, window: UIWindow?) {
        guard
            let typeRaw = response.notification.request.content.userInfo["notification_type"] as? String,
            let type = NotificationType(rawValue: typeRaw)
        else { return }
        routeFromNotification(type: type, window: window)
    }

    private func routeFromNotification(type: NotificationType, window: UIWindow? = nil) {
        _ = window // kept for backward compatibility with current callers

        Task { @MainActor in
            switch type {
            case .dailyStepsReminder, .workoutReminder:
                MainTabRouter.shared.navigate(to: .gym)
            case .waterReminder:
                MainTabRouter.shared.navigate(to: .kitchen)
            case .checkInReminder:
                MainTabRouter.shared.navigate(to: .home)
            }
        }
    }
}

// MARK: - Captain Smart Notifications

struct WorkoutCoachingSummary {
    let duration: TimeInterval
    let calories: Double
    let averageHeartRate: Double
    let distanceMeters: Double
    let estimatedSteps: Int
}

final class CaptainSmartNotificationService {
    static let shared = CaptainSmartNotificationService()

    static let categoryIdentifier = "aiqo.captain.smart"
    private let coach = AiQoCoachService.shared
    private let defaults = UserDefaults.standard
    private let lastInactivitySentAtKey = "aiqo.captain.lastInactivitySentAt"
    private let inactivityCooldownSeconds: TimeInterval = 45 * 60

    private init() {}

    func registerNotificationCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_CAPTAIN",
            title: "Open Captain",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func evaluateInactivityAndNotifyIfNeeded() async {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        let inactivityMinutes = InactivityTracker.shared.currentInactivityMinutes
        guard inactivityMinutes >= 45 else { return }
        guard canSendInactivityNow() else { return }

        let currentSteps = HealthKitManager.shared.todaySteps
        let message = await coach.generateSmartNotification(currentSteps: currentSteps)

        sendCaptainNotification(
            title: "Captain Hamoudi",
            body: message,
            type: "inactivity",
            messageText: message
        )
        defaults.set(Date(), forKey: lastInactivitySentAtKey)
    }

    func handleWorkoutCompleted(summary: WorkoutCoachingSummary) async {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        let mins = max(Int(summary.duration / 60), 0)
        let kcal = Int(summary.calories.rounded())
        let distanceKm = summary.distanceMeters / 1000.0

        let prompt = """
        Workout done: \(mins) min, \(kcal) kcal, avg HR \(Int(summary.averageHeartRate)), \(String(format: "%.2f", distanceKm)) km, \(summary.estimatedSteps) steps.
        Write one short Iraqi Arabic motivational line.
        """
        let message: String
        do {
            message = try await coach.sendToCoach(message: prompt)
        } catch {
            message = "عفية! خلصت التمرين اليوم، استمر بنفس النفس."
        }

        sendCaptainNotification(
            title: "Workout Complete",
            body: message,
            type: "workout_complete",
            messageText: message
        )
    }

    private func canSendInactivityNow() -> Bool {
        guard let last = defaults.object(forKey: lastInactivitySentAtKey) as? Date else { return true }
        return Date().timeIntervalSince(last) >= inactivityCooldownSeconds
    }

    private func sendCaptainNotification(title: String, body: String, type: String, messageText: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = [
            "notification_type": type,
            "source": "captain_hamoudi",
            "messageText": messageText,
            "deepLink": "aiqo://captain"
        ]

        let request = UNNotificationRequest(
            identifier: "aiqo.captain.smart.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
