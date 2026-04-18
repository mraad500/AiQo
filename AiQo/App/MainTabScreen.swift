import SwiftUI
import UIKit
import Combine

struct MainTabScreen: View {
    @ObservedObject private var tabRouter = MainTabRouter.shared
    @ObservedObject private var appRootManager = AppRootManager.shared
    private let tierGate = TierGate.shared
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
                    L10n.t("tab.home"),
                    systemImage: "house.fill"
                )
            }
            .accessibilityHint(L10n.t("tab.home.hint"))

            NavigationStack {
                GymView()
            }
            .tag(MainTabRouter.Tab.gym)
            .tabItem {
                Label(
                    L10n.t("tab.gym"),
                    systemImage: "figure.strengthtraining.traditional"
                )
            }
            .accessibilityHint(L10n.t("tab.gym.hint"))

            NavigationStack {
                Group {
                    if tierGate.canAccess(.captainChat) {
                        CaptainScreen()
                            .navigationDestination(isPresented: $appRootManager.isCaptainChatPresented) {
                                CaptainChatView()
                            }
                    } else {
                        CaptainLockedView(config: .init(
                            title: "Captain",
                            subtitle: "Upgrade to unlock the Captain.",
                            iconSystemName: "lock.fill",
                            tier: tierGate.requiredTier(for: .captainChat),
                            onUpgradeTap: {}
                        ))
                    }
                }
            }
            .tag(MainTabRouter.Tab.captain)
            .tabItem {
                Label(
                    L10n.t("tab.captain"),
                    systemImage: "wand.and.stars"
                )
            }
            .accessibilityHint(L10n.t("tab.captain.hint"))
        }
        .environment(\.layoutDirection, .rightToLeft)
        .tint(appTint)
        .onChange(of: tabRouter.selectedTab) { _, _ in
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

}

#Preview {
    MainTabScreen()
        .environmentObject(CaptainViewModel())
}
