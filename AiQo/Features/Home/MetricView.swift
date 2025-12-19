import UIKit

// MARK: - MetricView
final class MetricView: UIView {

    // Public
    let kind: MetricKind
    var onTap: (() -> Void)?
    func setValue(_ value: String) { animateValueChange(to: value) }

    // UI
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let unitLabel  = UILabel()
    private let iconView   = UIImageView()

    // Init
    init(kind: MetricKind, tint: UIColor) {
        self.kind = kind
        super.init(frame: .zero)
        setupView(tint: tint)
        setupLayout()
        applyStyle()
        installGestures()
        // ارتفاع ثابت حتى ما ينهار داخل UIStackView
        heightAnchor.constraint(equalToConstant: 132).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Setup
private extension MetricView {

    func setupView(tint: UIColor) {
        backgroundColor = tint
        layer.cornerRadius = 22
        layer.masksToBounds = true

        // عنوان
        titleLabel.text = kind.title
        titleLabel.textAlignment = .left
        titleLabel.textColor = UIColor(white: 0.1, alpha: 0.85)

        // قيمة + وحدة
        valueLabel.textAlignment = .left
        valueLabel.textColor = .black
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        unitLabel.text = kind.unit
        unitLabel.textAlignment = .left
        unitLabel.textColor = .black

        // أيقونة زاوية الكارت
        iconView.image = UIImage(systemName: kind.icon)
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .secondaryLabel

        [titleLabel, valueLabel, unitLabel, iconView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }

    func setupLayout() {
        NSLayoutConstraint.activate([
            // Icon (top right)
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            iconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            // Title (top left)
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconView.leadingAnchor, constant: -8),

            // Value
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            // Unit baseline مع القيمة
            unitLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 4),
            unitLabel.firstBaselineAnchor.constraint(equalTo: valueLabel.firstBaselineAnchor),

            // لا يتجاوز حواف اليمين
            unitLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            // ضمان وجود مساحة سفلية (حتى بدون ارتفاع ثابت ما ينهار)
            valueLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }

    func applyStyle() {
        titleLabel.font = rounded(18, .semibold)
        valueLabel.font = rounded(32, .heavy)   // أصغر شوي حتى يتوازن
        unitLabel.font  = rounded(14, .medium)
        // VoiceOver
        isAccessibilityElement = true
        accessibilityLabel = "\(kind.title) \(kind.unit)"
        accessibilityTraits = .button
    }

    func installGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc func tap() { onTap?() }
}

// MARK: - Animations / Helpers
private extension MetricView {

    func animateValueChange(to newText: String) {
        // تغيير ناعم + pulse خفيفة
        UIView.transition(with: valueLabel, duration: 0.18, options: .transitionCrossDissolve) {
            self.valueLabel.text = newText
        }
        // نبضة خفيفة
        let original = self.transform
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = original.scaledBy(x: 0.98, y: 0.98)
        }, completion: { _ in
            UIView.animate(withDuration: 0.15) { self.transform = original }
        })
    }

    // خط Rounded بدون ما نصطدم مع Extension خارجي
    func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let f = UIFont.systemFont(ofSize: size, weight: weight)
        if let d = f.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: size) }
        return f
    }
}
