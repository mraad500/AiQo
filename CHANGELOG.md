# Changelog

## v1.0.7 — 2026-06-01

A polished, more trustworthy AiQo — and one big new thing: **النواة (Kernel)**, a
digital-wellbeing app-lock you open with your body.

### New

- **النواة (Kernel) — guard your focus with movement.** Pick the apps that pull you
  in and AiQo shields them; to open one, you move — real steps (from Health) lift the
  shield. Each shield gets a little harder so the doomscroll loop breaks instead of
  feeds, but it always stays physically possible. Captain Hamoudi coaches you live
  through every challenge. It's all on your terms: turn protection off whenever you
  want (after a short, deliberate pause to keep it meaningful), and your blocked-app
  choices never leave your device. Part of AiQo Max.

### Improved

- **English, done right.** Several screens were leaking Arabic text (or, in a few
  places, raw placeholder labels) when the app was set to English. The **Weekly
  Report** (title, share menu, score reactions, motivation line), **Progress Photos**
  (empty state, summary, delete dialog), the **music / "ذوقي" sheet** (~two dozen
  controls), the **post-workout summary**, the **daily-nutrition VoiceOver label**,
  and the **language picker** all now read correctly in whichever language you choose.
- **Notifications speak your language.** Captain Hamoudi's proactive nudges and the
  daily reminders (water, workout, sleep, streak, weekly report) were always sent in
  Iraqi Arabic; English users now receive them in English.
- **Quests you can actually finish.** The camera-form quests required a literally
  unreachable 100% accuracy at their top tier, which quietly blocked progression
  through Stages 3–10. The bar is now a demanding-but-attainable 95%.
- **Honest coaching.** When you teach the Captain a standing instruction it can't yet
  run automatically in the background, it now says it'll keep it in mind and bring it
  up in chat — instead of claiming an automatic reminder that never fired.
- **A richer kitchen.** The built-in meal library grew from 6 to 18 varied meals (no
  more repeats), and meal names now show proper English.
- **Fewer dead ends.** Removed three tappable-but-inert "Clarity" cards and a
  decorative plan filter that did nothing; relabeled a Captain plan button that said
  "Start Workout" but opened a chat.

### Privacy & compliance

- **Deleting your account is now honest.** If the server can't complete the deletion,
  the app tells you and keeps you signed in to retry — instead of signing you out and
  implying your data was erased when it wasn't.
- **Age screening up front.** The quick health/age setup (which blocks under-18) is now
  a required step in onboarding rather than something reachable only from Profile.

### Behind the scenes

- Refreshed the test baseline (it had drifted from intentional product changes) and
  verified the full suite green; clean build verified for submission.

## v1.0.6 — 2026-05-30

### New

- **Captain Hamoudi keeps the whole conversation in mind — no matter how long it runs.** Long chats used to lose their beginning once the session grew, so the Captain could "forget" what you told it earlier and answer vaguely. The Captain now performs **rolling, in-place conversation compaction**: as a session grows past its live window, the earlier part is folded into a faithful, structured memory of the chat (your opening goal, the points you made, the plans and promises the Captain itself gave you, and any corrections you made) and carried forward inside the same conversation — no new screen, no lost thread. The summary is **extracted from what was actually said**, never invented, and the Captain is explicitly instructed not to fabricate any detail that isn't in that memory or the recent messages. A soft "طويت بداية محادثتنا بذاكرتي" / "earlier chat folded into memory" marker appears once at the seam so you can see the continuity. Works on every tier; sleep analysis stays on-device and untouched. New `ConversationCompactor` / `ConversationDigest` + a dedicated, PII-sanitized `conversationState` prompt channel and grounding lock.

### Improved

- **Captain Hamoudi now reports your exact numbers.** The Captain used to coarsen your live stats before reasoning on them — steps were floored to the nearest 500, so 962 steps showed up as "500" and its answers disagreed with the home dashboard. Health metrics (steps, calories, heart rate, sleep) and your height/weight now reach the Captain at full precision across the chat reply, the session-opener greeting, and proactive nudges, so what it tells you always matches what the app shows. PII redaction (names, emails, phones) is unchanged, and identifiability stays governed by the existing cloud-AI consent gate — not by blurring your own metrics.
- **Rich workout-plan cards in chat.** Plans the Captain builds now render as full day-by-day cards directly in the conversation (title, weeks, per-day muscle focus, sets/reps), with cross-feature polish so the chat, Plan, and Gym surfaces feel consistent.
- **Reliability & safety hardening.** Centralized model selection behind a single policy with a remote kill-switch (the `gemini-3-flash-preview` model is gated and OFF by default; every path falls back to the stable `gemini-2.5-flash` automatically on error/timeout). Brain V2, Memory V4, and the Notification Brain each gained a Supabase-backed remote kill switch so they can be disabled live without an App Store release. The realistic-3D surfaces (outdoor-run map, avatar) now auto-downgrade on lower-RAM devices and under thermal stress for smoother performance.

### Privacy & compliance

- The new conversation memory is derived only from messages that already flow to the cloud, and runs through the same `PrivacySanitizer` PII-redaction pipeline before any send. No new data types, no new privacy labels, no new endpoints.

### Behind the scenes

- Fixed a latent bug where the Captain's session-continuity summary never actually reached the cloud model on the main chat path (the cloud request rebuilt its working-memory block and dropped it); continuity now rides a dedicated request field that survives sanitization.
- Added a DEBUG-only `CaptainBrainV2Gate.testOverride` seam and repaired `ProactiveEngineTests` (it referenced a now get-only flag), restoring the unit-test target. New `ConversationCompactorTests` include a no-fabrication faithfulness check.

## v1.0.5 — 2026-05-12

### New

- **Teach Captain Hamoudi standing instructions — new `11_Directives` Brain layer.** The user can now teach the Captain a durable, executable rule in natural Iraqi/English — e.g. *"بعد كل تمرين حلّل تمريني وقارنه بالي قبله ودزّلي إشعار"* ("after every workout, analyze it and compare it to the previous one and notify me"). It is parsed on-device (no LLM round-trip, no added chat latency), persisted in a new **Memory Schema V5** (`LearnedDirective` @Model; one additive model + lightweight `migrateV4toV5` migration, same proven pattern as V2→V3), mirrored into every prompt's Working Memory so the Captain confirms it in the same reply and never forgets it (re-hydrated on relaunch via `DirectiveCoordinator.hydratePromptMirror()`), and executed automatically after every workout through `AIWorkoutSummaryService` — a deterministic, offline Iraqi analysis comparing the just-finished workout (duration / calories / avg-HR / distance) to the previous one. New subsystem (`AiQo/Features/Captain/Brain/11_Directives/`): `DirectiveTaxonomy`, `DirectiveStore` (actor, mirrors `ProceduralStore`), `DirectiveLearner` (conservative — needs a recurrence marker **and** an action **and** a recognized trigger, so a one-off "حلّل تمريني" never creates a rule), `DirectiveEngine` (+ pure `WorkoutComparisonComposer`), `DirectiveCoordinator`. Gated by a new `TierGate.captainDirectives` (`.max`+, consistent with `captainMemory` / `captainNotifications`); `BrainBus` gains `directiveLearned` / `directiveFired` / `workoutCompleted` events.
- **Bigger, sharper Captain memory.** `maxSemanticFacts` Pro 500→1200 / Max 200→500; `maxMemoryRetrievalDepth` 25→40 / 10→18; prompt-context budget 800→1200 tokens & 30→48 entries; relevant-memory retrieval 8→12; rolling workout history 7→30; persisted chat history 200→400. The prompt-token guard is preserved end-to-end so the larger store doesn't blow latency/cost.
- **Multi-day workout plans.** The Plan intake now includes a "Plan length" chip (1 / 2 / 4 / 8 weeks). Captain Hamoudi returns a structured plan split into named training days (e.g. "Day 1 — Chest & Triceps") with a per-day muscle focus and explicit sets/reps.
- **Day picker in the active plan card.** The Plan dashboard now surfaces a horizontal day-picker over the active plan. Selecting a day re-scopes the exercise list, time/sets/moves stats, and the "Start workout" CTA — the runner now executes only the selected day, not the entire week.
- **Optional body photo for tailored plans.** An optional photo attachment in the intake lets the user share a body photo. With explicit per-purpose consent, the image is downsized, EXIF/GPS-stripped, and sent to Google Gemini once for plan tailoring. The photo is never written to disk and never stored on AiQo servers.
- **Dedicated Body Photo consent surface.** A new "Body photo (Plan)" row under Settings → Privacy & AI Data, with grant/revoke controls, last-changed timestamp, and a plain-language explainer. Consent is independent of the AI Data and Captain Voice consents (Apple 5.1.2(II)).

### Improved

- **Plan world-class UI restored.** The unified PlanPalette surface (mint · sand · lavender · lemon) is now active across the Plan dashboard, Workout Runner, Insights, Weekly Stats, Exercise Detail, Template Library, Intake Chips, Workout Cards, and Flow Views. Visual hierarchy comes from typography, spacing, and material layering rather than color noise.
- **Plan dashboard reorder.** The active plan card now appears immediately after the hero — primary content first. The compliance footer moves to the bottom. Vertical rhythm tuned for breathing room.
- **Intake chip section names** clarified to separate "Per-session time" (length of one workout) from "Plan length" (overall program duration).
- **Prompt schema for Captain Hamoudi** updated to describe the multi-day plan output shape (title + durationWeeks + days[] with named days and focus). Backward compatible — older flat plans still decode.

### Privacy & compliance

- Body photo path uses the same audit-logged Gemini pipeline as kitchen vision; the image-handling code runs through `PrivacySanitizer.sanitizeKitchenImageData` (downsize + JPEG re-encode, drops EXIF / GPS).
- New per-purpose consent class `BodyPhotoConsent` persists state in `UserDefaults` with versioned keys (v1).
- `PrivacyInfo.xcprivacy` already declares `NSPrivacyCollectedDataTypePhotosorVideos` with purpose `AppFunctionality` — no new privacy labels required.
- Photo picker uses `PhotosPicker` (out-of-process), so `NSPhotoLibraryUsageDescription` is not needed.

## v1.0.2 — 2026-04-20

### New

- **Learning Spark Stage 2** — a new 5-course picker lands in Stage 2, slot 3, letting the user choose one free course from a curated set (Edraak + Coursera). Course titles, Arabic descriptions, and "~hours" pills help you pick by your time budget.
- Stage 2 picker header: "اختر الكورس اللي يلهمك الآن — تقدر تجرب غيره بالمرحلة الجاية" — the user holds agency, Stage 3+ can offer a different path.
- On-device certificate verification extended to Stage 2 as-is — same `HamoudiVerificationReasoner` pipeline, zero new privacy labels, image never leaves the device.
- **Challenge completion now awards XP.** Stage 1 Learning Spark grants **+1000 XP**, Stage 2 Learning Spark grants **+2000 XP**. XP reflects on your Profile level, syncs to Supabase in the background, and is awarded exactly once per challenge (idempotent by design).
- **Celebration redesign** — the "you completed a challenge" sheet now rises from the bottom as a translucent half-sheet over `.ultraThinMaterial`, showing the earned badge, congratulations, an XP pill, and the time of completion.

### Improved

- Certificate URL field in the Stage 1 / Stage 2 submission flow is now optional. The image is sufficient for verification; label and placeholder now explicitly mark the field as "(اختياري)" / "(Optional)".
- Career-path course title tuned to match the exact string on the issued Misk certificate ("...ناجح" suffix) — fewer false "pending review" results.
- Audit log entries now segment verification outcomes by stage (`learningSpark.stage1` vs `learningSpark.stage2`) for funnel analysis later.

### Behind the scenes

- Plank Ladder (the legacy Stage 2 slot-3 challenge) is retained fully compilable behind `PLANK_LADDER_CHALLENGE_ENABLED`. It can be re-enabled at any time for rollback. Emergency both-flags-off shows a non-interactive "قريباً" placeholder.
- Zero new App Store privacy labels, zero new cloud endpoints, zero new data collected.
- New `QuestXPRewards` lookup table: only Learning Spark quests currently carry an explicit XP value — other quests will receive values via future product-tuning PRs (no silent stage-default grants).

## v1.0.1 — 2026-04-19

### New

- Captain can now detect crisis cues from message text, repeated distress patterns, and severe sleep disruption, then surface professional support resources that fit the user's region.
- Captain's proactive brain is more context-aware, with better memory callbacks, emotional follow-ups, and cultural timing.
- A new developer-only Brain Dashboard shows memory counts, safety signals, trigger scores, and feature flags for debugging.

### Improved

- Crisis messages now bypass paywall and consent blockers so urgent safety guidance is never hidden behind a gated path.
- Captain's safety responses flow through one intervention policy, which keeps gentle check-ins, reflective replies, and referrals consistent.
- Regional support links are now built into the safety layer for UAE, Saudi Arabia, Iraq, and global fallback coverage.

### Known issues

- Some Captain Memory labels still fall back to raw localization keys and need one more cleanup pass.
- Final App Store submission QA is still pending for free-tier, purchase restore, trial flow, and a few manual screen checks.
