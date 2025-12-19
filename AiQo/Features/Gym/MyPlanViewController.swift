import UIKit

final class MyPlanViewController: BaseViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // كارت الإحصائيات
    private let todayTitle: UILabel = {
        let label = UILabel()
        label.text = "خُطّتي لليوم"
        label.font = UIFont.systemFont(ofSize: 26, weight: .bold)
        label.textAlignment = .right
        return label
    }()

    private let statsCard = GlassCardView()
    private let stepsLabel = UILabel()
    private let caloriesLabel = UILabel()
    private let waterLabel = UILabel()
    private let trainingLabel = UILabel()

    // كارت تمارين اليوم
    private let todayWorkoutTitle: UILabel = {
        let label = UILabel()
        label.text = "تمارين اليوم"
        label.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .right
        return label
    }()

    private let todayWorkoutCard = GlassCardView()
    private let todayExercisesStack = UIStackView()

    // كارت خطة التمارين (إضافة / إدارة)
    private let planTitle: UILabel = {
        let label = UILabel()
        label.text = "خطة تماريني"
        label.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .right
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
    }

    // MARK: - Setup UI

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

        // كارت الإحصائيات
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

        stepsLabel.textAlignment = .right
        caloriesLabel.textAlignment = .right
        waterLabel.textAlignment = .right
        trainingLabel.textAlignment = .right
        trainingLabel.numberOfLines = 0

        // كارت تمارين اليوم
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

        // كارت خطة التمارين
        contentStack.setCustomSpacing(24, after: todayWorkoutCard)
        contentStack.addArrangedSubview(planTitle)
        contentStack.addArrangedSubview(planCard)

        let planContainer = UIStackView()
        planContainer.axis = .vertical
        planContainer.spacing = 12

        // حقل الإضافة
        let inputRow = UIStackView()
        inputRow.axis = .horizontal
        inputRow.spacing = 8
        inputRow.alignment = .center

        planTextField.placeholder = "اكتب تمرين جديد (مثلاً: 3 مجاميع شناو)"
        planTextField.borderStyle = .roundedRect
        planTextField.textAlignment = .right
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

    // MARK: - Load stats from HealthKit

    private func loadPlan() {
        stepsLabel.text = "الخطوات: ..."
        caloriesLabel.text = "السعرات: ..."
        waterLabel.text = "الماء: ..."
        trainingLabel.text = "التمرين: ..."

        Task { [weak self] in
            guard let self else { return }

            let steps  = await self.health.getTodaySteps()
            let burned = await self.health.getActiveCalories()
            let water  = await self.health.getWaterIntake()

            await MainActor.run {
                UIView.animate(withDuration: 0.25) {
                    self.stepsLabel.text = "الخطوات: \(steps)/\(self.goals.steps)"
                    self.caloriesLabel.text = "السعرات المحروقة: \(Int(burned)) kcal"
                    self.waterLabel.text = "الماء: \(Int(water)) ml"
                    self.trainingLabel.text = self.dailyTrainingSuggestion(steps: steps, burned: burned)
                }
            }
        }
    }

    private func dailyTrainingSuggestion(steps: Int, burned: Double) -> String {
        if steps < goals.steps / 3 {
            return "اقتراح اليوم: 20 دقيقة مشي خفيف + 3 مجاميع شناو"
        } else if steps < (2 * goals.steps) / 3 {
            return "اقتراح اليوم: 10 دقايق HIIT + 5 دقايق بايسكل"
        } else {
            return "اقتراح اليوم: يوم ريكوفري، مطاوعة خفيفة + تنفس عميق"
        }
    }

    // MARK: - Workouts (templates + today)

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
            empty.text = "ما عندك تمارين لليوم.\nإبدي بوضع خطة من الأسفل."
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
            label.text = "أضف تمارينك المفضلة حتى تصير خطة ثابتة لكل يوم."
            label.textAlignment = .right
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

    @objc private func addExerciseTapped() {
        addExerciseFromField()
    }

    @objc private func addExerciseFromReturn() {
        addExerciseFromField()
    }

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

// MARK: - Row Views

private final class TodayWorkoutRow: UIView {

    var onToggle: (() -> Void)?

    private let titleLabel = UILabel()
    private let checkbox = UIButton(type: .system)

    private var isChecked: Bool {
        didSet { updateUI() }
    }

    init(title: String, isChecked: Bool) {
        self.isChecked = isChecked
        super.init(frame: .zero)
        setup(title: title)
        updateUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(title: String) {
        let h = UIStackView()
        h.axis = .horizontal
        h.spacing = 12
        h.alignment = .center

        titleLabel.text = title
        titleLabel.textAlignment = .right
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(title: String) {
        let h = UIStackView()
        h.axis = .horizontal
        h.spacing = 8
        h.alignment = .center

        titleLabel.text = title
        titleLabel.textAlignment = .right
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

    @objc private func deleteTapped() {
        onDelete?()
    }
}
