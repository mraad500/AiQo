# AiQo Master Blueprint 4

Generated from the live codebase in:

```text
/Users/mohammedraad/Desktop/untitled folder/AiQo
```

Generation date:

```text
2026-03-31
```

Primary scope:

```text
AiQo iOS app target
AiQo watchOS companion target
AiQoWidget and AiQoWatchWidget widget targets
Configuration/*.xcconfig
AiQo.xcodeproj package and build metadata
```

Method:

- Step 1 discovery commands were executed exactly as requested.
- The raw discovery file count returned by `cat /tmp/all_swift_files.txt | wc -l` was `859`.
- The top-level directory tree was read from `find . -maxdepth 4 -type d | sort`.
- The requested architecture files were read from their live locations; when a requested path was missing, this blueprint calls that out and points to the actual implementation file.
- Every factual claim below is grounded in the current checked-in code, configuration, or project metadata reviewed during this run.

---

## SECTION 1 — App Identity & Philosophy

### Product name

- Product name in code and target naming is `AiQo`.
- The main target folder is `AiQo`.
- The Xcode project file is `AiQo.xcodeproj`.
- The watch target is named `AiQoWatch Watch App`.
- The widget target is named `AiQoWidget`.
- The watch widget target is named `AiQoWatchWidget`.
- No separate code-level marketing rename was found.

### Tagline

- No single canonical tagline constant or marketing headline was found in the app source.
- `Inference:` the product positions itself as an Arabic-first personal wellness operating system because the feature set combines health, recovery, gym guidance, food planning, tribe competition, and an Iraqi-Arabic AI coach.
- This inference is based on:
  - the Captain Hamoudi persona files,
  - the Arabic-first localization footprint,
  - the health and lifestyle feature modules,
  - the wellness-oriented notification and background services.

### Target users

- `Inference:` the app is aimed at Arabic-speaking iPhone users who want an integrated health, fitness, recovery, and motivation system.
- Evidence for Arabic-first users:
  - Iraqi-Arabic system-prompt rules in `AiQo/Features/Captain/CaptainPromptBuilder.swift`.
  - Arabic copy and localizations in `AiQo/Resources/ar.lproj/Localizable.strings`.
  - RTL enforcement in the main tab shell and several UI components.
- Evidence for wellness and performance users:
  - Gym module under `AiQo/Features/Gym`.
  - Kitchen and nutrition module under `AiQo/Features/Kitchen`.
  - Sleep analysis logic in Captain and HealthKit services.
  - Streaks, levels, quests, and tribe challenges.
- Evidence for premium / subscription users:
  - StoreKit 2 purchase flow.
  - Free trial state management.
  - gated access logic in `AccessManager`.

### Core principles visible in code

- Privacy-first:
  - `PrivacySanitizer` strips personal identifiers before cloud calls.
  - HealthKit data is aggregated before use in cloud prompts.
  - Captain memory has a cloud-safe export path that only exposes selected categories.
  - Legal/privacy strings state health data is stored locally and AI processing is not permanently stored.
- Arabic-first:
  - Captain Arabic prompt path explicitly forces Iraqi Baghdadi dialect.
  - Main tab UI is forced into RTL layout.
  - Arabic localization files are first-class resources.
- Circadian-aware:
  - `CaptainContextBuilder` computes a `BioTimePhase`.
  - tone shifts based on hour, sleep deprivation, and late-night activity.
  - sleep, wake, and recovery services influence notifications and Captain tone.
- Zero digital pollution:
  - `Inference:` this exact phrase is not a code constant, but the implementation shows a bias toward concise replies, few actionable points, calm notification timing, and privacy-preserving on-device processing.
  - Captain prompt rules explicitly ban rambling and generic filler.
- Companion-coach model:
  - Captain is implemented as an older-brother Iraqi coach rather than a generic chatbot.
  - The app routes users into guidance by context rather than a single monolithic chat surface.

### Persona identity

- Captain identity is `Captain Hamoudi`.
- The Arabic identity block says:
  - he is an Iraqi coach,
  - he speaks only Iraqi colloquial Arabic,
  - he acts like an older brother,
  - he should avoid fusha and generic AI language.
- English mode exists, but Arabic mode is the opinionated default experience.

### Supported languages

- The project contains:
  - `AiQo/Resources/ar.lproj`
  - `AiQo/Resources/en.lproj`
- `LocalizationManager` persists and reapplies the saved app language.
- `LanguageSelectionView` is part of the first-run flow.
- `CaptainViewModel` supports `AppLanguage`.
- `CaptainPromptBuilder` has separate Arabic and English identity paths.

### RTL strategy

- `MainTabScreen` applies:

```swift
.environment(\.layoutDirection, .rightToLeft)
```

- `AiQoCard` contains layout-direction-aware visual-leading behavior.
- Multiple Arabic-first screens use RTL intentionally rather than relying only on localization files.
- `Inference:` the app treats RTL as a primary interaction mode, not as a retrofit.

### App Store category

- No App Store category is encoded in the checked-in source.
- App Store category is typically set in App Store Connect, not in Swift code or `Info.plist`.
- `Inference:` the most likely category would be Health & Fitness, but the codebase itself does not prove the App Store Connect setting.

### Target OS / deployment target

- The Xcode project file contains multiple `IPHONEOS_DEPLOYMENT_TARGET` entries.
- The active iPhone target values visible in `AiQo.xcodeproj/project.pbxproj` are `26.1` and `26.2`.
- `SWIFT_VERSION` is `5.0`.
- `MARKETING_VERSION` is `1.0`.
- `CURRENT_PROJECT_VERSION` is `1`.
- `Inference:` the project is currently aligned to a very new Xcode/iOS toolchain because it imports `FoundationModels` and sets deployment targets in the iOS 26 generation.

### Source evidence

- `AiQo/Features/Captain/CaptainPromptBuilder.swift`
- `AiQo/Features/Captain/CaptainContextBuilder.swift`
- `AiQo/Core/Localization/LocalizationManager.swift`
- `AiQo/App/LanguageSelectionView.swift`
- `AiQo/App/MainTabScreen.swift`
- `AiQo/Resources/ar.lproj/Localizable.strings`
- `AiQo/Resources/en.lproj/Localizable.strings`
- `AiQo.xcodeproj/project.pbxproj`

---

## SECTION 2 — Tech Stack & Dependencies

### Language and UI stack

- Primary language: Swift.
- Main UI framework: SwiftUI.
- State management patterns used:
  - `ObservableObject`
  - `@StateObject`
  - `@ObservedObject`
  - `@Published`
  - `@AppStorage`
  - `NotificationCenter` bridging
- Persistence stack:
  - SwiftData
  - `ModelContainer`
  - `ModelContext`
- Imperative UIKit appears in a few bridge surfaces:
  - login and auth presentation,
  - tab bar appearance,
  - camera preview / blur / UIKit wrappers,
  - some legacy feature views.

### Swift version

- `SWIFT_VERSION = 5.0` is declared repeatedly in `AiQo.xcodeproj/project.pbxproj`.
- The project also relies on new Apple SDK frameworks such as `FoundationModels`, so practical compiler/toolchain reality is newer than the raw `SWIFT_VERSION` build setting string suggests.

### Minimum iOS

- Project file values show `IPHONEOS_DEPLOYMENT_TARGET = 26.1` and `26.2`.
- The app code also uses availability checks such as `if #available(iOS 18.0, *)` in UI shells.
- `Inference:` the codebase is being developed against a future-facing Apple SDK and is not targeting older iOS releases.

### Package manager footprint

- Swift Package Manager is in use.
- Resolved packages are declared in:

```text
AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

### Exact SPM dependencies from `Package.resolved`

- `SDWebImage` `5.21.6`
- `SDWebImageSwiftUI` `3.1.4`
- `supabase-swift` `2.36.0`
- `swift-asn1` `1.5.0`
- `swift-clocks` `1.0.6`
- `swift-concurrency-extras` `1.3.2`
- `swift-crypto` `4.2.0`
- `swift-http-types` `1.4.0`
- `swift-system` `1.6.4`
- `xctest-dynamic-overlay` `1.7.0`

### Package declarations visible in the project file

- `https://github.com/supabase-community/supabase-swift`
- `https://github.com/apple/swift-system.git`
- `https://github.com/SDWebImage/SDWebImageSwiftUI`

### Embedded / binary dependencies

- The project embeds:

```text
AiQo/Frameworks/SpotifyiOS.framework
```

- Spotify is integrated as a prebuilt framework, not as an SPM package.

### External APIs actually used in code today

- Google Gemini:
  - `CloudBrainService` calls Google Generative Language API.
  - model string is `gemini-flash-latest`.
  - additional prompt-related Gemini usage appears in memory extraction and spiritual whispers.
- ElevenLabs:
  - Captain voice synthesis uses ElevenLabs text-to-speech.
  - output format is `mp3_44100_128`.
- Supabase:
  - auth,
  - profile storage,
  - arena / tribe backend calls,
  - edge function receipt validation.
- Spotify:
  - Spotify App Remote framework is embedded.
  - `SpotifyVibeManager` handles music/vibe integration.

### External APIs named in the user prompt but not found as live code integrations

- OpenAI:
  - No active OpenAI SDK or REST integration was found in the current source tree.
  - No `OpenAI`, `openai`, `GPT`, `Assistants`, or `Responses API` client implementation exists in the live code.
  - Some naming strings such as `arabicGPT` or prompt copy mentioning OpenAI exist, but they do not represent a wired runtime integration.
- `File not found — needs to be created` would apply to an actual OpenAI service layer because no such implementation exists today.

### Apple frameworks used in code

- `SwiftUI`
- `SwiftData`
- `UIKit`
- `Foundation`
- `Combine`
- `HealthKit`
- `FoundationModels`
- `StoreKit`
- `WatchConnectivity`
- `WidgetKit`
- `ActivityKit`
- `AlarmKit`
- `BackgroundTasks`
- `AppIntents`
- `AuthenticationServices`
- `FamilyControls`
- `DeviceActivity`
- `ManagedSettings`
- `Vision`
- `CoreSpotlight`
- `Intents`
- `AVFoundation`
- `MediaPlayer`
- `CryptoKit`
- `UserNotifications`
- `os`

### Frameworks explicitly not found in imports

- `CoreML` was not found in project imports.
- `ManagedSettingsUI` was not found in project imports.
- `CoreData` was not found in project imports.
- `Inference:` the app currently uses Vision for camera/coach assistance but not CoreML as a visible top-level dependency.

### Health / AI / audio / commerce clusters

- Health cluster:
  - `HealthKit`
  - `WidgetKit`
  - `WatchConnectivity`
- AI cluster:
  - `FoundationModels`
  - Gemini HTTP calls
  - privacy sanitizer
  - prompt builders
- Audio / voice cluster:
  - `AVFoundation`
  - `MediaPlayer`
  - ElevenLabs
  - Spotify
- Commerce cluster:
  - `StoreKit`
  - receipt edge function via Supabase

### Build configuration notes

- `Configuration/AiQo.xcconfig` disables explicit modules:
  - `CLANG_ENABLE_EXPLICIT_MODULES = NO`
  - `SWIFT_ENABLE_EXPLICIT_MODULES = NO`
- The file comment says this is a workaround for `SDWebImageSwiftUI`.

### Secrets / config handling

- `Configuration/AiQo.xcconfig` includes `Secrets.xcconfig`.
- `Secrets.xcconfig` contains live-looking service credentials.
- This is operationally important but also a security risk.
- The source comments say the file is gitignored and local-only, but the repository contains it today.
- The blueprint intentionally does not reproduce those secrets.

### Source evidence

- `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `AiQo.xcodeproj/project.pbxproj`
- `Configuration/AiQo.xcconfig`
- `Configuration/Secrets.xcconfig`
- `AiQo/Core/SpotifyVibeManager.swift`
- `AiQo/Core/CaptainVoiceAPI.swift`
- `AiQo/Features/Captain/CloudBrainService.swift`
- `AiQo/Services/SupabaseService.swift`
- `AiQo/Services/SupabaseArenaService.swift`

---

## SECTION 3 — Project File Structure

### Top-level structure

- Main app code lives in `AiQo/`.
- Xcode project metadata lives in `AiQo.xcodeproj/`.
- App configuration lives in `Configuration/`.
- iOS tests live in `AiQoTests/`.
- UI tests live in `AiQoUITests/`.
- watchOS app code lives in `AiQoWatch Watch App/`.
- watch tests live in:
  - `AiQoWatch Watch AppTests/`
  - `AiQoWatch Watch AppUITests/`
- widgets live in:
  - `AiQoWidget/`
  - `AiQoWatchWidget/`

### Important top-level app directories

- `AiQo/App`
- `AiQo/Core`
- `AiQo/DesignSystem`
- `AiQo/Features`
- `AiQo/Premium`
- `AiQo/Resources`
- `AiQo/Services`
- `AiQo/Shared`
- `AiQo/Tribe`
- `AiQo/UI`
- `AiQo/watch`

### App sub-areas by responsibility

- `App`:
  - app entry,
  - root flow,
  - login,
  - language selection,
  - profile setup,
  - main tab shell.
- `Core`:
  - shared stores,
  - user profile,
  - voice,
  - localization,
  - settings,
  - smart notifications,
  - streaks,
  - Spotify,
  - memory.
- `DesignSystem`:
  - tokens,
  - colors,
  - cards,
  - CTA,
  - modifiers,
  - UI primitives.
- `Features`:
  - Captain,
  - Gym,
  - Home,
  - Kitchen,
  - LegendaryChallenges,
  - MyVibe,
  - Onboarding,
  - Profile,
  - ProgressPhotos,
  - Tribe,
  - WeeklyReport,
  - DataExport.
- `Premium`:
  - entitlement access logic,
  - free trial state,
  - premium store / paywall surfaces.
- `Services`:
  - deep links,
  - analytics,
  - crash reporting,
  - notifications,
  - network monitor,
  - permissions,
  - Supabase access.
- `Shared`:
  - health kit manager,
  - level helper,
  - workout sync codec.
- `Tribe`:
  - tribe-specific models,
  - stores,
  - repositories,
  - galaxy / arena UI,
  - preview data.
- `UI`:
  - general reusable app UI not placed in `DesignSystem`.

### Naming conventions

- Feature folders use domain nouns:
  - `Captain`
  - `Gym`
  - `Kitchen`
  - `Home`
  - `Profile`
- Some older UIKit-style names still end with `ViewController.swift` even when the type is a SwiftUI `View`.
- Some files are named by role:
  - `Manager`
  - `Store`
  - `Service`
  - `Router`
  - `Screen`
  - `ViewModel`
- Domain models are spread across:
  - `Core/Models`
  - feature folders,
  - `Tribe/Models`,
  - SwiftData model files.

### File organization strategy

- The codebase is feature-oriented at the top level but not purely feature-sliced.
- Shared concerns are centralized into `Core`, `Services`, `Shared`, and `UI`.
- Tribe/Arena is large enough to exist both under `Features/Tribe` and top-level `Tribe`.
- `Inference:` this codebase grew iteratively rather than from a single strict architecture template.

### Notable structure mismatches vs the requested read list

- `AiQo/App/AiQoApp.swift`
  - File not found — actual `@main` app entry lives in `AiQo/App/AppDelegate.swift`.
- `AiQo/App/AppFlowController.swift`
  - File not found — actual `AppFlowController` lives inside `AiQo/App/SceneDelegate.swift`.
- `AiQo/Services/AI/*.swift`
  - File not found — actual AI service files live in `AiQo/Features/Captain`.
- `AiQo/Services/Monetization/PurchaseManager.swift`
  - File not found — actual file is `AiQo/Core/Purchases/PurchaseManager.swift`.
- `AiQo/Services/Monetization/FreeTrialManager.swift`
  - File not found — actual file is `AiQo/Premium/FreeTrialManager.swift`.
- `AiQo/Models/*.swift`
  - File not found — model files live across `AiQo/Core`, `AiQo/Features`, and `AiQo/Tribe`.
- `AiQo/Data/*.swift`
  - File not found — there is no top-level `Data` folder in the live source.
- `AiQo/Features/Sleep/*.swift`
  - File not found — sleep logic is distributed across Home, Captain, HealthKit, and Notifications.
- `AiQo/Features/Arena/*.swift`
  - File not found — arena lives under `AiQo/Tribe/Galaxy` and `AiQo/Tribe/Arena`.
- `AiQo/Features/Settings/*.swift`
  - File not found — settings UI lives in `AiQo/Core/AppSettingsScreen.swift`.
- `AiQoWatch/*.swift`
  - File not found — watch companion files live under `AiQoWatch Watch App/`.

### Example file grouping by functional lane

- App shell:
  - `AiQo/App/AppDelegate.swift`
  - `AiQo/App/SceneDelegate.swift`
  - `AiQo/App/MainTabRouter.swift`
  - `AiQo/App/MainTabScreen.swift`
  - `AiQo/App/AppRootManager.swift`
- Captain AI:
  - `AiQo/Features/Captain/BrainOrchestrator.swift`
  - `AiQo/Features/Captain/CloudBrainService.swift`
  - `AiQo/Features/Captain/LocalBrainService.swift`
  - `AiQo/Features/Captain/PrivacySanitizer.swift`
  - `AiQo/Features/Captain/CaptainViewModel.swift`
- Persistence:
  - `AiQo/Core/CaptainMemory.swift`
  - `AiQo/Core/MemoryStore.swift`
  - `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift`
  - `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift`
- Commerce:
  - `AiQo/Core/Purchases/PurchaseManager.swift`
  - `AiQo/Core/Purchases/ReceiptValidator.swift`
  - `AiQo/Premium/FreeTrialManager.swift`
  - `AiQo/Premium/AccessManager.swift`
- Backend:
  - `AiQo/Services/SupabaseService.swift`
  - `AiQo/Services/SupabaseArenaService.swift`
  - `AiQo/Tribe/Repositories/TribeRepositories.swift`

### Source evidence

- `find AiQo -maxdepth 4 -type d | sort`
- `find AiQo -maxdepth 4 -type f | sort`
- `find AiQo AiQoWatch Watch App AiQoWidget AiQoWatchWidget Configuration -type f ...`

---

## SECTION 4 — App Entry, Boot Sequence & Navigation

### Requested file mismatch

- `AiQo/App/AiQoApp.swift`
  - File not found — actual `AiQoApp` is declared in `AiQo/App/AppDelegate.swift`.
- `AiQo/App/AppFlowController.swift`
  - File not found — actual `AppFlowController` is declared in `AiQo/App/SceneDelegate.swift`.

### `@main` entry point

- The app entry type is:

```swift
@main
struct AiQoApp: App
```

- It lives in:

```text
AiQo/App/AppDelegate.swift
```

### `AiQoApp.init()` boot work

- Configures `MemoryStore.shared`.
- Configures `RecordProjectManager.shared`.
- Removes stale memories.
- If legacy calculation was already completed:
  - syncs HealthKit-derived metrics into memory.
- Sets up a dedicated Captain model container.

### SwiftData container setup at app entry

- `captainContainer` is created manually in `AiQoApp`.
- The model list in that container is:
  - `CaptainMemory`
  - `PersistentChatMessage`
  - `RecordProject`
  - `WeeklyLog`
- Store URL is:

```text
Application Support/captain_memory.store
```

- If the store fails, the code falls back to an in-memory configuration.

### Main app scene container

- `AiQoApp` also attaches a scene-wide `.modelContainer(for:)`.
- The scene-wide container includes:
  - `AiQoDailyRecord`
  - `WorkoutTask`
  - `ArenaTribe`
  - `ArenaTribeMember`
  - `ArenaWeeklyChallenge`
  - `ArenaTribeParticipation`
  - `ArenaEmirateLeaders`
  - `ArenaHallOfFameEntry`

### Additional quest persistence container

- `AppRootView` also applies:

```swift
.modelContainer(QuestPersistenceController.shared.container)
```

- This means the app has more than one SwiftData persistence lane in practice.
- The user requested exactly two SwiftData containers, but the live code shows:
  - a Captain container,
  - a scene-wide app container,
  - a quest persistence controller container.

### `UIApplicationDelegateAdaptor`

- `AiQoApp` uses `@UIApplicationDelegateAdaptor`.
- `AppDelegate` is the entry point for push, background tasks, notifications, crash setup, trial refresh, and service startup.

### `AppDelegate.didFinishLaunchingWithOptions` boot sequence

- `CrashReportingService.shared.configure()`
- If logged in:
  - bind Crashlytics user identity via Supabase user id.
- Initialize `PhoneConnectivityManager.shared`.
- Set `UNUserNotificationCenter.current().delegate`.
- Initialize local crash and connectivity helpers:
  - `CrashReporter.shared`
  - `NetworkMonitor.shared`
- Track analytics event `.appLaunched`.
- Refresh free trial state.
- Apply saved language.
- Register notification categories.
- Register background tasks through `NotificationIntelligenceManager`.
- Start purchase observation asynchronously.
- If onboarding is already complete:
  - enable HealthKit permission flow,
  - request notification permissions,
  - register for remote notifications,
  - start `MorningHabitOrchestrator`,
  - start `SleepSessionObserver`,
  - start `AIWorkoutSummaryService`,
  - if notifications are enabled:
    - schedule angel notifications,
    - schedule background tasks,
    - schedule smart notifications.
- Update app shortcut parameters if iOS supports it.
- Donate Siri shortcuts.
- Check streak continuity.

### `applicationDidBecomeActive`

- Tracks `.appBecameActive`.
- Refreshes phone/watch context.
- Reloads widgets.
- Clears app icon badge number.
- Restarts key background intelligence if onboarding is complete.
- Evaluates pending Captain deep-link notification routing.

### `AppFlowController`

- `AppFlowController` is inside `AiQo/App/SceneDelegate.swift`.
- It is an `ObservableObject`.
- It owns the root-screen resolution logic.

### `RootScreen` cases

- `.languageSelection`
- `.login`
- `.profileSetup`
- `.legacy`
- `.featureIntro`
- `.main`

### Root-screen resolution logic

- The flow controller resolves route order based on first-run flags and auth state.
- Resolution order is:
  - language selection,
  - login,
  - profile setup,
  - legacy calculation,
  - feature intro,
  - main app.
- A completed onboarding state can still allow entry to the main app even if a Supabase session is no longer fresh.

### Onboarding completion flags used by the root state machine

- `didSelectLanguage`
- `didShowFirstAuthScreen`
- `didCompleteDatingProfile`
- `didCompleteLegacyCalculation`
- `didCompleteFeatureIntro`

### Legacy calculation handoff

- `finishOnboardingRequestingPermissions()`:
  - enables HealthKit permission flow,
  - requests HealthKit authorization,
  - requests notification authorization,
  - requests `ProtectionModel` authorization,
  - starts remote notifications,
  - starts morning habit orchestration,
  - starts sleep session observer,
  - starts AI workout summaries.

### Final onboarding completion

- `finalizeOnboarding()`:
  - sets `didCompleteLegacyCalculation`,
  - starts the free trial if needed,
  - transitions into `.featureIntro`.
- `didCompleteFeatureIntro()`:
  - sets `didCompleteFeatureIntro`,
  - navigates to `.home`,
  - transitions into `.main`.

### Main tab router

- `MainTabRouter.Tab` declares:
  - `.home`
  - `.gym`
  - `.captain`

### Main tab rendering

- `MainTabScreen` renders the same three destinations:
  - home
  - gym
  - captain
- The current router and rendered `TabView` are aligned.
- `kitchen` is not a tab in the live enum.
- `openKitchen()` is a special-case route that:
  - switches to `.home`,
  - posts `Notification.Name.openKitchenFromHome`.

### `AppRootManager`

- `AppRootManager.shared` currently stores cross-tab presentation state.
- The main published flag is:
  - `isCaptainChatPresented`
- This is used to push from `CaptainScreen` into `CaptainChatView`.

### Deep-link router

- Implemented in `AiQo/Services/DeepLinkRouter.swift`.
- Supported deep links:
  - `.home`
  - `.captain`
  - `.gym`
  - `.kitchen`
  - `.settings`
  - `.referral(code: String)`
  - `.premium`
- No live `.tribe` deep-link case exists in the current router.

### Supported URL shapes

- Custom scheme:

```text
aiqo://...
```

- Spotify callback scheme:

```text
aiqo-spotify://...
```

- Universal links are parsed for:
  - `/captain` and `/chat`
  - `/gym`
  - `/kitchen`
  - `/settings`
  - `/refer/<code>` and `/referral/<code>`
  - `/premium`
- No live universal-link tribe join parser exists in the current router.

### `NSUserActivityTypes`

- `com.aiqo.startWalk`
- `com.aiqo.startRun`
- `com.aiqo.startHIIT`
- `com.aiqo.openCaptain`
- `com.aiqo.todaySummary`
- `com.aiqo.logWater`
- `com.aiqo.openKitchen`
- `com.aiqo.weeklyReport`

### Source evidence

- `AiQo/App/AppDelegate.swift`
- `AiQo/App/SceneDelegate.swift`
- `AiQo/App/MainTabRouter.swift`
- `AiQo/App/MainTabScreen.swift`
- `AiQo/App/AppRootManager.swift`
- `AiQo/Services/DeepLinkRouter.swift`
- `AiQo/Info.plist`

---

## SECTION 5 — Hybrid AI Brain (BrainOrchestrator)

### Requested file-path mismatch

- `AiQo/Services/AI/BrainOrchestrator.swift`
  - File not found — actual file is `AiQo/Features/Captain/BrainOrchestrator.swift`.
- The same is true for:
  - `CloudBrainService.swift`
  - `LocalBrainService.swift`
  - `HybridBrainService.swift`
  - `PrivacySanitizer.swift`
  - `CaptainOnDeviceChatEngine.swift`
  - `AppleIntelligenceSleepAgent.swift`

### Core orchestration components

- `BrainOrchestrator`
- `HybridBrainService`
- `CloudBrainService`
- `LocalBrainService`
- `PrivacySanitizer`
- `CaptainOnDeviceChatEngine`
- `AppleIntelligenceSleepAgent`
- `CaptainFallbackPolicy`
- `CaptainContextBuilder`

### Screen-context enum

- `ScreenContext` cases:
  - `kitchen`
  - `gym`
  - `sleepAnalysis`
  - `peaks`
  - `mainChat`
  - `myVibe`

### Routing table

- `sleepAnalysis`:
  - routed to local first.
- `gym`:
  - routed to cloud.
- `kitchen`:
  - routed to cloud.
- `peaks`:
  - routed to cloud.
- `myVibe`:
  - routed to cloud.
- `mainChat`:
  - routed to cloud.

### Routing policy summary

- The system prefers cloud for rich general-purpose coaching and structured plan generation.
- The system prefers local for sleep analysis and on-device fallbacks.
- `Inference:` this architecture treats sleep as the most privacy- and latency-sensitive AI lane.

### Sleep intent interception

- If the user is chatting in a general surface but the intent looks like sleep-data analysis, the orchestrator can reroute the request into `.sleepAnalysis`.
- This allows sleep-specific fallback logic and Apple Intelligence handling to apply.

### `HybridBrainRequest` schema

- `conversation`
- `screenContext`
- `language`
- `contextData`
- `userProfileSummary`
- `attachedImageData`

### `HybridBrainServiceReply` schema

- `message`
- `quickReplies`
- `workoutPlan`
- `mealPlan`
- `spotifyRecommendation`
- `rawText`

### `CloudBrainService`

- Uses Google Gemini REST calls.
- Base endpoint:

```text
https://generativelanguage.googleapis.com/v1beta/models
```

- Current model:

```text
gemini-flash-latest
```

- Request path pattern:

```text
<base>/<model>:generateContent
```

- API key source:

```text
CAPTAIN_API_KEY
```

### Cloud generation tuning

- `mainChat` max tokens:
  - `600`
- `myVibe` max tokens:
  - `600`
- `sleepAnalysis` max tokens:
  - `600`
- `gym` max tokens:
  - `900`
- `kitchen` max tokens:
  - `900`
- `peaks` max tokens:
  - `900`
- temperature:
  - `0.7`

### `LocalBrainService`

- Handles local-only or local-first routes.
- Supports on-device sleep analysis.
- Supports background-notification prompt generation.
- Includes structured rule-based fallbacks when model access fails.
- Uses the on-device chat engine with timeout constraints.

### `CaptainOnDeviceChatEngine`

- Uses `FoundationModels`.
- Availability is guarded by platform availability.
- Builds prompts that include live HealthKit context.
- Uses on-device generation for Captain-style chat where possible.
- Operates with short timeout protection to avoid hanging the UI.

### `AppleIntelligenceSleepAgent`

- Uses `FoundationModels`.
- Generates short sleep analysis.
- Response cap is approximately `160` tokens.
- Output goal:
  - Iraqi tone,
  - three-sentence analysis,
  - recovery-oriented guidance.
- Throws `modelUnavailable` if the local model path is not accessible.

### `PrivacySanitizer` goals

- Strip direct personal identifiers.
- Reduce exactness of health metrics before cloud exposure.
- Keep enough semantic context for useful AI responses.
- Remove metadata from images before upload.

### PII removed or redacted

- emails
- phone numbers
- UUIDs
- `@mentions`
- URLs
- long numeric sequences
- IP addresses
- long base64-like tokens

### Profile masking

- Known user name values are replaced with `"User"` in sanitized cloud context.

### Health / context bucketing

- steps are bucketed by `50`
- calories are bucketed by `10`
- level is clamped between `1` and `100`
- vibe is replaced with `"General"` for cloud-safe context

### Image sanitization

- Kitchen images are transformed before cloud use.
- Images are re-encoded as JPEG.
- Max dimension is `1280`.
- JPEG quality is `0.78`.
- EXIF / GPS metadata is stripped by the re-encode path.

### Prompt generation chain

- `CaptainContextBuilder` builds contextual health and tone data.
- `CaptainPromptBuilder` builds the six-layer prompt.
- `CloudBrainService` or `LocalBrainService` runs the request.
- `LLMJSONParser` parses structured responses.
- `CaptainViewModel` validates and presents the reply.

### Fallback chain for normal cloud routes

- Route to cloud.
- If cloud fails:
  - decide whether failure is network / recoverable.
- Attempt local fallback when appropriate.
- If local fallback also fails:
  - emit a network-safe / fallback-safe reply.

### Fallback chain for sleep routes

- Attempt `AppleIntelligenceSleepAgent`.
- If unavailable or empty:
  - attempt cloud sleep fallback using aggregated summary only.
- If cloud sleep fallback fails:
  - compute a local rule-based sleep response.

### Structured plan outputs

- `workoutPlan` is primarily populated in gym / peaks contexts.
- `mealPlan` is primarily populated in kitchen context.
- `spotifyRecommendation` can be returned in `myVibe`.

### Important truth about current cloud provider

- The live cloud brain is Gemini-based.
- It is not OpenAI-based today.
- Any architecture statement claiming OpenAI as the active production cloud brain would be inaccurate for the current source snapshot.

### Source evidence

- `AiQo/Features/Captain/BrainOrchestrator.swift`
- `AiQo/Features/Captain/CloudBrainService.swift`
- `AiQo/Features/Captain/LocalBrainService.swift`
- `AiQo/Features/Captain/HybridBrainService.swift`
- `AiQo/Features/Captain/PrivacySanitizer.swift`
- `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift`
- `AiQo/Features/Captain/AppleIntelligenceSleepAgent.swift`
- `AiQo/Features/Captain/ScreenContext.swift`

---

## SECTION 6 — Captain Hamoudi Persona System

### Identity

- Captain name: `Captain Hamoudi`.
- Role: older-brother-style Iraqi coach.
- App position: internal mentor / guide / conversational coach.
- Arabic prompt identity explicitly says:
  - Iraqi,
  - warm,
  - smart,
  - colloquial,
  - not formal Arabic,
  - not generic AI.

### Tone

- The prompt forbids generic AI disclaimers.
- The prompt forbids formulaic assistant language.
- The prompt tells Captain to:
  - respond to user intent first,
  - not open with stats,
  - stay concise,
  - prefer specific action over vague wellness language,
  - use humor only if it feels natural.

### Dialect

- Arabic mode is locked to Iraqi Baghdadi colloquial.
- Prompt rules explicitly reject:
  - fusha,
  - Google-translate-style phrasing,
  - corporate wellness wording.

### Language lock

- English mode:
  - English only,
  - no Arabic leakage.
- Arabic mode:
  - Iraqi Arabic only,
  - feature names may remain in English:
    - `My Vibe`
    - `Zone 2`
    - `Alchemy Kitchen`
    - `Arena`
    - `Tribe`

### Prompt architecture

- `CaptainPromptBuilder` explicitly documents six layers.

### Layer 1 — Identity

- Defines the Captain persona.
- Enforces the language lock.
- Defines behavioral rules.
- Lists banned phrases.
- Defines response-length rules.
- Optionally adds personalized first-name usage rules.

### Layer 2 — Memory

- Injects long-term remembered context.
- Uses the profile summary built by the view model.
- Tells the model not to recite memories unless relevant.

### Layer 3 — Bio-state

- Injects current metrics for calibration only.
- Includes:
  - steps,
  - active calories,
  - user level,
  - sleep hours when available,
  - heart rate when available,
  - time of day,
  - growth progress.
- Explicitly says not to expose internal variable names or exact numbers unless the user asks.

### Layer 4 — Circadian tone

- Injects tone guidance based on `BioTimePhase`.
- Explicitly forbids saying words such as:
  - `phase`
  - `bio-phase`
  - `circadian`

### Layer 5 — Screen context

- Injects current in-app context.
- Changes response style for:
  - main chat,
  - gym,
  - kitchen,
  - sleep,
  - peaks,
  - my vibe.
- Special-cases attached images in kitchen context.

### Layer 6 — Output contract

- Enforces structured JSON output.
- Guides which structured fields should or should not be populated based on screen context.

### Circadian phases

- `awakening`
  - `05:00–09:59`
- `energy`
  - `10:00–13:59`
- `focus`
  - `14:00–17:59`
- `recovery`
  - `18:00–20:59`
- `zen`
  - `21:00–04:59`

### Circadian override rules

- Poor sleep:
  - if sleep hours are greater than `0` and below `5.5`,
  - and time is between `05:00` and `09:59`,
  - phase becomes `recovery`.
- High late-night activity:
  - if hour is `>= 21`,
  - and steps exceed `8,000`,
  - phase becomes `recovery`.

### Circadian tone labels

- `awakening`
  - gentle, clear, optimistic.
- `energy`
  - sharp, direct, high-output.
- `focus`
  - steady, precise, minimal.
- `recovery`
  - warm, calm, encouraging.
- `zen`
  - soft, philosophical, minimal.

### Custom user tone options

- `CaptainTone.practical`
  - Arabic raw value: `عملي`
- `CaptainTone.caring`
  - Arabic raw value: `حنون`
- `CaptainTone.strict`
  - Arabic raw value: `صارم`

### Personalization fields stored for Captain customization

- `name`
- `age`
- `height`
- `weight`
- `calling`
- `tone`

### Long-term memory system

- Core storage is `CaptainMemory`.
- Manager/store is `MemoryStore`.
- Extraction is split across:
  - rule-based extraction,
  - periodic Gemini extraction.
- Memory categories used in cloud-safe context are:
  - `goal`
  - `preference`
  - `mood`
  - `injury`
  - `nutrition`
  - `insight`

### Memory items stored by extraction logic

- `user_name`
- `goal`
- `weight`
- `height`
- `age`
- `injury`
- `mood`
- `preferred_workout`
- `diet_preference`
- `sleep_hours`
- `fitness_level`
- `workout_feedback`
- `available_equipment`
- `training_days`
- `medical_condition`
- `water_intake`
- `record_project_feedback`

### Memory retention behavior

- Max stored memories: `200`.
- Stale low-confidence memories older than `90` days can be removed.
- The `active_record_project` style context is preserved more aggressively.
- Rule-based extraction runs per message.
- LLM memory extraction runs every three messages.

### Chat persistence model

- `PersistentChatMessage` stores:
  - message id,
  - text,
  - user/assistant role,
  - timestamp,
  - serialized Spotify recommendation data,
  - session id.
- Captain starts a fresh session on cold launch.
- It does not automatically reopen the prior session transcript.

### Message-window policy

- Max in-memory messages:
  - `80`
- Max messages sent to the model:
  - last `20`
- General timeout:
  - `15s`
- Sleep timeout:
  - `25s`

### Profile summary inputs used by Captain

- preferred name
- profile name
- username
- age
- height
- weight
- preferred tone
- memory context
- active record-project context

### Response validation behavior

- The view model validates model output.
- It tries to reduce:
  - duplicated content,
  - accidental English spillover in Arabic mode,
  - malformed structured payloads.

### ElevenLabs voice configuration

- API URL default:

```text
https://api.elevenlabs.io/v1/text-to-speech
```

- model:

```text
eleven_multilingual_v2
```

- output:

```text
mp3_44100_128
```

- stability:
  - `0.34`
- similarity boost:
  - `0.88`
- style:
  - `0.18`
- speaker boost:
  - `true`

### Voice cache strategy

- Cache directory:

```text
Documents/HamoudiVoiceCache
```

- Filenames are SHA256-based.
- Common phrases are pre-cached.
- Cached phrase families:
  - movement,
  - water,
  - food,
  - sleep,
  - motivation.

### Pre-cached phrases visible in code

- `يلا قوم تحرّك شوية`
- `تمرين قوي، أحسنت يا بطل`
- `كمّل كمّل لا توقف`
- `باقيلك شوية، لا تستسلم`
- `شربت ماي؟ يلا اشرب كوب`
- `خلّصت هدف الماي، تمام`
- `وقت الفطور، خل ناكل صحّي`
- `وقت الغداء`
- `وقت العشاء`
- `يلا نام بدري اليوم، جسمك يحتاج راحة`
- `صباح الخير، يلا نبدأ يومنا`
- `كل يوم أحسن من اللي قبله، كمّل`
- `سلسلة قوية، لا تكطعها`

### Voice pre-cache trigger

- `CaptainVoiceService.preCacheVoices()` calls `voiceCache.preCacheAllPhrases()`.
- Code comment says this is intended for Wi‑Fi / post-login warm-up behavior.

### TTS fallback chain

- Use cached ElevenLabs audio if phrase match exists.
- Else request live ElevenLabs synthesis.
- Else use native `AVSpeechSynthesizer`.

### Native TTS tuning

- Arabic speech rate:
  - `0.44`
- English speech rate:
  - `0.48`
- pitch multiplier:
  - `0.96`

### Source evidence

- `AiQo/Features/Captain/CaptainPromptBuilder.swift`
- `AiQo/Features/Captain/CaptainContextBuilder.swift`
- `AiQo/Features/Captain/CaptainScreen.swift`
- `AiQo/Features/Captain/CaptainViewModel.swift`
- `AiQo/Core/MemoryStore.swift`
- `AiQo/Core/MemoryExtractor.swift`
- `AiQo/Core/CaptainVoiceAPI.swift`
- `AiQo/Core/CaptainVoiceCache.swift`
- `AiQo/Core/CaptainVoiceService.swift`

---

## SECTION 7 — Data Models & Persistence

### Requested folder mismatch

- `AiQo/Models/*.swift`
  - File not found — model files are distributed across `AiQo/Core`, `AiQo/Features`, `AiQo/Tribe`, and quest/legendary subfolders.
- `AiQo/Data/*.swift`
  - File not found — there is no top-level `Data` folder in the current app.

### SwiftData model containers visible in live code

- Captain container in `AiQoApp`.
- Scene-wide app container in `AiQoApp`.
- Quest persistence container via `QuestPersistenceController.shared.container`.

### Captain container models

- `CaptainMemory`
- `PersistentChatMessage`
- `RecordProject`
- `WeeklyLog`

### Scene-wide app container models

- `AiQoDailyRecord`
- `WorkoutTask`
- `ArenaTribe`
- `ArenaTribeMember`
- `ArenaWeeklyChallenge`
- `ArenaTribeParticipation`
- `ArenaEmirateLeaders`
- `ArenaHallOfFameEntry`

### Additional SwiftData lane

- Quest persistence stores additional player/quest/reward data in a separate controller.

### Key SwiftData models

- `AiQoDailyRecord`
- `WorkoutTask`
- `CaptainMemory`
- `PersistentChatMessage`
- `RecordProject`
- `WeeklyLog`
- `SmartFridgeScannedItemRecord`
- `ArenaTribe`
- `ArenaTribeMember`
- `ArenaWeeklyChallenge`
- `ArenaTribeParticipation`
- `ArenaEmirateLeaders`
- `ArenaHallOfFameEntry`
- `PlayerStats`
- `QuestStage`
- `QuestRecord`
- `Reward`

### `AiQoDailyRecord`

- Unique day id string.
- `date`
- `currentSteps`
- `targetSteps`
- `burnedCalories`
- `targetCalories`
- `waterCups`
- `targetWaterCups`
- `captainDailySuggestion`
- relationship `workouts`

### `WorkoutTask`

- `id`
- `title`
- `isCompleted`
- relationship `dailyRecord`

### `CaptainMemory`

- `id`
- `category`
- `key`
- `value`
- `confidence`
- `source`
- `createdAt`
- `updatedAt`
- `accessCount`
- `key` is unique in the model definition.

### `PersistentChatMessage`

- `messageID`
- `text`
- `isUser`
- `timestamp`
- `spotifyRecommendationData`
- `sessionID`

### `RecordProject`

- `id`
- `recordID`
- `recordTitle`
- `recordCategory`
- `targetValue`
- `unit`
- `currentRecordHolder`
- `holderCountryFlag`
- `userWeightAtStart`
- `userFitnessLevelAtStart`
- `userBestAtStart`
- `totalWeeks`
- `currentWeek`
- `planJSON`
- `difficulty`
- `bestPerformance`
- relationship `weeklyLogs`
- `status`
- `startDate`
- `endDate`
- `lastReviewDate`
- `lastReviewNotes`
- `isPinnedToPlan`
- `completedTaskIDsJSON`
- `hrrPeakHR`
- `hrrRecoveryHR`
- `hrrLevel`

### `WeeklyLog`

- `id`
- `weekNumber`
- `date`
- `currentWeight`
- `performanceThisWeek`
- `userFeedback`
- `captainNotes`
- `adjustments`
- `weekRating`
- `isOnTrack`
- `obstacles`
- relationship `project`

### `SmartFridgeScannedItemRecord`

- `id`
- `name`
- `quantity`
- `unit`
- `alchemyNoteKey`
- `capturedAt`

## SECTION 8 — HealthKit Integration

### HealthKit service surface

- `AiQo/Services/Permissions/HealthKit/HealthKitService.swift`
- `AiQo/Shared/HealthKitManager.swift`
- `AiQo/Features/Sleep/HealthManager+Sleep.swift`
- onboarding permission requests in `AiQo/App/SceneDelegate.swift`
- watch health service in `AiQoWatch Watch App/Services/WatchHealthKitManager.swift`

### HealthKit quantity/category types read in code

- `stepCount`
- `activeEnergyBurned`
- `distanceWalkingRunning`
- `distanceCycling`
- `heartRate`
- `heartRateVariabilitySDNN`
- `restingHeartRate`
- `walkingHeartRateAverage`
- `oxygenSaturation`
- `vo2Max`
- `bodyMass`
- `dietaryWater`
- `appleStandTime`
- `appleStandHour`
- `bodyFatPercentage`
- `leanBodyMass`
- `sleepAnalysis`
- `activitySummaryType`
- `workoutType`

### Types written in code

- `dietaryWater`
- `heartRate`
- `restingHeartRate`
- `heartRateVariabilitySDNN`
- `vo2Max`
- `distanceWalkingRunning`
- `bodyMass`
- `workoutType`

### Onboarding permission request strategy

- The broadest permission request lives in `AppFlowController.requestFullHealthKitPermissions()`.
- This happens during the legacy-calculation stage.
- It is paired with notification permission and `ProtectionModel` authorization.
- `HealthKitService.permissionFlowEnabled` is flipped when onboarding is complete or when permission flow should be enabled.

### `HealthKitService.requestAuthorization()`

- Read set includes:
  - steps,
  - heart rate,
  - resting heart rate,
  - HRV,
  - walking HR average,
  - active energy,
  - walking/running distance,
  - dietary water,
  - VO2 max,
  - sleep analysis,
  - stand hour,
  - workout type.
- Write set includes:
  - dietary water,
  - heart rate,
  - resting heart rate,
  - HRV,
  - VO2 max,
  - walking/running distance,
  - workout type.

### `AppFlowController` full permission set

- read:
  - step count,
  - active kcal,
  - walk/run distance,
  - cycling distance,
  - heart rate,
  - HRV,
  - resting HR,
  - walking HR average,
  - oxygen saturation,
  - VO2 max,
  - body mass,
  - dietary water,
  - apple stand time,
  - sleep analysis,
  - activity summary,
  - workout type.
- write:
  - heart rate,
  - HRV,
  - resting HR,
  - VO2 max,
  - walking/running distance,
  - dietary water,
  - body mass,
  - workout type.

### Sleep integration

- `HealthManager+Sleep` parses detailed sleep stages.
- Visible stage names include:
  - `awake`
  - `rem`
  - `core`
  - `deep`
- Sleep also feeds:
  - Home cards,
  - Captain context,
  - SleepSessionObserver,
  - smart recovery logic.

### Health summary aggregation

- `HealthKitService.fetchTodaySummary()` aggregates:
  - today steps,
  - active kcal,
  - walking/running distance,
  - dietary water,
  - sleep hours,
  - stand percentage.

### Published health UI state

- `HealthKitManager` publishes:
  - `todaySteps`
  - `todayCalories`
  - `todayDistanceKm`

### Health data into Captain prompts

- `CaptainContextBuilder` loads daily metrics from `CaptainIntelligenceManager`.
- Prompt bio-state includes:
  - steps,
  - active calories,
  - sleep hours,
  - heart rate,
  - time of day,
  - level.
- The cloud prompt never needs raw HealthKit sample exports.

### Health-to-memory bridge

- `HealthKitMemoryBridge.syncHealthDataToMemory()` writes remembered health summaries:
  - latest body mass,
  - resting HR,
  - 7-day average steps,
  - 7-day average active calories,
  - 7-day average sleep hours.

### Privacy rule: what never leaves device directly

- Raw HealthKit sample streams are not directly uploaded to Supabase in the reviewed code.
- Captain cloud requests receive sanitized aggregates, not direct raw sample histories.
- Local legal strings state health data is stored locally.
- Image metadata is stripped before kitchen cloud use.
- `Inference:` the architecture is deliberately designed so cloud AI gets enough context to coach without owning full raw HealthKit history.

### Background health observers

- `SleepSessionObserver` uses anchored/background sleep observation.
- `MorningHabitOrchestrator` reads steps after wake time.
- `AIWorkoutSummaryService` observes workouts and composes a short AI notification.

### Watch health usage

- The watch app also requests HealthKit access.
- Watch types include:
  - steps,
  - active calories,
  - walking/running distance,
  - heart rate,
  - sleep,
  - workout type.
- The watch writes workouts and sends workout completion payloads to the phone.

### Source evidence

- `AiQo/Services/Permissions/HealthKit/HealthKitService.swift`
- `AiQo/Shared/HealthKitManager.swift`
- `AiQo/Features/Sleep/HealthManager+Sleep.swift`
- `AiQo/App/SceneDelegate.swift`
- `AiQo/Core/HealthKitMemoryBridge.swift`
- `AiQo/Features/Captain/CaptainContextBuilder.swift`
- `AiQoWatch Watch App/Services/WatchHealthKitManager.swift`

---

## SECTION 9 — Onboarding Flow

### Requested read list vs live files

- `AiQo/Features/Onboarding/*.swift`
  - exists and was read.
- The actual first-run flow also depends on:
  - `AiQo/App/LanguageSelectionView.swift`
  - `AiQo/App/LoginViewController.swift`
  - `AiQo/App/ProfileSetupView.swift`
  - `AiQo/Features/First screen/LegacyCalculationViewController.swift`
  - `AiQo/Features/Onboarding/FeatureIntroView.swift`

### Effective screen order from `AppFlowController`

- `LanguageSelectionView`
- login screen via `AuthFlowUI` / `LoginScreenView`
- `ProfileSetupView`
- `LegacyCalculationScreenView`
- `FeatureIntroView`
- `MainTabScreen`

### `LanguageSelectionView`

- Collects initial language choice.
- Writes onboarding progress state.
- Works with `LocalizationManager`.
- Establishes Arabic/English route before the rest of onboarding.

### Login screen

- Implemented via:
  - `AiQo/App/AuthFlowUI.swift`
  - `AiQo/App/LoginViewController.swift`
- Sign in with Apple happens here.
- The login code exchanges Apple credentials into Supabase auth.

### Profile setup

- `ProfileSetupView` captures personal profile information used by the app.
- This includes profile identity inputs used later by Captain and tribe.

### Legacy calculation stage

- Implemented in `LegacyCalculationViewController.swift`.
- It is the major permissions-and-baseline step.
- It requests HealthKit and notification permissions.
- It performs historical health sync / initial scoring behavior.
- It gates progression into the feature intro and main app.

### Feature intro

- Implemented in `FeatureIntroView.swift`.
- This is the final explanatory layer before the user lands in the tab shell.

### `OnboardingWalkthroughView`

- The file exists.
- It is not referenced by `AppFlowController.RootScreen`.
- `Inference:` it appears to be a legacy or alternative walkthrough that is not currently wired into the first-run root state machine.

### What each onboarding stage collects or explains

- Language selection:
  - app language,
  - RTL/LTR experience foundation.
- Login:
  - Apple identity,
  - Supabase session.
- Profile setup:
  - personal profile state,
  - future tribe / AI identity context.
- Legacy calculation:
  - HealthKit permissions,
  - notifications,
  - initial scoring and calibration.
- Feature intro:
  - overview of the core product surfaces.

### Subscription paywall position

- No onboarding paywall screen is wired in the reviewed root-flow code.
- `FreeTrialManager.shared.startTrialIfNeeded()` runs during onboarding finalization.
- This means trial state starts during onboarding, but paywall presentation is not part of the first-run screen chain today.
- `Inference:` monetization currently begins with trial activation before an explicit onboarding paywall.

### Sign in with Apple position

- Positioned in the login stage.
- It occurs before profile setup.

### HealthKit permission position

- Positioned in the legacy calculation stage.
- Triggered before the app transitions to the feature intro and main tab shell.

### Notification permission position

- Paired with HealthKit permission in the onboarding completion path.
- Also refreshed at app launch for returning fully-onboarded users.

### Feature flags controlling onboarding

- No separate generic onboarding feature-flag file was found.
- The effective onboarding control plane is the set of persisted first-run booleans:
  - `didSelectLanguage`
  - `didShowFirstAuthScreen`
  - `didCompleteDatingProfile`
  - `didCompleteLegacyCalculation`
  - `didCompleteFeatureIntro`

### Historical sync support

- `HistoricalHealthSyncEngine.swift` exists under onboarding.
- It supports importing historical health context during the first-run calibration stage.

### Source evidence

- `AiQo/App/SceneDelegate.swift`
- `AiQo/App/LanguageSelectionView.swift`
- `AiQo/App/AuthFlowUI.swift`
- `AiQo/App/LoginViewController.swift`
- `AiQo/App/ProfileSetupView.swift`
- `AiQo/Features/First screen/LegacyCalculationViewController.swift`
- `AiQo/Features/Onboarding/FeatureIntroView.swift`
- `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift`
- `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift`

---

## SECTION 10 — Feature Modules (all 7)

### Home

- Purpose:
  - daily health dashboard,
  - aura surface,
  - home shortcuts into sleep, water, kitchen, vibe, tribe, and Captain.
- Key files:
  - `AiQo/Features/Home/HomeView.swift`
  - `AiQo/Features/Home/HomeViewModel.swift`
  - `AiQo/Features/Home/DailyAuraView.swift`
  - `AiQo/Features/Sleep/SleepDetailCardView.swift`
  - `AiQo/Features/Home/WaterDetailSheetView.swift`
  - `AiQo/Features/Home/SpotifyVibeCard.swift`
  - `AiQo/Features/Home/StreakBadgeView.swift`
- AI routing:
  - indirect.
  - Captain opens from home surfaces, but home itself is not a direct AI brain route.
- Data models used:
  - `AiQoDailyRecord`
  - level and streak stores
  - `TodaySummary`
- HealthKit types consumed:
  - steps
  - energy
  - distance
  - sleep
  - water
- Feature flags:
  - tribe visibility affects whether tribe-related navigation remains accessible.
- Current status:
  - `Inference: complete`
  - reason: this module is the main first-tab experience and is clearly wired, localized, and visually mature.

### Gym / Peaks

- Purpose:
  - workouts,
  - plans,
  - peaks / records,
  - impact summaries,
  - challenges and quests,
  - live workout experiences.
- Key files:
  - `AiQo/Features/Gym/GymViewController.swift`
  - `AiQo/Features/Gym/Club/ClubRootView.swift`
  - `AiQo/Features/Gym/Club/Plan/PlanView.swift`
  - `AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift`
  - `AiQo/Features/Gym/WorkoutSessionViewModel.swift`
  - `AiQo/Features/Gym/WorkoutLiveActivityManager.swift`
  - `AiQo/Features/Gym/QuestKit/*`
  - `AiQo/Features/Gym/Quests/*`
- AI routing:
  - cloud for `gym`
  - cloud for `peaks`
  - local fallback when needed.
- Data models used:
  - `RecordProject`
  - `WeeklyLog`
  - quest SwiftData models
  - `PlayerStats`
  - rewards / wins stores
- HealthKit types consumed:
  - workouts
  - heart rate
  - active energy
  - steps
  - distance
  - VO2 max in some flows
- Feature flags:
  - no dedicated gym feature flag found.
- Current status:
  - `Inference: complete with in-progress edges`
  - reason: core gym flow is extensive and wired, but some files retain legacy naming and experimental subfeatures.

### Alchemy Kitchen

- Purpose:
  - nutrition planning,
  - meal plan generation,
  - fridge scanning,
  - ingredient browsing,
  - nutrition tracking.
- Key files:
  - `AiQo/Features/Kitchen/KitchenScreen.swift`
  - `AiQo/Features/Kitchen/KitchenViewModel.swift`
  - `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift`
  - `AiQo/Features/Kitchen/MealPlanGenerator.swift`
  - `AiQo/Features/Kitchen/SmartFridgeScannerView.swift`
  - `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift`
- AI routing:
  - cloud for `kitchen`.
- Data models used:
  - `SmartFridgeScannedItemRecord`
  - meal / ingredient models
  - nutrition goals from `UserDefaults`
- HealthKit types consumed:
  - dietary water directly,
  - broader health context may inform meal generation via Captain context.
- Feature flags:
  - no kitchen-specific feature flag found.
- Current status:
  - `Inference: complete with some local-data bias`
  - reason: the feature is wired and large, but repositories and seed content suggest a mix of local generation and evolving intelligence services.

### Sleep & Spirit

- Requested folder:
  - `AiQo/Features/Sleep/*.swift`
- File status:
  - exists and was read from the live project.
- Key files:
  - `AiQo/Features/Sleep/AlarmSetupCardView.swift`
  - `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift`
  - `AiQo/Features/Sleep/HealthManager+Sleep.swift`
  - `AiQo/Features/Sleep/SleepDetailCardView.swift`
  - `AiQo/Features/Sleep/SleepScoreRingView.swift`
  - `AiQo/Features/Sleep/SleepSessionObserver.swift`
  - `AiQo/Features/Sleep/SmartWakeCalculatorView.swift`
  - `AiQo/Features/Sleep/SmartWakeEngine.swift`
  - `AiQo/Features/Sleep/SmartWakeViewModel.swift`
  - `AiQo/Services/Notifications/NotificationIntelligenceManager.swift`
- Purpose:
  - sleep tracking,
  - on-device sleep analysis,
  - recovery coaching,
  - smart wake planning,
  - background follow-up notifications,
  - “spiritual whispers” style notification intelligence.
- AI routing:
  - local first for `sleepAnalysis`.
- Data models used:
  - Captain chat state,
  - Captain memory state,
  - notification scheduling state,
  - health summary state.
- HealthKit types consumed:
  - `sleepAnalysis`
  - heart rate
  - heart rate variability
  - steps
  - active calories
- Feature flags:
  - no sleep-specific feature flag found.
- Current status:
  - `Inference: complete core feature with distributed services`
  - reason: the folder is real, the sleep agent and observer are wired, and the feature already participates in onboarding, Captain routing, and background notifications.

### My Vibe

- Purpose:
  - music / vibe orchestration,
  - Spotify connection,
  - DJ Hamoudi chat lane,
  - audio-mode mood control.
- Key files:
  - `AiQo/Features/MyVibe/MyVibeScreen.swift`
  - `AiQo/Features/MyVibe/MyVibeViewModel.swift`
  - `AiQo/Features/MyVibe/VibeOrchestrator.swift`
  - `AiQo/Core/SpotifyVibeManager.swift`
  - `AiQo/Core/VibeAudioEngine.swift`
- AI routing:
  - cloud for `myVibe`.
- Data models used:
  - daily vibe state
  - Spotify recommendation payloads
  - Captain chat state
- HealthKit types consumed:
  - indirectly via Captain context and daily metrics.
- Feature flags:
  - no dedicated My Vibe flag found.
- Current status:
  - `Inference: complete`
  - reason: clear screen, view model, audio engine, Spotify integration, and dedicated AI context exist.

### Tribe / Emara

- Purpose:
  - social wellness hub,
  - tribe membership,
  - private/public identity within tribe,
  - arena and leaderboard access.
- Key files:
  - `AiQo/Features/Tribe/TribeView.swift`
  - `AiQo/Features/Tribe/TribeExperienceFlow.swift`
  - `AiQo/Tribe/TribeScreen.swift`
  - `AiQo/Tribe/TribeStore.swift`
  - `AiQo/Tribe/Repositories/TribeRepositories.swift`
  - `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift`
- AI routing:
  - no dedicated Captain screen-context route for tribe was found.
- Data models used:
  - tribe / member / mission / event models
  - Supabase profile data
  - privacy mode settings
- HealthKit types consumed:
  - indirectly via points, level, streak, and challenge scores.
- Feature flags:
  - `TRIBE_BACKEND_ENABLED = false`
  - `TRIBE_FEATURE_VISIBLE = false`
  - `TRIBE_SUBSCRIPTION_GATE_ENABLED = false`
- Current status:
  - `Inference: hidden and in-progress`
  - reason: the code surface is large, but the current build disables visibility and the repository/store layer still falls back to mock or stubbed behavior.

### Arena

- Requested folder:
  - `AiQo/Features/Arena/*.swift`
- File status:
  - File not found — actual arena implementation lives under `AiQo/Tribe/Galaxy` and `AiQo/Tribe/Arena`.
- Purpose:
  - curated and user challenge competition,
  - history,
  - leaderboards,
  - tribe-vs-tribe / galaxy challenge framing.
- Key files:
  - `AiQo/Tribe/Galaxy/ArenaScreen.swift`
  - `AiQo/Tribe/Galaxy/ArenaViewModel.swift`
  - `AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift`
  - `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift`
  - `AiQo/Tribe/Arena/TribeArenaView.swift`
- AI routing:
  - no dedicated screen-context route was found.
  - Captain may still be invoked contextually from related surfaces.
- Data models used:
  - arena SwiftData models
  - completed challenge history
  - hall-of-fame models
- HealthKit types consumed:
  - steps
  - water
  - sleep
  - other challenge metrics depending on challenge type.
- Feature flags:
  - inherited from tribe feature flags, which are currently disabled in `Info.plist`.
- Current status:
  - `Inference: hidden and in-progress`
  - reason: the UI is substantial, but the current build disables tribe visibility and the backend/repository path is not fully live end to end.

### Profile

- Purpose:
  - personal identity,
  - level display,
  - privacy mode,
  - weekly report access,
  - progress photos,
  - settings entry.
- Key files:
  - `AiQo/Features/Profile/ProfileScreen.swift`
  - `AiQo/Features/Profile/LevelCardView.swift`
  - `AiQo/Core/AppSettingsScreen.swift`
  - `AiQo/Features/WeeklyReport/WeeklyReportView.swift`
  - `AiQo/Features/ProgressPhotos/ProgressPhotosView.swift`
- AI routing:
  - none directly.
- Data models used:
  - `UserProfileStore`
  - `LevelStore`
  - progress photo store
- HealthKit types consumed:
  - bio metrics displayed in profile.
- Current status:
  - `Inference: complete`
  - reason: fully reachable UI, data wiring, and companion settings/report surfaces exist.

### Settings

- Requested folder:
  - `AiQo/Features/Settings/*.swift`
- File status:
  - File not found — actual settings screen is `AiQo/Core/AppSettingsScreen.swift`.
- Purpose:
  - language,
  - notification preferences,
  - privacy,
  - account actions,
  - debug/dev surfaces.
- Current status:
  - `Inference: complete`

### Source evidence

- `AiQo/Features/Home/*`
- `AiQo/Features/Gym/*`
- `AiQo/Features/Kitchen/*`
- `AiQo/Features/MyVibe/*`
- `AiQo/Features/Profile/*`
- `AiQo/Tribe/*`
- `AiQo/Core/AppSettingsScreen.swift`

---

## SECTION 11 — Gamification System

### Main gamification subsystems visible in code

- `LevelStore`
- `LevelSystem`
- `XPCalculator`
- `StreakManager`
- `QuestAchievementStore`
- `QuestDailyStore`
- `WinsStore`
- `ChallengeHistoryStore`
- legendary project persistence and views

### XP engine

- `XPCalculator.calculateSessionStats()`:
  - `truthNumber = calories + durationMinutes`
  - `luckyNumber = sum of digits in computed heartbeat count`
  - `totalXP = truthNumber + luckyNumber`
- `XPCalculator.calculateCoins()`:
  - every `100` steps = `1` coin
  - every `50` active calories = `1` coin
  - if heart rate > `115`, bonus = `durationMinutes * 2`
- `PhoneConnectivityManager` adds XP when watch workouts complete.
- `LevelStore.addXP(_:)` syncs XP and level to Supabase arena profiles.

### Level progression

- Base XP for next-level calculation:
  - `1000`
- Multiplier:
  - `1.2`
- Next-level XP formula:

```text
baseXP * multiplier^(level - 1)
```

### Shield / level tiers in `LevelStore`

- level `1-4`:
  - `wood`
- level `5-9`:
  - `bronze`
- level `10-14`:
  - `silver`
- level `15-19`:
  - `gold`
- level `20-24`:
  - `platinum`
- level `25-29`:
  - `diamond`
- level `30-34`:
  - `obsidian`
- level `35+`:
  - `legendary`

### Shield colors

- wood:
  - `#8B4513`
- bronze:
  - `#CD7F32`
- silver:
  - `#C0C0C0`
- gold:
  - `#FFD700`
- platinum:
  - `#E5E4E2`
- diamond:
  - `#B9F2FF`
- obsidian:
  - `#3D3D3D`
- legendary:
  - `#FF6B6B`

### Level names in Arabic

- No canonical Arabic level-name table exists in `LevelStore`.
- The persisted tier identifiers and `displayName` values are English:
  - `Wood`
  - `Bronze`
  - `Silver`
  - `Gold`
  - `Platinum`
  - `Diamond`
  - `Obsidian`
  - `Legendary`
- Arabic meaning is present in comments, not as runtime display strings.
- `Inference:` Arabic-facing UI currently relies more on icons and localized surrounding copy than on a dedicated Arabic tier-name map.

### Streak system

- Main manager:
  - `StreakManager.shared`
- Active-day rule in comment:
  - `5000+` steps or one workout or `30+` active minutes.
- Runtime API:
  - `markTodayAsActive()`
  - `checkStreakContinuity()`
- Continuity logic:
  - same-day repeat does not increment,
  - yesterday continuity increments streak,
  - larger gap resets to `1` when marked active again,
  - app-open continuity check resets broken streaks to `0`.

### Streak persistence keys

- `aiqo.streak.current`
- `aiqo.streak.longest`
- `aiqo.streak.lastActive`
- `aiqo.streak.history`

### Streak color tiers

- `< 7` days:
  - sand color
- `7-29` days:
  - orange
- `30+` days:
  - purple

### Streak motivation tiers

- `0`
- `1`
- `2...3`
- `4...6`
- `7...13`
- `14...29`
- `30...59`
- `60...89`
- `90...364`
- `365+`

### Quest system

- Quest kit includes:
  - definitions,
  - evaluator,
  - formatting,
  - SwiftData models,
  - progress store,
  - challenge views.
- Achievements are persisted locally in `QuestAchievementStore`.
- Wins are persisted in `WinsStore`.

### Badge system in Arena challenge history

- badge ids and unlock conditions:
  - `first`
    - unlock at `>= 1` completed challenge
  - `five`
    - unlock at `>= 5`
  - `ten`
    - unlock at `>= 10`
  - `twentyfive`
    - unlock at `>= 25`
  - `fifty`
    - unlock at `>= 50`
  - `walker`
    - unlock when completed challenge history contains `figure.walk`
  - `hydrated`
    - unlock when completed challenge history contains `drop.fill`

### Badge labels

- `first`:
  - `البداية`
- `five`:
  - `المثابر`
- `ten`:
  - `المحارب`
- `twentyfive`:
  - `الأسطورة`
- `fifty`:
  - `الخالد`
- `walker`:
  - `الماشي`
- `hydrated`:
  - `المرطّب`

### Legendary projects

- Core structs:
  - `LegendaryRecord`
  - `LegendaryProject`
  - `RecordProject`
  - `WeeklyLog`
- Seed records include:
  - pushups/minute
  - plank hold
  - squats/minute
  - 24h walk distance
  - burpees/minute
  - pullups/minute
  - breath hold
  - 24h step count

### Legendary project structure

- `LegendaryProject` stores:
  - record id,
  - start date,
  - target weeks,
  - weekly checkpoints,
  - daily tasks,
  - personal best,
  - completion state.
- `RecordProject` is the richer persisted SwiftData version.
- Weekly review and plan JSON are persisted.

### Legendary project durations

- Example estimated durations in seed records:
  - pushups/minute: `16` weeks
  - plank: `24` weeks
  - squats/minute: `10` weeks
  - walk 24h: `20` weeks
  - burpees/minute: `12` weeks
  - pullups/minute: `16` weeks
  - breath hold: `12` weeks
  - steps 24h: `16` weeks

### Legendary XP rewards

- No dedicated legendary-project XP reward table was found.
- Legendary progression currently tracks:
  - project creation,
  - weekly logs,
  - performance,
  - captain guidance.
- `Inference:` explicit XP rewards for legendary projects are not yet implemented as a distinct ruleset in the reviewed code.

### Source evidence

- `AiQo/XPCalculator.swift`
- `AiQo/Core/Models/LevelStore.swift`
- `AiQo/Shared/LevelSystem.swift`
- `AiQo/Core/StreakManager.swift`
- `AiQo/Features/Home/StreakBadgeView.swift`
- `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift`
- `AiQo/Features/LegendaryChallenges/*`

---

## SECTION 12 — Monetization & StoreKit 2

### Monetization files requested vs live files

- `AiQo/Services/Monetization/PurchaseManager.swift`
  - File not found — actual file is `AiQo/Core/Purchases/PurchaseManager.swift`.
- `AiQo/Services/Monetization/FreeTrialManager.swift`
  - File not found — actual file is `AiQo/Premium/FreeTrialManager.swift`.
- Paywall files exist in:
  - `AiQo/Premium/PremiumPaywallView.swift`
  - `AiQo/UI/Purchases/PaywallView.swift`

### Core monetization components

- `PurchaseManager`
- `SubscriptionProductIDs`
- `EntitlementStore`
- `ReceiptValidator`
- `FreeTrialManager`
- `AccessManager`
- `PremiumStore`
- `PremiumPaywallView`
- `PaywallView`

### Free trial

- Duration:
  - `7` days
- Trial starts through:
  - `FreeTrialManager.shared.startTrialIfNeeded()`
- Trial activation is triggered in onboarding finalization.

### Product ids

- current ids:
  - `aiqo_nr_30d_individual_5_99`
  - `aiqo_nr_30d_family_10_00`
- legacy alias ids:
  - `aiqo_30d_individual_5_99`
  - `aiqo_30d_family_10_00`

### Plan types

- individual plan
- family plan

### Fallback display prices

- individual:
  - `$5.99`
- family:
  - `$10.00`

### Access rules

- `canAccessTribe`
  - active if tribe entitlement is true or free trial is active.
- `canCreateTribe`
  - active if family-plan entitlement is true or free trial is active.

### Purchase flow

- `PurchaseManager.start()` begins StoreKit observation.
- `Transaction.updates` is observed.
- On purchase:
  - transaction is verified,
  - local entitlement expiry is updated,
  - expiry notifications are scheduled,
  - transaction is finished,
  - async server-side validation is triggered.

### Restore flow

- Uses:

```swift
AppStore.sync()
```

### Local entitlement persistence

- `aiqo.purchases.activeProductId`
- `aiqo.purchases.expiresAt`

### Receipt validation flow

- `ReceiptValidator` calls Supabase edge function:

```text
https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/validate-receipt
```

- This is the only explicit edge function found in the monetization lane.

### Paywall design and copy behavior

- `PremiumPaywallView` includes:
  - free-trial banner if user has not used the trial,
  - active-trial banner when trial is running,
  - individual and family plan cards,
  - restore button,
  - legal links.
- It tracks `.paywallViewed`.

### StoreKit 2 compliance-related implementation facts

- Uses `StoreKit` transaction verification.
- Supports restore.
- Observes `Transaction.updates`.
- Finishes verified transactions.
- Separates entitlement storage from UI.
- Maintains receipt validation via a server function.
- Includes debug local StoreKit config for development.

### Pricing strategy

- `Inference:` current pricing strategy is simple two-tier monthly recurring pricing:
  - lower-cost individual,
  - higher-cost family.
- There is no annual tier in the reviewed code.

### Subscription gating

- Tribe access is the most explicit gated feature in reviewed code.
- Free trial temporarily unlocks premium behavior.
- Preview / debug overrides also exist for tribe access.

### Debug / preview monetization flags

- `aiqo.tribe.preview.enabled`
- `aiqo.tribe.preview.useMockData`
- `aiqo.tribe.preview.plan`
- `aiqo.tribe.preview.forceEnabled`

### Source evidence

- `AiQo/Core/Purchases/PurchaseManager.swift`
- `AiQo/Core/Purchases/SubscriptionProductIDs.swift`
- `AiQo/Core/Purchases/EntitlementStore.swift`
- `AiQo/Core/Purchases/ReceiptValidator.swift`
- `AiQo/Premium/FreeTrialManager.swift`
- `AiQo/Premium/AccessManager.swift`
- `AiQo/Premium/PremiumPaywallView.swift`
- `AiQo/UI/Purchases/PaywallView.swift`

---

## SECTION 13 — Supabase Backend Schema

### Core backend files

- `AiQo/Services/SupabaseService.swift`
- `AiQo/Services/SupabaseArenaService.swift`
- `AiQo/Tribe/Repositories/TribeRepositories.swift`
- `AiQo/Tribe/Models/TribeFeatureModels.swift`
- `AiQo/App/LoginViewController.swift`

### Auth strategy

- Apple Sign In is the identity provider.
- Apple credentials are exchanged into Supabase auth using `signInWithIdToken`.
- User profile / id values are then used across the app.

### Tables explicitly used in code

- `profiles`
- `arena_tribes`
- `arena_tribe_members`
- `arena_tribe_participations`
- `arena_weekly_challenges`
- `arena_hall_of_fame_entries`

### `profiles` usage

- fetch current profile
- search profiles
- update device token
- sync points / level
- update privacy visibility
- fetch leaderboard data

### `arena_tribes` usage

- create tribe
- join / fetch my tribe
- leave tribe

### `arena_tribe_members` usage

- membership and roster handling
- tribe user visibility
- creator/member state

### `arena_tribe_participations` usage

- submit tribe participation
- fetch tribe participation results

### `arena_weekly_challenges` usage

- create default weekly challenge
- fetch current weekly challenge

### `arena_hall_of_fame_entries` usage

- fetch hall of fame history

### Real-time subscriptions

- No Supabase realtime channel or subscription usage was found in the reviewed source.
- `Inference:` the current backend integration is request/response oriented, not realtime.

### Edge functions

- Explicitly found edge function:
  - receipt validation at `validate-receipt`.
- No other edge function usage was found in the reviewed code.

### RLS strategy

- No RLS policies are defined in the app repository.
- `Inference:` RLS likely lives only in Supabase project configuration outside the iOS source repo.
- The client code assumes:
  - authenticated user-scoped access,
  - profile-scoped updates,
  - per-tribe operations.

### Current backend readiness gap

- `TRIBE_BACKEND_ENABLED` is `false` in `Info.plist`.
- `TRIBE_FEATURE_VISIBLE` is `false` in `Info.plist`.
- `TRIBE_SUBSCRIPTION_GATE_ENABLED` is `false` in `Info.plist`.
- `TribeRepositoryFactory` can instantiate `SupabaseTribeRepository` and `SupabaseChallengeRepository` when the backend flag is enabled.
- But both current “Supabase” repository types still delegate to mock repositories.
- `TribeStore.createTribe` and `TribeStore.joinTribe` also remain explicit local stubs with TODO comments.
- Result:
  - the backend code path exists,
  - the current build hides the feature,
  - and the live tribe social flow is not yet fully backed by production Supabase tables.

### Resulting backend truth

- Supabase is real for:
  - auth,
  - profiles,
  - arena stats / leaderboard style services,
  - receipt validation edge function.
- Tribe repository abstraction is not fully live end-to-end yet.
- The Info.plist flag is ahead of full repository implementation.

### Source evidence

- `AiQo/Services/SupabaseService.swift`
- `AiQo/Services/SupabaseArenaService.swift`
- `AiQo/App/LoginViewController.swift`
- `AiQo/Tribe/Repositories/TribeRepositories.swift`
- `AiQo/Tribe/TribeStore.swift`
- `AiQo/Info.plist`

---

## SECTION 14 — Notifications & Background Tasks

### Core files

- `AiQo/Core/SmartNotificationScheduler.swift`
- `AiQo/Services/Notifications/MorningHabitOrchestrator.swift`
- `AiQo/Features/Sleep/SleepSessionObserver.swift`
- `AiQo/Services/Notifications/NotificationIntelligenceManager.swift`
- `AiQo/Services/Notifications/ActivityNotificationEngine.swift`
- `AiQo/Services/Notifications/AlarmSchedulingService.swift`
- `AiQo/Services/Notifications/PremiumExpiryNotifier.swift`
- `AiQo/Services/Notifications/NotificationCategoryManager.swift`
- `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift`
- `AiQo/Services/Notifications/SmartNotificationManager.swift`
- `AiQo/Features/Captain/CaptainNotificationRouting.swift`

### Background task identifiers

- `aiqo.captain.spiritual-whispers.refresh`
- `aiqo.captain.inactivity-check`

### Notification categories and behaviors

- captain smart notifications
- captain angel reminders
- morning habit follow-up
- sleep-session follow-up
- premium expiry reminders
- AI workout summary notifications

### `SmartNotificationScheduler` static schedule logic

- water reminders:
  - `10:00`
  - `12:00`
  - `14:00`
  - `16:00`
  - `18:00`
  - `20:00`
- workout motivation:
  - `17:00`
- sleep reminder:
  - `22:30`
- streak protection:
  - `20:00`
- weekly report:
  - Friday `10:00`

### `CaptainSmartNotificationService`

- category id:
  - `aiqo.captain.smart`
- reminder types:
  - inactivity
  - water reminder
  - meal-time reminder
  - step-goal progress
  - sleep reminder

### Smart-notification cooldowns

- inactivity:
  - `45m`
- water:
  - `2h`
- meal:
  - `4h`
- step goal:
  - `1h`
- sleep reminder:
  - `20h`

### Activity notification engine

- Uses angel-number timing patterns.
- Selected times include:
  - `01:11`
  - `02:22`
  - `03:33`
  - `04:44`
  - `05:55`
  - `10:10`
  - `11:11`
  - `12:12`
  - `12:21`

### Activity notification persistence keys

- `aiqo.activity.selectedAngelTimes`
- `aiqo.activity.lastScheduleDate`
- `aiqo.activity.yesterdayTimes`

### Morning habit orchestrator

- Tracks movement after wake time.
- Observation window:
  - `6h`
- step threshold:
  - `25`
- stored keys:
  - `aiqo.morningHabit.scheduledWakeTimestamp`
  - `aiqo.morningHabit.notificationWakeTimestamp`
  - `aiqo.morningHabit.cachedInsight`

### Sleep session observer

- Uses anchored/background observation for `sleepAnalysis`.
- stored keys:
  - `aiqo.sleepObserver.anchorData`
  - `aiqo.sleepObserver.lastNotifiedSleepEnd`
- On new sleep completion it can schedule a Captain deep-link notification.

### Notification intelligence manager

- Registers background tasks.
- Schedules “spiritual whispers”.
- Supports Iraqi-Arabic translation behavior for notification content.
- inactivity cooldown:
  - `3h`
- coach language key:
  - `notificationLanguage`

### AI workout summary service

- Observes workout completion.
- Uses anchored HealthKit workout queries.
- Stores:
  - `aiqo.ai.workout.anchor`
  - `aiqo.ai.workout.processed.ids`
- Generates a short summary notification around `20` words.

### Alarm integration

- `AlarmSchedulingService` imports `AlarmKit`.
- `Info.plist` includes `NSAlarmKitUsageDescription`.
- `Inference:` smart wake / alarm features are intended to integrate with Apple alarm capabilities.

### Source evidence

- `AiQo/Core/SmartNotificationScheduler.swift`
- `AiQo/Services/Notifications/*`
- `AiQo/Features/Captain/CaptainNotificationRouting.swift`
- `AiQo/Info.plist`

---

## SECTION 15 — Design System

### Core design-system files

- `AiQo/DesignSystem/AiQoColors.swift`
- `AiQo/DesignSystem/AiQoTheme.swift`
- `AiQo/DesignSystem/AiQoTokens.swift`
- `AiQo/DesignSystem/Components/AiQoBottomCTA.swift`
- `AiQo/DesignSystem/Components/AiQoCard.swift`
- `AiQo/DesignSystem/Components/AiQoChoiceGrid.swift`
- `AiQo/DesignSystem/Components/AiQoPillSegment.swift`
- `AiQo/DesignSystem/Components/AiQoPlatformPicker.swift`
- `AiQo/DesignSystem/Components/AiQoSkeletonView.swift`
- `AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift`
- `AiQo/DesignSystem/Modifiers/AiQoShadow.swift`
- `AiQo/DesignSystem/Modifiers/AiQoSheetStyle.swift`
- `AiQo/UI/GlassCardView.swift`
- `AiQo/Core/Colors.swift`
- `AiQo/Core/AiQoAccessibility.swift`

### Named colors in `AiQoColors`

- `mint`
  - `#CDF4E4`
- `beige`
  - `#F5D5A6`

### Theme colors in `AiQoTheme.Colors`

- `primaryBackground`
  - light: `#F5F7FB`
  - dark: `#0B1016`
- `surface`
  - light: white
  - dark: `#121922`
- `surfaceSecondary`
  - light: `#EEF2F7`
  - dark: `#18212B`
- `textPrimary`
  - light: `#0F1721`
  - dark: `#F6F8FB`
- `textSecondary`
  - light: `#5F6F80`
  - dark: `#A3AFBC`
- `accent`
  - light: `#5ECDB7`
  - dark: `#8AE3D1`
- `iconBackground`
  - light: `#F2F6FA`
  - dark: `#1A2430`
- `ctaGradientLeading`
  - light: `#7CE0D2`
  - dark: `#90E6D6`
- `ctaGradientTrailing`
  - light: `#A4C8FF`
  - dark: `#C4D9FF`

### Additional shared colors in `Colors.swift`

- `mint`
  - `#C4F0DB`
- `sand`
  - `#F8D6A3`
- `accent`
  - `#FFE68C`
- `aiqoBeige`
  - `#FADEB3`
- `lemon`
  - `#FFECB8`
- `lav`
  - `#F5E0FF`

### Typography scale

- `screenTitle`
- `sectionTitle`
- `cardTitle`
- `body`
- `caption`
- `cta`

### Spacing tokens

- `AiQoSpacing.xs`
  - `8`
- `AiQoSpacing.sm`
  - `12`
- `AiQoSpacing.md`
  - `16`
- `AiQoSpacing.lg`
  - `24`

### Corner radius tokens

- `AiQoRadius.control`
  - `12`
- `AiQoRadius.card`
  - `16`
- `AiQoRadius.ctaContainer`
  - `24`

### Metrics tokens

- minimum tap target:
  - `44`

### Core UI components

- `AiQoCard`
- `AiQoBottomCTA`
- `AiQoChoiceGrid`
- `AiQoPillSegment`
- `AiQoPlatformPicker`
- `AiQoSkeletonView`
- `StatefulPreviewWrapper`

### Interaction modifiers

- `AiQoPressButtonStyle`
- `AiQoShadow`
- `AiQoSheetStyle`

### Animation / motion presets

- several choice and segmented components use:

```text
spring(response: 0.28, dampingFraction: 0.86)
```

- `AiQoPressButtonStyle` scales down to approximately:

```text
0.92
```

- `LevelUpCelebrationView` and home overlays use explicit animation transitions.

### Glassmorphism usage

- `AiQoSheetStyle` uses:

```swift
.presentationBackground(.ultraThinMaterial)
```

- `GlassCardView` is a UIKit blur/tint/stroke wrapper.
- Tribe surfaces also use glass-card styling heavily.

### Accessibility helpers

- `AiQoAccessibility.isVoiceOverRunning`
- `AiQoAccessibility.prefersReducedMotion`
- Helper builders exist for:
  - metric cards,
  - rings,
  - nav buttons.

### RTL layout rules

- `MainTabScreen` enforces RTL.
- `AiQoCard` adapts visual-leading content to layout direction.
- Many Arabic screens are built assuming RTL layout from the start.

### Source evidence

- `AiQo/DesignSystem/*`
- `AiQo/UI/GlassCardView.swift`
- `AiQo/Core/Colors.swift`
- `AiQo/Core/AiQoAccessibility.swift`
- `AiQo/App/MainTabScreen.swift`

---

## SECTION 16 — Apple Watch Companion

### Current status

- Status:
  - `exists`
- Main watch app root:
  - `AiQoWatch Watch App/AiQoWatchApp.swift`
- Watch widget target also exists.

### Main watch app structure

- `AiQoWatchApp`
- `WatchHomeView`
- `WatchWorkoutListView`
- `WatchActiveWorkoutView`
- `WatchWorkoutSummaryView`
- `WatchHealthKitManager`
- `WatchWorkoutManager`
- `WatchConnectivityManager`

### Watch boot behavior

- If a workout is active:
  - show active workout screen.
- Otherwise:
  - show a paged `TabView` with home and workout list surfaces.
- On appear:
  - request HealthKit authorization.

### WatchConnectivity integration points

- watch side:
  - `WatchConnectivityService`
  - `WatchConnectivityManager`
- phone side:
  - `PhoneConnectivityManager`

### Data sent from watch to phone

- workout completion payload includes:
  - calories
  - duration
  - workout type
  - distance

### Phone-side reaction

- `PhoneConnectivityManager` receives workout-completion data.
- It awards XP through `LevelStore.shared.addXP(...)`.

### Watch HealthKit types

- read:
  - steps
  - active energy
  - walking/running distance
  - heart rate
  - sleep
  - workout type
- write:
  - workouts

### Watch workout summary logic

- summary XP formula:

```text
(calories * 0.8) + (duration_minutes * 2)
```

### Watch UI responsibilities

- `WatchHomeView`
  - aura ring
  - stat summaries
- `WatchWorkoutListView`
  - workout selection
- `WatchWorkoutSummaryView`
  - post-workout summary

### Haptics / interaction events

- `WatchConnectivityManager` supports haptics for:
  - rep detected
  - challenge completed

### Planned features

- `Inference:` the code suggests ongoing investment in:
  - live workout sync,
  - aura mirroring,
  - richer workout guidance,
  - widget/watch face presentation.
- No formal roadmap comment block was found inside watch code.

### Data sync strategy

- session messages for active sync
- application context / snapshot-style updates for summary state
- XP and workout completion synced back to phone
- widgets refreshed on phone side after relevant activity

### Source evidence

- `AiQoWatch Watch App/AiQoWatchApp.swift`
- `AiQoWatch Watch App/Services/WatchConnectivityService.swift`
- `AiQoWatch Watch App/Services/WatchHealthKitManager.swift`
- `AiQoWatch Watch App/Services/WatchWorkoutManager.swift`
- `AiQoWatch Watch App/Views/*`
- `AiQo/PhoneConnectivityManager.swift`

---

## SECTION 17 — Analytics & Crash Reporting

### Analytics files

- `AiQo/Services/Analytics/AnalyticsEvent.swift`
- `AiQo/Services/Analytics/AnalyticsService.swift`

### `AnalyticsService.shared`

- Provider-based design.
- Uses:
  - `ConsoleAnalyticsProvider` in debug
  - `LocalAnalyticsProvider` always
- stores super properties:
  - device model
  - OS version
  - app version
  - build number
  - locale
  - timezone
  - user id when identified

### Local analytics storage

- path:

```text
Application Support/Analytics/events.jsonl
```

- max events:
  - `5000`

### Analytics events currently defined

- app lifecycle:
  - `app_launched`
  - `app_became_active`
  - `app_entered_background`
- onboarding:
  - `onboarding_step_viewed`
  - `onboarding_completed`
  - `onboarding_skipped`
- auth:
  - `login_started`
  - `login_completed`
  - `logout_completed`
- navigation:
  - `tab_selected`
  - `screen_viewed`
- captain:
  - `captain_chat_opened`
  - `captain_message_sent`
  - `captain_response_received`
  - `captain_response_failed`
  - `captain_voice_played`
  - `captain_history_viewed`
- workouts:
  - `workout_started`
  - `workout_completed`
  - `workout_cancelled`
  - `vision_coach_started`
  - `vision_coach_completed`
- quests:
  - `quest_started`
  - `quest_completed`
- kitchen:
  - `kitchen_opened`
  - `meal_plan_generated`
  - `fridge_item_added`
- tribe:
  - `tribe_created`
  - `tribe_joined`
  - `tribe_left`
  - `tribe_leaderboard_viewed`
  - `tribe_arena_viewed`
- spotify:
  - `spotify_connected`
  - `spotify_track_played`
- health:
  - `health_permission_granted`
  - `health_permission_denied`
  - `daily_summary_generated`
- premium:
  - `paywall_viewed`
  - `subscription_started`
  - `subscription_failed`
  - `subscription_restored`
  - `subscription_cancelled`
  - `free_trial_started`
- notifications:
  - `notification_permission_granted`
  - `notification_permission_denied`
  - `notification_tapped`
- settings:
  - `language_changed`
  - `memory_cleared`
- generic:
  - `error_occurred`

### Crash reporting files

- `AiQo/Services/CrashReporting/CrashReporter.swift`
- `AiQo/Services/CrashReporting/CrashReportingService.swift`
- `AiQo/Services/CrashReporting/CRASHLYTICS_SETUP.md`

### Local crash reporter

- Captures uncaught exceptions.
- Captures signal handlers.
- Supports non-fatal logging.
- local path:

```text
Application Support/CrashReports/crash_log.jsonl
```

- max crash logs:
  - `50`
- clean-termination key:
  - `aiqo.crash.didTerminateCleanly`

### Remote crash integration

- `CrashReportingService` wraps Firebase Crashlytics if linked.
- It supports:
  - configure
  - set user
  - clear user
  - record non-fatal
  - add breadcrumbs
  - set custom keys
- If Firebase SDK is absent, the wrapper becomes effectively inert and logs that Crashlytics is disabled.

### Current gaps

- No external analytics SaaS provider beyond local/provider abstraction is visible in the reviewed code.
- No dedicated funnel dashboard definition exists in repo.
- No privacy manifest or analytics governance layer specific to events was found.
- `Inference:` analytics are sufficient for local development and event capture, but product analytics maturity is below App Store scale.

### Recommended additions

- Add explicit feature-success funnel events for:
  - completed meal plan use,
  - retained weekly active usage,
  - successful tribe creation-to-join conversion,
  - sleep insight opened after notification.
- Add result-quality analytics for:
  - Captain fallback rate,
  - local-vs-cloud routing rate,
  - voice-cache hit rate.
- Add structured crash breadcrumbs around:
  - onboarding permission failures,
  - Supabase auth exchange,
  - StoreKit validation failures.

### Source evidence

- `AiQo/Services/Analytics/AnalyticsEvent.swift`
- `AiQo/Services/Analytics/AnalyticsService.swift`
- `AiQo/Services/CrashReporting/CrashReporter.swift`
- `AiQo/Services/CrashReporting/CrashReportingService.swift`

---

## SECTION 18 — Accessibility & Localization

### VoiceOver support status

- `AiQoAccessibility` exposes VoiceOver state.
- Several components include explicit accessibility labels and combined accessibility elements.
- Examples:
  - tab labels,
  - streak badge,
  - metric/ring helpers.
- Status:
  - `Inference: partial but intentional support exists`

### Dynamic Type support

- Many screens use fixed custom font sizes via `.system(size:...)`.
- Some reusable components are therefore not fully Dynamic Type-native.
- Status:
  - `Inference: partial support`
  - reason: SwiftUI text is accessible by default in many places, but large portions of the UI rely on fixed-size typography.

### Reduce Motion handling

- `AiQoAccessibility.prefersReducedMotion` exists.
- The existence of this helper shows intent, though motion gating is not uniformly applied across every animated surface in reviewed files.
- Status:
  - `Inference: helper exists, adoption is partial`

### Localization strategy

- Localizations exist in:
  - Arabic
  - English
- `LocalizationManager` stores and reapplies language choice.
- `LanguageSelectionView` is the front door into language configuration.
- Captain has separate Arabic and English system-prompt paths.

### Approximate localized string counts

- Arabic `Localizable.strings` regex count:
  - approximately `1849` entries
- English `Localizable.strings` regex count:
  - approximately `1850` entries
- `Prompts.xcstrings` also exists and adds prompt-resource localization data.

### RTL-specific patterns used

- root tab shell is forced to RTL
- cards adapt visual-leading placement
- Arabic copy is first-class across onboarding, tribe, captain, and gamification

### Localization caveats

- Some feature names intentionally remain in English even in Arabic mode:
  - `My Vibe`
  - `Zone 2`
  - `Alchemy Kitchen`
  - `Arena`
  - `Tribe`
- This is enforced in Captain prompts as part of brand vocabulary.

### Source evidence

- `AiQo/Core/AiQoAccessibility.swift`
- `AiQo/App/MainTabScreen.swift`
- `AiQo/DesignSystem/Components/AiQoCard.swift`
- `AiQo/Core/Localization/LocalizationManager.swift`
- `AiQo/Resources/ar.lproj/Localizable.strings`
- `AiQo/Resources/en.lproj/Localizable.strings`
- `AiQo/Resources/Prompts.xcstrings`

---

## SECTION 19 — Feature Flags & Configuration

### Primary feature flags in `Info.plist`

- `TRIBE_BACKEND_ENABLED`
  - current value: `false`
- `TRIBE_FEATURE_VISIBLE`
  - current value: `false`
- `TRIBE_SUBSCRIPTION_GATE_ENABLED`
  - current value: `false`

### What each flag controls

- `TRIBE_BACKEND_ENABLED`
  - controls repository factory choice for tribe/challenge repositories.
  - intended to switch between mock and backend repositories.
- `TRIBE_FEATURE_VISIBLE`
  - controls whether Tribe is launch-visible at all.
- `TRIBE_SUBSCRIPTION_GATE_ENABLED`
  - controls whether tribe access requires premium gating when the feature is visible.

### Important reality gap

- The current shipping build disables the Tribe feature entirely through `Info.plist`.
- Even if `TRIBE_BACKEND_ENABLED` were flipped to `true`, the current “Supabase” repositories still forward to mock data and `TribeStore` create/join flows remain stubbed.
- So the flags express launch intent, but not full backend completion.

### Other important configuration values

- URL schemes:
  - `aiqo`
  - `aiqo-spotify`
- queried schemes:
  - `spotify`
  - `instagram-stories`
  - `instagram`
- background modes:
  - `audio`
  - `remote-notification`
  - `fetch`
- background task identifiers:
  - `aiqo.captain.spiritual-whispers.refresh`
  - `aiqo.captain.inactivity-check`
- activity types:
  - walk
  - run
  - HIIT
  - open Captain
  - today summary
  - log water
  - open kitchen
  - weekly report

### Build config files

- `Configuration/AiQo.xcconfig`
- `Configuration/Secrets.xcconfig`
- `Configuration/Secrets.template.xcconfig`

### Secrets risk

- `AiQo.xcconfig` includes `Secrets.xcconfig` and disables explicit modules.
- `Secrets.xcconfig` is present in the repo and contains runtime integration keys/URLs for Gemini, ElevenLabs, Spotify, and Supabase.
- This is a release-risk and security-risk finding if those values are production credentials.

### How to enable / disable launch-sensitive features

- Tribe launch readiness is controlled through the three `TRIBE_*` `Info.plist` flags above.
- Language is controlled through onboarding plus `LocalizationManager` and `AppSettingsStore`.
- Notification-heavy behavior depends on:
  - onboarding completion,
  - notification permissions,
  - `AppSettingsStore.shared.notificationsEnabled`,
  - HealthKit permission flow state.
- Purchase / trial behavior depends on:
  - StoreKit configuration,
  - entitlement state,
  - free-trial state.

### Source evidence

- `AiQo/Info.plist`
- `AiQo/Tribe/Models/TribeFeatureModels.swift`
- `AiQo/Tribe/Repositories/TribeRepositories.swift`
- `AiQo/Tribe/TribeStore.swift`
- `AiQo/Premium/AccessManager.swift`
- `Configuration/AiQo.xcconfig`
- `Configuration/Secrets.xcconfig`
- `Configuration/Secrets.template.xcconfig`

---

## SECTION 20 — Known Issues, Gaps & Roadmap

### Known issue 1 — Tribe launch is disabled and still not production-backed

- `AiQo/Info.plist` currently sets:
  - `TRIBE_BACKEND_ENABLED = false`
  - `TRIBE_FEATURE_VISIBLE = false`
  - `TRIBE_SUBSCRIPTION_GATE_ENABLED = false`
- `AiQo/Tribe/Repositories/TribeRepositories.swift` can instantiate “Supabase” repositories, but those types still delegate to mock repositories.
- `AiQo/Tribe/TribeStore.swift` still uses explicit local stub logic for `createTribe` and `joinTribe`.
- Impact:
  - tribe/arena remain prelaunch code paths rather than production-ready features.

### Known issue 2 — StoreKit config ids do not match the current product-id constants

- `AiQo/Core/Purchases/SubscriptionProductIDs.swift` uses current ids:
  - `aiqo_nr_30d_individual_5_99`
  - `aiqo_nr_30d_family_10_00`
- `AiQo/Resources/AiQo.storekit` and `AiQo/Resources/AiQo_Test.storekit` still contain legacy ids:
  - `aiqo_30d_individual_5_99`
  - `aiqo_30d_family_10_00`
- Impact:
  - local StoreKit testing can drift from the ids the app uses at runtime.

### Known issue 3 — Crashlytics wrapper exists, but checked-in project wiring appears incomplete

- `AiQo/Services/CrashReporting/CrashReportingService.swift` contains a Firebase Crashlytics integration guarded by `canImport(FirebaseCore)` and `canImport(FirebaseCrashlytics)`.
- `AiQo/Services/CrashReporting/CRASHLYTICS_SETUP.md` documents Firebase setup.
- The checked-in Swift package resolution and project package references reviewed in this audit only show Supabase and SDWebImage packages, not Firebase package products.
- Impact:
  - local crash logging works through `CrashReporter`, but Crashlytics may not be active in the current project configuration.

### Known issue 4 — Secrets are stored in checked-in xcconfig files

- `Configuration/Secrets.xcconfig` is present in the repository.
- It contains runtime configuration keys/URLs for cloud integrations.
- Impact:
  - this is a security and release-process risk until secrets are rotated and moved out of version control.

### UI/UX gaps identified from current code

- Tribe and Arena UI exist, but the current build hides them behind disabled launch flags.
- Sleep features are functionally rich but split across Home, Sleep, Captain, and notification services rather than a single cohesive shell.
- Captain routing is strong, but product naming still implies OpenAI/Apple Intelligence breadth that the live cloud path does not fully implement today.

### Missing before TestFlight

- Finish live Tribe/Arena backend integration and remove mock/stub repository behavior.
- Reconcile StoreKit config files with the `aiqo_nr_*` product ids.
- Decide whether Crashlytics is required for TestFlight and wire Firebase packages if yes.
- Remove production secrets from checked-in xcconfig files.

### Missing before App Store launch

- Flip Tribe launch flags only after backend, gating, and deep-link support are fully validated.
- Confirm final monetization copy, legal links, and receipt-validation monitoring in production.
- Set the final App Store category and verify all metadata outside the codebase.
- Run a final Arabic/English localization and accessibility regression pass across onboarding, paywall, Captain, and watch flows.

### Post-launch roadmap items visible from code direction

- Live Tribe and Galaxy social competition.
- Richer Captain background intelligence and notification composition.
- Expanded Apple Intelligence / on-device generation coverage.
- Deeper watch-to-phone workout and recovery sync.

### Source evidence

- `AiQo/Info.plist`
- `AiQo/Tribe/Models/TribeFeatureModels.swift`
- `AiQo/Tribe/Repositories/TribeRepositories.swift`
- `AiQo/Tribe/TribeStore.swift`
- `AiQo/Core/Purchases/SubscriptionProductIDs.swift`
- `AiQo/Resources/AiQo.storekit`
- `AiQo/Resources/AiQo_Test.storekit`
- `AiQo/Services/CrashReporting/CrashReportingService.swift`
- `AiQo/Services/CrashReporting/CRASHLYTICS_SETUP.md`
- `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `Configuration/Secrets.xcconfig`

---

## APPENDIX A — Requested Path Resolution

### App entry and navigation requests

- `AiQo/App/AiQoApp.swift`
  - File not found — actual implementation lives in `AiQo/App/AppDelegate.swift`.
- `AiQo/App/AppDelegate.swift`
  - found
- `AiQo/App/AppFlowController.swift`
  - File not found — actual implementation lives in `AiQo/App/SceneDelegate.swift`.
- `AiQo/App/MainTabRouter.swift`
  - found
- `AiQo/App/AppRootManager.swift`
  - found
- `AiQo/Services/DeepLinkRouter.swift`
  - found

### AI brain and routing requests

- `AiQo/Services/AI/BrainOrchestrator.swift`
  - File not found — actual implementation lives in `AiQo/Features/Captain/BrainOrchestrator.swift`.
- `AiQo/Services/AI/CloudBrainService.swift`
  - File not found — actual implementation lives in `AiQo/Features/Captain/CloudBrainService.swift`.
- `AiQo/Services/AI/LocalBrainService.swift`
  - File not found — actual implementation lives in `AiQo/Features/Captain/LocalBrainService.swift`.
- `AiQo/Services/AI/HybridBrainService.swift`
  - File not found — actual implementation lives in `AiQo/Features/Captain/HybridBrainService.swift`.
- `AiQo/Services/AI/PrivacySanitizer.swift`
  - File not found — actual implementation lives in `AiQo/Features/Captain/PrivacySanitizer.swift`.
- `AiQo/Services/AI/CaptainOnDeviceChatEngine.swift`
  - File not found — actual implementation lives in `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift`.
- `AiQo/Services/AI/AppleIntelligenceSleepAgent.swift`
  - File not found — actual implementation lives in `AiQo/Features/Captain/AppleIntelligenceSleepAgent.swift`.

### Captain / persona requests

- `AiQo/Features/Captain/CaptainViewModel.swift`
  - found
- `AiQo/Features/Captain/CaptainPersonaBuilder.swift`
  - found
- `AiQo/Features/Captain/CaptainPromptBuilder.swift`
  - found
- `AiQo/Features/Captain/CaptainVoiceService.swift`
  - File not found — actual implementation lives in `AiQo/Core/CaptainVoiceService.swift`.
- `AiQo/Features/Captain/CaptainMemoryManager.swift`
  - File not found — actual implementation is split across `AiQo/Core/MemoryStore.swift` and `AiQo/Core/MemoryExtractor.swift`.

### Data-model requests

- `AiQo/Models/*.swift`
  - File not found — models are distributed across `AiQo/Core`, `AiQo/Features`, and `AiQo/Tribe`.
- `AiQo/Data/*.swift`
  - File not found — no top-level `Data` directory exists.

### HealthKit requests

- `AiQo/Services/Health/HealthKitManager.swift`
  - File not found — actual implementation lives in `AiQo/Shared/HealthKitManager.swift`.
- `AiQo/Services/Health/HealthKitPermissionManager.swift`
  - File not found — permission flow is handled in `AiQo/Services/Permissions/HealthKit/HealthKitService.swift` and `AiQo/App/SceneDelegate.swift`.

### Monetization requests

- `AiQo/Services/Monetization/PurchaseManager.swift`
  - File not found — actual implementation lives in `AiQo/Core/Purchases/PurchaseManager.swift`.
- `AiQo/Services/Monetization/FreeTrialManager.swift`
  - File not found — actual implementation lives in `AiQo/Premium/FreeTrialManager.swift`.
- `AiQo/Features/Paywall/*.swift`
  - File not found — actual paywall implementations live in `AiQo/Premium/PremiumPaywallView.swift` and `AiQo/UI/Purchases/PaywallView.swift`.

### Sleep / Arena / Settings requests

- `AiQo/Features/Sleep/*.swift`
  - File not found — capability is distributed across Home, Captain, Shared, and Notifications.
- `AiQo/Features/Arena/*.swift`
  - File not found — actual implementation lives in `AiQo/Tribe/Galaxy` and `AiQo/Tribe/Arena`.
- `AiQo/Features/Settings/*.swift`
  - File not found — actual settings screen lives in `AiQo/Core/AppSettingsScreen.swift`.

### Watch companion request

- `AiQoWatch/*.swift`
  - File not found — actual watch companion files live under `AiQoWatch Watch App/`.

---

## APPENDIX B — UserDefaults Key Inventory

- `didSelectLanguage`
- `didShowFirstAuthScreen`
- `didCompleteDatingProfile`
- `didCompleteLegacyCalculation`
- `didCompleteFeatureIntro`
- `captain_memory_enabled`
- `captain_user_name`
- `captain_user_age`
- `captain_user_height`
- `captain_user_weight`
- `captain_calling`
- `captain_tone`
- `aiqo.captain.pendingMessage`
- `aiqo.user.level`
- `aiqo.user.currentXP`
- `aiqo.user.totalXP`
- `aiqo.currentLevel`
- `aiqo.currentXP`
- `aiqo.user.xp`
- `aiqo.currentLevelProgress`
- `aiqo.legacyTotalPoints`
- `aiqo.levelMigrationDone`
- `lastCelebratedLevel`
- `aiqo.streak.current`
- `aiqo.streak.longest`
- `aiqo.streak.lastActive`
- `aiqo.streak.history`
- `aiqo.freeTrial.startDate`
- `aiqo.purchases.activeProductId`
- `aiqo.purchases.expiresAt`
- `aiqo.userProfile`
- `aiqo.userAvatar`
- `aiqo.user.tribePrivacyMode`
- `user_gender`
- `notificationLanguage`
- `aiqo.notification.language`
- `push_device_token`
- `aiqo.tribe.preview.enabled`
- `aiqo.tribe.preview.useMockData`
- `aiqo.tribe.preview.plan`
- `aiqo.tribe.preview.forceEnabled`
- `aiqo.dailyGoals`
- `aiqo.nutrition.calorieGoal`
- `aiqo.nutrition.proteinGoal`
- `aiqo.nutrition.carbGoal`
- `aiqo.nutrition.fatGoal`
- `aiqo.nutrition.fiberGoal`
- `aiqo.morningHabit.scheduledWakeTimestamp`
- `aiqo.morningHabit.notificationWakeTimestamp`
- `aiqo.morningHabit.cachedInsight`
- `aiqo.sleepObserver.anchorData`
- `aiqo.sleepObserver.lastNotifiedSleepEnd`
- `aiqo.ai.workout.anchor`
- `aiqo.ai.workout.processed.ids`
- `aiqo.quest.earned_achievements`
- `aiqo.gym.quests.daily-state.v3`
- `aiqo.gym.quests.daily-state.v2`
- `aiqo.gym.quests.daily-state.v1`
- `aiqo.gym.quests.wins.v1`
- `aiqo.quests.help-strangers.share-anonymous`
- `aiqo.quest.kitchen.hasMealPlan`
- `aiqo.quest.kitchen.savedAt`
- `aiqo.app.language`
- `aiqo.notifications.enabled`
- `AppleLanguages`
- `appLanguage`
- `coach_language`
- `aiqo.activity.selectedAngelTimes`
- `aiqo.activity.lastScheduleDate`
- `aiqo.activity.yesterdayTimes`
- `aiqo.arena.completedChallenges`
- `aiqo.crash.didTerminateCleanly`

---

## APPENDIX C — Analytics Event Inventory

- `app_launched`
- `app_became_active`
- `app_entered_background`
- `onboarding_step_viewed`
- `onboarding_completed`
- `onboarding_skipped`
- `login_started`
- `login_completed`
- `logout_completed`
- `tab_selected`
- `screen_viewed`
- `captain_chat_opened`
- `captain_message_sent`
- `captain_response_received`
- `captain_response_failed`
- `captain_voice_played`
- `captain_history_viewed`
- `workout_started`
- `workout_completed`
- `workout_cancelled`
- `vision_coach_started`
- `vision_coach_completed`
- `quest_started`
- `quest_completed`
- `kitchen_opened`
- `meal_plan_generated`
- `fridge_item_added`
- `tribe_created`
- `tribe_joined`
- `tribe_left`
- `tribe_leaderboard_viewed`
- `tribe_arena_viewed`
- `spotify_connected`
- `spotify_track_played`
- `health_permission_granted`
- `health_permission_denied`
- `daily_summary_generated`
- `paywall_viewed`
- `subscription_started`
- `subscription_failed`
- `subscription_restored`
- `subscription_cancelled`
- `free_trial_started`
- `notification_permission_granted`
- `notification_permission_denied`
- `notification_tapped`
- `language_changed`
- `memory_cleared`
- `error_occurred`

---

## APPENDIX D — HealthKit Matrix

### Read

- `stepCount`
- `activeEnergyBurned`
- `distanceWalkingRunning`
- `distanceCycling`
- `heartRate`
- `heartRateVariabilitySDNN`
- `restingHeartRate`
- `walkingHeartRateAverage`
- `oxygenSaturation`
- `vo2Max`
- `bodyMass`
- `dietaryWater`
- `appleStandTime`
- `appleStandHour`
- `bodyFatPercentage`
- `leanBodyMass`
- `sleepAnalysis`
- `activitySummaryType`
- `workoutType`

### Write

- `heartRate`
- `heartRateVariabilitySDNN`
- `restingHeartRate`
- `vo2Max`
- `distanceWalkingRunning`
- `dietaryWater`
- `bodyMass`
- `workoutType`

---

## APPENDIX E — `@Model` Inventory

- `AiQoDailyRecord`
  - area: daily dashboard persistence
- `WorkoutTask`
  - area: daily dashboard / workout checklist
- `CaptainMemory`
  - area: long-term Captain memory
- `PersistentChatMessage`
  - area: Captain conversation persistence
- `RecordProject`
  - area: legendary projects
- `WeeklyLog`
  - area: legendary weekly review
- `SmartFridgeScannedItemRecord`
  - area: kitchen scan persistence
- `ArenaTribe`
  - area: arena/tribe local state
- `ArenaTribeMember`
  - area: arena/tribe local state
- `ArenaWeeklyChallenge`
  - area: arena challenge state
- `ArenaTribeParticipation`
  - area: arena challenge participation
- `ArenaEmirateLeaders`
  - area: emirate / leader banners
- `ArenaHallOfFameEntry`
  - area: arena history
- `PlayerStats`
  - area: quest/player progression
- `QuestStage`
  - area: quest structure
- `QuestRecord`
  - area: quest progress
- `Reward`
  - area: quest rewards

---

## APPENDIX F — `find AiQo -maxdepth 4 -type d | sort`

```text
AiQo
AiQo/AiQoCore
AiQo/AiQoCore/AiQoCore.docc
AiQo/App
AiQo/Core
AiQo/Core/Localization
AiQo/Core/Models
AiQo/Core/Purchases
AiQo/Core/Utilities
AiQo/DesignSystem
AiQo/DesignSystem/Components
AiQo/DesignSystem/Modifiers
AiQo/Features
AiQo/Features/Captain
AiQo/Features/DataExport
AiQo/Features/First screen
AiQo/Features/Gym
AiQo/Features/Gym/Club
AiQo/Features/Gym/Club/Body
AiQo/Features/Gym/Club/Challenges
AiQo/Features/Gym/Club/Components
AiQo/Features/Gym/Club/Impact
AiQo/Features/Gym/Club/Plan
AiQo/Features/Gym/Models
AiQo/Features/Gym/QuestKit
AiQo/Features/Gym/QuestKit/Views
AiQo/Features/Gym/Quests
AiQo/Features/Gym/Quests/Models
AiQo/Features/Gym/Quests/Store
AiQo/Features/Gym/Quests/Views
AiQo/Features/Gym/Quests/VisionCoach
AiQo/Features/Gym/T
AiQo/Features/Home
AiQo/Features/Kitchen
AiQo/Features/LegendaryChallenges
AiQo/Features/LegendaryChallenges/Components
AiQo/Features/LegendaryChallenges/Models
AiQo/Features/LegendaryChallenges/ViewModels
AiQo/Features/LegendaryChallenges/Views
AiQo/Features/MyVibe
AiQo/Features/Onboarding
AiQo/Features/Profile
AiQo/Features/ProgressPhotos
AiQo/Features/Tribe
AiQo/Features/WeeklyReport
AiQo/Frameworks
AiQo/Frameworks/SpotifyiOS.framework
AiQo/Frameworks/SpotifyiOS.framework/Headers
AiQo/Frameworks/SpotifyiOS.framework/Modules
AiQo/Premium
AiQo/Resources
AiQo/Resources/Assets.xcassets
AiQo/Resources/Assets.xcassets/1.1.imageset
AiQo/Resources/Assets.xcassets/1.2.imageset
AiQo/Resources/Assets.xcassets/1.3.imageset
AiQo/Resources/Assets.xcassets/1.4.imageset
AiQo/Resources/Assets.xcassets/1.5.imageset
AiQo/Resources/Assets.xcassets/11.imageset
AiQo/Resources/Assets.xcassets/2.1.imageset
AiQo/Resources/Assets.xcassets/2.2.imageset
AiQo/Resources/Assets.xcassets/2.3.imageset
AiQo/Resources/Assets.xcassets/2.4.imageset
AiQo/Resources/Assets.xcassets/2.5.imageset
AiQo/Resources/Assets.xcassets/22.imageset
AiQo/Resources/Assets.xcassets/3.1.imageset
AiQo/Resources/Assets.xcassets/3.2.imageset
AiQo/Resources/Assets.xcassets/3.3.imageset
AiQo/Resources/Assets.xcassets/3.4.imageset
AiQo/Resources/Assets.xcassets/3.5.imageset
AiQo/Resources/Assets.xcassets/4.1.imageset
AiQo/Resources/Assets.xcassets/4.2.imageset
AiQo/Resources/Assets.xcassets/4.3.imageset
AiQo/Resources/Assets.xcassets/4.4.imageset
AiQo/Resources/Assets.xcassets/4.5.imageset
AiQo/Resources/Assets.xcassets/5.1.imageset
AiQo/Resources/Assets.xcassets/5.2.imageset
AiQo/Resources/Assets.xcassets/5.3.imageset
AiQo/Resources/Assets.xcassets/5.4.imageset
AiQo/Resources/Assets.xcassets/5.5.imageset
AiQo/Resources/Assets.xcassets/AccentColor.colorset
AiQo/Resources/Assets.xcassets/AppIcon.appiconset
AiQo/Resources/Assets.xcassets/Captain_Hamoudi_DJ.imageset
AiQo/Resources/Assets.xcassets/ChatUserBubble.colorset
AiQo/Resources/Assets.xcassets/GammaFlow.dataset
AiQo/Resources/Assets.xcassets/Hammoudi5.imageset
AiQo/Resources/Assets.xcassets/Hypnagogic_state.dataset
AiQo/Resources/Assets.xcassets/Kitchenـicon.imageset
AiQo/Resources/Assets.xcassets/Profile-icon.imageset
AiQo/Resources/Assets.xcassets/SerotoninFlow.dataset
AiQo/Resources/Assets.xcassets/SleepRing_Mint.imageset
AiQo/Resources/Assets.xcassets/SleepRing_Orange.imageset
AiQo/Resources/Assets.xcassets/SleepRing_Purple.imageset
AiQo/Resources/Assets.xcassets/SoundOfEnergy.dataset
AiQo/Resources/Assets.xcassets/The.refrigerator.imageset
AiQo/Resources/Assets.xcassets/ThetaTrance.dataset
AiQo/Resources/Assets.xcassets/TribeInviteBackground.imageset
AiQo/Resources/Assets.xcassets/Tribe_icon.imageset
AiQo/Resources/Assets.xcassets/WaterBottle.imageset
AiQo/Resources/Assets.xcassets/imageKitchenHamoudi.imageset
AiQo/Resources/Assets.xcassets/vibe_ icon.imageset
AiQo/Resources/Specs
AiQo/Resources/ar.lproj
AiQo/Resources/en.lproj
AiQo/Services
AiQo/Services/Analytics
AiQo/Services/CrashReporting
AiQo/Services/Notifications
AiQo/Services/Permissions
AiQo/Services/Permissions/HealthKit
AiQo/Shared
AiQo/Tribe
AiQo/Tribe/Arena
AiQo/Tribe/Galaxy
AiQo/Tribe/Log
AiQo/Tribe/Models
AiQo/Tribe/Preview
AiQo/Tribe/Repositories
AiQo/Tribe/Stores
AiQo/Tribe/Views
AiQo/UI
AiQo/UI/Purchases
AiQo/watch
```

---

## APPENDIX G — `find AiQo -maxdepth 4 -type f | sort`

```text
AiQo/.DS_Store
AiQo/AiQo.entitlements
AiQo/AiQoActivityNames.swift
AiQo/AiQoCore/AiQoCore.docc/AiQoCore.md
AiQo/AiQoCore/AiQoCore.h
AiQo/App/AppDelegate.swift
AiQo/App/AppRootManager.swift
AiQo/App/AuthFlowUI.swift
AiQo/App/LanguageSelectionView.swift
AiQo/App/LoginViewController.swift
AiQo/App/MainTabRouter.swift
AiQo/App/MainTabScreen.swift
AiQo/App/MealModels.swift
AiQo/App/ProfileSetupView.swift
AiQo/App/SceneDelegate.swift
AiQo/AppGroupKeys.swift
AiQo/Core/AiQoAccessibility.swift
AiQo/Core/AiQoAudioManager.swift
AiQo/Core/AppSettingsScreen.swift
AiQo/Core/AppSettingsStore.swift
AiQo/Core/ArabicNumberFormatter.swift
AiQo/Core/CaptainMemory.swift
AiQo/Core/CaptainMemorySettingsView.swift
AiQo/Core/CaptainVoiceAPI.swift
AiQo/Core/CaptainVoiceCache.swift
AiQo/Core/CaptainVoiceService.swift
AiQo/Core/Colors.swift
AiQo/Core/Constants.swift
AiQo/Core/DailyGoals.swift
AiQo/Core/DeveloperPanelView.swift
AiQo/Core/HapticEngine.swift
AiQo/Core/HealthKitMemoryBridge.swift
AiQo/Core/Localization/Bundle+Language.swift
AiQo/Core/Localization/LocalizationManager.swift
AiQo/Core/MemoryExtractor.swift
AiQo/Core/MemoryStore.swift
AiQo/Core/Models/ActivityNotification.swift
AiQo/Core/Models/LevelStore.swift
AiQo/Core/Models/NotificationPreferencesStore.swift
AiQo/Core/Purchases/EntitlementStore.swift
AiQo/Core/Purchases/PurchaseManager.swift
AiQo/Core/Purchases/ReceiptValidator.swift
AiQo/Core/Purchases/SubscriptionProductIDs.swift
AiQo/Core/SiriShortcutsManager.swift
AiQo/Core/SmartNotificationScheduler.swift
AiQo/Core/SpotifyVibeManager.swift
AiQo/Core/StreakManager.swift
AiQo/Core/UserProfileStore.swift
AiQo/Core/Utilities/ConnectivityDebugProviding.swift
AiQo/Core/VibeAudioEngine.swift
AiQo/DesignSystem/AiQoColors.swift
AiQo/DesignSystem/AiQoTheme.swift
AiQo/DesignSystem/AiQoTokens.swift
AiQo/DesignSystem/Components/AiQoBottomCTA.swift
AiQo/DesignSystem/Components/AiQoCard.swift
AiQo/DesignSystem/Components/AiQoChoiceGrid.swift
AiQo/DesignSystem/Components/AiQoPillSegment.swift
AiQo/DesignSystem/Components/AiQoPlatformPicker.swift
AiQo/DesignSystem/Components/AiQoSkeletonView.swift
AiQo/DesignSystem/Components/StatefulPreviewWrapper.swift
AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift
AiQo/DesignSystem/Modifiers/AiQoShadow.swift
AiQo/DesignSystem/Modifiers/AiQoSheetStyle.swift
AiQo/Features/Captain/AiQoPromptManager.swift
AiQo/Features/Captain/AppleIntelligenceSleepAgent.swift
AiQo/Features/Captain/BrainOrchestrator.swift
AiQo/Features/Captain/CaptainChatView.swift
AiQo/Features/Captain/CaptainContextBuilder.swift
AiQo/Features/Captain/CaptainFallbackPolicy.swift
AiQo/Features/Captain/CaptainIntelligenceManager.swift
AiQo/Features/Captain/CaptainModels.swift
AiQo/Features/Captain/CaptainNotificationRouting.swift
AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift
AiQo/Features/Captain/CaptainPersonaBuilder.swift
AiQo/Features/Captain/CaptainPromptBuilder.swift
AiQo/Features/Captain/CaptainScreen.swift
AiQo/Features/Captain/CaptainViewModel.swift
AiQo/Features/Captain/ChatHistoryView.swift
AiQo/Features/Captain/CloudBrainService.swift
AiQo/Features/Captain/CoachBrainMiddleware.swift
AiQo/Features/Captain/CoachBrainTranslationConfig.swift
AiQo/Features/Captain/HybridBrainService.swift
AiQo/Features/Captain/LLMJSONParser.swift
AiQo/Features/Captain/LocalBrainService.swift
AiQo/Features/Captain/LocalIntelligenceService.swift
AiQo/Features/Captain/MessageBubble.swift
AiQo/Features/Captain/PrivacySanitizer.swift
AiQo/Features/Captain/PromptRouter.swift
AiQo/Features/Captain/ScreenContext.swift
AiQo/Features/DataExport/HealthDataExporter.swift
AiQo/Features/First screen/LegacyCalculationViewController.swift
AiQo/Features/Gym/ActiveRecoveryView.swift
AiQo/Features/Gym/AudioCoachManager.swift
AiQo/Features/Gym/CinematicGrindCardView.swift
AiQo/Features/Gym/CinematicGrindViews.swift
AiQo/Features/Gym/Club/ClubRootView.swift
AiQo/Features/Gym/ExercisesView.swift
AiQo/Features/Gym/GuinnessEncyclopediaView.swift
AiQo/Features/Gym/GymViewController.swift
AiQo/Features/Gym/HandsFreeZone2Manager.swift
AiQo/Features/Gym/HeartView.swift
AiQo/Features/Gym/L10n.swift
AiQo/Features/Gym/LiveMetricsHeader.swift
AiQo/Features/Gym/LiveWorkoutSession.swift
AiQo/Features/Gym/Models/GymExercise.swift
AiQo/Features/Gym/MyPlanViewController.swift
AiQo/Features/Gym/OriginalWorkoutCardView.swift
AiQo/Features/Gym/PhoneWorkoutSummaryView.swift
AiQo/Features/Gym/QuestKit/QuestDataSources.swift
AiQo/Features/Gym/QuestKit/QuestDefinitions.swift
AiQo/Features/Gym/QuestKit/QuestEngine.swift
AiQo/Features/Gym/QuestKit/QuestEvaluator.swift
AiQo/Features/Gym/QuestKit/QuestFormatting.swift
AiQo/Features/Gym/QuestKit/QuestKitModels.swift
AiQo/Features/Gym/QuestKit/QuestProgressStore.swift
AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift
AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift
AiQo/Features/Gym/Quests/.DS_Store
AiQo/Features/Gym/RecapViewController.swift
AiQo/Features/Gym/RewardsViewController.swift
AiQo/Features/Gym/ShimmeringPlaceholder.swift
AiQo/Features/Gym/SoftGlassCardView.swift
AiQo/Features/Gym/SpotifyWebView.swift
AiQo/Features/Gym/SpotifyWorkoutPlayerView.swift
AiQo/Features/Gym/T/SpinWheelView.swift
AiQo/Features/Gym/T/WheelTypes.swift
AiQo/Features/Gym/T/WorkoutTheme.swift
AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift
AiQo/Features/Gym/WatchConnectionStatusButton.swift
AiQo/Features/Gym/WatchConnectivityService.swift
AiQo/Features/Gym/WinsViewController.swift
AiQo/Features/Gym/WorkoutLiveActivityManager.swift
AiQo/Features/Gym/WorkoutSessionScreen.swift.swift
AiQo/Features/Gym/WorkoutSessionSheetView.swift
AiQo/Features/Gym/WorkoutSessionViewModel.swift
AiQo/Features/Home/ActivityDataProviding.swift
AiQo/Features/Home/AlarmSetupCardView.swift
AiQo/Features/Home/DJCaptainChatView.swift
AiQo/Features/Home/DailyAuraModels.swift
AiQo/Features/Home/DailyAuraPathData.swift
AiQo/Features/Home/DailyAuraView.swift
AiQo/Features/Home/DailyAuraViewModel.swift
AiQo/Features/Home/HealthKitService+Water.swift
AiQo/Features/Home/HomeStatCard.swift
AiQo/Features/Home/HomeView.swift
AiQo/Features/Home/HomeViewModel.swift
AiQo/Features/Home/LevelUpCelebrationView.swift
AiQo/Features/Home/MetricKind.swift
AiQo/Features/Sleep/SleepDetailCardView.swift
AiQo/Features/Sleep/SleepScoreRingView.swift
AiQo/Features/Home/SmartWakeCalculatorView.swift
AiQo/Features/Home/SmartWakeEngine.swift
AiQo/Features/Home/SmartWakeViewModel.swift
AiQo/Features/Home/SpotifyVibeCard.swift
AiQo/Features/Home/StreakBadgeView.swift
AiQo/Features/Home/VibeControlSheet.swift
AiQo/Features/Home/WaterBottleView.swift
AiQo/Features/Home/WaterDetailSheetView.swift
AiQo/Features/Kitchen/CameraView.swift
AiQo/Features/Kitchen/CompositePlateView.swift
AiQo/Features/Kitchen/FridgeInventoryView.swift
AiQo/Features/Kitchen/IngredientAssetCatalog.swift
AiQo/Features/Kitchen/IngredientAssetLibrary.swift
AiQo/Features/Kitchen/IngredientCatalog.swift
AiQo/Features/Kitchen/IngredientDisplayItem.swift
AiQo/Features/Kitchen/IngredientKey.swift
AiQo/Features/Kitchen/InteractiveFridgeView.swift
AiQo/Features/Kitchen/KitchenLanguageRouter.swift
AiQo/Features/Kitchen/KitchenModels.swift
AiQo/Features/Kitchen/KitchenPersistenceStore.swift
AiQo/Features/Kitchen/KitchenPlanGenerationService.swift
AiQo/Features/Kitchen/KitchenSceneView.swift
AiQo/Features/Kitchen/KitchenScreen.swift
AiQo/Features/Kitchen/KitchenView.swift
AiQo/Features/Kitchen/KitchenViewModel.swift
AiQo/Features/Kitchen/LocalMealsRepository.swift
AiQo/Features/Kitchen/Meal.swift
AiQo/Features/Kitchen/MealIllustrationView.swift
AiQo/Features/Kitchen/MealImageSpec.swift
AiQo/Features/Kitchen/MealPlanGenerator.swift
AiQo/Features/Kitchen/MealPlanView.swift
AiQo/Features/Kitchen/MealSectionView.swift
AiQo/Features/Kitchen/MealsRepository.swift
AiQo/Features/Kitchen/NutritionTrackerView.swift
AiQo/Features/Kitchen/PlateTemplate.swift
AiQo/Features/Kitchen/RecipeCardView.swift
AiQo/Features/Kitchen/SmartFridgeCameraPreviewController.swift
AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift
AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift
AiQo/Features/Kitchen/SmartFridgeScannerView.swift
AiQo/Features/Kitchen/meals_data.json
AiQo/Features/LegendaryChallenges/Components/RecordCard.swift
AiQo/Features/LegendaryChallenges/Models/LegendaryProject.swift
AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift
AiQo/Features/LegendaryChallenges/Models/RecordProject.swift
AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift
AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift
AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift
AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift
AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift
AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift
AiQo/Features/LegendaryChallenges/Views/ProjectView.swift
AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift
AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift
AiQo/Features/LegendaryChallenges/Views/WeeklyReviewResultView.swift
AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift
AiQo/Features/MyVibe/DailyVibeState.swift
AiQo/Features/MyVibe/MyVibeScreen.swift
AiQo/Features/MyVibe/MyVibeSubviews.swift
AiQo/Features/MyVibe/MyVibeViewModel.swift
AiQo/Features/MyVibe/VibeOrchestrator.swift
AiQo/Features/Onboarding/FeatureIntroView.swift
AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift
AiQo/Features/Onboarding/OnboardingWalkthroughView.swift
AiQo/Features/Profile/LevelCardView.swift
AiQo/Features/Profile/ProfileScreen.swift
AiQo/Features/Profile/String+Localized.swift
AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift
AiQo/Features/ProgressPhotos/ProgressPhotosView.swift
AiQo/Features/Tribe/TribeDesignSystem.swift
AiQo/Features/Tribe/TribeExperienceFlow.swift
AiQo/Features/Tribe/TribeView.swift
AiQo/Features/WeeklyReport/ShareCardRenderer.swift
AiQo/Features/WeeklyReport/WeeklyReportModel.swift
AiQo/Features/WeeklyReport/WeeklyReportView.swift
AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemote.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteAlbum.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteArtist.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteCommon.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteConnectionParams.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteConnectivityAPI.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteConnectivityState.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteContentAPI.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteContentItem.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteCrossfadeState.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteImageAPI.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteImageRepresentable.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteLibraryState.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemotePlaybackOptions.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemotePlaybackRestrictions.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemotePlayerAPI.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemotePlayerState.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemotePodcastPlaybackSpeed.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteTrack.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteUserAPI.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTAppRemoteUserCapabilities.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTConfiguration.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTError.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTLogin.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTMacros.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTScope.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTSession.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SPTSessionManager.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SpotifyAppRemote.h
AiQo/Frameworks/SpotifyiOS.framework/Headers/SpotifyiOS.h
AiQo/Frameworks/SpotifyiOS.framework/Info.plist
AiQo/Frameworks/SpotifyiOS.framework/Modules/module.modulemap
AiQo/Frameworks/SpotifyiOS.framework/PrivacyInfo.xcprivacy
AiQo/Frameworks/SpotifyiOS.framework/SpotifyiOS
AiQo/Info.plist
AiQo/NeuralMemory.swift
AiQo/PhoneConnectivityManager.swift
AiQo/Premium/AccessManager.swift
AiQo/Premium/EntitlementProvider.swift
AiQo/Premium/FreeTrialManager.swift
AiQo/Premium/PremiumPaywallView.swift
AiQo/Premium/PremiumStore.swift
AiQo/ProtectionModel.swift
AiQo/Resources/.DS_Store
AiQo/Resources/AiQo.storekit
AiQo/Resources/AiQo_Test.storekit
AiQo/Resources/Assets.xcassets/.DS_Store
AiQo/Resources/Assets.xcassets/1.1.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/1.1.imageset/11 Medium (1) Small.png
AiQo/Resources/Assets.xcassets/1.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/1.2.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/1.2.imageset/12 Medium (1) Small.png
AiQo/Resources/Assets.xcassets/1.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/1.3.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/1.3.imageset/13 Medium Small.png
AiQo/Resources/Assets.xcassets/1.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/1.4.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/1.4.imageset/14 Medium Small.png
AiQo/Resources/Assets.xcassets/1.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/1.5.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/1.5.imageset/15 Medium Small.png
AiQo/Resources/Assets.xcassets/1.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/11.imageset/Contents.json
AiQo/Resources/Assets.xcassets/11.imageset/١١١.png
AiQo/Resources/Assets.xcassets/2.1.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/2.1.imageset/8E28D091-8A68-41BB-94C6-FEB2C1B4A461 Medium Small.png
AiQo/Resources/Assets.xcassets/2.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/2.2.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/2.2.imageset/80882F75-B2FC-45FA-8755-80E4B3EA449D Medium Small.png
AiQo/Resources/Assets.xcassets/2.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/2.3.imageset/440FD23C-8CC1-4899-B30E-E760CF9CF03A Medium Small.png
AiQo/Resources/Assets.xcassets/2.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/2.4.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/2.4.imageset/4CB75402-8737-433C-96B8-5E7F112E6379 Medium Small.png
AiQo/Resources/Assets.xcassets/2.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/2.5.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/2.5.imageset/41E0CEE7-EB1A-4F53-90AF-725C42CB66CF Medium Small.png
AiQo/Resources/Assets.xcassets/2.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/22.imageset/22.svg
AiQo/Resources/Assets.xcassets/22.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.1.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/3.1.imageset/3C4CE18F-9016-4511-BC6C-0EF0FDE46843 Small.png
AiQo/Resources/Assets.xcassets/3.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.2.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/3.2.imageset/BC070E06-6FAA-4E5F-AF1F-15BF8F7633E8 Small.png
AiQo/Resources/Assets.xcassets/3.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.3.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/3.3.imageset/27C8AB0E-2DCF-4D99-839C-73C96158C51C Small.png
AiQo/Resources/Assets.xcassets/3.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.4.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/3.4.imageset/0CF368F2-ED9D-4068-BAC9-EE639C3E7699 Small.png
AiQo/Resources/Assets.xcassets/3.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.5.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/3.5.imageset/BCEC565B-7889-4F0C-B1BD-84AF807A1768 Small.png
AiQo/Resources/Assets.xcassets/3.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.1.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/4.1.imageset/A010C193-7CE4-42E1-BE4E-0048F46BC508 Small.png
AiQo/Resources/Assets.xcassets/4.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.2.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/4.2.imageset/8AE18BB4-3014-41D9-B45E-B9BE379B89A6 Small.png
AiQo/Resources/Assets.xcassets/4.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.3.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/4.3.imageset/C608ACBB-61FC-45B0-897E-F246F9EE4B37 Small.png
AiQo/Resources/Assets.xcassets/4.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.4.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/4.4.imageset/5EC324FC-B925-453A-8173-87262B9A69F3 Small.png
AiQo/Resources/Assets.xcassets/4.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.5.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/4.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.5.imageset/D4B8BE50-8447-4BBA-84AD-7C3F6B76D814 Small.png
AiQo/Resources/Assets.xcassets/5.1.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/5.1.imageset/3E0FB6D8-40E2-46A9-BE21-D91EDC5D32F5 Small.png
AiQo/Resources/Assets.xcassets/5.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.2.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/5.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.2.imageset/FB37435D-6E5F-4EC2-AB35-98C9ED99CBFB Small.png
AiQo/Resources/Assets.xcassets/5.3.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/5.3.imageset/A7CF4A63-A50B-48B7-A3EF-151AEE948503 Small.png
AiQo/Resources/Assets.xcassets/5.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.4.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/5.4.imageset/9A6EE89D-F7ED-4427-8C66-35F91D0BF852 Small.png
AiQo/Resources/Assets.xcassets/5.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.5.imageset/.DS_Store
AiQo/Resources/Assets.xcassets/5.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.5.imageset/D96909CA-F297-4790-8D1A-929232BE38E1 Small.png
AiQo/Resources/Assets.xcassets/AccentColor.colorset/Contents.json
AiQo/Resources/Assets.xcassets/AppIcon.appiconset/== 2٠.png
AiQo/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
AiQo/Resources/Assets.xcassets/Captain_Hamoudi_DJ.imageset/3AD949AC-7FF8-4F6F-961E-5C774B865F44.png
AiQo/Resources/Assets.xcassets/Captain_Hamoudi_DJ.imageset/Contents.json
AiQo/Resources/Assets.xcassets/ChatUserBubble.colorset/Contents.json
AiQo/Resources/Assets.xcassets/Contents.json
AiQo/Resources/Assets.xcassets/GammaFlow.dataset/Contents.json
AiQo/Resources/Assets.xcassets/GammaFlow.dataset/GammaFlow.m4a
AiQo/Resources/Assets.xcassets/Hammoudi5.imageset/0A22BFB3-8C68-43C8-A259-7FA0965F70AF.png
AiQo/Resources/Assets.xcassets/Hammoudi5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/Hypnagogic_state.dataset/Contents.json
AiQo/Resources/Assets.xcassets/Hypnagogic_state.dataset/Hypnagogic_state.m4a
AiQo/Resources/Assets.xcassets/Kitchenـicon.imageset/831993C0-6749-493B-B62F-47E52D1509B1.png
AiQo/Resources/Assets.xcassets/Kitchenـicon.imageset/Contents.json
AiQo/Resources/Assets.xcassets/Profile-icon.imageset/Contents.json
AiQo/Resources/Assets.xcassets/Profile-icon.imageset/Profile-icon.png
AiQo/Resources/Assets.xcassets/SerotoninFlow.dataset/Contents.json
AiQo/Resources/Assets.xcassets/SerotoninFlow.dataset/SerotoninFlow.m4a
AiQo/Resources/Assets.xcassets/SleepRing_Mint.imageset/Contents.json
AiQo/Resources/Assets.xcassets/SleepRing_Mint.imageset/SleepRing_Mint.png
AiQo/Resources/Assets.xcassets/SleepRing_Orange.imageset/Contents.json
AiQo/Resources/Assets.xcassets/SleepRing_Orange.imageset/SleepRing_Orange.png
AiQo/Resources/Assets.xcassets/SleepRing_Purple.imageset/Contents.json
AiQo/Resources/Assets.xcassets/SleepRing_Purple.imageset/SleepRing_Purple.png
AiQo/Resources/Assets.xcassets/SoundOfEnergy.dataset/Contents.json
AiQo/Resources/Assets.xcassets/SoundOfEnergy.dataset/SoundOfEnergy.m4a
AiQo/Resources/Assets.xcassets/The.refrigerator.imageset/9926DC39-28AF-4248-9FAC-A1B11D9038DC.png
AiQo/Resources/Assets.xcassets/The.refrigerator.imageset/Contents.json
AiQo/Resources/Assets.xcassets/ThetaTrance.dataset/Contents.json
AiQo/Resources/Assets.xcassets/ThetaTrance.dataset/ThetaTrance.m4a
AiQo/Resources/Assets.xcassets/TribeInviteBackground.imageset/Contents.json
AiQo/Resources/Assets.xcassets/TribeInviteBackground.imageset/TribeInviteBackground.png
AiQo/Resources/Assets.xcassets/Tribe_icon.imageset/C6A0B0EC-79D6-413D-9263-BC134974BE13 2.png
AiQo/Resources/Assets.xcassets/Tribe_icon.imageset/Contents.json
AiQo/Resources/Assets.xcassets/WaterBottle.imageset/Contents.json
AiQo/Resources/Assets.xcassets/WaterBottle.imageset/WaterBottle.png
AiQo/Resources/Assets.xcassets/imageKitchenHamoudi.imageset/AADFA8D4-67AD-49AC-BDAC-C7068940D734.png
AiQo/Resources/Assets.xcassets/imageKitchenHamoudi.imageset/Contents.json
AiQo/Resources/Assets.xcassets/vibe_ icon.imageset/6F8750EA-DAC5-450B-8D71-126FFA304533.png
AiQo/Resources/Assets.xcassets/vibe_ icon.imageset/Contents.json
AiQo/Resources/Prompts.xcstrings
AiQo/Resources/Specs/achievements_spec.json
AiQo/Resources/ar.lproj/.DS_Store
AiQo/Resources/ar.lproj/InfoPlist.strings
AiQo/Resources/ar.lproj/Localizable.strings
AiQo/Resources/en.lproj/.DS_Store
AiQo/Resources/en.lproj/InfoPlist.strings
AiQo/Resources/en.lproj/Localizable.strings
AiQo/Services/AiQoError.swift
AiQo/Services/Analytics/AnalyticsEvent.swift
AiQo/Services/Analytics/AnalyticsService.swift
AiQo/Services/CrashReporting/CRASHLYTICS_SETUP.md
AiQo/Services/CrashReporting/CrashReporter.swift
AiQo/Services/CrashReporting/CrashReportingService.swift
AiQo/Services/DeepLinkRouter.swift
AiQo/Services/NetworkMonitor.swift
AiQo/Services/NotificationType.swift
AiQo/Services/Notifications/ActivityNotificationEngine.swift
AiQo/Services/Notifications/AlarmSchedulingService.swift
AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift
AiQo/Services/Notifications/InactivityTracker.swift
AiQo/Services/Notifications/MorningHabitOrchestrator.swift
AiQo/Services/Notifications/NotificationCategoryManager.swift
AiQo/Services/Notifications/NotificationIntelligenceManager.swift
AiQo/Services/Notifications/NotificationRepository.swift
AiQo/Services/Notifications/NotificationService.swift
AiQo/Services/Notifications/PremiumExpiryNotifier.swift
AiQo/Features/Sleep/SleepSessionObserver.swift
AiQo/Services/Notifications/SmartNotificationManager.swift
AiQo/Services/Permissions/HealthKit/HealthKitService.swift
AiQo/Services/Permissions/HealthKit/TodaySummary.swift
AiQo/Services/ReferralManager.swift
AiQo/Services/SupabaseArenaService.swift
AiQo/Services/SupabaseService.swift
AiQo/Shared/CoinManager.swift
AiQo/Shared/HealthKitManager.swift
AiQo/Features/Sleep/HealthManager+Sleep.swift
AiQo/Shared/LevelSystem.swift
AiQo/Shared/WorkoutSyncCodec.swift
AiQo/Shared/WorkoutSyncModels.swift
AiQo/Tribe/Arena/TribeArenaView.swift
AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift
AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift
AiQo/Tribe/Galaxy/ArenaModels.swift
AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift
AiQo/Tribe/Galaxy/ArenaScreen.swift
AiQo/Tribe/Galaxy/ArenaTabView.swift
AiQo/Tribe/Galaxy/ArenaViewModel.swift
AiQo/Tribe/Galaxy/BattleLeaderboard.swift
AiQo/Tribe/Galaxy/BattleLeaderboardRow.swift
AiQo/Tribe/Galaxy/ConstellationCanvasView.swift
AiQo/Tribe/Galaxy/CountdownTimerView.swift
AiQo/Tribe/Galaxy/CreateTribeSheet.swift
AiQo/Tribe/Galaxy/EditTribeNameSheet.swift
AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift
AiQo/Tribe/Galaxy/EmirateLeadersBanner.swift
AiQo/Tribe/Galaxy/GalaxyCanvasView.swift
AiQo/Tribe/Galaxy/GalaxyHUD.swift
AiQo/Tribe/Galaxy/GalaxyLayout.swift
AiQo/Tribe/Galaxy/GalaxyModels.swift
AiQo/Tribe/Galaxy/GalaxyNodeCard.swift
AiQo/Tribe/Galaxy/GalaxyScreen.swift
AiQo/Tribe/Galaxy/GalaxyView.swift
AiQo/Tribe/Galaxy/GalaxyViewModel.swift
AiQo/Tribe/Galaxy/HallOfFameFullView.swift
AiQo/Tribe/Galaxy/HallOfFameSection.swift
AiQo/Tribe/Galaxy/InviteCardView.swift
AiQo/Tribe/Galaxy/JoinTribeSheet.swift
AiQo/Tribe/Galaxy/MockArenaData.swift
AiQo/Tribe/Galaxy/TribeEmptyState.swift
AiQo/Tribe/Galaxy/TribeHeroCard.swift
AiQo/Tribe/Galaxy/TribeInviteView.swift
AiQo/Tribe/Galaxy/TribeLogScreen.swift
AiQo/Tribe/Galaxy/TribeMemberRow.swift
AiQo/Tribe/Galaxy/TribeMembersList.swift
AiQo/Tribe/Galaxy/TribeRingView.swift
AiQo/Tribe/Galaxy/TribeTabView.swift
AiQo/Tribe/Galaxy/WeeklyChallengeCard.swift
AiQo/Tribe/Log/TribeLogView.swift
AiQo/Tribe/Models/TribeFeatureModels.swift
AiQo/Tribe/Models/TribeModels.swift
AiQo/Tribe/Preview/TribePreviewController.swift
AiQo/Tribe/Preview/TribePreviewData.swift
AiQo/Tribe/Repositories/TribeRepositories.swift
AiQo/Tribe/Stores/ArenaStore.swift
AiQo/Tribe/Stores/GalaxyStore.swift
AiQo/Tribe/Stores/TribeLogStore.swift
AiQo/Tribe/TribeModuleComponents.swift
AiQo/Tribe/TribeModuleModels.swift
AiQo/Tribe/TribeModuleViewModel.swift
AiQo/Tribe/TribePulseScreenView.swift
AiQo/Tribe/TribeScreen.swift
AiQo/Tribe/TribeStore.swift
AiQo/Tribe/Views/GlobalTribeRadialView.swift
AiQo/Tribe/Views/TribeAtomRingView.swift
AiQo/Tribe/Views/TribeEnergyCoreCard.swift
AiQo/Tribe/Views/TribeHubScreen.swift
AiQo/Tribe/Views/TribeLeaderboardView.swift
AiQo/UI/AccessibilityHelpers.swift
AiQo/UI/AiQoProfileButton.swift
AiQo/UI/AiQoScreenHeader.swift
AiQo/UI/ErrorToastView.swift
AiQo/UI/GlassCardView.swift
AiQo/UI/LegalView.swift
AiQo/UI/OfflineBannerView.swift
AiQo/UI/Purchases/PaywallView.swift
AiQo/UI/ReferralSettingsRow.swift
AiQo/XPCalculator.swift
AiQo/watch/ConnectivityDiagnosticsView.swift
```

---

## APPENDIX H — Live source/config inventory (`AiQo`, watch, widgets, config)

```text
AiQo/AiQoActivityNames.swift
AiQo/App/AppDelegate.swift
AiQo/App/AppRootManager.swift
AiQo/App/AuthFlowUI.swift
AiQo/App/LanguageSelectionView.swift
AiQo/App/LoginViewController.swift
AiQo/App/MainTabRouter.swift
AiQo/App/MainTabScreen.swift
AiQo/App/MealModels.swift
AiQo/App/ProfileSetupView.swift
AiQo/App/SceneDelegate.swift
AiQo/AppGroupKeys.swift
AiQo/Core/AiQoAccessibility.swift
AiQo/Core/AiQoAudioManager.swift
AiQo/Core/AppSettingsScreen.swift
AiQo/Core/AppSettingsStore.swift
AiQo/Core/ArabicNumberFormatter.swift
AiQo/Core/CaptainMemory.swift
AiQo/Core/CaptainMemorySettingsView.swift
AiQo/Core/CaptainVoiceAPI.swift
AiQo/Core/CaptainVoiceCache.swift
AiQo/Core/CaptainVoiceService.swift
AiQo/Core/Colors.swift
AiQo/Core/Constants.swift
AiQo/Core/DailyGoals.swift
AiQo/Core/DeveloperPanelView.swift
AiQo/Core/HapticEngine.swift
AiQo/Core/HealthKitMemoryBridge.swift
AiQo/Core/Localization/Bundle+Language.swift
AiQo/Core/Localization/LocalizationManager.swift
AiQo/Core/MemoryExtractor.swift
AiQo/Core/MemoryStore.swift
AiQo/Core/Models/ActivityNotification.swift
AiQo/Core/Models/LevelStore.swift
AiQo/Core/Models/NotificationPreferencesStore.swift
AiQo/Core/Purchases/EntitlementStore.swift
AiQo/Core/Purchases/PurchaseManager.swift
AiQo/Core/Purchases/ReceiptValidator.swift
AiQo/Core/Purchases/SubscriptionProductIDs.swift
AiQo/Core/SiriShortcutsManager.swift
AiQo/Core/SmartNotificationScheduler.swift
AiQo/Core/SpotifyVibeManager.swift
AiQo/Core/StreakManager.swift
AiQo/Core/UserProfileStore.swift
AiQo/Core/Utilities/ConnectivityDebugProviding.swift
AiQo/Core/VibeAudioEngine.swift
AiQo/DesignSystem/AiQoColors.swift
AiQo/DesignSystem/AiQoTheme.swift
AiQo/DesignSystem/AiQoTokens.swift
AiQo/DesignSystem/Components/AiQoBottomCTA.swift
AiQo/DesignSystem/Components/AiQoCard.swift
AiQo/DesignSystem/Components/AiQoChoiceGrid.swift
AiQo/DesignSystem/Components/AiQoPillSegment.swift
AiQo/DesignSystem/Components/AiQoPlatformPicker.swift
AiQo/DesignSystem/Components/AiQoSkeletonView.swift
AiQo/DesignSystem/Components/StatefulPreviewWrapper.swift
AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift
AiQo/DesignSystem/Modifiers/AiQoShadow.swift
AiQo/DesignSystem/Modifiers/AiQoSheetStyle.swift
AiQo/Features/Captain/AiQoPromptManager.swift
AiQo/Features/Captain/AppleIntelligenceSleepAgent.swift
AiQo/Features/Captain/BrainOrchestrator.swift
AiQo/Features/Captain/CaptainChatView.swift
AiQo/Features/Captain/CaptainContextBuilder.swift
AiQo/Features/Captain/CaptainFallbackPolicy.swift
AiQo/Features/Captain/CaptainIntelligenceManager.swift
AiQo/Features/Captain/CaptainModels.swift
AiQo/Features/Captain/CaptainNotificationRouting.swift
AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift
AiQo/Features/Captain/CaptainPersonaBuilder.swift
AiQo/Features/Captain/CaptainPromptBuilder.swift
AiQo/Features/Captain/CaptainScreen.swift
AiQo/Features/Captain/CaptainViewModel.swift
AiQo/Features/Captain/ChatHistoryView.swift
AiQo/Features/Captain/CloudBrainService.swift
AiQo/Features/Captain/CoachBrainMiddleware.swift
AiQo/Features/Captain/CoachBrainTranslationConfig.swift
AiQo/Features/Captain/HybridBrainService.swift
AiQo/Features/Captain/LLMJSONParser.swift
AiQo/Features/Captain/LocalBrainService.swift
AiQo/Features/Captain/LocalIntelligenceService.swift
AiQo/Features/Captain/MessageBubble.swift
AiQo/Features/Captain/PrivacySanitizer.swift
AiQo/Features/Captain/PromptRouter.swift
AiQo/Features/Captain/ScreenContext.swift
AiQo/Features/DataExport/HealthDataExporter.swift
AiQo/Features/First screen/LegacyCalculationViewController.swift
AiQo/Features/Gym/ActiveRecoveryView.swift
AiQo/Features/Gym/AudioCoachManager.swift
AiQo/Features/Gym/CinematicGrindCardView.swift
AiQo/Features/Gym/CinematicGrindViews.swift
AiQo/Features/Gym/Club/Body/BodyView.swift
AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift
AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift
AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift
AiQo/Features/Gym/Club/Challenges/ChallengesView.swift
AiQo/Features/Gym/Club/ClubRootView.swift
AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift
AiQo/Features/Gym/Club/Components/RailScrollOffsetPreferenceKey.swift
AiQo/Features/Gym/Club/Components/RightSideRailView.swift
AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift
AiQo/Features/Gym/Club/Components/SegmentedTabs.swift
AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift
AiQo/Features/Gym/Club/Impact/ImpactAchievementsView.swift
AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift
AiQo/Features/Gym/Club/Impact/ImpactSummaryView.swift
AiQo/Features/Gym/Club/Plan/PlanView.swift
AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift
AiQo/Features/Gym/ExercisesView.swift
AiQo/Features/Gym/GuinnessEncyclopediaView.swift
AiQo/Features/Gym/GymViewController.swift
AiQo/Features/Gym/HandsFreeZone2Manager.swift
AiQo/Features/Gym/HeartView.swift
AiQo/Features/Gym/L10n.swift
AiQo/Features/Gym/LiveMetricsHeader.swift
AiQo/Features/Gym/LiveWorkoutSession.swift
AiQo/Features/Gym/Models/GymExercise.swift
AiQo/Features/Gym/MyPlanViewController.swift
AiQo/Features/Gym/OriginalWorkoutCardView.swift
AiQo/Features/Gym/PhoneWorkoutSummaryView.swift
AiQo/Features/Gym/QuestKit/QuestDataSources.swift
AiQo/Features/Gym/QuestKit/QuestDefinitions.swift
AiQo/Features/Gym/QuestKit/QuestEngine.swift
AiQo/Features/Gym/QuestKit/QuestEvaluator.swift
AiQo/Features/Gym/QuestKit/QuestFormatting.swift
AiQo/Features/Gym/QuestKit/QuestKitModels.swift
AiQo/Features/Gym/QuestKit/QuestProgressStore.swift
AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift
AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift
AiQo/Features/Gym/QuestKit/Views/QuestCameraPermissionGateView.swift
AiQo/Features/Gym/QuestKit/Views/QuestDebugView.swift
AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift
AiQo/Features/Gym/Quests/Models/Challenge.swift
AiQo/Features/Gym/Quests/Models/ChallengeStage.swift
AiQo/Features/Gym/Quests/Models/HelpStrangersModels.swift
AiQo/Features/Gym/Quests/Models/WinRecord.swift
AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift
AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift
AiQo/Features/Gym/Quests/Store/WinsStore.swift
AiQo/Features/Gym/Quests/Views/ChallengeCard.swift
AiQo/Features/Gym/Quests/Views/ChallengeDetailView.swift
AiQo/Features/Gym/Quests/Views/ChallengeRewardSheet.swift
AiQo/Features/Gym/Quests/Views/ChallengeRunView.swift
AiQo/Features/Gym/Quests/Views/HelpStrangersBottomSheet.swift
AiQo/Features/Gym/Quests/Views/QuestCard.swift
AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift
AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift
AiQo/Features/Gym/Quests/Views/QuestDetailView.swift
AiQo/Features/Gym/Quests/Views/QuestWinsGridView.swift
AiQo/Features/Gym/Quests/Views/QuestsView.swift
AiQo/Features/Gym/Quests/Views/StageSelectorBar.swift
AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift
AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift
AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift
AiQo/Features/Gym/RecapViewController.swift
AiQo/Features/Gym/RewardsViewController.swift
AiQo/Features/Gym/ShimmeringPlaceholder.swift
AiQo/Features/Gym/SoftGlassCardView.swift
AiQo/Features/Gym/SpotifyWebView.swift
AiQo/Features/Gym/SpotifyWorkoutPlayerView.swift
AiQo/Features/Gym/T/SpinWheelView.swift
AiQo/Features/Gym/T/WheelTypes.swift
AiQo/Features/Gym/T/WorkoutTheme.swift
AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift
AiQo/Features/Gym/WatchConnectionStatusButton.swift
AiQo/Features/Gym/WatchConnectivityService.swift
AiQo/Features/Gym/WinsViewController.swift
AiQo/Features/Gym/WorkoutLiveActivityManager.swift
AiQo/Features/Gym/WorkoutSessionScreen.swift.swift
AiQo/Features/Gym/WorkoutSessionSheetView.swift
AiQo/Features/Gym/WorkoutSessionViewModel.swift
AiQo/Features/Home/ActivityDataProviding.swift
AiQo/Features/Home/AlarmSetupCardView.swift
AiQo/Features/Home/DJCaptainChatView.swift
AiQo/Features/Home/DailyAuraModels.swift
AiQo/Features/Home/DailyAuraPathData.swift
AiQo/Features/Home/DailyAuraView.swift
AiQo/Features/Home/DailyAuraViewModel.swift
AiQo/Features/Home/HealthKitService+Water.swift
AiQo/Features/Home/HomeStatCard.swift
AiQo/Features/Home/HomeView.swift
AiQo/Features/Home/HomeViewModel.swift
AiQo/Features/Home/LevelUpCelebrationView.swift
AiQo/Features/Home/MetricKind.swift
AiQo/Features/Sleep/SleepDetailCardView.swift
AiQo/Features/Sleep/SleepScoreRingView.swift
AiQo/Features/Home/SmartWakeCalculatorView.swift
AiQo/Features/Home/SmartWakeEngine.swift
AiQo/Features/Home/SmartWakeViewModel.swift
AiQo/Features/Home/SpotifyVibeCard.swift
AiQo/Features/Home/StreakBadgeView.swift
AiQo/Features/Home/VibeControlSheet.swift
AiQo/Features/Home/WaterBottleView.swift
AiQo/Features/Home/WaterDetailSheetView.swift
AiQo/Features/Kitchen/CameraView.swift
AiQo/Features/Kitchen/CompositePlateView.swift
AiQo/Features/Kitchen/FridgeInventoryView.swift
AiQo/Features/Kitchen/IngredientAssetCatalog.swift
AiQo/Features/Kitchen/IngredientAssetLibrary.swift
AiQo/Features/Kitchen/IngredientCatalog.swift
AiQo/Features/Kitchen/IngredientDisplayItem.swift
AiQo/Features/Kitchen/IngredientKey.swift
AiQo/Features/Kitchen/InteractiveFridgeView.swift
AiQo/Features/Kitchen/KitchenLanguageRouter.swift
AiQo/Features/Kitchen/KitchenModels.swift
AiQo/Features/Kitchen/KitchenPersistenceStore.swift
AiQo/Features/Kitchen/KitchenPlanGenerationService.swift
AiQo/Features/Kitchen/KitchenSceneView.swift
AiQo/Features/Kitchen/KitchenScreen.swift
AiQo/Features/Kitchen/KitchenView.swift
AiQo/Features/Kitchen/KitchenViewModel.swift
AiQo/Features/Kitchen/LocalMealsRepository.swift
AiQo/Features/Kitchen/Meal.swift
AiQo/Features/Kitchen/MealIllustrationView.swift
AiQo/Features/Kitchen/MealImageSpec.swift
AiQo/Features/Kitchen/MealPlanGenerator.swift
AiQo/Features/Kitchen/MealPlanView.swift
AiQo/Features/Kitchen/MealSectionView.swift
AiQo/Features/Kitchen/MealsRepository.swift
AiQo/Features/Kitchen/NutritionTrackerView.swift
AiQo/Features/Kitchen/PlateTemplate.swift
AiQo/Features/Kitchen/RecipeCardView.swift
AiQo/Features/Kitchen/SmartFridgeCameraPreviewController.swift
AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift
AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift
AiQo/Features/Kitchen/SmartFridgeScannerView.swift
AiQo/Features/Kitchen/meals_data.json
AiQo/Features/LegendaryChallenges/Components/RecordCard.swift
AiQo/Features/LegendaryChallenges/Models/LegendaryProject.swift
AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift
AiQo/Features/LegendaryChallenges/Models/RecordProject.swift
AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift
AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift
AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift
AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift
AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift
AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift
AiQo/Features/LegendaryChallenges/Views/ProjectView.swift
AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift
AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift
AiQo/Features/LegendaryChallenges/Views/WeeklyReviewResultView.swift
AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift
AiQo/Features/MyVibe/DailyVibeState.swift
AiQo/Features/MyVibe/MyVibeScreen.swift
AiQo/Features/MyVibe/MyVibeSubviews.swift
AiQo/Features/MyVibe/MyVibeViewModel.swift
AiQo/Features/MyVibe/VibeOrchestrator.swift
AiQo/Features/Onboarding/FeatureIntroView.swift
AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift
AiQo/Features/Onboarding/OnboardingWalkthroughView.swift
AiQo/Features/Profile/LevelCardView.swift
AiQo/Features/Profile/ProfileScreen.swift
AiQo/Features/Profile/String+Localized.swift
AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift
AiQo/Features/ProgressPhotos/ProgressPhotosView.swift
AiQo/Features/Tribe/TribeDesignSystem.swift
AiQo/Features/Tribe/TribeExperienceFlow.swift
AiQo/Features/Tribe/TribeView.swift
AiQo/Features/WeeklyReport/ShareCardRenderer.swift
AiQo/Features/WeeklyReport/WeeklyReportModel.swift
AiQo/Features/WeeklyReport/WeeklyReportView.swift
AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift
AiQo/Frameworks/SpotifyiOS.framework/Info.plist
AiQo/Info.plist
AiQo/NeuralMemory.swift
AiQo/PhoneConnectivityManager.swift
AiQo/Premium/AccessManager.swift
AiQo/Premium/EntitlementProvider.swift
AiQo/Premium/FreeTrialManager.swift
AiQo/Premium/PremiumPaywallView.swift
AiQo/Premium/PremiumStore.swift
AiQo/ProtectionModel.swift
AiQo/Resources/Assets.xcassets/1.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/1.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/1.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/1.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/1.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/11.imageset/Contents.json
AiQo/Resources/Assets.xcassets/2.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/2.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/2.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/2.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/2.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/22.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/3.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/4.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.1.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.2.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.3.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.4.imageset/Contents.json
AiQo/Resources/Assets.xcassets/5.5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/AccentColor.colorset/Contents.json
AiQo/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
AiQo/Resources/Assets.xcassets/Captain_Hamoudi_DJ.imageset/Contents.json
AiQo/Resources/Assets.xcassets/ChatUserBubble.colorset/Contents.json
AiQo/Resources/Assets.xcassets/Contents.json
AiQo/Resources/Assets.xcassets/GammaFlow.dataset/Contents.json
AiQo/Resources/Assets.xcassets/Hammoudi5.imageset/Contents.json
AiQo/Resources/Assets.xcassets/Hypnagogic_state.dataset/Contents.json
AiQo/Resources/Assets.xcassets/Kitchenـicon.imageset/Contents.json
AiQo/Resources/Assets.xcassets/Profile-icon.imageset/Contents.json
AiQo/Resources/Assets.xcassets/SerotoninFlow.dataset/Contents.json
AiQo/Resources/Assets.xcassets/SleepRing_Mint.imageset/Contents.json
AiQo/Resources/Assets.xcassets/SleepRing_Orange.imageset/Contents.json
AiQo/Resources/Assets.xcassets/SleepRing_Purple.imageset/Contents.json
AiQo/Resources/Assets.xcassets/SoundOfEnergy.dataset/Contents.json
AiQo/Resources/Assets.xcassets/The.refrigerator.imageset/Contents.json
AiQo/Resources/Assets.xcassets/ThetaTrance.dataset/Contents.json
AiQo/Resources/Assets.xcassets/TribeInviteBackground.imageset/Contents.json
AiQo/Resources/Assets.xcassets/Tribe_icon.imageset/Contents.json
AiQo/Resources/Assets.xcassets/WaterBottle.imageset/Contents.json
AiQo/Resources/Assets.xcassets/imageKitchenHamoudi.imageset/Contents.json
AiQo/Resources/Assets.xcassets/vibe_ icon.imageset/Contents.json
AiQo/Resources/Specs/achievements_spec.json
AiQo/Services/AiQoError.swift
AiQo/Services/Analytics/AnalyticsEvent.swift
AiQo/Services/Analytics/AnalyticsService.swift
AiQo/Services/CrashReporting/CrashReporter.swift
AiQo/Services/CrashReporting/CrashReportingService.swift
AiQo/Services/DeepLinkRouter.swift
AiQo/Services/NetworkMonitor.swift
AiQo/Services/NotificationType.swift
AiQo/Services/Notifications/ActivityNotificationEngine.swift
AiQo/Services/Notifications/AlarmSchedulingService.swift
AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift
AiQo/Services/Notifications/InactivityTracker.swift
AiQo/Services/Notifications/MorningHabitOrchestrator.swift
AiQo/Services/Notifications/NotificationCategoryManager.swift
AiQo/Services/Notifications/NotificationIntelligenceManager.swift
AiQo/Services/Notifications/NotificationRepository.swift
AiQo/Services/Notifications/NotificationService.swift
AiQo/Services/Notifications/PremiumExpiryNotifier.swift
AiQo/Features/Sleep/SleepSessionObserver.swift
AiQo/Services/Notifications/SmartNotificationManager.swift
AiQo/Services/Permissions/HealthKit/HealthKitService.swift
AiQo/Services/Permissions/HealthKit/TodaySummary.swift
AiQo/Services/ReferralManager.swift
AiQo/Services/SupabaseArenaService.swift
AiQo/Services/SupabaseService.swift
AiQo/Shared/CoinManager.swift
AiQo/Shared/HealthKitManager.swift
AiQo/Features/Sleep/HealthManager+Sleep.swift
AiQo/Shared/LevelSystem.swift
AiQo/Shared/WorkoutSyncCodec.swift
AiQo/Shared/WorkoutSyncModels.swift
AiQo/Tribe/Arena/TribeArenaView.swift
AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift
AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift
AiQo/Tribe/Galaxy/ArenaModels.swift
AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift
AiQo/Tribe/Galaxy/ArenaScreen.swift
AiQo/Tribe/Galaxy/ArenaTabView.swift
AiQo/Tribe/Galaxy/ArenaViewModel.swift
AiQo/Tribe/Galaxy/BattleLeaderboard.swift
AiQo/Tribe/Galaxy/BattleLeaderboardRow.swift
AiQo/Tribe/Galaxy/ConstellationCanvasView.swift
AiQo/Tribe/Galaxy/CountdownTimerView.swift
AiQo/Tribe/Galaxy/CreateTribeSheet.swift
AiQo/Tribe/Galaxy/EditTribeNameSheet.swift
AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift
AiQo/Tribe/Galaxy/EmirateLeadersBanner.swift
AiQo/Tribe/Galaxy/GalaxyCanvasView.swift
AiQo/Tribe/Galaxy/GalaxyHUD.swift
AiQo/Tribe/Galaxy/GalaxyLayout.swift
AiQo/Tribe/Galaxy/GalaxyModels.swift
AiQo/Tribe/Galaxy/GalaxyNodeCard.swift
AiQo/Tribe/Galaxy/GalaxyScreen.swift
AiQo/Tribe/Galaxy/GalaxyView.swift
AiQo/Tribe/Galaxy/GalaxyViewModel.swift
AiQo/Tribe/Galaxy/HallOfFameFullView.swift
AiQo/Tribe/Galaxy/HallOfFameSection.swift
AiQo/Tribe/Galaxy/InviteCardView.swift
AiQo/Tribe/Galaxy/JoinTribeSheet.swift
AiQo/Tribe/Galaxy/MockArenaData.swift
AiQo/Tribe/Galaxy/TribeEmptyState.swift
AiQo/Tribe/Galaxy/TribeHeroCard.swift
AiQo/Tribe/Galaxy/TribeInviteView.swift
AiQo/Tribe/Galaxy/TribeLogScreen.swift
AiQo/Tribe/Galaxy/TribeMemberRow.swift
AiQo/Tribe/Galaxy/TribeMembersList.swift
AiQo/Tribe/Galaxy/TribeRingView.swift
AiQo/Tribe/Galaxy/TribeTabView.swift
AiQo/Tribe/Galaxy/WeeklyChallengeCard.swift
AiQo/Tribe/Log/TribeLogView.swift
AiQo/Tribe/Models/TribeFeatureModels.swift
AiQo/Tribe/Models/TribeModels.swift
AiQo/Tribe/Preview/TribePreviewController.swift
AiQo/Tribe/Preview/TribePreviewData.swift
AiQo/Tribe/Repositories/TribeRepositories.swift
AiQo/Tribe/Stores/ArenaStore.swift
AiQo/Tribe/Stores/GalaxyStore.swift
AiQo/Tribe/Stores/TribeLogStore.swift
AiQo/Tribe/TribeModuleComponents.swift
AiQo/Tribe/TribeModuleModels.swift
AiQo/Tribe/TribeModuleViewModel.swift
AiQo/Tribe/TribePulseScreenView.swift
AiQo/Tribe/TribeScreen.swift
AiQo/Tribe/TribeStore.swift
AiQo/Tribe/Views/GlobalTribeRadialView.swift
AiQo/Tribe/Views/TribeAtomRingView.swift
AiQo/Tribe/Views/TribeEnergyCoreCard.swift
AiQo/Tribe/Views/TribeHubScreen.swift
AiQo/Tribe/Views/TribeLeaderboardView.swift
AiQo/UI/AccessibilityHelpers.swift
AiQo/UI/AiQoProfileButton.swift
AiQo/UI/AiQoScreenHeader.swift
AiQo/UI/ErrorToastView.swift
AiQo/UI/GlassCardView.swift
AiQo/UI/LegalView.swift
AiQo/UI/OfflineBannerView.swift
AiQo/UI/Purchases/PaywallView.swift
AiQo/UI/ReferralSettingsRow.swift
AiQo/XPCalculator.swift
AiQo/watch/ConnectivityDiagnosticsView.swift
AiQoWatch Watch App/ActivityRingsView.swift
AiQoWatch Watch App/AiQoWatchApp.swift
AiQoWatch Watch App/Assets.xcassets/AccentColor.colorset/Contents.json
AiQoWatch Watch App/Assets.xcassets/AiQoLogo.imageset/Contents.json
AiQoWatch Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json
AiQoWatch Watch App/Assets.xcassets/Contents.json
AiQoWatch Watch App/ControlsView.swift
AiQoWatch Watch App/Design/WatchDesignSystem.swift
AiQoWatch Watch App/ElapsedTimeView.swift
AiQoWatch Watch App/MetricsView.swift
AiQoWatch Watch App/Models/WatchWorkoutType.swift
AiQoWatch Watch App/Services/WatchConnectivityService.swift
AiQoWatch Watch App/Services/WatchHealthKitManager.swift
AiQoWatch Watch App/Services/WatchWorkoutManager.swift
AiQoWatch Watch App/SessionPagingView.swift
AiQoWatch Watch App/StartView.swift
AiQoWatch Watch App/SummaryView.swift
AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift
AiQoWatch Watch App/Views/WatchHomeView.swift
AiQoWatch Watch App/Views/WatchWorkoutListView.swift
AiQoWatch Watch App/Views/WatchWorkoutSummaryView.swift
AiQoWatch Watch App/WatchConnectivityManager.swift
AiQoWatch Watch App/WorkoutManager.swift
AiQoWatch Watch App/WorkoutNotificationCenter.swift
AiQoWatch Watch App/WorkoutNotificationController.swift
AiQoWatch Watch App/WorkoutNotificationView.swift
AiQoWatchWidget/AiQoWatchWidget.swift
AiQoWatchWidget/AiQoWatchWidgetBundle.swift
AiQoWatchWidget/AiQoWatchWidgetProvider.swift
AiQoWatchWidget/Assets.xcassets/AiQoLogo.imageset/Contents.json
AiQoWatchWidget/Assets.xcassets/Contents.json
AiQoWatchWidget/Info.plist
AiQoWidget/AiQoEntry.swift
AiQoWidget/AiQoProvider.swift
AiQoWidget/AiQoRingsFaceWidget.swift
AiQoWidget/AiQoSharedStore.swift
AiQoWidget/AiQoWatchFaceWidget.swift
AiQoWidget/AiQoWidget.swift
AiQoWidget/AiQoWidgetBundle.swift
AiQoWidget/AiQoWidgetLiveActivity.swift
AiQoWidget/AiQoWidgetView.swift
AiQoWidget/Assets.xcassets/AccentColor.colorset/Contents.json
AiQoWidget/Assets.xcassets/AppIcon.appiconset/Contents.json
AiQoWidget/Assets.xcassets/Contents.json
AiQoWidget/Assets.xcassets/WidgetBackground.colorset/Contents.json
AiQoWidget/Info.plist
Configuration/AiQo.xcconfig
Configuration/ExternalSymbols/SpotifyiOS.framework.dSYM/Contents/Info.plist
Configuration/Secrets.xcconfig
```

---

## APPENDIX I — `find . -maxdepth 4 -type d | sort`

```text
.
./.claude
./.claude/worktrees
./.claude/worktrees/hopeful-feistel
./.claude/worktrees/hopeful-feistel/.claude
./.claude/worktrees/hopeful-feistel/.codex
./.claude/worktrees/hopeful-feistel/AiQo
./.claude/worktrees/hopeful-feistel/AiQo.xcodeproj
./.claude/worktrees/hopeful-feistel/AiQoTests
./.claude/worktrees/hopeful-feistel/AiQoWatch Watch App
./.claude/worktrees/hopeful-feistel/AiQoWatch Watch AppTests
./.claude/worktrees/hopeful-feistel/AiQoWatch Watch AppUITests
./.claude/worktrees/hopeful-feistel/AiQoWatchWidget
./.claude/worktrees/hopeful-feistel/AiQoWidget
./.claude/worktrees/hopeful-feistel/Configuration
./.codex
./.codex/environments
./.git
./.git/backup-invalid-refs
./.git/cursor
./.git/cursor/crepe
./.git/cursor/crepe/f0a1a51ac2ffc4b308fdb344f88c4f12c42e2e1e
./.git/hooks
./.git/info
./.git/logs
./.git/logs/refs
./.git/logs/refs/heads
./.git/logs/refs/remotes
./.git/objects
./.git/objects/00
./.git/objects/01
./.git/objects/02
./.git/objects/03
./.git/objects/04
./.git/objects/05
./.git/objects/06
./.git/objects/07
./.git/objects/08
./.git/objects/09
./.git/objects/0a
./.git/objects/0b
./.git/objects/0c
./.git/objects/0d
./.git/objects/0e
./.git/objects/0f
./.git/objects/10
./.git/objects/11
./.git/objects/12
./.git/objects/13
./.git/objects/14
./.git/objects/15
./.git/objects/16
./.git/objects/17
./.git/objects/18
./.git/objects/19
./.git/objects/1a
./.git/objects/1b
./.git/objects/1c
./.git/objects/1d
./.git/objects/1e
./.git/objects/1f
./.git/objects/20
./.git/objects/21
./.git/objects/22
./.git/objects/23
./.git/objects/24
./.git/objects/25
./.git/objects/26
./.git/objects/27
./.git/objects/28
./.git/objects/29
./.git/objects/2a
./.git/objects/2b
./.git/objects/2c
./.git/objects/2d
./.git/objects/2e
./.git/objects/2f
./.git/objects/30
./.git/objects/31
./.git/objects/32
./.git/objects/33
./.git/objects/34
./.git/objects/35
./.git/objects/36
./.git/objects/37
./.git/objects/38
./.git/objects/39
./.git/objects/3a
./.git/objects/3b
./.git/objects/3c
./.git/objects/3d
./.git/objects/3e
./.git/objects/3f
./.git/objects/40
./.git/objects/41
./.git/objects/42
./.git/objects/43
./.git/objects/44
./.git/objects/45
./.git/objects/46
./.git/objects/47
./.git/objects/48
./.git/objects/49
./.git/objects/4a
./.git/objects/4b
./.git/objects/4c
./.git/objects/4d
./.git/objects/4e
./.git/objects/4f
./.git/objects/50
./.git/objects/51
./.git/objects/52
./.git/objects/53
./.git/objects/54
./.git/objects/55
./.git/objects/56
./.git/objects/57
./.git/objects/58
./.git/objects/59
./.git/objects/5a
./.git/objects/5b
./.git/objects/5c
./.git/objects/5d
./.git/objects/5e
./.git/objects/5f
./.git/objects/60
./.git/objects/61
./.git/objects/62
./.git/objects/63
./.git/objects/64
./.git/objects/65
./.git/objects/66
./.git/objects/67
./.git/objects/68
./.git/objects/69
./.git/objects/6a
./.git/objects/6b
./.git/objects/6c
./.git/objects/6d
./.git/objects/6e
./.git/objects/6f
./.git/objects/70
./.git/objects/71
./.git/objects/72
./.git/objects/73
./.git/objects/74
./.git/objects/75
./.git/objects/76
./.git/objects/77
./.git/objects/78
./.git/objects/79
./.git/objects/7a
./.git/objects/7b
./.git/objects/7c
./.git/objects/7d
./.git/objects/7e
./.git/objects/7f
./.git/objects/80
./.git/objects/81
./.git/objects/82
./.git/objects/83
./.git/objects/84
./.git/objects/85
./.git/objects/86
./.git/objects/87
./.git/objects/88
./.git/objects/89
./.git/objects/8a
./.git/objects/8b
./.git/objects/8c
./.git/objects/8d
./.git/objects/8e
./.git/objects/8f
./.git/objects/90
./.git/objects/91
./.git/objects/92
./.git/objects/93
./.git/objects/94
./.git/objects/95
./.git/objects/96
./.git/objects/97
./.git/objects/98
./.git/objects/99
./.git/objects/9a
./.git/objects/9b
./.git/objects/9c
./.git/objects/9d
./.git/objects/9e
./.git/objects/9f
./.git/objects/a0
./.git/objects/a1
./.git/objects/a2
./.git/objects/a3
./.git/objects/a4
./.git/objects/a5
./.git/objects/a6
./.git/objects/a7
./.git/objects/a8
./.git/objects/a9
./.git/objects/aa
./.git/objects/ab
./.git/objects/ac
./.git/objects/ad
./.git/objects/ae
./.git/objects/af
./.git/objects/b0
./.git/objects/b1
./.git/objects/b2
./.git/objects/b3
./.git/objects/b4
./.git/objects/b5
./.git/objects/b6
./.git/objects/b7
./.git/objects/b8
./.git/objects/b9
./.git/objects/ba
./.git/objects/bb
./.git/objects/bc
./.git/objects/bd
./.git/objects/be
./.git/objects/bf
./.git/objects/c0
./.git/objects/c1
./.git/objects/c2
./.git/objects/c3
./.git/objects/c4
./.git/objects/c5
./.git/objects/c6
./.git/objects/c7
./.git/objects/c8
./.git/objects/c9
./.git/objects/ca
./.git/objects/cb
./.git/objects/cc
./.git/objects/cd
./.git/objects/ce
./.git/objects/cf
./.git/objects/d0
./.git/objects/d1
./.git/objects/d2
./.git/objects/d3
./.git/objects/d4
./.git/objects/d5
./.git/objects/d6
./.git/objects/d7
./.git/objects/d8
./.git/objects/d9
./.git/objects/da
./.git/objects/db
./.git/objects/dc
./.git/objects/dd
./.git/objects/de
./.git/objects/df
./.git/objects/e0
./.git/objects/e1
./.git/objects/e2
./.git/objects/e3
./.git/objects/e4
./.git/objects/e5
./.git/objects/e6
./.git/objects/e7
./.git/objects/e8
./.git/objects/e9
./.git/objects/ea
./.git/objects/eb
./.git/objects/ec
./.git/objects/ed
./.git/objects/ee
./.git/objects/ef
./.git/objects/f0
./.git/objects/f1
./.git/objects/f2
./.git/objects/f3
./.git/objects/f4
./.git/objects/f5
./.git/objects/f6
./.git/objects/f7
./.git/objects/f8
./.git/objects/f9
./.git/objects/fa
./.git/objects/fb
./.git/objects/fc
./.git/objects/fd
./.git/objects/fe
./.git/objects/ff
./.git/objects/info
./.git/objects/pack
./.git/refs
./.git/refs/heads
./.git/refs/heads/claude
./.git/refs/remotes
./.git/refs/remotes/origin
./.git/refs/tags
./.git/worktrees
./.git/worktrees/hopeful-feistel
./.git/worktrees/hopeful-feistel/logs
./.git/worktrees/hopeful-feistel/refs
./AiQo
./AiQo.xcodeproj
./AiQo.xcodeproj/project.xcworkspace
./AiQo.xcodeproj/project.xcworkspace/xcshareddata
./AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
./AiQo.xcodeproj/project.xcworkspace/xcuserdata
./AiQo.xcodeproj/project.xcworkspace/xcuserdata/mohammedraad.xcuserdatad
./AiQo.xcodeproj/xcshareddata
./AiQo.xcodeproj/xcshareddata/xcschemes
./AiQo.xcodeproj/xcuserdata
./AiQo.xcodeproj/xcuserdata/mohammedraad.xcuserdatad
./AiQo.xcodeproj/xcuserdata/mohammedraad.xcuserdatad/xcdebugger
./AiQo.xcodeproj/xcuserdata/mohammedraad.xcuserdatad/xcschemes
./AiQo/AiQoCore
./AiQo/AiQoCore/AiQoCore.docc
./AiQo/App
./AiQo/Core
./AiQo/Core/Localization
./AiQo/Core/Models
./AiQo/Core/Purchases
./AiQo/Core/Utilities
./AiQo/DesignSystem
./AiQo/DesignSystem/Components
./AiQo/DesignSystem/Modifiers
./AiQo/Features
./AiQo/Features/Captain
./AiQo/Features/DataExport
./AiQo/Features/First screen
./AiQo/Features/Gym
./AiQo/Features/Gym/Club
./AiQo/Features/Gym/Models
./AiQo/Features/Gym/QuestKit
./AiQo/Features/Gym/Quests
./AiQo/Features/Gym/T
./AiQo/Features/Home
./AiQo/Features/Kitchen
./AiQo/Features/LegendaryChallenges
./AiQo/Features/LegendaryChallenges/Components
./AiQo/Features/LegendaryChallenges/Models
./AiQo/Features/LegendaryChallenges/ViewModels
./AiQo/Features/LegendaryChallenges/Views
./AiQo/Features/MyVibe
./AiQo/Features/Onboarding
./AiQo/Features/Profile
./AiQo/Features/ProgressPhotos
./AiQo/Features/Tribe
./AiQo/Features/WeeklyReport
./AiQo/Frameworks
./AiQo/Frameworks/SpotifyiOS.framework
./AiQo/Frameworks/SpotifyiOS.framework/Headers
./AiQo/Frameworks/SpotifyiOS.framework/Modules
./AiQo/Premium
./AiQo/Resources
./AiQo/Resources/Assets.xcassets
./AiQo/Resources/Assets.xcassets/1.1.imageset
./AiQo/Resources/Assets.xcassets/1.2.imageset
./AiQo/Resources/Assets.xcassets/1.3.imageset
./AiQo/Resources/Assets.xcassets/1.4.imageset
./AiQo/Resources/Assets.xcassets/1.5.imageset
./AiQo/Resources/Assets.xcassets/11.imageset
./AiQo/Resources/Assets.xcassets/2.1.imageset
./AiQo/Resources/Assets.xcassets/2.2.imageset
./AiQo/Resources/Assets.xcassets/2.3.imageset
./AiQo/Resources/Assets.xcassets/2.4.imageset
./AiQo/Resources/Assets.xcassets/2.5.imageset
./AiQo/Resources/Assets.xcassets/22.imageset
./AiQo/Resources/Assets.xcassets/3.1.imageset
./AiQo/Resources/Assets.xcassets/3.2.imageset
./AiQo/Resources/Assets.xcassets/3.3.imageset
./AiQo/Resources/Assets.xcassets/3.4.imageset
./AiQo/Resources/Assets.xcassets/3.5.imageset
./AiQo/Resources/Assets.xcassets/4.1.imageset
./AiQo/Resources/Assets.xcassets/4.2.imageset
./AiQo/Resources/Assets.xcassets/4.3.imageset
./AiQo/Resources/Assets.xcassets/4.4.imageset
./AiQo/Resources/Assets.xcassets/4.5.imageset
./AiQo/Resources/Assets.xcassets/5.1.imageset
./AiQo/Resources/Assets.xcassets/5.2.imageset
./AiQo/Resources/Assets.xcassets/5.3.imageset
./AiQo/Resources/Assets.xcassets/5.4.imageset
./AiQo/Resources/Assets.xcassets/5.5.imageset
./AiQo/Resources/Assets.xcassets/AccentColor.colorset
./AiQo/Resources/Assets.xcassets/AppIcon.appiconset
./AiQo/Resources/Assets.xcassets/Captain_Hamoudi_DJ.imageset
./AiQo/Resources/Assets.xcassets/ChatUserBubble.colorset
./AiQo/Resources/Assets.xcassets/GammaFlow.dataset
./AiQo/Resources/Assets.xcassets/Hammoudi5.imageset
./AiQo/Resources/Assets.xcassets/Hypnagogic_state.dataset
./AiQo/Resources/Assets.xcassets/Kitchenـicon.imageset
./AiQo/Resources/Assets.xcassets/Profile-icon.imageset
./AiQo/Resources/Assets.xcassets/SerotoninFlow.dataset
./AiQo/Resources/Assets.xcassets/SleepRing_Mint.imageset
./AiQo/Resources/Assets.xcassets/SleepRing_Orange.imageset
./AiQo/Resources/Assets.xcassets/SleepRing_Purple.imageset
./AiQo/Resources/Assets.xcassets/SoundOfEnergy.dataset
./AiQo/Resources/Assets.xcassets/The.refrigerator.imageset
./AiQo/Resources/Assets.xcassets/ThetaTrance.dataset
./AiQo/Resources/Assets.xcassets/TribeInviteBackground.imageset
./AiQo/Resources/Assets.xcassets/Tribe_icon.imageset
./AiQo/Resources/Assets.xcassets/WaterBottle.imageset
./AiQo/Resources/Assets.xcassets/imageKitchenHamoudi.imageset
./AiQo/Resources/Assets.xcassets/vibe_ icon.imageset
./AiQo/Resources/Specs
./AiQo/Resources/ar.lproj
./AiQo/Resources/en.lproj
./AiQo/Services
./AiQo/Services/Analytics
./AiQo/Services/CrashReporting
./AiQo/Services/Notifications
./AiQo/Services/Permissions
./AiQo/Services/Permissions/HealthKit
./AiQo/Shared
./AiQo/Tribe
./AiQo/Tribe/Arena
./AiQo/Tribe/Galaxy
./AiQo/Tribe/Log
./AiQo/Tribe/Models
./AiQo/Tribe/Preview
./AiQo/Tribe/Repositories
./AiQo/Tribe/Stores
./AiQo/Tribe/Views
./AiQo/UI
./AiQo/UI/Purchases
./AiQo/watch
./AiQoTests
./AiQoUITests
./AiQoWatch Watch App
./AiQoWatch Watch App/Assets.xcassets
./AiQoWatch Watch App/Assets.xcassets/AccentColor.colorset
./AiQoWatch Watch App/Assets.xcassets/AiQoLogo.imageset
./AiQoWatch Watch App/Assets.xcassets/AppIcon.appiconset
./AiQoWatch Watch App/Design
./AiQoWatch Watch App/Models
./AiQoWatch Watch App/Services
./AiQoWatch Watch App/Shared
./AiQoWatch Watch App/Views
./AiQoWatch Watch AppTests
./AiQoWatch Watch AppUITests
./AiQoWatchWidget
./AiQoWatchWidget/Assets.xcassets
./AiQoWatchWidget/Assets.xcassets/AiQoLogo.imageset
./AiQoWidget
./AiQoWidget/Assets.xcassets
./AiQoWidget/Assets.xcassets/AccentColor.colorset
./AiQoWidget/Assets.xcassets/AppIcon.appiconset
./AiQoWidget/Assets.xcassets/WidgetBackground.colorset
./Configuration
./Configuration/ExternalSymbols
./Configuration/ExternalSymbols/SpotifyiOS.framework.dSYM
./Configuration/ExternalSymbols/SpotifyiOS.framework.dSYM/Contents
```
