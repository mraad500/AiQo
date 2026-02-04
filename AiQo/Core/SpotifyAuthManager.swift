import Foundation
import AuthenticationServices
import CryptoKit

final class SpotifyAuthManager: NSObject {
    static let shared = SpotifyAuthManager()

    // ضع Client ID الحقيقي
    let clientID = "YOUR_CLIENT_ID"
    let redirectURI = "aiqo-spotify://callback"

    // Scopes حسب احتياجك
    // app-remote-control مهم للـ iOS SDK App Remote  [oai_citation:5‡developer.spotify.com](https://developer.spotify.com/documentation/web-api/concepts/scopes?utm_source=chatgpt.com)
    private let scopes = [
        "app-remote-control",
        "user-read-playback-state",
        "user-modify-playback-state"
    ]

    private var codeVerifier: String?
    private var session: ASWebAuthenticationSession?

    private(set) var accessToken: String? {
        didSet { onTokenChanged?(accessToken) }
    }

    var onTokenChanged: ((String?) -> Void)?

    func startLogin(presentationAnchor: ASPresentationAnchor) {
        let verifier = Self.randomString(length: 64)
        codeVerifier = verifier
        let challenge = Self.codeChallenge(for: verifier)

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "scope", value: scopes.joined(separator: " "))
        ]

        let authURL = comps.url!

        let webSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "aiqo-spotify") { [weak self] callbackURL, error in
            guard let self else { return }
            guard error == nil, let callbackURL else { return }

            let query = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
            let code = query?.first(where: { $0.name == "code" })?.value
            guard let code, let verifier = self.codeVerifier else { return }

            Task { await self.exchangeCodeForToken(code: code, verifier: verifier) }
        }

        webSession.presentationContextProvider = self
        webSession.prefersEphemeralWebBrowserSession = true
        webSession.start()
        self.session = webSession
    }

    private func exchangeCodeForToken(code: String, verifier: String) async {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id=\(clientID)",
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(redirectURI)",
            "code_verifier=\(verifier)"
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let token = json?["access_token"] as? String
            await MainActor.run { self.accessToken = token }
        } catch {
            // تعامل مع الخطأ
        }
    }

    var isLoggedIn: Bool { accessToken != nil }

    // PKCE helpers
    private static func randomString(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hashed = SHA256.hash(data: data)
        return Data(hashed).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow ?? ASPresentationAnchor()
    }
}
