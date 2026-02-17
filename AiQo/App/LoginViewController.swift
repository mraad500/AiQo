import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase
import Auth
internal import Combine

struct LoginScreenView: View {
    @StateObject private var viewModel = LoginScreenViewModel()

    private var layoutDirection: LayoutDirection {
        AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        ZStack {
            AuthFlowBackground()

            VStack(spacing: 22) {
                AuthFlowBrandHeader(
                    subtitle: localized("login.brand.subtitle", fallback: "World Class Wellness System")
                )

                AuthFlowCard {
                    VStack(spacing: 18) {
                        Text(localized("login.welcome.title", fallback: "أهلًا بيك في AiQo"))
                            .font(.aiqoDisplay(33))
                            .foregroundStyle(AuthFlowTheme.text)
                            .multilineTextAlignment(.center)

                        Text(localized(
                            "login.welcome.subtitle",
                            fallback: "أنشئ حسابك حتى نحفظ تقدمك الصحي ونزامن بياناتك بأمان."
                        ))
                        .font(.aiqoBody(16))
                        .foregroundStyle(AuthFlowTheme.subtext)
                        .multilineTextAlignment(.center)

                        VStack(spacing: 13) {
                            Text(localized("login.apple.hint", fallback: "التسجيل يتم فقط باستخدام Apple"))
                                .font(.aiqoLabel(13))
                                .tracking(0.6)
                                .foregroundStyle(AuthFlowTheme.subtext)

                            AppleSignInUIKitButton(
                                isLoading: viewModel.isLoading,
                                action: { viewModel.startAppleSignIn() }
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 6)

                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(AuthFlowTheme.mint)
                            }

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.aiqoBody(13))
                                    .foregroundStyle(Color.red.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .environment(\.layoutDirection, layoutDirection)
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.onLoginSuccess = {
                UIApplication.activeSceneDelegate()?.didLoginSuccessfully()
            }
        }
    }

    private func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}

final class LoginScreenViewModel: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentNonce: String?
    var onLoginSuccess: (() -> Void)?

    func startAppleSignIn() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        isLoading = true
        errorMessage = nil
        controller.performRequests()
    }
}

extension LoginScreenViewModel: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        if let keyWindow = windowScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return keyWindow
        }

        guard let windowScene = windowScenes.first else {
            preconditionFailure("No active UIWindowScene for Apple Sign-In presentation anchor.")
        }
        return UIWindow(windowScene: windowScene)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let identityToken = credential.identityToken,
              let idToken = String(data: identityToken, encoding: .utf8) else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = NSLocalizedString(
                    "login.error.invalidAppleToken",
                    value: "تعذر قراءة بيانات تسجيل الدخول من Apple.",
                    comment: ""
                )
            }
            return
        }

        Task {
            do {
                _ = try await SupabaseService.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )

                await MainActor.run {
                    self.isLoading = false
                    self.onLoginSuccess?()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = NSLocalizedString(
                        "login.error.supabase",
                        value: "فشل تسجيل الدخول. حاول مرة ثانية.",
                        comment: ""
                    )
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                self.errorMessage = nil
            } else {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct AppleSignInUIKitButton: UIViewRepresentable {
    let isLoading: Bool
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.cornerRadius = 16
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        uiView.isEnabled = !isLoading
        uiView.alpha = isLoading ? 0.55 : 1.0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        private let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func didTap() {
            action()
        }
    }
}


private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)

    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    if errorCode != errSecSuccess {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    return String(randomBytes.map { charset[Int($0) % charset.count] })
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.map { String(format: "%02x", $0) }.joined()
}
