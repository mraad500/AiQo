import Foundation

/// Centralized Spotify playlist configuration for the My Vibe feature.
/// All playlist URIs are maintained here instead of being hardcoded in view support logic.
enum VibeSpotifyConfig {

    private static let playlistURIs: [VibeMode: String] = [
        .awakening: "spotify:playlist:37i9dQZF1DX3rxVfibe1L0",
        .deepFocus:  "spotify:playlist:37i9dQZF1DWZeKCadgRdKQ",
        .egoDeath:   "spotify:playlist:37i9dQZF1DWU0ScTcjJBdj",
        .energy:     "spotify:playlist:37i9dQZF1DX76Wlfdnj7AP",
        .recovery:   "spotify:playlist:37i9dQZF1DX4sWSpwq3LiO",
    ]

    static func playlistURI(for mode: VibeMode) -> String {
        guard let uri = playlistURIs[mode] else {
            assertionFailure("Missing Spotify playlist URI for mode: \(mode.rawValue)")
            return ""
        }
        return uri
    }
}
