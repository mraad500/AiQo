import Foundation
import UserNotifications

final class NotificationCategoryManager {
    static let shared = NotificationCategoryManager()

    private let notificationCenter: UNUserNotificationCenter

    init(
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.notificationCenter = notificationCenter
    }

    func registerAllCategories() {
        let categories: Set<UNNotificationCategory> = [
            ActivityNotificationEngine.notificationCategory,
            CaptainSmartNotificationService.notificationCategory,
            CaptainNotificationEngine.notificationCategory,
        ]
        notificationCenter.setNotificationCategories(categories)
    }
}
