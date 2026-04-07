import Foundation
import Combine

/// Coordinates automatic time-based state transitions and DJ Hamoudi
/// overrides across the ``VibeAudioEngine`` (local bio-frequency) and
/// ``SpotifyVibeManager`` (Spotify playlist layer).
///
/// Design:
/// - The local frequency always follows the current ``DailyVibeState``.
/// - Spotify can be overridden by DJ Hamoudi without stopping the frequency.
/// - A 30-second scheduler polls for day-part transitions.
@MainActor
final class VibeOrchestrator: ObservableObject {
    static let shared = VibeOrchestrator()

    // MARK: - Published State

    @Published private(set) var currentState: DailyVibeState
    @Published private(set) var isActive = false
    @Published private(set) var spotifyOverrideActive = false
    @Published private(set) var overridePlaylistName: String?

    // MARK: - Dependencies

    private let vibeEngine = VibeAudioEngine.shared
    private let spotifyManager = SpotifyVibeManager.shared
    private let audioManager = AiQoAudioManager.shared

    // MARK: - Internal

    private var schedulerTimer: DispatchSourceTimer?
    private let schedulerQueue = DispatchQueue(label: "com.aiqo.vibeOrchestrator.scheduler", qos: .utility)

    private init() {
        self.currentState = DailyVibeState.current()
    }

    // MARK: - Lifecycle

    /// Starts both the local bio-frequency and the matching Spotify playlist.
    func activate(mixWithOthers: Bool = true) {
        let state = DailyVibeState.current()
        currentState = state

        // Start local bio-frequency via the audio engine
        var profile = vibeEngine.currentProfile
        let dayPart = VibeDayPart.current()
        profile.set(state.vibeMode, for: dayPart)
        vibeEngine.start(profile: profile, mixWithOthers: mixWithOthers)

        // Start matching Spotify playlist (non-blocking; silently fails on simulator)
        spotifyManager.playVibe(uri: state.spotifyURI, vibeTitle: state.title)
        spotifyOverrideActive = false
        overridePlaylistName = nil

        isActive = true
        startScheduler()
    }

    /// Stops all playback and the scheduler.
    func deactivate() {
        stopScheduler()
        vibeEngine.stop()
        spotifyManager.stopVibe()
        spotifyOverrideActive = false
        overridePlaylistName = nil
        isActive = false
    }

    /// Pauses both layers.
    func pause() {
        vibeEngine.pause()
        spotifyManager.pauseVibe()
    }

    /// Resumes both layers.
    func resume() {
        vibeEngine.resume()
        if spotifyOverrideActive {
            spotifyManager.resumeVibe()
        } else {
            spotifyManager.playVibe(uri: currentState.spotifyURI, vibeTitle: currentState.title)
        }
    }

    // MARK: - DJ Hamoudi Override

    /// DJ Hamoudi can override **only the Spotify playlist** without
    /// interrupting the local bio-frequency layer.
    func overrideSpotifyPlaylist(uri: String, name: String) {
        spotifyOverrideActive = true
        overridePlaylistName = name
        spotifyManager.playVibe(uri: uri, vibeTitle: name)
    }

    /// Clears the DJ override and returns Spotify to the current state's playlist.
    func clearSpotifyOverride() {
        spotifyOverrideActive = false
        overridePlaylistName = nil
        spotifyManager.playVibe(uri: currentState.spotifyURI, vibeTitle: currentState.title)
    }

    /// Manually forces a specific state (used from the timeline tap).
    func forceState(_ state: DailyVibeState) {
        guard state != currentState || !isActive else { return }
        currentState = state

        vibeEngine.switch(to: state.vibeMode)

        if !spotifyOverrideActive {
            spotifyManager.playVibe(uri: state.spotifyURI, vibeTitle: state.title)
        }

        if !isActive {
            isActive = true
            startScheduler()
        }
    }

    // MARK: - Auto Scheduler

    private func startScheduler() {
        stopScheduler()
        let timer = DispatchSource.makeTimerSource(queue: schedulerQueue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.checkForTransition()
            }
        }
        schedulerTimer = timer
        timer.resume()
    }

    private func stopScheduler() {
        schedulerTimer?.cancel()
        schedulerTimer = nil
    }

    private func checkForTransition() {
        guard isActive else { return }
        let newState = DailyVibeState.current()
        guard newState != currentState else { return }

        currentState = newState
        vibeEngine.switch(to: newState.vibeMode)

        // Only update Spotify if no DJ override is active
        if !spotifyOverrideActive {
            spotifyManager.playVibe(uri: newState.spotifyURI, vibeTitle: newState.title)
        }
    }
}
