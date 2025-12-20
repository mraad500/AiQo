import UIKit
import PhotosUI
import Supabase
import SwiftUI
import FamilyControls

// MARK: - NewProfileViewController (Main + UI + Logic Combined)
final class NewProfileViewController: UIViewController, PHPickerViewControllerDelegate, UIGestureRecognizerDelegate {

    // MARK: - UI Components
    let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // الهيدر
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
        l.font = .aiqoRounded(size: 24, weight: .black)
        l.textAlignment = .left
        return l
    }()

    let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .aiqoRounded(size: 14, weight: .medium)
        l.textColor = .secondaryLabel
        l.text = "Let's optimize your body & mind"
        l.textAlignment = .left
        return l
    }()

    // أزرار البيانات
    lazy var ageButton = createMetricButton(icon: "calendar", title: "--")
    lazy var heightButton = createMetricButton(icon: "ruler", title: "--")
    lazy var weightButton = createMetricButton(icon: "scalemass", title: "--")
    lazy var goalButton = createMetricButton(icon: "flame", title: "--")

    // كارت الليفل
    let levelCard = LevelCardView()

    // اختيار الجنس
    let genderSegment = UISegmentedControl(items: ["ذكر", "أنثى"])

    // MARK: - Data
    var profile: UserProfile {
        get { UserProfileStore.shared.current }
        set {
            UserProfileStore.shared.current = newValue
            loadData()
        }
    }

    var supabase: SupabaseClient { SupabaseService.shared.client }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupUI()
        setupActions()
        loadData()
        loadAvatarFromDisk()

        NotificationCenter.default.addObserver(self, selector: #selector(refreshLevel), name: .levelStoreDidChange, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        levelCard.reloadFromStorage()
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
        setupBodySection()
        setupLevelSection()
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
        contentStack.addArrangedSubview(sectionTitle("بيانات الجسم"))

        let row1 = UIStackView(arrangedSubviews: [ageButton, heightButton])
        row1.axis = .horizontal; row1.spacing = 12; row1.distribution = .fillEqually

        let row2 = UIStackView(arrangedSubviews: [weightButton, goalButton])
        row2.axis = .horizontal; row2.spacing = 12; row2.distribution = .fillEqually

        contentStack.addArrangedSubview(row1)
        contentStack.addArrangedSubview(row2)

        let genderContainer = UIView()
        genderContainer.backgroundColor = .secondarySystemBackground
        genderContainer.layer.cornerRadius = 16
        genderContainer.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let gTitle = UILabel()
        gTitle.text = "الجنس"
        gTitle.font = .aiqoRounded(size: 15, weight: .bold)

        let normalAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.aiqoRounded(size: 13, weight: .medium)]
        let selectedAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.aiqoRounded(size: 13, weight: .bold)]
        genderSegment.setTitleTextAttributes(normalAttrs, for: .normal)
        genderSegment.setTitleTextAttributes(selectedAttrs, for: .selected)

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
    }

    private func setupLevelSection() {
        contentStack.setCustomSpacing(24, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(levelCard)
        levelCard.translatesAutoresizingMaskIntoConstraints = false
        levelCard.heightAnchor.constraint(equalToConstant: 100).isActive = true
    }

    private func setupAppSection() {
        contentStack.setCustomSpacing(30, after: levelCard)
        contentStack.addArrangedSubview(sectionTitle("التطبيق"))

        let kernel = createSettingRow(icon: "brain.head.profile", title: "Bio-Digital Kernel", sub: "حماية التركيز")
        kernel.addTarget(self, action: #selector(openBioKernelTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(kernel)

        let settings = createSettingRow(icon: "gearshape.fill", title: "الإعدادات", sub: "التنبيهات واللغة")
        settings.addTarget(self, action: #selector(openAppSettings), for: .touchUpInside)
        contentStack.addArrangedSubview(settings)

        let support = createSettingRow(icon: "message.fill", title: "الدعم الفني", sub: "تواصل معنا")
        support.addTarget(self, action: #selector(contactSupport), for: .touchUpInside)
        contentStack.addArrangedSubview(support)
    }

    // MARK: - Logic & Data
    func loadData() {
        nameLabel.text = profile.name.isEmpty ? "كابتن حمودي" : profile.name

        let age = profile.age
        updateButton(ageButton, text: "\(age) years")

        let height = profile.heightCm
        updateButton(heightButton, text: "\(Int(height)) cm")

        let weight = profile.weightKg
        updateButton(weightButton, text: "\(Int(weight)) kg")

        let goal = profile.goalText.isEmpty ? "Stronger" : profile.goalText
        updateButton(goalButton, text: goal)

        genderSegment.selectedSegmentIndex = (NotificationPreferencesStore.shared.gender == .male ? 0 : 1)
    }

    private func setupActions() {
        avatarButton.addTarget(self, action: #selector(didTapAvatar), for: .touchUpInside)
        genderSegment.addTarget(self, action: #selector(genderChanged), for: .valueChanged)

        let levelTap = UITapGestureRecognizer(target: self, action: #selector(levelCardTapped))
        levelCard.isUserInteractionEnabled = true
        levelCard.addGestureRecognizer(levelTap)

        ageButton.addTarget(self, action: #selector(editAge), for: .touchUpInside)
        heightButton.addTarget(self, action: #selector(editHeight), for: .touchUpInside)
        weightButton.addTarget(self, action: #selector(editWeight), for: .touchUpInside)
    }

    // MARK: - Actions
    @objc func levelCardTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let alert = UIAlertController(
            title: "مستواك الحالي",
            message: "لديك \(LevelStore.shared.currentXP) نقطة خبرة.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "إضافة 50 نقطة (تجربة)", style: .default, handler: { _ in
            LevelStore.shared.addXP(amount: 50)
        }))
        alert.addAction(UIAlertAction(title: "إغلاق", style: .cancel))
        present(alert, animated: true)
    }

    @objc func genderChanged(_ sender: UISegmentedControl) {
        NotificationPreferencesStore.shared.gender = (sender.selectedSegmentIndex == 0) ? .male : .female
    }

    @objc func refreshLevel() {
        levelCard.reloadFromStorage()
    }

    @objc func editName() { /* افتح التعديل */ }
    @objc func editAge() { /* افتح التعديل */ }
    @objc func editHeight() { /* افتح التعديل */ }
    @objc func editWeight() { /* افتح التعديل */ }

    // ✅ المطلوب: تفتح PermissionView فقط
    @objc func openBioKernelTapped() {
        // 1. نستخدم ContentView لأن هي "البوابة" الذكية
        // 2. نستخدم .shared (المفتاح السحري) حتى نربط ويا نفس العقل مال النظام كله
        let rootView = ContentView()
            .environmentObject(ProtectionModel.shared)
        
        let hostingController = UIHostingController(rootView: rootView)
        
        // إعدادات الشيت (نص شاشة أو كاملة)
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
        let alert = UIAlertController(title: "الدعم", message: "تواصل معنا قريباً", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // Animations
    @objc func rowTouchDown(_ sender: UIControl) {
        UIView.animate(withDuration: 0.1) { sender.transform = CGAffineTransform(scaleX: 0.98, y: 0.98) }
    }

    @objc func rowTouchUp(_ sender: UIControl) {
        UIView.animate(withDuration: 0.1) { sender.transform = .identity }
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
            .first?
            .appendingPathComponent("user_avatar_local.jpg")
    }

    func saveAvatarLocally(_ image: UIImage) {
        guard let url = localAvatarURL else { return }
        try? image.jpegData(compressionQuality: 0.8)?.write(to: url)
    }

    func loadAvatarFromDisk() {
        if let url = localAvatarURL,
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            avatarButton.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
        }
    }

    // MARK: - Helper Views
    private func sectionTitle(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .aiqoRounded(size: 18, weight: .bold)
        l.textColor = .secondaryLabel
        return l
    }

    private func updateButton(_ btn: UIButton, text: String) {
        btn.configuration?.title = text
    }

    private func createMetricButton(icon: String, title: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .secondarySystemBackground
        config.baseForegroundColor = .label
        config.cornerStyle = .large
        config.image = UIImage(systemName: icon)
        config.imagePadding = 8
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .aiqoRounded(size: 15, weight: .bold)
            return outgoing
        }

        let btn = UIButton(configuration: config)
        btn.contentHorizontalAlignment = .leading
        btn.heightAnchor.constraint(equalToConstant: 55).isActive = true
        return btn
    }

    private func createSettingRow(icon: String, title: String, sub: String) -> UIControl {
        let row = UIControl()
        row.backgroundColor = .secondarySystemBackground
        row.layer.cornerRadius = 20
        row.heightAnchor.constraint(equalToConstant: 70).isActive = true

        row.addTarget(self, action: #selector(rowTouchDown), for: [.touchDown])
        row.addTarget(self, action: #selector(rowTouchUp), for: [.touchUpInside, .touchCancel])

        let img = UIImageView(image: UIImage(systemName: icon))
        img.tintColor = .label
        img.contentMode = .scaleAspectFit

        let tLabel = UILabel()
        tLabel.text = title
        tLabel.font = .aiqoRounded(size: 16, weight: .bold)

        let sLabel = UILabel()
        sLabel.text = sub
        sLabel.font = .aiqoRounded(size: 12, weight: .medium)
        sLabel.textColor = .secondaryLabel

        let vStack = UIStackView(arrangedSubviews: [tLabel, sLabel])
        vStack.axis = .vertical
        vStack.spacing = 2

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = .tertiaryLabel

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
            img.heightAnchor.constraint(equalToConstant: 24)
        ])

        return row
    }
}
