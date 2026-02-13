import Foundation

final class SpotifyRemoteController: NSObject {
    static let shared = SpotifyRemoteController()

    var onPlayerState: ((Any) -> Void)?
    var onConnectedChanged: ((Bool) -> Void)?
    private(set) var isConnected: Bool = false {
        didSet { onConnectedChanged?(isConnected) }
    }

    func connect(accessToken: String) {
        _ = accessToken
        isConnected = false
    }

    func disconnect() { isConnected = false }
    func play(uri: String) { _ = uri }
    func togglePlayPause(isPlaying: Bool) { _ = isPlaying }
    func next() {}
    func prev() {}
    func subscribePlayerState() {}
}
