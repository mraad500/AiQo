# AiQo — Glossary

> AiQo-specific terms and concepts, for grounding any answer in the product's own vocabulary. Sources: `docs/ai-context/`, `AiQo_Master_Blueprint.md`.

| Term | Arabic | Definition |
|---|---|---|
| **AiQo** | — | The product: an Arabic-first, AI-native health companion for iOS. Positioned as a *Bio-Digital OS*, not a fitness tracker. |
| **Bio-Digital OS** | — | AiQo's organizing philosophy: the body is the input (HealthKit), the AI is the interface (Captain), and the system adapts to the user's circadian rhythm across five bio-phases. |
| **Captain Hamoudi** | كابتن حمودي | The AI coach at the center of AiQo. Speaks Iraqi/Gulf Arabic, remembers the user, and reasons over their health data. (Also spelled "Hammoudi.") |
| **Bio-phase** | — | One of five circadian phases — *Awakening, Energy, Focus, Recovery, Zen* — that shift the Captain's tone, timing, and advice through the day. |
| **Tier** | الاشتراك | Subscription level. Enum `SubscriptionTier`: `none(0) < max(1) < trial(2) < pro(3)`. ⚠️ `.max` is the **entry** paid tier ($9.99), **not** the top; `.pro` ($19.99) is the top. |
| **AiQo Max** | — | The entry paid tier, $9.99/mo. Full Captain, Kitchen, Gym, Sleep, Battle, My-Vibe-less. |
| **AiQo Intelligence Pro** | — | The top tier, $19.99/mo. Adds advanced model, extended memory, full Peaks, My Vibe, Directives, photo analysis. |
| **Trial** | التجربة المجانية | A 7-day, Pro-equivalent free trial. No charge during the trial; one per Apple ID. |
| **Daily Aura** | — | The animated 24-hour activity ring on the Home screen (concentric arc segments). |
| **Peaks / Legendary Challenges** | قِمَم / التحديات الأسطورية | Real 4–16 week periodized record programs. Full access is Pro; Max is view-only. |
| **Engine Test** | قياس المحرك | The HR-reserve fitness assessment (via Apple Watch) that calibrates a Peaks plan. |
| **Dynamic AI Plan** | خطة حية | A Peaks training plan rewritten weekly from the user's latest data. |
| **Weekly Review** | ضبط البوصلة الأسبوعي | The Captain's weekly Peaks debrief that adjusts next week's plan. |
| **Battle / QuestKit Arena** | — | A competitive ladder: 10 stages × 5 challenges × 3 difficulties; stages unlock sequentially. (Max+) |
| **Quests** | التحديات اليومية | Daily/weekly micro-tasks that award XP. (Free) |
| **Learning Spark** | شرارة التعلّم | A one-time starter quest — the first challenge in Battle Stage 1 ("Awakening"), **free** to start. Complete a hand-picked free course (Edraak, Arabic ~6h; or Coursera, English ~15h) and verify the certificate **on-device** (the cert never leaves the phone) for a **+1,000 XP** reward. |
| **Kitchen (Alchemy Kitchen)** | المطبخ | Fridge-camera → ingredient detection → AI meal plan with macros and a shopping list. (Max) |
| **My Vibe / DJ Hamoudi** | — | Spotify-powered music that adapts to the user's biometric state and time of day. (Pro) |
| **Zone 2** | — | Hands-free voice coaching during cardio that keeps the user in the optimal heart-rate zone. |
| **Smart Wake** | الاستيقاظ الذكي | Optimal wake-window recommendation from 90-minute sleep cycles, saved as a system alarm (AlarmKit). |
| **XP / Level** | — | Experience points earned from actions; exponential curve (base 1000, ×1.2/level). |
| **Shield Tiers** | — | Level bands: Wood, Bronze, Silver, Gold, Platinum, Diamond, Obsidian, Legendary. |
| **Memory** | ذاكرة الكابتن | The Captain's durable store of user facts (identity, goal, body, preference, mood, injury, nutrition, workouts, sleep, insights). ~200 facts on Max, ~500 on Pro. |
| **Directives** | — | User-taught standing rules the Captain executes automatically and forever. (Pro) |
| **Conversation Digest / Compaction** | — | A faithful summary of an older conversation, carried in the `conversationState` prompt field with a "grounding lock" so the Captain never invents or contradicts prior commitments. |
| **PrivacySanitizer** | — | The layer that redacts PII (emails, phones, UUIDs, IPs) and normalizes names to "User" before any cloud call. Health metrics pass through **exactly** (not bucketed). |
| **Hybrid Brain** | — | The two-layer AI: on-device (Apple Intelligence) for sleep/fallback/privacy work, and cloud (Gemini) for chat and plans. |
| **BrainOrchestrator** | — | The router that decides on-device vs. cloud per intent and runs the fallback chain. |
| **TierGate** | — | The single gate (`TierGate.shared.canAccess(_:)`) that enforces which features a tier may use. |
| **Tribe / Arena** | القبيلة | A small private social layer (max 5 members). Built but **not yet live** (feature-flagged off). |
| **Sparks** | — | In Tribe: encouragement sent to a teammate that adds energy. |
| **Outdoor Run** | — | GPS running with a 3D map, chase camera, live stats, and route replay. (Free) |
| **Daily Record** | — | The per-day SwiftData model holding goals and progress (steps, calories, water, workouts). |
| **Hamoudi Persona (brand)** | — | The founder's public persona, fused with the in-app Captain so all "Hamoudi" content is AiQo content. |
