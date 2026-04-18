import Foundation
import UIKit
import Combine

#if !targetEnvironment(simulator)
import SpotifyiOS

enum VibePlaybackState: String {
    case stopped = "Stopped"
    case paused = "Paused"
    case playing = "Playing"
}

final class SpotifyVibeManager: NSObject, ObservableObject {
    static let shared = SpotifyVibeManager()

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isSpotifyAppInstalled: Bool = false
    @Published var currentTrackName: String = "Not Playing"
    @Published var currentArtistName: String = ""
    @Published var currentAlbumArt: UIImage? = nil
    @Published var isPaused: Bool = true
    @Published private(set) var currentVibeTitle: String?
    @Published private(set) var playbackState: VibePlaybackState = .stopped
    @Published var lastErrorMessage: String?
    @Published var lastErrorCode: String?

    let configuration: SPTConfiguration
    let sessionManager: SPTSessionManager
    let appRemote: SPTAppRemote

    let clientID: String
    static let redirectURI: URL = {
        guard let url = URL(string: "aiqo://spotify-login-callback") else {
            assertionFailure("Invalid Spotify redirect URI")
            return URL(fileURLWithPath: "/")
        }
        return url
    }()
    let scopes: SPTScope = [
        .appRemoteControl,
        .userTopRead,
        .userReadPlaybackState,
        .userModifyPlaybackState
    ]

    @Published var webAPIToken: String?
    @Published var isWebAPIAuthorized: Bool = false
    /// First 8 hex chars of SHA256(rawSpotifyUserID). Safe to log / render.
    /// Populated once after a successful OAuth session.
    @Published var currentSpotifyUserIDHash: String?
    /// Raw Spotify user ID — in-memory only, never written to disk.
    /// Exposed for Dashboard allowlisting diagnostics via the debugger.
    var _rawSpotifyUserIDForDashboard: String?
    var pkceCodeVerifier: String?
    /// Guards against re-entrant `authorizeWebAPI()` calls while an ASWebAuth session is open.
    var isAuthorizingWebAPI: Bool = false

    static let webAPIScopes = "user-top-read user-read-playback-state user-modify-playback-state"

    var pendingVibeURI: String?
    var shouldReconnectWhenActive = false
    var shouldResumePlaybackWhenConnected = false
    var currentTrackURI: String?
    var wasStoppedManually = false

    private override init() {
        guard let resolvedClientID = Bundle.main.infoDictionary?["SPOTIFY_CLIENT_ID"] as? String,
              !resolvedClientID.isEmpty,
              !resolvedClientID.hasPrefix("$(") else {
            PrivacySanitizer.log("SpotifyVibeManager: SPOTIFY_CLIENT_ID missing from Info.plist — Spotify features disabled.")
            self.clientID = ""
            let dummyConfig = SPTConfiguration(clientID: "", redirectURL: Self.redirectURI)
            self.configuration = dummyConfig
            self.sessionManager = SPTSessionManager(configuration: dummyConfig, delegate: nil)
            self.appRemote = SPTAppRemote(configuration: dummyConfig, logLevel: .debug)
            super.init()
            return
        }
        self.clientID = resolvedClientID
        let configuration = SPTConfiguration(clientID: resolvedClientID, redirectURL: Self.redirectURI)
        configuration.companyName = "AiQo"

        self.configuration = configuration
        self.sessionManager = SPTSessionManager(configuration: configuration, delegate: nil)
        self.appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)

        super.init()

        sessionManager.delegate = self
        appRemote.delegate = self
        appRemote.connectionParameters.accessToken = sessionManager.session?.accessToken
        refreshSpotifyAvailability()

        migrateLegacySpotifyTokensIfNeeded()

        // Only mark as "authorized" if the token is actually usable — either
        // still valid, or expired-but-refreshable. A dead token (expired and
        // no refresh) should NOT be marked authorized; otherwise the VM's
        // auto-build subscriber would fire and immediately hit authExpired.
        if let token = SpotifyTokenStore.load(), !token.accessToken.isEmpty {
            let isFresh = token.expiresAt > Date()
            let canRefresh = (token.refreshToken ?? "").isEmpty == false
            if isFresh || canRefresh {
                webAPIToken = token.accessToken
                isWebAPIAuthorized = true
                log("Restored Spotify Web API token from SpotifyTokenStore.")
            } else {
                log("Stored Spotify token is expired and has no refresh token; awaiting PKCE.")
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Availability

    var canAttemptAuthorization: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isPlaybackAvailable: Bool {
        isSpotifyAppInstalled && canAttemptAuthorization
    }

    var connectionRetryCount = 0
    let maxConnectionRetries = 3

    // MARK: - Connection

    func connect() {
        connectionRetryCount = 0

        if appRemote.isConnected {
            setConnectionState(true)
            log("Already connected to Spotify.")
            return
        }

        log("Starting Spotify authentication.")
        refreshSpotifyAvailability()
        clearError()

        guard isPlaybackAvailable else {
            presentAvailabilityError()
            return
        }

        shouldReconnectWhenActive = true
        sessionManager.initiateSession(with: scopes, options: .default, campaign: nil)
    }

    // MARK: - Silent Reconnect

    /// Attempts to reconnect to Spotify without prompting the user for auth.
    /// Returns `true` if we have a cached session and App Remote connects within 3s.
    /// Returns `false` immediately if no stored token or no cached session exists.
    func reconnectSilentlyIfPossible() async -> Bool {
        // 1. Check SpotifyTokenStore for saved Web API token
        guard let savedToken = SpotifyTokenStore.load()?.accessToken,
              !savedToken.isEmpty else {
            log("Silent reconnect: no Keychain token found.")
            return false
        }

        // 2. Already connected — nothing to do
        if appRemote.isConnected {
            log("Silent reconnect: already connected.")
            return true
        }

        // 3. Check for a cached SPT session with a valid access token
        guard let session = sessionManager.session, !session.isExpired else {
            log("Silent reconnect: no valid cached session — user must auth interactively.")
            return false
        }

        // 4. Attempt App Remote connection (non-interactive)
        shouldReconnectWhenActive = true
        connectAppRemote(with: session.accessToken)

        // 5. Poll for connection (max 3 seconds, 100ms intervals)
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if appRemote.isConnected {
                log("Silent reconnect: App Remote connected successfully.")
                return true
            }
        }

        log("Silent reconnect: timed out after 3s.")
        return false
    }

    /// Explicitly fetches the current player state from Spotify and feeds it through
    /// the existing playerStateDidChange pipeline to populate track name / artist.
    func fetchCurrentPlayerState() {
        guard isConnected else { return }
        requestPlayerState()
        log("Explicit player state fetch requested.")
    }

    @discardableResult
    func handleURL(_ url: URL) -> Bool {
        let handled = sessionManager.application(
            UIApplication.shared,
            open: url,
            options: [:]
        )

        if handled {
            log("Handled Spotify callback URL.")
        } else {
            log("Ignored non-Spotify callback URL: \(url.absoluteString)")
        }

        return handled
    }

    // MARK: - App Lifecycle

    @objc
    private func applicationDidBecomeActive() {
        refreshSpotifyAvailability()

        guard shouldReconnectWhenActive,
              !appRemote.isConnected,
              let session = sessionManager.session,
              !session.isExpired else {
            return
        }

        log("App became active. Will reconnect App Remote after delay...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self,
                  !self.appRemote.isConnected,
                  let session = self.sessionManager.session,
                  !session.isExpired else { return }
            self.log("Reconnecting App Remote now.")
            self.connectAppRemote(with: session.accessToken)
        }
    }

    @objc
    private func applicationWillResignActive() {
        guard appRemote.isConnected else { return }

        appRemote.playerAPI?.unsubscribe(toPlayerState: nil)
        log("App is resigning active. Disconnecting App Remote transport.")
        appRemote.disconnect()
        setConnectionState(false)
    }

    // MARK: - Connection Helpers

    func connectAppRemote(with accessToken: String) {
        guard !accessToken.isEmpty else {
            reportError("Spotify couldn't reconnect because the access token is missing.", code: "spotify_access_token_missing")
            return
        }

        appRemote.connectionParameters.accessToken = accessToken

        if appRemote.isConnected {
            setConnectionState(true)
            log("App Remote already connected.")

            if let pendingVibeURI {
                log("Playback request is ready while App Remote is already connected: \(pendingVibeURI)")
                playPendingVibeIfNeeded()
            } else if shouldResumePlaybackWhenConnected {
                resumePlaybackIfPossible()
            }
            return
        }

        log("Connecting to Spotify App Remote.")
        appRemote.connect()
    }

    @discardableResult
    func prepareForConnection() -> Bool {
        refreshSpotifyAvailability()
        clearError()

        guard isPlaybackAvailable else {
            presentAvailabilityError()
            return false
        }

        shouldReconnectWhenActive = true

        if appRemote.isConnected {
            setConnectionState(true)
            return true
        }

        if let session = sessionManager.session, !session.isExpired {
            log("Using cached Spotify session.")
            connectAppRemote(with: session.accessToken)
            return false
        }

        log("Starting Spotify authentication.")
        sessionManager.initiateSession(with: scopes, options: .default, campaign: nil)
        return false
    }

    // MARK: - State Management

    func setConnectionState(_ connected: Bool) {
        if Thread.isMainThread {
            isConnected = connected
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = connected
            }
        }
    }

    func setPausedState(_ paused: Bool) {
        if Thread.isMainThread {
            isPaused = paused
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isPaused = paused
            }
        }
    }

    func setPlaybackState(_ state: VibePlaybackState) {
        if Thread.isMainThread {
            playbackState = state
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.playbackState = state
            }
        }
    }

    func setCurrentVibeTitle(_ title: String?) {
        if Thread.isMainThread {
            currentVibeTitle = title
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.currentVibeTitle = title
            }
        }
    }

    // MARK: - Error Handling

    func clearError() {
        if Thread.isMainThread {
            lastErrorMessage = nil
            lastErrorCode = nil
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.lastErrorMessage = nil
                self?.lastErrorCode = nil
            }
        }
    }

    func presentAvailabilityError() {
        if !isSpotifyAppInstalled {
            let mapped = SpotifyAuthError.notInstalled
            reportError(mapped.localizedMessage, code: mapped.code)
            return
        }

        if !canAttemptAuthorization {
            let mapped = SpotifyAuthError.generic
            reportError(mapped.localizedMessage, code: "spotify_auth_unavailable")
        }
    }

    func reportError(_ message: String, code: String? = nil) {
        if Thread.isMainThread {
            lastErrorMessage = message
            lastErrorCode = code
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.lastErrorMessage = message
                self?.lastErrorCode = code
            }
        }

        log("Error [\(code ?? "unknown")]: \(message)")
    }

    func refreshSpotifyAvailability() {
        let installed = sessionManager.isSpotifyAppInstalled

        if Thread.isMainThread {
            isSpotifyAppInstalled = installed
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isSpotifyAppInstalled = installed
            }
        }
    }

    // MARK: - Spotify Logout

    func logoutSpotify() {
        stopVibe()

        if appRemote.isConnected {
            appRemote.disconnect()
        }

        appRemote.connectionParameters.accessToken = nil
        shouldReconnectWhenActive = false
        connectionRetryCount = 0

        currentSpotifyUserIDHash = nil
        _rawSpotifyUserIDForDashboard = nil
        clearSpotifyToken()

        setConnectionState(false)
        setPausedState(true)
        setPlaybackState(.stopped)

        DispatchQueue.main.async { [weak self] in
            self?.currentTrackName = "Not Playing"
            self?.currentArtistName = ""
            self?.currentAlbumArt = nil
            self?.currentVibeTitle = nil
        }

        log("Spotify fully reset. Session + Keychain cleared.")
    }

    // MARK: - Web API Helpers

    var accessToken: String? {
        sessionManager.session?.accessToken
    }

    func spotifyAPIError(from data: Data?, response: URLResponse?, fallback: String) -> NSError {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        var message = "HTTP \(statusCode)"

        if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any] {
                message = error["message"] as? String ?? message
            } else if let errorStr = json["error"] as? String {
                message = errorStr
            }
        }

        if statusCode == 401 || statusCode == 403 {
            self.clearSpotifyToken()
            self.log("Web API token expired/invalid — cleared. User must re-auth.")
        }

        let fullMessage = "\(fallback): \(message)"
        log("Spotify API error: \(fullMessage)")
        return NSError(domain: "SpotifyAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: fullMessage])
    }

    // MARK: - Token Persistence

    /// Centralized write path. Replaces all legacy token writes.
    /// Updates SpotifyTokenStore and syncs the published mirrors on the main thread.
    func persistSpotifyToken(access: String, refresh: String?, expiresIn: TimeInterval) {
        let carriedRefresh = refresh ?? SpotifyTokenStore.load()?.refreshToken
        let token = SpotifyToken(
            accessToken: access,
            refreshToken: carriedRefresh,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
        SpotifyTokenStore.save(token)

        let apply = { [weak self] in
            self?.webAPIToken = access
            self?.isWebAPIAuthorized = true
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    /// Centralized clear path. Wipes SpotifyTokenStore and the published mirrors.
    func clearSpotifyToken() {
        SpotifyTokenStore.clear()

        let apply = { [weak self] in
            self?.webAPIToken = nil
            self?.isWebAPIAuthorized = false
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    /// One-shot migration: legacy UserDefaults + split Keychain keys → SpotifyTokenStore.
    /// Runs at init. After success, old keys are deleted and never read again.
    ///
    /// Fix (post-live-test): the old synthesized `expiresAt = now + 3300s` was
    /// dishonest — the migrated access token was often already expired on the
    /// server, causing a stale-token cycle (stale token → 401 → clear → error
    /// alert). We now set `expiresAt = Date()` so the token is treated as
    /// immediately expired; if no refresh token exists, `refreshWebAPITokenIfNeeded`
    /// will trigger the auto-PKCE recovery path instead of serving a stale token.
    private func migrateLegacySpotifyTokensIfNeeded() {
        if SpotifyTokenStore.load() != nil { return }

        let legacyUD = UserDefaults.standard.string(forKey: "spotify_web_api_token")
        let legacyKCAccess = KeychainStore.get("aiqo.spotify.webapi.token")
        let legacyKCRefresh = KeychainStore.get("aiqo.spotify.webapi.refresh")

        defer {
            UserDefaults.standard.removeObject(forKey: "spotify_web_api_token")
            KeychainStore.delete("aiqo.spotify.webapi.token")
            KeychainStore.delete("aiqo.spotify.webapi.refresh")
        }

        let access = (legacyUD?.isEmpty == false ? legacyUD : nil) ?? legacyKCAccess
        guard let access, !access.isEmpty else { return }

        SpotifyTokenStore.save(
            SpotifyToken(
                accessToken: access,
                refreshToken: legacyKCRefresh,
                expiresAt: Date()
            )
        )
        log("Migrated legacy Spotify tokens into SpotifyTokenStore (treated as expired).")
    }

    func log(_ message: String) {
        PrivacySanitizer.log("Aura Vibe: \(message)")
    }
}

#else

// MARK: - Simulator Stub

enum VibePlaybackState: String {
    case stopped = "Stopped"
    case paused = "Paused"
    case playing = "Playing"
}

final class SpotifyVibeManager: NSObject, ObservableObject {
    static let shared = SpotifyVibeManager()

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var isSpotifyAppInstalled: Bool = false
    @Published var currentTrackName: String = "Spotify unavailable on Simulator"
    @Published var currentArtistName: String = ""
    @Published var currentAlbumArt: UIImage? = nil
    @Published var isPaused: Bool = true
    @Published private(set) var currentVibeTitle: String?
    @Published private(set) var playbackState: VibePlaybackState = .stopped
    @Published var lastErrorMessage: String?
    @Published var lastErrorCode: String?

    @Published var webAPIToken: String?
    @Published var isWebAPIAuthorized: Bool = false
    @Published private(set) var currentSpotifyUserIDHash: String?

    var canAttemptAuthorization: Bool { false }
    var isPlaybackAvailable: Bool { false }

    private override init() {
        super.init()
        lastErrorMessage = "Spotify is disabled on the iOS Simulator. Run on a real iPhone to use Spotify playback."
        lastErrorCode = "spotify_simulator_unavailable"
    }

    func reconnectSilentlyIfPossible() async -> Bool {
        false
    }

    func fetchCurrentPlayerState() {}

    func connect() {
        presentAvailabilityError()
    }

    func playVibe(uri: String, vibeTitle: String? = nil) {
        currentVibeTitle = vibeTitle
        presentAvailabilityError()
    }

    func playVibe() {
        presentAvailabilityError()
    }

    func resumeVibe() {
        presentAvailabilityError()
    }

    func pauseVibe() {
        isPaused = true
        playbackState = .paused
    }

    func stopVibe() {
        isPaused = true
        playbackState = .stopped
    }

    func playTrack(uri: String) {
        presentAvailabilityError()
    }

    func skipNext() {}

    func skipPrevious() {}

    func handleURL(_ url: URL) -> Bool {
        false
    }

    func logoutSpotify() {
        presentAvailabilityError()
    }

    func authorizeWebAPI() {
        presentAvailabilityError()
    }

    func refreshWebAPIToken() async throws {
        throw SpotifyAPIError.authExpired
    }

    func refreshWebAPITokenIfNeeded() async throws -> String {
        throw SpotifyAPIError.authExpired
    }

    func fetchUserTopTracks(limit: Int = 50) async throws -> [String] {
        throw SpotifyAPIError.unknown("Simulator")
    }

    func fetchUserTopTracksWithMetadata(limit: Int = 30) async throws -> [SpotifyTopTrack] {
        throw SpotifyAPIError.unknown("Simulator")
    }

    func enqueueTrack(uri: String) {
        presentAvailabilityError()
    }

    func clearError() {
        lastErrorMessage = nil
        lastErrorCode = nil
    }

    func presentAvailabilityError() {
        lastErrorMessage = "Spotify App Remote يحتاج جهاز iPhone حقيقي. على المحاكي نخليه مطفي."
        lastErrorCode = "spotify_simulator_unavailable"
    }
}
#endif
