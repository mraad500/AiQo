# AiQo — Master Blueprint (المرجع الأساسي الكامل)

> **هذا الملف هو المصدر الأول والأساسي للحقيقة عن تطبيق AiQo.**
> The single source of truth for the AiQo product — its identity, founder/persona, architecture, every feature, backend, monetization, privacy, and growth strategy.
>
> **Owner:** Mohammed Raad (founder, solo) · **Persona:** Captain Hamoudi (كابتن حمودي)
> **App version:** `1.0.5` (build `27`) · **Bundle:** `com.mraad500.aiqo` · **Platform:** iOS 26.2+ (SwiftUI)
> **Doc generated:** 2026-05-30 · **Repo:** `github.com/mraad500/AiQo`

---

## 0. كيف تستخدم هذا الملف · How to use this file

**بالعربي:** هذا الملف صُمّم ليُرفَع كـ "Project Knowledge" في مشروع AiQo داخل Claude، ويُعتمد كـ**المرجع الأول والأساسي** في أي محادثة تبدأها داخل المشروع. عند أي تعارض بين هذا الملف وأي معلومة أخرى، **هذا الملف هو الحَكَم** (مع ملاحظة أن الكود في المستودع هو الحقيقة النهائية عند اختلافه عن الوصف هنا — حدّث الملف عندها).

**To establish it as the primary source in your Claude Project:**
1. Open the AiQo project on claude.ai → **Project knowledge** → add/upload `AiQo_Master_Blueprint.md`.
2. In the project's **Custom instructions**, paste:
   > «اعتمد `AiQo_Master_Blueprint.md` كمصدر أساسي وأول للحقيقة عن تطبيق AiQo في كل محادثة. عند أي تعارض، هذا الملف هو المرجع، والكود في المستودع هو الحقيقة النهائية.»
3. Keep it current: when the app changes materially, update this file (it lives in the repo root next to `CHANGELOG.md`).

**Companion source docs** (also in repo root): `AiQo_Hamoudi_Strategy.md` (v2.0 — current growth/persona strategy), `AiQo_Growth_Strategy_May-Aug_2026.md` (v1 — **obsolete**, superseded), `CHANGELOG.md`, `AIQO_TECH_DEBT.md`.

---

## Table of Contents
1. [What AiQo is](#1-what-aiqo-is--ما-هو-aiqo)
2. [Founder & the Hamoudi persona](#2-founder--the-hamoudi-persona)
3. [Product overview & tech stack](#3-product-overview--tech-stack)
4. [App architecture](#4-app-architecture)
5. [The Captain (Hamoudi) AI Brain](#5-the-captain-hamoudi-ai-brain)
6. [Feature catalog](#6-feature-catalog)
7. [Data, backend & services](#7-data-backend--services)
8. [Monetization & subscription tiers](#8-monetization--subscription-tiers)
9. [Localization & internationalization](#9-localization--internationalization)
10. [Configuration, capabilities & feature flags](#10-configuration-capabilities--feature-flags)
11. [Privacy & compliance](#11-privacy--compliance)
12. [Growth & content strategy](#12-growth--content-strategy)
13. [Version history](#13-version-history)
14. [Invariants & gotchas (do-not-break)](#14-invariants--gotchas-do-not-break)
15. [Glossary](#15-glossary)
16. [Repo map](#16-repo-map)

---

## 1. What AiQo is · ما هو AiQo

**AiQo is an Arabic-first "Bio-Digital OS" — a personal health/wellness operating system for iOS, built around an AI coach with a distinct Iraqi personality (Captain Hamoudi / كابتن حمودي).** It is not a chatbot wrapper and not a translated Western fitness app: it is written Arabic-first, speaks authentic Iraqi (Mesopotamian) dialect, remembers the user durably, and unifies workouts, running, nutrition, sleep, hydration, music/mood, challenges, and a social arena under one coach.

**One-line positioning (canonical):**
> «حمودي — مؤسس AiQo. عراقي. بنى أول AI يحجي عراقي. بياناتك ملكك.»
> *Hamoudi — founder of AiQo. Iraqi. Built the first AI that speaks Iraqi. Your data is yours.*

**The defensible moats (what no competitor in the Arabic market has):**
1. **Authentic Iraqi dialect AI** — "هلا بالذيب"، "هسّه"، "شلون"، "عاشت ايدك"، "بطل" — not translated ChatGPT.
2. **Durable memory (up to ~1000–1200 facts)** — remembers goals, injuries, preferences, prior conversations over months.
3. **Directives** — teach the Captain a standing rule once in dialect; it executes it forever (v1.0.5).
4. **Bio-phases** — the Captain knows time-of-day/circadian state and shifts tone & timing.
5. **Privacy by architecture** — PII is scrubbed *before* anything reaches the cloud; sleep stays 100% on-device.
6. **Solo Iraqi founder** — one person built every line; no investor pressure.
7. **Vision Kitchen** — photograph your fridge → AI meal plan (not "log every meal").
8. **Peaks** — real 4–12 week periodized challenges (not TikTok "30-day" gimmicks).

**Anti-positioning (what AiQo explicitly is NOT):** not a ChatGPT wrapper, not "MyFitnessPal in Arabic," not Whoop-without-hardware, not a localized Apple Fitness+, not a generic "health app." It is a Bio-Digital OS.

**Target users:** Gulf/Iraqi/Egyptian Arabic speakers, 18–35, iPhone owners, who want a coach that "speaks like them." Three personas: the returning gym-goer (highest conversion), the holistic wellness user (high LTV), and the Arabic AI/tech enthusiast (secondary amplifier).

---

## 2. Founder & the Hamoudi persona

> This section is essential product context — AiQo's brand and the in-app AI share one identity. The strategy is documented fully in `AiQo_Hamoudi_Strategy.md` (v2.0, current).

### 2.1 The founder
Mohammed Raad (محمد رعد) — a former large-scale creator (≈2M TikTok / 280K Instagram at peak) who **deliberately stepped away from "fame without substance" to build AiQo**. Framing is strategic, not tragic: the withdrawal was a deliberate pivot toward building something with meaning, not a dramatic exit. He builds solo.

### 2.2 The Hamoudi pivot (2026-05-20, current strategy = v2.0)
The current go-to-market is **persona emergence, not a comeback**: a *new* character named **Hamoudi** emerges — Iraqi, builds AI, speaks dialect, visually transformed (short hair, full beard, serious/cinematic) — **without explaining the past**. Old accounts (`@mraad_`, `m_raad_3`) stay **dormant** (not deleted, not referenced). The mystery is the marketing; discovery ("is that…?") drives engagement.

**Brand fusion:** the persona name **Hamoudi = Captain Hamoudi in the app**. Every piece of content about Hamoudi is content about AiQo. He is positioned as the first unified **Iraqi AI founder-persona**.

### 2.3 Persona discipline — the 10 golden rules (do not break)
1. **Never the name "Mohammed"** anywhere new — only "Hamoudi."
2. **No reference to old accounts** (`@mraad_`, `m_raad_3`, "2M followers").
3. **No "explanation"/comeback content** — he *emerged*, he didn't return.
4. **If detected ("this is Mohammed Raad!") → neither confirm nor deny;** ignore or deflect to the product.
5. **Visual transformation is fixed** (beard stays, hair stays short) — it's a brand asset.
6. **No dance, lipsync, or comedy skits** (pattern-matches the old creator).
7. **Camera content = product-first**, not selfie content.
8. **Engagement is minimal but intentional** — not lazma-reply to every comment.
9. **Religiously time-sensitive** — no light content during prayer/Ashura/Arafah.
10. **Hamoudi uses AiQo** — every video shows the phone with the app open.

### 2.4 The in-app Captain personality
- **Name:** حمودي (Hamoudi). **Traits:** warm, direct, witty, protective, observant, humble, culturally-rooted.
- **Values:** honesty over comfort, user wellbeing over engagement, respect for culture, privacy sacred, consent first, no medical claims.
- **Forbidden phrasings:** "you should/must," "I know how you feel," "everything happens for a reason," "just be positive."
- **Dialect:** Iraqi (Mesopotamian) primary; MSA fallback; English for tech terms. **The Captain must never speak in MSA in primary content — the Iraqi dialect is the moat.**
- **Emoji policy:** reserved for celebration kinds only (personal record, Eid, achievement unlocked, etc.); serious nudges (inactivity, sleep debt) stay plain text.
- **Three tones** (user-selectable): `practical` (عملي), `caring` (حنون), `strict` (صارم).

---

## 3. Product overview & tech stack

| Attribute | Value |
|---|---|
| **App name** | AiQo |
| **Marketing version** | `1.0.5` (build `27`) |
| **Bundle ID (app)** | `com.mraad500.aiqo` |
| **Deployment target** | iOS **26.2** |
| **Language** | Swift (project `SWIFT_VERSION = 5.0`; uses modern Swift concurrency — `actor`, `async/await`, `@MainActor`, `Sendable`) |
| **UI** | SwiftUI-first (UIKit interop for a few legacy/bridge screens) |
| **Persistence** | **SwiftData** (`@Model`) primary; UserDefaults; Keychain; file storage (JSON/JSONL) |
| **Backend** | **Supabase** (auth, Postgres, Realtime, Storage, Edge Functions) |
| **AI** | Google **Gemini** (cloud chat/vision) + **Apple Intelligence / Foundation Models** (on-device) + **MiniMax** TTS (premium voice) |
| **Dependency mgr** | Swift Package Manager (no CocoaPods) |

**Targets:** main iOS app (`AiQo`), `AiQoWatch Watch App` (watchOS), `AiQoWatchWidget`, `AiQoWidget` (iOS home-screen widget), plus test targets. There is a companion Next.js web app under `aiqo-web/` and the Supabase backend under `supabase/`.

**Key SPM dependencies:** Supabase (Auth/PostgREST/Realtime/Storage), Firebase (Core + Crashlytics), SDWebImage (+ AVIF/WebP/SVG coders), Charts, SpotifyiOS, GoogleSignIn, plus Apple frameworks: HealthKit, CoreLocation, MapKit, WatchConnectivity, ActivityKit (Live Activities), AppIntents/SiriKit, UserNotifications, BackgroundTasks, Vision, NaturalLanguage (on-device embeddings), AVFoundation, WeatherKit, RealityKit (3D Captain avatar).

### 3.1 Root navigation flow
A state machine (`AppFlowController`) drives the root screen sequence:
`languageSelection → login (Supabase auth or continue-without-account) → profileSetup → legacy (fitness baseline) → aiConsent → medicalDisclaimer → quickStart → featureIntro → subscriptionIntro (skippable paywall) → main`.

### 3.2 Main tab bar — exactly **3 tabs**
Defined in `AiQo/App/MainTabRouter.swift` (`enum Tab: Int`) and `MainTabScreen.swift`:
| Tab | Index | Purpose | Gating |
|---|---|---|---|
| **Home** | `0` | Daily dashboard (metrics, Daily Aura, water, vibe, streaks, level) | Free |
| **Gym** | `1` | Workout plans, live sessions, outdoor run, quests, challenges | Free (core); premium sub-features gated |
| **Captain** | `2` | AI chat with Hamoudi | **Max+** (`TierGate.captainChat`) |

Everything else (Kitchen, MyVibe, Sleep, Weekly Report, Profile, Tribe, etc.) is reached *within* these tabs or via navigation/sheets, not as top-level tabs.

---

## 4. App architecture

**Pattern:** hybrid **MVVM + feature-folder modules**, with **actor-based concurrency** for the Captain Brain. A typical feature folder: `{Feature}View.swift` (SwiftUI) + `{Feature}ViewModel.swift` (`@MainActor` `ObservableObject`/`@Observable`, `@Published` state) + `{Feature}Models.swift` (Codable) + optional `Services/` and `Store`. Many cross-cutting services are singletons (`.shared`).

### 4.1 Top-level layout under `AiQo/`
```
App/            App entry, AppDelegate/SceneDelegate, AppFlowController, MainTabScreen, MainTabRouter, MealModels
AiQoCore/       Shared core module
Core/           AppSettingsStore, Constants (K.Supabase…), Colors, HapticEngine, UserProfileStore,
                Config/ (AiQoFeatureFlags), Models/ (AiQoDailyRecord, WorkoutTask…), Purchases/ (tiers, StoreKit),
                Security/, Keychain/
DesignSystem/   AiQoTheme, AiQoColors, AiQoTokens, Components/, Modifiers/  (mint+sand palette)
Features/       All feature modules (see §6)
Frameworks/     Vendored/auxiliary frameworks
Premium/        FreeTrialManager, AccessManager, PremiumPaywallView
Resources/      Assets.xcassets, ar.lproj / en.lproj (Localizable.strings, InfoPlist.strings), Specs/ (achievements_spec.json)
Services/       SupabaseService, SupabaseArenaService, Analytics/, CrashReporting/, Notifications/, Location/, Trial/, Permissions/
Shared/         HealthKitManager, LevelSystem, CoinManager, WorkoutSyncModels, MedicalDisclaimerView
Tribe/          Social arena subsystem
UI/             Shared components (headers, glass cards, toasts, offline banner), Purchases/ (PaywallView)
watch/          watchOS app sources
+ loose: Info.plist, AiQo.entitlements, PrivacyInfo.xcprivacy, AppGroupKeys.swift, XPCalculator.swift, PhoneConnectivityManager.swift
```

### 4.2 Design system
Brand palette (used in-app and across all marketing): Mint `#C4F0DB` / `#CDF4E4`, Sand/Gold `#F8D6A3` / `#EBCF97`, Beige `#FADEB3`, Lemon `#FFE68C`, accent yellow `#FFDF63`. Aesthetic: glassmorphism (ultra-thin material), 16–24pt corner radius, generous whitespace, SF Pro Rounded (system). Hierarchy via typography/spacing, not color noise.

---

## 5. The Captain (Hamoudi) AI Brain

The Captain is AiQo's crown jewel and most complex subsystem. It lives under `AiQo/Features/Captain/`, with the cognitive engine under `Brain/` organized into **12 numbered layers (00–11)**.

### 5.1 The 12-layer Brain — folders `00`–`11` (folder = responsibility)
```
00_Foundation/   BrainBus (event bus), TierGate (subscription gating), BrainError, DevOverride, DiagnosticsLogger, CaptainLockedView
01_Sensing/      ContextSensor, BioStateEngine, BehavioralObserver, CaptainHealthSnapshotService; Bridges/ (HealthKit, Weather, Music)
02_Memory/       MemoryStore + Stores/ (Semantic, Episodic, Emotional, Procedural, Relationship, WeeklyMetricsBuffer)
                 Intelligence/ (MemoryRetriever, MemoryExtractor, FactExtractor, ChatMemoryEnricher, EmotionalMiner)
                 Indexing/ (EmbeddingIndex, SalienceScorer, TemporalIndex); Models/ (schemas V1–V5, migration plan)
03_Reasoning/    CognitivePipeline, CaptainContextBuilder, IntentClassifier, EmotionalEngine, SentimentDetector,
                 TrendAnalyzer, ScreenContext, CulturalContextEngine, CoachingThesisSynthesizer, AppKnowledge
04_Inference/    BrainOrchestrator (router), PromptComposer (7-layer prompt), PromptRouter, LLMJSONParser,
                 DynamicWelcomeComposer, CaptainModels; Services/ (CloudBrain, LocalBrain, HybridBrain, FallbackBrain,
                 CaptainProxyConfig); Validation/ (PersonaGuard)
05_Privacy/      PrivacySanitizer (PII scrub), AuditLogger
06_Proactive/    NotificationBrain, SmartNotificationScheduler, ProactiveEngine, TriggerEvaluator;
                 Budget/ (GlobalBudget, CooldownManager, QuietHoursManager); Composition/ (MessageComposer, TemplateLibrary);
                 Triggers/ (Health, Temporal, Behavioral, Emotional, Relationship, MemoryCallback, Cultural, Lifecycle)
07_Learning/     BackgroundCoordinator, WeeklyMemoryConsolidator, FeedbackLearner
08_Persona/      CaptainIdentity, CaptainPersonaBuilder, CaptainPersonalization, DialectLibrary, HumorEngine, WisdomLibrary
09_Wellbeing/    CrisisDetector, SafetyNet, InterventionPolicy, ProfessionalReferral
10_Observability/ BrainBusObserver, BrainDashboard, CaptainMemorySettingsView, CaptainMetricsCounter
11_Directives/   DirectiveCoordinator, DirectiveEngine, DirectiveStore, DirectiveLearner, DirectiveTaxonomy
```

### 5.2 The cognitive pipeline (message → reply)
1. **Intent detection** (`CaptainMessageIntent`): `.general / .workout / .nutrition / .sleep / .challenge / .vibe / .emotionalSupport / .recovery` — from keywords + screen context; each maps to memory-retrieval weights and a `coachingDirective`.
2. **Emotional signal** (`CaptainEmotionalSignal`): `.neutral / .motivated / .tired / .stressed / .frustrated` → tone modulation.
3. **Memory retrieval (RAG)** via `MemoryRetriever`, budget-split across the 5 stores; tier-aware depth.
4. **Context building**: current health snapshot, screen context, circadian/bio state.
5. **Prompt composition** (7-layer system prompt — see §5.4), including **conversation compaction**: the head of a long session (outside the verbatim window) is folded into a faithful `ConversationDigest` so the Captain never loses earlier context as the chat grows (see §5.6).
6. **Routing** (`BrainOrchestrator`): **sleep → on-device**, everything else → cloud Gemini.
7. **Generate**: cloud (`CloudBrain`→Gemini) or local (`LocalBrain`→Apple Intelligence / on-device chat).
8. **Fallback chain**: cloud fail → local → hardcoded offline message.
9. **Safety**: `CrisisDetector` + `SafetyNet` may short-circuit to a gentle check-in or professional referral.
10. **Personalize** (name injection), **persist** (Episodic + background fact extraction), **stream** to UI.

### 5.3 Inference routing & models
| Path | Model | When | Privacy |
|---|---|---|---|
| **Cloud** | `gemini-2.5-flash` (free/Max default) · `gemini-3-flash-preview` (Pro / reasoning + memory extraction) | gym, kitchen, peaks, myVibe, mainChat | Request sanitized (PII redacted, last ~4 msgs, health bucketed) before send |
| **On-device** | Apple Intelligence **sleep agent** · on-device chat engine | **sleep analysis (always)**; cloud fallback | Raw sleep stages never leave the device |
| **Voice** | Apple TTS (default) · **MiniMax** cloud TTS (premium/Pro) | spoken replies | Premium voice gated; key isolated per-user in Keychain |

Cloud calls can route **directly** to Gemini/MiniMax **or** through Supabase Edge Functions (`captain-chat`, `captain-voice`) when the `USE_CLOUD_PROXY` flag is on (proxy holds server-side keys + validates the user JWT).

> **Model selection is centralized in `GeminiModelPolicy`** (`Brain/04_Inference/`) and gated by `GEMINI_3_PREVIEW_ENABLED` (default **OFF**). When OFF, every cloud path (chat, kitchen vision, memory extraction, weekly review) uses the stable `gemini-2.5-flash`; the preview model is opt-in only. `CloudBrain.generateReply` adds an **automatic fallback**: if a preview call errors/times out it silently retries once on `gemini-2.5-flash` and audits both attempts.

### 5.4 The 7-layer system prompt (`PromptComposer`)
Stacked, empty layers filtered out: **(1)** reply-language lock (Arabic *or* English only) · **(2)** safety rules · **(3)** identity ("أنت الكابتن حمودي" + traits/values) · **(4)** stable profile summary · **(5)** **injury constraints** (hard rules — e.g. knee injury ⇒ "ممنوع: سكوات عميق/لانجز/قفز" + safer alternatives) · **(6)** working memory (active directives — never filtered — + relevant facts + pinned constraints) · **conversation state** (`layerConversationState`: the compacted `ConversationDigest` of the session's head + an anti-hallucination grounding lock — see §5.6; skipped in sleep mode) · **(7)** coaching thesis (emotional + cultural modulation) + bio-state + circadian tone + app-knowledge + screen context + medical disclaimer + **output contract** (the JSON shape below).

### 5.5 Structured output contract (`CaptainStructuredResponse`)
Defined in `AiQo/Features/Captain/Brain/04_Inference/CaptainModels.swift`. The model is instructed to return JSON; the app parses it (with graceful text-only fallback):
```jsonc
{
  "message": "string (required, short, natural, Iraqi dialect)",
  "quickReplies": ["…"],                 // optional suggested follow-ups
  "workoutPlan": {                        // WorkoutPlan: title, durationWeeks, exercises[] or days[]
    "title": "…", "durationWeeks": 4,
    "days": [{ "name": "Day 1 — Chest & Triceps", "focus": "…",
               "exercises": [{ "name": "…", "sets": 3, "repsOrDuration": "8-10" }] }]
  },
  "mealPlan": { /* MealPlan: title, meals[] with calories/macros */ },
  "spotifyRecommendation": { "trackId": "…", "trackName": "…", "artistName": "…", "reason": "…" },
  "savedMemory": { "category": "goal|preference|injury|insight|…", "content": "…" },
  "reminder": { "text": "…", "clockTime": "HH:mm", "repeatDaily": false }
}
```
Rendered in chat by `WorkoutPlanCard.swift` (rich day-by-day plan card, RTL-aware) and `CaptainMessageText.swift` (hand-walked `**bold**` parsing to avoid Arabic/RTL Markdown issues). Multi-day plans decode backward-compatibly with older flat plans.

### 5.6 Memory system (5 stores + RAG)
- **SemanticStore** — durable facts (goals, preferences, injuries, relationships, health constraints) with category, source (extracted/explicit/inferred), confidence, salience, PII/sensitive flags, and a persisted on-device embedding (`embeddingJSON`).
- **EpisodicStore** — conversation journal (turn + context + salience), feeds weekly consolidation.
- **EmotionalStore** — mood patterns. **ProceduralStore** — learned routines. **RelationshipStore** — people the user mentions.
- **Retrieval:** `MemoryRetriever` unifies all stores with a budget split (facts ~40%, episodes ~25%, patterns ~15%, emotions ~10%, relationships ~10%); embedding similarity (Apple `NLEmbedding`, Arabic + English, on-device) with **lexical fallback** for free tier / vector-less cases.
- **Schema** versions V1→V5 with `CaptainSchemaMigrationPlan` (V5 adds `LearnedDirective`). **Weekly consolidation** compresses episodes into a digest in a background task.
- **Conversation compaction (anti-hallucination, in-session continuity):** as a single chat grows past the verbatim window (≤24 messages **and** ≤9000 chars, floor 8), `ConversationCompactor` folds the head into a faithful, **deterministic** `ConversationDigest` — opening goal · user points · **the Captain's own commitments** (so it never contradicts/re-offers a plan it already gave) · **corrections** ("لا قصدي…") · last exchange. Every line is extracted/clipped from a real message, so the digest **cannot fabricate** (unlike an LLM summary). It is carried to the model via the dedicated, PII-sanitized `HybridBrainRequest.conversationState` field and rendered by `PromptComposer.layerConversationState` with a **grounding lock** ("if a detail isn't here or in the recent messages, don't invent it — ask or stay general; never contradict a commitment; never say 'I don't remember'"). **Lossless** even past the 80-message in-RAM cap (the evicted head is merged into a rolling `sessionDigest` before removal). All tiers (continuity is basic competence); skipped in strict sleep mode. Covered by `ConversationCompactorTests` incl. a no-fabrication faithfulness check.

### 5.7 Directives (v1.0.5, layer 11)
Teach the Captain a durable, executable rule in natural Iraqi/English (e.g. *"بعد كل تمرين حلّل تمريني وقارنه بالي قبله ودزّلي إشعار"*). Parsed **on-device** (no LLM round-trip), stored in `DirectiveStore` + Memory Schema V5, **mirrored into every prompt's working memory** (never forgotten, re-hydrated on relaunch), and executed automatically after each workout via `AIWorkoutSummaryService` (offline Iraqi analysis comparing the just-finished workout to the previous one). The learner is conservative: needs a recurrence marker **and** an action **and** a recognized trigger (so a one-off request never creates a permanent rule). Gated by `TierGate.captainDirectives` (Max+).

### 5.8 Proactive notifications (layer 06)
8 trigger types (Health, Temporal, Behavioral, Emotional, Relationship, MemoryCallback, Cultural, Lifecycle) emit intents across ~15 notification kinds (personal record, streak save/risk, hydration, workout summary, sleep-debt, inactivity, weekly insight, monthly reflection, Eid celebration, achievement, trial-day…). Every candidate passes a **budget chain**: trial lane → 4h hard cap → tier daily budget → per-kind cooldown → quiet hours (9pm–8am) → iOS pending-limit → PersonaGuard. Messages are composed bilingually from `TemplateLibrary` and sanitized before delivery.

### 5.9 Chat UI
`CaptainViewModel` (`@MainActor`) holds `messages`, `isLoading`, streaming state, `quickReplies`, `effectiveTier`. A `CoachCognitiveState` drives the "thinking" animation (`idle / readingMessage / thinkingOnDevice / shapingReply / typing`). Replies stream token-by-token (≈24-char chunks, ~16ms) for a typewriter effect; structured cards (plan, Spotify, quick replies) append after completion. History persists to SwiftData per session. The live model window is **token-budget-aware** (≤24 msgs / ≤9000 chars); when a session grows past it, conversation compaction (§5.6) keeps the full context and a single soft **"طويت بداية محادثتنا بذاكرتي" / "earlier chat folded into memory"** marker (`ChatMessage.isSystemNote` — a frosted sand-accent capsule, UI-only, never persisted or sent to the model) appears once at the seam so the continuity is visible, not a silent gap. Voice subsystem under `Captain/Voice/` (Apple + MiniMax providers, router, consent, cache, keychain). Scoped to its own conversation context (Plan has a separate Captain conversation).

---

## 6. Feature catalog

> Tier legend: **Free** = all users · **Max** = `com.…aiqo.max` ($9.99/mo) · **Pro** = `…Intelligence.pro` ($19.99/mo) · **Trial** = 7-day Pro-equivalent.

### Home (`Features/Home/`) — Free
Daily dashboard: metrics grid (steps, calories, distance, stand, sleep, water, workouts via `MetricKind`), animated **Daily Aura** (24h activity visualization), interactive water bottle, **Spotify vibe card** (now-playing), streak badge, level-up celebration. `DJCaptainChatView` brings the DJ-mode Captain to Home. Key: `HomeView`, `HomeViewModel`, `DailyAuraView`, `WaterBottleView`, `VibeControlSheet`.

### Gym (`Features/Gym/`) — Free core, premium sub-features (~104 files)
The largest feature area. Subfolders:
- **Club/Plan** — workout-plan hub & lifecycle. `WorkoutPlanDashboard` (pinned plan, day-picker, weekly progress strip, templates, history), `CaptainPlanChatView` (conversational plan creation with intake chips: goal/duration/equipment/level + optional body photo), `PlanWorkoutRunner` (live execution: per-set tracking, rest timer, session timer, completion celebration). Plans persist as `AiQoDailyRecord` + `WorkoutTask` (exercises serialized as `AIQEX1‖name‖sets‖reps`). **Multi-week plans (>1 week) are Pro.**
- **Club/Body, Challenges, Impact, Components** — body photo/gratitude, challenge views, achievements/impact stats, shared nav rails.
- **OutdoorRun** — GPS running with a **3D satellite map** (`OutdoorRunSessionView`), cinematic chase camera, live stats (distance/time/pace/HR/calories/elevation), per-km milestones, phone↔Watch GPS fusion. `OutdoorRunSession` (state machine), `ActiveRunStore` (keeps tracking when screen is dismissed), `RunLocationManager` (CLLocation, best-for-navigation, jitter filters), `RunRecordStore` (last 50 runs as JSON, matches `HKWorkout`), `RunSummaryView` (interactive route replay + shareable 1080×1920 card).
- **QuestKit / Quests** — gamified daily/weekly quests (`QuestDefinition` with tiers + metrics: steps, plank, pushups, sleep, calories, distance, zone-2, mindfulness, kindness, streaks), `QuestEngine`, SwiftData stores (`PlayerStats`, `QuestRecord`, `QuestStage`), XP/aura rewards, completion celebrations.
- **Quests/VisionCoach** — camera + Vision pose estimation for push-up form, rep counting, audio coaching.
- **Quests/Learning** — see Learning Spark below.
- **LiveWorkoutSession + Zone 2** — real-time coaching with HR zones (`Zone2AuraState`: warmingUp/inZone2/tooFast/tooSlow), Karvonen bounds, audio coach with ambient ducking (`HandsFreeZone2Manager`, `AudioCoachManager`), Live Activity / Dynamic Island (`WorkoutLiveActivityManager`).
- **Guinness Encyclopedia** (`GuinnessEncyclopediaView`) — world-record categories (longest plank, fastest mile, most push-ups/hour, 100m) with a Coach chat that builds a personal challenge plan.
- **Cinematic Grind, Active Recovery, Spotify workout player** — themed workout modes & music.
- Exercise catalog: `GymExercise` (25+ exercises mapped to `HKWorkoutActivityType` + indoor/outdoor location). `WorkoutHistoryStore` keeps a rolling 30 workouts (14 folded into Captain memory).

### Captain (`Features/Captain/`) — **Max+**
See §5. The AI coach tab.

### Kitchen (`Features/Kitchen/`) — **Max**
Nutrition & meal planning: interactive fridge inventory, **camera "smart fridge" scan** → Gemini vision → meal plan, recipe/ingredient catalog, composite plate visualization, bundled `meals_data.json`. AI plan generation via the Captain pipeline. Key: `KitchenView`, `SmartFridgeScannerView`/`SmartFridgeCameraViewModel`, `KitchenPlanGenerationService`, `Meal`, `KitchenMealType`.

### MyVibe (`Features/MyVibe/`) — **Max**
Music/mood powered by **DJ Hamoudi**. `DailyVibeState` (energized/calm/focus/recovery), `VibeOrchestrator` (audio engine + transitions + Spotify overrides), `HamoudiDJ`, now-playing Spotify integration, ambient frequency datasets (Gamma/Theta/Serotonin flows).

### Sleep (`Features/Sleep/`) — Free basic; SmartWake premium
HealthKit sleep tracking, quality score ring, **SmartWake** (optimal wake window from 90-min cycles → save as AlarmKit alarm), `AppleIntelligenceSleepAgent` (**on-device** analysis), `SleepSessionObserver`. Sleep AI is always on-device for privacy.

### WeeklyReport (`Features/WeeklyReport/`) — Free
7-day vs prior-week summary with overall score (0–100), daily chart, metric cards, workout summary, motivational message. `ShareCardRenderer` produces a shareable image/Story.

### Smart Water Tracking (`Features/SmartWaterTracking/`) — Free (basic)
Intelligent hydration goals/reminders based on activity/climate/time; widget bridge; `HydrationSettings`, `HydrationDailyState`, `HydrationService`.

### Progress Photos (`Features/ProgressPhotos/`) — Free
Before/after body transformation tracking with weight + notes, side-by-side compare; `ProgressPhotoStore` (SwiftData).

### Challenges — Learning Spark (`Features/Challenges/LearningSpark/`) — Free
Educational quest: complete a free online course (Edraak, Coursera, Rwaq, Maharah, edX, YouTube) and submit a certificate. **On-device** verification (Vision OCR + text matcher + `HamoudiVerificationReasoner`, zero-cloud), URL whitelist, rate limiting, consent sheet. Awards XP (Stage 1 +1000, Stage 2 +2000).

### Legendary Challenges / Peaks (`Features/LegendaryChallenges/`) — **Pro (Peaks)**
Multi-week (4–12) personal-record projects with weekly checkpoints, daily tasks, HR-reserve assessments, completion badges. This is the product surface marketed as **"Peaks / قِمم"** (paywall source `peaksGate`). `LegendaryProject`, `WeeklyCheckpoint`, `RecordProjectManager`.

### Tribe / Arena / Battle (`Tribe/` + `Features/Tribe/`) — Free (view); **Battle = Max**
Social leaderboard with 3 tabs (Global, Arena, Tribe). Live ranks via Supabase Realtime (Emara/Arena). Competitive "Battle" surfaces are Max (paywall source `battleGate`). Profile privacy (public/private) controls visibility. Note: `TRIBE_BACKEND_ENABLED` / `TRIBE_SUBSCRIPTION_GATE_ENABLED` flags gate rollout.

### Profile / Settings (`Features/Profile/`) — Free
Avatar, bio metrics (age/height/weight from HealthKit), level/XP, privacy toggle, links to Weekly Report / Progress Photos / paywall, language & consent settings.

### Onboarding (`Features/Onboarding/`) — Free
Language selection, health screening, **historical HealthKit bulk import** (`HistoricalHealthSyncEngine`), AI-consent + medical-disclaimer screens, points/level explainer, **skippable** subscription intro.

### Compliance & Data Export (`Features/Compliance/`, `Features/DataExport/`) — Free
AI data-use disclosure, voice consent, body-photo consent, medical disclaimer, health-source transparency; GDPR-style export to CSV/JSON/PDF.

### Cardio (`Features/Cardio/`) — Free
`ZoneCoachingVoiceService` — TTS heart-rate-zone coaching (Z1–Z5).

### Widgets & Watch
iOS home-screen widget (`AiQoWidget`), Watch app (`AiQoWatch`) + Watch widget — live workout metrics, lock-screen/Dynamic Island Live Activities, hydration/quick-action surfaces. `PhoneConnectivityManager` / `WatchConnectivityService` sync workouts via `WatchConnectivity`.

---

## 7. Data, backend & services

### 7.1 SwiftData models (primary persistence)
`AiQoDailyRecord` (unique by date; steps/calories/water targets + `captainDailySuggestion`; cascade to `WorkoutTask`), `WorkoutTask` (title, isCompleted), `PlayerStats`, `QuestRecord`, `QuestStage`, `ProgressPhotoEntry`, and the Captain memory models (`SemanticFact`, `EpisodicEntry`, `EmotionalMemory`, `ProceduralPattern`, `Relationship`, `LearnedDirective`, `CaptainMemory`, schema V1–V5). Arena models: `ArenaTribe`, `ArenaTribeMember`, `ArenaWeeklyChallenge`, `ArenaTribeParticipation`, `ArenaHallOfFameEntry`.

### 7.2 Other persistence
- **UserDefaults:** settings, onboarding flags, `aiqo.purchases.currentTier`, `aiqo.app.language`, push token, captain calling name, memory-enabled flag.
- **Keychain:** Spotify tokens, MiniMax API key (per-user, cleared on sign-out), trial start date (mirrored), voice audio profile.
- **Files:** crash log (`CrashReports/crash_log.jsonl`, max 50), voice cache, audit log (`brain_audit.log.json`).

### 7.3 Supabase
Client in `Services/SupabaseService.swift` (URL/anon key from `K.Supabase`, resolved from Info.plist/env). **Auth:** Sign in with Apple / Google (id-token), JWT session. **Tables referenced:** `profiles` (incl. `device_token`, `is_private`), `arena_tribes`, `arena_tribe_members`, `arena_tribe_participations`, `arena_weekly_challenges`, `arena_hall_of_fame_entries`, `quest_wins`. **Edge Functions** (`supabase/functions/`):
- `captain-chat` — Gemini proxy (model whitelist `gemini-2.5-flash`, `gemini-3-flash-preview`; JWT-authed; 256KB cap; secret `GEMINI_API_KEY`).
- `captain-voice` — MiniMax TTS proxy (model whitelist; 16KB cap; secret `MINIMAX_API_KEY`).
- `validate-receipt` — server-side StoreKit receipt validation.
Shared `_shared/cors.ts`, `_shared/auth.ts`.

### 7.4 AI/LLM details
- **Gemini** base `https://generativelanguage.googleapis.com/v1beta/models`; models `gemini-2.5-flash` (default) / `gemini-3-flash-preview` (Pro + memory extraction). `URLSession` (request 35s / resource 40s timeouts). Tracks `finishReason: "MAX_TOKENS"`.
- **MiniMax TTS** `https://api.minimax.io/v1/t2a_v2`; 8 model variants (speech-2.8/2.6/02/01 hd/turbo).
- **Embeddings:** Apple `NLEmbedding`, **on-device only** (Arabic 0x0600–0x06FF + English), cosine similarity, ~500-entry cache.
- **Three-tier brain fallback:** CloudBrain → LocalBrain → persona/offline.

### 7.5 HealthKit
Read: heartRate, activeEnergyBurned, distanceWalking/Running + cycling, stepCount, bodyMass, bodyFatPercentage, leanBodyMass, sleepAnalysis, ActivitySummary. Write: workoutType. `HealthKitManager` (singleton, observer query throttled ~60s). Captain health snapshots are bucketed (steps by 50, calories by 10) and time-boxed (2s/query) before any cloud use.

### 7.6 Location, notifications, analytics, crash
- **Location:** `RunLocationManager` (CoreLocation, `.fitness`, accuracy gate 50m, step gate 1.5–150m, elevation noise gate 1m, smoothed course).
- **Notifications:** `NotificationService` + engines (Smart, MorningHabit, CaptainReminderScheduler, DirectiveNotificationScheduler, Inactivity, Alarm, PremiumExpiry); categories with action buttons; deep-link routing; APNs device token synced to `profiles.device_token`.
- **Analytics:** `AnalyticsService` (multi-provider; super-properties: device/os/app version, locale, timezone, user_id).
- **Crash:** `CrashReporter` (local JSONL + signal/exception handlers) mirrored to Firebase Crashlytics via privacy-sanitized `CrashReportingService`.

### 7.7 Background tasks
`aiqo.notifications.refresh`, `aiqo.notifications.inactivity-check`, `aiqo.brain.nightly` (nightly Captain consolidation + trigger evaluation). Orchestrators: MorningHabit, SleepSessionObserver, TrialJourney, AIWorkoutSummaryService.

---

## 8. Monetization & subscription tiers

### 8.1 Tiers (`Core/Purchases/SubscriptionTier.swift`)
**`enum SubscriptionTier: Int` — raw values are persisted; never renumber, rename only:**
| Case | Raw | Display | Price | Notes |
|---|---|---|---|---|
| `.none` | `0` | — | Free | Base tier |
| `.max` | `1` | **AiQo Max** | ~$9.99/mo | Captain + premium features |
| `.trial` | `2` | تجربة مجانية | — | 7-day, **Pro-equivalent** access |
| `.pro` | `3` | **AiQo Intelligence Pro** | ~$19.99/mo | Everything |

Ranking: `.none(0) < .max(1) ≤ .trial/.pro(2)`. `effectiveAccessTier`: `.trial → .pro`.

### 8.2 Tier-scaled capacity (verified, `SubscriptionTier`)
| Capacity | none | max | trial/pro |
|---|---|---|---|
| Memory fact limit (user-visible) | 100 | 500 | 1000 |
| Daily notification budget | 2 | 4 | 7 |
| Memory retrieval depth | 5 | 10 | 25 |
| Pattern-mining window (days) | 14 | 14 | 56 |
| Gemini context budget (bytes) | 2,000 | 8,000 | 32,000 |

> The Captain's `TierGate` enforces additional **hard ceilings** raised in v1.0.5 (e.g. Pro semantic-fact ceiling → 1200, retrieval depth → 40; Max retrieval depth → 18). When exact numbers matter, read `TierGate.swift` + `SubscriptionTier.swift` — they are the source of truth.

### 8.3 Feature gating (`TierGate`, `Brain/00_Foundation/TierGate.swift`)
`TierGate.shared.canAccess(_ feature:)` is the single gate.
- **All tiers (incl. free):** `basicLifeNotifications` (water/streak/sleep/workout/weekly reminders — no AI reasoning).
- **Max+ (max, trial, pro):** `captainChat`, `captainMemory`, `captainNotifications`, `captainDirectives`.
- **Pro only:** `multiWeekPlan(weeks>1)`, `weeklyInsightsNarrative`, `monthlyReflection`, `photoAnalysis`, `premiumVoice` (MiniMax), `advancedCulturalAwareness`.
- **Product→tier mapping** (marketing): Captain, Kitchen, MyVibe, Battle = **Max**; Peaks (Legendary Challenges) = **Pro**; multi-week plans / photo analysis / premium voice = **Pro**.

### 8.4 Paywall
`UI/Purchases/PaywallView.swift` (shows Max + Pro, RTL/LTR, restore + legal). `PaywallSource` enum tracks origin: `manual, featureGate, legendaryChallenges, day6Preview, trialEnded, tribeGate, captainGate, kitchenGate, myVibeGate, battleGate, peaksGate`. **Skippable** at onboarding and on trial-end (drops to free); feature gates dismiss without unlocking.

### 8.5 Purchases & trial (StoreKit 2)
`PurchaseManager` (observes `Transaction.updates`, loads products with retry, schedules expiry notifications) → `ReceiptValidator` (Supabase `validate-receipt`) → `EntitlementStore` (persists product + expiry, computes tier) → `TierGate` reads UserDefaults immediately. `FreeTrialManager`: 7-day trial, start date in UserDefaults + Keychain, `isTrialActiveSnapshot` readable from any context; captures real Apple intro-offer start.

> ⚠️ **Product IDs contain intentional, immutable typos** (e.g. `mraad5000` vs `mraad500`, capital `I` in `Intelligence`). They are permanent in App Store Connect — **never "fix" them**; it would break StoreKit resolution. Canonical list lives in `Core/Purchases/SubscriptionProductIDs.swift` (current + legacy IDs retained for back-compat).

---

## 9. Localization & internationalization
- **Languages:** Arabic (`ar`, default, RTL) + English (`en`, LTR). ~3,072 string keys each in `Resources/{ar,en}.lproj/Localizable.strings` (+ `InfoPlist.strings` for permission prompts).
- **Storage:** `AppSettingsStore.appLanguage` ↔ UserDefaults `aiqo.app.language` (`"ar"`/`"en"`), default Arabic.
- **RTL:** views set `.environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)`. Feature-local `L10n` helpers (Kitchen, Gym) and `L10n.t("key")`.
- **Dialect:** UI strings are clear MSA-leaning Arabic; the **Captain speaks Iraqi dialect** (a product rule, not a localization string).

---

## 10. Configuration, capabilities & feature flags

### 10.1 Info.plist / capabilities
- **Background modes:** audio, remote-notification, fetch, processing, location.
- **BGTask IDs:** `aiqo.notifications.refresh`, `aiqo.notifications.inactivity-check`, `aiqo.brain.nightly`.
- **URL schemes:** `aiqo`, `aiqo-spotify`.
- **Siri / NSUserActivityTypes:** startWalk, startRun, startHIIT, openCaptain, todaySummary, logWater, openKitchen, weeklyReport.
- **Entitlements (`AiQo.entitlements`):** push (`aps-environment`), Sign in with Apple, HealthKit (+ background delivery), Siri, App Groups `group.com.aiqo.kernel2` & `group.aiqo`.
- **Usage strings:** location (outdoor run, background), AlarmKit (SmartWake). PhotosPicker is out-of-process (no photo-library usage string needed). `PrivacyInfo.xcprivacy` declares photo data type with `AppFunctionality`.
- **Secrets** injected from `Secrets.xcconfig` → Info.plist: `CAPTAIN_API_KEY`, `CAPTAIN_VOICE_*`, `COACH_BRAIN_LLM_API_KEY`, `SPOTIFY_CLIENT_ID`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, proxy flags.

### 10.2 Feature flags (`Core/Config/AiQoFeatureFlags.swift`, read from Info.plist)
**Default ON:** `MEMORY_V4_ENABLED`, `NOTIFICATION_BRAIN_ENABLED`, `CAPTAIN_BRAIN_V2_ENABLED`, `CRISIS_DETECTOR_ENABLED`, `AIQO_CHAT_V1_1_ENABLED`, `LEARNING_CHALLENGE_V2_ENABLED`, `LEARNING_VERIFICATION_ON_DEVICE_ENABLED`, `SAFARI_VIEW_CONTROLLER_ENABLED`, `LEARNING_SPARK_STAGE2_ENABLED`, `SMART_WATER_TRACKING_ENABLED`, `CAPTAIN_VOICE_CLOUD_ENABLED`, `HIGH_FIDELITY_3D_ENABLED`.
**Default OFF:** `GEMINI_3_PREVIEW_ENABLED`, `HAMOUDI_BLEND_ENABLED`, `TRIBE_SUBSCRIPTION_GATE_ENABLED`, `PLANK_LADDER_CHALLENGE_ENABLED`, `USE_CLOUD_PROXY` (+ per-path `USE_CHAT_CLOUD_PROXY`, `USE_VOICE_CLOUD_PROXY`), `AIQO_DEV_UNLOCK_ALL`.
- `GEMINI_3_PREVIEW_ENABLED` — gates the `gemini-3-flash-preview` model app-wide via `GeminiModelPolicy`; OFF ⇒ everything uses stable `gemini-2.5-flash`. `CloudBrain` also auto-falls-back to `gemini-2.5-flash` if a preview call errors/times out.
- `HIGH_FIDELITY_3D_ENABLED` — gates full-fidelity 3D (OutdoorRun realistic-elevation map + cinematic chase camera, RealityKit avatar); `DevicePerformanceTier` additionally auto-downgrades on < ~5 GB-RAM devices and under thermal stress (`.serious`/`.critical`).
**Remote kill switches:** Supabase `remote_flags` table (`flag_name` rows), fetched by `RemoteFlags.shared.refresh()` (cached, fail-safe to enabled). Live-disable rows: `memory_v4_globally_disabled` (`MemoryV4Gate.isOn`), `notification_brain_globally_disabled` (`NotificationBrainGate.isOn`), `captain_brain_v2_globally_disabled` (`CaptainBrainV2Gate.isOn`). DevPanel + `DevOverride` can unlock features in DEBUG.

---

## 11. Privacy & compliance
Privacy is a first-class product value ("بياناتك ملكك"):
- **Sanitize-before-cloud:** `PrivacySanitizer` redacts emails/phones/UUIDs/IPs, normalizes names to "User," truncates to last ~4 messages, buckets health numbers — before any Gemini/MiniMax call.
- **On-device guarantees:** sleep analysis, memory embeddings, Learning-Spark certificate OCR/verification, directive parsing — never leave the device.
- **Per-purpose consent** (Apple 5.1.2(II)): independent classes for AI Data, Captain Voice, and **Body Photo** (`BodyPhotoConsent`, versioned UserDefaults keys) with grant/revoke + timestamps.
- **Body/meal photos:** downsized, JPEG re-encoded, **EXIF/GPS stripped** (`sanitizeKitchenImageData`), sent once to Gemini, never written to disk or stored on AiQo servers.
- **Audit logging:** `AuditLogger` records every cloud call (destination, tier, prompt/response bytes, latency, consent, purpose, outcome) to `brain_audit.log.json`.
- **Wellbeing:** `CrisisDetector` + `SafetyNet` + `ProfessionalReferral` provide bilingual crisis support paths (passive, consent-respecting).

---

## 12. Growth & content strategy
> Current strategy = **`AiQo_Hamoudi_Strategy.md` (v2.0, "Persona Emergence")**. The older `AiQo_Growth_Strategy_May-Aug_2026.md` (v1, "Mohammed Raad comeback") is **obsolete** — do not use it.

**Thesis:** *We are not bringing back Mohammed Raad. We are birthing Hamoudi.* New accounts, new name, visual transformation, no explanation. The mystery is the marketing; brand fusion (Hamoudi the persona = Captain Hamoudi the app) means every piece of Hamoudi content is AiQo content.

**3-month goal (May 20 → Aug 20, 2026):** TikTok 0→150k, Instagram 0→80k, 35,000 downloads, 1,200 paid subs, **$14,000 MRR**. North-star metric = **MRR growth rate** (conversion > vanity followers).

**Phases:** Month 1 "Hamoudi Emerges" (build persona, test creative, ~5k followers / 150 subs) → Month 2 "Resonates" (scale winners + collabs, ~30k / 600 subs) → Month 3 "Lands" (breakout + annual tier, 150k+ / 1200+ subs). A possible "Reveal" documentary is **out of scope** for these 3 months.

**4 content pillars:** Building (40%) · Hamoudi × the Captain (30%) · Iraqi AI Manifesto (15%) · Lifestyle Atmospheric (15%). **Channels:** TikTok (discovery), Instagram (depth), YouTube (authority/SEO), X (tech audience), LinkedIn (B2B). **Paid:** Apple Search Ads (money engine) + TikTok Spark Ads (boost organic winners) + Meta retargeting; ~$5–8k over 3 months. **Handle target:** `@hamoudi.ai`.

**Marketing don'ts:** no buying followers/bots, no faking KPIs, no fake urgency/scarcity, no "Insha'Allah/MashaAllah" as decoration, Captain never speaks MSA, never confirm/deny the Mohammed link.

---

## 13. Version history (`CHANGELOG.md`)
- **Unreleased (`program/world-class-completion`, 2026-05-30)** — **Captain conversation compaction** (anti-hallucination for long chats): faithful rolling `ConversationDigest` (opening goal · user points · the Captain's own commitments · corrections) + a prompt grounding lock, delivered via a new `conversationState` request field; **fixed a latent bug** where session continuity never reached Gemini on the cloud path (sanitizeForCloud overwrote `workingMemorySummary`); token-budget live window; a subtle "folded into memory" chat marker; `ConversationCompactorTests`. Also a DEBUG `CaptainBrainV2Gate.testOverride` test seam. (see §5.2, §5.4, §5.6, §5.9, §14.13)
- **v1.0.5 (2026-05-12)** — **Directives** (layer 11, on-device, executed after every workout); bigger/sharper memory (Pro facts→1200, Max→500, retrieval 40/18, history 7→30, chat 200→400); **multi-day workout plans** + day-picker; optional **body photo** for tailored plans + dedicated consent surface; Plan "world-class" UI (PlanPalette mint·sand·lavender·lemon).
- **v1.0.2 (2026-04-20)** — Learning Spark Stage 2 (5-course picker, Edraak+Coursera), challenge XP (+1000 / +2000), on-device verification extended, celebration redesign.
- **v1.0.1 (2026-04-19)** — Crisis detection, proactive brain, regional safety resources.

> Build number has advanced over time (project currently `CURRENT_PROJECT_VERSION = 27` at marketing version `1.0.5`). Release branches `brain-refactor/*` and `release/*` may lag `main` and the active `program/world-class-completion` branch — a "missing Captain feature" is usually an unmerged branch, not a regression.

---

## 14. Invariants & gotchas (do-not-break)
1. **`SubscriptionTier` raw values are persisted** — `none=0, max=1, trial=2, pro=3`. Never renumber; rename only.
2. **Product IDs are immutable with intentional typos** — never "correct" `mraad5000`/capital-`I` Intelligence.
3. **Captain must speak Iraqi dialect** (never MSA in primary content) — it is the moat.
4. **Sleep AI is always on-device** — raw sleep stages never go to the cloud.
5. **Injury constraints are hard rules**, not suggestions — surfaced in the prompt and never filtered out.
6. **Active directives are mirrored into every prompt** and never filtered (unlike normal memories).
7. **Sanitize before cloud** — never send raw PII/health/photos to Gemini/MiniMax.
8. **Persona discipline** — no "Mohammed," no old-account references, no confirm/deny of the link (see §2.3).
9. **3 tabs only** (Home/Gym/Captain); Captain is Max-gated.
10. **Don't lower timeouts to "fix" UI freezes** — find the real CPU/render hog (root-cause, not band-aid).
11. **Ship at a premium/cinematic bar** — this is a flagship; MVP polish is not acceptable for hero features.
12. **Free tier by design:** memory is lexical-only and episodes are excluded — that's intentional, not a bug.
13. **Captain chat continuity rides `conversationState`, not `workingMemorySummary`** — `PrivacySanitizer.sanitizeForCloud` *rebuilds* `workingMemorySummary` from cloud-safe durable memories, so anything placed there is silently dropped on the cloud (main-chat) path. Session continuity / conversation compaction must use the dedicated `HybridBrainRequest.conversationState` field (rendered by `PromptComposer.layerConversationState`).

---

## 15. Glossary
- **AiQo** — the app; an Arabic-first Bio-Digital OS.
- **Captain Hamoudi / كابتن حمودي** — the in-app AI coach and the founder's public persona (same identity).
- **Brain** — the Captain's 12-layer cognitive engine, folders `00`–`11` (`Features/Captain/Brain/`).
- **Directive** — a user-taught standing rule the Captain executes forever (v1.0.5).
- **Bio-phase / circadian tone** — time-of-day awareness that shifts the Captain's tone/timing.
- **Peaks (قِمم)** — 4–12 week periodized record challenges (= Legendary Challenges; Pro).
- **Tribe / Arena / Battle** — the social leaderboard + competitive layer (Supabase Realtime).
- **Daily Aura** — Home's 24h animated activity visualization.
- **Aura / XP / Level** — gamification currencies (`PlayerStats`, `XPCalculator`, `LevelSystem`).
- **MyVibe / DJ Hamoudi** — music+mood feature (Max).
- **Learning Spark** — complete-a-course + on-device certificate verification quest.
- **TierGate** — the single subscription-feature gate. **EntitlementStore** — persisted purchase state.

---

## 16. Repo map (quick index)
```
AiQo/App/                          AppDelegate, SceneDelegate, AppFlowController, MainTabScreen, MainTabRouter, MealModels
AiQo/Core/Constants.swift          K.Supabase (url/anonKey/functionsURL)
AiQo/Core/AppSettingsStore.swift   AppLanguage, settings (UserDefaults)
AiQo/Core/Config/AiQoFeatureFlags  All feature flags
AiQo/Core/Purchases/               SubscriptionTier, SubscriptionProductIDs, EntitlementStore, PurchaseManager, ReceiptValidator
AiQo/Premium/FreeTrialManager      7-day trial logic
AiQo/Features/Captain/             Chat UI (CaptainScreen/ViewModel/ChatView), WorkoutPlanCard, CaptainMessageText, Voice/
AiQo/Features/Captain/Brain/       12 numbered layers 00_Foundation … 11_Directives
  …/04_Inference/CaptainModels     CaptainStructuredResponse, WorkoutPlan, WorkoutDay, Exercise, MealPlan, CaptainReminder, CaptainSavedMemory, SpotifyRecommendation
  …/04_Inference/PromptComposer    7-layer system prompt
  …/04_Inference/Services/         CloudBrain (Gemini), LocalBrain, HybridBrain, FallbackBrain, CaptainProxyConfig
  …/00_Foundation/TierGate         Feature gating
AiQo/Features/Gym/                 Club/Plan, OutdoorRun, QuestKit, Quests (VisionCoach, Learning), Guinness, GymExercise
AiQo/Features/Home/                HomeView, DailyAura, DJCaptainChatView
AiQo/Features/Kitchen/             meals_data.json, SmartFridge…, KitchenPlanGenerationService
AiQo/Features/Sleep/               SmartWake, AppleIntelligenceSleepAgent
AiQo/Features/WeeklyReport/        ShareCardRenderer
AiQo/Features/{MyVibe,SmartWaterTracking,ProgressPhotos,Challenges,LegendaryChallenges,Profile,Onboarding,Compliance,DataExport,Cardio}/
AiQo/Services/                     SupabaseService, Analytics, CrashReporting, Notifications, Location
AiQo/Resources/{ar,en}.lproj/      Localizable.strings; Resources/Specs/achievements_spec.json; Assets.xcassets
supabase/functions/                captain-chat, captain-voice, validate-receipt, _shared/
Root: CHANGELOG.md, AIQO_TECH_DEBT.md, AiQo_Hamoudi_Strategy.md (current), AiQo_Growth_Strategy_May-Aug_2026.md (obsolete)
```

---

*End of master blueprint. Keep this file authoritative and current; the repository code is the final truth when it diverges from this description.*
