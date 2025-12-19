import UserNotifications
import UIKit

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func configureCategories() {
        // إذا تحتاج Actions مستقبلاً، عرّفها هنا
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([])
    }

    // MARK: - Schedule

    func scheduleDailyReminder(
        type: NotificationType,
        title: String,
        body: String,
        hour: Int,
        minute: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["notification_type": type.rawValue]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: type.rawValue,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancel(type: NotificationType) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [type.rawValue])
    }

    // MARK: - Handling tap

    func handle(response: UNNotificationResponse) {
        guard
            let typeRaw = response.notification.request.content.userInfo["notification_type"] as? String,
            let type = NotificationType(rawValue: typeRaw)
        else { return }

        routeFromNotification(type: type)
    }

    func handleInitial(response: UNNotificationResponse, window: UIWindow?) {
        guard
            let typeRaw = response.notification.request.content.userInfo["notification_type"] as? String,
            let type = NotificationType(rawValue: typeRaw)
        else { return }

        // التطبيق انفتح من الإشعار
        routeFromNotification(type: type, window: window)
    }

    private func routeFromNotification(type: NotificationType, window: UIWindow? = nil) {
        // هنا تربطه مع MainTabBarController و تفتح التاب المناسب
        guard
            let window,
            let tabBar = window.rootViewController as? MainTabBarController
        else { return }

        switch type {
        case .dailyStepsReminder:
            tabBar.selectedIndex = /* index تبويب الخطوات */
                3
        case .waterReminder:
            tabBar.selectedIndex = /* index تبويب المي */
                2
        case .workoutReminder:
            tabBar.selectedIndex = /* index تبويب الجم */
                1
        case .checkInReminder:
            tabBar.selectedIndex = /* index الهوم أو الكابتن */
                0
        }
    }
}
