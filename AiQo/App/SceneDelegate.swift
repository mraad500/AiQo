import UIKit
import UserNotifications
import FamilyControls
import SwiftUI // ضفنا هاي لأن نحتاجها اذا ردنا نغلف فيوات

private enum OnboardingKeys {
    static let didCompleteLegacyCalculation = "didCompleteLegacyCalculation"
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // 1. (مهم) نصنع نسخة وحدة من "عقل الحماية" ونخليها هنا
    let protectionModel = ProtectionModel()

    // MARK: - UIScene Lifecycle
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)

        let isUserOnboarded = UserDefaults.standard.bool(forKey: OnboardingKeys.didCompleteLegacyCalculation)
        
        if isUserOnboarded {
            window.rootViewController = makeMainRoot()
        } else {
            let legacyVC = LegacyCalculationViewController()
            
            // اذا شاشة الاونبوردنج تحتاج المودل هم تكدر تدزه هنا، بس اعتقد ما تحتاجه هسه
            
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

    // MARK: - الانتقال والطلبات

    func onboardingFinished() {
        Task {
            // 2. (تعديل) نطلب الصلاحية عن طريق المودل مو مباشرة
            // هذا يضمن ان المتغير isAuthorized داخل المودل يصير True
            await protectionModel.requestAuthorization()
            
            await MainActor.run {
                self.switchToMainInterface()
            }
        }
    }

    // 3. (تعديل) دالة بناء الشاشة الرئيسية وحقن المودل
    private func makeMainRoot() -> UIViewController {
        let tabBar = MainTabBarController()
        
        // ⚠️ مهم جداً: هنا لازم توصل المودل للتاب بار
        // بما ان MainTabBarController هو UIKit، لازم تسويله متغير يستقبل المودل
        // مثلاً تكون ضايف بداخله: var model: ProtectionModel?
        
        // tabBar.model = protectionModel  <-- فعل هذا السطر بعد ما تعدل التاب بار
        
        return tabBar
    }

    private func switchToMainInterface() {
        guard let window = window else { return }
        
        UserDefaults.standard.set(true, forKey: OnboardingKeys.didCompleteLegacyCalculation)
        
        let mainRoot = makeMainRoot()
        UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: {
            window.rootViewController = mainRoot
        }, completion: nil)
    }
}
