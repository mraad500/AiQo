import UIKit
import HealthKit
import SwiftUI

// =========================
// File: Features/Gym/GymViewController.swift
// iOS 18 Glass Bubble Tabs Header ✅
// Theme matches Home (Mint + Beige) ✅
// =========================

final class GymViewController: UIViewController, ExercisesViewControllerDelegate {

    // MARK: - Theme (Matches Home)
    private let homeMint  = Colors.mint
    private let homeBeige = Colors.aiqoBeige   // نفس بيجي Home (اللي سوّيناه)
    private let glassAlpha: CGFloat = 0.16     // تدرّج خفيف حتى ما يصير فاقع

    // MARK: - UI Elements
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Gym"
        l.font = .systemFont(ofSize: 40, weight: .black)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // زر البروفايل (تصميم Home)
    private let profileButton = FloatingProfileButton()

    // شريط التبويبات الزجاجي + فقاعة
    private let header = GlassHeader(items: ["Body", "Vitals", "Plan", "Wins", "Recap"])

    private let container = UIView()
    private var currentChild: UIViewController?

    // MARK: - Child View Controllers
    private lazy var exercisesVC: ExercisesViewController = {
        let vc = ExercisesViewController()
        vc.delegate = self
        return vc
    }()

    private lazy var heartVC   = HeartViewController()
    private lazy var myPlanVC  = MyPlanViewController()
    private lazy var rewardsVC = RewardsViewController()
    private lazy var recapVC   = RecapViewController()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // نفس Home
        view.backgroundColor = Colors.background

        buildUI()
        applyHomeThemeToGym()

        profileButton.addTarget(self, action: #selector(onProfileTap), for: .touchUpInside)

        header.onChange = { [weak self] index in
            self?.switchTo(index)
        }

        // Default Screen
        header.selectedIndex = 0
        showChild(exercisesVC)
    }

    private func buildUI() {
        header.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        profileButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(profileButton)
        view.addSubview(header)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            // رفع العنوان للأعلى
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            // زر البروفايل يتبع العنوان
            profileButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            profileButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            profileButton.widthAnchor.constraint(equalToConstant: 44),
            profileButton.heightAnchor.constraint(equalToConstant: 44),

            // شريط التبويبات تحت العنوان
            header.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            header.heightAnchor.constraint(equalToConstant: 54),

            // المحتوى
            container.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // ✅ يلوّن الهيدر/الفقاعة بلمسة Mint/Beige مثل Home
    private func applyHomeThemeToGym() {
        header.setTheme(mint: homeMint, beige: homeBeige, alpha: glassAlpha)
    }

    // MARK: - Actions
    @objc private func onProfileTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let vc = NewProfileViewController()
        vc.modalPresentationStyle = .pageSheet
        present(vc, animated: true)
    }

    private func switchTo(_ index: Int) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        switch index {
        case 0: showChild(exercisesVC)
        case 1: showChild(heartVC)
        case 2: showChild(myPlanVC)
        case 3: showChild(rewardsVC)
        case 4: showChild(recapVC)
        default: break
        }
    }

    private func showChild(_ vc: UIViewController) {
        if let currentChild {
            currentChild.willMove(toParent: nil)
            currentChild.view.removeFromSuperview()
            currentChild.removeFromParent()
        }

        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false

        // نفس Home
        vc.view.backgroundColor = vc.view.backgroundColor ?? Colors.background

        container.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: container.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        vc.didMove(toParent: self)
        currentChild = vc
    }

    // MARK: - Delegate
    func didSelectExercise(name: String, activityType: HKWorkoutActivityType, location: HKWorkoutSessionLocationType) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let live = LiveWorkoutSession(title: name, activityType: activityType, locationType: location)
        let screen = WorkoutSessionScreen(session: live)
        let host = UIHostingController(rootView: screen)

        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 30
        }
        present(host, animated: true)
    }
}

// =========================
// MARK: - GlassHeader (iOS 18 Glass + Bubble Tabs)
// =========================

final class GlassHeader: UIView {

    private let items: [String]
    var onChange: ((Int) -> Void)?

    var selectedIndex: Int {
        get { tabs.selectedIndex }
        set { tabs.setSelectedIndex(newValue, animated: false) }
    }

    private let backgroundGlass = UIVisualEffectView()
    private let tintOverlay = UIView() // ✅ Tint overlay for Home palette
    private let tabs: GlassBubbleTabs

    init(items: [String]) {
        self.items = items
        self.tabs = GlassBubbleTabs(items: items)
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.items = ["Body", "Vitals", "Plan", "Wins", "Recap"]
        self.tabs = GlassBubbleTabs(items: self.items)
        super.init(coder: coder)
        setup()
    }

    func setTheme(mint: UIColor, beige: UIColor, alpha: CGFloat) {
        // نستخدم mint كلون عام للهيدر (نفس جو Home)
        tintOverlay.backgroundColor = mint.withAlphaComponent(alpha)
        tabs.setTheme(mint: mint, beige: beige, alpha: alpha)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        // شكل الحاوية
        layer.cornerRadius = 27
        layer.cornerCurve = .continuous

        // Glass background
        backgroundGlass.translatesAutoresizingMaskIntoConstraints = false
        backgroundGlass.clipsToBounds = true
        backgroundGlass.layer.cornerRadius = 27
        backgroundGlass.layer.cornerCurve = .continuous

        if #available(iOS 18.0, *) {
            backgroundGlass.effect = UIGlassEffect()
        } else {
            backgroundGlass.effect = UIBlurEffect(style: .systemUltraThinMaterial)
        }

        // ✅ Tint overlay
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        tintOverlay.isUserInteractionEnabled = false
        tintOverlay.backgroundColor = .clear
        tintOverlay.layer.cornerRadius = 27
        tintOverlay.layer.cornerCurve = .continuous
        tintOverlay.clipsToBounds = true

        // ظل خفيف يطي “floating”
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.10
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)

        addSubview(backgroundGlass)
        backgroundGlass.contentView.addSubview(tintOverlay)
        backgroundGlass.contentView.addSubview(tabs)

        tabs.translatesAutoresizingMaskIntoConstraints = false
        tabs.onSelect = { [weak self] index in
            self?.onChange?(index)
        }

        NSLayoutConstraint.activate([
            backgroundGlass.topAnchor.constraint(equalTo: topAnchor),
            backgroundGlass.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundGlass.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundGlass.trailingAnchor.constraint(equalTo: trailingAnchor),

            tintOverlay.topAnchor.constraint(equalTo: backgroundGlass.contentView.topAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: backgroundGlass.contentView.bottomAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: backgroundGlass.contentView.leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: backgroundGlass.contentView.trailingAnchor),

            tabs.leadingAnchor.constraint(equalTo: backgroundGlass.contentView.leadingAnchor, constant: 6),
            tabs.trailingAnchor.constraint(equalTo: backgroundGlass.contentView.trailingAnchor, constant: -6),
            tabs.topAnchor.constraint(equalTo: backgroundGlass.contentView.topAnchor, constant: 6),
            tabs.bottomAnchor.constraint(equalTo: backgroundGlass.contentView.bottomAnchor, constant: -6)
        ])
    }
}

// =========================
// MARK: - GlassBubbleTabs (الفقاعة تتحرك سلاسة)
// =========================

final class GlassBubbleTabs: UIControl {

    var onSelect: ((Int) -> Void)?
    private(set) var selectedIndex: Int = 0

    private let items: [String]
    private let bubble = UIVisualEffectView()
    private let bubbleTint = UIView() // ✅ tint for bubble (beige like Home)
    private let stack = UIStackView()
    private var buttons: [UIButton] = []

    private var bubbleLeading: NSLayoutConstraint!
    private var bubbleWidth: NSLayoutConstraint!

    init(items: [String]) {
        self.items = items
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.items = ["Body", "Vitals", "Plan", "Wins", "Recap"]
        super.init(coder: coder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBubble(animated: false)
    }

    func setSelectedIndex(_ index: Int, animated: Bool) {
        guard index >= 0, index < items.count else { return }
        selectedIndex = index
        updateSelection(animated: animated)
    }

    func setTheme(mint: UIColor, beige: UIColor, alpha: CGFloat) {
        // نخلي الفقاعة لونها أقرب لبيجي Home
        bubbleTint.backgroundColor = beige.withAlphaComponent(alpha)
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        // Bubble effect
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.clipsToBounds = true
        bubble.layer.cornerRadius = 18
        bubble.layer.cornerCurve = .continuous

        if #available(iOS 18.0, *) {
            bubble.effect = UIGlassEffect()
        } else {
            bubble.effect = UIBlurEffect(style: .systemMaterial)
        }

        // ✅ tint داخل الفقاعة
        bubbleTint.translatesAutoresizingMaskIntoConstraints = false
        bubbleTint.isUserInteractionEnabled = false
        bubbleTint.backgroundColor = .clear
        bubble.contentView.addSubview(bubbleTint)
        NSLayoutConstraint.activate([
            bubbleTint.topAnchor.constraint(equalTo: bubble.contentView.topAnchor),
            bubbleTint.bottomAnchor.constraint(equalTo: bubble.contentView.bottomAnchor),
            bubbleTint.leadingAnchor.constraint(equalTo: bubble.contentView.leadingAnchor),
            bubbleTint.trailingAnchor.constraint(equalTo: bubble.contentView.trailingAnchor)
        ])

        // لمعة بسيطة داخل الفقاعة
        let highlight = UIView()
        highlight.translatesAutoresizingMaskIntoConstraints = false
        highlight.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.10)
        bubble.contentView.addSubview(highlight)
        NSLayoutConstraint.activate([
            highlight.topAnchor.constraint(equalTo: bubble.contentView.topAnchor),
            highlight.bottomAnchor.constraint(equalTo: bubble.contentView.bottomAnchor),
            highlight.leadingAnchor.constraint(equalTo: bubble.contentView.leadingAnchor),
            highlight.trailingAnchor.constraint(equalTo: bubble.contentView.trailingAnchor)
        ])

        // Border خفيف للفقاعة
        bubble.layer.borderWidth = 0.5
        bubble.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor

        // Stack
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 4

        addSubview(bubble)
        addSubview(stack)

        // Buttons
        buttons = items.enumerated().map { (i, title) in
            let b = UIButton(type: .system)
            b.tag = i
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            b.setTitleColor(.secondaryLabel, for: .normal)
            b.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
            b.accessibilityLabel = title
            return b
        }

        buttons.forEach { stack.addArrangedSubview($0) }

        // Bubble constraints
        bubbleLeading = bubble.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0)
        bubbleWidth = bubble.widthAnchor.constraint(equalToConstant: 10)

        NSLayoutConstraint.activate([
            bubbleLeading,
            bubbleWidth,
            bubble.topAnchor.constraint(equalTo: topAnchor),
            bubble.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        selectedIndex = 0
        updateSelection(animated: false)
    }

    @objc private func tap(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedIndex else { return }
        setSelectedIndex(index, animated: true)
        onSelect?(index)
    }

    private func updateSelection(animated: Bool) {
        for (i, b) in buttons.enumerated() {
            if i == selectedIndex {
                b.setTitleColor(.label, for: .normal)
                b.titleLabel?.font = .systemFont(ofSize: 14, weight: .heavy)
            } else {
                b.setTitleColor(.secondaryLabel, for: .normal)
                b.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
            }
        }
        updateBubble(animated: animated)
    }

    private func updateBubble(animated: Bool) {
        let count = max(items.count, 1)
        let w = bounds.width
        guard w > 0 else { return }

        let segmentWidth = w / CGFloat(count)
        bubbleWidth.constant = segmentWidth
        bubbleLeading.constant = segmentWidth * CGFloat(selectedIndex)

        let animations = { self.layoutIfNeeded() }

        if animated {
            UIView.animate(
                withDuration: 0.36,
                delay: 0,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0.25,
                options: [.allowUserInteraction, .curveEaseInOut],
                animations: animations
            )
        } else {
            animations()
        }
    }
}

// =========================
// MARK: - FloatingProfileButton (نفس تصميمك)
// =========================

final class FloatingProfileButton: UIControl {

    private let icon = UIImageView(image: UIImage(systemName: "person.fill"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 22
        layer.cornerCurve = .circular

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 4)

        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .label
        icon.contentMode = .scaleAspectFit

        addSubview(icon)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])

        addTarget(self, action: #selector(animatePress), for: .touchDown)
        addTarget(self, action: #selector(animateRelease), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    @objc private func animatePress() {
        UIView.animate(withDuration: 0.1) { self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92) }
    }

    @objc private func animateRelease() {
        UIView.animate(withDuration: 0.1) { self.transform = .identity }
    }
}
