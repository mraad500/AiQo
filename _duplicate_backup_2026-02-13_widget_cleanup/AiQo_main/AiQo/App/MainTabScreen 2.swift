import SwiftUI
import UIKit
internal import Combine

struct MainTabScreen: View {
    @ObservedObject private var tabRouter = MainTabRouter.shared

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                tabBody
                    .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                tabBody
            }
        }
        .onAppear(perform: configureTabBarAppearance)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCaptainScreen)) { _ in
            tabRouter.navigate(to: .captain)
        }
    }

    private var tabBody: some View {
        TabView(selection: $tabRouter.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tag(MainTabRouter.Tab.home)
            .tabItem {
                Label(
                    NSLocalizedString("tab.home", comment: "Home tab title"),
                    systemImage: "house.fill"
                )
            }

            NavigationStack {
                GymView()
            }
            .tag(MainTabRouter.Tab.gym)
            .tabItem {
                Label(
                    NSLocalizedString("tab.gym", comment: "Gym tab title"),
                    systemImage: "figure.strengthtraining.traditional"
                )
            }

            NavigationStack {
                KitchenTabRootView()
            }
            .tag(MainTabRouter.Tab.kitchen)
            .tabItem {
                Label(
                    NSLocalizedString("tab.kitchen", comment: "Kitchen tab title"),
                    systemImage: "fork.knife"
                )
            }

            NavigationStack {
                CaptainScreen()
            }
            .tag(MainTabRouter.Tab.captain)
            .tabItem {
                Label(
                    NSLocalizedString("tab.captain", comment: "Captain tab title"),
                    systemImage: "wand.and.stars"
                )
            }
        }
        .tint(.yellow)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

        let selectedColor = UIColor.systemYellow
        let unselectedColor = UIColor.systemGray

        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor
        ]

        appearance.stackedLayoutAppearance.normal.iconColor = unselectedColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: unselectedColor
        ]

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }

        UITabBar.appearance().backgroundImage = UIImage()
        UITabBar.appearance().shadowImage = UIImage()
        UITabBar.appearance().barTintColor = .clear
        UITabBar.appearance().backgroundColor = .clear
        UITabBar.appearance().isTranslucent = true
    }
}

private struct KitchenTabRootView: View {
    @State private var viewModel: KitchenViewModel

    init() {
        _viewModel = State(
            initialValue: KitchenViewModel(repository: LocalMealsRepository())
        )
    }

    var body: some View {
        KitchenScreen(
            viewModel: viewModel,
            onEditDietTapped: {}
        )
    }
}

#Preview {
    MainTabScreen()
}
