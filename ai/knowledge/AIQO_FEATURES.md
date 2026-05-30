# AiQo — Features

> Every AiQo feature, what it does, and the minimum tier it requires. Tiers: **Free** (`.none`) · **Max** ($9.99, `.max`) · **Pro** ($19.99, `.pro`) · **Trial** (7 days, Pro-equivalent). Sources: `docs/ai-context/AiQo_AIContext_02_UserExperience.md`, `AiQo_Master_Blueprint.md`, the iOS source, and [aiqo.app](https://aiqo.app).

---

## Quick tier map

| Feature | Min tier | Feature | Min tier |
|---|---|---|---|
| Home / Daily Dashboard | Free | Captain Hamoudi chat | **Max** |
| Apple Health tracking | Free | Captain memory | **Max** |
| XP & Leveling | Free | Captain voice (TTS) | **Max** |
| Daily Quests | Free | Kitchen (fridge → meal plan) | **Max** |
| Learning Spark | Free | Full Gym plans & Zone-2 coaching | **Max** |
| Smart Water (basic) | Free | Sleep Smart Wake & analysis | **Max** |
| Progress Photos | Free | Battle / QuestKit Arena | **Max** |
| Weekly Report | Free | Peaks (view-only) | **Max** |
| Outdoor Run (GPS) | Free | Peaks / Legendary Challenges (full) | **Pro** |
| Profile & Settings | Free | My Vibe / DJ Hamoudi (Spotify) | **Pro** |
| Data Export & Compliance | Free | Multi-week workout plans | **Pro** |
| Apple Watch app & Widgets | Free | Photo / form analysis | **Pro** |
| Onboarding | Free | Directives | **Pro** |
| | | Advanced AI model & memory | **Pro** |

---

## Free features (everyone)

### Home / Daily Dashboard
Your day at a glance: a metrics grid (steps, calories, distance, stand, sleep, water, workouts), the animated **Daily Aura** (a 24-hour activity ring visualization), an interactive water bottle, a vibe card, streak badge, and level-up celebrations. *(AR: الرئيسية — "يومك بنظرة واحدة")*

### Apple Health tracking
Continuous read of HealthKit (steps, heart rate, HRV, energy, distance, stand, sleep, VO₂max, workouts, water). Optional write-back for water and workouts.

### XP & Leveling
Every meaningful action earns XP (workouts, hitting step goals, meals, streaks, quest completion). Exponential curve (base 1000, ×1.2 per level). Levels map to **shield tiers**: Wood → Bronze → Silver → Gold → Platinum → Diamond → Obsidian → Legendary.

### Daily Quests
Small daily/weekly tasks (steps, plank, push-ups, sleep, calories, distance, Zone-2, mindfulness, kindness, streaks) that award XP. *(AR: التحديات اليومية — "تقدّم يومي. مكافآت حقيقية")*

### Learning Spark
Complete an online course (Edraak, Coursera, …), then verify the certificate **on-device** (Vision OCR + text match) to earn a large XP reward.

### Outdoor Run (GPS)
GPS running with a 3D satellite map, cinematic chase camera, live stats (distance, pace, HR, calories, elevation), per-km milestones, phone↔Watch GPS fusion, and an interactive route replay.

### Smart Water Tracking (basic)
Hydration goals and reminders that adapt to activity, climate (WeatherKit), and time of day, with a home-screen widget.

### Progress Photos
Before/after body-transformation tracking with weight and notes, plus side-by-side compare. Stored locally (SwiftData).

### Weekly Report
A 7-day vs. prior-week summary (0–100 score), daily chart, metric cards, workout summary, and a motivational message — shareable as an image/Story.

### Profile, Settings, Data Export & Compliance
Avatar, bio metrics, level/XP, privacy toggle, language, notification settings. **Data Export:** HealthKit export to CSV/JSON/PDF, AI data-use disclosure, consent surfaces, medical disclaimer (GDPR-style portability).

### Apple Watch app & Widgets
*(AR: "معاك على معصمك")* Live activity rings, one-tap/preset workouts, real-time heart rate, and a quick voice check-in with the Captain. Home-screen + watch-face widgets and Live Activities (Dynamic Island).

---

## Max features ($9.99/mo)

### Captain Hamoudi chat
The AI coach tab: a 3D RealityKit avatar, the hybrid on-device + cloud brain, chat history, the cognitive pipeline (intent → emotion → memory retrieval → context → generation), quick-reply chips, and rich structured cards (workout plans, meal plans, reminders). See [CAPTAIN_HAMMOUDI_PROFILE.md](CAPTAIN_HAMMOUDI_PROFILE.md). *(AR: "مو مساعد. شخصية.")*

### Captain memory
The Captain remembers ~200 facts about you (Max), with confidence scoring and sources (explicit, extracted, HealthKit, inferred).

### Captain voice (TTS)
Spoken replies via the `captain-voice` proxy (MiniMax), with Apple on-device TTS fallback. Consent-gated.

### Kitchen
*(AR: المطبخ — "كل وجبة تخدم هدفك")* Point the camera at your fridge → ingredient detection (Gemini Vision) → a 3- or 7-day meal plan calibrated to your goal, with full macros and an auto-built shopping list. Images are sanitized (EXIF/GPS stripped, re-encoded ≤1280px) before any cloud call.

### Full Gym & workouts
*(AR: التمارين — "كل تمرين، مفصّل لك")* Captain-generated plans (exercises, sets, reps, rest), a live session screen (timer, HR, calories), **Zone-2 hands-free voice coaching** (the Captain talks you through staying in the right HR zone), Apple Watch tracking, and a post-workout summary with Captain commentary. Siri Shortcuts to start workouts.

### Sleep (Smart Wake + analysis)
*(AR: النوم — "نوم أعمق. صحوة أذكى")* HealthKit sleep tracking, a quality-score ring, **Smart Wake** (optimal wake windows from 90-minute cycles → an AlarmKit alarm), and **on-device** Apple-Intelligence sleep analysis with a morning briefing. Sleep data never leaves the device.

### Battle / QuestKit Arena
A competitive challenge ladder: 10 stages × 5 challenges, 3 difficulty levels each, auto-tracked via HealthKit plus manual entry; each stage unlocks only on full completion of the prior one.

### Peaks (view-only on Max)
Max users can browse Peaks / Legendary Challenges but not start them — a deliberate "preview to create desire." Full access is Pro.

---

## Pro features ($19.99/mo — "Intelligence Pro")

### Peaks / Legendary Challenges (full)
*(AR: قِمَم — "أرقام قياسية، نكسرها بذكاء بايولوجي")* Real **4–16 week periodized** record projects across world-record-style categories (longest plank, fastest mile, most push-ups, sprints, …). Flow: an **Engine Test** (HR-reserve fitness assessment via Apple Watch) → a **Dynamic AI Plan** rewritten weekly from your data → a **Weekly Review** debrief with the Captain. Not "30-day gimmicks" — genuine progression.

### My Vibe / DJ Hamoudi
*(AR: My Vibe — "الموسيقى الصح بالوقت الصح")* Music that tracks your day's rhythm (calm morning, midday push, evening wind-down), powered by Spotify, with the Captain recommending playlists from your biometric state and mood.

### Advanced intelligence
The advanced AI model (deeper reasoning), extended memory (~500 facts), premium voice, weekly **insight narratives**, monthly reflection, multi-week workout plans, and **photo/form analysis**.

### Directives
Teach the Captain a standing rule once ("after every workout, suggest what to eat"; "remind me to hydrate at 3pm") — parsed on-device, mirrored into every prompt, and executed automatically thereafter.

---

## Built but not yet live

### Tribe / Arena (القبيلة)
A small, private, family-sized social layer (max 5 members): shared missions, "sparks" (encouragement that adds energy), a private leaderboard, and weekly arena challenges. **Status:** fully built with demo data but **gated OFF** behind feature flags (`TRIBE_BACKEND_ENABLED`, `TRIBE_SUBSCRIPTION_GATE_ENABLED`) pending the live backend. Do **not** describe Tribe as currently available to users.

---

## Stats the product highlights

- **16 weeks** — the length of a Legendary Challenge journey ("long, designed projects — not passing daily fads").
- **22+ levels** — the progression system depth.
- **∞ memories** — "the more you talk to him, the closer and smarter he gets about you."
