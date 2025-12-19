import UIKit
import UserNotifications
import FamilyControls

private enum OnboardingKeys {
    static let didCompleteLegacyCalculation = "didCompleteLegacyCalculation"
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - UIScene Lifecycle
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)

        // فحص: هل المستخدم قديم أم جديد؟
        let isUserOnboarded = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)
        
        if isUserOnboarded {
            // مستخدم قديم -> شاشة رئيسية فوراً
            window.rootViewController = makeMainRoot()
        } else {
            // مستخدم جديد -> شاشة التقييم (Onboarding)
            // تأكد أن LegacyCalculationViewController هو اسم ملفك الصحيح
            let legacyVC = LegacyCalculationViewController()
            let nav = UINavigationController(rootViewController: legacyVC)
            nav.navigationBar.prefersLargeTitles = true
            window.rootViewController = nav
        }

        window.makeKeyAndVisible()
        self.window = window
        
        if let response = connectionOptions.notificationResponse {
            NotificationService.shared.handleInitial(response: response, window: window)
        }
    }

    // MARK: - الانتقال والطلبات (هذا الجزء المهم)

    // 1. هذه الدالة تستدعيها لما المستخدم يضغط "إنهاء" في آخر شاشة
    func onboardingFinished() {
        Task {
            // أ. طلب إذن الدرع والمراقب
            try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            
            // ب. بعد ما يوافق (أو يرفض)، ننقله للشاشة الرئيسية
            await MainActor.run {
                self.switchToMainInterface()
            }
        }
    }

    // 2. دالة بناء الشاشة الرئيسية
    private func makeMainRoot() -> UIViewController {
        return MainTabBarController()
    }

    // 3. تنفيذ الانتقال بصرياً
    private func switchToMainInterface() {
        guard let window = window else { return }
        
        // حفظ أن المستخدم أكمل التسجيل
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteLegacyCalculation)
        
        // تأثير انتقال ناعم
        let mainRoot = makeMainRoot()
        UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: {
            window.rootViewController = mainRoot
        }, completion: nil)
    }
}
