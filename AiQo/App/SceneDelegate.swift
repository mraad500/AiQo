import UIKit
import UserNotifications
import FamilyControls
import SwiftUI
import WidgetKit
import Supabase
import Auth

private enum OnboardingKeys {
    static let didCompleteLegacyCalculation = "didCompleteLegacyCalculation"
    static let didShowFirstAuthScreen = "didShowFirstAuthScreen"
    static let didCompleteDatingProfile = "didCompleteDatingProfile"
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    let protectionModel = ProtectionModel()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        _ = PhoneConnectivityManager.shared
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appLanguageDidChange),
            name: .appLanguageDidChange,
            object: nil
        )

        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        window.rootViewController = makeInitialRoot()

        window.makeKeyAndVisible()

        if let response = connectionOptions.notificationResponse {
            let userInfo = response.notification.request.content.userInfo
            if let source = userInfo["source"] as? String, source == "captain_hamoudi" {
                CaptainNotificationHandler.shared.handleIncomingNotification(userInfo: userInfo)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    CaptainNavigationHelper.shared.navigateToCaptainScreen()
                }
            } else {
                NotificationService.shared.handleInitial(response: response, window: window)
            }
        }
    }

    func didLoginSuccessfully() {
        guard let window = window else { return }
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didShowFirstAuthScreen)

        let datingRoot = makeDatingRoot()

        UIView.transition(
            with: window,
            duration: 0.6,
            options: .transitionFlipFromRight,
            animations: { window.rootViewController = datingRoot },
            completion: nil
        )
    }

    func didCompleteDatingProfile() {
        guard let window = window else { return }
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteDatingProfile)

        let legacyRoot = makeLegacyRoot()

        UIView.transition(
            with: window,
            duration: 0.5,
            options: .transitionCrossDissolve,
            animations: { window.rootViewController = legacyRoot },
            completion: nil
        )
    }

    func onboardingFinished() {
        Task {
            await requestNotificationAuthorizationIfNeeded()
            await protectionModel.requestAuthorization()

            await MainActor.run {
                self.switchToMainInterface()
            }
        }
    }

    private func switchToMainInterface() {
        guard let window = window else { return }

        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteLegacyCalculation)

        let mainRoot = makeMainRoot()

        UIView.transition(
            with: window,
            duration: 0.5,
            options: .transitionCrossDissolve,
            animations: { window.rootViewController = mainRoot },
            completion: nil
        )
    }

    func logout() {
        Task {
            try? await SupabaseService.shared.client.auth.signOut()
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteLegacyCalculation)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteDatingProfile)
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didShowFirstAuthScreen)

            await MainActor.run {
                guard let window = self.window else { return }
                window.rootViewController = host(LoginScreenView())
            }
        }
    }

    private func makeInitialRoot() -> UIViewController {
        let isLoggedIn = SupabaseService.shared.client.auth.currentUser != nil
        let didCompleteDatingProfile = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteDatingProfile)
        let didCompleteLegacyCalculation = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)

        guard isLoggedIn else { return host(LoginScreenView()) }

        if !didCompleteDatingProfile {
            return makeDatingRoot()
        }

        if !didCompleteLegacyCalculation {
            return makeLegacyRoot()
        }

        return makeMainRoot()
    }

    private func makeDatingRoot() -> UIViewController {
        host(DatingScreenView())
    }

    private func makeLegacyRoot() -> UIViewController {
        host(LegacyCalculationScreenView())
    }

    private func makeMainRoot() -> UIViewController {
        host(MainTabScreen())
    }

    private func host<V: View>(_ view: V) -> UIViewController {
        UIHostingController(rootView: view)
    }

    func sceneWillEnterForeground(_ scene: UIScene) { _ = PhoneConnectivityManager.shared }

    func sceneDidBecomeActive(_ scene: UIScene) {
        _ = PhoneConnectivityManager.shared
        WidgetCenter.shared.reloadAllTimelines()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        MusicManager.shared.handleSpotifyURL(url)
    }

    private func requestNotificationAuthorizationIfNeeded() async {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                continuation.resume()
            }
        }
    }

    @objc private func appLanguageDidChange() {
        guard let window = window else { return }
        window.rootViewController = makeInitialRoot()
    }
}
