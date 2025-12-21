import UIKit

final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViewControllers()
        setupTransparentStyle() // قمنا بتغيير الاسم ليعبر عن الوظيفة الجديدة

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
        
        // التأكد من الشفافية
        tabBar.isTranslucent = true
    }

    // MARK: - Style Setup

    private func setupTransparentStyle() {
        let appearance = UITabBarAppearance()
        
        // هذا السطر يجعل الخلفية شفافة تماماً ويلغي "الكارت" الافتراضي
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear // إزالة خط الظل العلوي

        // إعدادات ألوان الأيقونات والنص
        let selectedColor = UIColor.systemYellow
        
        // الأيقونات
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.normal.iconColor = .systemGray // لون الأيقونات غير المختارة
        
        // النصوص
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]

        // تطبيق المظهر
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}
