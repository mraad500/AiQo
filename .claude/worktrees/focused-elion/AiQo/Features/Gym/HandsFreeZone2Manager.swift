import AVFoundation
import Speech
import SwiftUI
import os.log
import Combine

@MainActor
struct HandsFreeZone2Manager: View {
    @StateObject private var viewModel: HandsFreeZone2ManagerViewModel

    init() {
        _viewModel = StateObject(wrappedValue: HandsFreeZone2ManagerViewModel())
    }

    init(viewModel: HandsFreeZone2ManagerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.44, green: 0.95, blue: 0.79).opacity(0.72),
                                Color(red: 0.12, green: 0.74, blue: 0.58).opacity(0.12),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                    .frame(width: 34, height: 34)
                    .blur(radius: 5)
                    .scaleEffect(viewModel.isListening ? 1.08 : 0.92)

                Image(systemName: viewModel.symbolName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.titleText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))

                Text(viewModel.displayText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HandsFreeZone2WaveformView(
                levels: viewModel.waveformLevels,
                isListening: viewModel.isListening
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.44),
                            Color(red: 0.44, green: 0.95, blue: 0.79).opacity(0.36),
                            Color.white.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
        }
        .overlay(alignment: .topLeading) {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.34),
                            Color(red: 0.44, green: 0.95, blue: 0.79).opacity(0.16),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 96, height: 1.2)
                .padding(.leading, 18)
                .padding(.top, 7)
        }
        .shadow(
            color: Color(red: 0.18, green: 0.84, blue: 0.64).opacity(0.18),
            radius: 18,
            x: 0,
            y: 10
        )
        .padding(.top, 6)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear {
            viewModel.activate()
        }
        .onDisappear {
            viewModel.deactivate()
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: viewModel.isListening)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: viewModel.waveformLevels)
    }
}

private struct HandsFreeZone2WaveformView: View {
    let levels: [CGFloat]
    let isListening: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isListening ? 0.92 : 0.42),
                                Color(red: 0.40, green: 0.94, blue: 0.76).opacity(isListening ? 0.88 : 0.22)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: 4,
                        height: max(10, min(26, level * 26))
                    )
                    .shadow(
                        color: Color(red: 0.36, green: 0.88, blue: 0.72).opacity(isListening ? 0.28 : 0),
                        radius: 4,
                        x: 0,
                        y: 0
                    )
                    .opacity(isListening ? 1 : 0.62)
                    .animation(
                        .spring(
                            response: 0.28 + (Double(index) * 0.01),
                            dampingFraction: 0.78
                        ),
                        value: level
                    )
            }
        }
        .frame(width: 56, height: 28, alignment: .center)
        .accessibilityHidden(true)
    }
}

@MainActor
final class HandsFreeZone2ManagerViewModel: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case requestingAccess
        case listening
        case processing
        case speaking
        case unavailable(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var displayText = "Captain is ready to keep your pace locked in."
    @Published private(set) var waveformLevels = Array(repeating: CGFloat(0.18), count: 10)

    var isListening: Bool {
        phase == .listening
    }

    var titleText: String {
        switch phase {
        case .requestingAccess:
            return "Voice Access"
        case .listening:
            return "Captain Listening"
        case .processing:
            return "Captain Thinking"
        case .speaking:
            return "Captain Talking"
        case .unavailable:
            return "Voice Coach"
        case .idle:
            return "Zone 2 Hands-Free"
        }
    }

    var symbolName: String {
        switch phase {
        case .listening:
            return "waveform"
        case .processing:
            return "sparkles"
        case .speaking:
            return "speaker.wave.2.fill"
        case .unavailable:
            return "mic.slash.fill"
        case .requestingAccess:
            return "lock.open.fill"
        case .idle:
            return "figure.run"
        }
    }

    private let intelligenceManager: CaptainIntelligenceManager
    private let voiceService: CaptainVoiceService
    private let audioSession: AVAudioSession
    private let audioEngine = AVAudioEngine()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "HandsFreeZone2Manager"
    )

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var responseTask: Task<Void, Never>?
    private var restartTask: Task<Void, Never>?
    private var isActive = false

    init(locale: Locale = .autoupdatingCurrent) {
        self.intelligenceManager = .shared
        self.voiceService = .shared
        self.audioSession = .sharedInstance()
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
    }

    func activate() {
        guard !isActive else { return }
        isActive = true

        Task {
            await requestPermissionsAndStart()
        }
    }

    func deactivate() {
        isActive = false
        restartTask?.cancel()
        restartTask = nil
        responseTask?.cancel()
        responseTask = nil

        stopListening()
        voiceService.stopSpeaking()
        resetWaveform()

        try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])

        phase = .idle
        displayText = "Captain is ready to keep your pace locked in."
    }

    private func requestPermissionsAndStart() async {
        phase = .requestingAccess
        displayText = "Checking local speech and microphone access."

        let speechStatus = await requestSpeechAccess()
        guard speechStatus == .authorized else {
            phase = .unavailable("Speech recognition permission is required.")
            displayText = "Enable Speech Recognition in Settings to use hands-free coaching."
            return
        }

        let hasMicrophoneAccess = await requestMicrophoneAccess()
        guard hasMicrophoneAccess else {
            phase = .unavailable("Microphone access is required.")
            displayText = "Enable Microphone access in Settings to use hands-free coaching."
            return
        }

        startListening()
    }

    private func startListening() {
        guard isActive else { return }
        guard !voiceService.isSpeaking else { return }
        guard let speechRecognizer else {
            phase = .unavailable("Speech recognition is unavailable on this device.")
            displayText = "Speech recognition is unavailable on this device."
            return
        }
        guard speechRecognizer.isAvailable else {
            phase = .unavailable("Speech recognition is temporarily unavailable.")
            displayText = "Speech recognition is temporarily unavailable."
            scheduleListeningRestart(after: 1.2)
            return
        }
        guard speechRecognizer.supportsOnDeviceRecognition else {
            phase = .unavailable("On-device speech recognition is not supported.")
            displayText = "On-device speech recognition is not supported on this device."
            return
        }

        stopListening()
        resetWaveform()

        do {
            try configureListeningAudioSession()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true

            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                request.append(buffer)
                let level = Self.normalizedLevel(from: buffer)

                Task { @MainActor in
                    self?.pushWaveformLevel(level)
                }
            }

            audioEngine.prepare()
            try audioEngine.start()

            phase = .listening
            displayText = "Speak naturally. Captain will keep the cue short."

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                Task { @MainActor in
                    await self.handleRecognitionResult(result, error: error)
                }
            }
        } catch {
            phase = .unavailable("Listening could not start.")
            displayText = "Listening could not start. Captain will try again."
            logger.error("hands_free_listen_failed error=\(error.localizedDescription, privacy: .public)")
            scheduleListeningRestart(after: 1.2)
        }
    }

    private func stopListening() {
        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
    }

    private func handleRecognitionResult(
        _ result: SFSpeechRecognitionResult?,
        error: Error?
    ) async {
        guard isActive else { return }

        if let result {
            let transcript = result.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !transcript.isEmpty {
                displayText = transcript
            }

            if result.isFinal {
                await processVoiceInput(transcript)
                return
            }
        }

        if let error {
            if phase == .speaking || phase == .processing {
                return
            }

            logger.error("hands_free_recognition_failed error=\(error.localizedDescription, privacy: .public)")
            displayText = "Captain missed that. Keep moving and speak once more."
            phase = .listening
            scheduleListeningRestart(after: 0.65)
        }
    }

    private func processVoiceInput(_ transcript: String) async {
        let cleanedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTranscript.isEmpty else {
            scheduleListeningRestart(after: 0.35)
            return
        }

        stopListening()
        phase = .processing
        displayText = "Captain is shaping the next cue."

        responseTask?.cancel()
        responseTask = Task { [weak self] in
            guard let self else { return }

            let response: String
            do {
                let instructions = AiQoPromptManager.shared.getZone2CoachPrompt()
                let prompt = buildModelInput(from: cleanedTranscript)
                response = try await intelligenceManager.generateOnDeviceReply(
                    prompt: prompt,
                    instructions: instructions
                )
            } catch {
                logger.error("hands_free_generation_failed error=\(error.localizedDescription, privacy: .public)")
                response = fallbackSpeechResponse(for: cleanedTranscript)
            }

            await self.speak(response)
        }
    }

    private func buildModelInput(from transcript: String) -> String {
        """
        The user is mid-workout in Zone 2 cardio and wants ego-reset coaching that protects flow state.
        Reply in short spoken cues that are easy to hear while moving.

        User said: "\(transcript)"
        """
    }

    private func speak(_ response: String) async {
        guard isActive else { return }
        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            scheduleListeningRestart(after: 0.25)
            return
        }

        phase = .speaking
        displayText = response
        resetWaveform(forSpeaking: true)
        await voiceService.speakAndWait(text: response)
        guard isActive else { return }
        scheduleListeningRestart(after: 0.25)
    }

    private func scheduleListeningRestart(after delay: TimeInterval) {
        restartTask?.cancel()
        guard isActive else { return }

        restartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                self?.startListening()
            }
        }
    }

    private func configureListeningAudioSession() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothHFP]
        )
        try audioSession.setActive(true)
    }

    private func resetWaveform(forSpeaking: Bool = false) {
        let restingValue: CGFloat = forSpeaking ? 0.24 : 0.18
        waveformLevels = Array(repeating: restingValue, count: waveformLevels.count)
    }

    private func pushWaveformLevel(_ level: CGFloat) {
        guard phase == .listening else { return }

        let boundedLevel = min(max(level, 0.16), 1)
        waveformLevels.removeFirst()
        waveformLevels.append(boundedLevel)
    }

    private func requestSpeechAccess() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func fallbackSpeechResponse(for transcript: String) -> String {
        if containsArabic(in: transcript) {
            return "خلك على جهد تگدر تحچي وياه. نزّل كتافك، ثبت النفس، وخل السرعة ناعمة للخمس دقايق الجاية."
        }

        return "Stay at a pace where you can still talk. Relax your shoulders, smooth out the breath, and keep the next five minutes steady."
    }

    private func containsArabic(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF,
                 0x0750...0x077F,
                 0x0870...0x089F,
                 0x08A0...0x08FF,
                 0xFB50...0xFDFF,
                 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }

    private static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let channelData = buffer.floatChannelData?.pointee else {
            return 0.18
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0.18 }

        var sum: Float = 0
        var sampleCount = 0

        for index in stride(from: 0, to: frameLength, by: 16) {
            let sample = channelData[index]
            sum += sample * sample
            sampleCount += 1
        }

        guard sampleCount > 0 else { return 0.18 }

        let rootMeanSquare = sqrt(sum / Float(sampleCount))
        return min(1, max(0.18, CGFloat(rootMeanSquare) * 18))
    }
}
