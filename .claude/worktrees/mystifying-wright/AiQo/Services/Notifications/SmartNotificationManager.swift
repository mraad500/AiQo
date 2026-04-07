import Foundation

struct SmartNotificationManager: Sendable {
    static let shared = SmartNotificationManager()

    private let sanitizer = PrivacySanitizer()

    func morningSleepNotificationBody(
        language: AppLanguage = AppSettingsStore.shared.appLanguage,
        userName: String? = nil
    ) -> String {
        let resolvedUserName = userName ?? currentUserName()
        let baseMessage = language == .english
            ? "You completed your sleep cycle well. Tap for today's energy analysis."
            : "أكملت دورة نومك بامتياز. اضغط لتحليل طاقتك اليوم."

        guard let resolvedUserName, !resolvedUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return baseMessage
        }

        return sanitizer.injectUserName(into: baseMessage, userName: resolvedUserName)
    }

    func inactivityNotificationBody(
        currentSteps: Int,
        language: AppLanguage = AppSettingsStore.shared.appLanguage,
        userName: String? = nil
    ) -> String {
        let resolvedUserName = userName ?? currentUserName()
        let baseMessage: String
        switch language {
        case .arabic:
            if currentSteps < 2_000 {
                baseMessage = "خمس دقايق مشي هسه تفتح يومك. اضغط وخذ الدفعة."
            } else if currentSteps < 6_000 {
                baseMessage = "تقدمك زين، بس يحتاج دفعة قصيرة. اضغط وكمل."
            } else {
                baseMessage = "طاقة اليوم موجودة. اضغط وثبت الزخم بخطوة سريعة."
            }
        case .english:
            if currentSteps < 2_000 {
                baseMessage = "A five-minute walk will wake the day up. Tap to start."
            } else if currentSteps < 6_000 {
                baseMessage = "Your progress is solid. Tap for a short push."
            } else {
                baseMessage = "Your momentum is alive. Tap to lock in the next burst."
            }
        }

        guard let resolvedUserName, !resolvedUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return baseMessage
        }

        return sanitizer.injectUserName(into: baseMessage, userName: resolvedUserName)
    }

    func currentUserName(
        userDefaults: UserDefaults = .standard
    ) -> String? {
        let profile = UserProfileStore.shared.current
        let candidates = [
            userDefaults.string(forKey: "captain_calling"),
            userDefaults.string(forKey: "captain_user_name"),
            profile.name,
            profile.username
        ]

        for candidate in candidates {
            guard let candidate else { continue }
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }
}
