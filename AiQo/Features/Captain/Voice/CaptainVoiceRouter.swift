import Foundation
import Combine
import os.log

/// Single entry point for spoken output in AiQo. Dispatches utterances to the
/// right provider based on the caller's declared tier:
///
/// - `.realtime` → always the on-device Apple TTS path. Used for Zone 2
///   coaching, stand reminders, short system phrases. Latency budget
///   <150ms. Never hits the network.
/// - `.premium` → the MiniMax cloud provider when **all** of:
///   (a) `FeatureFlags.captainVoiceCloudEnabled` is on,
///   (b) the MiniMax provider is configured (commit 2),
///   (c) the user has granted voice cloud consent (commit 2),
///   (d) the network request succeeds.
///   Any failure silently falls back to Apple TTS. After 3 consecutive
///   MiniMax failures in a 60-second window, one toast is emitted
///   ("Switched to local voice temporarily") and further toasts are
///   suppressed until next app launch.
///
/// The tier is a caller-side context signal, not a user setting. The only
/// user-facing control is the Settings voice row (commit 2) which gates
/// the consent + feature flag combination.
///
/// # Commit 1 behavior
/// In commit 1, `miniMaxProvider` is always `nil`, so `.premium` calls
/// fall through to Apple TTS. The router's public API is stable — commit 2
/// wires in `MiniMaxTTSProvider` and `CaptainVoiceConsent` without
/// changing any call site.
@MainActor
final class CaptainVoiceRouter: ObservableObject {
    static let shared = CaptainVoiceRouter.makeShared()

    /// Static factory used only by `shared`. Wrapping the convenience
    /// initializer behind a function lets Swift 6 reason about main-actor
    /// isolation without complaining about nonisolated default-argument
    /// expressions.
    private static func makeShared() -> CaptainVoiceRouter {
        CaptainVoiceRouter()
    }

    enum VoiceTier {
        case realtime
        case premium
    }

    @Published private(set) var isSpeaking = false
    @Published private(set) var activeProvider: VoiceProviderKind = .appleTTS
    /// Set to true when a `.premium` request is rejected because cloud-voice
    /// consent has not been granted yet. Views observe this and present
    /// `VoiceConsentSheet` reactively, so the user discovers the consent
    /// requirement at the moment they tap a speaker — regardless of which
    /// chat surface (CaptainChatView, CaptainScreen, future) hosts the
    /// speaker. The view should call `acknowledgeConsentRequest()` once the
    /// sheet is dismissed so a later tap can re-trigger.
    @Published private(set) var needsConsent: Bool = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainVoiceRouter"
    )

    private let appleTTSProvider: VoiceProvider
    /// Cloud provider. When unavailable or misconfigured, `.premium` silently
    /// falls back to Apple TTS.
    private var miniMaxProvider: VoiceProvider?

    /// Feature-flag closure. Prod reads `FeatureFlags.captainVoiceCloudEnabled`
    /// live each call; tests substitute a closure to simulate the kill switch
    /// in either state without touching `Info.plist`.
    private let featureFlagEnabled: () -> Bool

    // Failure accounting for toast suppression — see `handleMiniMaxFailure`.
    /// Rolling 60-second window of MiniMax failure timestamps. Exposed
    /// `private(set)` so tests can verify the threshold logic without
    /// relying on the external toast side effect.
    private(set) var miniMaxFailureTimestamps: [Date] = []
    private(set) var hasShownFallbackToastThisSession = false

    /// Designated initializer. Dependency-injected providers so tests can
    /// stand in mocks without spinning up the real Apple TTS synthesizer.
    /// Swift 6 strict concurrency flags default argument expressions that
    /// reference main-actor state, so callers must supply all three
    /// arguments. For production use the no-argument `init()` convenience
    /// (which resolves real defaults inside its own main-actor body).
    init(
        appleTTSProvider: VoiceProvider,
        miniMaxProvider: VoiceProvider?,
        featureFlagEnabled: @escaping () -> Bool
    ) {
        self.appleTTSProvider = appleTTSProvider
        self.miniMaxProvider = miniMaxProvider
        self.featureFlagEnabled = featureFlagEnabled
    }

    /// Production default — wires in the real Apple TTS provider, the
    /// MiniMax cloud provider, and the live feature-flag lookup.
    convenience init() {
        self.init(
            appleTTSProvider: AppleTTSProvider(),
            miniMaxProvider: MiniMaxTTSProvider(),
            featureFlagEnabled: { FeatureFlags.captainVoiceCloudEnabled }
        )
    }

    // MARK: - Public API

    /// The main speech entry point. Returns when playback completes (or when
    /// the fallback chain is exhausted). Never throws — every failure path
    /// eventually resolves to either Apple TTS or silence.
    func speak(text: String, tier: VoiceTier) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let provider = resolveProvider(for: tier)
        activeProvider = provider.kind
        isSpeaking = true
        defer { isSpeaking = false }

        logger.notice("voice_router_speak tier=\(String(describing: tier), privacy: .public) provider=\(String(describing: provider.kind), privacy: .public) chars=\(trimmed.count)")

        do {
            try await provider.speak(text: trimmed)
        } catch VoiceProviderError.consentMissing {
            // Surface the consent requirement to the chat UI so the
            // VoiceConsentSheet appears on the next render. The current
            // utterance still gets played by Apple TTS so the user is not
            // left with silence; a second tap (after granting) will use
            // MiniMax.
            logger.notice("voice_router_fallback to=appleTTS reason=consent_missing from=\(String(describing: provider.kind), privacy: .public)")
            if provider.kind == .miniMax {
                needsConsent = true
            }
            activeProvider = .appleTTS
            try? await appleTTSProvider.speak(text: trimmed)
        } catch VoiceProviderError.configurationMissing,
                VoiceProviderError.tooLong {
            // Silent fallback — these are expected states, not runtime
            // failures. No toast, no accounting.
            logger.notice("voice_router_fallback to=appleTTS reason=expected_skip from=\(String(describing: provider.kind), privacy: .public)")
            activeProvider = .appleTTS
            try? await appleTTSProvider.speak(text: trimmed)
        } catch {
            // Any other cloud failure: fall back and record for toast
            // throttling.
            if provider.kind == .miniMax {
                handleMiniMaxFailure()
                activeProvider = .appleTTS
                try? await appleTTSProvider.speak(text: trimmed)
            }
            // Apple TTS failures surface via `CaptainVoiceService.displayedToast`;
            // the router does not re-surface them.
        }
    }

    /// Stop any in-flight speech on either provider.
    func stop() {
        appleTTSProvider.stop()
        miniMaxProvider?.stop()
    }

    /// Reset the published consent flag once the host view has shown the
    /// consent sheet. Lets a later tap re-trigger the sheet if the user
    /// dismissed without granting.
    func acknowledgeConsentRequest() {
        needsConsent = false
    }

    /// Premium-tier cache warming hook. In commit 1 this is a no-op; in
    /// commit 2 `MiniMaxTTSProvider` will use it to pre-fetch audio for
    /// upcoming utterances (e.g. a workout summary's known text).
    func warmCache(text: String) async {
        // Filled in commit 2 (MiniMax cache integration).
    }

    // MARK: - Provider resolution

    private func resolveProvider(for tier: VoiceTier) -> VoiceProvider {
        switch tier {
        case .realtime:
            return appleTTSProvider
        case .premium:
            guard featureFlagEnabled() else {
                logger.notice("voice_router_resolve picked=appleTTS reason=feature_flag_off (CAPTAIN_VOICE_CLOUD_ENABLED=NO)")
                return appleTTSProvider
            }
            guard let miniMax = miniMaxProvider else {
                logger.notice("voice_router_resolve picked=appleTTS reason=minimax_provider_nil")
                return appleTTSProvider
            }
            // Consent is checked inside `MiniMaxTTSProvider.speak` — it
            // throws `.consentMissing` when absent, and the router's
            // fallback handling silently routes to Apple TTS.
            return miniMax
        }
    }

    // MARK: - Failure accounting

    /// Tracks MiniMax failures over a rolling 60-second window. Emits a
    /// single fallback toast via `CaptainVoiceService` once we cross the
    /// 3-failures-in-60s threshold, then stays silent for the rest of the
    /// app launch so we do not spam the user with the same notice.
    private func handleMiniMaxFailure() {
        let now = Date()
        miniMaxFailureTimestamps.append(now)
        miniMaxFailureTimestamps.removeAll { now.timeIntervalSince($0) > 60 }

        guard miniMaxFailureTimestamps.count >= 3,
              !hasShownFallbackToastThisSession
        else {
            return
        }

        hasShownFallbackToastThisSession = true
        let isArabic = AppSettingsStore.shared.appLanguage == .arabic
        let toast = isArabic
            ? "تم التبديل إلى الصوت المحلي مؤقتاً"
            : "Switched to local voice temporarily"
        CaptainVoiceService.shared.presentRouterFallbackToast(toast)
    }
}
