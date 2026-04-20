import Foundation
import UserNotifications

struct ScheduledPremiumNotification: Equatable {
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
}

enum PremiumExpiryNotifier {
    static let twoDaysBeforeIdentifier = "aiqo.premium.expiry.twoDays"
    static let oneDayBeforeIdentifier = "aiqo.premium.expiry.oneDay"
    static let expiredIdentifier = "aiqo.premium.expiry.expired"

    static let allIdentifiers = [
        twoDaysBeforeIdentifier,
        oneDayBeforeIdentifier,
        expiredIdentifier
    ]

    static func scheduleAllNotifications(_ expiresAt: Date) {
        if !DevOverride.unlockAllFeatures {
            guard TierGate.shared.canAccess(.captainNotifications) else {
                diag.info("PremiumExpiryNotifier.scheduleAllNotifications blocked by TierGate(.captainNotifications)")
                return
            }
        }
        clearScheduledNotifications(center: .current())

        let notifications = plannedNotifications(for: expiresAt)
        let expiresAtString = String(expiresAt.timeIntervalSince1970)

        for notification in notifications {
            let intent = NotificationIntent(
                kind: .trialDay,
                requestedBy: "PremiumExpiryNotifier"
            )
            let fireDate = notification.fireDate
            let userInfo: [String: String] = [
                "source": "premium_expiry",
                "expiresAt": expiresAtString
            ]
            let identifier = notification.identifier
            let title = notification.title
            let body = notification.body
            Task {
                let result = await NotificationBrain.shared.request(
                    intent,
                    fireDate: fireDate,
                    precomposedTitle: title,
                    precomposedBody: body,
                    userInfo: userInfo,
                    identifier: identifier
                )
                if result.deliveredAt != nil {
                    diag.info("Scheduled premium notification \(identifier) for \(fireDate)")
                } else {
                    diag.info("Premium notification \(identifier) not scheduled: \(String(describing: result.decision))")
                }
            }
        }
    }

    static func clearScheduledNotifications() {
        clearScheduledNotifications(center: .current())
    }

    static func plannedNotifications(
        for expiresAt: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ScheduledPremiumNotification] {
        let candidates = [
            ScheduledPremiumNotification(
                identifier: twoDaysBeforeIdentifier,
                title: "باقي يومين على انتهاء البريميوم",
                body: "باقي يومين على انتهاء اشتراكك. إذا تريد، جدده يدوياً حتى يستمر بدون انقطاع.",
                fireDate: calendar.date(byAdding: .day, value: -2, to: expiresAt) ?? expiresAt
            ),
            ScheduledPremiumNotification(
                identifier: oneDayBeforeIdentifier,
                title: "باقي يوم واحد على انتهاء البريميوم",
                body: "باقي يوم واحد على انتهاء اشتراكك. التجديد بقرارك إذا تحب تكمل.",
                fireDate: calendar.date(byAdding: .day, value: -1, to: expiresAt) ?? expiresAt
            ),
            ScheduledPremiumNotification(
                identifier: expiredIdentifier,
                title: "انتهت مدة بريميوم",
                body: "انتهت مدة بريميوم. إذا تريد ترجع الميزات، تقدر تشتري 30 يوم جديدة.",
                fireDate: expiresAt
            )
        ]

        return candidates
            .map {
                ScheduledPremiumNotification(
                    identifier: $0.identifier,
                    title: $0.title,
                    body: $0.body,
                    fireDate: SmartNotificationScheduler.shared.adjustedAutomationDate(for: $0.fireDate)
                )
            }
            .filter { $0.fireDate > now }
    }

    private static func clearScheduledNotifications(center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: allIdentifiers)
        diag.info("Cleared previous premium expiry notifications.")
    }
}
