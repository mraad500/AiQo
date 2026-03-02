import Foundation
import UIKit
internal import Combine

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

    private let clientID = "b55c2098adc8411e83eee55a905e42f3"
    private let redirectURI = URL(string: "aiqo://spotify-login-callback")!
    private let scopes: SPTScope = .appRemoteControl

    private var pendingVibeURI: String?
    private var shouldReconnectWhenActive = false
    private var shouldResumePlaybackWhenConnected = false
    private var currentTrackURI: String?
    private var wasStoppedManually = false

    private override init() {
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        configuration.companyName = "AiQo"

        self.configuration = configuration
        self.sessionManager = SPTSessionManager(configuration: configuration, delegate: nil)
        self.appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)

        super.init()

        sessionManager.delegate = self
        appRemote.delegate = self
        appRemote.connectionParameters.accessToken = sessionManager.session?.accessToken
        refreshSpotifyAvailability()

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

    var canAttemptAuthorization: Bool {
        !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isPlaybackAvailable: Bool {
        isSpotifyAppInstalled && canAttemptAuthorization
    }

    func connect() {
        if prepareForConnection() {
            log("Already connected to Spotify.")
        }
    }

    func playVibe(uri: String, vibeTitle: String? = nil) {
        let trimmedURI = uri.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURI.isEmpty else {
            reportError("Choose a Spotify playlist before trying to play a vibe.", code: "spotify_uri_missing")
            return
        }

        if let vibeTitle {
            setCurrentVibeTitle(vibeTitle)
        }
        shouldResumePlaybackWhenConnected = false
        pendingVibeURI = trimmedURI
        wasStoppedManually = false

        if prepareForConnection() {
            playPendingVibeIfNeeded()
        }
    }

    func playVibe() {
        resumeVibe()
    }

    func resumeVibe() {
        shouldResumePlaybackWhenConnected = true
        wasStoppedManually = false

        if prepareForConnection() {
            resumePlaybackIfPossible()
        }
    }

    func pauseVibe() {
        guard appRemote.isConnected else {
            reportError("Connect Spotify before trying to pause playback.", code: "spotify_disconnected")
            return
        }

        clearError()
        appRemote.playerAPI?.pause({ [weak self] _, error in
            guard let self else { return }

            if let error {
                self.reportError(
                    "Couldn't pause Spotify playback: \(error.localizedDescription)",
                    code: "spotify_pause_failed"
                )
                return
            }

            self.wasStoppedManually = false
            self.shouldResumePlaybackWhenConnected = false
            self.setPausedState(true)
            self.setPlaybackState(.paused)
            self.log("Playback paused.")
        })
    }

    func stopVibe() {
        pendingVibeURI = nil
        shouldResumePlaybackWhenConnected = false
        shouldReconnectWhenActive = false
        wasStoppedManually = true

        guard appRemote.isConnected else {
            setPausedState(true)
            setPlaybackState(.stopped)
            log("Playback marked as stopped while Spotify was disconnected.")
            return
        }

        clearError()
        appRemote.playerAPI?.pause({ [weak self] _, error in
            guard let self else { return }

            if let error {
                self.reportError(
                    "Couldn't stop Spotify playback: \(error.localizedDescription)",
                    code: "spotify_stop_failed"
                )
                return
            }

            self.setPausedState(true)
            self.setPlaybackState(.stopped)
            self.log("Playback stopped.")
        })
    }

    func skipNext() {
        guard appRemote.isConnected else {
            reportError("Connect Spotify before skipping tracks.", code: "spotify_disconnected")
            return
        }

        clearError()
        appRemote.playerAPI?.skip(toNext: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.reportError(
                    "Couldn't skip to the next Spotify track: \(error.localizedDescription)",
                    code: "spotify_skip_next_failed"
                )
                return
            }

            self.log("Skipped to next track.")
        })
    }

    func skipPrevious() {
        guard appRemote.isConnected else {
            reportError("Connect Spotify before skipping tracks.", code: "spotify_disconnected")
            return
        }

        clearError()
        appRemote.playerAPI?.skip(toPrevious: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.reportError(
                    "Couldn't go back to the previous Spotify track: \(error.localizedDescription)",
                    code: "spotify_skip_previous_failed"
                )
                return
            }

            self.log("Skipped to previous track.")
        })
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

    @objc
    private func applicationDidBecomeActive() {
        refreshSpotifyAvailability()

        guard shouldReconnectWhenActive,
              !appRemote.isConnected,
              let session = sessionManager.session,
              !session.isExpired else {
            return
        }

        log("App became active. Reconnecting App Remote.")
        connectAppRemote(with: session.accessToken)
    }

    @objc
    private func applicationWillResignActive() {
        guard appRemote.isConnected else { return }

        appRemote.playerAPI?.unsubscribe(toPlayerState: nil)
        log("App is resigning active. Disconnecting App Remote transport.")
        appRemote.disconnect()
        setConnectionState(false)
    }

    private func connectAppRemote(with accessToken: String) {
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
    private func prepareForConnection() -> Bool {
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

    private func playPendingVibeIfNeeded() {
        guard appRemote.isConnected, let pendingVibeURI else { return }

        clearError()
        appRemote.playerAPI?.play(pendingVibeURI, callback: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.reportError(
                    "Couldn't start the selected Spotify playlist: \(error.localizedDescription)",
                    code: "spotify_play_failed"
                )
                return
            }

            self.pendingVibeURI = nil
            self.shouldResumePlaybackWhenConnected = false
            self.wasStoppedManually = false
            self.setPausedState(false)
            self.setPlaybackState(.playing)
            self.log("Playing vibe URI: \(pendingVibeURI)")
        })
    }

    private func resumePlaybackIfPossible() {
        guard appRemote.isConnected else { return }

        clearError()
        appRemote.playerAPI?.resume({ [weak self] _, error in
            guard let self else { return }

            if let error {
                self.reportError(
                    "Couldn't resume Spotify playback: \(error.localizedDescription)",
                    code: "spotify_resume_failed"
                )
                return
            }

            self.wasStoppedManually = false
            self.shouldResumePlaybackWhenConnected = false
            self.setPausedState(false)
            self.setPlaybackState(.playing)
            self.log("Playback resumed.")
        })
    }

    private func setConnectionState(_ connected: Bool) {
        if Thread.isMainThread {
            isConnected = connected
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isConnected = connected
            }
        }
    }

    private func setPausedState(_ paused: Bool) {
        if Thread.isMainThread {
            isPaused = paused
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isPaused = paused
            }
        }
    }

    private func setPlaybackState(_ state: VibePlaybackState) {
        if Thread.isMainThread {
            playbackState = state
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.playbackState = state
            }
        }
    }

    private func setCurrentVibeTitle(_ title: String?) {
        if Thread.isMainThread {
            currentVibeTitle = title
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.currentVibeTitle = title
            }
        }
    }

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

    private func reportError(_ message: String, code: String? = nil) {
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

    private func refreshSpotifyAvailability() {
        let installed = sessionManager.isSpotifyAppInstalled

        if Thread.isMainThread {
            isSpotifyAppInstalled = installed
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isSpotifyAppInstalled = installed
            }
        }
    }

    private func requestPlayerState() {
        guard appRemote.isConnected else { return }

        appRemote.playerAPI?.getPlayerState({ [weak self] result, error in
            guard let self else { return }

            if let error {
                self.reportError(
                    "Couldn't refresh Spotify player state: \(error.localizedDescription)",
                    code: "spotify_state_fetch_failed"
                )
                return
            }

            guard let playerState = result as? SPTAppRemotePlayerState else {
                self.reportError(
                    "Spotify returned an unexpected player state payload.",
                    code: "spotify_state_invalid"
                )
                return
            }

            self.updatePlayerState(from: playerState)
        })
    }

    private func updatePlayerState(from playerState: SPTAppRemotePlayerState) {
        let track = playerState.track
        let trackName = track.name
        let artistName = track.artist.name
        let trackURI = track.uri
        let shouldFetchArtwork = currentTrackURI != trackURI || currentAlbumArt == nil
        let resolvedPlaybackState: VibePlaybackState

        currentTrackURI = trackURI

        if wasStoppedManually && playerState.isPaused {
            resolvedPlaybackState = .stopped
        } else if playerState.isPaused {
            resolvedPlaybackState = .paused
        } else {
            wasStoppedManually = false
            resolvedPlaybackState = .playing
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentTrackName = trackName
            self.currentArtistName = artistName
            self.isPaused = playerState.isPaused
            self.playbackState = resolvedPlaybackState

            if shouldFetchArtwork {
                self.currentAlbumArt = nil
            }
        }

        guard shouldFetchArtwork else { return }

        appRemote.imageAPI?.fetchImage(
            forItem: track,
            with: CGSize(width: 100, height: 100),
            callback: { [weak self] result, error in
                guard let self else { return }

                if let error {
                    self.reportError(
                        "Couldn't load Spotify album art: \(error.localizedDescription)",
                        code: "spotify_art_fetch_failed"
                    )
                    return
                }

                guard let image = result as? UIImage else {
                    self.reportError(
                        "Spotify returned an unexpected album art payload.",
                        code: "spotify_art_invalid"
                    )
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self, self.currentTrackURI == trackURI else { return }
                    self.currentAlbumArt = image
                }
            }
        )
    }

    private func log(_ message: String) {
        print("Aura Vibe: \(message)")
    }
}

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

extension SpotifyVibeManager: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        setConnectionState(true)
        clearError()
        log("Connected to Spotify.")

        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.reportError(
                    "Couldn't subscribe to Spotify player updates: \(error.localizedDescription)",
                    code: "spotify_subscribe_failed"
                )
                return
            }

            self.log("Subscribed to Spotify player state.")
        })

        requestPlayerState()

        if let pendingVibeURI {
            log("Playback request is ready after reconnect: \(pendingVibeURI)")
            playPendingVibeIfNeeded()
        } else if shouldResumePlaybackWhenConnected {
            resumePlaybackIfPossible()
        }
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        setConnectionState(false)
        let message = error?.localizedDescription ?? "Unknown connection error."
        reportError("Couldn't connect to Spotify: \(message)", code: "spotify_connection_failed")
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        setConnectionState(false)

        if let error {
            reportError(
                "Spotify disconnected: \(error.localizedDescription)",
                code: "spotify_disconnected"
            )
        } else {
            log("Disconnected from Spotify.")
        }
    }
}

extension SpotifyVibeManager: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        updatePlayerState(from: playerState)
        log("Player state updated. Track URI: \(playerState.track.uri)")
    }
}
#else

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

    var canAttemptAuthorization: Bool { false }
    var isPlaybackAvailable: Bool { false }

    private override init() {
        super.init()
        lastErrorMessage = "Spotify is disabled on the iOS Simulator. Run on a real iPhone to use Spotify playback."
        lastErrorCode = "spotify_simulator_unavailable"
    }

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

    func skipNext() {}

    func skipPrevious() {}

    func handleURL(_ url: URL) -> Bool {
        false
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
