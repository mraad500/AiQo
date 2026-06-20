import Foundation

/// App-facing Kernel constants and UI models. The cross-process Codable state
/// (`KernelState`, `KernelUnlockRequirement`) lives in `KernelSharedStore` so it
/// can compile into the extensions; this file is app-target only.
///
/// Phase 1: structure only — no shielding / blocking behavior.
enum KernelModels {
    /// Sensible default unlock goal until the user customizes it.
    static let defaultStepGoal = 5_000
}

/// Live physiological / behavioral snapshot the bio engine computes from real
/// HealthKit data to gate blocking and grade the unlock challenge. App-only.
///
/// Steps are the universal (iPhone-only) signal; heart signals are an Apple
/// Watch enhancement only — `stressed` never gates blocking, it only raises
/// challenge difficulty when present.
struct DoomscrollState: Equatable {
    /// No meaningful step increase within the recent window.
    var sedentary: Bool
    /// Minutes the user has been continuously sedentary.
    var sedentaryMinutes: Int
    /// Stress signal: recent HR above personal resting + margin (or low HRV).
    /// Watch-only; `false` when no recent heart data.
    var stressed: Bool
    /// Late-night window (raises difficulty).
    var lateNight: Bool
    /// Recent heart-rate data exists (≈ Apple Watch present).
    var hasHeartData: Bool

    static let calm = DoomscrollState(
        sedentary: false, sedentaryMinutes: 0, stressed: false, lateNight: false, hasHeartData: false
    )
}

/// What the in-app challenge screen renders while protection is on (Phase 3).
enum KernelChallengeUIState: Equatable {
    /// Nothing shielded — no challenge to show.
    case none
    /// Locked, challenge not resolved yet (brief).
    case preparing
    /// An active (rising) challenge with live progress — shields 1…4.
    case challenge(UnlockChallenge, stepsWalked: Int)
    /// From the 5th shield onward: lead with the gentle "enough for today — come back
    /// tomorrow" message; the (hard) challenge stays available beneath it, never a
    /// jail. Replaces the old fixed daily-limit / 500-step emergency screen.
    case enoughForToday(UnlockChallenge, stepsWalked: Int)
}

// MARK: - Escalation control surface

/// The **single** control surface for the Kernel's rising-shield model — every
/// tunable number lives here so the whole escalation can be retuned in one place.
/// App-target only (the extensions read the already-frozen `activeChallenge` +
/// `triggeredTodayCount()`, never these constants).
///
/// Indexed by `shieldsTriggeredToday` (1 = the first shield of the day). Shields
/// 1…5 use the explicit tiers below; from shield 6 the model continues by formula
/// with the hardest tier's session/threshold floor — an infinite, gentle tail. The
/// final step target is ALWAYS clamped to `maxSteps`, so the walk stays physically
/// possible and the user is never trapped (they can also always turn protection off).
///
/// Replaces the old fixed daily wall + 500-step emergency exit (`UnlockChallenge`
/// `.emergency`) with a graded, never-jailing ramp — the cap is the safety valve.
enum KernelEscalation {
    /// Per-shield tier: usage minutes allowed before the NEXT shield (SMART
    /// threshold), base step target, session minutes after opening, energy cost.
    struct Tier {
        let usageBeforeNext: Int
        let baseSteps: Int
        let sessionMinutes: Double
        let energyCost: Int
    }

    /// Shields 1…5 (index 0 = shield 1). The note in the spec stands: the FIRST
    /// shield's *trigger* uses the user's own `usageThresholdMinutes` — these
    /// `usageBeforeNext` values govern shield 2 onward.
    static let tiers: [Tier] = [
        Tier(usageBeforeNext: 15, baseSteps: 40,  sessionMinutes: 5.0, energyCost: 20),   // shield 1
        Tier(usageBeforeNext: 8,  baseSteps: 90,  sessionMinutes: 4.0, energyCost: 60),   // shield 2
        Tier(usageBeforeNext: 5,  baseSteps: 160, sessionMinutes: 3.0, energyCost: 150),  // shield 3
        Tier(usageBeforeNext: 3,  baseSteps: 260, sessionMinutes: 2.0, energyCost: 350),  // shield 4
        Tier(usageBeforeNext: 2,  baseSteps: 400, sessionMinutes: 1.5, energyCost: 700),  // shield 5 (hardest tier)
    ]

    /// Usage-threshold floor (minutes) for shield 6+.
    static let usageFloorMinutes = 2
    /// Step growth per shield past 5.
    static let stepsPerExtraShield = 250
    /// Session floor (minutes) for shield 6+.
    static let sessionFloorMinutes = 1.5
    /// Hard cap on the final step target — always physically walkable.
    static let maxSteps = 2_500
    /// The gentle "enough for today" message leads from this shield number onward.
    static let enoughForTodayShield = 5
    /// Bio-modifier step bump per stress point (sedentary / stressed / late-night).
    static let bioStepBumpPerPoint = 0.10

    private static func tier(for shield: Int) -> Tier {
        let n = max(1, shield)
        return n <= tiers.count ? tiers[n - 1] : tiers[tiers.count - 1]
    }

    /// Usage minutes allowed before the NEXT shield fires (SMART threshold).
    static func usageMinutesBeforeNext(forShield shield: Int) -> Int {
        max(usageFloorMinutes, tier(for: shield).usageBeforeNext)
    }

    /// Base step target for this shield (before the bio modifier + MAX clamp).
    static func baseSteps(forShield shield: Int) -> Int {
        let n = max(1, shield)
        if n <= tiers.count { return tiers[n - 1].baseSteps }
        return tiers[tiers.count - 1].baseSteps + (n - tiers.count) * stepsPerExtraShield
    }

    /// Earned-energy cost to bypass this shield, or `nil` once the energy path is
    /// switched OFF (shield > 5 → physical effort only; zero money, ever).
    static func energyCost(forShield shield: Int) -> Int? {
        let n = max(1, shield)
        return n <= tiers.count ? tiers[n - 1].energyCost : nil
    }

    /// Session minutes granted after a successful unlock at this shield.
    static func sessionMinutes(forShield shield: Int) -> Double {
        let n = max(1, shield)
        return n <= tiers.count ? tiers[n - 1].sessionMinutes : sessionFloorMinutes
    }

    /// Final step target: base × bio-modifier, clamped to `maxSteps` (and floored at
    /// the base so the modifier never makes it *easier*). Always physically possible.
    static func stepTarget(forShield shield: Int, bioScore: Int) -> Int {
        let base = baseSteps(forShield: shield)
        let scaled = Int((Double(base) * (1.0 + Double(max(0, bioScore)) * bioStepBumpPerPoint)).rounded())
        return min(maxSteps, max(base, scaled))
    }

    /// True once we've reached the "enough for today" tier (shield ≥ 5).
    static func isEnoughForToday(shield: Int) -> Bool {
        shield >= enoughForTodayShield
    }
}

/// High-level gate the Kernel screen renders. Resolved from the feature flag and
/// Family Controls authorization. (No tier gate: every tier may open the Kernel;
/// the free tier is capped to one app via `TierGate.kernelAppLimit`.)
enum KernelGateState: Equatable {
    /// `KERNEL_ENABLED` is off.
    case featureDisabled
    /// Family Controls is not approved yet.
    case needsAuthorization
    /// Authorized and ready to choose apps.
    case ready
}
