import Combine
import Foundation

/// Dedicated consent surface for sending an optional body photo to Google
/// Gemini during a workout-plan request.
///
/// This is intentionally separate from `AIDataConsentManager` and
/// `CaptainVoiceConsent`. Apple 5.1.2(II) requires per-purpose consent —
/// agreeing to send the response text to a TTS provider is semantically
/// distinct from agreeing to send a body image to a multimodal AI model.
/// Each purpose gets its own toggle, its own revoke flow, and its own audit
/// trail.
///
/// Privacy posture (documented in `BodyPhotoConsentSheet`):
/// - The image is downsized and re-encoded as JPEG client-side before
///   leaving the device — EXIF/GPS is stripped.
/// - The image is NOT saved to disk locally; it lives only in `@State` for
///   the duration of the intake flow.
/// - The image is sent to Google Gemini for one-shot plan tailoring. It is
///   not retained on AiQo servers (we have none in the data path).
/// - Revoking does not "delete" past uploads from Google — that is
///   governed by Google's retention policy.
@MainActor
final class BodyPhotoConsent: ObservableObject {
    static let shared = BodyPhotoConsent()

    @Published private(set) var isGranted: Bool
    @Published private(set) var grantedAt: Date?
    @Published private(set) var revokedAt: Date?

    private let defaults: UserDefaults

    static let isGrantedKey = "aiqo.plan.bodyPhoto.consent.v1"
    static let grantedAtKey = "aiqo.plan.bodyPhoto.consent.grantedAt.v1"
    static let revokedAtKey = "aiqo.plan.bodyPhoto.consent.revokedAt.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isGranted = defaults.bool(forKey: Self.isGrantedKey)
        self.grantedAt = defaults.object(forKey: Self.grantedAtKey) as? Date
        self.revokedAt = defaults.object(forKey: Self.revokedAtKey) as? Date
    }

    func grant() {
        let now = Date()
        isGranted = true
        grantedAt = now
        revokedAt = nil

        defaults.set(true, forKey: Self.isGrantedKey)
        defaults.set(now, forKey: Self.grantedAtKey)
        defaults.removeObject(forKey: Self.revokedAtKey)
    }

    func revoke() {
        let now = Date()
        isGranted = false
        revokedAt = now

        defaults.set(false, forKey: Self.isGrantedKey)
        defaults.set(now, forKey: Self.revokedAtKey)

        NotificationCenter.default.post(name: .bodyPhotoConsentRevoked, object: nil)
    }
}

extension Notification.Name {
    static let bodyPhotoConsentRevoked = Notification.Name("aiqo.plan.bodyPhoto.consent.revoked")
}
