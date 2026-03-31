import Foundation
import SwiftUI
import Combine

@MainActor
final class MainTabRouter: ObservableObject {
    static let shared = MainTabRouter()

    enum Tab: Int {
        case home = 0
        case gym = 1
        case captain = 2
    }

    @Published var selectedTab: Tab = .home

    private init() {}

    func navigate(to tab: Tab) {
        guard selectedTab != tab else { return }
        AnalyticsService.shared.track(.tabSelected(tab.analyticsName))
        selectedTab = tab
    }

    func openKitchen() {
        AnalyticsService.shared.track(.kitchenOpened)

        if selectedTab != .home {
            selectedTab = .home
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openKitchenFromHome, object: nil)
        }
    }
}

extension MainTabRouter.Tab {
    var analyticsName: String {
        switch self {
        case .home: return "home"
        case .gym: return "gym"
        case .captain: return "captain"
        }
    }
}

extension Notification.Name {
    static let openKitchenFromHome = Notification.Name("aiqo.openKitchenFromHome")
}
