import AVFoundation
import Foundation
import os.log
internal import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class CaptainVoiceService: NSObject, ObservableObject {
    static let shared = CaptainVoiceService()

    @Published private(set) var isSpeaking = false

    private enum API {
        static let voiceID = "UgBBYS2sOqTuMpoF3BR0"
        static let apiKey = "sk_71d34e347f0d6efec6c82ccbaeb918251babfddbec9669e7"
        static let modelID = "eleven_multilingual_v2"
        static let baseURL = "https://api.elevenlabs.io/v1/text-to-speech/"
    }

    private struct TTSRequestBody: Encodable {
        let text: String
        let model_id: String
    }

    private let audioSession = AVAudioSession.sharedInstance()
    private let audioManager = AiQoAudioManager.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainVoiceService"
    )

    private var audioPlayer: AVAudioPlayer?
    private var playContinuation: CheckedContinuation<Void, Never>?
    private var hasActiveSpeechSession = false
    private var externalMixedPlaybackClients = 0

    private override init() {
        super.init()
    }

    func speak(text: String) async {
        let sanitizedText = sanitizedSpeechText(text)
        guard !sanitizedText.isEmpty else { return }

        stopSpeaking()

        do {
            let audioData = try await fetchSpeechAudio(for: sanitizedText)
            try beginSpeechSession()

            let nextPlayer = try AVAudioPlayer(data: audioData)
            nextPlayer.delegate = self
            nextPlayer.prepareToPlay()

            guard nextPlayer.play() else {
                throw CaptainVoiceError.playbackStartFailed
            }

            audioPlayer = nextPlayer
            isSpeaking = true

            await withCheckedContinuation { continuation in
                playContinuation = continuation
            }
        } catch {
            logger.error("captain_voice_failed error=\(error.localizedDescription, privacy: .public)")
            completeCurrentPlayback()
            endSpeechSession()
        }
    }

    func speakAndWait(text: String) async {
        await speak(text: text)
    }

    func stopSpeaking() {
        completeCurrentPlayback()

        guard let audioPlayer else {
            endSpeechSession()
            return
        }

        audioPlayer.stop()
        self.audioPlayer = nil
        endSpeechSession()
    }

    func generateAndSpeakWorkoutPrompt(
        liveHR: Int,
        zoneBounds: ClosedRange<Int>,
        distance: Double
    ) async {
        let workoutPrompt = await generatedWorkoutPrompt(
            liveHR: liveHR,
            zoneBounds: zoneBounds,
            distance: distance
        )

        await speak(text: workoutPrompt)
    }

    func beginExternalMixedPlayback() {
        externalMixedPlaybackClients += 1
    }

    func endExternalMixedPlayback() {
        externalMixedPlaybackClients = max(0, externalMixedPlaybackClients - 1)
    }

    private func fetchSpeechAudio(for text: String) async throws -> Data {
        guard let url = URL(string: API.baseURL + API.voiceID) else {
            throw CaptainVoiceError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(API.apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TTSRequestBody(text: text, model_id: API.modelID)
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CaptainVoiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let responseText = String(data: data, encoding: .utf8) ?? "No response body"
            throw CaptainVoiceError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: responseText
            )
        }

        return data
    }

    private func sanitizedSpeechText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginSpeechSession() throws {
        audioManager.beginSpeechDucking()
        hasActiveSpeechSession = true

        try audioSession.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
        )
        try audioSession.setActive(true)
    }

    private func endSpeechSession() {
        guard hasActiveSpeechSession else {
            isSpeaking = false
            return
        }

        hasActiveSpeechSession = false
        isSpeaking = false
        audioManager.endSpeechDucking()

        if audioManager.isPlaying {
            audioManager.refreshAudioSessionConfiguration()
        } else if externalMixedPlaybackClients > 0 {
            try? audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? audioSession.setActive(true)
        } else {
            try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func completeCurrentPlayback() {
        playContinuation?.resume()
        playContinuation = nil
    }

    private func generatedWorkoutPrompt(
        liveHR: Int,
        zoneBounds: ClosedRange<Int>,
        distance: Double
    ) async -> String {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default

            if model.availability == .available {
                let instructions = """
                You are Captain Hammoudi, an elite Iraqi AI coach in the user's ear. LIVE DATA: HR is \(liveHR). Zone 2 is \(zoneBounds). Distance: \(String(format: "%.2f", distance)) km. RULES: Generate EXACTLY ONE short sentence to be spoken aloud. Use pure Iraqi Arabic (e.g., 'يا بطل', 'هسه', 'عوف'). If HR is above Zone 2, tell them to slow down and breathe. Mention their exact HR.
                """

                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let response = try await session.respond(to: "Generate the spoken cue now.")
                    let generatedText = sanitizedSpeechText(response.content)

                    if !generatedText.isEmpty {
                        return generatedText
                    }
                } catch {
                    logger.error("captain_workout_voice_generation_failed error=\(error.localizedDescription, privacy: .public)")
                }
            }
        }
#endif

        return fallbackWorkoutPrompt(
            liveHR: liveHR,
            zoneBounds: zoneBounds,
            distance: distance
        )
    }

    private func fallbackWorkoutPrompt(
        liveHR: Int,
        zoneBounds: ClosedRange<Int>,
        distance: Double
    ) -> String {
        if liveHR > zoneBounds.upperBound {
            return "يا بطل، نبضك \(liveHR)، هسه هدّي السرعة وخذ نفس أعمق حتى ترجع للزون."
        }

        if liveHR < zoneBounds.lowerBound {
            return "يا بطل، نبضك \(liveHR)، هسه زيد الإيقاع شوي حتى تدخل Zone 2 بثبات."
        }

        return "يا بطل، نبضك \(liveHR)، هيج مضبوط وخلك ثابت، واصل \(String(format: "%.2f", distance)) كيلو."
    }
}

extension CaptainVoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor in
            audioPlayer = nil
            completeCurrentPlayback()
            endSpeechSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                logger.error("captain_voice_decode_failed error=\(error.localizedDescription, privacy: .public)")
            }
            audioPlayer = nil
            completeCurrentPlayback()
            endSpeechSession()
        }
    }
}

private enum CaptainVoiceError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)
    case playbackStartFailed

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Captain voice endpoint is invalid."
        case .invalidResponse:
            return "Captain voice returned an invalid response."
        case let .requestFailed(statusCode, message):
            return "Captain voice request failed with status \(statusCode): \(message)"
        case .playbackStartFailed:
            return "Captain voice audio could not start playing."
        }
    }
}
