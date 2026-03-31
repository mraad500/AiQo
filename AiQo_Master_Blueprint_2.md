# AiQo Master Blueprint 2

Generated from the checked-in project at `/Users/mohammedraad/Desktop/untitled folder/AiQo`.

Initial discovery command returned `719` candidate `.swift` / `.plist` / `.xcconfig` / `.json` files.

This blueprint excludes auxiliary `.git` / `.claude` directories and documents the live project tree across `482` scanned source/config files and `153` scanned directories.

Every section below is derived from the current codebase, project settings, resources, or configuration files.

Where the requested path did not exist, the blueprint calls that out explicitly instead of inventing structure.

## SECTION 1 — App Identity & Philosophy

### Code-Sourced Identity

Product name: `AiQo`.

Observed coach/persona name: `Captain Hamoudi` / `حمّودي`; spelling varies slightly across files, but the persona is consistent.

Observed target domain: wellness, workouts, kitchen/nutrition, sleep, habit formation, vibe/music, and tribe/community accountability.

Tagline: not found in the checked-in source; this still needs a product-marketing source of truth outside code.

Bundle identifier: `com.mraad500.aiqo`.

Inference from code, not explicit product copy: the app is aimed at Arabic-speaking users who want a coaching-led, privacy-aware lifestyle operating system rather than a single-purpose tracker.

### Product Principles Visible in Code

`Zero Digital Pollution` is explicitly referenced in `MemoryStore` cleanup comments and `LegacyCalculationViewController` persistence comments.

`Privacy-first` is visible in `PrivacySanitizer`, local HealthKit aggregation, on-device sleep analysis, and cloud-safe memory filtering.

`Iraqi Arabic persona` is enforced in `CaptainPromptBuilder`, `CaptainOnDeviceChatEngine`, `LocalBrainService`, and multiple UI strings.

`Circadian-aware` behavior is implemented by `CaptainContextBuilder` and consumed by `CaptainPromptBuilder` for tone shaping.

### Languages and RTL

Supported app languages found in code: `ar` and `en`.

Arabic is the default language in `AppSettingsStore` and in the initial language-selection screen.

RTL strategy is active at the app shell level through `AppRootView`, and many screens also force `.rightToLeft` explicitly.

Some layout-heavy components intentionally switch specific subtrees back to `.leftToRight` for charts, rails, or control affordances.

### Platform / Category

App Store category: not found in project files; this is an App Store Connect concern, not a code setting in this repo.

Configured iOS deployment target(s) found in project settings: `26.1, 26.2`.

Configured watchOS deployment target(s) found in project settings: `26.2`.

Project marketing version(s): `1.0`.

Project build number(s): `1`.

### Evidence Files

- `AiQo/App/AppDelegate.swift`

- `AiQo/App/SceneDelegate.swift`

- `AiQo/Core/AppSettingsStore.swift`

- `AiQo/Core/Localization/LocalizationManager.swift`

- `AiQo/Features/Captain/CaptainPromptBuilder.swift`

- `AiQo/Features/Captain/CaptainContextBuilder.swift`

- `AiQo/Info.plist`

- `AiQo.xcodeproj/project.pbxproj`

## SECTION 2 — Tech Stack & Dependencies

### Language / UI Stack

Swift version configured in the project: `5.0`.

UI framework: `SwiftUI` across the primary app, watch app, and widgets.

Persistence stack: `SwiftData` plus targeted `UserDefaults`, Keychain-backed free-trial storage, and local file storage for analytics/crashes/progress photos.

Backend/auth stack: `supabase-swift` for auth, database access, and RPC usage.

Store stack: `StoreKit 2` with server-side receipt validation via a Supabase Edge Function.

Health stack: `HealthKit` with app-side aggregation and watch-side workout/metrics collection.

AI stack: `FoundationModels` / Apple Intelligence on-device, Google Gemini HTTP endpoints for cloud inference, and ElevenLabs for premium voice playback.

### SPM Dependencies With Versions

- `sdwebimage` -> `5.21.6`

- `sdwebimageswiftui` -> `3.1.4`

- `supabase-swift` -> `2.36.0`

- `swift-asn1` -> `1.5.0`

- `swift-clocks` -> `1.0.6`

- `swift-concurrency-extras` -> `1.3.2`

- `swift-crypto` -> `4.2.0`

- `swift-http-types` -> `1.4.0`

- `swift-system` -> `1.6.4`

- `xctest-dynamic-overlay` -> `1.7.0`

CocoaPods: no `Podfile` or `Pods/` dependency graph is present in the live project root used for this blueprint.

Vendored framework: `AiQo/Frameworks/SpotifyiOS.framework`.

### External APIs / Services Actually Referenced

Google Gemini / Generative Language API is the active cloud LLM path for Captain, smart fridge image reasoning, weekly review text generation, and spiritual whispers.

Supabase is used for authentication, profiles, tribe/arena data, device-token sync, account deletion RPC, and receipt-validation edge logic.

ElevenLabs is used for Captain Hamoudi voice synthesis and cached playback assets.

Spotify is used through `SpotifyiOS.framework`, app URL schemes, and vibe/workout playback helpers.

OpenAI: no active OpenAI SDK or endpoint usage was found in the current codebase; the only explicit `OpenAI` string is an instruction telling the model never to mention it.

### Apple / System Frameworks Imported In Source

- `AVFoundation`

- `AVKit`

- `ActivityKit`

- `AlarmKit`

- `AppIntents`

- `Auth`

- `AuthenticationServices`

- `BackgroundTasks`

- `Charts`

- `Combine`

- `CoreGraphics`

- `CoreMedia`

- `CoreSpotlight`

- `CryptoKit`

- `DeviceActivity`

- `FamilyControls`

- `Foundation`

- `FoundationModels`

- `HealthKit`

- `ImageIO`

- `Intents`

- `ManagedSettings`

- `MediaPlayer`

- `MessageUI`

- `Network`

- `ObjectiveC`

- `Observation`

- `PDFKit`

- `PhotosUI`

- `Security`

- `Speech`

- `SpotifyiOS`

- `StoreKit`

- `Supabase`

- `SwiftData`

- `SwiftUI`

- `UIKit`

- `UniformTypeIdentifiers`

- `UserNotifications`

- `Vision`

- `WatchConnectivity`

- `WebKit`

- `WidgetKit`

- `os`

### Configuration Surfaces

Secrets are injected through `Configuration/AiQo.xcconfig` + `Configuration/Secrets.xcconfig`.

Runtime plist placeholders include `CAPTAIN_API_KEY`, `CAPTAIN_ARABIC_API_URL`, `CAPTAIN_VOICE_*`, `COACH_BRAIN_LLM_*`, `SUPABASE_*`, `SPOTIFY_CLIENT_ID`, and tribe feature flags.

### Evidence Files

- `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- `AiQo.xcodeproj/project.pbxproj`

- `AiQo/Info.plist`

- `Configuration/AiQo.xcconfig`

- `Configuration/Secrets.xcconfig`

- `AiQo/Frameworks/SpotifyiOS.framework/Info.plist`

## SECTION 3 — Project File Structure

### Structure Summary

The checked-in app is organized by target first, then by feature/domain.

The main iPhone app lives under `AiQo/`.

The watch companion lives under `AiQoWatch Watch App/`.

Widgets live under `AiQoWidget/` and `AiQoWatchWidget/`.

Tests live under `AiQoTests/`, `AiQoUITests/`, `AiQoWatch Watch AppTests/`, and `AiQoWatch Watch AppUITests/`.

Configuration is centralized under `Configuration/`.

Naming is mostly feature-oriented: `Features/Home`, `Features/Gym`, `Features/Kitchen`, `Features/Captain`, `Features/MyVibe`, `Features/Profile`, `Features/Tribe`, plus `Core`, `Services`, `Shared`, `UI`, and `DesignSystem`.

### Naming / Organization Conventions

App shell and boot code is colocated under `AiQo/App/`.

Reusable state stores and utilities live under `AiQo/Core/`.

Backend/network primitives mostly live under `AiQo/Services/`.

Cross-target shared HealthKit/watch sync utilities live under `AiQo/Shared/`.

There is no single `Models/` folder; model types are distributed by feature and subsystem.

There is no single `Extensions/` folder; extensions are colocated near usage sites.

### Requested Paths That Do Not Match The Real Tree

- `AiQo/App/AiQoApp.swift` -> Real @main entry is `AiQo/App/AppDelegate.swift`.

- `AiQo/App/AppFlowController.swift` -> Real `AppFlowController` is declared inside `AiQo/App/SceneDelegate.swift`.

- `AiQo/Services/AI/BrainOrchestrator.swift` -> Real file is `AiQo/Features/Captain/BrainOrchestrator.swift`.

- `AiQo/Services/AI/CloudBrainService.swift` -> Real file is `AiQo/Features/Captain/CloudBrainService.swift`.

- `AiQo/Services/AI/LocalBrainService.swift` -> Real file is `AiQo/Features/Captain/LocalBrainService.swift`.

- `AiQo/Services/AI/HybridBrainService.swift` -> Real file is `AiQo/Features/Captain/HybridBrainService.swift`.

- `AiQo/Services/AI/PrivacySanitizer.swift` -> Real file is `AiQo/Features/Captain/PrivacySanitizer.swift`.

- `AiQo/Services/AI/CaptainOnDeviceChatEngine.swift` -> Real file is `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift`.

- `AiQo/Services/AI/AppleIntelligenceSleepAgent.swift` -> Real file is `AiQo/Features/Captain/AppleIntelligenceSleepAgent.swift`.

- `AiQo/Features/Captain/CaptainVoiceService.swift` -> Real voice services live under `AiQo/Core/`.

- `AiQo/Features/Captain/CaptainMemoryManager.swift` -> Equivalent memory logic is split across `AiQo/Core/MemoryStore.swift` and `AiQo/Core/CaptainMemory.swift`.

- `AiQo/Models/*.swift` -> Folder not found — needs to be created if the team wants a dedicated models folder.

- `AiQo/Data/*.swift` -> Folder not found — needs to be created if the team wants a dedicated data layer folder.

- `AiQo/Services/Health/HealthKitManager.swift` -> Real files are `AiQo/Shared/HealthKitManager.swift` and `AiQo/Services/Permissions/HealthKit/HealthKitService.swift`.

- `AiQo/Services/Health/HealthKitPermissionManager.swift` -> File not found — permission gating is embedded in `HealthKitService` and onboarding flow.

- `AiQo/Services/Monetization/PurchaseManager.swift` -> Real file is `AiQo/Core/Purchases/PurchaseManager.swift`.

- `AiQo/Services/Monetization/FreeTrialManager.swift` -> Real file is `AiQo/Premium/FreeTrialManager.swift`.

- `AiQo/Features/Paywall/*.swift` -> Paywall views live in `AiQo/Premium/` and `AiQo/UI/Purchases/`.

- `AiQo/Features/Sleep/*.swift` -> No standalone sleep feature folder — sleep code is distributed across Home, Captain, Shared, and Notifications.

- `AiQo/Features/Arena/*.swift` -> Arena lives inside `AiQo/Tribe/Galaxy/` and `AiQo/Features/Tribe/`.

- `AiQo/Features/Settings/*.swift` -> Settings UI lives in `AiQo/Core/AppSettingsScreen.swift`.

- `AiQo/Services/Gamification/XPEngine.swift` -> File not found — XP is split across `LevelStore`, `XPCalculator`, onboarding sync, and quest systems.

- `AiQo/Services/Gamification/BadgeEngine.swift` -> File not found — badge catalog currently ships as `AiQo/Resources/Specs/achievements_spec.json`.

- `AiQo/Services/Background/*.swift` -> No standalone background folder — background logic lives under `AiQo/Services/Notifications/` plus app boot code.

- `AiQo/Services/SmartNotificationScheduler.swift` -> Real file is `AiQo/Core/SmartNotificationScheduler.swift`.

- `AiQo/Services/Backend/SupabaseManager.swift` -> Equivalent backend logic is in `AiQo/Services/SupabaseService.swift` and `AiQo/Services/SupabaseArenaService.swift`.

- `AiQo/Services/Backend/SupabaseClient.swift` -> File not found — `SupabaseClient` is instantiated inside `SupabaseService`.

- `AiQo/Components/*.swift` -> Component library lives under `AiQo/DesignSystem/Components/` and `AiQo/UI/`.

- `AiQo/Extensions/*.swift` -> No dedicated extensions folder — extensions are colocated under module folders and `AiQo/Core/Localization`.

- `AiQo/*.xcconfig` -> Root-level xcconfig files are not present; config files live under `Configuration/`.

- `AiQoWatch/*.swift` -> Watch companion files live under `AiQoWatch Watch App/`.

### Directory Tree (depth <= 4, live source tree only)

- `.`

- `.codex`

- `.codex/environments`

- `AiQo`

- `AiQo/AiQoCore`

- `AiQo/AiQoCore/AiQoCore.docc`

- `AiQo/App`

- `AiQo/Core`

- `AiQo/Core/Localization`

- `AiQo/Core/Models`

- `AiQo/Core/Purchases`

- `AiQo/Core/Utilities`

- `AiQo/DesignSystem`

- `AiQo/DesignSystem/Components`

- `AiQo/DesignSystem/Modifiers`

- `AiQo/Features`

- `AiQo/Features/Captain`

- `AiQo/Features/DataExport`

- `AiQo/Features/First screen`

- `AiQo/Features/Gym`

- `AiQo/Features/Gym/Club`

- `AiQo/Features/Gym/Models`

- `AiQo/Features/Gym/QuestKit`

- `AiQo/Features/Gym/Quests`

- `AiQo/Features/Gym/T`

- `AiQo/Features/Home`

- `AiQo/Features/Kitchen`

- `AiQo/Features/LegendaryChallenges`

- `AiQo/Features/LegendaryChallenges/Components`

- `AiQo/Features/LegendaryChallenges/Models`

- `AiQo/Features/LegendaryChallenges/ViewModels`

- `AiQo/Features/LegendaryChallenges/Views`

- `AiQo/Features/MyVibe`

- `AiQo/Features/Onboarding`

- `AiQo/Features/Profile`

- `AiQo/Features/ProgressPhotos`

- `AiQo/Features/Tribe`

- `AiQo/Features/WeeklyReport`

- `AiQo/Frameworks`

- `AiQo/Frameworks/SpotifyiOS.framework`

- `AiQo/Frameworks/SpotifyiOS.framework/Headers`

- `AiQo/Frameworks/SpotifyiOS.framework/Modules`

- `AiQo/Premium`

- `AiQo/Resources`

- `AiQo/Resources/Assets.xcassets`

- `AiQo/Resources/Assets.xcassets/1.1.imageset`

- `AiQo/Resources/Assets.xcassets/1.2.imageset`

- `AiQo/Resources/Assets.xcassets/1.3.imageset`

- `AiQo/Resources/Assets.xcassets/1.4.imageset`

- `AiQo/Resources/Assets.xcassets/1.5.imageset`

- `AiQo/Resources/Assets.xcassets/11.imageset`

- `AiQo/Resources/Assets.xcassets/2.1.imageset`

- `AiQo/Resources/Assets.xcassets/2.2.imageset`

- `AiQo/Resources/Assets.xcassets/2.3.imageset`

- `AiQo/Resources/Assets.xcassets/2.4.imageset`

- `AiQo/Resources/Assets.xcassets/2.5.imageset`

- `AiQo/Resources/Assets.xcassets/22.imageset`

- `AiQo/Resources/Assets.xcassets/3.1.imageset`

- `AiQo/Resources/Assets.xcassets/3.2.imageset`

- `AiQo/Resources/Assets.xcassets/3.3.imageset`

- `AiQo/Resources/Assets.xcassets/3.4.imageset`

- `AiQo/Resources/Assets.xcassets/3.5.imageset`

- `AiQo/Resources/Assets.xcassets/4.1.imageset`

- `AiQo/Resources/Assets.xcassets/4.2.imageset`

- `AiQo/Resources/Assets.xcassets/4.3.imageset`

- `AiQo/Resources/Assets.xcassets/4.4.imageset`

- `AiQo/Resources/Assets.xcassets/4.5.imageset`

- `AiQo/Resources/Assets.xcassets/5.1.imageset`

- `AiQo/Resources/Assets.xcassets/5.2.imageset`

- `AiQo/Resources/Assets.xcassets/5.3.imageset`

- `AiQo/Resources/Assets.xcassets/5.4.imageset`

- `AiQo/Resources/Assets.xcassets/5.5.imageset`

- `AiQo/Resources/Assets.xcassets/AccentColor.colorset`

- `AiQo/Resources/Assets.xcassets/AppIcon.appiconset`

- `AiQo/Resources/Assets.xcassets/Captain_Hamoudi_DJ.imageset`

- `AiQo/Resources/Assets.xcassets/ChatUserBubble.colorset`

- `AiQo/Resources/Assets.xcassets/GammaFlow.dataset`

- `AiQo/Resources/Assets.xcassets/Hammoudi5.imageset`

- `AiQo/Resources/Assets.xcassets/Hypnagogic_state.dataset`

- `AiQo/Resources/Assets.xcassets/Kitchenـicon.imageset`

- `AiQo/Resources/Assets.xcassets/Profile-icon.imageset`

- `AiQo/Resources/Assets.xcassets/SerotoninFlow.dataset`

- `AiQo/Resources/Assets.xcassets/SleepRing_Mint.imageset`

- `AiQo/Resources/Assets.xcassets/SleepRing_Orange.imageset`

- `AiQo/Resources/Assets.xcassets/SleepRing_Purple.imageset`

- `AiQo/Resources/Assets.xcassets/SoundOfEnergy.dataset`

- `AiQo/Resources/Assets.xcassets/The.refrigerator.imageset`

- `AiQo/Resources/Assets.xcassets/ThetaTrance.dataset`

- `AiQo/Resources/Assets.xcassets/TribeInviteBackground.imageset`

- `AiQo/Resources/Assets.xcassets/Tribe_icon.imageset`

- `AiQo/Resources/Assets.xcassets/WaterBottle.imageset`

- `AiQo/Resources/Assets.xcassets/imageKitchenHamoudi.imageset`

- `AiQo/Resources/Assets.xcassets/vibe_ icon.imageset`

- `AiQo/Resources/Specs`

- `AiQo/Resources/ar.lproj`

- `AiQo/Resources/en.lproj`

- `AiQo/Services`

- `AiQo/Services/Analytics`

- `AiQo/Services/CrashReporting`

- `AiQo/Services/Notifications`

- `AiQo/Services/Permissions`

- `AiQo/Services/Permissions/HealthKit`

- `AiQo/Shared`

- `AiQo/Tribe`

- `AiQo/Tribe/Arena`

- `AiQo/Tribe/Galaxy`

- `AiQo/Tribe/Log`

- `AiQo/Tribe/Models`

- `AiQo/Tribe/Preview`

- `AiQo/Tribe/Repositories`

- `AiQo/Tribe/Stores`

- `AiQo/Tribe/Views`

- `AiQo/UI`

- `AiQo/UI/Purchases`

- `AiQo/watch`

- `AiQo.xcodeproj`

- `AiQo.xcodeproj/project.xcworkspace`

- `AiQo.xcodeproj/project.xcworkspace/xcshareddata`

- `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm`

- `AiQo.xcodeproj/project.xcworkspace/xcuserdata`

- `AiQo.xcodeproj/project.xcworkspace/xcuserdata/mohammedraad.xcuserdatad`

- `AiQo.xcodeproj/xcshareddata`

- `AiQo.xcodeproj/xcshareddata/xcschemes`

- `AiQo.xcodeproj/xcuserdata`

- `AiQo.xcodeproj/xcuserdata/mohammedraad.xcuserdatad`

- `AiQo.xcodeproj/xcuserdata/mohammedraad.xcuserdatad/xcdebugger`

- `AiQo.xcodeproj/xcuserdata/mohammedraad.xcuserdatad/xcschemes`

- `AiQoTests`

- `AiQoUITests`

- `AiQoWatch Watch App`

- `AiQoWatch Watch App/Assets.xcassets`

- `AiQoWatch Watch App/Assets.xcassets/AccentColor.colorset`

- `AiQoWatch Watch App/Assets.xcassets/AiQoLogo.imageset`

- `AiQoWatch Watch App/Assets.xcassets/AppIcon.appiconset`

- `AiQoWatch Watch App/Design`

- `AiQoWatch Watch App/Models`

- `AiQoWatch Watch App/Services`

- `AiQoWatch Watch App/Shared`

- `AiQoWatch Watch App/Views`

- `AiQoWatch Watch AppTests`

- `AiQoWatch Watch AppUITests`

- `AiQoWatchWidget`

- `AiQoWatchWidget/Assets.xcassets`

- `AiQoWatchWidget/Assets.xcassets/AiQoLogo.imageset`

- `AiQoWidget`

- `AiQoWidget/Assets.xcassets`

- `AiQoWidget/Assets.xcassets/AccentColor.colorset`

- `AiQoWidget/Assets.xcassets/AppIcon.appiconset`

- `AiQoWidget/Assets.xcassets/WidgetBackground.colorset`

- `Configuration`

- `Configuration/ExternalSymbols`

- `Configuration/ExternalSymbols/SpotifyiOS.framework.dSYM`

- `Configuration/ExternalSymbols/SpotifyiOS.framework.dSYM/Contents`

### Source / Config Ledger

`AiQoWatch-Watch-App-Info.plist`

kind: `plist`

line_count: `16`

logical_group: `AiQoWatch-Watch-App-Info.plist`

`AiQo/AiQoActivityNames.swift`

kind: `swift`

line_count: `9`

logical_group: `AiQo/AiQoActivityNames.swift`

`AiQo/AppGroupKeys.swift`

kind: `swift`

line_count: `19`

logical_group: `AiQo/AppGroupKeys.swift`

`AiQo/Info.plist`

kind: `plist`

line_count: `87`

logical_group: `AiQo/Info.plist`

`AiQo/NeuralMemory.swift`

kind: `swift`

line_count: `60`

logical_group: `AiQo/NeuralMemory.swift`

`AiQo/PhoneConnectivityManager.swift`

kind: `swift`

line_count: `1007`

logical_group: `AiQo/PhoneConnectivityManager.swift`

`AiQo/ProtectionModel.swift`

kind: `swift`

line_count: `139`

logical_group: `AiQo/ProtectionModel.swift`

`AiQo/XPCalculator.swift`

kind: `swift`

line_count: `83`

logical_group: `AiQo/XPCalculator.swift`

`AiQo/App/AppDelegate.swift`

kind: `swift`

line_count: `454`

logical_group: `AiQo/App`

`AiQo/App/AppRootManager.swift`

kind: `swift`

line_count: `22`

logical_group: `AiQo/App`

`AiQo/App/AuthFlowUI.swift`

kind: `swift`

line_count: `464`

logical_group: `AiQo/App`

`AiQo/App/ProfileSetupView.swift`

kind: `swift`

line_count: `292`

logical_group: `AiQo/App`

`AiQo/App/LanguageSelectionView.swift`

kind: `swift`

line_count: `119`

logical_group: `AiQo/App`

`AiQo/App/LoginViewController.swift`

kind: `swift`

line_count: `191`

logical_group: `AiQo/App`

`AiQo/App/MainTabRouter.swift`

kind: `swift`

line_count: `53`

logical_group: `AiQo/App`

`AiQo/App/MainTabScreen.swift`

kind: `swift`

line_count: `128`

logical_group: `AiQo/App`

`AiQo/App/MealModels.swift`

kind: `swift`

line_count: `30`

logical_group: `AiQo/App`

`AiQo/App/SceneDelegate.swift`

kind: `swift`

line_count: `284`

logical_group: `AiQo/App`

`AiQo/Core/AiQoAccessibility.swift`

kind: `swift`

line_count: `106`

logical_group: `AiQo/Core`

`AiQo/Core/AiQoAudioManager.swift`

kind: `swift`

line_count: `343`

logical_group: `AiQo/Core`

`AiQo/Core/AppSettingsScreen.swift`

kind: `swift`

line_count: `453`

logical_group: `AiQo/Core`

`AiQo/Core/AppSettingsStore.swift`

kind: `swift`

line_count: `45`

logical_group: `AiQo/Core`

`AiQo/Core/ArabicNumberFormatter.swift`

kind: `swift`

line_count: `28`

logical_group: `AiQo/Core`

`AiQo/Core/CaptainMemory.swift`

kind: `swift`

line_count: `42`

logical_group: `AiQo/Core`

`AiQo/Core/CaptainMemorySettingsView.swift`

kind: `swift`

line_count: `209`

logical_group: `AiQo/Core`

`AiQo/Core/CaptainVoiceAPI.swift`

kind: `swift`

line_count: `197`

logical_group: `AiQo/Core`

`AiQo/Core/CaptainVoiceCache.swift`

kind: `swift`

line_count: `179`

logical_group: `AiQo/Core`

`AiQo/Core/CaptainVoiceService.swift`

kind: `swift`

line_count: `359`

logical_group: `AiQo/Core`

`AiQo/Core/Colors.swift`

kind: `swift`

line_count: `68`

logical_group: `AiQo/Core`

`AiQo/Core/Constants.swift`

kind: `swift`

line_count: `66`

logical_group: `AiQo/Core`

`AiQo/Core/DailyGoals.swift`

kind: `swift`

line_count: `42`

logical_group: `AiQo/Core`

`AiQo/Core/DeveloperPanelView.swift`

kind: `swift`

line_count: `101`

logical_group: `AiQo/Core`

`AiQo/Core/HapticEngine.swift`

kind: `swift`

line_count: `33`

logical_group: `AiQo/Core`

`AiQo/Core/HealthKitMemoryBridge.swift`

kind: `swift`

line_count: `170`

logical_group: `AiQo/Core`

`AiQo/Core/MemoryExtractor.swift`

kind: `swift`

line_count: `324`

logical_group: `AiQo/Core`

`AiQo/Core/MemoryStore.swift`

kind: `swift`

line_count: `467`

logical_group: `AiQo/Core`

`AiQo/Core/SiriShortcutsManager.swift`

kind: `swift`

line_count: `117`

logical_group: `AiQo/Core`

`AiQo/Core/SmartNotificationScheduler.swift`

kind: `swift`

line_count: `210`

logical_group: `AiQo/Core`

`AiQo/Core/SpotifyVibeManager.swift`

kind: `swift`

line_count: `721`

logical_group: `AiQo/Core`

`AiQo/Core/StreakManager.swift`

kind: `swift`

line_count: `165`

logical_group: `AiQo/Core`

`AiQo/Core/UserProfileStore.swift`

kind: `swift`

line_count: `132`

logical_group: `AiQo/Core`

`AiQo/Core/VibeAudioEngine.swift`

kind: `swift`

line_count: `829`

logical_group: `AiQo/Core`

`AiQo/Core/Localization/Bundle+Language.swift`

kind: `swift`

line_count: `22`

logical_group: `AiQo/Core`

`AiQo/Core/Localization/LocalizationManager.swift`

kind: `swift`

line_count: `38`

logical_group: `AiQo/Core`

`AiQo/Core/Models/ActivityNotification.swift`

kind: `swift`

line_count: `26`

logical_group: `AiQo/Core`

`AiQo/Core/Models/LevelStore.swift`

kind: `swift`

line_count: `195`

logical_group: `AiQo/Core`

`AiQo/Core/Models/NotificationPreferencesStore.swift`

kind: `swift`

line_count: `36`

logical_group: `AiQo/Core`

`AiQo/Core/Purchases/EntitlementStore.swift`

kind: `swift`

line_count: `68`

logical_group: `AiQo/Core`

`AiQo/Core/Purchases/PurchaseManager.swift`

kind: `swift`

line_count: `400`

logical_group: `AiQo/Core`

`AiQo/Core/Purchases/ReceiptValidator.swift`

kind: `swift`

line_count: `102`

logical_group: `AiQo/Core`

`AiQo/Core/Purchases/SubscriptionProductIDs.swift`

kind: `swift`

line_count: `68`

logical_group: `AiQo/Core`

`AiQo/Core/Utilities/ConnectivityDebugProviding.swift`

kind: `swift`

line_count: `16`

logical_group: `AiQo/Core`

`AiQo/DesignSystem/AiQoColors.swift`

kind: `swift`

line_count: `6`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/AiQoTheme.swift`

kind: `swift`

line_count: `37`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/AiQoTokens.swift`

kind: `swift`

line_count: `18`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Components/AiQoBottomCTA.swift`

kind: `swift`

line_count: `62`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Components/AiQoCard.swift`

kind: `swift`

line_count: `174`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Components/AiQoChoiceGrid.swift`

kind: `swift`

line_count: `84`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Components/AiQoPillSegment.swift`

kind: `swift`

line_count: `88`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Components/AiQoPlatformPicker.swift`

kind: `swift`

line_count: `91`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Components/AiQoSkeletonView.swift`

kind: `swift`

line_count: `52`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Components/StatefulPreviewWrapper.swift`

kind: `swift`

line_count: `15`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift`

kind: `swift`

line_count: `51`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Modifiers/AiQoShadow.swift`

kind: `swift`

line_count: `23`

logical_group: `AiQo/DesignSystem`

`AiQo/DesignSystem/Modifiers/AiQoSheetStyle.swift`

kind: `swift`

line_count: `17`

logical_group: `AiQo/DesignSystem`

`AiQo/Features/Captain/AiQoPromptManager.swift`

kind: `swift`

line_count: `132`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/AppleIntelligenceSleepAgent.swift`

kind: `swift`

line_count: `288`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/BrainOrchestrator.swift`

kind: `swift`

line_count: `479`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainChatView.swift`

kind: `swift`

line_count: `613`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainContextBuilder.swift`

kind: `swift`

line_count: `298`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainFallbackPolicy.swift`

kind: `swift`

line_count: `212`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainIntelligenceManager.swift`

kind: `swift`

line_count: `965`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainModels.swift`

kind: `swift`

line_count: `487`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainNotificationRouting.swift`

kind: `swift`

line_count: `77`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift`

kind: `swift`

line_count: `240`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainPersonaBuilder.swift`

kind: `swift`

line_count: `71`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainPromptBuilder.swift`

kind: `swift`

line_count: `361`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainScreen.swift`

kind: `swift`

line_count: `1147`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CaptainViewModel.swift`

kind: `swift`

line_count: `942`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/ChatHistoryView.swift`

kind: `swift`

line_count: `158`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CloudBrainService.swift`

kind: `swift`

line_count: `39`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CoachBrainMiddleware.swift`

kind: `swift`

line_count: `773`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/CoachBrainTranslationConfig.swift`

kind: `swift`

line_count: `91`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/HybridBrainService.swift`

kind: `swift`

line_count: `415`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/LLMJSONParser.swift`

kind: `swift`

line_count: `240`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/LocalBrainService.swift`

kind: `swift`

line_count: `846`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/LocalIntelligenceService.swift`

kind: `swift`

line_count: `160`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/MessageBubble.swift`

kind: `swift`

line_count: `108`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/PrivacySanitizer.swift`

kind: `swift`

line_count: `396`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/PromptRouter.swift`

kind: `swift`

line_count: `137`

logical_group: `AiQo/Features`

`AiQo/Features/Captain/ScreenContext.swift`

kind: `swift`

line_count: `52`

logical_group: `AiQo/Features`

`AiQo/Features/DataExport/HealthDataExporter.swift`

kind: `swift`

line_count: `328`

logical_group: `AiQo/Features`

`AiQo/Features/First screen/LegacyCalculationViewController.swift`

kind: `swift`

line_count: `749`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/ActiveRecoveryView.swift`

kind: `swift`

line_count: `182`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/AudioCoachManager.swift`

kind: `swift`

line_count: `94`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/CinematicGrindCardView.swift`

kind: `swift`

line_count: `226`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/CinematicGrindViews.swift`

kind: `swift`

line_count: `1204`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/ExercisesView.swift`

kind: `swift`

line_count: `39`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/GuinnessEncyclopediaView.swift`

kind: `swift`

line_count: `339`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/GymViewController.swift`

kind: `swift`

line_count: `25`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/HandsFreeZone2Manager.swift`

kind: `swift`

line_count: `549`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/HeartView.swift`

kind: `swift`

line_count: `20`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/L10n.swift`

kind: `swift`

line_count: `25`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/LiveMetricsHeader.swift`

kind: `swift`

line_count: `213`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/LiveWorkoutSession.swift`

kind: `swift`

line_count: `885`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/MyPlanViewController.swift`

kind: `swift`

line_count: `419`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/OriginalWorkoutCardView.swift`

kind: `swift`

line_count: `101`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/PhoneWorkoutSummaryView.swift`

kind: `swift`

line_count: `1459`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/RecapViewController.swift`

kind: `swift`

line_count: `874`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/RewardsViewController.swift`

kind: `swift`

line_count: `297`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/ShimmeringPlaceholder.swift`

kind: `swift`

line_count: `111`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/SoftGlassCardView.swift`

kind: `swift`

line_count: `106`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/SpotifyWebView.swift`

kind: `swift`

line_count: `72`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/SpotifyWorkoutPlayerView.swift`

kind: `swift`

line_count: `181`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/WatchConnectionStatusButton.swift`

kind: `swift`

line_count: `100`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/WatchConnectivityService.swift`

kind: `swift`

line_count: `77`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/WinsViewController.swift`

kind: `swift`

line_count: `600`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/WorkoutLiveActivityManager.swift`

kind: `swift`

line_count: `238`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/WorkoutSessionScreen.swift.swift`

kind: `swift`

line_count: `719`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/WorkoutSessionSheetView.swift`

kind: `swift`

line_count: `29`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/WorkoutSessionViewModel.swift`

kind: `swift`

line_count: `160`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/ClubRootView.swift`

kind: `swift`

line_count: `220`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Body/BodyView.swift`

kind: `swift`

line_count: `9`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift`

kind: `swift`

line_count: `216`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift`

kind: `swift`

line_count: `454`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift`

kind: `swift`

line_count: `544`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Challenges/ChallengesView.swift`

kind: `swift`

line_count: `9`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift`

kind: `swift`

line_count: `219`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Components/RailScrollOffsetPreferenceKey.swift`

kind: `swift`

line_count: `24`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Components/RightSideRailView.swift`

kind: `swift`

line_count: `61`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift`

kind: `swift`

line_count: `255`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Components/SegmentedTabs.swift`

kind: `swift`

line_count: `157`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift`

kind: `swift`

line_count: `451`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Impact/ImpactAchievementsView.swift`

kind: `swift`

line_count: `13`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift`

kind: `swift`

line_count: `117`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Impact/ImpactSummaryView.swift`

kind: `swift`

line_count: `9`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Plan/PlanView.swift`

kind: `swift`

line_count: `250`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift`

kind: `swift`

line_count: `712`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Models/GymExercise.swift`

kind: `swift`

line_count: `238`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/QuestDataSources.swift`

kind: `swift`

line_count: `547`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/QuestDefinitions.swift`

kind: `swift`

line_count: `943`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/QuestEngine.swift`

kind: `swift`

line_count: `691`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/QuestEvaluator.swift`

kind: `swift`

line_count: `235`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/QuestFormatting.swift`

kind: `swift`

line_count: `358`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/QuestKitModels.swift`

kind: `swift`

line_count: `287`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/QuestProgressStore.swift`

kind: `swift`

line_count: `74`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift`

kind: `swift`

line_count: `244`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift`

kind: `swift`

line_count: `353`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/Views/QuestCameraPermissionGateView.swift`

kind: `swift`

line_count: `105`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/Views/QuestDebugView.swift`

kind: `swift`

line_count: `77`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift`

kind: `swift`

line_count: `144`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Models/Challenge.swift`

kind: `swift`

line_count: `406`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Models/ChallengeStage.swift`

kind: `swift`

line_count: `11`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Models/HelpStrangersModels.swift`

kind: `swift`

line_count: `72`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Models/WinRecord.swift`

kind: `swift`

line_count: `77`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift`

kind: `swift`

line_count: `38`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift`

kind: `swift`

line_count: `680`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Store/WinsStore.swift`

kind: `swift`

line_count: `100`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/ChallengeCard.swift`

kind: `swift`

line_count: `195`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/ChallengeDetailView.swift`

kind: `swift`

line_count: `180`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/ChallengeRewardSheet.swift`

kind: `swift`

line_count: `51`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/ChallengeRunView.swift`

kind: `swift`

line_count: `207`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/HelpStrangersBottomSheet.swift`

kind: `swift`

line_count: `361`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/QuestCard.swift`

kind: `swift`

line_count: `101`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift`

kind: `swift`

line_count: `95`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift`

kind: `swift`

line_count: `1043`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/QuestDetailView.swift`

kind: `swift`

line_count: `847`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/QuestWinsGridView.swift`

kind: `swift`

line_count: `243`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/QuestsView.swift`

kind: `swift`

line_count: `429`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/Views/StageSelectorBar.swift`

kind: `swift`

line_count: `59`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift`

kind: `swift`

line_count: `133`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift`

kind: `swift`

line_count: `304`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift`

kind: `swift`

line_count: `381`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/T/SpinWheelView.swift`

kind: `swift`

line_count: `287`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/T/WheelTypes.swift`

kind: `swift`

line_count: `14`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/T/WorkoutTheme.swift`

kind: `swift`

line_count: `40`

logical_group: `AiQo/Features`

`AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift`

kind: `swift`

line_count: `127`

logical_group: `AiQo/Features`

`AiQo/Features/Home/ActivityDataProviding.swift`

kind: `swift`

line_count: `29`

logical_group: `AiQo/Features`

`AiQo/Features/Home/AlarmSetupCardView.swift`

kind: `swift`

line_count: `550`

logical_group: `AiQo/Features`

`AiQo/Features/Home/DJCaptainChatView.swift`

kind: `swift`

line_count: `464`

logical_group: `AiQo/Features`

`AiQo/Features/Home/DailyAuraModels.swift`

kind: `swift`

line_count: `9`

logical_group: `AiQo/Features`

`AiQo/Features/Home/DailyAuraPathData.swift`

kind: `swift`

line_count: `7`

logical_group: `AiQo/Features`

`AiQo/Features/Home/DailyAuraView.swift`

kind: `swift`

line_count: `427`

logical_group: `AiQo/Features`

`AiQo/Features/Home/DailyAuraViewModel.swift`

kind: `swift`

line_count: `132`

logical_group: `AiQo/Features`

`AiQo/Features/Home/HealthKitService+Water.swift`

kind: `swift`

line_count: `13`

logical_group: `AiQo/Features`

`AiQo/Features/Home/HomeStatCard.swift`

kind: `swift`

line_count: `454`

logical_group: `AiQo/Features`

`AiQo/Features/Home/HomeView.swift`

kind: `swift`

line_count: `606`

logical_group: `AiQo/Features`

`AiQo/Features/Home/HomeViewModel.swift`

kind: `swift`

line_count: `954`

logical_group: `AiQo/Features`

`AiQo/Features/Home/LevelUpCelebrationView.swift`

kind: `swift`

line_count: `54`

logical_group: `AiQo/Features`

`AiQo/Features/Home/MetricKind.swift`

kind: `swift`

line_count: `48`

logical_group: `AiQo/Features`

`AiQo/Features/Home/SleepDetailCardView.swift`

kind: `swift`

line_count: `859`

logical_group: `AiQo/Features`

`AiQo/Features/Home/SleepScoreRingView.swift`

kind: `swift`

line_count: `339`

logical_group: `AiQo/Features`

`AiQo/Features/Home/SmartWakeCalculatorView.swift`

kind: `swift`

line_count: `518`

logical_group: `AiQo/Features`

`AiQo/Features/Home/SmartWakeEngine.swift`

kind: `swift`

line_count: `407`

logical_group: `AiQo/Features`

`AiQo/Features/Home/SmartWakeViewModel.swift`

kind: `swift`

line_count: `197`

logical_group: `AiQo/Features`

`AiQo/Features/Home/SpotifyVibeCard.swift`

kind: `swift`

line_count: `262`

logical_group: `AiQo/Features`

`AiQo/Features/Home/StreakBadgeView.swift`

kind: `swift`

line_count: `187`

logical_group: `AiQo/Features`

`AiQo/Features/Home/VibeControlSheet.swift`

kind: `swift`

line_count: `1444`

logical_group: `AiQo/Features`

`AiQo/Features/Home/WaterBottleView.swift`

kind: `swift`

line_count: `282`

logical_group: `AiQo/Features`

`AiQo/Features/Home/WaterDetailSheetView.swift`

kind: `swift`

line_count: `222`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/CameraView.swift`

kind: `swift`

line_count: `49`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/CompositePlateView.swift`

kind: `swift`

line_count: `145`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/FridgeInventoryView.swift`

kind: `swift`

line_count: `153`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/IngredientAssetCatalog.swift`

kind: `swift`

line_count: `48`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/IngredientAssetLibrary.swift`

kind: `swift`

line_count: `71`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/IngredientCatalog.swift`

kind: `swift`

line_count: `129`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/IngredientDisplayItem.swift`

kind: `swift`

line_count: `150`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/IngredientKey.swift`

kind: `swift`

line_count: `624`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/InteractiveFridgeView.swift`

kind: `swift`

line_count: `732`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/KitchenLanguageRouter.swift`

kind: `swift`

line_count: `23`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/KitchenModels.swift`

kind: `swift`

line_count: `243`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/KitchenPersistenceStore.swift`

kind: `swift`

line_count: `332`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/KitchenPlanGenerationService.swift`

kind: `swift`

line_count: `449`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/KitchenSceneView.swift`

kind: `swift`

line_count: `185`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/KitchenScreen.swift`

kind: `swift`

line_count: `419`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/KitchenView.swift`

kind: `swift`

line_count: `338`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/KitchenViewModel.swift`

kind: `swift`

line_count: `105`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/LocalMealsRepository.swift`

kind: `swift`

line_count: `46`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/Meal.swift`

kind: `swift`

line_count: `80`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/MealIllustrationView.swift`

kind: `swift`

line_count: `9`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/MealImageSpec.swift`

kind: `swift`

line_count: `231`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/MealPlanGenerator.swift`

kind: `swift`

line_count: `68`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/MealPlanView.swift`

kind: `swift`

line_count: `432`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/MealSectionView.swift`

kind: `swift`

line_count: `89`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/MealsRepository.swift`

kind: `swift`

line_count: `7`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/NutritionTrackerView.swift`

kind: `swift`

line_count: `653`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/PlateTemplate.swift`

kind: `swift`

line_count: `191`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/RecipeCardView.swift`

kind: `swift`

line_count: `56`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/SmartFridgeCameraPreviewController.swift`

kind: `swift`

line_count: `50`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift`

kind: `swift`

line_count: `473`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift`

kind: `swift`

line_count: `38`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/SmartFridgeScannerView.swift`

kind: `swift`

line_count: `627`

logical_group: `AiQo/Features`

`AiQo/Features/Kitchen/meals_data.json`

kind: `json`

line_count: `44`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Components/RecordCard.swift`

kind: `swift`

line_count: `88`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Models/LegendaryProject.swift`

kind: `swift`

line_count: `45`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift`

kind: `swift`

line_count: `185`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Models/RecordProject.swift`

kind: `swift`

line_count: `106`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift`

kind: `swift`

line_count: `39`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift`

kind: `swift`

line_count: `268`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift`

kind: `swift`

line_count: `139`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift`

kind: `swift`

line_count: `359`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift`

kind: `swift`

line_count: `611`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift`

kind: `swift`

line_count: `46`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Views/ProjectView.swift`

kind: `swift`

line_count: `312`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift`

kind: `swift`

line_count: `212`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift`

kind: `swift`

line_count: `360`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Views/WeeklyReviewResultView.swift`

kind: `swift`

line_count: `100`

logical_group: `AiQo/Features`

`AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift`

kind: `swift`

line_count: `418`

logical_group: `AiQo/Features`

`AiQo/Features/MyVibe/DailyVibeState.swift`

kind: `swift`

line_count: `95`

logical_group: `AiQo/Features`

`AiQo/Features/MyVibe/MyVibeScreen.swift`

kind: `swift`

line_count: `423`

logical_group: `AiQo/Features`

`AiQo/Features/MyVibe/MyVibeSubviews.swift`

kind: `swift`

line_count: `199`

logical_group: `AiQo/Features`

`AiQo/Features/MyVibe/MyVibeViewModel.swift`

kind: `swift`

line_count: `105`

logical_group: `AiQo/Features`

`AiQo/Features/MyVibe/VibeOrchestrator.swift`

kind: `swift`

line_count: `153`

logical_group: `AiQo/Features`

`AiQo/Features/Onboarding/FeatureIntroView.swift`

kind: `swift`

line_count: `449`

logical_group: `AiQo/Features`

`AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift`

kind: `swift`

line_count: `272`

logical_group: `AiQo/Features`

`AiQo/Features/Onboarding/OnboardingWalkthroughView.swift`

kind: `swift`

line_count: `299`

logical_group: `AiQo/Features`

`AiQo/Features/Profile/LevelCardView.swift`

kind: `swift`

line_count: `244`

logical_group: `AiQo/Features`

`AiQo/Features/Profile/ProfileScreen.swift`

kind: `swift`

line_count: `2075`

logical_group: `AiQo/Features`

`AiQo/Features/Profile/String+Localized.swift`

kind: `swift`

line_count: `7`

logical_group: `AiQo/Features`

`AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift`

kind: `swift`

line_count: `154`

logical_group: `AiQo/Features`

`AiQo/Features/ProgressPhotos/ProgressPhotosView.swift`

kind: `swift`

line_count: `904`

logical_group: `AiQo/Features`

`AiQo/Features/Tribe/TribeDesignSystem.swift`

kind: `swift`

line_count: `219`

logical_group: `AiQo/Features`

`AiQo/Features/Tribe/TribeExperienceFlow.swift`

kind: `swift`

line_count: `531`

logical_group: `AiQo/Features`

`AiQo/Features/Tribe/TribeView.swift`

kind: `swift`

line_count: `1030`

logical_group: `AiQo/Features`

`AiQo/Features/WeeklyReport/ShareCardRenderer.swift`

kind: `swift`

line_count: `398`

logical_group: `AiQo/Features`

`AiQo/Features/WeeklyReport/WeeklyReportModel.swift`

kind: `swift`

line_count: `96`

logical_group: `AiQo/Features`

`AiQo/Features/WeeklyReport/WeeklyReportView.swift`

kind: `swift`

line_count: `551`

logical_group: `AiQo/Features`

`AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift`

kind: `swift`

line_count: `265`

logical_group: `AiQo/Features`

`AiQo/Frameworks/SpotifyiOS.framework/Info.plist`

kind: `plist`

line_count: `10`

logical_group: `AiQo/Frameworks`

`AiQo/Premium/AccessManager.swift`

kind: `swift`

line_count: `211`

logical_group: `AiQo/Premium`

`AiQo/Premium/EntitlementProvider.swift`

kind: `swift`

line_count: `67`

logical_group: `AiQo/Premium`

`AiQo/Premium/FreeTrialManager.swift`

kind: `swift`

line_count: `159`

logical_group: `AiQo/Premium`

`AiQo/Premium/PremiumPaywallView.swift`

kind: `swift`

line_count: `232`

logical_group: `AiQo/Premium`

`AiQo/Premium/PremiumStore.swift`

kind: `swift`

line_count: `198`

logical_group: `AiQo/Premium`

`AiQo/Resources/Assets.xcassets/Contents.json`

kind: `json`

line_count: `6`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/1.1.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/1.2.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/1.3.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/1.4.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/1.5.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/11.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/2.1.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/2.2.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/2.3.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/2.4.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/2.5.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/22.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/3.1.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/3.2.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/3.3.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/3.4.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/3.5.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/4.1.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/4.2.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/4.3.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/4.4.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/4.5.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/5.1.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/5.2.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/5.3.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/5.4.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/5.5.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`

kind: `json`

line_count: `20`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

kind: `json`

line_count: `14`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/Captain_Hamoudi_DJ.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/ChatUserBubble.colorset/Contents.json`

kind: `json`

line_count: `20`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/GammaFlow.dataset/Contents.json`

kind: `json`

line_count: `12`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/Hammoudi5.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/Hypnagogic_state.dataset/Contents.json`

kind: `json`

line_count: `12`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/Kitchenـicon.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/Profile-icon.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/SerotoninFlow.dataset/Contents.json`

kind: `json`

line_count: `12`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/SleepRing_Mint.imageset/Contents.json`

kind: `json`

line_count: `12`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/SleepRing_Orange.imageset/Contents.json`

kind: `json`

line_count: `12`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/SleepRing_Purple.imageset/Contents.json`

kind: `json`

line_count: `12`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/SoundOfEnergy.dataset/Contents.json`

kind: `json`

line_count: `12`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/The.refrigerator.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/ThetaTrance.dataset/Contents.json`

kind: `json`

line_count: `12`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/TribeInviteBackground.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/Tribe_icon.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/WaterBottle.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/imageKitchenHamoudi.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Assets.xcassets/vibe_ icon.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQo/Resources`

`AiQo/Resources/Specs/achievements_spec.json`

kind: `json`

line_count: `48`

logical_group: `AiQo/Resources`

`AiQo/Services/AiQoError.swift`

kind: `swift`

line_count: `116`

logical_group: `AiQo/Services`

`AiQo/Services/DeepLinkRouter.swift`

kind: `swift`

line_count: `129`

logical_group: `AiQo/Services`

`AiQo/Services/NetworkMonitor.swift`

kind: `swift`

line_count: `54`

logical_group: `AiQo/Services`

`AiQo/Services/NotificationType.swift`

kind: `swift`

line_count: `11`

logical_group: `AiQo/Services`

`AiQo/Services/ReferralManager.swift`

kind: `swift`

line_count: `120`

logical_group: `AiQo/Services`

`AiQo/Services/SupabaseArenaService.swift`

kind: `swift`

line_count: `959`

logical_group: `AiQo/Services`

`AiQo/Services/SupabaseService.swift`

kind: `swift`

line_count: `144`

logical_group: `AiQo/Services`

`AiQo/Services/Analytics/AnalyticsEvent.swift`

kind: `swift`

line_count: `157`

logical_group: `AiQo/Services`

`AiQo/Services/Analytics/AnalyticsService.swift`

kind: `swift`

line_count: `201`

logical_group: `AiQo/Services`

`AiQo/Services/CrashReporting/CrashReporter.swift`

kind: `swift`

line_count: `243`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/ActivityNotificationEngine.swift`

kind: `swift`

line_count: `627`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/AlarmSchedulingService.swift`

kind: `swift`

line_count: `262`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift`

kind: `swift`

line_count: `166`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/InactivityTracker.swift`

kind: `swift`

line_count: `21`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/MorningHabitOrchestrator.swift`

kind: `swift`

line_count: `382`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/NotificationCategoryManager.swift`

kind: `swift`

line_count: `22`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/NotificationIntelligenceManager.swift`

kind: `swift`

line_count: `551`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/NotificationRepository.swift`

kind: `swift`

line_count: `37`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/NotificationService.swift`

kind: `swift`

line_count: `986`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/PremiumExpiryNotifier.swift`

kind: `swift`

line_count: `98`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/SleepSessionObserver.swift`

kind: `swift`

line_count: `214`

logical_group: `AiQo/Services`

`AiQo/Services/Notifications/SmartNotificationManager.swift`

kind: `swift`

line_count: `78`

logical_group: `AiQo/Services`

`AiQo/Services/Permissions/HealthKit/HealthKitService.swift`

kind: `swift`

line_count: `990`

logical_group: `AiQo/Services`

`AiQo/Services/Permissions/HealthKit/TodaySummary.swift`

kind: `swift`

line_count: `37`

logical_group: `AiQo/Services`

`AiQo/Shared/CoinManager.swift`

kind: `swift`

line_count: `39`

logical_group: `AiQo/Shared`

`AiQo/Shared/HealthKitManager.swift`

kind: `swift`

line_count: `428`

logical_group: `AiQo/Shared`

`AiQo/Shared/HealthManager+Sleep.swift`

kind: `swift`

line_count: `451`

logical_group: `AiQo/Shared`

`AiQo/Shared/LevelSystem.swift`

kind: `swift`

line_count: `56`

logical_group: `AiQo/Shared`

`AiQo/Shared/WorkoutSyncCodec.swift`

kind: `swift`

line_count: `31`

logical_group: `AiQo/Shared`

`AiQo/Shared/WorkoutSyncModels.swift`

kind: `swift`

line_count: `445`

logical_group: `AiQo/Shared`

`AiQo/Tribe/TribeModuleComponents.swift`

kind: `swift`

line_count: `1146`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/TribeModuleModels.swift`

kind: `swift`

line_count: `611`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/TribeModuleViewModel.swift`

kind: `swift`

line_count: `462`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/TribePulseScreenView.swift`

kind: `swift`

line_count: `728`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/TribeScreen.swift`

kind: `swift`

line_count: `17`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/TribeStore.swift`

kind: `swift`

line_count: `544`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Arena/TribeArenaView.swift`

kind: `swift`

line_count: `319`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift`

kind: `swift`

line_count: `434`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift`

kind: `swift`

line_count: `248`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/ArenaModels.swift`

kind: `swift`

line_count: `177`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift`

kind: `swift`

line_count: `162`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/ArenaScreen.swift`

kind: `swift`

line_count: `262`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/ArenaTabView.swift`

kind: `swift`

line_count: `149`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/ArenaViewModel.swift`

kind: `swift`

line_count: `302`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/BattleLeaderboard.swift`

kind: `swift`

line_count: `91`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/BattleLeaderboardRow.swift`

kind: `swift`

line_count: `100`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/ConstellationCanvasView.swift`

kind: `swift`

line_count: `464`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/CountdownTimerView.swift`

kind: `swift`

line_count: `67`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/CreateTribeSheet.swift`

kind: `swift`

line_count: `217`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/EditTribeNameSheet.swift`

kind: `swift`

line_count: `71`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift`

kind: `swift`

line_count: `203`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/EmirateLeadersBanner.swift`

kind: `swift`

line_count: `141`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/GalaxyCanvasView.swift`

kind: `swift`

line_count: `10`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/GalaxyHUD.swift`

kind: `swift`

line_count: `260`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/GalaxyLayout.swift`

kind: `swift`

line_count: `142`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/GalaxyModels.swift`

kind: `swift`

line_count: `58`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/GalaxyNodeCard.swift`

kind: `swift`

line_count: `204`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/GalaxyScreen.swift`

kind: `swift`

line_count: `196`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/GalaxyView.swift`

kind: `swift`

line_count: `626`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/GalaxyViewModel.swift`

kind: `swift`

line_count: `341`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/HallOfFameFullView.swift`

kind: `swift`

line_count: `80`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/HallOfFameSection.swift`

kind: `swift`

line_count: `104`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/InviteCardView.swift`

kind: `swift`

line_count: `246`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/JoinTribeSheet.swift`

kind: `swift`

line_count: `164`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/MockArenaData.swift`

kind: `swift`

line_count: `143`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/TribeEmptyState.swift`

kind: `swift`

line_count: `104`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/TribeHeroCard.swift`

kind: `swift`

line_count: `148`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/TribeInviteView.swift`

kind: `swift`

line_count: `193`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/TribeLogScreen.swift`

kind: `swift`

line_count: `83`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/TribeMemberRow.swift`

kind: `swift`

line_count: `88`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/TribeMembersList.swift`

kind: `swift`

line_count: `59`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/TribeRingView.swift`

kind: `swift`

line_count: `57`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/TribeTabView.swift`

kind: `swift`

line_count: `111`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Galaxy/WeeklyChallengeCard.swift`

kind: `swift`

line_count: `150`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Log/TribeLogView.swift`

kind: `swift`

line_count: `68`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Models/TribeFeatureModels.swift`

kind: `swift`

line_count: `371`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Models/TribeModels.swift`

kind: `swift`

line_count: `154`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Preview/TribePreviewController.swift`

kind: `swift`

line_count: `286`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Preview/TribePreviewData.swift`

kind: `swift`

line_count: `209`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Repositories/TribeRepositories.swift`

kind: `swift`

line_count: `312`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Stores/ArenaStore.swift`

kind: `swift`

line_count: `225`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Stores/GalaxyStore.swift`

kind: `swift`

line_count: `100`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Stores/TribeLogStore.swift`

kind: `swift`

line_count: `25`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Views/GlobalTribeRadialView.swift`

kind: `swift`

line_count: `593`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Views/TribeAtomRingView.swift`

kind: `swift`

line_count: `150`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Views/TribeEnergyCoreCard.swift`

kind: `swift`

line_count: `123`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Views/TribeHubScreen.swift`

kind: `swift`

line_count: `1008`

logical_group: `AiQo/Tribe`

`AiQo/Tribe/Views/TribeLeaderboardView.swift`

kind: `swift`

line_count: `800`

logical_group: `AiQo/Tribe`

`AiQo/UI/AccessibilityHelpers.swift`

kind: `swift`

line_count: `96`

logical_group: `AiQo/UI`

`AiQo/UI/AiQoProfileButton.swift`

kind: `swift`

line_count: `125`

logical_group: `AiQo/UI`

`AiQo/UI/AiQoScreenHeader.swift`

kind: `swift`

line_count: `67`

logical_group: `AiQo/UI`

`AiQo/UI/ErrorToastView.swift`

kind: `swift`

line_count: `101`

logical_group: `AiQo/UI`

`AiQo/UI/GlassCardView.swift`

kind: `swift`

line_count: `69`

logical_group: `AiQo/UI`

`AiQo/UI/LegalView.swift`

kind: `swift`

line_count: `92`

logical_group: `AiQo/UI`

`AiQo/UI/OfflineBannerView.swift`

kind: `swift`

line_count: `43`

logical_group: `AiQo/UI`

`AiQo/UI/ReferralSettingsRow.swift`

kind: `swift`

line_count: `64`

logical_group: `AiQo/UI`

`AiQo/UI/Purchases/PaywallView.swift`

kind: `swift`

line_count: `278`

logical_group: `AiQo/UI`

`AiQo/watch/ConnectivityDiagnosticsView.swift`

kind: `swift`

line_count: `87`

logical_group: `AiQo/watch`

`AiQo.xcodeproj/xcuserdata/mohammedraad.xcuserdatad/xcschemes/xcschememanagement.plist`

kind: `plist`

line_count: `72`

logical_group: `AiQo.xcodeproj`

`AiQoTests/IngredientAssetCatalogTests.swift`

kind: `swift`

line_count: `72`

logical_group: `AiQoTests`

`AiQoTests/IngredientAssetLibraryTests.swift`

kind: `swift`

line_count: `13`

logical_group: `AiQoTests`

`AiQoTests/PurchasesTests.swift`

kind: `swift`

line_count: `132`

logical_group: `AiQoTests`

`AiQoTests/QuestEvaluatorTests.swift`

kind: `swift`

line_count: `140`

logical_group: `AiQoTests`

`AiQoTests/SmartWakeManagerTests.swift`

kind: `swift`

line_count: `75`

logical_group: `AiQoTests`

`AiQoWatch Watch App/ActivityRingsView.swift`

kind: `swift`

line_count: `51`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/AiQoWatchApp.swift`

kind: `swift`

line_count: `151`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/ControlsView.swift`

kind: `swift`

line_count: `45`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/ElapsedTimeView.swift`

kind: `swift`

line_count: `56`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/MetricsView.swift`

kind: `swift`

line_count: `52`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/SessionPagingView.swift`

kind: `swift`

line_count: `79`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/StartView.swift`

kind: `swift`

line_count: `423`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/SummaryView.swift`

kind: `swift`

line_count: `129`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/WatchConnectivityManager.swift`

kind: `swift`

line_count: `235`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/WorkoutManager.swift`

kind: `swift`

line_count: `1344`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/WorkoutNotificationCenter.swift`

kind: `swift`

line_count: `109`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/WorkoutNotificationController.swift`

kind: `swift`

line_count: `104`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/WorkoutNotificationView.swift`

kind: `swift`

line_count: `217`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Assets.xcassets/Contents.json`

kind: `json`

line_count: `6`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Assets.xcassets/AccentColor.colorset/Contents.json`

kind: `json`

line_count: `11`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Assets.xcassets/AiQoLogo.imageset/Contents.json`

kind: `json`

line_count: `21`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json`

kind: `json`

line_count: `214`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Design/WatchDesignSystem.swift`

kind: `swift`

line_count: `42`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Models/WatchWorkoutType.swift`

kind: `swift`

line_count: `72`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Services/WatchConnectivityService.swift`

kind: `swift`

line_count: `54`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Services/WatchHealthKitManager.swift`

kind: `swift`

line_count: `72`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Services/WatchWorkoutManager.swift`

kind: `swift`

line_count: `131`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Shared/WorkoutSyncCodec.swift`

kind: `swift`

line_count: `31`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Shared/WorkoutSyncModels.swift`

kind: `swift`

line_count: `445`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift`

kind: `swift`

line_count: `156`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Views/WatchHomeView.swift`

kind: `swift`

line_count: `180`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Views/WatchWorkoutListView.swift`

kind: `swift`

line_count: `65`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch App/Views/WatchWorkoutSummaryView.swift`

kind: `swift`

line_count: `122`

logical_group: `AiQoWatch Watch App`

`AiQoWatch Watch AppTests/AiQoWatch_Watch_AppTests.swift`

kind: `swift`

line_count: `17`

logical_group: `AiQoWatch Watch AppTests`

`AiQoWatch Watch AppUITests/AiQoWatch_Watch_AppUITests.swift`

kind: `swift`

line_count: `41`

logical_group: `AiQoWatch Watch AppUITests`

`AiQoWatch Watch AppUITests/AiQoWatch_Watch_AppUITestsLaunchTests.swift`

kind: `swift`

line_count: `33`

logical_group: `AiQoWatch Watch AppUITests`

`AiQoWatchWidget/AiQoWatchWidget.swift`

kind: `swift`

line_count: `235`

logical_group: `AiQoWatchWidget`

`AiQoWatchWidget/AiQoWatchWidgetBundle.swift`

kind: `swift`

line_count: `10`

logical_group: `AiQoWatchWidget`

`AiQoWatchWidget/AiQoWatchWidgetProvider.swift`

kind: `swift`

line_count: `59`

logical_group: `AiQoWatchWidget`

`AiQoWatchWidget/Info.plist`

kind: `plist`

line_count: `11`

logical_group: `AiQoWatchWidget`

`AiQoWatchWidget/Assets.xcassets/Contents.json`

kind: `json`

line_count: `6`

logical_group: `AiQoWatchWidget`

`AiQoWatchWidget/Assets.xcassets/AiQoLogo.imageset/Contents.json`

kind: `json`

line_count: `13`

logical_group: `AiQoWatchWidget`

`AiQoWidget/AiQoEntry.swift`

kind: `swift`

line_count: `69`

logical_group: `AiQoWidget`

`AiQoWidget/AiQoProvider.swift`

kind: `swift`

line_count: `55`

logical_group: `AiQoWidget`

`AiQoWidget/AiQoRingsFaceWidget.swift`

kind: `swift`

line_count: `106`

logical_group: `AiQoWidget`

`AiQoWidget/AiQoSharedStore.swift`

kind: `swift`

line_count: `28`

logical_group: `AiQoWidget`

`AiQoWidget/AiQoWatchFaceWidget.swift`

kind: `swift`

line_count: `79`

logical_group: `AiQoWidget`

`AiQoWidget/AiQoWidget.swift`

kind: `swift`

line_count: `51`

logical_group: `AiQoWidget`

`AiQoWidget/AiQoWidgetBundle.swift`

kind: `swift`

line_count: `16`

logical_group: `AiQoWidget`

`AiQoWidget/AiQoWidgetLiveActivity.swift`

kind: `swift`

line_count: `718`

logical_group: `AiQoWidget`

`AiQoWidget/AiQoWidgetView.swift`

kind: `swift`

line_count: `396`

logical_group: `AiQoWidget`

`AiQoWidget/Info.plist`

kind: `plist`

line_count: `11`

logical_group: `AiQoWidget`

`AiQoWidget/Assets.xcassets/Contents.json`

kind: `json`

line_count: `6`

logical_group: `AiQoWidget`

`AiQoWidget/Assets.xcassets/AccentColor.colorset/Contents.json`

kind: `json`

line_count: `11`

logical_group: `AiQoWidget`

`AiQoWidget/Assets.xcassets/AppIcon.appiconset/Contents.json`

kind: `json`

line_count: `14`

logical_group: `AiQoWidget`

`AiQoWidget/Assets.xcassets/WidgetBackground.colorset/Contents.json`

kind: `json`

line_count: `11`

logical_group: `AiQoWidget`

`Configuration/AiQo.xcconfig`

kind: `xcconfig`

line_count: `11`

logical_group: `Configuration`

`Configuration/Secrets.xcconfig`

kind: `xcconfig`

line_count: `16`

logical_group: `Configuration`

`Configuration/ExternalSymbols/SpotifyiOS.framework.dSYM/Contents/Info.plist`

kind: `plist`

line_count: `20`

logical_group: `Configuration`

## SECTION 4 — App Entry, Boot Sequence & Navigation

### App Entry

The real `@main` entry point is `AiQoApp` inside `AiQo/App/AppDelegate.swift`.

`AiQo/App/AiQoApp.swift` was requested but is not present; no separate entry file exists.

`AiQoApp` constructs two explicit SwiftData containers before rendering UI: a dedicated Captain container and the default app container.

### Boot Sequence In `application(_:didFinishLaunchingWithOptions:)`

- Create / initialize `PhoneConnectivityManager.shared`.

- Assign `UNUserNotificationCenter.current().delegate = self`.

- Initialize `CrashReporter.shared`.

- Initialize `NetworkMonitor.shared`.

- Track `AnalyticsEvent.appLaunched`.

- Refresh `FreeTrialManager.shared` state.

- Apply saved language through `LocalizationManager.shared.loadSavedLanguageOnLaunch()`.

- Register notification categories via `NotificationCategoryManager.shared.registerCategories()`.

- Register background tasks via `NotificationIntelligenceManager.shared.registerBackgroundTasks()`.

- Start in-app purchase infrastructure with `PurchaseManager.shared.start()`.

- If onboarding is complete, enable HealthKit permission flow, request notification auth, register for remote notifications, start morning habit orchestration, start sleep session observation, start workout summary service, schedule angel notifications, schedule notification intelligence background work, schedule smart notifications, donate Siri shortcuts, and check streak continuity.

### Activation Sequence In `applicationDidBecomeActive`

- Refresh watch context through `PhoneConnectivityManager.shared.refreshAppContext()`.

- Trigger widget timeline reloads through `WidgetCenter.shared.reloadAllTimelines()`.

- Clear app badge number.

- If onboarding is complete, restart morning habit orchestration, sleep observer, AI workout summaries, smart notification scheduler, and inactivity scheduling.

### `AppFlowController` State Machine

Requested file `AiQo/App/AppFlowController.swift` is not present; the real `AppFlowController` lives inside `AiQo/App/SceneDelegate.swift`.

- root state: `languageSelection`

- root state: `login`

- root state: `profileSetup`

- root state: `legacy`

- root state: `featureIntro`

- root state: `main`

Resolution logic uses `didSelectLanguage`, Supabase auth presence, `didCompleteDatingProfile`, `didCompleteLegacyCalculation`, and `didCompleteFeatureIntro`.

`didShowFirstAuthScreen` is stored, but current root-screen resolution is driven by the actual auth/session check.

`finishOnboardingRequestingPermissions()` requests HealthKit, notifications, and `ProtectionModel` authorization, starts the free trial, marks legacy done, then transitions into feature intro.

### Main Tabs

`MainTabRouter.Tab` defines five symbolic tabs: `home`, `gym`, `tribe`, `kitchen`, `captain`.

`MainTabScreen` currently renders only three visible tabs: `home`, `gym`, and `captain`.

Selecting `kitchen` through the router redirects to `home` and posts `Notification.Name.openKitchenFromHome`.

Captain chat presentation is centralized in `AppRootManager.shared.isCaptainChatPresented`.

The main tab shell is globally forced to `.rightToLeft`.

### Deep Links

- route: `home`

- route: `captain`

- route: `gym`

- route: `tribe(inviteCode:)`

- route: `kitchen`

- route: `settings`

- route: `referral(code:)`

- route: `premium`

Supported prefixes are `aiqo://` and `https://aiqo.app/`.

`captain` routes to the Captain tab and opens chat via `AppRootManager`.

`tribe` and `premium` are stored as pending deep links for later handling.

### Cross-Tab Root State

`AppRootManager` currently owns only one cross-tab flag: `isCaptainChatPresented`.

### Evidence Files

- `AiQo/App/AppDelegate.swift`

- `AiQo/App/SceneDelegate.swift`

- `AiQo/App/MainTabRouter.swift`

- `AiQo/App/MainTabScreen.swift`

- `AiQo/App/AppRootManager.swift`

- `AiQo/Services/DeepLinkRouter.swift`

## SECTION 5 — Hybrid AI Brain (BrainOrchestrator)

### Real Source Layout

The requested `AiQo/Services/AI/*` folder does not exist in the live tree.

The real AI orchestration code lives under `AiQo/Features/Captain/`.

### Routing Table

`ScreenContext.sleepAnalysis` -> local-first path through `LocalBrainService`.

`ScreenContext.gym` -> cloud path.

`ScreenContext.kitchen` -> cloud path.

`ScreenContext.peaks` -> cloud path.

`ScreenContext.myVibe` -> cloud path.

`ScreenContext.mainChat` -> cloud path.

Sleep intent interception upgrades free-text into `sleepAnalysis` when keywords/patterns indicate sleep problems or sleep review requests.

### Request / Reply Schema

`HybridBrainRequest` fields: `conversation`, `screenContext`, `language`, `contextData`, `userProfileSummary`, `attachedImageData`.

`HybridBrainServiceReply` fields: `message`, `quickReplies`, `workoutPlan`, `mealPlan`, `spotifyRecommendation`, `rawText`.

### PrivacySanitizer Behavior

- PII redaction for emails, phone numbers, UUIDs, URLs, long numeric sequences, IP addresses, long opaque tokens, and profile-style labels.

- Normalize names to `User`.

- Trim outbound conversation to the last four messages.

- Bucket steps to increments of 50.

- Bucket calories to increments of 10.

- Clamp level into `1...100`.

- Replace vibe with `General` in cloud payloads.

- Re-encode outbound images as JPEG, strip EXIF/GPS, cap max dimension at 1280, use quality `0.78`.

### Local Brain Service

Sleep analysis is delegated to `AppleIntelligenceSleepAgent` when `FoundationModels` is available.

General on-device chat uses `CaptainOnDeviceChatEngine` with an 8-second timeout.

Non-sleep local replies fall back to deterministic templates for workouts, meals, sleep, vibe, and challenge scaffolding.

Background notification text generation uses special prompt keys `background.sleep_notification` and `background.inactivity_notification`.

### Cloud Brain Service

Despite the original product brief, the current cloud endpoint is Google Gemini, not OpenAI.

Configured model constant: `gemini-flash-latest`.

Configured base endpoint: `https://generativelanguage.googleapis.com/v1beta/models`.

Default request timeout: `35` seconds.

Token budget: `600` output tokens for `mainChat`, `myVibe`, and `sleepAnalysis`; `900` for `gym`, `kitchen`, and `peaks`.

Kitchen image context is attached as inline JPEG to the final user turn only.

`CloudBrainService` builds cloud-safe memory context with `MemoryStore.buildCloudSafeContext(maxTokens: 400)` before delegating into `HybridBrainService`.

### Fallback Chain

Sleep path fallback order: local Apple Intelligence -> cloud sleep reply -> computed local summary.

General cloud path fallback order: cloud reply -> immediate network error reply for skip/network conditions -> local fallback -> localized network error reply.

### Evidence Files

- `AiQo/Features/Captain/BrainOrchestrator.swift`

- `AiQo/Features/Captain/CloudBrainService.swift`

- `AiQo/Features/Captain/LocalBrainService.swift`

- `AiQo/Features/Captain/HybridBrainService.swift`

- `AiQo/Features/Captain/PrivacySanitizer.swift`

- `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift`

- `AiQo/Features/Captain/AppleIntelligenceSleepAgent.swift`

## SECTION 6 — Captain Hamoudi Persona System

### Identity / Tone / Dialect

Captain is always framed as a practical Iraqi Arabic coach rooted in Baghdad dialect.

Prompting explicitly forbids generic AI disclaimers and non-Iraqi dialect drift.

Allowed custom tone options in the UI are `عملي`, `حنون`, and `صارم`.

Captain cognitive-state UI text emphasizes on-device reasoning when available.

### Prompt Builder 6-Layer Architecture

- Layer 1 `Identity`: persona rules, Iraqi dialect, voice, and relationship framing.

- Layer 2 `Memory`: long-term memory snippets and user-specific context.

- Layer 3 `Bio-state`: health, level, vibe, and current physiological context.

- Layer 4 `Circadian tone`: time-of-day and sleep-adjusted tone shaping.

- Layer 5 `Screen context`: gym/kitchen/sleep/vibe/chat-specific behavior rules.

- Layer 6 `Output contract`: strict JSON output keys and response-shape enforcement.

### Circadian Tone Phases

- `awakening` -> 05:00 to 09:59.

- `energy` -> 10:00 to 13:59.

- `focus` -> 14:00 to 17:59.

- `recovery` -> 18:00 to 20:59.

- `zen` -> 21:00 to 04:59.

- If sleep is below `5.5` hours during the morning window, the phase is forced toward `recovery`.

- If the hour is `>= 21` and steps exceed `8000`, tone also shifts toward `recovery`.

### Long-Term Memory

Persistent memory entities are `CaptainMemory` and `PersistentChatMessage`.

Memory categories retained in cloud-safe form include `goal`, `preference`, `mood`, `injury`, `nutrition`, and `insight`.

`MemoryStore` caps stored memories at `200` and persisted messages at `200`.

Prompt context prioritizes `active_record_project` plus the top memories ranked by confidence and recency.

Captain profile customization is stored in `UserDefaults` keys: `captain_user_name`, `captain_user_age`, `captain_user_height`, `captain_user_weight`, `captain_calling`, `captain_tone`.

### Voice Stack

Voice API defaults: model `eleven_multilingual_v2`, bitrate/output `mp3_44100_128`.

Voice tuning defaults: `stability=0.34`, `similarityBoost=0.88`, `style=0.18`, `speakerBoost=true`.

Voice API configuration keys come from plist/xcconfig placeholders: `CAPTAIN_VOICE_API_KEY`, `CAPTAIN_VOICE_VOICE_ID`, `CAPTAIN_VOICE_API_URL`, `CAPTAIN_VOICE_MODEL_ID`.

Local fallback TTS uses `AVSpeechSynthesizer` with Arabic preference order `ar-SA`, `ar-AE`, then generic `ar`.

Fallback speech rates: Arabic `0.44`, English `0.48`; pitch `0.96`.

### Voice Cache Strategy

- preloaded phrase: `getUp`

- preloaded phrase: `greatWorkout`

- preloaded phrase: `keepGoing`

- preloaded phrase: `almostThere`

- preloaded phrase: `drinkWater`

- preloaded phrase: `waterGoalDone`

- preloaded phrase: `mealTimeBreakfast`

- preloaded phrase: `mealTimeLunch`

- preloaded phrase: `mealTimeDinner`

- preloaded phrase: `sleepTime`

- preloaded phrase: `goodMorning`

- preloaded phrase: `dailyMotivation`

- preloaded phrase: `streakCongrats`

Cached voice files are named as `hamoudi_<sha256>.mp3`.

Captain voice pre-cache is intended to make common coaching phrases available instantly and offline-like after first retrieval.

### Evidence Files

- `AiQo/Features/Captain/CaptainViewModel.swift`

- `AiQo/Features/Captain/CaptainPersonaBuilder.swift`

- `AiQo/Features/Captain/CaptainPromptBuilder.swift`

- `AiQo/Features/Captain/CaptainScreen.swift`

- `AiQo/Core/CaptainVoiceAPI.swift`

- `AiQo/Core/CaptainVoiceCache.swift`

- `AiQo/Core/CaptainVoiceService.swift`

- `AiQo/Core/MemoryStore.swift`

- `AiQo/Core/CaptainMemory.swift`

## SECTION 7 — Data Models & Persistence

### SwiftData Containers

The user requested two containers, but the checked-in code actually uses three distinct container contexts.

Default app model container in `AiQoApp`: `AiQoDailyRecord`, `WorkoutTask`, `ArenaTribe`, `ArenaTribeMember`, `ArenaWeeklyChallenge`, `ArenaTribeParticipation`, `ArenaEmirateLeaders`, `ArenaHallOfFameEntry`.

Dedicated Captain container in `AiQoApp`: `CaptainMemory`, `PersistentChatMessage`, `RecordProject`, `WeeklyLog`.

Quest container from `QuestPersistenceController.shared.container`: `PlayerStats`, `QuestStage`, `QuestRecord`, `Reward`.

### Key `@Model` Classes And Stored Fields

- `AiQoDailyRecord`: `id`, `date`, `currentSteps`, `targetSteps`, `burnedCalories`, `targetCalories`, `waterCups`, `targetWaterCups`, `captainDailySuggestion`, `workouts`.

- `WorkoutTask`: `id`, `title`, `isCompleted`, `dailyRecord`.

- `CaptainMemory`: `id`, `category`, unique `key`, `value`, `confidence`, `source`, `createdAt`, `updatedAt`, `accessCount`.

- `PersistentChatMessage`: `messageID`, `text`, `isUser`, `timestamp`, `spotifyRecommendationData`, `sessionID` with indexes on `sessionID` and `timestamp`.

- `ArenaTribe`: unique `id`, `name`, `creatorUserID`, `inviteCode`, `members`, `createdAt`, `isActive`, `isFrozen`, `frozenAt`.

- `ArenaTribeMember`: unique `id`, `userID`, `displayName`, `initials`, `joinedAt`, `isCreator`, `tribe`.

- `ArenaWeeklyChallenge`: unique `id`, `title`, `descriptionText`, `metric`, `startDate`, `endDate`, `isActive`, `participations`.

- `ArenaTribeParticipation`: unique `id`, `tribe`, `challenge`, `currentScore`, `rank`, `joinedAt`.

- `ArenaEmirateLeaders`: unique `id`, `tribe`, `challenge`, `weekNumber`, `startDate`, `endDate`, `isDefending`.

- `ArenaHallOfFameEntry`: unique `id`, `weekNumber`, `tribeName`, `challengeTitle`, `date`.

- `PlayerStats`: unique `profileID`, `currentLevel`, `currentLevelXP`, `totalXP`, `totalAura`, `createdAt`, `updatedAt`.

- `QuestStage`: unique `stageID`, `stageIndex`, `titleKey`, `tabTitleKey`, `sortOrder`, `createdAt`, `updatedAt`, `records`.

- `QuestRecord`: unique `questID`, `stageIndex`, `questIndex`, `titleKey`, `fallbackTitle`, `questType`, `questSource`, `metricAKey`, `metricBKey`, `deepLinkAction`, `currentTier`, `metricAValue`, `metricBValue`, `lastUpdated`, `isStarted`, `startedAt`, `streakCount`, `lastCompletionDate`, `lastStreakDate`, `resetKeyDaily`, `resetKeyWeekly`, `isCompleted`, `completedAt`, `stage`.

- `Reward`: unique `rewardID`, `title`, `subtitle`, `iconSystemName`, `tintHex`, `kind`, `currentValue`, `targetValue`, `isUnlocked`, `unlockedAt`, `sourceQuestID`, `stageIndex`, `isFeatured`, `displayOrder`, `createdAt`, `updatedAt`.

- `SmartFridgeScannedItemRecord`: `id`, `name`, `quantity`, `unit`, `alchemyNoteKey`, `capturedAt`.

- `RecordProject`: `id`, `recordID`, `recordTitle`, `recordCategory`, `targetValue`, `unit`, `currentRecordHolder`, `holderCountryFlag`, `userWeightAtStart`, `userFitnessLevelAtStart`, `userBestAtStart`, `totalWeeks`, `currentWeek`, `planJSON`, `difficulty`, `bestPerformance`, `weeklyLogs`, `status`, `startDate`, `endDate`, `lastReviewDate`, `lastReviewNotes`, `isPinnedToPlan`, `hrrPeakHR`, `hrrRecoveryHR`, `hrrLevel`.

- `WeeklyLog`: `id`, `weekNumber`, `date`, `currentWeight`, `performanceThisWeek`, `userFeedback`, `captainNotes`, `adjustments`, `weekRating`, `isOnTrack`, `obstacles`, `project`.

### Singleton Managers / Persistent State Stores

- `AppSettingsStore` -> `aiqo.app.language`, `aiqo.notifications.enabled`.

- `UserProfileStore` -> `aiqo.userProfile`, `aiqo.userAvatar`, `aiqo.user.tribePrivacyMode`.

- `NotificationPreferencesStore` -> `user_gender`, `aiqo.notification.language`.

- `DailyGoalsStore` pattern in `DailyGoals` -> `aiqo.dailyGoals` plus widget goal mirrors.

- `MemoryStore` -> `captain_memory_enabled` and Captain SwiftData persistence.

- `LevelStore` -> `aiqo.user.level`, `aiqo.user.currentXP`, `aiqo.user.totalXP`.

- `StreakManager` -> `aiqo.streak.current`, `aiqo.streak.longest`, `aiqo.streak.lastActive`, `aiqo.streak.history`.

- `FreeTrialManager` -> `aiqo.freeTrial.startDate` plus Keychain mirror `com.aiqo.trial/trialStartDate`.

- `EntitlementStore` -> `aiqo.purchases.activeProductId`, `aiqo.purchases.expiresAt`.

- `ProgressPhotoStore` -> `aiqo.progressPhotos.entries`.

- `KitchenPersistenceStore` -> fridge/shopping/needs/pinned-plan keys under `aiqo.kitchen.*`.

### Additional UserDefaults Keys Explicitly Visible In Code

- `didSelectLanguage`

- `didShowFirstAuthScreen`

- `didCompleteDatingProfile`

- `didCompleteLegacyCalculation`

- `didCompleteFeatureIntro`

- `lastCelebratedLevel`

- `notificationLanguage`

- `coach_language`

- `push_device_token`

- `aiqo.currentLevel`

- `aiqo.currentLevelProgress`

- `aiqo.legacyTotalPoints`

- `aiqo.nutrition.calorieGoal`

- `aiqo.nutrition.proteinGoal`

- `aiqo.nutrition.carbGoal`

- `aiqo.nutrition.fatGoal`

- `aiqo.nutrition.fiberGoal`

- `aiqo.quest.kitchen.hasMealPlan`

- `aiqo.quest.kitchen.savedAt`

- `aiqo.mining.lastDate`

- `aiqo.mining.lastAwardedCoins`

- `aiqo.watch.session-id`

- `aiqo.watch.workout-type`

- `aiqo.watch.location-type`

- `aiqo.activity.lastProgress`

- `aiqo.activity.lastGoalCompletedDate`

- `aiqo.activity.lastAlmostThereDate`

- `aiqo.activity.lastAlmostThereMilestone`

- `aiqo.activity.selectedAngelTimes`

- `aiqo.activity.lastScheduleDate`

- `aiqo.activity.yesterdayTimes`

- `aiqo.captain.lastInactivitySentAt`

- `aiqo.captain.lastWaterReminderSentAt`

- `aiqo.captain.lastSleepReminderSentAt`

- `aiqo.ai.workout.anchor`

- `aiqo.ai.workout.processed.ids`

- `aiqo.morningHabit.scheduledWakeTimestamp`

- `aiqo.morningHabit.notificationWakeTimestamp`

- `aiqo.morningHabit.cachedInsight`

- `aiqo.sleepObserver.anchorData`

- `aiqo.sleepObserver.lastNotifiedSleepEnd`

- `aiqo.inactivity.lastActiveDate`

- `aiqo.dailyAura.history.v1`

- `aiqo.legendary.activeProject`

- `aiqo.tribe.preview.enabled`

- `aiqo.tribe.preview.useMockData`

- `aiqo.tribe.preview.plan`

- `AppleLanguages`

### Context Usage Patterns

App shell data uses `.modelContainer(for:)` at the root plus `QuestPersistenceController.shared.container` injection in `AppRootView`.

Captain-specific persistence is isolated into a separate `ModelContainer` stored in `AiQoApp` and passed into `MemoryStore.bootstrap(with:)`.

Quest persistence syncs `LevelStore` defaults into SwiftData `PlayerStats`.

The codebase mixes SwiftData, `UserDefaults`, local JSONL logs, local file storage, and network-backed Supabase records.

### Evidence Files

- `AiQo/App/AppDelegate.swift`

- `AiQo/App/SceneDelegate.swift`

- `AiQo/NeuralMemory.swift`

- `AiQo/Core/CaptainMemory.swift`

- `AiQo/Core/MemoryStore.swift`

- `AiQo/Features/Captain/CaptainModels.swift`

- `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift`

- `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift`

- `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift`

- `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift`

- `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift`

- `AiQo/Tribe/Galaxy/ArenaModels.swift`

## SECTION 8 — HealthKit Integration

### Read Types

- `stepCount`

- `heartRate`

- `restingHeartRate`

- `heartRateVariabilitySDNN`

- `walkingHeartRateAverage`

- `activeEnergyBurned`

- `distanceWalkingRunning`

- `distanceCycling`

- `dietaryWater`

- `vo2Max`

- `sleepAnalysis`

- `appleStandHour`

- `workoutType`

- `bodyMass`

- `bodyFatPercentage`

- `leanBodyMass`

- `activitySummaryType`

### Write Types Declared / Used

- `dietaryWater`

- `heartRate`

- `restingHeartRate`

- `heartRateVariabilitySDNN`

- `vo2Max`

- `distanceWalkingRunning`

- `workoutType`

### Permission Strategy

HealthKit prompts are gated by `HealthKitService.permissionFlowEnabled` so the app does not request permission too early.

The main onboarding permission moment is during legacy calculation completion and the onboarding finish routine.

After onboarding, app boot re-enables HealthKit-related services, observers, summaries, and widgets.

### Privacy Rule

Raw HealthKit samples stay on device in the current app architecture.

Cloud prompts use bucketed or summarized health values after `PrivacySanitizer` and `MemoryStore.buildCloudSafeContext` filtering.

`LegacyCalculationViewController` explicitly comments that only aggregate values and computed XP/level should be saved, not raw samples.

### Health Data Flow Into AI

`HealthKitService.fetchTodaySummary()` produces aggregated steps, calories, stand percentage, water, sleep, and distance values.

`HealthKitManager.fetchSleepStagesForLastNight()` produces structured sleep-stage sessions for Apple Intelligence sleep analysis.

`HealthKitMemoryBridge` syncs weight, resting HR, average steps, active calories average, and sleep average into `MemoryStore` categories.

`HistoricalHealthSyncEngine` computes legacy points from steps, calories, distance, and sleep totals, then pushes that aggregate into `LevelStore.shared.addXP(...)`.

### Evidence Files

- `AiQo/Services/Permissions/HealthKit/HealthKitService.swift`

- `AiQo/Shared/HealthKitManager.swift`

- `AiQo/Shared/HealthManager+Sleep.swift`

- `AiQo/Core/HealthKitMemoryBridge.swift`

- `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift`

## SECTION 9 — Onboarding Flow

### Current Screen Order

- `LanguageSelectionView` (`AiQo/App/LanguageSelectionView.swift`).

- `LoginScreenView` / Sign in with Apple (`AiQo/App/LoginViewController.swift`).

- `ProfileSetupView` (`AiQo/App/ProfileSetupView.swift`).

- `LegacyCalculationScreenView` (`AiQo/Features/First screen/LegacyCalculationViewController.swift`).

- `FeatureIntroView` (`AiQo/Features/Onboarding/FeatureIntroView.swift`).

- `MainTabScreen` (`AiQo/App/MainTabScreen.swift`).

### What Each Step Collects Or Explains

Language selection collects `AppLanguage` and sets the initial layout direction baseline.

Login uses Sign in with Apple and Supabase token exchange.

Profile setup collects name, username, birth date, gender, weight, height, and privacy preference.

Legacy calculation explains the app mission, requests HealthKit + notifications if the user taps permission CTA, performs historical sync, and computes initial level/XP.

Feature intro presents three pages: Captain Hamoudi, workouts/challenges/Peaks, and Alchemy Kitchen.

### Subscription / Paywall Placement

The current onboarding state machine does not include a mandatory paywall screen.

Free trial start is triggered from onboarding completion logic, but the dedicated paywall UI is presented from premium/community access surfaces rather than the onboarding root sequence.

### Sign In With Apple Placement

Sign in with Apple comes immediately after language selection whenever no active Supabase session is available.

### HealthKit Permission Placement

HealthKit is requested during the legacy-calculation path and again through onboarding-finish permission orchestration if needed.

### Feature Flags / Completion Flags

Onboarding progression is controlled by persisted booleans rather than plist feature flags.

- `didSelectLanguage`

- `didShowFirstAuthScreen`

- `didCompleteDatingProfile`

- `didCompleteLegacyCalculation`

- `didCompleteFeatureIntro`

### Unwired / Legacy Onboarding Code

`OnboardingWalkthroughView` exists but is not referenced by the current app flow.

### Evidence Files

- `AiQo/App/SceneDelegate.swift`

- `AiQo/App/LanguageSelectionView.swift`

- `AiQo/App/LoginViewController.swift`

- `AiQo/App/ProfileSetupView.swift`

- `AiQo/Features/First screen/LegacyCalculationViewController.swift`

- `AiQo/Features/Onboarding/FeatureIntroView.swift`

- `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift`

## SECTION 10 — Feature Modules (all 7)

### Home

Purpose: daily dashboard for aura, steps, calories, stand, water, sleep, distance, profile entry points, kitchen shortcut, and vibe controls.

AI routing: mostly none in the shell itself; Home launches Captain chat and DJ/Vibe flows rather than owning a separate model route.

Key data models: `AiQoDailyRecord`, `WorkoutTask`, daily aura history in `UserDefaults`, `TodaySummary`, level/streak stores.

HealthKit use: steps, active calories, stand percent, water, sleep, distance.

Feature flags: none specific to Home were found in plist.

Status: implemented in the current build; several cards are polished and connected to live data.

- `AiQo/Features/Home/ActivityDataProviding.swift`

- `AiQo/Features/Home/AlarmSetupCardView.swift`

- `AiQo/Features/Home/DJCaptainChatView.swift`

- `AiQo/Features/Home/DailyAuraModels.swift`

- `AiQo/Features/Home/DailyAuraPathData.swift`

- `AiQo/Features/Home/DailyAuraView.swift`

- `AiQo/Features/Home/DailyAuraViewModel.swift`

- `AiQo/Features/Home/HealthKitService+Water.swift`

- `AiQo/Features/Home/HomeStatCard.swift`

- `AiQo/Features/Home/HomeView.swift`

- `AiQo/Features/Home/HomeViewModel.swift`

- `AiQo/Features/Home/LevelUpCelebrationView.swift`

- `AiQo/Features/Home/MetricKind.swift`

- `AiQo/Features/Home/SleepDetailCardView.swift`

- `AiQo/Features/Home/SleepScoreRingView.swift`

- `AiQo/Features/Home/SmartWakeCalculatorView.swift`

- `AiQo/Features/Home/SmartWakeEngine.swift`

- `AiQo/Features/Home/SmartWakeViewModel.swift`

- `AiQo/Features/Home/SpotifyVibeCard.swift`

- `AiQo/Features/Home/StreakBadgeView.swift`

- `AiQo/Features/Home/VibeControlSheet.swift`

- `AiQo/Features/Home/WaterBottleView.swift`

- `AiQo/Features/Home/WaterDetailSheetView.swift`

### Gym / Peaks

Purpose: workouts, QuestKit progression, Club flows, watch-connected live sessions, recovery, rewards, cinematic grind, and workout summaries.

AI routing: cloud for `gym` / `peaks`, with local voice/on-device helpers in some workout contexts.

Key data models: Quest SwiftData models, workout session models, reward catalogs, legacy XP, live activity state.

HealthKit use: workouts, HR, calories, distance, sleep-linked quests, activity percent, zone minutes.

Feature flags: no dedicated plist flags; several comments mark V2/post-launch hooks.

Status: broadest module in the repo; core features are implemented, but some subfeatures remain mixed between shipping and post-launch placeholders.

Quest inventory from `QuestDefinitions.swift`:

- stage `1` quest `1` id `s1q1` title `شرارة الخير (مكافأة)` type `oneTime` source `manual`

- stage `1` quest `2` id `s1q2` title `نبع الماء (يومي)` type `daily` source `water`

- stage `1` quest `3` id `s1q3` title `عرش التعافي (يومي)` type `daily` source `healthkit`

- stage `1` quest `4` id `s1q4` title `نبض زون 2 (تراكمي)` type `cumulative` source `workout`

- stage `1` quest `5` id `s1q5` title `تأسيس المطبخ` type `oneTime` source `kitchen`

- stage `2` quest `1` id `s2q1` title `دقة آلة الرؤية (كاميرا)` type `oneTime` source `camera`

- stage `2` quest `2` id `s2q2` title `الحركة في يوم واحد` type `daily` source `healthkit`

- stage `2` quest `3` id `s2q3` title `سلم البلانك` type `cumulative` source `timer`

- stage `2` quest `4` id `s2q4` title `جلسة امتنان` type `daily` source `timer`

- stage `2` quest `5` id `s2q5` title `سلسلة الوقود` type `streak` source `water`

- stage `3` quest `1` id `s3q1` title `نسبة هدف الحركة` type `daily` source `healthkit`

- stage `3` quest `2` id `s3q2` title `بناء الضغط` type `cumulative` source `manual`

- stage `3` quest `3` id `s3q3` title `حارس زون 2` type `cumulative` source `workout`

- stage `3` quest `4` id `s3q4` title `سلسلة التعافي` type `streak` source `healthkit`

- stage `3` quest `5` id `s3q5` title `ساعد شخصين (مكافأة)` type `weekly` source `manual`

- stage `4` quest `1` id `s4q1` title `الخطوات` type `daily` source `healthkit`

- stage `4` quest `2` id `s4q2` title `سلم البلانك` type `cumulative` source `timer`

- stage `4` quest `3` id `s4q3` title `ضغط بالرؤية (كاميرا)` type `oneTime` source `camera`

- stage `4` quest `4` id `s4q4` title `نسبة هدف الحركة` type `daily` source `healthkit`

- stage `4` quest `5` id `s4q5` title `سلسلة الماء` type `streak` source `water`

- stage `5` quest `1` id `s5q1` title `سلسلة زون 2` type `streak` source `workout`

- stage `5` quest `2` id `s5q2` title `بناء الضغط` type `cumulative` source `manual`

- stage `5` quest `3` id `s5q3` title `سلسلة الخطوات` type `streak` source `healthkit`

- stage `5` quest `4` id `s5q4` title `جلسة صفاء` type `daily` source `timer`

- stage `5` quest `5` id `s5q5` title `ساعد 3 غرباء (مكافأة)` type `weekly` source `manual`

- stage `6` quest `1` id `s6q1` title `دقة الرؤية المطلقة (كاميرا)` type `oneTime` source `camera`

- stage `6` quest `2` id `s6q2` title `مسافة ممتدة` type `daily` source `healthkit`

- stage `6` quest `3` id `s6q3` title `سلسلة الحركة` type `streak` source `healthkit`

- stage `6` quest `4` id `s6q4` title `بلانك` type `cumulative` source `timer`

- stage `6` quest `5` id `s6q5` title `سلسلة النوم` type `streak` source `healthkit`

- stage `7` quest `1` id `s7q1` title `نبض القبيلة (الساحة)` type `cumulative` source `social`

- stage `7` quest `2` id `s7q2` title `زون 2 العظيم` type `cumulative` source `workout`

- stage `7` quest `3` id `s7q3` title `الخطوات` type `daily` source `healthkit`

- stage `7` quest `4` id `s7q4` title `سلسلة الماء` type `streak` source `water`

- stage `7` quest `5` id `s7q5` title `مشاركة إنجاز داخل التطبيق (مكافأة)` type `oneTime` source `share`

- stage `8` quest `1` id `s8q1` title `الخطوات` type `daily` source `healthkit`

- stage `8` quest `2` id `s8q2` title `بناء الضغط` type `cumulative` source `manual`

- stage `8` quest `3` id `s8q3` title `الرؤية المثالية (كاميرا)` type `oneTime` source `camera`

- stage `8` quest `4` id `s8q4` title `سلسلة الحركة` type `streak` source `healthkit`

- stage `8` quest `5` id `s8q5` title `سلسلة الامتنان` type `streak` source `timer`

- stage `9` quest `1` id `s9q1` title `الحركة في يوم واحد` type `daily` source `healthkit`

- stage `9` quest `2` id `s9q2` title `بلانك` type `cumulative` source `timer`

- stage `9` quest `3` id `s9q3` title `الساحة المتقدمة` type `cumulative` source `social`

- stage `9` quest `4` id `s9q4` title `سلسلة الخطوات` type `streak` source `healthkit`

- stage `9` quest `5` id `s9q5` title `أثر حقيقي: ساعد 5 غرباء (مكافأة)` type `oneTime` source `manual`

- stage `10` quest `1` id `s10q1` title `أسبوع المحارب` type `weekly` source `healthkit`

- stage `10` quest `2` id `s10q2` title `دقة الرؤية الأسطورية (كاميرا)` type `oneTime` source `camera`

- stage `10` quest `3` id `s10q3` title `سلسلة التعافي المركبة` type `combo` source `healthkit`

- stage `10` quest `4` id `s10q4` title `قلب الأسد (كارديو)` type `cumulative` source `workout`

- stage `10` quest `5` id `s10q5` title `مشاركة \` type `oneTime` source `share`

Key Gym/Peaks files:

- `AiQo/Features/Gym/ActiveRecoveryView.swift`

- `AiQo/Features/Gym/AudioCoachManager.swift`

- `AiQo/Features/Gym/CinematicGrindCardView.swift`

- `AiQo/Features/Gym/CinematicGrindViews.swift`

- `AiQo/Features/Gym/Club/Body/BodyView.swift`

- `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift`

- `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift`

- `AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift`

- `AiQo/Features/Gym/Club/Challenges/ChallengesView.swift`

- `AiQo/Features/Gym/Club/ClubRootView.swift`

- `AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift`

- `AiQo/Features/Gym/Club/Components/RailScrollOffsetPreferenceKey.swift`

- `AiQo/Features/Gym/Club/Components/RightSideRailView.swift`

- `AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift`

- `AiQo/Features/Gym/Club/Components/SegmentedTabs.swift`

- `AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift`

- `AiQo/Features/Gym/Club/Impact/ImpactAchievementsView.swift`

- `AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift`

- `AiQo/Features/Gym/Club/Impact/ImpactSummaryView.swift`

- `AiQo/Features/Gym/Club/Plan/PlanView.swift`

- `AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift`

- `AiQo/Features/Gym/ExercisesView.swift`

- `AiQo/Features/Gym/GuinnessEncyclopediaView.swift`

- `AiQo/Features/Gym/GymViewController.swift`

- `AiQo/Features/Gym/HandsFreeZone2Manager.swift`

- `AiQo/Features/Gym/HeartView.swift`

- `AiQo/Features/Gym/L10n.swift`

- `AiQo/Features/Gym/LiveMetricsHeader.swift`

- `AiQo/Features/Gym/LiveWorkoutSession.swift`

- `AiQo/Features/Gym/Models/GymExercise.swift`

- `AiQo/Features/Gym/MyPlanViewController.swift`

- `AiQo/Features/Gym/OriginalWorkoutCardView.swift`

- `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift`

- `AiQo/Features/Gym/QuestKit/QuestDataSources.swift`

- `AiQo/Features/Gym/QuestKit/QuestDefinitions.swift`

- `AiQo/Features/Gym/QuestKit/QuestEngine.swift`

- `AiQo/Features/Gym/QuestKit/QuestEvaluator.swift`

- `AiQo/Features/Gym/QuestKit/QuestFormatting.swift`

- `AiQo/Features/Gym/QuestKit/QuestKitModels.swift`

- `AiQo/Features/Gym/QuestKit/QuestProgressStore.swift`

- `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift`

- `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift`

- `AiQo/Features/Gym/QuestKit/Views/QuestCameraPermissionGateView.swift`

- `AiQo/Features/Gym/QuestKit/Views/QuestDebugView.swift`

- `AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift`

- `AiQo/Features/Gym/Quests/Models/Challenge.swift`

- `AiQo/Features/Gym/Quests/Models/ChallengeStage.swift`

- `AiQo/Features/Gym/Quests/Models/HelpStrangersModels.swift`

- `AiQo/Features/Gym/Quests/Models/WinRecord.swift`

- `AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift`

- `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift`

- `AiQo/Features/Gym/Quests/Store/WinsStore.swift`

- `AiQo/Features/Gym/Quests/Views/ChallengeCard.swift`

- `AiQo/Features/Gym/Quests/Views/ChallengeDetailView.swift`

- `AiQo/Features/Gym/Quests/Views/ChallengeRewardSheet.swift`

- `AiQo/Features/Gym/Quests/Views/ChallengeRunView.swift`

- `AiQo/Features/Gym/Quests/Views/HelpStrangersBottomSheet.swift`

- `AiQo/Features/Gym/Quests/Views/QuestCard.swift`

- `AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift`

- `AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift`

- `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift`

- `AiQo/Features/Gym/Quests/Views/QuestWinsGridView.swift`

- `AiQo/Features/Gym/Quests/Views/QuestsView.swift`

- `AiQo/Features/Gym/Quests/Views/StageSelectorBar.swift`

- `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift`

- `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift`

- `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift`

- `AiQo/Features/Gym/RecapViewController.swift`

- `AiQo/Features/Gym/RewardsViewController.swift`

- `AiQo/Features/Gym/ShimmeringPlaceholder.swift`

- `AiQo/Features/Gym/SoftGlassCardView.swift`

- `AiQo/Features/Gym/SpotifyWebView.swift`

- `AiQo/Features/Gym/SpotifyWorkoutPlayerView.swift`

- `AiQo/Features/Gym/T/SpinWheelView.swift`

- `AiQo/Features/Gym/T/WheelTypes.swift`

- `AiQo/Features/Gym/T/WorkoutTheme.swift`

- `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift`

- `AiQo/Features/Gym/WatchConnectionStatusButton.swift`

- `AiQo/Features/Gym/WatchConnectivityService.swift`

- `AiQo/Features/Gym/WinsViewController.swift`

- `AiQo/Features/Gym/WorkoutLiveActivityManager.swift`

- `AiQo/Features/Gym/WorkoutSessionScreen.swift.swift`

- `AiQo/Features/Gym/WorkoutSessionSheetView.swift`

- `AiQo/Features/Gym/WorkoutSessionViewModel.swift`

### Alchemy Kitchen

Purpose: fridge scan, ingredient inventory, meal planning, nutrition tracking, and Captain-guided “what can I cook?” flows.

AI routing: cloud for Arabic kitchen reasoning; mixed cloud/on-device routing in `KitchenPlanGenerationService` depending on language and code path.

Key data models: `SmartFridgeScannedItemRecord`, `Meal`, `KitchenModels`, `KitchenPersistenceStore` values, `meals_data.json`.

HealthKit use: indirect; nutrition/water tie-ins exist, but kitchen is not a primary HealthKit writer beyond shared wellness loops.

Feature flags: none found specific to kitchen.

Status: implemented with working views and persistence; some V2 comments remain.

- `AiQo/Features/Kitchen/CameraView.swift`

- `AiQo/Features/Kitchen/CompositePlateView.swift`

- `AiQo/Features/Kitchen/FridgeInventoryView.swift`

- `AiQo/Features/Kitchen/IngredientAssetCatalog.swift`

- `AiQo/Features/Kitchen/IngredientAssetLibrary.swift`

- `AiQo/Features/Kitchen/IngredientCatalog.swift`

- `AiQo/Features/Kitchen/IngredientDisplayItem.swift`

- `AiQo/Features/Kitchen/IngredientKey.swift`

- `AiQo/Features/Kitchen/InteractiveFridgeView.swift`

- `AiQo/Features/Kitchen/KitchenLanguageRouter.swift`

- `AiQo/Features/Kitchen/KitchenModels.swift`

- `AiQo/Features/Kitchen/KitchenPersistenceStore.swift`

- `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift`

- `AiQo/Features/Kitchen/KitchenSceneView.swift`

- `AiQo/Features/Kitchen/KitchenScreen.swift`

- `AiQo/Features/Kitchen/KitchenView.swift`

- `AiQo/Features/Kitchen/KitchenViewModel.swift`

- `AiQo/Features/Kitchen/LocalMealsRepository.swift`

- `AiQo/Features/Kitchen/Meal.swift`

- `AiQo/Features/Kitchen/MealIllustrationView.swift`

- `AiQo/Features/Kitchen/MealImageSpec.swift`

- `AiQo/Features/Kitchen/MealPlanGenerator.swift`

- `AiQo/Features/Kitchen/MealPlanView.swift`

- `AiQo/Features/Kitchen/MealSectionView.swift`

- `AiQo/Features/Kitchen/MealsRepository.swift`

- `AiQo/Features/Kitchen/NutritionTrackerView.swift`

- `AiQo/Features/Kitchen/PlateTemplate.swift`

- `AiQo/Features/Kitchen/RecipeCardView.swift`

- `AiQo/Features/Kitchen/SmartFridgeCameraPreviewController.swift`

- `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift`

- `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift`

- `AiQo/Features/Kitchen/SmartFridgeScannerView.swift`

- `AiQo/Features/Kitchen/meals_data.json`

### Sleep & Spirit

Purpose: sleep review, smart wake, sleep-stage interpretation, spiritual whispers, morning wake/habit nudges, and sleep session observations.

AI routing: local-first for `sleepAnalysis`; cloud fallback exists; notification intelligence also uses Gemini-backed text generation.

Key files:

- `AiQo/Features/Captain/AppleIntelligenceSleepAgent.swift`

- `AiQo/Features/Captain/LocalBrainService.swift`

- `AiQo/Features/Home/SleepDetailCardView.swift`

- `AiQo/Features/Home/SleepScoreRingView.swift`

- `AiQo/Features/Home/SmartWakeCalculatorView.swift`

- `AiQo/Features/Home/SmartWakeEngine.swift`

- `AiQo/Features/Home/SmartWakeViewModel.swift`

- `AiQo/Shared/HealthManager+Sleep.swift`

- `AiQo/Services/Notifications/MorningHabitOrchestrator.swift`

- `AiQo/Services/Notifications/SleepSessionObserver.swift`

- `AiQo/Services/Notifications/NotificationIntelligenceManager.swift`

Key data models: `SleepSession`, `TodaySummary`, sleep history aggregates, notification cached-insight values.

HealthKit use: `sleepAnalysis`, plus bedtime history and last-night stages.

Feature flags: none found; the feature is distributed rather than gated.

Status: implemented as a distributed subsystem rather than a standalone folder.

### My Vibe

Purpose: DJ Hamoudi mood state, audio frequencies, Spotify vibe playback, and vibe timeline control.

AI routing: cloud for `myVibe` in Captain context; local audio/state orchestration for actual playback experience.

Key data models: `DailyVibeState`, `SpotifyRecommendation`, `VibeOrchestrator` state.

HealthKit use: indirect; vibe state follows day part and wellness context but is not a direct HealthKit module.

Feature flags: none found specific to My Vibe.

Status: implemented in the current build with both local audio and Spotify integration paths.

- `AiQo/Features/MyVibe/DailyVibeState.swift`

- `AiQo/Features/MyVibe/MyVibeScreen.swift`

- `AiQo/Features/MyVibe/MyVibeSubviews.swift`

- `AiQo/Features/MyVibe/MyVibeViewModel.swift`

- `AiQo/Features/MyVibe/VibeOrchestrator.swift`

### Tribe / Emara

Purpose: social accountability, leaderboard overlays, tribe creation/joining, previews, premium community positioning, and global `Emara` leaderboards.

AI routing: none primary; social surfaces are backend/data driven.

Key data models: `ArenaTribe*` models, tribe preview/store models, profile visibility overlays.

HealthKit use: indirect through synced level/points and challenge metrics, not raw health samples.

Feature flags: `TRIBE_BACKEND_ENABLED`, `TRIBE_FEATURE_VISIBLE`, `TRIBE_SUBSCRIPTION_GATE_ENABLED`.

Status: mixed. Live leaderboard/profile sync exists, but multiple screens still describe themselves as preview/local-only placeholders.

- `AiQo/Features/Tribe/TribeDesignSystem.swift`

- `AiQo/Features/Tribe/TribeExperienceFlow.swift`

- `AiQo/Features/Tribe/TribeView.swift`

### Arena

Purpose: challenge graph, hall of fame, tribe participation, weekly challenge lifecycle, and global ranking visuals.

AI routing: none direct in Arena views; backend and persistence driven.

Key data models: `ArenaTribe`, `ArenaTribeMember`, `ArenaWeeklyChallenge`, `ArenaTribeParticipation`, `ArenaEmirateLeaders`, `ArenaHallOfFameEntry`.

HealthKit use: challenge metrics are derived from synced points/progress rather than direct raw samples.

Feature flags: inherits the tribe feature flags.

Status: partially live, partially preview. The service and models are real, but several Galaxy/Arena views still carry “Supabase hook” or placeholder comments.

- `AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift`

- `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift`

- `AiQo/Tribe/Galaxy/ArenaModels.swift`

- `AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift`

- `AiQo/Tribe/Galaxy/ArenaScreen.swift`

- `AiQo/Tribe/Galaxy/ArenaTabView.swift`

- `AiQo/Tribe/Galaxy/ArenaViewModel.swift`

- `AiQo/Tribe/Galaxy/BattleLeaderboard.swift`

- `AiQo/Tribe/Galaxy/BattleLeaderboardRow.swift`

- `AiQo/Tribe/Galaxy/ConstellationCanvasView.swift`

- `AiQo/Tribe/Galaxy/CountdownTimerView.swift`

- `AiQo/Tribe/Galaxy/CreateTribeSheet.swift`

- `AiQo/Tribe/Galaxy/EditTribeNameSheet.swift`

- `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift`

- `AiQo/Tribe/Galaxy/EmirateLeadersBanner.swift`

- `AiQo/Tribe/Galaxy/GalaxyCanvasView.swift`

- `AiQo/Tribe/Galaxy/GalaxyHUD.swift`

- `AiQo/Tribe/Galaxy/GalaxyLayout.swift`

- `AiQo/Tribe/Galaxy/GalaxyModels.swift`

- `AiQo/Tribe/Galaxy/GalaxyNodeCard.swift`

- `AiQo/Tribe/Galaxy/GalaxyScreen.swift`

- `AiQo/Tribe/Galaxy/GalaxyView.swift`

- `AiQo/Tribe/Galaxy/GalaxyViewModel.swift`

- `AiQo/Tribe/Galaxy/HallOfFameFullView.swift`

- `AiQo/Tribe/Galaxy/HallOfFameSection.swift`

- `AiQo/Tribe/Galaxy/InviteCardView.swift`

- `AiQo/Tribe/Galaxy/JoinTribeSheet.swift`

- `AiQo/Tribe/Galaxy/MockArenaData.swift`

- `AiQo/Tribe/Galaxy/TribeEmptyState.swift`

- `AiQo/Tribe/Galaxy/TribeHeroCard.swift`

- `AiQo/Tribe/Galaxy/TribeInviteView.swift`

- `AiQo/Tribe/Galaxy/TribeLogScreen.swift`

- `AiQo/Tribe/Galaxy/TribeMemberRow.swift`

- `AiQo/Tribe/Galaxy/TribeMembersList.swift`

- `AiQo/Tribe/Galaxy/TribeRingView.swift`

- `AiQo/Tribe/Galaxy/TribeTabView.swift`

- `AiQo/Tribe/Galaxy/WeeklyChallengeCard.swift`

## SECTION 11 — Gamification System

### XP / Score Sources

There is no single `XPEngine.swift` file in the live tree.

XP and score logic is currently split across multiple systems.

Workout-session XP comes from `XPCalculator.calculateSessionStats(...)`, which computes `truthNumber = calories + durationMinutes`, `luckyNumber = sum(heartbeatDigits)`, then `totalXP = truthNumber + luckyNumber`.

Coin mining comes from `XPCalculator.calculateCoins(...)`: `steps / 100`, plus `activeCalories / 50`, plus `durationMinutes * 2` turbo bonus when average HR is above `115` BPM.

Historical onboarding XP comes from `steps / 200 + calories / 25 + distance * 10 + sleep * 5`.

`LevelStore.addXP(_:)` is the central modern level accumulator and syncs total points/level to Supabase profiles.

QuestKit uses its own progress/reward tracks alongside the shared `LevelStore` stats mirror.

### Level System

Modern level curve formula in `LevelStore`: `baseXP = 1000`, `multiplier = 1.2`.

- level `1` requires `1000` XP for the next-level threshold calculation

- level `2` requires `1200` XP for the next-level threshold calculation

- level `3` requires `1440` XP for the next-level threshold calculation

- level `4` requires `1727` XP for the next-level threshold calculation

- level `5` requires `2073` XP for the next-level threshold calculation

- level `6` requires `2488` XP for the next-level threshold calculation

- level `7` requires `2985` XP for the next-level threshold calculation

- level `8` requires `3583` XP for the next-level threshold calculation

- level `9` requires `4299` XP for the next-level threshold calculation

- level `10` requires `5159` XP for the next-level threshold calculation

- level `11` requires `6191` XP for the next-level threshold calculation

- level `12` requires `7430` XP for the next-level threshold calculation

- level `13` requires `8916` XP for the next-level threshold calculation

- level `14` requires `10699` XP for the next-level threshold calculation

- level `15` requires `12839` XP for the next-level threshold calculation

Shield tiers: `wood` (levels 1-4), `bronze` (5-9), `silver` (10-14), `gold` (15-19), `platinum` (20-24), `diamond` (25-29), `obsidian` (30-34), `legendary` (35+).

Legacy Arabic level titles still exist in onboarding/legacy calculation UI:

- `البداية`

- `المتحرّك`

- `النشيط`

- `المنضبط`

- `القوي`

- `المحارب`

- `البطل`

- `الأسطورة الرياضية`

- `الخارق`

- `الأسطورة الحيّة`

### Streak System

`StreakManager` tracks `currentStreak`, `longestStreak`, `lastActiveDate`, and date history.

The streak only increments when app code explicitly marks today as active; it is not a passive automatic HealthKit streak engine.

Color tiers in `StreakBadgeView`: sand for small streaks, orange for `>= 7`, purple for `>= 30`.

Motivation messages change over these brackets: `0`, `1`, `2...3`, `4...6`, `7...13`, `14...29`, `30...59`, `60...89`, `90...364`, `365+`.

### Badge / Achievement System

Current shipped achievement catalog is JSON-driven in `AiQo/Resources/Specs/achievements_spec.json`.

- `badge_first_steps` -> `FIRST_HEALTH_SYNC` -> 10 points.

- `badge_steps_10k` -> `STEPS_DAY_10000` -> 15 points.

- `shield_streak_7_steps` -> `STEPS_STREAK_7` -> 60 points.

- `belt_month_champion` -> `TRIBE_MONTH_CHAMPION` -> 200 points.

Quest reward seeds in SwiftData include IDs such as `reward.streak.7day`, `reward.heart.hero`, `reward.step.master`, `reward.gratitude.mode`, and `reward.weekly.chest`.

### Legendary Projects

Long-horizon challenge persistence is represented by `RecordProject` + `WeeklyLog`.

A project stores target value, unit, difficulty, baseline stats, current/best performance, total weeks, current week, HRR markers, plan JSON, and weekly review notes.

Weekly logs store weekly weight, performance, feedback, Captain notes, adjustments, rating, on-track status, and obstacles.

A separate older `LegendaryChallengesViewModel` still uses `UserDefaults` (`aiqo.legendary.activeProject`), which signals an in-progress migration toward the SwiftData manager.

### Evidence Files

- `AiQo/Core/Models/LevelStore.swift`

- `AiQo/Core/StreakManager.swift`

- `AiQo/XPCalculator.swift`

- `AiQo/Features/Home/StreakBadgeView.swift`

- `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift`

- `AiQo/Resources/Specs/achievements_spec.json`

- `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift`

- `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift`

## SECTION 12 — Monetization & StoreKit 2

### Free Trial

Free trial duration is `7` days.

Trial state is persisted to both `UserDefaults` and Keychain so reinstalls do not reset the trial.

The onboarding finish flow starts the trial automatically; premium paywall can also explicitly start it if unused.

Community/Tribe access and creation are granted by either active premium entitlement or active free trial depending on the gate check (`AccessManager`).

### Product IDs

- `aiqo_nr_30d_individual_5_99`

- `aiqo_nr_30d_family_10_00`

- `aiqo_30d_individual_5_99` (legacy lookup only)

- `aiqo_30d_family_10_00` (legacy lookup only)

### Tiers / Pricing Signals

Displayed tier names are `فردي` and `عائلي`.

Fallback display prices are `$5.99` for individual and `$10.00` for family.

`EntitlementStore` exposes `isActive`, `isFamily`, and `canCreateTribe`.

### Paywall Design / Copy Rules Visible In UI

`PremiumPaywallView` uses the Tribe glass-card visual language, large rounded typography, and Arabic-localized title/subtitle strings.

Free-trial CTAs are surfaced before paid plan cards when the user has not used the trial.

Restore purchases is always present.

Status UI shows active/expired state and formatted expiry date when available.

`PaywallView` includes legal links, restore, retry, debug test setup in DEBUG, and a community/Tribe entry point.

### Receipt Validation Flow

After verified purchase completion, the app posts transaction metadata to `https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/validate-receipt`.

Payload fields: `transactionId`, `productId`, `originalPurchaseDate`, `purchaseDate`, `appAccountToken` (optional).

Expected response shape: `valid`, `expiresAt`, `reason`.

Network errors fall back to local entitlement interpretation rather than hard-failing the app.

### StoreKit 2 Compliance Notes Visible In Code

The app supports purchase, restore, entitlement refresh, and transaction finishing.

The paywall includes restore and legal surfaces.

DEBUG mode can use a local StoreKit configuration (`AiQo_Test.storekit`).

### Evidence Files

- `AiQo/Premium/FreeTrialManager.swift`

- `AiQo/Core/Purchases/PurchaseManager.swift`

- `AiQo/Core/Purchases/SubscriptionProductIDs.swift`

- `AiQo/Core/Purchases/ReceiptValidator.swift`

- `AiQo/Core/Purchases/EntitlementStore.swift`

- `AiQo/Premium/PremiumPaywallView.swift`

- `AiQo/UI/Purchases/PaywallView.swift`

## SECTION 13 — Supabase Backend Schema

### Tables Explicitly Referenced In Code

- `profiles` -> app auth/profile/device-token/visibility/leaderboard profile data.

- `arena_tribes` -> tribe records.

- `arena_tribe_members` -> tribe membership rows.

- `arena_tribe_participations` -> challenge participation rows.

- `arena_weekly_challenges` -> challenge definitions and lifecycle.

- `arena_hall_of_fame_entries` -> historical winners / hall of fame.

- `quest_wins` -> only referenced in commented-out future upload code, not active.

### Key Columns Visible In DTOs / Queries

- `profiles`: `id`, `user_id`, `name`, `age`, `height_cm`, `weight_kg`, `goal_text`, `is_private`, `device_token`, `display_name`, `username`, `level`, `total_points`, `is_profile_public`.

- `arena_tribes`: `id`, `name`, `owner_id`, `invite_code`, `created_at`, `is_active`, `is_frozen`, `frozen_at`.

- `arena_tribe_members`: `id`, `tribe_id`, `user_id`, `role`, `contribution_points`, `joined_at`.

- `arena_weekly_challenges`: DTOs in service code imply title/description/metric/time window / active-state fields.

- `arena_hall_of_fame_entries`: hall-of-fame winner metadata with week number and titles.

### Auth Strategy

Sign in with Apple produces an ID token and nonce.

`LoginViewController` exchanges that token with `SupabaseService.shared.client.auth.signInWithIdToken(provider: .apple, ...)`.

`AppFlowController` treats an existing Supabase session as sufficient to skip the login screen.

### Real-Time Subscriptions

No active `.channel(...)` realtime subscription usage was found in the live source tree.

### Edge Functions / RPC

Supabase Edge Function: `validate-receipt` for StoreKit receipt validation.

Supabase RPC: `delete_user_account` is called from Settings to remove user data / mark account for deletion.

### RLS Strategy

No SQL migrations or explicit RLS policy files are present in this repo.

The client code assumes per-user row security behavior for profile and tribe actions, but the actual policies are not source-controlled here.

### Backend Toggle Strategy

`TribeRepositories` switches between Supabase repositories and local/mock repositories based on `TRIBE_BACKEND_ENABLED`.

### Evidence Files

- `AiQo/Services/SupabaseService.swift`

- `AiQo/Services/SupabaseArenaService.swift`

- `AiQo/App/LoginViewController.swift`

- `AiQo/Core/AppSettingsScreen.swift`

- `AiQo/Tribe/Repositories/TribeRepositories.swift`

- `AiQo/Tribe/Models/TribeFeatureModels.swift`

## SECTION 14 — Notifications & Background Tasks

### Notification Categories

Registered categories are `ActivityNotificationEngine.notificationCategory` and `CaptainSmartNotificationService.notificationCategory` via `NotificationCategoryManager`.

### SmartNotificationScheduler Schedule

- Water reminders at `10:00`, `12:00`, `14:00`, `16:00`, `18:00`, `20:00`.

- Workout motivation at `17:00`.

- Sleep reminder at `22:30`.

- Streak protection at `20:00`.

- Weekly report every Friday at `10:00`.

### Notification Intelligence Manager

Background task identifiers: `aiqo.captain.spiritual-whispers.refresh`, `aiqo.captain.inactivity-check`.

Preferred whisper windows are around `06:15` and `17:30`.

Inactivity background checks run every two hours after `14:05` if steps are below `3000`.

Notification language is configurable via `notificationLanguage` / app language surfaces.

### MorningHabitOrchestrator

Tracks scheduled wake timestamp, notification wake timestamp, and cached insight.

Uses a “first 25 steps within 6 hours of wake” style morning success condition.

Primary notification identifier: `aiqo.morningHabit.notification`.

### SleepSessionObserver

Tracks HealthKit anchor data and last notified sleep-end time.

Notification identifiers are generated as `aiqo.sleepObserver.<uuid>`.

### ActivityNotificationEngine

Schedules angel-number times such as `01:11`, `02:22`, `03:33`, `04:44`, `05:55`, `10:10`, `11:11`, `12:12`, `12:21`.

Tracks goal progress and “almost there” cooldown state in multiple `aiqo.activity.*` keys.

### Other Background / Notification Services

`NotificationService` handles permission prompting, deep-link tap routing, cooldown timestamps, and workout-summary processing anchors.

`AlarmSchedulingService` uses `AlarmKit` on iOS `26.1+`.

`CaptainBackgroundNotificationComposer` uses `LocalBrainService` to phrase sleep/inactivity notifications in Captain voice.

### Background Modes / Identifiers From Info.plist

- BGTask permitted identifier: `aiqo.captain.spiritual-whispers.refresh`

- BGTask permitted identifier: `aiqo.captain.inactivity-check`

- UIBackgroundModes entry: `audio`

- UIBackgroundModes entry: `remote-notification`

- UIBackgroundModes entry: `fetch`

### Evidence Files

- `AiQo/Core/SmartNotificationScheduler.swift`

- `AiQo/Services/Notifications/NotificationCategoryManager.swift`

- `AiQo/Services/Notifications/NotificationService.swift`

- `AiQo/Services/Notifications/NotificationIntelligenceManager.swift`

- `AiQo/Services/Notifications/MorningHabitOrchestrator.swift`

- `AiQo/Services/Notifications/SleepSessionObserver.swift`

- `AiQo/Services/Notifications/ActivityNotificationEngine.swift`

- `AiQo/App/AppDelegate.swift`

- `AiQo/Info.plist`

## SECTION 15 — Design System

### Color Tokens

- `AiQoColors.mint` -> `#CDF4E4`.

- `AiQoColors.beige` -> `#F5D5A6`.

- `AiQoTheme.primaryBackground` -> light `#F5F7FB`, dark `#0B1016`.

- `AiQoTheme.surface` -> light `#FFFFFF`, dark `#121922`.

- `AiQoTheme.surfaceSecondary` -> light `#EEF2F7`, dark `#18212B`.

- `AiQoTheme.textPrimary` -> light `#0F1721`, dark `#F6F8FB`.

- `AiQoTheme.textSecondary` -> light `#5F6F80`, dark `#A3AFBC`.

- `AiQoTheme.accent` -> light `#5ECDB7`, dark `#8AE3D1`.

- `AiQoTheme.iconBackground` -> light `#F2F6FA`, dark `#1A2430`.

- `AiQoTheme.ctaGradientLeading` -> light `#7CE0D2`, dark `#90E6D6`.

- `AiQoTheme.ctaGradientTrailing` -> light `#A4C8FF`, dark `#C4D9FF`.

- `Colors.mint` -> `#C4F0DB`.

- `Colors.sand` -> `#F8D6A3`.

- `Colors.accent` -> `#FFE68C`.

- `Colors.aiqoBeige` -> `#FADEB3`.

- `Colors.lemon` -> `#FFECB8`.

- `Colors.lav` -> `#F5E0FF`.

### Typography

- `screenTitle` -> rounded `.title2.bold()`.

- `sectionTitle` -> rounded `.headline.semibold()`.

- `cardTitle` -> rounded `.headline.semibold()`.

- `body` -> rounded `.subheadline`.

- `caption` -> rounded `.caption`.

- `cta` -> rounded `.headline.semibold()`.

### Spacing / Radius Tokens

- `spacing.xs = 8`.

- `spacing.sm = 12`.

- `spacing.md = 16`.

- `spacing.lg = 24`.

- `radius.control = 12`.

- `radius.card = 16`.

- `radius.ctaContainer = 24`.

- `minimumTapTarget = 44`.

### Core UI Components

- `AiQoBottomCTA`.

- `AiQoCard`.

- `AiQoChoiceGrid`.

- `AiQoPillSegment`.

- `AiQoPlatformPicker`.

- `AiQoSkeletonView`.

- `AiQoProfileButton`.

- `AiQoScreenHeader`.

- `GlassCardView`.

- `OfflineBannerView`.

- `LegalView`.

### Animation Presets / Motion Patterns

- `AiQoPressButtonStyle` pressed spring -> `response 0.10`, `dampingFraction 0.5`; release spring -> `response 1.2`, `dampingFraction 0.85`.

- `AiQoPressEffect` -> `response 0.12`, `dampingFraction 0.5`.

- `AiQoChoiceGrid`, `AiQoPlatformPicker`, `AiQoPillSegment` selection spring -> `response 0.28`, `dampingFraction 0.86`.

- `OfflineBannerView` -> spring `response 0.35`.

- `SmartWake` controls -> spring `response 0.34`, `dampingFraction 0.86`.

- `Home` metric expansion -> spring `response 0.3`, `dampingFraction 0.8`.

- `AiQoSkeletonView` shimmer -> linear duration `1.2`.

### Shadow / Sheet / Glass Rules

`AiQoShadow` uses adaptive black opacity, radius `16`, and vertical offset `7`.

`AiQoSheetStyle` uses `.ultraThinMaterial`, radius `28`, and a visible drag indicator.

Glassmorphism is common in premium/community surfaces and Captain-adjacent cards through glass cards, material fills, and soft translucent strokes.

### RTL Rules

Arabic root screens frequently force `.rightToLeft` at the screen boundary.

Selective `.leftToRight` overrides are used for rails, segmented controls, charts, or directional affordances where the visual language benefits from LTR orientation.

### Evidence Files

- `AiQo/DesignSystem/AiQoColors.swift`

- `AiQo/DesignSystem/AiQoTheme.swift`

- `AiQo/DesignSystem/AiQoTokens.swift`

- `AiQo/DesignSystem/Components/AiQoBottomCTA.swift`

- `AiQo/DesignSystem/Components/AiQoCard.swift`

- `AiQo/DesignSystem/Components/AiQoPillSegment.swift`

- `AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift`

- `AiQo/DesignSystem/Modifiers/AiQoShadow.swift`

- `AiQo/DesignSystem/Modifiers/AiQoSheetStyle.swift`

- `AiQo/UI/GlassCardView.swift`

- `AiQo/UI/AccessibilityHelpers.swift`

- `AiQo/Core/Colors.swift`

## SECTION 16 — Apple Watch Companion

### Current Status

The watch companion exists and is actively implemented.

The requested `AiQoWatch/*.swift` layout does not exist; the real target folder is `AiQoWatch Watch App/`.

### WatchConnectivity Integration Points

- `AiQoWatch Watch App/WatchConnectivityManager.swift` on the watch side.

- `AiQoWatch Watch App/Services/WatchConnectivityService.swift` on the watch side.

- `AiQo/PhoneConnectivityManager.swift` on the phone side.

- `AiQo/Features/Gym/WatchConnectivityService.swift` and live session screens on the phone side.

### Implemented Watch Features

Watch home stats view.

Watch workout list and live active workout views.

Mirrored workout session state, snapshots, and workout summary handoff.

HealthKit reading on watch for steps, calories, distance, heart rate, sleep, and workouts.

### Data Sync Strategy

The app uses `WCSession` messaging plus codable sync payloads in `WorkoutSyncCodec` / `WorkoutSyncModels`.

Phone-side widgets also rely on app-group/shared storage for certain metrics/goal mirrors.

### Planned / Implied Next Steps From Code

A TODO remains in `AiQo/PhoneConnectivityManager.swift:756` to integrate watch-earned XP directly into `LevelStore.shared.addXP(xp)`.

### Evidence Files

- `AiQoWatch Watch App/AiQoWatchApp.swift`

- `AiQoWatch Watch App/WatchConnectivityManager.swift`

- `AiQoWatch Watch App/Services/WatchConnectivityService.swift`

- `AiQoWatch Watch App/Services/WatchHealthKitManager.swift`

- `AiQoWatch Watch App/Services/WatchWorkoutManager.swift`

- `AiQoWatch Watch App/WorkoutManager.swift`

- `AiQo/PhoneConnectivityManager.swift`

## SECTION 17 — Analytics & Crash Reporting

### Analytics Service API

`AnalyticsService.shared.track(_:)` records events with enriched super properties.

`AnalyticsService.shared.identify(userId:traits:)` stores user identity and forwards it to providers.

`AnalyticsService.shared.reset()` clears the current identity and local provider state.

`AnalyticsService.shared.setSuperProperty(_:value:)` adds enriched properties to future events.

### Active Providers

DEBUG builds register `ConsoleAnalyticsProvider`.

All builds register `LocalAnalyticsProvider`, which writes JSONL to `Application Support/Analytics/events.jsonl` and trims to `5000` events.

No third-party analytics SDK is currently wired into the live tree.

### Events Defined In Source

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

### Crash Reporting

`CrashReporter` is a local crash/non-fatal logger with exception handler, signal handler, and previous-crash detection.

Crash logs are stored at `Application Support/CrashReports/crash_log.jsonl` and trimmed to `50` records.

`aiqo.crash.didTerminateCleanly` is used to detect likely previous-session crashes.

Non-fatal recordings also emit analytics `error_occurred` events.

### Current Gaps

There is no remote crash backend (Sentry, Crashlytics, etc.) wired in the checked-in project.

There is no remote analytics vendor wired in the checked-in project.

### Evidence Files

- `AiQo/Services/Analytics/AnalyticsEvent.swift`

- `AiQo/Services/Analytics/AnalyticsService.swift`

- `AiQo/Services/CrashReporting/CrashReporter.swift`

## SECTION 18 — Accessibility & Localization

### VoiceOver Support Status

Accessibility helper modifiers exist: `accessibleButton`, `accessibleInfo`, `accessibleHeader`, `accessibleCard`, `accessibilityDecorative`.

Confirmed usage in scanned code is limited rather than universal; for example, `PremiumPaywallView` applies `accessibleButton`, but most large screens still use raw SwiftUI controls.

Status assessment: partial / framework-ready, not comprehensively audited.

### Dynamic Type Support

Dynamic type helpers exist in `UI/AccessibilityHelpers.swift` and `Core/AiQoAccessibility.swift`.

Support is mixed: some shared helpers are ready, but many views still hard-code font sizes.

### Reduce Motion

A `respectsReduceMotion()` helper exists and disables animation transactions when `UIAccessibility.isReduceMotionEnabled` is true.

No code-wide enforcement pass is visible; usage is opt-in.

### Localization Strategy

The app ships Arabic and English `Localizable.strings` and `InfoPlist.strings` files.

Arabic localized-string entries counted from file: `1854`.

English localized-string entries counted from file: `1855`.

`LocalizationManager` writes `AppleLanguages` and reloads saved language on launch.

### RTL Patterns

`AppRootView` sets layout direction from `AppSettingsStore.shared.appLanguage`.

Many screens force `.rightToLeft` explicitly, including main tabs, login/profile onboarding, tribe views, captain screens, legendary challenge views, and watch views.

Some components intentionally force `.leftToRight` to stabilize visual structure, especially rails and some impact/club subviews.

### Evidence Files

- `AiQo/UI/AccessibilityHelpers.swift`

- `AiQo/Core/AiQoAccessibility.swift`

- `AiQo/Core/AppSettingsStore.swift`

- `AiQo/Core/Localization/LocalizationManager.swift`

- `AiQo/Resources/ar.lproj/Localizable.strings`

- `AiQo/Resources/en.lproj/Localizable.strings`

## SECTION 19 — Feature Flags & Configuration

### Info.plist Feature / Service Keys

- `CAPTAIN_API_KEY` -> `$(CAPTAIN_API_KEY)`

- `CAPTAIN_ARABIC_API_URL` -> `$(CAPTAIN_ARABIC_API_URL)`

- `CAPTAIN_VOICE_API_KEY` -> `$(CAPTAIN_VOICE_API_KEY)`

- `CAPTAIN_VOICE_API_URL` -> `$(CAPTAIN_VOICE_API_URL)`

- `CAPTAIN_VOICE_MODEL_ID` -> `$(CAPTAIN_VOICE_MODEL_ID)`

- `CAPTAIN_VOICE_VOICE_ID` -> `$(CAPTAIN_VOICE_VOICE_ID)`

- `COACH_BRAIN_LLM_API_KEY` -> `$(COACH_BRAIN_LLM_API_KEY)`

- `COACH_BRAIN_LLM_API_URL` -> `$(COACH_BRAIN_LLM_API_URL)`

- `SPIRITUAL_WHISPERS_LLM_API_KEY` -> ``

- `SPIRITUAL_WHISPERS_LLM_API_URL` -> `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent`

- `SPOTIFY_CLIENT_ID` -> `$(SPOTIFY_CLIENT_ID)`

- `SUPABASE_URL` -> `$(SUPABASE_URL)`

- `SUPABASE_ANON_KEY` -> `$(SUPABASE_ANON_KEY)`

- `TRIBE_BACKEND_ENABLED` -> `true`

- `TRIBE_FEATURE_VISIBLE` -> `true`

- `TRIBE_SUBSCRIPTION_GATE_ENABLED` -> `true`

### What The Main Flags Control

`TRIBE_BACKEND_ENABLED` controls repository selection between live Supabase-backed repositories and local/mock repositories.

`TRIBE_FEATURE_VISIBLE` controls whether Tribe surfaces should be presented as available in the app shell.

`TRIBE_SUBSCRIPTION_GATE_ENABLED` controls premium gating for Tribe/community flows.

Captain/Gemini/voice keys wire cloud AI, coach translation, and voice services.

Supabase keys wire auth and backend tables.

Spotify client ID wires vibe/workout music integration.

### Other Runtime Configuration

URL schemes found in plist:

- `aiqo`

- `aiqo-spotify`

Queried external schemes found in plist:

- `spotify`

- `instagram-stories`

- `instagram`

NSUserActivity types found in plist:

- `com.aiqo.startWalk`

- `com.aiqo.startRun`

- `com.aiqo.startHIIT`

- `com.aiqo.openCaptain`

- `com.aiqo.todaySummary`

- `com.aiqo.logWater`

- `com.aiqo.openKitchen`

- `com.aiqo.weeklyReport`

`Configuration/AiQo.xcconfig` includes `Secrets.xcconfig` and contains build-time placeholders and module settings.

`Configuration/Secrets.xcconfig` contains actual secret material and should be treated as sensitive configuration.

DEBUG StoreKit setting in `PurchaseManager`: `useLocalStoreKitConfig = true` with config name `AiQo_Test.storekit`.

### Launch Control Guidance From Current Code

To hide Tribe while keeping code intact, switch the tribe plist flags and/or point repositories to mock mode.

To disable premium network dependencies in DEBUG, the local StoreKit configuration path is already available.

To disable Captain cloud calls, removing/blanking Captain/Gemini keys would force more fallback behavior but is not exposed as a first-class feature flag.

### Evidence Files

- `AiQo/Info.plist`

- `Configuration/AiQo.xcconfig`

- `Configuration/Secrets.xcconfig`

- `AiQo/Tribe/Models/TribeFeatureModels.swift`

- `AiQo/Core/Purchases/PurchaseManager.swift`

## SECTION 20 — Known Issues, Gaps & Roadmap

### Confirmed Issues / Risks With File References

- `AiQo/App/MainTabRouter.swift:9-14` defines five tabs, but `AiQo/App/MainTabScreen.swift` only renders three visible tabs. Kitchen and Tribe are indirect/hidden routes rather than first-class tabs.

- `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift` exists but `rg` shows no live references outside its own preview; the current onboarding flow bypasses it entirely.

- `AiQo/App/ProfileSetupView.swift:195` defines `SetupPrivacyToggleCard`, and `rg` shows no usages anywhere else in the repo.

- `AiQo/PhoneConnectivityManager.swift:756` contains a TODO to integrate watch-earned XP into `LevelStore.shared.addXP(xp)`.

- `AiQo/Features/Profile/LevelCardView.swift:236-238`, `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:268-300`, and `AiQo/Core/Models/LevelStore.swift:134-152` show two parallel leveling systems: legacy `aiqo.currentLevel` keys and modern `aiqo.user.level` keys.

- `AiQo/Tribe/TribeStore.swift:77` and `:115` explicitly log that creation/join flows still use local stub data until Supabase tribe tables are ready.

- `AiQo/Features/Tribe/TribeExperienceFlow.swift:202-221` labels community feed, challenges, and invites as placeholders.

- `AiQo/Features/Gym/HeartView.swift:3` is marked as a future-release / post-launch feature.

- `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:248` and `:418` still contain V2/post-launch hooks for real camera execution and real Arena event integration.

- `Configuration/Secrets.xcconfig` stores live-looking secrets in the repo, which is a security risk and release-process issue.

### UI / UX Gaps Visible From Code Comments And Structure

Tribe/community still mixes premium marketing shell, preview mode, local stubs, and live Supabase-backed leaderboard/service code.

The leveling system has not fully converged on one canonical source of truth.

Some accessibility helpers exist but have not been applied consistently across the app.

Onboarding contains at least one unused screen path and one unused setup component, which increases maintenance cost.

### Missing Before TestFlight (inference from current code/comments)

Converge legacy XP keys into the modern `LevelStore` or fully retire one path.

Finish live Tribe create/join/member flows so the preview/local-stub split is removed.

Resolve the watch XP TODO if workout rewards must feel consistent across phone/watch sessions.

Audit committed secrets and move them out of source control.

Run a navigation review for kitchen/tribe discoverability because the symbolic router and visible tabs diverge.

### Missing Before App Store Launch (inference from current code/comments)

Replace preview/placeholder Tribe copy with production community functionality or explicitly gate/hide those surfaces.

Decide whether Heart / V2 Quest camera / future Arena hooks are launch-scope or must remain hidden.

Add a production remote crash/analytics backend if operations visibility is required at scale.

Lock the backend policy/migration story because RLS and schema migrations are not versioned in this repo.

### Post-Launch / Ongoing Roadmap Signals Found In Code

Expand Tribe/Arena into fully live graph/event streams.

Complete the LegendaryChallenges migration from `UserDefaults` to `RecordProjectManager` SwiftData persistence.

Expand on-device coaching and structured output flows wherever `FoundationModels` is available.

Continue building watch-connected workout and reward loops.

### Evidence Files

- `AiQo/App/MainTabRouter.swift`

- `AiQo/App/MainTabScreen.swift`

- `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift`

- `AiQo/App/ProfileSetupView.swift`

- `AiQo/PhoneConnectivityManager.swift`

- `AiQo/Tribe/TribeStore.swift`

- `AiQo/Features/Tribe/TribeExperienceFlow.swift`

- `AiQo/Features/Gym/HeartView.swift`

- `AiQo/Features/Gym/QuestKit/QuestDataSources.swift`

- `AiQo/Core/Models/LevelStore.swift`

- `AiQo/Features/Profile/LevelCardView.swift`

- `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift`

- `Configuration/Secrets.xcconfig`

## Verification Footer

Total filtered scanned files documented in the Section 3 ledger: `482`.

Total filtered scanned directories documented in the Section 3 tree: `153`.

The blueprint intentionally reports missing requested files instead of creating fictional architecture layers.
