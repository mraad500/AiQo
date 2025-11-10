import UIKit

final class MainTabBarController: UITabBarController {

    // نخزن الـ glass view حتى نتحكم بيه لاحقاً
    private var glassView: UIVisualEffectView?

    override func viewDidLoad() {
        super.viewDidLoad()

        // إعداد التابات
        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = .init(title: "Home", image: UIImage(systemName: "house.fill"), selectedImage: nil)

        let gym = UINavigationController(rootViewController: GymViewController())
        gym.tabBarItem = .init(title: "Gym", image: UIImage(systemName: "figure.strengthtraining.traditional"), selectedImage: nil)

        let kitchen = UINavigationController(rootViewController: KitchenViewController())
        kitchen.tabBarItem = .init(title: "Kitchen", image: UIImage(systemName: "fork.knife"), selectedImage: nil)

        let captain = UINavigationController(rootViewController: CaptainViewController())
        captain.tabBarItem = .init(title: "Captain", image: UIImage(systemName: "wand.and.stars"), selectedImage: nil)

        // نربطهم سوا
        viewControllers = [home, gym, kitchen, captain]

        // إعداد المظهر العام
        tabBar.isTranslucent = true
        setupGlassStyle()

        // 👇 حركة تصغير التاب بار لما تسحب للأسفل (iOS 18)
        if #available(iOS 18.0, *) {
            self.tabBarMinimizeBehavior = .onScrollDown
        }
    }

    // MARK: - Glass / Blur Style
    private func setupGlassStyle() {
        // إعداد الـ appearance الأساسي للتاب بار
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
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

        // نضبط حجمه ومكانه
        effectView.isUserInteractionEnabled = false
        effectView.frame = tabBar.bounds
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // نخلي الزجاج خلف الأيقونات
        tabBar.insertSubview(effectView, at: 0)
        glassView = effectView

        // نضيف لون مميز للأيقونة المختارة (أصفر)
        let selectedColor = UIColor.systemYellow
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    // نحدث حجم الزجاج إذا تغيّر التاب بار
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        glassView?.frame = tabBar.bounds
    }
}
