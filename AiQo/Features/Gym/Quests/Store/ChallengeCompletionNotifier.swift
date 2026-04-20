import Foundation
import UserNotifications
import os.log

@MainActor
final class ChallengeCompletionNotifier {
    static let shared = ChallengeCompletionNotifier()

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "ChallengeCompletionNotifier"
    )
    private let identifierPrefix = "aiqo.challenge.completion."
    private let delaySeconds: TimeInterval = 10 * 60

    private init() {}

    func scheduleCongratulation(for challenge: Challenge) {
        guard AppSettingsStore.shared.notificationsEnabled else { return }

        let language = AppSettingsStore.shared.appLanguage
        let title = notificationTitle(language: language)
        let body = notificationBody(for: challenge, language: language)
        let identifier = "\(identifierPrefix)\(challenge.id).\(UUID().uuidString)"

        Task {
            let authorized = await NotificationService.shared.ensureAuthorizationIfNeeded()
            guard authorized else { return }

            await submit(
                identifier: identifier,
                title: title,
                body: body,
                delaySeconds: delaySeconds,
                challengeID: challenge.id
            )
        }
    }

    private func submit(
        identifier: String,
        title: String,
        body: String,
        delaySeconds: TimeInterval,
        challengeID: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "CAPTAIN_DEFAULT"
        content.threadIdentifier = "aiqo.challenge.congratulations"
        content.userInfo = [
            "notification_type": "challenge_completion",
            "source": "captain_hamoudi",
            "challenge_id": challengeID,
            "messageText": body,
            "deepLink": "aiqo://captain"
        ]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .active
        }

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, delaySeconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            logger.error("challenge_notification_schedule_failed error=\(error.localizedDescription, privacy: .public)")
        }
    }

    private func notificationTitle(language: AppLanguage) -> String {
        language == .arabic
            ? "🎉 مبروك يا بطل"
            : "🎉 Well done, champion"
    }

    private func notificationBody(for challenge: Challenge, language: AppLanguage) -> String {
        let challengeTitle = challenge.title
        if language == .arabic {
            return "خلصت تحدي \(challengeTitle). الكابتن حمودي فخور بيك، خليك على هالإيقاع."
        }
        return "You completed \(challengeTitle). Captain Hamoudi is proud — keep this rhythm going."
    }
}
