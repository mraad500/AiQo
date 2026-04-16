import Foundation
import UIKit
import AuthenticationServices
import CryptoKit

#if !targetEnvironment(simulator)
import SpotifyiOS

// MARK: - Web API PKCE Authorization

extension SpotifyVibeManager {

    func authorizeWebAPI() {
        guard !clientID.isEmpty else {
            reportError("Spotify Client ID missing.", code: "webapi_no_client_id")
            return
        }

        let verifier = generateCodeVerifier()
        pkceCodeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI.absoluteString),
            URLQueryItem(name: "scope", value: Self.webAPIScopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]

        guard let authURL = components.url else { return }

        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "aiqo") { [weak self] callbackURL, error in
            guard let self else { return }

            if let error {
                self.reportError("Web API auth cancelled: \(error.localizedDescription)", code: "webapi_auth_cancelled")
                return
            }

            guard let callbackURL,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value else {
                self.reportError("No auth code received.", code: "webapi_no_code")
                return
            }

            self.exchangeCodeForToken(code: code)
        }

        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = self

        session.start()
    }

    private func exchangeCodeForToken(code: String) {
        guard let verifier = pkceCodeVerifier else { return }

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParts = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(Self.redirectURI.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
            "client_id=\(clientID)",
            "code_verifier=\(verifier)"
        ]
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                self.reportError("Token exchange failed: \(error.localizedDescription)", code: "webapi_token_error")
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                self.reportError("Couldn't parse Web API token.", code: "webapi_token_parse_failed")
                return
            }

            DispatchQueue.main.async {
                self.webAPIToken = accessToken
                self.isWebAPIAuthorized = true
                self.log("Web API token acquired via PKCE.")
            }

            // Save refresh token for silent re-auth when access token expires
            if let refreshToken = json["refresh_token"] as? String {
                KeychainStore.set(refreshToken, for: "aiqo.spotify.webapi.refresh")
                self.log("Saved refresh token to Keychain.")
            }
        }.resume()
    }

    // MARK: - Token Refresh

    /// Uses the stored refresh token to obtain a new Web API access token.
    /// Called automatically when API requests return 401.
    func refreshWebAPIToken() async throws {
        guard let refreshToken = KeychainStore.get("aiqo.spotify.webapi.refresh") else {
            log("No refresh token in Keychain — cannot auto-refresh.")
            throw BlendError.authExpired
        }

        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParts = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
            "client_id=\(clientID)"
        ]
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            KeychainStore.delete("aiqo.spotify.webapi.refresh")
            log("Token refresh failed — refresh token may be revoked.")
            throw BlendError.authExpired
        }

        // Spotify may rotate the refresh token
        if let newRefresh = json["refresh_token"] as? String {
            KeychainStore.set(newRefresh, for: "aiqo.spotify.webapi.refresh")
        }

        // Write to Keychain immediately so getWebAPIToken() picks it up on retry
        KeychainStore.set(newAccessToken, for: "aiqo.spotify.webapi.token")

        DispatchQueue.main.async { [weak self] in
            self?.webAPIToken = newAccessToken
            self?.isWebAPIAuthorized = true
        }

        log("Web API token refreshed successfully.")
    }

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - SPTSessionManagerDelegate

extension SpotifyVibeManager: SPTSessionManagerDelegate {
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        log("Spotify session initiated.")
        connectAppRemote(with: session.accessToken)
    }

    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        setConnectionState(false)
        reportError(
            "Spotify authentication failed: \(error.localizedDescription)",
            code: "spotify_auth_failed"
        )
    }

    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        log("Spotify session renewed.")
        connectAppRemote(with: session.accessToken)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyVibeManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor(windowScene: UIApplication.shared.connectedScenes.first as! UIWindowScene)
    }
}
#endif
