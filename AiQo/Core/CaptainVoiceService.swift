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

    private let audioSession = AVAudioSession.sharedInstance()
    private let audioManager = AiQoAudioManager.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainVoiceService"
    )
    private let speechSynthesizer = AVSpeechSynthesizer()

    private let voiceCache = CaptainVoiceCache.shared

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

            // Wait for AVSpeechSynthesizer delegate with a safety timeout (max 60s for long text)
            await awaitPlaybackCompletion(timeout: 60)
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

    /// Maximum time to wait for ElevenLabs TTS before falling back to AVSpeechSynthesizer.
    /// The network call itself has an 8-second timeout in CaptainVoiceAPI; this is the outer
    /// safety net that also covers audio decoding and playback start.
    private static let remoteSpeechTimeout: TimeInterval = 10

    /// **Fix (2026-04-08):** Added timeout race around the entire remote speech path.
    /// Before: if ElevenLabs hung (QUIC retry loop) or the audio player delegate never fired,
    /// the `withCheckedContinuation` would suspend forever, leaving `isSpeaking = true` and
    /// the Main Thread blocked. Now:
    /// 1. The ElevenLabs call races against a 10-second deadline
    /// 2. On timeout or any error, returns `false` immediately → caller falls through to AVSpeech
    /// 3. The continuation has a safety timeout so it can never leak
    private func playRemoteSpeechIfAvailable(for text: String, sequence: Int) async -> Bool {
        // Check voice cache first (instant, offline)
        if let cachedAudio = await voiceCache.matchedAudio(for: text) {
            guard sequence == activeSpeechSequence else { return true }
            do {
                try playRemoteAudio(data: cachedAudio)
                await awaitPlaybackCompletion(timeout: Self.remoteSpeechTimeout)
                return true
            } catch {
                logger.error("captain_voice_cache_playback_failed error=\(error.localizedDescription, privacy: .public)")
            }
        }

        guard CaptainVoiceAPI.isConfigured else { return false }

        do {
            // Race the network call against a strict timeout
            let audioData = try await withThrowingTimeout(seconds: Self.remoteSpeechTimeout) {
                try await CaptainVoiceAPI.synthesizeSpeech(for: text)
            }
            guard sequence == activeSpeechSequence else { return true }

            try playRemoteAudio(data: audioData)
            await awaitPlaybackCompletion(timeout: 30) // audio itself can play for up to 30s

            return true
        } catch {
            guard sequence == activeSpeechSequence else { return true }

            logger.error("captain_voice_remote_failed error=\(error.localizedDescription, privacy: .public)")
            audioPlayer?.stop()
            audioPlayer = nil
            completeCurrentPlayback()
            return false
        }
    }

    /// Waits for the audio player delegate to fire, with a hard timeout to prevent
    /// the continuation from leaking forever if the delegate never calls back.
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

            // Whichever finishes first wins — cancel the other
            await group.next()
            group.cancelAll()
        }

        // If the timeout won, clean up the leaked continuation
        completeCurrentPlayback()
    }

    /// Races an async operation against a deadline. Throws on timeout.
    private func withThrowingTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw CancellationError()
            }
            guard let result = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return result
        }
    }

    /// Pre-caches all common Captain Hamoudi phrases via ElevenLabs.
    /// Call this on WiFi (e.g., after first login or in background).
    func preCacheVoices() async {
        await voiceCache.preCacheAllPhrases()
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
