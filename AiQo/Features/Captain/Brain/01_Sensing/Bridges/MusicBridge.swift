import Foundation

/// Read-only music playback context for Brain/ consumers.
/// Thin wrapper — real Spotify / Apple Music integration lives in the feature layer
/// (`SpotifyVibeManager`, etc.) and will wire into this bridge in a later batch.
enum MusicBridge {
    struct NowPlaying: Sendable, Equatable {
        let trackTitle: String
        let artist: String
        let isPlaying: Bool
        let source: Source
    }

    enum Source: String, Sendable, Equatable {
        case spotify
        case appleMusic
        case unknown
        case none
    }

    /// Placeholder. Real implementation (BATCH 6+) wires into SPTAppRemote and
    /// `MPMusicPlayerController` — stubbed to nil for now so downstream consumers
    /// can code against the final API.
    static func nowPlaying() -> NowPlaying? {
        nil
    }
}
