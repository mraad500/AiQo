import Foundation
import Combine

enum BlendSheetState: Equatable {
    case empty
    case loading
    case playing
    case error(BlendError)
}

/// Manages blend-specific state only: state, queue, currentSource.
/// Live Spotify data (track name, artist, playback) is read directly
/// from SpotifyVibeManager by the view — no Combine mirroring needed.
@MainActor
final class HamoudiBlendViewModel: ObservableObject {
    @Published var state: BlendSheetState = .empty
    @Published var queue: [BlendTrackItem] = []
    @Published var currentSource: BlendSourceTag? = nil

    private let spotify = SpotifyVibeManager.shared
    private let engine = BlendEngine()
    private var cancellables = Set<AnyCancellable>()
    private var isBuildingBlend = false

    init() {
        // Auto-build when Spotify connects and we have no queue.
        spotify.$isConnected
            .dropFirst()
            .removeDuplicates()
            .filter { $0 }
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.queue.isEmpty, self.state == .empty else { return }
                Task { [weak self] in await self?.buildAndPlay() }
            }
            .store(in: &cancellables)

        // Track blend source from player state changes.
        spotify.$currentBlendSource
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] source in
                self?.currentSource = source
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func onSheetAppear() async {
        let connected = await spotify.reconnectSilentlyIfPossible()

        if connected, let saved = BlendQueuePersistence.load(), !saved.isEmpty {
            queue = saved
            currentSource = saved.first?.source

            var lookup: [String: BlendSourceTag] = [:]
            for item in saved { lookup[item.uri] = item.source }
            spotify.blendSourceLookup = lookup

            let startIndex = Int.random(in: 0..<saved.count)
            startPlayback(tracks: saved, fromIndex: startIndex)

            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                spotify.fetchCurrentPlayerState()
            }
            return
        }

        state = .empty
    }

    // MARK: - Actions

    func connectSpotify() {
        spotify.connect()
    }

    func buildAndPlay() async {
        guard !isBuildingBlend else { return }
        isBuildingBlend = true
        defer { isBuildingBlend = false }

        state = .loading

        do {
            async let hamoudiURIs = spotify.fetchHamoudiPlaylistTracks()
            async let userURIs = spotify.fetchUserTopTracks()

            let (hamoudi, user) = try await (hamoudiURIs, userURIs)

            guard !hamoudi.isEmpty else {
                state = .error(.noMasterTracks)
                return
            }

            let config = BlendConfiguration(
                userShare: 0.6,
                totalTracks: 10,
                masterPlaylistId: "14YVMyaZsefyZMgEIIicao"
            )
            let blended = try await engine.build(
                userTopURIs: user,
                masterURIs: hamoudi,
                config: config
            )

            BlendQueuePersistence.save(blended)
            queue = blended
            currentSource = blended.first?.source

            var lookup: [String: BlendSourceTag] = [:]
            for item in blended { lookup[item.uri] = item.source }
            spotify.blendSourceLookup = lookup

            startPlayback(tracks: blended, fromIndex: 0)

            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                spotify.fetchCurrentPlayerState()
            }

        } catch let error as BlendError {
            state = .error(error)
        } catch {
            state = .error(.unknown(error.localizedDescription))
        }
    }

    func regenerateBlend() async {
        BlendQueuePersistence.clear()
        queue = []
        currentSource = nil
        state = .empty
        await buildAndPlay()
    }

    func togglePlayPause() {
        if spotify.playbackState == .playing {
            spotify.pauseVibe()
        } else {
            spotify.resumeVibe()
        }
    }

    func skipNext() {
        spotify.skipNext()
    }

    func skipPrevious() {
        spotify.skipPrevious()
    }

    // MARK: - Computed

    var currentError: BlendError? {
        if case .error(let e) = state { return e }
        return nil
    }

    func dismissError() {
        state = .empty
    }

    // MARK: - Private

    private func startPlayback(tracks: [BlendTrackItem], fromIndex: Int) {
        guard !tracks.isEmpty, fromIndex < tracks.count else { return }

        spotify.playTrack(uri: tracks[fromIndex].uri)

        let remaining = Array(tracks[(fromIndex + 1)...]) + Array(tracks[..<fromIndex])
        for track in remaining {
            spotify.enqueueTrack(uri: track.uri)
        }

        state = .playing
        currentSource = tracks[fromIndex].source
    }
}
