import AVFoundation
import Foundation
import UIKit
internal import Combine

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
    static let speechVolume: Float = 0.65

    private let audioSession = AVAudioSession.sharedInstance()
    private let speechSynthesizer = AVSpeechSynthesizer()

    private var backgroundPlayer: AVAudioPlayer?
    private var spokenAudioPlayer: AVAudioPlayer?
    private var speechTask: Task<Void, Never>?

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

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

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        if spokenAudioPlayer?.isPlaying == true {
            spokenAudioPlayer?.stop()
        }
        spokenAudioPlayer = nil

        speechTask = Task { @MainActor [weak self] in
            guard let self else { return }

            if CaptainVoiceAPI.isConfigured {
                do {
                    let audioData = try await CaptainVoiceAPI.synthesizeSpeech(for: sanitizedText)
                    guard !Task.isCancelled else { return }
                    try playRemoteSpeech(data: audioData)
                    speechTask = nil
                    return
                } catch {
                    guard !Task.isCancelled else { return }
                    print("GratitudeAudioManager: Remote voice failed - \(error.localizedDescription)")
                }
            }

            guard !Task.isCancelled else { return }
            playLocalSpeech(sanitizedText, language: language)
            speechTask = nil
        }
    }

    func stopAll() {
        speechTask?.cancel()
        speechTask = nil
        speechSynthesizer.stopSpeaking(at: .immediate)

        if spokenAudioPlayer?.isPlaying == true {
            spokenAudioPlayer?.stop()
        }
        spokenAudioPlayer = nil

        if let backgroundPlayer, backgroundPlayer.isPlaying {
            backgroundPlayer.setVolume(0, fadeDuration: 0.35)
            backgroundPlayer.stop()
            backgroundPlayer.currentTime = 0
            backgroundPlayer.volume = Self.musicVolume
        }

        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("GratitudeAudioManager: Failed to deactivate audio session - \(error.localizedDescription)")
        }
    }

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("GratitudeAudioManager: Failed to configure audio session - \(error.localizedDescription)")
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
            print("GratitudeAudioManager: Failed to create background player - \(error.localizedDescription)")
        }

        return nil
    }

    private func playLocalSpeech(_ text: String, language: GratitudeSessionLanguage) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.speechVoiceCode)
        utterance.volume = Self.speechVolume
        utterance.rate = language == .arabic ? 0.45 : 0.47
        utterance.pitchMultiplier = 0.94
        utterance.postUtteranceDelay = 0.2

        speechSynthesizer.speak(utterance)
    }

    private func playRemoteSpeech(data: Data) throws {
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.volume = Self.speechVolume
        player.prepareToPlay()

        guard player.play() else {
            throw NSError(
                domain: "GratitudeAudioManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to play gratitude voice audio."]
            )
        }

        spokenAudioPlayer = player
    }
}

extension GratitudeAudioManager: AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor in
            spokenAudioPlayer = nil
            speechTask = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: Error?
    ) {
        Task { @MainActor in
            spokenAudioPlayer = nil
            speechTask = nil
            if let error {
                print("GratitudeAudioManager: Voice decode failed - \(error.localizedDescription)")
            }
        }
    }
}
