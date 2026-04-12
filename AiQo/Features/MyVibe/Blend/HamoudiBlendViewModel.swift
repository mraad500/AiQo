import Foundation
import Combine

@MainActor
final class HamoudiBlendViewModel: ObservableObject {
    @Published var isConnectedToSpotify: Bool = false
    @Published var isWebAPIAuthorized: Bool = false
    @Published var isBuilding: Bool = false
    @Published var error: BlendError?
    @Published var blendQueue: [BlendTrackItem] = []

    let playback = BlendPlaybackController()
    private let engine = BlendEngine()
    private let spotify: SpotifyVibeManager
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.spotify = SpotifyVibeManager.shared

        spotify.$isConnected
            .receive(on: RunLoop.main)
            .assign(to: &$isConnectedToSpotify)

        spotify.$isWebAPIAuthorized
            .receive(on: RunLoop.main)
            .assign(to: &$isWebAPIAuthorized)
    }

    // MARK: - Lifecycle

    /// Called on sheet appear. Attempts silent reconnect, then restores a persisted same-day queue.
    func onSheetAppear() async {
        // 1. Try silent reconnect if not already connected
        if !isConnectedToSpotify {
            let reconnected = await spotify.reconnectSilentlyIfPossible()
            if reconnected {
                PrivacySanitizer.log("Blend sheet: silent reconnect succeeded — skipping connect state.")
            }
        }

        // 2. Try to restore a same-day persisted queue
        guard blendQueue.isEmpty else { return }
        if let restored = BlendQueuePersistence.load() {
            blendQueue = restored.tracks

            // Pick a random start index (not always index 0) for variety on reopen
            let randomIndex = Int.random(in: 0..<restored.tracks.count)

            if isConnectedToSpotify {
                playback.startBlend(tracks: restored.tracks, startIndex: randomIndex)
            }

            PrivacySanitizer.log("Blend sheet: restored \(restored.tracks.count) tracks, starting at index \(randomIndex).")
        }
    }

    // MARK: - Actions

    func connectSpotify() {
        spotify.connect()
    }

    func authorizeWebAPI() {
        spotify.authorizeWebAPI()
    }

    func disconnectSpotify() {
        spotify.logoutSpotify()
        blendQueue = []
        BlendQueuePersistence.clear()
        playback.stop()
    }

    /// Called when user taps "مزيج جديد" — clears persisted queue, then rebuilds.
    func regenerateBlend() async {
        BlendQueuePersistence.clear()
        blendQueue = []
        playback.stop()
        await buildAndPlay()
    }

    func buildAndPlay() async {
        isBuilding = true
        error = nil

        do {
            // Fetch user tracks (required)
            let user = try await spotify.fetchTopTrackURIs()

            // Fetch master playlist (optional — if private/unavailable, use 100% user tracks)
            var master: [String] = []
            do {
                master = try await spotify.fetchMasterPlaylistURIs(
                    playlistId: BlendConfiguration.default.masterPlaylistId
                )
            } catch {
                PrivacySanitizer.log("Master playlist unavailable, using 100%% user tracks: \(error.localizedDescription)")
            }

            // If no master tracks, set userShare to 1.0 (all user tracks)
            let effectiveUserShare = master.isEmpty ? 1.0 : featureFlagBlendRatio
            let config = BlendConfiguration(
                userShare: effectiveUserShare,
                totalTracks: BlendConfiguration.default.totalTracks,
                masterPlaylistId: BlendConfiguration.default.masterPlaylistId
            )

            let tracks = try await engine.build(
                userTopURIs: user,
                masterURIs: master.isEmpty ? user : master,
                config: config
            )

            blendQueue = tracks
            playback.startBlend(tracks: tracks)
            BlendQueuePersistence.save(tracks)

            PrivacySanitizer.log("Blend built and started: \(tracks.count) tracks.")
        } catch let blendError as BlendError {
            self.error = blendError
            PrivacySanitizer.log("Blend build failed: \(blendError.errorDescription ?? "unknown")")
        } catch {
            self.error = .unknown(error.localizedDescription)
            PrivacySanitizer.log("Blend build failed: \(error.localizedDescription)")
        }

        isBuilding = false
    }

    // MARK: - Config

    private var featureFlagBlendRatio: Double {
        if let ratio = Bundle.main.infoDictionary?["HAMOUDI_BLEND_RATIO"] as? Double {
            return ratio
        }
        return BlendConfiguration.default.userShare
    }
}
