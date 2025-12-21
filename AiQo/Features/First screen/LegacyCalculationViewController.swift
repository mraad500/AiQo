import UIKit
import HealthKit

/// شاشة حساب المستوى الرياضي بالاعتماد على كل بيانات HealthKit التاريخية
final class LegacyCalculationViewController: BaseViewController {

    // MARK: - Types

    private enum State {
        case intro
        case loading
        case result(ResultModel)
    }

    struct ResultModel {
        let levelName: String
        let totalPoints: Int
        let level: Int
        let levelProgress: Double   // بين 0 و 1 داخل المستوى الحالي

        let totalSteps: Double
        let stepsPoints: Int

        let totalCalories: Double
        let caloriesPoints: Int

        let totalDistanceKm: Double
        let distancePoints: Int

        let totalSleepHours: Double
        let sleepPoints: Int

        let message: String
        let hasHealthData: Bool
    }

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()

    // MARK: - UI

    private let backgroundGradientLayer = CAGradientLayer()
    private let cardView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))

    private let mainStack = UIStackView()
    private let introStack = UIStackView()
    private let loadingStack = UIStackView()
    private let resultStack = UIStackView()

    private let iconView = UIImageView(image: UIImage(systemName: "figure.walk.circle.fill"))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let loadingIconView = UIImageView(image: UIImage(systemName: "hourglass"))
    private let loadingLabel = UILabel()

    private let levelTitleLabel = UILabel()
    private let explanationLabel = UILabel()

    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)

    private var currentState: State = .intro {
        didSet { updateUI(for: currentState) }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hidesBackButton = true
        navigationItem.title = "AiQo Legacy"

        setupBackground()
        setupLayout()
        configureStaticTexts()

        currentState = .intro
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
    }

    // MARK: - Setup: Background + Glass Card

    private func setupBackground() {
        view.backgroundColor = Colors.background

        backgroundGradientLayer.colors = [
            Colors.mint.withAlphaComponent(0.32).cgColor,
            Colors.background.cgColor,
            Colors.accent.withAlphaComponent(0.28).cgColor
        ]
        backgroundGradientLayer.locations = [0.0, 0.45, 1.0]
        backgroundGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        backgroundGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.clipsToBounds = true
        cardView.layer.cornerRadius = 28
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = Colors.sand.withAlphaComponent(0.35).cgColor
        cardView.layer.shadowColor = UIColor.black.withAlphaComponent(0.18).cgColor
        cardView.layer.shadowOpacity = 1
        cardView.layer.shadowRadius = 18
        cardView.layer.shadowOffset = CGSize(width: 0, height: 16)

        view.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    private func setupLayout() {
        mainStack.axis = .vertical
        mainStack.spacing = 24
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.layoutMargins = UIEdgeInsets(top: 24, left: 20, bottom: 20, right: 20)
        mainStack.isLayoutMarginsRelativeArrangement = true

        cardView.contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: cardView.contentView.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor)
        ])

        // Intro stack
        introStack.axis = .vertical
        introStack.spacing = 16
        introStack.alignment = .center

        iconView.preferredSymbolConfiguration = .init(pointSize: 60, weight: .bold)
        iconView.tintColor = Colors.sand

        let pillLabel = UILabel()
        // هنا يمكن استخدام ترجمة للعنوان الصغير إذا رغبت، حالياً جعلته يعتمد على العنوان الرئيسي
        pillLabel.text = NSLocalizedString("legacy_intro_title", comment: "").components(separatedBy: " ").first ?? "Analysis"
        pillLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        pillLabel.textColor = Colors.text
        pillLabel.textAlignment = .center
        pillLabel.backgroundColor = Colors.mint.withAlphaComponent(0.3)
        pillLabel.layer.cornerRadius = 18
        pillLabel.layer.cornerCurve = .continuous
        pillLabel.clipsToBounds = true
        pillLabel.translatesAutoresizingMaskIntoConstraints = false

        let pillContainer = UIView()
        pillContainer.translatesAutoresizingMaskIntoConstraints = false
        pillContainer.addSubview(pillLabel)

        NSLayoutConstraint.activate([
            pillLabel.topAnchor.constraint(equalTo: pillContainer.topAnchor),
            pillLabel.bottomAnchor.constraint(equalTo: pillContainer.bottomAnchor),
            pillLabel.centerXAnchor.constraint(equalTo: pillContainer.centerXAnchor),
            pillLabel.leadingAnchor.constraint(greaterThanOrEqualTo: pillContainer.leadingAnchor),
            pillLabel.trailingAnchor.constraint(lessThanOrEqualTo: pillContainer.trailingAnchor)
        ])

        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = Colors.text

        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = Colors.subtext

        introStack.addArrangedSubview(pillContainer)
        introStack.addArrangedSubview(iconView)
        introStack.addArrangedSubview(titleLabel)
        introStack.addArrangedSubview(subtitleLabel)

        // Loading stack
        loadingStack.axis = .vertical
        loadingStack.spacing = 12
        loadingStack.alignment = .center

        loadingIconView.preferredSymbolConfiguration = .init(pointSize: 40, weight: .medium)
        loadingIconView.tintColor = Colors.mint

        loadingLabel.numberOfLines = 0
        loadingLabel.textAlignment = .center
        loadingLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        loadingLabel.textColor = Colors.text

        loadingStack.addArrangedSubview(loadingIconView)
        loadingStack.addArrangedSubview(loadingLabel)

        // Result stack
        resultStack.axis = .vertical
        resultStack.spacing = 12
        resultStack.alignment = .fill

        levelTitleLabel.numberOfLines = 0
        levelTitleLabel.textAlignment = .center
        levelTitleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        levelTitleLabel.textColor = Colors.text

        explanationLabel.numberOfLines = 0
        explanationLabel.textAlignment = .natural
        explanationLabel.font = .systemFont(ofSize: 15, weight: .regular)
        explanationLabel.textColor = Colors.subtext

        resultStack.addArrangedSubview(levelTitleLabel)
        resultStack.addArrangedSubview(explanationLabel)

        // Buttons
        var primaryConfig = UIButton.Configuration.filled()
        primaryConfig.cornerStyle = .large
        primaryConfig.baseBackgroundColor = Colors.sand
        primaryConfig.baseForegroundColor = Colors.text
        primaryConfig.titleAlignment = .center
        primaryConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        primaryButton.configuration = primaryConfig
        primaryButton.layer.shadowColor = UIColor.black.withAlphaComponent(0.15).cgColor
        primaryButton.layer.shadowOpacity = 1
        primaryButton.layer.shadowRadius = 10
        primaryButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        primaryButton.addTarget(self, action: #selector(primaryButtonTapped), for: .touchUpInside)

        var secondaryConfig = UIButton.Configuration.bordered()
        secondaryConfig.cornerStyle = .large
        secondaryConfig.baseForegroundColor = Colors.sand
        secondaryConfig.titleAlignment = .center
        secondaryConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        secondaryButton.configuration = secondaryConfig
        secondaryButton.addTarget(self, action: #selector(secondaryButtonTapped), for: .touchUpInside)

        let buttonsStack = UIStackView(arrangedSubviews: [primaryButton, secondaryButton])
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 8

        mainStack.addArrangedSubview(introStack)
        mainStack.addArrangedSubview(loadingStack)
        mainStack.addArrangedSubview(resultStack)
        mainStack.addArrangedSubview(buttonsStack)
    }

    private func configureStaticTexts() {
        titleLabel.text = NSLocalizedString("legacy_intro_title", comment: "")
        subtitleLabel.text = NSLocalizedString("legacy_intro_subtitle", comment: "")

        loadingLabel.text = NSLocalizedString("legacy_loading_text", comment: "")
        
        primaryButton.setTitle(NSLocalizedString("btn_agree", comment: ""), for: .normal)
        secondaryButton.setTitle(NSLocalizedString("btn_no_thanks", comment: ""), for: .normal)
    }

    // MARK: - UI State

    private func updateUI(for state: State) {
        switch state {
        case .intro:
            introStack.isHidden = false
            loadingStack.isHidden = true
            resultStack.isHidden = true

            primaryButton.isHidden = false
            primaryButton.setTitle(NSLocalizedString("btn_agree", comment: ""), for: .normal)
            secondaryButton.isHidden = false
            secondaryButton.setTitle(NSLocalizedString("btn_no_thanks", comment: ""), for: .normal)

        case .loading:
            introStack.isHidden = true
            loadingStack.isHidden = false
            resultStack.isHidden = true

            primaryButton.isHidden = true
            secondaryButton.isHidden = true

            if #available(iOS 17.0, *) {
                loadingIconView.addSymbolEffect(.variableColor.iterative.reversing)
                loadingIconView.addSymbolEffect(.scale.up)
            }

        case .result(let model):
            introStack.isHidden = true
            loadingStack.isHidden = true
            resultStack.isHidden = false

            if #available(iOS 17.0, *) {
                loadingIconView.removeSymbolEffect(ofType: .variableColor)
                loadingIconView.removeSymbolEffect(ofType: .scale)
            }

            let headerTitle: String
            if model.hasHealthData {
                let format = NSLocalizedString("result_header_format", comment: "")
                headerTitle = String(format: format, model.levelName, model.level, model.totalPoints)
            } else {
                let format = NSLocalizedString("result_header_format", comment: "")
                headerTitle = String(format: format, NSLocalizedString("level_name_starter", comment: ""), 1, 0)
            }
            levelTitleLabel.text = headerTitle

            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale.current

            let stepsText = formatter.string(from: model.totalSteps as NSNumber) ?? "\(Int(model.totalSteps))"
            let caloriesText = formatter.string(from: model.totalCalories as NSNumber) ?? "\(Int(model.totalCalories))"
            let distanceText = String(format: "%.1f", model.totalDistanceKm)
            let sleepText = String(format: "%.1f", model.totalSleepHours)

            var explanation = NSLocalizedString("result_explanation_intro", comment: "")

            let statsFormat = NSLocalizedString("result_stats_block", comment: "")
            let statsBlock = String(format: statsFormat,
                                    stepsText, model.stepsPoints,
                                    caloriesText, model.caloriesPoints,
                                    distanceText, model.distancePoints,
                                    sleepText, model.sleepPoints,
                                    model.totalPoints)

            explanation += "\n\n" + statsBlock + "\n\n" + model.message

            if model.hasHealthData {
                let footerFormat = NSLocalizedString("result_footer_success", comment: "")
                let footer = String(format: footerFormat, model.level)
                explanation += "\n\n" + footer
            } else {
                explanation += "\n\n" + NSLocalizedString("result_footer_no_data", comment: "")
            }

            explanationLabel.text = explanation

            primaryButton.isHidden = false
            primaryButton.setTitle(NSLocalizedString("btn_goto_main", comment: ""), for: .normal)
            secondaryButton.isHidden = true

            playCelebrationAnimation()
        }
    }

    private func playCelebrationAnimation() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        levelTitleLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.6,
            options: [.allowUserInteraction],
            animations: {
                self.levelTitleLabel.transform = .identity
            },
            completion: nil
        )
    }

    // MARK: - Actions

    @objc
    private func primaryButtonTapped() {
        switch currentState {
        case .intro:
            currentState = .loading
            requestHealthAuthorizationIfNeeded { [weak self] authorized in
                guard let self else { return }

                if authorized {
                    self.startCalculationFlow()
                } else {
                    let model = ResultModel(
                        levelName: NSLocalizedString("level_name_starter", comment: ""),
                        totalPoints: 0,
                        level: 1,
                        levelProgress: 0,
                        totalSteps: 0,
                        stepsPoints: 0,
                        totalCalories: 0,
                        caloriesPoints: 0,
                        totalDistanceKm: 0,
                        distancePoints: 0,
                        totalSleepHours: 0,
                        sleepPoints: 0,
                        message: NSLocalizedString("msg_level_starter", comment: ""),
                        hasHealthData: false
                    )
                    self.currentState = .result(model)
                }
            }

        case .loading:
            break

        case .result:
            markCompletedAndGoToMain()
        }
    }

    @objc
    private func secondaryButtonTapped() {
        markCompletedAndGoToMain()
    }

    // MARK: - Navigation

    private func markCompletedAndGoToMain() {
        UserDefaults.standard.set(true, forKey: "didCompleteLegacyCalculation")

        guard
            let windowScene = view.window?.windowScene,
            let sceneDelegate = windowScene.delegate as? SceneDelegate
        else { return }

        sceneDelegate.onboardingFinished()
    }

    // MARK: - Flow

    private func startCalculationFlow() {
        let startTime = Date()

        fetchHealthTotals { [weak self] result in
            guard let self else { return }

            let elapsed = Date().timeIntervalSince(startTime)
            let delay = max(0.0, 2.0 - elapsed)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let result = result else {
                    self.markCompletedAndGoToMain()
                    return
                }
                self.currentState = .result(result)
            }
        }
    }

    // MARK: - HealthKit Authorization

    private func requestHealthAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

        let readTypes: Set<HKObjectType> = [
            stepType,
            energyType,
            distanceType,
            sleepType
        ]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            if let error = error {
                print("HealthKit Authorization Error:", error.localizedDescription)
            }
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    // MARK: - Health Data Aggregation

    private func fetchHealthTotals(completion: @escaping (ResultModel?) -> Void) {
        let group = DispatchGroup()

        var totalSteps: Double = 0
        var totalCalories: Double = 0
        var totalDistance: Double = 0
        var totalSleepHours: Double = 0

        let startDate = Date.distantPast
        let endDate = Date()

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        // Steps
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                if let sum = statistics?.sumQuantity() {
                    totalSteps = sum.doubleValue(for: .count())
                }
                group.leave()
            }
            healthStore.execute(query)
        }

        // Active energy (kcal)
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            group.enter()
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                if let sum = statistics?.sumQuantity() {
                    totalCalories = sum.doubleValue(for: .kilocalorie())
                }
                group.leave()
            }
            healthStore.execute(query)
        }

        // Distance (km)
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            group.enter()
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                if let sum = statistics?.sumQuantity() {
                    totalDistance = sum.doubleValue(for: .meter()) / 1000.0
                }
                group.leave()
            }
            healthStore.execute(query)
        }

        // Sleep (hours)
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            group.enter()

            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                defer { group.leave() }

                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    totalSleepHours = 0
                    return
                }

                var totalSeconds: TimeInterval = 0
                for sample in categorySamples where asleepValues.contains(sample.value) {
                    totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                }

                totalSleepHours = totalSeconds / 3600.0
            }

            healthStore.execute(query)
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            let model = self.buildResultModel(
                steps: totalSteps,
                calories: totalCalories,
                distanceKm: totalDistance,
                sleepHours: totalSleepHours
            )
            DispatchQueue.main.async {
                completion(model)
            }
        }
    }

    // MARK: - Level System + Scoring

    private func calculateLevel(from totalPoints: Int) -> (level: Int, progress: Double) {
        let baseRequirement = 500
        let increment = 200

        var remainingPoints = max(totalPoints, 0)
        var currentLevel = 1
        var requirementForThisLevel = baseRequirement

        while remainingPoints >= requirementForThisLevel {
            remainingPoints -= requirementForThisLevel
            currentLevel += 1
            requirementForThisLevel += increment
        }

        let progress = requirementForThisLevel > 0
            ? Double(remainingPoints) / Double(requirementForThisLevel)
            : 0

        return (max(currentLevel, 1), min(max(progress, 0), 1))
    }

    private func buildResultModel(
        steps: Double,
        calories: Double,
        distanceKm: Double,
        sleepHours: Double
    ) -> ResultModel {

        let stepsPoints = Int(steps / 1_000.0)
        let caloriesPoints = Int(calories / 100.0)
        let distancePoints = Int(distanceKm * 5.0)
        let sleepPoints = Int(sleepHours / 8.0) * 20

        let totalPoints = max(0, stepsPoints + caloriesPoints + distancePoints + sleepPoints)

        let levelInfo = calculateLevel(from: totalPoints)
        let level = levelInfo.level
        let levelProgress = levelInfo.progress

        // ----------------------------------------------------------------
        // تصحيح: استخدام المفاتيح الأصلية LevelStorageKeys لضمان قراءة البروفايل للبيانات
        // ----------------------------------------------------------------
        UserDefaults.standard.set(level, forKey: LevelStorageKeys.currentLevel)
        UserDefaults.standard.set(levelProgress, forKey: LevelStorageKeys.currentLevelProgress)
        UserDefaults.standard.set(totalPoints, forKey: LevelStorageKeys.legacyTotalPoints)

        let levelName: String
        let message: String

        switch totalPoints {
        case 0..<150:
            levelName = NSLocalizedString("level_name_starter", comment: "")
            message = NSLocalizedString("msg_level_starter", comment: "")
        case 150..<400:
            levelName = NSLocalizedString("level_name_riser", comment: "")
            message = NSLocalizedString("msg_level_riser", comment: "")
        case 400..<800:
            levelName = NSLocalizedString("level_name_fighter", comment: "")
            message = NSLocalizedString("msg_level_fighter", comment: "")
        default:
            levelName = NSLocalizedString("level_name_legend", comment: "")
            message = NSLocalizedString("msg_level_legend", comment: "")
        }

        let hasHealthData = (steps > 0 || calories > 0 || distanceKm > 0 || sleepHours > 0)

        return ResultModel(
            levelName: levelName,
            totalPoints: totalPoints,
            level: level,
            levelProgress: levelProgress,
            totalSteps: steps,
            stepsPoints: stepsPoints,
            totalCalories: calories,
            caloriesPoints: caloriesPoints,
            totalDistanceKm: distanceKm,
            distancePoints: distancePoints,
            totalSleepHours: sleepHours,
            sleepPoints: sleepPoints,
            message: message,
            hasHealthData: hasHealthData
        )
    }
}
