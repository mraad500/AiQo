import SwiftUI
import UIKit
import Combine

struct MainTabScreen: View {
    @ObservedObject private var tabRouter = MainTabRouter.shared
    @ObservedObject private var appRootManager = AppRootManager.shared
    private let appTint = Color.aiqoAccent

    @State private var showLevelUp = false
    @State private var levelUpLevel = 0

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
                .accessibilityLabel("الرئيسية")
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
                .accessibilityLabel("النادي الرياضي")
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
                .accessibilityLabel("الكابتن")
            }
            .accessibilityHint(NSLocalizedString("tab.captain.hint", value: "Chat with your AI health coach", comment: ""))
        }
        .environment(\.layoutDirection, .rightToLeft)
        .tint(appTint)
        .onAppear(perform: enforceTribeVisibilityGuard)
        .onChange(of: tabRouter.selectedTab) { _, newTab in
            enforceTribeVisibilityGuard()

            guard TribeFeatureFlags.featureVisible || newTab != .tribe else { return }
            HapticEngine.selection()
        }
        .overlay {
            if showLevelUp {
                LevelUpCelebrationView(level: levelUpLevel) {
                    showLevelUp = false
                }
                .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .levelDidLevelUp)) { notification in
            guard let newLevel = notification.userInfo?["newLevel"] as? Int else { return }
            let lastCelebrated = UserDefaults.standard.integer(forKey: "lastCelebratedLevel")
            guard newLevel > lastCelebrated else { return }
            UserDefaults.standard.set(newLevel, forKey: "lastCelebratedLevel")
            levelUpLevel = newLevel
            withAnimation { showLevelUp = true }
        }
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

    private func enforceTribeVisibilityGuard() {
        guard TribeFeatureFlags.featureVisible == false,
              tabRouter.selectedTab == .tribe else { return }
        tabRouter.selectedTab = .home
    }
}

#Preview {
    MainTabScreen()
        .environmentObject(CaptainViewModel())
}
