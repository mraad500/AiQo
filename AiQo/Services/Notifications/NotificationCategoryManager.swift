import Foundation
import UserNotifications

final class NotificationCategoryManager {
    static let shared = NotificationCategoryManager()
    static let trialJourneyCategory = "aiqo.trial.journey"

    private let notificationCenter: UNUserNotificationCenter

    init(
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.notificationCenter = notificationCenter
    }

    func registerAllCategories() {
        let openCaptainAction = UNNotificationAction(
            identifier: "OPEN_CAPTAIN",
            title: NSLocalizedString("notification.captain.openAction", value: "Open Captain", comment: ""),
            options: [.foreground]
        )
        let openDeepLinkAction = UNNotificationAction(
            identifier: "OPEN_DEEPLINK",
            title: NSLocalizedString("notification.openApp", value: "Open", comment: ""),
            options: [.foreground]
        )

        let trialCategory = UNNotificationCategory(
            identifier: Self.trialJourneyCategory,
            actions: [openCaptainAction, openDeepLinkAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let categories: Set<UNNotificationCategory> = [
            CaptainSmartNotificationService.notificationCategory,
            trialCategory
        ]
        notificationCenter.setNotificationCategories(categories)
    }
}
