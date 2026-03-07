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

    private let audioSession = AVAudioSession.sharedInstance()
    private let audioManager = AiQoAudioManager.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainVoiceService"
    )
    private let speechSynthesizer = AVSpeechSynthesizer()

    private var audioPlayer: AVAudioPlayer?
    private var playContinuation: CheckedContinuation<Void, Never>?
    private var hasActiveSpeechSession = false
    private var externalMixedPlaybackClients = 0
    private var activeSpeechSequence = 0

    private override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func speak(text: String) async {
        let sanitizedText = sanitizedSpeechText(text)
        guard !sanitizedText.isEmpty else { return }

        stopSpeaking()
        let speechSequence = nextSpeechSequence()

        do {
            try beginSpeechSession()
            isSpeaking = true

            if await playRemoteSpeechIfAvailable(for: sanitizedText, sequence: speechSequence) {
                return
            }

            guard speechSequence == activeSpeechSequence else { return }

            speechSynthesizer.speak(makeUtterance(for: sanitizedText))

            await withCheckedContinuation { continuation in
                playContinuation = continuation
            }
        } catch {
            if speechSequence == activeSpeechSequence {
                logger.error("captain_voice_failed error=\(error.localizedDescription, privacy: .public)")
                completeCurrentPlayback()
                endSpeechSession()
            }
        }
    }

    func speakAndWait(text: String) async {
        await speak(text: text)
    }

    func stopSpeaking() {
        invalidateActiveSpeech()
        completeCurrentPlayback()

        if speechSynthesizer.isSpeaking || speechSynthesizer.isPaused {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        audioPlayer = nil

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

    private func makeUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice(for: text)
        utterance.rate = containsArabicCharacters(in: text) ? 0.44 : 0.48
        utterance.pitchMultiplier = 0.96
        utterance.postUtteranceDelay = 0.05
        return utterance
    }

    private func preferredVoice(for text: String) -> AVSpeechSynthesisVoice? {
        let languageCandidates = containsArabicCharacters(in: text)
            ? ["ar-SA", "ar-AE", "ar"]
            : ["en-US", "en-GB"]

        for language in languageCandidates {
            if let voice = AVSpeechSynthesisVoice(language: language) {
                return voice
            }
        }

        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    private func containsArabicCharacters(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
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

    private func nextSpeechSequence() -> Int {
        activeSpeechSequence += 1
        return activeSpeechSequence
    }

    private func invalidateActiveSpeech() {
        activeSpeechSequence += 1
    }

    private func playRemoteSpeechIfAvailable(for text: String, sequence: Int) async -> Bool {
        guard CaptainVoiceAPI.isConfigured else { return false }

        do {
            let audioData = try await CaptainVoiceAPI.synthesizeSpeech(for: text)
            guard sequence == activeSpeechSequence else { return true }

            try playRemoteAudio(data: audioData)

            await withCheckedContinuation { continuation in
                playContinuation = continuation
            }

            return true
        } catch {
            guard sequence == activeSpeechSequence else { return true }

            logger.error("captain_voice_remote_failed error=\(error.localizedDescription, privacy: .public)")
            audioPlayer = nil
            return false
        }
    }

    private func playRemoteAudio(data: Data) throws {
        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.volume = 1
        player.prepareToPlay()

        guard player.play() else {
            throw NSError(
                domain: "CaptainVoiceService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to play Captain voice audio."]
            )
        }

        audioPlayer = player
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

extension CaptainVoiceService: AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            completeCurrentPlayback()
            endSpeechSession()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            completeCurrentPlayback()
            endSpeechSession()
        }
    }

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
                logger.error("captain_voice_audio_decode_failed error=\(error.localizedDescription, privacy: .public)")
            }
            audioPlayer = nil
            completeCurrentPlayback()
            endSpeechSession()
        }
    }
}
