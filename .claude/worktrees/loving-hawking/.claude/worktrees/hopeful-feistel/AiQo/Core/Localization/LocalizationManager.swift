import Foundation

final class LocalizationManager {
    static let shared = LocalizationManager()
    private init() {}

    func applySavedLanguage() {
        let language = AppSettingsStore.shared.appLanguage
        Bundle.setLanguage(language.rawValue)
    }

    func setLanguage(_ language: AppLanguage) {
        AppSettingsStore.shared.appLanguage = language
        Bundle.setLanguage(language.rawValue)
        NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
    }
}
