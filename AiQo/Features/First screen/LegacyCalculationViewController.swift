// File: LegacyCalculationViewController.swift
import UIKit
import HealthKit

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
        let levelProgress: Double

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

    // MARK: - Theme

    private let brandMint  = Colors.mint
    private let brandBeige = Colors.aiqoBeige

    private let darkBG     = UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0)
    private let darkText   = UIColor.white
    private let darkSub    = UIColor.white.withAlphaComponent(0.70)
    private let darkSub2   = UIColor.white.withAlphaComponent(0.55)

    // MARK: - UI

    private let backgroundGradientLayer = CAGradientLayer()
    private let glowLayer = CALayer()
    private let dimOverlay = UIView()

    private let brandRow = UIStackView()
    private let topTitle = UILabel()
    private let brandSpark = UIImageView(image: UIImage(systemName: "sparkles"))

    private let cardView = BeigeGlassCardView()
    private let mainStack = UIStackView()

    private let introStack = UIStackView()
    private let loadingStack = UIStackView()
    private let resultStack = UIStackView()

    // Intro
    private let heroPill = UIView()
    private let heroIcon = UIImageView(image: UIImage(systemName: "sparkles"))
    private let brandWordmark = UILabel()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let privacyNoteLabel = UILabel()

    // Loading (Premium Ripple Loader)
    private let premiumLoader = PremiumRippleLoader()
    private let loadingLabel = UILabel()
    private let loadingBar = UIProgressView(progressViewStyle: .bar)

    // Result
    private let resultHeaderCard = PlainCardView()
    private let levelTitleLabel = UILabel()
    
    // Level Display
    private let levelCaptionLabel = UILabel()
    private let levelNumberLabel = UILabel()

    private let messageLabel = UILabel()

    private let progressPill = PlainPillView()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private var progressFillWidth: NSLayoutConstraint!

    private let pointsTitleLabel = UILabel()
    private let pointsCard = PlainCardView()
    private let pointsTable = UITableView(frame: .zero, style: .plain)
    private var pointsRows: [PointsRow] = []

    // Buttons
    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)

    // Confetti
    private var confettiLayer: CAEmitterLayer?

    private var currentState: State = .intro {
        didSet { updateUI(for: currentState) }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.hidesBackButton = true
        navigationItem.title = ""

        setupBackground()
        setupBrandRow()
        setupCard()
        setupLayout()
        configureTexts()

        currentState = .intro
        animateIntroEntrance()
        startBrandSparkAnimation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
        glowLayer.frame = view.bounds

        if case .result(let model) = currentState {
            applyProgress(model.levelProgress, animated: false)
        }
    }

    // MARK: - Background

    private func setupBackground() {
        view.backgroundColor = darkBG

        backgroundGradientLayer.colors = [
            brandMint.withAlphaComponent(0.22).cgColor,
            darkBG.withAlphaComponent(0.98).cgColor,
            brandBeige.withAlphaComponent(0.18).cgColor
        ]
        backgroundGradientLayer.locations = [0.0, 0.56, 1.0]
        backgroundGradientLayer.startPoint = CGPoint(x: 0.08, y: 0.0)
        backgroundGradientLayer.endPoint = CGPoint(x: 0.92, y: 1.0)
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)

        glowLayer.backgroundColor = UIColor.clear.cgColor
        view.layer.insertSublayer(glowLayer, above: backgroundGradientLayer)

        glowLayer.addSublayer(makeRadialGlow(center: CGPoint(x: 0.18, y: 0.12), radius: 320, color: brandMint.withAlphaComponent(0.10)))
        glowLayer.addSublayer(makeRadialGlow(center: CGPoint(x: 0.85, y: 0.88), radius: 360, color: brandBeige.withAlphaComponent(0.10)))

        dimOverlay.translatesAutoresizingMaskIntoConstraints = false
        dimOverlay.isUserInteractionEnabled = false
        dimOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        view.addSubview(dimOverlay)
        NSLayoutConstraint.activate([
            dimOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            dimOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dimOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func makeRadialGlow(center: CGPoint, radius: CGFloat, color: UIColor) -> CALayer {
        let layer = CAGradientLayer()
        layer.type = .radial
        layer.colors = [color.cgColor, UIColor.clear.cgColor]
        layer.locations = [0.0, 1.0]
        layer.startPoint = center
        layer.endPoint = CGPoint(
            x: center.x + (radius / max(view.bounds.width, 1)),
            y: center.y + (radius / max(view.bounds.height, 1))
        )
        layer.frame = view.bounds
        return layer
    }

    // MARK: - Brand Row + Animation

    private func setupBrandRow() {
        brandRow.translatesAutoresizingMaskIntoConstraints = false
        brandRow.axis = .horizontal
        brandRow.alignment = .center
        brandRow.spacing = 10
        // ✅ تعديل هام: تفعيل عدم القص لضمان ظهور الوهج كاملاً حتى لو خرج عن الحدود
        brandRow.clipsToBounds = false
        brandRow.layer.masksToBounds = false
        
        // رفع الـ ZPosition لضمان ظهوره فوق الخلفية دائماً
        brandRow.layer.zPosition = 100

        topTitle.translatesAutoresizingMaskIntoConstraints = false
        topTitle.text = "AiQo"
        topTitle.textColor = darkText
        topTitle.font = roundedFont(size: 40, weight: .black)

        brandSpark.translatesAutoresizingMaskIntoConstraints = false
        brandSpark.tintColor = brandMint.withAlphaComponent(0.98)
        brandSpark.preferredSymbolConfiguration = .init(pointSize: 18, weight: .bold)
        brandSpark.alpha = 0.98
        // ✅ تفعيل عدم القص للأنميشن نفسه
        brandSpark.clipsToBounds = false
        brandSpark.layer.masksToBounds = false

        brandRow.addArrangedSubview(topTitle)
        brandRow.addArrangedSubview(brandSpark)

        view.addSubview(brandRow)

        // ✅ التعديل الجوهري لرفع العنصر:
        // استخدام -5 مع safeArea يرفعه قليلاً للأعلى في منطقة الهيدر بشكل آمن
        NSLayoutConstraint.activate([
            brandRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            brandRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -5)
        ])
    }

    private func startBrandSparkAnimation() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.92
        pulse.toValue = 1.06
        pulse.duration = 1.1
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let glow = CABasicAnimation(keyPath: "opacity")
        glow.fromValue = 0.65
        glow.toValue = 1.0
        glow.duration = 1.1
        glow.autoreverses = true
        glow.repeatCount = .infinity
        glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let rotate = CABasicAnimation(keyPath: "transform.rotation")
        rotate.fromValue = -0.06
        rotate.toValue = 0.06
        rotate.duration = 0.9
        rotate.autoreverses = true
        rotate.repeatCount = .infinity
        rotate.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        brandSpark.layer.add(pulse, forKey: "pulse")
        brandSpark.layer.add(glow, forKey: "glow")
        brandSpark.layer.add(rotate, forKey: "rotate")
    }

    // MARK: - Card

    private func setupCard() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.apply(beige: brandBeige, mint: brandMint)

        view.addSubview(cardView)

        // ✅ الكارت يتبع اللوغو تلقائياً لأنه مرتبط بـ brandRow.bottomAnchor
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            cardView.topAnchor.constraint(equalTo: brandRow.bottomAnchor, constant: 8),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18)
        ])
    }

    // MARK: - Layout

    private func setupLayout() {
        mainStack.axis = .vertical
        mainStack.spacing = 16
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.layoutMargins = UIEdgeInsets(top: 20, left: 18, bottom: 18, right: 18)
        mainStack.isLayoutMarginsRelativeArrangement = true

        cardView.contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: cardView.contentView.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor)
        ])

        setupIntroSection()
        setupLoadingSection()
        setupResultSection()
        setupButtons()

        mainStack.addArrangedSubview(introStack)
        mainStack.addArrangedSubview(loadingStack)
        mainStack.addArrangedSubview(resultStack)
        mainStack.addArrangedSubview(makeSpacer(minHeight: 10))
        mainStack.addArrangedSubview(primaryButton)
        mainStack.addArrangedSubview(secondaryButton)

        loadingStack.isHidden = true
        resultStack.isHidden = true
    }

    private func setupIntroSection() {
        introStack.axis = .vertical
        introStack.spacing = 14
        introStack.alignment = .fill

        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.textColor = darkText
        titleLabel.font = roundedFont(size: 34, weight: .black)

        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = darkSub
        subtitleLabel.font = roundedFont(size: 16, weight: .semibold)

        privacyNoteLabel.numberOfLines = 0
        privacyNoteLabel.textAlignment = .center
        privacyNoteLabel.textColor = darkSub2
        privacyNoteLabel.font = roundedFont(size: 13, weight: .medium)

        introStack.addArrangedSubview(titleLabel)
        introStack.addArrangedSubview(subtitleLabel)
        introStack.addArrangedSubview(privacyNoteLabel)
    }

    private func setupLoadingSection() {
        loadingStack.axis = .vertical
        loadingStack.spacing = 20
        loadingStack.alignment = .center

        premiumLoader.setup(tint: brandMint)
        NSLayoutConstraint.activate([
            premiumLoader.widthAnchor.constraint(equalToConstant: 80),
            premiumLoader.heightAnchor.constraint(equalToConstant: 80)
        ])

        loadingLabel.numberOfLines = 0
        loadingLabel.textAlignment = .center
        loadingLabel.font = roundedFont(size: 16, weight: .bold)
        loadingLabel.textColor = darkText.withAlphaComponent(0.9)

        loadingBar.translatesAutoresizingMaskIntoConstraints = false
        loadingBar.progress = 0.12
        loadingBar.layer.cornerRadius = 6
        loadingBar.clipsToBounds = true
        loadingBar.trackTintColor = UIColor.white.withAlphaComponent(0.08)
        loadingBar.progressTintColor = brandMint

        NSLayoutConstraint.activate([
            loadingBar.heightAnchor.constraint(equalToConstant: 8),
            loadingBar.widthAnchor.constraint(equalToConstant: 200)
        ])

        loadingStack.addArrangedSubview(premiumLoader)
        loadingStack.addArrangedSubview(loadingLabel)
        loadingStack.addArrangedSubview(loadingBar)
    }

    private func setupResultSection() {
        resultStack.axis = .vertical
        resultStack.spacing = 12
        resultStack.alignment = .fill

        let headerInner = UIStackView()
        headerInner.axis = .vertical
        headerInner.spacing = 10
        headerInner.alignment = .fill
        headerInner.translatesAutoresizingMaskIntoConstraints = false
        headerInner.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        headerInner.isLayoutMarginsRelativeArrangement = true

        levelTitleLabel.numberOfLines = 0
        levelTitleLabel.textAlignment = .left
        levelTitleLabel.font = roundedFont(size: 26, weight: .black)
        levelTitleLabel.textColor = darkText
        
        // LEVEL Design
        levelCaptionLabel.text = "LEVEL"
        levelCaptionLabel.font = roundedFont(size: 17, weight: .black)
        levelCaptionLabel.textColor = brandMint
        
        levelNumberLabel.font = roundedFont(size: 48, weight: .black)
        levelNumberLabel.textColor = brandMint
        
        let levelDisplayStack = UIStackView(arrangedSubviews: [levelCaptionLabel, levelNumberLabel])
        levelDisplayStack.axis = .vertical
        levelDisplayStack.alignment = .trailing
        levelDisplayStack.spacing = -6
        
        let titleRow = UIStackView(arrangedSubviews: [levelTitleLabel, UIView(), levelDisplayStack])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 10

        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left
        messageLabel.font = roundedFont(size: 15, weight: .semibold)
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.72)

        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        progressTrack.layer.cornerRadius = 10
        progressTrack.layer.cornerCurve = .continuous
        progressTrack.clipsToBounds = true

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = brandMint.withAlphaComponent(0.98)
        progressFill.layer.cornerRadius = 10
        progressFill.layer.cornerCurve = .continuous
        progressFill.clipsToBounds = true

        progressPill.contentView.addSubview(progressTrack)
        progressTrack.addSubview(progressFill)

        NSLayoutConstraint.activate([
            progressTrack.topAnchor.constraint(equalTo: progressPill.contentView.topAnchor, constant: 8),
            progressTrack.bottomAnchor.constraint(equalTo: progressPill.contentView.bottomAnchor, constant: -8),
            progressTrack.leadingAnchor.constraint(equalTo: progressPill.contentView.leadingAnchor, constant: 10),
            progressTrack.trailingAnchor.constraint(equalTo: progressPill.contentView.trailingAnchor, constant: -10),
            progressTrack.heightAnchor.constraint(equalToConstant: 20),

            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor)
        ])

        progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 24)
        progressFillWidth.isActive = true

        headerInner.addArrangedSubview(titleRow)
        headerInner.addArrangedSubview(messageLabel)
        headerInner.addArrangedSubview(progressPill)

        resultHeaderCard.contentView.addSubview(headerInner)

        NSLayoutConstraint.activate([
            headerInner.topAnchor.constraint(equalTo: resultHeaderCard.contentView.topAnchor),
            headerInner.bottomAnchor.constraint(equalTo: resultHeaderCard.contentView.bottomAnchor),
            headerInner.leadingAnchor.constraint(equalTo: resultHeaderCard.contentView.leadingAnchor),
            headerInner.trailingAnchor.constraint(equalTo: resultHeaderCard.contentView.trailingAnchor),
            progressPill.heightAnchor.constraint(equalToConstant: 36)
        ])

        pointsTitleLabel.numberOfLines = 1
        pointsTitleLabel.text = "Points breakdown"
        pointsTitleLabel.textColor = darkText
        pointsTitleLabel.font = roundedFont(size: 15, weight: .bold)

        pointsTable.translatesAutoresizingMaskIntoConstraints = false
        pointsTable.backgroundColor = .clear
        pointsTable.isScrollEnabled = false
        pointsTable.separatorStyle = .none
        pointsTable.dataSource = self
        pointsTable.delegate = self
        pointsTable.register(PointsCell.self, forCellReuseIdentifier: PointsCell.reuseID)
        pointsTable.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 10, right: 0)

        pointsCard.contentView.addSubview(pointsTable)

        NSLayoutConstraint.activate([
            pointsTable.topAnchor.constraint(equalTo: pointsCard.contentView.topAnchor),
            pointsTable.bottomAnchor.constraint(equalTo: pointsCard.contentView.bottomAnchor),
            pointsTable.leadingAnchor.constraint(equalTo: pointsCard.contentView.leadingAnchor),
            pointsTable.trailingAnchor.constraint(equalTo: pointsCard.contentView.trailingAnchor),
            pointsCard.heightAnchor.constraint(equalToConstant: 285)
        ])

        resultStack.addArrangedSubview(resultHeaderCard)
        resultStack.addArrangedSubview(pointsTitleLabel)
        resultStack.addArrangedSubview(pointsCard)
    }

    private func setupButtons() {
        primaryButton.addTarget(self, action: #selector(primaryButtonTapped), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(secondaryButtonTapped), for: .touchUpInside)

        GlassButtons.stylePrimary(primaryButton, title: "Continue", systemImage: "arrow.right", mint: brandMint, text: UIColor.black)
        GlassButtons.styleSecondary(secondaryButton, title: "Not now", beige: brandBeige, text: UIColor.black)
    }

    private func configureTexts() {
        titleLabel.text = "Welcome to AiQo"
        subtitleLabel.text = "Connect Apple Health and we’ll build your fitness level from your real history."
        privacyNoteLabel.text = "Privacy first: we only read totals (steps, calories, distance, sleep) to calculate your level."
        loadingLabel.text = "Analyzing your history..."
    }

    private func makeSpacer(minHeight: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
        return v
    }

    // MARK: - UI State

    private func updateUI(for state: State) {
        switch state {
        case .intro:
            introStack.isHidden = false
            loadingStack.isHidden = true
            resultStack.isHidden = true

            primaryButton.isHidden = false
            secondaryButton.isHidden = false

            GlassButtons.stylePrimary(primaryButton, title: "Continue", systemImage: "arrow.right", mint: brandMint, text: UIColor.black)
            GlassButtons.styleSecondary(secondaryButton, title: "Not now", beige: brandBeige, text: UIColor.black)

        case .loading:
            introStack.isHidden = true
            loadingStack.isHidden = false
            resultStack.isHidden = true

            primaryButton.isHidden = true
            secondaryButton.isHidden = true

            startLoadingAnimations()

        case .result(let model):
            stopLoadingAnimations()

            introStack.isHidden = true
            loadingStack.isHidden = true
            resultStack.isHidden = false

            levelTitleLabel.text = model.hasHealthData ? model.levelName : NSLocalizedString("level_name_starter", comment: "")
            
            // Update Number
            let finalLevel = model.hasHealthData ? model.level : 1
            levelNumberLabel.text = "\(finalLevel)"
            animateLevelNumberEntrance()

            messageLabel.text = model.hasHealthData
                ? "\(model.message)\nTotal: \(model.totalPoints) pts"
                : "No history found yet.\nStart today and your level will grow fast."

            applyProgress(model.levelProgress, animated: true)

            pointsRows = makeRows(from: model)
            pointsTable.reloadData()

            primaryButton.isHidden = false
            secondaryButton.isHidden = true
            GlassButtons.stylePrimary(primaryButton, title: "Go to Home", systemImage: "house.fill", mint: brandMint, text: UIColor.black)

            let h = UIImpactFeedbackGenerator(style: .soft)
            h.impactOccurred()

            playResultEntrance()
            playConfettiLight()
        }
    }
    
    private func animateLevelNumberEntrance() {
        levelNumberLabel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        levelNumberLabel.alpha = 0
        
        UIView.animate(withDuration: 0.6, delay: 0.2, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .allowUserInteraction) {
            self.levelNumberLabel.transform = .identity
            self.levelNumberLabel.alpha = 1
        }
    }

    private func applyProgress(_ progress: Double, animated: Bool) {
        view.layoutIfNeeded()

        let p = CGFloat(min(max(progress, 0), 1))
        let available = max(240.0, (progressPill.bounds.width > 10 ? progressPill.bounds.width : 300.0) - 20.0)
        let target = max(24.0, available * p)

        progressFillWidth.constant = target

        if animated {
            UIView.animate(withDuration: 0.45, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.progressPill.layoutIfNeeded()
            }
        } else {
            progressPill.layoutIfNeeded()
        }
    }

    private func makeRows(from model: ResultModel) -> [PointsRow] {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = .current

        let stepsText = nf.string(from: model.totalSteps as NSNumber) ?? "\(Int(model.totalSteps))"
        let caloriesText = nf.string(from: model.totalCalories as NSNumber) ?? "\(Int(model.totalCalories))"
        let distanceText = String(format: "%.1f km", model.totalDistanceKm)
        let sleepText = String(format: "%.1f h", model.totalSleepHours)

        return [
            .init(title: "Steps", value: stepsText, points: model.stepsPoints, symbol: "figure.walk"),
            .init(title: "Calories", value: caloriesText, points: model.caloriesPoints, symbol: "flame.fill"),
            .init(title: "Distance", value: distanceText, points: model.distancePoints, symbol: "location.fill"),
            .init(title: "Sleep", value: sleepText, points: model.sleepPoints, symbol: "moon.zzz.fill"),
            .init(title: "Total", value: "—", points: model.totalPoints, symbol: "sparkles")
        ]
    }

    // MARK: - Animations

    private func animateIntroEntrance() {
        cardView.transform = CGAffineTransform(scaleX: 0.985, y: 0.985).translatedBy(x: 0, y: 10)
        cardView.alpha = 0

        UIView.animate(withDuration: 0.55, delay: 0.04, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.65, options: [.allowUserInteraction]) {
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    private func startLoadingAnimations() {
        premiumLoader.startAnimating()

        loadingBar.layer.removeAllAnimations()
        loadingBar.setProgress(0.18, animated: false)
        UIView.animate(withDuration: 1.2, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction]) {
            self.loadingBar.setProgress(0.92, animated: true)
        }
    }

    private func stopLoadingAnimations() {
        premiumLoader.stopAnimating()
        loadingBar.layer.removeAllAnimations()
    }

    private func playResultEntrance() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        resultHeaderCard.transform = CGAffineTransform(scaleX: 0.985, y: 0.985).translatedBy(x: 0, y: 8)
        resultHeaderCard.alpha = 0

        UIView.animate(withDuration: 0.55, delay: 0.02, usingSpringWithDamping: 0.80, initialSpringVelocity: 0.65, options: [.allowUserInteraction]) {
            self.resultHeaderCard.alpha = 1
            self.resultHeaderCard.transform = .identity
        }
    }

    private func playConfettiLight() {
        confettiLayer?.removeFromSuperlayer()
        confettiLayer = nil

        let layer = CAEmitterLayer()
        layer.emitterPosition = CGPoint(x: view.bounds.midX, y: cardView.frame.minY + 10)
        layer.emitterShape = .line
        layer.emitterSize = CGSize(width: min(view.bounds.width * 0.55, 300), height: 1)

        func cell(_ color: UIColor) -> CAEmitterCell {
            let c = CAEmitterCell()
            c.birthRate = 2.2
            c.lifetime = 1.9
            c.velocity = 95
            c.velocityRange = 35
            c.emissionLongitude = .pi
            c.emissionRange = .pi / 6
            c.spinRange = 2.2
            c.scale = 0.022
            c.scaleRange = 0.014
            c.color = color.cgColor
            c.contents = UIImage(systemName: "circle.fill")?
                .withTintColor(color, renderingMode: .alwaysOriginal)
                .cgImage
            return c
        }

        layer.emitterCells = [
            cell(brandMint.withAlphaComponent(0.92)),
            cell(brandBeige.withAlphaComponent(0.92)),
            cell(UIColor.white.withAlphaComponent(0.85))
        ]

        view.layer.addSublayer(layer)
        confettiLayer = layer

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, let l = self.confettiLayer else { return }
            l.birthRate = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                l.removeFromSuperlayer()
            }
        }
    }

    // MARK: - Actions

    @objc private func primaryButtonTapped() {
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
                        totalPoints: 0, level: 1, levelProgress: 0,
                        totalSteps: 0, stepsPoints: 0,
                        totalCalories: 0, caloriesPoints: 0,
                        totalDistanceKm: 0, distancePoints: 0,
                        totalSleepHours: 0, sleepPoints: 0,
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

    @objc private func secondaryButtonTapped() {
        markCompletedAndGoToMain()
    }

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
            let delay = max(0.0, 1.15 - elapsed)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let result = result else {
                    self.markCompletedAndGoToMain()
                    return
                }
                self.currentState = .result(result)
            }
        }
    }

    // MARK: - Health Authorization

    private func requestHealthAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

        healthStore.requestAuthorization(toShare: nil, read: [stepType, energyType, distanceType, sleepType]) { success, error in
            if let error = error {
                print("HealthKit Authorization Error:", error.localizedDescription)
            }
            DispatchQueue.main.async { completion(success) }
        }
    }

    // MARK: - Health Totals

    private func fetchHealthTotals(completion: @escaping (ResultModel?) -> Void) {
        let group = DispatchGroup()

        var totalSteps: Double = 0
        var totalCalories: Double = 0
        var totalDistanceKm: Double = 0
        var totalSleepHours: Double = 0

        let predicate = HKQuery.predicateForSamples(withStart: .distantPast, end: Date(), options: .strictStartDate)

        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            let q = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                if let sum = stats?.sumQuantity() { totalSteps = sum.doubleValue(for: .count()) }
                group.leave()
            }
            healthStore.execute(q)
        }

        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            group.enter()
            let q = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                if let sum = stats?.sumQuantity() { totalCalories = sum.doubleValue(for: .kilocalorie()) }
                group.leave()
            }
            healthStore.execute(q)
        }

        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            group.enter()
            let q = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                if let sum = stats?.sumQuantity() {
                    totalDistanceKm = sum.doubleValue(for: .meter()) / 1000.0
                }
                group.leave()
            }
            healthStore.execute(q)
        }

        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            group.enter()

            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]

            let q = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                defer { group.leave() }

                guard let s = samples as? [HKCategorySample], !s.isEmpty else {
                    totalSleepHours = 0
                    return
                }

                var totalSeconds: TimeInterval = 0
                for item in s where asleepValues.contains(item.value) {
                    totalSeconds += item.endDate.timeIntervalSince(item.startDate)
                }
                totalSleepHours = totalSeconds / 3600.0
            }
            healthStore.execute(q)
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            let model = self.buildResultModel(
                steps: totalSteps,
                calories: totalCalories,
                distanceKm: totalDistanceKm,
                sleepHours: totalSleepHours
            )
            DispatchQueue.main.async { completion(model) }
        }
    }

    // MARK: - Level System + Scoring

    private func calculateLevel(from totalPoints: Int) -> (level: Int, progress: Double) {
        let baseRequirement = 500
        let increment = 200

        var remaining = max(totalPoints, 0)
        var level = 1
        var req = baseRequirement

        while remaining >= req {
            remaining -= req
            level += 1
            req += increment
        }

        let progress = req > 0 ? Double(remaining) / Double(req) : 0
        return (max(level, 1), min(max(progress, 0), 1))
    }

    private func buildResultModel(steps: Double, calories: Double, distanceKm: Double, sleepHours: Double) -> ResultModel {

        let stepsPoints = Int(steps / 1_000.0)
        let caloriesPoints = Int(calories / 100.0)
        let distancePoints = Int(distanceKm * 5.0)
        let sleepPoints = Int(sleepHours / 8.0) * 20

        let totalPoints = max(0, stepsPoints + caloriesPoints + distancePoints + sleepPoints)

        let info = calculateLevel(from: totalPoints)
        let level = info.level
        let levelProgress = info.progress

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

    // MARK: - Typography

    private func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return base
    }
}

// MARK: - Table

extension LegacyCalculationViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        pointsRows.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 56 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = pointsRows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: PointsCell.reuseID, for: indexPath) as! PointsCell

        cell.configure(
            title: row.title,
            value: row.value,
            points: row.points,
            symbol: row.symbol,
            isTotal: row.title == "Total",
            tint: Colors.mint,
            text: UIColor.white,
            sub: UIColor.white.withAlphaComponent(0.60)
        )
        return cell
    }
}
