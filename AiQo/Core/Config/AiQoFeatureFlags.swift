import Foundation

/// Central registry of in-app feature flags sourced from `Info.plist`.
///
/// Prefer the `@FeatureFlag` property wrapper on `FeatureFlags` entries over the
/// lower-level `FeatureFlag` struct or direct `Bundle.main.object` lookups.
enum AiQoFeatureFlags {
    static func boolFlag(named key: String, default defaultValue: Bool) -> Bool {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: key)

        if let boolValue = rawValue as? Bool {
            return boolValue
        }

        if let stringValue = rawValue as? String {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1":
                return true
            case "false", "no", "0":
                return false
            default:
                break
            }
        }

        return defaultValue
    }
}

/// Property wrapper form. Reads fresh from Info.plist each access (no caching) so
/// test injection of bundled Info.plist values takes effect immediately.
@propertyWrapper
struct FeatureFlag {
    let key: String
    let defaultValue: Bool

    init(_ key: String, default defaultValue: Bool = false) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: Bool {
        AiQoFeatureFlags.boolFlag(named: key, default: defaultValue)
    }

    /// Legacy accessor for call sites that used the old struct shape `FeatureFlag(key:defaultValue:).value`.
    /// New code should read the property directly via `@FeatureFlag`.
    var value: Bool { wrappedValue }
}

enum FeatureFlags {
    @FeatureFlag("MEMORY_V4_ENABLED", default: false)
    static var memoryV4Enabled: Bool

    @FeatureFlag("CAPTAIN_BRAIN_V2_ENABLED", default: false)
    static var brainV2Enabled: Bool

    @FeatureFlag("HAMOUDI_BLEND_ENABLED", default: false)
    static var hamoudiBlendEnabled: Bool

    @FeatureFlag("TRIBE_SUBSCRIPTION_GATE_ENABLED", default: false)
    static var tribeSubscriptionGateEnabled: Bool

    // MARK: - Learning Spark (Stage 1) — flag group added 2026-04-19
    //
    // NOTE: The same documentation exists as XML comments in `AiQo/Info.plist`.
    // The Swift copy is the source of truth because Xcode's plist GUI editor can
    // strip XML comments on save. If you change semantics here, update Info.plist
    // too — but never trust Info.plist comments alone.

    /// Master kill switch for the V2 Learning Spark challenge flow (on-device
    /// verification + dual-course options + Captain Hamoudi reasoner).
    ///
    /// When OFF, consumers should hide the V2 UI. No current call site references
    /// this flag yet — it exists so we can dark-launch a pre-V2 rollback quickly if
    /// App Review flags the new flow.
    @FeatureFlag("LEARNING_CHALLENGE_V2_ENABLED", default: true)
    static var learningChallengeV2Enabled: Bool

    // ═════════════════════════════════════════════════════════════════════════════
    //  ARCHITECTURAL COMMITMENT — zero-cloud verification, permanently.
    // ═════════════════════════════════════════════════════════════════════════════
    //
    // When ON (default), `CertificateVerifier` runs the on-device OCR + Foundation
    // Models pipeline. When OFF, `HamoudiVerificationReasoner.reason(...)` short-
    // circuits to `.needsReview` with an honest "device can't verify" Arabic
    // fallback.
    //
    // IT DOES NOT — AND MUST NOT — RE-ENGAGE THE DEPRECATED GEMINI VERIFIER.
    //
    // The flag is a local-only kill switch. The deprecated
    // `LearningCertificateVerifier` struct (marked `@available(*, deprecated, …)`)
    // is retained compilable purely as a manual-only rollback target. If you want
    // to revive cloud verification for any reason, you must:
    //   1. Read and accept the deprecation attribute's message.
    //   2. Manually rewire `LearningProofSubmissionView.performSubmit(image:)` to
    //      call the old verifier.
    //   3. Accept that you are breaking AiQo's zero-cloud-verification commitment
    //      and inform the product owner.
    //
    // Certificate images and extracted text never leave the device under any flag
    // combination. This is a non-negotiable privacy guarantee.
    /// On-device certificate verification toggle. See the banner above.
    @FeatureFlag("LEARNING_VERIFICATION_ON_DEVICE_ENABLED", default: true)
    static var learningVerificationOnDeviceEnabled: Bool

    /// When ON (default), external course URLs open in `SFSafariViewController`
    /// (Apple's sanctioned in-app browser — inherits Safari cookies, no extra
    /// privacy labels required). When OFF, falls back to `UIApplication.shared.open`
    /// which jumps out to the Safari app.
    @FeatureFlag("SAFARI_VIEW_CONTROLLER_ENABLED", default: true)
    static var safariViewControllerEnabled: Bool
}
