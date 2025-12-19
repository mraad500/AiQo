import UIKit
import HealthKit

// MARK: - HomeViewController
final class HomeViewController: BaseViewController {

    // Views
    let scroll = UIScrollView()
    let content = UIStackView()
    // تأكد من تعديل الخط داخل ملف LargeTitleHeaderView أيضاً
    let header = LargeTitleHeaderView(
        title: NSLocalizedString("screen.home.title", comment: "Home header title")
    )

    // Health service + live refresh
    let health = HealthKitService.shared
    var refreshTimer: Timer?

    // تجميعة الكروت
    var metrics: [MetricView] = []

    // bookkeeping Grid (للتوسيع داخل نفس الكارت)
    var rowStacks: [UIStackView] = []
    var kindToIndexPath: [MetricKind: (row: Int, col: Int)] = [:]
    var expandedKind: MetricKind?

    // آخر ملخّص محمّل
    var currentSummaryCache: TodaySummary?

    // ألوان الكروت
    let mint = UIColor(red: 0.77, green: 0.94, blue: 0.86, alpha: 1)
    let sand = UIColor(red: 0.97, green: 0.84, blue: 0.64, alpha: 1)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupHeader()
        setupScrollAndContent()
        setupGrid()
        setupTribeArea()
        Task { await setupHealthAndAutoRefresh() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        stopLiveTimer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if DEBUG
        print("Notification debug: OK")
        #endif
    }

    // MARK: Background
    func setupBackground() {
        view.backgroundColor = .systemBackground
    }

    // MARK: Header (Home + Profile)
    func setupHeader() {
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        // ✅ عنوان Home بنفس الخط السمين الدائري
        header.titleLabel.font = .aiqoRounded(size: 32, weight: .heavy)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -36),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            header.heightAnchor.constraint(equalToConstant: 60)
        ])

        header.profileButton.addTarget(self, action: #selector(openProfile), for: .touchUpInside)
    }
    // MARK: Scroll & Content
    func setupScrollAndContent() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scroll)
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])
    }

    // MARK: Grid 2×3
    func setupGrid() {
        rowStacks.removeAll()
        kindToIndexPath.removeAll()
        metrics.removeAll()

        let kinds: [MetricKind] = [.steps, .calories, .stand, .water, .sleep, .distance]
        let tints: [UIColor] = [mint, mint, sand, sand, mint, mint]

        for row in 0..<3 {
            let h = UIStackView()
            h.axis = .horizontal
            h.spacing = 14
            h.distribution = .fillEqually
            rowStacks.append(h)

            for col in 0..<2 {
                let i = row * 2 + col
                // تأكد أن MetricView يستخدم الخط الجديد داخلياً (شوف التعديل بالأسفل)
                let v = MetricView(kind: kinds[i], tint: tints[i])
                v.onTap = { [weak self] in
                    self?.presentMetricSheet(for: v.kind)
                }
                h.addArrangedSubview(v)
                metrics.append(v)
                kindToIndexPath[v.kind] = (row, col)
            }

            content.addArrangedSubview(h)
        }
    }

    // MARK: - Tribe section
    func setupTribeArea() {
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 27).isActive = true

        let tribeButton = BouncyTribeButton(type: .custom)
        tribeButton.translatesAutoresizingMaskIntoConstraints = false
        tribeButton.setImage(UIImage(named: "Tribeicon"), for: .normal)
        tribeButton.imageView?.contentMode = .scaleAspectFit

        tribeButton.addAction(UIAction { [weak self] _ in
            self?.openTribe()
        }, for: .primaryActionTriggered)

        let title = UILabel()
        title.text = NSLocalizedString("screen.home.tribe", comment: "Tribe title under icon")

        // ✅ خط سمين، مدوّر، واضح
        title.font = .aiqoRounded(size: 24, weight: .heavy)
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [tribeButton, title])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        let host = UIView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(stack)
        content.addArrangedSubview(host)

        NSLayoutConstraint.activate([
            tribeButton.widthAnchor.constraint(equalToConstant: 120),
            tribeButton.heightAnchor.constraint(equalToConstant: 120),

            stack.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            stack.topAnchor.constraint(equalTo: host.topAnchor),
            stack.bottomAnchor.constraint(equalTo: host.bottomAnchor),

            host.heightAnchor.constraint(equalToConstant: 145)
        ])
    }

    // MARK: Health — Authorization + Live Refresh
    func setupHealthAndAutoRefresh() async {
        do {
            _ = try await health.requestAuthorization()
        } catch {
            // حتى لو فشل التفويض UI نكمّل
        }

        await loadTodayFromHealth()
        startLiveTimer()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appBecameActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    @objc func appBecameActive() {
        Task { await loadTodayFromHealth() }
    }

    func startLiveTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60,
                                            repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.loadTodayFromHealth() }
        }
    }

    func stopLiveTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: Formatting + Summary
    func format(_ value: Double, digits: Int = 0) -> String {
        let f = NumberFormatter()
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = digits
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    func setMetric(_ kind: MetricKind, text: String) {
        if let v = metrics.first(where: { $0.kind == kind }) {
            v.setValue(text)
        }
    }

    func setMetric(_ kind: MetricKind, number: Double, digits: Int = 0) {
        setMetric(kind, text: format(number, digits: digits))
    }

    func clearIfNoAuth() {
        setMetric(.steps, number: 0)
        setMetric(.calories, number: 0)
        setMetric(.stand, number: 0)
        setMetric(.water, number: 0, digits: 1)
        setMetric(.sleep, number: 0, digits: 1)
        setMetric(.distance, number: 0, digits: 2)
    }

    func applySummary(_ s: TodaySummary?) {
        guard let s else {
            clearIfNoAuth()
            currentSummaryCache = nil
            return
        }

        currentSummaryCache = s
        setMetric(.steps, number: s.steps)
        setMetric(.calories, number: s.activeKcal)
        setMetric(.stand, number: s.standPercent)
        setMetric(.water, number: s.waterML / 1000.0, digits: 1)
        setMetric(.sleep, number: s.sleepHours, digits: 1)
        setMetric(.distance, number: s.distanceMeters / 1000.0, digits: 2)
    }

    func loadValuesIfAuthorized() async -> TodaySummary? {
        return try? await health.fetchTodaySummary()
    }

    func loadTodayFromHealth() async {
        let summary = await loadValuesIfAuthorized()
        await MainActor.run {
            self.applySummary(summary)
        }
    }

    func formattedHeader(for kind: MetricKind, from s: TodaySummary) -> String {
        switch kind {
        case .steps: return format(s.steps)
        case .calories: return format(s.activeKcal)
        case .stand: return format(s.standPercent) + "%"
        case .water: return String(format: "%.1f L", s.waterML / 1000.0)
        case .sleep: return String(format: "%.1f h", s.sleepHours)
        case .distance: return String(format: "%.2f km", s.distanceMeters / 1000.0)
        }
    }

    // MARK: Actions
    @objc func openProfile() {
        let profileVC = NewProfileViewController()
        let nav = UINavigationController(rootViewController: profileVC)
        presentAsSheet(nav, detents: [.large()], initial: .large())
    }

    @objc func openTribe() {
        let vc = AiQoTribeRankingViewController()
        presentAsSheet(vc, detents: [.medium(), .large()], initial: .medium())
    }

    func presentAsSheet(_ vc: UIViewController,
                        detents: [UISheetPresentationController.Detent],
                        initial: UISheetPresentationController.Detent? = nil) {
        vc.modalPresentationStyle = .pageSheet
        vc.isModalInPresentation = false

        if let sheet = vc.sheetPresentationController {
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false

            if let initial {
                if initial == .medium() {
                    sheet.selectedDetentIdentifier = .medium
                } else if initial == .large() {
                    sheet.selectedDetentIdentifier = .large
                }
            }
        }

        present(vc, animated: true)
    }
}

// MARK: - BouncyTribeButton (New Animated Button)
class BouncyTribeButton: UIButton {

    override var isHighlighted: Bool {
        didSet {
            let transform = isHighlighted
            ? CGAffineTransform(scaleX: 0.92, y: 0.92)
            : .identity

            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 3.0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: {
                    self.transform = transform
                },
                completion: nil
            )
        }
    }
}
