import Foundation

// Kept for profile gender preference — notification-specific fields removed
final class NotificationPreferencesStore {
    static let shared = NotificationPreferencesStore()
    private let defaults = UserDefaults.standard

    var gender: ActivityNotificationGender {
        get {
            let raw = defaults.string(forKey: "notification_gender") ?? "male"
            return ActivityNotificationGender(rawValue: raw) ?? .male
        }
        set {
            defaults.set(newValue.rawValue, forKey: "notification_gender")
        }
    }
}
