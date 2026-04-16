import Foundation
import UIKit
import Combine

#if !targetEnvironment(simulator)
import SpotifyiOS

// MARK: - Playback Control

extension SpotifyVibeManager {

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

    func playTrack(uri: String) {
        guard isConnected, let playerAPI = appRemote.playerAPI else {
            PrivacySanitizer.log("Aura Vibe: playTrack called but not connected")
            return
        }
        playerAPI.play(uri) { _, error in
            if let error = error {
                PrivacySanitizer.log("Aura Vibe: playTrack error: \(error.localizedDescription)")
            }
        }
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

    // MARK: - Internal Playback Helpers

    func playPendingVibeIfNeeded() {
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

    func resumePlaybackIfPossible() {
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

    // MARK: - Player State

    func requestPlayerState() {
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

    func updatePlayerState(from playerState: SPTAppRemotePlayerState) {
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

        setPausedState(playerState.isPaused)
        setPlaybackState(resolvedPlaybackState)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.currentTrackName = trackName
            self.currentArtistName = artistName

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
}

// MARK: - SPTAppRemoteDelegate

extension SpotifyVibeManager: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        connectionRetryCount = 0
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

        if connectionRetryCount < maxConnectionRetries {
            connectionRetryCount += 1
            let delay = Double(connectionRetryCount) * 1.5
            log("Connection attempt \(connectionRetryCount)/\(maxConnectionRetries) failed. Retrying in \(delay)s...")

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }

                if self.connectionRetryCount == 2,
                   let spotifyURL = URL(string: "spotify:"),
                   UIApplication.shared.canOpenURL(spotifyURL) {
                    UIApplication.shared.open(spotifyURL) { [weak self] _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            guard let self,
                                  let session = self.sessionManager.session,
                                  !session.isExpired else { return }
                            self.connectAppRemote(with: session.accessToken)
                        }
                    }
                    return
                }

                guard let session = self.sessionManager.session, !session.isExpired else {
                    self.reportError("Spotify session expired. Please reconnect.", code: "spotify_session_expired")
                    return
                }
                self.connectAppRemote(with: session.accessToken)
            }
            return
        }

        connectionRetryCount = 0
        log("All connection retries exhausted. Starting fresh authentication...")
        sessionManager.initiateSession(with: scopes, options: .default, campaign: nil)
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        setConnectionState(false)

        shouldReconnectWhenActive = true

        if let error {
            log("Spotify disconnected (will auto-reconnect): \(error.localizedDescription)")
        } else {
            log("Disconnected from Spotify (will auto-reconnect).")
        }
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate

extension SpotifyVibeManager: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        updatePlayerState(from: playerState)

        let trackURI = playerState.track.uri
        if let source = resolveBlendSource(for: trackURI) {
            DispatchQueue.main.async { [weak self] in
                self?.currentBlendSource = source
            }
        }

        log("Player state updated. Track URI: \(trackURI)")
    }
}
#endif
