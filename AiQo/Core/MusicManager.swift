import Foundation
internal import Combine
import UIKit

class MusicManager: NSObject, ObservableObject {
    static let shared = MusicManager()

    @Published var isPlaying: Bool = false
    @Published var songTitle: String = "No Music Playing"
    @Published var artistName: String = "Select Vibe"
    @Published var artwork: UIImage? = nil

    func togglePlayPause() {}
    func nextTrack() {}
    func previousTrack() {}
    func connect() {}
    func handleSpotifyURL(_ url: URL) { _ = url }
}
