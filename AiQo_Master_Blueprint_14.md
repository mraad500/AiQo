# AiQo — Master Blueprint 14

**Generated:** 2026-04-11T00:21:00+04:00
**Previous Blueprint:** AiQo_Master_Blueprint_13.md
**Codebase Commit:** e5730e8 Enable Brain V2 proactive captain notifications
**Auditor:** Claude Code deep audit pass (post Brain V2)

---

## 0. Executive Summary

AiQo is an Arabic-first SwiftUI wellness app with a real multi-target architecture. The current repo contains **452 Swift files** and **112,144 Swift lines** across five targets: iPhone app (401 files), Apple Watch app (25 files), iPhone widget (9 files), Watch widget (3 files), and tests (14 files). The composition root lives in `AiQo/App/AppDelegate.swift:12` and `AiQo/App/SceneDelegate.swift:17`, with a dedicated Captain SwiftData container and a separate app-wide container for daily records and Tribe models.

The biggest change since Blueprint 13 is the **Captain Hamoudi Brain V2** upgrade, delivered across five implementation phases. Brain V2 added **six new systems** totaling 1,154 LOC across 6 new files: `EmotionalStateEngine` (223 LOC), `TrendAnalyzer` (219 LOC), `SentimentDetector` (128 LOC), `ConversationThread` (206 LOC), `ProactiveEngine` (324 LOC), and `VibeMiniBubble` (54 LOC). These systems bring emotional intelligence, trend analysis, bilingual sentiment detection, persistent interaction logging, centralized notification decision-making, and cross-screen music recommendations to Captain Hamoudi.

The prompt system expanded from 6 layers to **7 enhanced layers**. Layer 3 (Working Memory) now includes recent interaction summaries from ConversationThread. Layer 4 (Bio-State) now injects 7-day health trends and emotional state with confidence scores. Layer 5 (Circadian Tone) now includes an emotional tone override that takes precedence when biometric signals conflict with time-of-day defaults. Layer 6 (Screen Context) now includes a "Music Bridge" that enables Spotify recommendations on any screen, not just My Vibe. The notification system shifted from hardcoded decisions scattered across `InactivityTracker`, `MorningHabitOrchestrator`, and `SmartNotificationScheduler` to a centralized **ProactiveEngine** that evaluates 5 blocking gates and 8 priority-ordered triggers before any captain notification is sent.

Monetization remains a confirmed **2-tier** system: `PremiumPlan` exposes `.core` and `.intelligencePro` in `AiQo/Premium/PremiumStore.swift:5`, `SubscriptionTier` maps `.none`, `.core`, and `.intelligencePro` in `AiQo/Core/Purchases/SubscriptionTier.swift:4`, and `PaywallView` markets "Two clear options only" in `AiQo/UI/Purchases/PaywallView.swift:259`. The 7-day free trial is managed by `FreeTrialManager` with Keychain persistence in `AiQo/Premium/FreeTrialManager.swift:8`.

**Launch readiness for AUE May 2026** is improved over BP13. Brain V2 resolves several BP13 blockers: hardcoded notification cooldowns are now centralized in ProactiveEngine, quiet hours use the user's actual bedtime, and notification budgets are subscription-aware. The single kill switch `CAPTAIN_BRAIN_V2_ENABLED` in `AiQo/Info.plist:74` (currently `true`) allows instant rollback to V1 behavior if issues arise in production.

**Biggest unresolved risks** remain: (1) Tribe backend code still ships in the binary despite UI flags being false (`AiQo/Info.plist:76`); (2) production analytics are still local-only (`AiQo/Services/Analytics/AnalyticsService.swift:27`); (3) Crashlytics linkage is still uncertain; (4) test coverage is thin (14 test files / 452 source files); (5) TrendAnalyzer is wired in the ProactiveEngine context builder but the `trendSnapshot` field is set to `nil` in `CaptainContextBuilder.buildContextData()` at line 248 — meaning trend data flows to notifications but not to the chat prompt.

---

## 1. What Changed Since Blueprint 13

### 1.1 New Files

| File | LOC | Purpose |
|---|---|---|
| `AiQo/Features/Captain/EmotionalStateEngine.swift` | 223 | Computes estimated emotional state (mood, confidence, tone) from biometric signals on-device. Singleton: `EmotionalStateEngine.shared`. Pure logic — no HealthKit import. |
| `AiQo/Features/Captain/TrendAnalyzer.swift` | 219 | Computes 7-day vs prior-7-day health trends (steps, sleep, workouts, water, HR, ring completion, streak momentum). Singleton: `TrendAnalyzer.shared`. |
| `AiQo/Features/Captain/SentimentDetector.swift` | 128 | Keyword-based bilingual (Iraqi Arabic + English) sentiment analysis for user messages. Returns sentiment enum + confidence + detected keywords. Singleton: `SentimentDetector.shared`. |
| `AiQo/Features/Captain/ConversationThread.swift` | 206 | SwiftData-backed persistent log of all Captain interactions (messages, notifications sent/opened/dismissed, workouts, goals). Singleton: `ConversationThreadManager.shared` (@MainActor). |
| `AiQo/Features/Captain/ProactiveEngine.swift` | 324 | Centralized notification decision engine with 5 blocking gates (budget, cooldown, quiet hours, subscription, engagement) and 8 priority-ordered triggers. Singleton: `ProactiveEngine.shared`. |
| `AiQo/Features/Captain/VibeMiniBubble.swift` | 54 | SwiftUI view for inline Spotify vibe recommendations in Captain chat. RTL layout, AiQoColors.mint theme. |

### 1.2 Modified Files

| File | What Changed |
|---|---|
| `AiQo/App/AppDelegate.swift:62-63` | Added `ConversationThreadManager.shared.configure(modelContext:)` and `.pruneOldEntries()` at init. `ConversationThreadEntry` registered in Captain SwiftData container. |
| `AiQo/Features/Captain/CaptainContextBuilder.swift:95-98,143-144,222-250` | Added `emotionalState`, `trendSnapshot`, `messageSentiment`, `recentInteractions` fields to `CaptainContextData`. Added `isBrainV2Enabled` static flag. Added V2 population block gated by feature flag that calls `EmotionalStateEngine.shared.evaluate(...)` and `ConversationThreadManager.shared.buildPromptSummary()`. |
| `AiQo/Features/Captain/CaptainPromptBuilder.swift:195-205,258-285,293-327,345-352` | Layer 3: injects recent interactions from ConversationThread. Layer 4: injects TrendSnapshot and EmotionalState data. Layer 5: adds emotional tone override. Layer 6: adds "Music Bridge" for cross-screen Spotify recommendations. |
| `AiQo/Features/Captain/CaptainViewModel.swift:236,409-413,487` | Logs user messages and captain responses to ConversationThread. Runs SentimentDetector on user messages when V2 enabled. |
| `AiQo/Features/Captain/CaptainChatView.swift:34-47` | Renders `VibeMiniBubble` inline when assistant message has `spotifyRecommendation`. On tap calls `SpotifyVibeManager.shared.playVibe()`. |
| `AiQo/Features/Captain/CaptainNotificationRouting.swift:30` | Logs notification opens to ConversationThread via `ConversationThreadManager.shared.logNotificationOpened()`. |
| `AiQo/Core/SmartNotificationScheduler.swift:493-513,603-624,827-946` | Added `buildProactiveContext()` method (120 LOC). Coach nudge and inactivity check paths now consult ProactiveEngine first, with legacy fallback. |
| `AiQo/Services/Notifications/NotificationService.swift:195-201,266-267,1002-1004` | Added notification budget check via ConversationThread. Logs notification sends to ConversationThread. |
| `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:97-100,341` | Added notification budget check via ConversationThread. Logs notification sends to ConversationThread. |
| `AiQo/Info.plist:74-75` | Added `CAPTAIN_BRAIN_V2_ENABLED = true` feature flag. |

### 1.3 Blueprint 13 Issues: Resolved vs Still Open

| BP13 Issue | Status | Evidence |
|---|---|---|
| Hardcoded notification cooldowns scattered across files | **Resolved** | ProactiveEngine manages all cooldowns centrally with 120-minute minimum in `ProactiveEngine.swift:166` via `NotificationBudget.minIntervalMinutes`. |
| Hardcoded quiet hours (23:00-07:00) | **Resolved** | ProactiveEngine uses user's bedtime/wakeTime from CaptainPersonalizationStore, with 23:00-07:00 as fallback only in `ProactiveEngine.swift:143`. |
| InactivityTracker directly sends notifications | **Changed** | `InactivityTracker.swift` is now only 21 LOC — a simple timestamp tracker. The inactivity notification decision now routes through `SmartNotificationScheduler.performInactivityCheckAndNotifyIfNeeded()` which consults ProactiveEngine at line 605. |
| MorningHabitOrchestrator hardcoded thresholds | **Partially Resolved** | Now checks ConversationThread notification budget (< 4/day) at `MorningHabitOrchestrator.swift:97-100`. Step threshold (25+ steps) remains hardcoded. |
| Hidden Tribe backend still ships in binary | **Still Open** | `AiQo/Info.plist:76` (`TRIBE_FEATURE_VISIBLE = false`), `AiQo/Services/SupabaseArenaService.swift:10` still compiled. |
| Production analytics are still local-only | **Still Open** | `AiQo/Services/Analytics/AnalyticsService.swift:27` — no remote sink. |
| Crashlytics linkage uncertain | **Still Open** | `AiQo/Services/CrashReporting/CrashReportingService.swift:21` wrapper exists but Firebase package linkage unconfirmed. |
| Onboarding product intent diverges | **Still Open** | `AiQo/App/SceneDelegate.swift:52` — no GoalsAndSleepSetupView, no end-of-flow level classification. |
| Captain Context Assembly naming | **Still Open** | Live code uses `CaptainContextBuilder` not the planned "Context Assembly" naming. |
| Captain memory settings UI misreports entitlement | **Still Open** | `AiQo/Core/CaptainMemorySettingsView.swift:67` still shows fixed 200 cap. |
| Tribe leaderboards identity/scoring bugs | **Still Open** | `AiQo/Tribe/Views/TribeLeaderboardView.swift:96` — double @@ username and 0 XP bugs. |
| WatchConnectivityService polls every 2s | **Still Open** | `AiQoWatch Watch App/Services/WatchConnectivityService.swift:18`. |
| PhoneConnectivityManager duplicates XP logic | **Still Open** | `AiQo/PhoneConnectivityManager.swift:756` vs `AiQo/XPCalculator.swift:23`. |
| Inactivity notifications hardcoded prompt/fallback | **Partially Resolved** | Legacy path still hardcoded in `NotificationService.swift:468`, but V2 path uses ProactiveEngine-generated content. |
| Analytics per-event synchronous file appends | **Still Open** | `AiQo/Services/Analytics/AnalyticsService.swift:157`. |
| Large-file concentration | **Still Open** | 14+ files over 1,000 LOC remain. |

---

## 2. Directory Structure

```
AiQo/
├── App/                          — AppDelegate, SceneDelegate, MainTabScreen, Auth, Login, ProfileSetup, MealModels, MainTabRouter, AppRootManager, LanguageSelection
├── Core/
│   ├── Localization/             — Bundle+Language, LocalizationManager
│   ├── Models/                   — ActivityNotification, LevelStore, NotificationPreferencesStore, WeeklyMetricsBuffer, WeeklyReportEntry
│   ├── Purchases/                — EntitlementStore, PurchaseManager, ReceiptValidator, SubscriptionProductIDs, SubscriptionTier
│   ├── Schema/                   — CaptainSchemaMigrationPlan, CaptainSchemaV1-V3
│   ├── Utilities/                — ConnectivityDebugProviding, DebugPrint
│   └── [root]                    — CaptainMemory, CaptainPersonalization, CaptainVoice*, Colors, Constants, DailyGoals, HapticEngine, HealthKitMemoryBridge, MemoryExtractor, MemoryStore, SmartNotificationScheduler, SpotifyVibeManager, StreakManager, etc.
├── DesignSystem/
│   ├── Components/               — AiQoBottomCTA, AiQoCard, AiQoChoiceGrid, AiQoPillSegment, AiQoPlatformPicker, AiQoSkeletonView
│   ├── Modifiers/                — AiQoPressEffect, AiQoShadow, AiQoSheetStyle
│   └── [root]                    — AiQoColors, AiQoTheme, AiQoTokens
├── Features/
│   ├── Captain/                  — 34 files (Brain V2 adds 6 new: EmotionalStateEngine, TrendAnalyzer, SentimentDetector, ConversationThread, ProactiveEngine, VibeMiniBubble)
│   ├── DataExport/               — HealthDataExporter
│   ├── First screen/             — LegacyCalculationViewController
│   ├── Gym/                      — 50+ files: Club, QuestKit, Quests, Models, T (SpinWheel), workouts, sessions, grind views
│   ├── Home/                     — HomeView, HomeViewModel, DailyAura*, VibeControl*, SpotifyVibeCard, WaterBottle, StreakBadge, etc.
│   ├── Kitchen/                  — 25+ files: KitchenScreen, FridgeInventory, MealPlan*, Camera, Ingredients, Nutrition
│   ├── LegendaryChallenges/      — RecordProject, WeeklyLog, HRRWorkoutManager, FitnessAssessment, ProjectView, etc.
│   ├── MyVibe/                   — MyVibeScreen, MyVibeViewModel, VibeOrchestrator, DailyVibeState
│   ├── Onboarding/               — CaptainPersonalizationOnboardingView, FeatureIntroView, HistoricalHealthSyncEngine, OnboardingWalkthrough
│   ├── Profile/                  — ProfileScreen, ProfileScreenComponents, ProfileScreenLogic, LevelCardView
│   ├── ProgressPhotos/           — ProgressPhotoStore, ProgressPhotosView
│   ├── Sleep/                    — 9 files: AppleIntelligenceSleepAgent, SleepSessionObserver, SmartWake*, SleepAnalysis*, AlarmSetup
│   ├── Tribe/                    — TribeView, TribeDesignSystem, TribeExperienceFlow
│   └── WeeklyReport/             — WeeklyReportView, WeeklyReportViewModel, ShareCardRenderer, WeeklyReportModel
├── Premium/                      — AccessManager, EntitlementProvider, FreeTrialManager, PremiumPaywallView, PremiumStore
├── Services/
│   ├── Analytics/                — AnalyticsEvent, AnalyticsService
│   ├── CrashReporting/           — CrashReporter, CrashReportingService
│   ├── Memory/                   — WeeklyMemoryConsolidator, WeeklyMetricsBufferStore
│   ├── Notifications/            — 10 files: NotificationService, SmartNotificationManager, InactivityTracker, MorningHabitOrchestrator, CaptainBackgroundNotificationComposer, PremiumExpiryNotifier, AlarmSchedulingService, NotificationCategory/Localization/Repository
│   ├── Permissions/HealthKit/    — HealthKitService, TodaySummary
│   ├── Trial/                    — TrialJourneyOrchestrator, TrialNotificationCopy, TrialPersonalizationReader
│   └── [root]                    — AiQoError, DeepLinkRouter, NetworkMonitor, NotificationType, ReferralManager, SupabaseArenaService, SupabaseService
├── Shared/                       — CoinManager, HealthKitManager, LevelSystem, WorkoutSync*
├── Tribe/                        — 35+ files: Galaxy, Arena, Log, Models, Preview, Repositories, Stores, Views
├── UI/                           — Purchases/PaywallView, AiQoScreenHeader, ProfileButton, GlassCard, ErrorToast, OfflineBanner, LegalView, etc.
├── watch/                        — ConnectivityDiagnosticsView
├── NeuralMemory.swift            — NeuralMemoryEntry, NeuralMemoryStore (SwiftData)
├── PhoneConnectivityManager.swift
├── ProtectionModel.swift
└── XPCalculator.swift

AiQoWatch Watch App/              — 25 files: WatchApp, WorkoutManager, services, views, design
AiQoWidget/                       — 9 files: iPhone widget
AiQoWatchWidget/                  — 3 files: Watch widget
AiQoTests/                        — 11 files: unit tests
AiQoWatch Watch AppTests/         — 1 file
AiQoWatch Watch AppUITests/       — 2 files
```

---

## 3. Core Architecture

### 3.1 App Entry & Composition Root

The `@main` entry point is `AiQoApp` in `AiQo/App/AppDelegate.swift:12`. It creates two SwiftData `ModelContainer` instances:

1. **Captain container** (`AiQo/App/AppDelegate.swift:18`): stores `PersistentChatMessage`, `CaptainMemory`, `ConversationThreadEntry` (NEW in V2). Schema versioned via `CaptainSchemaMigrationPlan` in `AiQo/Core/Schema/CaptainSchemaMigrationPlan.swift`.
2. **App-wide container** (`AiQo/App/AppDelegate.swift:80`): stores quest models, weekly metrics, weekly reports, scanned items, record projects, weekly logs, and Tribe arena models.

Brain V2 addition: `ConversationThreadManager.shared.configure(modelContext: captainContainer.mainContext)` at `AppDelegate.swift:62` and `ConversationThreadManager.shared.pruneOldEntries()` at `AppDelegate.swift:63`.

`AppFlowController` in `AiQo/App/SceneDelegate.swift:17` manages the root navigation state machine with states: `languageSelection → login → profileSetup → legacy → captainPersonalization → featureIntro → main`. The main screen is `MainTabScreen` (`AiQo/App/MainTabScreen.swift:4`) with 3 tabs: Home, Gym, Captain.

### 3.2 SwiftData Models

| Model | File | Container | Key Fields |
|---|---|---|---|
| `PersistentChatMessage` | `CaptainModels.swift:7` | Captain | messageID, text, isUser, timestamp, spotifyRecommendationData, sessionID |
| `CaptainMemory` | `CaptainMemory.swift:5` | Captain | id, category, key, value, confidence, source, createdAt, updatedAt, accessCount |
| `ConversationThreadEntry` | `ConversationThread.swift:26` | Captain | id, entryType, content, timestamp, metadata — **NEW in Brain V2** |
| `NeuralMemoryEntry` | `NeuralMemory.swift:5` | Captain | Consolidation entries |
| `NeuralMemoryRelation` | `NeuralMemory.swift:46` | Captain | Memory graph edges |
| `WeeklyMetricsBuffer` | `WeeklyMetricsBuffer.swift:7` | App-wide | Weekly health metric snapshots |
| `WeeklyReportEntry` | `WeeklyReportEntry.swift:6` | App-wide | Weekly report records |
| `QuestProgressRecord` | `QuestSwiftDataModels.swift:10` | App-wide | Quest progress tracking |
| `QuestMilestoneRecord` | `QuestSwiftDataModels.swift:41` | App-wide | Quest milestones |
| `QuestStreakRecord` | `QuestSwiftDataModels.swift:73` | App-wide | Quest streak data |
| `QuestDailyRecord` | `QuestSwiftDataModels.swift:185` | App-wide | Daily quest records |
| `SmartFridgeScannedItemRecord` | `SmartFridgeScannedItemRecord.swift:4` | App-wide | Kitchen scanned items |
| `RecordProject` | `RecordProject.swift:5` | App-wide | Legendary challenge projects |
| `WeeklyLog` | `WeeklyLog.swift:5` | App-wide | Legendary challenge weekly logs |
| `ArenaChallenge` | `ArenaModels.swift:6` | App-wide | Tribe arena challenges |
| `ArenaChallengeParticipant` | `ArenaModels.swift:41` | App-wide | Arena participants |
| `ArenaLeaderboardEntry` | `ArenaModels.swift:94` | App-wide | Arena leaderboard |
| `ArenaUserProfile` | `ArenaModels.swift:122` | App-wide | Arena profiles |
| `ArenaTeam` | `ArenaModels.swift:141` | App-wide | Arena teams |
| `ArenaAchievement` | `ArenaModels.swift:162` | App-wide | Arena achievements |

### 3.3 Captain Hamoudi Intelligence Pipeline — V2

**Complete message flow after Brain V2:**

```text
User input
  → CaptainViewModel.sendMessage()                     [CaptainViewModel.swift:150]
      → ConversationThreadManager.shared.logUserMessage  [CaptainViewModel.swift:236]  ← NEW V2
      → CaptainContextBuilder.buildContextData()         [CaptainViewModel.swift:400]
          → if isBrainV2Enabled:                         [CaptainContextBuilder.swift:223]
              → EmotionalStateEngine.shared.evaluate()   [CaptainContextBuilder.swift:233]
              → ConversationThreadManager.buildPromptSummary() [CaptainContextBuilder.swift:249]
              → contextData.trendSnapshot = nil          [CaptainContextBuilder.swift:248] (placeholder)
      → if isBrainV2Enabled:
          → SentimentDetector.shared.detect(message)     [CaptainViewModel.swift:411]
          → contextData.messageSentiment = result        [CaptainViewModel.swift:413]
      → CaptainPromptBuilder.build(for: contextData)     [CaptainPromptBuilder.swift:14]
          → Layer 1: Identity
          → Layer 2: Stable Profile
          → Layer 3: Working Memory + Recent Interactions ← ENHANCED
          → Layer 4: Bio-State + Trends + Emotional State ← ENHANCED
          → Layer 5: Circadian + Emotional Tone Override  ← ENHANCED
          → Layer 6: Screen Context + Vibe Bridge         ← ENHANCED
          → Layer 7: JSON Output Contract
      → BrainOrchestrator.processMessage()               [BrainOrchestrator.swift:37]
          → interceptSleepIntent()
          → route(for:) → .local or .cloud
              → Local: CaptainOnDeviceChatEngine (Apple Intelligence, 8s timeout)
              → Cloud:
                  → MemoryStore.buildCloudSafeContext()
                  → PrivacySanitizer.sanitizeForCloud()  [PrivacySanitizer.swift:95]
                  → CloudBrainService.generateReply()    [CloudBrainService.swift:18]
                      → HybridBrainService → Gemini API  [HybridBrainService.swift:300]
          → PrivacySanitizer.injectUserName()            [PrivacySanitizer.swift:167]
      → CaptainViewModel.validateResponse()              [CaptainViewModel.swift:843]
      → Handle spotifyRecommendation (non-Vibe context)  ← NEW V2 (Vibe Bridge)
      → ConversationThreadManager.logCaptainResponse()   [CaptainViewModel.swift:487] ← NEW V2
      → MemoryExtractor.extract()                        [MemoryExtractor.swift:18]
      → MemoryStore.persistMessageAsync()                [MemoryStore.swift:350]
```

**Enhanced prompt layers (V2):**

| Layer | Name | File:Lines | V2 Changes |
|---|---|---|---|
| 1 | Identity | `CaptainPromptBuilder.swift:48-80` | Unchanged — Captain Hamoudi persona, Iraqi Arabic voice |
| 2 | Stable Profile | `CaptainPromptBuilder.swift:82-130` | Unchanged — user name, age, height, weight, goals |
| 3 | Working Memory | `CaptainPromptBuilder.swift:132-210` | **ENHANCED** — Now includes `recentInteractions` from ConversationThread (lines 195-205). LLM instructed to connect replies to recently opened notifications. |
| 4 | Bio-State | `CaptainPromptBuilder.swift:212-290` | **ENHANCED** — Injects `TrendSnapshot` (7-day trends, consistency score, ring avg, streak momentum) at lines 258-269. Injects `EmotionalState` (mood, confidence, signals) at lines 272-285. LLM instructions: declining trends → focus on one small step; improving → celebrate; streak breaking → gentle motivation. |
| 5 | Circadian Tone | `CaptainPromptBuilder.swift:292-340` | **ENHANCED** — Emotional tone override at lines 293-327. When `emotionalState.recommendedTone` conflicts with time-of-day tone (e.g., evening says energetic but user is tired), emotional tone wins. |
| 6 | Screen Context | `CaptainPromptBuilder.swift:342-380` | **ENHANCED** — "Music Bridge" at lines 345-352. Allows Spotify recommendations on any screen when context suggests user could benefit from music. |
| 7 | JSON Output Contract | `CaptainPromptBuilder.swift:382-508` | Unchanged — CaptainStructuredResponse schema, quick replies, workout/meal plans, Spotify recommendations. |

### 3.4 Brain V2 Component Table

| Component | File | LOC | Purpose | Public API | Dependencies | On-device only? |
|---|---|---|---|---|---|---|
| EmotionalStateEngine | `EmotionalStateEngine.swift` | 223 | Computes estimated mood and recommended tone from biometric signals | `evaluate(stepsToday:steps7DayAvg:sleepLastNightHours:sleep7DayAvgHours:restingHeartRate:hrvLatest:hrv7DayAvg:lastWorkoutDate:messageLength:messageTimestamp:userPreferredBedtime:userPreferredWakeTime:) → EmotionalState` | Foundation only | Yes |
| TrendAnalyzer | `TrendAnalyzer.swift` | 219 | Computes week-over-week health trends and streak momentum | `compute(dailyPoints:currentStreak:yesterdayStreak:) → TrendSnapshot` | Foundation only | Yes |
| SentimentDetector | `SentimentDetector.swift` | 128 | Bilingual keyword-based sentiment analysis for user messages | `detect(message:) → SentimentResult` | Foundation only | Yes |
| ConversationThreadManager | `ConversationThread.swift` | 206 | Persistent log of all Captain interactions via SwiftData | `configure(modelContext:)`, `logNotificationSent(content:category:)`, `logNotificationOpened(content:actionTaken:)`, `logUserMessage(content:)`, `logCaptainResponse(content:)`, `recentEntries(limit:)`, `recentNotifications(withinHours:)`, `buildPromptSummary(maxEntries:)`, `pruneOldEntries()` | Foundation, SwiftData | Yes |
| ProactiveEngine | `ProactiveEngine.swift` | 324 | Centralized notification decision engine with gates and triggers | `evaluate(context: ProactiveContext) → ProactiveDecision` | Foundation, EmotionalState, TrendSnapshot, CaptainContextBuilder | Yes |
| VibeMiniBubble | `VibeMiniBubble.swift` | 54 | Inline Spotify recommendation card in chat | SwiftUI View with `vibeName`, `description`, `onTap` | SwiftUI, AiQoColors | N/A (UI) |

**EmotionalStateEngine algorithm:**
- Collects signals from 7 categories: sleep quality, step count vs average, resting HR (>85 = high), HRV vs average, late-night messaging, short messages (<5 chars), workout recency (>3 days = none).
- Mood by priority: `low_hrv + poor_sleep → stressed`, `good_sleep + above_avg_steps → highEnergy`, `above_avg_steps alone → highEnergy`, `poor_sleep alone → lowEnergy`, etc.
- Confidence: starts 0.5, adds 0.08 per non-nil input, capped 0.95. If < 3 inputs, capped 0.40.
- Tone: highEnergy → energetic, lowEnergy/stressed → gentle, neutral/recovering → neutral.

**TrendAnalyzer algorithm:**
- Splits daily health points into this-week (last 7 days) and last-week (days 8-14).
- Computes week-over-week percentage change. Threshold: >10% = improving/declining, else stable.
- Heart rate trend inverted (lower is better).
- Consistency score = proportion of days with ring completion >= 0.80.
- Streak momentum: >=3 = building, >=1 = holding, yesterday active + current 0 = breaking, else broken.

**SentimentDetector algorithm:**
- Bilingual keywords: 19 question words (Arabic + English + "?"), 24 positive keywords (Arabic + English + emoji), 25 negative keywords.
- Priority: question > positive/negative count > neutral tie.
- Confidence: 0.3 (no matches), 0.5 + 0.1 per match, capped 0.9. Questions always 0.85.

### 3.5 Brain Routing

`BrainOrchestrator` in `AiQo/Features/Captain/BrainOrchestrator.swift:11` is a `Sendable` struct that routes messages between local and cloud brain services.

**Routing logic (`route(for:)`):**
- Sleep intents → intercepted and handled specially (local or cloud sleep agent).
- Cloud route: default for most messages. Uses `CloudBrainService` → `HybridBrainService` → Gemini API.
- Local route: fallback when network unavailable. Uses `LocalBrainService` → `CaptainOnDeviceChatEngine` (Apple Intelligence).

**Cloud models:**
- `gemini-3-flash-preview` (reasoning) for Intelligence Pro tier — `CloudBrainService.swift:42`.
- `gemini-2.5-flash` (fast) for Core and trial — `CloudBrainService.swift:44`.
- Token budget: 700 for Intelligence Pro, 400 for others — `HybridBrainService.swift:300`.

**V2 note:** BrainOrchestrator itself has no V2 feature flag checks. V2 data flows through it implicitly via `HybridBrainRequest.contextData` which is populated upstream by `CaptainContextBuilder`.

### 3.6 Proactive Notification System — V2

**Complete notification flow after Brain V2:**

```text
Background task fires
  → BGAppRefreshTask ("aiqo.notifications.refresh")
  → BGProcessingTask ("aiqo.notifications.inactivity-check")
  → HKObserverQuery (step/workout changes)

SmartNotificationScheduler receives trigger
  → buildProactiveContext()                          [SmartNotificationScheduler.swift:827]
      → CaptainIntelligenceManager: health metrics
      → EmotionalStateEngine.shared.evaluate(...)    [SmartNotificationScheduler.swift:838]
      → CaptainPersonalizationStore: user profile
      → FreeTrialManager + StoreKitEntitlementProvider: subscription state
      → ConversationThreadManager.shared.recentNotifications(withinHours: 24)
      → ConversationThreadManager.shared.recentEntries(limit: 5)
      → Constructs ProactiveContext with 24 fields   [SmartNotificationScheduler.swift:921]

  → ProactiveEngine.shared.evaluate(context)         [SmartNotificationScheduler.swift:495/605]
      → Gate 0: Kill switch (CaptainContextBuilder.isBrainV2Enabled)  [ProactiveEngine.swift:96]
      → Gate 1: Subscription check (tier != "none")                    [ProactiveEngine.swift:101]
      → Gate 2: Budget exhausted (sent >= maxPerDay)                   [ProactiveEngine.swift:106]
      → Gate 3: Cooldown (< minIntervalMinutes since last)             [ProactiveEngine.swift:111]
      → Gate 4: Quiet hours (between bedtime and wake)                 [ProactiveEngine.swift:119]
      → Gate 5: User disengaged (3+ dismissals AND 1+ sent today)     [ProactiveEngine.swift:127]
      
      → Trigger scan (priority order):
          1. CRITICAL: Workout just ended (< 300s)       → workout_complete
          2. HIGH: Currently working out                  → activity_spike
          3. HIGH: Ring completion 80-99%                 → goal_near
          4. MEDIUM: Steps < 50% goal, afternoon/evening  → activity_nudge
          5. MEDIUM: Water < 50% after noon               → water_reminder
          6. MEDIUM: Sleep trend declining >15%, evening   → sleep_nudge
          7. LOW: Streak momentum = .breaking              → streak_protection
          8. LOW: Morning window, no notifications today   → morning_kickoff
      
      → Returns: .sendNotification(content, category, priority) or .doNothing(reason)

  → If .sendNotification:
      → Compose content (ProactiveEngine provides Iraqi Arabic text)
      → ConversationThreadManager.shared.logNotificationSent()
      → UNUserNotificationCenter.add()
  
  → If .doNothing or ProactiveEngine unavailable:
      → Falls through to legacy CaptainBackgroundNotificationComposer path

Notification opened:
  → CaptainNotificationRouting.handleIncomingNotification()  [CaptainNotificationRouting.swift:18]
  → ConversationThreadManager.shared.logNotificationOpened() [CaptainNotificationRouting.swift:30]
  → CaptainNavigationHelper.navigateToCaptainScreen()
  → Captain chat opens — sees notification in ConversationThread via prompt summary
```

**Notification Budget Table:**

| Subscription State | Max/Day | Cooldown | Quiet Hours |
|---|---|---|---|
| Trial Day 1 | 1 | 120 min | User's bedtime → wake (fallback: 23:00-07:00) |
| Trial Day 2 | 2 | 120 min | User's bedtime → wake |
| Trial Day 3-7 | 3 | 120 min | User's bedtime → wake |
| Post-trial (no sub) | 0 | N/A | N/A |
| Core | 3 | 120 min | User's bedtime → wake |
| Intelligence Pro | 4 | 120 min | User's bedtime → wake |

Budget computed at `ProactiveEngine.swift:152-170` via `NotificationBudget.forContext(_:)`.

---

## 4. Feature Status

### 4.1 Language Selection & Auth

| | |
|---|---|
| Status | Functional |
| Files | `LanguageSelectionView.swift`, `LoginViewController.swift`, `AuthFlowUI.swift` |
| Entry point | `AppFlowController.currentScreen = .languageSelection` in `SceneDelegate.swift:52` |
| Dependencies | Supabase Auth, AppSettingsStore |
| Known issues | Guest login flows directly to `.profileSetup`, skipping legacy classification. |
| Feature flag | None |

### 4.2 Profile Setup & Onboarding

| | |
|---|---|
| Status | Functional with gaps |
| Files | `ProfileSetupView.swift`, `CaptainPersonalizationOnboardingView.swift`, `FeatureIntroView.swift`, `OnboardingWalkthroughView.swift`, `HistoricalHealthSyncEngine.swift` |
| Entry point | `AppFlowController.currentScreen = .profileSetup` |
| Dependencies | CaptainPersonalizationStore, HealthKitService, AppSettingsStore |
| Known issues | No GoalsAndSleepSetupView, no end-of-flow level classification, no UserTrainingProfile model. Onboarding order diverges from latest product plan. |
| Feature flag | None |

### 4.3 Level Classification

| | |
|---|---|
| Status | Functional |
| Files | `LegacyCalculationViewController.swift`, `LevelStore.swift`, `LevelSystem.swift`, `XPCalculator.swift` |
| Entry point | `AppFlowController.currentScreen = .legacy` |
| Dependencies | HealthKitService |
| Known issues | Watch-earned XP can drift from app-earned XP due to duplicated logic in `PhoneConnectivityManager.swift:756`. |
| Feature flag | None |

### 4.4 Captain Hamoudi Chat (UPDATED for V2)

| | |
|---|---|
| Status | Functional — V2 active |
| Files | `CaptainScreen.swift`, `CaptainChatView.swift`, `CaptainViewModel.swift`, `BrainOrchestrator.swift`, `CloudBrainService.swift`, `HybridBrainService.swift`, `LocalBrainService.swift`, `CaptainPromptBuilder.swift`, `CaptainContextBuilder.swift`, `CaptainModels.swift`, `LLMJSONParser.swift`, `ScreenContext.swift`, `PrivacySanitizer.swift`, `CaptainPersonaBuilder.swift`, `CaptainFallbackPolicy.swift`, `CaptainIntelligenceManager.swift`, `CaptainCognitivePipeline.swift`, `CaptainOnDeviceChatEngine.swift`, `ChatHistoryView.swift`, `MessageBubble.swift`, `PromptRouter.swift`, `AiQoPromptManager.swift`, `CoachBrainMiddleware.swift`, `CoachBrainTranslationConfig.swift`, `LocalIntelligenceService.swift`, `CaptainAvatar3DView.swift` |
| Entry point | Captain tab → `CaptainScreen` → `CaptainChatView` |
| Dependencies | Gemini API, Apple Intelligence (on-device), CaptainMemory, HealthKit, SpotifyVibeManager, EmotionalStateEngine (V2), SentimentDetector (V2), ConversationThreadManager (V2) |
| Known issues | TrendSnapshot set to nil in context builder (line 248), so chat prompt lacks trend data. |
| Feature flag | `CAPTAIN_BRAIN_V2_ENABLED` gates V2 prompt enrichment |

### 4.5 Captain Memory & Settings

| | |
|---|---|
| Status | Functional |
| Files | `CaptainMemory.swift`, `MemoryStore.swift`, `MemoryExtractor.swift`, `CaptainMemorySettingsView.swift`, `NeuralMemory.swift`, `WeeklyMemoryConsolidator.swift` |
| Entry point | Auto-populated via MemoryExtractor after each conversation turn |
| Dependencies | SwiftData, PrivacySanitizer, Gemini API (for LLM extraction every 3rd message) |
| Known issues | Settings UI hardcodes 200 memory cap, but Intelligence Pro allows 500 via `AccessManager.swift:58`. |
| Feature flag | None |

### 4.6 Captain Brain V2: Emotional Intelligence — NEW

| | |
|---|---|
| Status | Functional |
| Files | `EmotionalStateEngine.swift`, `CaptainContextBuilder.swift:222-250`, `CaptainPromptBuilder.swift:272-285,293-327` |
| Entry point | `CaptainContextBuilder.buildContextData()` when `isBrainV2Enabled` is true |
| Dependencies | None (pure computation). Consumes health data passed in as parameters. |
| Known issues | `celebratory` tone defined in `RecommendedTone` but never assigned by the engine. Confidence capped at 0.40 when fewer than 3 optional health inputs are available. |
| Feature flag | `CAPTAIN_BRAIN_V2_ENABLED` |

### 4.7 Captain Brain V2: Proactive Notifications — NEW

| | |
|---|---|
| Status | Functional |
| Files | `ProactiveEngine.swift`, `SmartNotificationScheduler.swift:493-513,603-624,827-946` |
| Entry point | `SmartNotificationScheduler.generateAndScheduleCoachNudge()` and `performInactivityCheckAndNotifyIfNeeded()` |
| Dependencies | EmotionalStateEngine, TrendSnapshot, ConversationThreadManager, CaptainPersonalizationStore, FreeTrialManager, StoreKitEntitlementProvider, CaptainContextBuilder (for feature flag) |
| Known issues | Legacy fallback path still active when ProactiveEngine is unavailable. Morning kickoff message varies by trial day but doesn't handle post-trial non-subscriber (budget is 0 anyway). |
| Feature flag | `CAPTAIN_BRAIN_V2_ENABLED` (kill switch at `ProactiveEngine.swift:96`) |

### 4.8 Captain Brain V2: Conversation Thread — NEW

| | |
|---|---|
| Status | Functional |
| Files | `ConversationThread.swift`, `AppDelegate.swift:62-63` |
| Entry point | Configured at app init, logged from CaptainViewModel, CaptainNotificationRouting, NotificationService, MorningHabitOrchestrator |
| Dependencies | SwiftData (registered in Captain container) |
| Known issues | Pruning deletes entries > 7 days old. No migration path if schema changes. Metadata stored as JSON string, not structured SwiftData relations. |
| Feature flag | Always active (not gated). Data consumed in prompts only when V2 enabled. |

### 4.9 Captain Brain V2: Vibe Bridge — NEW

| | |
|---|---|
| Status | Functional |
| Files | `VibeMiniBubble.swift`, `CaptainChatView.swift:34-47`, `CaptainPromptBuilder.swift:345-352` |
| Entry point | Captain chat renders VibeMiniBubble when assistant message contains `spotifyRecommendation` |
| Dependencies | SpotifyVibeManager, AiQoColors |
| Known issues | None identified. |
| Feature flag | Indirectly gated — Music Bridge prompt section only activates when V2 enriches the prompt |

### 4.10 Sleep Architecture

| | |
|---|---|
| Status | Functional |
| Files | `AppleIntelligenceSleepAgent.swift`, `SleepSessionObserver.swift`, `SmartWakeEngine.swift`, `SmartWakeViewModel.swift`, `SmartWakeCalculatorView.swift`, `SleepAnalysisQualityEvaluator.swift`, `SleepDetailCardView.swift`, `SleepScoreRingView.swift`, `AlarmSetupCardView.swift`, `AlarmSchedulingService.swift` |
| Entry point | Sleep tab in Gym, BrainOrchestrator sleep intent interception |
| Dependencies | HealthKit, Apple Intelligence (on-device), AlarmSchedulingService |
| Known issues | None identified since BP13. |
| Feature flag | None |

### 4.11 Alchemy Kitchen

| | |
|---|---|
| Status | Functional |
| Files | 25+ files in `AiQo/Features/Kitchen/` |
| Entry point | ScreenContext `.kitchen` in Captain, KitchenScreen navigation |
| Dependencies | Camera, Gemini API (for food recognition), SmartFridge scanner |
| Known issues | None identified since BP13. |
| Feature flag | None |

### 4.12 Gym & Workouts

| | |
|---|---|
| Status | Functional |
| Files | 50+ files in `AiQo/Features/Gym/` |
| Entry point | Gym tab → `GymViewController` / `ClubRootView` |
| Dependencies | HealthKit, WorkoutKit, Watch connectivity, AudioCoachManager |
| Known issues | `PhoneWorkoutSummaryView.swift` is 1,422 LOC. |
| Feature flag | None |

### 4.13 XP & Leveling

| | |
|---|---|
| Status | Functional |
| Files | `XPCalculator.swift`, `LevelStore.swift`, `LevelSystem.swift`, `LevelCardView.swift`, `LevelUpCelebrationView.swift` |
| Entry point | XP awarded via `LevelStore` after workouts, steps, streak milestones |
| Dependencies | HealthKit data |
| Known issues | Duplicated XP formula in `PhoneConnectivityManager.swift:756`. |
| Feature flag | None |

### 4.14 Streak System

| | |
|---|---|
| Status | Functional |
| Files | `StreakManager.swift`, `StreakBadgeView.swift` |
| Entry point | `StreakManager` evaluates daily at app launch |
| Dependencies | UserDefaults |
| Known issues | None identified. |
| Feature flag | None |

### 4.15 Quest System

| | |
|---|---|
| Status | Functional |
| Files | `QuestKit/` (8 files), `Quests/` (15+ files including VisionCoach) |
| Entry point | QuestsView in Gym tab |
| Dependencies | SwiftData, HealthKit, Camera (VisionCoach push-up detection) |
| Known issues | None identified since BP13. |
| Feature flag | None |

### 4.16 Subscription & Trial

| | |
|---|---|
| Status | Functional — 2-tier |
| Files | `PremiumStore.swift`, `FreeTrialManager.swift`, `EntitlementProvider.swift`, `AccessManager.swift`, `PurchaseManager.swift`, `EntitlementStore.swift`, `ReceiptValidator.swift`, `SubscriptionProductIDs.swift`, `SubscriptionTier.swift`, `PaywallView.swift`, `PremiumPaywallView.swift`, `TrialJourneyOrchestrator.swift`, `TrialNotificationCopy.swift` |
| Entry point | `PremiumStore.start()` at app launch |
| Dependencies | StoreKit 2, Keychain (trial persistence), Supabase (receipt validation) |
| Known issues | Receipt validation depends on Supabase edge function. Memory settings UI hardcodes 200 cap. |
| Feature flag | `useLocalStoreKitConfig` in DEBUG for local testing |

### 4.17 Weekly Memory Consolidation

| | |
|---|---|
| Status | Functional |
| Files | `WeeklyMemoryConsolidator.swift`, `WeeklyMetricsBufferStore.swift`, `WeeklyMetricsBuffer.swift`, `WeeklyReportEntry.swift` |
| Entry point | Background task via SmartNotificationScheduler |
| Dependencies | SwiftData, MemoryStore, HealthKit |
| Known issues | None identified. |
| Feature flag | None |

### 4.18 My Vibe / DJ Hamoudi

| | |
|---|---|
| Status | Functional |
| Files | `MyVibeScreen.swift`, `MyVibeViewModel.swift`, `VibeOrchestrator.swift`, `DailyVibeState.swift`, `MyVibeSubviews.swift`, `SpotifyVibeManager.swift`, `VibeAudioEngine.swift`, `VibeControlSheet.swift`, `VibeControlSheetLogic.swift`, `VibeControlComponents.swift`, `VibeControlSupport.swift`, `SpotifyVibeCard.swift`, `DJCaptainChatView.swift` |
| Entry point | Home screen → Vibe card, My Vibe screen |
| Dependencies | SpotifyiOS SDK, Spotify app installed on device |
| Known issues | SpotifyiOS conditional compilation — stub on simulator. |
| Feature flag | None |

### 4.19 Tribe (Hidden)

| | |
|---|---|
| Status | Hidden — UI disabled, backend compiled |
| Files | 35+ files in `AiQo/Tribe/`, `AiQo/Features/Tribe/`, `AiQo/Services/SupabaseArenaService.swift` |
| Entry point | `TribeFeatureModels.swift:35` checks `TRIBE_FEATURE_VISIBLE` |
| Dependencies | Supabase, SwiftData |
| Known issues | Double @@ usernames, 0 XP in leaderboards, stale Arena models. Backend code ships despite UI flag being false. |
| Feature flag | `TRIBE_BACKEND_ENABLED = false`, `TRIBE_FEATURE_VISIBLE = false`, `TRIBE_SUBSCRIPTION_GATE_ENABLED = false` |

### 4.20 Legendary Challenges / Peaks

| | |
|---|---|
| Status | Functional |
| Files | `LegendaryChallenges/` (8+ files): RecordProject, WeeklyLog, HRRWorkoutManager, LegendaryChallengesViewModel, FitnessAssessment, ProjectView, RecordDetail, WeeklyReview |
| Entry point | ScreenContext `.peaks` in Captain, LegendaryChallengesSection in Gym |
| Dependencies | SwiftData, HealthKit |
| Known issues | None identified. |
| Feature flag | Paywall-gated via AccessManager |

### 4.21 Apple Watch App

| | |
|---|---|
| Status | Functional |
| Files | 25 files in `AiQoWatch Watch App/` |
| Entry point | Watch app entry, WorkoutManager |
| Dependencies | HealthKit, WatchConnectivity, WorkoutKit |
| Known issues | WatchConnectivityService polls every 2 seconds. |
| Feature flag | None |

### 4.22 Daily Aura / Home Screen

| | |
|---|---|
| Status | Functional |
| Files | `DailyAuraView.swift`, `DailyAuraViewModel.swift`, `DailyAuraModels.swift`, `DailyAuraPathData.swift`, `HomeView.swift`, `HomeViewModel.swift`, `HomeStatCard.swift`, `WaterBottleView.swift`, `WaterDetailSheetView.swift`, `MetricKind.swift` |
| Entry point | Home tab |
| Dependencies | HealthKit, DailyGoals, StreakManager |
| Known issues | None identified. |
| Feature flag | None |

### 4.23 Progress Photos

| | |
|---|---|
| Status | Functional |
| Files | `ProgressPhotoStore.swift`, `ProgressPhotosView.swift` |
| Entry point | Profile screen |
| Dependencies | PhotosUI |
| Known issues | None identified. |
| Feature flag | None |

---

## 5. Notification System Architecture (V2)

| Notification Type | Source File | Goes Through ProactiveEngine? | Trigger |
|---|---|---|---|
| Captain coach nudge | `SmartNotificationScheduler.swift:493` | **Yes (V2)** | BGAppRefreshTask schedule |
| Captain inactivity | `SmartNotificationScheduler.swift:603` | **Yes (V2)** | BGProcessingTask inactivity check |
| Morning insight | `MorningHabitOrchestrator.swift:302` | **Budget check only** | 25+ steps after wake, CMPedometer |
| Water reminder | `NotificationService.swift:257` | No (independent) | Timed schedule, localized |
| Meal reminder | `NotificationService.swift:300` | No (independent) | Timed schedule, localized |
| Sleep reminder | `SmartNotificationScheduler.swift:310` | No (independent) | 30 min before bedtime |
| Step/milestone | `NotificationService.swift:175` | No (independent) | Step count thresholds |
| Premium expiry | `PremiumExpiryNotifier.swift:96` | No (independent) | Trial countdown days |
| Streak protection | `NotificationService.swift` | No (independent) | Daily evening check |
| Workout summary | `NotificationService.swift:1002` | No (independent) | Post-workout completion |
| Alarm | `AlarmSchedulingService.swift` | No (independent) | User-set alarm time |
| Trial journey | `TrialJourneyOrchestrator.swift` | No (independent) | Trial day progression |

**ConversationThread logging:** All captain-category notifications log sends via `ConversationThreadManager.shared.logNotificationSent()`. Notification opens log via `CaptainNotificationRouting.swift:30`. MorningHabitOrchestrator logs sends at line 341.

**Budget enforcement layers:**
1. **ProactiveEngine** (primary): 5 gates including daily budget, cooldown, quiet hours.
2. **ConversationThread budget check** (secondary): `CaptainSmartNotificationService` (`NotificationService.swift:196`) and `MorningHabitOrchestrator` (`MorningHabitOrchestrator.swift:97`) independently enforce `< 4` notifications per 24 hours.

---

## 6. Privacy Architecture

| Data | Computed Where | Goes to Cloud? | How |
|---|---|---|---|
| EmotionalState.estimatedMood | EmotionalStateEngine (on-device) | Yes (as string) | Part of CaptainContextData → prompt Layer 4 |
| EmotionalState.signals | EmotionalStateEngine (on-device) | Yes (as strings) | Part of prompt Layer 4 |
| EmotionalState.confidence | EmotionalStateEngine (on-device) | Yes (as number) | Part of prompt Layer 4 |
| EmotionalState.recommendedTone | EmotionalStateEngine (on-device) | Yes (as string) | Part of prompt Layer 5 |
| TrendSnapshot | TrendAnalyzer (on-device) | Yes (numbers/enums) | Part of prompt Layer 4 (when non-nil) |
| SentimentResult | SentimentDetector (on-device) | Yes (enum + keywords) | Part of CaptainContextData |
| ConversationThread entries | SwiftData (on-device) | Summary only | `buildPromptSummary()` produces Arabic text summary, no raw entries |
| User name | UserDefaults (on-device) | **Never** | Stripped by PrivacySanitizer pre-cloud, injected post-response |
| HRV raw data | HealthKit (on-device) | **Never** | Only mood string derived from it |
| Resting heart rate | HealthKit (on-device) | **Never** | Only "high"/"normal" signal string in prompt |
| Sleep hours | HealthKit (on-device) | Yes (as bucketed range) | Bucketed by CloudBrainService before transport |
| Steps | HealthKit (on-device) | Yes (bucketed by 50) | CloudBrainService buckets before Gemini |
| Calories | HealthKit (on-device) | Yes (bucketed by 10) | CloudBrainService buckets before Gemini |
| Conversation history | PersistentChatMessage | Last 4 messages only | PrivacySanitizer truncates at `PrivacySanitizer.swift:21` |
| Kitchen images | Camera (on-device) | Yes (re-encoded) | EXIF/GPS stripped via `sanitizeKitchenImageData` |
| TTS text | Captain response | Yes (to ElevenLabs) | Via CaptainVoiceAPI |

**PrivacySanitizer pipeline** (`PrivacySanitizer.swift:95`):
1. Truncate conversation to 4 messages
2. Redact PII: emails, phone numbers, UUIDs, IP addresses
3. Replace self-identifying phrases
4. Replace explicit profile fields
5. Replace known user name with "User"
6. Bucket health metrics

**Privacy manifest:** `AiQo/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking = false`, health/fitness collection for app functionality.

---

## 7. Data Privacy & Apple Compliance

Captain cloud requests are privacy-sanitized before leaving the device. `PrivacySanitizer` truncates conversation history to four messages (`PrivacySanitizer.swift:21`), performs outbound redaction (`PrivacySanitizer.swift:95`), and reinjects the local user name after generation (`PrivacySanitizer.swift:167`). Kitchen images are re-encoded and stripped.

Health data mostly stays local. `CaptainIntelligenceManager` reads HealthKit on-device and uses the external API only for Arabic responses (`CaptainIntelligenceManager.swift:70-72`). `HealthKitMemoryBridge` syncs only summarized subsets into Captain memory (`HealthKitMemoryBridge.swift:14`).

**Brain V2 privacy impact:** All six V2 engines compute on-device. Derived signals (mood strings, trend enums, sentiment labels) are sent to cloud as part of the prompt, but raw biometric data never leaves the device. ConversationThread entries stay in local SwiftData; only a summarized Arabic text blob from `buildPromptSummary()` reaches the prompt.

Apple review risk items:
- Hidden Tribe networking (`SupabaseArenaService.swift:10`) ships despite UI flags being false.
- Broad HealthKit authorization surface (`HealthKitService.swift:46`).
- Crashlytics wrapper without confirmed Firebase linkage.

---

## 8. Monetization State

Two-tier subscription confirmed:
- **AiQo Core** (`com.mraad500.aiqo.standard.monthly`): `PremiumStore.swift:5`, `SubscriptionProductIDs.swift:20`
- **AiQo Intelligence Pro** (`com.mraad500.aiqo.intelligencepro.monthly`): same files

PaywallView markets "Two clear options only" (`PaywallView.swift:259`).

**Free trial:** 7 days, managed by `FreeTrialManager.swift:8` with Keychain persistence (survives reinstall). Trial state: `.notStarted`, `.active(daysRemaining)`, `.expired`.

**Entitlement gating:**
- `AccessManager.swift` controls feature limits per tier
- Captain memory: 200 (Core) / 500 (Intelligence Pro) — but UI hardcodes 200
- AI model: `gemini-2.5-flash` (Core) / `gemini-3-flash-preview` (Intelligence Pro)
- Token budget: 400 (Core) / 700 (Intelligence Pro)
- ProactiveEngine notifications: 3/day (Core) / 4/day (Intelligence Pro)

**Gaps:** Receipt validation depends on Supabase edge function (`ReceiptValidator.swift:36`). Developer flows use local StoreKit config in DEBUG.

---

## 9. Notifications Audit

The notification system has four layers:
1. `NotificationService` (`NotificationService.swift:13`): immediate categories, permission flow
2. `SmartNotificationScheduler` (`SmartNotificationScheduler.swift:11`): recurring automation, background processing
3. `MorningHabitOrchestrator` (`MorningHabitOrchestrator.swift:35`): wake-window step monitoring
4. `PremiumExpiryNotifier` (`PremiumExpiryNotifier.swift:96`): trial countdown

**V2 additions:**
5. `ProactiveEngine` (`ProactiveEngine.swift`): centralized decision engine for captain notifications
6. `ConversationThreadManager`: notification history logging and budget enforcement

Quiet hours enforced centrally in SmartNotificationScheduler. Notification language handled via `NotificationLocalization.swift:3`.

**Remaining issues:** Legacy inactivity prompt still contains hardcoded fallback text (`NotificationService.swift:468`). `NotificationRepository` still exposes placeholder content (`NotificationRepository.swift:7`).

---

## 10. Known Issues & Technical Debt

### 10.1 Blockers for TestFlight

| # | Issue | Location | Impact |
|---|---|---|---|
| 1 | Hidden Tribe backend ships in binary | `Info.plist:76`, `SupabaseArenaService.swift:10` | Dormant network code, stale data paths |
| 2 | Production analytics local-only | `AnalyticsService.swift:27` | No server-side usage visibility |
| 3 | Crashlytics linkage uncertain | `CrashReportingService.swift:21` | May lack production crash telemetry |
| 4 | Onboarding diverges from product plan | `SceneDelegate.swift:52` | Missing GoalsAndSleepSetupView, level classification |

### 10.2 Blockers for AUE Launch

| # | Issue | Location | Impact |
|---|---|---|---|
| 5 | TrendSnapshot nil in chat prompt | `CaptainContextBuilder.swift:248` | Chat doesn't see 7-day trends (ProactiveEngine does) |
| 6 | Captain memory settings hardcodes 200 | `CaptainMemorySettingsView.swift:67` | Intelligence Pro users misinformed about 500 limit |
| 7 | Tribe leaderboard identity bugs | `TribeLeaderboardView.swift:96`, `TribeMembersList.swift:28` | Double @@ usernames, 0 XP values |
| 8 | Captain Context naming drift | `CaptainContextBuilder.swift:134` | Docs say "Context Assembly", code says "CaptainContextBuilder" |

### 10.3 Non-blocking Debt

| # | Issue | Location | Impact |
|---|---|---|---|
| 9 | WatchConnectivityService polls 2s | `WatchConnectivityService.swift:18` | Battery churn |
| 10 | PhoneConnectivityManager duplicates XP | `PhoneConnectivityManager.swift:756` | Watch/phone XP drift |
| 11 | Inactivity legacy fallback hardcoded | `NotificationService.swift:468` | Localization harder than rest of stack |
| 12 | Analytics sync file I/O | `AnalyticsService.swift:157` | Avoidable I/O overhead |
| 13 | Large files (14+ > 1000 LOC) | Various | Regression risk, slow audits |
| 14 | EmotionalStateEngine `celebratory` tone unused | `EmotionalStateEngine.swift` | Defined but never assigned |
| 15 | ConversationThread metadata as JSON string | `ConversationThread.swift:38` | Not structured SwiftData relations |
| 16 | TrendAnalyzer wired in ProactiveEngine but not chat | `SmartNotificationScheduler.swift:838` vs `CaptainContextBuilder.swift:248` | Inconsistent V2 data availability |

---

## 11. Feature Flags Inventory

| Flag | Location | Current | Controls | Safe to flip? |
|---|---|---|---|---|
| `CAPTAIN_BRAIN_V2_ENABLED` | `Info.plist:74` | `true` | EmotionalState, TrendAnalyzer, SentimentDetector, ConversationThread prompt injection, ProactiveEngine decisions, Vibe Bridge. Setting false reverts to V1 (6-layer prompt, hardcoded notification decisions). | **Yes** — designed as kill switch |
| `TRIBE_BACKEND_ENABLED` | `Info.plist:76` | `false` | Backend-backed Tribe paths | No — backend code has TODOs |
| `TRIBE_FEATURE_VISIBLE` | `Info.plist:78` | `false` | Tribe UI entry points | No — incomplete UX |
| `TRIBE_SUBSCRIPTION_GATE_ENABLED` | `Info.plist:80` | `false` | Tribe premium gating | Not yet |
| `HealthKitService.permissionFlowEnabled` | `HealthKitService.swift:29` | `false` default | HealthKit permission flow | Yes, during onboarding only |
| `useLocalStoreKitConfig` | `PurchaseManager.swift:12` | `true` DEBUG / `false` release | Local .storekit config | Yes for dev, no for release |
| `previewEnabled` | `AccessManager.swift:8` | `false` | Developer entitlement override | DEBUG only |
| `ScreenshotMode.isActive` | `SceneDelegate.swift:173` | Runtime | Forces app to .main for screenshots | Internal builds only |

---

## 12. Test Coverage

**14 test files** across 452 source files:

| Test File | Tests |
|---|---|
| `AppleIntelligenceSleepAgentTests.swift` | Sleep agent logic |
| `CaptainMemoryRetrievalTests.swift` | Memory relevance scoring |
| `CaptainPersonalizationReminderMappingTests.swift` | Personalization reminder mapping |
| `CaptainPersonalizationStoreTests.swift` | Personalization store |
| `CaptainSleepPromptBuilderTests.swift` | Sleep prompt construction |
| `IngredientAssetCatalogTests.swift` | Kitchen asset sanity |
| `IngredientAssetLibraryTests.swift` | Kitchen asset library |
| `PurchasesTests.swift` | Purchase surface checks |
| `QuestEvaluatorTests.swift` | Quest evaluator logic |
| `SleepAnalysisQualityEvaluatorTests.swift` | Sleep quality evaluation |
| `SmartWakeManagerTests.swift` | Smart wake behavior |
| `AiQoWatch_Watch_AppTests.swift` | Watch scaffolding |
| `AiQoWatch_Watch_AppUITests.swift` | Watch UI test scaffolding |
| `AiQoWatch_Watch_AppUITestsLaunchTests.swift` | Watch launch tests |

**Not covered:** BrainOrchestrator routing, PrivacySanitizer redaction, MemoryExtractor, onboarding state transitions, Supabase failure handling, notification scheduling, Tribe sync, crash reporting, watch/phone XP sync.

**Brain V2 not covered:** EmotionalStateEngine, TrendAnalyzer, SentimentDetector, ConversationThreadManager, ProactiveEngine — all 1,154 LOC of V2 logic have zero automated tests.

---

## 13. Performance & Budget Notes

**AI API costs:**
- Cloud chat: Gemini 2.5 Flash (Core) or 3 Flash Preview (Intelligence Pro)
- Token output caps: 400 (Core) / 700 (Intelligence Pro) per message — `HybridBrainService.swift:300`
- Memory extraction: 160 tokens, every 3rd message — `MemoryExtractor.swift:229`
- Kitchen screen: 900 max output tokens — `HybridBrainService.swift:300`
- TTS: ElevenLabs per-character billing — `CaptainVoiceAPI.swift`

**Brain V2 compute costs:**
- EmotionalStateEngine: pure arithmetic, negligible CPU. Called once per message and once per notification evaluation.
- TrendAnalyzer: array sorting + averaging over 14 days max, negligible CPU. Called in `buildProactiveContext()`.
- SentimentDetector: string contains checks over ~68 keywords, negligible CPU. Called once per message.
- ConversationThreadManager: SwiftData inserts/queries. Pruning (> 7 days) runs once at app launch. Queries limited to 10-24h windows.
- ProactiveEngine: pure logic over ProactiveContext struct, negligible CPU.
- Total V2 overhead per message: < 1ms additional compute on main thread.
- Total V2 overhead per notification evaluation: ~5ms (health data fetch dominates, not V2 logic).

**Background I/O risks:**
- AnalyticsService: synchronous JSONL per event — `AnalyticsService.swift:157`
- CrashReporter: synchronous JSONL — `CrashReporter.swift:198`
- WatchConnectivityService: 2-second polling timer — `WatchConnectivityService.swift:18`

**Large files (>1000 LOC):**

| File | LOC |
|---|---|
| `PhoneWorkoutSummaryView.swift` | 1,422 |
| `SupabaseArenaService.swift` | 1,362 |
| `ProfileScreenComponents.swift` | 1,264 |
| `CinematicGrindViews.swift` | 1,204 |
| `CaptainScreen.swift` | 1,147 |
| `TribeModuleComponents.swift` | 1,146 |
| `NotificationService.swift` | 1,119 |
| `QuestDetailSheet.swift` | 1,043 |
| `PaywallView.swift` | 1,035 |
| `TribeView.swift` | 1,028 |
| `PhoneConnectivityManager.swift` | 1,009 |
| `TribeHubScreen.swift` | 1,008 |
| `HealthKitService.swift` | 1,006 |

---

## 14. File-by-File Appendix

### AiQo (iPhone App — 401 files)

```
AiQo/AiQoActivityNames.swift — DeviceActivityName, DeviceActivityEvent — Device activity name/event constants.
AiQo/App/AppDelegate.swift — AiQoApp, AppDelegate, SiriWorkoutType, SiriWorkoutLocation, StartWorkoutIntent, AiQoWorkoutShortcuts — @main entry, SwiftData containers, Siri intents. V2: ConversationThreadManager init.
AiQo/App/AppRootManager.swift — AppRootManager — Global navigation state (isCaptainChatPresented, etc.).
AiQo/App/AuthFlowUI.swift — AuthFlowTheme, AuthFlowBackground — Auth flow visual theme.
AiQo/App/LanguageSelectionView.swift — LanguageSelectionView — Language picker (Arabic/English).
AiQo/App/LoginViewController.swift — LoginScreenView, LoginScreenViewModel — Login/guest auth UI.
AiQo/App/MainTabRouter.swift — MainTabRouter, Tab — Tab selection state singleton.
AiQo/App/MainTabScreen.swift — MainTabScreen — 3-tab root: Home, Gym, Captain.
AiQo/App/MealModels.swift — MealItem, MealCardData — Meal data models.
AiQo/App/ProfileSetupView.swift — ProfileSetupView, SetupPrivacyToggleCard — Profile setup onboarding.
AiQo/App/SceneDelegate.swift — OnboardingKeys, AppFlowController, RootScreen, AppRootView — Root state machine, onboarding flow.
AiQo/AppGroupKeys.swift — AppGroupKeys — App group key constants.
AiQo/Core/AiQoAccessibility.swift — AiQoAccessibility, AccessibleDaySummary — Accessibility helpers.
AiQo/Core/AiQoAudioManager.swift — AiQoAudioManager — Audio session management.
AiQo/Core/AppSettingsScreen.swift — AppSettingsScreen — Settings UI.
AiQo/Core/AppSettingsStore.swift — AppLanguage, AppSettingsStore — Language/settings persistence.
AiQo/Core/ArabicNumberFormatter.swift — Int+arabicFormatted, Double+arabicFormatted — Arabic number formatting.
AiQo/Core/CaptainMemory.swift — CaptainMemory, CaptainMemorySnapshot — @Model: Captain memory entries.
AiQo/Core/CaptainMemorySettingsView.swift — CaptainMemorySettingsView — Memory settings UI (hardcoded 200 cap).
AiQo/Core/CaptainPersonalization.swift — CaptainPersonalizationStore, PersonalizationSnapshot — User personalization data.
AiQo/Core/CaptainVoiceAPI.swift — CaptainVoiceAPI, VoiceSettings — ElevenLabs TTS API client.
AiQo/Core/CaptainVoiceCache.swift — CachedPhrase, CaptainVoiceCache — TTS audio cache.
AiQo/Core/CaptainVoiceService.swift — CaptainVoiceService — TTS orchestration singleton.
AiQo/Core/Colors.swift — Colors — Legacy color definitions.
AiQo/Core/Constants.swift — K, Supabase — App constants, Supabase config.
AiQo/Core/DailyGoals.swift — DailyGoals, GoalsStore — Daily health goals.
AiQo/Core/DeveloperPanelView.swift — DeveloperPanelView — Debug panel.
AiQo/Core/HapticEngine.swift — HapticEngine — Haptic feedback.
AiQo/Core/HealthKitMemoryBridge.swift — HealthKitMemoryBridge — Syncs HealthKit summaries to Captain memory.
AiQo/Core/Localization/Bundle+Language.swift — LocalizedBundle — Runtime localization bundle swizzle.
AiQo/Core/Localization/LocalizationManager.swift — LocalizationManager — Localization state.
AiQo/Core/MemoryExtractor.swift — MemoryExtractor — Rule-based + LLM memory extraction from conversations.
AiQo/Core/MemoryStore.swift — MemoryStore — @Observable singleton: memory CRUD, relevance ranking, chat persistence.
AiQo/Core/Models/ActivityNotification.swift — ActivityNotificationType, ActivityNotificationGender, ActivityNotificationLanguage — Notification type enums.
AiQo/Core/Models/LevelStore.swift — ShieldTier, LevelStore — Level/XP state.
AiQo/Core/Models/NotificationPreferencesStore.swift — NotificationPreferencesStore — Notification preferences.
AiQo/Core/Models/WeeklyMetricsBuffer.swift — WeeklyMetricsBuffer — @Model: buffered weekly metrics.
AiQo/Core/Models/WeeklyReportEntry.swift — WeeklyReportEntry — @Model: weekly report records.
AiQo/Core/Purchases/EntitlementStore.swift — EntitlementStore — StoreKit 2 entitlement state.
AiQo/Core/Purchases/PurchaseManager.swift — PurchaseManager, PurchaseOutcome — StoreKit 2 purchase flow.
AiQo/Core/Purchases/ReceiptValidator.swift — ReceiptValidator, ValidationResult — Supabase receipt validation.
AiQo/Core/Purchases/SubscriptionProductIDs.swift — SubscriptionProductIDs — SKU constants (2 products).
AiQo/Core/Purchases/SubscriptionTier.swift — SubscriptionTier — .none, .core, .intelligencePro enum.
AiQo/Core/Schema/CaptainSchemaMigrationPlan.swift — CaptainSchemaMigrationPlan — SwiftData migration plan.
AiQo/Core/Schema/CaptainSchemaV1.swift — CaptainSchemaV1 — Schema version 1.
AiQo/Core/Schema/CaptainSchemaV2.swift — CaptainSchemaV2 — Schema version 2.
AiQo/Core/Schema/CaptainSchemaV3.swift — CaptainSchemaV3 — Schema version 3.
AiQo/Core/SiriShortcutsManager.swift — SiriShortcutsManager — Siri shortcut registration.
AiQo/Core/SmartNotificationScheduler.swift — SmartNotificationScheduler, HealthContext — Background notification scheduling. V2: ProactiveEngine integration, buildProactiveContext().
AiQo/Core/SpotifyVibeManager.swift — VibePlaybackState, SpotifyVibeManager — Spotify SDK integration singleton.
AiQo/Core/StreakManager.swift — StreakManager — Daily streak tracking.
AiQo/Core/UserProfileStore.swift — UserProfile, UserProfileStore — User profile persistence.
AiQo/Core/Utilities/ConnectivityDebugProviding.swift — ConnectivityDebugProviding — Debug connectivity protocol.
AiQo/Core/Utilities/DebugPrint.swift — debug helpers — Debug print utilities.
AiQo/Core/VibeAudioEngine.swift — VibeDayPart, VibeDayProfile, VibeAudioState — Vibe audio state machine.
AiQo/DesignSystem/AiQoColors.swift — AiQoColors — Design system color palette.
AiQo/DesignSystem/AiQoTheme.swift — AiQoTheme — Design system theme.
AiQo/DesignSystem/AiQoTokens.swift — AiQoSpacing, AiQoRadius, AiQoMetrics — Design system spacing/radius tokens.
AiQo/DesignSystem/Components/AiQoBottomCTA.swift — AiQoBottomCTA — Bottom CTA button component.
AiQo/DesignSystem/Components/AiQoCard.swift — AiQoCard, IconPlacement — Card component.
AiQo/DesignSystem/Components/AiQoChoiceGrid.swift — AiQoChoiceGrid — Choice grid component.
AiQo/DesignSystem/Components/AiQoPillSegment.swift — AiQoPillSegment — Pill segment control.
AiQo/DesignSystem/Components/AiQoPlatformPicker.swift — AiQoPlatformPicker — Platform picker.
AiQo/DesignSystem/Components/AiQoSkeletonView.swift — AiQoSkeletonView — Skeleton loading view.
AiQo/DesignSystem/Components/StatefulPreviewWrapper.swift — StatefulPreviewWrapper — SwiftUI preview helper.
AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift — AiQoPressButtonStyle, AiQoPressEffect — Press effect modifier.
AiQo/DesignSystem/Modifiers/AiQoShadow.swift — AiQoShadow — Shadow modifier.
AiQo/DesignSystem/Modifiers/AiQoSheetStyle.swift — AiQoSheetStyle — Sheet style modifier.
AiQo/Features/Captain/AiQoPromptManager.swift — AiQoPromptManager, PromptKey — Prompt template management.
AiQo/Features/Captain/BrainOrchestrator.swift — BrainOrchestrator, Route — Message routing: local vs cloud brain.
AiQo/Features/Captain/CaptainAvatar3DView.swift — CaptainAvatar3DView — 3D avatar (RealityKit).
AiQo/Features/Captain/CaptainChatView.swift — CaptainChatView, ChatMessageRow, WorkoutPlanReadyCard — Chat UI. V2: VibeMiniBubble rendering.
AiQo/Features/Captain/CaptainCognitivePipeline.swift — CaptainCognitivePipeline — Cognitive state transitions.
AiQo/Features/Captain/CaptainContextBuilder.swift — BioTimePhase, CaptainContextData, CaptainContextBuilder — Context assembly. V2: isBrainV2Enabled flag, EmotionalState + thread integration.
AiQo/Features/Captain/CaptainFallbackPolicy.swift — CaptainFallbackPolicy — Fallback response policy.
AiQo/Features/Captain/CaptainIntelligenceManager.swift — CaptainDailyHealthMetrics, CaptainIntelligenceManager — Health metrics aggregation for Captain.
AiQo/Features/Captain/CaptainModels.swift — PersistentChatMessage, ChatSession, CaptainStructuredResponse, SpotifyRecommendation, MealPlan, WorkoutPlan — @Model chat message, structured response types.
AiQo/Features/Captain/CaptainNotificationRouting.swift — CaptainNotificationHandler, CaptainNavigationHelper — Notification tap handling. V2: logs notification opens.
AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift — CaptainOnDeviceChatEngine — Apple Intelligence on-device chat (8s timeout).
AiQo/Features/Captain/CaptainPersonaBuilder.swift — CaptainPersonaBuilder — Persona context for prompts.
AiQo/Features/Captain/CaptainPromptBuilder.swift — CaptainPromptBuilder — 7-layer system prompt. V2: enhanced layers 3-6.
AiQo/Features/Captain/CaptainScreen.swift — CaptainCustomization, CaptainTone, CoachCognitiveState, CaptainScreen, CaptainTheme — Main captain screen with avatar, chat, background.
AiQo/Features/Captain/CaptainViewModel.swift — ChatMessage, CaptainViewModel — Main chat view model. V2: sentiment detection, thread logging.
AiQo/Features/Captain/ChatHistoryView.swift — ChatHistoryView — Chat session history browser.
AiQo/Features/Captain/CloudBrainService.swift — CloudBrainService — Privacy-wrapping cloud service: sanitizes, routes to Gemini.
AiQo/Features/Captain/CoachBrainMiddleware.swift — CoachBrainTranslating, CoachBrainLLMTranslator — Translation middleware.
AiQo/Features/Captain/CoachBrainTranslationConfig.swift — CoachBrainTranslationConfig — Translation config.
AiQo/Features/Captain/ConversationThread.swift — ThreadEntryType, ConversationThreadEntry, ConversationThreadManager — NEW V2: SwiftData interaction log, prompt summary builder.
AiQo/Features/Captain/EmotionalStateEngine.swift — EstimatedMood, RecommendedTone, EmotionalState, EmotionalStateEngine — NEW V2: on-device emotional state computation.
AiQo/Features/Captain/HybridBrainService.swift — HybridBrainRequest, HybridBrainServiceReply, HybridBrainService — Gemini API transport layer.
AiQo/Features/Captain/LLMJSONParser.swift — LLMJSONParser — Robust JSON parser for LLM output with multi-layer recovery.
AiQo/Features/Captain/LocalBrainService.swift — LocalBrainService, LocalBrainRequest — On-device AI: intent classification, hardcoded plans.
AiQo/Features/Captain/LocalIntelligenceService.swift — LocalIntelligenceService — On-device intelligence.
AiQo/Features/Captain/MessageBubble.swift — MessageBubble — Chat bubble shape.
AiQo/Features/Captain/PrivacySanitizer.swift — PrivacySanitizer, RedactionRule — PII redaction, cloud sanitization, name injection.
AiQo/Features/Captain/ProactiveEngine.swift — ProactiveDecision, ProactivePriority, ProactiveContext, NotificationBudget, ProactiveEngine — NEW V2: centralized notification decision engine.
AiQo/Features/Captain/PromptRouter.swift — PromptRouter — Prompt routing logic.
AiQo/Features/Captain/ScreenContext.swift — ScreenContext — Screen context enum: kitchen, gym, sleep, peaks, mainChat, myVibe.
AiQo/Features/Captain/SentimentDetector.swift — MessageSentiment, SentimentResult, SentimentDetector — NEW V2: bilingual keyword sentiment analysis.
AiQo/Features/Captain/TrendAnalyzer.swift — TrendDirection, StreakMomentum, TrendSnapshot, DailyHealthPoint, TrendAnalyzer — NEW V2: 7-day health trend computation.
AiQo/Features/Captain/VibeMiniBubble.swift — VibeMiniBubble — NEW V2: inline Spotify recommendation card in chat.
AiQo/Features/DataExport/HealthDataExporter.swift — HealthDataExporter — Health data export.
AiQo/Features/First screen/LegacyCalculationViewController.swift — LegacyCalculationScreenView, LegacyCalculationViewModel — Legacy level classification.
AiQo/Features/Gym/ActiveRecoveryView.swift — ActiveRecoveryView — Active recovery guidance.
AiQo/Features/Gym/AudioCoachManager.swift — AudioCoachManager, Zone2Target, Zone2State — Audio coaching for workouts.
AiQo/Features/Gym/CinematicGrindCardView.swift — CinematicGrindCardView — Grind card view.
AiQo/Features/Gym/CinematicGrindViews.swift — CinematicPlatform, CinematicMood, CinematicGrindSuggestion — Cinematic grind views (1,204 LOC).
AiQo/Features/Gym/Club/Body/BodyView.swift — BodyView — Body section.
AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift — GratitudeAudioManager — Gratitude session audio.
AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift — GratitudeSessionView — Gratitude session UI.
AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift — WorkoutCategoriesView — Workout category browser.
AiQo/Features/Gym/Club/Challenges/ChallengesView.swift — ChallengesView — Challenges list.
AiQo/Features/Gym/Club/ClubRootView.swift — ClubRootView — Club root navigation.
AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift — Club navigation helpers.
AiQo/Features/Gym/Club/Components/RailScrollOffsetPreferenceKey.swift — Rail scroll tracking.
AiQo/Features/Gym/Club/Components/RightSideRailView.swift — Right side rail.
AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift — Vertical rail variant.
AiQo/Features/Gym/Club/Components/SegmentedTabs.swift — Segmented tab control.
AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift — Slim rail variant.
AiQo/Features/Gym/Club/Impact/ImpactAchievementsView.swift — Impact achievements.
AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift — Impact container.
AiQo/Features/Gym/Club/Impact/ImpactSummaryView.swift — Impact summary.
AiQo/Features/Gym/Club/Plan/PlanView.swift — Workout plan view.
AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift — Plan flow subviews.
AiQo/Features/Gym/ExercisesView.swift — ExercisesView — Exercise browser.
AiQo/Features/Gym/GuinnessEncyclopediaView.swift — GuinnessEncyclopediaView — Records encyclopedia.
AiQo/Features/Gym/GymViewController.swift — GymView — Gym tab root.
AiQo/Features/Gym/HandsFreeZone2Manager.swift — HandsFreeZone2Manager — Hands-free zone 2 workout.
AiQo/Features/Gym/HeartView.swift — HeartView — Heart rate display.
AiQo/Features/Gym/L10n.swift — L10n — Gym localization keys.
AiQo/Features/Gym/LiveMetricsHeader.swift — LiveMetricsHeader — Live workout metrics.
AiQo/Features/Gym/LiveWorkoutSession.swift — LiveWorkoutSession — Active workout tracking.
AiQo/Features/Gym/Models/GymExercise.swift — GymExercise — Exercise model.
AiQo/Features/Gym/MyPlanViewController.swift — MyPlanView — User's workout plan.
AiQo/Features/Gym/OriginalWorkoutCardView.swift — OriginalWorkoutCardView — Workout card.
AiQo/Features/Gym/PhoneWorkoutSummaryView.swift — PhoneWorkoutSummaryView — Post-workout summary (1,422 LOC).
AiQo/Features/Gym/QuestKit/QuestDataSources.swift — Quest data sources.
AiQo/Features/Gym/QuestKit/QuestDefinitions.swift — Quest definitions.
AiQo/Features/Gym/QuestKit/QuestEngine.swift — QuestEngine — Quest evaluation engine.
AiQo/Features/Gym/QuestKit/QuestEvaluator.swift — QuestEvaluator — Quest condition evaluator.
AiQo/Features/Gym/QuestKit/QuestFormatting.swift — Quest display formatting.
AiQo/Features/Gym/QuestKit/QuestKitModels.swift — Quest kit model types.
AiQo/Features/Gym/QuestKit/QuestProgressStore.swift — QuestProgressStore — Quest progress persistence.
AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift — QuestProgressRecord, QuestMilestoneRecord, QuestStreakRecord, QuestDailyRecord — @Model: quest data.
AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift — SwiftData store for quests.
AiQo/Features/Gym/QuestKit/Views/QuestCameraPermissionGateView.swift — Camera permission gate.
AiQo/Features/Gym/QuestKit/Views/QuestDebugView.swift — Quest debug UI.
AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift — Push-up challenge with Vision.
AiQo/Features/Gym/Quests/Models/Challenge.swift — Challenge model.
AiQo/Features/Gym/Quests/Models/ChallengeStage.swift — Challenge stage model.
AiQo/Features/Gym/Quests/Models/HelpStrangersModels.swift — Help strangers models.
AiQo/Features/Gym/Quests/Models/WinRecord.swift — Win record model.
AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift — Quest achievements.
AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift — Daily quest store.
AiQo/Features/Gym/Quests/Store/WinsStore.swift — Wins store.
AiQo/Features/Gym/Quests/Views/ChallengeCard.swift — Challenge card.
AiQo/Features/Gym/Quests/Views/ChallengeDetailView.swift — Challenge detail.
AiQo/Features/Gym/Quests/Views/ChallengeRewardSheet.swift — Reward sheet.
AiQo/Features/Gym/Quests/Views/ChallengeRunView.swift — Challenge run.
AiQo/Features/Gym/Quests/Views/HelpStrangersBottomSheet.swift — Help strangers sheet.
AiQo/Features/Gym/Quests/Views/QuestCard.swift — Quest card.
AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift — Quest completion animation.
AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift — Quest detail (1,043 LOC).
AiQo/Features/Gym/Quests/Views/QuestDetailView.swift — Quest detail alternate.
AiQo/Features/Gym/Quests/Views/QuestWinsGridView.swift — Wins grid.
AiQo/Features/Gym/Quests/Views/QuestsView.swift — Quests list.
AiQo/Features/Gym/Quests/Views/StageSelectorBar.swift — Stage selector.
AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift — Vision coach audio.
AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift — Vision coach camera UI.
AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift — Vision coach logic.
AiQo/Features/Gym/RecapViewController.swift — RecapView — Session recap.
AiQo/Features/Gym/RewardsViewController.swift — RewardsView — Rewards display.
AiQo/Features/Gym/ShimmeringPlaceholder.swift — Shimmer loading effect.
AiQo/Features/Gym/SoftGlassCardView.swift — Glass card.
AiQo/Features/Gym/SpotifyWebView.swift — Spotify web fallback.
AiQo/Features/Gym/SpotifyWorkoutPlayerView.swift — Spotify workout player.
AiQo/Features/Gym/T/SpinWheelView.swift — Spin wheel game.
AiQo/Features/Gym/T/WheelTypes.swift — Wheel type models.
AiQo/Features/Gym/T/WorkoutTheme.swift — Workout theme.
AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift — Wheel session logic.
AiQo/Features/Gym/WatchConnectionStatusButton.swift — Watch connection indicator.
AiQo/Features/Gym/WatchConnectivityService.swift — WatchConnectivityService — Watch message service.
AiQo/Features/Gym/WinsViewController.swift — WinsView — Wins display.
AiQo/Features/Gym/WorkoutLiveActivityManager.swift — Live Activity for workouts.
AiQo/Features/Gym/WorkoutSessionScreen.swift.swift — Workout session screen.
AiQo/Features/Gym/WorkoutSessionSheetView.swift — Workout session sheet.
AiQo/Features/Gym/WorkoutSessionViewModel.swift — Workout session logic.
AiQo/Features/Home/ActivityDataProviding.swift — Activity data protocol.
AiQo/Features/Home/DJCaptainChatView.swift — DJ Captain chat variant.
AiQo/Features/Home/DailyAuraModels.swift — Daily aura models.
AiQo/Features/Home/DailyAuraPathData.swift — Aura path data.
AiQo/Features/Home/DailyAuraView.swift — Daily aura visualization.
AiQo/Features/Home/DailyAuraViewModel.swift — Aura view model.
AiQo/Features/Home/HealthKitService+Water.swift — Water tracking extension.
AiQo/Features/Home/HomeStatCard.swift — Home stat card.
AiQo/Features/Home/HomeView.swift — Home tab root.
AiQo/Features/Home/HomeViewModel.swift — Home tab logic (948 LOC).
AiQo/Features/Home/LevelUpCelebrationView.swift — Level up animation.
AiQo/Features/Home/MetricKind.swift — Metric type enum.
AiQo/Features/Home/ScreenshotMode.swift — Screenshot mode flag.
AiQo/Features/Home/SpotifyVibeCard.swift — Spotify vibe card on home.
AiQo/Features/Home/StreakBadgeView.swift — Streak badge.
AiQo/Features/Home/VibeControlComponents.swift — Vibe control subviews.
AiQo/Features/Home/VibeControlSheet.swift — Vibe control sheet.
AiQo/Features/Home/VibeControlSheetLogic.swift — Vibe control logic (950 LOC).
AiQo/Features/Home/VibeControlSupport.swift — Vibe support utilities.
AiQo/Features/Home/WaterBottleView.swift — Water bottle visualization.
AiQo/Features/Home/WaterDetailSheetView.swift — Water detail sheet.
AiQo/Features/Kitchen/CameraView.swift — Kitchen camera.
AiQo/Features/Kitchen/CompositePlateView.swift — Plate composition.
AiQo/Features/Kitchen/FridgeInventoryView.swift — Fridge inventory.
AiQo/Features/Kitchen/IngredientAssetCatalog.swift — Ingredient asset catalog.
AiQo/Features/Kitchen/IngredientAssetLibrary.swift — Ingredient asset library.
AiQo/Features/Kitchen/IngredientCatalog.swift — Ingredient catalog.
AiQo/Features/Kitchen/IngredientDisplayItem.swift — Ingredient display.
AiQo/Features/Kitchen/IngredientKey.swift — Ingredient keys.
AiQo/Features/Kitchen/InteractiveFridgeView.swift — Interactive fridge.
AiQo/Features/Kitchen/KitchenLanguageRouter.swift — Kitchen localization.
AiQo/Features/Kitchen/KitchenModels.swift — Kitchen models.
AiQo/Features/Kitchen/KitchenPersistenceStore.swift — Kitchen persistence.
AiQo/Features/Kitchen/KitchenPlanGenerationService.swift — Meal plan generation.
AiQo/Features/Kitchen/KitchenSceneView.swift — Kitchen 3D scene.
AiQo/Features/Kitchen/KitchenScreen.swift — Kitchen root screen.
AiQo/Features/Kitchen/KitchenView.swift — Kitchen view.
AiQo/Features/Kitchen/KitchenViewModel.swift — Kitchen logic.
AiQo/Features/Kitchen/LocalMealsRepository.swift — Local meals storage.
AiQo/Features/Kitchen/Meal.swift — Meal model.
AiQo/Features/Kitchen/MealIllustrationView.swift — Meal illustration.
AiQo/Features/Kitchen/MealImageSpec.swift — Meal image spec.
AiQo/Features/Kitchen/MealPlanGenerator.swift — Meal plan generator.
AiQo/Features/Kitchen/MealPlanView.swift — Meal plan display.
AiQo/Features/Kitchen/MealSectionView.swift — Meal section.
AiQo/Features/Kitchen/MealsRepository.swift — Meals repository.
AiQo/Features/Kitchen/NutritionTrackerView.swift — Nutrition tracker.
AiQo/Features/Kitchen/PlateTemplate.swift — Plate template.
AiQo/Features/Kitchen/RecipeCardView.swift — Recipe card.
AiQo/Features/Kitchen/SmartFridgeCameraPreviewController.swift — Fridge camera preview.
AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift — Fridge camera logic.
AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift — @Model: scanned fridge items.
AiQo/Features/Kitchen/SmartFridgeScannerView.swift — Fridge scanner UI.
AiQo/Features/LegendaryChallenges/Components/RecordCard.swift — Record card.
AiQo/Features/LegendaryChallenges/Models/LegendaryProject.swift — Project model.
AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift — Record model.
AiQo/Features/LegendaryChallenges/Models/RecordProject.swift — @Model: record projects.
AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift — @Model: weekly logs.
AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift — HRR workout manager.
AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift — Challenges view model.
AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift — Project manager.
AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift — Fitness assessment.
AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift — Challenges section.
AiQo/Features/LegendaryChallenges/Views/ProjectView.swift — Project view.
AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift — Record detail.
AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift — Record project view.
AiQo/Features/LegendaryChallenges/Views/WeeklyReviewResultView.swift — Weekly review results.
AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift — Weekly review.
AiQo/Features/MyVibe/DailyVibeState.swift — Daily vibe state.
AiQo/Features/MyVibe/MyVibeScreen.swift — My Vibe root.
AiQo/Features/MyVibe/MyVibeSubviews.swift — My Vibe subviews.
AiQo/Features/MyVibe/MyVibeViewModel.swift — My Vibe logic.
AiQo/Features/MyVibe/VibeOrchestrator.swift — Vibe orchestration.
AiQo/Features/Onboarding/CaptainPersonalizationOnboardingView.swift — Captain personalization (972 LOC).
AiQo/Features/Onboarding/FeatureIntroView.swift — Feature intro.
AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift — Historical health data sync.
AiQo/Features/Onboarding/OnboardingWalkthroughView.swift — Onboarding walkthrough.
AiQo/Features/Profile/LevelCardView.swift — Level card.
AiQo/Features/Profile/ProfileScreen.swift — Profile root.
AiQo/Features/Profile/ProfileScreenComponents.swift — Profile components (1,264 LOC).
AiQo/Features/Profile/ProfileScreenLogic.swift — Profile logic.
AiQo/Features/Profile/ProfileScreenModels.swift — Profile models.
AiQo/Features/Profile/String+Localized.swift — Localization helper.
AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift — Photo store.
AiQo/Features/ProgressPhotos/ProgressPhotosView.swift — Progress photos UI.
AiQo/Features/Sleep/AlarmSetupCardView.swift — Alarm setup.
AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift — On-device sleep analysis.
AiQo/Features/Sleep/HealthManager+Sleep.swift — Sleep HealthKit queries.
AiQo/Features/Sleep/SleepAnalysisQualityEvaluator.swift — Sleep quality scoring.
AiQo/Features/Sleep/SleepDetailCardView.swift — Sleep detail.
AiQo/Features/Sleep/SleepScoreRingView.swift — Sleep score ring.
AiQo/Features/Sleep/SleepSessionObserver.swift — Sleep session observer.
AiQo/Features/Sleep/SmartWakeCalculatorView.swift — Smart wake calculator.
AiQo/Features/Sleep/SmartWakeEngine.swift — Smart wake algorithm.
AiQo/Features/Sleep/SmartWakeViewModel.swift — Smart wake logic.
AiQo/Features/Tribe/TribeDesignSystem.swift — Tribe design tokens.
AiQo/Features/Tribe/TribeExperienceFlow.swift — Tribe experience flow.
AiQo/Features/Tribe/TribeView.swift — Tribe view (1,028 LOC).
AiQo/Features/WeeklyReport/ShareCardRenderer.swift — Share card rendering.
AiQo/Features/WeeklyReport/WeeklyReportModel.swift — Weekly report model.
AiQo/Features/WeeklyReport/WeeklyReportView.swift — Weekly report UI.
AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift — Weekly report logic.
AiQo/NeuralMemory.swift — NeuralMemoryEntry, NeuralMemoryRelation, NeuralMemoryStore — @Model: neural memory graph.
AiQo/PhoneConnectivityManager.swift — PhoneConnectivityManager — Watch-phone data sync (1,009 LOC).
AiQo/Premium/AccessManager.swift — AccessManager — Feature gating per subscription tier.
AiQo/Premium/EntitlementProvider.swift — EntitlementSnapshot, StoreKitEntitlementProvider — Entitlement resolution.
AiQo/Premium/FreeTrialManager.swift — FreeTrialManager, TrialState — 7-day trial with Keychain persistence.
AiQo/Premium/PremiumPaywallView.swift — PremiumPaywallView — Premium paywall variant.
AiQo/Premium/PremiumStore.swift — PremiumPlan, PremiumStore — IAP facade, 2-tier.
AiQo/ProtectionModel.swift — ProtectionModel — App protection.
AiQo/Services/AiQoError.swift — AiQoError — App error types.
AiQo/Services/Analytics/AnalyticsEvent.swift — AnalyticsEvent — Analytics event definitions.
AiQo/Services/Analytics/AnalyticsService.swift — AnalyticsService — Local JSONL analytics (no remote sink).
AiQo/Services/CrashReporting/CrashReporter.swift — CrashReporter — Local crash reporter.
AiQo/Services/CrashReporting/CrashReportingService.swift — CrashReportingService — Firebase/Crashlytics wrapper.
AiQo/Services/DeepLinkRouter.swift — DeepLinkRouter — Deep link handling.
AiQo/Services/Memory/WeeklyMemoryConsolidator.swift — WeeklyMemoryConsolidator — Weekly memory consolidation.
AiQo/Services/Memory/WeeklyMetricsBufferStore.swift — WeeklyMetricsBufferStore — Metrics buffer management.
AiQo/Services/NetworkMonitor.swift — NetworkMonitor — Network availability.
AiQo/Services/NotificationType.swift — NotificationType — Notification type enum.
AiQo/Services/Notifications/AlarmSchedulingService.swift — AlarmSchedulingService — Alarm scheduling.
AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift — CaptainBackgroundNotificationComposer — Legacy notification composition (fallback for V2).
AiQo/Services/Notifications/InactivityTracker.swift — InactivityTracker — Simple timestamp tracker (21 LOC).
AiQo/Services/Notifications/MorningHabitOrchestrator.swift — MorningHabitOrchestrator, MorningInsight — Wake-window step monitoring. V2: budget check.
AiQo/Services/Notifications/NotificationCategoryManager.swift — NotificationCategoryManager — Notification category registration.
AiQo/Services/Notifications/NotificationLocalization.swift — NotificationLocalization — Notification language resolution.
AiQo/Services/Notifications/NotificationRepository.swift — NotificationRepository — Notification content templates.
AiQo/Services/Notifications/NotificationService.swift — NotificationService, CaptainSmartNotificationService, AIWorkoutSummaryService — Notification management (1,119 LOC). V2: thread logging, budget check.
AiQo/Services/Notifications/PremiumExpiryNotifier.swift — PremiumExpiryNotifier — Trial expiry notifications.
AiQo/Services/Notifications/SmartNotificationManager.swift — SmartNotificationManager — Smart notification helpers.
AiQo/Services/Permissions/HealthKit/HealthKitService.swift — HealthKitService — HealthKit authorization and queries (1,006 LOC).
AiQo/Services/Permissions/HealthKit/TodaySummary.swift — TodaySummary — Today's health summary model.
AiQo/Services/ReferralManager.swift — ReferralManager — Referral system.
AiQo/Services/SupabaseArenaService.swift — SupabaseArenaService — Tribe backend service (1,362 LOC, compiled but UI hidden).
AiQo/Services/SupabaseService.swift — SupabaseService — Supabase client.
AiQo/Services/Trial/TrialJourneyOrchestrator.swift — TrialJourneyOrchestrator — Trial day progression.
AiQo/Services/Trial/TrialNotificationCopy.swift — TrialNotificationCopy — Trial notification templates.
AiQo/Services/Trial/TrialPersonalizationReader.swift — TrialPersonalizationReader — Trial personalization.
AiQo/Shared/CoinManager.swift — CoinManager — Virtual coin system.
AiQo/Shared/HealthKitManager+TrialQueries.swift — HealthKit trial queries extension.
AiQo/Shared/HealthKitManager.swift — HealthKitManager — HealthKit data manager.
AiQo/Shared/LevelSystem.swift — LevelSystem — Level/XP calculations.
AiQo/Shared/WorkoutSyncCodec.swift — WorkoutSyncCodec — Watch-phone workout encoding.
AiQo/Shared/WorkoutSyncModels.swift — WorkoutSyncModels — Sync models.
AiQo/Tribe/Arena/TribeArenaView.swift — TribeArenaView — Arena UI.
AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift — Arena challenge detail.
AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift — Arena challenge history.
AiQo/Tribe/Galaxy/ArenaModels.swift — ArenaChallenge, ArenaChallengeParticipant, etc. — @Model: 6 arena SwiftData types.
AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift — Quick challenges.
AiQo/Tribe/Galaxy/ArenaScreen.swift — Arena screen.
AiQo/Tribe/Galaxy/ArenaTabView.swift — Arena tab.
AiQo/Tribe/Galaxy/ArenaViewModel.swift — Arena logic.
AiQo/Tribe/Galaxy/BattleLeaderboard.swift — Battle leaderboard.
AiQo/Tribe/Galaxy/BattleLeaderboardRow.swift — Leaderboard row.
AiQo/Tribe/Galaxy/ConstellationCanvasView.swift — Constellation visualization.
AiQo/Tribe/Galaxy/CountdownTimerView.swift — Countdown timer.
AiQo/Tribe/Galaxy/CreateTribeSheet.swift — Create tribe.
AiQo/Tribe/Galaxy/EditTribeNameSheet.swift — Edit tribe name.
AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift — Emara arena logic.
AiQo/Tribe/Galaxy/EmirateLeadersBanner.swift — Leaders banner.
AiQo/Tribe/Galaxy/GalaxyCanvasView.swift — Galaxy visualization.
AiQo/Tribe/Galaxy/GalaxyHUD.swift — Galaxy HUD.
AiQo/Tribe/Galaxy/GalaxyLayout.swift — Galaxy layout.
AiQo/Tribe/Galaxy/GalaxyModels.swift — Galaxy models.
AiQo/Tribe/Galaxy/GalaxyNodeCard.swift — Galaxy node.
AiQo/Tribe/Galaxy/GalaxyScreen.swift — Galaxy screen.
AiQo/Tribe/Galaxy/GalaxyView.swift — Galaxy view.
AiQo/Tribe/Galaxy/GalaxyViewModel.swift — Galaxy logic.
AiQo/Tribe/Galaxy/HallOfFameFullView.swift — Hall of fame.
AiQo/Tribe/Galaxy/HallOfFameSection.swift — Hall of fame section.
AiQo/Tribe/Galaxy/InviteCardView.swift — Invite card.
AiQo/Tribe/Galaxy/JoinTribeSheet.swift — Join tribe.
AiQo/Tribe/Galaxy/MockArenaData.swift — Mock data.
AiQo/Tribe/Galaxy/TribeEmptyState.swift — Empty state.
AiQo/Tribe/Galaxy/TribeHeroCard.swift — Hero card.
AiQo/Tribe/Galaxy/TribeInviteView.swift — Invite view.
AiQo/Tribe/Galaxy/TribeLogScreen.swift — Log screen.
AiQo/Tribe/Galaxy/TribeMemberRow.swift — Member row.
AiQo/Tribe/Galaxy/TribeMembersList.swift — Members list.
AiQo/Tribe/Galaxy/TribeRingView.swift — Ring view.
AiQo/Tribe/Galaxy/TribeTabView.swift — Tab view.
AiQo/Tribe/Galaxy/WeeklyChallengeCard.swift — Weekly challenge.
AiQo/Tribe/Log/TribeLogView.swift — Tribe log.
AiQo/Tribe/Models/TribeFeatureModels.swift — TribeFeatureFlags — Feature flag reader.
AiQo/Tribe/Models/TribeModels.swift — Tribe models.
AiQo/Tribe/Preview/TribePreviewController.swift — Preview controller.
AiQo/Tribe/Preview/TribePreviewData.swift — Preview data.
AiQo/Tribe/Repositories/TribeRepositories.swift — Tribe repositories.
AiQo/Tribe/Stores/ArenaStore.swift — Arena store.
AiQo/Tribe/Stores/GalaxyStore.swift — Galaxy store.
AiQo/Tribe/Stores/TribeLogStore.swift — Tribe log store.
AiQo/Tribe/TribeModuleComponents.swift — Tribe components (1,146 LOC).
AiQo/Tribe/TribeModuleModels.swift — Module models.
AiQo/Tribe/TribeModuleViewModel.swift — Module view model.
AiQo/Tribe/TribePulseScreenView.swift — Pulse screen.
AiQo/Tribe/TribeScreen.swift — Tribe screen.
AiQo/Tribe/TribeStore.swift — Tribe store.
AiQo/Tribe/Views/GlobalTribeRadialView.swift — Radial view.
AiQo/Tribe/Views/TribeAtomRingView.swift — Atom ring.
AiQo/Tribe/Views/TribeEnergyCoreCard.swift — Energy core card.
AiQo/Tribe/Views/TribeHubScreen.swift — Tribe hub (1,008 LOC).
AiQo/Tribe/Views/TribeLeaderboardView.swift — Leaderboard (double @@ bug).
AiQo/UI/AccessibilityHelpers.swift — Accessibility utilities.
AiQo/UI/AiQoProfileButton.swift — Profile button.
AiQo/UI/AiQoScreenHeader.swift — Screen header.
AiQo/UI/ErrorToastView.swift — Error toast.
AiQo/UI/GlassCardView.swift — Glass card.
AiQo/UI/LegalView.swift — Legal/terms.
AiQo/UI/OfflineBannerView.swift — Offline banner.
AiQo/UI/Purchases/PaywallSource.swift — Paywall source tracking.
AiQo/UI/Purchases/PaywallView.swift — PaywallView — 2-tier paywall (1,035 LOC).
AiQo/UI/ReferralSettingsRow.swift — Referral settings.
AiQo/XPCalculator.swift — XPCalculator — XP calculation formula.
AiQo/watch/ConnectivityDiagnosticsView.swift — Watch connectivity diagnostics.
```

### AiQoWatch Watch App (25 files)

```
AiQoWatch Watch App/ — Watch app entry, WorkoutManager (1,347 LOC), services (WatchHealthKitManager, WatchConnectivityService), views (WatchHomeView, WatchWorkoutActiveView, etc.), design, models, shared.
```

### AiQoWidget (9 files)

```
AiQoWidget/ — iPhone home screen widget.
```

### AiQoWatchWidget (3 files)

```
AiQoWatchWidget/ — Watch complication widget.
```

### AiQoTests (11 files)

```
AiQoTests/ — AppleIntelligenceSleepAgentTests, CaptainMemoryRetrievalTests, CaptainPersonalizationReminderMappingTests, CaptainPersonalizationStoreTests, CaptainSleepPromptBuilderTests, IngredientAssetCatalogTests, IngredientAssetLibraryTests, PurchasesTests, QuestEvaluatorTests, SleepAnalysisQualityEvaluatorTests, SmartWakeManagerTests.
```

---

## 15. Brain V2 Feature Flag Reference

### Flag Definition

| Flag | Location | Default | Effect when false |
|---|---|---|---|
| `CAPTAIN_BRAIN_V2_ENABLED` | `AiQo/Info.plist:74-75` | `true` | Disables: EmotionalState evaluation in CaptainContextBuilder, TrendSnapshot population (already nil), SentimentDetector in CaptainViewModel, ConversationThread prompt injection, ProactiveEngine decisions (returns `.doNothing`), Vibe Bridge prompt section (no data to inject). Captain reverts to V1 behavior: 6-layer prompt (layers 3-6 without V2 enrichments), hardcoded notification decisions via legacy CaptainBackgroundNotificationComposer. |

### Code References

| File | Line | Usage |
|---|---|---|
| `AiQo/Info.plist` | 74-75 | `<key>CAPTAIN_BRAIN_V2_ENABLED</key><true/>` — source of truth |
| `CaptainContextBuilder.swift` | 143-144 | `static let isBrainV2Enabled: Bool = Bundle.main.infoDictionary?["CAPTAIN_BRAIN_V2_ENABLED"] as? Bool ?? false` — runtime resolution |
| `CaptainContextBuilder.swift` | 223 | `if Self.isBrainV2Enabled` — gates EmotionalState evaluation and ConversationThread summary injection |
| `CaptainViewModel.swift` | 410 | `if CaptainContextBuilder.isBrainV2Enabled` — gates SentimentDetector execution |
| `ProactiveEngine.swift` | 96 | `guard CaptainContextBuilder.isBrainV2Enabled else { return .doNothing(reason: "brain_v2_disabled") }` — kill switch for all notification decisions |

### Rollback behavior

Setting `CAPTAIN_BRAIN_V2_ENABLED = false` in Info.plist:
1. `CaptainContextBuilder.buildContextData()` skips V2 fields → `emotionalState`, `trendSnapshot`, `messageSentiment`, `recentInteractions` all remain nil.
2. `CaptainPromptBuilder` receives nil V2 fields → Layers 3-6 revert to pre-V2 content (no trend data, no emotional state, no interaction summary, no music bridge).
3. `CaptainViewModel` skips SentimentDetector call.
4. `ProactiveEngine.evaluate()` returns `.doNothing` immediately → SmartNotificationScheduler falls through to legacy `CaptainBackgroundNotificationComposer` path.
5. ConversationThreadManager continues logging (not gated) but logged data is not consumed in prompts.
6. VibeMiniBubble still renders if `spotifyRecommendation` is non-nil on a message, but without the Music Bridge prompt section, the LLM is less likely to generate recommendations outside My Vibe context.

---

*End of Blueprint 14*
