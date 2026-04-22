import AVFoundation
import Foundation
import os.log

@MainActor
final class MiniMaxTTSProvider: NSObject, VoiceProvider {
    let kind: VoiceProviderKind = .miniMax

    private let session: URLSession
    private let sanitizer: PrivacySanitizer
    private let consentManager: AIDataConsentManager
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioManager = AiQoAudioManager.shared
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "MiniMaxTTSProvider"
    )

    private var audioPlayer: AVAudioPlayer?
    private var playbackContinuation: CheckedContinuation<Void, Error>?
    private var hasActiveSpeechSession = false
    private var activePlaybackSequence = 0

    private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 35
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    init(
        session: URLSession,
        sanitizer: PrivacySanitizer,
        consentManager: AIDataConsentManager
    ) {
        self.session = session
        self.sanitizer = sanitizer
        self.consentManager = consentManager
        super.init()
    }

    override convenience init() {
        self.init(
            session: Self.defaultSession,
            sanitizer: PrivacySanitizer(),
            consentManager: .shared
        )
    }

    func speak(text: String) async throws {
        let sanitizedText = normalizedSpeechText(text)
        guard !sanitizedText.isEmpty else { return }
        guard sanitizedText.count <= 10_000 else {
            throw VoiceProviderError.tooLong
        }
        guard consentManager.ensureConsent() else {
            throw VoiceProviderError.consentMissing
        }
        guard let configuration = MiniMaxVoiceConfiguration.resolved() else {
            throw VoiceProviderError.configurationMissing
        }

        stop()
        let playbackSequence = nextPlaybackSequence()

        do {
            let outgoingText = sanitizedOutgoingText(sanitizedText)
            let audioData = try await synthesizeAudio(
                text: outgoingText,
                configuration: configuration
            )

            guard playbackSequence == activePlaybackSequence else {
                throw VoiceProviderError.cancelled
            }

            try beginSpeechSession()
            try play(audioData: audioData, playbackSequence: playbackSequence)
            try await awaitPlaybackCompletion(timeout: 90)
        } catch let error as VoiceProviderError {
            cleanupForFailure()
            throw error
        } catch {
            cleanupForFailure()
            logger.error("minimax_tts_unexpected_failure message=\(error.localizedDescription, privacy: .public)")
            throw VoiceProviderError.networkFailed
        }
    }

    func stop() {
        invalidateActivePlayback()
        failCurrentPlayback(with: VoiceProviderError.cancelled)

        if let audioPlayer {
            audioPlayer.stop()
            self.audioPlayer = nil
        }

        endSpeechSession()
    }

    private func synthesizeAudio(
        text: String,
        configuration: MiniMaxVoiceConfiguration.Resolved
    ) async throws -> Data {
        var request = URLRequest(url: configuration.endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = MiniMaxTTSRequest(
            model: configuration.modelID,
            text: text,
            stream: false,
            languageBoost: languageBoost(for: text),
            outputFormat: "hex",
            voiceSetting: .init(
                voiceID: configuration.voiceID,
                speed: 1,
                volume: 1,
                pitch: 0
            ),
            audioSetting: .init(
                sampleRate: 32_000,
                bitrate: 128_000,
                format: "mp3",
                channel: 1
            )
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            logger.error("minimax_tts_http_failed")
            throw VoiceProviderError.networkFailed
        }

        let decoded: MiniMaxTTSResponse
        do {
            decoded = try JSONDecoder().decode(MiniMaxTTSResponse.self, from: data)
        } catch {
            logger.error("minimax_tts_decode_failed message=\(error.localizedDescription, privacy: .public)")
            throw VoiceProviderError.decodingFailed
        }

        guard decoded.baseResponse?.statusCode == 0 else {
            logger.error("minimax_tts_status_failed code=\(decoded.baseResponse?.statusCode ?? -1, privacy: .public) message=\(decoded.baseResponse?.statusMessage ?? "unknown", privacy: .public)")
            throw VoiceProviderError.networkFailed
        }

        guard let audioHex = decoded.data?.audio,
              let audioData = Data(hexEncodedString: audioHex),
              !audioData.isEmpty else {
            logger.error("minimax_tts_audio_missing")
            throw VoiceProviderError.decodingFailed
        }

        return audioData
    }

    private func play(audioData: Data, playbackSequence: Int) throws {
        do {
            let player = try AVAudioPlayer(data: audioData)
            player.delegate = self
            player.prepareToPlay()

            guard playbackSequence == activePlaybackSequence else {
                throw VoiceProviderError.cancelled
            }

            audioPlayer = player

            guard player.play() else {
                throw VoiceProviderError.playbackFailed
            }
        } catch let error as VoiceProviderError {
            throw error
        } catch {
            logger.error("minimax_tts_player_create_failed message=\(error.localizedDescription, privacy: .public)")
            throw VoiceProviderError.playbackFailed
        }
    }

    private func awaitPlaybackCompletion(timeout: TimeInterval) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { continuation in
                    self.playbackContinuation = continuation
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw VoiceProviderError.playbackFailed
            }

            let result = try await group.next()
            group.cancelAll()
            _ = result
        }

        completeCurrentPlayback()
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
        guard hasActiveSpeechSession else { return }

        hasActiveSpeechSession = false
        audioManager.endSpeechDucking()

        if audioManager.isPlaying {
            audioManager.refreshAudioSessionConfiguration()
        } else {
            try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func completeCurrentPlayback() {
        playbackContinuation?.resume()
        playbackContinuation = nil
    }

    private func failCurrentPlayback(with error: Error) {
        playbackContinuation?.resume(throwing: error)
        playbackContinuation = nil
    }

    private func nextPlaybackSequence() -> Int {
        activePlaybackSequence += 1
        return activePlaybackSequence
    }

    private func invalidateActivePlayback() {
        activePlaybackSequence += 1
    }

    private func cleanupForFailure() {
        if let audioPlayer {
            audioPlayer.stop()
            self.audioPlayer = nil
        }
        failCurrentPlayback(with: VoiceProviderError.cancelled)
        endSpeechSession()
    }

    private func normalizedSpeechText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "\t", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizedOutgoingText(_ text: String) -> String {
        let profileName = UserProfileStore.shared.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let knownUserName: String? = {
            guard !profileName.isEmpty,
                  profileName.caseInsensitiveCompare("Captain") != .orderedSame else {
                return nil
            }
            return profileName
        }()

        return sanitizer.sanitizeForTTS(
            text,
            knownUserName: knownUserName,
            language: AppSettingsStore.shared.appLanguage
        )
    }

    private func languageBoost(for text: String) -> String {
        containsArabicCharacters(in: text) ? "Arabic" : "English"
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
}

extension MiniMaxTTSProvider: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor in
            if flag {
                completeCurrentPlayback()
            } else {
                failCurrentPlayback(with: VoiceProviderError.playbackFailed)
            }
            audioPlayer = nil
            endSpeechSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: Error?
    ) {
        Task { @MainActor in
            failCurrentPlayback(with: error ?? VoiceProviderError.decodingFailed)
            audioPlayer = nil
            endSpeechSession()
        }
    }
}

private struct MiniMaxTTSRequest: Encodable {
    struct VoiceSetting: Encodable {
        let voiceID: String
        let speed: Double
        let volume: Double
        let pitch: Double

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
            case speed
            case volume = "vol"
            case pitch
        }
    }

    struct AudioSetting: Encodable {
        let sampleRate: Int
        let bitrate: Int
        let format: String
        let channel: Int

        enum CodingKeys: String, CodingKey {
            case sampleRate = "sample_rate"
            case bitrate
            case format
            case channel
        }
    }

    let model: String
    let text: String
    let stream: Bool
    let languageBoost: String
    let outputFormat: String
    let voiceSetting: VoiceSetting
    let audioSetting: AudioSetting

    enum CodingKeys: String, CodingKey {
        case model
        case text
        case stream
        case languageBoost = "language_boost"
        case outputFormat = "output_format"
        case voiceSetting = "voice_setting"
        case audioSetting = "audio_setting"
    }
}

private struct MiniMaxTTSResponse: Decodable {
    struct DataPayload: Decodable {
        let audio: String?
        let status: Int?
    }

    struct BaseResponse: Decodable {
        let statusCode: Int?
        let statusMessage: String?

        enum CodingKeys: String, CodingKey {
            case statusCode = "status_code"
            case statusMessage = "status_msg"
        }
    }

    let data: DataPayload?
    let traceID: String?
    let baseResponse: BaseResponse?

    enum CodingKeys: String, CodingKey {
        case data
        case traceID = "trace_id"
        case baseResponse = "base_resp"
    }
}

private extension Data {
    init?(hexEncodedString: String) {
        let normalized = hexEncodedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count.isMultiple(of: 2) else { return nil }

        var data = Data(capacity: normalized.count / 2)
        var index = normalized.startIndex

        while index < normalized.endIndex {
            let next = normalized.index(index, offsetBy: 2)
            let byteString = normalized[index..<next]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = next
        }

        self = data
    }
}
