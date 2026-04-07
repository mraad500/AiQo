# 1. Executive Summary
AiQo is no longer a concept build; it is a large, feature-dense SwiftUI/SwiftData/HealthKit app with a real Captain stack, real watch workout flows, real Supabase auth, and meaningful HealthKit integrations, but it is still not at submission quality. My readiness estimate is approximately 60% for TestFlight and 35% for App Store submission, inferred from the currently shipped blockers in monetization/legal alignment, placeholder or fallback user-visible data, secrets/config handling, notification/language drift, and privacy/compliance packaging. The highest-risk blockers today are user-visible placeholder data in Tribe and Kitchen, mismatched StoreKit/paywall/legal subscription behavior, and hardcoded secrets in app-shipped configuration. `AiQo/Features/Tribe/TribeExperienceFlow.swift:188-208`; `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:120-131`; `AiQo/UI/Purchases/PaywallView.swift:861-927`; `AiQo/Resources/en.lproj/Localizable.strings:49`; `AiQo/Info.plist:66-75`; `Configuration/Secrets.xcconfig:4-16`

Blueprint 7 was not found in the repo, so a literal delta versus Blueprint 7 is not reproducible from source control alone. Against the latest available historical baseline, `AiQo_Master_Blueprint_10.md`, the biggest delta is that Tribe is no longer hidden by plist flags, the three-tier monthly StoreKit test catalog now exists beside the old two-product 30-day config, and the app has moved further into a mixed live-and-preview state instead of a uniformly hidden one. `AiQo_Master_Blueprint_10.md:173`; `AiQo_Master_Blueprint_10.md:446-448`; `AiQo/Info.plist:70-75`; `AiQo/Resources/AiQo_Test.storekit:25-110`; `AiQo/Resources/AiQo.storekit:3-31`

# 2. Project Topology
## Targets
| Target | Type | Notes |
| --- | --- | --- |
| `AiQo` | iOS app | Main app target. `AiQo.xcodeproj/project.pbxproj:390-419` |
| `AiQoTests` | Unit tests | Main unit-test bundle. `AiQo.xcodeproj/project.pbxproj:420-442` |
| `AiQoUITests` | UI tests | Main UI-test bundle. `AiQo.xcodeproj/project.pbxproj:443-465` |
| `AiQoWidgetExtension` | iOS widget extension | Widget / Live Activity surface. `AiQo.xcodeproj/project.pbxproj:466-487` |
| `AiQoWatch Watch App` | watchOS app | Companion workout/watch app. `AiQo.xcodeproj/project.pbxproj:488-511` |
| `AiQoWatch Watch AppTests` | watchOS unit tests | Watch tests. `AiQo.xcodeproj/project.pbxproj:512-534` |
| `AiQoWatch Watch AppUITests` | watchOS UI tests | Watch UI tests. `AiQo.xcodeproj/project.pbxproj:535-557` |
| `AiQoWorkoutLiveAttributesExtension` | app extension | Live activity extension. `AiQo.xcodeproj/project.pbxproj:558-576` |
| `Watch Widget Extension` / `AiQoWatchWidgetExtension` | ExtensionKit extension | Watch widget surface. `AiQo.xcodeproj/project.pbxproj:577-611` |

## Folder Structure Tree (depth 3)
```text
AiQo/
├── App/
├── Core/
│   ├── Localization/
│   ├── Models/
│   ├── Purchases/
│   └── Utilities/
├── DesignSystem/
│   ├── Components/
│   └── Modifiers/
├── Features/
│   ├── Captain/
│   ├── Gym/
│   ├── Kitchen/
│   ├── LegendaryChallenges/
│   ├── MyVibe/
│   ├── Onboarding/
│   ├── Profile/
│   ├── Sleep/
│   ├── Tribe/
│   └── WeeklyReport/
├── Premium/
├── Resources/
│   ├── Assets.xcassets/
│   ├── ar.lproj/
│   └── en.lproj/
├── Services/
│   ├── Analytics/
│   ├── CrashReporting/
│   ├── Notifications/
│   └── Permissions/
├── Shared/
├── Tribe/
│   ├── Arena/
│   ├── Galaxy/
│   ├── Models/
│   ├── Preview/
│   ├── Repositories/
│   ├── Stores/
│   └── Views/
└── UI/
    └── Purchases/
```

## Size Snapshot
- Total Swift files: `421`. Audit corpus count: `449` files / `135728` LOC. Swift-only LOC: `105386`. The 449-file / 135728-LOC total includes the Phase 1 requested corpus plus targeted supporting reads such as `project.pbxproj`, privacy manifests, localized strings, and asset-catalog manifests. `AiQo.xcodeproj/project.pbxproj`; `AiQo/PrivacyInfo.xcprivacy`; `AiQo/Resources/ar.lproj/InfoPlist.strings`; `AiQo/Resources/en.lproj/Localizable.strings`
- Largest 10 Swift files by LOC: `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift` (1422), `AiQo/Services/SupabaseArenaService.swift` (1362), `AiQoWatch Watch App/WorkoutManager.swift` (1344), `AiQo/Features/Profile/ProfileScreenComponents.swift` (1264), `AiQo/Features/Gym/CinematicGrindViews.swift` (1204), `AiQo/Features/Captain/CaptainScreen.swift` (1147), `AiQo/Tribe/TribeModuleComponents.swift` (1146), `AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift` (1043), `AiQo/Features/Tribe/TribeView.swift` (1028), `AiQo/UI/Purchases/PaywallView.swift` (1024). `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift`; `AiQo/Services/SupabaseArenaService.swift`; `AiQoWatch Watch App/WorkoutManager.swift`; `AiQo/Features/Profile/ProfileScreenComponents.swift`; `AiQo/Features/Gym/CinematicGrindViews.swift`; `AiQo/Features/Captain/CaptainScreen.swift`; `AiQo/Tribe/TribeModuleComponents.swift`; `AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift`; `AiQo/Features/Tribe/TribeView.swift`; `AiQo/UI/Purchases/PaywallView.swift`

## Third-Party Dependencies (SPM)
| Package | Version | Evidence |
| --- | --- | --- |
| `SDWebImage` | `5.21.6` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:4-11` |
| `SDWebImageSwiftUI` | `3.1.4` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:13-20` |
| `supabase-swift` | `2.36.0` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:22-29` |
| `swift-asn1` | `1.5.0` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:31-38` |
| `swift-clocks` | `1.0.6` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:40-47` |
| `swift-concurrency-extras` | `1.3.2` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:49-56` |
| `swift-crypto` | `4.2.0` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:58-65` |
| `swift-http-types` | `1.4.0` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:67-74` |
| `swift-system` | `1.6.4` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:76-83` |
| `xctest-dynamic-overlay` | `1.7.0` | `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:85-92` |

# 3. Architecture Map
## Layer Breakdown
| Layer | Primary implementation | Notes |
| --- | --- | --- |
| Views | `AiQo/Features/*`, `AiQo/UI/*`, `AiQoWatch Watch App/Views/*` | Most product surfaces are SwiftUI, with some UIKit holdovers in Gym/Kitchen/Profile. `AiQo/Features/Captain/CaptainScreen.swift`; `AiQo/UI/Purchases/PaywallView.swift`; `AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift` |
| ViewModels | Feature-specific observable objects in `Features/*/ViewModel*` or `*Manager*` | Captain, Tribe, Legendary, Gym, MyVibe, and Home all have dedicated state managers. `AiQo/Features/Captain/CaptainViewModel.swift`; `AiQo/Features/Home/HomeViewModel.swift`; `AiQo/Tribe/TribeModuleViewModel.swift`; `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift` |
| Services | `AiQo/Services/*`, orchestration services under `Core` and `Features` | HealthKit, notifications, Supabase, network, purchase validation, and AI transports live here. `AiQo/Services/SupabaseService.swift`; `AiQo/Services/Notifications/NotificationService.swift`; `AiQo/Core/CaptainVoiceService.swift` |
| Stores | SwiftData / UserDefaults / singleton stores | Captain memory, entitlement state, streaks, levels, and preview data are store-driven. `AiQo/Core/MemoryStore.swift`; `AiQo/Core/Models/LevelStore.swift`; `AiQo/Core/Purchases/EntitlementStore.swift`; `AiQo/Tribe/Stores/ArenaStore.swift` |
| Models | App/domain models under `Core/Models`, `Features/*/Models`, `Tribe/Models` | Data contracts for health summaries, subscriptions, legendary projects, tribe entities, and watch sync. `AiQo/Core/CaptainMemory.swift`; `AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift`; `AiQo/Tribe/Models/TribeModels.swift`; `AiQo/Shared/WorkoutSyncModels.swift` |
| Orchestrators | Routing / coordination singletons | The real orchestration seams are Brain routing, notifications, vibe audio/Spotify, and workout/watch sync. `AiQo/Features/Captain/BrainOrchestrator.swift`; `AiQo/Core/SmartNotificationScheduler.swift`; `AiQo/Features/MyVibe/VibeOrchestrator.swift`; `AiQoWatch Watch App/WorkoutManager.swift` |

## Data Flow Diagram
```text
HealthKit / AlarmKit / Watch sensors
        |
        v
SceneDelegate + HealthKitService + SleepSessionObserver + Shared/HealthKitManager
        |
        v
LevelStore / MemoryStore / UserProfileStore / notification observers / workout sync codecs
        |
        +----------------------------+
        |                            |
        v                            v
HomeViewModel / CaptainViewModel /  LiveWorkoutSession / HRR managers / Kitchen stores
Tribe stores / Legendary managers
        |
        v
SwiftUI views (Home, Captain, Gym, Sleep, Tribe, Kitchen, Watch)
```
Evidence: `AiQo/App/SceneDelegate.swift:103-140`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:45-102`; `AiQo/Features/Sleep/SleepSessionObserver.swift:45-83`; `AiQo/Shared/HealthKitManager.swift:169-212`; `AiQo/Core/MemoryStore.swift`; `AiQo/Features/Home/HomeViewModel.swift`; `AiQo/Features/Captain/CaptainViewModel.swift`; `AiQo/Features/Gym/LiveWorkoutSession.swift`

## `BrainOrchestrator` Ground Truth
The implemented routing rule is extremely simple: only `.sleepAnalysis` is forced local; every other screen context goes cloud. A secondary interception pass rewrites sleep-like chat requests coming from `.mainChat` into `.sleepAnalysis`, and if the local sleep agent is unavailable the orchestrator can fall back to a cloud call that sends an aggregated Arabic sleep summary rather than raw samples. `AiQo/Features/Captain/BrainOrchestrator.swift:83-109`; `AiQo/Features/Captain/BrainOrchestrator.swift:227-260`; `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:212-220`

Source: `AiQo/Features/Captain/BrainOrchestrator.swift:84-90`
```swift
case .sleepAnalysis:
    return .local
case .gym, .kitchen, .peaks, .myVibe, .mainChat:
    return .cloud
```

## `PrivacySanitizer` Ground Truth
What is demonstrably stripped or normalized today:
- Cloud payloads are sanitized before transport, not after. `AiQo/Features/Captain/CloudBrainService.swift:23-37`
- Text redaction runs through regex replacement and then collapses repeated redaction tokens. `AiQo/Features/Captain/PrivacySanitizer.swift:120-138`
- Explicit user-name placeholders are replaced only in Captain replies after generation. `AiQo/Features/Captain/PrivacySanitizer.swift:153-172`
- Kitchen images are re-encoded to JPEG thumbnails to strip EXIF/GPS metadata. `AiQo/Features/Captain/PrivacySanitizer.swift:175-200`
- Conversation history is truncated to a fixed recent suffix, and fully redacted user turns are preserved only as `User request.`. `AiQo/Features/Captain/PrivacySanitizer.swift:236-264`
- Outbound cloud health context is bucketed/generalized: steps are bucketed, calories are bucketed, vibe is flattened to `General`, and level is clamped. The constructor shown in `sanitizeHealthContext` only forwards those generalized fields; it does not forward exact sleep/HR fields in that call path. This is an inference from the constructor call in `AiQo/Features/Captain/PrivacySanitizer.swift:269-275`. `AiQo/Features/Captain/PrivacySanitizer.swift:269-275`
- Cloud-safe Captain memories are limited to `goal`, `preference`, `mood`, `injury`, `nutrition`, and `insight`. `AiQo/Core/MemoryStore.swift:169-196`

Source: `AiQo/Features/Captain/CloudBrainService.swift:27-37`
```swift
let cloudSafeMemories = await MainActor.run {
    MemoryStore.shared.buildCloudSafeContext(maxTokens: 400)
}
let sanitizedRequest = sanitizer.sanitizeForCloud(
```

# 4. Feature Inventory
| Feature | Status | Files involved | Info.plist flag | Known issues | Apple / policy risks |
| --- | --- | --- | --- | --- | --- |
| هندسة النوم / Sleep Architecture | 🟡 Partial | `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift`; `AiQo/Features/Sleep/SleepSessionObserver.swift`; `AiQo/Features/Sleep/SleepDetailCardView.swift`; `AiQo/Features/Captain/BrainOrchestrator.swift` | None found | Local analysis exists, but background observers have no teardown path and sleep-completion notifications ignore `notificationLanguage`. `AiQo/Features/Sleep/SleepSessionObserver.swift:45-83`; `AiQo/Features/Sleep/SleepSessionObserver.swift:99-103` | HealthKit disclosure, background delivery hygiene. `AiQo/Features/Sleep/SleepSessionObserver.swift:45-83`; `AiQo/Resources/ar.lproj/InfoPlist.strings:2-3` |
| الاستيقاظ الذكي / Smart Wake | 🟡 Partial | `AiQo/Features/Sleep/SmartWakeEngine.swift`; `AiQo/Features/Sleep/SmartWakeViewModel.swift`; `AiQo/Services/Notifications/AlarmSchedulingService.swift` | None found | Engine exists, but scheduling depends on AlarmKit-specific implementation and still needs shipping-grade QA around real alarm behavior. `AiQo/Features/Sleep/SmartWakeEngine.swift:67-72`; `AiQo/Services/Notifications/AlarmSchedulingService.swift:93-123` | Alarm/notification entitlement correctness. `AiQo/Info.plist:46-47`; `AiQo/AiQo.entitlements:5-20` |
| مطبخ الكيمياء / Alchemy Kitchen | 🔴 Broken | `AiQo/Features/Kitchen/KitchenView.swift`; `AiQo/Features/Kitchen/MealPlanView.swift`; `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift`; `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift` | None found | Empty or failed vision scans silently return canned fallback fridge items, and plan generation falls back deterministically instead of surfacing an error state. `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:120-131`; `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:258-284`; `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:83-92`; `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:263-320` | User-visible mock/fake data risk, camera/privacy disclosure, AI image upload disclosure. `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:120-131`; `AiQo/Resources/ar.lproj/InfoPlist.strings:1` |
| تدريب زون 2 / Zone 2 Coaching | ✅ Shipped | `AiQo/Features/Gym/LiveWorkoutSession.swift`; `AiQo/Features/Gym/AudioCoachManager.swift`; `AiQo/Features/Gym/HandsFreeZone2Manager.swift`; `AiQo/Core/CaptainVoiceService.swift` | None found | Functionality is real, but it depends on mic/speech permissions and the paywall copy overstates its entitlement mapping. `AiQo/Features/Gym/LiveWorkoutSession.swift:534-584`; `AiQo/UI/Purchases/PaywallView.swift:914-917`; `AiQo/Premium/AccessManager.swift:49-52` | Microphone/speech disclosure, workout coaching claims. `AiQo.xcodeproj/project.pbxproj:1067-1071`; `AiQo/Core/CaptainVoiceService.swift:261-311` |
| النقاط والمستويات / XP & Leveling | ✅ Shipped | `AiQo/Core/Models/LevelStore.swift`; `AiQo/XPCalculator.swift`; `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift`; `AiQo/Features/Home/HomeViewModel.swift` | None found | The leveling system is live, but onboarding copy advertises a different formula than the actual historical sync formula. `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:24-38`; `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:171-197` | Misleading onboarding/product messaging. `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:24-38`; `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:171-197` |
| إمارة / Tribe | 🔴 Broken | `AiQo/Features/Tribe/TribeExperienceFlow.swift`; `AiQo/Tribe/Repositories/TribeRepositories.swift`; `AiQo/Tribe/TribeStore.swift`; `AiQo/Tribe/TribeModuleViewModel.swift`; `AiQo/Services/SupabaseArenaService.swift` | `TRIBE_BACKEND_ENABLED`, `TRIBE_FEATURE_VISIBLE`, `TRIBE_SUBSCRIPTION_GATE_ENABLED` | The visible UX still contains explicit preview/placeholder shells, the module view model still resets compact challenges from `mockData`, and the subscription gate is currently disabled in plist. `AiQo/Features/Tribe/TribeExperienceFlow.swift:188-208`; `AiQo/Tribe/TribeModuleViewModel.swift:54`; `AiQo/Tribe/TribeModuleViewModel.swift:181-183`; `AiQo/Info.plist:70-75`; `AiQo/Premium/AccessManager.swift:191-200` | User-visible preview/mock data, community/moderation expectations, privacy if live social data ships incompletely. `AiQo/Features/Tribe/TribeExperienceFlow.swift:208`; `AiQo/Tribe/Preview/TribePreviewData.swift:4-20`; `AiQo/Tribe/Galaxy/MockArenaData.swift:1-80` |
| التحديات الأسطورية / Legendary Challenges | 🟡 Partial | `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift`; `AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift`; `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift`; `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift` | None found | Static record content is seeded in code, Pro gating is wired, and weekly review sends sanitized payload to Gemini but drops `nextWeekPlanJSON`. `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:10`; `AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift:48-90`; `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:388-394` | AI-generated training advice and health claims need careful copy. `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:306-398` |
| قياس المحرك / HRR Assessment | 🟡 Partial | `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift`; `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift`; `AiQo/Premium/AccessManager.swift` | None found | Watch-linked step test exists, but completion quality depends on watch connectivity/workout termination and lives behind Pro gating only indirectly through Peaks. `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:502-573`; `AiQo/Premium/AccessManager.swift:44-47` | Health/fitness assessment claims. `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:551-573` |
| ماي فايب / My Vibe | 🟡 Partial | `AiQo/Features/MyVibe/VibeOrchestrator.swift`; `AiQo/Features/MyVibe/DailyVibeState.swift`; `AiQo/Features/MyVibe/MyVibeScreen.swift`; `AiQo/Core/SpotifyVibeManager.swift` | None found | The feature is live but still carries terms like `egoDeath`, uses English-only internal mode names, and routes freeform DJ text through Captain without a stricter music-only boundary. `AiQo/Features/MyVibe/DailyVibeState.swift:6-24`; `AiQo/Features/MyVibe/MyVibeScreen.swift:366-376` | Tone/content risk more than policy risk; music integrations still need truthful disclosure. `AiQo/Features/MyVibe/DailyVibeState.swift:17-30`; `AiQo/App/AuthFlowUI.swift:16-20` |
| ذاكرة كابتن حمودي / Captain Hamoudi Memory | ✅ Shipped | `AiQo/Core/CaptainMemory.swift`; `AiQo/Core/MemoryStore.swift`; `AiQo/Premium/AccessManager.swift`; `AiQo/Core/HealthKitMemoryBridge.swift` | None found | Memory persistence exists, but the cap is not a universal 200; it is 200 by default and 500 for Intelligence Pro. `AiQo/Premium/AccessManager.swift:56-63`; `AiQo/Core/MemoryStore.swift:40-74` | Health/privacy disclosure around what leaves device. `AiQo/Core/HealthKitMemoryBridge.swift:21-60`; `AiQo/Core/MemoryStore.swift:169-196` |
| AiQoWatch | 🟡 Partial | `AiQoWatch Watch App/WorkoutManager.swift`; `AiQoWatch Watch App/Services/WatchHealthKitManager.swift`; `AiQoWatch Watch App/Services/WatchConnectivityService.swift`; `AiQoWatch Watch App/Views/*` | None found | Workout flows are substantial, but notification copy is English-only and overall surface area is narrower than the phone app. `AiQoWatch Watch App/WorkoutNotificationCenter.swift:44-46`; `AiQoWatch Watch App/Views/WatchHomeView.swift`; `AiQoWatch Watch App/WorkoutManager.swift` | HealthKit/watch workout policy, watch notification localization quality. `AiQoWatch-Watch-App-Info.plist:5-14`; `AiQoWatch Watch App/WorkoutNotificationCenter.swift:44-46` |
| الإشعارات / Notifications | 🟡 Partial | `AiQo/Core/SmartNotificationScheduler.swift`; `AiQo/Services/Notifications/NotificationService.swift`; `AiQo/Services/Notifications/MorningHabitOrchestrator.swift`; `AiQo/Services/Notifications/PremiumExpiryNotifier.swift` | None found | Quiet hours and cooldowns exist, but language handling is inconsistent and several background observers never tear down. `AiQo/Core/SmartNotificationScheduler.swift:185-221`; `AiQo/Features/Sleep/SleepSessionObserver.swift:99-103`; `AiQo/Services/Notifications/NotificationService.swift:357-399` | Notification relevance, language consistency, background-processing hygiene. `AiQo/Core/SmartNotificationScheduler.swift:10-13`; `AiQo/Services/Notifications/NotificationService.swift:143-161` |
| الإعداد الأولي / Onboarding | 🟡 Partial | `AiQo/App/LanguageSelectionView.swift`; `AiQo/App/ProfileSetupView.swift`; `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift`; `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift` | None found | The onboarding experience exists, but its XP explanation diverges from the real scoring code. `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:24-38`; `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:171-197` | Truth-in-marketing / misleading onboarding copy. `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:171-197` |
| الدفع / Paywall | 🔴 Broken | `AiQo/UI/Purchases/PaywallView.swift`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift`; `AiQo/Resources/AiQo_Test.storekit`; `AiQo/Resources/AiQo.storekit`; `AiQo/Resources/en.lproj/Localizable.strings` | None found | Three-tier UI exists, but naming, entitlement mapping, legal copy, and legacy StoreKit config are all out of sync. `AiQo/UI/Purchases/PaywallView.swift:861-927`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:84-95`; `AiQo/Resources/AiQo_Test.storekit:25-110`; `AiQo/Resources/AiQo.storekit:3-31`; `AiQo/Resources/en.lproj/Localizable.strings:49` | StoreKit/App Review subscription disclosure risk. `AiQo/UI/Purchases/PaywallView.swift:693-712`; `AiQo/Resources/ar.lproj/Localizable.strings:49` |

## Implementation Proof Excerpts
### Sleep Architecture
Source: `AiQo/Features/Sleep/SleepSessionObserver.swift:52-55`
```swift
try await healthStore.enableBackgroundDelivery(
    for: sleepType,
    frequency: .immediate
)
```

### Smart Wake
Source: `AiQo/Features/Sleep/SmartWakeEngine.swift:67-72`
```swift
static let `default` = Configuration(
    cycleLength: 90 * 60,
    sleepOnsetDelay: 14 * 60,
    priorityCycles: [6, 5, 4],
```

### Alchemy Kitchen
Source: `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:123-130`
```swift
guard !items.isEmpty else {
    logger.warning("Vision API returned empty items, using fallback")
    return fallbackItems()
}
```

### Zone 2 Coaching
Source: `AiQo/Features/Gym/AudioCoachManager.swift:72-77`
```swift
Task { @MainActor in
    await CaptainVoiceService.shared.generateAndSpeakWorkoutPrompt(
        liveHR: bpm,
        zoneBounds: zoneBounds,
```

### XP & Leveling
Source: `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:34-38`
```swift
let stepPoints = steps / 200
let caloriePoints = activeCalories / 25
let distancePoints = Int(distanceKm * 10)
let sleepPoints = Int(sleepHours) * 5
```

### Tribe
Source: `AiQo/Features/Tribe/TribeExperienceFlow.swift:188-191`
```swift
// STUB: Live Supabase backend not yet connected.
// This feature is hidden via TRIBE_FEATURE_VISIBLE=false in Info.plist.
// TODO before launch: replace with live SupabaseTribeRepository call.
futurePlaceholders
```

### Legendary Challenges
Source: `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:10-11`
```swift
@Published var records: [LegendaryRecord] = LegendaryRecord.seedRecords
@Published var activeProject: LegendaryProject?
```

### HRR
Source: `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:551-557`
```swift
isCreatingProject = true
let level = hrrManager.calculateRecoveryLevel()
Task {
    let planJSON = RecordProjectManager.generateDefaultPlan(
```

### My Vibe
Source: `AiQo/Features/MyVibe/VibeOrchestrator.swift:45-52`
```swift
var profile = vibeEngine.currentProfile
let dayPart = VibeDayPart.current()
profile.set(state.vibeMode, for: dayPart)
vibeEngine.start(profile: profile, mixWithOthers: mixWithOthers)
```

### Captain Memory
Source: `AiQo/Core/MemoryStore.swift:58-64`
```swift
let count = (try? context.fetchCount(countDescriptor)) ?? 0
if count >= maxMemories {
    removeLowestConfidence()
}
let memory = CaptainMemory(
```

### AiQoWatch
Source: `AiQoWatch Watch App/WorkoutManager.swift:211-214`
```swift
do {
    let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
    let newBuilder = newSession.associatedWorkoutBuilder()
```

### Notifications
Source: `AiQo/Core/SmartNotificationScheduler.swift:193-199`
```swift
let hour = calendar.component(.hour, from: date)
return hour >= Self.quietHoursStartHour || hour < Self.quietHoursEndHour
```

### Onboarding
Source: `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:177-187`
```swift
icon: "figure.walk",
iconColor: Color(hex: "2AA88E"),
points: isArabic ? "١ نقطة" : "1 pt",
description: isArabic ? "كل ١٠٠ خطوة" : "Every 100 steps"
```

### Paywall
Source: `AiQo/UI/Purchases/PaywallView.swift:907-917`
```swift
title: "AiQo Intelligence Pro",
PaywallFeature(icon: "brain.head.profile", text: copy(ar: "Full Captain Hamoudi memory لذاكرة شخصية ممتدة", en: "Full Captain Hamoudi memory for a richer personal context")),
PaywallFeature(icon: "figure.run", text: copy(ar: "Zone 2 live coaching أثناء التدريب اللحظي", en: "Zone 2 live coaching during active sessions")),
PaywallFeature(icon: "crown.fill", text: copy(ar: "Legendary Challenges للوصول إلى المستوى الأسطوري", en: "Legendary Challenges for next-level progression")),
```

# 5. Captain Hamoudi System
## Six-Layer Prompt Architecture
| Layer | What it does in code today | Actual implementation |
| --- | --- | --- |
| 1. Identity | Sets Captain persona and hard language lock. | `layerIdentity` inside `CaptainPromptBuilder.build(for:)`. `AiQo/Features/Captain/CaptainPromptBuilder.swift:13-25`; `AiQo/Features/Captain/CaptainPromptBuilder.swift:28-40` |
| 2. Memory | Injects prior profile/memory summary when non-empty. | `AiQo/Features/Captain/CaptainPromptBuilder.swift:137-146` |
| 3. Bio-state | Injects internal masked metrics such as steps/calories/level/sleep/HR for calibration only. | `AiQo/Features/Captain/CaptainPromptBuilder.swift:149-188` |
| 4. Circadian tone | Applies time-of-day tone directives without exposing phase names. | `AiQo/Features/Captain/CaptainPromptBuilder.swift:190-205` |
| 5. Screen context | Changes behavior based on active screen; Kitchen adds photo-specific guidance when an image is attached. | `AiQo/Features/Captain/CaptainPromptBuilder.swift:208-223` |
| 6. Output contract | Forces JSON-only output and screen-specific nullability rules. | `AiQo/Features/Captain/CaptainPromptBuilder.swift:274-327` |

Source: `AiQo/Features/Captain/CaptainPromptBuilder.swift:16-23`
```swift
return [
    layerIdentity(language: request.language, firstName: firstName),
    layerMemory(profileSummary: request.userProfileSummary),
    layerBioState(data: request.contextData, language: request.language),
```

## Voice Pipeline
Current voice transport is ElevenLabs-oriented. `CaptainVoiceAPI` defaults to `https://api.elevenlabs.io/v1/text-to-speech` with model `eleven_multilingual_v2`, `CaptainVoiceService` tries cached or remote audio first, then falls back to `AVSpeechSynthesizer`, and the workout voice path can generate a one-line on-device coaching cue before speaking it. I did not find any Fish Speech implementation or migration scaffolding in the repo; the migration path is therefore “not started in codebase,” not “partially integrated.” `AiQo/Core/CaptainVoiceAPI.swift:4-10`; `AiQo/Core/CaptainVoiceAPI.swift:68-120`; `AiQo/Core/CaptainVoiceService.swift:37-58`; `AiQo/Core/CaptainVoiceService.swift:201-235`; `AiQo/Core/CaptainVoiceService.swift:261-311`

Source: `AiQo/Core/CaptainVoiceService.swift:48-54`
```swift
if await playRemoteSpeechIfAvailable(for: sanitizedText, sequence: speechSequence) {
    return
}
guard speechSequence == activeSpeechSequence else { return }
```

## Memory Store
`CaptainMemory` is a real SwiftData model, and cap enforcement is real, but the cap is not a universal 200-entry ceiling. The tier gate returns `500` for Intelligence Pro and `200` for every other tier, while chat-history persistence is separately trimmed to 200 persisted messages. `AiQo/Core/CaptainMemory.swift:4-41`; `AiQo/Premium/AccessManager.swift:56-63`; `AiQo/Core/MemoryStore.swift:40-74`; `AiQo/Core/MemoryStore.swift:275-289`; `AiQo/Core/MemoryStore.swift:411-430`

Source: `AiQo/Premium/AccessManager.swift:56-62`
```swift
switch activeTier {
case .intelligencePro:
    return 500
default:
    return 200
```

## Health-to-Memory Bridge
HealthKit-derived memory writes are local and concrete: body mass, resting heart rate, 7-day average steps, 7-day active calories, and 7-day sleep average are written into `MemoryStore`. Cloud-safe memory export later excludes `body` and `sleep` categories. `AiQo/Core/HealthKitMemoryBridge.swift:21-60`; `AiQo/Core/MemoryStore.swift:169-196`

## Language Switching Logic
The requested `captainLanguage` setting does not exist in the codebase. The implemented setting is `notificationLanguage`, backed by `@AppStorage("notificationLanguage")`, mirrored into `NotificationPreferencesStore`, and consumed by `SmartNotificationScheduler` / `NotificationService`. Not all notification copy respects it: sleep completion uses `appLanguage`, the notification action title is English-only, and some Captain prompt text remains Iraqi-Arabic-only. `AiQo/Core/AppSettingsScreen.swift:12`; `AiQo/Core/AppSettingsScreen.swift:61-67`; `AiQo/Core/AppSettingsScreen.swift:318-323`; `AiQo/Core/SmartNotificationScheduler.swift:52`; `AiQo/Core/SmartNotificationScheduler.swift:490-513`; `AiQo/Services/Notifications/NotificationService.swift:143-148`; `AiQo/Services/Notifications/NotificationService.swift:971-978`; `AiQo/Features/Sleep/SleepSessionObserver.swift:99-103`

Additional tone debt still present:
- `CaptainOnDeviceChatEngine` still defines Captain as a “spiritual + tactical guide.” `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:106-110`
- Debug settings still expose “Trigger Test Spiritual Whisper”. `AiQo/Core/AppSettingsScreen.swift:246-250`; `AiQo/Core/AppSettingsScreen.swift:389-404`

# 6. Monetization & StoreKit 2
## Current `.storekit` Files
| File | Contents | Audit call |
| --- | --- | --- |
| `AiQo/Resources/AiQo_Test.storekit` | Three auto-renewing monthly tiers: Core `$9.99`, Pro `$19.99`, Intelligence `$39.99`, each with a 1-week free introductory offer. `AiQo/Resources/AiQo_Test.storekit:25-110` | This is the only file that matches the current three-tier direction. |
| `AiQo/Resources/AiQo.storekit` | Two legacy non-renewing 30-day products: `aiqo_nr_30d_individual_5_99` and `aiqo_nr_30d_family_10_00`. `AiQo/Resources/AiQo.storekit:3-31` | This file is stale and materially conflicts with the live paywall/product model. |

## Product / Tier Snapshot
| Tier | Product ID | StoreKit display | Price | Intro offer | Evidence |
| --- | --- | --- | --- | --- | --- |
| Core | `com.mraad500.aiqo.standard.monthly` | `AiQo Core` | `9.99` | 1 week free | `AiQo/Resources/AiQo_Test.storekit:25-47`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:6`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:84-88` |
| Pro | `com.mraad500.aiqo.pro.monthly` | `AiQo Pro` | `19.99` | 1 week free | `AiQo/Resources/AiQo_Test.storekit:56-79`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:7`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:88-89` |
| Intelligence | `com.mraad500.aiqo.intelligencepro.monthly` | `AiQo Intelligence` | `39.99` | 1 week free | `AiQo/Resources/AiQo_Test.storekit:87-110`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:8`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:90-91` |

## Does `PaywallView.swift` Match Core / Pro / Intelligence?
No. The three cards exist, but the implementation is still out of alignment with the actual product and entitlement ground truth.

Gaps:
- Naming mismatch: paywall title is `AiQo Intelligence Pro`, while StoreKit and `SubscriptionProductIDs` resolve the product as `AiQo Intelligence`. `AiQo/UI/Purchases/PaywallView.swift:905-919`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:84-95`; `AiQo/Resources/AiQo_Test.storekit:98-107`
- Core copy is too narrow: the entitlement layer grants Captain, Gym, Kitchen, MyVibe, Challenges, Data Tracking, and Captain notifications at Core, but the paywall card only advertises basic health tracking, standard gym quests, and a simple dashboard. `AiQo/Premium/AccessManager.swift:34-40`; `AiQo/UI/Purchases/PaywallView.swift:861-882`
- Pro copy is mismatched: the paywall advertises Kitchen Vision, deeper biometrics, and sleep architecture, but the entitlement gate actually unlocks Peaks, HRR assessment, weekly AI workout plans, and record projects. `AiQo/UI/Purchases/PaywallView.swift:883-904`; `AiQo/Premium/AccessManager.swift:44-47`
- Intelligence copy is overstated: the paywall advertises Zone 2 live coaching and Legendary Challenges, but the entitlement layer only explicitly gates extended memory and the intelligence model. `AiQo/UI/Purchases/PaywallView.swift:905-927`; `AiQo/Premium/AccessManager.swift:49-52`
- Tribe is effectively ungated at runtime because `TRIBE_SUBSCRIPTION_GATE_ENABLED` is `false`, and `AccessManager` rewrites the snapshot to Intelligence Pro access. `AiQo/Info.plist:74-75`; `AiQo/Premium/AccessManager.swift:191-200`
- Legal copy is stale and still describes `$5.99` / `$10.00` 30-day non-auto-renewing plans. `AiQo/Resources/en.lproj/Localizable.strings:49`; `AiQo/Resources/ar.lproj/Localizable.strings:49`

## Entitlement Gating Matrix
| Gate | Actual condition | Evidence |
| --- | --- | --- |
| Captain | `activeTier >= .core` | `AiQo/Premium/AccessManager.swift:34` |
| Gym | `activeTier >= .core` | `AiQo/Premium/AccessManager.swift:35` |
| Kitchen | `activeTier >= .core` | `AiQo/Premium/AccessManager.swift:36` |
| My Vibe | `activeTier >= .core` | `AiQo/Premium/AccessManager.swift:37` |
| Challenges | `activeTier >= .core` | `AiQo/Premium/AccessManager.swift:38` |
| Data tracking | `activeTier >= .core` | `AiQo/Premium/AccessManager.swift:39` |
| Captain notifications | `activeTier >= .core` | `AiQo/Premium/AccessManager.swift:40` |
| Peaks / legendary section visibility | `activeTier >= .pro` via `canAccessPeaks` | `AiQo/Premium/AccessManager.swift:44`; `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift:23-38` |
| HRR assessment | `activeTier >= .pro` | `AiQo/Premium/AccessManager.swift:45` |
| Weekly AI workout plan | `activeTier >= .pro` | `AiQo/Premium/AccessManager.swift:46` |
| Record projects | `activeTier >= .pro` | `AiQo/Premium/AccessManager.swift:47` |
| Extended Captain memory | `activeTier >= .intelligencePro` | `AiQo/Premium/AccessManager.swift:51` |
| Intelligence model | `activeTier >= .intelligencePro` | `AiQo/Premium/AccessManager.swift:52` |
| Tribe creation | Derived from active product in `EntitlementStore`, but effectively bypassed when `TRIBE_SUBSCRIPTION_GATE_ENABLED == false` | `AiQo/Core/Purchases/EntitlementStore.swift:32-34`; `AiQo/Premium/AccessManager.swift:191-200` |

## Free Trial Status
Free trial logic exists in two places: StoreKit introductory offers in `AiQo_Test.storekit` and a separate app-side `FreeTrialManager` that can make `activeTier` resolve to `.intelligencePro` while a local trial flag is active. That duplication is functional but risky because it creates two independent trial authorities. `AiQo/Resources/AiQo_Test.storekit:29-35`; `AiQo/Resources/AiQo_Test.storekit:60-66`; `AiQo/Resources/AiQo_Test.storekit:91-97`; `AiQo/Premium/FreeTrialManager.swift`; `AiQo/Premium/AccessManager.swift:27-29`

## Apple Guideline Check
- Restore purchases button: ✅ Present. `AiQo/UI/Purchases/PaywallView.swift:693-700`
- Terms link: ✅ Present. `AiQo/UI/Purchases/PaywallView.swift:705-707`
- Privacy link: ✅ Present. `AiQo/UI/Purchases/PaywallView.swift:711-712`
- Manage subscriptions deep link: ❌ Not found in `PaywallView` or `LegalView`. `AiQo/UI/Purchases/PaywallView.swift`; `AiQo/UI/LegalView.swift`
- Misleading copy: ❌ Current legal text and tier descriptions do not match product reality. `AiQo/UI/Purchases/PaywallView.swift:861-927`; `AiQo/Resources/en.lproj/Localizable.strings:49`; `AiQo/Resources/ar.lproj/Localizable.strings:49`

Source: `AiQo/UI/Purchases/PaywallView.swift:693-707`
```swift
footerTextButton(
    title: isRestoringPurchases ? copy(ar: "جارٍ الاستعادة…", en: "Restoring...") : copy(ar: "استعادة المشتريات", en: "Restore Purchases")
) {
    restorePurchases()
}
```

# 7. HealthKit & Privacy Compliance
## Usage Description Strings
The app’s HealthKit strings are present in both Arabic and English. Arabic-localized strings are present for `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`. `AiQo/Resources/ar.lproj/InfoPlist.strings:2-3`; `AiQo/Resources/en.lproj/InfoPlist.strings:2-3`; `AiQo.xcodeproj/project.pbxproj:1063-1064`; `AiQo.xcodeproj/project.pbxproj:1131-1132`

Arabic strings:
- `NSHealthShareUsageDescription`: `يقرأ AiQo بيانات صحية مختارة مثل الخطوات والنوم والماء لتجهيز ملخصاتك اليومية والأسبوعية.` `AiQo/Resources/ar.lproj/InfoPlist.strings:2`
- `NSHealthUpdateUsageDescription`: `يكتب AiQo الإدخالات الصحية التي تختارها، مثل تسجيل شرب الماء والتمارين، داخل تطبيق الصحة.` `AiQo/Resources/ar.lproj/InfoPlist.strings:3`

## Every `HKObjectType` Requested
| Type | Read / write | Where requested | Notes |
| --- | --- | --- | --- |
| `stepCount` | Read | `SceneDelegate`, `HealthKitService`, watch manager | `AiQo/App/SceneDelegate.swift:108-125`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:45-55`; `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:15-23` |
| `activeEnergyBurned` | Read | `SceneDelegate`, `HealthKitService`, watch manager | `AiQo/App/SceneDelegate.swift:109-125`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:45-55`; `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:15-23` |
| `distanceWalkingRunning` | Read + write | `SceneDelegate`, `HealthKitService`, watch manager | `AiQo/App/SceneDelegate.swift:111-135`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:52`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:94-96`; `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:19-24` |
| `distanceCycling` | Read | `SceneDelegate` | `AiQo/App/SceneDelegate.swift:112` |
| `heartRate` | Read + write | `SceneDelegate`, `HealthKitService`, watch manager | `AiQo/App/SceneDelegate.swift:113`; `AiQo/App/SceneDelegate.swift:128`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:47`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:82-84`; `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:20` |
| `heartRateVariabilitySDNN` | Read + write | `SceneDelegate`, `HealthKitService` | `AiQo/App/SceneDelegate.swift:114`; `AiQo/App/SceneDelegate.swift:129`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:49`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:88-90` |
| `restingHeartRate` | Read + write | `SceneDelegate`, `HealthKitService` | `AiQo/App/SceneDelegate.swift:115`; `AiQo/App/SceneDelegate.swift:130`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:48`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:85-87` |
| `walkingHeartRateAverage` | Read | `SceneDelegate`, `HealthKitService` | `AiQo/App/SceneDelegate.swift:116`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:50` |
| `oxygenSaturation` | Read | `SceneDelegate` | `AiQo/App/SceneDelegate.swift:117` |
| `vo2Max` | Read + write | `SceneDelegate`, `HealthKitService` | `AiQo/App/SceneDelegate.swift:118`; `AiQo/App/SceneDelegate.swift:131`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:54`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:91-93` |
| `bodyMass` | Read + write | `SceneDelegate` | `AiQo/App/SceneDelegate.swift:119`; `AiQo/App/SceneDelegate.swift:134` |
| `dietaryWater` | Read + write | `SceneDelegate`, `HealthKitService` | `AiQo/App/SceneDelegate.swift:120`; `AiQo/App/SceneDelegate.swift:133`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:53`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:79-81` |
| `appleStandTime` | Read | `SceneDelegate` | `AiQo/App/SceneDelegate.swift:121` |
| `appleStandHour` | Read | `HealthKitService` | `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:57-60` |
| `sleepAnalysis` | Read | `SceneDelegate`, `HealthKitService`, watch manager | `AiQo/App/SceneDelegate.swift:122`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:57-60`; `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:21` |
| `activitySummaryType()` | Read | `SceneDelegate` | `AiQo/App/SceneDelegate.swift:123` |
| `workoutType()` | Read + write | `SceneDelegate`, `HealthKitService`, watch manager | `AiQo/App/SceneDelegate.swift:124-135`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:74`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:99`; `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:22-24` |

## Localization Verification
- `NSHealthShareUsageDescription`: ✅ Present and Arabic-localized. `AiQo/Resources/ar.lproj/InfoPlist.strings:2`
- `NSHealthUpdateUsageDescription`: ✅ Present and Arabic-localized. `AiQo/Resources/ar.lproj/InfoPlist.strings:3`
- `NSAlarmKitUsageDescription`: present inline in `Info.plist`, but I did not find a separate localized `InfoPlist.strings` entry for it. `AiQo/Info.plist:46-47`; `AiQo/Resources/ar.lproj/InfoPlist.strings:1-3`

## Cloud / Gemini Data-Flow Audit
### Captain cloud path
I did not find any code that serializes raw `HKSample`, `HKQuantitySample`, or other raw HealthKit objects into the Captain cloud transport. The cloud path goes through `CloudBrainService`, which first builds a cloud-safe memory context and then calls `PrivacySanitizer.sanitizeForCloud(...)`. The sanitizer truncates conversation, generalizes health context, and the memory export only includes the safe categories `goal`, `preference`, `mood`, `injury`, `nutrition`, and `insight`. `AiQo/Features/Captain/CloudBrainService.swift:23-37`; `AiQo/Features/Captain/PrivacySanitizer.swift:236-275`; `AiQo/Core/MemoryStore.swift:169-196`

Source: `AiQo/Features/Captain/CloudBrainService.swift:27-35`
```swift
let cloudSafeMemories = await MainActor.run {
    MemoryStore.shared.buildCloudSafeContext(maxTokens: 400)
}
let sanitizedRequest = sanitizer.sanitizeForCloud(
```

### What can still leave the device
- Aggregated sleep summaries can be sent to cloud fallback when the local sleep agent is unavailable. `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:212-220`; `AiQo/Features/Captain/BrainOrchestrator.swift:227-260`
- Memory extraction sends sanitized user text to Gemini. `AiQo/Core/MemoryExtractor.swift:300-317`
- Weekly legendary review sends a sanitized weekly-fitness payload to Gemini. `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:306-398`
- Kitchen vision sends a fridge image to Gemini and falls back to canned results on failure. `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:120-131`; `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:171`; `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:258-284`

App Review read: no raw HealthKit samples are obviously sent to Gemini in the Captain path, but derived health advice and sanitized user-health review data are sent to external AI services, so the privacy narrative and App Store disclosure still need tightening. `AiQo/Features/Captain/CloudBrainService.swift:23-37`; `AiQo/Core/MemoryExtractor.swift:300-317`; `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:306-398`

## Background Delivery / Observer Queries / Teardown
| Component | Active subscription / query | Evidence | Teardown found? |
| --- | --- | --- | --- |
| Sleep observer | Sleep background delivery + `HKObserverQuery` + anchored sleep query | `AiQo/Features/Sleep/SleepSessionObserver.swift:45-83`; `AiQo/Features/Sleep/SleepSessionObserver.swift:110-132` | No explicit teardown found in this file. |
| Captain workout notifications | Workout background delivery | `AiQo/Services/Notifications/NotificationService.swift:944-952` | No explicit teardown found. |
| Morning habit orchestrator | Step background delivery + observer query | `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:155-191` | No explicit teardown found. |
| Shared HealthKit manager | Step observer query + hourly background delivery | `AiQo/Shared/HealthKitManager.swift:169-212` | No explicit teardown found. |
| Watch workout | Live `HKWorkoutSession` + builder + sync timers | `AiQoWatch Watch App/WorkoutManager.swift:29-80`; `AiQoWatch Watch App/WorkoutManager.swift:211-220` | Lifecycle management exists, but it is workout-session-specific rather than observer teardown. |

# 8. Supabase & Backend
## Tables Used (inferred from queries)
| Table | Evidence |
| --- | --- |
| `profiles` | `AiQo/Services/SupabaseService.swift:58-63`; `AiQo/Services/SupabaseService.swift:91-105` |
| `arena_tribes` | `AiQo/Services/SupabaseArenaService.swift` query sites for tribe create/fetch/update. |
| `arena_tribe_members` | `AiQo/Services/SupabaseArenaService.swift` membership query paths. |
| `arena_tribe_participations` | `AiQo/Services/SupabaseArenaService.swift` participation query paths. |
| `arena_weekly_challenges` | `AiQo/Services/SupabaseArenaService.swift` weekly-challenge fetch/sync paths. |
| `arena_hall_of_fame_entries` | `AiQo/Services/SupabaseArenaService.swift` hall-of-fame fetch/sync paths. |

## Edge Functions Called
- `validate-receipt` at `https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/validate-receipt`. `AiQo/Core/Purchases/ReceiptValidator.swift:9-10`
- A generic `.functions.supabase.co` helper exists in `Constants`, but receipt validation does not use it. `AiQo/Core/Constants.swift:32-43`; `AiQo/Core/Purchases/ReceiptValidator.swift:9-10`
- No Supabase Edge Function source files were found in the repo. No `supabase/functions/*` source-of-record implementation is checked in. `AiQo/Core/Purchases/ReceiptValidator.swift:9-10`; methodology inventory

## Auth Flow
Apple Sign In is wired directly into Supabase auth via `signInWithIdToken(provider: .apple, idToken: nonce:)`. `AiQo/App/LoginViewController.swift:123-148`

Source: `AiQo/App/LoginViewController.swift:139-143`
```swift
_ = try await SupabaseService.shared.client.auth.signInWithIdToken(
    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
)
```

## Backend Feature Flags
- `TRIBE_BACKEND_ENABLED = true` `AiQo/Info.plist:70-71`
- `TRIBE_FEATURE_VISIBLE = true` `AiQo/Info.plist:72-73`
- `TRIBE_SUBSCRIPTION_GATE_ENABLED = false` `AiQo/Info.plist:74-75`
- `TribeFeatureFlags` reads those keys from `Info.plist`. `AiQo/Tribe/Models/TribeFeatureModels.swift:3-36`

## Offline Behavior / Network Failure
The app has a real connectivity monitor and an offline banner, and many backend services catch/rethrow network errors into `AiQoError`, but I did not find a durable offline queue or deferred mutation layer for Supabase-backed actions. `AiQo/Services/NetworkMonitor.swift:5-49`; `AiQo/UI/OfflineBannerView.swift:3-42`; `AiQo/Services/AiQoError.swift:100-115`; `AiQo/Services/SupabaseArenaService.swift`; `AiQo/Services/SupabaseService.swift`

# 9. Notifications
## Categories / Identifiers
| Area | Identifier(s) | Evidence |
| --- | --- | --- |
| Background tasks | `aiqo.notifications.refresh`, `aiqo.notifications.inactivity-check` | `AiQo/Core/SmartNotificationScheduler.swift:10-13` |
| Captain smart notifications | Category `aiqo.captain.smart` | `AiQo/Services/Notifications/NotificationService.swift:143-156` |
| Morning habit | `aiqo.morningHabit.notification` | `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:20-22` |
| Water reminders | `water_reminder_<hour>` / `water_reminder` | `AiQo/Core/SmartNotificationScheduler.swift:272-281` |
| Workout motivation | `workout_motivation_daily` / `workout_motivation` | `AiQo/Core/SmartNotificationScheduler.swift:299-307` |
| Sleep reminder | `sleep_reminder_nightly` / `sleep_reminder` | `AiQo/Core/SmartNotificationScheduler.swift:310-321` |
| Streak protection | `streak_protection_evening` / `streak_protection` | `AiQo/Core/SmartNotificationScheduler.swift:324-336` |
| Weekly report | `weekly_report_friday` / `weekly_report` | `AiQo/Core/SmartNotificationScheduler.swift:339-351` |
| Premium expiry | `aiqo.premium.expiry.twoDays`, `aiqo.premium.expiry.oneDay`, `aiqo.premium.expiry.expired` | `AiQo/Services/Notifications/PremiumExpiryNotifier.swift:11-20` |
| Watch live / milestone / summary | `AIQO_WORKOUT_LIVE`, `AIQO_WORKOUT_MILESTONE`, `AIQO_WORKOUT_SUMMARY` | `AiQoWatch Watch App/WorkoutNotificationCenter.swift:4-8` |

## Quiet Hours
Quiet hours are implemented as `23:00` to `07:00` and enforced centrally by `SmartNotificationScheduler.isWithinQuietHours` and `nextAllowedDate`. `AiQo/Core/SmartNotificationScheduler.swift:12-13`; `AiQo/Core/SmartNotificationScheduler.swift:185-221`

## Language Consistency
Notification language handling is mixed.
- Good: coach nudge scheduling does respect `notificationLanguage`. `AiQo/Core/SmartNotificationScheduler.swift:52`; `AiQo/Core/SmartNotificationScheduler.swift:490-513`; `AiQo/Services/Notifications/NotificationService.swift:971-978`
- Bad: sleep completion composes language from `appLanguage`, not `notificationLanguage`. `AiQo/Features/Sleep/SleepSessionObserver.swift:99-103`
- Bad: notification action title `Open Captain` is English-only. `AiQo/Services/Notifications/NotificationService.swift:145-148`
- Bad: watch workout notification titles/bodies are English-only. `AiQoWatch Watch App/WorkoutNotificationCenter.swift:44-46`; `AiQoWatch Watch App/WorkoutNotificationCenter.swift:78-79`

## Cooldowns
| Notification | Cooldown | Evidence |
| --- | --- | --- |
| Developer test coach nudge | 5 seconds | `AiQo/Core/SmartNotificationScheduler.swift:57` |
| Background inactivity check | 3 hours | `AiQo/Core/SmartNotificationScheduler.swift:58-60` |
| Captain inactivity nudge | 45 minutes | `AiQo/Services/Notifications/NotificationService.swift:159-160`; `AiQo/Services/Notifications/NotificationService.swift:389-394` |
| Water reminder | 2 hours | `AiQo/Services/Notifications/NotificationService.swift:362-369` |
| Meal reminder | 4 hours | `AiQo/Services/Notifications/NotificationService.swift:363-376` |
| Step-goal milestone | 1 hour per milestone key | `AiQo/Services/Notifications/NotificationService.swift:364-381` |
| Sleep reminder | 20 hours | `AiQo/Services/Notifications/NotificationService.swift:365-386` |

## Angel-Number / Spiritual Content Audit
- Angel-number / numerology content: not found in codebase.
- Spiritual wording: still present. `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:106-110`; `AiQo/Core/AppSettingsScreen.swift:246-250`

# 10. Design System Audit
## Color Tokens
The requested mint/sand palette is not centralized in a single source of truth. There are at least three competing token surfaces:
- `AiQoColors` defines `#CDF4E4` and `#F5D5A6`, which do not match the requested `#B7E5D2` / `#EBCF97`. `AiQo/DesignSystem/AiQoColors.swift:3-5`
- Legacy UIKit `Colors` defines older mint/sand values `#C4F0DB` and `#F8D6A3`. `AiQo/Core/Colors.swift:12-17`
- `AiQoTheme.Colors.accent` and CTA gradients use `#5ECDB7` and related values. `AiQo/DesignSystem/AiQoTheme.swift:11-16`

Where the requested launch palette is actually hardcoded today:
- `#B7E5D2` and `#EBCF97` in Tribe surfaces and auth flow. `AiQo/Features/Tribe/TribeView.swift:35-40`; `AiQo/Tribe/Views/TribeLeaderboardView.swift:21-27`; `AiQo/App/AuthFlowUI.swift:6-11`
- `#5ECDB7` in theme and paywall. `AiQo/DesignSystem/AiQoTheme.swift:11`; `AiQo/UI/Purchases/PaywallView.swift:683`; `AiQo/UI/Purchases/PaywallView.swift:899-900`

Hardcoded hex values outside token files worth cleaning first:
- `AiQo/Features/ProgressPhotos/ProgressPhotosView.swift`
- `AiQo/Features/Captain/MessageBubble.swift`
- `AiQo/Core/Models/LevelStore.swift`
- `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift`
- `AiQo/UI/Purchases/PaywallView.swift`

## Typography
The app broadly uses rounded system typography (`.system(..., design: .rounded)` / SF Pro Rounded style), which is consistent with the Arabic-first look but not abstracted into a fully enforced typography token layer. `AiQo/App/AuthFlowUI.swift:16-20`; `AiQo/UI/Purchases/PaywallView.swift:253`; `AiQo/Features/MyVibe/MyVibeScreen.swift`; `AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift`

## Glassmorphism Components
Reusable glass surfaces found:
- `AiQo/UI/GlassCardView.swift`
- `AiQo/Features/Gym/SoftGlassCardView.swift`
- `AiQo/Features/Tribe/TribeDesignSystem.swift` (`PremiumGlassCard`)
- `AiQo/Features/Gym/CinematicGrindViews.swift` (`CinematicGlassCard`)
- `AiQo/Features/Gym/WinsViewController.swift` (`BottomGlassSheet`, `SoftGlassCardBackground`)
- `AiQo/Features/Gym/MyPlanViewController.swift` (`PlanGlassCard`)

## RTL Correctness Findings
Notable RTL problems:
- Forced `.leftToRight` in Arabic-facing screens: `AiQo/Tribe/TribeModuleComponents.swift:228`; `AiQo/Tribe/TribeModuleComponents.swift:437`; `AiQo/Tribe/TribeModuleComponents.swift:780`; `AiQo/Tribe/TribeModuleComponents.swift:835`; `AiQo/Tribe/TribeModuleComponents.swift:954`; `AiQo/Tribe/TribePulseScreenView.swift:163`; `AiQo/Tribe/TribePulseScreenView.swift:476`; `AiQo/UI/AiQoScreenHeader.swift:62`; `AiQo/Features/Gym/Club/ClubRootView.swift:150`
- Hardcoded left/right icon assumptions: `AiQo/Features/ProgressPhotos/ProgressPhotosView.swift:272`; `AiQo/Features/ProgressPhotos/ProgressPhotosView.swift:479`; `AiQo/Tribe/Views/TribeHubScreen.swift:530`; `AiQoWatch Watch App/Views/WatchWorkoutListView.swift:56`; `AiQoWatch Watch App/StartView.swift:225`; `AiQo/Features/Gym/MyPlanViewController.swift:155`
- UIKit text alignment with `.left` / `.right`: `AiQo/Features/Kitchen/MealSectionView.swift:38`; `AiQo/Features/Gym/LiveMetricsHeader.swift:52`; `AiQo/Features/Gym/LiveMetricsHeader.swift:70`

## Worst Hardcoded Strings That Should Be Localized
- `AiQo/Features/Tribe/TribeExperienceFlow.swift:193-209`; `AiQo/Features/Tribe/TribeExperienceFlow.swift:293-303`; `AiQo/Features/Tribe/TribeExperienceFlow.swift:335-372` — large English-only preview and premium copy.
- `AiQo/Core/AppSettingsScreen.swift:246-250`; `AiQo/Core/AppSettingsScreen.swift:393-402` — debug “Spiritual Whisper” strings.
- `AiQo/Services/Notifications/NotificationService.swift:147-148` — `Open Captain` action title.
- `AiQoWatch Watch App/WorkoutNotificationCenter.swift:44-46`; `AiQoWatch Watch App/WorkoutNotificationCenter.swift:78-79` — English workout notification copy.
- `AiQo/Features/WeeklyReport/ShareCardRenderer.swift` — English share-card output strings. `AiQo/Features/WeeklyReport/ShareCardRenderer.swift`

# 11. AiQoWatch Companion
## Standalone Capabilities
The watch target is not a thin shell. It contains a home surface, workout list, active workout screen, summary flow, workout notifications, and direct HealthKit workout session management. `AiQoWatch Watch App/Views/WatchHomeView.swift`; `AiQoWatch Watch App/Views/WatchWorkoutListView.swift`; `AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift`; `AiQoWatch Watch App/Views/WatchWorkoutSummaryView.swift`; `AiQoWatch Watch App/WorkoutManager.swift`

## Connectivity With Phone
Phone connectivity is real and two-layered: a thin SwiftUI-facing `WatchConnectivityService` wraps `WatchConnectivityManager`, and workout completions are sent via `sendMessage` when reachable or `transferUserInfo` otherwise. `AiQoWatch Watch App/Services/WatchConnectivityService.swift:5-53`; `AiQoWatch Watch App/WatchConnectivityManager.swift`; `AiQoWatch Watch App/Shared/WorkoutSyncCodec.swift`

Source: `AiQoWatch Watch App/Services/WatchConnectivityService.swift:38-52`
```swift
let session = WCSession.default
if session.isReachable {
    session.sendMessage(data, replyHandler: nil, errorHandler: nil)
} else {
```

## HealthKit On Watch
Watch HealthKit authorization requests steps, calories, walking/running distance, heart rate, sleep analysis, and workouts, with workouts shared back to HealthKit. `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:15-24`; `AiQoWatch-Watch-App-Info.plist:5-14`

## UI Completeness vs Phone Parity
Watch parity is strongest around workouts and summaries, not the whole AiQo universe. There is no equivalent watch surface for Kitchen, full Captain chat, or the richer Tribe / My Vibe experiences, and workout notification copy is still English-first. `AiQoWatch Watch App/Views/WatchHomeView.swift`; `AiQoWatch Watch App/WorkoutNotificationCenter.swift:44-46`; `AiQoWatch Watch App/WorkoutNotificationCenter.swift:78-79`

# 12. Outstanding TODOs & Tech Debt
## `TODO` / `FIXME` / `HACK` / `XXX` Hits
| File | Comment |
| --- | --- |
| `AiQo/Features/Tribe/TribeExperienceFlow.swift:190` | `// TODO before launch: replace with live SupabaseTribeRepository call.` |
| `AiQo/Features/Tribe/TribeExperienceFlow.swift:205` | `// TODO before launch: replace with live SupabaseTribeRepository call.` |
| `AiQo/Features/Tribe/TribeExperienceFlow.swift:299` | `// TODO before launch: replace with live SupabaseTribeRepository call.` |
| `AiQo/Features/Tribe/TribeExperienceFlow.swift:348` | `// TODO before launch: replace with live SupabaseTribeRepository call.` |
| `AiQo/Features/Tribe/TribeExperienceFlow.swift:369` | `// TODO before launch: replace with live SupabaseTribeRepository call.` |

## Hardcoded Values That Should Become Configurable
- `CAPTAIN_ARABIC_API_URL` still points to local dev hosts in both Debug and Release build settings. `AiQo.xcodeproj/project.pbxproj:1043-1045`; `AiQo.xcodeproj/project.pbxproj:1111-1113`
- Zone 2 still uses `220 - age` with hardcoded `60%` / `70%` bounds. `AiQo/Features/Gym/LiveWorkoutSession.swift:534-539`
- Smart Wake default cycle assumptions are hardcoded. `AiQo/Features/Sleep/SmartWakeEngine.swift:67-72`
- Notification quiet hours and cooldowns are hardcoded. `AiQo/Core/SmartNotificationScheduler.swift:12-13`; `AiQo/Services/Notifications/NotificationService.swift:362-365`
- Receipt validation endpoint is hardcoded instead of derived from environment. `AiQo/Core/Purchases/ReceiptValidator.swift:9-10`

## Duplicate Logic / Consolidation Candidates
- HealthKit authorization is duplicated between `SceneDelegate` and `HealthKitService`, and the requested type sets are not identical (`appleStandTime` vs `appleStandHour`). `AiQo/App/SceneDelegate.swift:108-140`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:45-102`
- Subscription truth is spread across `AiQo_Test.storekit`, `AiQo.storekit`, `SubscriptionProductIDs`, `AccessManager`, `EntitlementStore`, and localized legal strings. `AiQo/Resources/AiQo_Test.storekit:25-110`; `AiQo/Resources/AiQo.storekit:3-31`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:6-38`; `AiQo/Premium/AccessManager.swift:27-63`; `AiQo/Core/Purchases/EntitlementStore.swift:21-34`; `AiQo/Resources/en.lproj/Localizable.strings:49`
- Notification language resolution is duplicated between `AppSettingsScreen`, `SmartNotificationScheduler`, `NotificationService`, and `SleepSessionObserver`. `AiQo/Core/AppSettingsScreen.swift:12`; `AiQo/Core/SmartNotificationScheduler.swift:52`; `AiQo/Services/Notifications/NotificationService.swift:971-978`; `AiQo/Features/Sleep/SleepSessionObserver.swift:99-103`
- Tribe has parallel live, preview, and mock data layers active at once. `AiQo/Features/Tribe/TribeExperienceFlow.swift:188-208`; `AiQo/Tribe/Preview/TribePreviewData.swift:3-20`; `AiQo/Tribe/Galaxy/MockArenaData.swift:1-80`; `AiQo/Tribe/TribeModuleViewModel.swift:54`; `AiQo/Tribe/TribeModuleViewModel.swift:181-183`

## Files Exceeding 600 LOC
- `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift` — 1422
- `AiQo/Services/SupabaseArenaService.swift` — 1362
- `AiQoWatch Watch App/WorkoutManager.swift` — 1344
- `AiQo/Features/Profile/ProfileScreenComponents.swift` — 1264
- `AiQo/Features/Gym/CinematicGrindViews.swift` — 1204
- `AiQo/Features/Captain/CaptainScreen.swift` — 1147
- `AiQo/Tribe/TribeModuleComponents.swift` — 1146
- `AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift` — 1043
- `AiQo/Features/Tribe/TribeView.swift` — 1028
- `AiQo/UI/Purchases/PaywallView.swift` — 1024
- `AiQo/PhoneConnectivityManager.swift` — 1009
- `AiQo/Tribe/Views/TribeHubScreen.swift` — 1008
- `AiQo/Services/Permissions/HealthKit/HealthKitService.swift` — 1006
- `AiQo/Services/Notifications/NotificationService.swift` — 994
- `AiQo/Features/Captain/CaptainIntelligenceManager.swift` — 965
- `AiQo/Features/Captain/CaptainViewModel.swift` — 953
- `AiQo/Features/Home/VibeControlSheetLogic.swift` — 950
- `AiQo/Features/Home/HomeViewModel.swift` — 948
- `AiQo/Features/Gym/QuestKit/QuestDefinitions.swift` — 943
- `AiQo/Features/ProgressPhotos/ProgressPhotosView.swift` — 904
- `AiQo/Features/Gym/LiveWorkoutSession.swift` — 885
- `AiQo/Features/Gym/RecapViewController.swift` — 874
- `AiQo/Features/Sleep/SleepDetailCardView.swift` — 859
- `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift` — 847
- `AiQo/Features/Captain/LocalBrainService.swift` — 846
- `AiQo/Core/VibeAudioEngine.swift` — 829
- `AiQo/Tribe/Views/TribeLeaderboardView.swift` — 800
- `AiQo/Features/Captain/CoachBrainMiddleware.swift` — 773
- `AiQo/Core/SmartNotificationScheduler.swift` — 773
- `AiQo/Features/First screen/LegacyCalculationViewController.swift` — 751
- `AiQo/Features/Kitchen/InteractiveFridgeView.swift` — 732
- `AiQo/Tribe/TribePulseScreenView.swift` — 728
- `AiQo/Core/SpotifyVibeManager.swift` — 721
- `AiQo/Features/Gym/WorkoutSessionScreen.swift.swift` — 719
- `AiQoWidget/AiQoWidgetLiveActivity.swift` — 718
- `AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift` — 712
- `AiQo/Features/Gym/QuestKit/QuestEngine.swift` — 691
- `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift` — 680
- `AiQo/Features/Kitchen/NutritionTrackerView.swift` — 653
- `AiQo/Features/Kitchen/SmartFridgeScannerView.swift` — 627
- `AiQo/Tribe/Galaxy/GalaxyView.swift` — 626
- `AiQo/Features/Kitchen/IngredientKey.swift` — 624
- `AiQo/Features/Captain/CaptainChatView.swift` — 613
- `AiQo/Tribe/TribeModuleModels.swift` — 611
- `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift` — 611

# 13. TestFlight Readiness Checklist
| Item | Status | Evidence |
| --- | --- | --- |
| All required `Info.plist` usage descriptions present and Arabic-localized | ❌ | HealthKit is localized, but `NSAlarmKitUsageDescription` appears only inline and not in `InfoPlist.strings`. `AiQo/Resources/ar.lproj/InfoPlist.strings:1-3`; `AiQo/Info.plist:46-47` |
| App icon set complete | ✅ | Main app icon set includes iPhone/iPad/marketing sizes; watch icon set is also populated. `AiQo/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json:2-110`; `AiQoWatch Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json:2-218` |
| Launch screen configured | ✅ | `UILaunchScreen_Generation = YES` in Debug and Release. `AiQo.xcodeproj/project.pbxproj:1074`; `AiQo.xcodeproj/project.pbxproj:1142` |
| Build number / version set | ✅ | `CURRENT_PROJECT_VERSION = 17`, `MARKETING_VERSION = 1.0`. `AiQo.xcodeproj/project.pbxproj:1048`; `AiQo.xcodeproj/project.pbxproj:1082`; `AiQo.xcodeproj/project.pbxproj:1116`; `AiQo.xcodeproj/project.pbxproj:1150` |
| Crashlytics initialized | ❌ | Wiring exists in `AppDelegate`, but the setup doc says the Firebase package and `GoogleService-Info.plist` are not yet added. `AiQo/App/AppDelegate.swift:99-105`; `AiQo/Services/CrashReporting/CRASHLYTICS_SETUP.md:3-8` |
| No `print()` statements in release paths | ❌ | Release-path `print()` calls remain in purchase validation, sleep observer, morning habit, Tribe, watch notifications, and more. `AiQo/Core/Purchases/ReceiptValidator.swift:57`; `AiQo/Core/Purchases/ReceiptValidator.swift:75`; `AiQo/Features/Sleep/SleepSessionObserver.swift:57`; `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:168`; `AiQo/Tribe/TribeStore.swift:180`; `AiQoWatch Watch App/WorkoutNotificationCenter.swift:27-30` |
| No hardcoded API keys in source | ❌ | Hardcoded JWT and Google-style API key remain in tracked config. `AiQo/Info.plist:66-69`; `Configuration/Secrets.xcconfig:4-16` |
| StoreKit configuration matches App Store Connect (or note it needs to be created) | ❌ | Repo contains conflicting StoreKit catalogs and stale legal copy; App Store Connect parity is not provable from the codebase. `AiQo/Resources/AiQo_Test.storekit:25-110`; `AiQo/Resources/AiQo.storekit:3-31`; `AiQo/Resources/en.lproj/Localizable.strings:49` |
| Privacy manifest (`PrivacyInfo.xcprivacy`) present and accurate | ❌ | Manifest exists, but only declares the `UserDefaults` required-reason API and only two collected data types. `AiQo/PrivacyInfo.xcprivacy:9-46` |
| All required reason API declarations present | ❌ | Only `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1` is declared; completeness for the whole app is not demonstrated by the manifest. `AiQo/PrivacyInfo.xcprivacy:9-19` |

# 14. App Store Submission Blockers
| Rank | Blocker | Why it blocks | Files to fix | Effort |
| --- | --- | --- | --- | --- |
| 1 | P0: User-visible placeholder / fake data in Tribe and Kitchen | App Review can reject for unfinished or misleading functionality, and your own no-mock-data rule is violated by preview shells and canned fallback fridge items appearing in live code paths. `AiQo/Features/Tribe/TribeExperienceFlow.swift:188-208`; `AiQo/Tribe/TribeModuleViewModel.swift:54`; `AiQo/Tribe/Preview/TribePreviewData.swift:3-20`; `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:120-131`; `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:258-284` | `AiQo/Features/Tribe/TribeExperienceFlow.swift`; `AiQo/Tribe/TribeModuleViewModel.swift`; `AiQo/Tribe/Preview/TribePreviewData.swift`; `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift` | L |
| 2 | P0: Subscription / paywall / legal drift | Product IDs, UI copy, entitlements, and legal text do not describe the same subscription product. That is a direct subscription-review risk. `AiQo/UI/Purchases/PaywallView.swift:861-927`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:84-95`; `AiQo/Resources/AiQo_Test.storekit:25-110`; `AiQo/Resources/AiQo.storekit:3-31`; `AiQo/Resources/en.lproj/Localizable.strings:49` | `AiQo/UI/Purchases/PaywallView.swift`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift`; `AiQo/Resources/AiQo_Test.storekit`; `AiQo/Resources/AiQo.storekit`; `AiQo/Resources/en.lproj/Localizable.strings`; `AiQo/Resources/ar.lproj/Localizable.strings` | M |
| 3 | P0: Hardcoded secrets and production endpoints in shipped config | Shipping live anon keys / API keys in tracked config is a security and operational blocker, and it makes environment control fragile. `AiQo/Info.plist:66-69`; `Configuration/Secrets.xcconfig:4-16`; `AiQo/Core/Purchases/ReceiptValidator.swift:9-10` | `AiQo/Info.plist`; `Configuration/Secrets.xcconfig`; `AiQo/Core/Constants.swift`; `AiQo/Core/Purchases/ReceiptValidator.swift` | M |
| 4 | P1: Privacy manifest and AI disclosure package is incomplete | The manifest only covers `UserDefaults`, while the product performs health-driven AI features and external AI calls that need a cleaner disclosure story. `AiQo/PrivacyInfo.xcprivacy:9-46`; `AiQo/Features/Captain/CloudBrainService.swift:23-37`; `AiQo/Core/MemoryExtractor.swift:300-317`; `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:306-398` | `AiQo/PrivacyInfo.xcprivacy`; app privacy copy / submission metadata; possibly in-app legal strings | M |
| 5 | P1: Crash reporting is scaffolded but not production-ready | TestFlight without real crash capture slows stabilization and indicates incomplete release prep. `AiQo/App/AppDelegate.swift:99-105`; `AiQo/Services/CrashReporting/CRASHLYTICS_SETUP.md:3-8` | `AiQo/Services/CrashReporting/*`; Xcode package setup; Firebase plist wiring | S |
| 6 | P1: Release-path debug prints and tone debt remain | Excess console logging and “spiritual whisper” wording are not submission-grade polish. `AiQo/Core/Purchases/ReceiptValidator.swift:57-99`; `AiQo/Features/Sleep/SleepSessionObserver.swift:57-67`; `AiQo/Core/AppSettingsScreen.swift:246-250`; `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:106-110` | `AiQo/Core/Purchases/ReceiptValidator.swift`; `AiQo/Features/Sleep/SleepSessionObserver.swift`; `AiQo/Core/AppSettingsScreen.swift`; `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift` | S |
| 7 | P1: Notification language inconsistency | Arabic-first product quality breaks when some notifications honor `notificationLanguage` and others do not. `AiQo/Core/SmartNotificationScheduler.swift:490-513`; `AiQo/Features/Sleep/SleepSessionObserver.swift:99-103`; `AiQo/Services/Notifications/NotificationService.swift:143-148`; `AiQoWatch Watch App/WorkoutNotificationCenter.swift:44-46` | `AiQo/Features/Sleep/SleepSessionObserver.swift`; `AiQo/Services/Notifications/NotificationService.swift`; `AiQoWatch Watch App/WorkoutNotificationCenter.swift` | S |
| 8 | P2: Onboarding XP explanation is mathematically wrong | Not a hard build blocker, but it undermines trust at first launch. `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:24-38`; `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:171-197` | `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift`; optionally centralize formula in shared code | S |

# 15. Recommended Next 9 Prompts
| Priority | Prompt | One-line goal | Files likely touched |
| --- | --- | --- | --- |
| 1 | `Remove all user-visible mock and fallback data from Tribe and Kitchen, replacing it with honest empty/error states.` | Eliminate the biggest product-integrity blocker before TestFlight. | `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift`; `AiQo/Features/Tribe/TribeExperienceFlow.swift`; `AiQo/Tribe/TribeModuleViewModel.swift`; `AiQo/Tribe/Preview/TribePreviewData.swift` |
| 2 | `Align StoreKit, paywall copy, entitlement gates, and legal text to one three-tier subscription truth.` | Make Core / Pro / Intelligence consistent everywhere. | `AiQo/UI/Purchases/PaywallView.swift`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift`; `AiQo/Resources/AiQo_Test.storekit`; `AiQo/Resources/AiQo.storekit`; `AiQo/Resources/en.lproj/Localizable.strings`; `AiQo/Resources/ar.lproj/Localizable.strings` |
| 3 | `Purge hardcoded secrets and move all environment configuration to secure xcconfig / CI injection.` | Remove tracked keys and endpoint leakage. | `AiQo/Info.plist`; `Configuration/Secrets.xcconfig`; `AiQo/Core/Constants.swift`; `AiQo/Core/Purchases/ReceiptValidator.swift` |
| 4 | `Finish the Tribe live backend path and remove preview-only state from production screens.` | Convert visible Tribe from hybrid-preview to source-of-truth Supabase behavior. | `AiQo/Features/Tribe/TribeExperienceFlow.swift`; `AiQo/Tribe/Repositories/TribeRepositories.swift`; `AiQo/Tribe/TribeStore.swift`; `AiQo/Services/SupabaseArenaService.swift` |
| 5 | `Complete the App Store privacy/compliance package for HealthKit + AI, including privacy manifest and disclosure cleanup.` | Reduce App Review privacy risk. | `AiQo/PrivacyInfo.xcprivacy`; `AiQo/Resources/en.lproj/Localizable.strings`; `AiQo/Resources/ar.lproj/Localizable.strings`; submission metadata support docs |
| 6 | `Make notification language fully consistent and remove leftover spiritual/debug wording.` | Ensure Arabic-first notification polish. | `AiQo/Features/Sleep/SleepSessionObserver.swift`; `AiQo/Services/Notifications/NotificationService.swift`; `AiQo/Core/AppSettingsScreen.swift`; `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift`; `AiQoWatch Watch App/WorkoutNotificationCenter.swift` |
| 7 | `Finish production Crashlytics integration and strip release-path print logging.` | Improve TestFlight stabilization and release hygiene. | `AiQo/Services/CrashReporting/*`; `AiQo/App/AppDelegate.swift`; `AiQo/Core/Purchases/ReceiptValidator.swift`; `AiQo/Features/Sleep/SleepSessionObserver.swift`; `AiQo/Services/Notifications/MorningHabitOrchestrator.swift` |
| 8 | `Unify XP scoring formulas across onboarding, historical sync, and in-app explanations.` | Remove first-run trust debt and centralize game-economy logic. | `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift`; `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift`; `AiQo/XPCalculator.swift` |
| 9 | `Refactor the oversized files that sit on core release paths, starting with Paywall, Captain, NotificationService, and WorkoutManager.` | Reduce defect density ahead of launch. | `AiQo/UI/Purchases/PaywallView.swift`; `AiQo/Features/Captain/CaptainScreen.swift`; `AiQo/Services/Notifications/NotificationService.swift`; `AiQoWatch Watch App/WorkoutManager.swift` |

## Methodology
The numbered sections above are based on a full end-to-end read of the source-of-record AiQo project tree on April 8, 2026. For architecture counts, I used the requested Phase 1 file classes across the active project roots and excluded assistant-side worktree mirrors under `.claude/worktrees/*`, `.git/*`, and generated `build/` output so the metrics would reflect the actual Xcode codebase rather than local tooling duplicates. The counted audit corpus is 449 files / 135728 LOC, and I also read additional support files outside that glob when the audit required them (for example `project.pbxproj`, `Package.resolved`, privacy manifests, localized strings, and asset catalog `Contents.json` files).

### Counted Audit Corpus (449 files)
### .
- `AiQoWatch-Watch-App-Info.plist`
- `AiQoWatchWidgetExtension.entitlements`
- `AiQoWidgetExtension.entitlements`
- `AiQo_Master_Blueprint_10.md`
- `AiQo_Master_Blueprint_2 2.md`
- `AiQo_Master_Blueprint_2.md`
- `AiQo_Master_Blueprint_3.md`
- `AiQo_Master_Blueprint_4.md`
- `AiQo_Master_Blueprint_5.md`
- `AiQo_Master_Blueprint_9.md`
- `AiQo_Master_Blueprint_Complete.md`
- `HOME_SCREEN_CODEX_HANDOFF.md`

### AiQo
- `AiQo/AiQo.entitlements`
- `AiQo/AiQoActivityNames.swift`
- `AiQo/AppGroupKeys.swift`
- `AiQo/Info.plist`
- `AiQo/NeuralMemory.swift`
- `AiQo/PhoneConnectivityManager.swift`
- `AiQo/ProtectionModel.swift`
- `AiQo/XPCalculator.swift`

### AiQo.xcodeproj/xcuserdata/mohammedraad.xcuserdatad/xcschemes
- `AiQo.xcodeproj/xcuserdata/mohammedraad.xcuserdatad/xcschemes/xcschememanagement.plist`

### AiQo/AiQoCore/AiQoCore.docc
- `AiQo/AiQoCore/AiQoCore.docc/AiQoCore.md`

### AiQo/App
- `AiQo/App/AppDelegate.swift`
- `AiQo/App/AppRootManager.swift`
- `AiQo/App/AuthFlowUI.swift`
- `AiQo/App/LanguageSelectionView.swift`
- `AiQo/App/LoginViewController.swift`
- `AiQo/App/MainTabRouter.swift`
- `AiQo/App/MainTabScreen.swift`
- `AiQo/App/MealModels.swift`
- `AiQo/App/ProfileSetupView.swift`
- `AiQo/App/SceneDelegate.swift`

### AiQo/Core
- `AiQo/Core/AiQoAccessibility.swift`
- `AiQo/Core/AiQoAudioManager.swift`
- `AiQo/Core/AppSettingsScreen.swift`
- `AiQo/Core/AppSettingsStore.swift`
- `AiQo/Core/ArabicNumberFormatter.swift`
- `AiQo/Core/CaptainMemory.swift`
- `AiQo/Core/CaptainMemorySettingsView.swift`
- `AiQo/Core/CaptainVoiceAPI.swift`
- `AiQo/Core/CaptainVoiceCache.swift`
- `AiQo/Core/CaptainVoiceService.swift`
- `AiQo/Core/Colors.swift`
- `AiQo/Core/Constants.swift`
- `AiQo/Core/DailyGoals.swift`
- `AiQo/Core/DeveloperPanelView.swift`
- `AiQo/Core/HapticEngine.swift`
- `AiQo/Core/HealthKitMemoryBridge.swift`
- `AiQo/Core/MemoryExtractor.swift`
- `AiQo/Core/MemoryStore.swift`
- `AiQo/Core/SiriShortcutsManager.swift`
- `AiQo/Core/SmartNotificationScheduler.swift`
- `AiQo/Core/SpotifyVibeManager.swift`
- `AiQo/Core/StreakManager.swift`
- `AiQo/Core/UserProfileStore.swift`
- `AiQo/Core/VibeAudioEngine.swift`

### AiQo/Core/Localization
- `AiQo/Core/Localization/Bundle+Language.swift`
- `AiQo/Core/Localization/LocalizationManager.swift`

### AiQo/Core/Models
- `AiQo/Core/Models/ActivityNotification.swift`
- `AiQo/Core/Models/LevelStore.swift`
- `AiQo/Core/Models/NotificationPreferencesStore.swift`

### AiQo/Core/Purchases
- `AiQo/Core/Purchases/EntitlementStore.swift`
- `AiQo/Core/Purchases/PurchaseManager.swift`
- `AiQo/Core/Purchases/ReceiptValidator.swift`
- `AiQo/Core/Purchases/SubscriptionProductIDs.swift`
- `AiQo/Core/Purchases/SubscriptionTier.swift`

### AiQo/Core/Utilities
- `AiQo/Core/Utilities/ConnectivityDebugProviding.swift`
- `AiQo/Core/Utilities/DebugPrint.swift`

### AiQo/DesignSystem
- `AiQo/DesignSystem/AiQoColors.swift`
- `AiQo/DesignSystem/AiQoTheme.swift`
- `AiQo/DesignSystem/AiQoTokens.swift`

### AiQo/DesignSystem/Components
- `AiQo/DesignSystem/Components/AiQoBottomCTA.swift`
- `AiQo/DesignSystem/Components/AiQoCard.swift`
- `AiQo/DesignSystem/Components/AiQoChoiceGrid.swift`
- `AiQo/DesignSystem/Components/AiQoPillSegment.swift`
- `AiQo/DesignSystem/Components/AiQoPlatformPicker.swift`
- `AiQo/DesignSystem/Components/AiQoSkeletonView.swift`
- `AiQo/DesignSystem/Components/StatefulPreviewWrapper.swift`

### AiQo/DesignSystem/Modifiers
- `AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift`
- `AiQo/DesignSystem/Modifiers/AiQoShadow.swift`
- `AiQo/DesignSystem/Modifiers/AiQoSheetStyle.swift`

### AiQo/Features/Captain
- `AiQo/Features/Captain/AiQoPromptManager.swift`
- `AiQo/Features/Captain/BrainOrchestrator.swift`
- `AiQo/Features/Captain/CaptainChatView.swift`
- `AiQo/Features/Captain/CaptainContextBuilder.swift`
- `AiQo/Features/Captain/CaptainFallbackPolicy.swift`
- `AiQo/Features/Captain/CaptainIntelligenceManager.swift`
- `AiQo/Features/Captain/CaptainModels.swift`
- `AiQo/Features/Captain/CaptainNotificationRouting.swift`
- `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift`
- `AiQo/Features/Captain/CaptainPersonaBuilder.swift`
- `AiQo/Features/Captain/CaptainPromptBuilder.swift`
- `AiQo/Features/Captain/CaptainScreen.swift`
- `AiQo/Features/Captain/CaptainViewModel.swift`
- `AiQo/Features/Captain/ChatHistoryView.swift`
- `AiQo/Features/Captain/CloudBrainService.swift`
- `AiQo/Features/Captain/CoachBrainMiddleware.swift`
- `AiQo/Features/Captain/CoachBrainTranslationConfig.swift`
- `AiQo/Features/Captain/HybridBrainService.swift`
- `AiQo/Features/Captain/LLMJSONParser.swift`
- `AiQo/Features/Captain/LocalBrainService.swift`
- `AiQo/Features/Captain/LocalIntelligenceService.swift`
- `AiQo/Features/Captain/MessageBubble.swift`
- `AiQo/Features/Captain/PrivacySanitizer.swift`
- `AiQo/Features/Captain/PromptRouter.swift`
- `AiQo/Features/Captain/ScreenContext.swift`

### AiQo/Features/DataExport
- `AiQo/Features/DataExport/HealthDataExporter.swift`

### AiQo/Features/First screen
- `AiQo/Features/First screen/LegacyCalculationViewController.swift`

### AiQo/Features/Gym
- `AiQo/Features/Gym/ActiveRecoveryView.swift`
- `AiQo/Features/Gym/AudioCoachManager.swift`
- `AiQo/Features/Gym/CinematicGrindCardView.swift`
- `AiQo/Features/Gym/CinematicGrindViews.swift`
- `AiQo/Features/Gym/ExercisesView.swift`
- `AiQo/Features/Gym/GuinnessEncyclopediaView.swift`
- `AiQo/Features/Gym/GymViewController.swift`
- `AiQo/Features/Gym/HandsFreeZone2Manager.swift`
- `AiQo/Features/Gym/HeartView.swift`
- `AiQo/Features/Gym/L10n.swift`
- `AiQo/Features/Gym/LiveMetricsHeader.swift`
- `AiQo/Features/Gym/LiveWorkoutSession.swift`
- `AiQo/Features/Gym/MyPlanViewController.swift`
- `AiQo/Features/Gym/OriginalWorkoutCardView.swift`
- `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift`
- `AiQo/Features/Gym/RecapViewController.swift`
- `AiQo/Features/Gym/RewardsViewController.swift`
- `AiQo/Features/Gym/ShimmeringPlaceholder.swift`
- `AiQo/Features/Gym/SoftGlassCardView.swift`
- `AiQo/Features/Gym/SpotifyWebView.swift`
- `AiQo/Features/Gym/SpotifyWorkoutPlayerView.swift`
- `AiQo/Features/Gym/WatchConnectionStatusButton.swift`
- `AiQo/Features/Gym/WatchConnectivityService.swift`
- `AiQo/Features/Gym/WinsViewController.swift`
- `AiQo/Features/Gym/WorkoutLiveActivityManager.swift`
- `AiQo/Features/Gym/WorkoutSessionScreen.swift.swift`
- `AiQo/Features/Gym/WorkoutSessionSheetView.swift`
- `AiQo/Features/Gym/WorkoutSessionViewModel.swift`

### AiQo/Features/Gym/Club
- `AiQo/Features/Gym/Club/ClubRootView.swift`

### AiQo/Features/Gym/Club/Body
- `AiQo/Features/Gym/Club/Body/BodyView.swift`
- `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift`
- `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift`
- `AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift`

### AiQo/Features/Gym/Club/Challenges
- `AiQo/Features/Gym/Club/Challenges/ChallengesView.swift`

### AiQo/Features/Gym/Club/Components
- `AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift`
- `AiQo/Features/Gym/Club/Components/RailScrollOffsetPreferenceKey.swift`
- `AiQo/Features/Gym/Club/Components/RightSideRailView.swift`
- `AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift`
- `AiQo/Features/Gym/Club/Components/SegmentedTabs.swift`
- `AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift`

### AiQo/Features/Gym/Club/Impact
- `AiQo/Features/Gym/Club/Impact/ImpactAchievementsView.swift`
- `AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift`
- `AiQo/Features/Gym/Club/Impact/ImpactSummaryView.swift`

### AiQo/Features/Gym/Club/Plan
- `AiQo/Features/Gym/Club/Plan/PlanView.swift`
- `AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift`

### AiQo/Features/Gym/Models
- `AiQo/Features/Gym/Models/GymExercise.swift`

### AiQo/Features/Gym/QuestKit
- `AiQo/Features/Gym/QuestKit/QuestDataSources.swift`
- `AiQo/Features/Gym/QuestKit/QuestDefinitions.swift`
- `AiQo/Features/Gym/QuestKit/QuestEngine.swift`
- `AiQo/Features/Gym/QuestKit/QuestEvaluator.swift`
- `AiQo/Features/Gym/QuestKit/QuestFormatting.swift`
- `AiQo/Features/Gym/QuestKit/QuestKitModels.swift`
- `AiQo/Features/Gym/QuestKit/QuestProgressStore.swift`
- `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift`
- `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift`

### AiQo/Features/Gym/QuestKit/Views
- `AiQo/Features/Gym/QuestKit/Views/QuestCameraPermissionGateView.swift`
- `AiQo/Features/Gym/QuestKit/Views/QuestDebugView.swift`
- `AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift`

### AiQo/Features/Gym/Quests/Models
- `AiQo/Features/Gym/Quests/Models/Challenge.swift`
- `AiQo/Features/Gym/Quests/Models/ChallengeStage.swift`
- `AiQo/Features/Gym/Quests/Models/HelpStrangersModels.swift`
- `AiQo/Features/Gym/Quests/Models/WinRecord.swift`

### AiQo/Features/Gym/Quests/Store
- `AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift`
- `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift`
- `AiQo/Features/Gym/Quests/Store/WinsStore.swift`

### AiQo/Features/Gym/Quests/Views
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

### AiQo/Features/Gym/Quests/VisionCoach
- `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift`
- `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift`
- `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift`

### AiQo/Features/Gym/T
- `AiQo/Features/Gym/T/SpinWheelView.swift`
- `AiQo/Features/Gym/T/WheelTypes.swift`
- `AiQo/Features/Gym/T/WorkoutTheme.swift`
- `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift`

### AiQo/Features/Home
- `AiQo/Features/Home/ActivityDataProviding.swift`
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
- `AiQo/Features/Home/ScreenshotMode.swift`
- `AiQo/Features/Home/SpotifyVibeCard.swift`
- `AiQo/Features/Home/StreakBadgeView.swift`
- `AiQo/Features/Home/VibeControlComponents.swift`
- `AiQo/Features/Home/VibeControlSheet.swift`
- `AiQo/Features/Home/VibeControlSheetLogic.swift`
- `AiQo/Features/Home/VibeControlSupport.swift`
- `AiQo/Features/Home/WaterBottleView.swift`
- `AiQo/Features/Home/WaterDetailSheetView.swift`

### AiQo/Features/Kitchen
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

### AiQo/Features/LegendaryChallenges/Components
- `AiQo/Features/LegendaryChallenges/Components/RecordCard.swift`

### AiQo/Features/LegendaryChallenges/Models
- `AiQo/Features/LegendaryChallenges/Models/LegendaryProject.swift`
- `AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift`
- `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift`
- `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift`

### AiQo/Features/LegendaryChallenges/ViewModels
- `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift`
- `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift`
- `AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift`

### AiQo/Features/LegendaryChallenges/Views
- `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift`
- `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift`
- `AiQo/Features/LegendaryChallenges/Views/ProjectView.swift`
- `AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift`
- `AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift`
- `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewResultView.swift`
- `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift`

### AiQo/Features/MyVibe
- `AiQo/Features/MyVibe/DailyVibeState.swift`
- `AiQo/Features/MyVibe/MyVibeScreen.swift`
- `AiQo/Features/MyVibe/MyVibeSubviews.swift`
- `AiQo/Features/MyVibe/MyVibeViewModel.swift`
- `AiQo/Features/MyVibe/VibeOrchestrator.swift`

### AiQo/Features/Onboarding
- `AiQo/Features/Onboarding/FeatureIntroView.swift`
- `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift`
- `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift`

### AiQo/Features/Profile
- `AiQo/Features/Profile/LevelCardView.swift`
- `AiQo/Features/Profile/ProfileScreen.swift`
- `AiQo/Features/Profile/ProfileScreenComponents.swift`
- `AiQo/Features/Profile/ProfileScreenLogic.swift`
- `AiQo/Features/Profile/ProfileScreenModels.swift`
- `AiQo/Features/Profile/String+Localized.swift`

### AiQo/Features/ProgressPhotos
- `AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift`
- `AiQo/Features/ProgressPhotos/ProgressPhotosView.swift`

### AiQo/Features/Sleep
- `AiQo/Features/Sleep/AlarmSetupCardView.swift`
- `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift`
- `AiQo/Features/Sleep/HealthManager+Sleep.swift`
- `AiQo/Features/Sleep/SleepDetailCardView.swift`
- `AiQo/Features/Sleep/SleepScoreRingView.swift`
- `AiQo/Features/Sleep/SleepSessionObserver.swift`
- `AiQo/Features/Sleep/SmartWakeCalculatorView.swift`
- `AiQo/Features/Sleep/SmartWakeEngine.swift`
- `AiQo/Features/Sleep/SmartWakeViewModel.swift`

### AiQo/Features/Tribe
- `AiQo/Features/Tribe/TribeDesignSystem.swift`
- `AiQo/Features/Tribe/TribeExperienceFlow.swift`
- `AiQo/Features/Tribe/TribeView.swift`

### AiQo/Features/WeeklyReport
- `AiQo/Features/WeeklyReport/ShareCardRenderer.swift`
- `AiQo/Features/WeeklyReport/WeeklyReportModel.swift`
- `AiQo/Features/WeeklyReport/WeeklyReportView.swift`
- `AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift`

### AiQo/Frameworks/SpotifyiOS.framework
- `AiQo/Frameworks/SpotifyiOS.framework/Info.plist`

### AiQo/Premium
- `AiQo/Premium/AccessManager.swift`
- `AiQo/Premium/EntitlementProvider.swift`
- `AiQo/Premium/FreeTrialManager.swift`
- `AiQo/Premium/PremiumPaywallView.swift`
- `AiQo/Premium/PremiumStore.swift`

### AiQo/Resources
- `AiQo/Resources/AiQo.storekit`
- `AiQo/Resources/AiQo_Test.storekit`

### AiQo/Services
- `AiQo/Services/AiQoError.swift`
- `AiQo/Services/DeepLinkRouter.swift`
- `AiQo/Services/NetworkMonitor.swift`
- `AiQo/Services/NotificationType.swift`
- `AiQo/Services/ReferralManager.swift`
- `AiQo/Services/SupabaseArenaService.swift`
- `AiQo/Services/SupabaseService.swift`

### AiQo/Services/Analytics
- `AiQo/Services/Analytics/AnalyticsEvent.swift`
- `AiQo/Services/Analytics/AnalyticsService.swift`

### AiQo/Services/CrashReporting
- `AiQo/Services/CrashReporting/CRASHLYTICS_SETUP.md`
- `AiQo/Services/CrashReporting/CrashReporter.swift`
- `AiQo/Services/CrashReporting/CrashReportingService.swift`

### AiQo/Services/Notifications
- `AiQo/Services/Notifications/AlarmSchedulingService.swift`
- `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift`
- `AiQo/Services/Notifications/InactivityTracker.swift`
- `AiQo/Services/Notifications/MorningHabitOrchestrator.swift`
- `AiQo/Services/Notifications/NotificationCategoryManager.swift`
- `AiQo/Services/Notifications/NotificationRepository.swift`
- `AiQo/Services/Notifications/NotificationService.swift`
- `AiQo/Services/Notifications/PremiumExpiryNotifier.swift`
- `AiQo/Services/Notifications/SmartNotificationManager.swift`

### AiQo/Services/Permissions/HealthKit
- `AiQo/Services/Permissions/HealthKit/HealthKitService.swift`
- `AiQo/Services/Permissions/HealthKit/TodaySummary.swift`

### AiQo/Shared
- `AiQo/Shared/CoinManager.swift`
- `AiQo/Shared/HealthKitManager.swift`
- `AiQo/Shared/LevelSystem.swift`
- `AiQo/Shared/WorkoutSyncCodec.swift`
- `AiQo/Shared/WorkoutSyncModels.swift`

### AiQo/Tribe
- `AiQo/Tribe/TribeModuleComponents.swift`
- `AiQo/Tribe/TribeModuleModels.swift`
- `AiQo/Tribe/TribeModuleViewModel.swift`
- `AiQo/Tribe/TribePulseScreenView.swift`
- `AiQo/Tribe/TribeScreen.swift`
- `AiQo/Tribe/TribeStore.swift`

### AiQo/Tribe/Arena
- `AiQo/Tribe/Arena/TribeArenaView.swift`

### AiQo/Tribe/Galaxy
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

### AiQo/Tribe/Log
- `AiQo/Tribe/Log/TribeLogView.swift`

### AiQo/Tribe/Models
- `AiQo/Tribe/Models/TribeFeatureModels.swift`
- `AiQo/Tribe/Models/TribeModels.swift`

### AiQo/Tribe/Preview
- `AiQo/Tribe/Preview/TribePreviewController.swift`
- `AiQo/Tribe/Preview/TribePreviewData.swift`

### AiQo/Tribe/Repositories
- `AiQo/Tribe/Repositories/TribeRepositories.swift`

### AiQo/Tribe/Stores
- `AiQo/Tribe/Stores/ArenaStore.swift`
- `AiQo/Tribe/Stores/GalaxyStore.swift`
- `AiQo/Tribe/Stores/TribeLogStore.swift`

### AiQo/Tribe/Views
- `AiQo/Tribe/Views/GlobalTribeRadialView.swift`
- `AiQo/Tribe/Views/TribeAtomRingView.swift`
- `AiQo/Tribe/Views/TribeEnergyCoreCard.swift`
- `AiQo/Tribe/Views/TribeHubScreen.swift`
- `AiQo/Tribe/Views/TribeLeaderboardView.swift`

### AiQo/UI
- `AiQo/UI/AccessibilityHelpers.swift`
- `AiQo/UI/AiQoProfileButton.swift`
- `AiQo/UI/AiQoScreenHeader.swift`
- `AiQo/UI/ErrorToastView.swift`
- `AiQo/UI/GlassCardView.swift`
- `AiQo/UI/LegalView.swift`
- `AiQo/UI/OfflineBannerView.swift`
- `AiQo/UI/ReferralSettingsRow.swift`

### AiQo/UI/Purchases
- `AiQo/UI/Purchases/PaywallView.swift`

### AiQo/watch
- `AiQo/watch/ConnectivityDiagnosticsView.swift`

### AiQoTests
- `AiQoTests/IngredientAssetCatalogTests.swift`
- `AiQoTests/IngredientAssetLibraryTests.swift`
- `AiQoTests/PurchasesTests.swift`
- `AiQoTests/QuestEvaluatorTests.swift`
- `AiQoTests/SmartWakeManagerTests.swift`

### AiQoWatch Watch App
- `AiQoWatch Watch App/ActivityRingsView.swift`
- `AiQoWatch Watch App/AiQoWatch Watch App.entitlements`
- `AiQoWatch Watch App/AiQoWatchApp.swift`
- `AiQoWatch Watch App/ControlsView.swift`
- `AiQoWatch Watch App/DebugPrint.swift`
- `AiQoWatch Watch App/ElapsedTimeView.swift`
- `AiQoWatch Watch App/MetricsView.swift`
- `AiQoWatch Watch App/SessionPagingView.swift`
- `AiQoWatch Watch App/StartView.swift`
- `AiQoWatch Watch App/SummaryView.swift`
- `AiQoWatch Watch App/WatchConnectivityManager.swift`
- `AiQoWatch Watch App/WorkoutManager.swift`
- `AiQoWatch Watch App/WorkoutNotificationCenter.swift`
- `AiQoWatch Watch App/WorkoutNotificationController.swift`
- `AiQoWatch Watch App/WorkoutNotificationView.swift`

### AiQoWatch Watch App/Design
- `AiQoWatch Watch App/Design/WatchDesignSystem.swift`

### AiQoWatch Watch App/Models
- `AiQoWatch Watch App/Models/WatchWorkoutType.swift`

### AiQoWatch Watch App/Services
- `AiQoWatch Watch App/Services/WatchConnectivityService.swift`
- `AiQoWatch Watch App/Services/WatchHealthKitManager.swift`
- `AiQoWatch Watch App/Services/WatchWorkoutManager.swift`

### AiQoWatch Watch App/Shared
- `AiQoWatch Watch App/Shared/WorkoutSyncCodec.swift`
- `AiQoWatch Watch App/Shared/WorkoutSyncModels.swift`

### AiQoWatch Watch App/Views
- `AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift`
- `AiQoWatch Watch App/Views/WatchHomeView.swift`
- `AiQoWatch Watch App/Views/WatchWorkoutListView.swift`
- `AiQoWatch Watch App/Views/WatchWorkoutSummaryView.swift`

### AiQoWatch Watch AppTests
- `AiQoWatch Watch AppTests/AiQoWatch_Watch_AppTests.swift`

### AiQoWatch Watch AppUITests
- `AiQoWatch Watch AppUITests/AiQoWatch_Watch_AppUITests.swift`
- `AiQoWatch Watch AppUITests/AiQoWatch_Watch_AppUITestsLaunchTests.swift`

### AiQoWatchWidget
- `AiQoWatchWidget/AiQoWatchWidget.swift`
- `AiQoWatchWidget/AiQoWatchWidgetBundle.swift`
- `AiQoWatchWidget/AiQoWatchWidgetProvider.swift`
- `AiQoWatchWidget/Info.plist`

### AiQoWidget
- `AiQoWidget/AiQoEntry.swift`
- `AiQoWidget/AiQoProvider.swift`
- `AiQoWidget/AiQoRingsFaceWidget.swift`
- `AiQoWidget/AiQoSharedStore.swift`
- `AiQoWidget/AiQoWatchFaceWidget.swift`
- `AiQoWidget/AiQoWidget.swift`
- `AiQoWidget/AiQoWidgetBundle.swift`
- `AiQoWidget/AiQoWidgetLiveActivity.swift`
- `AiQoWidget/AiQoWidgetView.swift`
- `AiQoWidget/Info.plist`

### Configuration
- `Configuration/AiQo.xcconfig`
- `Configuration/SETUP.md`
- `Configuration/Secrets.template.xcconfig`
- `Configuration/Secrets.xcconfig`

### Configuration/ExternalSymbols/SpotifyiOS.framework.dSYM/Contents
- `Configuration/ExternalSymbols/SpotifyiOS.framework.dSYM/Contents/Info.plist`

### Additional Support Files Read Outside the Phase 1 Glob
### AiQo
- `AiQo/PrivacyInfo.xcprivacy`

### AiQo.xcodeproj
- `AiQo.xcodeproj/project.pbxproj`

### AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
- `AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

### AiQo/Frameworks/SpotifyiOS.framework
- `AiQo/Frameworks/SpotifyiOS.framework/PrivacyInfo.xcprivacy`

### AiQo/Resources
- `AiQo/Resources/Prompts.xcstrings`

### AiQo/Resources/Assets.xcassets
- `AiQo/Resources/Assets.xcassets/Contents.json`

### AiQo/Resources/Assets.xcassets/AppIcon.appiconset
- `AiQo/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

### AiQo/Resources/ar.lproj
- `AiQo/Resources/ar.lproj/InfoPlist.strings`
- `AiQo/Resources/ar.lproj/Localizable.strings`

### AiQo/Resources/en.lproj
- `AiQo/Resources/en.lproj/InfoPlist.strings`
- `AiQo/Resources/en.lproj/Localizable.strings`

### AiQoWatch Watch App/Assets.xcassets
- `AiQoWatch Watch App/Assets.xcassets/Contents.json`

### AiQoWatch Watch App/Assets.xcassets/AppIcon.appiconset
- `AiQoWatch Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json`

### AiQoWatchWidget/Assets.xcassets
- `AiQoWatchWidget/Assets.xcassets/Contents.json`

### AiQoWidget/Assets.xcassets
- `AiQoWidget/Assets.xcassets/Contents.json`

### AiQoWidget/Assets.xcassets/AppIcon.appiconset
- `AiQoWidget/Assets.xcassets/AppIcon.appiconset/Contents.json`

### Asset Catalog Sets Inventoried By Name
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
- `AiQoWatch Watch App/Assets.xcassets/AccentColor.colorset`
- `AiQoWatch Watch App/Assets.xcassets/AiQoLogo.imageset`
- `AiQoWatch Watch App/Assets.xcassets/AppIcon.appiconset`
- `AiQoWidget/Assets.xcassets/AccentColor.colorset`
- `AiQoWidget/Assets.xcassets/AppIcon.appiconset`
- `AiQoWidget/Assets.xcassets/WidgetBackground.colorset`
- `AiQoWatchWidget/Assets.xcassets/AiQoLogo.imageset`
