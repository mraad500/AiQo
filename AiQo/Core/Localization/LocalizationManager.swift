import Foundation

final class LocalizationManager {
    static let shared = LocalizationManager()
    private init() {}

    func applySavedLanguage() {
        // Check if the user changed the language from iOS Settings
        syncFromSystemLanguage()
        let language = AppSettingsStore.shared.appLanguage
        Bundle.setLanguage(language.rawValue)
        mirrorLanguageToKernel(language)
    }

    func setLanguage(_ language: AppLanguage) {
        AppSettingsStore.shared.appLanguage = language
        Bundle.setLanguage(language.rawValue)

        // Sync with iOS per-app language setting so it reflects in Settings > AiQo > Language
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")

        mirrorLanguageToKernel(language)
        NotificationCenter.default.post(name: .appLanguageDidChange, object: nil)
    }

    /// Mirror the app language into the Kernel App Group so the shield extension —
    /// a separate process that can't read our `UserDefaults` — always localizes to
    /// the user's current language, even if a shield fires before the Kernel hub is
    /// reopened (the hub also mirrors it on appear).
    private func mirrorLanguageToKernel(_ language: AppLanguage) {
        guard FeatureFlags.kernelEnabled else { return }
        KernelSharedStore.shared.setLanguageCode(language == .english ? "en" : "ar")
    }

    /// Detect if user changed language from iPhone Settings and sync our internal preference.
    private func syncFromSystemLanguage() {
        guard let systemLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
              let first = systemLanguages.first else { return }

        let prefix = String(first.prefix(2)) // "ar", "en"
        guard let systemLang = AppLanguage(rawValue: prefix) else { return }

        let stored = AppSettingsStore.shared.appLanguage
        if systemLang != stored {
            AppSettingsStore.shared.appLanguage = systemLang
            Bundle.setLanguage(systemLang.rawValue)
        }
    }
}
