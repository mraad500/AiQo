import Foundation
import SwiftUI
internal import Combine

@MainActor
final class MainTabRouter: ObservableObject {
    static let shared = MainTabRouter()

    enum Tab: Int {
        case home = 0
        case gym = 1
        case tribe = 2
        case kitchen = 3
        case captain = 4
    }

    @Published var selectedTab: Tab = .home

    private init() {}

    func navigate(to tab: Tab) {
        if tab == .kitchen {
            if selectedTab != .home {
                selectedTab = .home
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openKitchenFromHome, object: nil)
            }
            return
        }

        guard selectedTab != tab else { return }
        selectedTab = tab
    }
}

extension Notification.Name {
    static let openKitchenFromHome = Notification.Name("aiqo.openKitchenFromHome")
}
