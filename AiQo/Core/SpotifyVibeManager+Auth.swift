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

        guard !isAuthorizingWebAPI else {
            log("authorizeWebAPI already in progress — ignoring duplicate call.")
            return
        }
        isAuthorizingWebAPI = true

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
                self.isAuthorizingWebAPI = false
                let mapped = SpotifyAuthError.classify(error)
                let ns = error as NSError
                self.log("ASWebAuthSession failed: domain=\(ns.domain) code=\(ns.code) kind=\(mapped.code)")
                self.reportError(mapped.localizedMessage, code: mapped.code)
                return
            }

            guard let callbackURL,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value else {
                self.isAuthorizingWebAPI = false
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
                self.isAuthorizingWebAPI = false
                let mapped = SpotifyAuthError.classify(error)
                let ns = error as NSError
                self.log("Token exchange failed: domain=\(ns.domain) code=\(ns.code) kind=\(mapped.code)")
                self.reportError(mapped.localizedMessage, code: mapped.code)
                return
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                self.isAuthorizingWebAPI = false
                self.reportError("Couldn't parse Web API token.", code: "webapi_token_parse_failed")
                return
            }

            let refreshToken = json["refresh_token"] as? String
            let expiresIn = (json["expires_in"] as? Double) ?? 3300

            self.persistSpotifyToken(access: accessToken, refresh: refreshToken, expiresIn: expiresIn)
            self.isAuthorizingWebAPI = false
            self.log("Web API token acquired via PKCE (expires in \(Int(expiresIn))s).")

            Task { [weak self] in
                await self?.fetchAndStoreUserIDHash(accessToken: accessToken)
            }
        }.resume()
    }

    // MARK: - Token Refresh

    /// Uses the stored refresh token to obtain a new Web API access token.
    /// Called automatically when API requests return 401 or proactively via refreshWebAPITokenIfNeeded.
    func refreshWebAPIToken() async throws {
        guard let existing = SpotifyTokenStore.load(),
              let refreshToken = existing.refreshToken,
              !refreshToken.isEmpty else {
            log("No refresh token in store — cannot auto-refresh.")
            throw SpotifyAPIError.authExpired
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
            clearSpotifyToken()
            log("Token refresh failed — refresh token may be revoked.")
            throw SpotifyAPIError.authExpired
        }

        // Spotify may rotate the refresh token; preserve the existing one if not returned
        let rotatedRefresh = (json["refresh_token"] as? String) ?? refreshToken
        let expiresIn = (json["expires_in"] as? Double) ?? 3300

        persistSpotifyToken(access: newAccessToken, refresh: rotatedRefresh, expiresIn: expiresIn)
        log("Web API token refreshed successfully.")
    }

    /// One-shot fetch of the current user's Spotify ID.
    /// Publishes `currentSpotifyUserIDHash` (first 8 hex chars of SHA256)
    /// and keeps the raw ID only in an in-memory property for Dashboard allowlisting.
    private func fetchAndStoreUserIDHash(accessToken: String) async {
        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                log("User-ID fetch returned non-2xx (status=\(status)).")
                return
            }

            struct Me: Decodable {
                let id: String
                let display_name: String?
                let product: String?
                let country: String?
            }
            let me = try JSONDecoder().decode(Me.self, from: data)

            let digest = SHA256.hash(data: Data(me.id.utf8))
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            let shortHash = String(hex.prefix(8))

            await MainActor.run { [weak self] in
                self?._rawSpotifyUserIDForDashboard = me.id
                self?.currentSpotifyUserIDHash = shortHash
            }
            // These fields are scoped to the authenticated user's OWN profile
            // so they're safe to log (no PII leak vs what the user sees in Spotify).
            // They're the fastest way to spot an "account mismatch" between who's
            // logged into AiQo and who owns the Hamoudi playlist.
            let displayName = me.display_name ?? "<none>"
            let product = me.product ?? "<unknown>"
            let country = me.country ?? "<unknown>"
            log("Spotify user identified: id=\(me.id) display=\(displayName) product=\(product) country=\(country) hash=\(shortHash)")
        } catch {
            let ns = error as NSError
            log("User-ID fetch failed: domain=\(ns.domain) code=\(ns.code)")
        }
    }

    /// Fetches the authenticated user's top Spotify tracks with full
    /// display metadata (name, artist, album art). Same endpoint as
    /// `fetchUserTopTracks` but extracts more fields from the existing
    /// response — no extra network call.
    func fetchUserTopTracksWithMetadata(limit: Int = 30) async throws -> [SpotifyTopTrack] {
        for attempt in 0..<2 {
            let token = try await refreshWebAPITokenIfNeeded()

            var request = URLRequest(
                url: URL(string: "https://api.spotify.com/v1/me/top/tracks?limit=\(limit)&time_range=medium_term")!
            )
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                if attempt == 0 {
                    log("User top tracks (full) fetch got 401 — attempting token refresh...")
                    try await refreshWebAPIToken()
                    continue
                }
                throw SpotifyAPIError.authExpired
            }

            struct Payload: Decodable {
                struct Artist: Decodable { let name: String }
                struct Image: Decodable { let url: String; let height: Int?; let width: Int? }
                struct Album: Decodable { let images: [Image] }
                struct Item: Decodable {
                    let uri: String
                    let name: String
                    let artists: [Artist]
                    let album: Album
                }
                let items: [Item]
            }

            let decoded = try JSONDecoder().decode(Payload.self, from: data)
            let tracks: [SpotifyTopTrack] = decoded.items.map { item in
                let best = item.album.images.first(where: { ($0.width ?? 0) <= 300 }) ?? item.album.images.first
                return SpotifyTopTrack(
                    uri: item.uri,
                    name: item.name,
                    artist: item.artists.first?.name ?? "",
                    imageURL: best.flatMap { URL(string: $0.url) }
                )
            }
            PrivacySanitizer.log("Aura Vibe: fetched \(tracks.count) user top tracks (with metadata)")
            return tracks
        }
        throw SpotifyAPIError.authExpired
    }

    /// Fetches the authenticated user's top Spotify track URIs.
    /// Proactively refreshes the token; retries once on 401.
    /// Works in Spotify Dev Mode (self-scoped data is permitted).
    func fetchUserTopTracks(limit: Int = 50) async throws -> [String] {
        for attempt in 0..<2 {
            let token = try await refreshWebAPITokenIfNeeded()

            var request = URLRequest(
                url: URL(string: "https://api.spotify.com/v1/me/top/tracks?limit=\(limit)&time_range=medium_term")!
            )
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                if attempt == 0 {
                    log("User top tracks fetch got 401 — attempting token refresh...")
                    try await refreshWebAPIToken()
                    continue
                }
                throw SpotifyAPIError.authExpired
            }

            struct TopTracksResponse: Decodable {
                struct Track: Decodable { let uri: String }
                let items: [Track]
            }
            let decoded = try JSONDecoder().decode(TopTracksResponse.self, from: data)
            let uris = decoded.items.map { $0.uri }
            PrivacySanitizer.log("Aura Vibe: fetched \(uris.count) user top tracks")
            return uris
        }
        throw SpotifyAPIError.authExpired
    }

    /// Returns a valid access token. Proactively refreshes if expiring within 60s.
    /// If no refresh is possible, auto-starts PKCE (so the user goes through
    /// one continuous auth flow) and throws `SpotifyAPIError.authExpired` so the
    /// caller bails for this attempt; the VM will retry on `isWebAPIAuthorized`
    /// flipping true once PKCE completes.
    func refreshWebAPITokenIfNeeded() async throws -> String {
        if let token = SpotifyTokenStore.load(),
           !token.accessToken.isEmpty,
           token.expiresAt > Date().addingTimeInterval(60) {
            return token.accessToken
        }

        // Try the refresh flow if a refresh token exists.
        if let stored = SpotifyTokenStore.load(),
           let refresh = stored.refreshToken, !refresh.isEmpty {
            do {
                try await refreshWebAPIToken()
                if let token = SpotifyTokenStore.load(), !token.accessToken.isEmpty {
                    return token.accessToken
                }
            } catch {
                // Fall through to PKCE recovery below.
            }
        }

        // Dead end: no usable token and no refresh path. Auto-start PKCE
        // (re-entrancy guarded) so the user doesn't have to tap Connect a
        // second time — then signal this attempt as failed.
        await MainActor.run { [weak self] in
            guard let self else { return }
            self.log("refreshWebAPITokenIfNeeded: no refresh path — auto-starting PKCE.")
            self.authorizeWebAPI()
        }
        throw SpotifyAPIError.authExpired
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

        // The SDK session only grants App Remote playback control; Web API
        // calls (top tracks, playlist reads) need a separate PKCE token.
        // Kick off PKCE automatically so the user goes through one continuous
        // auth flow rather than getting stuck on "انتهت صلاحية الاتصال".
        //
        // A stored token only counts as "valid" if it's still fresh OR we
        // have a refresh token we can use — otherwise it's a dead token and
        // we must re-authorize.
        let hasLiveToken: Bool = {
            guard let stored = SpotifyTokenStore.load(), !stored.accessToken.isEmpty else {
                return false
            }
            let isFresh = stored.expiresAt > Date()
            let canRefresh = (stored.refreshToken ?? "").isEmpty == false
            return isFresh || canRefresh
        }()
        if !hasLiveToken {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self else { return }
                self.log("Auto-starting PKCE for Web API (no usable token).")
                self.authorizeWebAPI()
            }
        }
    }

    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        setConnectionState(false)
        let mapped = SpotifyAuthError.classify(error)
        let ns = error as NSError
        log("SPTSessionManager didFailWith: domain=\(ns.domain) code=\(ns.code) kind=\(mapped.code)")
        reportError(mapped.localizedMessage, code: mapped.code)
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
