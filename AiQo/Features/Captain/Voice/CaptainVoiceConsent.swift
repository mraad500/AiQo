import Combine
import Foundation

/// Dedicated consent surface for the MiniMax cloud voice tier.
///
/// This is intentionally separate from `AIDataConsentManager`. Apple 5.1.2(II)
/// requires per-purpose consent, and agreeing to Gemini cloud AI analysis is
/// semantically distinct from agreeing to send Hamoudi's response text to a
/// third-party TTS provider (MiniMax, operated in a different jurisdiction).
/// Bundling the two under one toggle was a likely path to a second App Review
/// rejection after submission 49728905.
///
/// Persistence is `UserDefaults` with versioned keys so a future v2 gate can
/// force re-consent without colliding with v1 state.
///
/// State machine:
/// - Initial: `isGranted = false`, both timestamps nil.
/// - `grant()`: flips to true, stamps `grantedAt`, clears `revokedAt`.
/// - `revoke()`: flips to false, stamps `revokedAt`, leaves `grantedAt` alone
///   (so "most recent grant" remains observable for audit UI).
///
/// `revoke()` also performs voice-specific teardown that does not belong in
/// the general AI consent flow: wipes the MP3 cache so no cloud-synthesized
/// audio survives, deletes the MiniMax API key from the Keychain, and posts
/// `.captainVoiceConsentRevoked` so any in-flight UI (settings screen, chat)
/// can react.
@MainActor
final class CaptainVoiceConsent: ObservableObject {
    static let shared = CaptainVoiceConsent.makeShared()

    private static func makeShared() -> CaptainVoiceConsent {
        CaptainVoiceConsent()
    }

    @Published private(set) var isGranted: Bool
    @Published private(set) var grantedAt: Date?
    @Published private(set) var revokedAt: Date?

    private let defaults: UserDefaults

    /// Versioned so a future v2 consent flow can force re-consent without
    /// silently inheriting a v1 grant. Do not reuse these keys — introduce
    /// `aiqo.voice.cloud.consent.v2` instead.
    static let isGrantedKey = "aiqo.voice.cloud.consent.v1"
    static let grantedAtKey = "aiqo.voice.cloud.consent.grantedAt.v1"
    static let revokedAtKey = "aiqo.voice.cloud.consent.revokedAt.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isGranted = defaults.bool(forKey: Self.isGrantedKey)
        self.grantedAt = defaults.object(forKey: Self.grantedAtKey) as? Date
        self.revokedAt = defaults.object(forKey: Self.revokedAtKey) as? Date
    }

    /// Called from `VoiceConsentSheet` primary CTA. Opens the cloud-voice
    /// route for subsequent `.premium`-tier calls.
    func grant() {
        let now = Date()
        isGranted = true
        grantedAt = now
        revokedAt = nil

        defaults.set(true, forKey: Self.isGrantedKey)
        defaults.set(now, forKey: Self.grantedAtKey)
        defaults.removeObject(forKey: Self.revokedAtKey)
    }

    /// Called from the Settings toggle's revoke confirmation. Performs the
    /// three teardown steps required by our privacy posture:
    ///
    /// 1. Flip the gate to `false` so the router's next `.premium` call
    ///    routes to Apple TTS without ever reaching `MiniMaxTTSProvider`.
    /// 2. Wipe the on-device MP3 cache (fire-and-forget — the actor call
    ///    is non-blocking, and a concurrent speak attempt is already
    ///    blocked by the consent gate at step 1).
    /// 3. Delete the MiniMax API key from the Keychain. The next call
    ///    would need a fresh consent + re-cache from `Info.plist`.
    /// 4. Post `.captainVoiceConsentRevoked` so UI observers (settings
    ///    subtitle, chat speaker badge) can refresh.
    func revoke() {
        let now = Date()
        isGranted = false
        revokedAt = now

        defaults.set(false, forKey: Self.isGrantedKey)
        defaults.set(now, forKey: Self.revokedAtKey)

        Task {
            await VoiceCacheStore.shared.wipeAll()
        }
        CaptainVoiceKeychain.deleteMiniMaxAPIKey()

        NotificationCenter.default.post(name: .captainVoiceConsentRevoked, object: nil)
    }
}

extension Notification.Name {
    /// Posted after `CaptainVoiceConsent.revoke()` completes the local
    /// teardown steps. UI that reflects cloud-voice status (chat badge,
    /// settings subtitle) should observe and refresh.
    static let captainVoiceConsentRevoked = Notification.Name("aiqo.voice.cloud.consent.revoked")
}
