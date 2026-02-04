import Foundation
import SpotifyiOS
import UIKit

final class SpotifyRemoteController: NSObject {
    static let shared = SpotifyRemoteController()

    private let clientID = "YOUR_CLIENT_ID"
    private let redirectURL = URL(string: "aiqo-spotify://callback")!

    private lazy var configuration: SPTConfiguration = {
        let c = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        // مهم: ما نخلي client secret بالموبايل
        return c
    }()

    private lazy var appRemote: SPTAppRemote = {
        let r = SPTAppRemote(configuration: configuration, logLevel: .none)
        r.delegate = self
        return r
    }()

    // Outputs
    var onPlayerState: ((SPTAppRemotePlayerState) -> Void)?
    var onConnectedChanged: ((Bool) -> Void)?

    private(set) var isConnected: Bool = false {
        didSet { onConnectedChanged?(isConnected) }
    }

    func connect(accessToken: String) {
        appRemote.connectionParameters.accessToken = accessToken
        if !appRemote.isConnected {
            appRemote.connect()
        }
    }

    func disconnect() {
        if appRemote.isConnected { appRemote.disconnect() }
    }

    func play(uri: String) {
        appRemote.playerAPI?.play(uri, callback: nil)
    }

    func togglePlayPause(isPlaying: Bool) {
        if isPlaying {
            appRemote.playerAPI?.pause(nil)
        } else {
            appRemote.playerAPI?.resume(nil)
        }
    }

    func next() { appRemote.playerAPI?.skip(toNext: nil) }
    func prev() { appRemote.playerAPI?.skip(toPrevious: nil) }

    func subscribePlayerState() {
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { _, _ in })
    }
}

extension SpotifyRemoteController: SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        isConnected = true
        subscribePlayerState()
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        isConnected = false
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        isConnected = false
    }

    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        onPlayerState?(playerState)
    }
}
