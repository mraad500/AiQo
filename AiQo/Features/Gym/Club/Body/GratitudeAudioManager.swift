import Combine
import Foundation

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
    static let musicVolume: Float = 0.25
    static let voiceVolume: Float = 0.85

    private static let backgroundTrackName = "SerotoninFlow"
    private static let backgroundTrackExtension = "m4a"

    private let voiceRouter = CaptainVoiceRouter.shared
    private let ambientAudio = AiQoAudioManager.shared

    private var speechTask: Task<Void, Never>?

    func startSessionAudio() {
        voiceRouter.setMiniMaxPlaybackVolume(Self.voiceVolume)
        ambientAudio.setVolume(Self.musicVolume)
        ambientAudio.playAmbient(
            trackName: Self.backgroundTrackName,
            fileExtension: Self.backgroundTrackExtension
        )
    }

    func speak(_ text: String, language: GratitudeSessionLanguage) {
        let sanitizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedText.isEmpty else { return }

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
        voiceRouter.setMiniMaxPlaybackVolume(1.0)
        ambientAudio.stopAmbient()
    }
}
