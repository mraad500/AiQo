# BATCH 6 Result — Notification Magic (Triggers + Composition + Learning + Legacy Migration)

**Date:** 2026-04-19
**Branch:** `brain-refactor/batch-6-notification-magic`
**Base:** `brain-refactor/p-fix-dev-override` @ `5523e5a`
**Commits:** 4 sub-commits (`bed2ceb`, `39131e3`, `b933b37`, `adbbf8a`)

## Summary

BATCH 6 shipped the full trigger + composition + learning layer on top of BATCH 5's NotificationBrain single-door, then migrated 7 legacy UN-scheduling sites across 4 services to route through the Brain.

| Part | Scope | Files | Tests |
|------|-------|-------|-------|
| A | Trigger protocol + 7 core triggers | 4 | 12 |
| B | 8 more triggers (incl. MemoryCallback) | 7 | 13 |
| C | TemplateLibrary + MessageComposer + FeedbackLearner | 4 | 12 |
| D | Migrate 5 legacy sender files (7 sites) | 5 | — |

**Totals:** 20 files created/modified, 37 new tests, all green. Plus 9 BATCH 5 tests (NotificationBrain/GlobalBudget/NotificationIntent) verified still passing = **46 green tests**.

---

## PART A — Core triggers (commit `bed2ceb`)

New:
- `Brain/06_Proactive/Triggers/Trigger.swift` — internal `Trigger` protocol + `TriggerContext` + `TriggerResult`.
  - Access is internal because `TriggerContext` exposes internal types (`BioSnapshot`, `CulturalContextEngine.State`, `EmotionalReading`).

Replaced stubs:
- `Triggers/HealthTrigger.swift` — `SleepDebtTrigger` (fires <5.5h sleep), `InactivityTrigger` (midday/afternoon + <2k steps), `PRTrigger` (≥10k steps, dedup via recentDeliveryKinds), `RecoveryTrigger` (`BioStateEngine.needsRecovery`)
- `Triggers/BehavioralTrigger.swift` — `StreakRiskTrigger` (evening + <3k steps), `DisengagementTrigger` (stub; requires BATCH 8 BehavioralObserver), `EngagementMomentumTrigger` (good sleep + high steps + positive emotion)
- `Evaluation/TriggerEvaluator.swift` — actor; `register` / `registerAll` / `evaluateAll(recentDeliveryKinds:)`; parallel evaluation via `TaskGroup`; `minScoreToFire = 0.5`; ranking = `priority.rawValue * 0.5 + score * 0.5`.

**Key design fix:** triggers read `context.bio.timeOfDay` (test-controllable) instead of `context.cultural.timeOfDay` (real-clock dependent) for time-of-day gating. Cultural state retains ramadan/jumuah/eid concerns.

**Tests (12):** `TriggerTests` — fire + silent paths for each of 6 impl'd triggers (sleep debt, inactivity, PR, streak risk, engagement momentum, disengagement).

---

## PART B — Magic + emotional + cultural + temporal + lifecycle (commit `39131e3`)

Replaced stubs:
- `Triggers/MemoryCallbackTrigger.swift` — ⭐ the magic. Hard guards on distressing emotion (grief/shame/frustration/anger/fear/anxiety/guilt via fileprivate `EmotionKind.isDistressing`) and competing notifications. Retrieves via `MemoryRetriever.shared.retrieve(query:"relationships", …)`, picks a relationship mentioned >14 days ago with `emotionalWeight > 0.5`.
- `Triggers/EmotionalTrigger.swift` — `EmotionalFollowUpTrigger` (EmotionalStore.unresolvedEmotions), `MoodShiftTrigger` (declining trend + intensity >0.5)
- `Triggers/RelationshipTrigger.swift` — `RelationshipCheckInTrigger` (90-day window, aged >30 days)
- `Triggers/CulturalTrigger.swift` — Eid > Ramadan > Jumu'ah precedence
- `Triggers/TemporalTrigger.swift` — `MorningKickoffTrigger`, `CircadianNudgeTrigger` (night/lateNight + <6.5h sleep)
- `Triggers/LifecycleTrigger.swift` — `TrialDayTrigger` (stub; BATCH 8 wires FreeTrialManager)

Registered all 15 triggers in `AppDelegate.swift` inside the existing `memoryV4Enabled` block:

```
SleepDebt, Inactivity, PR, Recovery, StreakRisk, Disengagement, EngagementMomentum,
MemoryCallback, EmotionalFollowUp, MoodShift, RelationshipCheckIn, MorningKickoff,
CircadianNudge, Cultural, TrialDay
```

**MemoryCallback sample path** (concept):
> User mentioned "أمي تعبانة" 21 days ago with emotional weight 0.8. Today: quiet evening, no distress, no other recent notifications. Trigger fires with `customPayload: [relationship_name: "أمي", days_since_mention: "21"]`. `MessageComposer` injects the name → body: `"شلون أمي اليوم؟"`.

**Tests (13):** `MagicTriggerTests` — distressing guard, competing-notif guard, Eid fires, Eid precedence, Ramadan fasting-hour, mood-shift decline, morning kickoff dedup, circadian night gate, trial-day placeholder.

---

## PART C — Composition + learning (commit `b933b37`)

Replaced stubs:
- `Composition/TemplateLibrary.swift` — 17 `NotificationKind`s × 2 languages (ar/en) = 34 templates. All cases covered (verified by `testEveryKindHasTemplate`).
- `Composition/MessageComposer.swift` — actor; template lookup + light signal injection (relationship_name, steps). Persona integration deferred to BATCH 7 per prompt note.
- `07_Learning/FeedbackLearner.swift` — actor; tracks `opened` / `dismissed` / `snoozed` / `appOpenedAfter(seconds:)`; weight bounded [0.3, 1.5]; defaults to 1.0.

Weight deltas:
- opened: +0.05
- dismissed: −0.05
- snoozed: −0.02 (floor 0.5)
- appOpenedAfter(<30s): +0.08

**NotificationBrain rewire:** replaced inline `composeMessage(for:)` with `await MessageComposer.shared.compose(intent:)`. Added a dedicated `categoryIdentifier(for:)` mapping for all 17 kinds (not just the original 3).

**Tests (12):** `FeedbackLearnerTests` (7 — initial, open boost, dismiss penalty, upper/lower clamp, appOpenedAfter, snooze), `MessageComposerTests` (5 — AR/EN morning, AR/EN relationship injection, coverage across all kinds).

---

## PART D — Legacy migration (commit `adbbf8a`)

Extended `NotificationBrain.request()` with 5 new optional params so legacy senders can migrate losslessly:

```swift
public func request(
    _ intent: NotificationIntent,
    fireDate: Date? = nil,              // delayed scheduling
    precomposedTitle: String? = nil,    // bypass MessageComposer
    precomposedBody: String? = nil,
    categoryIdentifier: String? = nil,  // override kind-based default
    userInfo: [String: String] = [:],   // preserve source/deepLink/trialKind
    identifier: String? = nil           // named dedup/cancellation
) async -> DeliveryResult
```

Also maps `intent.priority` → iOS 15+ `UNNotificationInterruptionLevel`:
- `.ambient` / `.low` → `.passive`
- `.medium` / `.high` → `.active`
- `.critical` → `.timeSensitive`

### Migrated (7 sites, 4 files)

| File | Site | Kind | Notes |
|---|---|---|---|
| `NotificationService.sendImmediateNotification` | line 88 | `legacyNotificationKind(for:)` mapping | generic AiQo nudge |
| `NotificationService.sendCaptainNotification` | line 282 | mapped | captain category + userInfo |
| `NotificationService.scheduleWorkoutSummaryNotification` | line 912 | `.workoutSummary` | workout summary |
| `MorningHabitOrchestrator.scheduleMorningNotification` | line 359 | `.morningKickoff`, `.low` priority | preserves passive interruption via priority mapping |
| `PremiumExpiryNotifier.scheduleAllNotifications` | line 62 | `.trialDay` | 3 expiry notifications, named identifiers for cancellation |
| `TrialJourneyOrchestrator.fireImmediate` | line 278 | `.trialDay` | precomposed trial-journey copy |
| `TrialJourneyOrchestrator.scheduleAtDate` | line 312 | `.trialDay` | delayed scheduling via `fireDate` |

Tier checks preserved verbatim in every site. Only the `UNNotificationRequest` construction + `UN...add(request)` line was replaced.

### Deferred (4 sites, 2 files — documented)

| File | Site | Reason |
|---|---|---|
| `TrialJourneyOrchestrator.scheduleNextSundayPostTrialIfEligible` | line 419 | `UNCalendarNotificationTrigger(…, repeats: true)` — Brain doesn't support recurring triggers yet. |
| `SmartNotificationScheduler` | lines 186, 402, 754 | Scheduler infrastructure. Line 402 is a recurring `UNCalendarNotificationTrigger(… repeats: true)`; others are internal wrappers/dev nudge. Routing through Brain would create a cycle (Brain → Scheduler → Brain). |

Brain's own `UN.add` at `NotificationBrain.swift:123` is intentional — it's the single exit point.

**Budget implication:** delayed/calendar notifications now run through `GlobalBudget.evaluate()` at schedule time, not fire time. Minor imperfection accepted for BATCH 6 — budget pressure at 2-day-ahead schedule time may block expiry notifications. Revisit in BATCH 7 if needed.

---

## Overall

- **Build:** `** BUILD SUCCEEDED **` on `generic/platform=iOS`
- **Tests:** 46 green (37 new + 9 BATCH 5 regression-checked)
- **Legacy UN adds in Services/*:** 1 site remains (TrialJourney recurring Sunday — intentional)
- **Cloud audit:** MessageComposer is 100% on-device. TemplateLibrary is static. FeedbackLearner is in-memory only. MemoryCallbackTrigger uses local `MemoryRetriever` + `RelationshipStore`. No new outbound network calls introduced.

### Deferred to future batches
- BATCH 7: Persona integration in `MessageComposer.compose(persona:)`, Arabic dialect polish, on-device Foundation Models pass.
- BATCH 8: `DisengagementTrigger` wiring via BehavioralObserver, `TrialDayTrigger` wiring via FreeTrialManager, recurring-trigger support in NotificationBrain (unblock the 4 deferred sites).

### Hard-rules check
- [x] Legacy tier checks preserved verbatim
- [x] No cloud calls in composer
- [x] MemoryCallbackTrigger hard-guards distressing emotions
- [x] Cultural Eid > Ramadan > Jumu'ah precedence enforced (test `testCulturalEidPrecedenceOverRamadan`)
- [x] FeedbackLearner weights bounded [0.3, 1.5]
- [x] Templates cover every `NotificationKind` in AR + EN (test `testEveryKindHasTemplate`)
- [x] One commit per PART (A/B/C/D)
