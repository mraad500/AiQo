import UIKit
import HealthKit
internal import Combine

// MARK: - GlassHeader (Segmented)
final class GlassHeader: UIView {
    let segmented: UISegmentedControl = {
        let items = [
            NSLocalizedString("screen.gym.segment.exercises", comment: "Exercises"),
            NSLocalizedString("screen.gym.segment.heart", comment: "Heart"),
            NSLocalizedString("screen.gym.segment.plan", comment: "Plan"),
            NSLocalizedString("screen.gym.segment.rewards", comment: "Rewards")
        ]
        return UISegmentedControl(items: items)
    }()

    private let effectView: UIVisualEffectView = {
        // نستخدم الـ Blur العادي لضمان التوافق مع كل الأنظمة حالياً
        // يمكنك تجربة .systemUltraThinMaterial ليعطي تأثيراً مشابهاً للزجاج
        return UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.masksToBounds = false

        effectView.translatesAutoresizingMaskIntoConstraints = false
        // ✅ الحل المضمون: التدوير الكلاسيكي
        effectView.layer.cornerRadius = 22
        effectView.layer.masksToBounds = true
        
        // ❌ حذفنا السطر الذي يسبب المشكلة (cornerConfiguration) مؤقتاً
        
        addSubview(effectView)

        segmented.selectedSegmentIndex = 0
        segmented.translatesAutoresizingMaskIntoConstraints = false
        segmented.backgroundColor = .clear
        segmented.selectedSegmentTintColor = .white

        segmented.setTitleTextAttributes([
            .font: UIFont.aiqoRounded(size: 15, weight: .bold),
            .foregroundColor: UIColor.black.withAlphaComponent(0.6)
        ], for: .normal)

        segmented.setTitleTextAttributes([
            .font: UIFont.aiqoRounded(size: 15, weight: .black),
            .foregroundColor: UIColor.black
        ], for: .selected)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        effectView.contentView.addSubview(segmented)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            segmented.topAnchor.constraint(equalTo: effectView.contentView.topAnchor, constant: 6),
            segmented.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor, constant: -6),
            segmented.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 8),
            segmented.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -8),

            heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}


// MARK: - GymViewController
final class GymViewController: BaseViewController {

    // ✅ استخدام ألوانك الخاصة
    private let mint = Colors.mint
    private let sand = Colors.sand

    // ✅ استخدام الهيدر الخاص بك
    private let titleHeader = LargeTitleHeaderView(
        title: NSLocalizedString("screen.gym.title", comment: "Gym header title")
    )
    private let segmentedHeader = GlassHeader()

    private let container = UIView()
    private var current: UIViewController?

    private lazy var exercisesVC: ExercisesViewController = {
        let vc = ExercisesViewController()
        vc.delegate = self
        return vc
    }()
    private lazy var heartVC = HeartViewController()
    private lazy var planVC = MyPlanViewController()
    private lazy var rewardsVC = RewardsViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationController?.setNavigationBarHidden(true, animated: false)

        buildHeader()
        buildGlassSegmented()
        buildContainer()

        segmentedChanged(segmentedHeader.segmented)
        
        // ✅ تفعيل الاتصال عند فتح الشاشة
        PhoneConnectivityManager.shared.activate()
    }

    @MainActor
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func buildHeader() {
        titleHeader.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleHeader)

        // ✅ استخدام خطك الخاص
        titleHeader.titleLabel.font = .aiqoRounded(size: 32, weight: .heavy)

        NSLayoutConstraint.activate([
            titleHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
            titleHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            titleHeader.heightAnchor.constraint(equalToConstant: 60)
        ])

        titleHeader.profileButton.addTarget(self, action: #selector(openProfile), for: .touchUpInside)
    }

    private func buildGlassSegmented() {
        view.addSubview(segmentedHeader)
        segmentedHeader.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            segmentedHeader.topAnchor.constraint(equalTo: titleHeader.bottomAnchor, constant: 16),
            segmentedHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        segmentedHeader.segmented.addTarget(self,
                                            action: #selector(segmentedChanged(_:)),
                                            for: .valueChanged)
    }

    private func buildContainer() {
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: segmentedHeader.bottomAnchor, constant: 10),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func segmentedChanged(_ sender: UISegmentedControl) {
        let next: UIViewController = {
            switch sender.selectedSegmentIndex {
            case 0: return exercisesVC
            case 1: return heartVC
            case 2: return planVC
            case 3: return rewardsVC
            default: return exercisesVC
            }
        }()
        showChild(next)
    }

    private func showChild(_ vc: UIViewController) {
        if let current {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(vc.view)

        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: container.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        vc.didMove(toParent: self)
        current = vc
    }

    @objc private func openProfile() {
        let profileVC = NewProfileViewController()
        presentAsSheet(profileVC, detents: [.large()])
    }

    private func openWorkoutSheet(title: String, activity: HKWorkoutActivityType) {
        let vc = LiveWorkoutSheet(titleText: title,
                                  activityType: activity,
                                  mint: mint,
                                  sand: sand)
        presentAsSheet(vc, detents: [.medium(), .large()])
    }

    private func presentAsSheet(_ vc: UIViewController,
                                detents: [UISheetPresentationController.Detent]) {
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
        present(vc, animated: true)
    }
}

// MARK: - LiveWorkoutSheet
final class LiveWorkoutSheet: UIViewController {

    private let titleText: String
    private let activityType: HKWorkoutActivityType
    private let mint: UIColor
    private let sand: UIColor

    private let session = LiveWorkoutSession.shared
    private var cancellables = Set<AnyCancellable>()

    private let distanceLabel = UILabel()
    private let timeLabel = UILabel()
    private let hrLabel = UILabel()
    private let kcalLabel = UILabel()
    private let startBtn = UIButton(type: .system)
    private let endBtn = UIButton(type: .system)

    init(titleText: String,
         activityType: HKWorkoutActivityType,
         mint: UIColor,
         sand: UIColor) {
        self.titleText = titleText
        self.activityType = activityType
        self.mint = mint
        self.sand = sand
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let title = UILabel()
        title.text = titleText
        title.font = .aiqoRounded(size: 20, weight: .black)
        title.textAlignment = .center

        let big = makeStatCard(label: distanceLabel, color: mint, big: true)
        distanceLabel.text = "0.00 km"

        let timeCard = makeStatCard(label: timeLabel, color: mint, big: false)
        timeLabel.text = "00:00"

        let hrCard = makeStatCard(label: hrLabel, color: sand, big: false)
        hrLabel.text = "-- bpm"

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12

        let row = UIStackView(arrangedSubviews: [timeCard, hrCard])
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually

        grid.addArrangedSubview(big)
        grid.addArrangedSubview(row)

        kcalLabel.text = "0 kcal"
        kcalLabel.font = .aiqoRounded(size: 22, weight: .heavy)
        kcalLabel.textAlignment = .center

        startBtn.setTitle(NSLocalizedString("sheet.workout.button.start", comment: "Start"), for: .normal)
        startBtn.titleLabel?.font = .aiqoRounded(size: 19, weight: .heavy)
        startBtn.backgroundColor = .systemGreen
        startBtn.tintColor = .white
        startBtn.layer.cornerRadius = 14
        startBtn.heightAnchor.constraint(equalToConstant: 54).isActive = true
        startBtn.addTarget(self, action: #selector(startTapped), for: .touchUpInside)

        endBtn.setTitle(NSLocalizedString("sheet.workout.button.end", comment: "End"), for: .normal)
        endBtn.titleLabel?.font = .aiqoRounded(size: 19, weight: .heavy)
        endBtn.backgroundColor = .systemRed
        endBtn.tintColor = .white
        endBtn.layer.cornerRadius = 14
        endBtn.heightAnchor.constraint(equalToConstant: 54).isActive = true
        endBtn.addTarget(self, action: #selector(endTapped), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [startBtn, endBtn])
        buttons.axis = .horizontal
        buttons.spacing = 16
        buttons.distribution = .fillEqually

        [title, grid, kcalLabel, buttons].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            grid.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            kcalLabel.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 16),
            kcalLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            kcalLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            buttons.topAnchor.constraint(equalTo: kcalLabel.bottomAnchor, constant: 24),
            buttons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        bindSession()
    }

    private func bindSession() {
        // Heart Rate
        LiveWorkoutSession.shared.$heartRate
            .receive(on: RunLoop.main)
            .sink { [weak self] bpm in
                let v = Int(bpm.rounded())
                self?.hrLabel.text = v > 0 ? "\(v) bpm" : "-- bpm"
            }
            .store(in: &cancellables)

        // Active Energy (kcal)
        LiveWorkoutSession.shared.$activeEnergy
            .receive(on: RunLoop.main)
            .sink { [weak self] kcal in
                self?.kcalLabel.text = "\(Int(kcal.rounded())) kcal"
            }
            .store(in: &cancellables)

        // Elapsed
        LiveWorkoutSession.shared.$elapsed
            .receive(on: RunLoop.main)
            .sink { [weak self] t in
                let s = Int(t)
                self?.timeLabel.text = String(format: "%02d:%02d", s / 60, s % 60)
            }
            .store(in: &cancellables)

        // ✅ Distance: الآن مربوطة بالبيانات الحية (New Feature)
        LiveWorkoutSession.shared.$distance
            .receive(on: RunLoop.main)
            .sink { [weak self] meters in
                let km = meters / 1000.0
                self?.distanceLabel.text = String(format: "%.2f km", km)
            }
            .store(in: &cancellables)
    }

    @objc private func startTapped() {
        let activityType = self.activityType

        // ✅ إرسال الأمر للساعة عبر ConnectivityManager
        PhoneConnectivityManager.shared.startWorkoutOnWatch(
            activityTypeRaw: Int(activityType.rawValue),
            locationTypeRaw: inferredLocationType(for: activityType).rawValue
        )
        
        // UI Feedback
        startBtn.isEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.startBtn.alpha = 0.5
        }
    }
    
    // helper to map activity to location
    private func inferredLocationType(for activity: HKWorkoutActivityType) -> HKWorkoutSessionLocationType {
        switch activity {
        case .running, .walking, .cycling:
            return .outdoor
        default:
            return .indoor
        }
    }

    @objc private func endTapped() {
        // ✅ إيقاف التمرين عبر الساعة
        PhoneConnectivityManager.shared.stopWorkoutOnWatch()
        
        // Reset UI
        startBtn.isEnabled = true
        startBtn.alpha = 1.0
    }

    private func makeStatCard(label: UILabel, color: UIColor, big: Bool) -> UIView {
        let v = UIView()
        v.backgroundColor = color
        v.layer.cornerRadius = 24

        label.textColor = .black
        // ✅ استخدام خطك الخاص
        label.font = .aiqoRounded(size: big ? 36 : 28, weight: .black)
        label.translatesAutoresizingMaskIntoConstraints = false

        v.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: v.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            v.heightAnchor.constraint(equalToConstant: big ? 100 : 80)
        ])

        return v
    }
}

// MARK: - Delegate from Exercises
extension GymViewController: ExercisesViewControllerDelegate {
    func exercisesViewController(_ vc: ExercisesViewController,
                                 didSelectWorkoutNamed name: String,
                                 activityType: HKWorkoutActivityType) {
        openWorkoutSheet(title: name, activity: activityType)
    }
}
