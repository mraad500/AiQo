import UIKit

final class FloatingTribeCard: UIControl {

    private let effectView: UIVisualEffectView
    private let imageView = UIImageView()

    private var floatIsRunning = false
    private let floatKey = "float"

    override init(frame: CGRect) {
        if #available(iOS 18.0, *) {
            effectView = UIVisualEffectView(effect: UIGlassEffect())
        } else {
            effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        }
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        clipsToBounds = false
        layer.cornerRadius = 24
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 10)

        effectView.layer.cornerRadius = 24
        effectView.layer.masksToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        imageView.image = UIImage(named: "Tribeicon")?.withRenderingMode(.alwaysOriginal)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: effectView.contentView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: effectView.widthAnchor, multiplier: 0.7),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor)
        ])

        // بارالاكس خفيف
        let x = UIInterpolatingMotionEffect(keyPath: "layer.transform.translation.x", type: .tiltAlongHorizontalAxis)
        x.minimumRelativeValue = -8; x.maximumRelativeValue = 8
        let y = UIInterpolatingMotionEffect(keyPath: "layer.transform.translation.y", type: .tiltAlongVerticalAxis)
        y.minimumRelativeValue = -8; y.maximumRelativeValue = 8
        let group = UIMotionEffectGroup(); group.motionEffects = [x, y]
        addMotionEffect(group)

        addTarget(self, action: #selector(touchDown), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(touchCancel), for: [.touchCancel, .touchDragExit])
        addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startFloatIfNeeded() } else { stopFloat() }
    }

    private func startFloatIfNeeded() {
        guard !floatIsRunning else { return }
        floatIsRunning = true
        let anim = CABasicAnimation(keyPath: "transform.translation.y")
        anim.fromValue = -4
        anim.toValue = 4
        anim.duration = 2.0
        anim.autoreverses = true
        anim.repeatCount = .greatestFiniteMagnitude
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: floatKey)
    }
    private func stopFloat() {
        floatIsRunning = false
        layer.removeAnimation(forKey: floatKey)
    }

    @objc private func touchDown() {
        stopFloat() // حتى ما تتعارض الأنيميشنات
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIView.animate(withDuration: 0.08) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            self.layer.shadowRadius = 10
            self.layer.shadowOffset = CGSize(width: 0, height: 6)
        }
    }
    @objc private func touchCancel() {
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseOut]) {
            self.transform = .identity
            self.layer.shadowRadius = 14
            self.layer.shadowOffset = CGSize(width: 0, height: 10)
        } completion: { _ in
            self.startFloatIfNeeded()
        }
    }
    @objc private func touchUpInside() {
        // نبضة سريعة جدًا وسلسة
        UIView.animate(withDuration: 0.18,
                       delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.9,
                       options: [.curveEaseOut]) {
            self.transform = CGAffineTransform(scaleX: 1.06, y: 1.06).translatedBy(x: 0, y: -5)
        } completion: { _ in
            UIView.animate(withDuration: 0.10) {
                self.transform = .identity
            } completion: { _ in
                self.startFloatIfNeeded()
                // خلي Home تقدّم الإيفينت الفعلي (target-action) للمستمع فوق
                self.sendActions(for: .primaryActionTriggered)
            }
        }
    }
}
