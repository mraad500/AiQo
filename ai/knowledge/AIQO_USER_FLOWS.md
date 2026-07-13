# AiQo — User Flows

> The key journeys through AiQo: onboarding, the daily loop, and each major feature flow. Source: `docs/ai-context/AiQo_AIContext_02_UserExperience.md`, iOS source.

---

## 1. Onboarding

1. **Language** — Arabic (default, RTL) or English. Persisted.
2. **Sign in** — *Sign in with Apple* (the sole auth method) or "continue without account" (guest).
3. **Profile setup** — name, age, height, weight, goal (free-form), optional gender/birthdate/username.
4. **Legacy Calculation (health sync)** — request HealthKit permissions and back-fill history (steps, calories, sleep averages) into the Captain's memory. **The 7-day trial clock starts here.**
5. **Captain personalization** — primary goal (lose/gain weight, cut fat, build muscle, improve fitness); favorite sport; preferred workout time; bedtime + wake time (feeds Smart Wake).
6. **Feature intro** — a short walkthrough.
7. **Subscription intro** — a *skippable* paywall preview.

---

## 2. The daily loop

| When | What happens |
|---|---|
| **Morning (~7:15)** | A background task generates a morning insight: the Captain briefs sleep quality and suggests today's plan, referencing real HealthKit data. |
| **Throughout the day** | Steps update live; water is logged via the interactive bottle; activity is tracked. |
| **Inactivity (afternoon/evening window)** | If 3+ hours pass with no steps, the Captain sends a gentle nudge. |
| **Evening** | Context-aware reminders: hydration, workout (at the user's preferred time), streak protection (~20:00), and a sleep reminder ~30 min before bedtime. |
| **Sunday** | A weekly report is generated and delivered as a notification (the only proactive touch for free/post-trial users). |

**Quiet hours:** roughly 21:00–08:00, no proactive notifications.

---

## 3. Captain chat journey

1. Open the Captain tab → avatar + input field ("اكتب رسالتك للكابتن…").
2. Type and send.
3. **Cognitive pipeline:** intent detection → emotional-signal analysis → memory retrieval (RAG) → context building → 7-layer prompt composition → routing (sleep → on-device; everything else → cloud Gemini) → generation → fallback chain on failure.
4. The reply streams in as typed bubbles, with a "thinking" state ("Captain is reading… running Apple Intelligence… composing in Iraqi… writing").
5. Up to 3 **quick-reply chips** appear.
6. **Structured cards** render when relevant: a day-by-day workout plan, a meal plan with macros, a Spotify recommendation, or a reminder.
7. **Voice playback** is available (Max+).
8. History persists per session (SwiftData), capped by tier.

---

## 4. Kitchen journey

1. Open Kitchen (from Home or the Gym tab).
2. **Scan the fridge** — camera → Gemini Vision → ingredient list with quantities.
3. **Adjust inventory** — add/remove items; the inventory persists with emoji icons.
4. **Generate a meal plan** — choose 3 or 7 days; the Captain builds meals from what's available, calibrated to your calorie target and goal.
5. **Shopping list** — missing ingredients auto-populate; check them off.
6. **Daily Kitchen** — today's meals (breakfast/lunch/dinner) as animated recipe cards; tap for macros and ingredients.

---

## 5. Workout (Gym) journey

1. Open the Gym tab → active plan, quest progress, Club.
2. Ask the Captain for a workout → he generates a structured plan.
3. **Live session** — full-screen timer, heart rate (with pulse animation), calories, distance.
4. **Zone-2 coaching (if enabled)** — HR-zone status with spoken guidance in Iraqi Arabic ("يا بطل، نبضك ١٤٥، هسه هدّي السرعة").
5. **Post-workout** — a summary (duration, calories, avg HR, distance) with Captain commentary; XP awarded; streak updated; a Directive (Pro) may trigger a follow-up.

---

## 6. Sleep journey

1. **Setup** — set target bedtime + wake time (during onboarding).
2. **Smart Wake** — choose "from bedtime" or "from wake time", enter a time; the engine computes 90-minute-cycle recommendations with wake windows (10/20/30 min) and confidence badges ("الأفضل / متوازن / أخف").
3. **Save the alarm** — to the system (AlarmKit, iOS 26.1+).
4. **Morning analysis** — the Captain analyzes the night's sleep stages **on-device** and delivers a briefing.

---

## 7. Peaks / Legendary Challenges journey (Pro)

1. Browse the record-style challenges.
2. **Start** — run an **Engine Test** (HR-reserve assessment on Apple Watch); the Captain builds a multi-week progression plan.
3. **Weekly** — daily tasks and weekly targets.
4. **Weekly Review** — debrief progress with the Captain; the plan adapts for next week.
5. **Completion** — the journey concludes with a summary and badge.

---

## 8. Trial → subscription journey

| Day | Captain | Notifications |
|---|---|---|
| 1 | Welcome, light touch, asks about goals | ≤1 (evening, if active) |
| 2–3 | Morning briefs begin; references HealthKit | dynamic triggers begin |
| 4–5 | Feature reveals (Kitchen, Zone-2) surfaced organically | up to ~3/day |
| 6 | Deeper engagement; references remembered facts | paywall preview (~20:00) |
| 7 | Weekly recap; first memory report generated | recap (~18:00) |
| Post-trial (no sub) | Premium gated; relationship preserved | weekly Sunday recap only |

---

## 9. Tribe journey *(built, not yet live)*

Create a tribe (Pro) → members join by code (max 5) → shared mission + energy contributions → send "sparks" → weekly arena challenges → an event log. Currently behind feature flags; not available to users yet.
