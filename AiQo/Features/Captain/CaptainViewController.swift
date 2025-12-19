import UIKit

// MARK: - CaptainViewController
@MainActor
final class CaptainViewController: BaseViewController {

    // MARK: - Services
    private let coach = AiQoCoachService.shared

    // MARK: - UI
    private let header = LargeTitleHeaderView(
        title: NSLocalizedString("screen.captain.title", comment: "Captain screen title")
    )
    private let scroll = UIScrollView()
    private let content = UIStackView()

    // Chat
    private let chatHost = UIVisualEffectView()
    private let chatStack = UIStackView()

    // Avatar
    private let avatarView = UIImageView(image: UIImage(named: "Hammoudi5"))
    private var avatarHeight: NSLayoutConstraint!

    // Composer
    private let composerShadowHost = UIView()
    private let composerGlass = UIVisualEffectView()
    private let textView = UITextView()
    private let placeholder = UILabel()
    private let sendButton = UIButton(type: .system)

    // State
    private var composerBottom: NSLayoutConstraint!
    private var textHeight: NSLayoutConstraint!
    private let maxComposerLines: CGFloat = 4
    private var didShrinkAvatar = false
    private let bgGradient = CAGradientLayer()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupHeaderAndScroll()
        setupChat()
        setupAvatar()
        setupComposer()
        setupKeyboardObservers()

        // أول رسالة من الكابتن (مترجمة)
        let firstMessage = NSLocalizedString("captain.firstMessage",
                                             comment: "First captain message")
        addMessage(firstMessage, isUser: false, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bgGradient.frame = view.bounds
    }

    @MainActor
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Background Gradient
    private func setupBackground() {
        view.backgroundColor = Colors.bg
        bgGradient.colors = [
            Colors.mint.withAlphaComponent(0.12).cgColor,
            Colors.background.withAlphaComponent(0.0).cgColor
        ]
        bgGradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        bgGradient.endPoint = CGPoint(x: 0.5, y: 0.35)
        view.layer.insertSublayer(bgGradient, at: 0)
    }

    // MARK: - Header + Scroll
    // في CaptainViewController
    private func setupHeaderAndScroll() {
        // 1. إعداد الهيدر
        header.translatesAutoresizingMaskIntoConstraints = false
        // ✅ خط العنوان: سمين + مدوّر
        header.titleLabel.font = .aiqoRounded(size: 32, weight: .heavy)

        view.addSubview(header)
        
        NSLayoutConstraint.activate([
            // التعديل هنا: غيرنا 0 إلى -42 لتطابق شاشة Home وبقية الشاشات
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -42),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            header.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        header.profileButton.addTarget(self, action: #selector(openProfile), for: .touchUpInside)
        
        // 2. إعداد السكرول
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 0),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 3. إعداد المحتوى الداخلي
        content.axis = .vertical
        content.spacing = 10
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Chat area
    private func setupChat() {
        if #available(iOS 18.0, *) {
            chatHost.effect = UIGlassEffect()
        } else {
            chatHost.effect = UIBlurEffect(style: .systemThinMaterial)
        }
        chatHost.layer.cornerRadius = 22
        chatHost.layer.masksToBounds = true
        chatHost.backgroundColor = Colors.card.withAlphaComponent(0.9)
        chatHost.layer.borderColor = UIColor.black.withAlphaComponent(0.06).cgColor
        chatHost.layer.borderWidth = 0.4
        chatHost.translatesAutoresizingMaskIntoConstraints = false

        chatStack.axis = .vertical
        chatStack.spacing = 10
        chatStack.translatesAutoresizingMaskIntoConstraints = false

        chatHost.contentView.addSubview(chatStack)
        NSLayoutConstraint.activate([
            chatStack.topAnchor.constraint(equalTo: chatHost.contentView.topAnchor, constant: 10),
            chatStack.leadingAnchor.constraint(equalTo: chatHost.contentView.leadingAnchor, constant: 10),
            chatStack.trailingAnchor.constraint(equalTo: chatHost.contentView.trailingAnchor, constant: -10),
            chatStack.bottomAnchor.constraint(equalTo: chatHost.contentView.bottomAnchor, constant: -10)
        ])

        content.addArrangedSubview(chatHost)
    }

    // MARK: - Add Message
    private func addMessage(_ text: String, isUser: Bool, animated: Bool) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let bubble = UIVisualEffectView()
        if #available(iOS 18.0, *) {
            bubble.effect = UIGlassEffect()
        } else {
            bubble.effect = UIBlurEffect(style: .systemThinMaterial)
        }
        bubble.layer.cornerRadius = 20
        bubble.layer.masksToBounds = true
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.backgroundColor = isUser
            ? Colors.mint.withAlphaComponent(0.95)
            : Colors.sand.withAlphaComponent(0.95)

        let label = UILabel()
        label.numberOfLines = 0
        // ✅ خط الرسائل: متوسط، مدوّر
        label.font = .aiqoRounded(size: 16, weight: .medium)
        label.textColor = Colors.text
        label.translatesAutoresizingMaskIntoConstraints = false

        bubble.contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: bubble.contentView.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: bubble.contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: bubble.contentView.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: bubble.contentView.bottomAnchor, constant: -10)
        ])

        container.addSubview(bubble)

        let maxWidth = bubble.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, multiplier: 0.82)
        maxWidth.isActive = true

        if isUser {
            NSLayoutConstraint.activate([
                bubble.topAnchor.constraint(equalTo: container.topAnchor),
                bubble.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                bubble.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                bubble.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 40)
            ])
        } else {
            NSLayoutConstraint.activate([
                bubble.topAnchor.constraint(equalTo: container.topAnchor),
                bubble.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                bubble.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                bubble.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -40)
            ])
        }

        chatStack.addArrangedSubview(container)
        view.layoutIfNeeded()

        if animated && !isUser {
            // typing effect
            label.text = ""
            let chars = Array(text)
            var index = 0
            Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                if index >= chars.count {
                    timer.invalidate()
                    Task { @MainActor in
                        label.text = text
                        self.scrollToBottom(animated: true)
                    }
                    return
                }
                Task { @MainActor in
                    label.text?.append(chars[index])
                    index += 1
                    self.scrollToBottom(animated: true)
                }
            }
        } else {
            label.text = text
            scrollToBottom(animated: true)
        }
    }

    // MARK: - Scrolling
    private func scrollToBottom(animated: Bool = true) {
        view.layoutIfNeeded()
        let height = scroll.contentSize.height - scroll.bounds.height + scroll.contentInset.bottom
        guard height > 0 else { return }
        scroll.setContentOffset(CGPoint(x: 0, y: height), animated: animated)
    }

    // MARK: - Avatar
    private func setupAvatar() {
        avatarView.contentMode = .scaleAspectFit
        avatarView.isUserInteractionEnabled = false
        avatarView.layer.shadowColor = UIColor.black.cgColor
        avatarView.layer.shadowOpacity = 0.10
        avatarView.layer.shadowRadius = 16
        avatarView.layer.shadowOffset = .init(width: 0, height: 8)

        content.addArrangedSubview(avatarView)

        avatarHeight = avatarView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.44)
        avatarHeight.isActive = true
    }

    // MARK: - Composer
    private func setupComposer() {
        composerShadowHost.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(composerShadowHost)

        composerShadowHost.layer.shadowColor = UIColor.black.cgColor
        composerShadowHost.layer.shadowOpacity = 0.14
        composerShadowHost.layer.shadowRadius = 18
        composerShadowHost.layer.shadowOffset = CGSize(width: 0, height: 10)

        if #available(iOS 18.0, *) {
            composerGlass.effect = UIGlassEffect()
        } else {
            composerGlass.effect = UIBlurEffect(style: .systemMaterial)
        }
        composerGlass.layer.cornerRadius = 24
        composerGlass.layer.masksToBounds = true
        composerGlass.backgroundColor = Colors.card.withAlphaComponent(0.9)
        composerGlass.layer.borderColor = UIColor.black.withAlphaComponent(0.06).cgColor
        composerGlass.layer.borderWidth = 0.5
        composerGlass.translatesAutoresizingMaskIntoConstraints = false

        composerShadowHost.addSubview(composerGlass)

        composerBottom = composerShadowHost.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                                     constant: -12)
        composerBottom.isActive = true

        NSLayoutConstraint.activate([
            composerShadowHost.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            composerShadowHost.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            composerGlass.leadingAnchor.constraint(equalTo: composerShadowHost.leadingAnchor),
            composerGlass.trailingAnchor.constraint(equalTo: composerShadowHost.trailingAnchor),
            composerGlass.topAnchor.constraint(equalTo: composerShadowHost.topAnchor),
            composerGlass.bottomAnchor.constraint(equalTo: composerShadowHost.bottomAnchor)
        ])

        textView.backgroundColor = .clear
        textView.textColor = Colors.text
        // ✅ خط الإنبت: مدوّر، متوسط
        textView.font = .aiqoRounded(size: 17, weight: .medium)
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 52)
        textView.delegate = self
        textView.translatesAutoresizingMaskIntoConstraints = false

        placeholder.text = NSLocalizedString("captain.placeholder", comment: "Captain input placeholder")
        placeholder.textColor = Colors.subtext
        // ✅ خط الـ placeholder مدوّر أخف
        placeholder.font = .aiqoRounded(size: 17, weight: .regular)
        placeholder.translatesAutoresizingMaskIntoConstraints = false

        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.tintColor = Colors.accent
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.isEnabled = false
        sendButton.alpha = 0.4

        composerGlass.contentView.addSubview(textView)
        composerGlass.contentView.addSubview(placeholder)
        composerGlass.contentView.addSubview(sendButton)

        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: composerGlass.contentView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: composerGlass.contentView.trailingAnchor),
            textView.topAnchor.constraint(equalTo: composerGlass.contentView.topAnchor),
            textView.bottomAnchor.constraint(equalTo: composerGlass.contentView.bottomAnchor),

            placeholder.leadingAnchor.constraint(equalTo: composerGlass.contentView.leadingAnchor, constant: 18),
            placeholder.centerYAnchor.constraint(equalTo: composerGlass.contentView.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: composerGlass.contentView.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: composerGlass.contentView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            sendButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        textHeight = composerGlass.heightAnchor.constraint(equalToConstant: 56)
        textHeight.isActive = true

        let panToDismiss = UIPanGestureRecognizer(target: self, action: #selector(handleComposerPan(_:)))
        panToDismiss.cancelsTouchesInView = false
        composerGlass.addGestureRecognizer(panToDismiss)
    }

    // MARK: - Keyboard
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(kbChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(kbHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }

    @objc private func kbChange(_ n: Notification) {
        guard let info = n.userInfo,
              let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let dur = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }

        let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)
        let kbHeight = max(0, view.bounds.height - frame.origin.y)

        composerBottom.constant = -(kbHeight + 12 - view.safeAreaInsets.bottom)

        UIView.animate(withDuration: dur,
                       delay: 0,
                       options: [curve, .allowUserInteraction]) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func kbHide(_ n: Notification) {
        let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.25
        composerBottom.constant = -12
        UIView.animate(withDuration: dur) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Actions
    @objc private func didTapSend() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        addMessage(text, isUser: true, animated: false)
        textView.text = ""
        textViewDidChange(textView)

        setSendingState(true)
        shrinkAvatarIfNeeded()

        Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await coach.sendToCoach(message: text)
                addMessage(reply, isUser: false, animated: true)
                setSendingState(false)
            } catch {
                print("Coach API error:", error)
                let errorText = NSLocalizedString("captain.errorMessage",
                                                  comment: "Error message when coach fails")
                addMessage(errorText, isUser: false, animated: false)
                setSendingState(false)
            }
        }
    }

    // MARK: - Profile Sheet (NewProfileViewController)
    @objc private func openProfile() {
        let profileVC = NewProfileViewController()
        presentAsSheet(profileVC, detents: [.large()])
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

    @objc private func handleComposerPan(_ g: UIPanGestureRecognizer) {
        let trans = g.translation(in: composerGlass)
        let vel = g.velocity(in: composerGlass)
        if g.state == .changed || g.state == .ended {
            if trans.y > 12 || vel.y > 250 {
                view.endEditing(true)
            }
        }
    }

    // MARK: - Shrink Avatar
    private func shrinkAvatarIfNeeded() {
        guard !didShrinkAvatar else { return }
        didShrinkAvatar = true

        avatarHeight.isActive = false
        avatarHeight = avatarView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.30)
        avatarHeight.isActive = true

        UIView.animate(withDuration: 0.45,
                       delay: 0,
                       usingSpringWithDamping: 0.88,
                       initialSpringVelocity: 0.6,
                       options: [.curveEaseInOut, .allowUserInteraction]) {
            self.avatarView.alpha = 0.95
            self.view.layoutIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.scrollToBottom(animated: true)
        }
    }

    // MARK: - Sending State
    private func setSendingState(_ sending: Bool) {
        sendButton.isEnabled = !sending
        sendButton.alpha = sending ? 0.4 : 1.0

        if sending {
            let anim = CABasicAnimation(keyPath: "transform.rotation")
            anim.toValue = Double.pi * 2
            anim.duration = 1.0
            anim.repeatCount = .infinity
            sendButton.layer.add(anim, forKey: "spin")
        } else {
            sendButton.layer.removeAnimation(forKey: "spin")
        }
    }
}

// MARK: - UITextViewDelegate
extension CaptainViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = !textView.text.isEmpty
        let enabled = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.isEnabled = enabled
        sendButton.alpha = enabled ? 1 : 0.4

        let fitting = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
        let size = textView.sizeThatFits(fitting)
        let line = textView.font?.lineHeight ?? 20
        let maxH = 20 + (line * maxComposerLines) + 20

        textHeight.constant = min(max(56, size.height), maxH)
        textView.isScrollEnabled = size.height > maxH
    }
}
