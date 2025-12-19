import UIKit

final class CircularTribeButton: UIControl {

    private let effectView: UIVisualEffectView = {
        if #available(iOS 18.0, *) {
            return UIVisualEffectView(effect: UIGlassEffect())
        } else {
            return UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        }
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "person.3.fill"))
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .black
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isAccessibilityElement = true
        accessibilityTraits = .button

        clipsToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.10
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.layer.cornerRadius = 999
        effectView.layer.masksToBounds = true
        addSubview(effectView)

        effectView.contentView.addSubview(iconView)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),

            widthAnchor.constraint(equalTo: heightAnchor),

            iconView.centerXAnchor.constraint(equalTo: effectView.contentView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalTo: effectView.contentView.widthAnchor, multiplier: 0.45),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        sendActions(for: .primaryActionTriggered)

        // feedback بسيط
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // animation صغيرة
        UIView.animate(withDuration: 0.12,
                       delay: 0,
                       options: [.curveEaseInOut],
                       animations: {
            self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }) { _ in
            UIView.animate(withDuration: 0.16,
                           delay: 0,
                           options: [.curveEaseInOut],
                           animations: {
                self.transform = .identity
            }, completion: nil)
        }
    }
}
