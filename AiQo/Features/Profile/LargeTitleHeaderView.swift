import UIKit

/// هيدر عام لكل الشاشات (Home, Gym, Kitchen, Captain)
/// يحتوي:
/// - عنوان كبير
/// - أيقونة بروفايل داخل كارت عائم بزجاج مع أنيميشن ضغط
final class LargeTitleHeaderView: UIView {

    // MARK: - Public API (نستخدمها بكل الشاشات)
    let titleLabel = UILabel()

    /// الكارت العائم كله (الظل + الزجاج)
    let profileContainer = UIView()

    /// الزجاج الأبيض داخل الكارت
    let profileGlass = UIVisualEffectView()

    /// زر الأيقونة (نربطه لفتح شاشة البروفايل من الكنترولرات)
    let profileButton = UIButton(type: .system)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    convenience init(title: String) {
        self.init(frame: .zero)
        titleLabel.text = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false

        // -------- Title --------
        titleLabel.textColor = Colors.text
        titleLabel.font = UIFont.systemFont(ofSize: 40, weight: .heavy)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // -------- Profile Container (كارت عائم) --------
        profileContainer.translatesAutoresizingMaskIntoConstraints = false
        profileContainer.isUserInteractionEnabled = true
        profileContainer.layer.cornerRadius = 26
        profileContainer.layer.masksToBounds = false

        // ظل ناعم يخليها كارت عائم
        profileContainer.layer.shadowColor = UIColor.black.cgColor
        profileContainer.layer.shadowOpacity = 0.16
        profileContainer.layer.shadowRadius = 18
        profileContainer.layer.shadowOffset = CGSize(width: 0, height: 14)

        // -------- Profile Glass (الطبقة الزجاجية) --------
        if #available(iOS 18.0, *) {
            profileGlass.effect = UIGlassEffect()
        } else {
            profileGlass.effect = UIBlurEffect(style: .systemThinMaterial)
        }

        profileGlass.translatesAutoresizingMaskIntoConstraints = false
        profileGlass.layer.cornerRadius = 26
        profileGlass.layer.masksToBounds = true
        profileGlass.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        profileGlass.layer.borderColor = UIColor.black.withAlphaComponent(0.06).cgColor
        profileGlass.layer.borderWidth = 0.4

        profileContainer.addSubview(profileGlass)

        // زر الآيكون نفسه (يُستخدم من الكنترولرات)
        profileButton.translatesAutoresizingMaskIntoConstraints = false
        profileButton.setImage(UIImage(systemName: "person.fill"), for: .normal)
        profileButton.tintColor = .black
        profileButton.backgroundColor = .clear

        profileGlass.contentView.addSubview(profileButton)

        // قيود البروفايل
        NSLayoutConstraint.activate([
            profileGlass.topAnchor.constraint(equalTo: profileContainer.topAnchor),
            profileGlass.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor),
            profileGlass.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor),
            profileGlass.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor),

            profileContainer.widthAnchor.constraint(equalToConstant: 52),
            profileContainer.heightAnchor.constraint(equalToConstant: 52),

            profileButton.centerXAnchor.constraint(equalTo: profileGlass.contentView.centerXAnchor),
            profileButton.centerYAnchor.constraint(equalTo: profileGlass.contentView.centerYAnchor),
            profileButton.widthAnchor.constraint(equalToConstant: 24),
            profileButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        // -------- Stack: Title + Spacer + Profile --------
        let hStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), profileContainer])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 12
        hStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: topAnchor),
            hStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // إعداد أنيميشن وآكشنات البروفايل
        setupProfileInteractions()
    }

    // MARK: - Profile floating interactions

    private func setupProfileInteractions() {
        // أنيميشن لمس (ضغط)
        profileButton.addTarget(self,
                                action: #selector(profileTouchDown),
                                for: [.touchDown, .touchDragEnter])

        profileButton.addTarget(self,
                                action: #selector(profileTouchUp),
                                for: [.touchUpInside, .touchCancel, .touchDragExit])
    }

    @objc private func profileTouchDown() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        UIView.animate(withDuration: 0.14,
                       delay: 0,
                       options: [.curveEaseInOut, .allowUserInteraction]) {
            // ينزل شوي ويتصغر
            self.profileContainer.transform = CGAffineTransform(translationX: 0, y: 2)
                .scaledBy(x: 0.94, y: 0.94)
            self.profileContainer.layer.shadowOpacity = 0.10
            self.profileContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        }
    }

    @objc private func profileTouchUp() {
        UIView.animate(withDuration: 0.18,
                       delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.6,
                       options: [.curveEaseInOut, .allowUserInteraction]) {
            // يرجع يطفو
            self.profileContainer.transform = .identity
            self.profileContainer.layer.shadowOpacity = 0.16
            self.profileContainer.layer.shadowOffset = CGSize(width: 0, height: 14)
        }
    }
}
