import Foundation

/// Identifies which underlying engine handled an utterance. Observed by
/// `CaptainVoiceRouter.activeProvider` so UI elements (e.g. the chat
/// speaker badge) can reflect whether cloud voice or on-device voice
/// is currently playing.
enum VoiceProviderKind: String {
    case appleTTS
    case miniMax
}

/// Errors a `VoiceProvider` may throw. Each case maps to a specific
/// fallback behavior in `CaptainVoiceRouter`:
///
/// - `.consentMissing` / `.configurationMissing` — silent fallback to Apple TTS.
///   These are configuration states, not runtime failures; no toast.
/// - `.networkFailed` — silent fallback to Apple TTS. A single
///   "switched to local voice" toast is surfaced per app launch after
///   3 consecutive failures in a 60-second window.
/// - `.decodingFailed` / `.playbackFailed` — treated like network failure.
/// - `.tooLong` — caller-side problem; fallback to Apple TTS.
/// - `.cancelled` — swallowed; the user (or a newer utterance) cancelled.
enum VoiceProviderError: Error {
    case consentMissing
    case configurationMissing
    case networkFailed
    case decodingFailed
    case playbackFailed
    case cancelled
    case tooLong
}

/// Abstraction over a single voice engine. Used by `CaptainVoiceRouter`
/// to dispatch speech requests without caring whether the implementation
/// is on-device (Apple TTS) or cloud-based (MiniMax).
///
/// Implementations are expected to be isolated to the main actor because
/// they touch `AVAudioSession` / `AVSpeechSynthesizer` / `AVAudioPlayer`,
/// all of which prefer main-thread setup.
protocol VoiceProvider: AnyObject {
    var kind: VoiceProviderKind { get }

    /// Speak `text` and return when playback finishes (or throw on failure).
    /// Callers should trim whitespace before invoking.
    func speak(text: String) async throws

    /// Stop any in-flight playback immediately. Safe to call when idle.
    func stop()
}
