import Foundation

/// Single source of truth for the AiQo level / XP threshold table.
///
/// Both the onboarding "legacy" calculation and the long-running `LevelStore`
/// route XP through this table so the user sees the same level number on the
/// onboarding result screen and on the Profile screen. Previously each side
/// used its own formula (a hard-coded threshold table on one side and an
/// exponential growth formula on the other), producing divergent levels for
/// the same XP total.
enum AiQoLeveling {
    /// Cumulative lower-bound XP for each level. Index 0 corresponds to level 1.
    /// Level `n` covers the half-open range `[thresholds[n-1], thresholds[n])`,
    /// except level 50 which is the cap and extends to infinity.
    static let thresholds: [Int] = [
        0, 200, 500, 1_000, 1_800, 2_800, 4_000, 5_500, 7_500, 10_000,
        13_000, 16_500, 20_500, 25_000, 30_000, 36_000, 42_500, 50_000, 58_000, 66_500,
        76_000, 86_000, 97_000, 109_000, 122_000, 136_000, 151_000, 167_000, 184_000, 202_000,
        222_000, 244_000, 268_000, 294_000, 322_000, 352_000, 385_000, 420_000, 458_000, 500_000,
        545_000, 594_000, 647_000, 705_000, 768_000, 837_000, 912_000, 994_000, 1_084_000, 1_183_000
    ]

    static let maxLevel = thresholds.count

    /// Returns the level (1-indexed) for a given total lifetime XP.
    static func level(forTotalXP totalXP: Int) -> Int {
        let safeXP = max(totalXP, 0)
        for i in (0..<thresholds.count).reversed() where safeXP >= thresholds[i] {
            return i + 1
        }
        return 1
    }

    /// XP span between the current level and the next. Returns 0 at the cap level.
    static func xpForNextLevel(at level: Int) -> Int {
        let safeLevel = max(level, 1)
        guard safeLevel < thresholds.count else { return 0 }
        return thresholds[safeLevel] - thresholds[safeLevel - 1]
    }

    /// XP earned within the current level (i.e. distance from the level's lower bound).
    static func currentXP(forTotalXP totalXP: Int, atLevel level: Int) -> Int {
        let safeLevel = max(min(level, thresholds.count), 1)
        let lowerBound = thresholds[safeLevel - 1]
        return max(totalXP - lowerBound, 0)
    }
}
