# Changelog

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
