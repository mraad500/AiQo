import UIKit

final class MainTabBarController: UITabBarController {

    // نخزن الـ glass view حتى نتحكم بيه لاحقاً
    private var glassView: UIVisualEffectView?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViewControllers()
        setupGlassStyle()

        // 👇 حركة تصغير التاب بار لما تسحب للأسفل (iOS 18)
        if #available(iOS 18.0, *) {
            tabBarMinimizeBehavior = .onScrollDown
        }
    }

    // MARK: - Tabs setup

    private func setupViewControllers() {
        // Home
        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(
            title: NSLocalizedString("tab.home", comment: "Home tab title"),
            image: UIImage(systemName: "house.fill"),
            selectedImage: nil
        )

        // Gym
        let gym = UINavigationController(rootViewController: GymViewController())
        gym.tabBarItem = UITabBarItem(
            title: NSLocalizedString("tab.gym", comment: "Gym tab title"),
            image: UIImage(systemName: "figure.strengthtraining.traditional"),
            selectedImage: nil
        )

        // Kitchen
        let kitchen = UINavigationController(rootViewController: KitchenViewController())
        kitchen.tabBarItem = UITabBarItem(
            title: NSLocalizedString("tab.kitchen", comment: "Kitchen tab title"),
            image: UIImage(systemName: "fork.knife"),
            selectedImage: UIImage(systemName: "fork.knife.circle.fill")
        )

        // Captain
        let captain = UINavigationController(rootViewController: CaptainViewController())
        captain.tabBarItem = UITabBarItem(
            title: NSLocalizedString("tab.captain", comment: "Captain tab title"),
            image: UIImage(systemName: "wand.and.stars"),
            selectedImage: nil
        )

        // نربطهم سوا
        viewControllers = [home, gym, kitchen, captain]

        // إعداد المظهر العام
        tabBar.isTranslucent = true
    }

    // MARK: - Glass / Blur Style

    private func setupGlassStyle() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        // لون الأيقونة المختارة (أصفر)
        let selectedColor = UIColor.systemYellow
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor
        ]

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance

        // نحذف أي glassView سابق
        glassView?.removeFromSuperview()

        // نضيف glass أو blur حسب النظام
        let effectView: UIVisualEffectView
        if #available(iOS 18.0, *) {
            effectView = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        }

        effectView.isUserInteractionEnabled = false
        effectView.frame = tabBar.bounds
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // نخلي الزجاج خلف الأيقونات
        tabBar.insertSubview(effectView, at: 0)
        glassView = effectView
    }

    // نحدث حجم الزجاج إذا تغيّر التاب بار
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        glassView?.frame = tabBar.bounds
    }
}
