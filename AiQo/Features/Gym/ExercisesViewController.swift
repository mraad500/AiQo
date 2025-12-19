import UIKit
import HealthKit

protocol ExercisesViewControllerDelegate: AnyObject {
    func exercisesViewController(_ vc: ExercisesViewController,
                                 didSelectWorkoutNamed name: String,
                                 activityType: HKWorkoutActivityType)
}

final class ExercisesViewController: UIViewController {

    weak var delegate: ExercisesViewControllerDelegate?

    private let scroll = UIScrollView()
    private let stack = UIStackView()

    // ألوان الكروت حسب AiQo
    private let cardColors: [UIColor] = [
        Colors.sand,
        Colors.mint,
        Colors.sand,
        Colors.mint,
        Colors.sand
    ]

    // MARK: - نموذج التمارين (يستخدم مفاتيح التعريب)
    private struct Exercise {
        let titleKey: String
        let activity: HKWorkoutActivityType
        let systemIcon: String
    }

    // MARK: - التمارين (المفاتيح لازم تطابق Localizable.strings)
    private let exercises: [Exercise] = [
        .init(
            titleKey: "exercise.gratitude.title",
            activity: .mindAndBody,
            systemIcon: "sparkles"
        ),
        .init(
            titleKey: "exercise.walk.indoor.title",
            activity: .walking,
            systemIcon: "figure.walk"
        ),
        .init(
            titleKey: "exercise.walk.outdoor.title",
            activity: .walking,
            systemIcon: "figure.walk.circle"
        ),
        .init(
            titleKey: "exercise.run.indoor.title",
            activity: .running,
            systemIcon: "figure.run"
        ),
        .init(
            titleKey: "exercise.run.outdoor.title",
            activity: .running,
            systemIcon: "figure.run.circle"
        )
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        layout()
        populate()
    }

    // MARK: - Layout
    private func layout() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)

        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    // MARK: - Build rows
    private func populate() {
        // لو تحب تعيد البناء لاحقًا
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (idx, item) in exercises.enumerated() {
            let localizedTitle = NSLocalizedString(
                item.titleKey,
                comment: "Exercise card title"
            )

            let row = makeRow(
                title: localizedTitle,
                systemIcon: item.systemIcon,
                index: idx
            )

            row.tag = idx
            let tap = UITapGestureRecognizer(target: self,
                                             action: #selector(cardTapped(_:)))
            row.addGestureRecognizer(tap)
            stack.addArrangedSubview(row)
        }
    }

    private func makeRow(title: String, systemIcon: String, index: Int) -> UIView {

        let container = UIView()
        container.backgroundColor = cardColors[index % cardColors.count]
        container.layer.cornerRadius = 28
        container.layer.masksToBounds = false

        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.08
        container.layer.shadowRadius = 12
        container.layer.shadowOffset = CGSize(width: 0, height: 8)

        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 116).isActive = true
        container.isUserInteractionEnabled = true

        // Icon
        let icon = UIImageView(image: UIImage(systemName: systemIcon))
        icon.preferredSymbolConfiguration = .init(pointSize: 26, weight: .semibold)
        icon.tintColor = .black
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 30).isActive = true

        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .heavy)
        titleLabel.textColor = .black

        let hStack = UIStackView(arrangedSubviews: [icon, titleLabel, UIView()])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 16
        hStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            hStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            hStack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    // MARK: - Tap
    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let idx = view.tag
        guard exercises.indices.contains(idx) else { return }

        let item = exercises[idx]
        let localizedTitle = NSLocalizedString(
            item.titleKey,
            comment: "Exercise sheet title"
        )

        delegate?.exercisesViewController(
            self,
            didSelectWorkoutNamed: localizedTitle,
            activityType: item.activity
        )
    }
}
