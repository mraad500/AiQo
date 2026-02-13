import Foundation
import SwiftUI
internal import Combine

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
        selectedTab = tab
    }
}
