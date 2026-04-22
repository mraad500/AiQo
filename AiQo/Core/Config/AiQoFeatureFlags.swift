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

    /// Master kill switch for the Captain Chat v1.1 rebuild (Apple rejection fix
    /// submission 49728905 — guidelines 1.4.1, 2.1.0, 4.0.0). When ON, the chat
    /// uses the Mint/Sand brand-token bubbles, persistent safety banner, fixed
    /// header, and the revised Gemini system prompt. When OFF, falls back to
    /// the v1.0 legacy chat — but note that prompt / name-injection / model
    /// fixes are unconditional because they are bug fixes. This flag only
    /// gates the visible rebuild.
    @FeatureFlag("AIQO_CHAT_V1_1_ENABLED", default: true)
    static var captainChatV1_1Enabled: Bool

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

    // MARK: - Learning Spark Stage 2 — flag group added 2026-04-19
    //
    // Paired-rollback model. Default production behavior is
    //   LEARNING_SPARK_STAGE2_ENABLED = YES, PLANK_LADDER_CHALLENGE_ENABLED = NO
    // which shows the 5-course Learning Spark Stage 2 challenge in the Stage 2 quest
    // slot that Plank Ladder previously occupied (reusing the "2.3" shield asset
    // verbatim — no new artwork).
    //
    // Rollback:   (NO,  YES) → Plank Ladder reappears in the same slot.
    // Emergency:  (NO,  NO)  → slot renders a non-interactive "قريباً"/"Coming Soon"
    //                          placeholder. Safety net only.
    //
    // Plank Ladder code is retained fully compilable (QuestDefinition entry preserved
    // as `QuestDefinitions.plankLadderQuest`, localizations, timer logic). It may
    // return in Stage 3 or Stage 4 later — dormant, not dead.
    //
    // NOTE — app-restart required for flag flips: These flag reads are cached by
    // `QuestEngine.shared` and `QuestSwiftDataStore` at init (see AIQO_TECH_DEBT.md
    // → Known Limitations). A flip during a session will NOT propagate until the app
    // is killed and relaunched. Acceptable because these flags are Info.plist-backed,
    // not remote-config — they can't change mid-session in a shipped build anyway.
    //
    // NOTE — source of truth: The same documentation exists as XML comments in
    // `AiQo/Info.plist`. The Swift copy is canonical because Xcode's plist GUI editor
    // can strip XML comments on save.

    /// Master switch for the Learning Spark Stage 2 Legendary Challenge. When ON,
    /// the challenge appears in Stage 2 with the reused Plank Ladder shield asset.
    @FeatureFlag("LEARNING_SPARK_STAGE2_ENABLED", default: true)
    static var learningSparkStage2Enabled: Bool

    /// Rollback switch for the deprecated Plank Ladder challenge. When OFF (default),
    /// Plank Ladder is hidden from the Stage 2 Legendary Challenges list. When ON,
    /// it reappears in its original position. Code is retained fully compilable.
    @FeatureFlag("PLANK_LADDER_CHALLENGE_ENABLED", default: false)
    static var plankLadderChallengeEnabled: Bool

    // MARK: - Smart Water Tracking (free feature) — flag added 2026-04-22
    //
    // Kill switch for the Smart Water Tracking & Reminders feature. When ON
    // (default), `WaterDetailSheetView` renders the `SmartHydrationSection`
    // (pace summary, WHO/EFSA guidance, toggle) and `HomeViewModel` schedules
    // pace-based hydration reminders through `NotificationBrain`. When OFF,
    // the Water sheet falls back to the v1 bottle + add-button UI and no
    // hydration notifications are scheduled.
    //
    // The feature is 100% free — no paywall or subscription gating. This flag
    // exists only as a production kill switch if the reminder logic misbehaves
    // in the wild. Users still control the feature via the in-app toggle
    // (`HydrationSettings.smartTrackingEnabled`, UserDefaults-backed).
    @FeatureFlag("SMART_WATER_TRACKING_ENABLED", default: true)
    static var smartWaterTrackingEnabled: Bool
}
