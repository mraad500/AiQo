import Foundation

final class NotificationRepository {
    static let shared = NotificationRepository()
    private init() {}

    func getNotification(
        type: ActivityNotificationType,
        gender: ActivityNotificationGender,
        language: ActivityNotificationLanguage
    ) -> ActivityNotification? {
        // Placeholder fallback to keep engine working even if no dataset is wired.
        let text: String
        switch (type, language) {
        case (.moveNow, .arabic):
            text = "وقتك تتحرك الآن."
        case (.moveNow, .english):
            text = "Time to move now."
        case (.almostThere, .arabic):
            text = "قريب جدًا من هدفك!"
        case (.almostThere, .english):
            text = "You are almost there!"
        case (.goalCompleted, .arabic):
            text = "مبروك! حققت هدفك."
        case (.goalCompleted, .english):
            text = "Congrats! You hit your goal."
        }

        return ActivityNotification(
            id: Int(Date().timeIntervalSince1970),
            text: text,
            type: type,
            gender: gender,
            language: language
        )
    }
}
