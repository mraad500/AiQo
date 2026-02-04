// =========================
// File: Features/Gym/MyPlanViewController.swift
// Fix: remove top overlay, fix scroll, increase card contrast, round corners
// =========================

import UIKit

final class MyPlanViewController: BaseViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Background (NO rising color overlay)
    private let backgroundHost = UIView()
    private let blurOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))

    private let todayTitle: UILabel = {
        let label = UILabel()
        label.text = L10n.t("plan.today.title")
        label.font = .aiqoTitle(28)
        label.textAlignment = .natural
        label.textColor = .label
        return label
    }()

    private let statsCard = GlassCardView()
    private let statsHeader = SectionHeaderView(title: L10n.t("plan.section.overview"))

    private let stepsRow = StatRowView(icon: "figure.walk", title: L10n.t("plan.stats.steps.short"))
    private let caloriesRow = StatRowView(icon: "flame.fill", title: L10n.t("plan.stats.calories.short"))
    private let waterRow = StatRowView(icon: "drop.fill", title: L10n.t("plan.stats.water.short"))
    private let trainingRow = StatRowView(icon: "sparkles", title: L10n.t("plan.stats.training.short"), isSuggestion: true)

    private let todayWorkoutTitle: UILabel = {
        let label = UILabel()
        label.text = L10n.t("plan.today.workoutsTitle")
        label.font = .aiqoSection(22)
        label.textAlignment = .natural
        label.textColor = .label
        return label
    }()

    private let todayWorkoutCard = GlassCardView()
    private let todayExercisesStack = UIStackView()

    private let planTitle: UILabel = {
        let label = UILabel()
        label.text = L10n.t("plan.templates.title")
        label.font = .aiqoSection(22)
        label.textAlignment = .natural
        label.textColor = .label
        return label
    }()

    private let planCard = GlassCardView()
    private let planTextField = UITextField()
    private let addButton = UIButton(type: .system)
    private let templatesStack = UIStackView()

    // MARK: - Data

    private let health = HealthKitService.shared
    private let goals = GoalsStore.shared.current
    private let workoutStore = WorkoutPlanStore.shared

    private var templates: [WorkoutExercise] = []
    private var completedToday: Set<UUID> = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPlan()
        loadWorkouts()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Background WITHOUT glows
        view.addSubview(backgroundHost)
        backgroundHost.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundHost.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundHost.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundHost.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundHost.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        backgroundHost.backgroundColor = .systemBackground
        backgroundHost.addSubview(blurOverlay)
        blurOverlay.alpha = 0.30 // أقل حتى ما يبهّت
        blurOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blurOverlay.topAnchor.constraint(equalTo: backgroundHost.topAnchor),
            blurOverlay.leadingAnchor.constraint(equalTo: backgroundHost.leadingAnchor),
            blurOverlay.trailingAnchor.constraint(equalTo: backgroundHost.trailingAnchor),
            blurOverlay.bottomAnchor.constraint(equalTo: backgroundHost.bottomAnchor)
        ])

        // Scroll
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Content stack
        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.alignment = .fill

        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -18)
        ])

        // Title
        contentStack.addArrangedSubview(todayTitle)

        // Stats
        contentStack.addArrangedSubview(statsHeader)
        contentStack.addArrangedSubview(statsCard)
        configureCard(statsCard, tone: .mint)

        let statsStack = UIStackView(arrangedSubviews: [stepsRow, caloriesRow, waterRow, trainingRow])
        statsStack.axis = .vertical
        statsStack.spacing = 10

        statsCard.contentView.addSubview(statsStack)
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statsStack.topAnchor.constraint(equalTo: statsCard.contentView.topAnchor, constant: 14),
            statsStack.leadingAnchor.constraint(equalTo: statsCard.contentView.leadingAnchor, constant: 14),
            statsStack.trailingAnchor.constraint(equalTo: statsCard.contentView.trailingAnchor, constant: -14),
            statsStack.bottomAnchor.constraint(equalTo: statsCard.contentView.bottomAnchor, constant: -14)
        ])

        // Today workouts
        contentStack.setCustomSpacing(22, after: statsCard)
        contentStack.addArrangedSubview(todayWorkoutTitle)
        contentStack.addArrangedSubview(todayWorkoutCard)
        configureCard(todayWorkoutCard, tone: .sand)

        todayExercisesStack.axis = .vertical
        todayExercisesStack.spacing = 8

        todayWorkoutCard.contentView.addSubview(todayExercisesStack)
        todayExercisesStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            todayExercisesStack.topAnchor.constraint(equalTo: todayWorkoutCard.contentView.topAnchor, constant: 14),
            todayExercisesStack.leadingAnchor.constraint(equalTo: todayWorkoutCard.contentView.leadingAnchor, constant: 14),
            todayExercisesStack.trailingAnchor.constraint(equalTo: todayWorkoutCard.contentView.trailingAnchor, constant: -14),
            todayExercisesStack.bottomAnchor.constraint(equalTo: todayWorkoutCard.contentView.bottomAnchor, constant: -14)
        ])

        // Plan templates
        contentStack.setCustomSpacing(22, after: todayWorkoutCard)
        contentStack.addArrangedSubview(planTitle)
        contentStack.addArrangedSubview(planCard)
        configureCard(planCard, tone: .mint)

        let planContainer = UIStackView()
        planContainer.axis = .vertical
        planContainer.spacing = 12

        let inputRow = UIStackView()
        inputRow.axis = .horizontal
        inputRow.spacing = 10
        inputRow.alignment = .center

        planTextField.placeholder = L10n.t("plan.input.placeholder")
        planTextField.textAlignment = .natural
        planTextField.returnKeyType = .done
        planTextField.addTarget(self, action: #selector(addExerciseFromReturn), for: .editingDidEndOnExit)
        styleTextField(planTextField)

        styleAddButton(addButton)

        inputRow.addArrangedSubview(planTextField)
        inputRow.addArrangedSubview(addButton)

        templatesStack.axis = .vertical
        templatesStack.spacing = 8

        planContainer.addArrangedSubview(inputRow)
        planContainer.addArrangedSubview(templatesStack)

        planCard.contentView.addSubview(planContainer)
        planContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            planContainer.topAnchor.constraint(equalTo: planCard.contentView.topAnchor, constant: 14),
            planContainer.leadingAnchor.constraint(equalTo: planCard.contentView.leadingAnchor, constant: 14),
            planContainer.trailingAnchor.constraint(equalTo: planCard.contentView.trailingAnchor, constant: -14),
            planContainer.bottomAnchor.constraint(equalTo: planCard.contentView.bottomAnchor, constant: -14)
        ])
    }

    // MARK: - Card Styling

    private enum CardTone { case mint, sand }

    private func configureCard(_ card: GlassCardView, tone: CardTone) {

        let radius: CGFloat = 30
        let tint: UIColor = (tone == .mint) ? .aiqoMint : .aiqoSand

        card.layer.cornerRadius = radius
        card.layer.cornerCurve = .continuous
        card.layer.masksToBounds = false

        // أقل white wash حتى اللون يصير أقوى
        card.contentView.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        card.contentView.layer.cornerRadius = radius
        card.contentView.layer.cornerCurve = .continuous
        card.contentView.clipsToBounds = true

        // Tint أقوى (تباين أعلى)
        let tag = 9991
        if card.contentView.viewWithTag(tag) == nil {
            let tintLayer = UIView()
            tintLayer.tag = tag
            tintLayer.isUserInteractionEnabled = false
            tintLayer.backgroundColor = tint.withAlphaComponent(0.94)
            tintLayer.layer.cornerRadius = radius
            tintLayer.layer.cornerCurve = .continuous
            tintLayer.translatesAutoresizingMaskIntoConstraints = false

            card.contentView.insertSubview(tintLayer, at: 0)
            NSLayoutConstraint.activate([
                tintLayer.topAnchor.constraint(equalTo: card.contentView.topAnchor),
                tintLayer.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
                tintLayer.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
                tintLayer.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor)
            ])
        } else if let tintLayer = card.contentView.viewWithTag(tag) {
            tintLayer.backgroundColor = tint.withAlphaComponent(0.94)
        }

        // Border أوضح شوي
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor

        // Shadow أوضح شوي
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.10
        card.layer.shadowRadius = 20
        card.layer.shadowOffset = CGSize(width: 0, height: 12)
    }

    private func styleTextField(_ tf: UITextField) {
        tf.font = .aiqoBody(16)
        tf.textColor = .label
        tf.backgroundColor = UIColor.white.withAlphaComponent(0.62)
        tf.layer.cornerRadius = 16
        tf.layer.cornerCurve = .continuous
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.white.withAlphaComponent(0.75).cgColor
        tf.clipsToBounds = true
        tf.heightAnchor.constraint(equalToConstant: 46).isActive = true

        let pad = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 46))
        tf.leftView = pad
        tf.leftViewMode = .always
    }

    private func styleAddButton(_ button: UIButton) {
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.addTarget(self, action: #selector(addExerciseTapped), for: .touchUpInside)

        var cfg = UIButton.Configuration.filled()
        cfg.image = UIImage(systemName: "plus")
        cfg.baseForegroundColor = .black
        cfg.baseBackgroundColor = .aiqoSand
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        button.configuration = cfg
    }

    // MARK: - Data

    private func loadPlan() {
        stepsRow.setValueText(L10n.t("plan.stats.steps.loading"))
        caloriesRow.setValueText(L10n.t("plan.stats.calories.loading"))
        waterRow.setValueText(L10n.t("plan.stats.water.loading"))
        trainingRow.setValueText(L10n.t("plan.stats.training.loading"))

        Task { [weak self] in
            guard let self else { return }
            let steps  = await self.health.getTodaySteps()
            let burned = await self.health.getActiveCalories()
            let water  = await self.health.getWaterIntake()

            await MainActor.run {
                UIView.animate(withDuration: 0.25) {
                    self.stepsRow.setValueText(
                        String(format: L10n.t("plan.stats.steps.value"),
                               L10n.num(steps),
                               L10n.num(self.goals.steps))
                    )
                    self.caloriesRow.setValueText(
                        String(format: L10n.t("plan.stats.calories.value"),
                               L10n.num(Int(burned)))
                    )
                    self.waterRow.setValueText(
                        String(format: L10n.t("plan.stats.water.value"),
                               L10n.num(Int(water)))
                    )
                    self.trainingRow.setValueText(self.dailyTrainingSuggestion(steps: steps, burned: burned))
                }
            }
        }
    }

    private func dailyTrainingSuggestion(steps: Int, burned: Double) -> String {
        if steps < goals.steps / 3 { return L10n.t("plan.suggestion.low") }
        if steps < (2 * goals.steps) / 3 { return L10n.t("plan.suggestion.mid") }
        return L10n.t("plan.suggestion.high")
    }

    private func loadWorkouts() {
        templates = workoutStore.templates
        completedToday = workoutStore.completedIdsForToday()
        rebuildTodayExercises()
        rebuildTemplatesList()
    }

    private func rebuildTodayExercises() {
        todayExercisesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !templates.isEmpty else {
            let empty = UILabel()
            empty.text = L10n.t("plan.today.empty")
            empty.textAlignment = .center
            empty.numberOfLines = 0
            empty.textColor = .secondaryLabel
            empty.font = .aiqoBody(15)
            todayExercisesStack.addArrangedSubview(empty)
            return
        }

        for exercise in templates {
            let checked = completedToday.contains(exercise.id)
            let row = TodayWorkoutRow(title: exercise.name, isChecked: checked)
            row.onToggle = { [weak self] in
                guard let self else { return }
                self.workoutStore.toggleCompletedToday(id: exercise.id)
                self.completedToday = self.workoutStore.completedIdsForToday()
                self.rebuildTodayExercises()
            }
            todayExercisesStack.addArrangedSubview(row)
        }
    }

    private func rebuildTemplatesList() {
        templatesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if templates.isEmpty {
            let label = UILabel()
            label.text = L10n.t("plan.templates.empty")
            label.textAlignment = .natural
            label.numberOfLines = 0
            label.textColor = .secondaryLabel
            label.font = .aiqoBody(15)
            templatesStack.addArrangedSubview(label)
            return
        }

        for exercise in templates {
            let row = TemplateWorkoutRow(title: exercise.name)
            row.onDelete = { [weak self] in
                guard let self else { return }
                self.workoutStore.removeTemplate(id: exercise.id)
                self.templates = self.workoutStore.templates
                self.completedToday = self.workoutStore.completedIdsForToday()
                self.rebuildTemplatesList()
                self.rebuildTodayExercises()
            }
            templatesStack.addArrangedSubview(row)
        }
    }

    // MARK: - Actions

    @objc private func addExerciseTapped() { addExerciseFromField() }
    @objc private func addExerciseFromReturn() { addExerciseFromField() }

    private func addExerciseFromField() {
        let text = planTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return }

        workoutStore.addTemplate(named: text)
        templates = workoutStore.templates
        completedToday = workoutStore.completedIdsForToday()

        planTextField.text = nil
        planTextField.resignFirstResponder()

        rebuildTemplatesList()
        rebuildTodayExercises()
    }
}

// MARK: - Section Header

private final class SectionHeaderView: UIView {

    private let label = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        label.text = title.uppercased()
        label.font = .aiqoCaption(12)
        label.textColor = .secondaryLabel

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Stat Row

private final class StatRowView: UIView {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let isSuggestion: Bool

    init(icon: String, title: String, isSuggestion: Bool = false) {
        self.isSuggestion = isSuggestion
        super.init(frame: .zero)
        setup(icon: icon, title: title)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(icon: String, title: String) {
        let h = UIStackView()
        h.axis = .horizontal
        h.spacing = 10
        h.alignment = .center

        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = .label
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true

        titleLabel.text = title
        titleLabel.font = .aiqoBody(15)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .natural

        valueLabel.font = isSuggestion ? .aiqoBody(15) : .aiqoNumber(17)
        valueLabel.textColor = isSuggestion ? .secondaryLabel : .label
        valueLabel.textAlignment = .natural
        valueLabel.numberOfLines = 0

        let v = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        v.axis = .vertical
        v.spacing = 2

        h.addArrangedSubview(iconView)
        h.addArrangedSubview(v)

        addSubview(h)
        h.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            h.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            h.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            h.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])

        // Rounded row card (أوضح شوي)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.40).cgColor
        backgroundColor = UIColor.white.withAlphaComponent(0.22)
        clipsToBounds = true
    }

    func setValueText(_ text: String) { valueLabel.text = text }
}

// MARK: - Rows

private final class TodayWorkoutRow: UIView {

    var onToggle: (() -> Void)?

    private let titleLabel = UILabel()
    private let checkbox = UIButton(type: .system)

    private var isChecked: Bool { didSet { updateUI() } }

    init(title: String, isChecked: Bool) {
        self.isChecked = isChecked
        super.init(frame: .zero)
        setup(title: title)
        updateUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(title: String) {
        let h = UIStackView()
        h.axis = .horizontal
        h.spacing = 12
        h.alignment = .center

        titleLabel.text = title
        titleLabel.textAlignment = .natural
        titleLabel.numberOfLines = 0
        titleLabel.font = .aiqoBody(16)

        checkbox.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        checkbox.tintColor = .aiqoSand
        checkbox.setContentHuggingPriority(.required, for: .horizontal)

        h.addArrangedSubview(titleLabel)
        h.addArrangedSubview(checkbox)

        addSubview(h)
        h.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            h.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            h.leadingAnchor.constraint(equalTo: leadingAnchor),
            h.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func updateUI() {
        checkbox.setImage(UIImage(systemName: isChecked ? "checkmark.circle.fill" : "circle"), for: .normal)
        titleLabel.textColor = isChecked ? .secondaryLabel : .label
    }

    @objc private func toggle() { isChecked.toggle(); onToggle?() }
}

private final class TemplateWorkoutRow: UIView {

    var onDelete: (() -> Void)?

    private let titleLabel = UILabel()
    private let deleteButton = UIButton(type: .system)

    init(title: String) {
        super.init(frame: .zero)
        setup(title: title)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup(title: String) {
        let h = UIStackView()
        h.axis = .horizontal
        h.spacing = 8
        h.alignment = .center

        titleLabel.text = title
        titleLabel.textAlignment = .natural
        titleLabel.numberOfLines = 0
        titleLabel.font = .aiqoBody(16)

        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.setContentHuggingPriority(.required, for: .horizontal)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        h.addArrangedSubview(titleLabel)
        h.addArrangedSubview(deleteButton)

        addSubview(h)
        h.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            h.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            h.leadingAnchor.constraint(equalTo: leadingAnchor),
            h.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    @objc private func deleteTapped() { onDelete?() }
}

// MARK: - Design Tokens

private extension UIColor {
    static let aiqoMint = UIColor(red: 0.77, green: 0.94, blue: 0.86, alpha: 1)
    static let aiqoSand = UIColor(red: 0.97, green: 0.84, blue: 0.64, alpha: 1)
}

private extension UIFont {
    static func aiqoTitle(_ size: CGFloat) -> UIFont { rounded(size: size, weight: .bold) }
    static func aiqoSection(_ size: CGFloat) -> UIFont { rounded(size: size, weight: .semibold) }
    static func aiqoBody(_ size: CGFloat) -> UIFont { rounded(size: size, weight: .regular) }
    static func aiqoCaption(_ size: CGFloat) -> UIFont { rounded(size: size, weight: .semibold) }
    static func aiqoNumber(_ size: CGFloat) -> UIFont { rounded(size: size, weight: .bold) }

    private static func rounded(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let d = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: d, size: size)
        }
        return base
    }
}
