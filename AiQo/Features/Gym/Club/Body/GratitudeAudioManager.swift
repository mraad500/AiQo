import AVFoundation
import Combine
import Foundation
import UIKit

enum GratitudeSessionLanguage: Sendable, Equatable {
    case arabic
    case english

    init(coachLanguageRaw: String, fallback: AppLanguage) {
        let normalized = coachLanguageRaw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "en", "english":
            self = .english
        case "ar", "arabic", "العربية":
            self = .arabic
        default:
            self = fallback == .english ? .english : .arabic
        }
    }

    var speechVoiceCode: String {
        switch self {
        case .arabic:
            return "ar-SA"
        case .english:
            return "en-US"
        }
    }
}

@MainActor
final class GratitudeAudioManager: NSObject, ObservableObject {
    static let musicVolume: Float = 0.3

    private let audioSession = AVAudioSession.sharedInstance()
    private let voiceRouter = CaptainVoiceRouter.shared

    private var backgroundPlayer: AVAudioPlayer?
    private var speechTask: Task<Void, Never>?

    func startSessionAudio() {
        configureAudioSession()

        if backgroundPlayer == nil {
            backgroundPlayer = makeBackgroundPlayer()
        }

        guard let backgroundPlayer else { return }

        if !backgroundPlayer.isPlaying {
            backgroundPlayer.currentTime = 0
            backgroundPlayer.volume = 0
            backgroundPlayer.play()
            backgroundPlayer.setVolume(Self.musicVolume, fadeDuration: 0.8)
        }
    }

    func speak(_ text: String, language: GratitudeSessionLanguage) {
        let sanitizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedText.isEmpty else { return }

        configureAudioSession()
        speechTask?.cancel()
        voiceRouter.stop()

        speechTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard !Task.isCancelled else { return }
            await voiceRouter.speak(text: sanitizedText, tier: .premium)
            speechTask = nil
        }
    }

    func stopAll() {
        speechTask?.cancel()
        speechTask = nil
        voiceRouter.stop()

        if let backgroundPlayer, backgroundPlayer.isPlaying {
            backgroundPlayer.setVolume(0, fadeDuration: 0.35)
            backgroundPlayer.stop()
            backgroundPlayer.currentTime = 0
            backgroundPlayer.volume = Self.musicVolume
        }

        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            diag.error("GratitudeAudioManager failed to deactivate audio session", error: error)
        }
    }

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            diag.error("GratitudeAudioManager failed to configure audio session", error: error)
        }
    }

    private func makeBackgroundPlayer() -> AVAudioPlayer? {
        do {
            if let bundleURL = Bundle.main.url(forResource: "SerotoninFlow", withExtension: "m4a") {
                let player = try AVAudioPlayer(contentsOf: bundleURL)
                player.numberOfLoops = -1
                player.volume = Self.musicVolume
                player.prepareToPlay()
                return player
            }

            if let dataAsset = NSDataAsset(name: "SerotoninFlow", bundle: .main) {
                let player = try AVAudioPlayer(data: dataAsset.data)
                player.numberOfLoops = -1
                player.volume = Self.musicVolume
                player.prepareToPlay()
                return player
            }
        } catch {
            diag.error("GratitudeAudioManager failed to create background player", error: error)
        }

        return nil
    }

}
