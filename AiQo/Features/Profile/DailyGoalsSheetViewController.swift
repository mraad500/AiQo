import UIKit

final class DailyGoalsSheetViewController: UIViewController {
    
    private var goals: ActivityDailyGoals
    private let onSave: (ActivityDailyGoals) -> Void
    
    private let caloriesValueLabel = UILabel()
    private let stepsValueLabel = UILabel()
    
    init(initialGoals: ActivityDailyGoals, onSave: @escaping (ActivityDailyGoals) -> Void) {
        self.goals = initialGoals
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        applyValues()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        
        let blur = UIBlurEffect(style: .systemChromeMaterial)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let container = UIView()
        container.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.9)
        container.layer.cornerRadius = 24
        container.layer.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        
        blurView.contentView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "الأهداف اليومية"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        
        let descLabel = UILabel()
        descLabel.text = "حدد هدف الخطوات وهدف السعرات لليوم."
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabel
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 2
        
        // Calories
        let caloriesTitle = UILabel()
        caloriesTitle.text = "هدف السعرات اليومية"
        caloriesTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        
        caloriesValueLabel.font = .systemFont(ofSize: 14)
        caloriesValueLabel.textColor = .secondaryLabel
        
        let caloriesStepper = UIStepper()
        caloriesStepper.minimumValue = 0
        caloriesStepper.maximumValue = 6000
        caloriesStepper.stepValue = 50
        caloriesStepper.addTarget(self, action: #selector(caloriesChanged(_:)), for: .valueChanged)
        
        let caloriesRow = UIStackView(arrangedSubviews: [caloriesTitle, UIView(), caloriesValueLabel])
        caloriesRow.axis = .horizontal
        caloriesRow.alignment = .center
        
        let caloriesStack = UIStackView(arrangedSubviews: [caloriesRow, caloriesStepper])
        caloriesStack.axis = .vertical
        caloriesStack.spacing = 6
        
        // Steps
        let stepsTitle = UILabel()
        stepsTitle.text = "هدف الخطوات اليومية"
        stepsTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        
        stepsValueLabel.font = .systemFont(ofSize: 14)
        stepsValueLabel.textColor = .secondaryLabel
        
        let stepsStepper = UIStepper()
        stepsStepper.minimumValue = 1000
        stepsStepper.maximumValue = 30000
        stepsStepper.stepValue = 500
        stepsStepper.addTarget(self, action: #selector(stepsChanged(_:)), for: .valueChanged)
        
        let stepsRow = UIStackView(arrangedSubviews: [stepsTitle, UIView(), stepsValueLabel])
        stepsRow.axis = .horizontal
        stepsRow.alignment = .center
        
        let stepsStack = UIStackView(arrangedSubviews: [stepsRow, stepsStepper])
        stepsStack.axis = .vertical
        stepsStack.spacing = 6
        
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("حفظ الأهداف", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        saveButton.backgroundColor = .systemYellow
        saveButton.setTitleColor(.label, for: .normal)
        saveButton.layer.cornerRadius = 16
        saveButton.layer.masksToBounds = true
        saveButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("إلغاء", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        let buttonsStack = UIStackView(arrangedSubviews: [saveButton, cancelButton])
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 8
        
        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            descLabel,
            UIView(),
            caloriesStack,
            stepsStack,
            UIView(),
            buttonsStack
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
        
        caloriesStepper.value = Double(goals.calories)
        stepsStepper.value = Double(goals.steps)
    }
    
    private func applyValues() {
        caloriesValueLabel.text = "\(goals.calories) سعرة"
        stepsValueLabel.text = "\(goals.steps) خطوة"
    }
    
    @objc private func caloriesChanged(_ sender: UIStepper) {
        goals.calories = Int(sender.value)
        applyValues()
    }
    
    @objc private func stepsChanged(_ sender: UIStepper) {
        goals.steps = Int(sender.value)
        applyValues()
    }
    
    @objc private func saveTapped() {
        onSave(goals)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}
