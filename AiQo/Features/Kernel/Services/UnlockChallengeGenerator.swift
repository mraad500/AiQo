import Foundation

/// Produces the escalating `UnlockChallenge` for the current shield. The PRIMARY
/// difficulty axis is now `shieldNumber` (today's shield count, via
/// `KernelEscalation`): the base step target rises 40 → 90 → 160 → 260 → 400, then
/// by formula past shield 5, ALWAYS clamped to `KernelEscalation.maxSteps` so the
/// walk stays physically possible (never a jail).
///
/// The existing bio modifier (sedentary / stressed / late-night) is then applied ON
/// TOP as a step multiplier — the same live signals as before, now *scaling* the
/// escalation base instead of replacing it. The earned-energy cost escalates too and
/// switches OFF past shield 5 (physical effort only). App-only (live HealthKit state).
///
/// NOTE: the breathing / calm-heart challenge KINDS (and their views) are retained
/// compilable for future bio-driven variants — the escalation path emits steps (the
/// universal, iPhone-only signal the shield extension can display); it does not
/// delete them. This replaces the old score→{40/150/250 + breath/calm} selection and
/// the fixed once-a-day 500-step `emergency()` exit with one graded ramp + tail.
enum UnlockChallengeGenerator {
    /// - Parameter shieldNumber: today's `shieldsTriggeredToday` (1 = first shield).
    static func make(for state: DoomscrollState, shieldNumber: Int) -> UnlockChallenge {
        // Existing bio modifier — unchanged signals, now an additive "stress score"
        // (0…5) that bumps the step target on top of the shield base.
        var score = 0
        if state.sedentaryMinutes >= 30 { score += 2 } else if state.sedentaryMinutes >= 10 { score += 1 }
        if state.stressed { score += 2 }
        if state.lateNight { score += 1 }

        let steps = KernelEscalation.stepTarget(forShield: shieldNumber, bioScore: score)
        // `nil` ⇒ energy path OFF past shield 5; 0 coinPrice is the "no spend" sentinel
        // (the real cost is always ≥ 20), enforced in `spendToUnlock` + the spend button.
        let energy = KernelEscalation.energyCost(forShield: shieldNumber) ?? 0
        let difficulty: UnlockChallenge.Difficulty = {
            switch shieldNumber {
            case ..<2: return .easy
            case 2...3: return .medium
            default:    return .hard
            }
        }()
        return UnlockChallenge(kind: .steps(steps), difficulty: difficulty, coinPrice: energy)
    }
}
