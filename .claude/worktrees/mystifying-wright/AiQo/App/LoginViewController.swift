import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase
import Auth
import Combine

struct LoginScreenView: View {
    @StateObject private var viewModel = LoginScreenViewModel()
    @State private var appeared = false

    var body: some View {
        ZStack {
            AuthFlowBackground()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AuthFlowTheme.mint)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                    Text("AiQo")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                }
                .padding(.bottom, 40)

                // Card
                AuthFlowCard {
                    VStack(spacing: 20) {
                        Text(localized("login.welcome.title", fallback: "أهلاً بيك في AiQo"))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text(localized(
                            "login.welcome.subtitle",
                            fallback: "أنشئ حسابك حتى نحفظ تقدمك الصحي ونزامن بياناتك بأمان."
                        ))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                        Text(localized("login.apple.hint", fallback: "التسجيل يتم فقط باستخدام Apple"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AuthFlowTheme.mint)

                        SignInWithAppleButton(.signUp) { request in
                            viewModel.prepareAppleSignInRequest(request)
                        } onCompletion: { result in
                            viewModel.handleAppleAuthorizationResult(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .cornerRadius(16)
                        .disabled(viewModel.isLoading)
                        .opacity(viewModel.isLoading ? 0.55 : 1.0)

                        if viewModel.isLoading {
                            ProgressView()
                                .tint(AuthFlowTheme.mint)
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .scaleEffect(appeared ? 1 : 0.96)

                Spacer()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            viewModel.onLoginSuccess = {
                AppFlowController.shared.didLoginSuccessfully()
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private func localized(_ key: String, fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }
}

final class LoginScreenViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentNonce: String?
    var onLoginSuccess: (() -> Void)?

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        isLoading = true
        errorMessage = nil
    }

    func handleAppleAuthorizationResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            handleSuccessfulAuthorization(authorization)
        case .failure(let error):
            handleAuthorizationError(error)
        }
    }

    private func handleSuccessfulAuthorization(_ authorization: ASAuthorization) {
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

    private func handleAuthorizationError(_ error: Error) {
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
