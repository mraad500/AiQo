import UserNotifications
import UIKit

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermissions() {
        let center = UNUserNotificationCenter.current()
        // أضفت خيار .alert و .sound و .badge
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Permission error: \(error)")
            }
            if granted {
                print("✅ Notification Permission Granted")
                self.configureCategories()
                
                // محاولة التسجيل مرة أخرى للتأكيد (يتم تنفيذها في الـ Main Thread)
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func configureCategories() {}

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
        let targetWindow = window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        guard let root = targetWindow?.rootViewController as? MainTabBarController else { return }

        switch type {
        case .dailyStepsReminder, .workoutReminder: root.selectedIndex = 1
        case .waterReminder: root.selectedIndex = 2
        case .checkInReminder: root.selectedIndex = 0
        }
    }
}
