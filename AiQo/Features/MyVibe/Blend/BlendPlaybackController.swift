import Foundation
import Combine

/// Controls blend playback through the existing SpotifyVibeManager.
/// Tracks only URIs → source mapping in memory. Never stores track metadata.
@MainActor
final class BlendPlaybackController: ObservableObject {

    @Published private(set) var currentSource: BlendSourceTag?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var error: BlendError?
    @Published private(set) var isBuilding: Bool = false

    /// Current track name from Spotify player state. In-memory only — NEVER persisted.
    @Published var currentTrackName: String? = nil
    /// Current artist name from Spotify player state. In-memory only — NEVER persisted.
    @Published var currentArtistName: String? = nil

    private var sourceLookup: [String: BlendSourceTag] = [:]
    private var queue: [BlendTrackItem] = []
    private let spotify = SpotifyVibeManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Observe playback state from SpotifyVibeManager
        spotify.$playbackState
            .receive(on: RunLoop.main)
            .map { $0 == .playing }
            .assign(to: &$isPlaying)

        // Observe blend source changes from player state
        spotify.$currentBlendSource
            .receive(on: RunLoop.main)
            .map { [weak self] source -> BlendSourceTag? in
                source ?? self?.currentSource
            }
            .assign(to: &$currentSource)

        // Observe track name from SpotifyVibeManager's playerStateDidChange updates
        spotify.$currentTrackName
            .receive(on: RunLoop.main)
            .map { [weak self] name -> String? in
                guard let self, !self.queue.isEmpty else { return nil }
                return name == "Not Playing" ? nil : name
            }
            .assign(to: &$currentTrackName)

        // Observe artist name
        spotify.$currentArtistName
            .receive(on: RunLoop.main)
            .map { [weak self] name -> String? in
                guard let self, !self.queue.isEmpty else { return nil }
                return name.isEmpty ? nil : name
            }
            .assign(to: &$currentArtistName)
    }

    // MARK: - Playback Control

    /// Starts blend playback from a specific index (rotates the queue so `startIndex` plays first).
    func startBlend(tracks: [BlendTrackItem], startIndex: Int) {
        guard startIndex > 0, startIndex < tracks.count else {
            startBlend(tracks: tracks)
            return
        }

        // Rotate queue so startIndex becomes index 0
        let rotated = Array(tracks[startIndex...]) + Array(tracks[..<startIndex])
        startBlend(tracks: rotated)
    }

    func startBlend(tracks: [BlendTrackItem]) {
        guard spotify.isConnected else {
            error = .spotifyAppNotInstalled
            return
        }

        guard !tracks.isEmpty else { return }

        queue = tracks
        sourceLookup = [:]
        for track in tracks {
            sourceLookup[track.uri] = track.source
        }

        // Store lookup in SpotifyVibeManager for playerStateDidChange
        spotify.blendSourceLookup = sourceLookup

        error = nil
        currentSource = tracks.first?.source
        spotify.playBlendQueue(tracks)

        PrivacySanitizer.log("Blend playback started with \(tracks.count) tracks.")
    }

    func togglePlayPause() {
        if isPlaying {
            spotify.pauseVibe()
        } else if !queue.isEmpty {
            spotify.resumeVibe()
        }
    }

    func skipNext() {
        spotify.skipNext()
    }

    func skipPrevious() {
        spotify.skipPrevious()
    }

    func stop() {
        spotify.stopVibe()
        queue = []
        sourceLookup = [:]
        currentSource = nil
        currentTrackName = nil
        currentArtistName = nil
    }

    func clearError() {
        error = nil
    }
}
