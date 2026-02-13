import Foundation

enum AppLanguage: String, CaseIterable {
    case arabic = "ar"
    case english = "en"
}

final class AppSettingsStore {
    static let shared = AppSettingsStore()

    private init() {}

    private let appLanguageKey = "aiqo.app.language"
    private let notificationsEnabledKey = "aiqo.notifications.enabled"

    var appLanguage: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: appLanguageKey),
               let value = AppLanguage(rawValue: raw) {
                return value
            }
            // default: Arabic (as requested)
            return .arabic
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: appLanguageKey)
        }
    }

    var notificationsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: notificationsEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: notificationsEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: notificationsEnabledKey)
        }
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("aiqo.appLanguageDidChange")
}
