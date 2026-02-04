import UIKit

// ==========================================
// MARK: - WinsViewController
// ==========================================

final class WinsViewController: UIViewController {

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Wins"
        l.font = .systemFont(ofSize: 34, weight: .heavy)
        l.textColor = .label
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Unlock rewards by staying consistent ✨"
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = .secondaryLabel
        l.numberOfLines = 2
        return l
    }()

    private let grid = UIStackView()

    // MARK: - Data Models
    struct WinItem {
        let title: String
        let subtitle: String
        let icon: String
        let themeColor: UIColor // اللون الأساسي للكارت
        let progress: CGFloat
        let isLocked: Bool
    }
    
    // تعريف الألوان الاحترافية (نفس ستايل التطبيقات العالمية)
    // Warm Orange
    // تعريف الألوان الاحترافية (نسخة ألوان قوية ومشبعة)
    
    // Warm Orange (برتقالي دافي وقوي)
    // ألوان قوية ومشبعة 95% (Vibrant Palette)
    
    // Deep Orange (برتقالي غني)
    private let colorStreak = UIColor(red: 1.00, green: 0.65, blue: 0.20, alpha: 1)
    private let tintStreak  = UIColor.white // الأيقونة تصير بيضة لأن الخلفية قوية
    
    // Punchy Pink (وردي فاقع)
    private let colorHeart  = UIColor(red: 1.00, green: 0.40, blue: 0.55, alpha: 1)
    private let tintHeart   = UIColor.white
    
    // Intense Teal (تركوازي عميق)
    private let colorSteps  = UIColor(red: 0.00, green: 0.75, blue: 0.65, alpha: 1)
    private let tintSteps   = UIColor.white
    
    // Electric Purple (بنفسجي كهربائي)
    private let colorZen    = UIColor(red: 0.55, green: 0.45, blue: 0.95, alpha: 1)
    private let tintZen     = UIColor.white

    private lazy var items: [WinItem] = [
        .init(title: "7-Day Streak", subtitle: "Train 7 days total", icon: "flame.fill",
              themeColor: colorStreak, progress: 0.35, isLocked: true),

        .init(title: "Heart Hero", subtitle: "Hit target BPM 3 times", icon: "heart.fill",
              themeColor: colorHeart, progress: 0.62, isLocked: true),

        .init(title: "Step Master", subtitle: "10k steps in one day", icon: "figure.walk",
              themeColor: colorSteps, progress: 1.0, isLocked: false), // Completed

        .init(title: "Gratitude", subtitle: "Log gratitude 5 times", icon: "sparkles",
              themeColor: colorZen, progress: 0.20, isLocked: true)
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        renderGrid()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.contentInset.bottom = 40
    }

    // MARK: - Setup Layout
    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // Header
        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headerStack)
        
        // Grid Container
        grid.axis = .vertical
        grid.spacing = 16 // Spacing between rows
        grid.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grid)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 10),
            headerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            grid.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 24),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Render Grid
    private func renderGrid() {
        // Clear old views
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var idx = 0
        while idx < items.count {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 16
            rowStack.distribution = .fillEqually
            
            // First Item
            let card1 = ModernCardView()
            configureCard(card1, with: items[idx])
            rowStack.addArrangedSubview(card1)
            idx += 1
            
            // Second Item (if exists)
            if idx < items.count {
                let card2 = ModernCardView()
                configureCard(card2, with: items[idx])
                rowStack.addArrangedSubview(card2)
                idx += 1
            } else {
                // Spacer for empty slot to keep alignment left
                let spacer = UIView()
                rowStack.addArrangedSubview(spacer)
            }
            
            grid.addArrangedSubview(rowStack)
        }

        // Weekly Chest (Featured Item)
        addFeaturedSection()
    }
    
    private func configureCard(_ card: ModernCardView, with item: WinItem) {
        // Mapping themes to icons based on item color logic
        var iconTint: UIColor = .black
        
        // Simple logic to pick darken color for elements based on background
        if item.themeColor == colorStreak { iconTint = tintStreak }
        else if item.themeColor == colorHeart { iconTint = tintHeart }
        else if item.themeColor == colorSteps { iconTint = tintSteps }
        else { iconTint = tintZen }

        card.setup(
            title: item.title,
            subtitle: item.subtitle,
            iconName: item.icon,
            bgColor: item.themeColor,
            accentColor: iconTint,
            progress: item.progress,
            isLocked: item.isLocked
        )
        
        // Add Tap Action
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCardTap(_:)))
        card.addGestureRecognizer(tap)
    }

    private func addFeaturedSection() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        // Subtle separation
        let line = UIView()
        line.backgroundColor = .systemGray5
        line.translatesAutoresizingMaskIntoConstraints = false
        
        // Featured Card
        let featuredCard = ModernCardView()
        featuredCard.setup(
            title: "Weekly Chest",
            subtitle: "Complete 3 workouts this week to open",
            iconName: "trophy.fill",
            bgColor: UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1), // Light Gray/White
            accentColor: .systemOrange,
            progress: 0.5,
            isLocked: true
        )
        featuredCard.translatesAutoresizingMaskIntoConstraints = false
        
        // Adjust featured card layout manually since it's full width
        grid.addArrangedSubview(line)
        grid.addArrangedSubview(featuredCard)
        
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        // Add extra spacing before line
        grid.setCustomSpacing(24, after: grid.arrangedSubviews[grid.arrangedSubviews.count - 3])
        grid.setCustomSpacing(24, after: line)
        
        featuredCard.heightAnchor.constraint(equalToConstant: 100).isActive = true
    }

    @objc private func handleCardTap(_ gesture: UITapGestureRecognizer) {
        guard let card = gesture.view else { return }
        
        // Bouncy Animation
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut], animations: {
            card.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 5, options: [], animations: {
                card.transform = .identity
            }, completion: nil)
        }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// ==========================================
// MARK: - Modern Card View (Custom Component)
// ==========================================

class ModernCardView: UIView {
    
    private let iconContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let statusIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .bold)
        l.textColor = .black.withAlphaComponent(0.85)
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .black.withAlphaComponent(0.5)
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    private let progressBar = ModernProgressBar()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func commonInit() {
        self.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        self.layer.cornerRadius = 24
        // Shadow Implementation
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.06
        self.layer.shadowOffset = CGSize(width: 0, height: 6)
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
        
        addSubview(iconContainer)
        iconContainer.addSubview(iconImageView)
        addSubview(statusIcon)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(progressBar)
        
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Icon
            iconContainer.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),
            
            // Status (Lock/Check)
            statusIcon.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            statusIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statusIcon.widthAnchor.constraint(equalToConstant: 20),
            statusIcon.heightAnchor.constraint(equalToConstant: 20),
            
            // Text
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Progress Bar
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            progressBar.heightAnchor.constraint(equalToConstant: 6)
        ])
    }
    
    func setup(title: String, subtitle: String, iconName: String, bgColor: UIColor, accentColor: UIColor, progress: CGFloat, isLocked: Bool) {
        self.backgroundColor = bgColor
        
        titleLabel.text = title
        subtitleLabel.text = subtitle
        
        iconImageView.image = UIImage(systemName: iconName)
        iconImageView.tintColor = accentColor
        
        iconContainer.backgroundColor = .white.withAlphaComponent(0.6)
        
        progressBar.setProgress(progress, color: accentColor)
        
        // Status Icon Logic
        if isLocked {
            statusIcon.image = UIImage(systemName: "lock.fill")
            statusIcon.tintColor = .black.withAlphaComponent(0.2)
        } else {
            statusIcon.image = UIImage(systemName: "checkmark.seal.fill")
            statusIcon.tintColor = accentColor
        }
    }
}

// ==========================================
// MARK: - Modern Progress Bar
// ==========================================

class ModernProgressBar: UIView {
    private let trackLayer = CALayer()
    private let progressLayer = CALayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
        trackLayer.backgroundColor = UIColor.black.withAlphaComponent(0.05).cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        trackLayer.frame = bounds
        trackLayer.cornerRadius = bounds.height / 2
        
        progressLayer.cornerRadius = bounds.height / 2
        var rect = bounds
        rect.size.width = bounds.width * (progressLayer.frame.width / bounds.width) // Maintain ratio
        
        // This is just a simple layout update, in real app set frame based on stored progress
    }
    
    func setProgress(_ value: CGFloat, color: UIColor) {
        let clamped = max(0, min(1, value))
        progressLayer.backgroundColor = color.cgColor
        
        // Update frame immediately
        DispatchQueue.main.async {
            self.progressLayer.frame = CGRect(x: 0, y: 0, width: self.bounds.width * clamped, height: self.bounds.height)
        }
    }
}
