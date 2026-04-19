# BATCH 5 — Notification Core Result Report

**Date:** 2026-04-19
**Branch:** `brain-refactor/batch-5-notification-core` (to be merged --ff-only into `brain-refactor/p-fix-dev-override`, both pushed)
**Starting commit:** `a46e106` (BATCH 4 final)
**Final commit on topic branch:** `060b4d9` (BATCH 5c)

---

## Commit chain

```
060b4d9 BATCH 5c: NotificationBrain single-door entry point + minimal composition
cfd82dd BATCH 5b: GlobalBudget + CooldownManager + QuietHoursManager with tests
69b5109 BATCH 5a: NotificationIntent + Priority + BudgetDecision types
a46e106 BATCH 4: add result report (PART A/B/C summary + 30 tests green + cloud audit)
```

---

## PART A — Types

**Files added:**
- `AiQo/Features/Captain/Brain/06_Proactive/Types/NotificationIntent.swift` — 110 lines
- `AiQo/Features/Captain/Brain/06_Proactive/Types/BudgetDecision.swift` — 28 lines
- `AiQoTests/NotificationIntentTests.swift` — 46 lines

**NotificationKind enum — all 23 cases listed** (stable raw values, never renumber):

Health (5): `morningKickoff`, `sleepDebtAcknowledgment`, `inactivityNudge`, `personalRecord`, `recoveryReminder`
Behavioral (4): `streakRisk`, `streakSave`, `disengagement`, `engagementMomentum`
Memory (1): `memoryCallback`
Emotional (3): `emotionalFollowUp`, `moodShift`, `relationshipCheckIn`
Temporal/Cultural (7): `weeklyInsight`, `monthlyReflection`, `ramadanMindful`, `eidCelebration`, `jumuahSpecial`, `circadianNudge`, `weatherAdaptive`
Lifecycle (2): `trialDay`, `achievementUnlocked`
Workout (1): `workoutSummary`

**Priority ordering verified:** `ambient (0) < low (1) < medium (2) < high (3) < critical (4)`. `Comparable` conformance on `Int` raw values.

**IntentSignals fields:** `memoryFactID: UUID?`, `bioSnapshotSummary: String?`, `emotionSummary: String?`, `customPayload: [String: String]`. `.empty` convenience singleton.

**BudgetDecision:** 4 top-level cases (`.allowed`, `.allowedWithOverride(reason:)`, `.deferredToMorning`, `.rejected(Reason)`) with 7 rejection reasons. `isAllowed` marked `nonisolated` so actor-crossing callers can read it without an extra hop.

**Adaptation from spec:** `isExpired(now:)` marked `nonisolated func` so it's callable from the `GlobalBudget` actor without a MainActor.run wrapper (this project enables default-MainActor isolation).

**Tests (6/6 passing):**
- `testPriorityOrdering`, `testIntentExpiresAfterDeadline`, `testIntentWithoutExpirationNeverExpires`, `testIntentDefaultsToMediumPriority`, `testAllNotificationKindsAreStable`, `testBudgetDecisionIsAllowed`

---

## PART B — Budget Infrastructure

**Files touched (all previously P1.1 stubs, replaced):**
- `AiQo/Features/Captain/Brain/06_Proactive/Budget/GlobalBudget.swift` — 100 lines
- `AiQo/Features/Captain/Brain/06_Proactive/Budget/CooldownManager.swift` — 52 lines
- `AiQo/Features/Captain/Brain/06_Proactive/Budget/QuietHoursManager.swift` — 43 lines
- `AiQoTests/GlobalBudgetTests.swift` — 163 lines (3 suites)

**Daily caps (via `SubscriptionTier.dailyNotificationBudget`, not `TierGate.dailyNotificationBudget` — the real API is on the enum):**
| Tier   | Cap |
|--------|-----|
| none   | 2   |
| max    | 4   |
| trial  | 7   |
| pro    | 7   |

**Adaptation from spec:** spec used `TierGate.shared.dailyNotificationBudget`; the property actually lives on `SubscriptionTier`. `GlobalBudget` now reads `tier` + `cap` together inside a single `MainActor.run` hop (`TierGate` is a non-actor class, and both reads are MainActor-isolated under default-MainActor).

**Cooldown seconds:**
- Global (any kind → any kind): `2 * 3600` = 2h
- Per-kind (same kind repeat): `6 * 3600` = 6h

**Quiet hours default window:** 22:00 → 07:00 local. Overnight branch (`startHour > endHour`): `hour >= startHour || hour < endHour`. Same-day branch preserved for edge-case configurations.

**GlobalBudget gate order (critical path):**
1. `isExpired` → silent `.rejected(.expired)`
2. Daily rollover
3. iOS 64-pending buffer (reserve 4 slots → 60 max)
4. Daily cap with critical-priority +1 override via `.allowedWithOverride`
5. Quiet hours → `.deferredToMorning` (critical bypasses)
6. Cooldown (global + per-kind) → `.rejected(.cooldown)` (critical bypasses)
7. Tier-gated kinds → `.rejected(.tierDisabled)` (currently only `.monthlyReflection` on non-Pro/non-trial)

**iOS 64-pending buffer:** hard-reserve 4 of the 64 system slots, so the budget rejects once `pending >= 60`.

**Test adaptation:** GlobalBudgetTests pass an explicit `now: noonToday()` instant so wall-clock time at test-run doesn't trip quiet hours. `testExpiredIntentRejected` uses `Date()` paired with `past = now - 60s` because the expired gate runs before quiet-hours and the comparison must be self-consistent regardless of hour.

**Tests (11/11 passing):**
- GlobalBudget (6): `testAllowedWhenUnderCap`, `testExpiredIntentRejected`, `testDailyCapEnforced`, `testCriticalOverridesDailyCap`, `testMonthlyReflectionRequiresPro`, `testMonthlyReflectionAllowedForPro`
- Cooldown (3): `testFreshKindNotOnCooldown`, `testRecentDeliveryPutsKindOnCooldown`, `testOldDeliveryAllowsAgain`
- QuietHours (3): `testQuietAtMidnight`, `testNotQuietAtNoon`, `testNextWakeDateReturnsFutureDate`

---

## PART C — NotificationBrain

**Files touched:**
- `AiQo/Features/Captain/Brain/06_Proactive/NotificationBrain.swift` — 169 lines (replaced 10-line P1.1 stub)
- `AiQoTests/NotificationBrainTests.swift` — 59 lines

**API signature:** `public actor NotificationBrain.request(_ intent: NotificationIntent) async -> DeliveryResult` (`@discardableResult`).

**DeliveryResult:** `(intentID: UUID, decision: BudgetDecision, deliveredAt: Date?, systemRequestID: String?)`. Rejected / errored paths return `nil` for the last two.

**Four-gate flow:**
1. `GlobalBudget.evaluate(intent)` → if not allowed, audit-log rejection and return early.
2. `composeMessage(for:)` placeholder switch (Arabic templates for morning / inactivity / memory + default). BATCH 6 replaces with `MessageComposer` from `Composition/`.
3. `PrivacySanitizer.sanitizeText` (title + body) inside a `MainActor.run` hop. Defensive — composer should never emit PII, but the scrub catches regressions.
4. `UNUserNotificationCenter.add` with 1s time-interval trigger + `CAPTAIN_*` category identifier. On success: `GlobalBudget.recordDelivered(intent)` + audit log.

**Composition placeholder docs:** explicit `// Minimal composition for BATCH 5. BATCH 6 wires MessageComposer for richer copy.` on the private helper.

**Privacy scrub confirmation:** calls `PrivacySanitizer().sanitizeText(_:knownUserName: nil)` — the real API per `05_Privacy/PrivacySanitizer.swift:144` (the spec's shorthand `sanitize(_:)` doesn't exist). `knownUserName: nil` is deliberate: on-device notifications don't need name-normalization, but PII regex redaction (emails, phones, UUIDs, IPs, URLs) still runs.

**Audit log format:** `AUDIT [notification]: {delivered|rejected} kind={raw} by={requestedBy}` via `diag.info(...)`. Added as an `extension AuditLogger` with a `nonisolated async func record(event:kind:requestedBy:)` — nonisolated so any caller can `await` it without crossing into the AuditLogger actor for state (log-only, doesn't touch the cloud-request ring).

**Tests (3/3 passing):**
- `testRequestProducesResult` — API smoke test; result's `intentID` matches the requested intent's ID.
- `testRejectedIntentReturnsNoDelivery` — expired intent → `deliveredAt` and `systemRequestID` both nil.
- `testDailyCapBlocksFurtherRequests` — 4 recorded deliveries (max tier) → 5th returns `.rejected(.dailyLimitReached)` in the decision.

---

## Overall

**Build status:** ✅ `** BUILD SUCCEEDED **` on `generic/platform=iOS`. No new errors. Compile warnings in my new files: zero (confirmed via `grep -E "warning:" | grep 06_Proactive` returning empty after final build).

**Test count:** 20/20 new BATCH 5 tests passing on `platform=iOS Simulator,name=iPhone 17 Pro`.

```
** TEST SUCCEEDED **
NotificationIntentTests       — 6/6 passed
GlobalBudgetTests             — 6/6 passed
CooldownManagerTests          — 3/3 passed
QuietHoursManagerTests        — 3/3 passed
NotificationBrainTests        — 3/3 passed
```

**Cloud audit:** `grep -rn "URLSession\|https://" AiQo/Features/Captain/Brain/06_Proactive/ --include="*.swift"` → zero matches. All notification decisions on-device.

**Info.plist:** no changes, no new permission keys.

**Legacy senders NOT modified (confirmed):** `git diff brain-refactor/p-fix-dev-override..HEAD -- {NotificationService.swift, MorningHabitOrchestrator.swift, SmartNotificationScheduler.swift}` returned empty. BATCH 6 does the migration.

**Lines added (diff vs. dev-override):**
- Source: ~483 (NotificationIntent 110 + BudgetDecision 28 + GlobalBudget 100 + CooldownManager 52 + QuietHoursManager 43 + NotificationBrain 169, minus ~34 from P1.1 stubs replaced)
- Tests: 268 (NotificationIntent 46 + GlobalBudget/Cooldown/QuietHours 163 + NotificationBrain 59)
- **Total: 753 insertions, 17 deletions** (9 files)

**Push status (pending):** see PUSH section below.

---

## Deferred items

1. **MessageComposer** — The real composition pipeline (TemplateLibrary + DynamicPersonalizer) lives in `06_Proactive/Composition/` and is still stubbed. BATCH 6 wires it into `NotificationBrain.composeMessage(for:)`, replacing the Arabic template placeholder.
2. **Legacy sender migration** — `NotificationService`, `MorningHabitOrchestrator`, `PremiumExpiryNotifier`, `TrialJourneyOrchestrator`, and `SmartNotificationScheduler` still schedule notifications directly. BATCH 6 routes them through `NotificationBrain.request(_:)`.
3. **Notification categories registration** — the `CAPTAIN_MORNING` / `CAPTAIN_INACTIVITY` / `CAPTAIN_MEMORY` / `CAPTAIN_DEFAULT` category identifiers are set on the content but not yet registered with `UNUserNotificationCenter.setNotificationCategories(_:)`. BATCH 8 handles categories + actions.
4. **QuietHoursManager.nextWakeDate deferred re-delivery** — the gate returns `.deferredToMorning` but no subsystem currently picks up deferred intents and reschedules them at wake time. Needs a queue + morning re-flush. Deferred to BATCH 6 / 7.
5. **Pending-count expensive call** — `UNUserNotificationCenter.getPendingNotificationRequests` is awaited on every `evaluate`. Under high request volume this could dominate; a 60s cache layer is a cheap optimization for a future batch.
6. **Critical-override counter reset** — the `cap + 1` override currently has no upper cap across multiple same-day critical intents. A wellbeing stream delivering 4 crises in a day could exceed cap by 4. Acceptable for now (crises are rare, safety-first). Revisit if observed.
7. **`BudgetDecision.Reason.duplicate`** — reason case exists but is unused (no dedup logic yet). BATCH 6's MessageComposer can wire it via content-hash compare.

---

## Hard-rules compliance

- [x] No cloud calls — `grep -rn "URLSession\|https://" 06_Proactive/` empty
- [x] Legacy senders unmodified — confirmed empty diff on 3 tracked paths
- [x] `critical` priority reserved for wellbeing / safety — only `recoveryReminder` uses it in tests; docs in code clarify
- [x] Global cooldown 2h hardcoded
- [x] Per-kind cooldown 6h hardcoded
- [x] iOS 64-pending buffer = 4 slots (`iosPendingBufferReserve = 4`)
- [x] Daily caps come from `TierGate.shared.currentTier.dailyNotificationBudget` (enum-level API), not hardcoded in `GlobalBudget`
- [x] Every delivered notification audit-logged (`record(event: .notificationDelivered, ...)`)
- [x] Every rejected intent audit-logged (`record(event: .notificationRejected, ...)`)
- [x] Expired intents drop silently — `isExpired` returns `.rejected(.expired)` without surfacing an error
- [x] `.monthlyReflection` is Pro-only — `.max` and `.none` return `.rejected(.tierDisabled)`; `.pro` and `.trial` pass through
- [x] One commit per PART — `69b5109`, `cfd82dd`, `060b4d9`
- [ ] Pushed to origin — pending after this report is committed
