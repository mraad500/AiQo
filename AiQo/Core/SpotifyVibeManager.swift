import Foundation
import UIKit
internal import Combine
import SpotifyiOS

final class SpotifyVibeManager: NSObject, ObservableObject {
    static let shared = SpotifyVibeManager()

    @Published private(set) var isConnected: Bool = false
    @Published var currentTrackName: String = "Not Playing"
    @Published var currentArtistName: String = ""
    @Published var currentAlbumArt: UIImage? = nil
    @Published var isPaused: Bool = true

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

    private override init() {
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        configuration.playURI = ""
        configuration.companyName = "AiQo"

        self.configuration = configuration
        self.sessionManager = SPTSessionManager(configuration: configuration, delegate: nil)
        self.appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)

        super.init()

        sessionManager.delegate = self
        appRemote.delegate = self
        appRemote.connectionParameters.accessToken = sessionManager.session?.accessToken

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

    func connect() {
        guard sessionManager.isSpotifyAppInstalled else {
            log("Spotify app is not installed or not available via LSApplicationQueriesSchemes.")
            return
        }

        shouldReconnectWhenActive = true

        if appRemote.isConnected {
            log("Already connected to Spotify.")
            setConnectionState(true)
            return
        }

        if let session = sessionManager.session, !session.isExpired {
            log("Using cached Spotify session.")
            connectAppRemote(with: session.accessToken)
            return
        }

        configuration.playURI = configuration.playURI ?? ""
        log("Starting Spotify authentication.")
        sessionManager.initiateSession(with: scopes, options: .default, campaign: nil)
    }

    func playVibe(uri: String) {
        let trimmedURI = uri.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURI.isEmpty else {
            log("Refusing to play an empty Spotify URI.")
            return
        }

        shouldResumePlaybackWhenConnected = false
        pendingVibeURI = trimmedURI
        configuration.playURI = trimmedURI

        guard appRemote.isConnected else {
            log("Spotify App Remote is not connected. Attempting connection before playback.")

            if let session = sessionManager.session, !session.isExpired {
                connectAppRemote(with: session.accessToken)
            } else {
                connect()
            }
            return
        }

        appRemote.playerAPI?.play(trimmedURI, callback: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.log("Failed to play vibe: \(error.localizedDescription)")
                return
            }

            self.pendingVibeURI = nil
            self.log("Playing vibe URI: \(trimmedURI)")
        })
    }

    func playVibe() {
        guard appRemote.isConnected else {
            shouldResumePlaybackWhenConnected = true
            log("Spotify App Remote is not connected. Attempting connection before resuming playback.")

            if let session = sessionManager.session, !session.isExpired {
                connectAppRemote(with: session.accessToken)
            } else {
                connect()
            }
            return
        }

        appRemote.playerAPI?.resume({ [weak self] _, error in
            guard let self else { return }

            if let error {
                self.log("Failed to resume playback: \(error.localizedDescription)")
                return
            }

            self.setPausedState(false)
            self.log("Playback resumed.")
        })
    }

    func pauseVibe() {
        guard appRemote.isConnected else {
            log("Pause requested while Spotify is disconnected.")
            return
        }

        appRemote.playerAPI?.pause({ [weak self] _, error in
            guard let self else { return }

            if let error {
                self.log("Failed to pause playback: \(error.localizedDescription)")
                return
            }

            self.setPausedState(true)
            self.log("Playback paused.")
        })
    }

    func skipNext() {
        guard appRemote.isConnected else {
            log("Skip next requested while Spotify is disconnected.")
            return
        }

        appRemote.playerAPI?.skip(toNext: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.log("Failed to skip to next track: \(error.localizedDescription)")
                return
            }

            self.log("Skipped to next track.")
        })
    }

    func skipPrevious() {
        guard appRemote.isConnected else {
            log("Skip previous requested while Spotify is disconnected.")
            return
        }

        appRemote.playerAPI?.skip(toPrevious: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.log("Failed to skip to previous track: \(error.localizedDescription)")
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
    }

    private func connectAppRemote(with accessToken: String) {
        guard !accessToken.isEmpty else {
            log("Cannot connect App Remote without an access token.")
            return
        }

        appRemote.connectionParameters.accessToken = accessToken

        if appRemote.isConnected {
            setConnectionState(true)
            log("App Remote already connected.")

            if let pendingVibeURI {
                playVibe(uri: pendingVibeURI)
            }
            return
        }

        log("Connecting to Spotify App Remote.")
        appRemote.connect()
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

    private func requestPlayerState() {
        guard appRemote.isConnected else { return }

        appRemote.playerAPI?.getPlayerState({ [weak self] result, error in
            guard let self else { return }

            if let error {
                self.log("Failed to fetch player state: \(error.localizedDescription)")
                return
            }

            guard let playerState = result as? SPTAppRemotePlayerState else {
                self.log("Received an unexpected player state payload.")
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

        currentTrackURI = trackURI

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentTrackName = trackName
            self.currentArtistName = artistName
            self.isPaused = playerState.isPaused

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
                    self.log("Failed to fetch album art: \(error.localizedDescription)")
                    return
                }

                guard let image = result as? UIImage else {
                    self.log("Spotify image API returned an unexpected album art payload.")
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
        log("Failed to authenticate with Spotify: \(error.localizedDescription)")
    }

    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        log("Spotify session renewed.")
        connectAppRemote(with: session.accessToken)
    }
}

extension SpotifyVibeManager: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        setConnectionState(true)
        log("Connected to Spotify.")

        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.log("Failed to subscribe to player state: \(error.localizedDescription)")
                return
            }

            self.log("Subscribed to Spotify player state.")
        })

        requestPlayerState()

        if let pendingVibeURI {
            playVibe(uri: pendingVibeURI)
        } else if shouldResumePlaybackWhenConnected {
            shouldResumePlaybackWhenConnected = false
            playVibe()
        }
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        setConnectionState(false)
        let message = error?.localizedDescription ?? "Unknown connection error."
        log("Failed to connect: \(message)")
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        setConnectionState(false)
        setPausedState(true)

        if let error {
            log("Disconnected from Spotify: \(error.localizedDescription)")
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
