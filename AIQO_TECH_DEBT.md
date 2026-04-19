# AiQo Tech Debt Log

Living log of deferred refactors, architectural cleanups, and known-good-enough
compromises. Each entry should include a concrete trigger to revisit — avoid
open-ended "someday" items.

---

## Foundation Models helper extraction

**Priority**: Low
**Added**: 2026-04-19
**Trigger to revisit**: When Sleep Architecture on-device path lands (4th call site)
**Rationale**: 3 identical 4-line preambles across `CaptainOnDeviceChatEngine`, `FactExtractor`, and `HamoudiVerificationReasoner`. Collapse into `AppleIntelligence.runOnDevice<Output>` helper to prevent future callers from forgetting the availability gate.
**Estimated effort**: 30 minutes + per-subsystem smoke test
**Risk**: Modifies `FactExtractor`'s blueprint-canonical shape

### Current pattern (duplicated 3×)

```swift
#if canImport(FoundationModels)
if #available(iOS 26.0, *) {
    guard SystemLanguageModel.default.availability == .available else { /* fallback */ }
    let session = LanguageModelSession(instructions: instructions)
    let response = try await session.respond(to: payload)
    // parse…
}
#endif
// fallback…
```

### Proposed shape

```swift
enum AppleIntelligence {
    /// Runs a one-shot `LanguageModelSession` on-device. Returns `fallback()` when
    /// Foundation Models is unavailable, the model is not ready, or generation throws.
    static func runOnDevice<Output: Sendable>(
        instructions: String,
        prompt: String,
        fallback: @autoclosure () -> Output,
        parse: (String) -> Output?
    ) async -> Output { … }
}
```

### Call sites to migrate
- [AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift](AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift) — chat path
- [AiQo/Features/Captain/Brain/02_Memory/Intelligence/FactExtractor.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/FactExtractor.swift) — memory facts (blueprint-canonical — migrate LAST)
- [AiQo/Features/Challenges/LearningSpark/Verification/HamoudiVerificationReasoner.swift](AiQo/Features/Challenges/LearningSpark/Verification/HamoudiVerificationReasoner.swift) — certificate verification

---

## Challenge.swift / QuestDefinitions.swift duality audit

**Priority**: Medium
**Added**: 2026-04-19
**Trigger to revisit**: Post-AUE launch, after first user feedback cycle (approximately 6 weeks post-launch)
**Rationale**: `Challenge.swift` contains an orphaned `plank_ladder` entry and references a non-existent `Plank.Ladder.imageset`. The live Plank Ladder is `s2q3` in `QuestDefinitions.swift` (asset `"2.3"`). `VisionCoachView` is the only consumer of `QuestDailyStore` / `Challenge.all` (used for pushup counting). A full audit should determine: (a) what `Challenge` code is actually live, (b) whether `VisionCoach` pushup logic should migrate to `QuestDefinitions`, (c) what dead code can be safely removed.
**Estimated effort**: 4–8 hours audit + refactor
**Risk**: Potentially wide — touches core pushup counting if done incorrectly

### Known orphans (discovered during Learning Spark Stage 2 rollout)

- [AiQo/Features/Gym/Quests/Models/Challenge.swift:234-247](AiQo/Features/Gym/Quests/Models/Challenge.swift) — `plank_ladder` entry with `awardImageName: "Plank.Ladder"` (asset does not exist on disk)
- [AiQo/Features/Gym/Quests/Views/ChallengeDetailView.swift](AiQo/Features/Gym/Quests/Views/ChallengeDetailView.swift), [ChallengeCard.swift](AiQo/Features/Gym/Quests/Views/ChallengeCard.swift), [ChallengeRunView.swift](AiQo/Features/Gym/Quests/Views/ChallengeRunView.swift) — never instantiated from any parent view
- [AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift](AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift) — only consumer is `VisionCoachView` (pushup counting + HealthKit refresh)

### Live path (for reference when auditing)

`ClubRootView` → `BattleChallengesView(questEngine:)` → iterates `questEngine.stages` (built from `QuestDefinitions.stageModels()`) → `QuestCard` + `QuestDetailSheet`.

---

# Known Limitations

Constraints of the current implementation that are *not* bugs but should be documented for future work. Unlike tech-debt items, these have no expectation of resolution on a particular timeline — they are the cost of shipped compromises.

## QuestEngine flag-flip requires app restart

- **Affected flags**: `LEARNING_SPARK_STAGE2_ENABLED`, `PLANK_LADDER_CHALLENGE_ENABLED` (and any future flag that modifies `QuestDefinitions.all`)
- **Reason**: `QuestEngine.shared` is a singleton; `stages` is a stored `@Published` property set once in `init()` from `QuestDefinitions.stageModels()`. `QuestSwiftDataStore.definitionsByID` also caches at init.
- **Impact**: Flag flips mid-session don't propagate until app restart.
- **Acceptable because**: Info.plist-backed flags don't change mid-session; only dev/rollback workflow matters, and rollback flow always involves a build+reinstall.
- **Future improvement**: If remote config is added, `QuestEngine` needs a `rebuildStages()` method (post-launch concern).
