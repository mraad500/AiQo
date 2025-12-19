import Foundation

final class NotificationPreferencesStore {
    static let shared = NotificationPreferencesStore()
    
    private init() {}
    
    private let defaults = UserDefaults.standard
    private let genderKey = "aiqo.notification.gender"
    private let languageKey = "aiqo.notification.language"
    
    var gender: ActivityNotificationGender {
        get {
            if let raw = defaults.string(forKey: genderKey),
               let value = ActivityNotificationGender(rawValue: raw) {
                return value
            }
            // الافتراضي: ذكر
            return .male
        }
        set {
            defaults.set(newValue.rawValue, forKey: genderKey)
        }
    }
    
    var language: ActivityNotificationLanguage {
        get {
            if let raw = defaults.string(forKey: languageKey),
               let value = ActivityNotificationLanguage(rawValue: raw) {
                return value
            }
            // الافتراضي: عربي
            return .arabic
        }
        set {
            defaults.set(newValue.rawValue, forKey: languageKey)
        }
    }
}
