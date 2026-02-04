import UIKit

// =========================
// File: Features/Gym/RewardsViewController.swift
// iOS 18 - Full working screen (Scroll + Grid + Glass Cards)
// =========================

final class RewardsViewController: UIViewController {

    // MARK: - UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Rewards"
        l.font = .systemFont(ofSize: 28, weight: .heavy)
        l.textColor = .label
        l.numberOfLines = 1
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Unlock rewards by staying consistent ✨"
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .secondaryLabel
        l.numberOfLines = 2
        return l
    }()

    private let grid = UIStackView()

    // MARK: - Brand colors (same as your exercises/rewards palette)
    private let brandMint  = UIColor(red: 0.77, green: 0.94, blue: 0.86, alpha: 1)
    private let brandSand  = UIColor(red: 0.97, green: 0.84, blue: 0.64, alpha: 1)
    private let brandLemon = UIColor(red: 1.00, green: 0.93, blue: 0.72, alpha: 1)
    private let brandLav   = UIColor(red: 0.96, green: 0.88, blue: 1.00, alpha: 1)

    // MARK: - Model
    struct RewardItem {
        let title: String
        let subtitle: String
        let icon: String
        let tint: UIColor
        let progress: CGFloat // 0...1
        let isLocked: Bool
    }

    private var items: [RewardItem] = [
        .init(title: "7-Day Streak", subtitle: "Train 7 days total", icon: "flame.fill", tint: UIColor(red: 1.00, green: 0.78, blue: 0.22, alpha: 1), progress: 0.35, isLocked: true),
        .init(title: "Heart Hero", subtitle: "Hit target BPM 3 times", icon: "heart.fill", tint: UIColor(red: 1.00, green: 0.40, blue: 0.55, alpha: 1), progress: 0.62, isLocked: true),
        .init(title: "Step Master", subtitle: "10k steps in one day", icon: "figure.walk", tint: UIColor(red: 0.35, green: 0.85, blue: 0.65, alpha: 1), progress: 0.88, isLocked: false),
        .init(title: "Gratitude Mode", subtitle: "Log gratitude 5 times", icon: "sparkles", tint: UIColor(red: 0.70, green: 0.60, blue: 0.95, alpha: 1), progress: 0.20, isLocked: true)
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        buildUI()
        renderRewards()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // helps scroll content size in some edge cases
        scrollView.contentInset.bottom = 24
    }

    // MARK: - UI Build
    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

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

            // critical: match widths so stack/grid can compute height
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // Header
        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(headerStack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 18),
            headerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])

        // Grid
        grid.axis = .vertical
        grid.spacing = 14
        grid.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            grid.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    // MARK: - Render
    private func renderRewards() {
        // clear
        grid.arrangedSubviews.forEach { v in
            grid.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        // Two-column rows
        var idx = 0
        while idx < items.count {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 14
            row.distribution = .fillEqually

            let left = makeRewardCard(items[idx])
            row.addArrangedSubview(left)
            idx += 1

            if idx < items.count {
                let right = makeRewardCard(items[idx])
                row.addArrangedSubview(right)
                idx += 1
            } else {
                // keep layout balanced if odd count
                row.addArrangedSubview(UIView())
            }

            grid.addArrangedSubview(row)
        }

        // Add a “big” featured card
        grid.setCustomSpacing(18, after: grid.arrangedSubviews.last ?? grid)

        let featured = makeFeaturedCard(
            title: "Weekly Chest",
            subtitle: "Complete 3 workouts this week",
            tint: brandMint,
            icon: "gift.fill",
            progress: 0.55
        )
        grid.addArrangedSubview(featured)
    }

    // MARK: - Card Factory
    private func makeRewardCard(_ item: RewardItem) -> UIView {
        let card = GlassCardView()
        card.heightAnchor.constraint(equalToConstant: 148).isActive = true
        card.setTint(item.isLocked ? item.tint.withAlphaComponent(0.55) : item.tint.withAlphaComponent(0.80))

        let iconBg = UIView()
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.backgroundColor = item.tint.withAlphaComponent(0.20)
        iconBg.layer.cornerRadius = 14

        let icon = UIImageView(image: UIImage(systemName: item.icon))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = item.tint

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = item.title
        title.font = .systemFont(ofSize: 16, weight: .heavy)
        title.textColor = .label
        title.numberOfLines = 2

        let subtitle = UILabel()
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        subtitle.text = item.subtitle
        subtitle.font = .systemFont(ofSize: 12.5, weight: .semibold)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 2

        let progress = ProgressBarView()
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.setProgress(item.progress, tint: item.tint)

        let lock = UIImageView(image: UIImage(systemName: item.isLocked ? "lock.fill" : "checkmark.seal.fill"))
        lock.translatesAutoresizingMaskIntoConstraints = false
        lock.tintColor = item.isLocked ? .secondaryLabel : item.tint

        card.contentView.addSubview(iconBg)
        iconBg.addSubview(icon)
        card.contentView.addSubview(title)
        card.contentView.addSubview(subtitle)
        card.contentView.addSubview(progress)
        card.contentView.addSubview(lock)

        NSLayoutConstraint.activate([
            iconBg.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 14),
            iconBg.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 14),
            iconBg.widthAnchor.constraint(equalToConstant: 44),
            iconBg.heightAnchor.constraint(equalToConstant: 44),

            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            lock.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 14),
            lock.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -14),

            title.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 14),
            title.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -14),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 14),
            subtitle.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -14),

            progress.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 14),
            progress.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -14),
            progress.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -14),
            progress.heightAnchor.constraint(equalToConstant: 10)
        ])

        // Tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(onCardTap(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        card.accessibilityLabel = item.title

        return card
    }

    private func makeFeaturedCard(title: String, subtitle: String, tint: UIColor, icon: String, progress: CGFloat) -> UIView {
        let card = GlassCardView()
        card.heightAnchor.constraint(equalToConstant: 130).isActive = true
        card.setTint(tint.withAlphaComponent(0.85))

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = tint

        let titleL = UILabel()
        titleL.translatesAutoresizingMaskIntoConstraints = false
        titleL.text = title
        titleL.font = .systemFont(ofSize: 18, weight: .heavy)
        titleL.textColor = .label

        let subtitleL = UILabel()
        subtitleL.translatesAutoresizingMaskIntoConstraints = false
        subtitleL.text = subtitle
        subtitleL.font = .systemFont(ofSize: 13, weight: .semibold)
        subtitleL.textColor = .secondaryLabel
        subtitleL.numberOfLines = 2

        let progressView = ProgressBarView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.setProgress(progress, tint: tint)

        card.contentView.addSubview(iconView)
        card.contentView.addSubview(titleL)
        card.contentView.addSubview(subtitleL)
        card.contentView.addSubview(progressView)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),

            titleL.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleL.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 16),
            titleL.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),

            subtitleL.leadingAnchor.constraint(equalTo: titleL.leadingAnchor),
            subtitleL.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 4),
            subtitleL.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),

            progressView.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
            progressView.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 10)
        ])

        return card
    }

    // MARK: - Actions
    @objc private func onCardTap(_ g: UITapGestureRecognizer) {
        guard let v = g.view else { return }
        // tiny feedback
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        // simple pulse animation
        UIView.animate(withDuration: 0.10, animations: {
            v.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }, completion: { _ in
            UIView.animate(withDuration: 0.18) { v.transform = .identity }
        })
    }
}

// =========================
// MARK: - GlassCardView (Reusable)
// =========================


// =========================
// MARK: - ProgressBarView
// =========================

final class ProgressBarView: UIView {

    private let track = UIView()
    private let fill = UIView()
    private var fillWidth: NSLayoutConstraint?

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

        track.translatesAutoresizingMaskIntoConstraints = false
        fill.translatesAutoresizingMaskIntoConstraints = false

        addSubview(track)
        track.addSubview(fill)

        track.backgroundColor = UIColor.label.withAlphaComponent(0.10)
        track.layer.cornerRadius = 5
        track.layer.masksToBounds = true

        fill.backgroundColor = UIColor.label.withAlphaComponent(0.35)
        fill.layer.cornerRadius = 5
        fill.layer.masksToBounds = true

        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),

            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor)
        ])

        fillWidth = fill.widthAnchor.constraint(equalToConstant: 0)
        fillWidth?.isActive = true
    }

    func setProgress(_ p: CGFloat, tint: UIColor) {
        let clamped = max(0, min(1, p))
        fill.backgroundColor = tint.withAlphaComponent(0.85)

        // update width after layout
        layoutIfNeeded()
        let w = bounds.width * clamped
        fillWidth?.constant = w

        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // keep rounding consistent
        track.layer.cornerRadius = bounds.height / 2
        fill.layer.cornerRadius = bounds.height / 2
    }
}
