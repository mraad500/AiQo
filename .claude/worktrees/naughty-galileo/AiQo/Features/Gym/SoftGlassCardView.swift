import UIKit

// =========================
// MARK: - SoftGlassCardView
// Premium soft glass card for iOS 18
// =========================

final class SoftGlassCardView: UIView {

    // MARK: - Subviews
    let contentView = UIView()

    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialLight)
        let v = UIVisualEffectView(effect: blur)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.clipsToBounds = true
        return v
    }()

    private let tintOverlay: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        return v
    }()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup
    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        layer.cornerRadius = 22
        layer.cornerCurve = .continuous

        // Shadow (soft paper-like)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 8)

        addSubview(blurView)
        addSubview(tintOverlay)
        addSubview(contentView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 22
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tintOverlay.topAnchor.constraint(equalTo: topAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Public API
    func setTint(_ color: UIColor, intensity: CGFloat = 0.35) {
        tintOverlay.backgroundColor = color.withAlphaComponent(intensity)
    }

    func setPressed(_ pressed: Bool) {
        UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.4) {
            self.transform = pressed
            ? CGAffineTransform(scaleX: 0.97, y: 0.97)
            : .identity
        }
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.layer.cornerRadius = layer.cornerRadius
        tintOverlay.layer.cornerRadius = layer.cornerRadius

        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: layer.cornerRadius
        ).cgPath
    }
}
