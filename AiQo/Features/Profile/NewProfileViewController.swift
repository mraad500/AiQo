import UIKit
import PhotosUI
import Supabase
import SwiftUI
import FamilyControls
internal import Combine

// MARK: - ☁️ AliveControl Base Class
// كلاس مسؤول عن حركات الطفو والتموج للأزرار والكروت
class AliveControl: UIControl {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupFloating()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFloating()
    }
    
    // 1. تأثير الطفو
    private func setupFloating() {
        let delay = Double.random(in: 0.0...2.0)
        let duration = Double.random(in: 3.5...5.5)
        
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = 0
        animation.toValue = -6
        animation.duration = duration
        animation.beginTime = CACurrentMediaTime() + delay
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        self.layer.add(animation, forKey: "floating")
    }
    
    // 2. تأثير اللمس
    override var isHighlighted: Bool {
        didSet {
            animateTouch(isPressed: isHighlighted)
        }
    }
    
    private func animateTouch(isPressed: Bool) {
        if isPressed {
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.5, options: [.allowUserInteraction]) {
                self.transform = .identity
            }
        }
    }
}

// MARK: - NewProfileViewController
final class NewProfileViewController: UIViewController, PHPickerViewControllerDelegate, UIGestureRecognizerDelegate {

    // MARK: - UI Components
    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        sv.delaysContentTouches = false
        return sv
    }()

    let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Header Section
    let headerContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 28
        view.layer.cornerCurve = .continuous
        return view
    }()

    let avatarButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.layer.cornerRadius = 40
        btn.clipsToBounds = true
        btn.imageView?.contentMode = .scaleAspectFill
        btn.backgroundColor = .systemGray5
        return btn
    }()

    let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 24, weight: .black)
        l.textAlignment = .natural
        return l
    }()

    let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = .secondaryLabel
        l.text = NSLocalizedString("optimize_bio", value: "Let's optimize your body & mind", comment: "")
        l.textAlignment = .natural
        return l
    }()

    // Body Stats Buttons (AliveControl)
    lazy var ageButton = createMetricCard(icon: "calendar", title: "--")
    lazy var heightButton = createMetricCard(icon: "ruler", title: "--")
    lazy var weightButton = createMetricCard(icon: "scalemass", title: "--")
    lazy var goalButton = createMetricCard(icon: "flame", title: "--")

    // Custom Cards
    let levelCard = LevelCardView()
    let currencyCard = CurrencyCardView()

    // Gender Segment
    let genderSegment = UISegmentedControl(items: [
        NSLocalizedString("male", value: "Male", comment: ""),
        NSLocalizedString("female", value: "Female", comment: "")
    ])

    // MARK: - Data Variables
    var profile: UserProfile {
        get { UserProfileStore.shared.current }
        set {
            UserProfileStore.shared.current = newValue
            loadData() // تحديث الواجهة عند تغيير البيانات
        }
    }
    
    var cancellables = Set<AnyCancellable>()
    var supabase: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupUI()
        setupActions()
        loadData()
        loadAvatarFromDisk()
        
        // مراقبة رصيد العملة
        CoinManager.shared.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newBalance in
                self?.currencyCard.updateBalance(amount: newBalance)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(self, selector: #selector(refreshLevel), name: .levelStoreDidChange, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        currencyCard.updateBalance(amount: CoinManager.shared.balance)
        HealthKitManager.shared.fetchSteps()
        loadData()
    }

    // MARK: - Layout Setup
    func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        setupHeaderSection()
        
        // Level Card
        contentStack.addArrangedSubview(levelCard)
        levelCard.translatesAutoresizingMaskIntoConstraints = false
        levelCard.heightAnchor.constraint(equalToConstant: 100).isActive = true
        contentStack.setCustomSpacing(20, after: levelCard)
        
        setupBodySection()
        setupAppSection()
    }

    private func setupHeaderSection() {
        headerContainer.addSubview(avatarButton)
        headerContainer.addSubview(nameLabel)
        headerContainer.addSubview(subtitleLabel)

        avatarButton.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerContainer.heightAnchor.constraint(equalToConstant: 110),

            avatarButton.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            avatarButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            avatarButton.widthAnchor.constraint(equalToConstant: 80),
            avatarButton.heightAnchor.constraint(equalToConstant: 80),

            nameLabel.topAnchor.constraint(equalTo: avatarButton.topAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: avatarButton.trailingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16)
        ])

        contentStack.addArrangedSubview(headerContainer)
    }

    private func setupBodySection() {
        let titleText = NSLocalizedString("body_stats", value: "Body Stats", comment: "")
        contentStack.addArrangedSubview(sectionTitle(titleText))

        // Row 1: Age & Height
        let row1 = UIStackView(arrangedSubviews: [ageButton, heightButton])
        row1.axis = .horizontal; row1.spacing = 12; row1.distribution = .fillEqually

        // Row 2: Weight & Goal
        let row2 = UIStackView(arrangedSubviews: [weightButton, goalButton])
        row2.axis = .horizontal; row2.spacing = 12; row2.distribution = .fillEqually

        contentStack.addArrangedSubview(row1)
        contentStack.addArrangedSubview(row2)

        // Gender Segment
        let genderContainer = UIView()
        genderContainer.backgroundColor = .secondarySystemBackground
        genderContainer.layer.cornerRadius = 16
        genderContainer.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let gTitle = UILabel()
        gTitle.text = NSLocalizedString("gender", value: "Gender", comment: "")
        gTitle.font = .systemFont(ofSize: 15, weight: .bold)

        let hStack = UIStackView(arrangedSubviews: [gTitle, UIView(), genderSegment])
        hStack.axis = .horizontal
        genderContainer.addSubview(hStack)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: genderContainer.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: genderContainer.trailingAnchor, constant: -16),
            hStack.centerYAnchor.constraint(equalTo: genderContainer.centerYAnchor)
        ])

        contentStack.addArrangedSubview(genderContainer)
        contentStack.setCustomSpacing(30, after: genderContainer)
    }

    private func setupAppSection() {
        let appTitle = NSLocalizedString("app_section", value: "Application", comment: "")
        contentStack.addArrangedSubview(sectionTitle(appTitle))

        // 1. Bio-Digital Kernel
        let kernelSub = NSLocalizedString("focus_protection", value: "Focus Protection", comment: "")
        let kernel = createSettingRow(icon: "brain.head.profile", title: "Bio-Digital Kernel", sub: kernelSub)
        kernel.addTarget(self, action: #selector(openBioKernelTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(kernel)
        
        contentStack.setCustomSpacing(20, after: kernel)

        // 2. Currency Card
        contentStack.addArrangedSubview(currencyCard)
        currencyCard.translatesAutoresizingMaskIntoConstraints = false
        currencyCard.heightAnchor.constraint(equalToConstant: 100).isActive = true
        
        contentStack.setCustomSpacing(25, after: currencyCard)

        // 3. Settings
        let settingsTitle = NSLocalizedString("settings", value: "Settings", comment: "")
        let settingsSub = NSLocalizedString("notif_lang", value: "Notifications & Language", comment: "")
        let settings = createSettingRow(icon: "gearshape.fill", title: settingsTitle, sub: settingsSub)
        settings.addTarget(self, action: #selector(openAppSettings), for: .touchUpInside)
        contentStack.addArrangedSubview(settings)

        // 4. Support
        let supportTitle = NSLocalizedString("support", value: "Support", comment: "")
        let supportSub = NSLocalizedString("contact_us", value: "Contact Us", comment: "")
        let support = createSettingRow(icon: "message.fill", title: supportTitle, sub: supportSub)
        support.addTarget(self, action: #selector(contactSupport), for: .touchUpInside)
        contentStack.addArrangedSubview(support)
    }

    // MARK: - Logic & Data Loading
    func loadData() {
        let defaultName = NSLocalizedString("default_name", value: "Captain", comment: "")
        nameLabel.text = profile.name.isEmpty ? defaultName : profile.name

        let age = profile.age
        let yearsText = NSLocalizedString("years", value: "years", comment: "")
        updateMetricCard(ageButton, text: age > 0 ? "\(age) \(yearsText)" : "--")

        let height = profile.heightCm
        let cmText = NSLocalizedString("cm", value: "cm", comment: "")
        updateMetricCard(heightButton, text: height > 0 ? "\(Int(height)) \(cmText)" : "--")

        let weight = profile.weightKg
        let kgText = NSLocalizedString("kg", value: "kg", comment: "")
        updateMetricCard(weightButton, text: weight > 0 ? "\(Int(weight)) \(kgText)" : "--")

        // الهدف اليومي
        let goalText = profile.goalText.isEmpty ? "--" : profile.goalText
        updateMetricCard(goalButton, text: goalText)

        genderSegment.selectedSegmentIndex = (NotificationPreferencesStore.shared.gender == .male ? 0 : 1)
    }

    private func setupActions() {
        avatarButton.addTarget(self, action: #selector(didTapAvatar), for: .touchUpInside)
        genderSegment.addTarget(self, action: #selector(genderChanged), for: .valueChanged)

        let levelTap = UITapGestureRecognizer(target: self, action: #selector(levelCardTapped))
        levelCard.isUserInteractionEnabled = true
        levelCard.addGestureRecognizer(levelTap)
        
        currencyCard.addTarget(self, action: #selector(currencyCardTapped), for: .touchUpInside)

        // ربط الأزرار بدوال التعديل
        ageButton.addTarget(self, action: #selector(editAge), for: .touchUpInside)
        heightButton.addTarget(self, action: #selector(editHeight), for: .touchUpInside)
        weightButton.addTarget(self, action: #selector(editWeight), for: .touchUpInside)
        goalButton.addTarget(self, action: #selector(editGoal), for: .touchUpInside)
        
        // تعديل الاسم عند الضغط
        let nameTap = UITapGestureRecognizer(target: self, action: #selector(editName))
        nameLabel.isUserInteractionEnabled = true
        nameLabel.addGestureRecognizer(nameTap)
    }

    // MARK: - Actions Implementation (All Fixed ✅)

    // Helper Alert Function
    func showEditAlert(title: String, message: String, placeholder: String, initialValue: String?, keyboardType: UIKeyboardType = .numberPad, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = placeholder
            textField.text = initialValue
            textField.keyboardType = keyboardType
            textField.textAlignment = .center
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                completion(text)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(cancelAction)
        alert.addAction(saveAction)
        
        present(alert, animated: true)
    }

    @objc func editName() {
        showEditAlert(title: "Change Name", message: "Enter your nickname", placeholder: "Name", initialValue: profile.name, keyboardType: .default) { [weak self] newName in
            guard let self = self else { return }
            var current = self.profile
            current.name = newName
            self.profile = current
        }
    }

    @objc func editAge() {
        let currentAge = profile.age > 0 ? "\(profile.age)" : ""
        showEditAlert(title: "Update Age", message: "How old are you?", placeholder: "Years", initialValue: currentAge) { [weak self] value in
            guard let self = self, let intValue = Int(value) else { return }
            var current = self.profile
            current.age = intValue
            self.profile = current
        }
    }

    @objc func editHeight() {
        let currentHeight = profile.heightCm > 0 ? "\(Int(profile.heightCm))" : ""
        showEditAlert(title: "Update Height", message: "Enter height in cm", placeholder: "CM", initialValue: currentHeight) { [weak self] value in
            // ✅ تم التحويل إلى Int
            guard let self = self, let doubleValue = Double(value) else { return }
            var current = self.profile
            current.heightCm = Int(doubleValue)
            self.profile = current
        }
    }

    @objc func editWeight() {
        let currentWeight = profile.weightKg > 0 ? "\(Int(profile.weightKg))" : ""
        showEditAlert(title: "Update Weight", message: "Enter weight in kg", placeholder: "KG", initialValue: currentWeight) { [weak self] value in
            // ✅ تم التحويل إلى Int
            guard let self = self, let doubleValue = Double(value) else { return }
            var current = self.profile
            current.weightKg = Int(doubleValue)
            self.profile = current
        }
    }
    
    // ✅ تمت إضافة دالة الهدف
    @objc func editGoal() {
        let currentGoal = profile.goalText
        showEditAlert(title: "Daily Goal", message: "Enter calorie burn goal", placeholder: "e.g. 500 kcal", initialValue: currentGoal, keyboardType: .default) { [weak self] value in
            guard let self = self else { return }
            var current = self.profile
            current.goalText = value
            self.profile = current
        }
    }

    @objc func levelCardTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let alert = UIAlertController(title: "Level Info", message: "Keep pushing!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc func currencyCardTapped() {
        let alert = UIAlertController(
            title: "AiQo Wallet",
            message: "This is your mining balance. Keep moving to earn more!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc func genderChanged(_ sender: UISegmentedControl) {
        NotificationPreferencesStore.shared.gender = (sender.selectedSegmentIndex == 0) ? .male : .female
    }

    @objc func refreshLevel() {
        // levelCard.reloadFromStorage() if available
    }

    @objc func openBioKernelTapped() {
        let rootView = ContentView().environmentObject(ProtectionModel.shared)
        let hostingController = UIHostingController(rootView: rootView)
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(hostingController, animated: true)
    }

    @objc func openAppSettings() {
        let vc = AppSettingsViewController()
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    @objc func contactSupport() {
        let alert = UIAlertController(title: "Support", message: "Coming Soon", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // Avatar Logic
    @objc func didTapAvatar() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        results.first?.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] img, _ in
            if let image = img as? UIImage {
                DispatchQueue.main.async {
                    self?.avatarButton.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
                    self?.saveAvatarLocally(image)
                }
            }
        }
    }

    private var localAvatarURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("user_avatar_local.jpg")
    }

    func saveAvatarLocally(_ image: UIImage) {
        guard let url = localAvatarURL else { return }
        try? image.jpegData(compressionQuality: 0.8)?.write(to: url)
    }

    func loadAvatarFromDisk() {
        if let url = localAvatarURL, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            avatarButton.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
        }
    }

    // MARK: - Helper Views
    private func sectionTitle(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .secondaryLabel
        l.textAlignment = .natural
        return l
    }

    private func updateMetricCard(_ card: AliveControl, text: String) {
        if let label = card.subviews.compactMap({ $0 as? UILabel }).first(where: { $0.tag == 101 }) {
            label.text = text
        }
    }

    private func createMetricCard(icon: String, title: String) -> AliveControl {
        let card = AliveControl()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous
        card.heightAnchor.constraint(equalToConstant: 55).isActive = true
        
        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = .label
        img.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.tag = 101
        
        let stack = UIStackView(arrangedSubviews: [img, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -8),
            img.widthAnchor.constraint(equalToConstant: 20),
            img.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return card
    }

    private func createSettingRow(icon: String, title: String, sub: String) -> AliveControl {
        let row = AliveControl()
        row.backgroundColor = .secondarySystemBackground
        row.layer.cornerRadius = 20
        row.layer.cornerCurve = .continuous
        row.heightAnchor.constraint(equalToConstant: 70).isActive = true

        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = .label
        img.contentMode = .scaleAspectFit

        let tLabel = UILabel()
        tLabel.text = title
        tLabel.font = .systemFont(ofSize: 16, weight: .bold)

        let sLabel = UILabel()
        sLabel.text = sub
        sLabel.font = .systemFont(ofSize: 12, weight: .medium)
        sLabel.textColor = .secondaryLabel

        let vStack = UIStackView(arrangedSubviews: [tLabel, sLabel])
        vStack.axis = .vertical
        vStack.spacing = 2
        vStack.alignment = .leading
        vStack.isUserInteractionEnabled = false

        let arrow = UIImageView(image: UIImage(systemName: "chevron.forward"))
        arrow.tintColor = .tertiaryLabel
        arrow.contentMode = .scaleAspectFit

        let hStack = UIStackView(arrangedSubviews: [img, vStack, UIView(), arrow])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 16
        hStack.isUserInteractionEnabled = false

        row.addSubview(hStack)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            hStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            hStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            img.widthAnchor.constraint(equalToConstant: 24),
            img.heightAnchor.constraint(equalToConstant: 24),
            arrow.widthAnchor.constraint(equalToConstant: 12),
            arrow.heightAnchor.constraint(equalToConstant: 20)
        ])
        return row
    }
}

// MARK: - Currency Card View
class CurrencyCardView: AliveControl {
    
    private let gradientLayer = CAGradientLayer()
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "AiQo Balance"
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = UIColor.black.withAlphaComponent(0.7)
        return l
    }()
    
    private let balanceLabel: UILabel = {
        let l = UILabel()
        l.text = "0"
        l.font = .systemFont(ofSize: 32, weight: .heavy)
        l.textColor = .black
        return l
    }()
    
    private let coinIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "currency") ?? UIImage(systemName: "bitcoinsign.circle.fill")
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .black
        iv.layer.shadowColor = UIColor.black.cgColor
        iv.layer.shadowOpacity = 0.2
        iv.layer.shadowOffset = CGSize(width: 0, height: 4)
        iv.layer.shadowRadius = 4
        return iv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor,
            UIColor(red: 1.0, green: 0.95, blue: 0.6, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 24
        gradientLayer.cornerCurve = .continuous
        layer.insertSublayer(gradientLayer, at: 0)
        
        layer.shadowColor = UIColor.orange.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowRadius = 10
        
        addSubview(titleLabel)
        addSubview(balanceLabel)
        addSubview(coinIcon)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        coinIcon.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            coinIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            coinIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            coinIcon.widthAnchor.constraint(equalToConstant: 65),
            coinIcon.heightAnchor.constraint(equalToConstant: 65),
            
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            
            balanceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            balanceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
    
    func updateBalance(amount: Int) {
        balanceLabel.text = "\(amount)"
    }
}
