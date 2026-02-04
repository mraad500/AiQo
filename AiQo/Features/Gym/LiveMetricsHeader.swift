import UIKit

// Live metrics compact header (HR • kcal • km • pace • time)
final class LiveMetricsHeader: UIView {

    // MARK: - UI

    private let effectView: UIVisualEffectView = {
        if #available(iOS 18.0, *) {
            return UIVisualEffectView(effect: UIGlassEffect())
        } else {
            return UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        }
    }()

    private let stack = UIStackView()

    // Labels
    private let hr = UILabel()
    private let kcal = UILabel()
    private let dist = UILabel()
    private let pace = UILabel()
    private let time = UILabel()

    // Heart icon (نستعمله لنبض القلب)
    private let heartImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "heart.fill"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.tintColor = .systemRed
        return iv
    }()

    // MARK: - Helpers

    private func metric(icon: String, label: UILabel) -> UIStackView {
        let iv = UIImageView(image: UIImage(systemName: icon))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.tintColor = .label.withAlphaComponent(0.8)

        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 16),
            iv.heightAnchor.constraint(equalToConstant: 16)
        ])

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .left

        let h = UIStackView(arrangedSubviews: [iv, label])
        h.axis = .horizontal
        h.alignment = .center
        h.spacing = 6
        return h
    }

    private func metric(iconView: UIImageView, label: UILabel) -> UIStackView {
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16)
        ])

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .left

        let h = UIStackView(arrangedSubviews: [iconView, label])
        h.axis = .horizontal
        h.alignment = .center
        h.spacing = 6
        return h
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 18
        layer.masksToBounds = true

        effectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])

        // Default texts
        hr.text = "-- bpm"
        kcal.text = "0"
        dist.text = "0.00 km"
        pace.text = "--"
        time.text = "00:00"

        let heartRow = metric(iconView: heartImageView, label: hr)
        let rows: [UIStackView] = [
            heartRow,
            metric(icon: "flame.fill", label: kcal),
            metric(icon: "figure.walk", label: dist),
            metric(icon: "speedometer", label: pace),
            metric(icon: "clock", label: time)
        ]
        rows.forEach { stack.addArrangedSubview($0) }

        isAccessibilityElement = false
        [hr, kcal, dist, pace, time].forEach { $0.isAccessibilityElement = true }
        hr.accessibilityLabel = "Heart rate"
        kcal.accessibilityLabel = "Active energy"
        dist.accessibilityLabel = "Distance"
        pace.accessibilityLabel = "Pace"
        time.accessibilityLabel = "Elapsed time"
    }

    // MARK: - Private Animations

    private func animateHeart() {
        if #available(iOS 18.0, *) {
            heartImageView.addSymbolEffect(.pulse, options: .repeat(1))
        }

        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.allowUserInteraction, .curveEaseInOut],
            animations: { [weak self] in
                self?.heartImageView.transform = CGAffineTransform(scaleX: 1.16, y: 1.16)
            },
            completion: { [weak self] _ in
                UIView.animate(
                    withDuration: 0.18,
                    delay: 0,
                    options: [.allowUserInteraction, .curveEaseInOut],
                    animations: {
                        self?.heartImageView.transform = .identity
                    },
                    completion: nil
                )
            }
        )
    }

    // MARK: - Public Updates

    public func setHeartRate(_ bpm: Int) {
        print("LiveMetricsHeader.setHeartRate =>", bpm) // DEBUG

        if bpm > 0 {
            hr.text = "\(bpm) bpm"
            animateHeart()
        } else {
            hr.text = "-- bpm"
        }
    }

    public func setCalories(_ kcalVal: Double) {
        let v = Int(kcalVal.rounded())
        kcal.text = v > 0 ? "\(v) kcal" : "0"
    }

    public func setDistanceMeters(_ meters: Double) {
        let km = meters / 1000.0
        dist.text = km > 0 ? String(format: "%.2f km", km) : "0.00 km"
    }

    public func setPace(_ paceStr: String) {
        pace.text = paceStr
    }

    public func setElapsed(_ seconds: TimeInterval) {
        let s = Int(seconds)
        let mm = s / 60
        let ss = s % 60
        time.text = String(format: "%02d:%02d", mm, ss)
    }
}
