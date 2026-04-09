import SwiftUI
import AuthenticationServices
import CryptoKit
import Supabase
import Auth
import Combine
import os.log

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
                    VStack(spacing: 16) {
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

                        SignInWithAppleButton(.continue) { request in
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

                        // ── Divider ──
                        HStack(spacing: 12) {
                            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
                            Text(localized("login.or", fallback: "أو"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
                        }

                        // ── Guest button — prominent ──
                        Button(action: viewModel.continueWithoutAccount) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(localized("login.guest.cta", fallback: "المتابعة بدون حساب"))
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Color(hex: "0E3A2B"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AuthFlowTheme.mint.opacity(0.25))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(AuthFlowTheme.mint.opacity(0.5), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoading)
                        .opacity(viewModel.isLoading ? 0.55 : 1.0)

                        Text(localized(
                            "login.guest.hint",
                            fallback: "تقدر تستخدم التطبيق الآن، وتربط حساب Apple لاحقاً إذا احتجت المزامنة."
                        ))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .scaleEffect(appeared ? 1 : 0.96)

                Spacer()
            }
        }
        .environment(\.layoutDirection, AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight)
        .onAppear {
            viewModel.onLoginSuccess = {
                AppFlowController.shared.didLoginSuccessfully()
            }
            viewModel.onContinueWithoutAccount = {
                AppFlowController.shared.didContinueWithoutAccount()
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
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "LoginScreenViewModel"
    )

    @Published var isLoading = false
    @Published var errorMessage: String?

    private var currentNonce: String?
    var onLoginSuccess: (() -> Void)?
    var onContinueWithoutAccount: (() -> Void)?

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

    func continueWithoutAccount() {
        errorMessage = nil
        isLoading = false
        onContinueWithoutAccount?()
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

        let profileMetadata = appleProfileMetadata(from: credential.fullName)

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await SupabaseService.shared.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )

                if !profileMetadata.isEmpty {
                    do {
                        _ = try await SupabaseService.shared.client.auth.update(
                            user: UserAttributes(data: profileMetadata)
                        )
                    } catch {
                        await MainActor.run {
                            CrashReportingService.shared.record(
                                error,
                                context: "apple_profile_metadata_update_failed"
                            )
                        }
                        Self.logger.error(
                            "apple_profile_metadata_update_failed message=\(error.localizedDescription, privacy: .public)"
                        )
                    }
                }

                await MainActor.run {
                    self.currentNonce = nil
                    self.isLoading = false
                    self.onLoginSuccess?()
                }
            } catch {
                let message = self.messageForLoginError(error)
                let errorCode = self.errorCodeDescription(for: error)

                await MainActor.run {
                    CrashReportingService.shared.record(error, context: "apple_supabase_sign_in_failed")
                    CrashReportingService.shared.log(
                        "apple_supabase_sign_in_failed code=\(errorCode) message=\(error.localizedDescription)"
                    )
                }
                Self.logger.error(
                    "apple_supabase_sign_in_failed code=\(errorCode, privacy: .public) message=\(error.localizedDescription, privacy: .public)"
                )

                await MainActor.run {
                    self.currentNonce = nil
                    self.isLoading = false
                    self.errorMessage = message
                }
            }
        }
    }

    private func handleAuthorizationError(_ error: Error) {
        DispatchQueue.main.async {
            self.currentNonce = nil
            self.isLoading = false
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                self.errorMessage = nil
            } else {
                self.errorMessage = NSLocalizedString(
                    "login.error.appleAuthorization",
                    value: "تعذر إكمال تسجيل Apple. حاول مرة ثانية.",
                    comment: ""
                )
            }
        }
    }

    private func appleProfileMetadata(from components: PersonNameComponents?) -> [String: AnyJSON] {
        guard let components else { return [:] }

        var metadata: [String: AnyJSON] = [:]
        let formatter = PersonNameComponentsFormatter()
        let fullName = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)

        if !fullName.isEmpty {
            metadata["full_name"] = .string(fullName)
        }

        if let givenName = trimmed(components.givenName) {
            metadata["given_name"] = .string(givenName)
        }

        if let familyName = trimmed(components.familyName) {
            metadata["family_name"] = .string(familyName)
        }

        return metadata
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func messageForLoginError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            switch authError.errorCode {
            case .unexpectedAudience:
                return NSLocalizedString(
                    "login.error.unexpectedAudience",
                    value: "تعذر ربط تسجيل Apple بالخدمة حالياً. تقدر تكمل بدون حساب مؤقتاً.",
                    comment: ""
                )
            case .requestTimeout, .hookTimeout, .hookTimeoutAfterRetry:
                return NSLocalizedString(
                    "login.error.timeout",
                    value: "صار تأخير بالاتصال. حاول مرة ثانية أو كمل بدون حساب مؤقتاً.",
                    comment: ""
                )
            case .providerDisabled:
                return NSLocalizedString(
                    "login.error.providerDisabled",
                    value: "تسجيل Apple غير متاح حالياً. تقدر تكمل بدون حساب مؤقتاً.",
                    comment: ""
                )
            default:
                break
            }
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return NSLocalizedString(
                "login.error.network",
                value: "ما قدرنا نوصل للخدمة. تأكد من الإنترنت أو كمل بدون حساب مؤقتاً.",
                comment: ""
            )
        }

        return NSLocalizedString(
            "login.error.supabase",
            value: "فشل تسجيل الدخول. حاول مرة ثانية أو كمل بدون حساب مؤقتاً.",
            comment: ""
        )
    }

    private func errorCodeDescription(for error: Error) -> String {
        guard let authError = error as? AuthError else {
            return "unknown"
        }

        return authError.errorCode.rawValue
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
