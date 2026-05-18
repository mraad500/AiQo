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

## Memory V4 shadow-write silent failures

**Priority**: Low
**Added**: 2026-05-18
**Trigger to revisit**: When the V4 actor stores (SemanticStore/EpisodicStore) become the primary read path (i.e. the legacyV3 + shadow-write transition is retired)
**Rationale**: `MemoryStore` writes the primary store (V3 or V4 per `storageMode`) and additionally shadow-writes into the new actor-based `SemanticStore`/`EpisodicStore` (gated by `MemoryV4Gate.isOn`). Shadow-write failures (`SemanticStore.syncFact` etc.) are not surfaced — if one fails, the actor store silently lags the primary. Impact is currently bounded because the actor stores are not yet the primary read path (intentional transition architecture), so a lagged shadow does not affect what the user sees. Becomes load-bearing only at the actor-only cutover.
**Estimated effort**: 1–2 hours (add a logged/analytics path on shadow-write failure, mirroring `recordMigrationFailure`)
**Risk**: Low — additive observability only; do NOT change dual-write semantics pre-release.

---

## CaptainPersonalizationStore actor conversion

**Priority**: Medium
**Added**: 2026-05-18
**Trigger to revisit**: When the Captain memory V3→V4 SwiftData cutover lands (same persistence subsystem — convert together to avoid a second migration of these call sites)
**Rationale**: `CaptainPersonalizationStore` (`AiQo/Features/Captain/Brain/08_Persona/CaptainPersonalization.swift:306`) serializes SwiftData access via a hand-rolled `DispatchQueue` + `queue.sync`. `currentSnapshot()`/`save()` therefore block the calling thread on a `ModelContext` fetch/save; some call sites are main-thread (notably `QuickStartOnboardingView`). The clean fix is converting the type to an `actor` with an `async` API.
**Estimated effort**: 3–5 hours + onboarding smoke test
**Risk**: Higher than it looks — `QuickStartOnboardingView.init` (`AiQo/Features/Onboarding/QuickStartOnboardingView.swift:36`) calls `currentSnapshot()` from a **synchronous SwiftUI `View.init`**, which cannot `await`. An actor conversion forces redesigning that screen's prefill data flow (init-time → `.task`/`@State` with a loading state) — a UX-bearing change to the first-run onboarding flow. Deferred because the blast radius (8 call sites incl. critical onboarding) is disproportionate to the severity: the blocked work is a single-record local fetch (no network), and `workoutReminderTime()`/`sleepReminderTime()` call `currentSnapshot()` without their own `queue.sync`, so there is **no reentrancy/deadlock risk** — only a brief, sub-millisecond main-thread stall.

### Call sites to migrate (when revisited)

- `AiQo/App/AppDelegate.swift:67` — `configure(container:)` (trivial)
- `AiQo/Features/Captain/Brain/03_Reasoning/CaptainContextBuilder.swift:231`, `CognitivePipeline.swift:333` — `currentSnapshot()` (async pipeline — easy)
- `AiQo/Features/Captain/Brain/06_Proactive/SmartNotificationScheduler.swift:301,328,864`
- `AiQo/Features/Onboarding/QuickStartOnboardingView.swift:36` (sync `init` — the hard one), `:586` (`save()` in a button action — wrap in `Task`)
- `AiQo/Services/Trial/TrialPersonalizationReader.swift:15`, `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:180`
- Update `AiQoTests/CaptainPersonalizationStoreTests.swift` to `await` the now-async API

---

# Known Limitations

Constraints of the current implementation that are *not* bugs but should be documented for future work. Unlike tech-debt items, these have no expectation of resolution on a particular timeline — they are the cost of shipped compromises.

## QuestEngine flag-flip requires app restart

- **Affected flags**: `LEARNING_SPARK_STAGE2_ENABLED`, `PLANK_LADDER_CHALLENGE_ENABLED` (and any future flag that modifies `QuestDefinitions.all`)
- **Reason**: `QuestEngine.shared` is a singleton; `stages` is a stored `@Published` property set once in `init()` from `QuestDefinitions.stageModels()`. `QuestSwiftDataStore.definitionsByID` also caches at init.
- **Impact**: Flag flips mid-session don't propagate until app restart.
- **Acceptable because**: Info.plist-backed flags don't change mid-session; only dev/rollback workflow matters, and rollback flow always involves a build+reinstall.
- **Future improvement**: If remote config is added, `QuestEngine` needs a `rebuildStages()` method (post-launch concern).
