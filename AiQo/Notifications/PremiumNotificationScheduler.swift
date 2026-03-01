import Foundation

enum PremiumNotificationScheduler {
    static func scheduleExpiryReminders(for expiresAt: Date) {
        PremiumExpiryNotifier.scheduleAllNotifications(expiresAt)
    }

    static func clear() {
        PremiumExpiryNotifier.clearScheduledNotifications()
    }
}
