# AiQo Master Blueprint v2.0

> **Generated:** 2026-03-31
> **Source:** Full source-code audit of 300+ Swift files across iOS, watchOS, and Widget targets
> **Scope:** Architecture, data flow, AI brain, persona, gamification, monetization, design system, and roadmap

---

## Table of Contents

1. [App Identity & Philosophy](#section-1--app-identity--philosophy)
2. [Tech Stack & Dependencies](#section-2--tech-stack--dependencies)
3. [Project File Structure](#section-3--project-file-structure)
4. [App Entry, Boot Sequence & Navigation](#section-4--app-entry-boot-sequence--navigation)
5. [Hybrid AI Brain (BrainOrchestrator)](#section-5--hybrid-ai-brain-brainorchestrator)
6. [Captain Hamoudi Persona System](#section-6--captain-hamoudi-persona-system)
7. [Data Models & Persistence](#section-7--data-models--persistence)
8. [HealthKit Integration](#section-8--healthkit-integration)
9. [Onboarding Flow](#section-9--onboarding-flow)
10. [Feature Modules](#section-10--feature-modules-all-7)
11. [Gamification System](#section-11--gamification-system)
12. [Monetization & StoreKit 2](#section-12--monetization--storekit-2)
13. [Supabase Backend Schema](#section-13--supabase-backend-schema)
14. [Notifications & Background Tasks](#section-14--notifications--background-tasks)
15. [Design System](#section-15--design-system)
16. [Apple Watch Companion](#section-16--apple-watch-companion)
17. [Analytics & Crash Reporting](#section-17--analytics--crash-reporting)
18. [Accessibility & Localization](#section-18--accessibility--localization)
19. [Feature Flags & Configuration](#section-19--feature-flags--configuration)
20. [Known Issues, Gaps & Roadmap](#section-20--known-issues-gaps--roadmap)

---

## SECTION 1 — App Identity & Philosophy

### Product Identity

| Field | Value |
|---|---|
| **Product Name** | AiQo |
| **Bundle ID** | `com.mraad500.aiqo` |
| **Marketing Version** | 1.0 |
| **Target Users** | Arabic-speaking wellness enthusiasts (primary: Iraqi Arabic speakers), English secondary |
| **App Store Category** | Health & Fitness |
| **Minimum Deployment** | iOS 26.1 (iPhone), watchOS 26.2 (Apple Watch) |
| **Swift Version** | 5.0 |

### Core Principles

1. **Zero Digital Pollution** — No ads, no trackers, no data selling. Every screen serves a purpose.
2. **Privacy-First** — Raw health data (especially sleep stages) NEVER leaves the device. PII is redacted before cloud calls via `PrivacySanitizer`. Kitchen images are stripped of EXIF/GPS metadata.
3. **Iraqi Arabic Persona** — Captain Hamoudi speaks exclusively in Baghdad-dialect Iraqi Arabic (or English when language is set). No formal Arabic (فصحى). Banned phrases list explicitly blocks generic AI filler.
4. **Circadian-Aware** — The AI adapts its tone, energy, and coaching intensity based on time of day via bio-phase detection in `CaptainContextBuilder`.
5. **Gamification-Driven** — XP, levels, shields, streaks, quests, and legendary challenges create intrinsic motivation loops.

### Supported Languages

| Language | Code | Direction | Localization File |
|---|---|---|---|
| Arabic (Iraqi dialect) | `ar` | RTL | `AiQo/Resources/ar.lproj/Localizable.strings` (2,153 lines) |
| English | `en` | LTR | `AiQo/Resources/en.lproj/Localizable.strings` (2,154 lines) |

### RTL Strategy

- `MainTabScreen` sets `.environment(\.layoutDirection, .rightToLeft)` globally
- `LocalizationManager` in `Core/Localization/` handles runtime language switching
- `Bundle+Language.swift` provides swizzled `Bundle.localizedString` for dynamic locale changes
- Arabic number formatting via `ArabicNumberFormatter`
- All UI components support both LTR and RTL through SwiftUI's built-in layout system

---

## SECTION 2 — Tech Stack & Dependencies

### Apple Frameworks Used

| Framework | Usage |
|---|---|
| **SwiftUI** | All UI — views, navigation, animations |
| **SwiftData** | Persistent models (`@Model` classes) — two separate `ModelContainer` instances |
| **HealthKit** | Steps, heart rate, sleep, calories, water, VO2 max, workouts, stand hours |
| **Foundation Models** | On-device Apple Intelligence for sleep analysis via `AppleIntelligenceSleepAgent` |
| **StoreKit 2** | Non-renewing subscriptions, product loading, transaction observation |
| **WatchConnectivity** | Phone↔Watch bidirectional sync for workouts |
| **ActivityKit** | Live Activities for workout tracking (Dynamic Island + Lock Screen) |
| **WidgetKit** | Home screen widgets (small/medium/large) + Watch complications |
| **AppIntents** | Siri Shortcuts for starting workouts |
| **CoreSpotlight** | Siri Shortcuts donation via `SiriShortcutsManager` |
| **BackgroundTasks** | `BGTaskScheduler` for notification intelligence and inactivity checks |
| **UserNotifications** | Local + remote notifications with rich category management |
| **Vision** | Push-up counter via camera in `VisionCoachViewModel` |
| **AVFoundation** | Audio coaching, voice playback, gratitude sessions |
| **Security (Keychain)** | Free trial persistence across app reinstalls |
| **FamilyControls** | Imported but usage TBD |
| **CoreGraphics / ImageIO** | Kitchen image sanitization (EXIF stripping, resizing) |

### SPM Dependencies (Package.resolved)

| Package | Version | Purpose |
|---|---|---|
| **supabase-swift** | 2.36.0 | Backend: auth, database, real-time, storage |
| **SDWebImage** | 5.21.6 | Async image loading and caching |
| **SDWebImageSwiftUI** | 3.1.4 | SwiftUI wrappers for SDWebImage |
| **swift-crypto** | 4.2.0 | Cryptographic operations (Supabase dependency) |
| **swift-asn1** | 1.5.0 | ASN.1 parsing (Supabase dependency) |
| **swift-http-types** | 1.4.0 | HTTP type definitions (Supabase dependency) |
| **swift-system** | 1.6.4 | System call abstractions (Supabase dependency) |
| **swift-clocks** | 1.0.6 | Clock abstractions for testing (Supabase dependency) |
| **swift-concurrency-extras** | 1.3.2 | Concurrency utilities (Supabase dependency) |
| **xctest-dynamic-overlay** | 1.7.0 | Test support (Supabase dependency) |

### External Frameworks (Vendored)

| Framework | Location |
|---|---|
| **SpotifyiOS.framework** | `AiQo/Frameworks/SpotifyiOS.framework` — Spotify SDK for music integration |

### External APIs

| API | Model/Endpoint | Purpose |
|---|---|---|
| **Google Gemini** | `gemini-2.0-flash` via `generativelanguage.googleapis.com/v1beta` | Main cloud AI brain for Captain Hamoudi |
| **Google Gemini** | `gemini-3-flash-preview` | Coach Brain middleware and spiritual whispers |
| **ElevenLabs** | `eleven_multilingual_v2` via `api.elevenlabs.io/v1/text-to-speech` | Captain Hamoudi voice synthesis |
| **Supabase** | `zidbsrepqpbucqzxnwgk.supabase.co` | Auth, profiles, tribes, arena, device tokens |
| **Spotify** | Via SpotifyiOS SDK | Music playback and vibe recommendations |

---

## SECTION 3 — Project File Structure

```
AiQo/
├── AiQo.xcodeproj/
├── Configuration/
│   ├── AiQo.xcconfig              # Shared build settings
│   ├── Secrets.xcconfig            # API keys (gitignored)
│   └── ExternalSymbols/            # SpotifyiOS dSYM
├── AiQo/
│   ├── App/
│   │   ├── AppDelegate.swift       # @main + UIApplicationDelegate + Siri intents
│   │   ├── AppRootManager.swift    # Cross-tab state (Captain chat presentation)
│   │   ├── MainTabRouter.swift     # Tab navigation singleton
│   │   ├── MainTabScreen.swift     # TabView with 3 tabs (Home, Gym, Captain)
│   │   ├── SceneDelegate.swift     # Scene lifecycle
│   │   ├── AuthFlowUI.swift        # Sign in with Apple flow
│   │   ├── LanguageSelectionView.swift
│   │   ├── DatingScreenViewController.swift  # Profile setup ("dating" = onboarding profile)
│   │   ├── LoginViewController.swift
│   │   └── MealModels.swift
│   ├── Core/
│   │   ├── Constants.swift         # App-wide constants (K namespace)
│   │   ├── Colors.swift            # UIColor + SwiftUI Color definitions
│   │   ├── AppSettingsStore.swift   # User preferences singleton
│   │   ├── UserProfileStore.swift   # User profile data
│   │   ├── CaptainMemory.swift     # @Model for long-term memory
│   │   ├── CaptainVoiceService.swift
│   │   ├── CaptainVoiceAPI.swift   # ElevenLabs API client
│   │   ├── CaptainVoiceCache.swift # Voice audio caching
│   │   ├── MemoryStore.swift       # Memory CRUD operations
│   │   ├── MemoryExtractor.swift   # Extracts memories from conversations
│   │   ├── HealthKitMemoryBridge.swift  # Syncs HK data to Captain memory
│   │   ├── DailyGoals.swift        # Daily step/calorie goals
│   │   ├── StreakManager.swift     # Streak tracking
│   │   ├── SmartNotificationScheduler.swift
│   │   ├── SiriShortcutsManager.swift
│   │   ├── HapticEngine.swift
│   │   ├── ArabicNumberFormatter.swift
│   │   ├── SpotifyVibeManager.swift
│   │   ├── VibeAudioEngine.swift
│   │   ├── AiQoAudioManager.swift
│   │   ├── AiQoAccessibility.swift
│   │   ├── DeveloperPanelView.swift
│   │   ├── Models/
│   │   │   ├── LevelStore.swift    # XP + Level + Shield system
│   │   │   ├── NotificationPreferencesStore.swift
│   │   │   └── ActivityNotification.swift
│   │   ├── Purchases/
│   │   │   ├── PurchaseManager.swift      # StoreKit 2 manager
│   │   │   ├── EntitlementStore.swift     # Active subscription state
│   │   │   ├── ReceiptValidator.swift     # Supabase receipt validation
│   │   │   └── SubscriptionProductIDs.swift
│   │   ├── Localization/
│   │   │   ├── LocalizationManager.swift
│   │   │   └── Bundle+Language.swift
│   │   └── Utilities/
│   │       └── ConnectivityDebugProviding.swift
│   ├── Features/
│   │   ├── Captain/               # 26 files — AI brain + chat UI
│   │   ├── Home/                  # 23 files — dashboard + daily aura + water + sleep
│   │   ├── Gym/                   # 60+ files — workouts, quests, vision coach, club
│   │   ├── Kitchen/               # 25+ files — meal plans, fridge scanner, recipes
│   │   ├── MyVibe/                # 5 files — mood/music/energy management
│   │   ├── Onboarding/            # 3 files — walkthrough, feature intro, health sync
│   │   ├── Profile/               # 3 files — profile screen, level card
│   │   ├── Tribe/                 # 3 files — tribe view, design system, experience flow
│   │   ├── LegendaryChallenges/   # 12 files — record-breaking projects
│   │   ├── WeeklyReport/          # 4 files — weekly health summary
│   │   ├── ProgressPhotos/        # 2 files — body transformation tracking
│   │   └── DataExport/            # 1 file — health data export
│   ├── Tribe/                     # 35+ files — Galaxy, Arena, Stores, Repositories
│   │   ├── Galaxy/                # Arena, Galaxy views, leaderboards
│   │   ├── Stores/                # ArenaStore, GalaxyStore, TribeLogStore
│   │   ├── Models/                # TribeModels, TribeFeatureModels
│   │   ├── Repositories/          # TribeRepositories (Supabase)
│   │   └── Views/                 # Hub, Leaderboard, AtomRing, EnergyCore
│   ├── Premium/
│   │   ├── AccessManager.swift
│   │   ├── EntitlementProvider.swift
│   │   ├── FreeTrialManager.swift
│   │   ├── PremiumPaywallView.swift
│   │   └── PremiumStore.swift
│   ├── Services/
│   │   ├── Analytics/             # AnalyticsService + AnalyticsEvent
│   │   ├── CrashReporting/        # CrashReporter
│   │   ├── Notifications/         # 10 files — comprehensive notification system
│   │   ├── Permissions/HealthKit/ # HealthKitService + TodaySummary
│   │   ├── DeepLinkRouter.swift
│   │   ├── NetworkMonitor.swift
│   │   ├── SupabaseService.swift
│   │   ├── SupabaseArenaService.swift
│   │   ├── ReferralManager.swift
│   │   ├── AiQoError.swift
│   │   └── NotificationType.swift
│   ├── Shared/
│   │   ├── HealthKitManager.swift     # Legacy HK manager (watch workout mirroring)
│   │   ├── HealthManager+Sleep.swift  # Sleep data queries
│   │   ├── LevelSystem.swift
│   │   ├── CoinManager.swift
│   │   ├── WorkoutSyncCodec.swift     # Phone↔Watch sync encoding
│   │   └── WorkoutSyncModels.swift
│   ├── DesignSystem/
│   │   ├── AiQoColors.swift       # Mint + Beige tokens
│   │   ├── AiQoTheme.swift        # Light/dark theme with semantic tokens
│   │   ├── AiQoTokens.swift       # Spacing, radius, metrics
│   │   ├── Components/            # AiQoBottomCTA, AiQoCard, AiQoChoiceGrid, etc.
│   │   └── Modifiers/             # AiQoPressEffect, AiQoShadow, AiQoSheetStyle
│   ├── UI/
│   │   ├── GlassCardView.swift
│   │   ├── AiQoScreenHeader.swift
│   │   ├── AiQoProfileButton.swift
│   │   ├── ErrorToastView.swift
│   │   ├── OfflineBannerView.swift
│   │   ├── LegalView.swift
│   │   ├── AccessibilityHelpers.swift
│   │   ├── ReferralSettingsRow.swift
│   │   └── Purchases/PaywallView.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/       # App icons, images, color sets, audio datasets
│   │   ├── Specs/achievements_spec.json
│   │   ├── ar.lproj/Localizable.strings
│   │   └── en.lproj/Localizable.strings
│   └── watch/
│       └── ConnectivityDiagnosticsView.swift
├── AiQoWatch Watch App/           # watchOS companion
│   ├── AiQoWatchApp.swift         # @main Watch entry
│   ├── Design/WatchDesignSystem.swift
│   ├── Models/WatchWorkoutType.swift
│   ├── Services/
│   │   ├── WatchConnectivityService.swift
│   │   ├── WatchWorkoutManager.swift
│   │   └── WatchHealthKitManager.swift
│   ├── Views/
│   │   ├── WatchHomeView.swift
│   │   ├── WatchActiveWorkoutView.swift
│   │   ├── WatchWorkoutListView.swift
│   │   └── WatchWorkoutSummaryView.swift
│   └── Shared/                    # WorkoutSyncCodec + WorkoutSyncModels (shared with iOS)
├── AiQoWidget/                    # iOS Home Screen widgets
│   ├── AiQoWidgetBundle.swift
│   ├── AiQoWidget.swift           # Daily Progress widget
│   ├── AiQoWatchFaceWidget.swift  # Watch Face complication
│   ├── AiQoRingsFaceWidget.swift  # Activity Rings widget
│   ├── AiQoWidgetLiveActivity.swift  # Workout Live Activity (Dynamic Island)
│   └── AiQoSharedStore.swift
├── AiQoWatchWidget/               # watchOS widget
│   ├── AiQoWatchWidget.swift
│   ├── AiQoWatchWidgetBundle.swift
│   └── AiQoWatchWidgetProvider.swift
├── AiQoTests/
└── AiQoUITests/
```

### Naming Conventions

- **Views:** `*View.swift`, `*Screen.swift`, `*CardView.swift`
- **ViewModels:** `*ViewModel.swift`
- **Services:** `*Service.swift`, `*Manager.swift`
- **Models:** `*Models.swift`, `*Model.swift`
- **Stores:** `*Store.swift` (persistent state managers)
- **Engines:** `*Engine.swift` (computation/logic units)

---

## SECTION 4 — App Entry, Boot Sequence & Navigation

### @main Entry Point

**File:** `AiQo/App/AppDelegate.swift`

The app uses `@main struct AiQoApp: App` with `@UIApplicationDelegateAdaptor(AppDelegate.self)`.

```swift
@main
struct AiQoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var globalBrain = CaptainViewModel()
```

### Boot Sequence (AppDelegate.didFinishLaunching)

Executed in this exact order:

1. **PhoneConnectivityManager.shared** — Activates WatchConnectivity session
2. **UNUserNotificationCenter.delegate = self** — Sets notification delegate
3. **CrashReporter.shared** — Initializes crash reporting
4. **NetworkMonitor.shared** — Starts network reachability monitoring
5. **AnalyticsService.shared.track(.appLaunched)** — Tracks app launch
6. **FreeTrialManager.shared.refreshState()** — Checks trial status
7. **LocalizationManager.shared.applySavedLanguage()** — Applies saved language preference
8. **NotificationCategoryManager.shared.registerAllCategories()** — Registers notification categories
9. **NotificationIntelligenceManager.shared.registerBackgroundTasks()** — Registers BG task identifiers
10. **PurchaseManager.shared.start()** — Starts StoreKit 2 transaction observation

**Conditional (only if ALL onboarding flags are true):**

11. **HealthKitService.permissionFlowEnabled = true** — Enables HK permission requests
12. **NotificationService.shared.requestPermissions()** — Requests notification permission
13. **application.registerForRemoteNotifications()** — Registers for push
14. **MorningHabitOrchestrator.shared.start()** — Starts morning habit monitoring
15. **SleepSessionObserver.shared.start()** — Starts sleep session observation
16. **AIWorkoutSummaryService.shared.startMonitoringWorkoutEnds()** — Monitors workout completions
17. **Smart notification scheduling** (if notifications enabled)

**Always (post-conditional):**

18. **AiQoWorkoutShortcuts.updateAppShortcutParameters()** — Updates Siri shortcuts
19. **SiriShortcutsManager.shared.donateAllShortcuts()** — Donates shortcuts
20. **StreakManager.shared.checkStreakContinuity()** — Validates active streak

### Onboarding Gate Flags

All 5 must be `true` for post-onboarding services to activate:

| UserDefaults Key | Screen |
|---|---|
| `didSelectLanguage` | Language Selection |
| `didShowFirstAuthScreen` | Sign in with Apple |
| `didCompleteDatingProfile` | Profile Setup (age, height, weight, goals) |
| `didCompleteLegacyCalculation` | HealthKit Sync + Level Calculation |
| `didCompleteFeatureIntro` | Feature Introduction |

### ModelContainer Initialization

**Two separate SwiftData containers** are created in `AiQoApp.init()`:

**Container 1 — Captain Memory Store** (custom path: `captain_memory.store`):
- `CaptainMemory`
- `PersistentChatMessage`
- `RecordProject`
- `WeeklyLog`

**Container 2 — Main App Store** (default SwiftData path):
- `AiQoDailyRecord`
- `WorkoutTask`
- `ArenaTribe`
- `ArenaTribeMember`
- `ArenaWeeklyChallenge`
- `ArenaTribeParticipation`
- `ArenaEmirateLeaders`
- `ArenaHallOfFameEntry`

### MainTabRouter

**File:** `AiQo/App/MainTabRouter.swift`

Singleton `@MainActor` class managing tab navigation.

```swift
enum Tab: Int {
    case home = 0
    case gym = 1
    case tribe = 2
    case kitchen = 3      // Special: routes through Home with notification
    case captain = 4
}
```

**Note:** The `TabView` in `MainTabScreen` only renders 3 visible tabs:
- **Home** (`house.fill`)
- **Gym** (`figure.strengthtraining.traditional`)
- **Captain** (`wand.and.stars`)

Kitchen is accessed via a notification from Home. Tribe is defined but not currently in the tab bar.

### AppRootManager

**File:** `AiQo/App/AppRootManager.swift`

Manages cross-tab state for Captain chat presentation:
- `isCaptainChatPresented: Bool` — drives `navigationDestination` to `CaptainChatView`
- `openCaptainChat()` — navigates to Captain tab and presents chat
- `dismissCaptainChat()` — dismisses the chat view

### DeepLink Routes

**File:** `AiQo/Services/DeepLinkRouter.swift`

**URL Scheme:** `aiqo://`
**Universal Links:** `https://aiqo.app/`

| Route | Scheme | Universal Link |
|---|---|---|
| Home | `aiqo://home` | `aiqo.app/` |
| Captain | `aiqo://captain` or `aiqo://chat` | `aiqo.app/captain` |
| Gym | `aiqo://gym` or `aiqo://workout` | `aiqo.app/gym` |
| Tribe | `aiqo://tribe?invite=CODE` | `aiqo.app/tribe/join/CODE` |
| Kitchen | `aiqo://kitchen` | `aiqo.app/kitchen` |
| Settings | `aiqo://settings` | `aiqo.app/settings` |
| Referral | `aiqo://referral?code=CODE` | `aiqo.app/refer/CODE` |
| Premium | `aiqo://premium` | `aiqo.app/premium` |

---

## SECTION 5 — Hybrid AI Brain (BrainOrchestrator)

### Architecture Overview

The AI brain uses a **3-tier architecture**:

```
User Message
    ↓
BrainOrchestrator (Router)
    ↓
┌──────────────────────┬─────────────────────────┐
│ LOCAL Route          │ CLOUD Route              │
│ (Apple Intelligence) │ (Gemini via Google API)  │
│ - Sleep analysis     │ - All other contexts     │
│ - Never leaves device│ - Privacy-sanitized      │
└──────────────────────┴─────────────────────────┘
    ↓
PrivacySanitizer (pre-cloud)
    ↓
CaptainPersonaBuilder (post-response)
    ↓
User Response
```

### Routing Table

**File:** `AiQo/Features/Captain/BrainOrchestrator.swift`

| ScreenContext | Route | Rationale |
|---|---|---|
| `.sleepAnalysis` | **LOCAL** | Raw sleep stages NEVER leave the device |
| `.gym` | **CLOUD** (Gemini) | Needs structured workout plans |
| `.kitchen` | **CLOUD** (Gemini) | Needs meal plans + image analysis |
| `.peaks` | **CLOUD** (Gemini) | Challenge coaching |
| `.mainChat` | **CLOUD** (Gemini) | General conversation |
| `.myVibe` | **CLOUD** (Gemini) | Mood + Spotify recommendations |

**Sleep Intent Interception:** If a user asks about sleep in ANY context, `interceptSleepIntent()` detects sleep-related keywords (Arabic + English) and forces the route to LOCAL.

### PrivacySanitizer

**File:** `AiQo/Features/Captain/PrivacySanitizer.swift`

Before any data reaches the Gemini API, the sanitizer applies these transformations:

1. **Conversation truncation** — Only the LAST 4 messages are sent (prevents hallucination, saves tokens)
2. **PII redaction** — Emails, phone numbers, UUIDs, IPs, URLs, long numeric sequences, base64 tokens → `[REDACTED]`
3. **Name normalization** — Known user names → `"User"` in cloud payloads
4. **Self-identifying phrase removal** — "my name is X" → "my name is User"
5. **Profile field redaction** — Explicit fields like "email:", "phone:", etc. → `[REDACTED_PROFILE]`
6. **Health data bucketing** — Steps bucketed by 50 (max 100K), Calories by 10 (max 10K), Level clamped 1-100
7. **Kitchen image sanitization** — EXIF/GPS stripped via CGImage re-encoding, resized to max 1280px, JPEG compressed at 0.78 quality
8. **Vibe field** — Always replaced with `"General"` in cloud payloads

### LocalBrainService (Apple Intelligence)

**File:** `AiQo/Features/Captain/LocalBrainService.swift`

- Uses Apple's Foundation Models framework (`FoundationModels`)
- Creates an `AdaptiveLanguageModelSession` for on-device inference
- Primary use: Sleep analysis (raw sleep stages processed entirely on-device)
- Fallback: Used when cloud API fails (but skipped if error implies local will also fail)

### CloudBrainService (Gemini API)

**File:** `AiQo/Features/Captain/CloudBrainService.swift`

Privacy wrapper that:
1. Fetches cloud-safe memories from `MemoryStore.shared.buildCloudSafeContext(maxTokens: 400)`
2. Sanitizes the request via `PrivacySanitizer.sanitizeForCloud()`
3. Delegates to `HybridBrainService` for the actual API call

### HybridBrainService (Gemini Transport)

**File:** `AiQo/Features/Captain/HybridBrainService.swift`

| Config | Value |
|---|---|
| **Model** | `gemini-2.0-flash` |
| **Endpoint** | `generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent` |
| **API Key Source** | `Info.plist` → `CAPTAIN_API_KEY` (from `Secrets.xcconfig`) |
| **Timeout** | 35 seconds |
| **Temperature** | 0.7 |
| **Max Output Tokens** | 600 (mainChat, myVibe, sleepAnalysis) / 900 (gym, kitchen, peaks) |

### HybridBrainRequest Schema

```swift
struct HybridBrainRequest: Sendable {
    let conversation: [CaptainConversationMessage]  // role + content
    let screenContext: ScreenContext                 // .mainChat, .gym, etc.
    let language: AppLanguage                       // .arabic or .english
    let contextData: CaptainContextData             // steps, calories, level, etc.
    let userProfileSummary: String                  // memories + profile
    let attachedImageData: Data?                    // kitchen image (optional)
}
```

### HybridBrainServiceReply Schema

```swift
struct HybridBrainServiceReply: Sendable {
    let message: String                           // Captain's text response
    let quickReplies: [String]?                   // 2-3 tappable suggestions
    let workoutPlan: WorkoutPlan?                 // Structured workout (gym context)
    let mealPlan: MealPlan?                       // Structured meal plan (kitchen)
    let spotifyRecommendation: SpotifyRecommendation?  // Spotify URI (myVibe)
    let rawText: String                           // Raw JSON for streaming
}
```

### Fallback Chain

1. **Cloud (Gemini)** — Primary for all non-sleep contexts
2. **Apple Intelligence (Local)** — Fallback when cloud fails (skipped for network errors)
3. **Computed Sleep Reply** — For sleep: uses `AppleIntelligenceSleepAgent.availabilityFallback()` if both cloud and local fail
4. **Localized Error Message** — Final safety net: warm human-readable offline message via `CaptainFallbackPolicy`

### Error Types

```swift
enum HybridBrainServiceError {
    case emptyConversation
    case missingUserMessage
    case invalidStructuredResponse
    case invalidResponse
    case emptyResponse
    case badStatusCode(Int)
    case networkUnavailable
    case requestFailed
    case missingAPIKey
    case invalidEndpoint
}
```

---

## SECTION 6 — Captain Hamoudi Persona System

### Identity

- **Name:** Captain Hamoudi (الكابتن حمودي)
- **Role:** Elite AI mentor, older brother figure, Iraqi coach
- **Dialect:** Baghdad-dialect Iraqi Arabic (primary), English (secondary)
- **Tone:** Sharp, warm, emotionally intelligent. Uses Iraqi sarcasm naturally. No corporate wellness language.
- **Personality:** Direct, concise, actionable. Empathizes before coaching. Says "I don't know" when unsure.

### CaptainPromptBuilder — 6-Layer Architecture

**File:** `AiQo/Features/Captain/CaptainPromptBuilder.swift`

| Layer | Name | Description |
|---|---|---|
| **Layer 1** | Identity | Elite AI mentor identity. Language lock (Arabic-only or English-only). Behavioral code (respond to intent first, be concise, use humor naturally). Banned phrases. Response length rules. Name usage rules. |
| **Layer 2** | Memory | Long-term memory context from prior sessions via `MemoryStore`. Injected as background knowledge. Instruction: "Do NOT recite these facts back unless directly relevant." |
| **Layer 3** | Bio-State | Current HealthKit metrics — steps, calories, level, sleep hours, heart rate, time of day. Marked as "INTERNAL CALIBRATION ONLY — NEVER output to user." Health data is masked. |
| **Layer 4** | Circadian Tone | Tone adapts to time of day via `bioPhase.toneDirective`. Captain never mentions "phase", "bio-phase", or "circadian." |
| **Layer 5** | Screen Context | Where the user is in the app. Controls which fields to populate (workoutPlan, mealPlan, spotifyRecommendation). Kitchen context notes if an image is attached. |
| **Layer 6** | Output Contract | STRICT JSON output requirement. No markdown, no text outside JSON. Fields: message, quickReplies (2-3, max 25 chars), workoutPlan, mealPlan, spotifyRecommendation. Language lock enforced in final reminder. |

### Circadian Tone Phases (BioTimePhase)

**File:** `AiQo/Features/Captain/CaptainContextBuilder.swift`

The `BioTimePhase` enum integrates clock time + sleep quality + activity level to determine true energy state:

```swift
enum BioTimePhase: String, Sendable {
    case awakening  // 5:00–9:59
    case energy     // 10:00–13:59
    case focus      // 14:00–17:59
    case recovery   // 18:00–20:59
    case zen        // 21:00–4:59
}
```

| Time Window | Phase | English Tone Directive | Arabic Tone Directive |
|---|---|---|---|
| 05:00–09:59 | `awakening` | "Gentle, clear, optimistic. The user just woke up — ease them in, don't overwhelm." | "النبرة: هادئة وواضحة. المستخدم لسه صاحي — خفف عليه، لا تثقل." |
| 10:00–13:59 | `energy` | "Sharp, direct, high-output. Peak biological energy — match their drive." | "النبرة: حادة ومباشرة. ذروة الطاقة — جاريه بنفس السرعة." |
| 14:00–17:59 | `focus` | "Steady, precise, minimal. Deep work hours — be efficient, don't break flow." | "النبرة: ثابتة ودقيقة. ساعات التركيز — كن مختصر ولا تقطع التدفق." |
| 18:00–20:59 | `recovery` | "Warm, calm, encouraging. The body is winding down — be supportive, not pushy." | "النبرة: دافئة وهادئة. الجسم يرتاح — ادعمه بدون ضغط." |
| 21:00–04:59 | `zen` | "Soft, philosophical, minimal. Late night — speak gently, encourage rest and reflection." | "النبرة: ناعمة وتأملية. وقت متأخر — تكلم بهدوء وشجّع الراحة." |

**Adaptive Overrides:**
- **Sleep deprived** (< 5.5h sleep) + morning (5-10am) → Forces `recovery` instead of `awakening`
- **High activity at night** (> 8,000 steps after 9pm) → Forces `recovery` instead of `zen`

```swift
static func current(hour: Int, sleepHours: Double, steps: Int) -> BioTimePhase {
    let sleepDeprived = sleepHours > 0 && sleepHours < 5.5
    if sleepDeprived && (5..<10).contains(hour) { return .recovery }
    if hour >= 21 && steps > 8_000 { return .recovery }
    // ... standard time-based mapping
}
```

### CaptainContextData Schema

**File:** `AiQo/Features/Captain/CaptainContextBuilder.swift`

```swift
struct CaptainContextData: Sendable {
    let steps: Int              // Today's step count
    let calories: Int           // Today's active calories
    let vibe: String            // Current vibe label
    let level: Int              // User's current level
    let sleepHours: Double      // Last night's sleep (hours)
    let heartRate: Int?         // Current heart rate (optional)
    let timeOfDay: String       // Formatted time string
    let toneHint: String        // Tone guidance string
    let stageTitle: String      // Growth stage title
    let bioPhase: BioTimePhase  // Circadian phase
}
```

**Context Builder:** `CaptainContextBuilder.shared` aggregates data from:
- `HealthKitService` (steps, calories, sleep, heart rate)
- `LevelStore` (level, stage)
- `VibeAudioEngine` / `SpotifyVibeManager` (current vibe)
- System clock (time of day, bio-phase calculation)

### Banned Phrases

```swift
static let bannedPhrases = [
    "بالتأكيد", "بكل سرور", "كمساعد ذكاء اصطناعي",
    "لا أستطيع", "يسعدني مساعدتك", "هل يمكنني مساعدتك",
    "كيف يمكنني مساعدتك اليوم", "بصفتي نموذج لغوي",
    "As an AI", "I'm happy to help", "How can I assist you",
    "Certainly!", "Of course!", "I'd be happy to"
]
```

All responses are post-processed by `CaptainPersonaBuilder.sanitizeResponse()` which strips these phrases.

### Custom Tone Options

Via `CaptainCustomization` in `CaptainViewModel`:
- User can select calling (e.g., custom nickname)
- User can select tone preference
- Persisted in `UserDefaults` under `captain_*` keys

### Long-Term Memory System

#### CaptainMemory Model

**File:** `AiQo/Core/CaptainMemory.swift` (SwiftData `@Model`)

```swift
@Model
final class CaptainMemory {
    #Index<CaptainMemory>([\.category], [\.key])

    var id: UUID
    var category: String        // Memory classification
    @Attribute(.unique) var key: String  // Unique identifier
    var value: String           // The stored information
    var confidence: Double      // 0.0–1.0 trust score
    var source: String          // How this memory was created
    var createdAt: Date
    var updatedAt: Date
    var accessCount: Int        // Times used in prompts
}
```

**Memory Categories:**
| Category | Description | Example Key |
|---|---|---|
| `identity` | User's name, age, background | `user_name`, `user_age` |
| `goal` | Fitness/health goals | `primary_goal`, `target_weight` |
| `body` | Physical measurements | `height_cm`, `weight_kg` |
| `preference` | Workout/food preferences | `preferred_workout`, `food_allergies` |
| `mood` | Emotional patterns | `morning_mood_trend` |
| `injury` | Physical limitations | `knee_injury`, `back_pain` |
| `nutrition` | Dietary habits | `daily_protein_target` |
| `workout_history` | Training patterns | `favorite_exercises` |
| `sleep` | Sleep patterns | `avg_sleep_hours` |
| `insight` | AI-derived observations | `stress_pattern_detected` |
| `active_record_project` | Legendary challenge data | `pushup_record_project` |

**Memory Sources:**
| Source | Description |
|---|---|
| `user_explicit` | User directly stated information |
| `extracted` | Extracted from conversation by MemoryExtractor |
| `healthkit` | Synced from HealthKit data |
| `inferred` | AI-inferred from patterns |
| `llm_extracted` | Extracted by LLM during analysis |

#### MemoryStore Manager

**File:** `AiQo/Core/MemoryStore.swift`

`@MainActor @Observable final class MemoryStore`

| Method | Description |
|---|---|
| `configure(container:)` | Binds the SwiftData ModelContainer |
| `set(key:value:category:source:confidence:)` | Create or update a memory |
| `get(key:) -> String?` | Retrieve by key |
| `getByCategory(category:) -> [CaptainMemory]` | Retrieve all memories in a category |
| `buildCloudSafeContext(maxTokens:) -> String` | Build a cloud-safe prompt fragment (max 400 tokens) |
| `removeStale()` | Delete old/low-confidence memories |
| `removeLowestConfidence()` | Delete least-confident memory when at capacity |
| `isEnabled: Bool` | Toggle memory on/off (UserDefaults: `captain_memory_enabled`) |

**Capacity:** Maximum 200 memories. When full, lowest-confidence memory is evicted.

**Confidence mechanics:**
- New memories start at confidence 0.7
- Each update adds 0.05 (capped at 1.0)
- `user_explicit` source never gets overwritten by lower-priority sources
- Stale memories with low access count are cleaned up at launch

#### Memory Pipeline

```
User Conversation
    ↓
MemoryExtractor.extract()         ← Analyzes conversation for persistent facts
    ↓
MemoryStore.set()                 ← Stores with category + source + confidence
    ↓
MemoryStore.buildCloudSafeContext() ← Retrieves top memories for cloud prompt
    ↓
CaptainPromptBuilder.layerMemory() ← Injects as "BACKGROUND KNOWLEDGE"
```

#### HealthKit Memory Bridge

**File:** `AiQo/Core/HealthKitMemoryBridge.swift`

`HealthKitMemoryBridge.syncHealthDataToMemory()` runs at app launch (after onboarding) and syncs aggregated health data into Captain memory:
- Average daily steps
- Average sleep duration
- Resting heart rate
- Activity patterns

This allows Captain to reference health trends without re-querying HealthKit during conversations.

#### Memory Settings UI

**File:** `AiQo/Core/CaptainMemorySettingsView.swift`

Provides a settings screen where users can:
- Enable/disable Captain memory
- View stored memories
- Delete individual memories
- Clear all memories

### ElevenLabs Voice Settings

**File:** `AiQo/Core/CaptainVoiceAPI.swift`

| Setting | Value |
|---|---|
| **Model** | `eleven_multilingual_v2` |
| **Voice ID** | `9FHjCdVXgA4tYxIYHTcZ` |
| **API URL** | `api.elevenlabs.io/v1/text-to-speech` |
| **API Key** | Via `Secrets.xcconfig` → `CAPTAIN_VOICE_API_KEY` |
| **Output Format** | `mp3_44100_128` (44.1 kHz, 128 kbps MP3) |
| **Request Timeout** | 30 seconds |

#### Voice Parameters (VoiceSettings)

```swift
VoiceSettings(
    stability: 0.34,          // Low stability = more expressive
    similarityBoost: 0.88,    // High similarity = close to reference voice
    style: 0.18,              // Subtle style transfer
    useSpeakerBoost: true     // Enhanced speaker clarity
)
```

#### Voice Architecture Files

| File | Purpose |
|---|---|
| `CaptainVoiceAPI.swift` | HTTP client for ElevenLabs API. Handles configuration resolution, request building, and audio data response. |
| `CaptainVoiceCache.swift` | Local cache for synthesized audio files. Prevents redundant API calls for repeated phrases. |
| `CaptainVoiceService.swift` | Orchestrates the full voice pipeline: text → synthesis → caching → playback. |

#### Configuration Resolution Order

1. **ProcessInfo.environment** (CI / TestFlight builds)
2. **Bundle.main.infoDictionary** (from `Secrets.xcconfig` → `Info.plist`)
3. Falls back to default URL/model if partially configured

### CaptainFallbackPolicy

**File:** `AiQo/Features/Captain/CaptainFallbackPolicy.swift`

When ALL AI services (cloud + local) fail, the fallback policy provides context-aware, intent-based responses:

#### Intent Detection Categories

| Detected Intent | Arabic Keywords | English Keywords |
|---|---|---|
| Hungry/Food | جوع, جوعان, أكل, وجبة | hungry, food, meal, diet |
| Tired/Exhausted | تعبان, مرهق, نعسان | tired, exhausted, sleepy |
| Stressed | توتر, مضغوط, قلق | stress, stressed, overwhelmed |
| Workout | تمرين, جيم, كارديو | workout, cardio, run, gym |

#### Response Strategy

Each fallback response includes:
1. **Acknowledgment** — Warm human-readable explanation that AI is temporarily unavailable
2. **Triage question** — Context-specific question to guide the user
3. **3 quick options** — Actionable choices the user can tap

#### Network Error Messages (Randomized)

Arabic examples:
- "عذراً! الشبكة عندي بيها مشكلة هسه..."
- "أووف! يبدو الاتصال انقطع هسه..."
- "ما وصلت للسيرفر هسه..."

English examples:
- "Looks like I can't reach my cloud brain right now..."
- "Network seems down — I couldn't connect..."
- "Connection lost. Check your internet..."

#### Generic Fallbacks (Final Safety Net)

Arabic: 5 randomized warm greetings in Iraqi dialect
English: 5 randomized casual coaching openers

### Fallback TTS Chain

1. **ElevenLabs API** — Primary (Iraqi Arabic voice with custom voice settings)
2. **AVSpeechSynthesizer** — Fallback (system TTS, less natural)
3. **Silent** — If both fail, message displayed without voice

### PromptRouter (Local Route System Prompt)

**File:** `AiQo/Features/Captain/PromptRouter.swift`

Used by `LocalBrainService` for on-device Apple Intelligence prompts. Generates context-specific system prompts that include:

1. **Captain Hamoudi identity** — Iraqi fitness and life coach
2. **Timestamp** — Formatted in user's locale
3. **Screen context** — Which screen the user is on
4. **Conversational awareness rules** — Respond to intent first, don't force stats
5. **Live context data** — Steps, calories, vibe, level (only when relevant)
6. **Privacy rules** — Never mention APIs, servers, cloud inference
7. **Screen-specific behavior** — Detailed instructions per screen context
8. **Output contract** — JSON-only output with message, workoutPlan, mealPlan, spotifyRecommendation

#### Screen-Specific Instructions (PromptRouter)

| Screen | Key Instruction |
|---|---|
| `.kitchen` | "Stay inside food, cooking, meal timing. Default to meal-first coaching." |
| `.gym` | "Lead with execution, exercise selection, sets, reps, progression." |
| `.sleepAnalysis` | "Bias toward recovery, parasympathetic downshift, realistic sleep hygiene." |
| `.peaks` | "Speak to momentum, discipline, measurable next actions." |
| `.mainChat` | "General chat. Respond naturally. Only generate plans when explicitly asked." |
| `.myVibe` | "Focus on mood, music energy, focus state. Generate spotify:search: URIs dynamically." |

### AppleIntelligenceSleepAgent

**File:** `AiQo/Features/Captain/AppleIntelligenceSleepAgent.swift`

Uses Apple's `FoundationModels` framework for on-device sleep analysis.

#### SleepSession Model

```swift
struct SleepSession: Sendable {
    let totalSleep: TimeInterval    // Total sleep duration
    let deepSleep: TimeInterval     // Deep sleep stage
    let remSleep: TimeInterval      // REM sleep stage
    let coreSleep: TimeInterval     // Core/light sleep stage
    let awake: TimeInterval         // Time awake during night
}
```

Computed properties: `totalMinutes`, `deepMinutes`, `remMinutes`, `coreMinutes`, `awakeMinutes`, `deepPercentage`, `remPercentage`

#### On-Device Analysis Flow

1. `analyze(session:)` checks `SystemLanguageModel.default.availability`
2. If `.available` → Creates `LanguageModelSession` with Iraqi Arabic system prompt
3. Temperature: 0.5, Max tokens: 160
4. Trigger prompt: `"شلون نوم المستخدم؟ حلله هسه بالعراقي."`
5. If `.unavailable` → Throws `modelUnavailable` with aggregated Arabic summary

#### System Prompt Structure

The sleep agent's system prompt includes:
- Captain Hamoudi identity (Iraqi dialect enforced)
- Sleep data with ratings:
  - Duration rating: "قليل هواية" (< 5h), "قليل" (5-6h), "يمشي بس مو مثالي" (6-7h), "خوش نوم" (7-9h), "هواية نوم" (> 9h)
  - Stage ratings: percentage vs ideal ranges (deep: 15-25%, REM: 20-25%)
- Output format: Exactly 3 sentences in Iraqi Arabic
- Restrictions: No emojis, no headers, no formal Arabic

#### Error Handling

```swift
enum AppleIntelligenceSleepAgentError {
    case emptyResponse(session: SleepSession)
    case modelUnavailable(sleepSummary: String, session: SleepSession)
}
```

On `modelUnavailable`: BrainOrchestrator falls back to cloud with aggregated text summary (no raw stages), then to computed fallback.

---

## SECTION 7 — Data Models & Persistence

### SwiftData ModelContainer 1 — Captain Memory Store

**Path:** `ApplicationSupport/captain_memory.store`

| @Model Class | Purpose |
|---|---|
| `CaptainMemory` | Long-term memories (goals, preferences, habits) |
| `PersistentChatMessage` | Chat history persistence across sessions |
| `RecordProject` | Legendary challenge projects |
| `WeeklyLog` | Weekly review logs for legendary challenges |

### SwiftData ModelContainer 2 — Main App Store

**Path:** Default SwiftData location

| @Model Class | Purpose |
|---|---|
| `AiQoDailyRecord` | Daily health metrics snapshot |
| `WorkoutTask` | Workout session records |
| `ArenaTribe` | Tribe (group) data |
| `ArenaTribeMember` | Tribe member profiles |
| `ArenaWeeklyChallenge` | Weekly tribe challenges |
| `ArenaTribeParticipation` | Challenge participation records |
| `ArenaEmirateLeaders` | Leaderboard data |
| `ArenaHallOfFameEntry` | Hall of fame records |

### Key @Model: PersistentChatMessage

```swift
@Model
final class PersistentChatMessage {
    var messageID: UUID
    var text: String
    var isUser: Bool
    var timestamp: Date
    var spotifyRecommendationData: Data?  // JSON-encoded SpotifyRecommendation
    var sessionID: UUID                   // Groups messages by session
}
```

**Indexes:** `[\.sessionID]`, `[\.timestamp]`

### Key Singleton Managers & Persisted State

| Manager | Storage | Key Prefix |
|---|---|---|
| `LevelStore.shared` | UserDefaults | `aiqo.user.level`, `aiqo.user.currentXP`, `aiqo.user.totalXP` |
| `StreakManager.shared` | UserDefaults | `aiqo.streak.current`, `aiqo.streak.longest`, `aiqo.streak.lastActive`, `aiqo.streak.history` |
| `FreeTrialManager.shared` | UserDefaults + Keychain | `aiqo.freeTrial.startDate` |
| `AppSettingsStore.shared` | UserDefaults | `appLanguage`, `notificationsEnabled`, etc. |
| `UserProfileStore.shared` | UserDefaults | User profile fields |
| `EntitlementStore.shared` | UserDefaults | Subscription state |
| `MemoryStore.shared` | SwiftData (captain container) | Captain memories |
| `CoinManager.shared` | UserDefaults | Coin balance |
| `DailyGoals` | UserDefaults | `aiqo.dailyGoals` |

### UserDefaults Key Inventory (Partial)

| Key | Type | Purpose |
|---|---|---|
| `didSelectLanguage` | Bool | Onboarding: language chosen |
| `didShowFirstAuthScreen` | Bool | Onboarding: auth screen shown |
| `didCompleteDatingProfile` | Bool | Onboarding: profile setup done |
| `didCompleteLegacyCalculation` | Bool | Onboarding: HK sync + level calc |
| `didCompleteFeatureIntro` | Bool | Onboarding: feature intro seen |
| `captain_user_name` | String | Captain customization: user name |
| `captain_calling` | String | Captain customization: calling |
| `captain_tone` | String | Captain customization: tone |
| `user_gender` | String | User gender (for notification language) |
| `lastCelebratedLevel` | Int | Last level-up celebration shown |
| `aiqo.dailyGoals` | Data | JSON-encoded daily step/calorie goals |

---

## SECTION 8 — HealthKit Integration

### Read Types (Quantity)

| HKQuantityTypeIdentifier | Purpose |
|---|---|
| `.stepCount` | Daily steps tracking |
| `.heartRate` | Real-time heart rate |
| `.restingHeartRate` | Resting HR baseline |
| `.heartRateVariabilitySDNN` | HRV for recovery |
| `.walkingHeartRateAverage` | Walking HR average |
| `.activeEnergyBurned` | Active calories |
| `.distanceWalkingRunning` | Distance tracking |
| `.dietaryWater` | Water intake |
| `.vo2Max` | Cardio fitness |

### Read Types (Category)

| HKCategoryTypeIdentifier | Purpose |
|---|---|
| `.sleepAnalysis` | Sleep stages (awake, core, deep, REM) |
| `.appleStandHour` | Stand hours |

### Read Types (Other)

- `HKObjectType.workoutType()` — Workout sessions

### Write Types

| Type | Purpose |
|---|---|
| `.dietaryWater` | Water logging from app |
| `.heartRate` | Watch workout HR data sync |
| `.restingHeartRate` | Watch data sync |
| `.heartRateVariabilitySDNN` | Watch data sync |
| `.vo2Max` | Watch data sync |
| `.distanceWalkingRunning` | Watch workout distance sync |
| `workoutType()` | Workout session recording |

### Permission Request Strategy

1. `HealthKitService.permissionFlowEnabled` is set to `false` by default
2. Enabled ONLY after ALL 5 onboarding flags are `true`
3. Authorization requested via `store.requestAuthorization(toShare:read:)`
4. Checks if at least one read type has `.sharingAuthorized` status
5. Falls back gracefully if HealthKit is unavailable

### Privacy Rule

**Raw health data (especially sleep stages) NEVER leaves the device.**

- Sleep analysis is routed to LOCAL (Apple Intelligence) exclusively
- If cloud fallback is needed for sleep, only an **aggregated text summary** is sent (not raw stage data)
- Health metrics sent to cloud are **bucketed** (steps by 50, calories by 10)
- The `PrivacySanitizer` enforces this at the API transport layer

### HealthKit → AI Prompt Flow

1. `CaptainContextBuilder` aggregates today's HealthKit data
2. Data is formatted into `CaptainContextData` (steps, calories, sleepHours, heartRate, timeOfDay, bioPhase, level)
3. `CaptainPromptBuilder.layerBioState()` injects this as "INTERNAL BIO-STATE" in the system prompt
4. The AI uses this data for **tone calibration only** — never outputs it directly

---

## SECTION 9 — Onboarding Flow

### Full Screen Order

| # | Screen | File | What It Does |
|---|---|---|---|
| 1 | Language Selection | `App/LanguageSelectionView.swift` | Choose Arabic or English. Sets `didSelectLanguage` |
| 2 | Onboarding Walkthrough | `Features/Onboarding/OnboardingWalkthroughView.swift` | Explains XP/level system. Shows how levels are calculated from health history |
| 3 | Sign in with Apple | `App/AuthFlowUI.swift` | Apple authentication via Supabase. Sets `didShowFirstAuthScreen` |
| 4 | Profile Setup | `App/DatingScreenViewController.swift` | Collects: name, age, height, weight, goals. Sets `didCompleteDatingProfile` |
| 5 | Health History Sync | `Features/Onboarding/HistoricalHealthSyncEngine.swift` | Reads historical HealthKit data to calculate initial level. Sets `didCompleteLegacyCalculation` |
| 6 | Feature Introduction | `Features/Onboarding/FeatureIntroView.swift` | Showcases app features (4 pages). Sets `didCompleteFeatureIntro` |
| 7 | Main App | `App/MainTabScreen.swift` | Lands on Home tab |

### Subscription Paywall Position

The paywall (`PremiumPaywallView`) is NOT part of the forced onboarding flow. The free trial starts automatically when the user opens the app. The paywall appears:
- When trial expires
- When accessing premium features
- Via deep link `aiqo://premium`

### HealthKit Permission Request Position

HealthKit permissions are requested during Step 5 (Health History Sync) via `HistoricalHealthSyncEngine`. The `HealthKitService.permissionFlowEnabled` flag ensures no accidental permission dialogs appear before this step.

---

## SECTION 10 — Feature Modules (All 7)

### 10.1 Home (القاعدة)

| Aspect | Detail |
|---|---|
| **Purpose** | Daily health dashboard — steps, calories, sleep, water, streak, level |
| **Key Files** | `HomeView.swift`, `HomeViewModel.swift`, `DailyAuraView.swift`, `WaterBottleView.swift`, `SleepDetailCardView.swift`, `SmartWakeEngine.swift`, `StreakBadgeView.swift`, `SpotifyVibeCard.swift`, `AlarmSetupCardView.swift` |
| **AI Routing** | None (data display only) |
| **Data Models** | `AiQoDailyRecord`, `DailyAuraModels`, `MetricKind` |
| **HealthKit Types** | Steps, calories, sleep, heart rate, water |
| **Sub-features** | Daily Aura (animated health visualization), Water tracking (bottle fill animation), Sleep detail card, Smart Wake Calculator (optimal wake time), Streak badge, Level-up celebration, Spotify Vibe Card, DJ Captain Chat quick access |
| **Status** | Complete |

### 10.2 Gym / Peaks (الجيم)

| Aspect | Detail |
|---|---|
| **Purpose** | Workout management, exercise tracking, fitness challenges, quests |
| **Key Files** | `GymViewController.swift`, `WorkoutSessionViewModel.swift`, `LiveWorkoutSession.swift`, `ClubRootView.swift`, `QuestEngine.swift`, `VisionCoachViewModel.swift`, `HandsFreeZone2Manager.swift` |
| **AI Routing** | CLOUD (Gemini) — generates workoutPlan |
| **Data Models** | `GymExercise`, `WorkoutTask`, `QuestKitModels`, `QuestSwiftDataModels`, `Challenge`, `WinRecord` |
| **HealthKit Types** | Heart rate, active calories, distance, workout type |
| **Status** | Complete (most advanced module) |

#### Gym Sub-Modules

**1. Live Workout Session**
- `WorkoutSessionViewModel.swift` — Main workout session state management
- `LiveWorkoutSession.swift` — Real-time workout tracking
- `WorkoutSessionScreen.swift` — Workout session UI
- `WorkoutSessionSheetView.swift` — Workout controls sheet
- `WorkoutLiveActivityManager.swift` — Dynamic Island + Lock Screen Live Activity
- `LiveMetricsHeader.swift` — Real-time heart rate, calories, distance display

**2. Zone 2 Heart Rate Tracking**
- `HandsFreeZone2Manager.swift` — Monitors heart rate zones during workout
- Heart rate states: neutral, warmingUp, zone2, belowZone2, aboveZone2
- Visual feedback via Dynamic Island color changes
- Audio coaching cues for zone transitions

**3. Club (Training Hub)**
- `ClubRootView.swift` — Main club navigation with segmented tabs
- `BodyView.swift` — Body tracking and gratitude sessions
- `PlanView.swift` — Workout plan management and creation flow
- `ImpactContainerView.swift` — Training impact visualization
- `ChallengesView.swift` — Challenge cards and progress
- `GratitudeSessionView.swift` — Audio-guided gratitude meditation
- Components: `RightSideRailView`, `SegmentedTabs`, `ClubNavigationComponents`

**4. Quest System (QuestKit)**
- `QuestEngine.swift` — Quest evaluation and progression engine
- `QuestDefinitions.swift` — All quest definitions and requirements
- `QuestKitModels.swift` — Quest data structures
- `QuestSwiftDataModels.swift` — SwiftData persistence for quest progress
- `QuestDataSources.swift` — Data providers for quest evaluation
- `QuestEvaluator.swift` — Logic for checking quest completion
- `QuestProgressStore.swift` — Progress tracking storage
- `QuestSwiftDataStore.swift` — SwiftData store for quest state
- Views: `QuestsView`, `QuestCard`, `QuestDetailView`, `QuestCompletionCelebration`
- Stores: `QuestAchievementStore`, `QuestDailyStore`, `WinsStore`

**5. Vision Coach (AI Push-up Counter)**
- `VisionCoachViewModel.swift` — Camera-based exercise detection
- `VisionCoachView.swift` — Camera preview with rep counter overlay
- `VisionCoachAudioFeedback.swift` — Voice counting and encouragement
- Uses Apple Vision framework for pose detection
- Camera permission gate: `QuestCameraPermissionGateView`

**6. Challenge System**
- `Challenge.swift` — Challenge model with stages
- `ChallengeStage.swift` — Progressive difficulty stages
- `ChallengeCard.swift` — Challenge selection UI
- `ChallengeDetailView.swift` — Full challenge details
- `ChallengeRunView.swift` — Active challenge execution
- `ChallengeRewardSheet.swift` — Completion rewards

**7. Audio Coach**
- `AudioCoachManager.swift` — Voice coaching during workouts
- Provides real-time verbal cues for: set completion, rest periods, zone transitions

**8. Watch Connectivity**
- `WatchConnectivityService.swift` — Phone↔Watch workout sync
- `WatchConnectionStatusButton.swift` — Connection status indicator
- Shared codec: `WorkoutSyncCodec.swift` + `WorkoutSyncModels.swift`

**9. Spin Wheel**
- `SpinWheelView.swift` — Randomized workout selection wheel
- `WheelTypes.swift` — Wheel segment types
- `WorkoutTheme.swift` — Visual themes for workout types
- `WorkoutWheelSessionViewModel.swift` — Session management

**10. Additional**
- `SpotifyWorkoutPlayerView.swift` — In-workout Spotify player
- `SpotifyWebView.swift` — Spotify web fallback
- `GuinnessEncyclopediaView.swift` — Exercise encyclopedia
- `ExercisesView.swift` — Exercise library browser
- `ActiveRecoveryView.swift` — Recovery session guidance
- `PhoneWorkoutSummaryView.swift` — Post-workout summary on phone
- `CinematicGrindCardView.swift` — Visual workout cards with cinematic effects

### 10.3 Alchemy Kitchen (مطبخ الكيمياء)

| Aspect | Detail |
|---|---|
| **Purpose** | AI-powered meal planning, nutrition tracking, smart fridge scanning |
| **Key Files** | `KitchenScreen.swift`, `KitchenViewModel.swift`, `KitchenPlanGenerationService.swift`, `SmartFridgeCameraViewModel.swift`, `MealsRepository.swift`, `IngredientCatalog.swift`, `FridgeInventoryView.swift` |
| **AI Routing** | CLOUD (Gemini) — generates mealPlan, analyzes fridge photos |
| **Data Models** | `KitchenModels`, `Meal`, `KitchenPersistenceStore`, `MealModels` |
| **HealthKit Types** | Calories for nutrition balance |
| **Status** | Complete |

#### Kitchen Sub-Modules

**1. Smart Fridge Scanner**
- `SmartFridgeScannerView.swift` — Camera UI for scanning fridge contents
- `SmartFridgeCameraViewModel.swift` — Camera session management and image capture
- `SmartFridgeCameraPreviewController.swift` — UIKit camera preview controller
- `SmartFridgeScannedItemRecord.swift` — Scanned item data model
- Photos are processed through `PrivacySanitizer.sanitizeKitchenImageData()` (strips EXIF/GPS, resizes to 1280px max, JPEG 0.78 quality) before being sent to Gemini

**2. Interactive Fridge**
- `InteractiveFridgeView.swift` — Visual fridge with ingredient placement
- `FridgeInventoryView.swift` — Inventory list management
- `IngredientCatalog.swift` — Master ingredient database
- `IngredientAssetCatalog.swift` — Image assets for ingredients
- `IngredientAssetLibrary.swift` — Asset library management
- `IngredientDisplayItem.swift` — Display model for ingredients
- `IngredientKey.swift` — Unique ingredient identifiers

**3. Meal Planning**
- `MealPlanView.swift` — Meal plan display and editing
- `MealPlanGenerator.swift` — Local meal plan generation logic
- `KitchenPlanGenerationService.swift` — AI-powered plan generation via Gemini
- `MealSectionView.swift` — Meal type sections (breakfast, lunch, dinner)
- `RecipeCardView.swift` — Individual recipe display cards
- `MealIllustrationView.swift` — Visual meal illustrations
- `MealImageSpec.swift` — Image specifications for meals

**4. Nutrition Tracking**
- `NutritionTrackerView.swift` — Daily nutrition overview
- `CompositePlateView.swift` — Visual plate composition
- `PlateTemplate.swift` — Plate layout templates

**5. Data & Persistence**
- `KitchenPersistenceStore.swift` — Local storage for kitchen data
- `MealsRepository.swift` — Meal data repository pattern
- `LocalMealsRepository.swift` — Local meal database
- `meals_data.json` — Static meal database (6 entries with Arabic/English names, calories, meal types)
- `KitchenLanguageRouter.swift` — Language-specific kitchen content routing

**6. Scene & Navigation**
- `KitchenScreen.swift` — Main kitchen screen container
- `KitchenView.swift` — Kitchen feature layout
- `KitchenSceneView.swift` — Kitchen scene rendering
- `CameraView.swift` — Camera utility view

### 10.4 Sleep & Spirit (النوم والروح)

| Aspect | Detail |
|---|---|
| **Purpose** | Sleep analysis using on-device AI, spiritual whispers |
| **Key Files** | `AppleIntelligenceSleepAgent.swift`, `SleepDetailCardView.swift`, `SleepScoreRingView.swift`, `HealthManager+Sleep.swift` |
| **AI Routing** | LOCAL (Apple Intelligence) — raw sleep data never leaves device |
| **Data Models** | `SleepSession`, `TodaySummary` |
| **HealthKit Types** | `.sleepAnalysis` (all stages) |
| **Sub-features** | Sleep score ring visualization, Sleep detail breakdown, Smart Wake Calculator, Spiritual whispers (Gemini 3 Flash Preview) |
| **Status** | Complete |

### 10.5 My Vibe (ذبذباتي)

| Aspect | Detail |
|---|---|
| **Purpose** | Mood tracking, energy management, music/vibe recommendations |
| **Key Files** | `MyVibeScreen.swift`, `MyVibeViewModel.swift`, `VibeOrchestrator.swift`, `DailyVibeState.swift`, `SpotifyVibeManager.swift`, `VibeAudioEngine.swift` |
| **AI Routing** | CLOUD (Gemini) — generates spotifyRecommendation |
| **Data Models** | `DailyVibeState`, `SpotifyRecommendation` |
| **HealthKit Types** | Heart rate (energy calibration) |
| **Sub-features** | Vibe state tracking, Spotify playlist recommendations, Audio engine for ambient sounds (binaural beats: GammaFlow, SerotoninFlow, ThetaTrance, Hypnagogic state, SoundOfEnergy), Vibe control sheet |
| **Status** | Complete |

### 10.6 Tribe / Emara (القبيلة / الإمارة)

| Aspect | Detail |
|---|---|
| **Purpose** | Social fitness — create tribes, compete, leaderboards |
| **Key Files** | `TribeScreen.swift`, `TribeStore.swift`, `TribeModuleViewModel.swift`, `GalaxyScreen.swift`, `ArenaScreen.swift`, `ArenaViewModel.swift` |
| **AI Routing** | None (social features) |
| **Data Models** | `TribeModels`, `TribeFeatureModels`, `ArenaModels`, `GalaxyModels`, `ArenaTribe`, `ArenaTribeMember` |
| **HealthKit Types** | Steps, calories (for tribe challenges) |
| **Feature Flags** | `TRIBE_FEATURE_VISIBLE: true`, `TRIBE_BACKEND_ENABLED: true`, `TRIBE_SUBSCRIPTION_GATE_ENABLED: true` |
| **Status** | In progress (backend enabled, UI mostly complete) |

#### Tribe Sub-Modules

**1. Core Tribe Management**
- `TribeScreen.swift` — Main tribe navigation container
- `TribeStore.swift` — Tribe state management (Supabase-backed)
- `TribeModuleViewModel.swift` — Module-level view model
- `TribeModuleModels.swift` + `TribeModuleComponents.swift` — Shared models and components
- `TribeRepositories.swift` — Supabase data access layer

**2. Galaxy View (Visual Tribe Network)**
- `GalaxyScreen.swift` — Galaxy view entry point
- `GalaxyViewModel.swift` — Galaxy state and data management
- `GalaxyStore.swift` — Galaxy state persistence
- `GalaxyModels.swift` — Galaxy data models
- `GalaxyCanvasView.swift` — Interactive constellation rendering
- `ConstellationCanvasView.swift` — Star constellation visualization
- `GalaxyHUD.swift` — Heads-up display overlay
- `GalaxyLayout.swift` — Node positioning algorithms
- `GalaxyNodeCard.swift` — Individual node cards
- `GalaxyView.swift` — Galaxy container view

**3. Tribe Views**
- `TribeHeroCard.swift` — Hero member highlight card
- `TribeMemberRow.swift` — Member list row
- `TribeMembersList.swift` — Full member list
- `TribeRingView.swift` — Circular tribe visualization
- `TribeInviteView.swift` — Invite sharing UI
- `InviteCardView.swift` — Shareable invite card
- `TribeEmptyState.swift` — Empty tribe state
- `TribeTabView.swift` — Tab navigation within tribe
- `TribeHubScreen.swift` — Central hub screen
- `TribeLeaderboardView.swift` — Tribe leaderboard
- `TribeAtomRingView.swift` — Atomic ring visualization
- `TribeEnergyCoreCard.swift` — Energy core display
- `GlobalTribeRadialView.swift` — Global tribe radial layout
- `TribePulseScreenView.swift` — Pulse activity screen

**4. Tribe Creation & Joining**
- `CreateTribeSheet.swift` — New tribe creation flow
- `JoinTribeSheet.swift` — Join via invite code
- `EditTribeNameSheet.swift` — Rename tribe
- Max 5 members per tribe

**5. Tribe Log**
- `TribeLogScreen.swift` — Activity log within galaxy
- `TribeLogView.swift` — Log display
- `TribeLogStore.swift` — Log data persistence

**6. Tribe Design**
- `TribeDesignSystem.swift` — Tribe-specific design tokens
- `TribeExperienceFlow.swift` — Tribe onboarding/experience flow

### 10.7 Arena (الحلبة)

| Aspect | Detail |
|---|---|
| **Purpose** | Competitive challenges between tribe members |
| **Key Files** | `ArenaScreen.swift`, `ArenaViewModel.swift`, `EmaraArenaViewModel.swift`, `ArenaStore.swift`, `SupabaseArenaService.swift` |
| **AI Routing** | None |
| **Data Models** | `ArenaModels`, `ArenaWeeklyChallenge`, `ArenaTribeParticipation` |
| **Status** | In progress |

#### Arena Sub-Modules

**1. Arena Core**
- `ArenaScreen.swift` — Main arena view
- `ArenaViewModel.swift` — Arena state management
- `EmaraArenaViewModel.swift` — Emirate-level arena logic
- `ArenaStore.swift` — Arena data persistence
- `ArenaModels.swift` — Arena data structures
- `ArenaTabView.swift` — Tab navigation within arena

**2. Challenge System**
- `ArenaQuickChallengesView.swift` — Quick challenge selection
- `ArenaChallengeDetailView.swift` — Full challenge detail
- `ArenaChallengeHistoryView.swift` — Past challenges
- `WeeklyChallengeCard.swift` — Weekly challenge display
- `CountdownTimerView.swift` — Challenge countdown

**3. Leaderboards**
- `BattleLeaderboard.swift` — Main leaderboard view
- `BattleLeaderboardRow.swift` — Individual leaderboard entry
- `EmirateLeadersBanner.swift` — Top leaders banner

**4. Hall of Fame**
- `HallOfFameSection.swift` — Hall of fame section
- `HallOfFameFullView.swift` — Full hall of fame view

**5. Arena Backend**
- `SupabaseArenaService.swift` — Supabase operations for arena
- `TribeArenaView.swift` — Tribe-specific arena view
- `MockArenaData.swift` — Preview/test data

---

## SECTION 11 — Gamification System

### XP Engine

**Files:** `XPCalculator.swift`, `LevelStore.swift`

#### XP Earning Triggers

| Trigger | XP Formula |
|---|---|
| **Workout completion** | `truthNumber (calories + minutes) + luckyNumber (heartbeat digit sum)` |
| **Coin mining** | `steps/100 + calories/50 + (intensity bonus: minutes*2 if avgHR > 115)` |
| **Quest completion** | Defined per quest in `QuestDefinitions` |
| **Legendary project milestones** | Defined per project |
| **Streak days** | Via `StreakManager` triggering XP additions |

#### XP Calculation (Workout)

```swift
static func calculateSessionStats(samples:duration:averageHeartRate:activeCalories:) -> XPResult {
    let truthNumber = calories + minutes
    let totalHeartbeats = sum(bpm * segmentDuration for each HR sample)
    let luckyNumber = sum(digits of totalHeartbeats)
    let totalXP = truthNumber + luckyNumber
}
```

### Level System

**File:** `AiQo/Core/Models/LevelStore.swift`

| Setting | Value |
|---|---|
| **Base XP** | 1,000 |
| **Multiplier** | 1.2x per level |
| **XP for level N** | `1000 * 1.2^(N-1)` |
| **Max level** | No hard cap (shields go to Legendary at 35+) |

**Persistence:** UserDefaults keys `aiqo.user.level`, `aiqo.user.currentXP`, `aiqo.user.totalXP`

**Sync:** Level and totalXP are synced to Supabase via `SupabaseArenaService.shared.syncUserStats()`

### Shield Tiers (Visual Level Indicators)

| Level Range | Shield Tier | Color |
|---|---|---|
| 1–4 | Wood | `#8B4513` |
| 5–9 | Bronze | `#CD7F32` |
| 10–14 | Silver | `#C0C0C0` |
| 15–19 | Gold | `#FFD700` |
| 20–24 | Platinum | `#E5E4E2` |
| 25–29 | Diamond | `#B9F2FF` |
| 30–34 | Obsidian | `#3D3D3D` |
| 35+ | Legendary | `#FF6B6B` |

### Streak System

**File:** `AiQo/Core/StreakManager.swift`

**Trigger Conditions:** User achieves daily goal (5000+ steps OR 1 workout OR 30+ minutes activity)

| Property | Description |
|---|---|
| `currentStreak` | Consecutive days meeting goal |
| `longestStreak` | All-time record |
| `lastActiveDate` | Last day goal was met |
| `todayCompleted` | Whether today's goal is met |
| `recentHistory` | Last 30 active days |
| `weeklyConsistency` | 7-day completion percentage |

**Persistence:** UserDefaults with prefix `aiqo.streak.*`

**Continuity Check:** Runs on app launch. If `lastActiveDate` is not yesterday, streak resets to 0.

### Badge System

**File:** `AiQo/Resources/Specs/achievements_spec.json`

Three achievement tiers:

| Type | Points | Examples |
|---|---|---|
| **Badge** | 10 | `badge_first_steps` (First HealthKit sync), `badge_steps_10k` (10K steps in a day) |
| **Shield** | 40-60 | `shield_streak_7_steps` (7-day streak) |
| **Belt** | 120-200 | `belt_month_champion` (Top scorer in tribe for a month) |

Badge unlock rules are keyed by `rule_key` values like `FIRST_HEALTH_SYNC`, `STEPS_DAY_10000`, `STEPS_STREAK_7`, `TRIBE_MONTH_CHAMPION`.

### Legendary Projects

**Files:** `Features/LegendaryChallenges/Models/LegendaryProject.swift`, `RecordProject.swift`, `WeeklyLog.swift`

- Long-duration personal record challenges (e.g., push-up records)
- `RecordProject` is a SwiftData `@Model` stored in the Captain Memory container
- `WeeklyLog` tracks weekly progress entries
- `LegendaryChallengesViewModel` manages the challenge lifecycle
- `RecordProjectManager` handles persistence via SwiftData
- UI includes: `ProjectView`, `RecordDetailView`, `WeeklyReviewView`, `FitnessAssessmentView`

---

## SECTION 12 — Monetization & StoreKit 2

### Free Trial

**File:** `AiQo/Premium/FreeTrialManager.swift`

| Setting | Value |
|---|---|
| **Duration** | 7 days |
| **Start trigger** | First app open (automatic) |
| **Persistence** | UserDefaults + Keychain (survives reinstall) |
| **What unlocks** | All premium features during trial |
| **After expiry** | Paywall shown for premium features |

**States:** `.notStarted` → `.active(daysRemaining: Int)` → `.expired`

#### Trial Persistence Strategy

The trial start date is stored in TWO locations for anti-abuse:

1. **UserDefaults** (`aiqo.freeTrial.startDate`) — Fast access, lost on reinstall
2. **Keychain** (`com.aiqo.trial / trialStartDate`) — Persists across reinstalls

Reading logic:
```
1. Check Keychain first (source of truth, survives reinstall)
2. If Keychain has date but UserDefaults doesn't → sync to UserDefaults
3. If UserDefaults has date but Keychain doesn't → sync to Keychain
4. If neither has date → trial not started
```

This prevents users from getting a new trial by reinstalling the app.

#### Trial State Machine

```
                 ┌─────────────┐
                 │ .notStarted │
                 └──────┬──────┘
                        │ startTrialIfNeeded()
                        ▼
           ┌────────────────────────┐
           │ .active(daysRemaining) │ ← refreshState() on every launch
           └────────────┬───────────┘
                        │ 7 days elapsed
                        ▼
                 ┌──────────┐
                 │ .expired │
                 └──────────┘
```

### Premium Architecture

#### AccessManager

**File:** `AiQo/Premium/AccessManager.swift`

Central access control that checks:
1. Is trial active? → Grant access
2. Is subscription active? → Grant access
3. Neither? → Show paywall

#### EntitlementProvider

**File:** `AiQo/Premium/EntitlementProvider.swift`

Protocol-based entitlement checking that abstracts the trial + subscription logic.

#### PremiumStore

**File:** `AiQo/Premium/PremiumStore.swift`

Observable store that publishes premium state changes for UI reactivity.

### Product IDs

**File:** `AiQo/Core/Purchases/SubscriptionProductIDs.swift`

| Product ID | Type | Price |
|---|---|---|
| `aiqo_nr_30d_individual_5_99` | Non-renewing, 30-day, Individual | $5.99/month |
| `aiqo_nr_30d_family_10_00` | Non-renewing, 30-day, Family (up to 5) | $10.00/month |
| `aiqo_30d_individual_5_99` | Legacy variant | $5.99/month |
| `aiqo_30d_family_10_00` | Legacy variant | $10.00/month |

**Note:** Subscriptions are **non-renewing** (`_nr_` prefix). Each cycle is exactly 30 days. Users must manually repurchase.

### Paywall Design

**Files:** `Premium/PremiumPaywallView.swift`, `UI/Purchases/PaywallView.swift`

- Shows individual and family plan options
- Displays localized prices from StoreKit
- Includes trial countdown if active
- Legal links (Privacy Policy, Terms of Service)
- Retry mechanism for product loading (2 attempts)

### Receipt Validation

**File:** `AiQo/Core/Purchases/ReceiptValidator.swift`

- Validates purchases via Supabase backend
- `EntitlementStore` tracks active subscription state
- `PremiumExpiryNotifier` schedules notifications before expiry

### StoreKit 2 Compliance

- Uses `Product.products(for:)` for loading
- `Transaction.updates` async sequence for real-time transaction observation
- Non-renewing subscriptions checked via `Transaction.currentEntitlements`
- `PurchaseManager` handles purchase flow with outcomes: `.success`, `.pending`, `.cancelled`, `.failed`

---

## SECTION 13 — Supabase Backend Schema

### Connection

| Setting | Value |
|---|---|
| **URL** | `https://zidbsrepqpbucqzxnwgk.supabase.co` |
| **Client** | `supabase-swift` v2.36.0 |
| **Auth** | Sign in with Apple → Supabase Auth |

### Known Tables

| Table | Key Columns | Purpose |
|---|---|---|
| `profiles` | `id`, `name`, `age`, `height_cm`, `weight_kg`, `goal_text`, `is_private`, `device_token`, `total_points`, `level` | User profiles |
| `tribes` | Tribe data | Tribe/group management |
| `tribe_members` | Member associations | Tribe membership |
| `arena_challenges` | Challenge definitions | Weekly challenges |
| `arena_participations` | Participation records | Challenge entries |
| `arena_leaders` | Leaderboard data | Emirate leaders |
| `hall_of_fame` | Fame entries | Historical achievements |

### Auth Strategy

1. User taps "Sign in with Apple" in `AuthFlowUI`
2. Apple returns identity token
3. Token is passed to Supabase Auth
4. Supabase creates/links user account
5. Device token registered for push notifications

### Services

- `SupabaseService.shared` — Main client, profile queries, user search
- `SupabaseArenaService.shared` — Arena-specific operations (sync stats, challenges)
- `TribeRepositories` — Tribe CRUD operations

### Real-Time Subscriptions

Used in Tribe/Arena features for live leaderboard updates and challenge status.

---

## SECTION 14 — Notifications & Background Tasks

### Notification Files

| File | Purpose |
|---|---|
| `NotificationService.swift` | Core notification management, permission requests, remote handling |
| `NotificationCategoryManager.swift` | Registers all notification categories and actions |
| `NotificationIntelligenceManager.swift` | AI-driven notification scheduling, background task management |
| `SmartNotificationManager.swift` | Smart scheduling based on user patterns |
| `SmartNotificationScheduler.swift` (Core) | Coordinates smart notification timing |
| `MorningHabitOrchestrator.swift` | Morning routine notifications |
| `SleepSessionObserver.swift` | Sleep session monitoring and notifications |
| `ActivityNotificationEngine.swift` | Angel number notifications (motivational) |
| `AlarmSchedulingService.swift` | Smart wake alarm scheduling |
| `CaptainBackgroundNotificationComposer.swift` | Composes Captain-style notifications in background |
| `InactivityTracker.swift` | Detects user inactivity for re-engagement |
| `PremiumExpiryNotifier.swift` | Subscription expiry warnings |
| `NotificationRepository.swift` | Notification history storage |

### Background Task Identifiers

Registered in `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`:

| Identifier | Purpose |
|---|---|
| `aiqo.captain.spiritual-whispers.refresh` | Background refresh for spiritual whispers |
| `aiqo.captain.inactivity-check` | Check for user inactivity and send re-engagement |

### UIBackgroundModes

- `audio` — Voice playback, audio coaching
- `remote-notification` — Push notification processing
- `fetch` — Background data fetching

### Notification Categories

Managed by `NotificationCategoryManager.shared.registerAllCategories()`:
- Captain Hamoudi messages (with reply actions)
- Morning habit reminders
- Sleep session reminders
- Activity encouragement
- Premium expiry warnings
- Angel number motivational messages

### MorningHabitOrchestrator

**File:** `AiQo/Services/Notifications/MorningHabitOrchestrator.swift`

- Monitors whether user completed morning routine
- Sends Captain-style encouragement if habits not logged
- Integrates with sleep data for contextual morning messages
- Source identifier: `"morning_habit_orchestrator"` for notification routing

### SleepSessionObserver

**File:** `AiQo/Services/Notifications/SleepSessionObserver.swift`

- Monitors HealthKit sleep sessions
- Triggers sleep analysis when session ends
- Coordinates with Smart Wake Calculator

---

## SECTION 15 — Design System

### Color Tokens

#### Brand Colors (Colors.swift)

| Token | UIColor | Hex | SwiftUI |
|---|---|---|---|
| `mint` | `(0.77, 0.94, 0.86)` | `#C4F0DB` | `.brandMint` |
| `sand` | `(0.97, 0.84, 0.64)` | `#F8D6A3` | `.brandSand` |
| `accent` | `(1.00, 0.90, 0.55)` | `#FFE68C` | `.aiqoAccent` |
| `aiqoBeige` | `(0.98, 0.87, 0.70)` | `#FADEB3` | `.aiqoBeige` |
| `lemon` | `(1.00, 0.93, 0.72)` | `#FFECB8` | `.aiqoLemon` |
| `lav` | `(0.96, 0.88, 1.00)` | `#F5E0FF` | `.aiqoLav` |

#### Semantic Theme (AiQoTheme.swift)

| Token | Light | Dark |
|---|---|---|
| `primaryBackground` | `#F5F7FB` | `#0B1016` |
| `surface` | `#FFFFFF` | `#121922` |
| `surfaceSecondary` | `#EEF2F7` | `#18212B` |
| `textPrimary` | `#0F1721` | `#F6F8FB` |
| `textSecondary` | `#5F6F80` | `#A3AFBC` |
| `accent` | `#5ECDB7` | `#8AE3D1` |
| `border` | `black/0.08` | `white/0.08` |
| `borderStrong` | `black/0.12` | `white/0.12` |
| `iconBackground` | `#F2F6FA` | `#1A2430` |
| `ctaGradientLeading` | `#7CE0D2` | `#90E6D6` |
| `ctaGradientTrailing` | `#A4C8FF` | `#C4D9FF` |

#### Additional Colors (AiQoColors.swift)

| Token | Hex |
|---|---|
| `AiQoColors.mint` | `#CDF4E4` |
| `AiQoColors.beige` | `#F5D5A6` |

### Typography Scale (AiQoTheme.Typography)

| Token | Style |
|---|---|
| `screenTitle` | `.title2, .rounded, .bold` |
| `sectionTitle` | `.headline, .rounded, .semibold` |
| `cardTitle` | `.headline, .rounded, .semibold` |
| `body` | `.subheadline, .rounded` |
| `caption` | `.caption, .rounded` |
| `cta` | `.headline, .rounded, .semibold` |

Custom fonts are available via `.aiqoDisplay()` and `.aiqoHeading()` extensions.

### Spacing Tokens (AiQoTokens.swift)

| Token | Value |
|---|---|
| `AiQoSpacing.xs` | 8pt |
| `AiQoSpacing.sm` | 12pt |
| `AiQoSpacing.md` | 16pt |
| `AiQoSpacing.lg` | 24pt |

### Corner Radius Tokens

| Token | Value |
|---|---|
| `AiQoRadius.control` | 12pt |
| `AiQoRadius.card` | 16pt |
| `AiQoRadius.ctaContainer` | 24pt |

### Metrics

| Token | Value |
|---|---|
| `AiQoMetrics.minimumTapTarget` | 44pt |

### Core UI Components

| Component | File | Purpose |
|---|---|---|
| `AiQoBottomCTA` | `DesignSystem/Components/AiQoBottomCTA.swift` | Primary action button (gradient, full-width) |
| `AiQoCard` | `DesignSystem/Components/AiQoCard.swift` | Standard card container with glassmorphism |
| `AiQoChoiceGrid` | `DesignSystem/Components/AiQoChoiceGrid.swift` | Grid selection component |
| `AiQoPillSegment` | `DesignSystem/Components/AiQoPillSegment.swift` | Segmented pill control |
| `AiQoPlatformPicker` | `DesignSystem/Components/AiQoPlatformPicker.swift` | Platform-specific picker |
| `AiQoSkeletonView` | `DesignSystem/Components/AiQoSkeletonView.swift` | Loading skeleton animation |
| `GlassCardView` | `UI/GlassCardView.swift` | Frosted glass card effect |
| `AiQoScreenHeader` | `UI/AiQoScreenHeader.swift` | Standard screen header |
| `AiQoProfileButton` | `UI/AiQoProfileButton.swift` | Profile avatar button |
| `ErrorToastView` | `UI/ErrorToastView.swift` | Error notification toast |
| `OfflineBannerView` | `UI/OfflineBannerView.swift` | No internet banner |

### View Modifiers

| Modifier | File | Purpose |
|---|---|---|
| `AiQoPressEffect` | `Modifiers/AiQoPressEffect.swift` | Scale-down press animation |
| `AiQoShadow` | `Modifiers/AiQoShadow.swift` | Standard shadow |
| `AiQoSheetStyle` | `Modifiers/AiQoSheetStyle.swift` | Bottom sheet styling |

### Animation Presets

The app uses SwiftUI's built-in spring animations throughout, with common patterns:
- Level-up celebrations use `.opacity` transitions
- Tab changes trigger `HapticEngine.selection()`
- Cards use scale-based press effects
- Workout Live Activity uses `.symbolEffect(.pulse.byLayer)` for heart rate

### RTL Layout Rules

- Global `.environment(\.layoutDirection, .rightToLeft)` set on `MainTabScreen`
- All SwiftUI layouts automatically respect RTL
- Arabic text alignment handled by system
- Tab bar order respects RTL direction

---

## SECTION 16 — Apple Watch Companion

### Current Status: EXISTS and ACTIVE

**Target:** `AiQoWatch Watch App`
**Deployment Target:** watchOS 26.2
**Bundle ID:** `com.mraad500.aiqo.watchkitapp`

### Watch App Structure

| File | Purpose |
|---|---|
| `AiQoWatchApp.swift` | @main entry point |
| `WatchHomeView.swift` | Home screen with health summary |
| `WatchActiveWorkoutView.swift` | Live workout tracking UI |
| `WatchWorkoutListView.swift` | Workout type selection |
| `WatchWorkoutSummaryView.swift` | Post-workout summary |
| `WatchWorkoutManager.swift` | HKWorkoutSession management |
| `WatchHealthKitManager.swift` | Watch-side HealthKit queries |
| `WatchConnectivityService.swift` | Watch→Phone communication |
| `WatchDesignSystem.swift` | Watch-specific design tokens |
| `WatchWorkoutType.swift` | Workout type definitions |

### WatchConnectivity Integration

**Phone-side:** `PhoneConnectivityManager.swift`, `WatchConnectivityService.swift` (in Gym)
**Watch-side:** `WatchConnectivityService.swift`, `WatchConnectivityManager.swift`

**Shared codec:** `WorkoutSyncCodec.swift` + `WorkoutSyncModels.swift` (duplicated in both targets)

Data sync includes:
- Workout start/stop commands
- Heart rate data
- Active calories
- Distance
- Workout session state

### Watch Widget

**Target:** `AiQoWatchWidget`
- `AiQoWatchWidget.swift` — Watch complication
- `AiQoWatchWidgetProvider.swift` — Timeline provider
- Supports: `accessoryInline`, `accessoryCircular`, `accessoryRectangular`

---

## SECTION 17 — Analytics & Crash Reporting

### AnalyticsService

**File:** `AiQo/Services/Analytics/AnalyticsService.swift`

Singleton: `AnalyticsService.shared`

API: `track(_ event: AnalyticsEvent)`

### Analytics Events

**File:** `AiQo/Services/Analytics/AnalyticsEvent.swift`

| Event | Trigger |
|---|---|
| `.appLaunched` | App launch |
| `.appBecameActive` | App foregrounded |
| `.appEnteredBackground` | App backgrounded |
| `.tabSelected(String)` | Tab navigation |
| `.notificationTapped(type:)` | Notification interaction |
| `.freeTrialStarted` | Trial begins |
| `.deepLinkOpened` | Deep link handled (with URL and destination) |

Additional events tracked via `AnalyticsEvent("eventName", properties: [...])` constructor.

### CrashReporter

**File:** `AiQo/Services/CrashReporting/CrashReporter.swift`

Singleton: `CrashReporter.shared`

Initialized at app launch. Current implementation is a placeholder/lightweight wrapper — no third-party crash reporting SDK (like Firebase Crashlytics) is integrated.

### Current Gaps

- No third-party analytics SDK (Firebase, Mixpanel, etc.) is integrated
- CrashReporter is a lightweight wrapper — no production crash reporting
- No screen view tracking events
- No funnel analytics for onboarding flow
- No retention/engagement metrics
- No A/B testing framework
- No revenue analytics
- No Captain conversation quality metrics
- No HealthKit data completeness tracking
- No crash-free rate monitoring

### Recommended Additions

1. **Production crash reporting** — Integrate Firebase Crashlytics or Sentry
2. **Production analytics** — Integrate Firebase Analytics, Mixpanel, or Amplitude
3. **Screen view tracking** — Add `.onAppear` tracking for all major screens
4. **Onboarding funnel** — Track per-step completion/drop-off rates
5. **Workout analytics** — Track completion, duration, type, XP earned per session
6. **Subscription funnel** — Track paywall views → purchase attempts → conversions
7. **Captain analytics** — Track message count, response quality, context usage, fallback rates
8. **Retention metrics** — DAU, WAU, MAU, session duration, streak continuation rate
9. **A/B testing** — Framework for testing paywall designs, onboarding flows, notification timing
10. **Performance monitoring** — Track app launch time, API response times, memory usage

### Event Taxonomy (Recommended)

| Category | Event Name | Properties |
|---|---|---|
| App | `app_launched` | launch_count, is_trial_active |
| App | `app_became_active` | source (notification, deep_link, organic) |
| App | `app_entered_background` | session_duration |
| Onboarding | `onboarding_step_completed` | step_name, step_index |
| Onboarding | `onboarding_completed` | total_duration, initial_level |
| Captain | `captain_message_sent` | screen_context, language, message_length |
| Captain | `captain_response_received` | route (local/cloud), latency_ms, has_plan |
| Captain | `captain_fallback_triggered` | error_type, screen_context |
| Captain | `captain_voice_played` | duration_ms |
| Workout | `workout_started` | type, location (indoor/outdoor), source (siri/app/watch) |
| Workout | `workout_completed` | type, duration_min, calories, xp_earned |
| Workout | `workout_cancelled` | type, duration_at_cancel |
| Kitchen | `meal_plan_generated` | meal_count, source (ai/local) |
| Kitchen | `fridge_scanned` | items_detected |
| Vibe | `vibe_session_started` | vibe_type, audio_asset |
| Vibe | `spotify_recommendation_opened` | vibe_name, spotify_uri |
| Gamification | `level_up` | new_level, shield_tier, total_xp |
| Gamification | `streak_milestone` | streak_days |
| Gamification | `quest_completed` | quest_id, xp_awarded |
| Monetization | `paywall_viewed` | source (trial_expired, feature_gate, deep_link) |
| Monetization | `purchase_attempted` | product_id |
| Monetization | `purchase_completed` | product_id, is_family |
| Monetization | `trial_started` | — |
| Monetization | `trial_expired` | — |
| Tribe | `tribe_created` | — |
| Tribe | `tribe_joined` | source (invite_code, deep_link) |
| Tribe | `arena_challenge_entered` | challenge_type |
| Notification | `notification_tapped` | type, source |
| Notification | `notification_permission_granted` | — |
| Deep Link | `deep_link_opened` | url, destination |

---

## SECTION 18 — Accessibility & Localization

### VoiceOver Support

**File:** `AiQo/Core/AiQoAccessibility.swift`, `UI/AccessibilityHelpers.swift`

- `AiQoAccessibility` provides accessibility labels and hints
- Tab items have `.accessibilityHint()` modifiers
- `MainTabScreen` adds hints like "View daily health summary", "Workouts and fitness challenges"
- `AiQoMetrics.minimumTapTarget = 44pt` ensures touch targets meet Apple guidelines

### Dynamic Type Support

- Uses system font with `.rounded` design throughout (`Font.system(.*, design: .rounded)`)
- SwiftUI's automatic Dynamic Type scaling is inherited
- No explicit Dynamic Type overrides or fixed font sizes in most components

### Reduce Motion Handling

- No explicit `@Environment(\.accessibilityReduceMotion)` handling detected
- SwiftUI's built-in animation reduction is relied upon

### Localization Strategy

- Two languages: Arabic (`ar.lproj`) and English (`en.lproj`)
- 2,153+ localized strings per language
- `NSLocalizedString()` used across 35+ screens
- `LocalizationManager` handles runtime language switching
- `Bundle+Language.swift` provides method swizzling for dynamic locale changes
- `ArabicNumberFormatter` converts Latin digits to Arabic numerals

### RTL-Specific Layout Patterns

- Global RTL direction set via `.environment(\.layoutDirection, .rightToLeft)`
- All SwiftUI layouts respect RTL automatically
- `HStack` content is automatically reversed in RTL
- Text alignment follows semantic direction

---

## SECTION 19 — Feature Flags & Configuration

### Info.plist Feature Flags

| Key | Current Value | Controls |
|---|---|---|
| `TRIBE_FEATURE_VISIBLE` | `true` | Whether Tribe tab/features are visible |
| `TRIBE_BACKEND_ENABLED` | `true` | Whether Supabase Tribe backend is active |
| `TRIBE_SUBSCRIPTION_GATE_ENABLED` | `true` | Whether premium subscription is required for Tribe |

### API Configuration (Info.plist)

| Key | Source | Purpose |
|---|---|---|
| `CAPTAIN_API_KEY` | `Secrets.xcconfig` | Gemini API key for Captain brain |
| `CAPTAIN_ARABIC_API_URL` | `Secrets.xcconfig` | Arabic API endpoint |
| `CAPTAIN_VOICE_API_KEY` | `Secrets.xcconfig` | ElevenLabs voice API key |
| `CAPTAIN_VOICE_API_URL` | `Secrets.xcconfig` | ElevenLabs endpoint |
| `CAPTAIN_VOICE_MODEL_ID` | `Secrets.xcconfig` | ElevenLabs model (`eleven_multilingual_v2`) |
| `CAPTAIN_VOICE_VOICE_ID` | `Secrets.xcconfig` | ElevenLabs voice ID |
| `COACH_BRAIN_LLM_API_KEY` | `Secrets.xcconfig` | Coach Brain middleware API key |
| `COACH_BRAIN_LLM_API_URL` | `Info.plist` | `generativelanguage.googleapis.com/.../gemini-3-flash-preview` |
| `SPIRITUAL_WHISPERS_LLM_API_URL` | `Info.plist` | Same Gemini 3 Flash Preview endpoint |
| `SPOTIFY_CLIENT_ID` | `Secrets.xcconfig` | Spotify SDK client ID |
| `SUPABASE_URL` | `AiQo.xcconfig` | Supabase project URL |
| `SUPABASE_ANON_KEY` | `AiQo.xcconfig` | Supabase anonymous key |

### Background Task Identifiers

| Identifier | Purpose |
|---|---|
| `aiqo.captain.spiritual-whispers.refresh` | Background spiritual whisper generation |
| `aiqo.captain.inactivity-check` | User inactivity detection |

### URL Schemes

| Scheme | Purpose |
|---|---|
| `aiqo` | App deep links |
| `aiqo-spotify` | Spotify auth callback |

### Queried URL Schemes (LSApplicationQueriesSchemes)

| Scheme | Purpose |
|---|---|
| `spotify` | Check if Spotify is installed |
| `instagram-stories` | Instagram Stories sharing |
| `instagram` | Instagram sharing |

### Siri Activity Types (NSUserActivityTypes)

| Activity | Purpose |
|---|---|
| `com.aiqo.startWalk` | Start walking workout |
| `com.aiqo.startRun` | Start running workout |
| `com.aiqo.startHIIT` | Start HIIT workout |
| `com.aiqo.openCaptain` | Open Captain chat |
| `com.aiqo.todaySummary` | View today's summary |
| `com.aiqo.logWater` | Log water intake |
| `com.aiqo.openKitchen` | Open Kitchen |
| `com.aiqo.weeklyReport` | View weekly report |

### How to Enable/Disable Features

1. **Tribe:** Set `TRIBE_FEATURE_VISIBLE` to `false` in `Info.plist` to hide
2. **Tribe Backend:** Set `TRIBE_BACKEND_ENABLED` to `false` to disable Supabase calls
3. **Tribe Paywall:** Set `TRIBE_SUBSCRIPTION_GATE_ENABLED` to `false` for free access
4. **Captain Voice:** Remove `CAPTAIN_VOICE_API_KEY` from `Secrets.xcconfig` to disable voice
5. **Spotify:** Remove `SPOTIFY_CLIENT_ID` to disable music features

---

## SECTION 20 — Known Issues, Gaps & Roadmap

### Known Issues

1. **Duplicate WorkoutSyncCodec/Models** — `Shared/WorkoutSyncCodec.swift` and `Shared/WorkoutSyncModels.swift` are duplicated between the iOS and watchOS targets (in `AiQoWatch Watch App/Shared/`). These should be in a shared Swift Package or framework.

2. **Kitchen tab not in TabView** — `MainTabRouter.Tab.kitchen` exists as case `.kitchen = 3` but is not rendered as a tab in `MainTabScreen`. It's accessed via a notification (`openKitchenFromHome`) from the Home screen. This is confusing navigation.

3. **Tribe tab not in TabView** — `MainTabRouter.Tab.tribe` exists as case `.tribe = 2` but is not currently rendered in `MainTabScreen`'s TabView. Only 3 tabs are visible (Home, Gym, Captain).

4. **CrashReporter is a stub** — `CrashReporter.shared` is initialized but no real crash reporting SDK is integrated.

5. **AnalyticsService has no backend** — Events are tracked but there's no indication they're sent anywhere (no Firebase, Mixpanel, etc.).

6. **API keys in xcconfig** — `Secrets.xcconfig` contains real API keys and is tracked in git. This file should be gitignored and not committed.

7. **Supabase credentials in AiQo.xcconfig** — The anon key is hardcoded in the non-gitignored config file. While anon keys are designed to be public with RLS, this is still a best-practice concern.

8. **Legacy ViewControllers** — `DatingScreenViewController`, `LoginViewController`, `GymViewController`, `LegacyCalculationViewController`, `RecapViewController`, `RewardsViewController`, `WinsViewController`, `MyPlanViewController` — These UIKit ViewControllers exist alongside SwiftUI views. Migration to pure SwiftUI would be cleaner.

9. **No `AppFlowController`** — The onboarding flow is controlled by checking 5 separate UserDefaults flags. A proper state machine (`AppFlowController`) would be more maintainable.

10. **Sleep Agent language mismatch** — Comments in `BrainOrchestrator` note that Apple Intelligence may fail due to "language mismatch (ar-SA vs en)" — the local model may not support Arabic well.

### UI/UX Gaps

1. **No Settings screen in tab bar** — Settings accessible only from profile
2. **No pull-to-refresh on Home** — Health data refreshes on appear but no manual refresh
3. **No empty states** — Several screens lack empty state designs
4. **No dark mode toggle** — Relies entirely on system setting
5. **No skeleton loading in all screens** — `AiQoSkeletonView` exists but isn't used everywhere

### Missing Features Before TestFlight

1. **Production crash reporting** — Integrate Firebase Crashlytics
2. **Production analytics** — Integrate analytics backend
3. **Proper error handling** — Many `print()` statements instead of user-facing error messages
4. **App Store screenshots** — Need marketing assets
5. **Privacy nutrition labels** — Need accurate App Store privacy declarations
6. **Remove hardcoded API keys** — Move all secrets to secure storage or CI environment
7. **App Review compliance** — Ensure subscription display meets Apple guidelines

### Missing Features Before App Store Launch

1. **Notification permission optimization** — Currently requests all at once
2. **Widget data sharing** — App Group setup for widget↔app data sharing
3. **Proper app icon** — Need final app icon (current has placeholder considerations)
4. **Localization QA** — Full RTL testing pass
5. **Performance profiling** — Memory and battery optimization
6. **Accessibility audit** — VoiceOver full testing pass
7. **Sign in with Apple compliance** — Account deletion support

### Missing Features Before App Store Launch (Expanded)

1. **Notification permission optimization** — Currently requests all permissions at once. Should use progressive permission requests.
2. **Widget data sharing** — App Group setup needed for widget ↔ app real-time data sharing. Currently widgets may show stale data.
3. **App icon finalization** — Current icon has had alpha channel issues (fixed in commit `69ed456`). Need final marketing icon.
4. **Full RTL testing pass** — Every screen needs RTL validation with Arabic content.
5. **Performance profiling** — Memory leaks, battery drain during workout sessions, background task efficiency.
6. **Full accessibility audit** — VoiceOver navigation, Dynamic Type overflow, Reduce Motion compliance.
7. **Sign in with Apple compliance** — Apple requires account deletion support. Need Settings → Delete Account flow.
8. **App Store review guidelines** — Subscription display must follow App Store guidelines precisely (pricing clarity, cancellation instructions).
9. **Privacy nutrition labels** — Must accurately declare all data types collected/tracked.
10. **GDPR/privacy compliance** — Data export and deletion capabilities required for certain markets.
11. **Rate limiting** — Captain API calls need client-side rate limiting to prevent abuse.
12. **Offline mode** — Some features should gracefully degrade when offline (currently shows error messages).
13. **Data migration** — Strategy for future SwiftData schema changes.
14. **iPad support** — Currently iPhone-only. iPad layout may need attention.
15. **Landscape mode** — Lock to portrait or add landscape support.

### Post-Launch Roadmap

#### Phase 1 — Polish & Analytics (Month 1-2)
1. **Production analytics** — Firebase Analytics + Crashlytics integration
2. **Onboarding optimization** — A/B test onboarding flow with funnel analytics
3. **Performance optimization** — Battery, memory, network usage improvements
4. **Bug fixes** — Address TestFlight feedback

#### Phase 2 — Feature Enhancement (Month 3-4)
5. **Food recognition AI** — Enhanced kitchen camera with on-device food recognition using CoreML
6. **Health trends** — Weekly/monthly health trend analysis with charts
7. **Custom workout builder** — User-created workout plans saved to library
8. **AI voice conversations** — Real-time voice chat with Captain Hamoudi (streaming ElevenLabs)

#### Phase 3 — Social & Community (Month 5-6)
9. **Social features** — Direct messaging within tribes
10. **Community challenges** — Global challenges beyond individual tribes
11. **Profile sharing** — Public profile cards for social media
12. **Referral program expansion** — Viral growth mechanics

#### Phase 4 — Platform Expansion (Month 7+)
13. **Arabic dialect expansion** — Gulf (خليجي), Levantine (شامي), Egyptian (مصري) dialects
14. **Wearable expansion** — Support for additional health devices beyond Apple Watch
15. **Integration with medical providers** — Share health reports with healthcare professionals
16. **Mindfulness module** — Guided meditation, breathing exercises, body scan
17. **iPad optimization** — Full iPad layout support with Split View
18. **macOS Catalyst** — Desktop companion app

### Known Technical Debt

1. **UIKit ↔ SwiftUI bridge** — Several legacy UIKit ViewControllers (`DatingScreenViewController`, `GymViewController`, `LoginViewController`, etc.) coexist with SwiftUI. These should be migrated to pure SwiftUI for consistency.

2. **Shared code duplication** — `WorkoutSyncCodec.swift` and `WorkoutSyncModels.swift` are copy-pasted between iOS and watchOS targets. Should be extracted to a Swift Package.

3. **Missing state machine** — Onboarding flow is controlled by 5 separate UserDefaults booleans. A proper `AppFlowController` state machine would be more maintainable and testable.

4. **Test coverage** — Only 5 test files exist:
   - `IngredientAssetCatalogTests.swift`
   - `IngredientAssetLibraryTests.swift`
   - `PurchasesTests.swift`
   - `QuestEvaluatorTests.swift`
   - `SmartWakeManagerTests.swift`

   Critical paths lacking tests: BrainOrchestrator routing, PrivacySanitizer PII redaction, CaptainPromptBuilder prompt generation, StreakManager continuity logic, FreeTrialManager state transitions.

5. **Hardcoded strings** — Some screens still have hardcoded strings despite the localization effort. The `L10n.swift` file in Gym suggests an attempted but incomplete type-safe localization approach.

6. **Missing error boundaries** — Many `print()` statements for errors instead of user-facing error handling. The `AiQoError.swift` error types exist but aren't consistently used.

7. **Singleton proliferation** — 15+ singletons (`.shared`) create hidden dependencies. Consider dependency injection for testability.

8. **API key security** — `Secrets.xcconfig` is committed to git with real API keys. Should be gitignored with a template file committed instead.

---

## Appendix A — Siri Shortcuts

### Available Shortcuts (via AppIntents)

| Shortcut | Intent | Phrases |
|---|---|---|
| Start Workout | `StartWorkoutIntent(workout: .running)` | "Start workout with AiQo", "ابدأ تمرين في AiQo" |
| Start Walk | `StartWorkoutIntent(workout: .walking)` | "Start walking workout with AiQo", "ابدأ تمرين مشي في AiQo" |

### Supported Workout Types (Siri)

- Running, Walking, Cycling, Strength, HIIT, Swimming, Yoga

### Donated Activities (SiriShortcutsManager)

- `com.aiqo.startWalk`, `com.aiqo.startRun`, `com.aiqo.startHIIT`
- `com.aiqo.openCaptain`, `com.aiqo.todaySummary`, `com.aiqo.logWater`
- `com.aiqo.openKitchen`, `com.aiqo.weeklyReport`

---

## Appendix B — Live Activity (Dynamic Island)

### WorkoutActivityAttributes

**File:** `AiQoWidget/AiQoWidgetLiveActivity.swift`

**ContentState properties:**
- `title: String`
- `elapsedSeconds: Int`
- `elapsedAnchorDate: Date?`
- `heartRate: Int`
- `activeCalories: Int`
- `distanceMeters: Double`
- `phase: WorkoutPhase` (`.running`, `.paused`, `.ending`)
- `heartRateState: HeartRateState` (`.neutral`, `.warmingUp`, `.zone2`, `.belowZone2`, `.aboveZone2`)
- `activeBuffs: [Buff]` (with tones: `.mint`, `.amber`, `.sky`, `.rose`, `.lavender`)

**Dynamic Island Regions:**
- **Expanded Leading:** Heart rate with pulse animation
- **Expanded Center:** Workout title + active buffs
- **Expanded Trailing:** Timer + phase label
- **Expanded Bottom:** Calorie/distance chips + buff summary
- **Compact Leading:** Heart icon + BPM
- **Compact Trailing:** Elapsed time
- **Minimal:** Pulsing heart glyph with buff indicator

**Lock Screen:** Full workout dashboard with gradient background, heart rate zones, timer, calories, distance, Zone 2 badge.

---

## Appendix C — Weekly Report & Data Export

### Weekly Report

**Files:** `Features/WeeklyReport/WeeklyReportModel.swift`, `WeeklyReportViewModel.swift`, `WeeklyReportView.swift`, `ShareCardRenderer.swift`

- Aggregates 7-day health data
- Generates shareable card image via `ShareCardRenderer`
- Available via Siri shortcut: `com.aiqo.weeklyReport`

### Health Data Export

**File:** `Features/DataExport/HealthDataExporter.swift`

- Exports user health data for personal backup
- Privacy-compliant data portability

### Progress Photos

**Files:** `Features/ProgressPhotos/ProgressPhotoStore.swift`, `ProgressPhotosView.swift`

- Body transformation photo tracking
- Before/after comparison views
- Photo storage and management

---

---

## Appendix D — Complete File Inventory

### App/ Directory (11 files)

```
AiQo/App/
├── AppDelegate.swift                    # @main + UIApplicationDelegate + Siri intents (455 lines)
├── AppRootManager.swift                 # Cross-tab state management
├── AuthFlowUI.swift                     # Sign in with Apple flow
├── DatingScreenViewController.swift     # Profile setup (onboarding)
├── LanguageSelectionView.swift          # Language picker (Arabic/English)
├── LoginViewController.swift            # Legacy login controller
├── MainTabRouter.swift                  # Tab navigation singleton
├── MainTabScreen.swift                  # TabView with 3 visible tabs
├── MealModels.swift                     # Meal data models
└── SceneDelegate.swift                  # Scene lifecycle
```

### Core/ Directory (29 files)

```
AiQo/Core/
├── AiQoAccessibility.swift              # Accessibility labels and hints
├── AiQoAudioManager.swift               # Central audio session management
├── AppSettingsScreen.swift              # Settings UI
├── AppSettingsStore.swift               # User preferences singleton
├── ArabicNumberFormatter.swift          # Latin → Arabic numeral conversion
├── CaptainMemory.swift                  # SwiftData @Model for memories
├── CaptainMemorySettingsView.swift      # Memory management UI
├── CaptainVoiceAPI.swift                # ElevenLabs API client
├── CaptainVoiceCache.swift              # Voice audio local cache
├── CaptainVoiceService.swift            # Voice synthesis orchestrator
├── Colors.swift                         # UIColor + SwiftUI Color definitions
├── Constants.swift                      # App-wide constants namespace (K)
├── DailyGoals.swift                     # Daily step/calorie goal tracking
├── DeveloperPanelView.swift             # Debug panel (DEBUG only)
├── HapticEngine.swift                   # Haptic feedback utilities
├── HealthKitMemoryBridge.swift          # HK → Captain memory sync
├── MemoryExtractor.swift                # Conversation → memory extraction
├── MemoryStore.swift                    # Memory CRUD manager
├── SiriShortcutsManager.swift           # Siri shortcut donation
├── SmartNotificationScheduler.swift     # Smart notification timing
├── SpotifyVibeManager.swift             # Spotify SDK integration
├── StreakManager.swift                  # Streak tracking
├── UserProfileStore.swift              # User profile data store
├── VibeAudioEngine.swift               # Binaural beats + ambient audio
├── Localization/
│   ├── Bundle+Language.swift            # Dynamic locale switching
│   └── LocalizationManager.swift        # Language management
├── Models/
│   ├── ActivityNotification.swift       # Notification models
│   ├── LevelStore.swift                 # XP + Level + Shield system
│   └── NotificationPreferencesStore.swift
├── Purchases/
│   ├── EntitlementStore.swift           # Active subscription state
│   ├── PurchaseManager.swift            # StoreKit 2 manager
│   ├── ReceiptValidator.swift           # Supabase receipt validation
│   └── SubscriptionProductIDs.swift     # Product ID registry
└── Utilities/
    └── ConnectivityDebugProviding.swift
```

### Features/Captain/ Directory (26 files)

```
AiQo/Features/Captain/
├── AiQoPromptManager.swift              # Prompt management utilities
├── AppleIntelligenceSleepAgent.swift     # On-device sleep analysis
├── BrainOrchestrator.swift              # AI routing engine (480 lines)
├── CaptainChatView.swift                # Main chat UI
├── CaptainContextBuilder.swift          # HealthKit → context aggregation
├── CaptainFallbackPolicy.swift          # Offline/error fallback responses
├── CaptainIntelligenceManager.swift     # Intelligence feature management
├── CaptainModels.swift                  # Chat message + structured response models (488 lines)
├── CaptainNotificationRouting.swift     # Notification → Captain chat routing
├── CaptainOnDeviceChatEngine.swift      # On-device chat fallback
├── CaptainPersonaBuilder.swift          # Banned phrases + response rules
├── CaptainPromptBuilder.swift           # 6-layer system prompt generator (362 lines)
├── CaptainScreen.swift                  # Captain tab main screen
├── CaptainViewModel.swift               # Main Captain ViewModel (400+ lines)
├── ChatHistoryView.swift                # Chat session history browser
├── CloudBrainService.swift              # Privacy wrapper for cloud API
├── CoachBrainMiddleware.swift           # Coach brain translation layer
├── CoachBrainTranslationConfig.swift    # Translation configuration
├── HybridBrainService.swift             # Gemini API transport (415 lines)
├── LLMJSONParser.swift                  # Robust JSON extraction from LLM output
├── LocalBrainService.swift              # Apple Intelligence service
├── LocalIntelligenceService.swift       # Local intelligence utilities
├── MessageBubble.swift                  # Chat bubble UI component
├── PrivacySanitizer.swift               # Privacy-first data sanitization (397 lines)
├── PromptRouter.swift                   # Local route prompt generation
└── ScreenContext.swift                  # Screen context enum (6 cases)
```

### Features/Home/ Directory (23 files)

```
AiQo/Features/Home/
├── ActivityDataProviding.swift          # Activity data protocol
├── AlarmSetupCardView.swift             # Smart wake alarm card
├── DJCaptainChatView.swift              # Quick Captain chat from home
├── DailyAuraModels.swift                # Daily aura data models
├── DailyAuraPathData.swift              # Aura animation path data
├── DailyAuraView.swift                  # Animated health visualization
├── DailyAuraViewModel.swift             # Aura state management
├── HealthKitService+Water.swift         # Water tracking extension
├── HomeStatCard.swift                   # Health stat display cards
├── HomeView.swift                       # Main home screen
├── HomeViewModel.swift                  # Home data aggregation
├── LevelUpCelebrationView.swift         # Level-up animation overlay
├── MetricKind.swift                     # Metric type enum
├── SleepDetailCardView.swift            # Sleep data card
├── SleepScoreRingView.swift             # Sleep quality ring
├── SmartWakeCalculatorView.swift        # Optimal wake time UI
├── SmartWakeEngine.swift                # Sleep cycle calculation engine
├── SmartWakeViewModel.swift             # Smart wake state management
├── SpotifyVibeCard.swift                # Spotify widget on home
├── StreakBadgeView.swift                # Streak display badge
├── VibeControlSheet.swift               # Vibe/music control sheet
├── WaterBottleView.swift                # Water bottle animation
└── WaterDetailSheetView.swift           # Water tracking detail
```

### Features/Gym/ Directory (60+ files)

```
AiQo/Features/Gym/
├── ActiveRecoveryView.swift
├── AudioCoachManager.swift
├── CinematicGrindCardView.swift
├── CinematicGrindViews.swift
├── ExercisesView.swift
├── GuinnessEncyclopediaView.swift
├── GymViewController.swift
├── HandsFreeZone2Manager.swift
├── HeartView.swift
├── L10n.swift
├── LiveMetricsHeader.swift
├── LiveWorkoutSession.swift
├── MyPlanViewController.swift
├── OriginalWorkoutCardView.swift
├── PhoneWorkoutSummaryView.swift
├── RecapViewController.swift
├── RewardsViewController.swift
├── ShimmeringPlaceholder.swift
├── SoftGlassCardView.swift
├── SpotifyWebView.swift
├── SpotifyWorkoutPlayerView.swift
├── WatchConnectionStatusButton.swift
├── WatchConnectivityService.swift
├── WinsViewController.swift
├── WorkoutLiveActivityManager.swift
├── WorkoutSessionScreen.swift.swift
├── WorkoutSessionSheetView.swift
├── WorkoutSessionViewModel.swift
├── Club/
│   ├── ClubRootView.swift
│   ├── Body/BodyView.swift
│   ├── Body/GratitudeAudioManager.swift
│   ├── Body/GratitudeSessionView.swift
│   ├── Body/WorkoutCategoriesView.swift
│   ├── Challenges/ChallengesView.swift
│   ├── Components/ClubNavigationComponents.swift
│   ├── Components/RailScrollOffsetPreferenceKey.swift
│   ├── Components/RightSideRailView.swift
│   ├── Components/RightSideVerticalRail.swift
│   ├── Components/SegmentedTabs.swift
│   ├── Components/SlimRightSideRail.swift
│   ├── Impact/ImpactAchievementsView.swift
│   ├── Impact/ImpactContainerView.swift
│   ├── Impact/ImpactSummaryView.swift
│   └── Plan/PlanView.swift
│       └── WorkoutPlanFlowViews.swift
├── Models/GymExercise.swift
├── QuestKit/                            # 10 files
├── Quests/                              # 20+ files (Models, Store, Views, VisionCoach)
└── T/                                   # Spin Wheel (4 files)
```

### Features/Kitchen/ Directory (25+ files)

```
AiQo/Features/Kitchen/
├── CameraView.swift
├── CompositePlateView.swift
├── FridgeInventoryView.swift
├── IngredientAssetCatalog.swift
├── IngredientAssetLibrary.swift
├── IngredientCatalog.swift
├── IngredientDisplayItem.swift
├── IngredientKey.swift
├── InteractiveFridgeView.swift
├── KitchenLanguageRouter.swift
├── KitchenModels.swift
├── KitchenPersistenceStore.swift
├── KitchenPlanGenerationService.swift
├── KitchenSceneView.swift
├── KitchenScreen.swift
├── KitchenView.swift
├── KitchenViewModel.swift
├── LocalMealsRepository.swift
├── Meal.swift
├── MealIllustrationView.swift
├── MealImageSpec.swift
├── MealPlanGenerator.swift
├── MealPlanView.swift
├── MealSectionView.swift
├── MealsRepository.swift
├── NutritionTrackerView.swift
├── PlateTemplate.swift
├── RecipeCardView.swift
├── SmartFridgeCameraPreviewController.swift
├── SmartFridgeCameraViewModel.swift
├── SmartFridgeScannedItemRecord.swift
├── SmartFridgeScannerView.swift
└── meals_data.json
```

### Services/ Directory (20 files)

```
AiQo/Services/
├── AiQoError.swift                      # Centralized error types
├── DeepLinkRouter.swift                 # URL scheme + Universal Link handler
├── NetworkMonitor.swift                 # NWPathMonitor wrapper
├── NotificationType.swift               # Notification type enum
├── ReferralManager.swift                # Referral code management
├── SupabaseArenaService.swift           # Arena-specific Supabase ops
├── SupabaseService.swift                # Main Supabase client
├── Analytics/
│   ├── AnalyticsEvent.swift             # Event definitions
│   └── AnalyticsService.swift           # Tracking service
├── CrashReporting/
│   └── CrashReporter.swift              # Crash reporting (stub)
├── Notifications/
│   ├── ActivityNotificationEngine.swift # Angel number notifications
│   ├── AlarmSchedulingService.swift     # Smart alarm scheduling
│   ├── CaptainBackgroundNotificationComposer.swift
│   ├── InactivityTracker.swift          # User inactivity detection
│   ├── MorningHabitOrchestrator.swift   # Morning routine monitoring
│   ├── NotificationCategoryManager.swift # Category registration
│   ├── NotificationIntelligenceManager.swift # AI-driven scheduling
│   ├── NotificationRepository.swift     # Notification history
│   ├── NotificationService.swift        # Core notification service
│   ├── PremiumExpiryNotifier.swift      # Subscription warnings
│   ├── SleepSessionObserver.swift       # Sleep session monitoring
│   └── SmartNotificationManager.swift   # Smart scheduling
└── Permissions/HealthKit/
    ├── HealthKitService.swift           # Unified HK service (actor)
    └── TodaySummary.swift               # Today's health summary
```

### Tribe/ Directory (35+ files)

```
AiQo/Tribe/
├── Arena/TribeArenaView.swift
├── Galaxy/                              # 30+ views
│   ├── ArenaScreen.swift
│   ├── ArenaViewModel.swift
│   ├── ArenaModels.swift
│   ├── GalaxyScreen.swift
│   ├── GalaxyViewModel.swift
│   ├── GalaxyModels.swift
│   ├── ... (25+ more files)
├── Log/TribeLogView.swift
├── Models/
│   ├── TribeFeatureModels.swift
│   └── TribeModels.swift
├── Preview/
│   ├── TribePreviewController.swift
│   └── TribePreviewData.swift
├── Repositories/TribeRepositories.swift
├── Stores/
│   ├── ArenaStore.swift
│   ├── GalaxyStore.swift
│   └── TribeLogStore.swift
├── Views/
│   ├── GlobalTribeRadialView.swift
│   ├── TribeAtomRingView.swift
│   ├── TribeEnergyCoreCard.swift
│   ├── TribeHubScreen.swift
│   └── TribeLeaderboardView.swift
├── TribeModuleComponents.swift
├── TribeModuleModels.swift
├── TribeModuleViewModel.swift
├── TribePulseScreenView.swift
├── TribeScreen.swift
└── TribeStore.swift
```

### DesignSystem/ Directory (12 files)

```
AiQo/DesignSystem/
├── AiQoColors.swift                     # Brand color tokens
├── AiQoTheme.swift                      # Semantic theme (light/dark)
├── AiQoTokens.swift                     # Spacing, radius, metrics
├── Components/
│   ├── AiQoBottomCTA.swift              # Primary action button
│   ├── AiQoCard.swift                   # Standard card container
│   ├── AiQoChoiceGrid.swift             # Grid selection
│   ├── AiQoPillSegment.swift            # Segmented pill control
│   ├── AiQoPlatformPicker.swift         # Platform-aware picker
│   ├── AiQoSkeletonView.swift           # Loading skeleton
│   └── StatefulPreviewWrapper.swift     # Preview utility
└── Modifiers/
    ├── AiQoPressEffect.swift            # Scale-down press animation
    ├── AiQoShadow.swift                 # Standard shadow
    └── AiQoSheetStyle.swift             # Bottom sheet styling
```

### Widget Targets

```
AiQoWidget/                              # iOS Home Screen + Live Activity
├── AiQoEntry.swift
├── AiQoProvider.swift
├── AiQoRingsFaceWidget.swift
├── AiQoSharedStore.swift
├── AiQoWatchFaceWidget.swift
├── AiQoWidget.swift
├── AiQoWidgetBundle.swift
├── AiQoWidgetLiveActivity.swift         # Dynamic Island + Lock Screen (719 lines)
└── AiQoWidgetView.swift

AiQoWatchWidget/                         # watchOS Complication
├── AiQoWatchWidget.swift
├── AiQoWatchWidgetBundle.swift
└── AiQoWatchWidgetProvider.swift
```

### Test Targets

```
AiQoTests/
├── IngredientAssetCatalogTests.swift
├── IngredientAssetLibraryTests.swift
├── PurchasesTests.swift
├── QuestEvaluatorTests.swift
└── SmartWakeManagerTests.swift

AiQoUITests/                             # (empty/minimal)

AiQoWatch Watch AppTests/
└── AiQoWatch_Watch_AppTests.swift

AiQoWatch Watch AppUITests/
├── AiQoWatch_Watch_AppUITests.swift
└── AiQoWatch_Watch_AppUITestsLaunchTests.swift
```

---

## Appendix E — Complete UserDefaults Key Reference

### Onboarding Flags

| Key | Type | Default | Description |
|---|---|---|---|
| `didSelectLanguage` | Bool | false | Language selection completed |
| `didShowFirstAuthScreen` | Bool | false | Auth screen shown |
| `didCompleteDatingProfile` | Bool | false | Profile setup completed |
| `didCompleteLegacyCalculation` | Bool | false | HealthKit sync + level calc done |
| `didCompleteFeatureIntro` | Bool | false | Feature intro viewed |

### Captain Customization

| Key | Type | Description |
|---|---|---|
| `captain_user_name` | String | User's display name for Captain |
| `captain_user_age` | String | User's age |
| `captain_user_height` | String | User's height |
| `captain_user_weight` | String | User's weight |
| `captain_calling` | String | How Captain addresses user |
| `captain_tone` | String | Preferred conversation tone |
| `captain_memory_enabled` | Bool | Captain memory toggle (default: true) |

### Gamification

| Key | Type | Description |
|---|---|---|
| `aiqo.user.level` | Int | Current level (starts at 1) |
| `aiqo.user.currentXP` | Int | XP within current level |
| `aiqo.user.totalXP` | Int | Total lifetime XP |
| `aiqo.streak.current` | Int | Current consecutive days |
| `aiqo.streak.longest` | Int | All-time longest streak |
| `aiqo.streak.lastActive` | Date | Last active day |
| `aiqo.streak.history` | Data | JSON-encoded [Date] array (last 30 days) |
| `lastCelebratedLevel` | Int | Last level-up celebration shown |

### App Settings

| Key | Type | Description |
|---|---|---|
| `appLanguage` | String | Current language (`arabic` / `english`) |
| `notificationsEnabled` | Bool | Global notification toggle |
| `user_gender` | String | User gender for notification personalization |

### Health & Goals

| Key | Type | Description |
|---|---|---|
| `aiqo.dailyGoals` | Data | JSON-encoded daily step/calorie goals |

### Monetization

| Key | Type | Description |
|---|---|---|
| `aiqo.freeTrial.startDate` | Date | Trial start (also in Keychain) |

---

## Appendix F — API Endpoint Reference

### Gemini API (Captain Brain)

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={API_KEY}

Headers:
  Content-Type: application/json
  Accept: application/json

Body: {
  "systemInstruction": { "parts": [{ "text": "<6-layer system prompt>" }] },
  "contents": [<Gemini format messages>],
  "generationConfig": {
    "maxOutputTokens": 600-900,
    "temperature": 0.7
  }
}

Response: {
  "candidates": [{ "content": { "parts": [{ "text": "<JSON response>" }] } }]
}
```

### Gemini API (Coach Brain Middleware)

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key={API_KEY}
```

Used by `CoachBrainMiddleware.swift` for translation and coaching enhancement.

### Gemini API (Spiritual Whispers)

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key={API_KEY}
```

Used for background spiritual whisper generation.

### ElevenLabs Voice API

```
POST https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}?output_format=mp3_44100_128

Headers:
  Content-Type: application/json
  Accept: audio/mpeg
  xi-api-key: {API_KEY}

Body: {
  "text": "<Captain's message>",
  "model_id": "eleven_multilingual_v2",
  "voice_settings": {
    "stability": 0.34,
    "similarity_boost": 0.88,
    "style": 0.18,
    "use_speaker_boost": true
  }
}

Response: Binary MP3 audio data
```

### Supabase API

```
Base URL: https://zidbsrepqpbucqzxnwgk.supabase.co

Tables accessed:
- GET/POST /rest/v1/profiles
- GET/POST /rest/v1/tribes
- GET/POST /rest/v1/tribe_members
- GET/POST /rest/v1/arena_challenges
- GET/POST /rest/v1/arena_participations

Auth: Bearer token from Sign in with Apple → Supabase Auth flow
```

---

## Appendix G — Complete ScreenContext Reference

**File:** `AiQo/Features/Captain/ScreenContext.swift`

```swift
enum ScreenContext: String, CaseIterable, Sendable {
    case kitchen        // Kitchen (المطبخ)
    case gym            // Gym (الجيم)
    case sleepAnalysis  // Sleep Analysis (تحليل النوم)
    case peaks          // Peaks (قِمَم)
    case mainChat       // Main Chat (الدردشة الرئيسية)
    case myVibe         // My Vibe (ذبذباتي)
}
```

### Context → AI Behavior Matrix

| Context | Route | Output Tokens | workoutPlan | mealPlan | spotifyRec | Tone Bias |
|---|---|---|---|---|---|---|
| `mainChat` | Cloud | 600 | Only if asked | Only if asked | null | Conversational |
| `gym` | Cloud | 900 | Auto-generate | Only if asked | null | Action-oriented |
| `kitchen` | Cloud | 900 | Only if asked | Auto-generate | null | Food-focused |
| `sleepAnalysis` | **Local** | 160 | null | null | null | Gentle, recovery |
| `peaks` | Cloud | 900 | Only if asked | Only if asked | null | Challenge-driven |
| `myVibe` | Cloud | 600 | null | null | MUST when asked | Emotionally intelligent |

### Context Focus Summaries

| Context | focusSummary |
|---|---|
| `kitchen` | "Food, fridge logic, meal suggestions, and practical nutrition choices." |
| `gym` | "Training guidance, structured workouts, and action-first fitness coaching." |
| `sleepAnalysis` | "Sleep quality, recovery, wind-down guidance, and low-stimulus coaching." |
| `peaks` | "Momentum, discipline, measurable challenges, and level-based progression." |
| `mainChat` | "General captain coaching across health, habits, and daily execution." |
| `myVibe` | "Mood, music, focus, emotional regulation, and energy pacing." |

---

## Appendix H — Structured Response Schema

### CaptainStructuredResponse

The JSON response from Gemini must match this exact schema:

```json
{
  "message": "Captain's reply text (required, non-empty)",
  "quickReplies": ["Option 1", "Option 2", "Option 3"],
  "workoutPlan": {
    "title": "Plan title",
    "exercises": [
      {
        "name": "Exercise name",
        "sets": 3,
        "repsOrDuration": "12 reps"
      }
    ]
  },
  "mealPlan": {
    "meals": [
      {
        "type": "breakfast",
        "description": "Egg whites with veggies",
        "calories": 250
      }
    ]
  },
  "spotifyRecommendation": {
    "vibeName": "Energy Lift",
    "description": "A clean energy ramp...",
    "spotifyURI": "spotify:search:Arabic+Workout+Motivation"
  }
}
```

### Field Rules

| Field | Required | Max Length | Rules |
|---|---|---|---|
| `message` | Yes | Unlimited | Natural text. No JSON/API references. Language must match setting. |
| `quickReplies` | No | 3 items, 25 chars each | Short tappable suggestions. Same language as message. |
| `workoutPlan` | No | — | Only when user asks for training. Must have title + exercises. |
| `mealPlan` | No | — | Only when user asks for food. Must have non-empty meals array. |
| `spotifyRecommendation` | No | — | Only for music requests. Must have vibeName + description + spotifyURI. |

### Spotify URI Format

Supported formats:
- `spotify:search:<query>` — Dynamic search (preferred for personalization)
- `spotify:playlist:<id>` — Direct playlist link

Fallback recommendations (from `SpotifyRecommendation.myVibeFallback()`):
| Vibe | Playlist ID |
|---|---|
| Energy Lift | `37i9dQZF1DX76Wlfdnj7AP` |
| Deep Focus | `37i9dQZF1DWZeKCadgRdKQ` |
| Zen Mode | `37i9dQZF1DWZqd5JICZI0u` |

---

## Appendix I — LLMJSONParser

**File:** `AiQo/Features/Captain/LLMJSONParser.swift`

Robust JSON extraction from LLM output that handles common LLM quirks:

1. **Strips markdown fences** — Removes ` ```json ` and ` ``` ` wrappers
2. **Extracts JSON object** — Finds first `{` to last `}` in output
3. **Handles trailing commas** — Common LLM error
4. **Handles unescaped quotes** — Within string values
5. **Falls back to message-only** — If JSON parsing fails, uses raw text as message

---

## Appendix J — Audio Assets

### Binaural Beat / Ambient Sound Assets

Stored in `Assets.xcassets` as `.dataset` types:

| Asset Name | Purpose |
|---|---|
| `GammaFlow` | High-frequency gamma wave stimulation (40 Hz) |
| `SerotoninFlow` | Serotonin-boosting ambient (10 Hz alpha) |
| `ThetaTrance` | Deep meditation theta waves (4-8 Hz) |
| `Hypnagogic_state` | Sleep onset / hypnagogic state induction |
| `SoundOfEnergy` | Energy and alertness boost |

Managed by `VibeAudioEngine` in `Core/VibeAudioEngine.swift`.

---

## Appendix K — Watch App Detailed Architecture

### WatchWorkoutManager

**File:** `AiQoWatch Watch App/Services/WatchWorkoutManager.swift`

Manages `HKWorkoutSession` on watchOS:
- Start/stop/pause/resume workout sessions
- Real-time heart rate monitoring
- Active calorie tracking
- Distance measurement
- Workout session delegation

### WatchHealthKitManager

**File:** `AiQoWatch Watch App/Services/WatchHealthKitManager.swift`

Watch-specific HealthKit queries:
- Current heart rate
- Today's step count
- Today's active calories
- Stand hours

### WatchConnectivityService

**File:** `AiQoWatch Watch App/Services/WatchConnectivityService.swift`

Handles Watch → Phone communication:
- Workout session updates (start, pause, resume, end)
- Heart rate sample forwarding
- Workout summary data transfer
- Application context sharing

### WatchDesignSystem

**File:** `AiQoWatch Watch App/Design/WatchDesignSystem.swift`

Watch-specific design tokens adapted for small screens:
- Compact spacing values
- Watch-optimized typography
- Reduced color palette

### WatchWorkoutType

**File:** `AiQoWatch Watch App/Models/WatchWorkoutType.swift`

Supported workout types on Watch:
- Running (indoor/outdoor)
- Walking (indoor/outdoor)
- Cycling
- HIIT
- Strength Training
- Yoga
- Swimming

### Watch Views

| View | Purpose |
|---|---|
| `WatchHomeView` | Health summary dashboard (steps, calories, heart rate) |
| `WatchWorkoutListView` | Workout type selection grid |
| `WatchActiveWorkoutView` | Live workout metrics display |
| `WatchWorkoutSummaryView` | Post-workout summary with XP earned |

### Phone ↔ Watch Sync Protocol

**Shared files:** `WorkoutSyncCodec.swift`, `WorkoutSyncModels.swift`

The codec handles:
1. **Workout command encoding** — Start/stop/pause messages
2. **Heart rate sample batching** — Batched HR data transfer
3. **Summary packaging** — Workout completion data
4. **Application context** — Background state sync

---

## Appendix L — Notification System Deep Dive

### NotificationCategoryManager

Registers all notification categories with UNNotificationCenter:

| Category | Actions | Description |
|---|---|---|
| Captain Message | Reply, Dismiss | Captain Hamoudi sends a message |
| Morning Habit | Start, Snooze | Morning routine reminder |
| Sleep Reminder | Set Alarm, Dismiss | Bedtime reminder |
| Activity Nudge | Open App, Later | Inactivity re-engagement |
| Premium Expiry | Subscribe, Dismiss | Subscription about to expire |
| Angel Number | Open, Dismiss | Motivational angel number |

### NotificationIntelligenceManager

AI-driven notification scheduling:
1. Registers background tasks with BGTaskScheduler
2. Evaluates user patterns to determine optimal notification timing
3. Composes context-aware messages via `CaptainBackgroundNotificationComposer`
4. Schedules/cancels based on `AppSettingsStore.shared.notificationsEnabled`

Background task identifiers:
- `aiqo.captain.spiritual-whispers.refresh`
- `aiqo.captain.inactivity-check`

### InactivityTracker

Detects when the user hasn't opened the app:
- Tracks last active timestamp
- Triggers re-engagement notifications after threshold
- Evaluates via `CaptainSmartNotificationService.shared.evaluateInactivityAndNotifyIfNeeded()`

### MorningHabitOrchestrator

Morning routine monitoring and notification:
- Starts on app become active (post-onboarding)
- Monitors morning health metrics
- Sends Captain-style morning encouragement
- Routes notification taps to Captain chat

### SleepSessionObserver

Sleep session monitoring:
- Observes HealthKit sleep analysis samples
- Detects sleep session boundaries
- Triggers morning sleep summary
- Coordinates with Smart Wake Calculator

### ActivityNotificationEngine

Angel number motivational notifications:
- Generates localized notifications based on user gender and language
- Schedules at appropriate times
- Debug mode: prints pending notifications

---

*End of AiQo Master Blueprint v2.0*

---

**Document Statistics:**
- Total Swift files in project: 300+
- Total localized strings: 4,307 (2,153 Arabic + 2,154 English)
- External dependencies: 10 SPM packages + 1 vendored framework (SpotifyiOS)
- Build targets: 7 (iOS app, watchOS app, iOS widget, watchOS widget, 3 test targets)
- SwiftData @Model classes: 10+
- ScreenContext values: 6
- AI models used: 3 (Gemini 2.0 Flash, Gemini 3 Flash Preview, Apple Intelligence Foundation Models)
- Notification categories: 6+
- Deep link routes: 8
- Siri shortcut activities: 8
- Background task identifiers: 2
- Feature flags: 3
- API integrations: 4 (Gemini, ElevenLabs, Supabase, Spotify)
