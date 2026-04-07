# AiQo Master Blueprint 9

> **Version:** 9.0 | **Generated:** 2026-04-03 | **Source of Truth** — extracted directly from codebase
>
> Scan scope: 372 iOS Swift files + 9 Widget files = 381 files scanned.
> Every prose claim below is anchored to a scanned source file and line number.

---

## Table of Contents

1. [App Identity & Philosophy](#section-1--app-identity--philosophy)
2. [Tech Stack & Dependencies](#section-2--tech-stack--dependencies)
3. [Project Structure & Boot Sequence](#section-3--project-structure--boot-sequence)
4. [The Hybrid Brain (AI Routing)](#section-4--the-hybrid-brain-ai-routing)
5. [Privacy Architecture](#section-5--privacy-architecture)
6. [Captain Hamoudi (AI Persona)](#section-6--captain-hamoudi-ai-persona)
7. [Feature Modules](#section-7--feature-modules)
8. [UI/UX Design System](#section-8--uiux-design-system)
9. [Data Models & State Management](#section-9--data-models--state-management)
10. [Monetization & Subscription](#section-10--monetization--subscription)
11. [Notification Engine (Dual-Persona)](#section-11--notification-engine-dual-persona)
12. [External Integrations](#section-12--external-integrations)
13. [Known Architecture Decisions](#section-13--known-architecture-decisions)
14. [File Manifest](#section-14--file-manifest)

---

# SECTION 1 — App Identity & Philosophy

- The shipped app display name is `AiQo`. [`AiQo.xcodeproj/project.pbxproj:1057`]
- The main iOS bundle identifier is `com.mraad500.aiqo`. [`AiQo.xcodeproj/project.pbxproj:1089`]
- The marketing version is `1.0`, build number `1`. [`AiQo.xcodeproj/project.pbxproj:1082`]
- The main app target deploys to iOS 26.2; the watch app deploys to watchOS 26.2; Swift 5.0. [`AiQo.xcodeproj/project.pbxproj:1077`]

## Core Principles

1. **Zero Digital Pollution** — Every token has purpose. 200-memory cap (500 for Intelligence Pro), 90-day cleanup, chat history trimmed at 200 messages. [`AiQo/Core/MemoryStore.swift:410`]
2. **Privacy-First Hybrid Intelligence** — Sleep data stays on-device (Apple Intelligence). Cloud gets only sanitized, bucketed data. PII is regex-redacted before any API call. [`AiQo/Features/Captain/PrivacySanitizer.swift:6`]
3. **Iraqi Arabic Persona** — Captain Hamoudi speaks Iraqi dialect. 14 banned phrases strip generic AI filler. [`AiQo/Features/Captain/CaptainPersonaBuilder.swift:9-24`]
4. **Circadian-Aware** — 5 bio-phases (awakening/energy/focus/recovery/zen) dynamically adjust Captain's tone based on time, sleep quality, and activity level. [`AiQo/Features/Captain/CaptainContextBuilder.swift:6-76`]

## Bilingual Strategy

- Arabic RTL-first + English support. [`AiQo/Core/AppSettingsStore.swift:3-6`]
- `AppLanguage` enum: `.arabic = "ar"`, `.english = "en"`. Default: `.arabic`. [`AiQo/Core/AppSettingsStore.swift:3-6`, `AppSettingsStore.swift:23`]
- Runtime language switching via `Bundle+Language.swift` (Associated Objects swizzle). [`AiQo/Core/Localization/Bundle+Language.swift`]
- `LocalizationManager.shared.applySavedLanguage()` called on boot. [`AiQo/App/AppDelegate.swift:118`]
- Layout direction set via `.environment(\.layoutDirection, currentDirection)` in `AppRootView`. [`AiQo/App/SceneDelegate.swift:250`]
- Notification posted: `.appLanguageDidChange`. [`AiQo/Core/AppSettingsStore.swift:43-45`]
- Feature names intentionally kept in English in Arabic prompts: `My Vibe`, `Zone 2`, `Alchemy Kitchen`, `Arena`, `Tribe`. [`AiQo/Features/Captain/CaptainPromptBuilder.swift:90`]

---

# SECTION 2 — Tech Stack & Dependencies

## Language & Frameworks

- **Primary language**: Swift 5.0+. SwiftUI and UIKit coexist. [`AiQo/App/AppDelegate.swift:1-3`]
- **State management**: `ObservableObject` + `@Published` + `@StateObject` + `@Observable` (mixed Combine + Observation). [`AiQo/Premium/AccessManager.swift:5-8`]
- **Persistence**: SwiftData, UserDefaults/AppStorage, Keychain, JSONL files, App Group defaults. [`AiQo/App/AppDelegate.swift:37`]
- **Embedded binary framework**: `SpotifyiOS.framework`. [`AiQo.xcodeproj/project.pbxproj:22`]

## SPM Dependencies

| Package | Source | Version |
|---------|--------|---------|
| supabase-swift | supabase-community/supabase-swift | 2.36.0 |
| SDWebImage | SDWebImage/SDWebImage.git | 5.21.6 |
| SDWebImageSwiftUI | SDWebImage/SDWebImageSwiftUI | 3.1.4 |
| swift-asn1 | apple/swift-asn1.git | 1.5.0 |
| swift-clocks | pointfreeco/swift-clocks | 1.0.6 |
| swift-concurrency-extras | pointfreeco/swift-concurrency-extras | 1.3.2 |
| swift-crypto | apple/swift-crypto.git | 4.2.0 |
| swift-http-types | apple/swift-http-types.git | 1.4.0 |
| swift-system | apple/swift-system.git | 1.6.4 |
| xctest-dynamic-overlay | pointfreeco/xctest-dynamic-overlay | 1.7.0 |

## Apple Frameworks (Top Imports by Count)

| Framework | Import Count | Primary Usage |
|-----------|-------------|---------------|
| SwiftUI | 232 | UI layer |
| Foundation | 180 | Core logic |
| Combine | 76 | Reactive state |
| UIKit | 67 | Legacy UI + integration |
| HealthKit | 36 | Steps, sleep, HR, workouts |
| SwiftData | 25 | Captain memory, RecordProject |
| os.log | 24 | Structured logging |
| AVFoundation | 14 | Voice, audio |
| WidgetKit | 14 | Widget updates |
| UserNotifications | 12 | Push/local notifications |
| WatchKit | 7 | Watch companion |
| WatchConnectivity | 6 | Phone-Watch sync |
| StoreKit | 5 | IAP/subscriptions |
| FoundationModels | 5 | Apple Intelligence (iOS 26+) |
| ActivityKit | 3 | Live Activities |
| Charts | 2 | Data visualization |
| Vision | 1 | Pose detection (VisionCoach) |
| AlarmKit | 1 | iOS 26.1+ alarms |
| Speech | 1 | Zone 2 coaching |
| PDFKit | 1 | Health data export |

## Secrets Handling

- Build config: `Configuration/AiQo.xcconfig` includes `Secrets.xcconfig`. [`Configuration/AiQo.xcconfig:8`]
- Template: `Configuration/Secrets.template.xcconfig`. [`Configuration/Secrets.template.xcconfig:4`]
- Keys resolved from environment variables, then Info.plist fallback. [`AiQo/Features/Captain/HybridBrainService.swift:94-106`]

---

# SECTION 3 — Project Structure & Boot Sequence

## Folder Structure

```
AiQo/
+-- App/                        # Entry: AppDelegate, SceneDelegate, MainTabRouter, Auth flow
+-- Core/                       # Shared: Memory, Voice, Colors, Settings, Purchases, Localization
|   +-- Localization/           # Bundle+Language, LocalizationManager
|   +-- Models/                 # ActivityNotification, LevelStore, NotificationPreferences
|   +-- Purchases/              # EntitlementStore, PurchaseManager, ReceiptValidator, ProductIDs
|   +-- Utilities/              # ConnectivityDebugProviding
+-- DesignSystem/               # AiQoColors, AiQoTheme, AiQoTokens
|   +-- Components/             # AiQoCard, AiQoBottomCTA, AiQoPillSegment, etc.
|   +-- Modifiers/              # AiQoPressEffect, AiQoShadow, AiQoSheetStyle
+-- Features/
|   +-- Captain/                # 40+ files: BrainOrchestrator, HybridBrain, Prompt, Privacy
|   +-- DataExport/             # HealthDataExporter
|   +-- First screen/           # LegacyCalculationViewController
|   +-- Gym/                    # 84+ files: Workouts, QuestKit, VisionCoach, Club
|   |   +-- Club/               # ClubRootView, Body, Plan, Impact, Challenges
|   |   +-- QuestKit/           # Quest engine, data sources, SwiftData models
|   |   +-- Quests/             # Challenge models, stores, views, VisionCoach
|   +-- Home/                   # 18 files: DailyAura, Water, Streak, Vibe, Metrics
|   +-- Kitchen/                # Meal planning, Smart Fridge, Nutrition tracker
|   +-- LegendaryChallenges/    # 16-week record-breaking projects
|   +-- MyVibe/                 # Spotify integration, mood-based music
|   +-- Onboarding/             # FeatureIntro, HistoricalHealthSync, Walkthrough
|   +-- Profile/                # ProfileScreen, LevelCard
|   +-- ProgressPhotos/         # Photo store and gallery
|   +-- WeeklyReport/           # Report model, view, ViewModel, ShareCardRenderer
+-- Premium/                    # AccessManager, FreeTrialManager, PremiumStore, PaywallView
+-- Services/
|   +-- Analytics/              # AnalyticsEvent (40+ events), AnalyticsService
|   +-- CrashReporting/         # CrashReporter, CrashReportingService
|   +-- Notifications/          # 12 files: Dual-persona engine, Angel Numbers, Smart, Alarms
|   +-- Permissions/HealthKit/  # HealthKitService (actor), TodaySummary
+-- Shared/                     # HealthKitManager, CoinManager, LevelSystem, WorkoutSync
+-- Tribe/                      # 58 files: Galaxy, Arena, Stores, Models, Views
|   +-- Arena/                  # TribeArenaView, challenges
|   +-- Galaxy/                 # 30+ Arena/Galaxy views and ViewModels
|   +-- Log/                    # TribeLogView
|   +-- Models/                 # TribeModels, TribeFeatureModels, TribeModuleModels (612 lines)
|   +-- Stores/                 # ArenaStore, GalaxyStore, TribeLogStore, TribeStore
|   +-- Views/                  # Leaderboard, AtomRing, HubScreen, PulseScreen
+-- UI/                         # 9 shared components: GlassCard, ErrorToast, OfflineBanner
```

## Entry Point & Boot Sequence

```swift
@main struct AiQoApp: App
```

**`init()` Boot Order** [`AiQo/App/AppDelegate.swift:54-68`]:
1. `MemoryStore.shared.configure(container: captainContainer)` — SwiftData for Captain memory
2. `RecordProjectManager.shared.configure(container: captainContainer)` — Legendary challenges
3. `MemoryStore.shared.removeStale()` — Remove memories older than 90 days with confidence < 0.3
4. `HealthKitMemoryBridge.syncHealthDataToMemory()` — Async health-to-memory sync

**SwiftData Schema** [`AiQo/App/AppDelegate.swift:18-26`]:
```swift
Schema([CaptainMemory.self, PersistentChatMessage.self, RecordProject.self, WeeklyLog.self])
```
Store path: `captain_memory.store`

**`didFinishLaunchingWithOptions` Boot Order** [`AiQo/App/AppDelegate.swift:95-168`]:
1. `CrashReportingService.shared.configure()`
2. Bind user ID if logged in
3. `PhoneConnectivityManager.shared` — WatchConnectivity
4. `UNUserNotificationCenter.current().delegate = self`
5. `CrashReporter.shared`, `NetworkMonitor.shared`, `AnalyticsService.shared.track(.appLaunched)`
6. `FreeTrialManager.shared.refreshState()`
7. `LocalizationManager.shared.applySavedLanguage()`
8. Conditional onboarding flow setup
9. `AiQoWorkoutShortcuts.updateAppShortcutParameters()` (iOS 16+)
10. `SiriShortcutsManager.shared.donateAllShortcuts()`
11. `StreakManager.shared.checkStreakContinuity()`

## Tab Navigation

Three main tabs in `MainTabScreen` [`AiQo/App/MainTabScreen.swift:27-67`]:

| Tab | View | Icon |
|-----|------|------|
| Home | `HomeView` | `house.fill` |
| Gym | `GymView` | `figure.strengthtraining.traditional` |
| Captain | `CaptainScreen` + `CaptainChatView` | `wand.and.stars` |

## Onboarding Flow

`AppFlowController.RootScreen` enum [`AiQo/App/SceneDelegate.swift:20-27`]:
```
languageSelection -> login -> profileSetup -> legacy -> featureIntro -> main
```
Each step persists a UserDefaults flag; `resolveCurrentScreen()` checks flags sequentially.

## Auth Flow

- Sign In with Apple via `ASAuthorizationAppleIDRequest`. [`AiQo/App/LoginViewController.swift:104-112`]
- Nonce generation + SHA256 hashing. [`AiQo/App/LoginViewController.swift:174-191`]
- Token exchanged via `SupabaseService.shared.client.auth.signInWithIdToken()`. [`AiQo/App/LoginViewController.swift:141`]

## Deep Links

`DeepLink` enum [`AiQo/Services/DeepLinkRouter.swift:11-19`]:

| Route | URL |
|-------|-----|
| Home | `aiqo://home` |
| Captain | `aiqo://captain` |
| Gym | `aiqo://gym` |
| Kitchen | `aiqo://kitchen` |
| Settings | `aiqo://settings` |
| Referral | `aiqo://referral?code=XXX` |
| Premium | `aiqo://premium` |

Universal Links also supported: `https://aiqo.app/{route}`. [`AiQo/Services/DeepLinkRouter.swift:96-114`]

---

# SECTION 4 — The Hybrid Brain (AI Routing)

## Architecture: BrainOrchestrator

The brain follows a strict LOCAL-vs-CLOUD routing table. [`AiQo/Features/Captain/BrainOrchestrator.swift:78-91`]

| Screen Context | Route | Reasoning |
|---------------|-------|-----------|
| `.sleepAnalysis` | LOCAL | Privacy: sleep data stays on-device (Apple Intelligence) |
| `.mainChat` | CLOUD | General chat via Gemini |
| `.gym` | CLOUD | Workout plan generation |
| `.kitchen` | CLOUD | Meal plan generation + image analysis |
| `.peaks` | CLOUD | Challenge coaching |
| `.myVibe` | CLOUD | Mood/music recommendations |

**Sleep Intent Detection** [`AiQo/Features/Captain/BrainOrchestrator.swift:452-478`]:
- English patterns: `sleep|slept|sleeping|deep sleep|rem|nap|last night`
- Arabic patterns: `نوم|نمت|نومي|نومتك|نومتـي`
- Data request patterns: `analy[sz]e|how much|show me|track|score|data|metrics|stages|healthkit`
- Arabic data patterns: `تحليل|حلل|شكد|قديش|بيانات|داتا|مراحل`

**Fallback Chain** (when local Apple Intelligence fails):
1. On-device `SystemLanguageModel` (iOS 26+)
2. Cloud aggregated sleep summary (sanitized)
3. Computed reply from raw HealthKit data (no AI)
4. Localized error message

## HybridBrainService (Cloud Transport)

- Model: `gemini-flash-latest`. [`AiQo/Features/Captain/HybridBrainService.swift:87`]
- Endpoint: `https://generativelanguage.googleapis.com/v1beta/models`. [`HybridBrainService.swift:88`]
- Timeout: 35 seconds. [`HybridBrainService.swift:89`]

**Token Limits by Screen** [`HybridBrainService.swift:283-289`]:

| Screen | Max Output Tokens |
|--------|------------------|
| `.mainChat`, `.myVibe`, `.sleepAnalysis` | 600 |
| `.gym`, `.kitchen`, `.peaks` | 900 |

**Structured Response JSON** [`CaptainPromptBuilder.swift:284-302`]:
```json
{
  "message": "string",
  "quickReplies": ["string", "string"],
  "workoutPlan": null | WorkoutPlan,
  "mealPlan": null | MealPlan,
  "spotifyRecommendation": null | SpotifyRecommendation
}
```

## 6-Layer System Prompt Architecture

[`AiQo/Features/Captain/CaptainPromptBuilder.swift:13-328`]

| Layer | Content | Lines |
|-------|---------|-------|
| 1. Identity | Elite AI mentor, Iraqi dialect rules, banned phrases | 30-133 |
| 2. Memory | Long-term context from MemoryStore | 137-147 |
| 3. Bio-State | steps_today, active_cal, sleep_last_night, heart_rate, user_level | 151-188 |
| 4. Circadian Tone | Adapts tone to BioTimePhase (awakening/energy/focus/recovery/zen) | 192-206 |
| 5. Screen Context | Behavior rules per screen (mainChat, gym, kitchen, etc.) | 210-270 |
| 6. Output Contract | MUST return strict JSON with message + quickReplies + plans | 274-328 |

---

# SECTION 5 — Privacy Architecture

[`AiQo/Features/Captain/PrivacySanitizer.swift`]

## Guarantees

| Protection | Implementation |
|-----------|---------------|
| PII Redaction | Emails, phones, UUIDs, IPs, card numbers, URLs, @mentions, Base64 tokens → `[REDACTED]` |
| User Name | Normalized to "User" in cloud payloads |
| Conversation Truncation | LAST 4 messages only sent to cloud |
| Health Data Bucketing | Steps bucketed by 50, calories by 10 |
| Kitchen Images | EXIF/GPS stripped via re-encoding, max 1280px, JPEG 0.78 quality |
| Self-Identifying Phrases | "my name is X", "اسمي", "I am X" → replaced |

**Constants** [`PrivacySanitizer.swift:18-25`]:
- `maxConversationMessages = 4`
- `maximumKitchenImageDimension = 1280`
- `kitchenImageCompressionQuality = 0.78`
- `stepsBucketSize = 50`
- `caloriesBucketSize = 10`

**Post-Generation Name Injection** [`PrivacySanitizer.swift:143-173`]:
After cloud reply arrives, `injectUserName(into:userName:)` re-personalizes the response with the user's real name. This ensures the name NEVER leaves the device.

---

# SECTION 6 — Captain Hamoudi (AI Persona)

## Identity

- Iraqi coach / older-brother persona. Separate English and Iraqi-Arabic identity blocks. [`CaptainPromptBuilder.swift:34`, `CaptainPromptBuilder.swift:84`]
- Real-person simulation, NOT generic AI assistant. [`CaptainPersonaBuilder.swift`]

## Banned Phrases (14 total)

[`AiQo/Features/Captain/CaptainPersonaBuilder.swift:9-24`]

Arabic: `بالتأكيد`, `بكل سرور`, `كمساعد ذكاء اصطناعي`, `لا أستطيع`, `يسعدني مساعدتك`, `هل يمكنني مساعدتك`, `كيف يمكنني مساعدتك اليوم`, `بصفتي نموذج لغوي`
English: `As an AI`, `I'm happy to help`, `How can I assist you`, `Certainly!`, `Of course!`, `I'd be happy to`

## Response Length Rules

[`CaptainPersonaBuilder.swift:50-62`]
- Simple questions: 1-2 sentences max
- Workout plans: structured bullets only
- Never ramble, max 3 actionable points per response
- No repetition within same reply

## Circadian Bio-Phases

[`AiQo/Features/Captain/CaptainContextBuilder.swift:6-76`]

| Phase | Hours | Tone |
|-------|-------|------|
| Awakening | 05:00-09:59 | Gentle, clear, optimistic |
| Energy | 10:00-13:59 | Sharp, direct, high-output |
| Focus | 14:00-17:59 | Steady, precise, minimal |
| Recovery | 18:00-20:59 | Warm, calm, encouraging |
| Zen | 21:00-04:59 | Soft, philosophical, minimal |

## Growth Stages (Levels 1-50)

[`CaptainContextBuilder.swift:250-266`]

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

## Voice Pipeline

- **ElevenLabs TTS** (primary): `eleven_multilingual_v2` model. [`AiQo/Core/CaptainVoiceAPI.swift:9`]
- **AVSpeechSynthesizer** (fallback): Arabic rate 0.44, English rate 0.48, pitch 0.96x. [`CaptainVoiceService.swift:121-128`]
- **Voice Caching**: `CaptainVoiceCache` for pre-cached common phrases. [`CaptainVoiceService.swift:240-242`]
- **Audio Session**: Playback category with duck-others during speech (0.26 volume), smooth ramp. [`AiQoAudioManager.swift:122-136`]

## Memory System

[`AiQo/Core/MemoryStore.swift`]

| Property | Value |
|----------|-------|
| Max Memories (Standard) | 200 |
| Max Memories (Intelligence Pro) | 500 |
| Stale Removal | > 90 days AND confidence < 0.3 |
| Cloud-Safe Categories | goal, preference, mood, injury, nutrition, insight |
| Cloud-Safe Token Budget | 400 tokens |
| Full Context Token Budget | 800 tokens |

---

# SECTION 7 — Feature Modules

## Home (18 files)

[`AiQo/Features/Home/`]

| Component | File | Purpose |
|-----------|------|---------|
| Main Dashboard | `HomeView.swift` | Central activity hub |
| Daily Aura | `DailyAuraView.swift` | Animated progress ring visualization |
| Water Tracking | `WaterBottleView.swift`, `WaterDetailSheetView.swift` | Animated bottle fill + detail |
| Streak Badge | `StreakBadgeView.swift` | Flame icon, color by streak level (7+ orange, 30+ purple) |
| Vibe Control | `VibeControlSheet.swift` (52KB) | Full Spotify integration sheet |
| DJ Captain | `DJCaptainChatView.swift` | AI music DJ overlay |
| Level Up | `LevelUpCelebrationView.swift` | Celebration animation |
| Stat Cards | `HomeStatCard.swift` | Steps/calories/distance cards |
| Metrics | `MetricKind.swift` | Metric type enum |

## Gym (84 files)

[`AiQo/Features/Gym/`]

### QuestKit Engine
- `QuestEngine.swift` — Main quest state machine
- `QuestKitModels.swift` — Types: `QuestType` (daily/weekly/oneTime/streak/cumulative/combo), `QuestSource` (manual/water/healthkit/camera/timer/workout/social/kitchen/share), `QuestMetricKey` (waterLiters/sleepHours/zone2Minutes/pushupReps/etc.)
- `QuestSwiftDataModels.swift`, `QuestSwiftDataStore.swift` — SwiftData persistence
- `QuestProgressStore.swift`, `QuestDailyStore.swift`, `QuestAchievementStore.swift` — Progress tracking

### Club (Structured Training)
- `ClubRootView.swift` — Main gym entry
- `Body.swift`, `Plan.swift`, `Impact.swift`, `Challenges.swift` — Workout categories

### VisionCoach (Pose Detection)
- `VisionCoachView.swift`, `VisionCoachViewModel.swift` — Camera-based pose detection using `Vision` framework
- `VisionCoachAudioFeedback.swift` — Real-time form feedback

### Live Workout
- `LiveWorkoutSession.swift` — Active session management
- `LiveMetricsHeader.swift` — Real-time HR, calories, distance
- `HandsFreeZone2Manager.swift` — Zone 2 cardio with speech guidance
- `WorkoutLiveActivityManager.swift` — Live Activity on lock screen

## Kitchen

[`AiQo/Features/Kitchen/`]

- `KitchenViewModel.swift` — Observable with `LoadingState` (idle/loading/loaded/error), target calories (default 2200), meal plan generation. [`KitchenViewModel.swift:9-104`]
- `SmartFridgeCameraViewModel.swift` — Camera-based ingredient detection
- Meal types: breakfast, lunch, dinner, snack
- AI-generated daily meal plans via Captain

## MyVibe (Mood/Music)

[`AiQo/Features/MyVibe/`]

- `MyVibeScreen.swift` — DJ Hamoudi header, vibe timeline, frequency card, Spotify card, DJ search bar. [`MyVibeScreen.swift:8-42`]
- `MyVibeViewModel.swift` — Vibe state management
- `VibeOrchestrator.swift` — Orchestrates mood-based music selection
- `DailyVibeState.swift` — Daily vibe state model
- Spotify SDK integration via `SpotifyiOS.framework`

## Tribe (58 files)

[`AiQo/Tribe/`]

### Core Models

[`AiQo/Tribe/Models/TribeModels.swift`]
- `Tribe`: id, name, ownerUserId, inviteCode, createdAt
- `TribeMember`: displayName (public/private), level, privacyMode, energyContributionToday, role (owner/admin/member)
- `TribeMission`: id, title, targetValue, progressValue, endsAt
- `TribeEvent`: 10 event types (contribution, spark, join, shieldUnlocked, missionCompleted, etc.)

[`AiQo/Tribe/Models/TribeFeatureModels.swift`]
- `TribeScreenTab`: hub, arena, log, galaxy
- `TribeChallengeMetricType`: steps, water, sleep, minutes, custom, sugarFree, calmMinutes (with titleString, unitLabel, iconName, accentHue)
- `TribeChallenge`: scope (personal/tribe/galaxy), cadence (daily/monthly), progress tracking
- `GalaxyChallengeSuggestion`: Community challenge proposals

[`AiQo/Tribe/Models/TribeModuleModels.swift` (612 lines)]
- `TribeSectorColor`: blue, green, yellow, red, purple (with accent, glow, halo colors)
- `TribeRingMember`: Ring visualization data
- `TribeGlobalRankEntry`: Global leaderboard entry
- `TribeModernPalette`: 32+ color definitions for dark/light modes

### Stores

| Store | File | Purpose |
|-------|------|---------|
| TribeStore | `TribeStore.swift` | CRUD: create/join/leave tribe, sync privacy, fetch members |
| ArenaStore | `ArenaStore.swift` (226 lines) | Challenges: create, contribute, leaderboard, galaxy suggestions |
| GalaxyStore | `GalaxyStore.swift` (101 lines) | Graph: nodes, edges, layout (network/spokes), spark events, pan/zoom |
| TribeLogStore | `TribeLogStore.swift` (26 lines) | Event log: record, latest events |

### Key Views
- `TribeHubScreen.swift` — Energy shield, member contributions, missions, events, galaxy
- `TribeLeaderboardView.swift` — Card themes (mint/sand/lavender/peach/sky/rose), crown animation
- `TribeAtomRingView.swift` — Animated ring with sector-colored members
- `TribePulseScreenView.swift` — Real-time activity pulse
- `GlobalTribeRadialView.swift` — Global tribe visualization

## Legendary Challenges

[`AiQo/Features/LegendaryChallenges/`]

- `RecordProject` (SwiftData `@Model`): 16-week record-breaking projects with HRR assessment, weekly logs, difficulty tiers. [`LegendaryChallenges/Models/RecordProject.swift:112 lines`]
- `LegendaryRecord`: 8 seed records (pushups, plank, squats, walk 24h, burpees, pullups, breath hold, steps 24h). [`LegendaryRecord.swift:186 lines`]
- Categories: strength, cardio, endurance, clarity
- Difficulty: beginner, advanced, legendary

## Weekly Report

[`AiQo/Features/WeeklyReport/`]

- `WeeklyReportData`: Steps, calories, distance, sleep, water, stand hours, workouts — current vs. previous week. [`WeeklyReportModel.swift:1-63`]
- `overallScore` (0-100): Steps 25%, Calories 25%, Sleep 25%, Workouts 25%
- Change calculations for week-over-week comparison
- `WeeklyReportViewModel`: Concurrent async HealthKit fetching

## Progress Photos

[`AiQo/Features/ProgressPhotos/`]

- `ProgressPhotoStore`: JPEG 0.85 quality, pagination (20/page), weight tracking, file-based storage in Documents. [`ProgressPhotoStore.swift:155 lines`]
- `ProgressPhotoEntry`: id, date, filename, weightKg, note

---

# SECTION 8 — UI/UX Design System

## Color Palette

[`AiQo/DesignSystem/AiQoColors.swift`, `AiQoTheme.swift`]

| Token | Light | Dark |
|-------|-------|------|
| Mint | #CDF4E4 | - |
| Beige | #F5D5A6 | - |
| textPrimary | #0F1721 | #F6F8FB |
| textSecondary | #5F6F80 | #A3AFBC |
| Accent | #5ECDB7 | #8AE3D1 |

Auth flow theme [`AuthFlowUI.swift:6-14`]:
- mint: `#B7E5D2`, sand: `#EBCF97`, bgTop: `#FAFAF8`, bgBottom: `#F5F0E8`

## Typography

[`AiQo/DesignSystem/AiQoTheme.swift`]

| Style | Config |
|-------|--------|
| screenTitle | Title2, Bold, Rounded |
| sectionTitle | Headline, Semibold |
| cardTitle | Headline, Semibold |
| body | Subheadline, Regular |
| caption | Caption, Regular |
| cta | Headline, Bold |

Auth flow fonts [`AuthFlowUI.swift:18-38`]: `.aiqoDisplay` (black/rounded), `.aiqoHeading` (bold/rounded), `.aiqoBody` (medium/rounded)

## Spacing & Sizing Tokens

[`AiQo/DesignSystem/AiQoTokens.swift`]

| Token | Value |
|-------|-------|
| Spacing.xs | 8 |
| Spacing.sm | 12 |
| Spacing.md | 16 |
| Spacing.lg | 24 |
| Radius.control | 12 |
| Radius.card | 16 |
| Radius.ctaContainer | 24 |
| Metrics.minimumTapTarget | 44 |

## Key Components

| Component | File | Behavior |
|-----------|------|----------|
| AiQoCard | `Components/AiQoCard.swift` | Universal card: title, subtitle, badge, accent, icon placement, min height 96 |
| AiQoBottomCTA | `Components/AiQoBottomCTA.swift` | Gradient CTA button with ultra-thin material background |
| AiQoPressEffect | `Modifiers/AiQoPressEffect.swift` | Scale 0.92 + 3D tilt 8 degrees on press, spring animation |
| AiQoSkeleton | `Components/AiQoSkeletonView.swift` | Loading placeholder |
| AiQoPillSegment | `Components/AiQoPillSegment.swift` | Segment picker |
| GlassCard | `UI/GlassCardView.swift` | Glassmorphism card |
| OfflineBanner | `UI/OfflineBannerView.swift` | Network status |
| ErrorToast | `UI/ErrorToastView.swift` | Error notifications |

---

# SECTION 9 — Data Models & State Management

## SwiftData Models

| Model | File | Key Fields |
|-------|------|------------|
| `CaptainMemory` | `Captain/CaptainMemory.swift` | key, value, category, source, confidence, accessCount, createdAt, updatedAt |
| `PersistentChatMessage` | `Captain/CaptainModels.swift` | role, content, timestamp |
| `RecordProject` | `LegendaryChallenges/RecordProject.swift` | recordID, title, targetValue, totalWeeks, currentWeek, status, weeklyLogs[] |
| `WeeklyLog` | `LegendaryChallenges/WeeklyLog.swift` | week, recordedValue, date |

## UserDefaults Stores

| Store | Key(s) | Purpose |
|-------|--------|---------|
| `AppSettingsStore` | `aiqo.app.language`, `aiqo.notifications.enabled` | App language + notifications toggle |
| `UserProfileStore` | `aiqo.userProfile` (JSON) | Name, age, height, weight, gender, username, birthDate |
| `GoalsStore` | `aiqo.dailyGoals` (JSON) | steps (default 8000), activeCalories (default 400) |
| `NotificationPreferencesStore` | `user_gender`, `aiqo.notification.language` | Gender + notification language |
| `LevelStore` | `aiqo.level.*` | Level, currentXP, totalXP (exponential: base 1000, multiplier 1.2) |
| `CoinManager` | `AppGroupKeys.userCoins` | Coin balance (App Group synced) |
| `EntitlementStore` | `aiqo.purchases.*` | activeProductId, expiresAt, currentTier |
| `FreeTrialManager` | Keychain + `aiqo.trial.*` | Trial start date (Keychain = survives reinstall) |
| `InactivityTracker` | `aiqo.inactivity.lastActiveDate` | Timestamp of last activity |
| `StreakManager` | Various | Streak count and continuity |

## HealthKit Data Flow

```
HealthKitManager.processNewHealthData()
  |-- HealthKitService.fetchTodaySummary() -> TodaySummary
  |     (steps, activeKcal, standPercent, waterML, sleepHours, distanceMeters)
  |-- InactivityTracker.markActive() (on step increase)
  |-- CoinManager.addCoins() (mining: 10k steps = 100 coins, 500 kcal = 100 coins)
  |-- ActivityNotificationEngine.evaluateAndSendIfNeeded()
  |     (goalCompleted / almostThere / moveNow based on progress %)
  |-- CaptainSmartNotificationService.evaluateInactivityAndNotifyIfNeeded()
  |     (45-min inactivity threshold)
  |-- CaptainNotificationEngine.evaluateHealthKitTriggers()  <<<< NEW
        (Dual-persona: 18-hour wake rule, late inactive day, high inactivity)
```

## Shield Tier System

[`AiQo/Core/Models/LevelStore.swift:12-48`]

| Tier | Levels | Color |
|------|--------|-------|
| Wood | 1-4 | Brown |
| Bronze | 5-9 | Bronze |
| Silver | 10-14 | Silver |
| Gold | 15-19 | Gold |
| Platinum | 20-24 | Platinum |
| Diamond | 25-29 | Diamond |
| Obsidian | 30-34 | Dark |
| Legendary | 35+ | Epic |

---

# SECTION 10 — Monetization & Subscription

## Subscription Tiers

[`AiQo/Core/Purchases/SubscriptionTier.swift`]

```swift
enum SubscriptionTier: Int, Comparable {
    case none = 0
    case standard = 1
    case intelligencePro = 2
}
```

## Feature Access Matrix

[`AiQo/Premium/AccessManager.swift:35-65`]

| Feature | none | standard | intelligencePro |
|---------|------|----------|-----------------|
| Captain Chat | - | Yes | Yes |
| Gym | - | Yes | Yes |
| Kitchen | - | Yes | Yes |
| MyVibe | - | Yes | Yes |
| Challenges | - | Yes | Yes |
| Data Tracking | - | Yes | Yes |
| Captain Notifications | - | Yes | Yes |
| Peaks | - | - | Yes |
| HRR Assessment | - | - | Yes |
| Weekly AI Workout Plan | - | - | Yes |
| Record Projects | - | - | Yes |
| **Coach Persona** | - | - | **Yes** |
| Extended Memory (500) | - | - | Yes |
| Intelligence Model | - | - | Yes |
| Create Tribe | - | - | Yes |

## StoreKit 2 Flow

[`AiQo/Core/Purchases/PurchaseManager.swift`]

1. `start()` — Begin observing transaction updates. [`PurchaseManager.swift:54-62`]
2. `loadProducts()` — Fetch from App Store (2 attempts, 2-second retry). [`PurchaseManager.swift:72-145`]
3. `purchase(product:)` — Purchase and validate. [`PurchaseManager.swift:163-201`]
4. `updateEntitlementsFromLatestTransactions()` — Rebuild state from verified transactions. [`PurchaseManager.swift:219-231`]
5. Receipt validation via Supabase Edge Function at `https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/validate-receipt`. [`ReceiptValidator.swift:10`]

## Free Trial

[`AiQo/Premium/FreeTrialManager.swift`]

- Duration: 7 days. [`FreeTrialManager.swift:15`]
- Storage: Keychain (survives reinstalls) + UserDefaults sync. [`FreeTrialManager.swift:78-94`]
- Grants Intelligence Pro tier during trial. [`AccessManager.swift:29`]

## Premium Expiry Notifications

[`AiQo/Services/Notifications/PremiumExpiryNotifier.swift`]

3 notifications scheduled: 2 days before, 1 day before, at expiration.

---

# SECTION 11 — Notification Engine (Dual-Persona)

## Overview

AiQo has 5 independent notification subsystems:

| Engine | File | Trigger |
|--------|------|---------|
| **CaptainNotificationEngine** (Dual-Persona) | `CaptainNotificationEngine.swift` (1069 lines) | Biological time + HealthKit triggers |
| ActivityNotificationEngine (Angel Numbers) | `ActivityNotificationEngine.swift` (628 lines) | 3 random angel-number times/day |
| CaptainSmartNotificationService | `NotificationService.swift` | Inactivity (45min), water, meals, step goals, sleep |
| NotificationIntelligenceManager | `NotificationIntelligenceManager.swift` (552 lines) | Background tasks + Spiritual Whispers |
| MorningHabitOrchestrator | `MorningHabitOrchestrator.swift` (383 lines) | Sleep-to-wake (25+ steps within 6hr of wake) |

## Dual-Persona System (NEW in Blueprint 9)

[`AiQo/Services/Notifications/CaptainNotificationEngine.swift`]

### Two Personas

| Persona | Name | Tier Required | Tone | Sound |
|---------|------|---------------|------|-------|
| `.friend` | "Hamoudi" | Free / Standard | Gentle, rare | `.default` |
| `.coach` | "Captain Hamoudi" | Intelligence Pro | Strict, physiology-driven | `.defaultCritical` |

Persona resolution [`CaptainNotificationEngine.swift:532-535`]:
```swift
func resolvePersona() -> PersonaType {
    AccessManager.shared.activeTier >= .intelligencePro ? .coach : .friend
}
```

### Coach Frequency Control (Pro Only)

[`CaptainNotificationEngine.swift`]

```swift
enum CaptainNotificationFrequency {
    case low    // 3 notifications/day, 180min cooldown
    case normal // 6 notifications/day, 90min cooldown (default)
    case high   // 10 notifications/day, 45min cooldown
}
```

Stored in `CaptainFrequencyStore` via UserDefaults key `aiqo.captain.notificationFrequency`.

### HealthKit Triggers (Real-Time)

Called from `HealthKitManager.processNewHealthData()` [`HealthKitManager.swift:362`]:

| Trigger | Condition | Coach (Pro) | Friend (Free) |
|---------|-----------|-------------|---------------|
| **18-Hour Wake Rule** | `sleepHours < 0.1` AND `hoursSinceLastSleep >= 18` AND `steps > 200` | Strict sleep **command** | Not fired |
| **Late Inactive Day** | `dayProgress >= 70%` AND `steps < 500` | Aggressive "move NOW" | Gentle nudge |
| **High Inactivity** | Coach: `inactivityMin >= 60` / Friend: `>= 90` | Strict workout push | Gentle hydration |

### PhysiologyProvider

[`CaptainNotificationEngine.swift` — `PhysiologyProvider` class]

Reads from HealthKit via `HKStatisticsQuery` (steps) and `HKSampleQuery` (sleep):
- `fetchTodaySteps()` — Cumulative step count since start of day
- `fetchTodaySleepHours()` — Sleep samples from -18 hours (captures overnight), filters for asleepCore/asleepDeep/asleepREM/asleepUnspecified
- `fetchHoursSinceLastSleep()` — Hours since end of most recent sleep session (48-hour lookback)
- `currentDayProgress()` — 0.0 at midnight, 1.0 at 11:59 PM

### 120-Notification Catalog

[`CaptainNotificationCatalog`]

4 variants x 30 entries = 120 total:
- Male Arabic (30), Male English (30), Female Arabic (30), Female English (30)

8 notification contexts with biological time windows:

| Context | Windows | Coach Priority |
|---------|---------|---------------|
| sleepWindDown | 22:00 | 10 (highest) |
| workoutMotivation | 11:00, 17:30 | 9 |
| morningRampUp | 07:00 | 8 |
| streakAndProgress | 20:00 | 7 |
| hydrationNudge | 10:00, 13:00, 16:00 | 6 |
| focusAndMindset | 09:30, 14:00 | 5 |
| nutritionFuel | 12:00, 19:00 | 4 |
| faithAndSoul | 05:00, 12:30 | 3 |

### Scheduling Logic

**Friend**: 3 gentle nudges (morning 07:00, midday 13:00, evening 22:00).
**Coach**: All context windows flattened, sorted by priority descending, pruned to frequency cap. Yesterday's picked notification IDs tracked to avoid repeats.

### Notification Categories

[`AiQo/Services/Notifications/NotificationCategoryManager.swift`]

3 registered categories:
1. `CAPTAIN_ANGEL_REMINDER` — ActivityNotificationEngine
2. `aiqo.captain.smart` — CaptainSmartNotificationService
3. `CAPTAIN_BEHAVIORAL_NUDGE` — CaptainNotificationEngine (Dual-Persona)

## Angel Numbers System

[`AiQo/Services/Notifications/ActivityNotificationEngine.swift`]

- 9 angel-number times: 1:11, 2:22, 3:33, 4:44, 5:55, 10:10, 11:11, 12:12, 12:21
- Selects 3 per day with maximum spacing algorithm (brute-force combinations)
- Excludes yesterday's times to ensure variety
- Time-specific messages (e.g., 11:11 = "Make a wish and move!")

## CaptainSmartNotificationService Cooldowns

[`AiQo/Services/Notifications/NotificationService.swift`]

| Trigger | Cooldown |
|---------|----------|
| Inactivity (45min+) | 45 minutes |
| Water (< 50% target) | 2 hours, 9am-9pm only |
| Meal time (breakfast/lunch/dinner) | 4 hours per meal |
| Step goal (50%/75%/90%) | 1 hour per milestone |
| Sleep reminder | 20 hours |

## Background Intelligence

[`AiQo/Services/Notifications/NotificationIntelligenceManager.swift`]

- 2 BGTask identifiers: `aiqo.captain.spiritual-whispers.refresh`, `aiqo.captain.inactivity-check`
- Spiritual Whispers: English context-aware message translated to Iraqi Arabic via AI
- Preferred refresh: 6:15 AM, 5:30 PM
- Inactivity check: 2:05 PM, then every 2 hours until 8:30 PM
- Fires if after 2 PM and steps < 3000

## Morning Habit

[`AiQo/Services/Notifications/MorningHabitOrchestrator.swift`]

- Triggers when user takes 25+ steps within 6 hours of wake time
- Generates ephemeral AI insight about sleep quality
- Caches insight to avoid duplicate generation

## Alarm Scheduling (iOS 26.1+)

[`AiQo/Services/Notifications/AlarmSchedulingService.swift`]

- `AlarmKitSchedulingService` implementation for native iOS 26.1+ alarms
- Managed alarm with fixed UUID
- `AlarmSaveState` tracks permission and save lifecycle
- Falls back to notification-based reminders on older iOS

---

# SECTION 12 — External Integrations

| Service | Purpose | Key File |
|---------|---------|----------|
| **Supabase** | Auth (Sign in with Apple), Database (profiles, tribes), Edge Functions (receipt validation) | `SupabaseService.swift` |
| **Gemini** | Cloud AI (Captain chat, meal plans, workout plans) | `HybridBrainService.swift` |
| **ElevenLabs** | TTS voice synthesis (Captain voice) | `CaptainVoiceAPI.swift` |
| **Apple Intelligence** | On-device sleep analysis (iOS 26+, FoundationModels) | `BrainOrchestrator.swift` |
| **HealthKit** | Steps, calories, distance, sleep, HR, workouts, water, stand hours | `HealthKitService.swift` |
| **AlarmKit** | Native alarm scheduling (iOS 26.1+) | `AlarmSchedulingService.swift` |
| **Spotify SDK** | Music playback, mood-based recommendations | `SpotifyiOS.framework` |
| **StoreKit 2** | IAP subscriptions (Standard, Intelligence Pro) | `PurchaseManager.swift` |
| **WatchConnectivity** | Phone-Watch sync for workouts and metrics | `PhoneConnectivityManager.swift` |
| **Vision** | Pose detection for VisionCoach exercise form | `VisionCoachViewModel.swift` |
| **ActivityKit** | Live Activities for active workouts | `WorkoutLiveActivityManager.swift` |
| **CoreSpotlight** | Siri search indexing | `SiriShortcutsManager.swift` |

---

# SECTION 13 — Known Architecture Decisions

1. **`@MainActor` Singletons**: `AccessManager`, `HealthKitManager`, `CaptainVoiceService`, all Tribe stores, `LevelStore` are `@MainActor`. Non-main-actor singletons: `AppSettingsStore`, `InactivityTracker`, `GoalsStore`, `CoinManager`.

2. **Mixed State Patterns**: Both `ObservableObject` + `@Published` (Combine) and `@Observable` (Observation) coexist. Tribe and Premium modules use `ObservableObject`; Kitchen uses `@Observable`.

3. **HealthKit Actor**: `HealthKitService` is a Swift actor for thread-safe HealthKit access. `HealthKitManager` wraps it with `@Published` properties for UI binding.

4. **Dual Persistence**: UserDefaults for lightweight state + SwiftData for Captain memory/chat/projects. Keychain for trial date (survives reinstall). App Group for widget data sharing.

5. **Sleep Data Locality**: Sleep analysis is strictly routed to LOCAL Apple Intelligence; never sent to cloud. This is an explicit privacy decision enforced in `BrainOrchestrator.route()`.

6. **Notification Identifier Prefixes**: `aiqo.captain.nudge.*` (behavioral), `aiqo.captain.coach.*` (coach triggers), `aiqo.angel.*` (angel numbers), `aiqo.captain.smart` (smart service), `aiqo.morningHabit.*` (morning).

7. **Coin Economy**: Steps-based mining (100 steps = 1 coin, 5 kcal = 1 coin, 0.1 km = 1 coin). Best metric wins (no double-counting). Daily reset. Persisted to App Group.

8. **Language Filter for Notifications**: Captain language reads from `AppSettingsStore.shared.appLanguage` (NOT device locale, NOT notification preference store). Gender reads from `UserProfileStore.shared.current.gender` with fallback to `NotificationPreferencesStore.shared.gender`.

---

# SECTION 14 — File Manifest

## By Module (372 iOS + 9 Widget = 381 total)

| Module | File Count | Key Types |
|--------|-----------|-----------|
| App/ | 10 | AiQoApp, AppDelegate, AppFlowController, AppRootManager, MainTabScreen, LoginScreenViewModel |
| Core/ | 20+ | AppSettingsStore, UserProfileStore, MemoryStore, LevelStore, GoalsStore, CaptainVoiceService, CaptainVoiceAPI, AiQoAudioManager |
| Core/Purchases/ | 5 | PurchaseManager, EntitlementStore, SubscriptionTier, ReceiptValidator, SubscriptionProductIDs |
| Core/Localization/ | 2 | Bundle+Language, LocalizationManager |
| Core/Models/ | 4 | ActivityNotification, LevelStore, NotificationPreferencesStore |
| DesignSystem/ | 13 | AiQoColors, AiQoTheme, AiQoTokens, AiQoCard, AiQoBottomCTA, AiQoPressEffect |
| Features/Captain/ | 40+ | BrainOrchestrator, HybridBrainService, CaptainPromptBuilder, CaptainContextBuilder, PrivacySanitizer, CaptainPersonaBuilder, CaptainChatView, CaptainViewModel |
| Features/Home/ | 18 | HomeView, HomeViewModel, DailyAuraView, WaterBottleView, StreakBadgeView, VibeControlSheet |
| Features/Gym/ | 84 | QuestEngine, QuestKitModels, VisionCoachViewModel, LiveWorkoutSession, ClubRootView, HandsFreeZone2Manager |
| Features/Kitchen/ | 10+ | KitchenViewModel, SmartFridgeCameraViewModel, MealModels |
| Features/MyVibe/ | 5 | MyVibeScreen, MyVibeViewModel, VibeOrchestrator, DailyVibeState |
| Features/LegendaryChallenges/ | 12 | RecordProject, LegendaryRecord, RecordProjectManager, HRRWorkoutManager |
| Features/WeeklyReport/ | 4 | WeeklyReportData, WeeklyReportViewModel, WeeklyReportView, ShareCardRenderer |
| Features/ProgressPhotos/ | 3 | ProgressPhotoStore, ProgressPhotoEntry, ProgressPhotosView |
| Features/Onboarding/ | 3 | OnboardingWalkthroughView, FeatureIntroView, HistoricalHealthSyncEngine |
| Features/Profile/ | 3 | ProfileScreen, LevelCardView |
| Premium/ | 4 | AccessManager, FreeTrialManager, PremiumStore, PaywallView |
| Services/Notifications/ | 12 | CaptainNotificationEngine, ActivityNotificationEngine, NotificationService, MorningHabitOrchestrator, NotificationIntelligenceManager, AlarmSchedulingService |
| Services/Analytics/ | 2 | AnalyticsEvent (40+ events), AnalyticsService |
| Services/CrashReporting/ | 2 | CrashReporter, CrashReportingService |
| Services/Permissions/ | 2 | HealthKitService (actor), TodaySummary |
| Services/ | 5 | DeepLinkRouter, NetworkMonitor, NotificationType, ReferralManager, SupabaseService |
| Shared/ | 6 | HealthKitManager, CoinManager, LevelSystem, WorkoutSyncCodec, WorkoutSyncModels |
| Tribe/ | 58 | TribeStore, ArenaStore, GalaxyStore, TribeModels, TribeFeatureModels, TribeModuleModels, TribeHubScreen |
| UI/ | 9 | GlassCardView, ErrorToastView, OfflineBannerView, AiQoProfileButton, AiQoScreenHeader |

---

> End of AiQo Master Blueprint 9.
> For implementation changes, always re-read the source file at the referenced line numbers — code may have evolved since this snapshot.
