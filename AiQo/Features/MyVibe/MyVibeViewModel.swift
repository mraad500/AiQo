import Foundation
import Combine
import SwiftUI

@MainActor
final class MyVibeViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var currentState: DailyVibeState
    @Published private(set) var isPlaying = false
    @Published private(set) var bioFrequencyStatus: String = "Ready"
    @Published private(set) var spotifyTrackName: String = "Not Playing"
    @Published private(set) var spotifyArtistName: String = ""
    @Published private(set) var isSpotifyConnected = false
    @Published private(set) var spotifyOverrideName: String?
    @Published private(set) var isDJModeActive = false
    @Published var showDJChat = false
    @Published var djSearchText = ""

    // MARK: - Dependencies

    let orchestrator = VibeOrchestrator.shared
    private let vibeEngine = VibeAudioEngine.shared
    private let spotifyManager = SpotifyVibeManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        self.currentState = DailyVibeState.current()
        bindOrchestrator()
        bindSpotify()
        bindVibeEngine()
    }

    // MARK: - Actions

    func togglePlayback() {
        if isPlaying {
            orchestrator.pause()
            isPlaying = false
        } else if orchestrator.isActive {
            orchestrator.resume()
            isPlaying = true
        } else {
            orchestrator.activate(mixWithOthers: true)
            isPlaying = true
        }
    }

    func selectState(_ state: DailyVibeState) {
        currentState = state
        orchestrator.forceState(state)
        isPlaying = true
    }

    func stop() {
        orchestrator.deactivate()
        isPlaying = false
    }

    func submitDJSearch() {
        let text = djSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // Forward to DJ Hamoudi chat (handled by the view via CaptainViewModel)
        djSearchText = ""
    }

    // MARK: - Bindings

    private func bindOrchestrator() {
        orchestrator.$currentState
            .receive(on: RunLoop.main)
            .assign(to: &$currentState)

        orchestrator.$isActive
            .receive(on: RunLoop.main)
            .assign(to: &$isPlaying)

        orchestrator.$overridePlaylistName
            .receive(on: RunLoop.main)
            .assign(to: &$spotifyOverrideName)

        orchestrator.$spotifyOverrideActive
            .receive(on: RunLoop.main)
            .assign(to: &$isDJModeActive)
    }

    private func bindSpotify() {
        spotifyManager.$currentTrackName
            .receive(on: RunLoop.main)
            .assign(to: &$spotifyTrackName)

        spotifyManager.$currentArtistName
            .receive(on: RunLoop.main)
            .assign(to: &$spotifyArtistName)

        spotifyManager.$isConnected
            .receive(on: RunLoop.main)
            .assign(to: &$isSpotifyConnected)
    }

    private func bindVibeEngine() {
        vibeEngine.$currentState
            .map(\.detailText)
            .receive(on: RunLoop.main)
            .assign(to: &$bioFrequencyStatus)
    }
}
