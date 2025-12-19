import UIKit

/// كارت يعرض مستوى المستخدم الحالي (Level) في شاشة البروفايل
final class LevelCardView: UIView {

    // MARK: - UI

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let levelLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let progressBackground = UIView()
    private let progressFill = UIView()

    // MARK: - State

    /// المستوى الحالي (يقرأ من UserDefaults إذا متوفر)
    var level: Int = 1 {
        didSet { updateUI() }
    }

    /// نسبة التقدم داخل المستوى الحالي [0,1]
    var levelProgress: CGFloat = 0 {
        didSet { updateProgress() }
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        reloadFromStorage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        reloadFromStorage()
    }

    // MARK: - Public API

    /// تستخدمها شاشة البروفايل إذا حابّة تمّرر Level صراحةً
    func configure(level: Int, progress: CGFloat? = nil) {
        self.level = max(level, 1)
        if let progress {
            self.levelProgress = min(max(progress, 0), 1)
        }
    }

    /// تقرأ المستوى المخزَّن من LegacyCalculationViewController
    func reloadFromStorage() {
        let storedLevel = UserDefaults.standard.integer(forKey: LevelStorageKeys.currentLevel)
        let finalLevel = max(storedLevel, 1)
        level = finalLevel

        let storedProgress = UserDefaults.standard.double(forKey: LevelStorageKeys.currentLevelProgress)
        if storedProgress > 0 {
            levelProgress = CGFloat(min(max(storedProgress, 0), 1))
        } else {
            levelProgress = 0
        }
    }

    // MARK: - Setup

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = Colors.card
        containerView.layer.cornerRadius = 22
        containerView.layer.cornerCurve = .continuous
        containerView.layer.masksToBounds = false
        containerView.layer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        containerView.layer.shadowOpacity = 1
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOffset = CGSize(width: 0, height: 8)

        addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14)
        ])

        // Title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = Colors.subtext
        titleLabel.text = "Level"

        // Level value
        levelLabel.font = .systemFont(ofSize: 28, weight: .bold)
        levelLabel.textColor = Colors.text
        levelLabel.textAlignment = .left

        // Subtitle
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = Colors.subtext
        subtitleLabel.numberOfLines = 0

        // Progress bar
        progressBackground.translatesAutoresizingMaskIntoConstraints = false
        progressBackground.backgroundColor = Colors.sand.withAlphaComponent(0.25)
        progressBackground.layer.cornerRadius = 6
        progressBackground.layer.cornerCurve = .continuous

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = Colors.sand
        progressFill.layer.cornerRadius = 6
        progressFill.layer.cornerCurve = .continuous

        progressBackground.addSubview(progressFill)

        NSLayoutConstraint.activate([
            progressFill.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressBackground.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBackground.bottomAnchor),
            progressFill.widthAnchor.constraint(equalToConstant: 0) // سيتحدث لاحقاً
        ])

        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(progressBackground)

        NSLayoutConstraint.activate([
            progressBackground.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressBackground.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressBackground.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressBackground.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            progressBackground.heightAnchor.constraint(equalToConstant: 10)
        ])

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(levelLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(progressContainer)
    }

    // MARK: - UI Updates

    private func updateUI() {
        levelLabel.text = "Level \(level)"

        if level == 1 {
            subtitleLabel.text = "كل نقطة جديدة تقرّبك من أول قفزة في AiQo."
        } else if level < 5 {
            subtitleLabel.text = "استمر، مستوى نشاطك يرتفع خطوة بعد خطوة."
        } else {
            subtitleLabel.text = "أنت داخل رحلة مستويات AiQo المتقدمة، خلّ استمراريتك تحچي عنك."
        }

        updateProgress()
    }

    private func updateProgress() {
        layoutIfNeeded()
        guard progressBackground.bounds.width > 0 else { return }

        let clamped = min(max(levelProgress, 0), 1)
        let targetWidth = progressBackground.bounds.width * clamped

        if let widthConstraint = progressFill.constraints.first(where: { $0.firstAttribute == .width }) {
            widthConstraint.constant = targetWidth
        }

        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.progressBackground.layoutIfNeeded()
        }
    }
}

// MARK: - Level Storage Keys

/// المفاتيح المشتركة بين LegacyCalculationViewController و LevelCardView
enum LevelStorageKeys {
    static let currentLevel = "aiqo.currentLevel"
    static let currentLevelProgress = "aiqo.currentLevelProgress"
    static let legacyTotalPoints = "aiqo.legacyTotalPoints"
}
