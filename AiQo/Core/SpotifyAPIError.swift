import Foundation

/// Thrown by the Web-API paths inside SpotifyVibeManager.
/// Internal type — callers translate to a user-facing message if needed.
enum SpotifyAPIError: Error, Equatable {
    case authExpired
    case rateLimited
    case forbidden
    case networkUnavailable
    case unknown(String)
}

/// One track returned from `/v1/me/top/tracks` with full display metadata.
struct SpotifyTopTrack: Equatable {
    let uri: String
    let name: String
    let artist: String
    let imageURL: URL?
}

extension Notification.Name {
    /// Fires whenever the Spotify player transitions to a new track URI.
    /// Callers receive the URI in `userInfo["uri"] as? String`.
    /// Declared here (outside any `#if targetEnvironment` block) so the
    /// simulator stub and real-device build both see the same symbol.
    static let spotifyPlayerTrackChanged = Notification.Name("spotifyPlayerTrackChanged")
}
