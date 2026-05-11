# BATCH 1 — Cleanup Result (2026-04-18)

## Hashes

- **Starting commit:** `8220b32` — P_MERGE_LOST_WORK (origin/brain-refactor/p-fix-dev-override)
- **Ending commit:** `63d2cda` — BATCH 1c
- Sub-commits (newest first):
  - `63d2cda` BATCH 1c: polish CaptainLockedView
  - `b2e776d` BATCH 1b: wrap 9 canAccess sites
  - `63a910e` BATCH 1a: relocate 10 V4 Models

Branch: `brain-refactor/batch-1-cleanup`

## PART A — V4 Models Relocation

### Moved (10 files, via `git mv`, history preserved)

| From | To |
|---|---|
| AiQo/Core/Models/BioSnapshot.swift | AiQo/Features/Captain/Brain/02_Memory/Models/BioSnapshot.swift |
| AiQo/Core/Models/ConsolidationDigest.swift | AiQo/Features/Captain/Brain/02_Memory/Models/ConsolidationDigest.swift |
| AiQo/Core/Models/EmotionalMemory.swift | AiQo/Features/Captain/Brain/02_Memory/Models/EmotionalMemory.swift |
| AiQo/Core/Models/EpisodicEntry.swift | AiQo/Features/Captain/Brain/02_Memory/Models/EpisodicEntry.swift |
| AiQo/Core/Models/MonthlyReflection.swift | AiQo/Features/Captain/Brain/02_Memory/Models/MonthlyReflection.swift |
| AiQo/Core/Models/ProceduralPattern.swift | AiQo/Features/Captain/Brain/02_Memory/Models/ProceduralPattern.swift |
| AiQo/Core/Models/Relationship.swift | AiQo/Features/Captain/Brain/02_Memory/Models/Relationship.swift |
| AiQo/Core/Models/SemanticFact.swift | AiQo/Features/Captain/Brain/02_Memory/Models/SemanticFact.swift |
| AiQo/Core/Models/WeeklyMetricsBuffer.swift | AiQo/Features/Captain/Brain/02_Memory/Models/WeeklyMetricsBuffer.swift |
| AiQo/Core/Models/WeeklyReportEntry.swift | AiQo/Features/Captain/Brain/02_Memory/Models/WeeklyReportEntry.swift |

Audit deferred only 8; re-inspection showed `WeeklyMetricsBuffer` and
`WeeklyReportEntry` also live in the Captain `ModelContainer` per their
doc comments ("Lives in the Captain ModelContainer") and are consumed
only under `Brain/02_Memory/Stores/`, so they were moved as well.

### Not moved (non-Captain-Brain; left at AiQo/Core/Models/)

| File | Reason |
|---|---|
| ActivityNotification.swift | Plain `struct`/`enum` (notification payload, app-wide) |
| LevelStore.swift | `ObservableObject`, not an `@Model` (level/shield state) |
| NotificationPreferencesStore.swift | Plain `final class` (UserDefaults wrapper) |

### Destination conflicts

None. All 10 destination paths were empty before the move (P1.1 stubs
for these names were not created; schemas at the same folder were
separate files).

### Build status after Part A

`** BUILD SUCCEEDED **` (iOS Debug, `generic/platform=iOS`).

## PART B — DevOverride Coverage

### Sites wrapped (9 — all 7 from audit + 2 extras found by re-grep)

| # | File | Line | Feature | Pattern |
|---|---|---|---|---|
| 1 | AiQo/Core/CaptainVoiceAPI.swift | 97 | `.premiumVoice` | throwing guard |
| 2 | AiQo/Core/CaptainVoiceService.swift | 213 | `.premiumVoice` | `guard … else { return false }` |
| 3 | AiQo/Core/CaptainVoiceService.swift | 295 | `.premiumVoice` | `guard … else { return }` |
| 4 | AiQo/Core/CaptainVoiceCache.swift | 138 | `.premiumVoice` | actor-isolated; awaits MainActor for DevOverride read |
| 5 | AiQo/Features/Kitchen/KitchenPlanGenerationService.swift | 19 | `.multiWeekPlan(weeks:)` | throwing guard |
| 6 | AiQo/Features/Kitchen/MealPlanView.swift | 415 | `.multiWeekPlan(weeks:)` | `guard … else { showPaywall = true; return }` |
| 7 | AiQo/Features/Kitchen/SmartFridgeScannerView.swift | 318 | `.photoAnalysis` | `guard … else { return }` |
| 8 | AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift | 319 | `.weeklyInsightsNarrative` | guard with template fallback |
| 9 | AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift | 88 | `.premiumVoice` | boolean-in-if (`if A && (DevOverride.unlockAllFeatures \|\| canAccess…)`) |

Additional (outside the audit's explicit list, but a DevOverride-wrap
concern in the same spirit):

| 10 | AiQo/App/MainTabScreen.swift | 54 | `.captainChat` | SwiftUI `if DevOverride.unlockAllFeatures \|\| tierGate.canAccess(.captainChat)` — this is the Captain-tab gate; unwrapping it meant dev users saw `CaptainLockedView` instead of the unlocked Captain flow. Wrap here required before Part C eye-test could be meaningful. |

For CaptainVoiceCache (actor context), a plain `if !DevOverride.unlockAllFeatures` would cross main-actor isolation and generated a Swift 6 warning. Fixed by reading the flag via `await MainActor.run { DevOverride.unlockAllFeatures }` then branching on the local. No other sites needed this pattern.

### Coverage counts

- Total `canAccess(` occurrences: **48**
- Of those that are call-sites (excluding the single definition at TierGate.swift:99): **47**
- Call-sites wrapped with DevOverride (inline or in wrapping `if !DevOverride.unlockAllFeatures` within ≤4 lines above): **45**

### Not touched — flagged for future follow-up

Two defensive secondary gates live in `NotificationService.swift` after
an already-wrapped primary gate earlier in the same function:

- `AiQo/Services/Notifications/NotificationService.swift:201` — `guard await MainActor.run(body: { TierGate.shared.canAccess(.captainNotifications) }) else { return }` (after primary gate at line 194).
- `AiQo/Services/Notifications/NotificationService.swift:628` — same pattern (after primary gate at line 621).

Both appear to be deliberate MainActor-hopping re-checks, not simple
duplicates. Per the prompt's "do not restructure canAccess sites"
rule, these were left as-is. With DevOverride ON the primary gate is
bypassed but these secondary gates will still block — a minor contradiction worth addressing in a focused follow-up that can also evaluate whether the re-check serves a real purpose (race condition) or is stale double-guarding.

### Build status after Part B

`** BUILD SUCCEEDED **` (iOS Debug). Pre-existing Swift 6 actor-isolation warning on `CaptainVoiceCache.swift:138` resolved via the MainActor-hop shown above.

## PART C — CaptainLockedView Polish

### Instantiation site

`AiQo/App/MainTabScreen.swift` — the else branch of the Captain tab gate.

### Arabic strings used (verbatim, copy/paste)

- `title`: `محادثة حمودي`
- `subtitle`: `افتح الكابتن حمودي كامل مع اشتراك AiQo. كل الميزات، بلهجتك، في أي وقت.`
- SF Symbol (`iconSystemName`): `message.badge.waveform.fill` — no emoji, brand §15 compliant.

### Upgrade tap

```swift
@State private var showCaptainPaywall = false
…
onUpgradeTap: { showCaptainPaywall = true }
…
.sheet(isPresented: $showCaptainPaywall) {
    PaywallView(source: .captainGate)
}
```

### PaywallSource case used

`.captainGate` — matches the pre-existing case used by
`CaptainChatView.swift:160` and `CaptainScreen.swift:248`. No new
`PaywallSource` case was added.

### Manual eye-test

Deferred. The prompt specifies toggling `AIQO_DEV_UNLOCK_ALL = false`
in Info.plist for a live simulator test. Doing so is a local-only
state change (Info.plist diff must not be committed). Given the
headless environment here, this step is marked **not performed in
this session**; the author should run the three-step toggle/observe/
restore sequence before merging to `brain-refactor/p-fix-dev-override`
per the prompt:

1. Set `AIQO_DEV_UNLOCK_ALL = false` in Info.plist.
2. Run app, open Captain tab → verify Arabic text renders RTL, tap
   `افتح AiQo Max` → confirm existing `PaywallView(source: .captainGate)`
   sheet appears.
3. Restore `AIQO_DEV_UNLOCK_ALL = true` and **do not commit** the
   Info.plist diff.

Build-level correctness was verified via xcodebuild.

## Overall Verification

- **Full build:** `** BUILD SUCCEEDED **` (iOS Debug, `generic/platform=iOS`).
- **Focused test pass** on iPhone 17 Pro simulator:
  - `AiQoTests/TierGateTests` — 15/15 passed.
  - `AiQoTests/SemanticStoreTests` — 4/4 passed.
  - `AiQoTests/EpisodicStoreTests` — 4+ passed (test suite completed; trailing output cut off at tail).
  - Net: `** TEST SUCCEEDED **`.
- **Final greps:**
  - V4 Models at new path: 17 files in `Brain/02_Memory/Models/` (7 pre-existing schemas + 10 moved).
  - `Core/Models/`: only the 3 non-Captain files remain.
  - `grep TODO(P1.3)`: 0 hits.
  - `canAccess(` total: 48; wrapped with DevOverride: 45; 1 is the definition; 2 are the flagged NotificationService secondary gates.

## Deferred / follow-up

- `NotificationService.swift:201` and `:628` belt-and-suspenders
  secondary `canAccess(.captainNotifications)` gates — candidate for a
  focused follow-up that decides whether each is a necessary MainActor
  re-check or a stale double-guard.
- Manual Info.plist-toggle eye-test of the polished
  `CaptainLockedView` (listed above under Part C).
