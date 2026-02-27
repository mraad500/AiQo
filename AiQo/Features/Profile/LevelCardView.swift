import UIKit
import SwiftUI // نحتاجها إذا كنا سنستخدم Color الخاصة بـ SwiftUI للتحويل، أو نستخدم ألوان UIKit مباشرة

/// Ultra Modern Level Card (Level + Shield + Line Score + Progress)
final class LevelCardView: UIView {

    private let useGroupingSeparator = true

    // MARK: - UI
    private let containerView = UIView()

    private let gradientView = UIView()
    private let gradientLayer = CAGradientLayer()

    private let glassHost = UIVisualEffectView()
    private let borderLayer = CAShapeLayer()
    
    // 🛡️ Shield & Level Info
    private let shieldImageView = UIImageView()
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
    private let levelNumberBaselineOffset: CGFloat = -4

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
        containerView.backgroundColor = Colors.sand
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
            Colors.sand.withAlphaComponent(1.0).cgColor,
            UIColor.white.withAlphaComponent(0.22).cgColor,
            Colors.sand.withAlphaComponent(0.94).cgColor
        ]
        gradientLayer.locations = [0.0, 0.52, 1.0]
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
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.40).cgColor
        borderLayer.lineWidth = 1
        containerView.layer.addSublayer(borderLayer)
        
        // 🛡️ Shield Icon
        shieldImageView.translatesAutoresizingMaskIntoConstraints = false
        shieldImageView.contentMode = .scaleAspectFit
        shieldImageView.tintColor = UIColor.black.withAlphaComponent(0.88)
        
        NSLayoutConstraint.activate([
            shieldImageView.widthAnchor.constraint(equalToConstant: 22),
            shieldImageView.heightAnchor.constraint(equalToConstant: 22)
        ])

        // Labels
        leftTitleLabel.text = NSLocalizedString("level", value: "Level", comment: "")
        leftTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        leftTitleLabel.textColor = UIColor.black.withAlphaComponent(0.58)
        leftTitleLabel.alpha = 0.95

        levelNumberLabel.font = .systemFont(ofSize: 36, weight: .black)
        levelNumberLabel.textColor = UIColor.black.withAlphaComponent(0.88)
        levelNumberLabel.baselineAdjustment = .alignCenters
        levelNumberLabel.clipsToBounds = false

        // ✅ Stack row: [Shield] + [Level Label] + [Number]
        let levelRow = UIStackView(arrangedSubviews: [shieldImageView, leftTitleLabel, levelNumberLabel])
        levelRow.axis = .horizontal
        levelRow.alignment = .firstBaseline
        levelRow.spacing = 8
        levelRow.translatesAutoresizingMaskIntoConstraints = false
        
        // Custom spacing: Shield should be closer to text? or a bit separate.
        // Let's make shield centered vertically with the text somewhat.
        // Since alignment is firstBaseline, we need to be careful with the image.
        // Better: Put Shield in a separate center-aligned h-stack with the text stack.
        
        // Re-structure:
        // V-Stack for (Level title, Number) ? No, side by side is better.
        // Let's keep the row simple. Center alignment works best for icons + text usually, but baseline is good for text.
        levelRow.alignment = .center

        // Level Host
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

        // Top row (Level Info --- Score Pill)
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
        progressBackground.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        progressBackground.layer.cornerRadius = 9
        progressBackground.layer.cornerCurve = .continuous
        progressBackground.layer.masksToBounds = true

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        progressFill.layer.cornerRadius = 9
        progressFill.layer.cornerCurve = .continuous
        progressFill.layer.masksToBounds = true

        progressGlow.translatesAutoresizingMaskIntoConstraints = false
        progressGlow.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        progressGlow.layer.cornerRadius = 10
        progressGlow.layer.cornerCurve = .continuous
        progressGlow.layer.masksToBounds = false
        progressGlow.layer.shadowColor = UIColor.black.withAlphaComponent(0.24).cgColor
        progressGlow.layer.shadowOpacity = 1
        progressGlow.layer.shadowRadius = 10
        progressGlow.layer.shadowOffset = .zero

        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        progressIndicator.layer.cornerRadius = 7
        progressIndicator.layer.cornerCurve = .continuous
        progressIndicator.layer.borderWidth = 1
        progressIndicator.layer.borderColor = UIColor.white.withAlphaComponent(0.30).cgColor
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

        leftTitleLabel.attributedText = NSAttributedString(string: title, attributes: attrsTitle)
        levelNumberLabel.attributedText = NSAttributedString(string: number, attributes: attrsNumber)
        
        // 🛡️ Update Shield Icon & Color
        let shieldType = LevelSystem.getShield(for: level)
        shieldImageView.image = UIImage(systemName: LevelSystem.getShieldIconName(for: level))
        shieldImageView.tintColor = getShieldColor(for: shieldType)

        accessibilityLabel = "Level \(level), Line Score \(lineScore)"

        if animated {
            UIView.transition(with: levelNumberLabel, duration: 0.16, options: [.transitionCrossDissolve, .allowUserInteraction], animations: nil)
            
            // Pulse the shield
            UIView.animate(withDuration: 0.2, animations: {
                self.shieldImageView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    self.shieldImageView.transform = .identity
                }
            }
        }
    }
    
    // Helper to map ShieldTier to UIColor
    private func getShieldColor(for tier: LevelSystem.ShieldTier) -> UIColor {
        UIColor.black.withAlphaComponent(0.88)
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
        blurHost.alpha = 0.72

        layer.borderWidth = 1
        layer.borderColor = UIColor.black.withAlphaComponent(0.06).cgColor
        layer.shadowColor = UIColor.black.withAlphaComponent(0.10).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)

        iconView.image = UIImage(systemName: "chart.line.uptrend.xyaxis")
        iconView.tintColor = UIColor.black.withAlphaComponent(0.82)
        iconView.contentMode = .scaleAspectFit

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16)
        ])

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = UIColor.black.withAlphaComponent(0.58)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = UIColor.black.withAlphaComponent(0.86)

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
