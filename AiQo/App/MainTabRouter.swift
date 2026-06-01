import Foundation
import SwiftUI
import Combine

@MainActor
final class MainTabRouter: ObservableObject {
    static let shared = MainTabRouter()

    enum Tab: Int {
        case home = 0
        case gym = 1
        case kitchen = 2
        case captain = 3
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
        // Kitchen is now a top-level tab — switch to it.
        if selectedTab != .kitchen {
            selectedTab = .kitchen
        }
    }
}

extension MainTabRouter.Tab {
    var analyticsName: String {
        switch self {
        case .home: return "home"
        case .gym: return "gym"
        case .kitchen: return "kitchen"
        case .captain: return "captain"
        }
    }
}

extension Notification.Name {
    static let openKitchenFromHome = Notification.Name("aiqo.openKitchenFromHome")
}
