import Foundation

func resolvedCoachNotificationLanguage(defaults: UserDefaults = .standard) -> CoachNotificationLanguage {
    if let raw = defaults.string(forKey: "notificationLanguage") {
        return CoachNotificationLanguage(preferenceValue: raw)
    }

    let legacyRaw = NotificationPreferencesStore.shared.language.rawValue
    return CoachNotificationLanguage(preferenceValue: legacyRaw)
}

func localizedNotificationString(
    _ key: String,
    language: CoachNotificationLanguage,
    fallback: String
) -> String {
    let appLanguage: AppLanguage
    switch language {
    case .english:
        appLanguage = .english
    case .arabic:
        appLanguage = .arabic
    }

    return localizedNotificationString(
        key,
        language: appLanguage,
        fallback: fallback
    )
}

func localizedNotificationString(
    _ key: String,
    language: AppLanguage,
    fallback: String
) -> String {
    guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return NSLocalizedString(key, value: fallback, comment: "")
    }

    return bundle.localizedString(forKey: key, value: fallback, table: nil)
}
