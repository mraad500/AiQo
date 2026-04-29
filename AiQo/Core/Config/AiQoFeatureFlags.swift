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

    // MARK: - Captain Voice (hybrid Apple + MiniMax) — flag added 2026-04-22
    //
    // Compile-time-constant kill switch for the MiniMax cloud voice tier.
    // When ON (default), `.premium`-tier calls to `CaptainVoiceRouter` route
    // through `MiniMaxTTSProvider` provided the user has granted voice
    // cloud consent (see `CaptainVoiceConsent`) and the MiniMax provider is
    // configured (API key in Keychain, non-placeholder voiceID/model/baseURL).
    // When OFF, the router always routes every call — including `.premium` —
    // to the Apple on-device TTS path; no consent sheet is presented, no
    // network call is ever made, the Settings voice row shows a
    // "coming soon" state.
    //
    // The `.realtime` tier is not affected by this flag — Zone 2 coaching,
    // stand nudges, and other latency-sensitive phrases always use
    // on-device Apple TTS regardless of this setting.
    @FeatureFlag("CAPTAIN_VOICE_CLOUD_ENABLED", default: true)
    static var captainVoiceCloudEnabled: Bool

    // MARK: - Cloud Proxy (Gemini + MiniMax via Supabase Edge Functions) — 2026-04-23
    //
    // When OFF (default), the app calls Gemini and MiniMax directly using API
    // keys shipped inside the IPA (via `Secrets.xcconfig` → `Info.plist` at
    // build time). That path works but exposes the keys to any attacker who
    // extracts the IPA — burning our quota is a realistic risk.
    //
    // When ON, all Gemini + MiniMax calls go through the Supabase Edge
    // Functions `captain-chat` and `captain-voice`. The user authenticates
    // with their Supabase JWT; the Edge Functions hold the real API keys
    // server-side and forward the request.
    //
    // Requirements before flipping this to ON:
    //   1. Deploy `supabase/functions/captain-chat` + `captain-voice` to Supabase.
    //   2. Rotate GEMINI + MINIMAX keys and set them as Supabase Edge secrets
    //      (`supabase secrets set GEMINI_API_KEY=… MINIMAX_API_KEY=…`).
    //   3. Remove the now-dead client-side keys from `Secrets.xcconfig`.
    //
    // See `/supabase/functions/README.md` (runbook) for the full deploy flow.
    @FeatureFlag("USE_CLOUD_PROXY", default: false)
    static var useCloudProxy: Bool

    // MARK: - Per-path proxy overrides — 2026-04-26
    //
    // The original `USE_CLOUD_PROXY` flag was a single switch — chat AND voice
    // both flipped together. In practice we want to keep chat behind the
    // Supabase Edge Function (so the Gemini key stays server-side) while
    // voice hits MiniMax directly with the rotated client key.
    //
    // These two flags override `useCloudProxy` per-path. When the Info.plist
    // entry is missing or empty, the path falls back to the master flag.
    // That keeps existing TestFlight builds (which only know about the master
    // flag) behaving exactly as before.

    /// True when chat (Gemini + memory extractor) should route through
    /// the `captain-chat` Edge Function. Falls back to `useCloudProxy`
    /// when `USE_CHAT_CLOUD_PROXY` is unset.
    static var useChatCloudProxy: Bool {
        if let override = Self.optionalBoolFlag(named: "USE_CHAT_CLOUD_PROXY") {
            return override
        }
        return useCloudProxy
    }

    /// True when MiniMax voice synthesis should route through the
    /// `captain-voice` Edge Function. Falls back to `useCloudProxy`
    /// when `USE_VOICE_CLOUD_PROXY` is unset.
    static var useVoiceCloudProxy: Bool {
        if let override = Self.optionalBoolFlag(named: "USE_VOICE_CLOUD_PROXY") {
            return override
        }
        return useCloudProxy
    }

    /// Reads a Bool/string Info.plist entry and returns `nil` when the value
    /// is missing, empty, or an unexpanded `$(…)` placeholder. The
    /// distinction matters for per-path overrides — `false` means "explicitly
    /// off", `nil` means "no opinion, defer to the master flag".
    private static func optionalBoolFlag(named key: String) -> Bool? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) else {
            return nil
        }
        if let bool = raw as? Bool {
            return bool
        }
        if let str = raw as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("$(") {
                return nil
            }
            switch trimmed.lowercased() {
            case "true", "yes", "1":
                return true
            case "false", "no", "0":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}
