import UIKit

final class RewardsViewController: UIViewController {

    private let grid = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        layout()
        renderBadges()
    }

    private func layout() {
        grid.axis = .vertical
        grid.spacing = 14
        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Badges

    private struct Badge {
        let title: String
        let subtitle: String
        let systemIcon: String
        let color: UIColor
    }

    private func renderBadges() {
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let badges: [Badge] = [
            Badge(
                title: NSLocalizedString("rewards.badge.5kSteps.title", comment: "5K steps badge title"),
                subtitle: NSLocalizedString("rewards.badge.5kSteps.subtitle", comment: "5K steps badge subtitle"),
                systemIcon: "figure.walk.circle.fill",
                color: UIColor(red: 0.97, green: 0.84, blue: 0.64, alpha: 1)
            ),

            Badge(
                title: NSLocalizedString("rewards.badge.hydration.title", comment: "Hydration streak title"),
                subtitle: NSLocalizedString("rewards.badge.hydration.subtitle", comment: "Hydration streak subtitle"),
                systemIcon: "drop.fill",
                color: UIColor(red: 0.77, green: 0.94, blue: 0.86, alpha: 1)
            ),

            Badge(
                title: NSLocalizedString("rewards.badge.sleepHero.title", comment: "Sleep hero title"),
                subtitle: NSLocalizedString("rewards.badge.sleepHero.subtitle", comment: "Sleep hero subtitle"),
                systemIcon: "moon.stars.fill",
                color: UIColor(red: 0.96, green: 0.88, blue: 1.0, alpha: 1)
            ),

            Badge(
                title: NSLocalizedString("rewards.badge.consistencyKing.title", comment: "Consistency king title"),
                subtitle: NSLocalizedString("rewards.badge.consistencyKing.subtitle", comment: "Consistency king subtitle"),
                systemIcon: "crown.fill",
                color: UIColor(red: 1.0, green: 0.93, blue: 0.72, alpha: 1)
            )
        ]

        for badge in badges {
            let row = makeBadgeRow(badge)
            grid.addArrangedSubview(row)
        }
    }

    private func makeBadgeRow(_ badge: Badge) -> UIView {
        let container = UIView()
        container.backgroundColor = badge.color
        container.layer.cornerRadius = 24
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.08
        container.layer.shadowRadius = 12
        container.layer.shadowOffset = CGSize(width: 0, height: 6)
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 90).isActive = true

        // Icon
        let icon = UIImageView(image: UIImage(systemName: badge.systemIcon))
        icon.tintColor = .black
        icon.preferredSymbolConfiguration = .init(pointSize: 26, weight: .bold)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 34).isActive = true

        // Labels
        // Labels
        let titleLabel = UILabel()
        titleLabel.text = badge.title
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        titleLabel.textColor = .black

        let subtitleLabel = UILabel()
        subtitleLabel.text = badge.subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = UIColor.black.withAlphaComponent(0.6)
        subtitleLabel.numberOfLines = 2
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let hStack = UIStackView(arrangedSubviews: [icon, textStack, UIView()])
        hStack.alignment = .center
        hStack.spacing = 16
        hStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            hStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }
}
