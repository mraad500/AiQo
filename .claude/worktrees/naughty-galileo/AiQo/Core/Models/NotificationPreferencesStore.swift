import Foundation

final class NotificationPreferencesStore {
    static let shared = NotificationPreferencesStore()

    private init() {}

    // Keep compatibility with existing AppDelegate usage
    private let genderKey = "user_gender"
    private let languageKey = "aiqo.notification.language"

    var gender: ActivityNotificationGender {
        get {
            let raw = UserDefaults.standard.string(forKey: genderKey) ?? "male"
            return raw == "female" ? .female : .male
        }
        set {
            let raw = newValue == .female ? "female" : "male"
            UserDefaults.standard.set(raw, forKey: genderKey)
        }
    }

    var language: ActivityNotificationLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: languageKey),
               let value = ActivityNotificationLanguage(rawValue: raw) {
                return value
            }
            // Default to app language if no explicit preference
            return AppSettingsStore.shared.appLanguage == .english ? .english : .arabic
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
        }
    }
}
