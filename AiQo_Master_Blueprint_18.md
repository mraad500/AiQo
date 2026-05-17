<div align="center">

<img src="AiQo.png" width="160" height="160" alt="AiQo app icon" />

# **AiQo**

*Master Blueprint · v18*

**Arabic-first AI health & coaching · iOS · Captain Hamoudi**

</div>

---

# AiQo Master Blueprint 18

*The current, forward-looking master document for the AiQo iOS app. Authored 2026-05-10 by the in-tree hygiene pass; refreshed 2026-05-12 alongside the v1.0.5 release for the Plan multi-day + body-photo work. **Supersedes** [Blueprint 17](AiQo_Master_Blueprint_17.md) for forward guidance only — Blueprint 17 remains the canonical historical snapshot at commit `39ca529` and the deep-reference text for the eleven Brain subsystems, the conversation-turn data flow, the proactive-notification data flow, and the §1–§36 batch chronology. Read 17 for "how was this built"; read 18 for "what's the state today and what's next."*

---

> **2026-05-12 refresh — read this first.** This document was originally written for the
> v1.0.1 → v1.0.2 cut on the `brain-refactor/p-fix-dev-override` branch. Three releases have
> shipped since: **v1.0.3** (privacy hardening + critical telemetry), **v1.0.4** (Memory V4
> globally enabled + NotificationBrain wired + cleanup sprint), and now **v1.0.5** (Plan
> world-class surface restored to the release line + multi-day plans + optional body-photo
> personalization through Gemini vision). Snapshot table in §1, full timeline in **§2A**.
> Several P0/P1 items in §4–§6 have landed and are now marked **✅ DONE**.

---

> **2026-05-17 update — read this second.** Eleven commits landed after the 2026-05-12
> refresh (cut at `ab6885e`) before the App Store archive — HEAD is now `2df0a9a`. The
> headline is a **notification-system v1.0.5 redesign** (free-tier basic-life
> notifications, an uncapped trial lane, a tier-scaled hard cap, unified quiet hours)
> plus a **world-class Plan-intake redesign**, a Captain "always produce a plan"
> guarantee, UI polish + art refresh, and a pinned-plan persistence triple-fix. Full
> account in **§2A → "v1.0.5 post-refresh hardening (2026-05-17)"**. A clean Release
> build at `2df0a9a` is green (0 errors / 0 warnings). **Public App Store is still at
> v1.0.2 (build 19)** — v1.0.3/1.0.4 were engineering cuts on the release line, not
> public releases; v1.0.5 build 21 is the next public submission.

---

> **2026-05-17 (later) — read this third.** v1.0.5 (build 21) was submitted to App
> Store review and then **withdrawn by the author** after pre-approval issues were
> found. It is being re-cut clean as **v1.0.6 (build 22)**. One commit — `d816d78`,
> pushed to `origin/release/v1.0.4-memory-v4` — lands a **monetization hard-wall**
> (the onboarding paywall now requires Apple's real card-required 7-day StoreKit
> trial; the auto no-card custom trial is no longer minted; existing active trials
> are grandfathered) and **re-anchors the 7-day trial-journey notifications** to the
> real Apple subscription start (`FreeTrialManager.captureStoreKitTrialStart`, called
> from `PurchaseManager`; `TrialJourneyOrchestrator` untouched). A clean Debug
> simulator build is green (`** BUILD SUCCEEDED **`) at `d816d78`. Full account in
> **§2A → "v1.0.6 — hard-wall Apple trial + clean resubmission"**. **Public App Store
> is still v1.0.2 (build 19)**; v1.0.6 build 22 is the next submission, gated on
> App Store Connect intro-offer setup (no code left — see §2A and §6).
>
> **Correction (same day, rev-2 — supersedes the hard-wall description above):**
> the onboarding hard wall was **reversed**. The paywall is **skippable** again
> (the `SubscriptionIntroView` Skip chip always shows); premium surfaces are gated
> **in-app** instead, mirroring the Captain `CaptainLockedView` pattern via
> `AccessManager`: **Captain / Kitchen / My Vibe / Battle → Max, Peaks → Pro**.
> Subscribing (or starting Apple's StoreKit trial) unlocks everything immediately.
> This is the App-Store-safer model ("be smarter than Apple and the user").
> `SceneDelegate` no-auto-trial and the trial-journey re-anchor still stand.
> rev-2 is **uncommitted** at time of writing (`d816d78` is the hard-wall version).

---

> **2026-05-17 (later still) — read this fourth.** A **twelfth Brain subsystem
> shipped: `11_Directives`**, the learn-and-execute layer the Captain previously
> lacked. The user can now **teach the Captain a durable standing instruction** in
> natural Iraqi/English ("بعد كل تمرين حلّل تمريني وقارنه بالي قبله ودزّلي إشعار");
> it is parsed on-device (no LLM round-trip), persisted in a new **Memory Schema V5**
> (one additive model, lightweight V4→V5 migration — same proven pattern as V2→V3),
> mirrored back into every prompt's Working Memory so the Captain confirms it and
> **never forgets it**, and **executed automatically after every workout** through
> `AIWorkoutSummaryService` (deterministic, offline, Iraqi analyze-vs-previous
> notification — no network/LLM/cost on the hot path). Captain memory was also
> **enlarged** per the same request (semantic-fact cap Pro 500→1200 / Max 200→500,
> retrieval depth 25→40 / 10→18, prompt budget 800→1200 tokens & 30→48 entries,
> workout-history window 7→30, persisted chat 200→400). The submission is **re-cut
> as v1.0.5 (build 23)** — `MARKETING_VERSION` 1.0.6→1.0.5, `CURRENT_PROJECT_VERSION`
> 22→23 (build number still increments over the withdrawn 1.0.5/21, satisfying
> Apple's higher-build requirement). Clean Release simulator build green (0 errors /
> 0 warnings, Swift-6 concurrency clean). Full account in **§2A → "v1.0.5 build 23 —
> Captain Directives layer + memory expansion"**.

---

## 0. How to use this document

This blueprint is structured to answer five questions in order:

1. **What is AiQo today?** — §1 Executive Summary
2. **What changed in this hygiene pass?** — §2 The 2026-05-10 Hygiene Pass
3. **How is the codebase laid out now?** — §3 Codebase Map (post-cleanup)
4. **What's actually wrong and what should we fix?** — §4 Security Posture, §5 Architecture Debt
5. **What's the path to v1.1 and beyond?** — §6 Roadmap, §7 Operational Notes

Cross-references use this convention: `Blueprint 17 §3.2.5` means "section 3.2.5 in the prior blueprint," `[CaptainViewModel.swift:225]` means "absolute file path with line number." Every concrete claim in §4 has a `file:line` reference so anyone can verify and fix it.

---

## 1. Executive Summary

AiQo is an Arabic-first iOS health-and-coaching app whose differentiator is **Captain Hamoudi (الكابتن حمّودي)** — a culturally-rooted AI coach with on-device memory, dialect-aware language, and a wellbeing safety net. **AiQo v1.0.6 (build 22, product version `1.0.6`) is the release candidate on `release/v1.0.4-memory-v4` (HEAD `d816d78`, pushed). v1.0.5 (build 21) was submitted to review then withdrawn by the author after pre-approval issues; v1.0.6 is the clean resubmission.** It rolls up five shipped points since this document was first written:

- **v1.0.2** — initial brain-refactor merge (§32–§36 from Blueprint 17: App-Knowledge layer, dynamic welcome, comparative workout analysis, Kitchen world-class upgrade, §35 14-layer cognitive brain refactor).
- **v1.0.3** — privacy hardening + critical telemetry events.
- **v1.0.4** — `MEMORY_V4_ENABLED` flipped globally, NotificationBrain fully wired, cleanup sprint.
- **v1.0.5** — **Plan world-class surface restored to the release line** (PlanPalette + Workout Runner + Insights + Weekly Stats + Exercise Detail + Template Library + Intake Chips + Workout Cards + Flow Views), **multi-day workout plans** (new `WorkoutDay`, `days[]`, `durationWeeks` fields on `WorkoutPlan` + day-picker UI in the active card + day-scoped runner), and **optional body-photo personalization** routed through the same Gemini path as kitchen vision with a dedicated per-purpose consent (`BodyPhotoConsent` + bilingual gesture-locked sheet + Settings revoke surface). **Post-refresh (2026-05-17, §2A):** a **notification-system v1.0.5 redesign** (free-tier basic-life notifications via `TierGate.basicLifeNotifications`, an uncapped trial lane governed solely by `TrialJourneyOrchestrator`, a tier-scaled hard cap, quiet hours unified to 23:00–07:00), a **world-class Plan-intake redesign**, a Captain "always produce a `workoutPlan`" guarantee, kitchen/nutrition/profile/chat polish + art refresh, and a pinned-plan persistence triple-fix.
- **v1.0.6** — **monetization hard-wall** (onboarding paywall now requires Apple's real card-required 7-day StoreKit trial; the auto no-card custom trial is no longer minted; existing active trials grandfathered) and **trial-journey notifications re-anchored** to the real Apple subscription start (`FreeTrialManager.captureStoreKitTrialStart`, called from `PurchaseManager`; `TrialJourneyOrchestrator` logic untouched). Version bumped 1.0.5/21 → 1.0.6/22 (1.0.5 was submitted then withdrawn pre-approval). Commit `d816d78`. Full account in §2A.

**Snapshot at the 2026-05-12 refresh:**

| Dimension | Value |
|---|---|
| iOS app source | **~600 Swift files**, ~120k LOC across the main target |
| Test target | ~63 Swift test files |
| Brain OS | **12** numbered subsystems (`00_Foundation` → `11_Directives`), ~137 Swift files (v1.0.5/23 added `11_Directives` — the learn/save/recall/execute layer) |
| Active branch | `release/v1.0.4-memory-v4` (HEAD `d816d78` — v1.0.6 monetization hard-wall + trial-journey anchor, pushed; was `2df0a9a` at the 2026-05-17 update) |
| Product version / build | **1.0.6 / 22** (v1.0.5 / 21 was submitted to review then withdrawn by the author pre-approval) |
| Subscription tiers | Free (`.none`) · Max ($9.99) · Intelligence Pro ($19.99) · Trial ≡ Pro. **v1.0.6:** trial is Apple's card-required 7-day StoreKit introductory offer (the auto no-card custom trial is no longer minted); legacy active custom trials are grandfathered |
| Cloud surface | Gemini 2.5-flash (free) / 3-flash-preview (Pro) — chat + kitchen vision + **plan-body vision (v1.0.5)** + extraction + verification; MiniMax (TTS); Supabase (proxy + auth + leaderboard) |
| App Store status | **v1.0.2 (build 19) live publicly; v1.0.3/1.0.4 were release-line engineering cuts, not public releases; v1.0.5 build 21 was submitted then withdrawn pre-approval; v1.0.6 build 22 (HEAD `d816d78`) is the clean resubmission — Debug simulator build green, pending App Store Connect intro-offer setup before archive** |
| Per-purpose consent surfaces | `AIDataConsentManager` (cloud AI) · `CaptainVoiceConsent` (MiniMax TTS) · **`BodyPhotoConsent` (Plan vision, new in v1.0.5)** |
| Live region | UAE launch (American University of the Emirates partnership), Saudi + Iraq + Gulf-other support shipping |

**Three load-bearing facts before you read further:**

1. **Privacy is enforced at the boundary, not by convention.** Every cloud call should pass through `PrivacySanitizer` (PII redaction + numeric bucketing + 4-message conversation cap) and be recorded in `AuditLogger`. The pipeline works for the canonical Captain chat path through `HybridBrain`, but **three feature-level callers bypass it** (see §4.1.1) — the hygiene pass elevates this from "tech debt" to a **P0 fix-before-the-next-release**.
2. **Tier-gating and DevOverride are the two switches that matter.** `TierGate.shared` is the single gate for paid features; `DevOverride.unlockAllFeatures` (DEBUG-only, Info.plist `AIQO_DEV_UNLOCK_ALL`) bypasses every gate so Mohammed can dogfood without paying his own paywall. Of the 46 `canAccess` call sites, 43 are wrapped with the DevOverride bypass pattern.
3. **The Brain has twelve subsystems but they form one pipeline.** A user message flows Sensing → Memory → Reasoning → Inference (cloud or on-device LLM) → Persona → Privacy → Wellbeing → reply. Proactive notifications run a parallel pipeline driven by Triggers and gated by GlobalBudget. **`11_Directives` (v1.0.5/23)** adds a third path: a taught standing instruction is persisted, surfaced into every prompt's Working Memory, and fired automatically by its trigger (today: workout completion → analyze-and-compare notification). See Blueprint 17 §3 for the full diagram and §4 for the data-flow trace.

---

## 2A. Release timeline since the hygiene pass (v1.0.2 → v1.0.5 build 23)

This section was added in the 2026-05-12 refresh. It documents what shipped between the original Blueprint 18 cut (2026-05-10, HEAD `39ca529`) and the v1.0.5 staging on `release/v1.0.4-memory-v4` (HEAD `ab6885e`). Each entry is anchored to a real commit on a release branch so future blueprints have a clean handoff.

### v1.0.2 — brain-refactor merge (PR #5 + #6, April 20 / May 9)

The §32–§36 brain-refactor work in Blueprint 17 was merged in two slices:

- **PR #5** (`c229db0`, 2026-04-20) — the bulk of the §32–§35 work: app-knowledge v2 (sliced + struct-generated), dynamic welcome, comparative workout analysis, the §35 14-layer cognitive brain refactor, captain-chat keyboard fixes, blueprint docs, HRMoodReading nonisolated fix.
- **PR #6** (`2450f16`, 2026-05-09) — `claude/magical-lumiere` onboarding/settings/profile UX pass + level system fix.

The **Plan world-class upgrade** from §32 (commit `1128a9e`, 2026-05-11) was made on `brain-refactor/p-fix-dev-override` *after* PR #6 merged, so it never reached `main` or any release branch until **v1.0.5** picked it up explicitly. See §2A.v1.0.5 below.

### v1.0.3 — privacy hardening + critical telemetry (`a7fc579`, 2026-05-12)

Shipped via PR #8. Tightened the cloud-call boundary (PrivacySanitizer + AuditLogger coverage of the three feature-level callers that bypassed it in v1.0.2 — the **§4.1.1 P0 from the original Blueprint 18 is now resolved for those callers**). Added critical-event telemetry so paywall + crisis + cloud-error paths are observable.

### v1.0.4 — Memory V4 globally enabled + NotificationBrain wired (`8374785`, 2026-05-12)

The §5.2 P0 in the original Blueprint 18 — `MEMORY_V4_ENABLED` had been kept `false` pending V3→V4 migration validation — was **flipped to `true` globally** after the side-by-side validator confirmed parity on the corpus of test conversations. The legacy V3 store (`MemoryStore.swift`, 1312 lines) is now the read-fallback path only; V4's five-store SwiftData architecture is what actually runs in production. `NotificationBrain` was fully wired to the proactive-trigger pipeline, and a cleanup sprint removed the §5.5 stub-file index churn.

### v1.0.5 — Plan multi-day + body-photo personalization (`1be4954`, 2026-05-12 + follow-up `ab6885e`)

Three threads landed in the same release:

**Thread 1: Plan world-class surface restored to release line.** The Plan upgrade (`1128a9e`) had been orphaned on `brain-refactor/p-fix-dev-override` after PR #6 closed. v1.0.5 brings the 10 files in `AiQo/Features/Gym/Club/Plan/` into the release branch verbatim:

- `PlanPalette.swift` — the unified mint · sand · lavender · lemon brand surface
- `PlanView.swift` / `WorkoutPlanFlowViews.swift` — top-level entry + dashboard + chat
- `WorkoutPlanCards.swift` — `ActivePlanCard` + `PendingPlanPreviewCard`
- `PlanWorkoutRunner.swift` — full-screen distraction-free runner with auto rest timer
- `WorkoutPlanInsights.swift` — exercise classifier + plan-level insights
- `PlanWeeklyStats.swift` — weekly stats hero
- `ExerciseDetailSheet.swift` — per-exercise form + alternatives
- `WorkoutPlanIntakeChips.swift` — pick-fast intake (Goal · Level · Per-session time · Plan length · Equipment · optional Body photo)
- `WorkoutTemplateLibrary.swift` — quick-start templates

Visual hierarchy now comes from typography + spacing + material layering. No saturated cyan / blue / coral; everything sits on the four brand pastels and the neutral hairlines.

**Thread 2: Multi-day plans.** `WorkoutPlan` gained two optional fields, backward-compatible:

- `days: [WorkoutDay]?` — list of training days in one week. Each `WorkoutDay` carries `name`, optional `focus`, and `exercises`.
- `durationWeeks: Int?` — overall plan length (1 / 2 / 4 / 8 weeks).

The decoder is tolerant: if `days` is present and non-empty, `exercises` becomes the flattened concatenation; if only flat `exercises` is present, the plan still parses (legacy path). The Gemini prompt schema in [PromptComposer.swift](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift) describes the new shape and instructs the model to default `durationWeeks = 1` when the user does not specify.

The active plan card surfaces a horizontal day-picker; selecting a day re-scopes the exercise list, the time / moves / sets metrics, and the "Start workout" CTA. Tapping start passes a narrowed `WorkoutPlan` (only that day's exercises) to `PlanWorkoutRunner` so the runner walks one day, not the whole week.

**Thread 3: Optional body-photo personalization.** A new optional photo attachment in the intake chips lets the user share a body photo. With explicit per-purpose consent (Apple 5.1.2(II)), the image is downsized and EXIF/GPS-stripped via `PrivacySanitizer.sanitizeKitchenImageData` (renamed in spirit — same pipeline, used for both kitchen and plan-body now), then attached to the last user message as `inlineData` in the Gemini request body. The plumbing reuses the existing `attachedImageData` field on `HybridBrainRequest`; the sanitizer + `HybridBrain` were extended to accept the `.gym` screen context in addition to `.kitchen`.

The consent surface is dedicated:

- `BodyPhotoConsent` ([AiQo/Features/Gym/Club/Plan/BodyPhotoConsent.swift](AiQo/Features/Gym/Club/Plan/BodyPhotoConsent.swift)) — versioned `UserDefaults` keys, mirrors `CaptainVoiceConsent`.
- `BodyPhotoConsentSheet` ([AiQo/Features/Gym/Club/Plan/BodyPhotoConsentSheet.swift](AiQo/Features/Gym/Club/Plan/BodyPhotoConsentSheet.swift)) — bilingual RTL-first, gesture-locked, four explainer rows (What's sent · What's NOT sent · Not stored locally · Revoke anytime), Privacy Policy link.
- `BodyPhotoSettingsScreen` ([AiQo/Core/BodyPhotoSettingsScreen.swift](AiQo/Core/BodyPhotoSettingsScreen.swift)) — grant/revoke + last-changed timestamp, reachable from Settings → Privacy & AI Data → "Body photo (Plan)".

The photo lives in `@State` only — never written to disk, never on AiQo servers. `PrivacyInfo.xcprivacy` already declares `NSPrivacyCollectedDataTypePhotosorVideos` with `AppFunctionality` purpose, so no new privacy labels were needed.

The Gemini prompt for the gym-context-with-image path was tuned twice. The first cut said "Never describe the user's appearance in the message field" — too restrictive, the user wanted Captain to actually call out what muscles need work. The follow-up (`ab6885e`) requires Captain to give a short 2–3-sentence constructive read of strengths + 1–2 underdeveloped muscle groups + the training implication in the `message`, *and* to bias the `days[]` accessory work toward those groups. Hard guardrails kept: no weight / body-fat / BMI estimates, no shaming language, no commentary outside musculature. The same follow-up tightened the gym-screen behavior so the model MUST produce a full `workoutPlan` object on the first mention of a plan / weeks / training days / equipment — a "where's the plan?" follow-up from the user is now explicitly flagged in the prompt as a failure case.

**Plan dashboard reorder (cosmetic):** the active plan card jumps right under the hero (primary content first), and the `HealthComplianceCard` footer drops to the bottom. Vertical rhythm is now `spacing: 18` with `bottom: 24` to respect the tab bar.

### v1.0.5 post-refresh hardening (2026-05-17 — HEAD `2df0a9a`)

The 2026-05-12 refresh above was cut at `ab6885e`. Eleven more commits landed on `release/v1.0.4-memory-v4` before the App Store archive, in four threads. Each is anchored to a real commit; a clean Release build at the tip (`2df0a9a`) is green with **0 errors / 0 warnings**.

**Thread 4 — Plan intake, world-class redesign.** The chip-driven intake (Goal · Level · Per-session time · Plan length · Equipment · optional Body photo) was rebuilt:

- `b1c0dd5` — world-class redesign of the Captain plan intake.
- `10590ec` — intake no longer overflows under the nav / status bar (safe-area fix).
- `d6a6333` — photo card surfaces first; the chat input is hidden during intake so the flow can't be derailed mid-collection.
- `ed02f80` — legacy sample content deleted from the Plan tab (no placeholder plans ship in the binary).

**Thread 5 — Captain always produces a plan when asked.** `b459b48` is a follow-up on `ab6885e`: the prompt + post-parse path now *guarantee* a `workoutPlan` object whenever the user asked for one (gym screen, a "weeks / days / equipment" mention, or an explicit "where's my plan?" follow-up). A plan-less reply to a plan request is treated as a hard failure, not a soft miss.

**Thread 6 — Notification system v1.0.5 redesign (the big one).** The proactive stack (`06_Proactive` + `00_Foundation/TierGate`) was redesigned from a pure anti-spam funnel into a tier-aware engagement engine (`f0084f2`). Four product decisions, all implemented:

1. **Free / post-trial (`.none`) users now get BASIC LIFE notifications** — water, streak, sleep, workout, weekly reminder — via the new `TierGate.Feature.basicLifeNotifications` (required tier `.none`). "Smart Captain" background intelligence (coach nudge, AI-inactivity) stays gated to `.captainNotifications` (`.max`+). `SmartNotificationScheduler` now schedules the recurring basic-life set for every tier; only the background-task nudges remain tier-gated.
2. **The 7-day trial runs in a dedicated lane.** Intents with `kind == .trialDay` bypass the `NotificationBrain` hard cap *and* the `GlobalBudget` daily-cap + cooldown. `TrialJourneyOrchestrator` is the sole cadence governor for trial (its own per-day caps 1/2/3 + 90-min cooldown). The lane still respects quiet hours, the iOS 64-pending limit, `PersonaGuard`, and privacy scrubbing.
3. **The hard cap is tier-scaled, not flat.** `.none` 3/day · 4h (floor); `.max` 5/day · 3h; `.pro` 6/day · 2h. Trial bypasses entirely. `NotificationBrain.hardCapLimits()` switches on `TierGate.shared.currentTier.effectiveAccessTier`.
4. **Quiet hours unified to 23:00–07:00.** `QuietHoursManager.startHour` moved 22→23 so a brain-routed and a directly-scheduled notification agree on the same window (the 22:30 sleep reminder is no longer deferred to morning).

Supporting changes in the same commit: `CaptainIdentity.emojiAllowedKinds` extended to the trial-journey + streak + hydration + workout-summary + weekly-insight surfaces (celebration copy stays warm; `inactivityNudge` / `sleepDebtAcknowledgment` stay deliberately plain). `TrialJourneyOrchestrator` gained a **Day 5 feature reveal** (Zone-2 coaching for sport-minded users, Smart Wake otherwise) and a **Day 7 final-day** morning beat distinct from the evening weekly-recap; it also force-requests notification authorization on trial start as a belt-and-suspenders guard if the onboarding-gated request was skipped. The redesign is documented end-to-end in [AiQo_Notifications_System.md](AiQo_Notifications_System.md); the read-only diagnostic that drove it is [diagnostic.md](diagnostic.md).

**Thread 7 — UI polish + asset refresh + plan persistence.**

- `00f120f` — kitchen scene fridge/captain hotspots repositioned to match the refreshed art; the nutrition summary collapsed into a single macro-chip row (per-meal breakdown dropped); the profile hero identity block aligned `.leading` (correct under the force-RTL `MainTabScreen` container — `.leading` auto-maps to the right edge in RTL, removing a prior `isRTL ? .trailing : .leading` double-flip); chat bubbles matched to the home stat-card mint / sand palette.
- `774d828` — new `Captain_Hamoudi_DJ` + `imageKitchenHamoudi` 3x artwork (Contents.json updated to match); three unreferenced junk imagesets removed (`Hammoudi5o`, `Hammoudi5٧٨`, `ا`) — verified no Swift references; the live `Hammoudi5` asset is untouched.
- Pinned-plan persistence was fixed three times as the root cause was chased: `9de7476` (date-ID formatter mismatch), `bc102f8` (`QuestSwiftDataStore` actually persisting), `2df0a9a` (the pinned plan restored into the Plan tab on relaunch). The pinned plan now survives a cold relaunch.

**Build & review verification (2026-05-17).** A clean **Release** build on the iOS 26.4.1 simulator (`CODE_SIGNING_ALLOWED=NO`) succeeds with **zero errors and zero warnings** at HEAD `2df0a9a`. Every new notification symbol was cross-checked against the codebase (`.trialDay`, `effectiveAccessTier`, the new `TrialNotificationKind` cases, `NotificationService.ensureAuthorizationIfNeeded()`, `SmartNotificationScheduler.adjustedAutomationDate(for:)`). No new entitlements, privacy labels, or external endpoints were introduced; `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` and the existing privacy usage strings still cover the binary. **v1.0.5 / build 21** is the App Store archive candidate (build number deliberately kept at 21 — never previously uploaded).

### v1.0.6 — hard-wall Apple trial + clean resubmission (2026-05-17 — HEAD `d816d78`)

v1.0.5 (build 21) was **submitted to App Store review and then withdrawn by the author** after pre-approval issues were found. Rather than ship a known-flawed binary, the release was re-cut clean as **v1.0.6 (build 22)**. Two product threads landed on top of `2df0a9a`; everything is in one commit, `d816d78`, pushed to `origin/release/v1.0.4-memory-v4`. A clean **Debug** simulator build (`AiQo` scheme, `CODE_SIGNING_ALLOWED=NO`) is green (`** BUILD SUCCEEDED **`) at the tip — this confirms the SourceKit "cannot find in scope" diagnostics seen mid-edit in a headless environment are false positives (unresolved SPM index), not real errors.

**Thread 8 — Monetization: hard-wall Apple trial + grandfathering.** The trial economics were rebuilt for paid user-acquisition. *Before:* onboarding auto-started a 7-day **no-card custom trial** (`FreeTrialManager`, Keychain/UserDefaults) and the paywall carried a "تخطي" (Skip) chip, so the dominant path was a card-free trial with a day-8 wall — the lowest-converting model and a money-loser under paid ads. *After:*

- [SceneDelegate.swift](AiQo/App/SceneDelegate.swift) `finalizeLegacyStep()` no longer calls `FreeTrialManager.startTrialIfNeeded()` — **no new no-card trials are minted**.
- [SubscriptionIntroView.swift](AiQo/Features/Onboarding/SubscriptionIntroView.swift) wraps the Skip chip in `if FreeTrialManager.shared.isTrialActive` — it shows **only** for grandfathered users with an active legacy custom trial. For everyone else the onboarding paywall is a **hard gate**: the only way past it is a successful `product.purchase()` (Apple's real card-required 7-day StoreKit introductory offer, already in `AiQo.storekit` on both products).
- Grandfathering is automatic and required **no** access-layer change: `TierGate.currentTier` already returns `.trial` while `FreeTrialManager.isTrialActiveSnapshot` is true, so existing active trials ride out; new users (no custom trial, no Apple sub) resolve to `.none` → `CaptainLockedView` → `PaywallView(source: .captainGate)`, which already existed in `MainTabScreen`. `TierGate` / `AccessManager` were not touched.
- Author decisions recorded in-session: a **pure hard wall** (app does nothing before the trial starts) over the softer "app opens, premium locked" option, and **grandfather** existing trial users. Trade-off acknowledged: the pure wall is the higher App Store **3.1.1** rejection risk; the mitigation is that the trial is reachable by reviewers via the StoreKit sandbox, with `Restore Purchases` and the auto-renew disclosure present on `PaywallView`. If Apple rejects under 3.1.1, the fastest remedy is softening to "app opens, Captain/Gym/Kitchen/Peaks locked" (the declined option). Do **not** re-introduce an auto no-card trial.

**Thread 9 — Trial-journey notifications re-anchored to the Apple subscription.** Killing the auto custom trial broke the anchor for the 7-day relationship arc (`TrialJourneyOrchestrator` reads `FreeTrialManager.currentTrialDay` / `isInsideTrialWindow`), so new Apple-trial users would have received **no** Day1→Day7 notifications. Fixed without touching the sensitive orchestrator:

- New [FreeTrialManager.swift](AiQo/Premium/FreeTrialManager.swift) `captureStoreKitTrialStart(_:)` — idempotent and self-healing (keeps the **earliest** known start, anchored to the real `Transaction.originalPurchaseDate`), and explicitly **not** a no-card trial: only ever called from a verified StoreKit transaction, so the onboarding hard wall stays intact.
- [PurchaseManager.swift](AiQo/Core/Purchases/PurchaseManager.swift) calls it at both chokepoints: the `purchase()` success path (plus an immediate `TrialJourneyOrchestrator.refresh()` so Day-1 schedules in-session, since the user just left the hard wall and won't relaunch), and `updateEntitlementsFromLatestTransactions()` (the safety net covering restore / new-device / background-renewal / launch). Every subscribe entry point is covered: onboarding, the Captain gate, the profile sheet, restore, launch.
- `TrialJourneyOrchestrator.swift` itself was deliberately **not edited** — only its existing public `refresh()` is invoked — so the v1.0.5 notification redesign (Thread 6) is preserved intact.

**Thread 10 — Dynamic Captain welcome restored, then made time- & heart-rate-aware.** The Captain chat had been opening with the same static line (`NSLocalizedString("captain.welcome", …)` — *"هلا! أنا كابتن حمّودي. شنو هدفك اليوم؟"*) on every entry. Root cause was **not** a deletion: the `DynamicWelcomeComposer` authored on `brain-refactor/p-fix-dev-override` (`32f3ae4`, carried untouched through the §35 refactor `d955c04`) was orphaned exactly like the Plan upgrade — `release/v1.0.4-memory-v4` forked at merge-base `b08fd6a`, *before* it, so the dynamic opener never reached the release line. This is the same unmerged-branch pattern as §2A.v1.0.2 / the Plan thread, not a regression; the general triage rule ("missing Captain feature on a release branch → check `brain-refactor/p-fix-dev-override` is merged before hunting a deleting commit") is the standing guidance. Restoration brought two files onto the release branch verbatim from `d955c04`: [DynamicWelcomeComposer.swift](AiQo/Features/Captain/Brain/04_Inference/DynamicWelcomeComposer.swift) and its one missing dependency [CaptainMetricsCounter.swift](AiQo/Features/Captain/Brain/10_Observability/CaptainMetricsCounter.swift) — a standalone `UserDefaults`-backed `(event · reason · latency_ms)` counter whose privacy contract is counts-only, never content / PII / prompt text. No `.pbxproj` edit was needed: `Brain/` is a `PBXFileSystemSynchronizedRootGroup`, so a file compiles in by folder membership. Every dependency (`BrainOrchestrator.processMessage`, `HybridBrainRequest`, `CaptainContextBuilder.shared`, `BioStateEngine`, `HydrationService`, `TierGate`, `AIDataConsentManager`, `DevOverride`) was verified present on the release branch *before* the file was reintroduced — the §35 refactor changed brain internals but left these public entry points stable.

[CaptainViewModel.swift](AiQo/Features/Captain/CaptainViewModel.swift) `startNewChat()` was rewired: cancel any in-flight `responseTask`, fire the `.captainChatOpened` analytics (preserved from the static path), show the typing state, then compose the opener asynchronously through the **same** `BrainOrchestrator` instance the view-model already holds. A new `applyWelcomeMessage(_:for:)` drops the bubble in once generation settles, guarded by a session-ID equality check so a chat-history tap mid-flight cannot race a stale welcome into a fresh session, and falls back to the original static string on any failure (offline · no AI consent · tier-blocked · 7 s timeout · empty reply). The static line is now a graceful-degradation floor, not the default; the chat is never blank.

The opener was then upgraded per author request to be **genuinely time-aware and richer**. The prompt now injects the exact local wall-clock (POSIX `HH:mm` from `bio.timestamp`, locale-stable, reasoning-only — never spoken) next to the period label, with distinct tone guidance for all seven `BioSnapshot.TimeOfDay` slots (فجر calm · صباح light energy · ظهر quick · عصر lift · مساء warm wind-down · ليل soothing · منتصف الليل very low, gently ask why they're up, never hyped), and is told to sometimes name the time explicitly and sometimes only colour the tone — varied every open. **Heart rate** (`bio.heartRateBucketed`) joins steps / calories / water as a selectable live metric **only when a HealthKit sample exists**: `formatHeartRate` returns `nil` when absent so the model is never invited to fabricate a number, and it is steered toward the calm periods. The persona was dialed toward Iraqi wit ("ممتعة مو معلّبة" / "enjoyable, never canned"). The spoken-output contract is unchanged — still 1–2 voice-first sentences, exactly one metric, standard JSON envelope, no emoji, no medical disclaimers. Committed in `d816d78`; clean Debug simulator build green at the tip.

**Follow-up root-cause fix (post-`d816d78`).** As shipped in `d816d78` the dynamic opener still never ran in practice. `DynamicWelcomeComposer.timeoutSeconds` was `7 s`, but the welcome is the session's *first and coldest* cloud call (DNS + TLS + model cold-start + the full 7-layer prompt) — the very latency the normal chat path already budgets `30 s` for (`CaptainViewModel.globalProcessingTimeout`). The 7 s window expired before the cold call returned on essentially every open, so `compose()` returned `nil` and the static fallback shipped every single time: the feature was inert in the binary even though the wiring was correct. The budget was raised to `30 s`, in lockstep with the chat path, and the constant carries a comment forbidding a lower value — shrinking it for a "snappier open" silently re-disables the dynamic greeting and is the exact regression that hid the feature here. Clean Debug simulator build green after the fix.

**Version + bundled work.** `MARKETING_VERSION` 1.0.5 → 1.0.6 and `CURRENT_PROJECT_VERSION` 21 → 22 across every build config in `project.pbxproj` (Apple requires a build number higher than the withdrawn 1.0.5/21). A stale duplicate kitchen imageset — a malformed non-ASCII folder name duplicating ~4.6 MB — was removed and the kitchen art refreshed (old PNG deleted, new PNG in the correctly-named imageset). Commit `d816d78` also bundles in-progress work from parallel sessions. The `DynamicWelcomeComposer` / `CaptainMetricsCounter` / `CaptainViewModel` welcome work is now fully documented in **Thread 10** above. The remainder — `NotificationBrain`, `StreakManager`, `EntitlementStore`, `MainTabScreen`, purchase tests, blueprint — is **not individually documented here** (authored outside this thread); it compiles clean in the same green build and should be back-filled into a future blueprint by whoever authored it.

**Still pending — App Store Connect only (no code left).** Create an **Introductory Offer = Free / 1 week** on both subscriptions (`com.mraad5000.aiqo.max`, `com.mraad500.aiqo.Intelligence.pro`); IAPs "Ready to Submit" attached to build 22; Paid Apps Agreement active; an App Review note that the free trial is reachable via the StoreKit sandbox. **Without the intro offer the hard wall has no free entry and review rejection is near-certain.**

---

### v1.0.5 build 23 — Captain Directives layer + memory expansion (2026-05-17 — HEAD pending)

The Captain had a rich **fact** memory (`SemanticFact`) and **silent-habit** observation (`ProceduralPattern`), but **no way for the user to teach it a durable, executable standing instruction** — e.g. *"بعد كل تمرين حلّل تمريني وقارنه بالي قبله ودزّلي إشعار"* ("after every workout, analyze it and compare it to the previous one and notify me"). The Gemini prompt's `memoryUpdate` schema field was never even parsed in Swift; the post-workout notification was a static one-liner. This release adds the missing capability as a **twelfth Brain subsystem, `11_Directives`** — the learn → save → recall → execute loop — plus the memory enlargement the same request asked for. One bundled commit; clean **Release** simulator build green (`** BUILD SUCCEEDED **`, 0 errors / 0 warnings, Swift-6 concurrency clean) at the tip.

**Thread 11 — the `11_Directives` subsystem (six new files).** [DirectiveTaxonomy.swift](AiQo/Features/Captain/Brain/11_Directives/DirectiveTaxonomy.swift) defines extensible `DirectiveTrigger` (`afterWorkout` fully wired; `beforeBedtime` / `everyMorning` / `afterPoorSleep` / `weeklyReview` recognized-but-scaffold so the taxonomy grows without a schema change) and `DirectiveAction` (`analyzeAndCompareWorkout`, `notify`), plus `nonisolated` Sendable draft/snapshot value types. [LearnedDirective.swift](AiQo/Features/Captain/Brain/02_Memory/Models/LearnedDirective.swift) is the `@Model` (raw-string-encoded enums + JSON params blob, mirroring `ProceduralPattern`'s shape). [DirectiveStore.swift](AiQo/Features/Captain/Brain/11_Directives/DirectiveStore.swift) is an `actor` cloned from `ProceduralStore`'s conventions exactly (per-call `ModelContext`, `#Predicate` fetches, graceful no-op before `configure(container:)`, capacity eviction). [DirectiveLearner.swift](AiQo/Features/Captain/Brain/11_Directives/DirectiveLearner.swift) is an on-device Arabic/English parser (no LLM, no network — like `IntentClassifier`); it is deliberately conservative — it requires a recurrence marker **and** an action verb **and** a recognized trigger domain, so a one-off "حلّل تمريني" never creates a standing rule. [DirectiveEngine.swift](AiQo/Features/Captain/Brain/11_Directives/DirectiveEngine.swift) executes on workout completion and contains `WorkoutComparisonComposer`, a pure deterministic Iraqi/English composer that diffs duration / calories / avg-HR / distance against the previous recorded workout. [DirectiveCoordinator.swift](AiQo/Features/Captain/Brain/11_Directives/DirectiveCoordinator.swift) bridges chat ↔ persistence ↔ recall in one call.

**Thread 12 — wiring into the existing layers (no new parallel channels).** Persistence: a new **`MemorySchemaV5`** ([MemorySchemaV5.swift](AiQo/Features/Captain/Brain/02_Memory/Models/MemorySchemaV5.swift)) = V4 models + `LearnedDirective`, with a **lightweight `migrateV4toV5`** stage appended to [CaptainSchemaMigrationPlan.swift](AiQo/Features/Captain/Brain/02_Memory/Models/CaptainSchemaMigrationPlan.swift) — the same proven additive pattern as V1→V2 / V2→V3 — and `makeCaptainContainerV4()` retargeted to V5 (the existing V5→V3 failure fallback is untouched, so the degraded path is unchanged). Recall: rather than bolt on a parallel prompt channel, `DirectiveCoordinator` mirrors each active directive into `MemoryStore` under a new `directive` category, and [CognitivePipeline.swift](AiQo/Features/Captain/Brain/03_Reasoning/CognitivePipeline.swift) `buildWorkingMemorySummary` emits an **always-on `[active_standing_directives]` block** — the exact mechanism the brain already uses for `[active_record_project]`, so the Captain confirms the order in the *same* reply and a relaunch re-hydrates it (`DirectiveCoordinator.hydratePromptMirror()` from [AppDelegate.swift](AiQo/App/AppDelegate.swift)). Execution: the chokepoint is `AIWorkoutSummaryService.handleWorkoutEnded` in [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) — it already fires after **every** HealthKit workout (Watch / external / in-app) and already sent a static line; it now asks `DirectiveEngine` first and sends the analyze-vs-previous body when a directive is active, falling back to the static line otherwise. Gating: new `TierGate.captainDirectives` (required tier `.max`, consistent with `captainMemory` / `captainNotifications`) honoring `DevOverride`. Inter-layer signalling: `BrainBus.Event` gained `directiveLearned` / `directiveFired` / `workoutCompleted` (the critical path stays a direct `await`, the bus is the decoupled observability channel).

**Thread 13 — memory enlargement (the second half of the request).** [TierGate.swift](AiQo/Features/Captain/Brain/00_Foundation/TierGate.swift): `maxSemanticFacts` Pro 500→**1200** / Max 200→**500**; `maxMemoryRetrievalDepth` 25→**40** / 10→**18**. [MemoryStore.swift](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift): `buildPromptContext` default budget 800→**1200** tokens and 30→**48** entries; `retrieveRelevantMemories` default 8→**12**; `maxPersistedMessages` 200→**400**. [WorkoutHistoryStore.swift](AiQo/Features/Captain/Brain/02_Memory/Stores/WorkoutHistoryStore.swift): rolling window 7→**30** (only the most recent 14 are folded into the single `workout_history` prompt memory, so a deeper store doesn't bloat the prompt). The prompt-token guard is preserved end-to-end, so the larger store doesn't blow latency/cost.

**Design decisions recorded in-session.** (1) Directive parsing is **on-device, deterministic** (not an LLM structured-output field) — it adds zero latency to chat, never touches the strict JSON contract / `LLMJSONParser`, and can't be gamed by a model hallucination. (2) The post-workout analysis body is **deterministic and offline by design** — a "do this after *every* workout" promise must run instantly, for free, in the background with no network; the model-written deeper analysis still happens when the user opens the app and asks. (3) Directives surface through the **existing Working Memory mechanism** (`[active_standing_directives]` alongside `[active_record_project]`) rather than a new plumbed `HybridBrainRequest` field — architectural consistency over a parallel channel, and zero risk to the ~6 request copy-sites. (4) Honest scope limit: compilation + integration are verified; **the real-device workout→notification cycle was not executed here** and should be validated on a device before relying on it in review.

**Version + submission.** `MARKETING_VERSION` 1.0.6 → **1.0.5** and `CURRENT_PROJECT_VERSION` 22 → **23** across every build config in `project.pbxproj` — the author's decision to resubmit under the 1.0.5 marketing string (the 1.0.5/21 that was withdrawn was never approved) with an incremented build number (23 > 22 > 21 satisfies Apple's strictly-increasing build requirement). This commit also carries pre-existing in-progress work staged before this thread ([MainTabScreen.swift](AiQo/App/MainTabScreen.swift), [CaptainScreen.swift](AiQo/Features/Captain/CaptainScreen.swift)) — authored outside this thread, compiles clean in the same green build, back-fill into a future blueprint by whoever authored it. The App Store Connect intro-offer prerequisite from the v1.0.6 entry above **still applies** to this submission.

---

## 2. The 2026-05-10 Hygiene Pass

This blueprint is itself the deliverable of a project-wide cleanup pass run on 2026-05-10. The pass touched **only files that were not part of the active in-flight branch work** — every modified Swift file in the brain-refactor branch (PromptComposer + Plan/* + the new PlanPalette) was preserved untouched. The cleanup sits *around* that work, not on top of it.

### 2.1 What was deleted

| Item | Size / count | Rationale |
|---|---|---|
| `build/` directory | **1.5 GB** | Xcode-generated, gitignored, regenerated on next build |
| `.DS_Store` files | 19 files | macOS Finder metadata, gitignored, never useful |
| `AiQo_Master_Blueprint_2 2.md` | 128 KB | Finder " 2"-suffix duplicate of an older blueprint that no longer exists at the original path; superseded by Blueprints 16/17 |
| `notes.txt` | 1 KB | Stale P_MERGE_LOST_WORK working notes from 2026-04-18 — the merge has long since landed |
| `untitled folder/` | 13 markdown files | Working-notes stash from the P0/P1/P2 brain-refactor phases (April 18) — content moved to `docs/archive/p-fix/`, then the unnamed folder was removed |

**Total disk reclaimed:** ~1.5 GB.

### 2.2 What was reorganized into `docs/`

The project root previously held **30+ historical markdown files** mixed in with current code-adjacent docs. These are now organized into a discoverable tree:

```
docs/
├── archive/
│   ├── app-store/         ← AppStore_Resubmission_Audit, AppStore_Reviewer_Reply,
│   │                        APP_STORE_CHECKLIST_v1.0.1
│   ├── batch-results/     ← BATCH_1..8_RESULT_*.md (Brain refactor batch logs)
│   ├── blueprints/        ← AiQo_Master_Blueprint_Complete, _16, _MyVibe, _MyVibe_2
│   ├── captain-brain/     ← CAPTAIN_BRAIN_RECON, CAPTAIN_CHAT_V1_1_CHANGELOG,
│   │                        Captain_Hamoudi_Diagnostic_Report, Captain_Hamoudi_Fix_Report
│   ├── handoffs/          ← HOME_SCREEN_CODEX_HANDOFF
│   └── p-fix/             ← BRAIN_OS_AUDIT, P0.1_PRIVACY_SURGERY_MAP, P0.2..P2.3_RESULT,
│                            P_FIX_1.3_RESULT, P_FIX_DEV_OVERRIDE_RESULT,
│                            P_MERGE_LOST_WORK_RESULT
├── explainers/
│   ├── ar/                ← AiQo_شرح_شامل_01..05 (Arabic product context, 2026-05-09)
│   └── en/                ← AiQo_AIContext_00..07 (English product context, 2026-04-10)
└── security/              ← (reserved for security audits — see §4)
```

Nothing was deleted from these moves — every historical document is still on disk, just discoverable now. Git treats this as a rename when content is unchanged, so blame history is preserved.

### 2.3 What stayed at root

The root is now a clean professional landing surface:

```
/
├── AiQo/                      # Main iOS app target (590 Swift files)
├── AiQoTests/                 # Test target (~63 files)
├── AiQoWatch Watch App/       # watchOS app
├── AiQoWatch Watch AppTests/
├── AiQoWatch Watch AppUITests/
├── AiQoWatchWidget/           # watchOS widget
├── AiQoWidget/                # iOS widget
├── AiQo.xcodeproj/            # Xcode project
├── Configuration/             # xcconfig files (incl. gitignored Secrets.xcconfig) + SETUP.md
├── supabase/                  # Edge Functions (captain-chat, captain-voice, etc.)
├── aiqo-web/                  # Sub-repo (gitignored, separate git history)
├── docs/                      # NEW: organized documentation tree
│   ├── archive/               # historical working notes
│   ├── explainers/            # product-context explainer series
│   └── security/              # (reserved)
│
├── AiQo_Master_Blueprint_17.md  # canonical historical reference
├── AiQo_Master_Blueprint_18.md  # this file (current/forward)
├── AIQO_TECH_DEBT.md            # living tech-debt log
├── CHANGELOG.md                 # release-notes changelog
├── LICENSE.txt
├── AiQo.png                     # app icon
├── AiQoWatch-Watch-App-Info.plist
├── AiQoWatchWidgetExtension.entitlements
├── AiQoWidgetExtension.entitlements
├── .gitignore
├── .github/
└── .claude/                   # local Claude Code workspace data (gitignored worktrees)
```

The root is no longer 65 entries deep with three competing blueprint families and two sets of explainer docs. It is now ~22 visible items, every one of which is either *active source*, *active config*, *current top-level documentation*, or a clearly-organized subdirectory.

### 2.4 Total impact

- **Disk freed:** ~1.5 GB
- **Root noise reduced:** 30+ stale markdown files moved out of the top level
- **Discoverability:** linear file dump → tree by purpose
- **Active in-flight work:** zero touched (all 11 modified files in the brain-refactor branch preserved exactly as they were)
- **Git history:** preserved (renames detected by git when committed)
- **Build/test impact:** none (nothing in `AiQo/`, `AiQoTests/`, `AiQoWatch*`, `AiQoWidget*`, `Configuration/`, or the Xcode project was touched)

---

## 3. Codebase Map (post-cleanup)

### 3.1 The five top-level Swift targets

| Target | Path | Files | Purpose |
|---|---|---|---|
| **iOS app** | `AiQo/` | 590 | The flagship target |
| **iOS tests** | `AiQoTests/` | ~63 | Unit + voice tests |
| **iOS widget** | `AiQoWidget/` | 12 | Lockscreen + Home Screen widgets (incl. Smart Water Tracking widget — §22) |
| **watchOS app** | `AiQoWatch Watch App/` | 25 | Mirrors a subset of the iPhone surface |
| **watchOS widget** | `AiQoWatchWidget/` | 0 | Assets-only at present |

Plus three test targets: `AiQoWatch Watch AppTests`, `AiQoWatch Watch AppUITests`, and the implicit unit-test target for the iOS app.

### 3.2 The iOS app internal layout

```
AiQo/
├── App/                   # 10 files — AppDelegate, SceneDelegate, MainTabView, routing, auth flows
├── AiQo.entitlements
├── AiQoCore/              # Empty placeholder (header + docc only) — see §5.4
├── Core/                  # 40 files — Config, Keychain, Localization, Models, Purchases, Security, Utilities
├── DesignSystem/          # 13 files — AiQoTheme, AiQoColors, AiQoTokens, Components, Modifiers
├── Features/              # 411 files — 18 feature modules
│   ├── Captain/           #   177 files — Brain (12 subsystems) + Voice
│   ├── Cardio/            #     1 file  — ZoneCoachingVoiceService (live, not a stub)
│   ├── Challenges/        #    10 files — General challenge system
│   ├── Compliance/        #     6 files — Legal, privacy, disclaimers
│   ├── DataExport/        #     1 file  — Export user data
│   ├── First screen/      #     1 file  — LegacyCalculationViewController (misnamed, see §4.4.2)
│   ├── Gym/               #   102 files — Workouts + Club + Plan + Quests
│   ├── Home/              #    22 files — Dashboard, charts, ScreenshotMode
│   ├── Kitchen/           #    34 files — Nutrition, smart fridge, meal plans, CookMode (§35)
│   ├── LegendaryChallenges/#    16 files
│   ├── MyVibe/            #     6 files — Spotify-blended music
│   ├── Onboarding/        #     8 files
│   ├── Profile/           #     6 files
│   ├── ProgressPhotos/    #     2 files
│   ├── Sleep/             #    11 files — Apple Intelligence on-device path
│   ├── SmartWaterTracking/#     7 files — §22 hydration with widget
│   ├── Tribe/             #     3 files — partial duplicate of /Tribe/ (see §4.4.1)
│   └── WeeklyReport/      #     4 files — Pro-tier digest
├── Frameworks/            # Spotify SDK binary
├── NeuralMemory.swift, AppGroupKeys.swift, PhoneConnectivityManager.swift, XPCalculator.swift, Info.plist, PrivacyInfo.xcprivacy
├── Premium/               # 5 files — FreeTrialManager, AccessManager, paywall logic
├── Resources/             # Localizations (ar.lproj, en.lproj), Assets.xcassets, achievement specs JSON
├── Services/              # 28 files — Analytics, CrashReporting, Notifications, Permissions, Trial
├── Shared/                # 7 files — HealthKit, level system, coin manager, watch sync codecs
├── Tribe/                 # 58 files — full Tribe module (Arena, Galaxy, Log, Models, Repositories, Stores, Views)
└── UI/                    # 13 files — Paywall + purchase UI
```

### 3.3 The Brain OS (`AiQo/Features/Captain/Brain/`)

Twelve numbered subsystems, ~137 files. See [Blueprint 17 §3.2](AiQo_Master_Blueprint_17.md) for the full file-by-file inventory (subsystems 00–10; `11_Directives` is documented in §2A).

| # | Subsystem | Files | Role |
|---|---|---:|---|
| 00 | Foundation | 6 | TierGate, DevOverride, BrainBus, BrainError, CaptainLockedView, DiagnosticsLogger |
| 01 | Sensing | 9 | BioStateEngine, CaptainHealthSnapshotService, BehavioralObserver, ContextSensor, HealthKitBridge, MusicBridge, WeatherBridge, CircadianReasoner (stub), SignalBus (stub) |
| 02 | Memory | 37 | 5 SwiftData stores, MemoryRetriever, EmotionalMiner, FactExtractor, EmbeddingIndex, SalienceScorer, TemporalIndex, MemorySchemaV1–V4 + migration plan, plus the legacy `MemoryStore.swift` (1312L) and `MemoryExtractor.swift` (the only outbound-HTTP file in the Brain — see §4.1.1) |
| 03 | Reasoning | 13 | EmotionalEngine, IntentClassifier, CulturalContextEngine, PersonaAdapter, ContextualPredictor, SentimentDetector, TrendAnalyzer, CaptainContextBuilder, CognitivePipeline (legacy), ScreenContext |
| 04 | Inference | 13 | BrainOrchestrator (846L conductor), HybridBrain (canonical Gemini caller), CloudBrain, FallbackBrain, LocalBrain, PromptComposer, PromptRouter, LLMJSONParser, PersonaGuard, plus stubs (RoutingPolicy, CulturalValidator, ResponseValidator) |
| 05 | Privacy | 5 | PrivacySanitizer (658L, the boundary), AuditLogger (106L ring buffer), plus stubs (ConsentGate, DataClassifier, DifferentialPrivacy) |
| 06 | Proactive | 26 | NotificationBrain (the single door), GlobalBudget, CooldownManager, QuietHoursManager, MessageComposer, TemplateLibrary, TriggerEvaluator, 15 trigger types |
| 07 | Learning | 7 | BackgroundCoordinator (BGTask 03:00), FeedbackLearner, WeeklyMemoryConsolidator, plus stubs |
| 08 | Persona | 9 | CaptainIdentity, DialectLibrary (4×9 phrase banks), HumorEngine, WisdomLibrary, CaptainPersonaBuilder, CaptainPersonalization, plus stubs |
| 09 | Wellbeing | 4 | CrisisDetector, InterventionPolicy, SafetyNet, ProfessionalReferral (region-aware) |
| 10 | Observability | 5 | BrainDashboard (DEBUG-only), CaptainMemorySettingsView, plus stubs |
| 11 | **Directives** | 6 | **(v1.0.5/23)** `LearnedDirective` (@Model, Schema V5) + `DirectiveTaxonomy` (trigger/action enums) + `DirectiveStore` (actor, mirrors `ProceduralStore`) + `DirectiveLearner` (on-device NL parser) + `DirectiveEngine` (executor + `WorkoutComparisonComposer`) + `DirectiveCoordinator` (chat↔memory bridge). The learn/save/recall/execute layer. |

> **v1.0.5 note (2026-05-17):** subsystems **00 Foundation** (`TierGate` — new `.basicLifeNotifications` feature) and **06 Proactive** (`NotificationBrain` tier-scaled hard cap + trial-lane bypass, `GlobalBudget` trial-lane bypass, `QuietHoursManager` 23:00 start) were materially reworked in the notification redesign. `TrialJourneyOrchestrator` (in `Services/Trial/`, not the Brain) is now the sole cadence governor for the trial lane. See §2A → "v1.0.5 post-refresh hardening" and [AiQo_Notifications_System.md](AiQo_Notifications_System.md).

> **v1.0.5/23 note (2026-05-17):** new subsystem **11 Directives** added (the standing-instruction learn/execute layer), and **00 Foundation** (`TierGate.captainDirectives`, `BrainBus` directive/workout events), **02 Memory** (`MemorySchemaV5` + lightweight `migrateV4toV5`; expanded `maxSemanticFacts` / `maxMemoryRetrievalDepth` / `buildPromptContext` budget / `WorkoutHistoryStore` window 7→30 / `maxPersistedMessages` 200→400), and **03 Reasoning** (`CognitivePipeline` always-on `[active_standing_directives]` block) were extended. Execution hooks into `AIWorkoutSummaryService` (in `Services/Notifications/`, not the Brain). See §2A → "v1.0.5 build 23 — Captain Directives layer + memory expansion".

### 3.4 What lives at the root of `AiQo/`

Four files float at the top of the iOS app target rather than living inside a feature module:

- `AppGroupKeys.swift` — shared App Group identifiers used by the iOS app, watch app, and widgets
- `NeuralMemory.swift` — older memory model, predates Brain V4 stores
- `PhoneConnectivityManager.swift` — WatchConnectivity bridge between iPhone and watchOS targets
- `XPCalculator.swift` — XP / leveling math used across features

These are intentionally module-free — they cross feature boundaries and don't belong in any single one.

---

## 4. Security Posture

This is the active "ثغرات" (vulnerabilities) section the user asked for. Every item below is concrete: file path, line number, what is wrong, what to do, and what priority. Findings are rooted in a fresh audit run on 2026-05-10. Nothing here is theoretical "best practice" advice — these are real issues in this codebase, ranked by blast radius.

### 4.1 CRITICAL — fix before the next release

#### 4.1.1 Three features bypass the privacy boundary on outbound LLM calls

This is the single most important finding of the hygiene pass. The Brain's privacy contract is that *every cloud call* passes through `PrivacySanitizer` (PII redaction + numeric bucketing + 4-message cap) **and** is recorded in `AuditLogger`. The canonical implementation is [HybridBrain.swift:122](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift) wrapped by [CloudBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift). Three feature-level callers do **not** route through this path:

| File | Line | What it does |
|---|---|---|
| [MemoryExtractor.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift) | 239 | Direct `URLSession.shared.data(for:)` to Gemini for memory-fact extraction. Sanitizes the input text but the request itself bypasses `AuditLogger`. |
| [WeeklyReviewView.swift](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift) | 398 | Same pattern, embedded inside a SwiftUI view (compounds the issue — UI code making cloud calls). |
| [SmartFridgeCameraViewModel.swift](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift) | 190 | Same pattern, with image bytes — the riskiest of the three because Vision payloads can leak more than text. |

Each of the three currently does a `CaptainProxyConfig.isChatEnabled` check and routes through the Supabase Edge Function when on, falling back to direct Gemini when off — so they all *do* understand the proxy architecture, but they never get the sanitization-and-audit pass that `CloudBrainService.generateReply(...)` provides.

**The fix is structural, not a patch:**

1. Extract a `CaptainCloudGateway` (working name) under `Brain/04_Inference/Services/` that becomes the single function any feature calls when it wants a Gemini round-trip. Existing `HybridBrainService` stays as the implementation of the chat path; the new gateway becomes the public API. Signatures should accept the prompt + intent + tier + screen context, return the response + an `AuditLogger.Entry`.
2. Migrate `MemoryExtractor`, `WeeklyReviewView`, `SmartFridgeCameraViewModel` to call the gateway. Each call site loses ~80–100 lines of URL construction, body assembly, and JSON parsing.
3. Delete the legacy `URLSession.shared.data(for:)` paths from the three files. Search for `URLSession.shared.data` outside `04_Inference/Services/` after the migration — should return zero hits.
4. Add a CI grep guard: `! grep -R "URLSession.shared" AiQo/ --include='*.swift' | grep -v '04_Inference/Services'` should be a build-time check.

**Effort:** 1–2 days for a focused refactor + smoke testing the three call sites. Low risk if the gateway is purely additive at first (introduce, migrate, delete legacy).

**Why this is CRITICAL:** the entire premise of "AiQo respects your privacy" rests on the audit log being a complete record of what left the device. Three features punching holes in that record turns the audit log from a contract into a marketing claim.

#### 4.1.2 API keys interpolated into URL query strings

In all three files above, when the proxy is *off*, the API key is built into the URL via `?key=\(apiKey)`. Concrete locations:

- [MemoryExtractor.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift) ~line 357
- [WeeklyReviewView.swift](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift) ~line 368
- [SmartFridgeCameraViewModel.swift](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift) ~line 182

URL query strings appear in HTTP request logs, in NSURLSession debug output, in Console.app on-device logs, and (worst-case) in proxy server logs if any TLS-terminating proxy is in the path. Even though the live build runs through the Supabase proxy where this is moot, the legacy fallback path is live code that ships in the binary.

**Fix:** during the §4.1.1 refactor, the gateway must use `Authorization: Bearer <token>` headers, never URL parameters. The Gemini direct-mode fallback (when proxy is off) is rare; it should be loud (DEBUG-only) and use the header.

#### 4.1.3 Subscription metadata in plaintext UserDefaults

[EntitlementStore.swift:36-78](AiQo/Core/Purchases/EntitlementStore.swift) writes `activeProductId`, `expiresAt`, and `currentTier` to `UserDefaults`. On a jailbroken device, an attacker can edit `expiresAt` to extend a trial indefinitely or flip `currentTier` to `.pro`. The signal is also *read* from UserDefaults at app launch before StoreKit reconciliation completes, so a tampered value is briefly authoritative.

**Fix:** migrate the three keys to `KeychainStore` (already exists at [Core/Keychain/KeychainStore.swift](AiQo/Core/Keychain/KeychainStore.swift)). Use a deterministic key like `aiqo.purchases.entitlement.v2`. Sign the JSON blob with HMAC keyed by an Info.plist constant for tamper detection — a mismatch should fall back to "free tier until StoreKit reconciles."

**Effort:** half a day. Touches one file plus the Keychain helper.

> **v1.0.6 status note (2026-05-17):** still **open**, and the hard-wall change in §2A Thread 8 shifts (does not remove) the threat. New users no longer get a `FreeTrialManager` no-card start date, so the "edit `isTrialActiveSnapshot`/trial dates to extend a free trial" vector is gone for them — access is now Apple-entitlement-driven. But `activeProductId` / `expiresAt` / `currentTier` are still plaintext `UserDefaults`, still read before StoreKit reconciles, and the new `captureStoreKitTrialStart` persists a trial-anchor date to the same stores; a jailbroken edit can still flip `currentTier` to `.pro` or back-date the anchor. The Keychain + HMAC migration remains the right fix.

#### 4.2.1 Keychain failures swallowed silently

[KeychainStore.swift:26-29, 53-54](AiQo/Core/Keychain/KeychainStore.swift) discards `OSStatus` from `SecItemCopyMatching` and `SecItemAdd`. A real-world failure (permission denied after a device unlock loop, corrupted Keychain DB after a restore-from-backup) returns `nil` and the calling code thinks "no value stored." This silently degrades into "user is logged out."

**Fix:** log non-`errSecSuccess` / non-`errSecItemNotFound` statuses through `DiagnosticsLogger.diag` so we get telemetry on real failures. Three-line change.

#### 4.2.2 No certificate pinning on the cloud surface

The app talks to three sensitive endpoints — Supabase (`zidbsrepqpbucqzxnwgk.supabase.co`), Gemini (`generativelanguage.googleapis.com`), MiniMax (`api.minimax.io`). All rely on system-level TLS validation only.

**Fix:** add `URLSessionConfiguration` with pinned leaf certificates for all three. Bundle the public-key fingerprints in the IPA. Use `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)` to compare. Provide a `PINNING_DISABLED` Info.plist flag for dev/QA convenience that is hard-rejected in RELEASE.

**Effort:** half a day of plumbing + one rotation runbook in §7.3 below.

#### 4.2.3 `fatalError` on SwiftData container init

[AppDelegate.swift:18](AiQo/App/AppDelegate.swift) and [QuestSwiftDataStore.swift:29](AiQo/Features/Gym/Quests/Store/QuestSwiftDataStore.swift) both call `fatalError(...)` when the persistent container fails to spin up. In production this manifests as a bricked app with no recovery — the user can't even launch to a setting that would clear data.

**Fix:** fall back to an in-memory container with a banner that flags "memory persistence is unavailable." Schedule a retry on next foreground. Crash reports to Sentry-equivalent (already integrated in `Services/CrashReporting/`).

**Effort:** 2–3 hours per call site. Touches two files.

### 4.3 MEDIUM — fix opportunistically

#### 4.3.1 Force-unwrapped URL construction

8+ sites use `URL(string: "...")!`. Most are static literals (low risk) but a handful interpolate values. Examples:

- [SpotifyVibeManager+Auth.swift:29, 216, 268](AiQo/Core/SpotifyVibeManager+Auth.swift)
- [SmartFridgeCameraViewModel.swift:182](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift) — interpolates `apiKey`

**Fix:** replace all dynamic-URL force unwraps with `guard let url = URL(string: ...) else { throw URLError(.badURL) }`. Static literals are fine to leave (the app will fail to launch on a typo, which is loud and catchable).

#### 4.3.2 `try!` audit (38 occurrences)

Most are static `NSRegularExpression` patterns where the literal cannot be wrong. Worth one audit pass to confirm none has crept into a code path that takes user input.

**Fix:** grep + manual triage. Replace any dynamic `try!` with `do { … } catch { fallback }`.

#### 4.3.3 No certificate pinning verifier in CI

Even after §4.2.2 lands, there is no CI step that reads the IPA, extracts the embedded fingerprints, and verifies they match a tracked file in source control.

**Fix:** add a release-build step that asserts the bundled fingerprint matches `Configuration/CertPinning.json`.

### 4.4 LOW — quality / hygiene

#### 4.4.1 Tribe module duplication

There are two top-level Tribe surfaces:

- `AiQo/Features/Tribe/` — 3 files, **1,793 LOC** (TribeView, TribeExperienceFlow, TribeDesignSystem)
- `AiQo/Tribe/` — 13 root files + 6 subdirectories (Arena, Galaxy, Log, Models, Preview, Repositories, Stores, Views), **5,295 LOC across the top files alone**

Both are genuinely live: `Tribe/TribeScreen.swift` is a 17-line wrapper that instantiates `TribeView()` from `Features/Tribe/`. So the larger `Tribe/` directory is *not* dead code — it's a parallel-and-collaborating module. But the split is not principled (why does TribeView live in Features/ while TribeStore lives in /Tribe/?) and any new Tribe contributor will burn an hour orienting.

**Fix:** consolidate. Pick one canonical home (`AiQo/Features/Tribe/`) and migrate everything in `AiQo/Tribe/` into it. Estimated 1 day of move-and-adjust-imports work + smoke test of all Tribe surfaces (Arena, Galaxy, Pulse, Hub, Leaderboard).

**Note:** Tribe is currently feature-flagged off in production (per Blueprint 17 §2.2), so this consolidation can land without user-visible risk.

#### 4.4.2 `LegacyCalculationViewController` is misnamed

[AiQo/Features/First screen/LegacyCalculationViewController.swift](AiQo/Features/First screen/LegacyCalculationViewController.swift) is *not* legacy — it is the live first-launch screen, referenced from `SceneDelegate.swift` and `HistoricalHealthSyncEngine.swift`. The name is a footgun: anyone scanning the file tree for dead code would assume this is removable.

**Fix:** rename to `OnboardingEntryViewController.swift` (or `FirstLaunchViewController.swift`). Rename the parent directory from `First screen/` (which has a space and looks accidental) to `FirstLaunch/`. ~10 minutes work; touches the two callers.

#### 4.4.3 `AiQoCore/` is an empty placeholder

[AiQo/AiQoCore/](AiQo/AiQoCore/) contains only `AiQoCore.h` and a `.docc` folder — no Swift files. Either it was scaffolded for a future shared-framework extraction that never happened, or it's leftover from an Xcode template wizard.

**Fix:** decide. Two options:

1. **Use it.** Promote a small set of cross-target shared types (`AppGroupKeys`, `XPCalculator`, the Brain message types) into `AiQoCore` as a real Swift module that the iOS app, watch app, and both widgets can link. Pays off because the four targets currently duplicate or copy-paste these types.
2. **Delete it.** Remove the directory and the `.h` file. Saves nothing but removes confusion.

The first option is the right move for a global-quality app, but it's a 1–2 day project. The second option is 5 minutes. Either is fine; the placeholder is the worst of both.

#### 4.4.4 Brain stub backlog

Sixteen 7-line stub files exist across the Brain. Most are placeholders from the original 91-stub scaffold (P1.1 commit `874c683`). Listed in Blueprint 17 §16. The most-quoted are `RoutingPolicy`, `ResponseValidator`, `CulturalValidator`, `SignalBus`, `CircadianReasoner`, `ConsentGate`, `DataClassifier`, `DifferentialPrivacy`, `MoodModulator`, `VoiceProfile`, `DynamicPersonalizer`, `NotificationDelivery`, `IntentPlanner`, `FeedbackTracker`, `PriorityRanker`, `AchievementTrigger`, `CulturalContext`, `MemoryUsageTracker`, `PerformanceMetrics`, `BrainHealthMonitor`, `DecayEngine`, `NightlyConsolidation`, `PersonalizationEvolver`, `WeeklyConsolidation`.

**Fix:** triage in two passes. Pass 1: identify which stubs have real call sites (`grep` reveals stubs with zero callers can be deleted now). Pass 2: schedule the remaining ones for v1.1 implementation per Blueprint 17 §3.2.

**Effort:** 2 hours triage; per-stub implementation cost varies.

#### 4.4.5 Three `Info.plist` flags are unused or stale

- `BRAIN_DASHBOARD_ENABLED` (line 19, default `false`) — only used for the DEBUG-only inspector
- `CRISIS_DETECTOR_ENABLED` (line 51, default `true` in some builds) — `BrainOrchestrator.wellbeingDecision` runs *unconditionally*, ignoring this flag (Blueprint 17 §3.2.10 confirms)
- `PLANK_LADDER_CHALLENGE_ENABLED` (line 88, default `false`) — kept compilable for rollback; intentionally retained per CHANGELOG.md v1.0.2

**Fix:** delete `BRAIN_DASHBOARD_ENABLED` (DEBUG ifdef is sufficient) and `CRISIS_DETECTOR_ENABLED` (since the orchestrator ignores it). Document `PLANK_LADDER_CHALLENGE_ENABLED` as the intentional back-compat flag it is.

#### 4.4.6 Dead `CAPTAIN_ARABIC_API_URL` dev IP in build settings (found 2026-05-17)

[AiQo.xcodeproj/project.pbxproj](AiQo.xcodeproj/project.pbxproj) defines, in **both Debug and Release** config blocks, `"CAPTAIN_ARABIC_API_URL[sdk=iphoneos*]" = "http://192.168.1.222:3000/captain-ar"` (a LAN dev-machine IP, cleartext HTTP) and `[sdk=iphonesimulator*]` = `http://localhost:3000/captain-ar`. On first sight this looks **critical** (a production build pointing the Arabic Captain at a private IP would brick the app's centerpiece for every real user). It was investigated and is **not** live: the key is **not** in `Info.plist` (no `$(CAPTAIN_ARABIC_API_URL)` reference) and **no Swift code reads it** — the real Captain endpoint resolves through `CaptainProxyConfig` (used by `HybridBrain`, `MemoryExtractor`) / `K.Supabase` in `Constants.swift`. So this is **dead/leftover build-setting cruft**, harmless to runtime, but confusing and a latent footgun if someone wires it up later.

**Fix (LOW, post-launch):** delete the three `CAPTAIN_ARABIC_API_URL*` lines from both config blocks in `project.pbxproj`. Do **not** do hand pbxproj surgery under resubmission time pressure — it is inert, so it does not block v1.0.6.

---

## 5. Architecture Debt

Items not security-graded but architecturally important for the "global / professional" goal the user asked for.

### 5.1 The "single door" pattern is incomplete for cloud calls

The `NotificationBrain` is the verified single door for notifications — Blueprint 17 §7.1 confirms zero direct `UNUserNotificationCenter.current().add(...)` calls outside the brain. But the *cloud-LLM* equivalent of NotificationBrain is missing. `HybridBrainService` is the single canonical caller for the chat path, but feature-level callers (§4.1.1) bypass it freely.

**Action:** §4.1.1's `CaptainCloudGateway` is the structural fix. After it lands, audit:

```bash
grep -R "URLSession" AiQo/ --include='*.swift' | grep -v 'CaptainCloudGateway\|MiniMaxTTSProvider\|Supabase\|Spotify\|ReceiptValidator'
```

The output should be empty. Anything that remains is a new hole.

### 5.2 `MEMORY_V4_ENABLED` is still false  →  ✅ DONE in v1.0.4

> **Status update 2026-05-12:** The flag was flipped to `true` globally in v1.0.4 (commit `8374785`) after the side-by-side validator confirmed parity. V4 is now the active path; legacy V3 (`MemoryStore.swift`, 1312 lines) is retained as a read-fallback only. Watch the next few crash-free sessions and TestFlight feedback before deleting the V3 path entirely. The text below is preserved verbatim for historical context.

Blueprint 17 §3.2.3 documents that Brain Memory V4 (the five-store SwiftData architecture) is fully written but gated behind an Info.plist flag that is `false` in this branch. The legacy V3 store ([MemoryStore.swift](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift), 1312 lines) is what actually runs in production. V4 has been ready since BATCH 2; the cutover is blocked on validation that the V3→V4 custom migration doesn't drop user memories.

**Action (completed):** schedule a v1.1 cutover. Steps:

1. Build a side-by-side validator that runs both V3 reads and V4 reads on the same query and asserts equivalence.
2. Run the validator on a corpus of recorded test conversations.
3. Flip the flag in an internal TestFlight build.
4. Watch for memory-related crashes or "the Captain doesn't remember me anymore" feedback.
5. Promote to a public release.

### 5.3 No network-layer abstraction outside cloud LLM

There is no shared `Networking` / `APIClient` module. Every feature that needs a cloud call writes its own URL construction, JSONEncoder, retry logic, and error mapping. Examples: `SpotifyVibeManager`, `ReceiptValidator`, `SupabaseArenaService`, `MiniMaxTTSProvider`. Each is correct in isolation but together they mean any cross-cutting concern (timeouts, retries, observability, certificate pinning) requires 5+ separate touches.

**Action:** lower priority than §4.1.1 because the LLM gateway covers the highest-risk path. Schedule for v1.2: extract a `CloudNetwork` module under `AiQoCore` (see §4.4.3 option 1) that all four cloud-talking features use.

### 5.4 Test coverage is thin (~10%)

63 test files vs 590 source files = ~10% file-ratio. A few subsystems have strong coverage (the Brain's `Reasoning/` and `Wellbeing/` got dedicated test sweeps in BATCH 4 + 8). Most features have zero tests.

**Action:** not all 590 files need tests, but the cloud + privacy + entitlement boundary should be near-100% covered. Prioritize: (a) `PrivacySanitizer`, (b) `AuditLogger`, (c) `TierGate`, (d) `EntitlementStore`, (e) the new `CaptainCloudGateway` once it lands. Each has 1–2 days of test work.

### 5.5 Stub-file index needs maintenance

Blueprint 17 §16 names 16 specific stub files. Some have been implemented since (e.g., `EmotionalEngineAPI` was a stub, now is real). The list needs a refresh.

**Action:** part of §4.4.4 triage. Output: an updated AIQO_TECH_DEBT.md entry per still-stub file with a concrete implementation trigger.

---

## 6. Roadmap

Concrete, prioritized items. Each maps to a section in §4 / §5 above.

### P0 — ship-blockers for v1.0.2 / v1.1

Fix before the next App Store release.

> **Status update 2026-05-12:** v1.0.3 shipped the privacy-hardening half of this row; v1.0.4 shipped the Memory V4 cutover from §5.2. The remaining items below are revalidated against the v1.0.5 codebase.

| Item | Section | Effort | Owner trigger | Status |
|---|---|---|---|---|
| `CaptainCloudGateway` extraction + 3-caller migration | §4.1.1 | 1–2 days | Before any new cloud-calling feature | ✅ resolved for the three feature-level callers in v1.0.3; the formal gateway extraction is now P2 |
| API keys out of URL query strings | §4.1.2 | (folds into above) | Same | ✅ DONE in v1.0.3 |
| Subscription state to Keychain | §4.1.3 | 0.5 day | Before next paywall A/B | open |

### P1 — production hardening

Fix in the next sprint after P0 lands:

| Item | Section | Effort |
|---|---|---|
| Keychain error logging | §4.2.1 | 1 hour |
| Certificate pinning on cloud surface | §4.2.2 | 0.5 day |
| `fatalError` graceful-degrade | §4.2.3 | 0.5 day |
| Force-unwrap URL audit | §4.3.1 | 2 hours |

### P2 — architecture consolidation

Take in the v1.1 → v1.2 window:

| Item | Section | Effort |
|---|---|---|
| Tribe consolidation | §4.4.1 | 1 day |
| `LegacyCalculationViewController` rename | §4.4.2 | 30 min |
| `AiQoCore` decision (use vs delete) | §4.4.3 | 5 min decide; 1–2 days execute if "use" |
| Brain stub triage + delete dead stubs | §4.4.4 | 2 hours triage |
| `Info.plist` flag cleanup | §4.4.5 | 30 min |
| MEMORY_V4_ENABLED cutover | §5.2 | 1 week (validator + TestFlight + monitor) |

### P3 — quality

Ongoing:

| Item | Section |
|---|---|
| `try!` audit | §4.3.2 |
| CI cert-pinning verifier | §4.3.3 |
| Test-coverage push on the privacy + entitlement boundary | §5.4 |
| Network-layer abstraction (CloudNetwork module) | §5.3 |
| Living `AIQO_TECH_DEBT.md` updates | §5.5 |

### Beyond v1.1

Strategic items from Blueprint 17 §15 + §17 worth re-flagging:

- **Tribe re-enablement** with a redesigned social model (currently feature-flagged off).
- **Apple Intelligence on-device path** for the chat fallback (the §3.2.5 LocalBrain is in place but Foundation Models on iOS 26 isn't broadly tested yet).
- **Sleep architecture rollout** (Blueprint 17 §3.2.5 plus AIQO_TECH_DEBT entry on Foundation Models helper extraction).
- **Saudi + Iraq launch** — the wellbeing layer's region detection already supports these, but the App Store Connect catalog and pricing per market need a deliberate rollout.
- **Watch app feature parity** — currently mirrors a subset of the iPhone surface; the Tribe + Captain Memory + Notifications could all extend to the wrist.

---

## 7. Operational Notes

### 7.1 Where to find things

| What you want | Where to look |
|---|---|
| Master deep reference (history, full inventory) | [AiQo_Master_Blueprint_17.md](AiQo_Master_Blueprint_17.md) |
| Master forward guidance (this file) | [AiQo_Master_Blueprint_18.md](AiQo_Master_Blueprint_18.md) |
| Living tech-debt log | [AIQO_TECH_DEBT.md](AIQO_TECH_DEBT.md) |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |
| Notification system (full technical reference, v1.0.5) | [AiQo_Notifications_System.md](AiQo_Notifications_System.md) |
| Notification "no-deliveries" diagnostic (read-only, drove the v1.0.5 redesign) | [diagnostic.md](diagnostic.md) |
| Build / dev setup | [Configuration/SETUP.md](Configuration/SETUP.md) |
| English product context (8-doc explainer) | [docs/explainers/en/](docs/explainers/en/) |
| Arabic product context (5-doc شرح شامل) | [docs/explainers/ar/](docs/explainers/ar/) |
| Historical batch logs from Brain refactor | [docs/archive/batch-results/](docs/archive/batch-results/) |
| App Store submission history | [docs/archive/app-store/](docs/archive/app-store/) |
| Captain refactor recon + diagnostic reports | [docs/archive/captain-brain/](docs/archive/captain-brain/) |
| P-fix phase logs (P0.1 → P_FIX_DEV_OVERRIDE) | [docs/archive/p-fix/](docs/archive/p-fix/) |
| Old MyVibe + pre-16 blueprints | [docs/archive/blueprints/](docs/archive/blueprints/) |

### 7.2 What NOT to do

- **Do not** add any new ad-hoc `URLSession` call to a feature module. All cloud LLM calls go through `04_Inference/Services/` (see §4.1.1).
- **Do not** write secrets, tokens, or subscription state to `UserDefaults`. Use `KeychainStore` (see §4.1.3).
- **Do not** disable `PrivacySanitizer` "for performance." It is the boundary — see Blueprint 17 §3.2.6.
- **Do not** modify files in `AiQo/Features/Gym/Club/Plan/` or `AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift` without reading the §32 / §36 timeline in Blueprint 17 — these have active in-flight work in the brain-refactor branch.
- **Do not** use `git add -A` or `git add .` from the root after this hygiene pass without reviewing the staged renames first — git will detect the docs/ moves as renames but you should verify before committing.
- **Do not** commit `Configuration/Secrets.xcconfig`. It is gitignored. If you ever accidentally stage it, treat it as a key-rotation event.
- **Do not** re-introduce an auto-started no-card trial (the removed `FreeTrialManager.startTrialIfNeeded()` call at onboarding). The v1.0.6 model is: trial = Apple's card-required StoreKit intro offer only; the onboarding paywall is a hard gate; legacy active trials are grandfathered via `FreeTrialManager.isTrialActiveSnapshot`. See §2A Thread 8.
- **Do not** stage `.claude/` (e.g. `.claude/scheduled_tasks.lock`) into an app commit — it is local Claude Code workspace data, not app source. Scope `git add` to `AiQo AiQoTests AiQo.xcodeproj AiQo_Master_Blueprint_18.md`.

### 7.3 Runbooks

#### Clean rebuild from scratch

```bash
rm -rf build/
xcodebuild clean -project AiQo.xcodeproj -scheme AiQo
```

The `build/` directory is gitignored and regenerable. The hygiene pass deleted it; Xcode will recreate it on the next build.

#### Add a new permission string

Edit four places, all in lockstep:

1. `AiQo/Info.plist` — the technical permission key (e.g. `NSCameraUsageDescription`)
2. `AiQo/Resources/en.lproj/InfoPlist.strings` — English copy
3. `AiQo/Resources/ar.lproj/InfoPlist.strings` — Arabic copy
4. The pbxproj if a new framework is needed

Verify with: `grep -R "NSCameraUsageDescription" AiQo/` — must show all three locales + Info.plist.

#### Rotate an API key

Updates in two places:

1. `Configuration/Secrets.xcconfig` — local
2. The corresponding Supabase Edge Function env var (`captain-chat`, `captain-voice`)

Re-deploy the Edge Function. Revoke the old key from the provider console (Google AI Studio / MiniMax dashboard).

History reference: 7524f88 (`fix(security): restore xcconfig placeholder pattern, rotate MiniMax + Gemini keys`).

#### Toggle Brain V4

When ready (see §5.2):

1. Edit `AiQo/Info.plist`: `MEMORY_V4_ENABLED` from `false` to `true`.
2. Internal TestFlight build first.
3. Watch crash reports for SwiftData migration failures.
4. Promote to production once the validator (built per §5.2 step 1) reports zero divergence.

#### Ship a hotfix

Follow Blueprint 17 §28 / §31 patterns: small focused branch, tightly-scoped commit, App Store Connect resubmit. v1.0.1 → v1.0.2 happened via PR #6.

### 7.4 Onboarding a new contributor

If someone joins the project, point them at this document in this order:

1. Read this file (Blueprint 18) end-to-end.
2. Skim Blueprint 17 §1–§3 for the architecture.
3. Read `docs/explainers/en/AiQo_AIContext_00_README.md` for product context.
4. Run `Configuration/SETUP.md` to get a build going.
5. Check the AIQO_TECH_DEBT.md for "trigger to revisit" items that match what they want to work on.

For Arabic-fluent contributors, swap step 3 for `docs/explainers/ar/`.

### 7.5 The "global / professional" bar

The user's brief was "اجعل تطبيق عالمي و ممتاز جداً" — make it a global, excellent app. The hygiene pass landed the *organizational* half of that bar:

- ✅ Clean root with everything where you'd expect it
- ✅ Documentation discoverable by purpose, not by accident of filing
- ✅ A clear separation between the in-flight brain-refactor work and the surrounding stable surface
- ✅ A living blueprint that supersedes 17 and points forward
- ✅ A concrete, prioritized security + architecture roadmap

The *engineering* half of that bar is the §6 P0 items. Until §4.1.1 lands, the audit-log claim is incomplete — and that's the table-stakes promise of an Arabic-first app whose differentiator is privacy-respecting AI.

---

## 8. Footer

**Author:** Mohammed Raad (mraad500), with the 2026-05-10 hygiene pass; refreshed 2026-05-12 for v1.0.5; post-refresh hardening update 2026-05-17 (§2A); v1.0.6 monetization hard-wall + trial-journey re-anchor update 2026-05-17 (§2A "v1.0.6").
**Originally generated:** 2026-05-10. **Refreshed:** 2026-05-12. **Updated:** 2026-05-17 (twice — post-refresh hardening, then v1.0.6 resubmission).
**Repo HEAD at original generation:** `39ca529` (`fix(captain-brain): mark HRMoodReading.unknown nonisolated`).
**Repo HEAD at v1.0.5 refresh:** `ab6885e` (`fix(captain): force workoutPlan in gym + allow constructive body-photo feedback`).
**Repo HEAD at 2026-05-17 post-refresh update:** `2df0a9a` (`fix(plan): restore the pinned plan into the Plan tab on relaunch`).
**Repo HEAD at 2026-05-17 v1.0.6 update:** `d816d78` (`feat(paywall): hard-wall Apple trial + trial-journey fix; v1.0.6 b22`), pushed to `origin/release/v1.0.4-memory-v4`.
**Active branch:** `release/v1.0.4-memory-v4` (now the v1.0.6 release candidate; branch name is legacy from the v1.0.4 memory cut).
**Supersedes:** Blueprint 17 for forward guidance only. Blueprint 17 remains the canonical historical reference for the §1–§36 batch chronology and the deep-reference text for the eleven Brain subsystems.
**Status:** ready to read; v1.0.6 / build 22 committed + pushed at `d816d78`, clean Debug simulator build green. **Blocked on App Store Connect only:** Introductory Offer = Free / 1 week on both subs + IAPs Ready-to-Submit on build 22 + Paid Apps Agreement, then archive + upload. Public App Store is still at v1.0.2 (build 19); v1.0.5/21 was withdrawn pre-approval. Next blueprint cut should follow the v1.1 release.

— *الكابتن حمّودي بانتظار الترقية القادمة.*
