import UIKit

/// Ultra Modern Level Card (Level + Line Score + Progress)
final class LevelCardView: UIView {

    private let useGroupingSeparator = true

    // MARK: - UI
    private let containerView = UIView()

    private let gradientView = UIView()
    private let gradientLayer = CAGradientLayer()

    private let glassHost = UIVisualEffectView()
    private let borderLayer = CAShapeLayer()

    private let leftTitleLabel = UILabel()
    private let levelNumberLabel = UILabel()
    private let scorePill = ScorePillView()

    private let progressBackground = UIView()
    private let progressFill = UIView()
    private let progressGlow = UIView()
    private let progressIndicator = UIView()

    private var progressFillWidth: NSLayoutConstraint!
    private var indicatorLeading: NSLayoutConstraint!

    // ✅ نزول الرقم بدون قص
    private let levelNumberBaselineOffset: CGFloat = -4   // سالب = ينزل

    // MARK: - State
    var level: Int = 1 { didSet { updateUI(animated: true) } }
    var levelProgress: CGFloat = 0 { didSet { updateProgress(animated: true) } }

    private var lineScore: Int = 0 {
        didSet {
            scorePill.setValue(formatScore(lineScore))
            pulseScore()
        }
    }

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupObservers()
        reloadFromStorage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupObservers()
        reloadFromStorage()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func layoutSubviews() {
        super.layoutSubviews()

        containerView.layer.shadowPath = UIBezierPath(
            roundedRect: containerView.bounds,
            cornerRadius: containerView.layer.cornerRadius
        ).cgPath

        gradientLayer.frame = gradientView.bounds

        let path = UIBezierPath(
            roundedRect: containerView.bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerRadius: containerView.layer.cornerRadius
        )
        borderLayer.path = path.cgPath
        borderLayer.frame = containerView.bounds

        updateProgress(animated: false)
    }

    // MARK: - Public
    func configure(level: Int, progress: CGFloat? = nil, lineScore: Int? = nil) {
        self.level = max(level, 1)
        if let progress { self.levelProgress = min(max(progress, 0), 1) }
        if let lineScore { self.lineScore = max(lineScore, 0) }
    }

    @objc func reloadFromStorage() {
        let storedLevel = UserDefaults.standard.integer(forKey: LevelStorageKeys.currentLevel)
        level = storedLevel == 0 ? 1 : storedLevel

        let storedProgress = UserDefaults.standard.double(forKey: LevelStorageKeys.currentLevelProgress)
        levelProgress = CGFloat(min(max(storedProgress, 0), 1))

        let storedScore = UserDefaults.standard.integer(forKey: LevelStorageKeys.legacyTotalPoints)
        lineScore = max(storedScore, 0)

        scorePill.setValue(formatScore(lineScore))
        updateUI(animated: false)
        updateProgress(animated: false)
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadFromStorage),
            name: NSNotification.Name("XPUpdated"),
            object: nil
        )
    }

    // MARK: - Setup
    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true

        // Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = Colors.card
        containerView.layer.cornerRadius = 26
        containerView.layer.cornerCurve = .continuous
        containerView.layer.masksToBounds = false

        containerView.layer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        containerView.layer.shadowOpacity = 1
        containerView.layer.shadowRadius = 22
        containerView.layer.shadowOffset = CGSize(width: 0, height: 12)

        addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Gradient
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.layer.cornerRadius = containerView.layer.cornerRadius
        gradientView.layer.cornerCurve = .continuous
        gradientView.layer.masksToBounds = true
        containerView.addSubview(gradientView)

        NSLayoutConstraint.activate([
            gradientView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: containerView.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        gradientLayer.type = .axial
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.55).cgColor,
            Colors.sand.withAlphaComponent(0.18).cgColor,
            Colors.card.withAlphaComponent(1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.45, 1.0]
        gradientView.layer.insertSublayer(gradientLayer, at: 0)

        // Glass
        glassHost.translatesAutoresizingMaskIntoConstraints = false
        glassHost.isUserInteractionEnabled = false
        glassHost.layer.cornerRadius = containerView.layer.cornerRadius
        glassHost.layer.cornerCurve = .continuous
        glassHost.layer.masksToBounds = true
        containerView.addSubview(glassHost)

        NSLayoutConstraint.activate([
            glassHost.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            glassHost.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            glassHost.topAnchor.constraint(equalTo: containerView.topAnchor),
            glassHost.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        applyGlassEffect()

        // Border
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.45).cgColor
        borderLayer.lineWidth = 1
        containerView.layer.addSublayer(borderLayer)

        // Labels (Level + Number)
        leftTitleLabel.text = NSLocalizedString("level", value: "Level", comment: "")
        leftTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        leftTitleLabel.textColor = Colors.subtext
        leftTitleLabel.alpha = 0.95
        leftTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        leftTitleLabel.setContentHuggingPriority(.required, for: .horizontal)

        levelNumberLabel.font = .systemFont(ofSize: 36, weight: .black)
        levelNumberLabel.textColor = Colors.text
        levelNumberLabel.baselineAdjustment = .alignCenters
        levelNumberLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        levelNumberLabel.setContentHuggingPriority(.required, for: .horizontal)
        levelNumberLabel.clipsToBounds = false

        // ✅ Stack row (مستحيل يختفي) + نزول رقم بـ baselineOffset
        let levelRow = UIStackView(arrangedSubviews: [leftTitleLabel, levelNumberLabel])
        levelRow.axis = .horizontal
        levelRow.alignment = .firstBaseline
        levelRow.spacing = 10
        levelRow.translatesAutoresizingMaskIntoConstraints = false

        // مهم: خلي للـ row ارتفاع مضمون
        let levelRowHost = UIView()
        levelRowHost.translatesAutoresizingMaskIntoConstraints = false
        levelRowHost.clipsToBounds = false
        levelRowHost.addSubview(levelRow)

        NSLayoutConstraint.activate([
            levelRow.leadingAnchor.constraint(equalTo: levelRowHost.leadingAnchor),
            levelRow.trailingAnchor.constraint(lessThanOrEqualTo: levelRowHost.trailingAnchor),
            levelRow.topAnchor.constraint(equalTo: levelRowHost.topAnchor),
            levelRow.bottomAnchor.constraint(equalTo: levelRowHost.bottomAnchor),
            levelRowHost.heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])

        // Score pill
        scorePill.setTitle(NSLocalizedString("line_score", value: "Line Score", comment: ""))
        scorePill.setValue(formatScore(lineScore))

        // Top row
        let topRow = UIStackView(arrangedSubviews: [levelRowHost, UIView(), scorePill])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 12
        topRow.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(topRow)
        NSLayoutConstraint.activate([
            topRow.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            topRow.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            topRow.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 18)
        ])

        // Progress background
        progressBackground.translatesAutoresizingMaskIntoConstraints = false
        progressBackground.backgroundColor = UIColor.black.withAlphaComponent(0.06)
        progressBackground.layer.cornerRadius = 9
        progressBackground.layer.cornerCurve = .continuous
        progressBackground.layer.masksToBounds = true

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = Colors.sand
        progressFill.layer.cornerRadius = 9
        progressFill.layer.cornerCurve = .continuous
        progressFill.layer.masksToBounds = true

        progressGlow.translatesAutoresizingMaskIntoConstraints = false
        progressGlow.backgroundColor = Colors.sand.withAlphaComponent(0.35)
        progressGlow.layer.cornerRadius = 10
        progressGlow.layer.cornerCurve = .continuous
        progressGlow.layer.masksToBounds = false
        progressGlow.layer.shadowColor = Colors.sand.withAlphaComponent(0.6).cgColor
        progressGlow.layer.shadowOpacity = 1
        progressGlow.layer.shadowRadius = 10
        progressGlow.layer.shadowOffset = .zero

        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.backgroundColor = .white.withAlphaComponent(0.92)
        progressIndicator.layer.cornerRadius = 7
        progressIndicator.layer.cornerCurve = .continuous
        progressIndicator.layer.borderWidth = 1
        progressIndicator.layer.borderColor = UIColor.black.withAlphaComponent(0.06).cgColor
        progressIndicator.layer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        progressIndicator.layer.shadowOpacity = 1
        progressIndicator.layer.shadowRadius = 8
        progressIndicator.layer.shadowOffset = CGSize(width: 0, height: 4)

        containerView.addSubview(progressBackground)
        progressBackground.addSubview(progressGlow)
        progressBackground.addSubview(progressFill)
        progressBackground.addSubview(progressIndicator)

        progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        indicatorLeading = progressIndicator.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor, constant: 0)

        NSLayoutConstraint.activate([
            progressBackground.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            progressBackground.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            progressBackground.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            progressBackground.heightAnchor.constraint(equalToConstant: 16),
            progressBackground.topAnchor.constraint(greaterThanOrEqualTo: topRow.bottomAnchor, constant: 12),

            progressGlow.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            progressGlow.topAnchor.constraint(equalTo: progressBackground.topAnchor, constant: 1),
            progressGlow.bottomAnchor.constraint(equalTo: progressBackground.bottomAnchor, constant: -1),
            progressGlow.widthAnchor.constraint(equalTo: progressFill.widthAnchor),

            progressFill.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressBackground.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBackground.bottomAnchor),
            progressFillWidth,

            indicatorLeading,
            progressIndicator.centerYAnchor.constraint(equalTo: progressBackground.centerYAnchor),
            progressIndicator.widthAnchor.constraint(equalToConstant: 14),
            progressIndicator.heightAnchor.constraint(equalToConstant: 14)
        ])

        updateUI(animated: false)
        updateProgress(animated: false)
    }

    private func applyGlassEffect() {
        if #available(iOS 18.0, *) {
            glassHost.effect = UIGlassEffect()
        } else {
            glassHost.effect = UIBlurEffect(style: .systemThinMaterial)
        }
        glassHost.alpha = 0.95
    }

    // MARK: - Update
    private func updateUI(animated: Bool) {
        // ✅ نزول الرقم عن طريق baselineOffset بدون قص
        let title = leftTitleLabel.text ?? "Level"
        let number = "\(level)"

        let attrsTitle: [NSAttributedString.Key: Any] = [
            .font: leftTitleLabel.font as Any,
            .foregroundColor: leftTitleLabel.textColor as Any
        ]

        let attrsNumber: [NSAttributedString.Key: Any] = [
            .font: levelNumberLabel.font as Any,
            .foregroundColor: levelNumberLabel.textColor as Any,
            .baselineOffset: levelNumberBaselineOffset
        ]

        // نكتبها على لابلين منفصلين (ثابتة) — بس نخلي baselineOffset على الرقم
        leftTitleLabel.attributedText = NSAttributedString(string: title, attributes: attrsTitle)
        levelNumberLabel.attributedText = NSAttributedString(string: number, attributes: attrsNumber)

        accessibilityLabel = "Level \(level), Line Score \(lineScore)"

        if animated {
            UIView.transition(with: levelNumberLabel, duration: 0.16, options: [.transitionCrossDissolve, .allowUserInteraction], animations: nil)
        }
    }

    private func updateProgress(animated: Bool) {
        layoutIfNeeded()
        let w = progressBackground.bounds.width
        guard w > 0 else { return }

        let clamped = min(max(levelProgress, 0), 1)
        let fillW = w * clamped
        progressFillWidth.constant = fillW

        let inset: CGFloat = 7
        let x = max(inset, min(fillW, w - inset))
        indicatorLeading.constant = x - inset

        let animations = {
            self.progressBackground.layoutIfNeeded()
            self.progressGlow.alpha = clamped > 0.02 ? 1.0 : 0.0
            self.progressIndicator.alpha = clamped > 0.02 ? 1.0 : 0.0
        }

        if animated {
            UIView.animate(withDuration: 0.32,
                           delay: 0,
                           usingSpringWithDamping: 0.9,
                           initialSpringVelocity: 0.18,
                           options: [.allowUserInteraction, .curveEaseOut],
                           animations: animations)
        } else {
            animations()
        }
    }

    private func pulseScore() {
        UIView.animate(withDuration: 0.10, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
            self.scorePill.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        } completion: { _ in
            UIView.animate(withDuration: 0.14, delay: 0, options: [.allowUserInteraction, .curveEaseIn]) {
                self.scorePill.transform = .identity
            }
        }
    }

    private func formatScore(_ value: Int) -> String {
        guard useGroupingSeparator else { return "\(value)" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Score Pill
private final class ScorePillView: UIView {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let stack = UIStackView()
    private let blurHost = UIVisualEffectView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false

        layer.cornerRadius = 18
        layer.cornerCurve = .continuous
        layer.masksToBounds = false

        blurHost.translatesAutoresizingMaskIntoConstraints = false
        blurHost.layer.cornerRadius = 18
        blurHost.layer.cornerCurve = .continuous
        blurHost.layer.masksToBounds = true
        addSubview(blurHost)

        NSLayoutConstraint.activate([
            blurHost.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurHost.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurHost.topAnchor.constraint(equalTo: topAnchor),
            blurHost.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if #available(iOS 18.0, *) {
            blurHost.effect = UIGlassEffect()
        } else {
            blurHost.effect = UIBlurEffect(style: .systemThinMaterial)
        }
        blurHost.alpha = 0.92

        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        layer.shadowColor = UIColor.black.withAlphaComponent(0.10).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)

        iconView.image = UIImage(systemName: "chart.line.uptrend.xyaxis")
        iconView.tintColor = Colors.text.withAlphaComponent(0.9)
        iconView.contentMode = .scaleAspectFit

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16)
        ])

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = Colors.subtext

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = Colors.text

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueLabel)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    func setTitle(_ text: String) { titleLabel.text = text }
    func setValue(_ text: String) { valueLabel.text = text }
}

// MARK: - Storage Keys
enum LevelStorageKeys {
    static let currentLevel = "aiqo.currentLevel"
    static let currentLevelProgress = "aiqo.currentLevelProgress"
    static let legacyTotalPoints = "aiqo.legacyTotalPoints"
}
