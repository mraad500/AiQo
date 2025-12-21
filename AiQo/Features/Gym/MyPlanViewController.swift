
// =========================
// File: Features/Gym/MyPlanViewController.swift
// NOTE: Localized strings + natural alignment.
// =========================

import UIKit

final class MyPlanViewController: BaseViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let todayTitle: UILabel = {
        let label = UILabel()
        label.text = L10n.t("plan.today.title")
        label.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        label.textAlignment = .natural
        return label
    }()

    private let statsCard = GlassCardView()
    private let stepsLabel = UILabel()
    private let caloriesLabel = UILabel()
    private let waterLabel = UILabel()
    private let trainingLabel = UILabel()

    private let todayWorkoutTitle: UILabel = {
        let label = UILabel()
        label.text = L10n.t("plan.today.workoutsTitle")
        label.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .natural
        return label
    }()

    private let todayWorkoutCard = GlassCardView()
    private let todayExercisesStack = UIStackView()

    private let planTitle: UILabel = {
        let label = UILabel()
        label.text = L10n.t("plan.templates.title")
        label.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .natural
        return label
    }()

    private let planCard = GlassCardView()
    private let planTextField = UITextField()
    private let addButton = UIButton(type: .system)
    private let templatesStack = UIStackView()

    private let health = HealthKitService.shared
    private let goals = GoalsStore.shared.current
    private let workoutStore = WorkoutPlanStore.shared

    private var templates: [WorkoutExercise] = []
    private var completedToday: Set<UUID> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPlan()
        loadWorkouts()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.alignment = .fill

        scrollView.addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
            contentStack.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor)
        ])

        // Stats
        contentStack.addArrangedSubview(todayTitle)
        contentStack.addArrangedSubview(statsCard)

        let statsStack = UIStackView(arrangedSubviews: [stepsLabel, caloriesLabel, waterLabel, trainingLabel])
        statsStack.axis = .vertical
        statsStack.spacing = 8

        statsCard.contentView.addSubview(statsStack)
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statsStack.topAnchor.constraint(equalTo: statsCard.contentView.topAnchor, constant: 16),
            statsStack.leadingAnchor.constraint(equalTo: statsCard.contentView.leadingAnchor, constant: 16),
            statsStack.trailingAnchor.constraint(equalTo: statsCard.contentView.trailingAnchor, constant: -16),
            statsStack.bottomAnchor.constraint(equalTo: statsCard.contentView.bottomAnchor, constant: -16)
        ])

        [stepsLabel, caloriesLabel, waterLabel, trainingLabel].forEach {
            $0.textAlignment = .natural
            $0.numberOfLines = 0
        }

        // Today workouts
        contentStack.setCustomSpacing(28, after: statsCard)
        contentStack.addArrangedSubview(todayWorkoutTitle)
        contentStack.addArrangedSubview(todayWorkoutCard)

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
        contentStack.setCustomSpacing(24, after: todayWorkoutCard)
        contentStack.addArrangedSubview(planTitle)
        contentStack.addArrangedSubview(planCard)

        let planContainer = UIStackView()
        planContainer.axis = .vertical
        planContainer.spacing = 12

        let inputRow = UIStackView()
        inputRow.axis = .horizontal
        inputRow.spacing = 8
        inputRow.alignment = .center

        planTextField.placeholder = L10n.t("plan.input.placeholder")
        planTextField.borderStyle = .roundedRect
        planTextField.textAlignment = .natural
        planTextField.returnKeyType = .done
        planTextField.addTarget(self, action: #selector(addExerciseFromReturn), for: .editingDidEndOnExit)

        addButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        addButton.tintColor = .systemYellow
        addButton.setContentHuggingPriority(.required, for: .horizontal)
        addButton.addTarget(self, action: #selector(addExerciseTapped), for: .touchUpInside)

        inputRow.addArrangedSubview(planTextField)
        inputRow.addArrangedSubview(addButton)

        templatesStack.axis = .vertical
        templatesStack.spacing = 6

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

    // MARK: - Data

    private func loadPlan() {
        stepsLabel.text = L10n.t("plan.stats.steps.loading")
        caloriesLabel.text = L10n.t("plan.stats.calories.loading")
        waterLabel.text = L10n.t("plan.stats.water.loading")
        trainingLabel.text = L10n.t("plan.stats.training.loading")

        Task { [weak self] in
            guard let self else { return }
            let steps  = await self.health.getTodaySteps()
            let burned = await self.health.getActiveCalories()
            let water  = await self.health.getWaterIntake()

            await MainActor.run {
                UIView.animate(withDuration: 0.25) {
                    self.stepsLabel.text = String(
                        format: L10n.t("plan.stats.steps.value"),
                        L10n.num(steps),
                        L10n.num(self.goals.steps)
                    )
                    self.caloriesLabel.text = String(
                        format: L10n.t("plan.stats.calories.value"),
                        L10n.num(Int(burned))
                    )
                    self.waterLabel.text = String(
                        format: L10n.t("plan.stats.water.value"),
                        L10n.num(Int(water))
                    )
                    self.trainingLabel.text = self.dailyTrainingSuggestion(steps: steps, burned: burned)
                }
            }
        }
    }

    private func dailyTrainingSuggestion(steps: Int, burned: Double) -> String {
        if steps < goals.steps / 3 {
            return L10n.t("plan.suggestion.low")
        } else if steps < (2 * goals.steps) / 3 {
            return L10n.t("plan.suggestion.mid")
        } else {
            return L10n.t("plan.suggestion.high")
        }
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

// MARK: - Row Views (unchanged visually; only natural alignment)

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

        checkbox.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        checkbox.tintColor = .systemYellow
        checkbox.setContentHuggingPriority(.required, for: .horizontal)

        h.addArrangedSubview(titleLabel)
        h.addArrangedSubview(checkbox)

        addSubview(h)
        h.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            h.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            h.leadingAnchor.constraint(equalTo: leadingAnchor),
            h.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func updateUI() {
        let imageName = isChecked ? "checkmark.circle.fill" : "circle"
        checkbox.setImage(UIImage(systemName: imageName), for: .normal)
        titleLabel.textColor = isChecked ? .secondaryLabel : .label
    }

    @objc private func toggle() {
        isChecked.toggle()
        onToggle?()
    }
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

        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.setContentHuggingPriority(.required, for: .horizontal)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)

        h.addArrangedSubview(titleLabel)
        h.addArrangedSubview(deleteButton)

        addSubview(h)
        h.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            h.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            h.leadingAnchor.constraint(equalTo: leadingAnchor),
            h.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    @objc private func deleteTapped() { onDelete?() }
}
