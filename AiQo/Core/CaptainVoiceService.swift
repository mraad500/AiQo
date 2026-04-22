import AVFoundation
import Foundation
import os.log
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
final class CaptainVoiceService: NSObject, ObservableObject {
    static let shared = CaptainVoiceService()

    @Published private(set) var isSpeaking = false
    /// v1.1 — surfaces TTS health to the chat view so the speaker icon dims
    /// when playback is unavailable. Flips false on failure, flips back true
    /// next time audio playback succeeds.
    @Published private(set) var isTTSAvailable = true
    /// Transient Arabic status surfaced above the composer when TTS fails.
    /// Cleared automatically after ~2.5s. Chat view observes this.
    @Published private(set) var displayedToast: String?

    private let audioSession = AVAudioSession.sharedInstance()
    private let audioManager = AiQoAudioManager.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainVoiceService"
    )
    private let speechSynthesizer = AVSpeechSynthesizer()

    private var playContinuation: CheckedContinuation<Void, Never>?
    private var hasActiveSpeechSession = false
    private var externalMixedPlaybackClients = 0
    private var activeSpeechSequence = 0
    private var toastDismissalTask: Task<Void, Never>?

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
            isTTSAvailable = true

            guard speechSequence == activeSpeechSequence else { return }

            speechSynthesizer.speak(makeUtterance(for: sanitizedText))

            await awaitPlaybackCompletion(timeout: 60)
        } catch {
            if speechSequence == activeSpeechSequence {
                logger.error("captain_voice_failed error=\(error.localizedDescription, privacy: .public)")
                completeCurrentPlayback()
                endSpeechSession()
                isTTSAvailable = false
                let arabic = AppSettingsStore.shared.appLanguage == .arabic
                presentToast(arabic ? "الصوت غير متاح حالياً" : "Audio is unavailable right now")
            }
        }
    }

    private func presentToast(_ message: String) {
        displayedToast = message
        toastDismissalTask?.cancel()
        toastDismissalTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.displayedToast = nil }
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

    /// No-op retained for callers that still invoke voice pre-warming. The app now
    /// uses only the on-device AVSpeechSynthesizer, so there is nothing to pre-cache.
    func preCacheVoices() async {}

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

    private func awaitPlaybackCompletion(timeout: TimeInterval) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { continuation in
                    self.playContinuation = continuation
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            }

            await group.next()
            group.cancelAll()
        }

        completeCurrentPlayback()
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

extension CaptainVoiceService: AVSpeechSynthesizerDelegate {
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
}
