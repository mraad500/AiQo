import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

final class SpotifyAuthManager: NSObject {
    static let shared = SpotifyAuthManager()

    // ⚠️ استبدل هذا بـ Client ID الخاص بك
    let clientID = "YOUR_CLIENT_ID"
    // ⚠️ تأكد أن هذا الرابط مطابق لإعداداتك في Spotify Dashboard
    let redirectURI = "aiqo-spotify://callback"

    // الصلاحيات (Scopes)
    private let scopes = [
        "app-remote-control",
        "user-read-playback-state",
        "user-modify-playback-state"
    ]

    private var codeVerifier: String?
    private var session: ASWebAuthenticationSession?
    
    // Keep a strong reference to the fallback window if needed
    private var fallbackWindow: UIWindow?

    private(set) var accessToken: String? {
        didSet { onTokenChanged?(accessToken) }
    }

    var onTokenChanged: ((String?) -> Void)?

    // MARK: - Login Function
    func startLogin() {
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

        guard let authURL = comps.url else { return }

        let webSession = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "aiqo-spotify") { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            // Clean up fallback window if it was used
            self.fallbackWindow = nil
            
            guard error == nil, let callbackURL = callbackURL else { return }

            let query = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems
            let code = query?.first(where: { $0.name == "code" })?.value
            
            guard let code = code, let verifier = self.codeVerifier else { return }

            Task { await self.exchangeCodeForToken(code: code, verifier: verifier) }
        }

        webSession.presentationContextProvider = self
        webSession.prefersEphemeralWebBrowserSession = true
        webSession.start()
        self.session = webSession
    }

    // MARK: - Exchange Code for Token
    private func exchangeCodeForToken(code: String, verifier: String) async {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        
        var request = URLRequest(url: url)
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
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                await MainActor.run { self.accessToken = token }
                print("✅ Access Token Received")
            } else {
                print("⚠️ Failed to parse token")
            }
        } catch {
            print("❌ Error exchanging token: \(error)")
        }
    }

    var isLoggedIn: Bool { accessToken != nil }

    // MARK: - PKCE Helpers
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

// MARK: - Presentation Anchor Fix
extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Helper function to get all window scenes
        func getWindowScenes() -> [UIWindowScene] {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
        }
        
        // 1. Try to find an active foreground window scene first
        let activeScene = getWindowScenes()
            .first { $0.activationState == .foregroundActive }
        
        // 2. If we found an active scene, try to get its key window
        if let scene = activeScene {
            if let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
            // If no key window, try any window from this scene
            if let anyWindow = scene.windows.first {
                return anyWindow
            }
            // Create a new window for this scene
            let window = UIWindow(windowScene: scene)
            window.makeKeyAndVisible()
            fallbackWindow = window
            return window
        }
        
        // 3. If no active scene, try any available window scene
        if let anyScene = getWindowScenes().first {
            if let existingWindow = anyScene.windows.first {
                return existingWindow
            }
            // Create a new window for this scene
            let window = UIWindow(windowScene: anyScene)
            window.makeKeyAndVisible()
            fallbackWindow = window
            return window
        }
        
        // 4. Last resort: This should never happen in a properly configured app
        // but we need to return something. Create a window scene if possible.
        // Note: We cannot create a UIWindowScene programmatically, so at this point
        // we must have at least one scene or the app isn't set up correctly.
        
        // If we reach here, the app has no connected scenes which is very unusual
        // Log an error in debug mode
        #if DEBUG
        assertionFailure("SpotifyAuthManager: No UIWindowScene available. Check your app's scene configuration.")
        #endif
        
        // Return any existing window we can find through the deprecated but necessary path
        // This handles edge cases like app extensions or unusual app lifecycle states
        if let existingWindow = getWindowScenes().flatMap({ $0.windows }).first {
            return existingWindow
        }
        
        // Absolute fallback - create a window attached to any scene we can find
        // This path should essentially never be reached in a normal app
        if let scene = getWindowScenes().first {
            let window = UIWindow(windowScene: scene)
            fallbackWindow = window
            return window
        }
        
        // If truly no scenes exist (shouldn't happen), we have no choice but to create
        // a detached window. This will show a warning but the app is in an invalid state anyway.
        fatalError("SpotifyAuthManager: Cannot present authentication - no window scenes available")
    }
}
