import Foundation

/// Per-quest XP reward table. Consumed by `saveQuestAchievement` when the user
/// completes a challenge for the first time — the guard in `saveQuestAchievement`
/// ensures XP is awarded exactly once per quest ID (Guardrail 6 compliance).
///
/// Only quests with an explicit entry in `perQuestID` award XP. Quests without
/// an entry return `nil` from `xp(for:)` and are skipped — intentional safety
/// valve so a new quest definition can ship without accidentally granting a
/// stage-default XP value the product team never signed off on.
enum QuestXPRewards {

    /// XP values are product-decided. Update via explicit PR — do NOT derive
    /// from metrics or tiers. Dates in inline comments track the decision.
    private static let perQuestID: [String: Int] = [
        // 2026-04-20 — Learning Spark tier (course completion — hours of work,
        // highest per-quest reward in Stage 1 / Stage 2).
        QuestDefinition.learningSparkQuestID: 1000,
        QuestDefinition.learningSparkStage2QuestID: 2000
    ]

    /// Returns the XP to award for completing `quest`, or `nil` if the quest has
    /// no product-decided value yet. Callers should skip the XP grant entirely
    /// when `nil` — never substitute a default, never call `LevelStore.addXP(0)`.
    static func xp(for quest: QuestDefinition) -> Int? {
        perQuestID[quest.id]
    }
}
