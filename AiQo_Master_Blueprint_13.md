# AiQo — Master Blueprint 13

**Generated:** 2026-04-09T00:00:00+04:00
**Previous Blueprint:** AiQo_Master_Blueprint_12.md
**Codebase Commit:** ed4b199b25b016b3eab1c5d08685b923d3245d84
**Auditor:** Codex deep audit pass

---

## 0. Executive Summary
AiQo is still an Arabic-first SwiftUI wellness app with a real multi-target architecture, not a prototype: the current repo contains 423 Swift files and 106,104 Swift lines across the iPhone app, watch app, widgets, and tests. The composition root lives in `AiQo/App/AppDelegate.swift:12` and `AiQo/App/SceneDelegate.swift:17`, with a dedicated Captain SwiftData container plus a separate app-wide container for daily records and Tribe models in `AiQo/App/AppDelegate.swift:18` and `AiQo/App/AppDelegate.swift:80`.

The biggest architectural win since Blueprint 12 is that several previously stale claims are now genuinely reworked in code. Notifications are no longer broadly Arabic-only because `NotificationLocalization` now feeds the scheduler paths in `AiQo/Services/Notifications/NotificationLocalization.swift:3` and `AiQo/Services/Notifications/NotificationService.swift:257`. Watch goals are no longer hardcoded in the home UI; they come from the shared app-group store in `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:8`, `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:50`, and `AiQoWatch Watch App/Views/WatchHomeView.swift:12`. Supabase secrets are no longer hardcoded in `Info.plist`; build-time variables now back the keys in `AiQo/Info.plist:70` and `Configuration/AiQo.xcconfig:13`.

The Captain stack remains the app’s strongest subsystem. Routing, fallback, sanitization, prompt building, memory persistence, and post-reply extraction are all present and cross-wired in live code through `AiQo/Features/Captain/BrainOrchestrator.swift:36`, `AiQo/Features/Captain/CloudBrainService.swift:48`, `AiQo/Features/Captain/HybridBrainService.swift:300`, `AiQo/Features/Captain/PrivacySanitizer.swift:95`, `AiQo/Features/Captain/CaptainPromptBuilder.swift:11`, `AiQo/Core/MemoryStore.swift:133`, and `AiQo/Core/MemoryExtractor.swift:18`. The recent “Context Assembly layer” names discussed outside the repo did not land verbatim; the live equivalent is `CaptainContextBuilder` in `AiQo/Features/Captain/CaptainContextBuilder.swift:134`.

The biggest product drift since Blueprint 12 is monetization. The runtime, StoreKit IDs, and paywall are now fully two-tier, not three-tier. `PremiumPlan` only exposes `.core` and `.intelligencePro` in `AiQo/Premium/PremiumStore.swift:5`, `SubscriptionTier` only maps `.none`, `.core`, and `.intelligencePro` in `AiQo/Core/Purchases/SubscriptionTier.swift:4`, `SubscriptionProductIDs.allCurrentIDs` contains only two SKUs in `AiQo/Core/Purchases/SubscriptionProductIDs.swift:20`, and `PaywallView` explicitly markets “Two clear options only” in `AiQo/UI/Purchases/PaywallView.swift:20` and `AiQo/UI/Purchases/PaywallView.swift:259`.

The biggest unresolved risks are still launch-facing. Tribe code is hidden in UI flags but still compiled and network-capable through `AiQo/Info.plist:74`, `AiQo/Info.plist:76`, `AiQo/Info.plist:78`, and `AiQo/Services/SupabaseArenaService.swift:10`. Analytics remain local-only in `AiQo/Services/Analytics/AnalyticsService.swift:27`, `AiQo/Services/Analytics/AnalyticsService.swift:29`, and `AiQo/Services/Analytics/AnalyticsService.swift:138`. Crash reporting has a Firebase wrapper in `AiQo/Services/CrashReporting/CrashReportingService.swift:5` and `AiQo/Services/CrashReporting/CrashReportingService.swift:21`, but the current Xcode project still contains no `Firebase` or `Crashlytics` references in `AiQo.xcodeproj/project.pbxproj`.

TestFlight readiness is better than BP12 on secrets and watch-goal correctness, but still constrained by observability and stale feature surface area. Internal TestFlight is viable once the team accepts local-only analytics and partial crash reporting; public TestFlight still carries risk from hidden Tribe shipping, onboarding drift from the desired reorder, and notification hardcodes still present in inactivity flows (`AiQo/Services/Notifications/NotificationService.swift:468`). AUE launch readiness is lower because Tribe, monetization messaging, and onboarding intent have diverged from the latest product decisions even though the underlying app remains shippable.

---

## 1. What Changed Since Blueprint 12
### 1.1 New Files
- `AiQo/Features/Captain/CaptainAvatar3DView.swift` — new RealityKit-based Captain avatar surface that `CaptainScreen` now mounts at `AiQo/Features/Captain/CaptainAvatar3DView.swift:11` and `AiQo/Features/Captain/CaptainScreen.swift:213`.
- `AiQo/Services/Notifications/NotificationLocalization.swift` — new locale resolution helper used by the notification stack, starting at `AiQo/Services/Notifications/NotificationLocalization.swift:3`.
- `AiQo/my 2.usdz` — new 3D asset consumed indirectly by `CaptainAvatar3DView`, which loads `Entity(named: "my", in: .main)` at `AiQo/Features/Captain/CaptainAvatar3DView.swift:35`.

### 1.2 Modified Subsystems
- Captain chat surface changed from a 2D-only presentation to a RealityKit avatar-backed screen; the new avatar is wired into `CaptainScreen` at `AiQo/Features/Captain/CaptainScreen.swift:213`, while response handling and persistence were also updated in `AiQo/Features/Captain/CaptainViewModel.swift:381` and `AiQo/Core/MemoryStore.swift:322`.
- Notifications changed from mostly hardcoded Arabic bodies to a partially localized system. Water, meal, step, and sleep notifications now resolve localized keys through `AiQo/Services/Notifications/NotificationService.swift:257`, `AiQo/Services/Notifications/NotificationService.swift:300`, `AiQo/Services/Notifications/NotificationService.swift:307`, and `AiQo/Services/Notifications/NotificationService.swift:409`, backed by `AiQo/Services/Notifications/NotificationLocalization.swift:3`.
- Monetization changed from a documented three-tier plan to a live two-tier runtime. The active plan enums and product IDs were reduced in `AiQo/Premium/PremiumStore.swift:5`, `AiQo/Core/Purchases/SubscriptionTier.swift:4`, and `AiQo/Core/Purchases/SubscriptionProductIDs.swift:20`, and the paywall copy now explicitly reflects two cards in `AiQo/UI/Purchases/PaywallView.swift:259` and `AiQo/UI/Purchases/PaywallView.swift:373`.
- Watch configuration changed from fixed daily goals to shared, app-group-driven goals through `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:8`, `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:50`, and `AiQoWatch Watch App/Views/WatchHomeView.swift:12`.
- App configuration changed from hardcoded Supabase fallbacks in `Info.plist` to build-variable-backed secrets in `AiQo/Info.plist:70` and `Configuration/AiQo.xcconfig:13`.
- Tribe persistence and views were modified, but the feature remains intentionally hidden. The live flags are still false in `AiQo/Info.plist:74`, `AiQo/Info.plist:76`, and `AiQo/Info.plist:78`, and the remaining live-code TODOs sit in `AiQo/Features/Tribe/TribeExperienceFlow.swift:190`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:205`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:299`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:348`, and `AiQo/Features/Tribe/TribeExperienceFlow.swift:369`.

### 1.3 Removed or Deprecated
- No tracked repo files were deleted between BP12’s audited commit (`8bcb9ec`) and the current head; the delta is additions plus in-place modification, not removals.
- The three-tier subscription runtime described in BP12 is effectively deprecated in place. `proMonthly` survives only as a compatibility ID in `AiQo/Core/Purchases/SubscriptionProductIDs.swift:10` and `AiQo/Core/Purchases/SubscriptionProductIDs.swift:26`, while current saleable tiers are only the two IDs listed in `AiQo/Core/Purchases/SubscriptionProductIDs.swift:20`.
- BP12’s path assumptions for `AiQo/Core/BrainOrchestrator.swift`, `AiQo/Core/LocalBrain.swift`, `AiQo/Core/CloudBrain.swift`, and `AiQo/Core/PrivacySanitizer.swift` are stale. Those files do not exist in the current tree; the live implementations sit under `AiQo/Features/Captain/` beginning at `AiQo/Features/Captain/BrainOrchestrator.swift:11`, `AiQo/Features/Captain/LocalBrainService.swift:1`, `AiQo/Features/Captain/CloudBrainService.swift:11`, and `AiQo/Features/Captain/PrivacySanitizer.swift:14`.
- `OnboardingWalkthroughView` is still present in the repo at `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:4`, but the live onboarding state machine in `AiQo/App/SceneDelegate.swift:20` and `AiQo/App/SceneDelegate.swift:266` never routes to it, so it is currently orphaned rather than removed.

### 1.4 Blueprint 12 Claims — Verification Table
| Claim from BP12 | Status | Evidence (file:line) |
|---|---|---|
| Captain chat is a shipped hybrid stack | Confirmed | Live routing, cloud, local, and fallback paths remain wired in `AiQo/Features/Captain/BrainOrchestrator.swift:36`, `AiQo/Features/Captain/CloudBrainService.swift:11`, `AiQo/Features/Captain/HybridBrainService.swift:150`, and `AiQo/Features/Captain/LocalBrainService.swift:62`. |
| Captain Memory shipped with 200/500 cap | Confirmed | Tier cap still comes from `AiQo/Premium/AccessManager.swift:58` and is enforced in `AiQo/Core/MemoryStore.swift:17` and `AiQo/Core/MemoryStore.swift:65`. |
| Captain Voice uses ElevenLabs with fallback | Confirmed | ElevenLabs transport and fallback remain in `AiQo/Core/CaptainVoiceAPI.swift:8`, `AiQo/Core/CaptainVoiceAPI.swift:118`, `AiQo/Core/CaptainVoiceService.swift:37`, and `AiQo/Core/CaptainVoiceService.swift:212`. |
| Sleep Architecture is shipped | Confirmed | Sleep feature files remain live in `AiQo/Features/Sleep/SmartWakeEngine.swift:19`, `AiQo/Features/Sleep/SmartWakeViewModel.swift:103`, `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:1`, and `AiQo/Features/Sleep/SleepSessionObserver.swift:1`. |
| Smart Wake shipped with 3 window sizes and confidence scoring | Confirmed | Window sizes and confidence are still defined in `AiQo/Features/Sleep/SmartWakeEngine.swift:19`, `AiQo/Features/Sleep/SmartWakeEngine.swift:46`, and `AiQo/Features/Sleep/SmartWakeEngine.swift:232`. |
| Alchemy Kitchen is shipped | Confirmed | Kitchen root, image path, and plan generation are live in `AiQo/Features/Kitchen/KitchenView.swift:4`, `AiQo/Features/Kitchen/KitchenView.swift:34`, and `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:3`. |
| My Vibe is shipped | Confirmed | `MyVibeScreen` and the orchestration stack remain live in `AiQo/Features/MyVibe/MyVibeScreen.swift:3`, `AiQo/Features/MyVibe/VibeOrchestrator.swift:13`, `AiQo/Core/VibeAudioEngine.swift:138`, and `AiQo/Core/SpotifyVibeManager.swift:14`. |
| Legendary Challenges is shipped | Confirmed | The section and persistence models remain active in `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift:5`, `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:5`, and `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:5`. |
| HRR Assessment is shipped | Confirmed | HRR assessment still runs through `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:6` and `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift:57`. |
| Weekly Report is shipped | Confirmed | Weekly report UI and export remain in `AiQo/Features/WeeklyReport/WeeklyReportView.swift:4`, `AiQo/Features/WeeklyReport/WeeklyReportView.swift:182`, and `AiQo/Features/DataExport/HealthDataExporter.swift:7`. |
| Onboarding is a 6-screen shipped flow | Changed | The live flow is now `languageSelection -> login -> profileSetup -> legacy -> featureIntro -> main` via `AiQo/App/SceneDelegate.swift:20`, `AiQo/App/SceneDelegate.swift:52`, `AiQo/App/SceneDelegate.swift:91`, `AiQo/App/SceneDelegate.swift:171`, and `AiQo/App/SceneDelegate.swift:266`; `OnboardingWalkthroughView` exists but is unused at `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:4`. |
| Tribe is hidden via flags | Confirmed | The feature is still hidden with all three Info.plist flags set in `AiQo/Info.plist:74`, `AiQo/Info.plist:76`, and `AiQo/Info.plist:78`, and runtime readers are in `AiQo/Tribe/Models/TribeFeatureModels.swift:27`. |
| Tribe has 5 TODOs for live Supabase replacement | Confirmed | The remaining TODOs are still present in `AiQo/Features/Tribe/TribeExperienceFlow.swift:190`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:205`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:299`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:348`, and `AiQo/Features/Tribe/TribeExperienceFlow.swift:369`. |
| Notifications are shipped | Confirmed | Notification scheduling still spans `AiQo/Services/Notifications/NotificationService.swift:13`, `AiQo/Core/SmartNotificationScheduler.swift:236`, `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:155`, and `AiQo/Services/Notifications/PremiumExpiryNotifier.swift:96`. |
| Three subscription tiers exist at runtime | Changed | Live runtime tiers are now only `.none`, `.core`, and `.intelligencePro` in `AiQo/Core/Purchases/SubscriptionTier.swift:4`, with only two current SKUs in `AiQo/Core/Purchases/SubscriptionProductIDs.swift:20`. |
| Paywall UI still shows three tiers | Removed | The live paywall supports only two tiers in `AiQo/UI/Purchases/PaywallView.swift:20`, and the copy explicitly says “Two clear options only” at `AiQo/UI/Purchases/PaywallView.swift:259`. |
| Hardcoded Supabase credentials remain in Info.plist | Removed | `Info.plist` now resolves keys from build variables at `AiQo/Info.plist:70`, and `Configuration/AiQo.xcconfig:13` carries the injected placeholders rather than plaintext secrets. |
| Health/Alarm usage descriptions are missing English base values | Removed | Base English alarm and HealthKit usage descriptions now exist in `AiQo/Info.plist:46`, `AiQo/Info.plist:48`, and `AiQo/Info.plist:50`, with localized overrides in `AiQo/Resources/en.lproj/InfoPlist.strings:2`. |
| No remote analytics | Confirmed | Analytics providers are still only console and local JSONL in `AiQo/Services/Analytics/AnalyticsService.swift:27`, `AiQo/Services/Analytics/AnalyticsService.swift:29`, and `AiQo/Services/Analytics/AnalyticsService.swift:138`. |
| Deep link gaps exist | Confirmed | `settings` still routes home and `premium` still relies on pending deep-link state in `AiQo/Services/DeepLinkRouter.swift:52` and `AiQo/Services/DeepLinkRouter.swift:56`. |
| Duplicated workout completion events from watch | Changed | The old BP12 duplication is less obvious now: `WatchConnectivityService` still sends completions at `AiQoWatch Watch App/Services/WatchConnectivityService.swift:35`, but the explicit second send path BP12 cited is no longer obvious in the current `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:10`; iPhone XP handling still exists at `AiQo/PhoneConnectivityManager.swift:756`. |
| Hard-coded Watch goals | Removed | Watch goals now come from shared defaults in `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:8`, `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:50`, and are consumed in `AiQoWatch Watch App/Views/WatchHomeView.swift:12`. |
| InactivityTracker default suppresses first-run inactivity | Confirmed | The tracker still relies on a persisted `lastActiveDate` key in `AiQo/Services/Notifications/InactivityTracker.swift:6`, and the notification gate still computes inactivity from that state in `AiQo/Services/Notifications/NotificationService.swift:175`. |
| Duplicated onboarding completion check exists | Confirmed | App bootstrap still repeats onboarding-complete logic in `AiQo/App/AppDelegate.swift:131` and `AiQo/App/AppDelegate.swift:177`. |
| Arabic-only notification bodies | Changed | Water, meal, step, and sleep paths now go through localized keys in `AiQo/Services/Notifications/NotificationService.swift:257`, `AiQo/Services/Notifications/NotificationService.swift:300`, `AiQo/Services/Notifications/NotificationService.swift:307`, and `AiQo/Services/Notifications/NotificationService.swift:409`, but inactivity prompts and fallbacks still contain hardcoded text at `AiQo/Services/Notifications/NotificationService.swift:468`, `AiQo/Services/Notifications/NotificationService.swift:492`, `AiQo/Services/Notifications/NotificationService.swift:498`, and `AiQo/Services/Notifications/NotificationService.swift:504`. |
| CrashReporting is a placeholder | Changed | There is now a real Firebase wrapper in `AiQo/Services/CrashReporting/CrashReportingService.swift:5` and `AiQo/Services/CrashReporting/CrashReportingService.swift:21`, but the project file still has no Firebase linkage and the local JSONL crash logger remains in `AiQo/Services/CrashReporting/CrashReporter.swift:19`. |
| WatchConnectivityService redundancy | Confirmed | The polling wrapper still exists with a 2-second timer in `AiQoWatch Watch App/Services/WatchConnectivityService.swift:9` and `AiQoWatch Watch App/Services/WatchConnectivityService.swift:18`. |
| 15 files exceed 1,000 LOC | Changed | The current manifest scan shows 14 files over 1,000 LOC, still led by `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:1`, `AiQo/Services/SupabaseArenaService.swift:10`, `AiQoWatch Watch App/WorkoutManager.swift:17`, and `AiQo/Services/Notifications/NotificationService.swift:13`. |
| AnalyticsEvent is not Sendable | Confirmed | `AnalyticsEvent` still stores `[String: Any]` in `AiQo/Services/Analytics/AnalyticsEvent.swift:8`. |
| No offline queue for Supabase writes | Confirmed | `SupabaseService` still writes directly to `profiles` in `AiQo/Services/SupabaseService.swift:141`, and `SupabaseArenaService` still performs direct live sync methods such as `AiQo/Services/SupabaseArenaService.swift:554` and `AiQo/Services/SupabaseArenaService.swift:930` with no durable queue layer. |
| Kitchen notification routing is fragile | Confirmed | The deep-link path still posts `openKitchenFromHome` in `AiQo/App/MainTabRouter.swift:33`, and `HomeView` still depends on observing that notification at `AiQo/Features/Home/HomeView.swift:91`. |
| `logout()` skips language reset | Confirmed | `logout()` clears four onboarding keys but not language in `AiQo/App/SceneDelegate.swift:145`. |
| Local analytics are unbatched | Confirmed | The local provider still appends JSONL on every event in `AiQo/Services/Analytics/AnalyticsService.swift:157` and `AiQo/Services/Analytics/AnalyticsService.swift:160`. |
| XP formula is hardcoded in PhoneConnectivityManager | Confirmed | The watch completion formula still uses `Int(cal * 0.8 + dur * 2)` at `AiQo/PhoneConnectivityManager.swift:756`, separate from `AiQo/XPCalculator.swift:23`. |
| Background notification prompts are Arabic-only | Changed | Background prompt composition now uses localized keys in `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:23`, `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:64`, and `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:105`, with localized profile summary fallback in `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:162`. |
| `TRIBE_BACKEND_ENABLED = true` | Changed | The live flag is now false in `AiQo/Info.plist:74`. |
| Three-tier subscription structure agreed but PaywallView not updated | Changed | The runtime and UI have both moved to two tiers in `AiQo/Premium/PremiumStore.swift:5`, `AiQo/Core/Purchases/SubscriptionProductIDs.swift:20`, and `AiQo/UI/Purchases/PaywallView.swift:20`. |
| Eleven remaining TODOs in Tribe files | Changed | Only five TODOs remain, all in `AiQo/Features/Tribe/TribeExperienceFlow.swift:190`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:205`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:299`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:348`, and `AiQo/Features/Tribe/TribeExperienceFlow.swift:369`. |
| Hardcoded values remain in MorningHabitOrchestrator, NotificationService, and HybridBrainService | Confirmed | Wake monitoring still hardcodes threshold/window in `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:35`, notification cooldowns remain hardcoded in `AiQo/Services/Notifications/NotificationService.swift:435`, and Gemini output tuning remains inline in `AiQo/Features/Captain/HybridBrainService.swift:300`. |
| Double `@` username display bug exists | Confirmed | Leaderboard rows still prepend `@` in `AiQo/Tribe/Views/TribeLeaderboardView.swift:96`, while profile setup strips leading `@` only on save in `AiQo/App/ProfileSetupView.swift:145`. |
| Tribe member XP/level shows 0 / Level 1 instead of LevelStore | Confirmed | Non-current users still get fallback values in `AiQo/Tribe/Galaxy/TribeMembersList.swift:28` and `AiQo/Tribe/Galaxy/TribeMembersList.swift:29`. |
| Fragmented analytics across four sources | Changed | Analytics and crash data are still fragmented across `AiQo/Services/Analytics/AnalyticsService.swift:27`, `AiQo/Services/CrashReporting/CrashReportingService.swift:21`, `AiQo/Services/CrashReporting/CrashReporter.swift:19`, and iOS/watch logging scattered through service files, but the exact “four sources” wording from BP12 is now better described as “local analytics plus two crash channels plus ad hoc console logging.” |
| Recent addition: `UserTrainingProfile` SwiftData model | Not Found | No symbol named `UserTrainingProfile` exists in the current Swift tree; the closest live onboarding/profile persistence remains `AiQo/Core/UserProfileStore.swift:6` and `AiQo/App/ProfileSetupView.swift:154`. |
| Recent addition: `GoalsAndSleepSetupView` | Not Found | No `GoalsAndSleepSetupView` exists, and the live onboarding transitions directly from profile to legacy classification in `AiQo/App/SceneDelegate.swift:52` and then to feature intro in `AiQo/App/SceneDelegate.swift:91`. |
| Recent addition: named Captain Context Assembly layer (`CaptainContextBundle`, `IntentDetector`, `LexicalMemoryRetriever`, `BiometricsContextProvider`, `TemporalContextProvider`, `CaptainContextAssembler`, `CaptainPromptComposer`) | Changed | None of those symbols exist, but the current equivalent context pipeline is `CaptainContextBuilder` in `AiQo/Features/Captain/CaptainContextBuilder.swift:134` and its consumers in `AiQo/Features/Captain/CaptainViewModel.swift:399` and `AiQo/Features/Captain/CaptainIntelligenceManager.swift:504`. |
| Recent addition: onboarding reorder moving level classification to the end | Not Found | The live flow still sends profile completion to `.legacy` immediately in `AiQo/App/SceneDelegate.swift:52`, and root rendering still places `LegacyCalculationScreenView` before `FeatureIntroView` in `AiQo/App/SceneDelegate.swift:278` and `AiQo/App/SceneDelegate.swift:281`. |
| Recent addition: wake alarm scheduling via NotificationService | Confirmed | Smart Wake now persists alarms through `AiQo/Features/Sleep/SmartWakeViewModel.swift:103`, `AiQo/Features/Sleep/SmartWakeViewModel.swift:130`, and `AiQo/Services/Notifications/AlarmSchedulingService.swift:166`, which hands the selected wake time to `MorningHabitOrchestrator` at `AiQo/Services/Notifications/AlarmSchedulingService.swift:189`. |

---

## 2. Directory Structure
The live tree below is limited to three levels deep for readability. Widgets and tests are covered exhaustively in Section 14.

```text
AiQo/ (540 files total)
  AiQoCore/ (2)
  App/ (10)
  Core/ (36)
    Localization/ (2)
    Models/ (3)
    Purchases/ (5)
    Utilities/ (2)
  DesignSystem/ (13)
    Components/ (7)
    Modifiers/ (3)
  Features/ (213)
    Captain/ (26)
    DataExport/ (1)
    First screen/ (1)
    Gym/ (84)
    Home/ (21)
    Kitchen/ (33)
    LegendaryChallenges/ (15)
    MyVibe/ (5)
    Onboarding/ (3)
    Profile/ (6)
    ProgressPhotos/ (2)
    Sleep/ (9)
    Tribe/ (3)
    WeeklyReport/ (4)
  Frameworks/ (34)
    SpotifyiOS.framework/ (34)
  Premium/ (5)
  Resources/ (120)
    Assets.xcassets/ (112)
    Specs/ (1)
    ar.lproj/ (2)
    en.lproj/ (2)
  Services/ (24)
    Analytics/ (2)
    CrashReporting/ (3)
    Notifications/ (10)
    Permissions/ (2)
  Shared/ (5)
  Tribe/ (58)
    Arena/ (1)
    Galaxy/ (37)
    Log/ (1)
    Models/ (2)
    Preview/ (2)
    Repositories/ (1)
    Stores/ (3)
    Views/ (5)
  UI/ (9)
    Purchases/ (1)
  watch/ (1)

AiQoWatch Watch App/ (62 files total)
  Assets.xcassets/ (36)
    AccentColor.colorset/ (1)
    AiQoLogo.imageset/ (2)
    AppIcon.appiconset/ (32)
  Design/ (1)
  Models/ (1)
  Services/ (3)
  Shared/ (2)
  Views/ (4)
```

---

## 3. Core Architecture

### 3.1 App Entry & Composition Root
There is no live `AiQo/App/AiQoApp.swift`; the app entry point is `@main struct AiQoApp` inside `AiQo/App/AppDelegate.swift:12`. That file creates a dedicated Captain `ModelContainer` containing `CaptainMemory`, `PersistentChatMessage`, `RecordProject`, and `WeeklyLog` in `AiQo/App/AppDelegate.swift:18`, persists it to `captain_memory.store` in `AiQo/App/AppDelegate.swift:30`, falls back to in-memory storage in `AiQo/App/AppDelegate.swift:45`, and binds `MemoryStore` plus `RecordProjectManager` to that container in `AiQo/App/AppDelegate.swift:56`.

The main app-wide SwiftData container is separate and registers `AiQoDailyRecord`, `WorkoutTask`, and all shipped Tribe models in `AiQo/App/AppDelegate.swift:80`. The composition root also boots crash reporting, phone connectivity, analytics, free trial state, localization, notification categories, and purchase state in `AiQo/App/AppDelegate.swift:99` through `AiQo/App/AppDelegate.swift:120`.

Onboarding and root-screen routing are owned by `AppFlowController` in `AiQo/App/SceneDelegate.swift:17`. The live route enum is `languageSelection`, `login`, `profileSetup`, `legacy`, `featureIntro`, and `main` in `AiQo/App/SceneDelegate.swift:20`. `resolveCurrentScreen()` reads five persisted flags plus Supabase session state in `AiQo/App/SceneDelegate.swift:171`, and `AppRootView` switches between the corresponding screens in `AiQo/App/SceneDelegate.swift:266`.

The visible app shell remains three tabs, not more. `MainTabScreen` mounts Home, Gym, and Captain in `AiQo/App/MainTabScreen.swift:5`, `AiQo/App/MainTabScreen.swift:28`, `AiQo/App/MainTabScreen.swift:42`, and `AiQo/App/MainTabScreen.swift:52`. Quest persistence is injected separately through `.modelContainer(QuestPersistenceController.shared.container)` in `AiQo/App/SceneDelegate.swift:255`.

The watch target has its own independent `@main` entry in `AiQoWatch Watch App/AiQoWatchApp.swift:45`. It conditionally shows the active workout screen or the two-tab watch shell at `AiQoWatch Watch App/AiQoWatchApp.swift:55`, `AiQoWatch Watch App/AiQoWatchApp.swift:70`, and `AiQoWatch Watch App/AiQoWatchApp.swift:72`, and its watch app delegate still accepts `HKWorkoutConfiguration` handoff from the phone at `AiQoWatch Watch App/AiQoWatchApp.swift:128`.

### 3.2 SwiftData Models
| Model name | File | Registered in container? | Fields summary |
|---|---|---|---|
| `CaptainMemory` | `AiQo/Core/CaptainMemory.swift:5` | Yes, Captain container in `AiQo/App/AppDelegate.swift:18` | Category/key/value/confidence/source/timestamps/accessCount memory row for Captain context. |
| `PersistentChatMessage` | `AiQo/Features/Captain/CaptainModels.swift:7` | Yes, Captain container in `AiQo/App/AppDelegate.swift:18` | Session-scoped message cache with `messageID`, `text`, `isUser`, `timestamp`, `spotifyRecommendationData`, and `sessionID`. |
| `RecordProject` | `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:5` | Yes, Captain container in `AiQo/App/AppDelegate.swift:18` | Record project identity, target, plan JSON, weekly logs, status, and HRR fields. |
| `WeeklyLog` | `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:5` | Yes, Captain container in `AiQo/App/AppDelegate.swift:18` | Per-week record review with performance, notes, rating, and project relationship. |
| `AiQoDailyRecord` | `AiQo/NeuralMemory.swift:5` | Yes, app container in `AiQo/App/AppDelegate.swift:80` | Daily dashboard record for steps, calories, water, captain suggestion, and workout relationships. |
| `WorkoutTask` | `AiQo/NeuralMemory.swift:46` | Yes, app container in `AiQo/App/AppDelegate.swift:80` | Lightweight workout task row attached to an `AiQoDailyRecord`. |
| `ArenaTribe` | `AiQo/Tribe/Galaxy/ArenaModels.swift:6` | Yes, app container in `AiQo/App/AppDelegate.swift:83` | Tribe identity, creator, invite code, members, lifecycle state. |
| `ArenaTribeMember` | `AiQo/Tribe/Galaxy/ArenaModels.swift:41` | Yes, app container in `AiQo/App/AppDelegate.swift:84` | Member identity with `userID`, `displayName`, initials, join time, and creator flag. |
| `ArenaWeeklyChallenge` | `AiQo/Tribe/Galaxy/ArenaModels.swift:94` | Yes, app container in `AiQo/App/AppDelegate.swift:85` | Weekly challenge title, metric, active dates, and participations. |
| `ArenaTribeParticipation` | `AiQo/Tribe/Galaxy/ArenaModels.swift:122` | Yes, app container in `AiQo/App/AppDelegate.swift:86` | Challenge participation score, rank, and relationships to tribe/challenge. |
| `ArenaEmirateLeaders` | `AiQo/Tribe/Galaxy/ArenaModels.swift:141` | Yes, app container in `AiQo/App/AppDelegate.swift:87` | Weekly leader snapshot for a tribe/challenge period. |
| `ArenaHallOfFameEntry` | `AiQo/Tribe/Galaxy/ArenaModels.swift:162` | Yes, app container in `AiQo/App/AppDelegate.swift:88` | Historical hall-of-fame summary for tribe wins. |
| `PlayerStats` | `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:10` | Yes, Quest container in `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:29` | Quest profile totals for level, XP, aura, and timestamps. |
| `QuestStage` | `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:41` | Yes, Quest container in `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:29` | Quest stage identity, localization keys, sort order, and record relationship. |
| `QuestRecord` | `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:73` | Yes, Quest container in `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:29` | Quest progress state, metrics, streaks, completion state, and deep-link action. |
| `Reward` | `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:185` | Yes, Quest container in `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:29` | Reward identity, visual metadata, unlock state, progress, and source quest. |
| `SmartFridgeScannedItemRecord` | `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:4` | Yes, local kitchen containers in `AiQo/Features/Kitchen/FridgeInventoryView.swift:24` and `AiQo/Features/Kitchen/InteractiveFridgeView.swift:62` | Captured fridge item name, quantity, unit, note key, and timestamp. |

### 3.3 Captain Hamoudi Intelligence Pipeline
The current Captain stack is routed from `CaptainViewModel`, not from any `AiQo/Core/BrainOrchestrator.swift` file. The live message path starts in `AiQo/Features/Captain/CaptainViewModel.swift:381`, builds context via `AiQo/Features/Captain/CaptainContextBuilder.swift:191`, routes through `AiQo/Features/Captain/BrainOrchestrator.swift:36`, and persists extracted memory via `AiQo/Core/MemoryExtractor.swift:18` and `AiQo/Core/MemoryStore.swift:322`.

```text
User input
  -> CaptainViewModel.processMessage
      -> CaptainContextBuilder.buildContextData
      -> BrainOrchestrator.processMessage
          -> interceptSleepIntent
          -> route(for:)
              -> Local route
                  -> LocalBrainService / AppleIntelligenceSleepAgent / deterministic fallbacks
              -> Cloud route
                  -> MemoryStore.buildCloudSafeContext
                  -> PrivacySanitizer.sanitizeForCloud
                  -> HybridBrainService.generateReply (Gemini)
          -> PrivacySanitizer.injectUserName
      -> CaptainViewModel.validateResponse
      -> MemoryExtractor.extract
      -> MemoryStore.persistMessageAsync
```

```text
HealthKitManager / CaptainIntelligenceManager
  -> CaptainContextBuilder.buildSystemContext
      -> BioTimePhase + LevelStore + Spotify/Vibe state
          -> CaptainPromptBuilder.build
              -> Layer 1 identity
              -> Layer 2 memory
              -> Layer 3 bio-state
              -> Layer 4 circadian tone
              -> Layer 5 screen context
              -> Layer 6 JSON output contract
```

| Component | File | Purpose | Public API | Key dependencies |
|---|---|---|---|---|
| `CaptainViewModel` | `AiQo/Features/Captain/CaptainViewModel.swift:87` | UI-facing coordinator for chat, plans, history, extraction, and analytics | `sendMessage`, session loading, `processMessage` at `AiQo/Features/Captain/CaptainViewModel.swift:381` | `BrainOrchestrator`, `CaptainContextBuilder`, `MemoryStore`, `MemoryExtractor`, `AnalyticsService` |
| `BrainOrchestrator` | `AiQo/Features/Captain/BrainOrchestrator.swift:11` | Decides cloud vs local, handles sleep interception, and owns fallback chain | `processMessage` at `AiQo/Features/Captain/BrainOrchestrator.swift:36`, `route(for:)` at `AiQo/Features/Captain/BrainOrchestrator.swift:84` | `CloudBrainService`, `LocalBrainService`, `AppleIntelligenceSleepAgent`, `PrivacySanitizer` |
| `CloudBrainService` | `AiQo/Features/Captain/CloudBrainService.swift:11` | Fetches tier-budgeted cloud-safe memory and sanitizes outbound requests | `generateReply` via memory fetch at `AiQo/Features/Captain/CloudBrainService.swift:48` and sanitization at `AiQo/Features/Captain/CloudBrainService.swift:54` | `MemoryStore`, `AccessManager`, `PrivacySanitizer`, `HybridBrainService` |
| `HybridBrainService` | `AiQo/Features/Captain/HybridBrainService.swift:150` | Raw Gemini transport and output decoding | endpoint build at `AiQo/Features/Captain/HybridBrainService.swift:107`, request build at `AiQo/Features/Captain/HybridBrainService.swift:233` | `URLSession`, `CaptainPromptBuilder`, `LLMJSONParser` |
| `LocalBrainService` | `AiQo/Features/Captain/LocalBrainService.swift:62` | On-device reply generation and deterministic fallbacks | local engine entry in the live file, cited by orchestration at `AiQo/Features/Captain/BrainOrchestrator.swift:114` | `CaptainOnDeviceChatEngine`, `AppleIntelligenceSleepAgent`, deterministic templates |
| `PrivacySanitizer` | `AiQo/Features/Captain/PrivacySanitizer.swift:14` | Redacts PII, buckets metrics, strips image metadata, and reinjects user name | `sanitizeForCloud` at `AiQo/Features/Captain/PrivacySanitizer.swift:95`, `injectUserName` at `AiQo/Features/Captain/PrivacySanitizer.swift:164` | Regex rules, kitchen image re-encoding, conversation truncation |
| `CaptainPromptBuilder` | `AiQo/Features/Captain/CaptainPromptBuilder.swift:11` | Builds the six-layer system prompt | `build` at `AiQo/Features/Captain/CaptainPromptBuilder.swift:13` | `CaptainContextData`, `ScreenContext`, language rules |
| `CaptainContextBuilder` | `AiQo/Features/Captain/CaptainContextBuilder.swift:134` | Live replacement for the unshipped “Context Assembly” names | `buildSystemContext` at `AiQo/Features/Captain/CaptainContextBuilder.swift:157`, `buildContextData` at `AiQo/Features/Captain/CaptainContextBuilder.swift:191` | `CaptainIntelligenceManager`, `LevelStore`, `SpotifyVibeManager`, `VibeAudioEngine` |
| `CaptainIntelligenceManager` | `AiQo/Features/Captain/CaptainIntelligenceManager.swift:70` | Legacy/parallel intelligence path that still fetches HealthKit locally and routes Arabic differently | Health fetch at `AiQo/Features/Captain/CaptainIntelligenceManager.swift:118`, Arabic API at `AiQo/Features/Captain/CaptainIntelligenceManager.swift:274` | `HealthKit`, `CaptainContextBuilder`, external Arabic API |
| `LLMJSONParser` | `AiQo/Features/Captain/LLMJSONParser.swift:11` | Repairs and decodes structured LLM responses | decode pipeline in the live parser file | `CaptainStructuredResponse` |

The expected named Context Assembly types from the latest product conversation are not present in the codebase. There is no `CaptainContextBundle`, `IntentDetector`, `LexicalMemoryRetriever`, `BiometricsContextProvider`, `TemporalContextProvider`, `CaptainContextAssembler`, or `CaptainPromptComposer`; the live equivalent is `CaptainContextBuilder` at `AiQo/Features/Captain/CaptainContextBuilder.swift:134`.

### 3.4 Brain Routing
The routing contract is simple but real. `BrainOrchestrator.route(for:)` chooses local processing for `.sleepAnalysis` and cloud for the other screen contexts in `AiQo/Features/Captain/BrainOrchestrator.swift:84`. `interceptSleepIntent(_:)` can rewrite a non-sleep screen into `.sleepAnalysis` when sleep language is detected in `AiQo/Features/Captain/BrainOrchestrator.swift:96`, which means sleep analysis can still force the local path even when the user is elsewhere in the app.

The cloud route first requests only cloud-safe memory at `AiQo/Features/Captain/CloudBrainService.swift:48`, then sanitizes the outgoing request at `AiQo/Features/Captain/CloudBrainService.swift:54`. `PrivacySanitizer` still truncates conversation history to four messages in `AiQo/Features/Captain/PrivacySanitizer.swift:21` and `AiQo/Features/Captain/PrivacySanitizer.swift:264`, strips/rewrites sensitive content in `AiQo/Features/Captain/PrivacySanitizer.swift:95`, and reinjects the saved user name after generation in `AiQo/Features/Captain/PrivacySanitizer.swift:164`.

The Gemini transport remains directly encoded in `HybridBrainService`. Request timeout is fixed at 35 seconds in `AiQo/Features/Captain/HybridBrainService.swift:236`, token limits are chosen by screen context in `AiQo/Features/Captain/HybridBrainService.swift:300`, and kitchen images are sent inline when present in `AiQo/Features/Captain/HybridBrainService.swift:344`. The active endpoint base and key-resolution chain are still configured through build variables and environment fallback in `AiQo/Features/Captain/HybridBrainService.swift:86` and `AiQo/Features/Captain/HybridBrainService.swift:93`.

### 3.5 Memory System
`CaptainMemory` remains a true SwiftData entity with confidence and access-tracking fields in `AiQo/Core/CaptainMemory.swift:5` and `AiQo/Core/CaptainMemory.swift:23`. `MemoryStore` is still the central singleton, and it derives its cap from the active entitlement tier at `AiQo/Core/MemoryStore.swift:17` by reading `AccessManager.shared.captainMemoryLimit` from `AiQo/Premium/AccessManager.swift:58`.

Prompt assembly uses two memory views: a broad prompt context in `AiQo/Core/MemoryStore.swift:133` and a filtered cloud-safe context in `AiQo/Core/MemoryStore.swift:178`. Stale cleanup still removes low-confidence memories older than 90 days in `AiQo/Core/MemoryStore.swift:217`, while chat persistence still caps stored messages at 200 in `AiQo/Core/MemoryStore.swift:297`.

`MemoryExtractor` still runs a mixed strategy: regex/rule extraction on every message and LLM extraction every third message via `AiQo/Core/MemoryExtractor.swift:12`, `AiQo/Core/MemoryExtractor.swift:18`, and `AiQo/Core/MemoryExtractor.swift:30`. The cloud extraction leg still uses a 15-second timeout and a small token budget in `AiQo/Core/MemoryExtractor.swift:215` and `AiQo/Core/MemoryExtractor.swift:229`.

One important UI inconsistency remains: the Captain memory settings screen still hardcodes the visible cap as `200`, even though the real backend cap is 500 for Intelligence Pro. The bad display string is in `AiQo/Core/CaptainMemorySettingsView.swift:67`, while the actual tier cap is in `AiQo/Premium/AccessManager.swift:58`.

---

## 4. Feature Inventory

### 4.1 Onboarding Flow
- **Status:** Shipped, but changed from the BP12 description. The live state machine is language -> login -> profile -> legacy calculation/permissions -> feature intro -> main, driven by `AiQo/App/SceneDelegate.swift:20`, `AiQo/App/SceneDelegate.swift:52`, `AiQo/App/SceneDelegate.swift:91`, and `AiQo/App/SceneDelegate.swift:266`.
- **Files:** `AiQo/App/SceneDelegate.swift`, `AiQo/App/LanguageSelectionView.swift`, `AiQo/App/LoginViewController.swift`, `AiQo/App/ProfileSetupView.swift`, `AiQo/App/AuthFlowUI.swift`, `AiQo/App/AppRootManager.swift`, `AiQo/Features/First screen/LegacyCalculationViewController.swift`, `AiQo/Features/Onboarding/FeatureIntroView.swift`, `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift`, `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift`.
- **Entry point:** `AppRootView` decides the first onboarding screen in `AiQo/App/SceneDelegate.swift:171` and renders it in `AiQo/App/SceneDelegate.swift:266`.
- **Dependencies:** `SupabaseService`, `CrashReportingService`, `HealthKitService`, `NotificationService`, `ProtectionModel`, `HistoricalHealthSyncEngine`, and `FreeTrialManager` are all touched during onboarding in `AiQo/App/SceneDelegate.swift:44`, `AiQo/App/SceneDelegate.swift:68`, `AiQo/Features/First screen/LegacyCalculationViewController.swift:389`, and `AiQo/App/SceneDelegate.swift:93`.
- **Known issues:** `OnboardingWalkthroughView` is not referenced by the live router even though it still exists at `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:4`; the onboarding-complete predicate is duplicated in `AiQo/App/AppDelegate.swift:131` and `AiQo/App/AppDelegate.swift:177`; logout preserves language selection in `AiQo/App/SceneDelegate.swift:145`.
- **Feature flag:** None.

### 4.2 Goals & Sleep Setup
- **Status:** Not present in current codebase.
- **Files:** No file or symbol named `GoalsAndSleepSetupView` exists in the current Swift tree; the nearest live onboarding surfaces are the files listed in 4.1.
- **Entry point:** None. The flow moves from profile setup straight to legacy classification in `AiQo/App/SceneDelegate.swift:52`.
- **Dependencies:** None in shipped code, because the feature did not land.
- **Known issues:** The planned dedicated goals/sleep onboarding surface is absent; sleep setup currently enters later through the main app’s Sleep feature instead of onboarding.
- **Feature flag:** None.

### 4.3 Level Classification
- **Status:** Shipped, but implemented inside the legacy onboarding calculator rather than as a standalone end-of-flow screen.
- **Files:** `AiQo/Features/First screen/LegacyCalculationViewController.swift`, `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift`, `AiQo/Core/Models/LevelStore.swift`.
- **Entry point:** `LegacyCalculationScreenView` begins authorization and aggregation at `AiQo/Features/First screen/LegacyCalculationViewController.swift:394`.
- **Dependencies:** `HealthKit`, `HistoricalHealthSyncEngine`, and `LevelStore` interact in `AiQo/Features/First screen/LegacyCalculationViewController.swift:389`, `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:79`, and `AiQo/Core/Models/LevelStore.swift:98`.
- **Known issues:** The desired reorder that moved classification to the end is not present; the controller still writes legacy keys directly in `AiQo/Features/First screen/LegacyCalculationViewController.swift:444`, even though `LevelStore` is the intended long-term source of truth.
- **Feature flag:** None.

### 4.4 Captain Hamoudi Chat
- **Status:** Shipped.
- **Files:** All Swift files under `AiQo/Features/Captain/`; `AiQo/Core/CaptainMemory.swift`; `AiQo/Core/MemoryStore.swift`; `AiQo/Core/MemoryExtractor.swift`; `AiQo/Core/UserProfileStore.swift`; `AiQo/Core/CaptainVoiceAPI.swift`; `AiQo/Core/CaptainVoiceService.swift`; `AiQo/Core/CaptainVoiceCache.swift`; `AiQo/Core/HealthKitMemoryBridge.swift`; `AiQo/Core/CaptainMemorySettingsView.swift`; `AiQo/Core/SpotifyVibeManager.swift`; `AiQo/Core/VibeAudioEngine.swift`.
- **Entry point:** The main captain tab still mounts `CaptainScreen` from `AiQo/App/MainTabScreen.swift:52`.
- **Dependencies:** `BrainOrchestrator`, Gemini, Apple Intelligence, HealthKit, MemoryStore, LevelStore, Spotify/Vibe, and analytics all converge in `AiQo/Features/Captain/CaptainViewModel.swift:381`, `AiQo/Features/Captain/HybridBrainService.swift:233`, and `AiQo/Features/Captain/CaptainContextBuilder.swift:157`.
- **Known issues:** The live code path does not match the old `AiQo/Core/*Brain*` file layout; the latest named Context Assembly types did not land; `CaptainScreen` is still very large at 1,148 LOC and begins at `AiQo/Features/Captain/CaptainScreen.swift:196`.
- **Feature flag:** None.

### 4.5 Captain Memory & Settings View ("ذاكرة الكابتن")
- **Status:** Shipped.
- **Files:** `AiQo/Core/CaptainMemory.swift`, `AiQo/Core/MemoryStore.swift`, `AiQo/Core/MemoryExtractor.swift`, `AiQo/Core/CaptainMemorySettingsView.swift`, `AiQo/Core/AppSettingsScreen.swift`, `AiQo/Premium/AccessManager.swift`.
- **Entry point:** The settings screen opens the memory settings sheet from `AiQo/Core/AppSettingsScreen.swift:133`.
- **Dependencies:** `SwiftData`, Captain chat persistence, premium entitlements, and HealthKit memory bridge in `AiQo/App/AppDelegate.swift:56`, `AiQo/Core/MemoryStore.swift:133`, and `AiQo/Core/HealthKitMemoryBridge.swift:14`.
- **Known issues:** `CaptainMemorySettingsView` still renders `\(memories.count) / 200` even for Intelligence Pro in `AiQo/Core/CaptainMemorySettingsView.swift:67`; this is a display bug against the real 500-cap tier logic in `AiQo/Premium/AccessManager.swift:58`.
- **Feature flag:** Tier-gated by active subscription in `AiQo/Premium/AccessManager.swift:58`.

### 4.6 Sleep Architecture + Smart Wake Calculator
- **Status:** Shipped.
- **Files:** All Swift files under `AiQo/Features/Sleep/`; `AiQo/Services/Notifications/AlarmSchedulingService.swift`; `AiQo/Services/Notifications/MorningHabitOrchestrator.swift`; `AiQo/Core/SmartNotificationScheduler.swift`.
- **Entry point:** The Sleep feature is reachable from the app surface; smart wake persistence happens through `AiQo/Features/Sleep/SmartWakeViewModel.swift:103`.
- **Dependencies:** `SmartWakeEngine`, `AlarmSchedulingService`, `MorningHabitOrchestrator`, `AppleIntelligenceSleepAgent`, and `SleepSessionObserver` are connected in `AiQo/Features/Sleep/SmartWakeViewModel.swift:130`, `AiQo/Services/Notifications/AlarmSchedulingService.swift:166`, and `AiQo/Services/Notifications/AlarmSchedulingService.swift:189`.
- **Known issues:** The feature is genuinely shipped, but the current wake scheduling path is split between Sleep view models and notifications rather than centralized under `NotificationService`; hardcoded output heuristics remain in `AiQo/Features/Sleep/SmartWakeEngine.swift:232`.
- **Feature flag:** None.

### 4.7 Alchemy Kitchen
- **Status:** Shipped.
- **Files:** All files under `AiQo/Features/Kitchen/`.
- **Entry point:** Kitchen is reachable from the home-routing path; `KitchenView` itself begins at `AiQo/Features/Kitchen/KitchenView.swift:4`.
- **Dependencies:** Captain chat, camera capture, local repositories, scanner persistence, and optional model containers connect through `AiQo/Features/Kitchen/KitchenView.swift:5`, `AiQo/Features/Kitchen/KitchenView.swift:34`, `AiQo/Features/Kitchen/SmartFridgeScannerView.swift:6`, and `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:3`.
- **Known issues:** The kitchen open action still depends on a `NotificationCenter` bridge from `MainTabRouter` to `HomeView` in `AiQo/App/MainTabRouter.swift:33` and `AiQo/Features/Home/HomeView.swift:91`; meal generation routes through `CaptainIntelligenceManager` rather than the newer `BrainOrchestrator`, which keeps two AI surfaces alive in parallel at `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:27`.
- **Feature flag:** Tier-gated by `AccessManager.canAccessKitchen` in `AiQo/Premium/AccessManager.swift:38`.

### 4.8 Zone 2 Coaching
- **Status:** Shipped.
- **Files:** `AiQo/Features/Gym/HandsFreeZone2Manager.swift`, plus workout and voice dependencies under `AiQo/Core/CaptainVoiceService.swift` and `AiQo/Features/Captain/CaptainIntelligenceManager.swift`.
- **Entry point:** The Zone 2 UI begins at `AiQo/Features/Gym/HandsFreeZone2Manager.swift:8`.
- **Dependencies:** Speech recognition, `CaptainIntelligenceManager`, and `CaptainVoiceService` are wired together in `AiQo/Features/Gym/HandsFreeZone2Manager.swift:215`, `AiQo/Features/Gym/HandsFreeZone2Manager.swift:216`, and `AiQo/Features/Gym/HandsFreeZone2Manager.swift:224`.
- **Known issues:** The feature still depends on `SFSpeechRecognizer`, which carries runtime permission and locale variability risk; it also uses the older intelligence manager rather than the newer chat orchestration path.
- **Feature flag:** Tier-gated by `AccessManager.canAccessGym` in `AiQo/Premium/AccessManager.swift:37`.

### 4.9 XP & Leveling System
- **Status:** Shipped.
- **Files:** `AiQo/Core/Models/LevelStore.swift`, `AiQo/XPCalculator.swift`, `AiQo/Shared/LevelSystem.swift`, `AiQo/Shared/CoinManager.swift`, watch connectivity award logic in `AiQo/PhoneConnectivityManager.swift`.
- **Entry point:** XP is awarded across workouts, onboarding sync, and watch completion via `AiQo/Core/Models/LevelStore.swift:98`, `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:128`, and `AiQo/PhoneConnectivityManager.swift:756`.
- **Dependencies:** `LevelStore`, `SupabaseArenaService`, watch connectivity, and legacy onboarding sync all interact in `AiQo/Core/Models/LevelStore.swift:105`, `AiQo/Services/SupabaseArenaService.swift:554`, and `AiQo/Features/First screen/LegacyCalculationViewController.swift:449`.
- **Known issues:** `PhoneConnectivityManager` still duplicates its own XP formula at `AiQo/PhoneConnectivityManager.swift:756` instead of delegating to `AiQo/XPCalculator.swift:23`; the onboarding calculator also writes legacy keys directly in `AiQo/Features/First screen/LegacyCalculationViewController.swift:444`.
- **Feature flag:** None.

### 4.10 Tribe / إمارة Social
- **Status:** Hidden behind flags, partially live, and still carrying stale/mock seams.
- **Files:** All Swift files under `AiQo/Features/Tribe/`; all Swift files under `AiQo/Tribe/`; `AiQo/Services/SupabaseArenaService.swift`.
- **Entry point:** Hidden from normal navigation by feature flags in `AiQo/Info.plist:74`, `AiQo/Info.plist:76`, and `AiQo/Info.plist:78`; when surfaced, `TribeView` begins at `AiQo/Features/Tribe/TribeView.swift:1`.
- **Dependencies:** `SupabaseArenaService`, `TribeFeatureFlags`, `LevelStore`, and app-wide premium state connect throughout `AiQo/Tribe/Models/TribeFeatureModels.swift:27`, `AiQo/Services/SupabaseArenaService.swift:554`, and `AiQo/Premium/AccessManager.swift:194`.
- **Known issues:** Five TODOs remain in `AiQo/Features/Tribe/TribeExperienceFlow.swift:190`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:205`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:299`, `AiQo/Features/Tribe/TribeExperienceFlow.swift:348`, and `AiQo/Features/Tribe/TribeExperienceFlow.swift:369`; usernames still risk double `@` in `AiQo/Tribe/Views/TribeLeaderboardView.swift:96`; non-current members still show `0 / Level 1` in `AiQo/Tribe/Galaxy/TribeMembersList.swift:28`.
- **Feature flag:** `TRIBE_BACKEND_ENABLED`, `TRIBE_FEATURE_VISIBLE`, and `TRIBE_SUBSCRIPTION_GATE_ENABLED`, all currently false in `AiQo/Info.plist:74`, `AiQo/Info.plist:76`, and `AiQo/Info.plist:78`.

### 4.11 Legendary Challenges
- **Status:** Shipped.
- **Files:** All files under `AiQo/Features/LegendaryChallenges/`.
- **Entry point:** The section root is `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift:5`.
- **Dependencies:** `RecordProject`, `WeeklyLog`, premium access, and HRR assessment connect through `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift:23`, `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:5`, and `AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift:1`.
- **Known issues:** The feature surface is shipped, but its persistence shares the same dedicated Captain container as chat memory in `AiQo/App/AppDelegate.swift:18`, which couples unrelated domains.
- **Feature flag:** `AccessManager.canAccessPeaks` gates the peaks surface at `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift:23`.

### 4.12 Heart Rate Recovery (HRR / قياس المحرك)
- **Status:** Shipped.
- **Files:** `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift`, `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift`, shared watch/phone connectivity files.
- **Entry point:** `FitnessAssessmentView` begins at `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:6`.
- **Dependencies:** `HRRWorkoutManager`, HealthKit, and watch connectivity are wired through `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift:78` and the watch step-test coordination inside the same manager.
- **Known issues:** The feature is watch-dependent by design, so any watch reachability or session bug cascades into HRR; it also shares the broader watch telemetry limitations noted in Section 9.
- **Feature flag:** Tier-gated by `AccessManager.canAccessHRRAssessment` in `AiQo/Premium/AccessManager.swift:46`.

### 4.13 My Vibe (Spotify biometric playlist)
- **Status:** Shipped.
- **Files:** All files under `AiQo/Features/MyVibe/`; `AiQo/Core/VibeAudioEngine.swift`; `AiQo/Core/SpotifyVibeManager.swift`.
- **Entry point:** `MyVibeScreen` begins at `AiQo/Features/MyVibe/MyVibeScreen.swift:3`.
- **Dependencies:** `CaptainViewModel`, `VibeOrchestrator`, `VibeAudioEngine`, and Spotify AppRemote join in `AiQo/Features/MyVibe/MyVibeScreen.swift:5`, `AiQo/Features/MyVibe/VibeOrchestrator.swift:25`, and `AiQo/Core/SpotifyVibeManager.swift:49`.
- **Known issues:** `SpotifyVibeManager` still silently disables Spotify if `SPOTIFY_CLIENT_ID` is missing in `AiQo/Core/SpotifyVibeManager.swift:49`; the orchestrator and audio engine both run 30-second schedulers in `AiQo/Features/MyVibe/VibeOrchestrator.swift:125` and `AiQo/Core/VibeAudioEngine.swift:518`.
- **Feature flag:** Tier-gated by `AccessManager.canAccessMyVibe` in `AiQo/Premium/AccessManager.swift:39`.

### 4.14 Notifications (all schedulers)
- **Status:** Shipped, but partially hardcoded and distributed across several services.
- **Files:** `AiQo/Core/SmartNotificationScheduler.swift`; all files under `AiQo/Services/Notifications/`.
- **Entry point:** Permission request and scheduling bootstrap happen from `AiQo/App/AppDelegate.swift:140` and `AiQo/App/SceneDelegate.swift:232`.
- **Dependencies:** `NotificationService`, `SmartNotificationScheduler`, `MorningHabitOrchestrator`, `InactivityTracker`, `PremiumExpiryNotifier`, and `NotificationCategoryManager` connect in `AiQo/Services/Notifications/NotificationService.swift:13`, `AiQo/Core/SmartNotificationScheduler.swift:236`, `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:155`, and `AiQo/Services/Notifications/PremiumExpiryNotifier.swift:96`.
- **Known issues:** Inactivity prompt generation still contains hardcoded prompt and fallback text at `AiQo/Services/Notifications/NotificationService.swift:468`; repository-backed notification content is still effectively placeholder data in `AiQo/Services/Notifications/NotificationRepository.swift:7`; cooldowns and thresholds remain inline constants in `AiQo/Services/Notifications/NotificationService.swift:164` and `AiQo/Services/Notifications/NotificationService.swift:435`.
- **Feature flag:** Premium access and quiet-hours policy apply indirectly through `AccessManager.canReceiveCaptainNotifications` at `AiQo/Premium/AccessManager.swift:42` and `AiQo/Core/SmartNotificationScheduler.swift:189`.

### 4.15 StoreKit 2 Subscriptions & Paywall
- **Status:** Shipped, but live code now reflects a two-tier business model instead of the previously documented three-tier plan.
- **Files:** `AiQo/UI/Purchases/PaywallView.swift`, `AiQo/Premium/PremiumStore.swift`, all files under `AiQo/Core/Purchases/`, `AiQo/Resources/AiQo.storekit`, `AiQo/Resources/AiQo_Test.storekit`, `AiQo/Premium/AccessManager.swift`, `AiQo/Premium/FreeTrialManager.swift`.
- **Entry point:** The paywall surface is `AiQo/UI/Purchases/PaywallView.swift:1`, and StoreKit loading begins in `AiQo/Core/Purchases/PurchaseManager.swift:75`.
- **Dependencies:** `SubscriptionTier`, `SubscriptionProductIDs`, `EntitlementStore`, `ReceiptValidator`, and `AccessManager` all participate in `AiQo/Core/Purchases/SubscriptionTier.swift:4`, `AiQo/Core/Purchases/SubscriptionProductIDs.swift:20`, `AiQo/Core/Purchases/ReceiptValidator.swift:36`, and `AiQo/Premium/AccessManager.swift:27`.
- **Known issues:** The app no longer matches the previously discussed three-tier plan; `proMonthly` survives only as backward compatibility in `AiQo/Core/Purchases/SubscriptionProductIDs.swift:10`; the Captain memory settings UI still hardcodes a 200-cap even for 500-cap users in `AiQo/Core/CaptainMemorySettingsView.swift:67`.
- **Feature flag:** Debug-only `useLocalStoreKitConfig` is enabled in DEBUG builds at `AiQo/Core/Purchases/PurchaseManager.swift:12`.

### 4.16 AiQoWatch Companion App
- **Status:** Shipped.
- **Files:** All Swift files under `AiQoWatch Watch App/`; shared connectivity files in the main app such as `AiQo/PhoneConnectivityManager.swift` and `AiQo/Features/Gym/WatchConnectivityService.swift`.
- **Entry point:** `AiQoWatch Watch App/AiQoWatchApp.swift:45`.
- **Dependencies:** `WorkoutManager`, `WatchHealthKitManager`, `WatchConnectivityManager`, `WatchConnectivityService`, and phone-side `PhoneConnectivityManager` connect through `AiQoWatch Watch App/AiQoWatchApp.swift:50`, `AiQoWatch Watch App/Services/WatchConnectivityService.swift:9`, and `AiQo/PhoneConnectivityManager.swift:13`.
- **Known issues:** `WatchConnectivityService` still polls every 2 seconds in `AiQoWatch Watch App/Services/WatchConnectivityService.swift:18`; iPhone XP rewards still use a duplicated formula in `AiQo/PhoneConnectivityManager.swift:756`; the watch codebase remains large, with `AiQoWatch Watch App/WorkoutManager.swift` still above 1,000 LOC.
- **Feature flag:** None.

### 4.17 HealthKit Integration
- **Status:** Shipped.
- **Files:** All files under `AiQo/Services/Permissions/HealthKit/`; `AiQo/Shared/HealthKitManager.swift`; `AiQo/Core/HealthKitMemoryBridge.swift`; relevant watch HealthKit files.
- **Entry point:** Authorization is requested during onboarding in `AiQo/App/SceneDelegate.swift:68`, in the legacy flow in `AiQo/Features/First screen/LegacyCalculationViewController.swift:516`, and on watch launch in `AiQoWatch Watch App/AiQoWatchApp.swift:95`.
- **Dependencies:** `HealthKitService`, `HealthKitManager`, `HealthKitMemoryBridge`, `CaptainContextBuilder`, and watch launch helpers are connected in `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:40`, `AiQo/Shared/HealthKitManager.swift:65`, `AiQo/Core/HealthKitMemoryBridge.swift:14`, and `AiQo/Shared/HealthKitManager.swift:129`.
- **Known issues:** Authorization gating still depends on a mutable static `permissionFlowEnabled` flag in `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:29`; read/write scope is broad for an onboarding-time permission ask.
- **Feature flag:** `HealthKitService.permissionFlowEnabled`, default false in `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:29`.

### 4.18 Supabase Backend Integration
- **Status:** Shipped, but unevenly scoped between lightweight profile APIs and large Tribe/Arena services.
- **Files:** `AiQo/Services/SupabaseService.swift`, `AiQo/Services/SupabaseArenaService.swift`, `AiQo/Core/Purchases/ReceiptValidator.swift`, app auth files under `AiQo/App/`.
- **Entry point:** `SupabaseService` is used for auth and profile loading in `AiQo/App/LoginViewController.swift:141`, while Tribe and leaderboard paths live in `AiQo/Services/SupabaseArenaService.swift:554` and `AiQo/Services/SupabaseArenaService.swift:575`.
- **Dependencies:** Build-configured `K.Supabase` values, Supabase Auth, PostgREST, Functions, and Tribe models appear in `AiQo/Services/SupabaseService.swift:23`, `AiQo/Services/SupabaseService.swift:59`, and `AiQo/Core/Purchases/ReceiptValidator.swift:36`.
- **Known issues:** There is still no durable offline queue for writes; `SupabaseService` can fall back to `placeholder.invalid` if build variables are missing in `AiQo/Services/SupabaseService.swift:23`; the hidden Tribe surface still ships substantial live network code.
- **Feature flag:** Tribe backend behavior is additionally gated by `TRIBE_BACKEND_ENABLED` in `AiQo/Info.plist:74`.

### 4.19 Gemini API Integration
- **Status:** Shipped.
- **Files:** `AiQo/Features/Captain/HybridBrainService.swift`, `AiQo/Features/Captain/CloudBrainService.swift`, `AiQo/Features/Captain/CoachBrainMiddleware.swift`, `AiQo/Core/MemoryExtractor.swift`, `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift`.
- **Entry point:** Captain chat and some kitchen/memory extraction paths reach Gemini through `AiQo/Features/Captain/HybridBrainService.swift:233` and `AiQo/Core/MemoryExtractor.swift:215`.
- **Dependencies:** `PrivacySanitizer`, `CaptainPromptBuilder`, `LLMJSONParser`, and various feature-specific callers are connected in `AiQo/Features/Captain/CloudBrainService.swift:54`, `AiQo/Features/Captain/CaptainPromptBuilder.swift:13`, and `AiQo/Features/Captain/HybridBrainService.swift:300`.
- **Known issues:** Token budgets and temperatures remain inline rather than centrally budgeted in `AiQo/Features/Captain/HybridBrainService.swift:300`; kitchen generation still uses `CaptainIntelligenceManager` in parallel to the newer orchestration path.
- **Feature flag:** Indirectly gated by tier through `AccessManager.canAccessIntelligenceModel` in `AiQo/Premium/AccessManager.swift:54`.

### 4.20 ElevenLabs TTS Integration
- **Status:** Shipped.
- **Files:** `AiQo/Core/CaptainVoiceAPI.swift`, `AiQo/Core/CaptainVoiceService.swift`, `AiQo/Core/CaptainVoiceCache.swift`.
- **Entry point:** Captain voice playback begins in `AiQo/Core/CaptainVoiceService.swift:37`.
- **Dependencies:** ElevenLabs HTTP transport, local cache, and AVSpeech fallback connect through `AiQo/Core/CaptainVoiceAPI.swift:8`, `AiQo/Core/CaptainVoiceService.swift:154`, and `AiQo/Core/CaptainVoiceCache.swift:39`.
- **Known issues:** The app has no visible cost governor beyond caching and short request timeouts in `AiQo/Core/CaptainVoiceAPI.swift:27`; remote TTS still sends text off-device whenever the service is configured.
- **Feature flag:** None.

### 4.21 Apple Sign In
- **Status:** Shipped.
- **Files:** `AiQo/App/LoginViewController.swift`, `AiQo/Services/SupabaseService.swift`, onboarding router files.
- **Entry point:** `LoginScreenView` begins at `AiQo/App/LoginViewController.swift:8`, and the Apple button is mounted at `AiQo/App/LoginViewController.swift:49`.
- **Dependencies:** `SignInWithAppleButton`, Supabase auth, and `AppFlowController` are connected in `AiQo/App/LoginViewController.swift:49`, `AiQo/App/LoginViewController.swift:141`, and `AiQo/App/SceneDelegate.swift:44`.
- **Known issues:** The auth layer is present, but deep-link/return handling is still concentrated in app root and SceneDelegate, so auth regression testing remains important.
- **Feature flag:** None.

### 4.22 Firebase Crashlytics
- **Status:** Partially shipped. The wrapper exists, but project linkage is currently unclear from the live project file.
- **Files:** `AiQo/Services/CrashReporting/CrashReportingService.swift`, `AiQo/Services/CrashReporting/CrashReporter.swift`, `AiQo.xcodeproj/project.pbxproj`.
- **Entry point:** Crash reporting is configured during launch at `AiQo/App/AppDelegate.swift:100`.
- **Dependencies:** `CrashReportingService`, Firebase imports guarded by `canImport`, and the local fallback crash logger are wired in `AiQo/Services/CrashReporting/CrashReportingService.swift:5`, `AiQo/Services/CrashReporting/CrashReportingService.swift:21`, and `AiQo/Services/CrashReporting/CrashReporter.swift:19`.
- **Known issues:** The wrapper is real, but the Xcode project still contains no `Firebase` or `Crashlytics` references; if the package is not linked elsewhere, production crash upload may still be absent even though the wrapper compiles.
- **Feature flag:** Compile-time only via `canImport(FirebaseCore)` and `canImport(FirebaseCrashlytics)` in `AiQo/Services/CrashReporting/CrashReportingService.swift:21`.

---

## 5. Onboarding Flow — Current Sequence
1. `LanguageSelectionView` is the first screen when `didSelectLanguage` is false in `AiQo/App/SceneDelegate.swift:176`, rendered at `AiQo/App/SceneDelegate.swift:268`.
2. `LoginScreenView` follows after language selection via `AiQo/App/SceneDelegate.swift:39` and `AiQo/App/SceneDelegate.swift:273`.
3. `ProfileSetupView` is next when the dating/profile flag is incomplete in `AiQo/App/SceneDelegate.swift:196` and `AiQo/App/SceneDelegate.swift:276`.
4. `LegacyCalculationScreenView` runs immediately after profile completion because `didCompleteProfileSetup()` transitions to `.legacy` in `AiQo/App/SceneDelegate.swift:52` and the root view renders it at `AiQo/App/SceneDelegate.swift:279`.
5. `FeatureIntroView` is shown after `finalizeOnboarding()` flips the legacy flag and transitions to `.featureIntro` in `AiQo/App/SceneDelegate.swift:91` and `AiQo/App/SceneDelegate.swift:282`.
6. `MainTabScreen` becomes the steady-state destination after `didCompleteFeatureIntro()` in `AiQo/App/SceneDelegate.swift:97` and `AiQo/App/SceneDelegate.swift:287`.

The requested reorder that moved level classification to the end has not been applied. Classification still happens inside the legacy screen and its health sync path through `AiQo/Features/First screen/LegacyCalculationViewController.swift:422` and `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:79`.

```text
Cold launch
  -> resolveCurrentScreen()
      -> LanguageSelectionView
      -> LoginScreenView
      -> ProfileSetupView
      -> LegacyCalculationScreenView
          -> request permissions
          -> HistoricalHealthSyncEngine.sync()
          -> write level + XP
      -> FeatureIntroView
      -> MainTabScreen
```

---

## 6. Backend & External Integrations
### 6.1 Supabase
`SupabaseService` still handles the narrow “profiles plus auth” surface. It resolves URL and anon key through build-configured constants, with a `placeholder.invalid` safety fallback in `AiQo/Services/SupabaseService.swift:23`. The service currently touches `profiles` for search, load, and device token updates in `AiQo/Services/SupabaseService.swift:59`, `AiQo/Services/SupabaseService.swift:92`, `AiQo/Services/SupabaseService.swift:101`, and `AiQo/Services/SupabaseService.swift:141`.

The broader backend footprint lives in `SupabaseArenaService`, which hits `arena_tribe_participations`, `arena_tribes`, `arena_tribe_members`, `arena_weekly_challenges`, `profiles`, and `arena_hall_of_fame_entries` through methods rooted at `AiQo/Services/SupabaseArenaService.swift:554`, `AiQo/Services/SupabaseArenaService.swift:575`, `AiQo/Services/SupabaseArenaService.swift:747`, `AiQo/Services/SupabaseArenaService.swift:930`, and `AiQo/Services/SupabaseArenaService.swift:954`. Apple Sign In flows into Supabase auth from `AiQo/App/LoginViewController.swift:141`.

### 6.2 Gemini Cloud Brain
The Captain cloud brain still talks directly to the Gemini Generative Language API. `HybridBrainService` defines the base endpoint in `AiQo/Features/Captain/HybridBrainService.swift:86`, derives the concrete URL in `AiQo/Features/Captain/HybridBrainService.swift:107`, builds the request in `AiQo/Features/Captain/HybridBrainService.swift:233`, and enforces a 35-second timeout in `AiQo/Features/Captain/HybridBrainService.swift:236`. Output token limits remain screen-specific in `AiQo/Features/Captain/HybridBrainService.swift:300`, and the request body still fixes `temperature` at `0.7` in `AiQo/Features/Captain/HybridBrainService.swift:318`.

Cloud routing is privacy-limited by `CloudBrainService` before transport. That wrapper fetches cloud-safe memory only in `AiQo/Features/Captain/CloudBrainService.swift:48`, sanitizes the request in `AiQo/Features/Captain/CloudBrainService.swift:54`, and varies memory budget by tier in `AiQo/Features/Captain/CloudBrainService.swift:47`. Error handling still lives inline in `HybridBrainService` status processing at `AiQo/Features/Captain/HybridBrainService.swift:264` and in the broader Captain fallback policy managed by `AiQo/Features/Captain/BrainOrchestrator.swift:164`.

### 6.3 ElevenLabs
ElevenLabs is still the remote TTS provider, with the default endpoint defined at `AiQo/Core/CaptainVoiceAPI.swift:8` and the default model `eleven_multilingual_v2` at `AiQo/Core/CaptainVoiceAPI.swift:9`. The HTTP session now uses short 8-second request and 10-second resource timeouts in `AiQo/Core/CaptainVoiceAPI.swift:27` and `AiQo/Core/CaptainVoiceAPI.swift:28`, and individual requests still set an 8-second timeout in `AiQo/Core/CaptainVoiceAPI.swift:118`.

Cost exposure is somewhat controlled by the voice cache and fallback strategy, but not by quota logic. `CaptainVoiceService` checks cache first and falls back to AVSpeech if remote generation fails in `AiQo/Core/CaptainVoiceService.swift:37`, `AiQo/Core/CaptainVoiceService.swift:212`, and `AiQo/Core/CaptainVoiceService.swift:246`; `CaptainVoiceCache` remains the main cost saver.

### 6.4 Firebase Crashlytics
Crashlytics is wrapped, not deeply integrated. `CrashReportingService` conditionally imports Firebase at `AiQo/Services/CrashReporting/CrashReportingService.swift:5`, configures only when both `FirebaseCore` and `FirebaseCrashlytics` are importable at `AiQo/Services/CrashReporting/CrashReportingService.swift:21`, and supports user binding plus non-fatal record/log/custom value helpers at `AiQo/Services/CrashReporting/CrashReportingService.swift:36`, `AiQo/Services/CrashReporting/CrashReportingService.swift:52`, `AiQo/Services/CrashReporting/CrashReportingService.swift:65`, and `AiQo/Services/CrashReporting/CrashReportingService.swift:87`.

What is missing is strong repository evidence that Firebase is actually linked. The current `AiQo.xcodeproj/project.pbxproj` contains no `Firebase` or `Crashlytics` string references, while the local fallback logger still writes `crash_log.jsonl` through `AiQo/Services/CrashReporting/CrashReporter.swift:19`.

---

## 7. Data Privacy & Apple Compliance
Captain cloud requests are still privacy-sanitized before they leave the device. `PrivacySanitizer` truncates conversation history to four messages in `AiQo/Features/Captain/PrivacySanitizer.swift:21` and `AiQo/Features/Captain/PrivacySanitizer.swift:264`, performs outbound redaction in `AiQo/Features/Captain/PrivacySanitizer.swift:95`, and reinjects the local user name after generation in `AiQo/Features/Captain/PrivacySanitizer.swift:164`. Kitchen images are re-encoded and stripped before cloud use in the same sanitizer path.

Health data mostly stays local. `CaptainIntelligenceManager` explicitly documents that it reads HealthKit on-device and uses the external API only for Arabic responses in `AiQo/Features/Captain/CaptainIntelligenceManager.swift:70` through `AiQo/Features/Captain/CaptainIntelligenceManager.swift:72`. `HealthKitService` requests a broad set of read/write types in `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:46` and `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:79`, but `HealthKitMemoryBridge` only syncs a summarized subset into Captain memory in `AiQo/Core/HealthKitMemoryBridge.swift:14`.

The privacy manifest still claims no tracking. `AiQo/PrivacyInfo.xcprivacy:5` sets `NSPrivacyTracking` false, and `AiQo/PrivacyInfo.xcprivacy:20` declares health and fitness collection for app functionality. That aligns with the current architecture: the app stores health summaries locally, optionally sends sanitized prompt text and sanitized images to Gemini, optionally sends TTS text to ElevenLabs, and sends profile/Tribe data to Supabase.

Apple review risk is lower than BP12 on permission copy because base English usage descriptions now exist in `AiQo/Info.plist:46`, `AiQo/Info.plist:48`, and `AiQo/Info.plist:50`. The larger remaining compliance risks are hidden-but-shipped Tribe networking in `AiQo/Services/SupabaseArenaService.swift:10`, the broad HealthKit authorization surface in `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:46`, and any production gap between the Crashlytics wrapper and actual Firebase linkage.

---

## 8. Monetization State
AiQo is now a live two-tier subscription product, not a three-tier one. `PremiumPlan` only exposes `.core` and `.intelligencePro` in `AiQo/Premium/PremiumStore.swift:5`, the runtime tier enum only exposes `.none`, `.core`, and `.intelligencePro` in `AiQo/Core/Purchases/SubscriptionTier.swift:4`, and the current SKU set only includes `com.mraad500.aiqo.standard.monthly` and `com.mraad500.aiqo.intelligencepro.monthly` in `AiQo/Core/Purchases/SubscriptionProductIDs.swift:20`.

The paywall is aligned with that runtime change. `PaywallView` only supports `[.core, .intelligencePro]` in `AiQo/UI/Purchases/PaywallView.swift:20`, markets “Two clear options only” in `AiQo/UI/Purchases/PaywallView.swift:259`, and repeats the “Just two cards” framing in `AiQo/UI/Purchases/PaywallView.swift:373`. The `.storekit` and test `.storekit` files also now contain only the two live product IDs at `AiQo/Resources/AiQo.storekit:43`, `AiQo/Resources/AiQo.storekit:74`, `AiQo/Resources/AiQo_Test.storekit:43`, and `AiQo/Resources/AiQo_Test.storekit:74`.

The main gaps are operational, not structural. Receipt validation still depends on the Supabase edge function endpoint defined in `AiQo/Core/Purchases/ReceiptValidator.swift:36`. Developer flows still depend on the local test configuration in DEBUG through `AiQo/Core/Purchases/PurchaseManager.swift:12` and `AiQo/Core/Purchases/PurchaseManager.swift:39`. The most visible premium inconsistency is the Captain memory settings UI, which still shows a fixed `200` cap even though Intelligence Pro can store 500 memories in `AiQo/Core/CaptainMemorySettingsView.swift:67` and `AiQo/Premium/AccessManager.swift:58`.

---

## 9. Notifications Audit
The notification system is spread across four layers. `NotificationService` owns most immediate categories and permission flow in `AiQo/Services/Notifications/NotificationService.swift:13`. `SmartNotificationScheduler` owns recurring automation, background processing IDs, and quiet-hours adjustment in `AiQo/Core/SmartNotificationScheduler.swift:11`, `AiQo/Core/SmartNotificationScheduler.swift:189`, and `AiQo/Core/SmartNotificationScheduler.swift:236`. `MorningHabitOrchestrator` adds wake-window step monitoring in `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:35` and `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:155`. `PremiumExpiryNotifier` uses the same scheduler-adjusted fire dates at `AiQo/Services/Notifications/PremiumExpiryNotifier.swift:96`.

The app currently schedules or composes at least these notification classes: Captain/inactivity in `AiQo/Services/Notifications/NotificationService.swift:175`, water reminders in `AiQo/Services/Notifications/NotificationService.swift:257`, meal reminders in `AiQo/Services/Notifications/NotificationService.swift:300`, step/milestone reminders in the same service, sleep reminders via `AiQo/Core/SmartNotificationScheduler.swift:310`, morning habit/wake follow-ups in `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:302`, background-composed sleep and inactivity messages in `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:23`, and premium expiry notices in `AiQo/Services/Notifications/PremiumExpiryNotifier.swift:96`.

Quiet hours are centrally enforced in `SmartNotificationScheduler`, which adjusts automation dates through `AiQo/Core/SmartNotificationScheduler.swift:189` and keeps the overnight quiet window in the same file. Notification language handling has improved materially: `NotificationLocalization` resolves the active language in `AiQo/Services/Notifications/NotificationLocalization.swift:3`, and `NotificationService` now uses localization keys for water, meal, and other common bodies in `AiQo/Services/Notifications/NotificationService.swift:257`, `AiQo/Services/Notifications/NotificationService.swift:300`, and `AiQo/Services/Notifications/NotificationService.swift:307`.

The remaining issues are specific, not systemic. Inactivity prompt generation still contains hardcoded prompt and fallback content in `AiQo/Services/Notifications/NotificationService.swift:468` through `AiQo/Services/Notifications/NotificationService.swift:504`. `NotificationRepository` still exposes placeholder-like content starting at `AiQo/Services/Notifications/NotificationRepository.swift:7`. `NotificationCategoryManager` only registers the Captain smart category in `AiQo/Services/Notifications/NotificationCategoryManager.swift:17`, so category growth remains centralized but minimal.

---

## 10. Known Issues & Technical Debt
### 10.1 Blockers for TestFlight
- **Hidden Tribe backend still ships in the binary** — `AiQo/Info.plist:74`, `AiQo/Info.plist:76`, `AiQo/Info.plist:78`, `AiQo/Services/SupabaseArenaService.swift:10`. Impact: public testers can be affected by dormant network code and stale data paths even while UI is hidden. Suggested fix: remove Tribe files from the target or wrap them in compile-time flags before public rollout.
- **Production analytics are still local-only** — `AiQo/Services/Analytics/AnalyticsService.swift:27`, `AiQo/Services/Analytics/AnalyticsService.swift:29`, `AiQo/Services/Analytics/AnalyticsService.swift:138`. Impact: no server-side usage visibility for activation, retention, paywall, or crash correlation. Suggested fix: add one real remote analytics sink and keep local JSONL only as debug support.
- **Crashlytics linkage is still uncertain** — `AiQo/Services/CrashReporting/CrashReportingService.swift:21`, `AiQo/Services/CrashReporting/CrashReporter.swift:19`, `AiQo.xcodeproj/project.pbxproj`. Impact: production crash telemetry may still be absent despite the wrapper. Suggested fix: confirm Firebase package linkage in the project and verify a test non-fatal arrives.
- **Onboarding product intent diverges from the latest plan** — `AiQo/App/SceneDelegate.swift:52`, `AiQo/App/SceneDelegate.swift:278`, `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:4`. Impact: the shipped flow does not match the requested reorder or dedicated goals/sleep setup. Suggested fix: decide whether to ship the current flow intentionally or implement the missing surfaces before public exposure.

### 10.2 Blockers for AUE Launch
- **Recent planned onboarding additions are missing** — `AiQo/App/SceneDelegate.swift:52`, `AiQo/App/SceneDelegate.swift:91`. Impact: no `GoalsAndSleepSetupView`, no end-of-flow level classification, and no `UserTrainingProfile` model. Suggested fix: either implement those surfaces or formally de-scope them in product docs and paywall messaging.
- **Captain Context Assembly naming plan did not land** — `AiQo/Features/Captain/CaptainContextBuilder.swift:134`. Impact: docs and engineering language are now drifting; onboarding new engineers against stale terminology will slow work. Suggested fix: either rename current code to match the intended design or update design docs to the live `CaptainContextBuilder` model.
- **Captain memory settings UI misreports entitlement** — `AiQo/Core/CaptainMemorySettingsView.swift:67`, `AiQo/Premium/AccessManager.swift:58`. Impact: premium users can be told they only have 200 memory slots when the actual limit is 500. Suggested fix: read the live limit from `AccessManager` or `MemoryStore`.
- **Tribe leaderboards still contain identity and scoring bugs** — `AiQo/Tribe/Views/TribeLeaderboardView.swift:96`, `AiQo/Tribe/Galaxy/TribeMembersList.swift:28`. Impact: visible social data can show double `@` usernames and fake `0 / Level 1` values. Suggested fix: normalize displayed usernames and source member scores from synced profile data instead of hardcoded fallbacks.

### 10.3 Non-blocking debt
- **`WatchConnectivityService` still polls every 2 seconds** — `AiQoWatch Watch App/Services/WatchConnectivityService.swift:18`. Impact: needless battery churn and overlapping responsibilities with `WatchConnectivityManager`. Suggested fix: rely on delegate callbacks and remove the timer.
- **`PhoneConnectivityManager` still duplicates XP logic** — `AiQo/PhoneConnectivityManager.swift:756`, `AiQo/XPCalculator.swift:23`. Impact: watch-earned XP can drift from app-earned XP. Suggested fix: centralize the formula in `XPCalculator`.
- **Inactivity notifications still contain hardcoded prompt/fallback text** — `AiQo/Services/Notifications/NotificationService.swift:468`. Impact: localization and tuning remain harder than the rest of the notification stack. Suggested fix: move inactivity prompt generation to the same key-based localization layer used elsewhere.
- **Analytics writes are still per-event synchronous file appends** — `AiQo/Services/Analytics/AnalyticsService.swift:157`, `AiQo/Services/Analytics/AnalyticsService.swift:160`. Impact: avoidable I/O overhead on busy sessions. Suggested fix: batch and flush periodically.
- **Large-file concentration remains high** — `AiQo/Services/SupabaseArenaService.swift:10`, `AiQo/Services/Notifications/NotificationService.swift:13`, `AiQo/Features/Captain/CaptainScreen.swift:196`, `AiQoWatch Watch App/WorkoutManager.swift:17`. Impact: slower audits, slower iteration, and more regression risk. Suggested fix: split UI composition, networking, and domain logic into smaller modules.

---

## 11. Feature Flags Inventory
| Flag | Location | Current value | Controls | Safe to flip? |
|---|---|---|---|---|
| `TRIBE_BACKEND_ENABLED` | `AiQo/Info.plist:74` | `false` | Enables backend-backed Tribe paths through `TribeFeatureFlags` in `AiQo/Tribe/Models/TribeFeatureModels.swift:27` | No. Backend code still carries TODOs and stale UI assumptions. |
| `TRIBE_FEATURE_VISIBLE` | `AiQo/Info.plist:76` | `false` | Hides Tribe UI entry points read in `AiQo/Tribe/Models/TribeFeatureModels.swift:35` | No. Flipping exposes incomplete social UX and data bugs. |
| `TRIBE_SUBSCRIPTION_GATE_ENABLED` | `AiQo/Info.plist:78` | `false` | Controls whether Tribe access is premium-gated, read in `AiQo/Tribe/Models/TribeFeatureModels.swift:30` | Not yet. `AccessManager` currently force-opens Tribe access when this is false in `AiQo/Premium/AccessManager.swift:194`. |
| `HealthKitService.permissionFlowEnabled` | `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:29` | `false` by default, flipped true during onboarding | Guards whether HealthKit permission flow is active | Yes, but only as part of onboarding. Flipping it globally changes permission behavior. |
| `useLocalStoreKitConfig` | `AiQo/Core/Purchases/PurchaseManager.swift:12` | `true` in DEBUG, `false` in release | Chooses local `.storekit` config usage | Yes for development, no for release. |
| `previewEnabled` / preview mode | `AiQo/Premium/AccessManager.swift:8` | `false` by default | Developer override of entitlements in DEBUG | Yes for local QA only. |
| `ScreenshotMode.isActive` | `AiQo/App/SceneDelegate.swift:173` | Build/runtime dependent | Forces app root to `.main` for screenshots | Yes for internal screenshot builds only. |

---

## 12. Test Coverage
Current automated coverage is still thin relative to app size. The repo contains 423 Swift files and 106,104 Swift LOC, but only 8 Swift test files totaling 540 LOC across the unit and watch UI test targets. The current test files are `AiQoTests/IngredientAssetCatalogTests.swift`, `AiQoTests/IngredientAssetLibraryTests.swift`, `AiQoTests/PurchasesTests.swift`, `AiQoTests/QuestEvaluatorTests.swift`, `AiQoTests/SmartWakeManagerTests.swift`, `AiQoWatch Watch AppTests/AiQoWatch_Watch_AppTests.swift`, `AiQoWatch Watch AppUITests/AiQoWatch_Watch_AppUITests.swift`, and `AiQoWatch Watch AppUITests/AiQoWatch_Watch_AppUITestsLaunchTests.swift`.

What is covered: kitchen ingredient asset sanity, purchase surface checks, quest evaluator logic, smart wake behavior, and watch target scaffolding. What is not covered: `BrainOrchestrator` routing, `PrivacySanitizer` redaction, `MemoryExtractor`, onboarding state transitions, Supabase failure handling, notification scheduling, Tribe sync, crash reporting, and watch/phone XP synchronization. There are still no Swift UI tests under `AiQoUITests/`.

For the app’s critical path, the biggest missing tests are `AiQo/Features/Captain/BrainOrchestrator.swift:36`, `AiQo/Features/Captain/PrivacySanitizer.swift:95`, `AiQo/Core/MemoryExtractor.swift:18`, `AiQo/Core/Purchases/PurchaseManager.swift:75`, `AiQo/App/SceneDelegate.swift:171`, and `AiQo/Services/Notifications/NotificationService.swift:175`.

---

## 13. Performance & Budget Notes
The largest performance-sensitive AI path is still the Captain cloud route. Memory budgets are capped before transport in `AiQo/Features/Captain/CloudBrainService.swift:47`, output tokens are screen-specific in `AiQo/Features/Captain/HybridBrainService.swift:300`, and the extraction model uses a smaller 160-token budget in `AiQo/Core/MemoryExtractor.swift:229`. That is a solid budget discipline baseline, but it is still encoded in several files instead of one model-budget registry.

The biggest background/runtime risks are not pure CPU work; they are I/O and coordination. `AnalyticsService` still writes JSONL on every event in `AiQo/Services/Analytics/AnalyticsService.swift:157`, the local crash logger still writes JSONL synchronously in `AiQo/Services/CrashReporting/CrashReporter.swift:198`, and `WatchConnectivityService` still polls on a fixed timer in `AiQoWatch Watch App/Services/WatchConnectivityService.swift:18`.

Main-thread and maintainability risk is concentrated in very large files and view models. The current manifest scan still finds 14 Swift files over 1,000 LOC, including `AiQo/Services/SupabaseArenaService.swift:10`, `AiQo/Services/Notifications/NotificationService.swift:13`, `AiQo/Features/Captain/CaptainScreen.swift:196`, and `AiQoWatch Watch App/WorkoutManager.swift:17`. None of those are automatic performance bugs on their own, but they raise regression and tuning cost significantly.

---

## 14. File-by-File Appendix
### AiQo
AiQo/AiQoActivityNames.swift — DeviceActivityName, DeviceActivityEvent — Defines DeviceActivityName, DeviceActivityEvent.
AiQo/App/AppDelegate.swift — AiQoApp, AppDelegate, SiriWorkoutType — Defines AiQoApp, AppDelegate, SiriWorkoutType.
AiQo/App/AppRootManager.swift — AppRootManager — State and logic for AppRootManager.
AiQo/App/AuthFlowUI.swift — AuthFlowTheme, Font, AuthFlowBackground — Defines AuthFlowTheme, Font, AuthFlowBackground.
AiQo/App/LanguageSelectionView.swift — LanguageSelectionView — UI surface for LanguageSelectionView.
AiQo/App/LoginViewController.swift — LoginScreenView, LoginScreenViewModel — UI surface for LoginViewController.
AiQo/App/MainTabRouter.swift — MainTabRouter, Tab, MainTabRouter — State and logic for MainTabRouter.
AiQo/App/MainTabScreen.swift — MainTabScreen — UI surface for MainTabScreen.
AiQo/App/MealModels.swift — MealItem, MealCardData — Model definitions for MealModels.
AiQo/App/ProfileSetupView.swift — ProfileSetupView, SetupPrivacyToggleCard — UI surface for ProfileSetupView.
AiQo/App/SceneDelegate.swift — OnboardingKeys, AppFlowController, RootScreen — Defines OnboardingKeys, AppFlowController, RootScreen.
AiQo/AppGroupKeys.swift — AppGroupKeys — Defines AppGroupKeys.
AiQo/Core/AiQoAccessibility.swift — View, AiQoAccessibility, AccessibleDaySummary — Defines View, AiQoAccessibility, AccessibleDaySummary.
AiQo/Core/AiQoAudioManager.swift — AiQoAudioManager — State and logic for AiQoAudioManager.
AiQo/Core/AppSettingsScreen.swift — AppSettingsScreen — UI surface for AppSettingsScreen.
AiQo/Core/AppSettingsStore.swift — AppLanguage, AppSettingsStore, Notification — State and logic for AppSettingsStore.
AiQo/Core/ArabicNumberFormatter.swift — Int, Double — Defines Int, Double.
AiQo/Core/CaptainMemory.swift — CaptainMemory — Defines CaptainMemory.
AiQo/Core/CaptainMemorySettingsView.swift — CaptainMemorySettingsView — UI surface for CaptainMemorySettingsView.
AiQo/Core/CaptainVoiceAPI.swift — CaptainVoiceAPI, Configuration, VoiceSettings — Defines CaptainVoiceAPI, Configuration, VoiceSettings.
AiQo/Core/CaptainVoiceCache.swift — CachedPhrase, CaptainVoiceCache — Defines CachedPhrase, CaptainVoiceCache.
AiQo/Core/CaptainVoiceService.swift — CaptainVoiceService, CaptainVoiceService — State and logic for CaptainVoiceService.
AiQo/Core/Colors.swift — Colors, Color — Defines Colors, Color.
AiQo/Core/Constants.swift — K, Supabase — Defines K, Supabase.
AiQo/Core/DailyGoals.swift — DailyGoals, GoalsStore — Defines DailyGoals, GoalsStore.
AiQo/Core/DeveloperPanelView.swift — DeveloperPanelView — UI surface for DeveloperPanelView.
AiQo/Core/HapticEngine.swift — HapticEngine — Core processing for HapticEngine.
AiQo/Core/HealthKitMemoryBridge.swift — HealthKitMemoryBridge — Defines HealthKitMemoryBridge.
AiQo/Core/Localization/Bundle+Language.swift — LocalizedBundle, Bundle — Defines LocalizedBundle, Bundle.
AiQo/Core/Localization/LocalizationManager.swift — LocalizationManager — State and logic for LocalizationManager.
AiQo/Core/MemoryExtractor.swift — MemoryExtractor, LLMConfig — Core processing for MemoryExtractor.
AiQo/Core/MemoryStore.swift — MemoryStore, SessionMeta — State and logic for MemoryStore.
AiQo/Core/Models/ActivityNotification.swift — ActivityNotificationType, ActivityNotificationGender, ActivityNotificationLanguage — Defines ActivityNotificationType, ActivityNotificationGender, ActivityNotificationLanguage.
AiQo/Core/Models/LevelStore.swift — Notification, ShieldTier, LevelStore — State and logic for LevelStore.
AiQo/Core/Models/NotificationPreferencesStore.swift — NotificationPreferencesStore — State and logic for NotificationPreferencesStore.
AiQo/Core/Purchases/EntitlementStore.swift — EntitlementStore, Keys — State and logic for EntitlementStore.
AiQo/Core/Purchases/PurchaseManager.swift — PurchaseManager, PurchaseOutcome, EntitlementState — State and logic for PurchaseManager.
AiQo/Core/Purchases/ReceiptValidator.swift — ReceiptValidator, ValidationResult — Defines ReceiptValidator, ValidationResult.
AiQo/Core/Purchases/SubscriptionProductIDs.swift — SubscriptionProductIDs — Defines SubscriptionProductIDs.
AiQo/Core/Purchases/SubscriptionTier.swift — SubscriptionTier — Defines SubscriptionTier.
AiQo/Core/SiriShortcutsManager.swift — SiriShortcutsManager, ActivityType, Notification — State and logic for SiriShortcutsManager.
AiQo/Core/SmartNotificationScheduler.swift — SmartNotificationScheduler, HealthContext, PendingLocalNotification — Defines SmartNotificationScheduler, HealthContext, PendingLocalNotification.
AiQo/Core/SpotifyVibeManager.swift — VibePlaybackState, SpotifyVibeManager, SpotifyVibeManager — State and logic for SpotifyVibeManager.
AiQo/Core/StreakManager.swift — StreakManager, Keys — State and logic for StreakManager.
AiQo/Core/UserProfileStore.swift — UserProfile, UserProfileStore, Notification — State and logic for UserProfileStore.
AiQo/Core/Utilities/ConnectivityDebugProviding.swift — ConnectivityDebugProviding — Defines ConnectivityDebugProviding.
AiQo/Core/Utilities/DebugPrint.swift — (no top-level declaration) — Defines DebugPrint.
AiQo/Core/VibeAudioEngine.swift — VibeDayPart, VibeDayProfile, VibeAudioState — Core processing for VibeAudioEngine.
AiQo/DesignSystem/AiQoColors.swift — AiQoColors — Defines AiQoColors.
AiQo/DesignSystem/AiQoTheme.swift — AiQoTheme, Colors, Typography — Defines AiQoTheme, Colors, Typography.
AiQo/DesignSystem/AiQoTokens.swift — AiQoSpacing, AiQoRadius, AiQoMetrics — Defines AiQoSpacing, AiQoRadius, AiQoMetrics.
AiQo/DesignSystem/Components/AiQoBottomCTA.swift — AiQoBottomCTA — Defines AiQoBottomCTA.
AiQo/DesignSystem/Components/AiQoCard.swift — AiQoCard, IconPlacement — Defines AiQoCard, IconPlacement.
AiQo/DesignSystem/Components/AiQoChoiceGrid.swift — AiQoChoiceGrid, PreviewChoice — Defines AiQoChoiceGrid, PreviewChoice.
AiQo/DesignSystem/Components/AiQoPillSegment.swift — AiQoPillSegment — Defines AiQoPillSegment.
AiQo/DesignSystem/Components/AiQoPlatformPicker.swift — AiQoPlatformPicker, PreviewPlatform — Defines AiQoPlatformPicker, PreviewPlatform.
AiQo/DesignSystem/Components/AiQoSkeletonView.swift — AiQoSkeletonView, AiQoMetricCardSkeleton — UI surface for AiQoSkeletonView.
AiQo/DesignSystem/Components/StatefulPreviewWrapper.swift — StatefulPreviewWrapper — Defines StatefulPreviewWrapper.
AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift — AiQoPressButtonStyle, AiQoPressEffect, View — Defines AiQoPressButtonStyle, AiQoPressEffect, View.
AiQo/DesignSystem/Modifiers/AiQoShadow.swift — AiQoShadow, View — Defines AiQoShadow, View.
AiQo/DesignSystem/Modifiers/AiQoSheetStyle.swift — AiQoSheetStyle, View — Defines AiQoSheetStyle, View.
AiQo/Features/Captain/AiQoPromptManager.swift — AiQoPromptManager, PromptKey, PromptIdentifier — State and logic for AiQoPromptManager.
AiQo/Features/Captain/BrainOrchestrator.swift — BrainOrchestrator, BrainOrchestrator, Route — Core processing for BrainOrchestrator.
AiQo/Features/Captain/CaptainAvatar3DView.swift — CaptainAvatar3DView — UI surface for CaptainAvatar3DView.
AiQo/Features/Captain/CaptainChatView.swift — CaptainChatView, CaptainChatView, ChatMessageRow — UI surface for CaptainChatView.
AiQo/Features/Captain/CaptainContextBuilder.swift — BioTimePhase, CaptainContextData, CaptainSystemContextSnapshot — Core processing for CaptainContextBuilder.
AiQo/Features/Captain/CaptainFallbackPolicy.swift — CaptainFallbackPolicy — Defines CaptainFallbackPolicy.
AiQo/Features/Captain/CaptainIntelligenceManager.swift — CaptainDailyHealthMetrics, CaptainIntelligenceError, CaptainResponseRoute — State and logic for CaptainIntelligenceManager.
AiQo/Features/Captain/CaptainModels.swift — PersistentChatMessage, ChatSession, CaptainStructuredResponse — Model definitions for CaptainModels.
AiQo/Features/Captain/CaptainNotificationRouting.swift — CaptainNotificationHandler, CaptainNavigationHelper, Notification — Defines CaptainNotificationHandler, CaptainNavigationHelper, Notification.
AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift — CaptainOnDeviceChatError, CaptainOnDeviceChatEngine, LiveHealthContext — Core processing for CaptainOnDeviceChatEngine.
AiQo/Features/Captain/CaptainPersonaBuilder.swift — CaptainPersonaBuilder — Core processing for CaptainPersonaBuilder.
AiQo/Features/Captain/CaptainPromptBuilder.swift — CaptainPromptBuilder — Core processing for CaptainPromptBuilder.
AiQo/Features/Captain/CaptainScreen.swift — CaptainCustomization, CaptainTone, CoachCognitiveState — UI surface for CaptainScreen.
AiQo/Features/Captain/CaptainViewModel.swift — CaptainProcessingTimeoutError, ChatMessageAccessory, ChatMessage — UI surface for CaptainViewModel.
AiQo/Features/Captain/ChatHistoryView.swift — ChatHistoryView, ChatHistoryView — UI surface for ChatHistoryView.
AiQo/Features/Captain/CloudBrainService.swift — CloudBrainService, GeminiModel — State and logic for CloudBrainService.
AiQo/Features/Captain/CoachBrainMiddleware.swift — CoachBrainTranslating, CoachBrainLLMTranslator, GeminiTranslationResponse — Defines CoachBrainTranslating, CoachBrainLLMTranslator, GeminiTranslationResponse.
AiQo/Features/Captain/CoachBrainTranslationConfig.swift — CoachBrainTranslationServiceConfiguration, CoachBrainTranslationConfigurationError, CoachBrainTranslationConfig — Defines CoachBrainTranslationServiceConfiguration, CoachBrainTranslationConfigurationError, CoachBrainTranslationConfig.
AiQo/Features/Captain/HybridBrainService.swift — CaptainConversationRole, CaptainConversationMessage, HybridBrainRequest — State and logic for HybridBrainService.
AiQo/Features/Captain/LLMJSONParser.swift — LLMJSONParser, CaptainResponse, LLMJSONParser — Core processing for LLMJSONParser.
AiQo/Features/Captain/LocalBrainService.swift — LocalBackgroundNotificationKind, LocalConversationRole, LocalConversationMessage — State and logic for LocalBrainService.
AiQo/Features/Captain/LocalIntelligenceService.swift — LocalIntelligenceServiceError, LocalSleepAnalysisSnapshot, LocalIntelligenceService — State and logic for LocalIntelligenceService.
AiQo/Features/Captain/MessageBubble.swift — MessageBubble — Defines MessageBubble.
AiQo/Features/Captain/PrivacySanitizer.swift — PrivacySanitizer, PrivacySanitizer, RedactionRule — Defines PrivacySanitizer, PrivacySanitizer, RedactionRule.
AiQo/Features/Captain/PromptRouter.swift — PromptRouter, PromptRouter, AppLanguage — State and logic for PromptRouter.
AiQo/Features/Captain/ScreenContext.swift — ScreenContext — Defines ScreenContext.
AiQo/Features/DataExport/HealthDataExporter.swift — HealthDataExporter — Defines HealthDataExporter.
AiQo/Features/First screen/LegacyCalculationViewController.swift — LegacyCalculationScreenView, LegacyCalculationViewModel, LoadingPhase — UI surface for LegacyCalculationViewController.
AiQo/Features/Gym/ActiveRecoveryView.swift — ActiveRecoveryView — UI surface for ActiveRecoveryView.
AiQo/Features/Gym/AudioCoachManager.swift — AudioCoachManager, Zone2Target, Zone2State — State and logic for AudioCoachManager.
AiQo/Features/Gym/CinematicGrindCardView.swift — CinematicGrindCardView — UI surface for CinematicGrindCardView.
AiQo/Features/Gym/CinematicGrindViews.swift — CinematicPlatform, CinematicMood, CinematicGrindSuggestion — UI surface for CinematicGrindViews.
AiQo/Features/Gym/Club/Body/BodyView.swift — BodyView — UI surface for BodyView.
AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift — GratitudeSessionLanguage, GratitudeAudioManager, GratitudeAudioManager — State and logic for GratitudeAudioManager.
AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift — GratitudeSessionView, SessionTiming — UI surface for GratitudeSessionView.
AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift — WorkoutCardItem, WorkoutCategoriesView, ClubWorkoutCard — UI surface for WorkoutCategoriesView.
AiQo/Features/Gym/Club/Challenges/ChallengesView.swift — ChallengesView — UI surface for ChallengesView.
AiQo/Features/Gym/Club/ClubRootView.swift — ClubTopTab, ClubRootView, PresentedExercise — UI surface for ClubRootView.
AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift — GlobalTopCapsuleTabsView, NativeTopCapsuleTabsControl, Coordinator — Defines GlobalTopCapsuleTabsView, NativeTopCapsuleTabsControl, Coordinator.
AiQo/Features/Gym/Club/Components/RailScrollOffsetPreferenceKey.swift — RailScrollOffsetPreferenceKey, RailScrollOffsetReader — Defines RailScrollOffsetPreferenceKey, RailScrollOffsetReader.
AiQo/Features/Gym/Club/Components/RightSideRailView.swift — RightSideRailView — UI surface for RightSideRailView.
AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift — RailItem, ClubRailLayout, RightSideVerticalRail — Defines RailItem, ClubRailLayout, RightSideVerticalRail.
AiQo/Features/Gym/Club/Components/SegmentedTabs.swift — ClubSegmentedTabItem, ClubSegmentedTabItem, PrimarySegmentedTabs — Defines ClubSegmentedTabItem, ClubSegmentedTabItem, PrimarySegmentedTabs.
AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift — ClubChromeLayout, SlimRightSideRailConfiguration, SlimRightSideRail — Defines ClubChromeLayout, SlimRightSideRailConfiguration, SlimRightSideRail.
AiQo/Features/Gym/Club/Impact/ImpactAchievementsView.swift — ImpactAchievementsView — UI surface for ImpactAchievementsView.
AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift — ImpactSubTab, ClubTopTab, ImpactSubTab — UI surface for ImpactContainerView.
AiQo/Features/Gym/Club/Impact/ImpactSummaryView.swift — ImpactSummaryView — UI surface for ImpactSummaryView.
AiQo/Features/Gym/Club/Plan/PlanView.swift — PlanView, CaptainLiveWorkoutPlanCard — UI surface for PlanView.
AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift — WorkoutPlanDashboard, CaptainPlanChatView, CaptainPendingWorkoutPreviewCard — UI surface for WorkoutPlanFlowViews.
AiQo/Features/Gym/ExercisesView.swift — ExercisesView — UI surface for ExercisesView.
AiQo/Features/Gym/GuinnessEncyclopediaView.swift — GuinnessCard, GuinnessCardSize, GuinnessTheme — UI surface for GuinnessEncyclopediaView.
AiQo/Features/Gym/GymViewController.swift — GymTheme, GymView — UI surface for GymViewController.
AiQo/Features/Gym/HandsFreeZone2Manager.swift — HandsFreeZone2Manager, HandsFreeZone2WaveformView, HandsFreeZone2ManagerViewModel — State and logic for HandsFreeZone2Manager.
AiQo/Features/Gym/HeartView.swift — HeartView — UI surface for HeartView.
AiQo/Features/Gym/L10n.swift — L10n — Defines L10n.
AiQo/Features/Gym/LiveMetricsHeader.swift — LiveMetricsHeader — Defines LiveMetricsHeader.
AiQo/Features/Gym/LiveWorkoutSession.swift — LiveWorkoutSession, Phase, Zone2AuraState — Defines LiveWorkoutSession, Phase, Zone2AuraState.
AiQo/Features/Gym/Models/GymExercise.swift — GymWorkoutKind, WorkoutCoachingProfile, GymExercise — Defines GymWorkoutKind, WorkoutCoachingProfile, GymExercise.
AiQo/Features/Gym/MyPlanViewController.swift — StatItem, WorkoutExerciseItem, TemplateExerciseItem — UI surface for MyPlanViewController.
AiQo/Features/Gym/OriginalWorkoutCardView.swift — OriginalWorkoutCardView, Color — UI surface for OriginalWorkoutCardView.
AiQo/Features/Gym/PhoneWorkoutSummaryView.swift — PhoneWorkoutSummaryView, SpaceBackdrop, Starfield — UI surface for PhoneWorkoutSummaryView.
AiQo/Features/Gym/QuestKit/QuestDataSources.swift — QuestSleepSummary, HealthKitDataSource, CameraVisionDataSource — Defines QuestSleepSummary, HealthKitDataSource, CameraVisionDataSource.
AiQo/Features/Gym/QuestKit/QuestDefinitions.swift — QuestDefinitions — Defines QuestDefinitions.
AiQo/Features/Gym/QuestKit/QuestEngine.swift — Notification, QuestDebugOverrides, QuestEngine — Core processing for QuestEngine.
AiQo/Features/Gym/QuestKit/QuestEvaluator.swift — QuestEvaluator — Core processing for QuestEvaluator.
AiQo/Features/Gym/QuestKit/QuestFormatting.swift — Stage1QuestFormatter — Defines Stage1QuestFormatter.
AiQo/Features/Gym/QuestKit/QuestKitModels.swift — QuestType, QuestSource, QuestMetricUnit — Model definitions for QuestKitModels.
AiQo/Features/Gym/QuestKit/QuestProgressStore.swift — QuestProgressStore, UserDefaultsQuestProgressStore, QuestDateKeyFactory — State and logic for QuestProgressStore.
AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift — RewardKind, PlayerStats, QuestStage — Model definitions for QuestSwiftDataModels.
AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift — PlayerStatsSyncing, QuestPersistenceController, SwiftDataQuestProgressStore — State and logic for QuestSwiftDataStore.
AiQo/Features/Gym/QuestKit/Views/QuestCameraPermissionGateView.swift — QuestCameraPermissionGateView — UI surface for QuestCameraPermissionGateView.
AiQo/Features/Gym/QuestKit/Views/QuestDebugView.swift — QuestDebugView — UI surface for QuestDebugView.
AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift — QuestPushupChallengeView, CameraPreviewView, CameraPreviewUIView — UI surface for QuestPushupChallengeView.
AiQo/Features/Gym/Quests/Models/Challenge.swift — ChallengeType, ChallengeMetricType, Challenge — Defines ChallengeType, ChallengeMetricType, Challenge.
AiQo/Features/Gym/Quests/Models/ChallengeStage.swift — ChallengeStage — Defines ChallengeStage.
AiQo/Features/Gym/Quests/Models/HelpStrangersModels.swift — HelpType, HelpImpact, HelpEntry — Model definitions for HelpStrangersModels.
AiQo/Features/Gym/Quests/Models/WinRecord.swift — WinRecord, CodingKeys, PendingChallengeReward — Defines WinRecord, CodingKeys, PendingChallengeReward.
AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift — QuestEarnedAchievement, QuestAchievementStore — State and logic for QuestAchievementStore.
AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift — DailyChallengeCompletion, QuestDailyStateV3, QuestDailyStateV2 — State and logic for QuestDailyStore.
AiQo/Features/Gym/Quests/Store/WinsStore.swift — WinsStore — State and logic for WinsStore.
AiQo/Features/Gym/Quests/Views/ChallengeCard.swift — QuestCardView, ChallengePlaceholderCard — Defines QuestCardView, ChallengePlaceholderCard.
AiQo/Features/Gym/Quests/Views/ChallengeDetailView.swift — ChallengeDetailView — UI surface for ChallengeDetailView.
AiQo/Features/Gym/Quests/Views/ChallengeRewardSheet.swift — ChallengeRewardSheet — Defines ChallengeRewardSheet.
AiQo/Features/Gym/Quests/Views/ChallengeRunView.swift — ChallengeRunView — UI surface for ChallengeRunView.
AiQo/Features/Gym/Quests/Views/HelpStrangersBottomSheet.swift — HelpStrangersInputField, HelpStrangersBottomSheet, HelpEntryInputCard — Defines HelpStrangersInputField, HelpStrangersBottomSheet, HelpEntryInputCard.
AiQo/Features/Gym/Quests/Views/QuestCard.swift — QuestCard — Defines QuestCard.
AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift — QuestCompletionCelebration, ClearBackground — Defines QuestCompletionCelebration, ClearBackground.
AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift — QuestDetailSheet, QuestSheetContent, QuestSheetContentProvider — Defines QuestDetailSheet, QuestSheetContent, QuestSheetContentProvider.
AiQo/Features/Gym/Quests/Views/QuestDetailView.swift — QuestDetailView, StageOneQuestSheet, StageOneSheetContent — UI surface for QuestDetailView.
AiQo/Features/Gym/Quests/Views/QuestWinsGridView.swift — QuestWinsGridView, WinAwardCard, QuestAchievementCard — UI surface for QuestWinsGridView.
AiQo/Features/Gym/Quests/Views/QuestsView.swift — PeaksRecordsView, BattleChallengesView, RecordCardVertical — UI surface for QuestsView.
AiQo/Features/Gym/Quests/Views/StageSelectorBar.swift — StageSelectorBar — Defines StageSelectorBar.
AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift — VisionCoachAudioFeedback — Defines VisionCoachAudioFeedback.
AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift — VisionCoachView, CameraPreviewView, CameraPreviewUIView — UI surface for VisionCoachView.
AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift — VisionCoachViewModel, CameraState, VisionCoachViewModel — UI surface for VisionCoachViewModel.
AiQo/Features/Gym/RecapViewController.swift — WorkoutHistorySection, WorkoutMetric, WorkoutHistoryItem — UI surface for RecapViewController.
AiQo/Features/Gym/RewardsViewController.swift — RewardItem, RewardsView, RewardCardView — UI surface for RewardsViewController.
AiQo/Features/Gym/ShimmeringPlaceholder.swift — ShimmeringSkeletonModifier, View, MatchSkeletonCard — Defines ShimmeringSkeletonModifier, View, MatchSkeletonCard.
AiQo/Features/Gym/SoftGlassCardView.swift — SoftGlassCardView — UI surface for SoftGlassCardView.
AiQo/Features/Gym/SpotifyWebView.swift — SpotifyWebView, SpotifyVibesLibrarySheet — UI surface for SpotifyWebView.
AiQo/Features/Gym/SpotifyWorkoutPlayerView.swift — SpotifyWorkoutPlayerView — UI surface for SpotifyWorkoutPlayerView.
AiQo/Features/Gym/T/SpinWheelView.swift — SpinWheelView, WheelSegmentsView, WheelSegment — UI surface for SpinWheelView.
AiQo/Features/Gym/T/WheelTypes.swift — WheelState, MediaMode — Defines WheelState, MediaMode.
AiQo/Features/Gym/T/WorkoutTheme.swift — WorkoutTheme, StarryBackground — Defines WorkoutTheme, StarryBackground.
AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift — WorkoutVideo, WorkoutWheelSessionViewModel — UI surface for WorkoutWheelSessionViewModel.
AiQo/Features/Gym/WatchConnectionStatusButton.swift — WatchConnectionStatusButton — Defines WatchConnectionStatusButton.
AiQo/Features/Gym/WatchConnectivityService.swift — WatchConnectionStatus, WatchConnectivityService — State and logic for WatchConnectivityService.
AiQo/Features/Gym/WinsViewController.swift — RecapStyle, SoftGlassCardBackground, View — UI surface for WinsViewController.
AiQo/Features/Gym/WorkoutLiveActivityManager.swift — WorkoutLiveActivityManager, WorkoutActivityAttributes, ContentState — State and logic for WorkoutLiveActivityManager.
AiQo/Features/Gym/WorkoutSessionScreen.swift.swift — WorkoutSessionScreen, WorkoutCompletionSnapshot, ActiveRecoveryContext — Defines WorkoutSessionScreen, WorkoutCompletionSnapshot, ActiveRecoveryContext.
AiQo/Features/Gym/WorkoutSessionSheetView.swift — WorkoutSessionSheetView — UI surface for WorkoutSessionSheetView.
AiQo/Features/Gym/WorkoutSessionViewModel.swift — WorkoutSessionViewModel, PrimaryControlConfiguration — UI surface for WorkoutSessionViewModel.
AiQo/Features/Home/ActivityDataProviding.swift — ActivitySnapshot, ActivityDataProviding, HealthKitActivityProvider — Defines ActivitySnapshot, ActivityDataProviding, HealthKitActivityProvider.
AiQo/Features/Home/DJCaptainChatView.swift — DJCaptainChatView, DJCaptainChatView, DJCaptainMessageRow — UI surface for DJCaptainChatView.
AiQo/Features/Home/DailyAuraModels.swift — DailyRecord — Model definitions for DailyAuraModels.
AiQo/Features/Home/DailyAuraPathData.swift — DailyAuraPathData — Defines DailyAuraPathData.
AiQo/Features/Home/DailyAuraView.swift — DailyAuraView, AuraArcShape, AuraVectorSegment — UI surface for DailyAuraView.
AiQo/Features/Home/DailyAuraViewModel.swift — DailyAuraViewModel — UI surface for DailyAuraViewModel.
AiQo/Features/Home/HealthKitService+Water.swift — HealthKitService — Defines HealthKitService.
AiQo/Features/Home/HomeStatCard.swift — HomeStatCard, HomeStatCard, StatCardRow — Defines HomeStatCard, HomeStatCard, StatCardRow.
AiQo/Features/Home/HomeView.swift — HomeView, HomeKitchenRootView, HomeKitchenSheetView — UI surface for HomeView.
AiQo/Features/Home/HomeViewModel.swift — MetricKind, TodaySummary, TimeScope — UI surface for HomeViewModel.
AiQo/Features/Home/LevelUpCelebrationView.swift — LevelUpCelebrationView — UI surface for LevelUpCelebrationView.
AiQo/Features/Home/MetricKind.swift — MetricKind — Defines MetricKind.
AiQo/Features/Home/ScreenshotMode.swift — ScreenshotScenario, ScreenshotMode — Defines ScreenshotScenario, ScreenshotMode.
AiQo/Features/Home/SpotifyVibeCard.swift — SpotifyVibeCard, Presentation, SpotifyVibeCard — Defines SpotifyVibeCard, Presentation, SpotifyVibeCard.
AiQo/Features/Home/StreakBadgeView.swift — StreakBadgeView, StreakDetailCard — UI surface for StreakBadgeView.
AiQo/Features/Home/VibeControlComponents.swift — VibeDashboardTriggerButton, SpotifyPlaylistPreview, VibeModeCard — Defines VibeDashboardTriggerButton, SpotifyPlaylistPreview, VibeModeCard.
AiQo/Features/Home/VibeControlSheet.swift — VibeControlSheet — Defines VibeControlSheet.
AiQo/Features/Home/VibeControlSheetLogic.swift — VibeControlSheet — Defines VibeControlSheet.
AiQo/Features/Home/VibeControlSupport.swift — RoutePickerView, VibeMode, VibePlaybackSource — Defines RoutePickerView, VibeMode, VibePlaybackSource.
AiQo/Features/Home/WaterBottleView.swift — WaterBottleView, LiquidShape, WaveShape — UI surface for WaterBottleView.
AiQo/Features/Home/WaterDetailSheetView.swift — WaterDetailSheetView, BounceButtonStyle, WaterDetailSheetView — UI surface for WaterDetailSheetView.
AiQo/Features/Kitchen/CameraView.swift — CameraView, Coordinator — UI surface for CameraView.
AiQo/Features/Kitchen/CompositePlateView.swift — CompositePlateView, CompositePlateView, PlateTemplate — UI surface for CompositePlateView.
AiQo/Features/Kitchen/FridgeInventoryView.swift — FridgeInventoryView, FridgeInventoryView — UI surface for FridgeInventoryView.
AiQo/Features/Kitchen/IngredientAssetCatalog.swift — IngredientAssetCatalog, BundleMarker, IngredientIconView — Defines IngredientAssetCatalog, BundleMarker, IngredientIconView.
AiQo/Features/Kitchen/IngredientAssetLibrary.swift — IngredientAssetLibrary, IngredientLocalAssetView — Defines IngredientAssetLibrary, IngredientLocalAssetView.
AiQo/Features/Kitchen/IngredientCatalog.swift — IngredientCatalog — Defines IngredientCatalog.
AiQo/Features/Kitchen/IngredientDisplayItem.swift — IngredientDisplayItem, IngredientDisplayBuilder, Bucket — Defines IngredientDisplayItem, IngredientDisplayBuilder, Bucket.
AiQo/Features/Kitchen/IngredientKey.swift — IngredientCategory, IngredientKey, IngredientKey — Defines IngredientCategory, IngredientKey, IngredientKey.
AiQo/Features/Kitchen/InteractiveFridgeView.swift — InteractiveFridgeView, InteractiveFridgeView, InteractiveFridgeScreenBackground — UI surface for InteractiveFridgeView.
AiQo/Features/Kitchen/KitchenLanguageRouter.swift — KitchenLanguageRoute, KitchenLanguageRouter — State and logic for KitchenLanguageRouter.
AiQo/Features/Kitchen/KitchenModels.swift — KitchenMealType, IngredientAvailabilityState, FridgeItem — Model definitions for KitchenModels.
AiQo/Features/Kitchen/KitchenPersistenceStore.swift — KitchenPersistenceStore — State and logic for KitchenPersistenceStore.
AiQo/Features/Kitchen/KitchenPlanGenerationService.swift — KitchenPlanGenerationService, GeneratedPlanPayload, GeneratedMealPayload — State and logic for KitchenPlanGenerationService.
AiQo/Features/Kitchen/KitchenSceneView.swift — KitchenSceneView, KitchenSceneView — UI surface for KitchenSceneView.
AiQo/Features/Kitchen/KitchenScreen.swift — KitchenScreen, KitchenScreen, KitchenMealType — UI surface for KitchenScreen.
AiQo/Features/Kitchen/KitchenView.swift — KitchenView, KitchenView, KitchenView — UI surface for KitchenView.
AiQo/Features/Kitchen/KitchenViewModel.swift — KitchenViewModel, LoadingState — UI surface for KitchenViewModel.
AiQo/Features/Kitchen/LocalMealsRepository.swift — LocalMealsRepository — Defines LocalMealsRepository.
AiQo/Features/Kitchen/Meal.swift — Meal, MealType, Meal — Defines Meal, MealType, Meal.
AiQo/Features/Kitchen/MealIllustrationView.swift — MealIllustrationView — UI surface for MealIllustrationView.
AiQo/Features/Kitchen/MealImageSpec.swift — PlateIngredient, MealImageSpec, MealDetailPresentation — Defines PlateIngredient, MealImageSpec, MealDetailPresentation.
AiQo/Features/Kitchen/MealPlanGenerator.swift — DailyMealPlan, MealPlanError, MealPlanGenerator — Defines DailyMealPlan, MealPlanError, MealPlanGenerator.
AiQo/Features/Kitchen/MealPlanView.swift — MealPlanView, MealPlanView — UI surface for MealPlanView.
AiQo/Features/Kitchen/MealSectionView.swift — MealSectionView — UI surface for MealSectionView.
AiQo/Features/Kitchen/MealsRepository.swift — MealsRepository — Defines MealsRepository.
AiQo/Features/Kitchen/NutritionTrackerView.swift — NutritionPalette, NutritionSummaryCard, NutritionGoalsEditor — UI surface for NutritionTrackerView.
AiQo/Features/Kitchen/PlateTemplate.swift — PlateTemplate — Defines PlateTemplate.
AiQo/Features/Kitchen/RecipeCardView.swift — RecipeCardView, RecipeCardView_Previews — UI surface for RecipeCardView.
AiQo/Features/Kitchen/SmartFridgeCameraPreviewController.swift — SmartFridgeCameraPreviewRepresentable, SmartFridgeCameraPreviewView — Defines SmartFridgeCameraPreviewRepresentable, SmartFridgeCameraPreviewView.
AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift — SmartFridgeCameraViewModel, PermissionState, ScanPhase — UI surface for SmartFridgeCameraViewModel.
AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift — SmartFridgeScannedItemRecord — Defines SmartFridgeScannedItemRecord.
AiQo/Features/Kitchen/SmartFridgeScannerView.swift — SmartFridgeScannerView, SmartFridgePermissionFallbackView, SmartFridgeProcessingOverlay — UI surface for SmartFridgeScannerView.
AiQo/Features/LegendaryChallenges/Components/RecordCard.swift — RecordCard — Defines RecordCard.
AiQo/Features/LegendaryChallenges/Models/LegendaryProject.swift — LegendaryProject, WeeklyCheckpoint, DailyTask — Defines LegendaryProject, WeeklyCheckpoint, DailyTask.
AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift — LegendaryRecord, ChallengeCategory, ChallengeDifficulty — Defines LegendaryRecord, ChallengeCategory, ChallengeDifficulty.
AiQo/Features/LegendaryChallenges/Models/RecordProject.swift — RecordProject — Defines RecordProject.
AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift — WeeklyLog — Defines WeeklyLog.
AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift — RecoveryLevel, HRRWorkoutManager — State and logic for HRRWorkoutManager.
AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift — LegendaryChallengesViewModel — UI surface for LegendaryChallengesViewModel.
AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift — RecordProjectManager, WeekPlanData, DayPlanData — State and logic for RecordProjectManager.
AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift — FitnessAssessmentView — UI surface for FitnessAssessmentView.
AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift — LegendaryChallengesSection, PeaksUpgradePromptView — Defines LegendaryChallengesSection, PeaksUpgradePromptView.
AiQo/Features/LegendaryChallenges/Views/ProjectView.swift — ProjectView — UI surface for ProjectView.
AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift — RecordDetailView — UI surface for RecordDetailView.
AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift — RecordProjectView — UI surface for RecordProjectView.
AiQo/Features/LegendaryChallenges/Views/WeeklyReviewResultView.swift — WeeklyReviewResultView — UI surface for WeeklyReviewResultView.
AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift — WeeklyReviewView, ReviewResult — UI surface for WeeklyReviewView.
AiQo/Features/MyVibe/DailyVibeState.swift — DailyVibeState — Defines DailyVibeState.
AiQo/Features/MyVibe/MyVibeScreen.swift — MyVibeScreen, MyVibeScreen, MyVibeScreen — UI surface for MyVibeScreen.
AiQo/Features/MyVibe/MyVibeSubviews.swift — MyVibeBackground, VibeTimelineNode, VibeWaveformView — Defines MyVibeBackground, VibeTimelineNode, VibeWaveformView.
AiQo/Features/MyVibe/MyVibeViewModel.swift — MyVibeViewModel — UI surface for MyVibeViewModel.
AiQo/Features/MyVibe/VibeOrchestrator.swift — VibeOrchestrator — Core processing for VibeOrchestrator.
AiQo/Features/Onboarding/FeatureIntroView.swift — Color, FeatureIntroView, FeatureIntroPage1 — UI surface for FeatureIntroView.
AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift — HistoricalHealthSyncResult, HistoricalHealthScoring, HistoricalHealthSyncEngine — Core processing for HistoricalHealthSyncEngine.
AiQo/Features/Onboarding/OnboardingWalkthroughView.swift — OnboardingWalkthroughView — UI surface for OnboardingWalkthroughView.
AiQo/Features/Profile/LevelCardView.swift — LevelCardView, LevelScorePillView, LevelCardSnapshot — UI surface for LevelCardView.
AiQo/Features/Profile/ProfileScreen.swift — ProfileScreen — UI surface for ProfileScreen.
AiQo/Features/Profile/ProfileScreenComponents.swift — ProfileVisibilityCard, ProfileBackdrop, ProfileHeroCard — Defines ProfileVisibilityCard, ProfileBackdrop, ProfileHeroCard.
AiQo/Features/Profile/ProfileScreenLogic.swift — ProfileScreen — Defines ProfileScreen.
AiQo/Features/Profile/ProfileScreenModels.swift — ProfileEditField, BioMetricDetail, BioScanHighlight — Model definitions for ProfileScreenModels.
AiQo/Features/Profile/String+Localized.swift — String — Defines String.
AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift — ProgressPhotoStore, ProgressPhotoEntry — State and logic for ProgressPhotoStore.
AiQo/Features/ProgressPhotos/ProgressPhotosView.swift — ProgressPalette, ProgressPhotosView, PhotoGridCell — UI surface for ProgressPhotosView.
AiQo/Features/Sleep/AlarmSetupCardView.swift — AlarmSetupCardView, SmartWakeRecommendation — UI surface for AlarmSetupCardView.
AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift — SleepSession, AppleIntelligenceSleepAgentError, AppleIntelligenceSleepAgent — Defines SleepSession, AppleIntelligenceSleepAgentError, AppleIntelligenceSleepAgent.
AiQo/Features/Sleep/HealthManager+Sleep.swift — SleepStageData, Stage, SleepStageFetchError — State and logic for HealthManager+Sleep.
AiQo/Features/Sleep/SleepDetailCardView.swift — SleepDetailCardView, HistoricalSleepPoint, SleepScoreBreakdown — UI surface for SleepDetailCardView.
AiQo/Features/Sleep/SleepScoreRingView.swift — SleepScoreRingView, Layout, SleepRingAssetLayer — UI surface for SleepScoreRingView.
AiQo/Features/Sleep/SleepSessionObserver.swift — SleepSessionObserver, DefaultsKeys, SleepSessionObserver — Defines SleepSessionObserver, DefaultsKeys, SleepSessionObserver.
AiQo/Features/Sleep/SmartWakeCalculatorView.swift — SmartWakeCalculatorView, SmartWakeInputCard, SmartWakeFeaturedRecommendationCard — UI surface for SmartWakeCalculatorView.
AiQo/Features/Sleep/SmartWakeEngine.swift — SmartWakeMode, SmartWakeWindow, SmartWakeRecommendation — Core processing for SmartWakeEngine.
AiQo/Features/Sleep/SmartWakeViewModel.swift — SmartWakeViewModel — UI surface for SmartWakeViewModel.
AiQo/Features/Tribe/TribeDesignSystem.swift — TribeMarketingSource, TribeScreenshotMode, TribeMarketingInterest — Defines TribeMarketingSource, TribeScreenshotMode, TribeMarketingInterest.
AiQo/Features/Tribe/TribeExperienceFlow.swift — TribeFlowDestination, TribeFeatureDescriptor, TribeExperienceFlowView — Defines TribeFlowDestination, TribeFeatureDescriptor, TribeExperienceFlowView.
AiQo/Features/Tribe/TribeView.swift — EmaraTab, EmaraTribeMember, TribeView — UI surface for TribeView.
AiQo/Features/WeeklyReport/ShareCardRenderer.swift — ShareCardRenderer, WorkoutShareCard, WeeklyShareCard — Defines ShareCardRenderer, WorkoutShareCard, WeeklyShareCard.
AiQo/Features/WeeklyReport/WeeklyReportModel.swift — WeeklyReportData, ReportMetricItem, ReportTint — Model definitions for WeeklyReportModel.
AiQo/Features/WeeklyReport/WeeklyReportView.swift — WeeklyReportView, ReportMetricCard — UI surface for WeeklyReportView.
AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift — WeeklyReportViewModel — UI surface for WeeklyReportViewModel.
AiQo/NeuralMemory.swift — AiQoDailyRecord, WorkoutTask — Defines AiQoDailyRecord, WorkoutTask.
AiQo/PhoneConnectivityManager.swift — PhoneConnectivityManager, VisionCoachEvent, Constants — State and logic for PhoneConnectivityManager.
AiQo/Premium/AccessManager.swift — AccessManager, Keys — State and logic for AccessManager.
AiQo/Premium/EntitlementProvider.swift — EntitlementSnapshot, EntitlementProvider, StoreKitEntitlementProvider — Defines EntitlementSnapshot, EntitlementProvider, StoreKitEntitlementProvider.
AiQo/Premium/FreeTrialManager.swift — FreeTrialManager, TrialState, Keys — State and logic for FreeTrialManager.
AiQo/Premium/PremiumPaywallView.swift — PremiumPaywallView — UI surface for PremiumPaywallView.
AiQo/Premium/PremiumStore.swift — PremiumPlan, PremiumStore — State and logic for PremiumStore.
AiQo/ProtectionModel.swift — ProtectionModel — Model definitions for ProtectionModel.
AiQo/Services/AiQoError.swift — AiQoError — Defines AiQoError.
AiQo/Services/Analytics/AnalyticsEvent.swift — AnalyticsEvent, AnalyticsEvent — Defines AnalyticsEvent, AnalyticsEvent.
AiQo/Services/Analytics/AnalyticsService.swift — AnalyticsProvider, AnalyticsService, ConsoleAnalyticsProvider — State and logic for AnalyticsService.
AiQo/Services/CrashReporting/CrashReporter.swift — CrashReporter — Defines CrashReporter.
AiQo/Services/CrashReporting/CrashReportingService.swift — CrashReportingService — State and logic for CrashReportingService.
AiQo/Services/DeepLinkRouter.swift — DeepLinkRouter, DeepLink — State and logic for DeepLinkRouter.
AiQo/Services/NetworkMonitor.swift — NetworkMonitor, ConnectionType — Defines NetworkMonitor, ConnectionType.
AiQo/Services/NotificationType.swift — NotificationType — Defines NotificationType.
AiQo/Services/Notifications/AlarmSchedulingService.swift — AlarmAuthorizationStatus, ScheduledAlarm, AlarmSaveState — State and logic for AlarmSchedulingService.
AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift — CaptainBackgroundNotificationComposer, Prompt, CaptainBackgroundNotificationComposer — Defines CaptainBackgroundNotificationComposer, Prompt, CaptainBackgroundNotificationComposer.
AiQo/Services/Notifications/InactivityTracker.swift — InactivityTracker — Defines InactivityTracker.
AiQo/Services/Notifications/MorningHabitOrchestrator.swift — MorningHabitOrchestrator, MorningInsight, DefaultsKeys — Core processing for MorningHabitOrchestrator.
AiQo/Services/Notifications/NotificationCategoryManager.swift — NotificationCategoryManager — State and logic for NotificationCategoryManager.
AiQo/Services/Notifications/NotificationLocalization.swift — (no top-level declaration) — Defines NotificationLocalization.
AiQo/Services/Notifications/NotificationRepository.swift — NotificationRepository — Defines NotificationRepository.
AiQo/Services/Notifications/NotificationService.swift — NotificationService, WorkoutCoachingSummary, CaptainSmartNotificationService — State and logic for NotificationService.
AiQo/Services/Notifications/PremiumExpiryNotifier.swift — ScheduledPremiumNotification, PremiumExpiryNotifier — Defines ScheduledPremiumNotification, PremiumExpiryNotifier.
AiQo/Services/Notifications/SmartNotificationManager.swift — SmartNotificationManager — State and logic for SmartNotificationManager.
AiQo/Services/Permissions/HealthKit/HealthKitService.swift — HealthKitQuantitySeries, HealthKitService, WidgetSnapshot — State and logic for HealthKitService.
AiQo/Services/Permissions/HealthKit/TodaySummary.swift — TodaySummary, AllTimeSummary — Defines TodaySummary, AllTimeSummary.
AiQo/Services/ReferralManager.swift — ReferralManager, Keys — State and logic for ReferralManager.
AiQo/Services/SupabaseArenaService.swift — SupabaseArenaService, TribeDTO, TribeMemberDTO — State and logic for SupabaseArenaService.
AiQo/Services/SupabaseService.swift — SupabaseService, ProfileDTO, Profile — State and logic for SupabaseService.
AiQo/Shared/CoinManager.swift — CoinManager — State and logic for CoinManager.
AiQo/Shared/HealthKitManager.swift — HealthKitManager, LiveHealthSnapshot, BioMetrics — State and logic for HealthKitManager.
AiQo/Shared/LevelSystem.swift — LevelSystem, ShieldTier — Defines LevelSystem, ShieldTier.
AiQo/Shared/WorkoutSyncCodec.swift — (no top-level declaration) — Defines WorkoutSyncCodec.
AiQo/Shared/WorkoutSyncModels.swift — (no top-level declaration) — Model definitions for WorkoutSyncModels.
AiQo/Tribe/Arena/TribeArenaView.swift — TribeArenaView, ArenaComposerSheet — UI surface for TribeArenaView.
AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift — ArenaChallengeDetailView, ArenaConfettiView, ConfettiParticle — UI surface for ArenaChallengeDetailView.
AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift — ArenaChallengeHistoryView, CompletedChallengeEntry, ArenaBadge — UI surface for ArenaChallengeHistoryView.
AiQo/Tribe/Galaxy/ArenaModels.swift — ArenaTribe, ArenaTribeMember, ArenaChallengeMetric — Model definitions for ArenaModels.
AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift — ArenaQuickChallengesView, QuickChallengeTemplate — UI surface for ArenaQuickChallengesView.
AiQo/Tribe/Galaxy/ArenaScreen.swift — ArenaScreen, ArenaChallengeGroupCard, ArenaComposerCard — UI surface for ArenaScreen.
AiQo/Tribe/Galaxy/ArenaTabView.swift — ArenaTabView — UI surface for ArenaTabView.
AiQo/Tribe/Galaxy/ArenaViewModel.swift — ArenaViewModel — UI surface for ArenaViewModel.
AiQo/Tribe/Galaxy/BattleLeaderboard.swift — BattleLeaderboard, YourTribeRankBar — Defines BattleLeaderboard, YourTribeRankBar.
AiQo/Tribe/Galaxy/BattleLeaderboardRow.swift — BattleLeaderboardRow — Defines BattleLeaderboardRow.
AiQo/Tribe/Galaxy/ConstellationCanvasView.swift — ConstellationCanvasView — UI surface for ConstellationCanvasView.
AiQo/Tribe/Galaxy/CountdownTimerView.swift — CountdownTimerView, TimeUnitCapsule — UI surface for CountdownTimerView.
AiQo/Tribe/Galaxy/CreateTribeSheet.swift — CreateTribeSheet — Defines CreateTribeSheet.
AiQo/Tribe/Galaxy/EditTribeNameSheet.swift — EditTribeNameSheet — Defines EditTribeNameSheet.
AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift — LeaderboardRow, GlobalUserRow, EmaraArenaViewModel — UI surface for EmaraArenaViewModel.
AiQo/Tribe/Galaxy/EmirateLeadersBanner.swift — EmirateLeadersBanner, MemberInitialsCircle — Defines EmirateLeadersBanner, MemberInitialsCircle.
AiQo/Tribe/Galaxy/GalaxyCanvasView.swift — GalaxyCanvasView — UI surface for GalaxyCanvasView.
AiQo/Tribe/Galaxy/GalaxyHUD.swift — TribePalette, TribeGalaxyBackground, TribeGlassCard — Defines TribePalette, TribeGalaxyBackground, TribeGlassCard.
AiQo/Tribe/Galaxy/GalaxyLayout.swift — GalaxyLayout — Defines GalaxyLayout.
AiQo/Tribe/Galaxy/GalaxyModels.swift — GalaxyConnectionStyle, GalaxyNode, GalaxyEdge — Model definitions for GalaxyModels.
AiQo/Tribe/Galaxy/GalaxyNodeCard.swift — GalaxySelectionCard, GalaxyChallengeMiniCard, GalaxyToast — Defines GalaxySelectionCard, GalaxyChallengeMiniCard, GalaxyToast.
AiQo/Tribe/Galaxy/GalaxyScreen.swift — GalaxyScreen, GalaxyExperienceCard, GalaxyArenaSheet — UI surface for GalaxyScreen.
AiQo/Tribe/Galaxy/GalaxyView.swift — GalaxyView, GalaxyViewPreviewContainer — UI surface for GalaxyView.
AiQo/Tribe/Galaxy/GalaxyViewModel.swift — GalaxyViewModel, GalaxyViewModel — UI surface for GalaxyViewModel.
AiQo/Tribe/Galaxy/HallOfFameFullView.swift — HallOfFameFullView — UI surface for HallOfFameFullView.
AiQo/Tribe/Galaxy/HallOfFameSection.swift — HallOfFameSection, HallOfFameRow — Defines HallOfFameSection, HallOfFameRow.
AiQo/Tribe/Galaxy/InviteCardView.swift — InviteCardView — UI surface for InviteCardView.
AiQo/Tribe/Galaxy/JoinTribeSheet.swift — JoinTribeSheet — Defines JoinTribeSheet.
AiQo/Tribe/Galaxy/MockArenaData.swift — MockArenaData — Defines MockArenaData.
AiQo/Tribe/Galaxy/TribeEmptyState.swift — TribeEmptyState, TribeFeatureCard — Defines TribeEmptyState, TribeFeatureCard.
AiQo/Tribe/Galaxy/TribeHeroCard.swift — TribeHeroCard, TribeInviteCodeCard, TribeStatColumn — Defines TribeHeroCard, TribeInviteCodeCard, TribeStatColumn.
AiQo/Tribe/Galaxy/TribeInviteView.swift — TribeInviteView — UI surface for TribeInviteView.
AiQo/Tribe/Galaxy/TribeLogScreen.swift — TribeLogScreen — UI surface for TribeLogScreen.
AiQo/Tribe/Galaxy/TribeMemberRow.swift — TribeMemberRow — Defines TribeMemberRow.
AiQo/Tribe/Galaxy/TribeMembersList.swift — TribeMembersList — Defines TribeMembersList.
AiQo/Tribe/Galaxy/TribeRingView.swift — TribeRingView — UI surface for TribeRingView.
AiQo/Tribe/Galaxy/TribeTabView.swift — TribeTabView — UI surface for TribeTabView.
AiQo/Tribe/Galaxy/WeeklyChallengeCard.swift — WeeklyChallengeCard — Defines WeeklyChallengeCard.
AiQo/Tribe/Log/TribeLogView.swift — TribeLogView — UI surface for TribeLogView.
AiQo/Tribe/Models/TribeFeatureModels.swift — TribeFeatureFlags, TribeScreenTab, GalaxyLayoutStyle — Model definitions for TribeFeatureModels.
AiQo/Tribe/Models/TribeModels.swift — PrivacyMode, TribeMemberRole, Tribe — Model definitions for TribeModels.
AiQo/Tribe/Preview/TribePreviewController.swift — TribePreviewController, PreviewState — Defines TribePreviewController, PreviewState.
AiQo/Tribe/Preview/TribePreviewData.swift — TribePreviewData — Defines TribePreviewData.
AiQo/Tribe/Repositories/TribeRepositories.swift — TribeRepositorySnapshot, TribeRepositoryProtocol, ChallengeRepositoryProtocol — Defines TribeRepositorySnapshot, TribeRepositoryProtocol, ChallengeRepositoryProtocol.
AiQo/Tribe/Stores/ArenaStore.swift — ArenaLeaderboardEntry, ArenaStore — State and logic for ArenaStore.
AiQo/Tribe/Stores/GalaxyStore.swift — GalaxyStore — State and logic for GalaxyStore.
AiQo/Tribe/Stores/TribeLogStore.swift — TribeLogStore — State and logic for TribeLogStore.
AiQo/Tribe/TribeModuleComponents.swift — TribeAuraPalette, View, TribeScreenBackground — Defines TribeAuraPalette, View, TribeScreenBackground.
AiQo/Tribe/TribeModuleModels.swift — TribeDashboardTab, TribeSectorColor, TribeSummary — Model definitions for TribeModuleModels.
AiQo/Tribe/TribeModuleViewModel.swift — TribeModuleViewModel — UI surface for TribeModuleViewModel.
AiQo/Tribe/TribePulseScreenView.swift — View, TribePulseScreenView, TribePulseHeroCard — UI surface for TribePulseScreenView.
AiQo/Tribe/TribeScreen.swift — TribeScreen — UI surface for TribeScreen.
AiQo/Tribe/TribeStore.swift — TribeStore, StorageKey — State and logic for TribeStore.
AiQo/Tribe/Views/GlobalTribeRadialView.swift — GlobalTribeRadialView, GlassHaloPane, AmbientNebulaView — UI surface for GlobalTribeRadialView.
AiQo/Tribe/Views/TribeAtomRingView.swift — TribeAtomRingView — UI surface for TribeAtomRingView.
AiQo/Tribe/Views/TribeEnergyCoreCard.swift — TribeEnergyCoreCard, TribeGlassPanelStyle, TribeGlassPanel — Defines TribeEnergyCoreCard, TribeGlassPanelStyle, TribeGlassPanel.
AiQo/Tribe/Views/TribeHubScreen.swift — TribeHubSection, TribeHubScreen, TribeMissionsListView — UI surface for TribeHubScreen.
AiQo/Tribe/Views/TribeLeaderboardView.swift — CardColorTheme, LeaderboardEntry, TimeFilter — UI surface for TribeLeaderboardView.
AiQo/UI/AccessibilityHelpers.swift — View, ScaledFontModifier, View — Defines View, ScaledFontModifier, View.
AiQo/UI/AiQoProfileButton.swift — AiQoProfileButtonLayout, AiQoProfileButton, AiQoProfileSheetModifier — Defines AiQoProfileButtonLayout, AiQoProfileButton, AiQoProfileSheetModifier.
AiQo/UI/AiQoScreenHeader.swift — AiQoScreenHeaderMetrics, AiQoScreenTopChrome — Defines AiQoScreenHeaderMetrics, AiQoScreenTopChrome.
AiQo/UI/ErrorToastView.swift — ErrorToastView, ErrorToastModifier, View — UI surface for ErrorToastView.
AiQo/UI/GlassCardView.swift — GlassCardView — UI surface for GlassCardView.
AiQo/UI/LegalView.swift — LegalView, LegalType, LegalLinksView — UI surface for LegalView.
AiQo/UI/OfflineBannerView.swift — OfflineBannerView, OfflineBannerModifier, View — UI surface for OfflineBannerView.
AiQo/UI/Purchases/PaywallView.swift — PaywallView, PaywallPlanModel, PaywallPlanDetails — UI surface for PaywallView.
AiQo/UI/ReferralSettingsRow.swift — ReferralSettingsRow, ShareSheet — Defines ReferralSettingsRow, ShareSheet.
AiQo/XPCalculator.swift — XPCalculator, XPResult — Defines XPCalculator, XPResult.
AiQo/watch/ConnectivityDiagnosticsView.swift — ConnectivityDiagnosticsView, ConnectivityDiagnosticsView_Previews — UI surface for ConnectivityDiagnosticsView.
### AiQoTests
AiQoTests/IngredientAssetCatalogTests.swift — IngredientAssetCatalogTests — Test coverage for IngredientAssetCatalogTests.
AiQoTests/IngredientAssetLibraryTests.swift — IngredientAssetLibraryTests — Test coverage for IngredientAssetLibraryTests.
AiQoTests/PurchasesTests.swift — PurchasesTests — Test coverage for PurchasesTests.
AiQoTests/QuestEvaluatorTests.swift — QuestEvaluatorTests — Test coverage for QuestEvaluatorTests.
AiQoTests/SmartWakeManagerTests.swift — SmartWakeEngineTests — Test coverage for SmartWakeEngineTests.
### AiQoWatch Watch App
AiQoWatch Watch App/ActivityRingsView.swift — ActivityRingsView, ActivityRingsView — UI surface for ActivityRingsView.
AiQoWatch Watch App/AiQoWatchApp.swift — WKApplicationDelegate, WKApplicationDelegateAdaptor, WKHapticType — Defines WKApplicationDelegate, WKApplicationDelegateAdaptor, WKHapticType.
AiQoWatch Watch App/ControlsView.swift — ControlsView, ControlsView_Previews — UI surface for ControlsView.
AiQoWatch Watch App/DebugPrint.swift — (no top-level declaration) — Defines DebugPrint.
AiQoWatch Watch App/Design/WatchDesignSystem.swift — AiQoWatch, Locale, WatchText — Defines AiQoWatch, Locale, WatchText.
AiQoWatch Watch App/ElapsedTimeView.swift — ElapsedTimeView, ElapsedTimeFormatter, ElapsedTime_Previews — UI surface for ElapsedTimeView.
AiQoWatch Watch App/MetricsView.swift — MetricsView, MetricsView_Previews, MetricsTimelineSchedule — UI surface for MetricsView.
AiQoWatch Watch App/Models/WatchWorkoutType.swift — WatchWorkoutType — Defines WatchWorkoutType.
AiQoWatch Watch App/Services/WatchConnectivityService.swift — WatchConnectivityService — State and logic for WatchConnectivityService.
AiQoWatch Watch App/Services/WatchHealthKitManager.swift — WatchHealthKitManager — State and logic for WatchHealthKitManager.
AiQoWatch Watch App/Services/WatchWorkoutManager.swift — WatchWorkoutManager — State and logic for WatchWorkoutManager.
AiQoWatch Watch App/SessionPagingView.swift — SessionPagingView, Tab, HKWorkoutActivityType — UI surface for SessionPagingView.
AiQoWatch Watch App/Shared/WorkoutSyncCodec.swift — (no top-level declaration) — Defines WorkoutSyncCodec.
AiQoWatch Watch App/Shared/WorkoutSyncModels.swift — (no top-level declaration) — Model definitions for WorkoutSyncModels.
AiQoWatch Watch App/StartView.swift — StartView, WatchExercise, AmbientBackground — UI surface for StartView.
AiQoWatch Watch App/SummaryView.swift — SummaryView, SummaryMetricView — UI surface for SummaryView.
AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift — WatchActiveWorkoutView, ActiveMetricCard — UI surface for WatchActiveWorkoutView.
AiQoWatch Watch App/Views/WatchHomeView.swift — WatchHomeView, WatchAuraArcShape, WatchAuraVectorSegment — UI surface for WatchHomeView.
AiQoWatch Watch App/Views/WatchWorkoutListView.swift — WatchWorkoutListView, WatchWorkoutRow — UI surface for WatchWorkoutListView.
AiQoWatch Watch App/Views/WatchWorkoutSummaryView.swift — WatchWorkoutSummaryView, SummaryStatPill — UI surface for WatchWorkoutSummaryView.
AiQoWatch Watch App/WatchConnectivityManager.swift — WatchConnectivityManager, WatchConnectivityManager — State and logic for WatchConnectivityManager.
AiQoWatch Watch App/WorkoutManager.swift — WorkoutManager, Constants, WorkoutManager — State and logic for WorkoutManager.
AiQoWatch Watch App/WorkoutNotificationCenter.swift — WorkoutNotificationCenter — Defines WorkoutNotificationCenter.
AiQoWatch Watch App/WorkoutNotificationController.swift — WKUserNotificationHostingController, WorkoutNotificationController — Defines WKUserNotificationHostingController, WorkoutNotificationController.
AiQoWatch Watch App/WorkoutNotificationView.swift — WorkoutNotificationPayload, Kind, WorkoutNotificationView — UI surface for WorkoutNotificationView.
### AiQoWatch Watch AppTests
AiQoWatch Watch AppTests/AiQoWatch_Watch_AppTests.swift — AiQoWatch_Watch_AppTests — Test coverage for AiQoWatch Watch AppTests.
### AiQoWatch Watch AppUITests
AiQoWatch Watch AppUITests/AiQoWatch_Watch_AppUITests.swift — AiQoWatch_Watch_AppUITests — Test coverage for AiQoWatch Watch AppUITests.
AiQoWatch Watch AppUITests/AiQoWatch_Watch_AppUITestsLaunchTests.swift — AiQoWatch_Watch_AppUITestsLaunchTests — Test coverage for AiQoWatch Watch AppUITestsLaunchTests.
### AiQoWatchWidget
AiQoWatchWidget/AiQoWatchWidget.swift — AiQoWatchWidget, AiQoWeeklyWidget, AiQoWatchWidgetView — Defines AiQoWatchWidget, AiQoWeeklyWidget, AiQoWatchWidgetView.
AiQoWatchWidget/AiQoWatchWidgetBundle.swift — AiQoWatchWidgetBundle — Defines AiQoWatchWidgetBundle.
AiQoWatchWidget/AiQoWatchWidgetProvider.swift — AiQoWatchEntry, AiQoWatchWidgetProvider — Defines AiQoWatchEntry, AiQoWatchWidgetProvider.
### AiQoWidget
AiQoWidget/AiQoEntry.swift — AiQoEntry, AiQoEntry — Defines AiQoEntry, AiQoEntry.
AiQoWidget/AiQoProvider.swift — AiQoProvider — Defines AiQoProvider.
AiQoWidget/AiQoRingsFaceWidget.swift — AiQoRingsFaceWidget, AiQoRingsFaceWidgetView — Defines AiQoRingsFaceWidget, AiQoRingsFaceWidgetView.
AiQoWidget/AiQoSharedStore.swift — AiQoSharedStore — State and logic for AiQoSharedStore.
AiQoWidget/AiQoWatchFaceWidget.swift — AiQoWatchFaceWidget, AiQoWatchFaceWidgetView — Defines AiQoWatchFaceWidget, AiQoWatchFaceWidgetView.
AiQoWidget/AiQoWidget.swift — AiQoWidget, View — Defines AiQoWidget, View.
AiQoWidget/AiQoWidgetBundle.swift — AiQoWidgetBundle — Defines AiQoWidgetBundle.
AiQoWidget/AiQoWidgetLiveActivity.swift — WorkoutActivityAttributes, ContentState, WorkoutPhase — Defines WorkoutActivityAttributes, ContentState, WorkoutPhase.
AiQoWidget/AiQoWidgetView.swift — AiQoWidgetView, WidgetAuraArcShape, WidgetAuraVectorSegment — UI surface for AiQoWidgetView.

## 15. Recommended Next Actions
1. Strip Tribe from the shipping target or gate it with compile-time flags before public rollout. Rough effort: 1-2 days.
2. Decide the real onboarding product and align code to it. Either implement `GoalsAndSleepSetupView` plus the reordered flow or update the product docs to the current `legacy -> featureIntro` sequence. Rough effort: 2-4 days.
3. Add one real remote analytics provider and verify a minimum event set across onboarding, paywall, Captain, kitchen, and watch workout completion. Rough effort: 1-2 days.
4. Verify Firebase Crashlytics linkage end to end and keep `CrashReporter` only as a local supplement. Rough effort: 0.5-1 day.
5. Fix `CaptainMemorySettingsView` so the visible cap comes from the active entitlement tier. Rough effort: under 1 hour.
6. Remove the duplicated XP formula from `PhoneConnectivityManager` and centralize watch awards through `XPCalculator`. Rough effort: under 1 hour.
7. Replace the remaining hardcoded inactivity prompt/fallback strings with the new localization path and move tuning values into configuration. Rough effort: 0.5-1 day.
8. Resolve the Tribe display bugs by removing forced `@` prefixing and sourcing leaderboard XP/level from synced data, not fallback literals. Rough effort: 0.5-1 day.
9. Break up `SupabaseArenaService`, `NotificationService`, `CaptainScreen`, and watch `WorkoutManager` into smaller domain units. Rough effort: 3-5 days.
10. Add targeted tests for `BrainOrchestrator`, `PrivacySanitizer`, `MemoryExtractor`, onboarding routing, and StoreKit entitlement rebuilds. Rough effort: 2-3 days.

---

## 16. Open Questions for Mohammed
1. Is the current two-tier monetization model the final direction, or should the repo return to a three-tier product with a restored middle plan?
2. Should Tribe remain compiled but hidden for the next milestone, or do you want it physically removed from the shipping target until the backend and UI are ready?
3. Do you want the current legacy calculation screen to remain the onboarding level-classification experience, or should it be replaced by the unreleased end-of-flow design discussed recently?
4. Is `CaptainContextBuilder` the intended long-term replacement for the planned Context Assembly layer, or should engineering still implement the named `CaptainContextBundle` / `CaptainPromptComposer` design?
5. Do you want ElevenLabs to stay enabled in production by default, or should Captain voice default to on-device speech unless the user explicitly opts in?
6. Is the Crashlytics wrapper already linked through a local package state outside the checked-in project file, or should the audit treat crash upload as not yet production-ready?
