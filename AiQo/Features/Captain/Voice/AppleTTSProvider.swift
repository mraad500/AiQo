import Foundation

/// `VoiceProvider` adapter around the existing on-device `CaptainVoiceService`
/// (AVSpeechSynthesizer). The underlying service is the Chat v1.1 TTS surface
/// — it owns the `isTTSAvailable` / `displayedToast` contract that the chat
/// view binds to, and it already handles the `AVAudioSession` setup, toast
/// dismissal, and `FoundationModels` workout-prompt generation path.
///
/// This adapter is a thin pass-through. It never throws because the
/// underlying service surfaces its own failures through published state —
/// the router does not need to treat Apple TTS outcomes as errors.
@MainActor
final class AppleTTSProvider: VoiceProvider {
    let kind: VoiceProviderKind = .appleTTS

    private let service: CaptainVoiceService

    /// Designated initializer. Callers supply the service explicitly so
    /// Swift 6 does not complain about main-actor access in a default
    /// argument expression. For the common case use the no-argument
    /// convenience init below.
    init(service: CaptainVoiceService) {
        self.service = service
    }

    /// Convenience initializer that wires in `CaptainVoiceService.shared`.
    /// Safe to call from any `@MainActor` context.
    convenience init() {
        self.init(service: CaptainVoiceService.shared)
    }

    func speak(text: String) async throws {
        await service.speak(text: text)
    }

    func stop() {
        service.stopSpeaking()
    }
}
