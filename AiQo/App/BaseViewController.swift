import UIKit

/// كل الشاشات الرئيسية ترث من هذا الكلاس
/// حالياً فقط حتى نوحد أشياء عامة (مثل الـ background أو سلوك مشترك)
class BaseViewController: UIViewController {

    // نحتفظ بزر لو احتجناه مستقبلاً، بس ما نضيفه على الشاشة
    let profileButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCommonAppearance()
    }

    // MARK: - Common UI

    private func setupCommonAppearance() {
        view.backgroundColor = .systemBackground
    }

    // ماكو setupProfileButton هنا
    // وماكو didTapProfile – فتح البروفايل يصير من كل شاشة على حدة
}
