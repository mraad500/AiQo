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
        .playlistReadPrivate,
        .userTopRead,
        .userReadPlaybackState,
        .userModifyPlaybackState
    ]

    @Published var isGeneratingBlend: Bool = false
    @Published var blendError: String?

    // Blend Engine (in-memory queue, no playlist creation)
    @Published var currentBlendSource: BlendSourceTag?
    @Published var currentBlendQueue: [BlendTrackItem] = []
    var blendSourceLookup: [String: BlendSourceTag] = [:]

    private static let keychainTokenKey = "aiqo.spotify.webapi.token"

    @Published var webAPIToken: String? {
        didSet {
            if let webAPIToken {
                KeychainStore.set(webAPIToken, for: Self.keychainTokenKey)
            } else {
                KeychainStore.delete(Self.keychainTokenKey)
            }
        }
    }
    @Published var isWebAPIAuthorized: Bool = false
    var pkceCodeVerifier: String?

    static let webAPIScopes = "playlist-read-private user-top-read user-read-playback-state user-modify-playback-state"

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

        // One-time migration: UserDefaults → Keychain
        if let legacyToken = UserDefaults.standard.string(forKey: "spotify_web_api_token"), !legacyToken.isEmpty {
            KeychainStore.set(legacyToken, for: Self.keychainTokenKey)
            UserDefaults.standard.removeObject(forKey: "spotify_web_api_token")
            log("Migrated Web API token from UserDefaults to Keychain.")
        }

        if let savedToken = KeychainStore.get(Self.keychainTokenKey), !savedToken.isEmpty {
            webAPIToken = savedToken
            isWebAPIAuthorized = true
            log("Restored Web API token from Keychain.")
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
    /// Returns `false` immediately if no Keychain token or no cached session exists.
    func reconnectSilentlyIfPossible() async -> Bool {
        // 1. Check Keychain for saved Web API token
        guard let savedToken = KeychainStore.get("aiqo.spotify.webapi.token"),
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
            reportError("Install Spotify to use My Vibe playlist controls.", code: "spotify_not_installed")
            return
        }

        if !canAttemptAuthorization {
            reportError("Spotify authentication is unavailable right now.", code: "spotify_auth_unavailable")
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

        blendError = nil
        currentBlendSource = nil
        currentBlendQueue = []
        blendSourceLookup = [:]
        webAPIToken = nil
        isWebAPIAuthorized = false
        KeychainStore.delete("aiqo.spotify.webapi.refresh")

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
            DispatchQueue.main.async { [weak self] in
                self?.webAPIToken = nil
                self?.isWebAPIAuthorized = false
                self?.log("Web API token expired/invalid — cleared. User must re-auth.")
            }
        }

        let fullMessage = "\(fallback): \(message)"
        log("Spotify API error: \(fullMessage)")
        return NSError(domain: "SpotifyAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: fullMessage])
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

    @Published var isGeneratingBlend: Bool = false
    @Published var blendError: String?
    @Published var currentBlendSource: BlendSourceTag?
    @Published var currentBlendQueue: [BlendTrackItem] = []
    var blendSourceLookup: [String: BlendSourceTag] = [:]
    @Published var webAPIToken: String?
    @Published var isWebAPIAuthorized: Bool = false

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

    func buildBlendQueue(userRatio: Double = 0.6, completion: @escaping (Result<[BlendTrackItem], Error>) -> Void) {
        presentAvailabilityError()
        completion(.failure(NSError(domain: "BlendEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulator"])))
    }

    func playBlendQueue(_ queue: [BlendTrackItem]) {
        presentAvailabilityError()
    }

    func resolveBlendSource(for trackURI: String) -> BlendSourceTag? {
        nil
    }

    func fetchTopTrackURIs(limit: Int = 10) async throws -> [String] {
        throw BlendError.unknown("Simulator")
    }

    func fetchMasterPlaylistURIs(playlistId: String) async throws -> [String] {
        throw BlendError.unknown("Simulator")
    }

    func refreshWebAPIToken() async throws {
        throw BlendError.authExpired
    }

    func fetchHamoudiPlaylistTracks() async throws -> [String] {
        throw BlendError.unknown("Simulator")
    }

    func fetchUserTopTracks(limit: Int = 50) async throws -> [String] {
        throw BlendError.unknown("Simulator")
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
