import Foundation
import SpotifyiOS
internal import Combine
import UIKit

class MusicManager: NSObject, ObservableObject {
    static let shared = MusicManager()
    
    @Published var isPlaying: Bool = false
    @Published var songTitle: String = "No Music Playing"
    @Published var artistName: String = "Select Vibe"
    @Published var artwork: UIImage? = nil
    
    private let spotifyClientID = "YOUR_CLIENT_ID" // ضع الـ ID الخاص بك هنا
    private let spotifyRedirectURL = URL(string: "aiqo-spotify://callback")!
    
    lazy var configuration = SPTConfiguration(clientID: spotifyClientID, redirectURL: spotifyRedirectURL)
    
    lazy var appRemote: SPTAppRemote = {
        let remote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        remote.delegate = self
        return remote
    }()
    
    private override init() {
        super.init()
    }
    
    func togglePlayPause() {
        guard appRemote.isConnected else {
            connect()
            return
        }
        isPlaying ? appRemote.playerAPI?.pause(nil) : appRemote.playerAPI?.resume(nil)
    }
    
    func nextTrack() { appRemote.playerAPI?.skip(toNext: nil) }
    func previousTrack() { appRemote.playerAPI?.skip(toPrevious: nil) }
    
    func connect() {
        appRemote.authorizeAndPlayURI("")
    }
}

// MARK: - Spotify Delegate
// MARK: - Spotify Delegate
extension MusicManager: SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("✅ Connected to Spotify")
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { (_, error) in
            if let error = error { print("Error subscribing: \(error)") }
        })
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("🛑 Disconnected: \(error?.localizedDescription ?? "Unknown error")")
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("❌ Connection Failed: \(error?.localizedDescription ?? "Unknown error")")
    }
    // أضف هذه الدالة داخل كلاس MusicManager
    func handleSpotifyURL(_ url: URL) {
        let parameters = appRemote.authorizationParameters(from: url)
        
        if let accessToken = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = accessToken
            appRemote.connect()
        } else if let errorDescription = parameters?[SPTAppRemoteErrorDescriptionKey] {
            print("❌ Spotify Auth Error: \(errorDescription)")
        }
    }
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        DispatchQueue.main.async {
            self.isPlaying = !playerState.isPaused
            self.songTitle = playerState.track.name
            self.artistName = playerState.track.artist.name
            
            self.appRemote.imageAPI?.fetchImage(forItem: playerState.track, with: CGSize(width: 300, height: 300)) { (image, _) in
                if let img = image as? UIImage { self.artwork = img }
            }
        }
    }
}

