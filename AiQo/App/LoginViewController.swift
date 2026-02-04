import UIKit
import AuthenticationServices
import CryptoKit // 🔐 ضروري للتشفير
import Supabase

final class LoginViewController: BaseViewController {

    // MARK: - Theme & UI Components
    private let brandMint = Colors.mint
    private let brandBeige = Colors.aiqoBeige
    private let darkBG = UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1.0)
    private let darkText = UIColor.white
    private let darkSub = UIColor.white.withAlphaComponent(0.70)

    // متغير لتخزين شفرة الحماية المؤقتة
    fileprivate var currentNonce: String?

    // Background
    private let backgroundGradientLayer = CAGradientLayer()
    private let glowLayer = CALayer()
    
    // Brand Header
    private let brandRow = UIStackView()
    private let topTitle = UILabel()
    private let brandSpark = UIImageView(image: UIImage(systemName: "sparkles"))

    // Main Card
    private let cardView = BeigeGlassCardView()
    private let contentStack = UIStackView()

    // Texts
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // Buttons
    private let appleButton = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupBrandRow()
        setupCard()
        setupContent()
        startBrandSparkAnimation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
        glowLayer.frame = view.bounds
    }

    // MARK: - Background Setup
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
        
        glowLayer.addSublayer(makeRadialGlow(center: CGPoint(x: 0.2, y: 0.3), radius: 300, color: brandMint.withAlphaComponent(0.12)))
        glowLayer.addSublayer(makeRadialGlow(center: CGPoint(x: 0.8, y: 0.8), radius: 340, color: brandBeige.withAlphaComponent(0.12)))
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

    // MARK: - Brand Header
    private func setupBrandRow() {
        brandRow.translatesAutoresizingMaskIntoConstraints = false
        brandRow.axis = .horizontal
        brandRow.alignment = .center
        brandRow.spacing = 10
        brandRow.clipsToBounds = false
        brandRow.layer.masksToBounds = false
        brandRow.layer.zPosition = 100

        topTitle.translatesAutoresizingMaskIntoConstraints = false
        topTitle.text = "AiQo"
        topTitle.textColor = darkText
        topTitle.font = roundedFont(size: 40, weight: .black)

        brandSpark.translatesAutoresizingMaskIntoConstraints = false
        brandSpark.tintColor = brandMint.withAlphaComponent(0.98)
        brandSpark.preferredSymbolConfiguration = .init(pointSize: 18, weight: .bold)
        brandSpark.alpha = 0.98

        brandRow.addArrangedSubview(topTitle)
        brandRow.addArrangedSubview(brandSpark)
        view.addSubview(brandRow)

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
        brandSpark.layer.add(pulse, forKey: "pulse")
    }

    // MARK: - Card & Content
    private func setupCard() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.apply(beige: brandBeige, mint: brandMint)
        view.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])
    }

    private func setupContent() {
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.layoutMargins = UIEdgeInsets(top: 30, left: 20, bottom: 30, right: 20)
        contentStack.isLayoutMarginsRelativeArrangement = true

        cardView.contentView.addSubview(contentStack)
        
        titleLabel.text = "Welcome Back"
        titleLabel.font = roundedFont(size: 28, weight: .black)
        titleLabel.textColor = darkText
        titleLabel.textAlignment = .center
        
        subtitleLabel.text = "Sign in to sync your fitness level and keep your progress safe."
        subtitleLabel.font = roundedFont(size: 16, weight: .medium)
        subtitleLabel.textColor = darkSub
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        appleButton.cornerRadius = 18
        appleButton.translatesAutoresizingMaskIntoConstraints = false
        appleButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        appleButton.addTarget(self, action: #selector(handleAppleSignIn), for: .touchUpInside)
        
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = brandMint

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 10).isActive = true

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(spacer)
        contentStack.addArrangedSubview(appleButton)
        contentStack.addArrangedSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: cardView.contentView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: cardView.contentView.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: cardView.contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: cardView.contentView.trailingAnchor)
        ])
    }

    // MARK: - 🍎 Apple Sign In Logic (الحقيقي)

    @objc private func handleAppleSignIn() {
        startLoading(true)
        
        // 1. توليد Nonce عشوائي للحماية
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce) // تشفير الـ Nonce وإرساله لأبل

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    private func startLoading(_ isLoading: Bool) {
        appleButton.isEnabled = !isLoading
        appleButton.alpha = isLoading ? 0.5 : 1.0
        if isLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }
    
    // الانتقال بعد النجاح
    private func navigateToNextScreen() {
        if let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate {
            sceneDelegate.didLoginSuccessfully()
        }
    }

    // MARK: - Helpers
    private func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return base
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension LoginViewController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ Unable to retrieve Apple ID Credential")
            startLoading(false)
            return
        }

        // 1. استخراج التوكن والـ Nonce
        guard let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("❌ Error fetching token or nonce")
            startLoading(false)
            return
        }

        print("🍏 Got Apple ID Token: \(idTokenString.prefix(20))...")
        
        // 2. تسجيل الدخول في Supabase
        Task {
            do {
                _ = try await SupabaseService.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idTokenString, nonce: nonce)
                )
                
                print("✅ Supabase Sign In Successful!")
                
                await MainActor.run {
                    self.startLoading(false)
                    self.navigateToNextScreen()
                }
            } catch {
                print("❌ Supabase Auth Error: \(error)")
                await MainActor.run {
                    self.startLoading(false)
                    // يمكنك إظهار تنبيه خطأ للمستخدم هنا
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign In Error: \(error.localizedDescription)")
        startLoading(false)
    }
}

// MARK: - Crypto Helpers (مطلوب من أبل)
// هذه الدوال ضرورية لتشفير الـ Nonce
private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    if errorCode != errSecSuccess {
        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
    }
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    let nonce = randomBytes.map { charset[Int($0) % charset.count] }
    return String(nonce)
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
        return String(format: "%02x", $0)
    }.joined()
    return hashString
}
