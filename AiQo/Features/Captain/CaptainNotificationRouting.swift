import Foundation
internal import Combine

// MARK: - Notifications Deep-link State

final class CaptainNotificationHandler: ObservableObject {
    static let shared = CaptainNotificationHandler()

    @Published var pendingNotificationMessage: String?
    @Published var shouldNavigateToCaptain: Bool = false

    private let pendingMessageKey = "aiqo.captain.pendingMessage"

    private init() {
        pendingNotificationMessage = UserDefaults.standard.string(forKey: pendingMessageKey)
    }

    func handleIncomingNotification(userInfo: [AnyHashable: Any]) {
        guard let source = userInfo["source"] as? String, source == "captain_hamoudi" else { return }

        let text = userInfo["messageText"] as? String
            ?? userInfo["notificationText"] as? String
            ?? userInfo["text"] as? String

        guard let messageText = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !messageText.isEmpty else { return }

        UserDefaults.standard.set(messageText, forKey: pendingMessageKey)

        DispatchQueue.main.async {
            self.pendingNotificationMessage = messageText
            self.shouldNavigateToCaptain = true

            NotificationCenter.default.post(
                name: .captainLaunchFromNotification,
                object: nil,
                userInfo: ["prompt": messageText]
            )
        }
    }

    func clearPendingMessage() {
        pendingNotificationMessage = nil
        shouldNavigateToCaptain = false
        UserDefaults.standard.removeObject(forKey: pendingMessageKey)
    }

    func hasPendingMessage() -> Bool {
        if let message = pendingNotificationMessage,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        if let stored = UserDefaults.standard.string(forKey: pendingMessageKey),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        return false
    }
}

final class CaptainNavigationHelper {
    static let shared = CaptainNavigationHelper()
    private init() {}

    func navigateToCaptainScreen() {
        Task { @MainActor in
            MainTabRouter.shared.navigate(to: .captain)
        }
        NotificationCenter.default.post(name: .navigateToCaptainScreen, object: nil)
    }
}

extension Notification.Name {
    static let captainLaunchFromNotification = Notification.Name("captainLaunchFromNotification")
    static let navigateToCaptainScreen = Notification.Name("navigateToCaptainScreen")
}
