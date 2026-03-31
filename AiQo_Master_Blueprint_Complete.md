# AiQo Master Blueprint — Complete Technical Architecture

> **Version:** 1.0 | **Generated:** 2026-03-29 | **Source of Truth** — extracted directly from codebase
>
> A developer with zero context can understand, maintain, and extend AiQo using only this document.

---

## Table of Contents

1. [App Identity & Philosophy](#1-app-identity--philosophy)
2. [Technical Architecture](#2-technical-architecture)
3. [The Hybrid Brain (AI Routing)](#3-the-hybrid-brain-ai-routing)
4. [Privacy Architecture](#4-privacy-architecture)
5. [Captain Hamoudi (AI Persona)](#5-captain-hamoudi-ai-persona)
6. [Feature Modules](#6-feature-modules)
7. [UI/UX Design System](#7-uiux-design-system)
8. [Data Models & State](#8-data-models--state)
9. [Monetization](#9-monetization)
10. [Additional Systems](#10-additional-systems)
11. [External Integrations](#11-external-integrations)
12. [Apple Compliance Checklist](#12-apple-compliance-checklist)
13. [Known Issues & Technical Debt](#13-known-issues--technical-debt)
14. [File Manifest](#14-file-manifest)

---

## 1. APP IDENTITY & PHILOSOPHY

### Core Identity

| Field | Value |
|-------|-------|
| **Name** | AiQo |
| **Bundle ID** | `com.mraad500.aiqo` |
| **Positioning** | Privacy-first AI wellness coach with Iraqi Arabic persona |
| **Core AI** | Captain Hamoudi — Iraqi coach & older brother figure |
| **Category** | Health & Fitness |
| **Target** | Arabic-speaking fitness enthusiasts (Iraq-first, Gulf region) |

### Core Principles

1. **Zero Digital Pollution** — Every token has purpose, no filler. 200-memory cap, 90-day cleanup, chat history trimmed at 200 messages.
2. **Privacy-First Hybrid Intelligence** — Sleep data stays on-device (Apple Intelligence). Cloud gets only sanitized, bucketed data. PII is regex-redacted before any API call.
3. **Iraqi Arabic Persona** — Captain Hamoudi speaks in Iraqi dialect (اللهجة العراقية). Banned phrases include generic AI filler like "بالتأكيد", "As an AI", "I'm happy to help".
4. **Circadian-Aware** — 5 bio-phases (awakening/energy/focus/recovery/zen) dynamically adjust Captain's tone based on time of day, sleep quality, and activity level.

### Bilingual Strategy

- **Arabic RTL-first** + English support
- Language selection on first launch (`LanguageSelectionView`)
- `LocalizationManager` manages runtime language switching
- `Bundle+Language.swift` swizzles `localizedString(forKey:)` for dynamic locale
- `AppSettingsStore.appLanguage` enum: `.arabic` / `.english`
- Layout direction set via `.environment(\.layoutDirection, currentDirection)` in `AppRootView`
- Notification posted: `.appLanguageDidChange`

---

## 2. TECHNICAL ARCHITECTURE

### Build Configuration

| Setting | Value |
|---------|-------|
| **iOS Deployment Target** | iOS 16.0+ |
| **Swift Version** | Swift 5.9+ |
| **Xcode Project** | `AiQo.xcodeproj` |
| **Build Config** | `Configuration/AiQo.xcconfig` → includes `Secrets.xcconfig` |
| **Explicit Modules** | Disabled (`SWIFT_ENABLE_EXPLICIT_MODULES = NO`) |

### SPM Dependencies

| Dependency | Purpose |
|------------|---------|
| **Supabase** (via `supabase-community/supabase-swift`) | Auth, Database, Edge Functions |
| **Auth** (Supabase module) | Sign in with Apple flow |

> No `Package.swift` or `Package.resolved` found — dependencies managed via Xcode SPM integration or xcconfig includes.

### Project Folder Structure

```
AiQo/
├── App/                    # Entry points: AppDelegate, SceneDelegate, MainTabRouter, Auth flow
├── Core/                   # Shared services: Memory, Voice, Colors, Settings, Purchases, Localization
│   ├── Localization/       # Bundle+Language, LocalizationManager
│   ├── Models/             # ActivityNotification, LevelStore, NotificationPreferences
│   ├── Purchases/          # EntitlementStore, PurchaseManager, ReceiptValidator, ProductIDs
│   └── Utilities/          # ConnectivityDebugProviding
├── DesignSystem/           # AiQoColors, AiQoTheme, AiQoTokens
│   ├── Components/         # AiQoCard, AiQoBottomCTA, AiQoPillSegment, etc.
│   └── Modifiers/          # AiQoPressEffect, AiQoShadow, AiQoSheetStyle
├── Features/
│   ├── Captain/            # AI brain: BrainOrchestrator, HybridBrainService, PrivacySanitizer
│   ├── DataExport/         # HealthDataExporter
│   ├── First screen/       # LegacyCalculationViewController
│   ├── Gym/                # Workouts, QuestKit, VisionCoach, Quests, Club
│   │   ├── Club/           # ClubRootView, Body, Plan, Impact, Challenges
│   │   ├── Models/         # GymExercise
│   │   ├── QuestKit/       # Quest engine, data sources, SwiftData models
│   │   ├── Quests/         # Challenge models, stores, views, VisionCoach
│   │   └── T/              # SpinWheel, WorkoutTheme, WheelTypes
│   ├── Home/               # DailyAura, SmartWake, Water, Sleep, Streak
│   ├── Kitchen/            # Meal planning, Smart Fridge, Nutrition tracker
│   ├── LegendaryChallenges/ # 16-week projects, World Record breaking
│   ├── MyVibe/             # Spotify integration, mood-based music
│   ├── Onboarding/         # FeatureIntro, HistoricalHealthSync, Walkthrough
│   ├── Profile/            # ProfileScreen, LevelCard
│   ├── ProgressPhotos/     # Photo store and gallery
│   ├── Tribe/              # TribeDesignSystem, TribeExperienceFlow, TribeView
│   └── WeeklyReport/       # Report model, view, ViewModel, ShareCardRenderer
├── Premium/                # AccessManager, FreeTrialManager, PremiumStore, PaywallView
├── Services/
│   ├── Analytics/          # AnalyticsEvent, AnalyticsService
│   ├── CrashReporting/     # CrashReporter
│   ├── Notifications/      # 10+ notification services
│   └── Permissions/HealthKit/ # HealthKitService, TodaySummary
├── Shared/                 # HealthKitManager, CoinManager, LevelSystem, WorkoutSync
├── Tribe/                  # Full Tribe module: Galaxy, Arena, Stores, Models, Views
│   ├── Arena/              # TribeArenaView
│   ├── Galaxy/             # 30+ Arena/Galaxy views and ViewModels
│   ├── Log/                # TribeLogView
│   ├── Models/             # TribeModels, TribeFeatureModels
│   ├── Preview/            # TribePreviewController/Data
│   ├── Repositories/       # TribeRepositories
│   ├── Stores/             # ArenaStore, GalaxyStore, TribeLogStore
│   └── Views/              # Leaderboard, AtomRing, HubScreen
├── UI/                     # Shared UI components: GlassCard, ErrorToast, OfflineBanner
└── watch/                  # ConnectivityDiagnosticsView
```

### Entry Point & Boot Sequence

```swift
@main struct AiQoApp: App
```

**Boot order in `init()`:**
1. `MemoryStore.shared.configure(container: captainContainer)` — Connect SwiftData
2. `RecordProjectManager.shared.configure(container: captainContainer)` — Legendary challenges
3. `MemoryStore.shared.removeStale()` — Clean 90-day-old memories
4. `HealthKitMemoryBridge.syncHealthDataToMemory()` — Async health→memory sync

**Boot order in `didFinishLaunchingWithOptions`:**
1. `PhoneConnectivityManager.shared` — WatchConnectivity
2. `UNUserNotificationCenter.current().delegate = self`
3. `CrashReporter.shared`
4. `NetworkMonitor.shared`
5. `AnalyticsService.shared.track(.appLaunched)`
6. `FreeTrialManager.shared.refreshState()`
7. `LocalizationManager.shared.applySavedLanguage()`
8. `NotificationService.shared.requestPermissions()`
9. `NotificationCategoryManager.shared.registerAllCategories()`
10. `NotificationIntelligenceManager.shared.registerBackgroundTasks()`
11. `PurchaseManager.shared.start()` — StoreKit 2
12. `application.registerForRemoteNotifications()`
13. `MorningHabitOrchestrator.shared.start()`
14. `SleepSessionObserver.shared.start()`
15. `AIWorkoutSummaryService.shared.startMonitoringWorkoutEnds()`
16. `scheduleAngelNotifications()` — if notifications enabled
17. `AiQoWorkoutShortcuts.updateAppShortcutParameters()` — iOS 16+
18. `SiriShortcutsManager.shared.donateAllShortcuts()`
19. `SmartNotificationScheduler.shared.scheduleSmartNotifications()`
20. `StreakManager.shared.checkStreakContinuity()`

### Two SwiftData ModelContainers

**Container 1: Captain Memory Store** (`captain_memory.store`)
| @Model | Purpose |
|--------|---------|
| `CaptainMemory` | Long-term memory facts (identity, goals, body, etc.) |
| `PersistentChatMessage` | Chat history persistence |
| `RecordProject` | Legendary challenge projects |
| `WeeklyLog` | Weekly review logs for legendary challenges |

**Container 2: Main App Store** (default)
| @Model | Purpose |
|--------|---------|
| `AiQoDailyRecord` | Daily health tracking snapshots |
| `WorkoutTask` | Workout task records |
| `ArenaTribe` | Tribe groups |
| `ArenaTribeMember` | Tribe member profiles |
| `ArenaWeeklyChallenge` | Weekly arena challenges |
| `ArenaTribeParticipation` | Challenge participation records |
| `ArenaEmirateLeaders` | Regional leaderboard |
| `ArenaHallOfFameEntry` | Hall of fame records |

### Auth Flow State Machine

```
languageSelection → login → profileSetup → legacy → featureIntro → main
```

**States** (from `AppFlowController.RootScreen`):
| State | View | UserDefaults Key |
|-------|------|-----------------|
| `languageSelection` | `LanguageSelectionView` | `didSelectLanguage` |
| `login` | `LoginScreenView` (Sign in with Apple) | `didShowFirstAuthScreen` |
| `profileSetup` | `ProfileSetupView` | `didCompleteDatingProfile` |
| `legacy` | `LegacyCalculationScreenView` | `didCompleteLegacyCalculation` |
| `featureIntro` | `FeatureIntroView` | `didCompleteFeatureIntro` |
| `main` | `MainTabScreen` | — |

**Resolution Logic** (`resolveCurrentScreen()`):
- Checks Supabase session + fallback: if user completed full onboarding but session expired, lets them through (Supabase refreshes token on next API call)
- Guards flow linearly through each stage

### Navigation

**MainTabRouter — 5 Tabs:**
| Index | Tab | Analytics Name |
|-------|-----|---------------|
| 0 | `.home` | "home" |
| 1 | `.gym` | "gym" |
| 2 | `.tribe` | "tribe" |
| 3 | `.kitchen` | "kitchen" (routes to home + notification) |
| 4 | `.captain` | "captain" |

> Kitchen tab (index 3) doesn't navigate directly — it navigates to `.home` and posts `Notification.Name.openKitchenFromHome`.

**DeepLinkRouter Routes:**
| Scheme | Host/Path | Destination |
|--------|-----------|-------------|
| `aiqo://` | `home` | Home tab |
| `aiqo://` | `captain` or `chat` | Captain chat |
| `aiqo://` | `gym` or `workout` | Gym tab |
| `aiqo://` | `tribe?invite=CODE` | Tribe tab + invite |
| `aiqo://` | `kitchen` | Kitchen |
| `aiqo://` | `settings` | Settings |
| `aiqo://` | `referral?code=CODE` | Apply referral |
| `aiqo://` | `premium` | Premium paywall |
| `https://aiqo.app/` | `tribe/join/CODE` | Tribe join |
| `https://aiqo.app/` | `refer/CODE` | Referral |

### Concurrency Model

- `BrainOrchestrator` — `Sendable` struct
- `PrivacySanitizer` — `Sendable` struct
- `CaptainPromptBuilder` — `Sendable` struct
- `HybridBrainService` — `Sendable` struct
- `LocalBrainService` — `Sendable` struct
- `CloudBrainService` — `Sendable` struct
- `SmartWakeEngine` — `Sendable` struct
- `MemoryStore` — `@MainActor @Observable`
- `CaptainContextBuilder` — `@MainActor`
- `AppFlowController` — `@MainActor`
- `MainTabRouter` — `@MainActor`
- `SiriShortcutsManager` — `@MainActor`

---

## 3. THE HYBRID BRAIN (AI ROUTING)

### BrainOrchestrator Routing Table

| ScreenContext | Route | Reasoning |
|---------------|-------|-----------|
| `.sleepAnalysis` | **LOCAL** | Privacy: raw sleep data never leaves device |
| `.gym` | **CLOUD** | Needs structured workout plan generation |
| `.kitchen` | **CLOUD** | Meal planning + image analysis (fridge photos) |
| `.peaks` | **CLOUD** | Challenge coaching requires broader context |
| `.myVibe` | **CLOUD** | Spotify recommendation generation |
| `.mainChat` | **CLOUD** | General coaching with full persona |

### Sleep Keyword Interception

The `BrainOrchestrator` intercepts sleep-related messages and reroutes them to `.sleepAnalysis` (LOCAL) even if they originate from `.mainChat`.

**Topic patterns (English):**
```regex
\b(?:sleep|slept|sleeping|sleep quality|deep sleep|rem|nap|last night)\b
```

**Topic patterns (Arabic):**
```regex
(?:نوم|نمت|نومي|نومتك|نومتـي|نومي)
(?:نوم البارحة|مرحلة النوم|مراحل النوم|النوم العميق|ريم)
```

**Data intent patterns (English):**
```regex
\b(?:analy[sz]e|analysis|how much|show me|read|track|score|data|metrics|stages?|healthkit)\b
\b(?:did i sleep well|how did i sleep|how much did i sleep)\b
```

**Data intent patterns (Arabic):**
```regex
(?:تحليل|حلل|شكد|قديش|بيانات|داتا|مراحل|اقرأ|قراية|سكرين|سكور|صحة|هيلث)
(?:تحليل نومي|بيانات نومي|شلون نمت|شكد نمت|اقرأ نومي|مراحل نومي)
```

Both a topic match AND a data intent match are required for rerouting.

### Fallback Chain

```
Cloud → Local (on cloud failure) → Aggregated-summary Cloud (for sleep when AI unavailable) → Localized fallback
```

1. **Cloud request** via `HybridBrainService` (Gemini API)
2. On cloud failure → `generateLocalReply()` (Apple Intelligence)
3. For sleep: if `AppleIntelligenceSleepAgentError.modelUnavailable` → sends **aggregated hours only** to cloud via `generateCloudSleepReply()`
4. Final fallback: `CaptainFallbackPolicy` provides canned localized responses

### Layer 1: On-Device Intelligence

**Apple Intelligence (FoundationModels framework):**
- `LocalBrainService` — Uses `SystemLanguageModel`, `LanguageModelSession`
- `LocalIntelligenceService` — Wraps Apple Intelligence for general queries
- `CaptainOnDeviceChatEngine` — On-device chat with JSON parsing
- `AppleIntelligenceSleepAgent` — Sleep-specific analysis agent

**HealthKit Signals Aggregated Locally:**
- Steps, calories, heart rate, HRV, resting HR, walking HR avg
- VO2Max, oxygen saturation, body mass, dietary water
- Sleep analysis (stages), activity summaries, workouts
- Stand time, distance walking/running, distance cycling

### Layer 2: Cloud Intelligence

**Pipeline:** `CloudBrainService` → `PrivacySanitizer` → `HybridBrainService` → Gemini API

**Configuration:**
| Setting | Value |
|---------|-------|
| Model | `gemini-3-flash-preview` |
| Base Endpoint | `https://generativelanguage.googleapis.com/v1beta/models` |
| API Key Source | `CAPTAIN_API_KEY` → `COACH_BRAIN_LLM_API_KEY` (Info.plist / env) |
| Max Output Tokens | 900 |
| Temperature | 0.7 |
| Timeout | 35 seconds |
| `CAPTAIN_ARABIC_API_URL` | Configured in Info.plist (currently `$(CAPTAIN_ARABIC_API_URL)`) |

**Message Windows:**
| Context | Limit |
|---------|-------|
| Cloud (sanitized) | 4 messages max |
| Local conversation | 20 recent messages |
| In-memory chat | 80 messages pre-flush |
| Persisted on disk | 200 messages max (trimmed) |
| Memory prompt context | 800 tokens (~30 memories) |
| Cloud-safe memory context | 400 tokens (~15 memories) |

---

## 4. PRIVACY ARCHITECTURE

### Privacy Layers

#### 1. Conversation Windowing
- Cloud receives only the **last 4 messages** (`maxConversationMessages = 4`)
- Local keeps 20 recent, 80 pre-flush

#### 2. PII Regex Redaction
Direct redaction rules applied before any cloud transmission:

| Pattern | Replacement |
|---------|-------------|
| Email addresses | `[REDACTED]` |
| Phone numbers (7+ digits) | `[REDACTED]` |
| UUIDs | `[REDACTED]` |
| Social handles (`@username`) | `User` |
| URLs (`https?://`) | `[REDACTED]` |
| Long digit sequences (10+) | `[REDACTED]` |
| IP addresses | `[REDACTED]` |
| Long hex strings (24+ chars) | `[REDACTED]` |

#### 3. Self-Identifying Phrase Replacement
- "my name is X" / "call me X" → "my name is User"
- "اسمي X" / "ناديني X" / "أنا X" → "اسمي User"
- Explicit profile fields (email, phone, DOB, height, weight, address) → `[REDACTED_PROFILE]`

#### 4. Name Normalization
- Known user name is replaced with `"User"` token in all cloud-bound text
- `replaceKnownUserName()` uses `NSRegularExpression.escapedPattern`

#### 5. Health Metric Bucketing
| Metric | Bucket Size | Maximum |
|--------|-------------|---------|
| Steps | 50 | 100,000 |
| Calories | 10 | 10,000 |
| Level | — | 100 (clamped) |
| Vibe | — | Set to `"General"` for cloud |

#### 6. UserProfileSummary for Cloud
- Not blanked entirely — populated with **cloud-safe memories only**
- Cloud-safe categories: `goal`, `preference`, `mood`, `injury`, `nutrition`, `insight`
- Categories excluded from cloud: `identity`, `body`, `workout_history`, `sleep`

#### 7. Image Sanitization
| Setting | Value |
|---------|-------|
| Max dimension | 1280px |
| JPEG compression | 0.78 quality |
| EXIF/GPS | **Stripped** — re-encoding fresh CGImage drops all source metadata |
| Context | Kitchen images only |

#### 8. Sleep Data Boundary
- Raw sleep data **never leaves device**
- Only aggregated hours sent to cloud when Apple Intelligence unavailable
- Cloud sleep prompt: `"حلل نومي.\nبيانات نومي:\n{aggregated summary}\nاكتب 3 جمل بس بالعراقي."`

#### 9. Data Minimization
- 200 memory cap (`MemoryStore.maxMemories`)
- 90-day cleanup for memories below 0.3 confidence
- 200 max persisted chat messages
- Chat sessions with only 1 message (welcome) excluded from history

---

## 5. CAPTAIN HAMOUDI (AI PERSONA)

### Identity

Captain Hamoudi is a **sharp, warm, emotionally intelligent Iraqi coach and older brother figure**. He speaks in Iraqi Arabic dialect with optional English. He is NOT a health dashboard — he never opens with stats.

### CaptainPromptBuilder 6-Layer Composition

#### Layer 1: Core Persona (`layerCorePersona`)
- Identity declaration + behavioral code
- 6 rules: respond to intent first, not a dashboard, be concise, specific coaching, natural humor, admit unknowns
- Language label: "Iraqi Arabic (اللهجة العراقية)" or "English"

#### Layer 2: Banned Phrases + Response Length (`CaptainPersonaBuilder`)
**Banned phrases (Arabic):**
- بالتأكيد, بكل سرور, كمساعد ذكاء اصطناعي, لا أستطيع
- يسعدني مساعدتك, هل يمكنني مساعدتك, كيف يمكنني مساعدتك اليوم, بصفتي نموذج لغوي

**Banned phrases (English):**
- As an AI, I'm happy to help, How can I assist you, Certainly!, Of course!, I'd be happy to

**Response length rules:**
- Simple question → 2-3 sentences
- Workout/meal plan → structured bullets
- Emotional support → 1 warm sentence + follow-up question
- Max 3 actionable points per response

#### Layer 3: Long-Term Memory (`layerLongTermMemory`)
- Injected from `MemoryStore.buildCloudSafeContext()` (for cloud) or `buildPromptContext()` (for local)
- Rule: use knowledge to personalize silently, never recite facts back

#### Layer 4: Bio-State (`layerBioState`)
- Steps, calories, vibe, level, sleep hours, heart rate, time of day, growth stage, tone hint, bio-phase
- Rule: NEVER list numbers unless user explicitly asks for health report

#### Layer 5: Circadian Tone Override (`layerCircadianTone`)

| Phase | Hours | English Directive | Arabic Directive |
|-------|-------|-------------------|-------------------|
| `awakening` | 5:00–9:59 | Gentle, clear, optimistic | هادئة وواضحة |
| `energy` | 10:00–13:59 | Sharp, direct, high-output | حادة ومباشرة |
| `focus` | 14:00–17:59 | Steady, precise, minimal | ثابتة ودقيقة |
| `recovery` | 18:00–20:59 | Warm, calm, encouraging | دافئة وهادئة |
| `zen` | 21:00–4:59 | Soft, philosophical, minimal | ناعمة وتأملية |

**Circadian overrides:**
- Sleep-deprived (<5.5h) + morning → `recovery` (not `awakening`)
- 8000+ steps at night → `recovery` (not `zen`)

#### Layer 6: Screen Context + Output Contract
- Context-specific behavior per screen (mainChat, gym, kitchen, sleepAnalysis, peaks, myVibe)
- JSON output schema: `{ message, quickReplies, workoutPlan, mealPlan, spotifyRecommendation }`
- Silence in structured fields is correct — don't generate plans user didn't ask for

### CaptainStructuredResponse Schema

```swift
struct CaptainStructuredResponse: Codable, Sendable {
    let message: String                          // Natural reply text
    let quickReplies: [String]?                  // 2-3 tappable chips, <25 chars each
    let workoutPlan: WorkoutPlan?                // null unless user asks for training
    let mealPlan: MealPlan?                      // null unless user asks for food
    let spotifyRecommendation: SpotifyRecommendation?  // null unless myVibe/music request
}

struct WorkoutPlan: Codable { let title: String; let exercises: [Exercise] }
struct Exercise: Codable { let name: String; let sets: Int; let repsOrDuration: String }
struct MealPlan: Codable { let meals: [Meal] }
struct Meal: Codable { let type: String; let description: String; let calories: Int }
struct SpotifyRecommendation: Codable { let vibeName: String; let description: String; let spotifyURI: String }
```

### Growth Stages (from `CaptainContextBuilder`)

| Stage | Levels | Title |
|-------|--------|-------|
| 1 | 1-5 | Foundation Awakening |
| 2 | 6-10 | Discipline Ritual |
| 3 | 11-15 | Comfort Zone Break |
| 4 | 16-20 | Momentum Forge |
| 5 | 21-25 | Identity Shift |
| 6 | 26-30 | Resilience Engine |
| 7 | 31-35 | Peak Focus |
| 8 | 36-40 | Command Presence |
| 9 | 41-45 | Legend Protocol |
| 10 | 46-50 | Transcendence Mode |

### Captain Memory System

**CaptainMemory @Model:**
```swift
@Model final class CaptainMemory {
    var id: UUID
    var category: String    // identity, goal, body, preference, mood, injury, nutrition, workout_history, sleep, insight, active_record_project
    @Attribute(.unique) var key: String
    var value: String
    var confidence: Double  // 0.0 - 1.0
    var source: String      // user_explicit, extracted, healthkit, inferred, llm_extracted
    var createdAt: Date
    var updatedAt: Date
    var accessCount: Int
}
```

**Memory Categories (11):**
1. `identity` — name, age
2. `goal` — fitness goals (تنشيف, تضخيم, etc.)
3. `body` — weight, height, fitness level
4. `preference` — preferred workout, diet, equipment, training days
5. `mood` — current emotional state
6. `injury` — knee, back, shoulder conditions
7. `nutrition` — diet preference, water intake
8. `workout_history` — workout feedback
9. `sleep` — sleep hours
10. `insight` — LLM-extracted workout feedback
11. `active_record_project` — legendary challenge project feedback

**MemoryStore:**
- Singleton `@MainActor @Observable`
- Max 200 memories
- 90-day cleanup for confidence < 0.3
- `buildPromptContext(maxTokens: 800)` — top 30 memories by confidence + recency
- `buildCloudSafeContext(maxTokens: 400)` — only cloud-safe categories, top 15
- Priority score: `confidence × recencyWeight` (24h=1.0, week=0.8, month=0.6, older=0.4)
- UserDefaults key: `captain_memory_enabled` (defaults true)

**MemoryExtractor:**
- **Rule-based extraction** — every message (weight, height, age, injury, goal, sleep, name — both Arabic and English regex)
- **LLM extraction** — every 3 messages via Gemini API with sanitized text
- LLM allowed keys: `user_name, goal, weight, height, age, injury, mood, preferred_workout, diet_preference, sleep_hours, fitness_level, workout_feedback, available_equipment, training_days, medical_condition, water_intake, record_project_feedback`

### Voice (ElevenLabs TTS)

**CaptainVoiceAPI Configuration:**
| Setting | Value |
|---------|-------|
| API URL | `https://api.elevenlabs.io/v1/text-to-speech` |
| Model | `eleven_multilingual_v2` |
| Stability | 0.34 |
| Similarity Boost | 0.88 |
| Style | 0.18 |
| Speaker Boost | `true` |
| Output Format | `mp3_44100_128` (MP3 44.1kHz 128kbps) |
| Timeout | 30 seconds |

**Configuration sources:** `CAPTAIN_VOICE_API_KEY`, `CAPTAIN_VOICE_VOICE_ID`, `CAPTAIN_VOICE_API_URL`, `CAPTAIN_VOICE_MODEL_ID` — from Info.plist / environment.

**CaptainVoiceCache** — caches synthesized audio for repeated phrases.

**CaptainVoiceService** — orchestrates TTS with fallback to `AVSpeechSynthesizer`.

---

## 6. FEATURE MODULES

### 6.1 HOME (Daily Aura)

**Files:** `HomeView.swift`, `HomeViewModel.swift`, `DailyAuraView.swift`, `DailyAuraViewModel.swift`, `DailyAuraModels.swift`, `DailyAuraPathData.swift`, `HomeStatCard.swift`, `MetricKind.swift`, `ActivityDataProviding.swift`

**DailyAura Arc System:**
- Concentric arc visualization of daily health metrics
- Inner ring: mint/steps
- Middle ring: calories
- Outer ring: combined activity
- Center orb with breathing animation
- 60-second HealthKit polling interval

**Additional Home Cards:**
- `SleepDetailCardView` — Sleep summary
- `SleepScoreRingView` — Sleep quality ring
- `SmartWakeCalculatorView` — Smart alarm setup
- `SpotifyVibeCard` — Current vibe/music
- `StreakBadgeView` — Streak display
- `WaterBottleView` / `WaterDetailSheetView` — Water tracking
- `AlarmSetupCardView` — Alarm configuration
- `DJCaptainChatView` — Mini captain chat
- `LevelUpCelebrationView` — Level milestone animation
- `VibeControlSheet` — Vibe mode controls

### 6.2 GYM (Al-Nadi) & PEAKS

**Core Files:** `GymViewController.swift`, `WorkoutSessionViewModel.swift`, `WorkoutSessionSheetView.swift`, `LiveWorkoutSession.swift`, `LiveMetricsHeader.swift`, `ExercisesView.swift`, `PhoneWorkoutSummaryView.swift`

**GymExercise Model:** Defines exercise types with HealthKit workout activity type mappings.

**QuestKit System:**
- `QuestKitModels.swift` — Quest types, sources, stages
- `QuestDefinitions.swift` — All quest definitions
- `QuestEngine.swift` — Core quest evaluation engine
- `QuestEvaluator.swift` — Evaluates quest completion
- `QuestDataSources.swift` — Data providers for quests
- `QuestProgressStore.swift` / `QuestSwiftDataStore.swift` — Persistence
- `QuestSwiftDataModels.swift` — SwiftData quest models

**Quest Views:** `QuestPushupChallengeView`, `QuestDebugView`, `QuestCameraPermissionGateView`

**Quests System:**
- `Challenge.swift` — Challenge model
- `ChallengeStage.swift` — Stage progression model
- `WinRecord.swift` — Victory records
- `HelpStrangersModels.swift` — Help strangers challenge models
- Stores: `QuestAchievementStore`, `QuestDailyStore`, `WinsStore`
- Views: `QuestsView`, `QuestCard`, `QuestDetailView`, `ChallengeCard`, `ChallengeDetailView`, `ChallengeRunView`, `ChallengeRewardSheet`, `QuestCompletionCelebration`

**VisionCoach:** Camera-based exercise form analysis
- `VisionCoachViewModel.swift` — Vision framework processing
- `VisionCoachView.swift` — Camera overlay UI
- `VisionCoachAudioFeedback.swift` — Audio cues for form correction

**Club System:**
- `ClubRootView.swift` — Main club container
- Body: `BodyView`, `GratitudeSessionView`, `WorkoutCategoriesView`
- Plan: `PlanView`, `WorkoutPlanFlowViews`
- Impact: `ImpactContainerView`, `ImpactSummaryView`, `ImpactAchievementsView`
- Challenges: `ChallengesView`

**Workout Features:**
- `WorkoutLiveActivityManager` — Live Activity integration
- `AudioCoachManager` — Audio coaching during workouts
- `HandsFreeZone2Manager` — Heart rate zone 2 hands-free mode
- `SpotifyWorkoutPlayerView` — Spotify integration during workouts
- `WatchConnectivityService` — Watch sync

### 6.3 KITCHEN (Alchemy Kitchen)

**Core Files:** `KitchenScreen.swift`, `KitchenView.swift`, `KitchenViewModel.swift`, `KitchenModels.swift`

**KitchenModels:** Meal types, nutrition data, ingredient models.

**KitchenLanguageRouter:**
- Routes to `arabicGPT` (cloud, Gemini) or `englishAppleIntelligence` (on-device) based on `AppSettingsStore.appLanguage`

**KitchenPlanGenerationService:**
- AI-powered meal plan generation
- Inputs: user goals, dietary preferences, available ingredients
- JSON output: structured meal plans
- 3/7-day normalization
- Deterministic fallbacks when AI unavailable

**NutritionTrackerView:** Daily macro tracking with color-coded nutrients.

**Smart Fridge:**
- `SmartFridgeScannerView` — Camera-based fridge scanning
- `SmartFridgeCameraViewModel` — Vision API processing
- `SmartFridgeCameraPreviewController` — Camera preview
- `SmartFridgeScannedItemRecord` — Scanned item records
- `FridgeInventoryView` — Inventory management
- `InteractiveFridgeView` — 3D fridge visualization

**Meal System:**
- `Meal.swift` — Core meal model
- `MealPlanView.swift` — Plan display
- `MealSectionView.swift` — Section layout
- `MealPlanGenerator.swift` — Generation logic
- `MealsRepository.swift` / `LocalMealsRepository.swift` — Persistence
- `KitchenPersistenceStore.swift` — Local storage

**Ingredients:**
- `IngredientCatalog.swift` — Master ingredient list
- `IngredientAssetCatalog.swift` / `IngredientAssetLibrary.swift` — Visual assets
- `IngredientDisplayItem.swift` / `IngredientKey.swift` — Display models

### 6.4 SLEEP & SPIRIT

**SmartWakeEngine:**

| Setting | Value |
|---------|-------|
| Cycle length | 90 minutes |
| Sleep onset delay | 14 minutes |
| Priority cycles | [6, 5, 4] |
| Supported cycles | [3, 4, 5, 6] |

**Two Modes:**
- `fromBedtime` — Given bedtime, calculates optimal wake times
- `fromWakeTime` — Given latest wake time + window, finds best wake times

**SmartWakeWindow options:** 10, 20, or 30 minutes

**Confidence Scoring:**
| Cycle Count | Base Score |
|-------------|------------|
| 6 cycles | 0.96 |
| 5 cycles | 0.87 |
| 4 cycles | 0.72 |
| 3 cycles | 0.46 |

**Penalties/Bonuses:**
- Sleep < 6h: -0.12
- Sleep > 9.5h: -0.06
- Cycles < 4: -0.08
- Within smart window: +0.04
- Fallback: -0.18

**Badges:** "الأفضل" (best), "متوازن" (balanced), "أخف" (lighter)

**GratitudeSessionView** — Gratitude journaling (in `Gym/Club/Body/`)

**MorningHabitOrchestrator** (`Services/Notifications/`):
- Ephemeral morning insights
- Auto-clean after delivery

### 6.5 TRIBE / ARENA (القبيلة)

**Feature Flags (Info.plist):**
| Flag | Value |
|------|-------|
| `TRIBE_BACKEND_ENABLED` | `"true"` |
| `TRIBE_FEATURE_VISIBLE` | `"true"` |
| `TRIBE_SUBSCRIPTION_GATE_ENABLED` | `"true"` |

**Tribe System:**
- `TribeStore.swift` — Core tribe state management
- `TribeModels.swift` / `TribeModuleModels.swift` — Data models
- `TribeRepositories.swift` — Supabase CRUD
- `GalaxyStore.swift` — Galaxy view state
- `ArenaStore.swift` — Arena challenge state
- `TribeLogStore.swift` — Activity log

**Galaxy View:**
- `GalaxyScreen.swift` / `GalaxyView.swift` — Main galaxy UI
- `GalaxyViewModel.swift` — Galaxy state management
- `GalaxyCanvasView.swift` / `ConstellationCanvasView.swift` — Star map rendering
- `GalaxyLayout.swift` — Layout calculations
- `GalaxyModels.swift` — Galaxy data models
- `GalaxyHUD.swift` — Heads-up display
- `GalaxyNodeCard.swift` — Node cards

**Arena System:**
- `ArenaScreen.swift` / `ArenaTabView.swift` — Arena navigation
- `ArenaViewModel.swift` / `EmaraArenaViewModel.swift` — State management
- `ArenaModels.swift` — Challenge models
- `ArenaQuickChallengesView.swift` — Quick challenge creation
- `ArenaChallengeDetailView.swift` — Challenge details
- `ArenaChallengeHistoryView.swift` — Past challenges
- `BattleLeaderboard.swift` / `BattleLeaderboardRow.swift` — Rankings
- `WeeklyChallengeCard.swift` — Weekly challenge card
- `CountdownTimerView.swift` — Challenge countdown

**Tribe Management:**
- `CreateTribeSheet.swift` — Create new tribe
- `JoinTribeSheet.swift` — Join via code
- `EditTribeNameSheet.swift` — Rename tribe
- `TribeInviteView.swift` / `InviteCardView.swift` — Invite sharing
- `TribeMemberRow.swift` / `TribeMembersList.swift` — Member list
- `TribeHeroCard.swift` — Hero display

**Leaderboard:**
- `TribeLeaderboardView.swift` — Leaderboard UI
- `EmirateLeadersBanner.swift` — Regional leaders
- `HallOfFameSection.swift` / `HallOfFameFullView.swift` — Hall of fame

**Arena SwiftData Models:**
- `ArenaTribe`
- `ArenaTribeMember`
- `ArenaWeeklyChallenge`
- `ArenaTribeParticipation`
- `ArenaEmirateLeaders`
- `ArenaHallOfFameEntry`

### 6.6 MY VIBE

**Files:** `MyVibeScreen.swift`, `MyVibeViewModel.swift`, `MyVibeSubviews.swift`, `DailyVibeState.swift`, `VibeOrchestrator.swift`

**Spotify Integration:**
- OAuth via `SpotifyVibeManager` (Core)
- URL scheme: `aiqo-spotify`
- Queried schemes: `spotify`, `instagram-stories`, `instagram`
- Cloud music recommendations via Captain's `spotifyRecommendation` field

**SpotifyRecommendation Fallbacks:**
| Signal Keywords | Vibe | Spotify Playlist |
|----------------|------|------------------|
| energy, boost, pump, gym, تمرين, طاقة | Energy Lift | `37i9dQZF1DX76Wlfdnj7AP` |
| focus, deep work, study, تركيز, دراسة | Deep Focus | `37i9dQZF1DWZeKCadgRdKQ` |
| (default) | Zen Mode | `37i9dQZF1DWZqd5JICZI0u` |

### 6.7 LEGENDARY CHALLENGES

**Files in `Features/LegendaryChallenges/`:**

**Models:**
- `LegendaryProject.swift` — 16-week project model
- `LegendaryRecord.swift` — Record tracking
- `RecordProject.swift` — SwiftData @Model for persistence
- `WeeklyLog.swift` — SwiftData @Model for weekly check-ins

**ViewModels:**
- `LegendaryChallengesViewModel.swift` — Main state management
- `RecordProjectManager.swift` — Project CRUD (configured with captain container)
- `HRRWorkoutManager.swift` — Heart Rate Recovery tracking

**Views:**
- `LegendaryChallengesSection.swift` — Section display
- `ProjectView.swift` — Project detail
- `RecordDetailView.swift` / `RecordProjectView.swift` — Record views
- `RecordCard.swift` — Card component
- `WeeklyReviewView.swift` / `WeeklyReviewResultView.swift` — Weekly reviews
- `FitnessAssessmentView.swift` — Initial assessment

---

## 7. UI/UX DESIGN SYSTEM

### Color Palette

**Brand Colors:**
| Token | Light Hex | RGB |
|-------|-----------|-----|
| `brandMint` / `mint` | `#C4F0DB` | (0.77, 0.94, 0.86) |
| `brandSand` / `sand` | `#F8D6A3` | (0.97, 0.84, 0.64) |
| `aiqoBeige` | `#FADEB3` | (0.98, 0.87, 0.70) |
| `aiqoLemon` / `lemon` | `#FFECB8` | (1.00, 0.93, 0.72) |
| `aiqoLav` / `lav` | `#F5E0FF` | (0.96, 0.88, 1.00) |
| `aiqoAccent` / `accent` | `#FFE68C` | (1.00, 0.90, 0.55) |

**AiQoColors (DesignSystem):**
| Token | Hex |
|-------|-----|
| `mint` | `#CDF4E4` |
| `beige` | `#F5D5A6` |

**AiQoTheme.Colors (Light / Dark):**
| Token | Light | Dark |
|-------|-------|------|
| `primaryBackground` | `#F5F7FB` | `#0B1016` |
| `surface` | `#FFFFFF` | `#121922` |
| `surfaceSecondary` | `#EEF2F7` | `#18212B` |
| `textPrimary` | `#0F1721` | `#F6F8FB` |
| `textSecondary` | `#5F6F80` | `#A3AFBC` |
| `accent` | `#5ECDB7` | `#8AE3D1` |
| `border` | black 8% | white 8% |
| `borderStrong` | black 12% | white 12% |
| `iconBackground` | `#F2F6FA` | `#1A2430` |
| `ctaGradientLeading` | `#7CE0D2` | `#90E6D6` |
| `ctaGradientTrailing` | `#A4C8FF` | `#C4D9FF` |

### Glassmorphism

**GlassCardView (UIKit):**
- Blur: `UIBlurEffect(style: .systemUltraThinMaterial)`
- Tint overlay: `color.withAlphaComponent(0.12)`
- Stroke: `UIColor.white.withAlphaComponent(0.2)`, 1pt border
- Corner radius: 22pt

### Typography (AiQoTheme.Typography)

| Scale | Style | Weight |
|-------|-------|--------|
| `screenTitle` | `.title2` | `.bold` |
| `sectionTitle` | `.headline` | `.semibold` |
| `cardTitle` | `.headline` | `.semibold` |
| `body` | `.subheadline` | Regular |
| `caption` | `.caption` | Regular |
| `cta` | `.headline` | `.semibold` |

All use `.rounded` design.

### Spacing Tokens (AiQoSpacing)

| Token | Value |
|-------|-------|
| `xs` | 8pt |
| `sm` | 12pt |
| `md` | 16pt |
| `lg` | 24pt |

### Corner Radii (AiQoRadius)

| Token | Value |
|-------|-------|
| `control` | 12pt |
| `card` | 16pt |
| `ctaContainer` | 24pt |
| GlassCard | 22pt |

### Minimum Tap Target

`AiQoMetrics.minimumTapTarget = 44pt`

### Core Components

| Component | File | Purpose |
|-----------|------|---------|
| `AiQoCard` | `DesignSystem/Components/AiQoCard.swift` | Standard card container |
| `AiQoBottomCTA` | `DesignSystem/Components/AiQoBottomCTA.swift` | Bottom action button |
| `AiQoPillSegment` | `DesignSystem/Components/AiQoPillSegment.swift` | Pill-shaped segmented control |
| `AiQoPlatformPicker` | `DesignSystem/Components/AiQoPlatformPicker.swift` | Platform-aware picker |
| `AiQoChoiceGrid` | `DesignSystem/Components/AiQoChoiceGrid.swift` | Grid selection component |
| `AiQoSkeletonView` | `DesignSystem/Components/AiQoSkeletonView.swift` | Loading skeleton |
| `AiQoProfileButton` | `UI/AiQoProfileButton.swift` | Profile avatar button |
| `AiQoScreenHeader` | `UI/AiQoScreenHeader.swift` | Screen header with navigation |
| `ErrorToastView` | `UI/ErrorToastView.swift` | Error toast notification |
| `OfflineBannerView` | `UI/OfflineBannerView.swift` | Offline status banner |
| `GlassCardView` | `UI/GlassCardView.swift` | Glassmorphism UIKit card |

### Modifiers

| Modifier | File | Purpose |
|----------|------|---------|
| `AiQoPressEffect` | `Modifiers/AiQoPressEffect.swift` | Press-down animation |
| `AiQoShadow` | `Modifiers/AiQoShadow.swift` | Standard shadow |
| `AiQoSheetStyle` | `Modifiers/AiQoSheetStyle.swift` | Sheet presentation style |

---

## 8. DATA MODELS & STATE

### SwiftData @Models

#### CaptainMemory
(See Section 5 for full property list)

#### PersistentChatMessage
```swift
@Model final class PersistentChatMessage {
    var messageID: UUID
    var text: String
    var isUser: Bool
    var timestamp: Date
    var spotifyRecommendationData: Data?  // JSON-encoded SpotifyRecommendation
    var sessionID: UUID
}
```

#### AiQoDailyRecord
```swift
@Model final class AiQoDailyRecord {
    // Daily health tracking snapshot
}
```

#### WorkoutTask
```swift
@Model final class WorkoutTask {
    // Workout task record
}
```

#### RecordProject / WeeklyLog
Legendary challenge SwiftData models in captain container.

#### Arena Models
`ArenaTribe`, `ArenaTribeMember`, `ArenaWeeklyChallenge`, `ArenaTribeParticipation`, `ArenaEmirateLeaders`, `ArenaHallOfFameEntry` — all in main container.

### Singleton Managers

| Manager | Persistence | Purpose |
|---------|------------|---------|
| `MemoryStore.shared` | SwiftData (captain container) | Captain's long-term memory |
| `StreakManager.shared` | UserDefaults | Daily activity streaks |
| `FreeTrialManager.shared` | UserDefaults + Keychain | 7-day free trial |
| `ReferralManager.shared` | UserDefaults | Referral code system |
| `AppSettingsStore.shared` | UserDefaults | App preferences |
| `UserProfileStore.shared` | UserDefaults | User profile data |
| `LevelStore.shared` | UserDefaults | XP and level tracking |
| `MainTabRouter.shared` | In-memory | Tab navigation |
| `AppFlowController.shared` | UserDefaults | Onboarding flow |
| `DeepLinkRouter.shared` | In-memory | Deep link routing |
| `SpotifyVibeManager.shared` | In-memory + OAuth | Spotify integration |
| `PhoneConnectivityManager.shared` | WatchConnectivity | Watch communication |
| `PurchaseManager.shared` | StoreKit 2 | IAP management |
| `NetworkMonitor.shared` | NWPathMonitor | Connectivity status |
| `CrashReporter.shared` | — | Crash reporting |
| `AnalyticsService.shared` | — | Event tracking |
| `NotificationService.shared` | UNUserNotificationCenter | Push notifications |

---

## 9. MONETIZATION

### Free Trial

| Setting | Value |
|---------|-------|
| Duration | 7 days |
| UserDefaults key | `aiqo.freeTrial.startDate` |
| Keychain service | `com.aiqo.trial` |
| Persistence | **Keychain** (survives reinstall) + UserDefaults (synced) |

**States:** `notStarted` → `active(daysRemaining: Int)` → `expired`

Trial starts automatically during onboarding (`finalizeOnboarding()` calls `FreeTrialManager.shared.startTrialIfNeeded()`).

### Referral System

| Setting | Value |
|---------|-------|
| Code format | 6 uppercase alphanumeric (no 0, O, 1, I, L) |
| Bonus per referral | 3 days |
| Maximum bonus | 30 days |
| Share URL | `https://aiqo.app/refer/{CODE}` |
| Self-referral | Blocked |

**Mechanism:** Referral extends trial by moving `startDate` backwards.

### Subscription Products

| Product ID | Type | Price | Duration |
|------------|------|-------|----------|
| `aiqo_nr_30d_individual_5_99` | Non-renewing | $5.99 | 30 days |
| `aiqo_nr_30d_family_10_00` | Non-renewing | $10.00 | 30 days |
| `aiqo_30d_individual_5_99` | Legacy | $5.99 | 30 days |
| `aiqo_30d_family_10_00` | Legacy | $10.00 | 30 days |

**StoreKit 2** managed by `PurchaseManager.shared.start()` at launch.

**Receipt Validation:** `ReceiptValidator` actor validates via Supabase edge function.

### Premium System

- `AccessManager.swift` — Entitlement gating
- `EntitlementProvider.swift` — Provider protocol
- `PremiumStore.swift` — Premium state management
- `PremiumPaywallView.swift` / `PaywallView.swift` — Purchase UI

---

## 10. ADDITIONAL SYSTEMS

### Weekly Reports

**Files:** `WeeklyReportModel.swift`, `WeeklyReportView.swift`, `WeeklyReportViewModel.swift`, `ShareCardRenderer.swift`

### Streak System

**Trigger:** StreakManager tracks daily completion.

**StreakManager:**
- `currentStreak`, `longestStreak`, `lastActiveDate`, `todayCompleted`
- `markTodayAsActive()` — Call when user hits daily goal
- `checkStreakContinuity()` — Called at app launch
- History: Last 90 days in UserDefaults as JSON-encoded `[Date]`
- `weeklyConsistency` — percentage of active days in last 7

**Motivation Messages:**
| Streak | Message |
|--------|---------|
| 0 | "ابدأ streak اليوم! 🌱" |
| 1 | "يوم واحد! البداية أحلى شي 💫" |
| 2-3 | "الزخم يبدأ! خلّيه مستمر 🔥" |
| 4-6 | "أسبوع كامل تقريباً! 💪" |
| 7-13 | "أسبوع+ كامل! أنت وحش 🏆" |
| 14-29 | "أسبوعين! هالالتزام أسطوري ⭐️" |
| 30-59 | "شهر كامل! ما يوقفك أحد 🚀" |
| 60-89 | "شهرين! أنت قدوة 👑" |
| 90-364 | "{N} يوم! هذا إنجاز تاريخي 🎖️" |
| 365+ | "سنة+! أنت أسطورة حية 🏅" |

### Siri Shortcuts (8 total)

| Activity Type | Title | Suggested Phrase |
|---------------|-------|-----------------|
| `com.aiqo.startWalk` | ابدأ تمرين مشي | ابدأ مشي |
| `com.aiqo.startRun` | ابدأ تمرين جري | ابدأ جري |
| `com.aiqo.startHIIT` | ابدأ تمرين HIIT | ابدأ تمرين |
| `com.aiqo.openCaptain` | تكلم مع كابتن حمّودي | كابتن حمودي |
| `com.aiqo.todaySummary` | ملخص اليوم | شنو تقدمي |
| `com.aiqo.logWater` | سجّل ماء | سجل ماء |
| `com.aiqo.openKitchen` | افتح المطبخ | افتح المطبخ |
| `com.aiqo.weeklyReport` | التقرير الأسبوعي | تقرير الأسبوع |

**App Shortcuts (iOS 16+):**
- Start running workout (English + Arabic phrases)
- Start walking workout (English + Arabic phrases)

### Smart Notifications

**Services:**
- `SmartNotificationScheduler` — Schedule-based notifications
- `SmartNotificationManager` — Intelligent notification management
- `NotificationIntelligenceManager` — Background task scheduling
- `ActivityNotificationEngine` — Activity-based angel number notifications
- `CaptainBackgroundNotificationComposer` — Captain-style notification text
- `InactivityTracker` — Tracks user inactivity periods
- `MorningHabitOrchestrator` — Morning routine notifications
- `SleepSessionObserver` — Sleep session monitoring
- `PremiumExpiryNotifier` — Premium expiry reminders
- `AlarmSchedulingService` — Alarm scheduling
- `NotificationCategoryManager` — Notification categories
- `NotificationRepository` — Notification storage

**Background Tasks (Info.plist):**
- `aiqo.captain.spiritual-whispers.refresh`
- `aiqo.captain.inactivity-check`

### Accessibility

- `AiQoAccessibility.swift` — Accessibility identifiers and helpers
- `AccessibilityHelpers.swift` — VoiceOver helpers
- Dynamic Type support
- Reduce Motion support
- Minimum 44pt tap targets (`AiQoMetrics.minimumTapTarget`)

### XP & Level System

**XPCalculator:** Calculates XP/coins from workout stats (steps, calories, heart rate, duration).

**LevelSystem.swift** / **LevelStore.swift** — Level progression tracking.

**CoinManager.swift** — Virtual currency management.

### Data Export

**HealthDataExporter.swift** — Export health data (PDF/CSV).

### Progress Photos

**ProgressPhotoStore.swift** / **ProgressPhotosView.swift** — Before/after photo tracking.

---

## 11. EXTERNAL INTEGRATIONS

### Supabase

| Component | Usage |
|-----------|-------|
| **Auth** | Sign in with Apple (`LoginViewController.swift`) |
| **Database** | Tribe data, Arena challenges, user profiles |
| **Edge Functions** | Receipt validation |
| **Realtime** | — |
| **URL** | `https://zidbsrepqpbucqzxnwgk.supabase.co` |
| **Functions URL** | `*.functions.supabase.co` (derived from base URL) |

**Services:** `SupabaseService.swift`, `SupabaseArenaService.swift`

### Google Gemini (AI)

| Setting | Value |
|---------|-------|
| **Endpoint** | `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent` |
| **Model** | `gemini-3-flash-preview` |
| **Key source** | `CAPTAIN_API_KEY` / `COACH_BRAIN_LLM_API_KEY` |
| **Max tokens** | 900 (chat), 200 (memory extraction) |
| **Temperature** | 0.7 (chat), 0.1 (memory extraction) |

### ElevenLabs (TTS)

| Setting | Value |
|---------|-------|
| **Endpoint** | `https://api.elevenlabs.io/v1/text-to-speech/{voiceID}` |
| **Model** | `eleven_multilingual_v2` |
| **Output** | `mp3_44100_128` |
| **Voice settings** | stability=0.34, similarity=0.88, style=0.18, speakerBoost=true |

### Spotify

| Setting | Value |
|---------|-------|
| **URL Scheme** | `aiqo-spotify` |
| **Client ID** | Via `$(SPOTIFY_CLIENT_ID)` in Secrets.xcconfig |
| **Queried schemes** | `spotify`, `instagram-stories`, `instagram` |

### HealthKit

**Read types:**
stepCount, activeEnergyBurned, distanceWalkingRunning, distanceCycling, heartRate, heartRateVariabilitySDNN, restingHeartRate, walkingHeartRateAverage, oxygenSaturation, vo2Max, bodyMass, dietaryWater, appleStandTime, sleepAnalysis, activitySummaryType, workoutType

**Write types:**
heartRate, heartRateVariabilitySDNN, restingHeartRate, vo2Max, distanceWalkingRunning, dietaryWater, bodyMass, workoutType

### Apple Intelligence (FoundationModels)

- `LocalBrainService` — System language model sessions
- `LocalIntelligenceService` — General on-device queries
- `AppleIntelligenceSleepAgent` — Sleep-specific analysis
- `CaptainOnDeviceChatEngine` — On-device chat

### WatchConnectivity

- `PhoneConnectivityManager.swift` (991 lines) — Full workout mirroring, command dispatch, HKWorkoutSession delegation
- `WatchConnectivityService.swift` — Watch sync service
- `ConnectivityDiagnosticsView.swift` — Debug view
- App Groups: `group.com.aiqo.kernel2`, `group.aiqo`

### FamilyControls / Screen Time

- `ProtectionModel.swift` — DeviceActivity monitoring with temporary unlock

---

## 12. APPLE COMPLIANCE CHECKLIST

### Entitlements (AiQo.entitlements)

| Entitlement | Value |
|-------------|-------|
| Push Notifications | `production` |
| Sign in with Apple | Yes |
| HealthKit | Yes, with background delivery |
| Siri | Yes |
| App Groups | `group.com.aiqo.kernel2`, `group.aiqo` |

### NSUsageDescription Strings (Info.plist)

| Key | Value |
|-----|-------|
| `NSAlarmKitUsageDescription` | "يستخدم AiQo صلاحية المنبه لحفظ وقت الاستيقاظ الذكي كمنبه على جهازك." |

> **Note:** Camera, photo library, and other permission strings may be in Localizable.strings or other plist files not fully enumerated here.

### Background Modes

- `audio` — Workout audio coaching
- `remote-notification` — Push notifications
- `fetch` — Background fetch for notification intelligence

### StoreKit 2 Compliance

- Non-renewing subscriptions (Individual $5.99, Family $10.00)
- StoreKit testing config: `AiQo_Test.storekit`
- Production config: `AiQo.storekit`
- `PurchaseManager` started at launch

### Sign in with Apple

- Implemented in `LoginViewController.swift` via Supabase Auth
- Required for apps that offer third-party sign-in

### Potential Compliance Notes

1. **API Key in Info.plist** — `CAPTAIN_API_KEY` is hardcoded in Info.plist. Should be moved to Secrets.xcconfig or server-side proxy.
2. **Supabase Anon Key** — Visible in Info.plist. This is expected for client-side Supabase but should be documented in security review.
3. **HealthKit Usage** — Extensive read/write types declared; must match App Store privacy questionnaire.
4. **FamilyControls** — Using DeviceActivity monitoring; requires appropriate entitlement and review.

---

## 13. KNOWN ISSUES & TECHNICAL DEBT

### Hardcoded Values

1. **API key in Info.plist** — `CAPTAIN_API_KEY` value `AIzaSyCQVkKbrEFIn91gQeF9FxF82tgAHso1ucI` is hardcoded in the plist file rather than only in Secrets.xcconfig
2. **Supabase anon key** — Full JWT visible in Info.plist
3. **Spiritual Whispers API key** — Empty string in Info.plist (`SPIRITUAL_WHISPERS_LLM_API_KEY`)

### File Naming Issues

- `WorkoutSessionScreen.swift.swift` — Double `.swift` extension in filename

### Architecture Notes

- Kitchen tab navigation is indirect: navigates to Home + posts notification `openKitchenFromHome`
- Two separate model containers could cause confusion; captain container uses custom path `captain_memory.store`
- `PhoneConnectivityManager.swift` is 991 lines — candidate for decomposition
- `DatingScreenViewController.swift` name is misleading — it's actually the profile setup view

### Feature Flags

| Flag | Status | Notes |
|------|--------|-------|
| `TRIBE_BACKEND_ENABLED` | `"true"` | Tribe backend active |
| `TRIBE_FEATURE_VISIBLE` | `"true"` | Tribe UI visible |
| `TRIBE_SUBSCRIPTION_GATE_ENABLED` | `"true"` | Tribe requires premium |

### Incomplete/Disabled Features

- `CAPTAIN_ARABIC_API_URL` — Set to `$(CAPTAIN_ARABIC_API_URL)` (unresolved variable)
- `SPIRITUAL_WHISPERS_LLM_API_KEY` — Empty string, feature may be incomplete

---

## 14. FILE MANIFEST

### App/

| File | Purpose | Key Types |
|------|---------|-----------|
| `App/AppDelegate.swift` | Entry point, boot sequence, Siri intents | `AiQoApp`, `AppDelegate`, `SiriWorkoutType`, `StartWorkoutIntent`, `AiQoWorkoutShortcuts` |
| `App/AppRootManager.swift` | Captain chat presentation state | `AppRootManager` |
| `App/AuthFlowUI.swift` | Auth/onboarding UI components | Auth theme colors, glass card components |
| `App/DatingScreenViewController.swift` | Profile setup (name, weight, height, gender) | `ProfileSetupView` |
| `App/LanguageSelectionView.swift` | First-launch language selection | `LanguageSelectionView` |
| `App/LoginViewController.swift` | Sign in with Apple | `LoginScreenView` |
| `App/MainTabRouter.swift` | 5-tab navigation | `MainTabRouter`, `Tab` enum |
| `App/MainTabScreen.swift` | Main tab bar view | `MainTabScreen` |
| `App/MealModels.swift` | Simple meal data models | `MealItem`, `MealCardData` |
| `App/SceneDelegate.swift` | Onboarding flow controller | `AppFlowController`, `RootScreen`, `AppRootView` |

### Core/

| File | Purpose | Key Types |
|------|---------|-----------|
| `Core/AiQoAccessibility.swift` | Accessibility identifiers | Accessibility constants |
| `Core/AiQoAudioManager.swift` | Audio session management | `AiQoAudioManager` |
| `Core/AppSettingsScreen.swift` | Settings UI | `AppSettingsScreen` |
| `Core/AppSettingsStore.swift` | App preferences persistence | `AppSettingsStore`, `AppLanguage` |
| `Core/ArabicNumberFormatter.swift` | Arabic numeral formatting | `ArabicNumberFormatter` |
| `Core/CaptainMemory.swift` | Memory SwiftData model | `CaptainMemory` @Model |
| `Core/CaptainMemorySettingsView.swift` | Memory settings UI | `CaptainMemorySettingsView` |
| `Core/CaptainVoiceAPI.swift` | ElevenLabs TTS API | `CaptainVoiceAPI` |
| `Core/CaptainVoiceCache.swift` | Voice audio cache | `CaptainVoiceCache` |
| `Core/CaptainVoiceService.swift` | Voice service orchestrator | `CaptainVoiceService` |
| `Core/Colors.swift` | Color definitions | `Colors`, Color extensions |
| `Core/Constants.swift` | Supabase config constants | `K.Supabase` |
| `Core/DailyGoals.swift` | Daily goal definitions | `DailyGoals` |
| `Core/DeveloperPanelView.swift` | Debug panel | `DeveloperPanelView` |
| `Core/HapticEngine.swift` | Haptic feedback | `HapticEngine` |
| `Core/HealthKitMemoryBridge.swift` | HealthKit → Memory sync | `HealthKitMemoryBridge` |
| `Core/MemoryExtractor.swift` | Extract memories from chat | `MemoryExtractor` |
| `Core/MemoryStore.swift` | Captain memory CRUD | `MemoryStore` |
| `Core/SiriShortcutsManager.swift` | Siri shortcut management | `SiriShortcutsManager` |
| `Core/SmartNotificationScheduler.swift` | Smart notification scheduling | `SmartNotificationScheduler` |
| `Core/SpotifyVibeManager.swift` | Spotify OAuth + playback | `SpotifyVibeManager` |
| `Core/StreakManager.swift` | Daily streak tracking | `StreakManager` |
| `Core/UserProfileStore.swift` | User profile persistence | `UserProfileStore` |
| `Core/VibeAudioEngine.swift` | Vibe audio engine | `VibeAudioEngine` |
| `Core/Purchases/EntitlementStore.swift` | Entitlement state | `EntitlementStore` |
| `Core/Purchases/PurchaseManager.swift` | StoreKit 2 management | `PurchaseManager` |
| `Core/Purchases/ReceiptValidator.swift` | Receipt validation | `ReceiptValidator` |
| `Core/Purchases/SubscriptionProductIDs.swift` | Product ID constants | `SubscriptionProductIDs` |

### Features/Captain/

| File | Purpose | Key Types |
|------|---------|-----------|
| `Captain/AiQoPromptManager.swift` | Prompt management | `AiQoPromptManager` |
| `Captain/AppleIntelligenceSleepAgent.swift` | On-device sleep analysis | `AppleIntelligenceSleepAgent` |
| `Captain/BrainOrchestrator.swift` | AI routing: local vs cloud | `BrainOrchestrator` |
| `Captain/CaptainChatView.swift` | Chat UI | `CaptainChatView` |
| `Captain/CaptainContextBuilder.swift` | Bio-state context builder | `CaptainContextBuilder`, `BioTimePhase`, `CaptainContextData` |
| `Captain/CaptainFallbackPolicy.swift` | Fallback responses | `CaptainFallbackPolicy` |
| `Captain/CaptainIntelligenceManager.swift` | Intelligence orchestration | `CaptainIntelligenceManager` |
| `Captain/CaptainModels.swift` | Data models | `PersistentChatMessage`, `CaptainStructuredResponse`, `WorkoutPlan`, `MealPlan`, `SpotifyRecommendation` |
| `Captain/CaptainNotificationRouting.swift` | Notification → Captain routing | `CaptainNotificationHandler`, `CaptainNavigationHelper` |
| `Captain/CaptainOnDeviceChatEngine.swift` | On-device chat engine | `CaptainOnDeviceChatEngine` |
| `Captain/CaptainPersonaBuilder.swift` | Persona rules | `CaptainPersonaBuilder` |
| `Captain/CaptainPromptBuilder.swift` | 6-layer system prompt | `CaptainPromptBuilder` |
| `Captain/CaptainScreen.swift` | Captain screen container | `CaptainScreen` |
| `Captain/CaptainViewModel.swift` | Main Captain state | `CaptainViewModel` |
| `Captain/ChatHistoryView.swift` | Chat history browser | `ChatHistoryView` |
| `Captain/CloudBrainService.swift` | Cloud API service | `CloudBrainService` |
| `Captain/CoachBrainMiddleware.swift` | Coach brain middleware | `CoachBrainMiddleware` |
| `Captain/CoachBrainTranslationConfig.swift` | Translation config | `CoachBrainTranslationConfig` |
| `Captain/HybridBrainService.swift` | Gemini API integration | `HybridBrainService`, `HybridBrainRequest`, `HybridBrainServiceReply` |
| `Captain/LLMJSONParser.swift` | Robust JSON parser | `LLMJSONParser` |
| `Captain/LocalBrainService.swift` | Apple Intelligence service | `LocalBrainService` |
| `Captain/LocalIntelligenceService.swift` | On-device AI wrapper | `LocalIntelligenceService` |
| `Captain/MessageBubble.swift` | Chat bubble UI | `MessageBubble` |
| `Captain/PrivacySanitizer.swift` | PII redaction + sanitization | `PrivacySanitizer` |
| `Captain/PromptRouter.swift` | Screen-aware prompt routing | `PromptRouter` |
| `Captain/ScreenContext.swift` | Screen context enum | `ScreenContext` |

### Services/

| File | Purpose | Key Types |
|------|---------|-----------|
| `Services/AiQoError.swift` | App error types | `AiQoError` |
| `Services/DeepLinkRouter.swift` | URL routing | `DeepLinkRouter`, `DeepLink` |
| `Services/NetworkMonitor.swift` | Connectivity monitoring | `NetworkMonitor` |
| `Services/NotificationType.swift` | Notification type enum | `NotificationType` |
| `Services/ReferralManager.swift` | Referral system | `ReferralManager` |
| `Services/SupabaseArenaService.swift` | Arena API | `SupabaseArenaService` |
| `Services/SupabaseService.swift` | Core Supabase client | `SupabaseService` |
| `Services/Analytics/AnalyticsEvent.swift` | Event definitions | `AnalyticsEvent` |
| `Services/Analytics/AnalyticsService.swift` | Analytics tracking | `AnalyticsService` |
| `Services/CrashReporting/CrashReporter.swift` | Crash reporting | `CrashReporter` |
| `Services/Permissions/HealthKit/HealthKitService.swift` | HealthKit queries | `HealthKitService` |
| `Services/Permissions/HealthKit/TodaySummary.swift` | Today's health summary | `TodaySummary` |

### Premium/

| File | Purpose | Key Types |
|------|---------|-----------|
| `Premium/AccessManager.swift` | Entitlement gating | `AccessManager` |
| `Premium/EntitlementProvider.swift` | Provider protocol | `EntitlementProvider` |
| `Premium/FreeTrialManager.swift` | 7-day trial management | `FreeTrialManager`, `TrialState` |
| `Premium/PremiumPaywallView.swift` | Paywall UI | `PremiumPaywallView` |
| `Premium/PremiumStore.swift` | Premium state | `PremiumStore` |

### Root Files

| File | Purpose | Key Types |
|------|---------|-----------|
| `AiQoActivityNames.swift` | DeviceActivity extensions | Activity name constants |
| `AppGroupKeys.swift` | App group IDs | `AppGroupKeys` |
| `NeuralMemory.swift` | Daily record + workout task models | `AiQoDailyRecord`, `WorkoutTask` |
| `PhoneConnectivityManager.swift` | WatchConnectivity (991 lines) | `PhoneConnectivityManager` |
| `ProtectionModel.swift` | Screen Time/FamilyControls | `ProtectionModel` |
| `XPCalculator.swift` | XP/coin calculations | `XPCalculator` |

---

*End of AiQo Master Blueprint. This document was generated by reading every Swift file, plist, entitlement, xcconfig, and StoreKit configuration in the project.*
