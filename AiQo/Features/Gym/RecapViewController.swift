import UIKit

// =========================
// File: Features/Gym/RecapViewController.swift
// Workout History / Recap (premium cards + date pills + bottom sheet details)
// =========================

final class RecapViewController: UIViewController {

    // MARK: UI
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stack = UIStackView()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "History"
        l.font = .systemFont(ofSize: 34, weight: .heavy)
        l.textColor = .label
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Your journey tracked via Apple Health."
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .secondaryLabel
        l.numberOfLines = 2
        return l
    }()

    // MARK: Model
    struct WorkoutRow {
        let dateTitle: String
        let items: [WorkoutItem]
    }

    struct WorkoutItem {
        let title: String
        let source: String
        let duration: String
        let calories: String
        let icon: String
        let tint: UIColor
    }

    // Demo data (replace later from HealthKit)
    private let data: [WorkoutRow] = [
        .init(dateTitle: "15 Jan 2026", items: [
            .init(title: "Running", source: "Health", duration: "00:00", calories: "50 kcal", icon: "figure.run",
                  tint: UIColor(red: 1.00, green: 0.78, blue: 0.45, alpha: 1.0)),
            .init(title: "Walking", source: "AiQo", duration: "03:33", calories: "9 kcal", icon: "figure.walk",
                  tint: UIColor(red: 0.25, green: 0.85, blue: 0.70, alpha: 1.0)),
            .init(title: "Walking", source: "AiQo", duration: "00:11", calories: "--", icon: "figure.walk",
                  tint: UIColor(red: 0.66, green: 0.58, blue: 0.98, alpha: 1.0)),
            .init(title: "Walking", source: "AiQo", duration: "00:03", calories: "--", icon: "figure.walk",
                  tint: UIColor(red: 0.72, green: 0.86, blue: 0.34, alpha: 1.0)),
        ]),
        .init(dateTitle: "14 Jan 2026", items: [
            .init(title: "Walking", source: "AiQo", duration: "27:36", calories: "211 kcal", icon: "figure.walk",
                  tint: UIColor(red: 1.00, green: 0.78, blue: 0.45, alpha: 1.0)),
            .init(title: "Walking", source: "AiQo", duration: "00:09", calories: "--", icon: "figure.walk",
                  tint: UIColor(red: 0.25, green: 0.85, blue: 0.70, alpha: 1.0)),
            .init(title: "Walking", source: "AiQo", duration: "08:30", calories: "42 kcal", icon: "figure.walk",
                  tint: UIColor(red: 0.66, green: 0.58, blue: 0.98, alpha: 1.0)),
        ])
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildUI()
        render()
    }

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
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerStack)

        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 18),
            headerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            stack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func render() {
        stack.arrangedSubviews.forEach { v in
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }

        for section in data {
            stack.addArrangedSubview(makeDatePill(section.dateTitle))

            for item in section.items {
                stack.addArrangedSubview(makeHistoryCard(item))
            }
        }
    }

    // MARK: - Date Pill
    private func makeDatePill(_ text: String) -> UIView {
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.78)
        pill.layer.cornerRadius = 16
        pill.layer.cornerCurve = .continuous

        // subtle shadow
        pill.layer.shadowColor = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.06
        pill.layer.shadowRadius = 10
        pill.layer.shadowOffset = CGSize(width: 0, height: 6)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label

        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 9),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -9),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -14),
        ])

        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(pill)
        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            pill.topAnchor.constraint(equalTo: wrap.topAnchor),
            pill.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
        ])

        return wrap
    }

    // MARK: - Premium Card
    private func makeHistoryCard(_ item: WorkoutItem) -> UIView {
        let card = SoftGlassCardView()
        card.heightAnchor.constraint(equalToConstant: 104).isActive = true

        // أقوى/أوضح مثل كروت التمارين
        card.setTint(item.tint, intensity: 0.42)

        // زوايا أكثر دوران
        card.layer.cornerRadius = 28
        card.layer.cornerCurve = .continuous

        // ظل ورقي خفيف
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.10
        card.layer.shadowRadius = 18
        card.layer.shadowOffset = CGSize(width: 0, height: 10)

        let iconBG = UIView()
        iconBG.translatesAutoresizingMaskIntoConstraints = false
        iconBG.backgroundColor = UIColor.black.withAlphaComponent(0.10)
        iconBG.layer.cornerRadius = 22
        iconBG.layer.cornerCurve = .continuous

        let icon = UIImageView(image: UIImage(systemName: item.icon))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .label
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = item.title
        title.font = .systemFont(ofSize: 19, weight: .heavy)
        title.textColor = .label

        let source = UILabel()
        source.translatesAutoresizingMaskIntoConstraints = false
        source.text = item.source
        source.font = .systemFont(ofSize: 13, weight: .semibold)
        source.textColor = UIColor.label.withAlphaComponent(0.55)

        let duration = UILabel()
        duration.translatesAutoresizingMaskIntoConstraints = false
        duration.text = item.duration
        duration.font = .systemFont(ofSize: 19, weight: .heavy)
        duration.textColor = .label
        duration.textAlignment = .right

        let calories = UILabel()
        calories.translatesAutoresizingMaskIntoConstraints = false
        calories.text = item.calories
        calories.font = .systemFont(ofSize: 13, weight: .semibold)
        calories.textColor = UIColor.label.withAlphaComponent(0.55)
        calories.textAlignment = .right

        // progress bar (subtle)
        let barTrack = UIView()
        barTrack.translatesAutoresizingMaskIntoConstraints = false
        barTrack.backgroundColor = UIColor.black.withAlphaComponent(0.10)
        barTrack.layer.cornerRadius = 5
        barTrack.layer.cornerCurve = .continuous

        let barFill = UIView()
        barFill.translatesAutoresizingMaskIntoConstraints = false
        barFill.backgroundColor = UIColor.black.withAlphaComponent(0.16)
        barFill.layer.cornerRadius = 5
        barFill.layer.cornerCurve = .continuous

        card.contentView.addSubview(iconBG)
        iconBG.addSubview(icon)
        card.contentView.addSubview(title)
        card.contentView.addSubview(source)
        card.contentView.addSubview(duration)
        card.contentView.addSubview(calories)
        card.contentView.addSubview(barTrack)
        barTrack.addSubview(barFill)

        NSLayoutConstraint.activate([
            iconBG.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
            iconBG.centerYAnchor.constraint(equalTo: card.contentView.centerYAnchor),
            iconBG.widthAnchor.constraint(equalToConstant: 62),
            iconBG.heightAnchor.constraint(equalToConstant: 62),

            icon.centerXAnchor.constraint(equalTo: iconBG.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBG.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),

            title.leadingAnchor.constraint(equalTo: iconBG.trailingAnchor, constant: 14),
            title.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 18),

            source.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            source.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),

            duration.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
            duration.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 18),

            calories.trailingAnchor.constraint(equalTo: duration.trailingAnchor),
            calories.topAnchor.constraint(equalTo: duration.bottomAnchor, constant: 2),

            barTrack.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            barTrack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
            barTrack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -14),
            barTrack.heightAnchor.constraint(equalToConstant: 10),

            barFill.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            barFill.widthAnchor.constraint(equalTo: barTrack.widthAnchor, multiplier: 0.72) // ثابت demo
        ])

        // Tap -> Bottom sheet
        let tap = UITapGestureRecognizer(target: self, action: #selector(onCardTap(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true

        // store item in accessibilityLabel (quick trick)
        card.accessibilityLabel = "\(item.title)|\(item.source)|\(item.duration)|\(item.calories)|\(item.icon)"

        return card
    }

    // MARK: - Actions
    @objc private func onCardTap(_ g: UITapGestureRecognizer) {
        guard let card = g.view else { return }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        UIView.animate(withDuration: 0.10, animations: {
            card.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }, completion: { _ in
            UIView.animate(withDuration: 0.18) { card.transform = .identity }
        })

        guard let payload = card.accessibilityLabel else { return }
        let parts = payload.split(separator: "|").map(String.init)
        guard parts.count >= 5 else { return }

        let item = WorkoutItem(
            title: parts[0],
            source: parts[1],
            duration: parts[2],
            calories: parts[3],
            icon: parts[4],
            tint: .systemMint
        )

        presentDetailsSheet(for: item)
    }

    private func presentDetailsSheet(for item: WorkoutItem) {
        let vc = WorkoutDetailsSheetViewController(item: item)
        vc.modalPresentationStyle = .pageSheet

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }

        present(vc, animated: true)
    }
}

// =========================
// MARK: - Bottom Sheet Details
// =========================

final class WorkoutDetailsSheetViewController: UIViewController {

    private let item: RecapViewController.WorkoutItem

    init(item: RecapViewController.WorkoutItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private let headerCard = SoftGlassCardView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.70)

        build()
    }

    private func build() {
        headerCard.translatesAutoresizingMaskIntoConstraints = false
        headerCard.layer.cornerRadius = 28
        headerCard.layer.cornerCurve = .continuous
        headerCard.setTint(.secondarySystemBackground, intensity: 0.35)

        view.addSubview(headerCard)

        let icon = UIImageView(image: UIImage(systemName: item.icon))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .label

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = item.title
        title.font = .systemFont(ofSize: 22, weight: .heavy)
        title.textColor = .label

        let source = UILabel()
        source.translatesAutoresizingMaskIntoConstraints = false
        source.text = "Source: \(item.source)"
        source.font = .systemFont(ofSize: 14, weight: .semibold)
        source.textColor = .secondaryLabel

        let duration = makeKeyValueRow("Duration", item.duration)
        let calories = makeKeyValueRow("Calories", item.calories)

        headerCard.contentView.addSubview(icon)
        headerCard.contentView.addSubview(title)
        headerCard.contentView.addSubview(source)
        headerCard.contentView.addSubview(duration)
        headerCard.contentView.addSubview(calories)

        NSLayoutConstraint.activate([
            headerCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            icon.topAnchor.constraint(equalTo: headerCard.contentView.topAnchor, constant: 18),
            icon.leadingAnchor.constraint(equalTo: headerCard.contentView.leadingAnchor, constant: 18),
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: icon.centerYAnchor),
            title.trailingAnchor.constraint(equalTo: headerCard.contentView.trailingAnchor, constant: -18),

            source.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            source.leadingAnchor.constraint(equalTo: headerCard.contentView.leadingAnchor, constant: 18),
            source.trailingAnchor.constraint(equalTo: headerCard.contentView.trailingAnchor, constant: -18),

            duration.topAnchor.constraint(equalTo: source.bottomAnchor, constant: 14),
            duration.leadingAnchor.constraint(equalTo: headerCard.contentView.leadingAnchor, constant: 18),
            duration.trailingAnchor.constraint(equalTo: headerCard.contentView.trailingAnchor, constant: -18),

            calories.topAnchor.constraint(equalTo: duration.bottomAnchor, constant: 10),
            calories.leadingAnchor.constraint(equalTo: headerCard.contentView.leadingAnchor, constant: 18),
            calories.trailingAnchor.constraint(equalTo: headerCard.contentView.trailingAnchor, constant: -18),
            calories.bottomAnchor.constraint(equalTo: headerCard.contentView.bottomAnchor, constant: -18)
        ])
    }

    private func makeKeyValueRow(_ key: String, _ value: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let k = UILabel()
        k.translatesAutoresizingMaskIntoConstraints = false
        k.text = key
        k.font = .systemFont(ofSize: 14, weight: .semibold)
        k.textColor = .secondaryLabel

        let v = UILabel()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.text = value
        v.font = .systemFont(ofSize: 16, weight: .heavy)
        v.textColor = .label
        v.textAlignment = .right

        row.addSubview(k)
        row.addSubview(v)

        NSLayoutConstraint.activate([
            k.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            k.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            v.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            v.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            v.leadingAnchor.constraint(greaterThanOrEqualTo: k.trailingAnchor, constant: 12),

            row.heightAnchor.constraint(equalToConstant: 26)
        ])

        return row
    }
}
