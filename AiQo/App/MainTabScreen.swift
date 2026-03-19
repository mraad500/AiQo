import SwiftUI
import UIKit
internal import Combine

struct MainTabScreen: View {
    @ObservedObject private var tabRouter = MainTabRouter.shared
    @ObservedObject private var appRootManager = AppRootManager.shared
    private let appTint = Color.aiqoAccent

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
            .accessibilityHint(NSLocalizedString("tab.home.hint", value: "View daily health summary", comment: ""))

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
            .accessibilityHint(NSLocalizedString("tab.gym.hint", value: "Workouts and fitness challenges", comment: ""))

            NavigationStack {
                CaptainScreen()
                    .navigationDestination(isPresented: $appRootManager.isCaptainChatPresented) {
                        CaptainChatView()
                    }
            }
            .tag(MainTabRouter.Tab.captain)
            .tabItem {
                Label(
                    NSLocalizedString("tab.captain", comment: "Captain tab title"),
                    systemImage: "wand.and.stars"
                )
            }
            .accessibilityHint(NSLocalizedString("tab.captain.hint", value: "Chat with your AI health coach", comment: ""))
        }
        .tint(appTint)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

        let selectedColor = Colors.accent
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
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = unselectedColor
    }
}

#Preview {
    MainTabScreen()
        .environmentObject(CaptainViewModel())
}
