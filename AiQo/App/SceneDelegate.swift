// =====================================================
// File: iOS/SceneDelegate.swift
// Target: iOS
// =====================================================

import UIKit
import UserNotifications
import FamilyControls
import SwiftUI
import Supabase // تأكد من استيراد Supabase

private enum OnboardingKeys {
    static let didCompleteLegacyCalculation = "didCompleteLegacyCalculation"
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    let protectionModel = ProtectionModel()

    // MARK: - UIScene Lifecycle

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        _ = PhoneConnectivityManager.shared

        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        // 1. الفحص: هل المستخدم مسجل دخول؟
        let isLoggedIn = SupabaseService.shared.client.auth.currentUser != nil
        
        // 2. الفحص: هل أتم حسابات اللياقة (Onboarding)؟
        let isOnboardingCompleted = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)

        if isLoggedIn {
            if isOnboardingCompleted {
                // مسجل دخول + مخلص حسابات -> الشاشة الرئيسية
                window.rootViewController = makeMainRoot()
            } else {
                // مسجل دخول + لم يكمل الحسابات -> شاشة الحسابات
                window.rootViewController = makeLegacyRoot()
            }
        } else {
            // غير مسجل دخول -> شاشة تسجيل الدخول الجديدة
            window.rootViewController = LoginViewController()
        }

        window.makeKeyAndVisible()

        // معالجة الإشعارات
        if let response = connectionOptions.notificationResponse {
            NotificationService.shared.handleInitial(response: response, window: window)
        }
    }

    // MARK: - Navigation Logic (Transitions)

    /// تستدعى من LoginViewController عند نجاح الدخول
    func didLoginSuccessfully() {
        guard let window = window else { return }
        
        // الانتقال إلى شاشة الحسابات (Legacy Calculation)
        let legacyRoot = makeLegacyRoot()
        
        UIView.transition(
            with: window,
            duration: 0.6,
            options: .transitionFlipFromRight, // أو .transitionCrossDissolve
            animations: { window.rootViewController = legacyRoot },
            completion: nil
        )
    }

    /// تستدعى من LegacyCalculationViewController عند الانتهاء
    func onboardingFinished() {
        Task {
            // طلب إذن Screen Time (اختياري حسب منطق تطبيقك)
            try? await protectionModel.requestAuthorization()
            
            await MainActor.run {
                self.switchToMainInterface()
            }
        }
    }
    
    /// الانتقال النهائي للشاشة الرئيسية
    private func switchToMainInterface() {
        guard let window = window else { return }

        // حفظ الحالة
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
    
    // تسجيل الخروج (للمستقبل)
    func logout() {
        Task {
            try? await SupabaseService.shared.client.auth.signOut()
            UserDefaults.standard.set(false, forKey: OnboardingKeys.didCompleteLegacyCalculation) // إعادة تعيين حسب الحاجة
            
            await MainActor.run {
                guard let window = self.window else { return }
                window.rootViewController = LoginViewController()
            }
        }
    }

    // MARK: - Root Builders

    private func makeLegacyRoot() -> UIViewController {
        let legacyVC = LegacyCalculationViewController()
        let nav = UINavigationController(rootViewController: legacyVC)
        nav.navigationBar.isHidden = true // نخفي البار لأننا صممنا الهيدر يدوياً
        return nav
    }

    private func makeMainRoot() -> UIViewController {
        let tabBar = MainTabBarController()
        return tabBar
    }
    
    // MARK: - Standard Methods
    func sceneWillEnterForeground(_ scene: UIScene) { _ = PhoneConnectivityManager.shared }
    func sceneDidBecomeActive(_ scene: UIScene) { _ = PhoneConnectivityManager.shared }
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        MusicManager.shared.handleSpotifyURL(url)
    }
}
