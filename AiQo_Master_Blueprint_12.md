# AiQo Master Blueprint 12

> **Generated**: 2026-04-08 | **Source of Truth**: Codebase audit of every `.swift` file, `.xcconfig`, `.plist`, and `.xcprivacy` in the repository. Every claim below includes an exact file path and line number. Nothing is assumed from Blueprint 11.

---

## 1. Executive Summary & Status

| Metric | Value |
|---|---|
| **Total Swift LOC** | **105,365** across **421 files** |
| **Main App (AiQo target)** | 97,848 LOC / 376 files |
| **Watch App** | 4,404 LOC / 25 files |
| **Widgets (iOS + watchOS)** | 1,822 LOC / 12 files |
| **Tests** | 540 LOC / 8 files |
| **Xcode Targets** | 10 (iOS app, Watch app, 2 widget extensions, Live Activity extension, 5 test targets) |
| **SPM Dependencies** | 3 direct (SDWebImage, SDWebImageSwiftUI, supabase-swift) + 7 transitive |
| **Vendored Frameworks** | SpotifyiOS.framework (binary) |
| **Localizations** | Arabic (primary), English |
| **Minimum Deployment** | iOS 17+ (FoundationModels features require iOS 26+) |

### Readiness Assessment

| Milestone | Readiness | Blockers |
|---|---|---|
| **TestFlight (Internal)** | **~88%** | P0: Hardcoded Supabase credentials in Info.plist; thin test coverage |
| **TestFlight (Public)** | **~82%** | P0s above + P1: no remote analytics, deep link gaps, Watch goal hardcoding |
| **App Store V1** | **~75%** | All above + Apple review: HealthKit justification strings, privacy nutrition labels, Tribe code presence despite being hidden |

### Top 3 Immediate Blockers

1. **Hardcoded Supabase Credentials** -- `AiQo/Info.plist` contains a fallback JWT and URL in plain text despite the `.xcconfig` migration. These will be visible in the IPA binary.
2. **Test Coverage Gap** -- 540 LOC of tests for 97,848 LOC of app code (~0.55%). Critical paths (BrainOrchestrator routing, PrivacySanitizer PII redaction, StoreKit entitlement logic) have zero automated tests.
3. **No Remote Analytics Provider** -- `AnalyticsService` (`AiQo/Services/Analytics/AnalyticsService.swift:17`) only registers `ConsoleAnalyticsProvider` (DEBUG) and `LocalAnalyticsProvider` (local JSONL). No data reaches any dashboard.

---

## 2. Project Topology & Folder Structure

### 2.1 Targets

| # | Target | Type | Notes |
|---|---|---|---|
| 1 | **AiQo** | iOS App | Main target, bundle `com.mraad500.aiqo` |
| 2 | **AiQoTests** | Unit Tests | 5 test files, 449 LOC |
| 3 | **AiQoUITests** | UI Tests | Declared in pbxproj, no test files found |
| 4 | **AiQoWidgetExtension** | iOS Widget | Home screen widget + Lock screen |
| 5 | **AiQoWatch Watch App** | watchOS App | Standalone workout + health companion |
| 6 | **AiQoWatch Watch AppTests** | Unit Tests | 1 file, 17 LOC |
| 7 | **AiQoWatch Watch AppUITests** | UI Tests | 2 files, 74 LOC |
| 8 | **AiQoWorkoutLiveAttributesExtension** | Live Activity | Workout Live Activity on Dynamic Island |
| 9 | **Watch Widget Extension** | watchOS Widget | Watch face complication |
| 10 | *(AiQoWatchWidget)* | watchOS Widget Bundle | Widget bundle wrapper |

### 2.2 Directory Map

```
AiQo/
  App/                          # AppDelegate, SceneDelegate, auth flow, tab routing
    AppDelegate.swift           # @main entry, service bootstrapping
    SceneDelegate.swift         # AppFlowController onboarding state machine
    MainTabRouter.swift         # 3-tab router (Home/Gym/Captain)
    MainTabScreen.swift         # SwiftUI TabView host
    AuthFlowUI.swift            # Glassmorphism auth design components
    AppRootManager.swift        # Captain deep-link coordinator
    LoginViewController.swift   # Supabase Auth UI
    ProfileSetupView.swift      # Post-login profile form
    LanguageSelectionView.swift # AR/EN picker
    MealModels.swift            # Shared meal type definitions

  Core/
    Colors.swift, Constants.swift, DailyGoals.swift, HapticEngine.swift
    CaptainMemory.swift         # SwiftData @Model for memory entries
    CaptainVoiceService.swift   # ElevenLabs TTS + AVSpeech fallback
    CaptainVoiceAPI.swift       # ElevenLabs HTTP transport
    CaptainVoiceCache.swift     # SHA256-keyed MP3 cache actor
    MemoryStore.swift           # Memory CRUD + prompt context builder
    MemoryExtractor.swift       # Rule-based + LLM memory extraction
    HealthKitMemoryBridge.swift # HK -> MemoryStore sync
    StreakManager.swift          # Daily streak tracking
    UserProfileStore.swift       # User profile persistence
    AppSettingsStore.swift       # App settings persistence
    SmartNotificationScheduler.swift
    SpotifyVibeManager.swift     # Spotify AppRemote integration
    VibeAudioEngine.swift        # Bio-frequency audio generator
    AiQoAudioManager.swift       # Audio session coordinator
    SiriShortcutsManager.swift   # 8 Siri intents
    Localization/               # Bundle+Language, LocalizationManager
    Models/                     # ActivityNotification, LevelStore, NotificationPreferencesStore
    Purchases/                  # EntitlementStore, PurchaseManager, ReceiptValidator, SubscriptionProductIDs, SubscriptionTier
    Utilities/                  # ConnectivityDebugProviding, DebugPrint

  DesignSystem/
    AiQoColors.swift, AiQoTheme.swift, AiQoTokens.swift
    Components/                 # AiQoBottomCTA, AiQoCard, AiQoChoiceGrid, AiQoPillSegment, etc.
    Modifiers/                  # AiQoPressEffect, AiQoShadow, AiQoSheetStyle

  Features/
    Captain/                    # 20 files -- AI chat, brain orchestration, prompt building
    DataExport/                 # HealthDataExporter
    First screen/               # LegacyCalculationViewController (UIKit legacy)
    Gym/                        # Workout sessions, Zone 2, exercises, quests, vision coach
      Club/                     # Body, Challenges, Impact, Plan sub-sections
      QuestKit/                 # Quest engine, evaluator, SwiftData models
      Quests/                   # Quest UI, VisionCoach (camera push-up counter)
      T/                        # SpinWheel, WorkoutTheme
    Home/                       # HomeView, DailyAura, water tracking, stat cards, vibe controls
    Kitchen/                    # Meal planning, fridge scanner, camera, recipe cards
    LegendaryChallenges/        # Record projects, HRR assessment, weekly review
    MyVibe/                     # Bio-frequency + Spotify orchestration
    Onboarding/                 # Feature intro, historical health sync
    Profile/                    # Profile screen, level card
    ProgressPhotos/             # Photo store + gallery
    Sleep/                      # Smart Wake, Apple Intelligence sleep agent, alarm setup
    Tribe/                      # TribeView, TribeExperienceFlow (HIDDEN for V1)
    WeeklyReport/               # AI-powered weekly health summary

  Frameworks/
    SpotifyiOS.framework        # Vendored Spotify SDK binary

  Premium/
    AccessManager.swift         # Feature gating by tier
    EntitlementProvider.swift    # StoreKit/Preview entitlement abstraction
    FreeTrialManager.swift      # 7-day Keychain-persisted trial
    PremiumPaywallView.swift    # Thin wrapper
    PremiumStore.swift          # 3-plan store (Core/Pro/IntelligencePro)

  Resources/
    Assets.xcassets             # Images, audio datasets, color sets
    Prompts.xcstrings           # Localized AI prompts
    achievements_spec.json      # Achievement definitions
    ar.lproj/, en.lproj/       # Localizable.strings, InfoPlist.strings
    AiQo.storekit              # StoreKit configuration file

  Services/
    Analytics/                  # AnalyticsService, AnalyticsEvent, ConsoleProvider, LocalProvider
    CrashReporting/             # CrashReporter, CrashReportingService (Crashlytics placeholder)
    Notifications/              # NotificationService, SmartNotificationManager, InactivityTracker, etc.
    Permissions/HealthKit/      # HealthKitService actor (1,006 LOC)
    DeepLinkRouter.swift        # aiqo:// and universal link routing
    NetworkMonitor.swift        # NWPathMonitor wrapper
    SupabaseService.swift       # Profile CRUD, auth, device tokens
    SupabaseArenaService.swift  # Tribe/Arena CRUD (1,362 LOC)
    ReferralManager.swift       # Referral codes, trial extension

  Shared/
    CoinManager.swift           # In-app currency
    HealthKitManager.swift      # HK authorization, background observer, coin mining
    LevelSystem.swift           # Shield tier mapping
    WorkoutSyncCodec.swift      # Watch <-> Phone serialization
    WorkoutSyncModels.swift     # Sync DTOs

  Tribe/                        # Galaxy, Arena, Log, Models, Stores, Views (HIDDEN for V1)
  UI/                           # Shared UI: PaywallView, GlassCardView, OfflineBanner, etc.

  PhoneConnectivityManager.swift  # WCSession + HK mirroring (1,009 LOC)
  XPCalculator.swift              # Coin/XP formulas
  NeuralMemory.swift              # Additional memory utilities
  ProtectionModel.swift           # Data protection model

AiQoWatch Watch App/
  AiQoWatchApp.swift            # @main entry + AppDelegate
  WorkoutManager.swift          # HKWorkoutSession + HKLiveWorkoutBuilder (1,344 LOC)
  WatchConnectivityManager.swift # WCSession delegate
  Services/                     # WatchConnectivityService, WatchHealthKitManager, WatchWorkoutManager
  Views/                        # WatchHomeView, WatchActiveWorkoutView, WatchWorkoutListView, WatchWorkoutSummaryView
  Shared/                       # WorkoutSyncCodec, WorkoutSyncModels (mirrored from main app)
  Design/                       # WatchDesignSystem
  Models/                       # WatchWorkoutType

AiQoWidget/                     # iOS widget: provider, entry, views, Live Activity
AiQoWatchWidget/                # watchOS widget: provider, widget, bundle

Configuration/
  AiQo.xcconfig                 # Disables explicit modules; #include? Secrets.xcconfig
  Secrets.template.xcconfig     # 10 secret key placeholders
  SETUP.md                      # Setup instructions
  ExternalSymbols/              # SpotifyiOS dSYM
```

### 2.3 SPM Dependencies

| Package | Version | Role |
|---|---|---|
| **SDWebImage** | 5.21.6 | Async image loading & caching |
| **SDWebImageSwiftUI** | 3.1.4 | SwiftUI `WebImage` wrapper |
| **supabase-swift** | 2.36.0 | Auth, Realtime, PostgREST, Storage, Functions |
| swift-crypto | 4.2.0 | *(transitive)* |
| swift-concurrency-extras | 1.3.2 | *(transitive)* |
| swift-clocks | 1.0.6 | *(transitive)* |
| swift-asn1 | 1.5.0 | *(transitive)* |
| swift-http-types | 1.4.0 | *(transitive)* |
| swift-system | 1.6.4 | *(transitive)* |
| xctest-dynamic-overlay | 1.7.0 | *(transitive)* |

**Vendored:** `SpotifyiOS.framework` under `AiQo/Frameworks/`

---

## 3. The Backbone (Architecture Map)

### 3.1 App Lifecycle & Routing

```
AiQoApp (@main)
  |-- ModelContainer (captain_memory.store) .... SwiftData for CaptainMemory
  |-- ModelContainer (default.store) ........... SwiftData for RecordProject, QuestProgress, etc.
  |-- AppDelegate
  |     |-- didFinishLaunching: boots 15+ services
  |     |-- applicationDidBecomeActive: refreshes health, widget, analytics
  |     |-- applicationDidEnterBackground: schedules smart notifications
  |     \-- userNotificationCenter: routes tapped notifications
  \-- AppFlowController (singleton)
        |-- RootScreen state machine:
        |     languageSelection -> login -> profileSetup -> featureIntro -> main
        |-- resolveCurrentScreen(): reads 5 UserDefaults keys + Supabase session
        \-- AppRootView: switches View based on currentScreen
              \-- MainTabScreen (3 tabs: Home / Gym / Captain)
```

**Key files:**
- `AiQo/App/AppDelegate.swift:93` -- `AppDelegate` class, service bootstrapping at line 95
- `AiQo/App/SceneDelegate.swift:17` -- `AppFlowController`, onboarding state at line 171
- `AiQo/App/MainTabRouter.swift:6` -- `MainTabRouter`, 3-tab enum at line 9
- `AiQo/App/MainTabScreen.swift:5` -- `MainTabScreen` SwiftUI view

### 3.2 Brain Orchestrator (AI Routing Engine)

```
User Message
     |
     v
CaptainViewModel.sendMessage()
     |
     v
BrainOrchestrator.processMessage()
     |
     |--- route(for: screenContext) --->  .sleepAnalysis ? LOCAL : CLOUD
     |
     |--- interceptSleepIntent() ------> detects sleep keywords in ANY screen,
     |                                    rewrites to .sleepAnalysis -> LOCAL
     |
     +--- CLOUD PATH:
     |      CloudBrainService.generateReply()
     |        1. MemoryStore.buildCloudSafeContext(maxTokens: 400)
     |        2. PrivacySanitizer.sanitizeForCloud()
     |           - Truncate to last 4 messages
     |           - Redact 8 PII patterns (email, phone, UUID, @mentions, URLs, card numbers, IPs, tokens)
     |           - Replace "my name is X" -> "User"
     |           - Bucket health data (steps/50, calories/10)
     |           - Strip EXIF/GPS from kitchen images
     |        3. HybridBrainService.generateReply()
     |           - Model: gemini-flash-latest
     |           - Endpoint: generativelanguage.googleapis.com
     |           - System prompt: CaptainPromptBuilder.build() (6 layers)
     |           - maxOutputTokens: 600 (chat/vibe/sleep) or 900 (gym/kitchen/peaks)
     |           - Temperature: 0.7
     |           - Response: LLMJSONParser.decode() -> CaptainStructuredResponse
     |
     +--- LOCAL PATH:
     |      LocalBrainService.generateReply()
     |        1. AppleIntelligenceSleepAgent.analyze() (iOS 26+ FoundationModels)
     |        2. Deterministic fallbacks: 5 workout modes x 2 langs, 3 meal styles x 2 langs
     |        3. CaptainOnDeviceChatEngine (8-second timeout)
     |
     +--- FALLBACK CHAIN:
     |      Cloud fails -> check if Apple Intelligence viable
     |        Yes -> LocalBrainService attempt
     |        No  -> makeNetworkErrorReply (deterministic)
     |      Sleep local fails (.modelUnavailable) -> cloud with aggregated summary
     |        Cloud also fails -> makeComputedSleepReply (fully deterministic, no AI)
     |
     v
CaptainPersonaBuilder.sanitizeResponse()  -- strips 14 banned AI phrases
     |
     v
PrivacySanitizer.injectUserName()  -- replaces [USER_NAME] / {{userName}} with real name
     |
     v
MemoryExtractor.extract()  -- rule-based (every msg) + LLM-based (every 3rd msg)
     |
     v
Streamed to UI via simulated chunking (24 chars, 16ms delay)
```

**Key files & lines:**
- `AiQo/Features/Captain/BrainOrchestrator.swift:11` -- `BrainOrchestrator` struct
  - Routing switch: line 84-91
  - Sleep intent interception: lines 96-110
  - Cloud fallback chain: lines 164-193
  - Sleep fallback chain: lines 128-159
  - Simulated streaming: lines 424-448
- `AiQo/Features/Captain/CloudBrainService.swift:11` -- privacy wrapper around HybridBrainService
- `AiQo/Features/Captain/HybridBrainService.swift:151` -- Gemini HTTP transport
  - Model config: line 87 (`gemini-flash-latest`)
  - Token limits: lines 292-294
- `AiQo/Features/Captain/LocalBrainService.swift:62` -- on-device AI + deterministic fallbacks
  - Intent classification: lines 220-253
  - Deterministic workout plans: lines 455-563
  - On-device timeout: line 402 (8 seconds)
- `AiQo/Features/Captain/PrivacySanitizer.swift:14` -- PII redaction & data bucketing
  - 8 regex rules: lines 32-73
  - Conversation truncation: line 22 (`maxConversationMessages = 4`)
  - EXIF stripping: lines 177-211
- `AiQo/Features/Captain/CaptainPromptBuilder.swift:11` -- 6-layer system prompt
- `AiQo/Features/Captain/LLMJSONParser.swift:11` -- robust JSON recovery pipeline

### 3.3 The 6-Layer Prompt Architecture

Built in `CaptainPromptBuilder.build()` (`AiQo/Features/Captain/CaptainPromptBuilder.swift:13`):

| Layer | Lines | Content |
|---|---|---|
| **1 - Identity** | 30-133 | Captain Hamoudi persona: Iraqi Baghdad dialect (AR) or casual direct (EN). 6 behavioral rules, variable masking, banned phrases, response length rules, name usage rules |
| **2 - Memory** | 137-147 | `userProfileSummary` from MemoryStore injected as background knowledge |
| **3 - Bio-State** | 151-188 | HealthKit metrics (steps, calories, level, sleep, HR, time, growth) marked "NEVER output to user" |
| **4 - Circadian Tone** | 192-206 | `BioTimePhase` tone directive (awakening/energy/focus/recovery/zen) adapted by hour + sleep quality + activity |
| **5 - Screen Context** | 210-269 | Per-screen behavior rules (mainChat, gym, kitchen, sleepAnalysis, peaks, myVibe) |
| **6 - Output Contract** | 274-328 | Strict JSON schema: `message`, `quickReplies` (2-3, max 25 chars), `workoutPlan`, `mealPlan`, `spotifyRecommendation`. Language lock enforced |

### 3.4 Arabic Pipeline (CoachBrainMiddleware)

For Arabic messages routed through the on-device path (`AiQo/Features/Captain/CoachBrainMiddleware.swift:225`):

```
Arabic user message
  |-- Phase 1: .reading
  |-- Phase 2: .translatingInput  --> Gemini translates AR -> EN
  |-- Phase 3: .thinking          --> Apple Intelligence on-device (EN)
  |-- Phase 4: .translatingOutput --> Gemini translates EN -> Iraqi AR
  |-- Phase 5: .preparingReply    --> final response
```

- Local intent detection (line 613-675) bypasses the full pipeline for greetings, health overview, time/date, AiQo explanation, recovery, nutrition, workout, stress queries with deterministic Iraqi Arabic replies.
- Translation uses `CoachBrainTranslationConfig` (`AiQo/Features/Captain/CoachBrainTranslationConfig.swift:23`): Gemini `gemini-3-flash-preview`, temperature 0.2, maxOutputTokens 180, timeout 25s.

---

## 4. Feature Complete Inventory

| Feature | Status | Key Files | Notes |
|---|---|---|---|
| **Home Dashboard** | **Shipped** | `Features/Home/HomeView.swift`, `HomeViewModel.swift` (948 LOC) | 6 metric cards, daily aura rings, water bottle, streak badge, vibe controls |
| **Daily Aura** | **Shipped** | `Features/Home/DailyAuraViewModel.swift:1` | Steps + calories ring animation, 14-day history in UserDefaults |
| **Water Tracking** | **Shipped** | `Features/Home/HealthKitService+Water.swift`, `WaterDetailSheetView.swift` | Reads/writes `HKQuantityType.dietaryWater`, syncs to Watch via app group |
| **Streak System** | **Shipped** | `Core/StreakManager.swift:1` | Criteria: 5000+ steps OR 300+ kcal OR workout. 30-day history, motivational messages |
| **Captain Hamoudi Chat** | **Shipped** | `Features/Captain/` (20 files) | Cloud (Gemini) + Local (Apple Intelligence) + Hybrid with full fallback chain |
| **Captain Memory** | **Shipped** | `Core/CaptainMemory.swift`, `MemoryStore.swift`, `MemoryExtractor.swift` | SwiftData model, confidence scoring, access counting, 90-day stale cleanup, tier-gated cap (200/500) |
| **Captain Voice** | **Shipped** | `Core/CaptainVoiceService.swift`, `CaptainVoiceAPI.swift`, `CaptainVoiceCache.swift` | ElevenLabs TTS -> AVSpeech fallback. 13 pre-cached Iraqi Arabic phrases. Workout coaching uses on-device FoundationModels |
| **Gym / Workouts** | **Shipped** | `Features/Gym/LiveWorkoutSession.swift` (886 LOC), `WorkoutSessionViewModel.swift` | Watch-mirrored sessions, pause/resume/end, Live Activity, distance milestones, ambient audio |
| **Zone 2 Coaching** | **Shipped** | `Features/Gym/HandsFreeZone2Manager.swift:8` | SFSpeechRecognizer (on-device) -> AI -> CaptainVoiceService TTS. HR zone evaluation at line 557 of LiveWorkoutSession |
| **Vision Coach (Push-ups)** | **Shipped** | `Features/Gym/Quests/VisionCoach/VisionCoachView.swift`, `VisionCoachViewModel.swift` | Camera-based rep counting |
| **Quest System** | **Shipped** | `Features/Gym/QuestKit/` (10 files) | QuestEngine, QuestEvaluator, SwiftData persistence, camera permission gate |
| **XP & Leveling** | **Shipped** | `XPCalculator.swift:1`, `Shared/LevelSystem.swift:1`, `Shared/CoinManager.swift` | 100 steps/coin, 50 kcal/coin, HR turbo bonus. 7 shield tiers (wood -> master), 5 levels per tier |
| **Sleep Architecture** | **Shipped** | `Features/Sleep/` (8 files) | Apple Intelligence sleep analysis, Smart Wake cycle calculator (90-min cycles), alarm scheduling, sleep score ring |
| **Smart Wake** | **Shipped** | `Features/Sleep/SmartWakeEngine.swift:1` | Sleep cycle alignment, 3 window sizes (10/20/30 min), confidence scoring (0.18-0.99), bedtime alignment |
| **Alchemy Kitchen** | **Shipped** | `Features/Kitchen/` (22 files) | Meal planning, fridge scanner (camera), recipe cards, nutrition tracker, ingredient catalog, plate templates |
| **Smart Fridge Scanner** | **Shipped** | `Features/Kitchen/SmartFridgeScannerView.swift`, `SmartFridgeCameraViewModel.swift` | Camera -> AI ingredient detection -> inventory |
| **My Vibe** | **Shipped** | `Features/MyVibe/` (5 files) | VibeOrchestrator: bio-frequency audio + Spotify playlists. 5 states synced to BioTimePhase |
| **Spotify Integration** | **Shipped** | `Core/SpotifyVibeManager.swift`, `Features/Gym/SpotifyWorkoutPlayerView.swift` | AppRemote SDK, playlist curation, workout player. URL schemes: `aiqo-spotify` |
| **Legendary Challenges** | **Shipped** | `Features/LegendaryChallenges/` (14 files) | Record projects (strength/cardio/endurance/clarity), weekly review, SwiftData migration from UserDefaults |
| **HRR Assessment** | **Shipped** | `Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift:1` | Watch-based HR step test, peak HR tracking, recovery levels (excellent/good/needsWork) |
| **Weekly Report** | **Shipped** | `Features/WeeklyReport/` (4 files) | AI-generated summary, share card renderer |
| **Progress Photos** | **Shipped** | `Features/ProgressPhotos/ProgressPhotoStore.swift`, `ProgressPhotosView.swift` | Photo gallery with timeline |
| **Onboarding** | **Shipped** | `Features/Onboarding/FeatureIntroView.swift`, `OnboardingWalkthroughView.swift`, `HistoricalHealthSyncEngine.swift` | 6-screen flow: language -> login -> profile -> feature intro -> permissions -> main |
| **Tribe (Emara)** | **Hidden** | `Tribe/` (38 files), `Features/Tribe/` (3 files) | Galaxy view, Arena challenges, leaderboards, hall of fame, tribe CRUD. **Hidden via 3 Info.plist flags** (`TRIBE_FEATURE_VISIBLE=false`, etc.). 5 TODOs for replacing mock data with live Supabase calls |
| **Data Export** | **Shipped** | `Features/DataExport/HealthDataExporter.swift` | CSV/JSON health data export |
| **Notifications (Smart)** | **Shipped** | `Services/Notifications/` (7 files) | AI-powered inactivity, water, meal, step goal, sleep, morning habit notifications |
| **Live Activity** | **Shipped** | `Features/Gym/WorkoutLiveActivityManager.swift`, `AiQoWidget/AiQoWidgetLiveActivity.swift` | Dynamic Island workout display |
| **Siri Shortcuts** | **Shipped** | `Core/SiriShortcutsManager.swift` | 8 intents: startWalk, startRun, startHIIT, openCaptain, todaySummary, logWater, openKitchen, weeklyReport |

---

## 5. Captain Hamoudi System (AI Layer)

### 5.1 Brain Services

| Service | File | Role |
|---|---|---|
| `BrainOrchestrator` | `Features/Captain/BrainOrchestrator.swift:11` | Routes requests to local or cloud; manages fallback chain |
| `CloudBrainService` | `Features/Captain/CloudBrainService.swift:11` | Privacy wrapper: fetches cloud-safe memories (maxTokens 400), sanitizes request, delegates to HybridBrainService |
| `HybridBrainService` | `Features/Captain/HybridBrainService.swift:151` | Gemini HTTP transport (`gemini-flash-latest`, temperature 0.7, timeout 35s) |
| `LocalBrainService` | `Features/Captain/LocalBrainService.swift:62` | On-device: Apple Intelligence sleep agent, deterministic fallbacks, CaptainOnDeviceChatEngine (8s timeout) |
| `LocalIntelligenceService` | `Features/Captain/LocalIntelligenceService.swift:22` | Simpler local path routing by screen context |
| `CaptainOnDeviceChatEngine` | `Features/Captain/CaptainOnDeviceChatEngine.swift:29` | Actor using iOS 26+ `FoundationModels` (`LanguageModelSession`) with live HealthKit injection |
| `CoachBrainMiddleware` | `Features/Captain/CoachBrainMiddleware.swift:225` | 5-phase Arabic pipeline: AR -> translate -> on-device AI -> translate -> Iraqi AR |
| `CaptainIntelligenceManager` | `Features/Captain/CaptainIntelligenceManager.swift:73` | Legacy intelligence manager, automatic routing (Arabic -> Arabic API, English -> on-device) |

### 5.2 Memory System

**Model:** `CaptainMemory` (`AiQo/Core/CaptainMemory.swift:6`) -- SwiftData `@Model`
- **Fields:** id, category, key (unique), value, confidence (0.0-1.0), source, createdAt, updatedAt, accessCount
- **Categories:** identity, goal, body, preference, mood, injury, nutrition, workout_history, sleep, insight, active_record_project
- **Sources:** user_explicit, extracted, healthkit, inferred, llm_extracted

**Store:** `MemoryStore` (`AiQo/Core/MemoryStore.swift:8`) -- `@MainActor`, `@Observable`, singleton
- **Cap:** `AccessManager.shared.captainMemoryLimit` -- 200 (default) / 500 (Intelligence Pro) (`AiQo/Premium/AccessManager.swift:56`)
- **Eviction:** When full, removes lowest-confidence non-project memory (line 57-63)
- **Prompt context:** Up to 5 active_record_project + 30 other memories, estimated at chars/4 tokens, max 800 tokens (line 127-167)
- **Cloud-safe context:** Only goal/preference/mood/injury/nutrition/insight categories, max 400 tokens, max 15 memories (line 170-201)
- **Stale cleanup:** Removes memories >90 days with confidence <0.3 (line 204-223)
- **Chat history:** Max 200 persisted, fetch limit 50, auto-trim oldest (line 275-434)

**Extraction:** `MemoryExtractor` (`AiQo/Core/MemoryExtractor.swift:5`)
- **Rule-based** (every message, line 42-179): Regex for weight, height, age, injuries, goals, sleep hours, user name
- **LLM-based** (every 3rd message, line 184-286): Sanitized text (max 240 chars) -> Gemini (maxOutputTokens 160, temperature 0.1) -> 16-field whitelist

**HealthKit Bridge:** `HealthKitMemoryBridge` (`AiQo/Core/HealthKitMemoryBridge.swift:6`)
- Syncs: body weight, resting HR, 7-day avg steps, 7-day avg calories, 7-day avg sleep hours

### 5.3 Voice Pipeline

**Service:** `CaptainVoiceService` (`AiQo/Core/CaptainVoiceService.swift:11`)

```
Text -> sanitize (strip *, collapse whitespace)
  -> check CaptainVoiceCache (SHA256 filename)
    -> HIT: play cached MP3
    -> MISS: CaptainVoiceAPI (ElevenLabs)
      -> SUCCESS: cache + play
      -> FAIL: AVSpeechSynthesizer fallback
```

**ElevenLabs config** (`AiQo/Core/CaptainVoiceAPI.swift:3`):
- Provider: `https://api.elevenlabs.io/v1/text-to-speech` (line 8)
- Model: `eleven_multilingual_v2` (line 9)
- Voice settings: stability 0.34, similarityBoost 0.88, style 0.18, speakerBoost true (lines 97-102)
- Output: MP3 44100Hz 128kbps, timeout 30s

**Cache:** `CaptainVoiceCache` actor (`AiQo/Core/CaptainVoiceCache.swift:39`)
- 13 pre-cached Iraqi Arabic phrases across 5 categories: movement (4), water (2), food (3), sleep (2), motivation (2) (lines 7-35)
- SHA256-based filenames in `Documents/HamoudiVoiceCache/`
- Pre-caching: 500ms rate limiting, aborts after 2 consecutive failures

**AVSpeech fallback** (`AiQo/Core/CaptainVoiceService.swift:121-128`):
- Arabic rate: 0.44, English rate: 0.48, pitch: 0.96
- Voice preference: ar-SA/ar-AE for Arabic, en-US/en-GB for English

**Live workout coaching** (`AiQo/Core/CaptainVoiceService.swift:261-311`):
- Generates Zone 2 coaching cues using Apple FoundationModels on-device
- Fallback: hardcoded Iraqi Arabic phrases based on HR vs zone bounds

### 5.4 Localization Rules

- **Language detection:** Arabic text detection triggers Arabic API or CoachBrainMiddleware pipeline
- **Dialect enforcement:** Post-processing replaces non-Iraqi Arabic words with Iraqi equivalents (`CaptainOnDeviceChatEngine.swift:213-228`): e.g., "عشان" -> "حتى", "هلأ" -> "هسه"
- **Banned phrases:** 14 phrases in both Arabic and English stripped from all responses (`CaptainPersonaBuilder.swift:9-24`)
- **Prompt language lock:** Layer 6 of system prompt enforces language match (line 274-328)

---

## 6. Monetization & StoreKit 2

### 6.1 Subscription Tiers

Defined in `AiQo/Core/Purchases/SubscriptionProductIDs.swift`:

| Tier | Product ID | Fallback Price |
|---|---|---|
| **Core** | `com.mraad500.aiqo.standard.monthly` (line 6) | $9.99/mo |
| **Pro** | `com.mraad500.aiqo.pro.monthly` (line 7) | $19.99/mo |
| **Intelligence Pro** | `com.mraad500.aiqo.intelligencepro.monthly` (line 8) | $39.99/mo |

Legacy IDs preserved at lines 12-13 for older installs.

### 6.2 Feature Gating

`AccessManager` (`AiQo/Premium/AccessManager.swift:27`):

| Feature Gate | Free | Core | Pro | Intelligence Pro |
|---|---|---|---|---|
| `canAccessCaptain` | Trial only | Yes | Yes | Yes |
| `canAccessGym` | Trial only | Yes | Yes | Yes |
| `canAccessKitchen` | Trial only | Yes | Yes | Yes |
| `canAccessMyVibe` | Trial only | Yes | Yes | Yes |
| `canAccessChallenges` | No | No | Yes | Yes |
| `canAccessDataTracking` | No | No | Yes | Yes |
| `canAccessPeaks` | No | No | Yes | Yes |
| `canAccessHRRAssessment` | No | No | Yes | Yes |
| `canAccessWeeklyAIWorkoutPlan` | No | No | Yes | Yes |
| `canAccessRecordProjects` | No | No | Yes | Yes |
| `canAccessExtendedMemory` | No | No | No | Yes |
| `canAccessIntelligenceModel` | No | No | No | Yes |
| `captainMemoryLimit` | 200 | 200 | 200 | 500 |

### 6.3 Free Trial

`FreeTrialManager` (`AiQo/Premium/FreeTrialManager.swift:1`):
- **Duration:** 7 days (line 12)
- **Persistence:** Keychain (survives reinstall) + UserDefaults (fast access) (line 35-50)
- **Referral extension:** 3 bonus days per referral, max 30 bonus days (`AiQo/Services/ReferralManager.swift:12-13`)

### 6.4 StoreKit 2 Implementation

`PurchaseManager` (`AiQo/Core/Purchases/PurchaseManager.swift:1`):
- Full StoreKit 2: `Product.products(for:)`, `product.purchase()`, `Transaction.updates`, `AppStore.sync()`
- Product loading with 2 retry attempts (line 72)
- Entitlement rebuild from all verified transactions (line 219)
- Receipt validation via Supabase Edge Function (line 176)

`ReceiptValidator` (`AiQo/Core/Purchases/ReceiptValidator.swift:1`):
- Endpoint: `https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/validate-receipt` (line 10)
- Posts: transactionId, productId, purchaseDate, expiresDate

### 6.5 Paywall UI

`PaywallView` (`AiQo/UI/Purchases/PaywallView.swift:1`) -- 1,025 LOC:
- 3-tier glassmorphism cards with feature comparison
- Arabic/English with RTL layout switching
- Free trial messaging in CTA
- Debug diagnostics section (DEBUG builds only)

---

## 7. HealthKit & Privacy

### 7.1 HealthKit Data Types

**Read Types** (`AiQo/Services/Permissions/HealthKit/HealthKitService.swift:45-60`):

| HKQuantityType | Usage |
|---|---|
| `stepCount` | Home dashboard, streak, XP, notifications |
| `heartRate` | Live workout, Zone 2 coaching, HRR assessment |
| `restingHeartRate` | Captain context, memory bridge |
| `heartRateVariabilitySDNN` | Health overview |
| `walkingHeartRateAverage` | Health overview |
| `activeEnergyBurned` | Home dashboard, streak, XP |
| `distanceWalkingRunning` | Workout sessions, home dashboard |
| `dietaryWater` | Water tracking, home dashboard |
| `vo2Max` | Health overview |

| HKCategoryType | Usage |
|---|---|
| `sleepAnalysis` | Sleep architecture, Smart Wake, Captain context |

| HKObjectType | Usage |
|---|---|
| `appleStandHour` | Home dashboard |
| `workoutType` | Workout history, weekly report |

**Write Types** (`AiQo/Services/Permissions/HealthKit/HealthKitService.swift:77-99`):

| Type | Usage |
|---|---|
| `dietaryWater` | Water logging from Home |
| `heartRate` | Manual HR samples |
| `restingHeartRate` | Manual entry |
| `heartRateVariabilitySDNN` | Manual entry |
| `vo2Max` | Manual entry |
| `distanceWalkingRunning` | Workout sessions |
| `workoutType` | Workout sessions via HKWorkoutBuilder |

### 7.2 Background Delivery

`HealthKitManager` (`AiQo/Shared/HealthKitManager.swift:169`):
- **HKObserverQuery** for `stepCount` with `.hourly` background delivery frequency
- 60-second throttle between processing cycles (line 179)
- On update: refreshes published properties, reloads widget, awards coins

`MorningHabitOrchestrator` (`AiQo/Services/Notifications/MorningHabitOrchestrator.swift:155`):
- **HKObserverQuery** for `stepCount` with `.hourly` delivery
- Monitors steps after wake time for morning insight generation

### 7.3 Privacy Manifest

`AiQo/PrivacyInfo.xcprivacy`:
- `NSPrivacyTracking` = **false** (line 6)
- `NSPrivacyTrackingDomains` = empty array (line 8)
- **Accessed API:** UserDefaults (reason CA92.1)
- **Collected data types:**
  - Fitness data: linked to user, not tracking, app functionality
  - Health data: linked to user, not tracking, app functionality

### 7.4 API Key Management

**Configuration:** `Configuration/AiQo.xcconfig` includes `Secrets.xcconfig` (gitignored)

**Secrets template** (`Configuration/Secrets.template.xcconfig`) defines 10 keys:
```
CAPTAIN_API_KEY=            # Gemini API key for Captain chat
COACH_BRAIN_LLM_API_KEY=    # Gemini key for CoachBrain translation
COACH_BRAIN_LLM_API_URL=    # Gemini endpoint URL
CAPTAIN_VOICE_API_KEY=      # ElevenLabs TTS API key
CAPTAIN_VOICE_API_URL=      # ElevenLabs endpoint
CAPTAIN_VOICE_MODEL_ID=     # ElevenLabs model
CAPTAIN_VOICE_VOICE_ID=     # ElevenLabs voice ID
SPOTIFY_CLIENT_ID=          # Spotify AppRemote client ID
SUPABASE_URL=               # Supabase project URL
SUPABASE_ANON_KEY=          # Supabase anonymous key
```

**Resolution chain** (used throughout):
1. Environment variable (for CI/testing)
2. Info.plist value (injected from xcconfig at build time)
3. Rejects unresolved `$(...)` xcconfig placeholders

**BLOCKER:** `AiQo/Info.plist` still contains hardcoded Supabase URL (`https://zidbsrepqpbucqzxnwgk.supabase.co`) and a hardcoded JWT anon key as fallback values. These are visible in the compiled binary.

---

## 8. Backend (Supabase) Integration

### 8.1 Supabase Client

`SupabaseService` (`AiQo/Services/SupabaseService.swift:1`):
- URL + anon key resolved from `K.Supabase` constants
- **Auth:** Supabase Auth (email/password, session management)
- **Tables accessed:** `profiles` (search, load, update device token)

### 8.2 Known Tables

| Table | Service | Operations |
|---|---|---|
| `profiles` | `SupabaseService` | Search (ilike), load, update device_token |
| `arena_tribe_participations` | `SupabaseArenaService` | Global leaderboard fetch |
| `tribes` | `SupabaseArenaService` | Create, read |
| `tribe_members` | `SupabaseArenaService` | Insert, read with profiles join |
| `weekly_challenges` | `SupabaseArenaService` | Challenge CRUD |

### 8.3 Edge Functions

| Function | Called From | Purpose |
|---|---|---|
| `validate-receipt` | `ReceiptValidator` (line 10) | Server-side StoreKit receipt validation |

### 8.4 Auth Flow

1. `LoginViewController` presents Supabase Auth UI
2. On success: `AppFlowController.didLoginSuccessfully()` advances to profile setup
3. Session persisted by supabase-swift SDK
4. `AppFlowController.resolveCurrentScreen()` checks `client.auth.currentSession` for auto-login
5. Logout: `supabase.auth.signOut()` + reset onboarding keys (except language)

### 8.5 Offline Handling

- `NetworkMonitor` (`AiQo/Services/NetworkMonitor.swift:7`) tracks connectivity via `NWPathMonitor`
- `OfflineBannerView` (`AiQo/UI/OfflineBannerView.swift`) displayed when offline
- Captain: `BrainOrchestrator` falls back to local/deterministic when cloud fails
- SupabaseArenaService: Uses SwiftData `ModelContext` for local persistence of Tribe data
- No explicit offline queue for Supabase writes (data loss risk for tribe actions while offline)

---

## 9. AiQoWatch Companion

### 9.1 Architecture

```
AiQoWatchApp (@main)
  |-- AppDelegate
  |     |-- applicationDidFinishLaunching: WatchConnectivityManager.shared
  |     |-- handle(_ workoutConfiguration:): receives from iPhone's startWatchApp()
  |     \-- handleUserActivity: parses workout type from user info
  |
  |-- WorkoutManager (singleton, 1344 LOC)
  |     |-- HKWorkoutSession + HKLiveWorkoutBuilder
  |     |-- Session mirroring to iPhone (watchOS 10+)
  |     |-- Snapshot pushing (throttled)
  |     |-- Recovery of active sessions
  |     \-- Widget update on completion
  |
  |-- WatchConnectivityManager (WCSession delegate)
  |     |-- sendWorkoutCompanionMessage (sendMessage + transferUserInfo fallback)
  |     |-- updateWorkoutSnapshotContext (applicationContext)
  |     |-- Haptic routing (rep detected, challenge completed)
  |     \-- Incoming: start requests, companion messages
  |
  \-- Views
        |-- WatchHomeView: Aura rings (steps/calories), 2x2 stats grid, distance bar
        |-- WatchWorkoutListView: Workout type picker
        |-- WatchActiveWorkoutView: Timer, HR, calories, distance, controls
        \-- WatchWorkoutSummaryView: Post-workout metrics
```

### 9.2 Key Files

| File | LOC | Role |
|---|---|---|
| `AiQoWatchApp.swift:46` | 234 | App entry, AppDelegate, non-watchOS stubs |
| `WorkoutManager.swift:17` | 1,344 | Workout engine: session, builder, mirroring, recovery |
| `WatchConnectivityManager.swift:15` | 234 | WCSession dual transport |
| `WatchHealthKitManager.swift:6` | 76 | Daily metrics + shared hydration |
| `WatchWorkoutManager.swift:10` | 156 | Bridge to WorkoutManager, Combine bindings |
| `WatchConnectivityService.swift:9` | 55 | Thin WCSession wrapper (partially duplicative) |

### 9.3 Health Integrations (Watch)

**Read:** stepCount, activeEnergyBurned, distanceWalkingRunning, heartRate, sleepAnalysis, workoutType
**Write:** workoutType (via HKWorkoutBuilder)
**Background:** workout-processing (WKBackgroundModes in `AiQoWatch-Watch-App-Info.plist`)

### 9.4 Phone <-> Watch Communication

| Direction | Mechanism | Data |
|---|---|---|
| Phone -> Watch | `healthStore.startWatchApp(with:)` | Start workout request |
| Phone -> Watch | WCSession `sendMessage` | Pause/resume/end commands, haptic events |
| Watch -> Phone | HK session mirroring (iOS 17+/watchOS 10+) | Full workout state |
| Watch -> Phone | WCSession `applicationContext` | Workout snapshots |
| Watch -> Phone | WCSession `sendMessage` / `transferUserInfo` | Companion messages, workout completed |
| Shared | App Group `group.aiqo` UserDefaults | Hydration data |

### 9.5 Known Issues

- **Duplicated workout completion sending:** Both `WatchWorkoutManager` (line 97-112) and `WatchConnectivityService` (line 35-53) can send `workout_completed` events, risking double XP awards
- **Hard-coded goals:** `WatchHomeView` uses 10,000 steps (line 24) and 800 calories (line 25) as literals instead of user-configured goals
- **Polling timer:** `WatchConnectivityService` polls reachability every 2 seconds (line 18) despite `WatchConnectivityManager` already having the `sessionReachabilityDidChange` delegate callback

---

## 10. Critical Blockers & Tech Debt

### P0 -- Must Fix Before App Store Submission

| # | Issue | File:Line | Impact |
|---|---|---|---|
| **P0-1** | **Hardcoded Supabase credentials in Info.plist** | `AiQo/Info.plist` (SUPABASE_URL, SUPABASE_ANON_KEY fallback values) | Credentials visible in IPA binary. Security risk. Must remove fallbacks and require xcconfig injection. |
| **P0-2** | **Near-zero test coverage** | `AiQoTests/` (449 LOC for 97,848 LOC app) | 0.55% coverage. Zero tests for BrainOrchestrator routing, PrivacySanitizer PII redaction, StoreKit entitlement logic, memory extraction. Any regression is undetectable. |
| **P0-3** | **HealthKit usage description in Arabic only** | `AiQo/Info.plist` (`NSAlarmKitUsageDescription` in Arabic) | Apple requires English usage descriptions. Missing English `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` in main Info.plist (only in localized InfoPlist.strings). Must verify all required keys have English base values. |
| **P0-4** | **Dead Tribe code ships in binary** | `Tribe/` (38 files), `Features/Tribe/` (3 files), `SupabaseArenaService.swift` (1,362 LOC) | Feature flags hide UI but code ships. Apple review may question unreachable code with network calls. Strip from target or use `#if` compilation flags. |

### P1 -- Should Fix Before Public TestFlight

| # | Issue | File:Line | Impact |
|---|---|---|---|
| **P1-1** | **No remote analytics** | `Services/Analytics/AnalyticsService.swift:17` | Only console + local file providers. No PostHog/Mixpanel/Firebase. Cannot track user behavior, conversion, or crashes in production. |
| **P1-2** | **Deep link gaps** | `Services/DeepLinkRouter.swift:52,57` | `settings` deep link navigates to home (not settings). `premium` deep link sets `pendingDeepLink` that nothing reads. |
| **P1-3** | **Duplicated workout completion events** | `WatchWorkoutManager.swift:97-112`, `WatchConnectivityService.swift:35-53` | Both send `workout_completed` to iPhone. Could cause double XP awards via `PhoneConnectivityManager.swift:754-759`. |
| **P1-4** | **Hard-coded Watch goals** | `WatchHomeView.swift:24-25` | 10,000 steps and 800 calories are literals. Should read from user settings / app group. |
| **P1-5** | **InactivityTracker default** | `Services/Notifications/InactivityTracker.swift:17` | New users who never call `markActive()` show 0 inactivity minutes. Inactivity notifications never fire until first `markActive()` call. |
| **P1-6** | **Duplicated onboarding check** | `App/AppDelegate.swift:131-136,178-183` | Same 5-key UserDefaults check copy-pasted. Should be a shared method. |
| **P1-7** | **Arabic-only notification bodies** | `Services/Notifications/NotificationService.swift:242,275,316,344,408-413` | Hard-coded Arabic strings bypass the localization system. English-locale users receive Arabic notifications. |
| **P1-8** | **CrashReporting is a placeholder** | `Services/CrashReporting/CrashReporter.swift`, `CrashReportingService.swift` | Framework present but no Crashlytics/Sentry SDK is integrated. Crashes in production are invisible. |

### P2 -- Tech Debt

| # | Issue | File:Line | Impact |
|---|---|---|---|
| **P2-1** | **Duplicated dictionary helpers** | `WorkoutSyncModels.swift`, `PhoneConnectivityManager.swift:820-843` | `doubleValue/intValue/boolValue` appear in 3+ places. Extract to shared utility. |
| **P2-2** | **WatchConnectivityService redundancy** | `WatchConnectivityService.swift:9` | Partially duplicates `WatchConnectivityManager`. Polling timer (2s) wastes battery. |
| **P2-3** | **15 files exceed 1,000 LOC** | Various | `PhoneWorkoutSummaryView` (1,422), `SupabaseArenaService` (1,362), `WorkoutManager` (1,344), etc. Refactoring targets. |
| **P2-4** | **AnalyticsEvent not Sendable** | `Services/Analytics/AnalyticsEvent.swift:6` | `properties: [String: Any]` prevents Sendable conformance. Will cause warnings in strict concurrency mode. |
| **P2-5** | **No offline queue for Supabase writes** | `Services/SupabaseService.swift`, `SupabaseArenaService.swift` | Tribe/profile writes while offline are silently lost. Need retry queue. |
| **P2-6** | **Kitchen notification routing fragility** | `App/MainTabRouter.swift:33` | Kitchen access via `NotificationCenter.default.post` relies on `HomeView` observing `openKitchenFromHome`. Breaks if HomeView lifecycle changes. |
| **P2-7** | **`logout()` skips language reset** | `App/SceneDelegate.swift:145` | After logout, user skips language selection on re-login. May be intentional but undocumented. |
| **P2-8** | **Local analytics unbatched** | `Services/Analytics/AnalyticsService.swift:141` | `LocalAnalyticsProvider` writes to disk on every event. No batching, potential I/O bottleneck. |
| **P2-9** | **XP formula hardcoded in PhoneConnectivityManager** | `PhoneConnectivityManager.swift:754-759` | `Int(cal * 0.8 + dur * 2)` duplicates logic from `XPCalculator.swift`. Should use shared calculator. |
| **P2-10** | **Background notification prompts Arabic-only** | `Services/Notifications/CaptainBackgroundNotificationComposer.swift:23-95` | On-device LLM prompts for notifications are hardcoded in Iraqi Arabic. English users get Arabic-prompted AI text. |

---

*End of AiQo Master Blueprint 12*
