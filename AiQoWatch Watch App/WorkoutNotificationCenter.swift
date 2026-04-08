import Foundation
import UserNotifications

enum WorkoutNotificationCenter {
    static let categoryIdentifier = "AIQO_WORKOUT_LIVE"
    static let milestoneIdentifier = "AIQO_WORKOUT_MILESTONE"
    static let summaryIdentifier = "AIQO_WORKOUT_SUMMARY"

    static func configure() {
        let locale = Locale.autoupdatingCurrent
        let openAction = UNNotificationAction(
            identifier: "OPEN_WORKOUT",
            title: WatchText.localized(ar: "افتح AiQoWatch", en: "Open AiQoWatch", locale: locale),
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("⌚️ [WorkoutNotificationCenter] Auth failed: \(error.localizedDescription)")
                return
            }
            print("⌚️ [WorkoutNotificationCenter] Auth granted: \(granted)")
        }
    }

    static func scheduleMilestone(
        km: Int,
        heartRate: Int,
        calories: Int,
        elapsedSeconds: Int,
        distanceMeters: Double
    ) {
        guard km > 0 else { return }
        let locale = Locale.autoupdatingCurrent

        let content = UNMutableNotificationContent()
        content.title = WatchText.localized(ar: "إنجاز AiQoWatch", en: "AiQoWatch Milestone", locale: locale)
        content.body = WatchText.localized(ar: "أكملت \(km) كم", en: "You completed \(km) km", locale: locale)
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.threadIdentifier = "aiqo.workout"
        content.userInfo = [
            "type": milestoneIdentifier,
            "km": km,
            "heartRate": max(0, heartRate),
            "calories": max(0, calories),
            "elapsed": max(0, elapsedSeconds),
            "distanceMeters": max(0, distanceMeters)
        ]

        let request = UNNotificationRequest(
            identifier: "\(milestoneIdentifier).\(km).\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("⌚️ [WorkoutNotificationCenter] Milestone notification failed: \(error.localizedDescription)")
            }
        }
    }

    static func scheduleSummary(
        elapsedSeconds: Int,
        distanceMeters: Double,
        calories: Int
    ) {
        let distanceKm = max(0, distanceMeters) / 1000
        let locale = Locale.autoupdatingCurrent
        let content = UNMutableNotificationContent()
        content.title = WatchText.localized(ar: "تم حفظ تمرين AiQoWatch", en: "AiQoWatch Workout Saved", locale: locale)
        content.body = String(
            format: locale.aiqoUsesArabicCopy ? "%.2f كم • %@ • %d سعرة" : "%.2f km • %@ • %d kcal",
            distanceKm,
            elapsedString(elapsedSeconds),
            max(0, calories)
        )
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.threadIdentifier = "aiqo.workout"
        content.userInfo = [
            "type": summaryIdentifier,
            "distanceKm": distanceKm,
            "elapsed": max(0, elapsedSeconds),
            "calories": max(0, calories)
        ]

        let request = UNNotificationRequest(
            identifier: "\(summaryIdentifier).\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("⌚️ [WorkoutNotificationCenter] Summary notification failed: \(error.localizedDescription)")
            }
        }
    }

    private static func elapsedString(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
