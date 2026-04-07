import Foundation
internal import Combine

@MainActor
final class AppRootManager: ObservableObject {
    static let shared = AppRootManager()

    @Published var isCaptainChatPresented = false

    private init() {}

    func openCaptainChat() {
        MainTabRouter.shared.navigate(to: .captain)
        DispatchQueue.main.async {
            self.isCaptainChatPresented = true
        }
    }

    func dismissCaptainChat() {
        isCaptainChatPresented = false
    }
}
