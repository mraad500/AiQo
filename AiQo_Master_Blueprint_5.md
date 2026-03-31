# AiQo Master Blueprint 5

- Scan scope: 476 discovery-listed files plus 9 supporting metadata/localization files = 485 files scanned.
- Generation rule: every prose claim below is anchored to a scanned source file and line number; raw discovery outputs are pasted verbatim where requested.

# SECTION 1 — App Identity & Philosophy
- The shipped app display name is `AiQo`. [`AiQo.xcodeproj/project.pbxproj:1057`]
- The main iOS bundle identifier is `com.mraad500.aiqo`. [`AiQo.xcodeproj/project.pbxproj:1089`]
- The marketing version is `1.0` and the build number is `1`. [`AiQo.xcodeproj/project.pbxproj:1082`; `AiQo.xcodeproj/project.pbxproj:1048`]
- The main app target deploys to iOS 26.2, the watch app target deploys to watchOS 26.2, and project build settings pin Swift 5.0. [`AiQo.xcodeproj/project.pbxproj:1077`; `AiQo.xcodeproj/project.pbxproj:1356`; `AiQo.xcodeproj/project.pbxproj:1100`]
- Privacy-first behavior is explicit in the Captain cloud sanitizer: it redacts PII, normalizes user names, truncates cloud conversations, buckets health data, and strips EXIF/GPS from kitchen images. [`AiQo/Features/Captain/PrivacySanitizer.swift:6`; `AiQo/Features/Captain/PrivacySanitizer.swift:11`; `AiQo/Features/Captain/PrivacySanitizer.swift:13`]
- Arabic-first behavior is explicit: `AppSettingsStore` defaults to Arabic and `CaptainPromptBuilder` locks Arabic replies to Iraqi dialect in the Arabic path. [`AiQo/Core/AppSettingsStore.swift:23`; `AiQo/Features/Captain/CaptainPromptBuilder.swift:88`]
- Circadian-aware coaching is explicit through `BioTimePhase` and the dedicated circadian-tone layer in `CaptainPromptBuilder`. [`AiQo/Features/Captain/CaptainContextBuilder.swift:6`; `AiQo/Features/Captain/CaptainPromptBuilder.swift:8`]
- “Zero Digital Pollution” is explicitly named in the Captain chat-history trimming policy. [`AiQo/Core/MemoryStore.swift:410`]
- Captain Hamoudi is defined as an Iraqi coach / older-brother persona with separate English and Iraqi-Arabic identity blocks. [`AiQo/Features/Captain/CaptainPromptBuilder.swift:34`; `AiQo/Features/Captain/CaptainPromptBuilder.swift:84`]
- Supported app languages are Arabic (`ar`) and English (`en`). [`AiQo/Core/AppSettingsStore.swift:4`; `AiQo/Core/AppSettingsStore.swift:5`]
- RTL layout is deliberate across app and watch surfaces, with explicit `.layoutDirection` overrides in multiple root-level views. [`AiQo/App/MainTabScreen.swift:69`; `AiQo/App/LoginViewController.swift:81`; `AiQo/App/ProfileSetupView.swift:137`; `AiQoWatch Watch App/Views/WatchHomeView.swift:18`]
- Feature names are intentionally kept in English in Arabic Captain replies: `My Vibe`, `Zone 2`, `Alchemy Kitchen`, `Arena`, and `Tribe` are explicit exceptions. [`AiQo/Features/Captain/CaptainPromptBuilder.swift:90`]

# SECTION 2 — Tech Stack & Dependencies
- Swift is the primary language; SwiftUI and UIKit coexist, while Combine and Observation (`@Observable`) are both used for state. [`AiQo/App/AppDelegate.swift:1`; `AiQo/Features/First screen/LegacyCalculationViewController.swift:3`; `AiQo/Core/MemoryStore.swift:7`; `AiQo/Premium/AccessManager.swift:2`]
- State patterns in active use include `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, and `@Observable`. [`AiQo/Premium/AccessManager.swift:5`; `AiQo/Premium/AccessManager.swift:8`; `AiQo/App/LoginViewController.swift:9`; `AiQo/Features/Home/StreakBadgeView.swift:5`; `AiQo/Core/MemoryStore.swift:7`]
- Persistence is hybrid: SwiftData, UserDefaults / AppStorage, Keychain, JSONL files, and App Group defaults are all present. [`AiQo/App/AppDelegate.swift:37`; `AiQo/Premium/FreeTrialManager.swift:134`; `AiQo/Services/Analytics/AnalyticsService.swift:138`; `AiQo/Services/CrashReporting/CrashReporter.swift:19`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:164`]
- The only embedded binary framework found in project settings is `AiQo/Frameworks/SpotifyiOS.framework`. [`AiQo.xcodeproj/project.pbxproj:22`; `AiQo.xcodeproj/project.pbxproj:154`]
- External endpoints actively used in code include Gemini generateContent endpoints, ElevenLabs TTS, the Supabase receipt-validation edge function, and local/LAN Captain Arabic bridge endpoints. [`AiQo/Info.plist:66`; `AiQo/Core/CaptainVoiceAPI.swift:8`; `AiQo/Core/Purchases/ReceiptValidator.swift:10`; `AiQo.xcodeproj/project.pbxproj:1045`]
- Secrets handling is externalized through `AiQo.xcconfig` plus optional `Secrets.xcconfig`, with a template listing the required keys. [`Configuration/AiQo.xcconfig:8`; `Configuration/AiQo.xcconfig:11`; `Configuration/Secrets.template.xcconfig:4`]
## SPM Dependencies
- `sdwebimage` resolves from `https://github.com/SDWebImage/SDWebImage.git` at version `5.21.6`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:5`]
- `sdwebimageswiftui` resolves from `https://github.com/SDWebImage/SDWebImageSwiftUI` at version `3.1.4`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:14`]
- `supabase-swift` resolves from `https://github.com/supabase-community/supabase-swift` at version `2.36.0`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:23`]
- `swift-asn1` resolves from `https://github.com/apple/swift-asn1.git` at version `1.5.0`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:32`]
- `swift-clocks` resolves from `https://github.com/pointfreeco/swift-clocks` at version `1.0.6`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:41`]
- `swift-concurrency-extras` resolves from `https://github.com/pointfreeco/swift-concurrency-extras` at version `1.3.2`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:50`]
- `swift-crypto` resolves from `https://github.com/apple/swift-crypto.git` at version `4.2.0`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:59`]
- `swift-http-types` resolves from `https://github.com/apple/swift-http-types.git` at version `1.4.0`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:68`]
- `swift-system` resolves from `https://github.com/apple/swift-system.git` at version `1.6.4`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:77`]
- `xctest-dynamic-overlay` resolves from `https://github.com/pointfreeco/xctest-dynamic-overlay` at version `1.7.0`. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:86`]

## Imported Apple Frameworks (Counts)
- `AVFoundation` appears 14 time(s) in the scanned Swift import graph. [`AiQo/Core/AiQoAudioManager.swift:1`]
- `AVKit` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Features/Home/VibeControlSheet.swift:3`]
- `ActivityKit` appears 3 time(s) in the scanned Swift import graph. [`AiQo/Features/Gym/WorkoutLiveActivityManager.swift:2`]
- `AlarmKit` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Services/Notifications/AlarmSchedulingService.swift:4`]
- `AppIntents` appears 1 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:8`]
- `AuthenticationServices` appears 1 time(s) in the scanned Swift import graph. [`AiQo/App/LoginViewController.swift:2`]
- `BackgroundTasks` appears 2 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:5`]
- `Charts` appears 2 time(s) in the scanned Swift import graph. [`AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:3`]
- `Combine` appears 76 time(s) in the scanned Swift import graph. [`AiQo/App/AppRootManager.swift:2`]
- `CoreGraphics` appears 5 time(s) in the scanned Swift import graph. [`AiQo/DesignSystem/AiQoTokens.swift:1`]
- `CoreMedia` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:3`]
- `CoreSpotlight` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Core/SiriShortcutsManager.swift:117`]
- `CryptoKit` appears 2 time(s) in the scanned Swift import graph. [`AiQo/App/LoginViewController.swift:3`]
- `DeviceActivity` appears 2 time(s) in the scanned Swift import graph. [`AiQo/AiQoActivityNames.swift:1`]
- `FamilyControls` appears 2 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:6`]
- `Foundation` appears 180 time(s) in the scanned Swift import graph. [`AiQo/App/AppRootManager.swift:1`]
- `FoundationModels` appears 5 time(s) in the scanned Swift import graph. [`AiQo/Core/CaptainVoiceService.swift:7`]
- `HealthKit` appears 36 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:9`]
- `ImageIO` appears 2 time(s) in the scanned Swift import graph. [`AiQo/Features/Captain/PrivacySanitizer.swift:3`]
- `Intents` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Core/SiriShortcutsManager.swift:2`]
- `ManagedSettings` appears 1 time(s) in the scanned Swift import graph. [`AiQo/ProtectionModel.swift:4`]
- `MediaPlayer` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Core/VibeAudioEngine.swift:3`]
- `MessageUI` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Features/Profile/ProfileScreen.swift:3`]
- `Network` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Services/NetworkMonitor.swift:2`]
- `ObjectiveC` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Core/Localization/Bundle+Language.swift:2`]
- `Observation` appears 2 time(s) in the scanned Swift import graph. [`AiQo/Features/Kitchen/KitchenViewModel.swift:4`]
- `PDFKit` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Features/DataExport/HealthDataExporter.swift:3`]
- `PhotosUI` appears 2 time(s) in the scanned Swift import graph. [`AiQo/Features/Profile/ProfileScreen.swift:2`]
- `Security` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Premium/FreeTrialManager.swift:2`]
- `Speech` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Features/Gym/HandsFreeZone2Manager.swift:2`]
- `StoreKit` appears 5 time(s) in the scanned Swift import graph. [`AiQo/Core/Purchases/PurchaseManager.swift:4`]
- `SwiftData` appears 25 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:2`]
- `SwiftUI` appears 232 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:1`]
- `UIKit` appears 67 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:3`]
- `UniformTypeIdentifiers` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Features/Captain/PrivacySanitizer.swift:4`]
- `UserNotifications` appears 12 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:4`]
- `Vision` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:6`]
- `WatchConnectivity` appears 6 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:7`]
- `WatchKit` appears 7 time(s) in the scanned Swift import graph. [`AiQoWatch Watch App/ActivityRingsView.swift:12`]
- `WebKit` appears 1 time(s) in the scanned Swift import graph. [`AiQo/Features/Gym/SpotifyWebView.swift:3`]
- `WidgetKit` appears 14 time(s) in the scanned Swift import graph. [`AiQo/App/AppDelegate.swift:10`]
- `os` appears 1 time(s) in the scanned Swift import graph. [`AiQo/PhoneConnectivityManager.swift:10`]
- `os.log` appears 24 time(s) in the scanned Swift import graph. [`AiQo/Core/CaptainVoiceCache.swift:3`]

## Raw Import Occurrence Inventory
- `DeviceActivity` — `AiQo/AiQoActivityNames.swift:1`
- `SwiftUI` — `AiQo/App/AppDelegate.swift:1`
- `SwiftData` — `AiQo/App/AppDelegate.swift:2`
- `UIKit` — `AiQo/App/AppDelegate.swift:3`
- `UserNotifications` — `AiQo/App/AppDelegate.swift:4`
- `BackgroundTasks` — `AiQo/App/AppDelegate.swift:5`
- `FamilyControls` — `AiQo/App/AppDelegate.swift:6`
- `WatchConnectivity` — `AiQo/App/AppDelegate.swift:7`
- `AppIntents` — `AiQo/App/AppDelegate.swift:8`
- `HealthKit` — `AiQo/App/AppDelegate.swift:9`
- `WidgetKit` — `AiQo/App/AppDelegate.swift:10`
- `Foundation` — `AiQo/App/AppRootManager.swift:1`
- `Combine` — `AiQo/App/AppRootManager.swift:2`
- `SwiftUI` — `AiQo/App/AuthFlowUI.swift:1`
- `UIKit` — `AiQo/App/AuthFlowUI.swift:2`
- `SwiftUI` — `AiQo/App/LanguageSelectionView.swift:1`
- `SwiftUI` — `AiQo/App/LoginViewController.swift:1`
- `AuthenticationServices` — `AiQo/App/LoginViewController.swift:2`
- `CryptoKit` — `AiQo/App/LoginViewController.swift:3`
- `Supabase` — `AiQo/App/LoginViewController.swift:4`
- `Auth` — `AiQo/App/LoginViewController.swift:5`
- `Combine` — `AiQo/App/LoginViewController.swift:6`
- `Foundation` — `AiQo/App/MainTabRouter.swift:1`
- `SwiftUI` — `AiQo/App/MainTabRouter.swift:2`
- `Combine` — `AiQo/App/MainTabRouter.swift:3`
- `SwiftUI` — `AiQo/App/MainTabScreen.swift:1`
- `UIKit` — `AiQo/App/MainTabScreen.swift:2`
- `Combine` — `AiQo/App/MainTabScreen.swift:3`
- `Foundation` — `AiQo/App/MealModels.swift:1`
- `SwiftUI` — `AiQo/App/ProfileSetupView.swift:1`
- `SwiftUI` — `AiQo/App/SceneDelegate.swift:1`
- `SwiftData` — `AiQo/App/SceneDelegate.swift:2`
- `Supabase` — `AiQo/App/SceneDelegate.swift:3`
- `Auth` — `AiQo/App/SceneDelegate.swift:4`
- `HealthKit` — `AiQo/App/SceneDelegate.swift:5`
- `Combine` — `AiQo/App/SceneDelegate.swift:6`
- `Foundation` — `AiQo/AppGroupKeys.swift:1`
- `SwiftUI` — `AiQo/Core/AiQoAccessibility.swift:1`
- `AVFoundation` — `AiQo/Core/AiQoAudioManager.swift:1`
- `Foundation` — `AiQo/Core/AiQoAudioManager.swift:2`
- `UIKit` — `AiQo/Core/AiQoAudioManager.swift:3`
- `Combine` — `AiQo/Core/AiQoAudioManager.swift:4`
- `SwiftUI` — `AiQo/Core/AppSettingsScreen.swift:1`
- `UserNotifications` — `AiQo/Core/AppSettingsScreen.swift:2`
- `Supabase` — `AiQo/Core/AppSettingsScreen.swift:3`
- `Foundation` — `AiQo/Core/AppSettingsStore.swift:1`
- `Foundation` — `AiQo/Core/ArabicNumberFormatter.swift:1`
- `Foundation` — `AiQo/Core/CaptainMemory.swift:1`
- `SwiftData` — `AiQo/Core/CaptainMemory.swift:2`
- `SwiftUI` — `AiQo/Core/CaptainMemorySettingsView.swift:1`
- `Foundation` — `AiQo/Core/CaptainVoiceAPI.swift:1`
- `Foundation` — `AiQo/Core/CaptainVoiceCache.swift:1`
- `CryptoKit` — `AiQo/Core/CaptainVoiceCache.swift:2`
- `os.log` — `AiQo/Core/CaptainVoiceCache.swift:3`
- `AVFoundation` — `AiQo/Core/CaptainVoiceService.swift:1`
- `Foundation` — `AiQo/Core/CaptainVoiceService.swift:2`
- `os.log` — `AiQo/Core/CaptainVoiceService.swift:3`
- `Combine` — `AiQo/Core/CaptainVoiceService.swift:4`
- `FoundationModels` — `AiQo/Core/CaptainVoiceService.swift:7`
- `UIKit` — `AiQo/Core/Colors.swift:1`
- `SwiftUI` — `AiQo/Core/Colors.swift:27`
- `Foundation` — `AiQo/Core/Constants.swift:1`
- `os.log` — `AiQo/Core/Constants.swift:2`
- `Foundation` — `AiQo/Core/DailyGoals.swift:1`
- `SwiftUI` — `AiQo/Core/DeveloperPanelView.swift:1`
- `UIKit` — `AiQo/Core/HapticEngine.swift:1`
- `Foundation` — `AiQo/Core/HealthKitMemoryBridge.swift:1`
- `HealthKit` — `AiQo/Core/HealthKitMemoryBridge.swift:2`
- `os.log` — `AiQo/Core/HealthKitMemoryBridge.swift:3`
- `Foundation` — `AiQo/Core/Localization/Bundle+Language.swift:1`
- `ObjectiveC` — `AiQo/Core/Localization/Bundle+Language.swift:2`
- `Foundation` — `AiQo/Core/Localization/LocalizationManager.swift:1`
- `Foundation` — `AiQo/Core/MemoryExtractor.swift:1`
- `os.log` — `AiQo/Core/MemoryExtractor.swift:2`
- `Foundation` — `AiQo/Core/MemoryStore.swift:1`
- `SwiftData` — `AiQo/Core/MemoryStore.swift:2`
- `os.log` — `AiQo/Core/MemoryStore.swift:3`
- `Foundation` — `AiQo/Core/Models/ActivityNotification.swift:1`
- `Foundation` — `AiQo/Core/Models/LevelStore.swift:1`
- `SwiftUI` — `AiQo/Core/Models/LevelStore.swift:2`
- `Combine` — `AiQo/Core/Models/LevelStore.swift:3`
- `Foundation` — `AiQo/Core/Models/NotificationPreferencesStore.swift:1`
- `Foundation` — `AiQo/Core/Purchases/EntitlementStore.swift:1`
- `Combine` — `AiQo/Core/Purchases/EntitlementStore.swift:2`
- `Foundation` — `AiQo/Core/Purchases/PurchaseManager.swift:1`
- `os.log` — `AiQo/Core/Purchases/PurchaseManager.swift:2`
- `Combine` — `AiQo/Core/Purchases/PurchaseManager.swift:3`
- `StoreKit` — `AiQo/Core/Purchases/PurchaseManager.swift:4`
- `Foundation` — `AiQo/Core/Purchases/ReceiptValidator.swift:1`
- `StoreKit` — `AiQo/Core/Purchases/ReceiptValidator.swift:2`
- `Foundation` — `AiQo/Core/Purchases/SubscriptionProductIDs.swift:1`
- `Foundation` — `AiQo/Core/Purchases/SubscriptionTier.swift:1`
- `Foundation` — `AiQo/Core/SiriShortcutsManager.swift:1`
- `Intents` — `AiQo/Core/SiriShortcutsManager.swift:2`
- `UIKit` — `AiQo/Core/SiriShortcutsManager.swift:3`
- `CoreSpotlight` — `AiQo/Core/SiriShortcutsManager.swift:117`
- `Foundation` — `AiQo/Core/SmartNotificationScheduler.swift:1`
- `UserNotifications` — `AiQo/Core/SmartNotificationScheduler.swift:2`
- `Foundation` — `AiQo/Core/SpotifyVibeManager.swift:1`
- `UIKit` — `AiQo/Core/SpotifyVibeManager.swift:2`
- `Combine` — `AiQo/Core/SpotifyVibeManager.swift:3`
- `SpotifyiOS` — `AiQo/Core/SpotifyVibeManager.swift:6`
- `Foundation` — `AiQo/Core/StreakManager.swift:1`
- `Combine` — `AiQo/Core/StreakManager.swift:2`
- `Foundation` — `AiQo/Core/UserProfileStore.swift:1`
- `UIKit` — `AiQo/Core/UserProfileStore.swift:2`
- `Foundation` — `AiQo/Core/Utilities/ConnectivityDebugProviding.swift:1`
- `Combine` — `AiQo/Core/Utilities/ConnectivityDebugProviding.swift:2`
- `Foundation` — `AiQo/Core/VibeAudioEngine.swift:1`
- `AVFoundation` — `AiQo/Core/VibeAudioEngine.swift:2`
- `MediaPlayer` — `AiQo/Core/VibeAudioEngine.swift:3`
- `UIKit` — `AiQo/Core/VibeAudioEngine.swift:4`
- `Combine` — `AiQo/Core/VibeAudioEngine.swift:5`
- `SwiftUI` — `AiQo/DesignSystem/AiQoColors.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/AiQoTheme.swift:1`
- `UIKit` — `AiQo/DesignSystem/AiQoTheme.swift:2`
- `CoreGraphics` — `AiQo/DesignSystem/AiQoTokens.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Components/AiQoBottomCTA.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Components/AiQoCard.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Components/AiQoChoiceGrid.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Components/AiQoPillSegment.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Components/AiQoPlatformPicker.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Components/AiQoSkeletonView.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Components/StatefulPreviewWrapper.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Modifiers/AiQoShadow.swift:1`
- `SwiftUI` — `AiQo/DesignSystem/Modifiers/AiQoSheetStyle.swift:1`
- `Foundation` — `AiQo/Features/Captain/AiQoPromptManager.swift:1`
- `os.log` — `AiQo/Features/Captain/AiQoPromptManager.swift:2`
- `Foundation` — `AiQo/Features/Captain/BrainOrchestrator.swift:1`
- `os.log` — `AiQo/Features/Captain/BrainOrchestrator.swift:2`
- `SwiftUI` — `AiQo/Features/Captain/CaptainChatView.swift:1`
- `UIKit` — `AiQo/Features/Captain/CaptainChatView.swift:2`
- `Foundation` — `AiQo/Features/Captain/CaptainContextBuilder.swift:1`
- `Foundation` — `AiQo/Features/Captain/CaptainFallbackPolicy.swift:1`
- `Foundation` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:1`
- `HealthKit` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:2`
- `os.log` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:3`
- `FoundationModels` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:6`
- `Foundation` — `AiQo/Features/Captain/CaptainModels.swift:1`
- `SwiftData` — `AiQo/Features/Captain/CaptainModels.swift:2`
- `Foundation` — `AiQo/Features/Captain/CaptainNotificationRouting.swift:1`
- `Combine` — `AiQo/Features/Captain/CaptainNotificationRouting.swift:2`
- `Foundation` — `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:1`
- `HealthKit` — `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:2`
- `os.log` — `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:3`
- `FoundationModels` — `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:6`
- `Foundation` — `AiQo/Features/Captain/CaptainPersonaBuilder.swift:1`
- `Foundation` — `AiQo/Features/Captain/CaptainPromptBuilder.swift:1`
- `SwiftUI` — `AiQo/Features/Captain/CaptainScreen.swift:8`
- `Combine` — `AiQo/Features/Captain/CaptainScreen.swift:9`
- `Foundation` — `AiQo/Features/Captain/CaptainViewModel.swift:1`
- `SwiftUI` — `AiQo/Features/Captain/CaptainViewModel.swift:2`
- `UIKit` — `AiQo/Features/Captain/CaptainViewModel.swift:3`
- `Combine` — `AiQo/Features/Captain/CaptainViewModel.swift:4`
- `SwiftUI` — `AiQo/Features/Captain/ChatHistoryView.swift:1`
- `Foundation` — `AiQo/Features/Captain/CloudBrainService.swift:1`
- `Foundation` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:1`
- `os.log` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:2`
- `SwiftUI` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:3`
- `Combine` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:4`
- `Foundation` — `AiQo/Features/Captain/CoachBrainTranslationConfig.swift:1`
- `os.log` — `AiQo/Features/Captain/CoachBrainTranslationConfig.swift:2`
- `Foundation` — `AiQo/Features/Captain/HybridBrainService.swift:1`
- `os.log` — `AiQo/Features/Captain/HybridBrainService.swift:2`
- `Foundation` — `AiQo/Features/Captain/LLMJSONParser.swift:1`
- `Foundation` — `AiQo/Features/Captain/LocalBrainService.swift:1`
- `Foundation` — `AiQo/Features/Captain/LocalIntelligenceService.swift:1`
- `SwiftUI` — `AiQo/Features/Captain/MessageBubble.swift:1`
- `CoreGraphics` — `AiQo/Features/Captain/PrivacySanitizer.swift:1`
- `Foundation` — `AiQo/Features/Captain/PrivacySanitizer.swift:2`
- `ImageIO` — `AiQo/Features/Captain/PrivacySanitizer.swift:3`
- `UniformTypeIdentifiers` — `AiQo/Features/Captain/PrivacySanitizer.swift:4`
- `Foundation` — `AiQo/Features/Captain/PromptRouter.swift:1`
- `Foundation` — `AiQo/Features/Captain/ScreenContext.swift:1`
- `Foundation` — `AiQo/Features/DataExport/HealthDataExporter.swift:1`
- `UIKit` — `AiQo/Features/DataExport/HealthDataExporter.swift:2`
- `PDFKit` — `AiQo/Features/DataExport/HealthDataExporter.swift:3`
- `SwiftUI` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:1`
- `HealthKit` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:2`
- `UIKit` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:3`
- `Combine` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:4`
- `SwiftUI` — `AiQo/Features/Gym/ActiveRecoveryView.swift:1`
- `Combine` — `AiQo/Features/Gym/ActiveRecoveryView.swift:2`
- `Foundation` — `AiQo/Features/Gym/AudioCoachManager.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/CinematicGrindCardView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/CinematicGrindViews.swift:1`
- `UIKit` — `AiQo/Features/Gym/CinematicGrindViews.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Club/Body/BodyView.swift:1`
- `AVFoundation` — `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift:1`
- `Foundation` — `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift:2`
- `UIKit` — `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift:3`
- `Combine` — `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift:4`
- `SwiftUI` — `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift:1`
- `UIKit` — `AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Club/Challenges/ChallengesView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Club/ClubRootView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift:1`
- `UIKit` — `AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Club/Components/RailScrollOffsetPreferenceKey.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Club/Components/RightSideRailView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift:1`
- `UIKit` — `AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Club/Components/SegmentedTabs.swift:1`
- `UIKit` — `AiQo/Features/Gym/Club/Components/SegmentedTabs.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift:1`
- `UIKit` — `AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Club/Impact/ImpactAchievementsView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Club/Impact/ImpactSummaryView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Club/Plan/PlanView.swift:1`
- `SwiftData` — `AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/ExercisesView.swift:1`
- `UIKit` — `AiQo/Features/Gym/ExercisesView.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/GuinnessEncyclopediaView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/GymViewController.swift:1`
- `AVFoundation` — `AiQo/Features/Gym/HandsFreeZone2Manager.swift:1`
- `Speech` — `AiQo/Features/Gym/HandsFreeZone2Manager.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/HandsFreeZone2Manager.swift:3`
- `os.log` — `AiQo/Features/Gym/HandsFreeZone2Manager.swift:4`
- `Combine` — `AiQo/Features/Gym/HandsFreeZone2Manager.swift:5`
- `SwiftUI` — `AiQo/Features/Gym/HeartView.swift:1`
- `Foundation` — `AiQo/Features/Gym/L10n.swift:1`
- `UIKit` — `AiQo/Features/Gym/LiveMetricsHeader.swift:1`
- `AVFoundation` — `AiQo/Features/Gym/LiveWorkoutSession.swift:6`
- `Foundation` — `AiQo/Features/Gym/LiveWorkoutSession.swift:7`
- `HealthKit` — `AiQo/Features/Gym/LiveWorkoutSession.swift:8`
- `SwiftUI` — `AiQo/Features/Gym/LiveWorkoutSession.swift:9`
- `UIKit` — `AiQo/Features/Gym/LiveWorkoutSession.swift:10`
- `Combine` — `AiQo/Features/Gym/LiveWorkoutSession.swift:11`
- `Foundation` — `AiQo/Features/Gym/Models/GymExercise.swift:1`
- `HealthKit` — `AiQo/Features/Gym/Models/GymExercise.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Models/GymExercise.swift:3`
- `SwiftUI` — `AiQo/Features/Gym/MyPlanViewController.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/OriginalWorkoutCardView.swift:3`
- `UIKit` — `AiQo/Features/Gym/OriginalWorkoutCardView.swift:4`
- `SwiftUI` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:1`
- `HealthKit` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:2`
- `Charts` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:3`
- `FoundationModels` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:6`
- `Combine` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:9`
- `Foundation` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:1`
- `HealthKit` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:2`
- `Foundation` — `AiQo/Features/Gym/QuestKit/QuestDefinitions.swift:1`
- `Foundation` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:2`
- `UIKit` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:3`
- `Combine` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:4`
- `Foundation` — `AiQo/Features/Gym/QuestKit/QuestEvaluator.swift:1`
- `Foundation` — `AiQo/Features/Gym/QuestKit/QuestFormatting.swift:1`
- `Foundation` — `AiQo/Features/Gym/QuestKit/QuestKitModels.swift:1`
- `Foundation` — `AiQo/Features/Gym/QuestKit/QuestProgressStore.swift:1`
- `Foundation` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:1`
- `SwiftData` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:2`
- `Foundation` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:1`
- `SwiftData` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:2`
- `AVFoundation` — `AiQo/Features/Gym/QuestKit/Views/QuestCameraPermissionGateView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/QuestKit/Views/QuestCameraPermissionGateView.swift:2`
- `UIKit` — `AiQo/Features/Gym/QuestKit/Views/QuestCameraPermissionGateView.swift:3`
- `SwiftUI` — `AiQo/Features/Gym/QuestKit/Views/QuestDebugView.swift:2`
- `AVFoundation` — `AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift:2`
- `UIKit` — `AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift:3`
- `Foundation` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:1`
- `Foundation` — `AiQo/Features/Gym/Quests/Models/ChallengeStage.swift:1`
- `Foundation` — `AiQo/Features/Gym/Quests/Models/HelpStrangersModels.swift:1`
- `Foundation` — `AiQo/Features/Gym/Quests/Models/WinRecord.swift:1`
- `Foundation` — `AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift:1`
- `Combine` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:1`
- `Foundation` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:2`
- `UIKit` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:3`
- `Foundation` — `AiQo/Features/Gym/Quests/Store/WinsStore.swift:1`
- `Combine` — `AiQo/Features/Gym/Quests/Store/WinsStore.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/ChallengeCard.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/ChallengeDetailView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/ChallengeRewardSheet.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/ChallengeRunView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/HelpStrangersBottomSheet.swift:1`
- `UIKit` — `AiQo/Features/Gym/Quests/Views/HelpStrangersBottomSheet.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/QuestCard.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift:1`
- `UIKit` — `AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift:1`
- `AVFoundation` — `AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift:2`
- `Combine` — `AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift:3`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift:1`
- `UIKit` — `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift:2`
- `Combine` — `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift:3`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/QuestWinsGridView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/QuestsView.swift:1`
- `UIKit` — `AiQo/Features/Gym/Quests/Views/QuestsView.swift:2`
- `Combine` — `AiQo/Features/Gym/Quests/Views/QuestsView.swift:3`
- `SwiftUI` — `AiQo/Features/Gym/Quests/Views/StageSelectorBar.swift:1`
- `AVFoundation` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift:1`
- `Combine` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift:2`
- `Foundation` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift:3`
- `AVFoundation` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift:2`
- `UIKit` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift:3`
- `AVFoundation` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:1`
- `Combine` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:2`
- `CoreGraphics` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:3`
- `Foundation` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:4`
- `ImageIO` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:5`
- `Vision` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:6`
- `SwiftUI` — `AiQo/Features/Gym/RecapViewController.swift:1`
- `HealthKit` — `AiQo/Features/Gym/RecapViewController.swift:2`
- `Combine` — `AiQo/Features/Gym/RecapViewController.swift:3`
- `SwiftUI` — `AiQo/Features/Gym/RewardsViewController.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/ShimmeringPlaceholder.swift:1`
- `UIKit` — `AiQo/Features/Gym/SoftGlassCardView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/SpotifyWebView.swift:1`
- `UIKit` — `AiQo/Features/Gym/SpotifyWebView.swift:2`
- `WebKit` — `AiQo/Features/Gym/SpotifyWebView.swift:3`
- `SwiftUI` — `AiQo/Features/Gym/SpotifyWorkoutPlayerView.swift:1`
- `UIKit` — `AiQo/Features/Gym/SpotifyWorkoutPlayerView.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/T/SpinWheelView.swift:8`
- `Foundation` — `AiQo/Features/Gym/T/WheelTypes.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/T/WorkoutTheme.swift:6`
- `SwiftUI` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:1`
- `Combine` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/WatchConnectionStatusButton.swift:1`
- `Foundation` — `AiQo/Features/Gym/WatchConnectivityService.swift:1`
- `Combine` — `AiQo/Features/Gym/WatchConnectivityService.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/WinsViewController.swift:1`
- `Foundation` — `AiQo/Features/Gym/WorkoutLiveActivityManager.swift:1`
- `ActivityKit` — `AiQo/Features/Gym/WorkoutLiveActivityManager.swift:2`
- `SwiftUI` — `AiQo/Features/Gym/WorkoutSessionScreen.swift.swift:6`
- `HealthKit` — `AiQo/Features/Gym/WorkoutSessionScreen.swift.swift:7`
- `SwiftUI` — `AiQo/Features/Gym/WorkoutSessionSheetView.swift:1`
- `SwiftUI` — `AiQo/Features/Gym/WorkoutSessionViewModel.swift:1`
- `Combine` — `AiQo/Features/Gym/WorkoutSessionViewModel.swift:2`
- `Foundation` — `AiQo/Features/Home/ActivityDataProviding.swift:1`
- `SwiftUI` — `AiQo/Features/Home/DJCaptainChatView.swift:1`
- `UIKit` — `AiQo/Features/Home/DJCaptainChatView.swift:2`
- `Foundation` — `AiQo/Features/Home/DailyAuraModels.swift:1`
- `Foundation` — `AiQo/Features/Home/DailyAuraPathData.swift:1`
- `SwiftUI` — `AiQo/Features/Home/DailyAuraView.swift:1`
- `UIKit` — `AiQo/Features/Home/DailyAuraView.swift:2`
- `Foundation` — `AiQo/Features/Home/DailyAuraViewModel.swift:1`
- `SwiftUI` — `AiQo/Features/Home/DailyAuraViewModel.swift:2`
- `Combine` — `AiQo/Features/Home/DailyAuraViewModel.swift:3`
- `HealthKit` — `AiQo/Features/Home/HealthKitService+Water.swift:1`
- `SwiftUI` — `AiQo/Features/Home/HomeStatCard.swift:1`
- `SwiftUI` — `AiQo/Features/Home/HomeView.swift:1`
- `UIKit` — `AiQo/Features/Home/HomeView.swift:2`
- `Combine` — `AiQo/Features/Home/HomeView.swift:3`
- `Foundation` — `AiQo/Features/Home/HomeViewModel.swift:10`
- `Combine` — `AiQo/Features/Home/HomeViewModel.swift:11`
- `HealthKit` — `AiQo/Features/Home/HomeViewModel.swift:12`
- `SwiftUI` — `AiQo/Features/Home/LevelUpCelebrationView.swift:1`
- `Foundation` — `AiQo/Features/Home/MetricKind.swift:1`
- `SwiftUI` — `AiQo/Features/Home/SpotifyVibeCard.swift:1`
- `UIKit` — `AiQo/Features/Home/SpotifyVibeCard.swift:2`
- `SwiftUI` — `AiQo/Features/Home/StreakBadgeView.swift:1`
- `SwiftUI` — `AiQo/Features/Home/VibeControlSheet.swift:1`
- `UIKit` — `AiQo/Features/Home/VibeControlSheet.swift:2`
- `AVKit` — `AiQo/Features/Home/VibeControlSheet.swift:3`
- `Combine` — `AiQo/Features/Home/VibeControlSheet.swift:4`
- `SwiftUI` — `AiQo/Features/Home/WaterBottleView.swift:1`
- `SwiftUI` — `AiQo/Features/Home/WaterDetailSheetView.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/CameraView.swift:1`
- `UIKit` — `AiQo/Features/Kitchen/CameraView.swift:2`
- `SwiftUI` — `AiQo/Features/Kitchen/CompositePlateView.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/FridgeInventoryView.swift:1`
- `SwiftData` — `AiQo/Features/Kitchen/FridgeInventoryView.swift:2`
- `SwiftUI` — `AiQo/Features/Kitchen/IngredientAssetCatalog.swift:1`
- `UIKit` — `AiQo/Features/Kitchen/IngredientAssetCatalog.swift:2`
- `SwiftUI` — `AiQo/Features/Kitchen/IngredientAssetLibrary.swift:1`
- `UIKit` — `AiQo/Features/Kitchen/IngredientAssetLibrary.swift:2`
- `Foundation` — `AiQo/Features/Kitchen/IngredientCatalog.swift:1`
- `Foundation` — `AiQo/Features/Kitchen/IngredientDisplayItem.swift:1`
- `Foundation` — `AiQo/Features/Kitchen/IngredientKey.swift:1`
- `SwiftData` — `AiQo/Features/Kitchen/InteractiveFridgeView.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/InteractiveFridgeView.swift:2`
- `Foundation` — `AiQo/Features/Kitchen/KitchenLanguageRouter.swift:1`
- `Foundation` — `AiQo/Features/Kitchen/KitchenModels.swift:1`
- `Foundation` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:2`
- `Combine` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:3`
- `Foundation` — `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/KitchenSceneView.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/KitchenScreen.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/KitchenView.swift:1`
- `UIKit` — `AiQo/Features/Kitchen/KitchenView.swift:2`
- `Foundation` — `AiQo/Features/Kitchen/KitchenViewModel.swift:3`
- `Observation` — `AiQo/Features/Kitchen/KitchenViewModel.swift:4`
- `Foundation` — `AiQo/Features/Kitchen/LocalMealsRepository.swift:3`
- `Foundation` — `AiQo/Features/Kitchen/Meal.swift:3`
- `SwiftUI` — `AiQo/Features/Kitchen/MealIllustrationView.swift:1`
- `Foundation` — `AiQo/Features/Kitchen/MealImageSpec.swift:1`
- `Foundation` — `AiQo/Features/Kitchen/MealPlanGenerator.swift:3`
- `SwiftUI` — `AiQo/Features/Kitchen/MealPlanView.swift:1`
- `UIKit` — `AiQo/Features/Kitchen/MealSectionView.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/MealSectionView.swift:2`
- `Foundation` — `AiQo/Features/Kitchen/MealsRepository.swift:3`
- `SwiftUI` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/PlateTemplate.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/RecipeCardView.swift:3`
- `AVFoundation` — `AiQo/Features/Kitchen/SmartFridgeCameraPreviewController.swift:1`
- `SwiftUI` — `AiQo/Features/Kitchen/SmartFridgeCameraPreviewController.swift:2`
- `UIKit` — `AiQo/Features/Kitchen/SmartFridgeCameraPreviewController.swift:3`
- `Combine` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:2`
- `CoreMedia` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:3`
- `Foundation` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:4`
- `os.log` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:5`
- `UIKit` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:6`
- `Foundation` — `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:1`
- `SwiftData` — `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:2`
- `AVFoundation` — `AiQo/Features/Kitchen/SmartFridgeScannerView.swift:1`
- `SwiftData` — `AiQo/Features/Kitchen/SmartFridgeScannerView.swift:2`
- `SwiftUI` — `AiQo/Features/Kitchen/SmartFridgeScannerView.swift:3`
- `UIKit` — `AiQo/Features/Kitchen/SmartFridgeScannerView.swift:4`
- `SwiftUI` — `AiQo/Features/LegendaryChallenges/Components/RecordCard.swift:1`
- `Foundation` — `AiQo/Features/LegendaryChallenges/Models/LegendaryProject.swift:1`
- `Foundation` — `AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift:1`
- `Foundation` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:1`
- `SwiftData` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:2`
- `Foundation` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:1`
- `SwiftData` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:2`
- `Foundation` — `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift:1`
- `HealthKit` — `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift:2`
- `Observation` — `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift:3`
- `Combine` — `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift:4`
- `SwiftUI` — `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:1`
- `Combine` — `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:2`
- `Foundation` — `AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift:1`
- `SwiftData` — `AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift:2`
- `os.log` — `AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift:3`
- `SwiftUI` — `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:1`
- `HealthKit` — `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:2`
- `SwiftUI` — `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift:1`
- `SwiftUI` — `AiQo/Features/LegendaryChallenges/Views/ProjectView.swift:1`
- `SwiftUI` — `AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift:1`
- `SwiftUI` — `AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift:1`
- `SwiftData` — `AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift:2`
- `SwiftUI` — `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewResultView.swift:1`
- `SwiftUI` — `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:1`
- `Foundation` — `AiQo/Features/MyVibe/DailyVibeState.swift:1`
- `SwiftUI` — `AiQo/Features/MyVibe/MyVibeScreen.swift:1`
- `SwiftUI` — `AiQo/Features/MyVibe/MyVibeSubviews.swift:1`
- `Foundation` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:1`
- `Combine` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:2`
- `SwiftUI` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:3`
- `Foundation` — `AiQo/Features/MyVibe/VibeOrchestrator.swift:1`
- `Combine` — `AiQo/Features/MyVibe/VibeOrchestrator.swift:2`
- `SwiftUI` — `AiQo/Features/Onboarding/FeatureIntroView.swift:1`
- `Foundation` — `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:1`
- `HealthKit` — `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:2`
- `os.log` — `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:3`
- `SwiftUI` — `AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:1`
- `SwiftUI` — `AiQo/Features/Profile/LevelCardView.swift:1`
- `Combine` — `AiQo/Features/Profile/LevelCardView.swift:2`
- `SwiftUI` — `AiQo/Features/Profile/ProfileScreen.swift:1`
- `PhotosUI` — `AiQo/Features/Profile/ProfileScreen.swift:2`
- `MessageUI` — `AiQo/Features/Profile/ProfileScreen.swift:3`
- `UIKit` — `AiQo/Features/Profile/ProfileScreen.swift:4`
- `Foundation` — `AiQo/Features/Profile/String+Localized.swift:1`
- `Foundation` — `AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift:1`
- `UIKit` — `AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift:2`
- `Combine` — `AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift:3`
- `SwiftUI` — `AiQo/Features/ProgressPhotos/ProgressPhotosView.swift:1`
- `PhotosUI` — `AiQo/Features/ProgressPhotos/ProgressPhotosView.swift:2`
- `SwiftUI` — `AiQo/Features/Sleep/AlarmSetupCardView.swift:1`
- `Foundation` — `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:1`
- `os.log` — `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:2`
- `FoundationModels` — `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:5`
- `Foundation` — `AiQo/Features/Sleep/HealthManager+Sleep.swift:1`
- `HealthKit` — `AiQo/Features/Sleep/HealthManager+Sleep.swift:2`
- `Charts` — `AiQo/Features/Sleep/SleepDetailCardView.swift:1`
- `SwiftUI` — `AiQo/Features/Sleep/SleepDetailCardView.swift:2`
- `SwiftUI` — `AiQo/Features/Sleep/SleepScoreRingView.swift:1`
- `Foundation` — `AiQo/Features/Sleep/SleepSessionObserver.swift:1`
- `HealthKit` — `AiQo/Features/Sleep/SleepSessionObserver.swift:2`
- `UserNotifications` — `AiQo/Features/Sleep/SleepSessionObserver.swift:3`
- `SwiftUI` — `AiQo/Features/Sleep/SmartWakeCalculatorView.swift:1`
- `UIKit` — `AiQo/Features/Sleep/SmartWakeCalculatorView.swift:2`
- `Foundation` — `AiQo/Features/Sleep/SmartWakeEngine.swift:1`
- `Combine` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:1`
- `Foundation` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:2`
- `SwiftUI` — `AiQo/Features/Tribe/TribeDesignSystem.swift:1`
- `SwiftUI` — `AiQo/Features/Tribe/TribeExperienceFlow.swift:1`
- `UIKit` — `AiQo/Features/Tribe/TribeExperienceFlow.swift:2`
- `SwiftUI` — `AiQo/Features/Tribe/TribeView.swift:1`
- `SwiftData` — `AiQo/Features/Tribe/TribeView.swift:2`
- `UIKit` — `AiQo/Features/Tribe/TribeView.swift:3`
- `Combine` — `AiQo/Features/Tribe/TribeView.swift:4`
- `SwiftUI` — `AiQo/Features/WeeklyReport/ShareCardRenderer.swift:1`
- `UIKit` — `AiQo/Features/WeeklyReport/ShareCardRenderer.swift:2`
- `Foundation` — `AiQo/Features/WeeklyReport/WeeklyReportModel.swift:1`
- `SwiftUI` — `AiQo/Features/WeeklyReport/WeeklyReportView.swift:1`
- `Foundation` — `AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift:1`
- `HealthKit` — `AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift:2`
- `Combine` — `AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift:3`
- `Foundation` — `AiQo/NeuralMemory.swift:1`
- `SwiftData` — `AiQo/NeuralMemory.swift:2`
- `Foundation` — `AiQo/PhoneConnectivityManager.swift:6`
- `WatchConnectivity` — `AiQo/PhoneConnectivityManager.swift:7`
- `HealthKit` — `AiQo/PhoneConnectivityManager.swift:8`
- `Combine` — `AiQo/PhoneConnectivityManager.swift:9`
- `os` — `AiQo/PhoneConnectivityManager.swift:10`
- `Foundation` — `AiQo/Premium/AccessManager.swift:1`
- `Combine` — `AiQo/Premium/AccessManager.swift:2`
- `Foundation` — `AiQo/Premium/EntitlementProvider.swift:1`
- `Foundation` — `AiQo/Premium/FreeTrialManager.swift:1`
- `Security` — `AiQo/Premium/FreeTrialManager.swift:2`
- `Combine` — `AiQo/Premium/FreeTrialManager.swift:3`
- `StoreKit` — `AiQo/Premium/PremiumPaywallView.swift:1`
- `SwiftUI` — `AiQo/Premium/PremiumPaywallView.swift:2`
- `Foundation` — `AiQo/Premium/PremiumStore.swift:1`
- `Combine` — `AiQo/Premium/PremiumStore.swift:2`
- `StoreKit` — `AiQo/Premium/PremiumStore.swift:3`
- `Foundation` — `AiQo/ProtectionModel.swift:1`
- `FamilyControls` — `AiQo/ProtectionModel.swift:2`
- `DeviceActivity` — `AiQo/ProtectionModel.swift:3`
- `ManagedSettings` — `AiQo/ProtectionModel.swift:4`
- `os.log` — `AiQo/ProtectionModel.swift:5`
- `Combine` — `AiQo/ProtectionModel.swift:6`
- `Foundation` — `AiQo/Services/AiQoError.swift:1`
- `Foundation` — `AiQo/Services/Analytics/AnalyticsEvent.swift:1`
- `Foundation` — `AiQo/Services/Analytics/AnalyticsService.swift:1`
- `UIKit` — `AiQo/Services/Analytics/AnalyticsService.swift:2`
- `Foundation` — `AiQo/Services/CrashReporting/CrashReporter.swift:1`
- `UIKit` — `AiQo/Services/CrashReporting/CrashReporter.swift:2`
- `Foundation` — `AiQo/Services/CrashReporting/CrashReportingService.swift:1`
- `FirebaseCore` — `AiQo/Services/CrashReporting/CrashReportingService.swift:3`
- `FirebaseCrashlytics` — `AiQo/Services/CrashReporting/CrashReportingService.swift:6`
- `Foundation` — `AiQo/Services/DeepLinkRouter.swift:1`
- `SwiftUI` — `AiQo/Services/DeepLinkRouter.swift:2`
- `Combine` — `AiQo/Services/DeepLinkRouter.swift:3`
- `Foundation` — `AiQo/Services/NetworkMonitor.swift:1`
- `Network` — `AiQo/Services/NetworkMonitor.swift:2`
- `Combine` — `AiQo/Services/NetworkMonitor.swift:3`
- `Foundation` — `AiQo/Services/NotificationType.swift:1`
- `Foundation` — `AiQo/Services/Notifications/ActivityNotificationEngine.swift:13`
- `UserNotifications` — `AiQo/Services/Notifications/ActivityNotificationEngine.swift:14`
- `Foundation` — `AiQo/Services/Notifications/AlarmSchedulingService.swift:1`
- `SwiftUI` — `AiQo/Services/Notifications/AlarmSchedulingService.swift:2`
- `ActivityKit` — `AiQo/Services/Notifications/AlarmSchedulingService.swift:3`
- `AlarmKit` — `AiQo/Services/Notifications/AlarmSchedulingService.swift:4`
- `Foundation` — `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:1`
- `Foundation` — `AiQo/Services/Notifications/InactivityTracker.swift:1`
- `Foundation` — `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:1`
- `HealthKit` — `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:2`
- `UserNotifications` — `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:3`
- `Foundation` — `AiQo/Services/Notifications/NotificationCategoryManager.swift:1`
- `UserNotifications` — `AiQo/Services/Notifications/NotificationCategoryManager.swift:2`
- `BackgroundTasks` — `AiQo/Services/Notifications/NotificationIntelligenceManager.swift:1`
- `Foundation` — `AiQo/Services/Notifications/NotificationIntelligenceManager.swift:2`
- `UserNotifications` — `AiQo/Services/Notifications/NotificationIntelligenceManager.swift:3`
- `Foundation` — `AiQo/Services/Notifications/NotificationRepository.swift:1`
- `UserNotifications` — `AiQo/Services/Notifications/NotificationService.swift:1`
- `UIKit` — `AiQo/Services/Notifications/NotificationService.swift:2`
- `Foundation` — `AiQo/Services/Notifications/NotificationService.swift:3`
- `HealthKit` — `AiQo/Services/Notifications/NotificationService.swift:4`
- `Foundation` — `AiQo/Services/Notifications/PremiumExpiryNotifier.swift:1`
- `UserNotifications` — `AiQo/Services/Notifications/PremiumExpiryNotifier.swift:2`
- `Foundation` — `AiQo/Services/Notifications/SmartNotificationManager.swift:1`
- `Foundation` — `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:1`
- `HealthKit` — `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:2`
- `WidgetKit` — `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:3`
- `Foundation` — `AiQo/Services/Permissions/HealthKit/TodaySummary.swift:1`
- `Foundation` — `AiQo/Services/ReferralManager.swift:1`
- `Combine` — `AiQo/Services/ReferralManager.swift:2`
- `Foundation` — `AiQo/Services/SupabaseArenaService.swift:1`
- `SwiftData` — `AiQo/Services/SupabaseArenaService.swift:2`
- `Supabase` — `AiQo/Services/SupabaseArenaService.swift:3`
- `os.log` — `AiQo/Services/SupabaseArenaService.swift:4`
- `Foundation` — `AiQo/Services/SupabaseService.swift:1`
- `os.log` — `AiQo/Services/SupabaseService.swift:2`
- `Supabase` — `AiQo/Services/SupabaseService.swift:3`
- `SwiftUI` — `AiQo/Shared/CoinManager.swift:1`
- `Combine` — `AiQo/Shared/CoinManager.swift:2`
- `Foundation` — `AiQo/Shared/HealthKitManager.swift:6`
- `HealthKit` — `AiQo/Shared/HealthKitManager.swift:7`
- `os.log` — `AiQo/Shared/HealthKitManager.swift:8`
- `Combine` — `AiQo/Shared/HealthKitManager.swift:9`
- `SwiftUI` — `AiQo/Shared/LevelSystem.swift:1`
- `Foundation` — `AiQo/Shared/WorkoutSyncCodec.swift:1`
- `Foundation` — `AiQo/Shared/WorkoutSyncModels.swift:1`
- `SwiftUI` — `AiQo/Tribe/Arena/TribeArenaView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift:1`
- `Combine` — `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift:2`
- `SwiftData` — `AiQo/Tribe/Galaxy/ArenaModels.swift:1`
- `Foundation` — `AiQo/Tribe/Galaxy/ArenaModels.swift:2`
- `SwiftUI` — `AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/ArenaScreen.swift:3`
- `SwiftUI` — `AiQo/Tribe/Galaxy/ArenaTabView.swift:1`
- `SwiftData` — `AiQo/Tribe/Galaxy/ArenaTabView.swift:2`
- `Combine` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:3`
- `SwiftUI` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:4`
- `UIKit` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:5`
- `SwiftUI` — `AiQo/Tribe/Galaxy/BattleLeaderboard.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/BattleLeaderboardRow.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/ConstellationCanvasView.swift:3`
- `SwiftUI` — `AiQo/Tribe/Galaxy/CountdownTimerView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/CreateTribeSheet.swift:1`
- `SwiftData` — `AiQo/Tribe/Galaxy/CreateTribeSheet.swift:2`
- `SwiftUI` — `AiQo/Tribe/Galaxy/EditTribeNameSheet.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift:1`
- `SwiftData` — `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift:2`
- `os.log` — `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift:3`
- `SwiftUI` — `AiQo/Tribe/Galaxy/EmirateLeadersBanner.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/GalaxyCanvasView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/GalaxyHUD.swift:3`
- `UIKit` — `AiQo/Tribe/Galaxy/GalaxyHUD.swift:4`
- `CoreGraphics` — `AiQo/Tribe/Galaxy/GalaxyLayout.swift:3`
- `Foundation` — `AiQo/Tribe/Galaxy/GalaxyLayout.swift:4`
- `CoreGraphics` — `AiQo/Tribe/Galaxy/GalaxyModels.swift:3`
- `Foundation` — `AiQo/Tribe/Galaxy/GalaxyModels.swift:4`
- `SwiftUI` — `AiQo/Tribe/Galaxy/GalaxyNodeCard.swift:3`
- `SwiftUI` — `AiQo/Tribe/Galaxy/GalaxyScreen.swift:3`
- `SwiftUI` — `AiQo/Tribe/Galaxy/GalaxyView.swift:1`
- `Combine` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:3`
- `SwiftUI` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:4`
- `UIKit` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:5`
- `SwiftUI` — `AiQo/Tribe/Galaxy/HallOfFameFullView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/HallOfFameSection.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/InviteCardView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/JoinTribeSheet.swift:1`
- `SwiftData` — `AiQo/Tribe/Galaxy/JoinTribeSheet.swift:2`
- `Foundation` — `AiQo/Tribe/Galaxy/MockArenaData.swift:2`
- `SwiftUI` — `AiQo/Tribe/Galaxy/TribeEmptyState.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/TribeHeroCard.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/TribeInviteView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/TribeLogScreen.swift:3`
- `SwiftUI` — `AiQo/Tribe/Galaxy/TribeMemberRow.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/TribeMembersList.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/TribeRingView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Galaxy/TribeTabView.swift:1`
- `SwiftData` — `AiQo/Tribe/Galaxy/TribeTabView.swift:2`
- `SwiftUI` — `AiQo/Tribe/Galaxy/WeeklyChallengeCard.swift:1`
- `SwiftUI` — `AiQo/Tribe/Log/TribeLogView.swift:1`
- `Foundation` — `AiQo/Tribe/Models/TribeFeatureModels.swift:1`
- `Foundation` — `AiQo/Tribe/Models/TribeModels.swift:1`
- `Foundation` — `AiQo/Tribe/Preview/TribePreviewController.swift:1`
- `Combine` — `AiQo/Tribe/Preview/TribePreviewController.swift:2`
- `Foundation` — `AiQo/Tribe/Preview/TribePreviewData.swift:1`
- `Foundation` — `AiQo/Tribe/Repositories/TribeRepositories.swift:1`
- `Foundation` — `AiQo/Tribe/Stores/ArenaStore.swift:1`
- `Combine` — `AiQo/Tribe/Stores/ArenaStore.swift:2`
- `SwiftUI` — `AiQo/Tribe/Stores/GalaxyStore.swift:3`
- `UIKit` — `AiQo/Tribe/Stores/GalaxyStore.swift:4`
- `Combine` — `AiQo/Tribe/Stores/GalaxyStore.swift:5`
- `Foundation` — `AiQo/Tribe/Stores/TribeLogStore.swift:1`
- `Combine` — `AiQo/Tribe/Stores/TribeLogStore.swift:2`
- `SwiftUI` — `AiQo/Tribe/TribeModuleComponents.swift:1`
- `Foundation` — `AiQo/Tribe/TribeModuleModels.swift:1`
- `SwiftUI` — `AiQo/Tribe/TribeModuleModels.swift:2`
- `Foundation` — `AiQo/Tribe/TribeModuleViewModel.swift:1`
- `Combine` — `AiQo/Tribe/TribeModuleViewModel.swift:2`
- `SwiftUI` — `AiQo/Tribe/TribeModuleViewModel.swift:3`
- `SwiftUI` — `AiQo/Tribe/TribePulseScreenView.swift:1`
- `SwiftUI` — `AiQo/Tribe/TribeScreen.swift:1`
- `Foundation` — `AiQo/Tribe/TribeStore.swift:1`
- `Combine` — `AiQo/Tribe/TribeStore.swift:2`
- `Supabase` — `AiQo/Tribe/TribeStore.swift:3`
- `Auth` — `AiQo/Tribe/TribeStore.swift:4`
- `SwiftUI` — `AiQo/Tribe/Views/GlobalTribeRadialView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Views/TribeAtomRingView.swift:1`
- `SwiftUI` — `AiQo/Tribe/Views/TribeEnergyCoreCard.swift:1`
- `UIKit` — `AiQo/Tribe/Views/TribeEnergyCoreCard.swift:2`
- `SwiftUI` — `AiQo/Tribe/Views/TribeHubScreen.swift:1`
- `UIKit` — `AiQo/Tribe/Views/TribeHubScreen.swift:2`
- `Combine` — `AiQo/Tribe/Views/TribeHubScreen.swift:3`
- `SwiftUI` — `AiQo/Tribe/Views/TribeLeaderboardView.swift:1`
- `SwiftUI` — `AiQo/UI/AccessibilityHelpers.swift:1`
- `SwiftUI` — `AiQo/UI/AiQoProfileButton.swift:1`
- `SwiftUI` — `AiQo/UI/AiQoScreenHeader.swift:1`
- `SwiftUI` — `AiQo/UI/ErrorToastView.swift:1`
- `UIKit` — `AiQo/UI/GlassCardView.swift:1`
- `SwiftUI` — `AiQo/UI/LegalView.swift:1`
- `SwiftUI` — `AiQo/UI/OfflineBannerView.swift:1`
- `SwiftUI` — `AiQo/UI/Purchases/PaywallView.swift:1`
- `StoreKit` — `AiQo/UI/Purchases/PaywallView.swift:2`
- `SwiftUI` — `AiQo/UI/ReferralSettingsRow.swift:1`
- `Foundation` — `AiQo/XPCalculator.swift:1`
- `HealthKit` — `AiQo/XPCalculator.swift:2`
- `SwiftUI` — `AiQo/watch/ConnectivityDiagnosticsView.swift:1`
- `WatchConnectivity` — `AiQo/watch/ConnectivityDiagnosticsView.swift:2`
- `Foundation` — `AiQoWatch Watch App/ActivityRingsView.swift:8`
- `HealthKit` — `AiQoWatch Watch App/ActivityRingsView.swift:9`
- `SwiftUI` — `AiQoWatch Watch App/ActivityRingsView.swift:10`
- `WatchKit` — `AiQoWatch Watch App/ActivityRingsView.swift:12`
- `SwiftUI` — `AiQoWatch Watch App/AiQoWatchApp.swift:6`
- `HealthKit` — `AiQoWatch Watch App/AiQoWatchApp.swift:7`
- `WatchKit` — `AiQoWatch Watch App/AiQoWatchApp.swift:9`
- `SwiftUI` — `AiQoWatch Watch App/ControlsView.swift:8`
- `SwiftUI` — `AiQoWatch Watch App/Design/WatchDesignSystem.swift:1`
- `SwiftUI` — `AiQoWatch Watch App/ElapsedTimeView.swift:8`
- `SwiftUI` — `AiQoWatch Watch App/MetricsView.swift:8`
- `HealthKit` — `AiQoWatch Watch App/MetricsView.swift:9`
- `SwiftUI` — `AiQoWatch Watch App/Models/WatchWorkoutType.swift:1`
- `HealthKit` — `AiQoWatch Watch App/Models/WatchWorkoutType.swift:2`
- `Foundation` — `AiQoWatch Watch App/Services/WatchConnectivityService.swift:1`
- `Combine` — `AiQoWatch Watch App/Services/WatchConnectivityService.swift:2`
- `WatchConnectivity` — `AiQoWatch Watch App/Services/WatchConnectivityService.swift:3`
- `Foundation` — `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:1`
- `Combine` — `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:2`
- `HealthKit` — `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:3`
- `Foundation` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:1`
- `Combine` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:2`
- `HealthKit` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:3`
- `WatchConnectivity` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:4`
- `SwiftUI` — `AiQoWatch Watch App/SessionPagingView.swift:8`
- `HealthKit` — `AiQoWatch Watch App/SessionPagingView.swift:9`
- `WatchKit` — `AiQoWatch Watch App/SessionPagingView.swift:11`
- `SwiftUI` — `AiQoWatch Watch App/StartView.swift:1`
- `HealthKit` — `AiQoWatch Watch App/StartView.swift:2`
- `Foundation` — `AiQoWatch Watch App/SummaryView.swift:1`
- `HealthKit` — `AiQoWatch Watch App/SummaryView.swift:2`
- `SwiftUI` — `AiQoWatch Watch App/SummaryView.swift:3`
- `WatchKit` — `AiQoWatch Watch App/SummaryView.swift:5`
- `SwiftUI` — `AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift:1`
- `SwiftUI` — `AiQoWatch Watch App/Views/WatchHomeView.swift:1`
- `SwiftUI` — `AiQoWatch Watch App/Views/WatchWorkoutListView.swift:1`
- `SwiftUI` — `AiQoWatch Watch App/Views/WatchWorkoutSummaryView.swift:1`
- `Foundation` — `AiQoWatch Watch App/WatchConnectivityManager.swift:6`
- `WatchConnectivity` — `AiQoWatch Watch App/WatchConnectivityManager.swift:7`
- `Combine` — `AiQoWatch Watch App/WatchConnectivityManager.swift:8`
- `WatchKit` — `AiQoWatch Watch App/WatchConnectivityManager.swift:10`
- `Foundation` — `AiQoWatch Watch App/WorkoutManager.swift:6`
- `HealthKit` — `AiQoWatch Watch App/WorkoutManager.swift:7`
- `Combine` — `AiQoWatch Watch App/WorkoutManager.swift:8`
- `WatchKit` — `AiQoWatch Watch App/WorkoutManager.swift:10`
- `WidgetKit` — `AiQoWatch Watch App/WorkoutManager.swift:13`
- `Foundation` — `AiQoWatch Watch App/WorkoutNotificationCenter.swift:1`
- `UserNotifications` — `AiQoWatch Watch App/WorkoutNotificationCenter.swift:2`
- `SwiftUI` — `AiQoWatch Watch App/WorkoutNotificationController.swift:1`
- `UserNotifications` — `AiQoWatch Watch App/WorkoutNotificationController.swift:2`
- `WatchKit` — `AiQoWatch Watch App/WorkoutNotificationController.swift:5`
- `SwiftUI` — `AiQoWatch Watch App/WorkoutNotificationView.swift:1`
- `WidgetKit` — `AiQoWatchWidget/AiQoWatchWidget.swift:1`
- `SwiftUI` — `AiQoWatchWidget/AiQoWatchWidget.swift:2`
- `WidgetKit` — `AiQoWatchWidget/AiQoWatchWidgetBundle.swift:1`
- `SwiftUI` — `AiQoWatchWidget/AiQoWatchWidgetBundle.swift:2`
- `WidgetKit` — `AiQoWatchWidget/AiQoWatchWidgetProvider.swift:1`
- `Foundation` — `AiQoWatchWidget/AiQoWatchWidgetProvider.swift:2`
- `WidgetKit` — `AiQoWidget/AiQoEntry.swift:1`
- `WidgetKit` — `AiQoWidget/AiQoProvider.swift:1`
- `SwiftUI` — `AiQoWidget/AiQoProvider.swift:2`
- `WidgetKit` — `AiQoWidget/AiQoRingsFaceWidget.swift:1`
- `SwiftUI` — `AiQoWidget/AiQoRingsFaceWidget.swift:2`
- `Foundation` — `AiQoWidget/AiQoSharedStore.swift:1`
- `WidgetKit` — `AiQoWidget/AiQoWatchFaceWidget.swift:1`
- `SwiftUI` — `AiQoWidget/AiQoWatchFaceWidget.swift:2`
- `WidgetKit` — `AiQoWidget/AiQoWidget.swift:1`
- `SwiftUI` — `AiQoWidget/AiQoWidget.swift:2`
- `WidgetKit` — `AiQoWidget/AiQoWidgetBundle.swift:1`
- `SwiftUI` — `AiQoWidget/AiQoWidgetBundle.swift:2`
- `ActivityKit` — `AiQoWidget/AiQoWidgetLiveActivity.swift:11`
- `WidgetKit` — `AiQoWidget/AiQoWidgetLiveActivity.swift:12`
- `SwiftUI` — `AiQoWidget/AiQoWidgetLiveActivity.swift:13`
- `SwiftUI` — `AiQoWidget/AiQoWidgetView.swift:1`
- `WidgetKit` — `AiQoWidget/AiQoWidgetView.swift:2`

# SECTION 3 — Project File Structure
- The repo is organized by app shell (`App/`), core systems (`Core/`), features (`Features/`), services (`Services/`), monetization (`Premium/`), social systems (`Tribe/`), design tokens (`DesignSystem/`), and companion targets (widgets / watch app). [`AiQo/App/AppDelegate.swift:1`; `AiQo/Core/MemoryStore.swift:8`; `AiQo/Features/Home/HomeView.swift:9`; `AiQo/Services/SupabaseService.swift:5`; `AiQo/Premium/AccessManager.swift:5`; `AiQoWatch Watch App/AiQoWatchApp.swift:41`]
- Naming is responsibility-driven: screens / views live in feature folders, managers / services live in `Core/` or `Services/`, and target-specific code is split by target directory. [`AiQo/Features/Kitchen/KitchenViewModel.swift:7`; `AiQo/Services/Analytics/AnalyticsService.swift:17`; `AiQoWidget/AiQoProvider.swift:4`; `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:9`]
- Notable path mismatches exist: the watch app Info.plist is root-level, and widget entitlements are also configured from root-level files rather than target subfolders. [`AiQo.xcodeproj/project.pbxproj:1334`; `AiQo.xcodeproj/project.pbxproj:1264`; `AiQo.xcodeproj/project.pbxproj:1556`]

## Complete Directory Tree From `/tmp/aiqo_dirs.txt`
```
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
./AiQo/Features/Sleep
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

## Complete File Inventory From `/tmp/aiqo_files.txt`
```
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
AiQo/Core/Purchases/SubscriptionTier.swift
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
AiQo/Features/Sleep/AlarmSetupCardView.swift
AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift
AiQo/Features/Sleep/HealthManager+Sleep.swift
AiQo/Features/Sleep/SleepDetailCardView.swift
AiQo/Features/Sleep/SleepScoreRingView.swift
AiQo/Features/Sleep/SleepSessionObserver.swift
AiQo/Features/Sleep/SmartWakeCalculatorView.swift
AiQo/Features/Sleep/SmartWakeEngine.swift
AiQo/Features/Sleep/SmartWakeViewModel.swift
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
AiQo/Resources/AiQo.storekit
AiQo/Resources/AiQo_Test.storekit
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
AiQo/Resources/Prompts.xcstrings
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
AiQo/Services/Notifications/SmartNotificationManager.swift
AiQo/Services/Permissions/HealthKit/HealthKitService.swift
AiQo/Services/Permissions/HealthKit/TodaySummary.swift
AiQo/Services/ReferralManager.swift
AiQo/Services/SupabaseArenaService.swift
AiQo/Services/SupabaseService.swift
AiQo/Shared/CoinManager.swift
AiQo/Shared/HealthKitManager.swift
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
Configuration/Secrets.template.xcconfig
Configuration/Secrets.xcconfig
```

# SECTION 4 — App Entry, Boot Sequence & Navigation
- The iOS entry point is `@main struct AiQoApp: App`. [`AiQo/App/AppDelegate.swift:8`]
- AiQo bootstraps a dedicated Captain SwiftData container for `CaptainMemory`, `PersistentChatMessage`, `RecordProject`, and `WeeklyLog`, persisted at `Application Support/captain_memory.store`. [`AiQo/App/AppDelegate.swift:20`; `AiQo/App/AppDelegate.swift:23`; `AiQo/App/AppDelegate.swift:30`]
- A separate main app container is injected for `AiQoDailyRecord`, `WorkoutTask`, and the Arena models. [`AiQo/App/AppDelegate.swift:81`; `AiQo/App/AppDelegate.swift:88`]
- A third container is created in `QuestPersistenceController` for `PlayerStats`, `QuestStage`, `QuestRecord`, and `Reward`. [`AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:30`; `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:33`]
- `didFinishLaunchingWithOptions` configures crash reporting, binds the Supabase user when available, starts phone/watch connectivity, tracks app launch, refreshes free trial state, applies language, registers notifications / background tasks, and starts purchases. [`AiQo/App/AppDelegate.swift:100`; `AiQo/App/AppDelegate.swift:107`; `AiQo/App/AppDelegate.swift:115`; `AiQo/App/AppDelegate.swift:117`; `AiQo/App/AppDelegate.swift:119`; `AiQo/App/AppDelegate.swift:120`; `AiQo/App/AppDelegate.swift:122`]
- Post-onboarding boot also requests HealthKit / notification access and starts Morning Habit, Sleep Observer, AI workout summaries, and smart-notification scheduling. [`AiQo/App/AppDelegate.swift:136`; `AiQo/App/AppDelegate.swift:137`; `AiQo/App/AppDelegate.swift:134`; `AiQo/App/AppDelegate.swift:146`]
- The root-state machine uses six `RootScreen` cases: `languageSelection`, `login`, `profileSetup`, `legacy`, `featureIntro`, and `main`. [`AiQo/App/SceneDelegate.swift:20`; `AiQo/App/SceneDelegate.swift:26`]
- Onboarding flags are `didCompleteLegacyCalculation`, `didCompleteFeatureIntro`, `didShowFirstAuthScreen`, `didCompleteDatingProfile`, and `didSelectLanguage`. [`AiQo/App/SceneDelegate.swift:9`; `AiQo/App/SceneDelegate.swift:13`]
- Root-screen resolution order is language -> login -> profile -> legacy -> feature intro -> main, unless an authenticated Supabase session is considered valid up front. [`AiQo/App/SceneDelegate.swift:178`; `AiQo/App/SceneDelegate.swift:188`; `AiQo/App/SceneDelegate.swift:201`]
- The live main-tab shell currently exposes only `home`, `gym`, and `captain`. [`AiQo/App/MainTabRouter.swift:10`; `AiQo/App/MainTabRouter.swift:12`; `AiQo/App/MainTabScreen.swift:28`; `AiQo/App/MainTabScreen.swift:54`]
- Kitchen navigation is indirect: `MainTabRouter.openKitchen()` broadcasts `openKitchenFromHome` rather than exposing a dedicated main tab. [`AiQo/App/MainTabRouter.swift:33`]
- DeepLinkRouter supports `aiqo://` and `https://aiqo.app/` routes for `home`, `captain`, `gym`, `kitchen`, `settings`, `referral`, and `premium`. [`AiQo/Services/DeepLinkRouter.swift:6`; `AiQo/Services/DeepLinkRouter.swift:7`; `AiQo/Services/DeepLinkRouter.swift:18`]
- Declared `NSUserActivityTypes` are the eight workout / Captain / summary / kitchen / weekly-report activities listed in Info.plist. [`AiQo/Info.plist:53`]

# SECTION 5 — Hybrid AI Brain
- The Captain screen-context enum consists of `kitchen`, `gym`, `sleepAnalysis`, `peaks`, `mainChat`, and `myVibe`. [`AiQo/Features/Captain/ScreenContext.swift:4`; `AiQo/Features/Captain/ScreenContext.swift:9`]
- The `BrainOrchestrator` routing table is explicit: `.sleepAnalysis` routes local, while `.gym`, `.kitchen`, `.peaks`, `.myVibe`, and `.mainChat` route cloud-first. [`AiQo/Features/Captain/BrainOrchestrator.swift:82`; `AiQo/Features/Captain/BrainOrchestrator.swift:84`]
- Sleep-like user intents can be intercepted and forced through the local sleep-analysis route even outside the dedicated sleep screen context. [`AiQo/Features/Captain/BrainOrchestrator.swift:86`]
- The cloud hybrid brain uses Gemini with `model = gemini-flash-latest`, base endpoint `https://generativelanguage.googleapis.com/v1beta/models`, and a 35-second timeout. [`AiQo/Features/Captain/HybridBrainService.swift:87`; `AiQo/Features/Captain/HybridBrainService.swift:88`; `AiQo/Features/Captain/HybridBrainService.swift:89`]
- Response budgets are explicit: `mainChat` / `myVibe` / `sleepAnalysis` use 600 max tokens, while `gym` / `kitchen` / `peaks` use 900. [`AiQo/Features/Captain/HybridBrainService.swift:280`; `AiQo/Features/Captain/HybridBrainService.swift:282`]
- Cloud requests are privacy-sanitized before transmission via `CloudBrainService` + `PrivacySanitizer`. [`AiQo/Features/Captain/CloudBrainService.swift:31`; `AiQo/Features/Captain/PrivacySanitizer.swift:77`]
- Local Captain replies can return a message, workout plan, meal plan, Spotify recommendation, and raw structured text. [`AiQo/Features/Captain/LocalBrainService.swift:34`; `AiQo/Features/Captain/LocalBrainService.swift:38`]
- Local capabilities include background-notification wording, sleep analysis, workout plans, meal plans, and Spotify recommendations. [`AiQo/Features/Captain/LocalBrainService.swift:103`; `AiQo/Features/Captain/LocalBrainService.swift:111`; `AiQo/Features/Captain/LocalBrainService.swift:117`; `AiQo/Features/Captain/LocalBrainService.swift:118`; `AiQo/Features/Captain/LocalBrainService.swift:38`]
- The on-device Captain engine uses local health context and Iraqi-dialect system prompting. [`AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:29`; `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:120`]
- The Apple-intelligence sleep agent exposes `.emptyResponse` and `.modelUnavailable` failure modes so the orchestrator can continue with cloud or computed fallback. [`AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:54`; `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:56`]
- Sleep fallback is three-stage: on-device Apple Intelligence first, then cloud summary fallback when possible, then a computed fallback message. [`AiQo/Features/Captain/BrainOrchestrator.swift:134`; `AiQo/Features/Captain/BrainOrchestrator.swift:135`]
- Cloud fallback is also tiered: some cloud failures degrade to a network fallback while others fall through to local generation. [`AiQo/Features/Captain/BrainOrchestrator.swift:182`; `AiQo/Features/Captain/BrainOrchestrator.swift:185`]
- `HybridBrainRequest` carries conversation, screen context, language, context, profile summary, and image data; `HybridBrainServiceReply` returns message + optional workout / meal / Spotify payloads + raw text. [`AiQo/Features/Captain/HybridBrainService.swift:19`; `AiQo/Features/Captain/HybridBrainService.swift:30`]

# SECTION 6 — Captain Hamoudi Persona System
- Captain prompting is an explicit 6-layer system: identity, memory, bio-state, circadian tone, screen context, and output contract. [`AiQo/Features/Captain/CaptainPromptBuilder.swift:3`; `AiQo/Features/Captain/CaptainPromptBuilder.swift:22`]
- Circadian phases and windows are `awakening` (05:00–09:59), `energy` (10:00–13:59), `focus` (14:00–17:59), `recovery` (18:00–20:59), and `zen` (21:00–04:59). [`AiQo/Features/Captain/CaptainContextBuilder.swift:8`; `AiQo/Features/Captain/CaptainContextBuilder.swift:16`]
- Circadian override rules force `recovery` for early sleep deprivation and for high late-night activity above 8,000 steps. [`AiQo/Features/Captain/CaptainContextBuilder.swift:27`; `AiQo/Features/Captain/CaptainContextBuilder.swift:32`]
- Captain tone options are `practical = عملي`, `caring = حنون`, and `strict = صارم`. [`AiQo/Features/Captain/CaptainScreen.swift:32`; `AiQo/Features/Captain/CaptainScreen.swift:33`; `AiQo/Features/Captain/CaptainScreen.swift:34`]
- Captain customization stores name, age, height, weight, calling, and tone. [`AiQo/Features/Captain/CaptainScreen.swift:13`; `AiQo/Features/Captain/CaptainScreen.swift:18`]
- Long-term Captain memory categories are documented as `identity`, `goal`, `body`, `preference`, `mood`, `injury`, `nutrition`, `workout_history`, `sleep`, `insight`, and `active_record_project`. [`AiQo/Core/CaptainMemory.swift:10`]
- Memory sources are documented as `user_explicit`, `extracted`, `healthkit`, `inferred`, and `llm_extracted`. [`AiQo/Core/CaptainMemory.swift:18`]
- Captain memory retention is tier-aware through `AccessManager.captainMemoryLimit`: 200 memories by default and 500 for the `intelligence` tier. [`AiQo/Core/MemoryStore.swift:14`; `AiQo/Premium/AccessManager.swift:59`; `AiQo/Premium/AccessManager.swift:60`]
- Stale memory cleanup deletes entries older than 90 days, below confidence 0.3, and outside `active_record_project`. [`AiQo/Core/MemoryStore.swift:204`]
- Prompt-context memory windows are capped: up to 5 active record-project memories + 30 other memories locally, and 15 cloud-safe memories / 400 tokens in cloud-safe mode. [`AiQo/Core/MemoryStore.swift:136`; `AiQo/Core/MemoryStore.swift:144`; `AiQo/Core/MemoryStore.swift:183`; `AiQo/Core/CaptainMemory.swift:7`]
- Persisted Captain chat history uses `PersistentChatMessage` rows and computed `ChatSession` summaries. [`AiQo/Features/Captain/CaptainModels.swift:8`; `AiQo/Features/Captain/CaptainModels.swift:75`]
- Chat-history persistence caps at 200 rows, recent fetches default to 50 rows, and session summaries scan up to 500 rows. [`AiQo/Core/MemoryStore.swift:275`; `AiQo/Core/MemoryStore.swift:276`; `AiQo/Core/MemoryStore.swift:320`]
- Live view-model message policy keeps at most 80 messages in memory, sends at most 20 in the prompt window, and uses 15s general / 25s sleep timeouts. [`AiQo/Features/Captain/CaptainViewModel.swift:113`; `AiQo/Features/Captain/CaptainViewModel.swift:115`; `AiQo/Features/Captain/CaptainViewModel.swift:118`; `AiQo/Features/Captain/CaptainViewModel.swift:534`]
- ElevenLabs config uses `eleven_multilingual_v2`, `mp3_44100_128`, stability 0.34, similarity boost 0.88, style 0.18, and speaker boost true. [`AiQo/Core/CaptainVoiceAPI.swift:9`; `AiQo/Core/CaptainVoiceAPI.swift:81`; `AiQo/Core/CaptainVoiceAPI.swift:99`; `AiQo/Core/CaptainVoiceAPI.swift:100`; `AiQo/Core/CaptainVoiceAPI.swift:101`; `AiQo/Core/CaptainVoiceAPI.swift:102`]
- Voice-cache storage lives in `Documents/HamoudiVoiceCache`. [`AiQo/Core/CaptainVoiceCache.swift:50`]
- Remote TTS fallback order is cache -> ElevenLabs when configured -> local `AVSpeechSynthesizer`. [`AiQo/Core/CaptainVoiceService.swift:351`; `AiQo/Core/CaptainVoiceService.swift:216`; `AiQo/Core/CaptainVoiceService.swift:22`]
- Pre-cached phrase: `يلا قوم تحرّك شوية`. [`AiQo/Core/CaptainVoiceCache.swift:9`]
- Pre-cached phrase: `تمرين قوي، أحسنت يا بطل`. [`AiQo/Core/CaptainVoiceCache.swift:10`]
- Pre-cached phrase: `كمّل كمّل لا توقف`. [`AiQo/Core/CaptainVoiceCache.swift:11`]
- Pre-cached phrase: `باقيلك شوية، لا تستسلم`. [`AiQo/Core/CaptainVoiceCache.swift:12`]
- Pre-cached phrase: `شربت ماي؟ يلا اشرب كوب`. [`AiQo/Core/CaptainVoiceCache.swift:15`]
- Pre-cached phrase: `خلّصت هدف الماي، تمام`. [`AiQo/Core/CaptainVoiceCache.swift:16`]
- Pre-cached phrase: `وقت الفطور، خل ناكل صحّي`. [`AiQo/Core/CaptainVoiceCache.swift:19`]
- Pre-cached phrase: `وقت الغداء`. [`AiQo/Core/CaptainVoiceCache.swift:20`]
- Pre-cached phrase: `وقت العشاء`. [`AiQo/Core/CaptainVoiceCache.swift:21`]
- Pre-cached phrase: `يلا نام بدري اليوم، جسمك يحتاج راحة`. [`AiQo/Core/CaptainVoiceCache.swift:24`]
- Pre-cached phrase: `صباح الخير، يلا نبدأ يومنا`. [`AiQo/Core/CaptainVoiceCache.swift:25`]
- Pre-cached phrase: `كل يوم أحسن من اللي قبله، كمّل`. [`AiQo/Core/CaptainVoiceCache.swift:28`]
- Pre-cached phrase: `سلسلة قوية، لا تكطعها`. [`AiQo/Core/CaptainVoiceCache.swift:29`]

# SECTION 7 — Data Models & Persistence
- There are three distinct SwiftData persistence lanes in active use: the Captain lane, the main app / arena lane, and the quest lane. [`AiQo/App/AppDelegate.swift:37`; `AiQo/App/AppDelegate.swift:80`; `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:29`]
- The Captain lane persists `CaptainMemory`, `PersistentChatMessage`, `RecordProject`, and `WeeklyLog`. [`AiQo/App/AppDelegate.swift:20`; `AiQo/App/AppDelegate.swift:23`]
- The main lane persists `AiQoDailyRecord`, `WorkoutTask`, and the Arena model set. [`AiQo/App/AppDelegate.swift:81`; `AiQo/App/AppDelegate.swift:88`]
- The quest lane persists `PlayerStats`, `QuestStage`, `QuestRecord`, and `Reward`. [`AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:30`; `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:33`]
- Keychain usage was found only for free-trial state via service `com.aiqo.trial` and account `trialStartDate`. [`AiQo/Premium/FreeTrialManager.swift:129`; `AiQo/Premium/FreeTrialManager.swift:130`]
- File-based persistence paths found in code are `captain_memory.store`, `Analytics/events.jsonl`, `CrashReports/crash_log.jsonl`, the tmp crash fallback, and `Documents/HamoudiVoiceCache`. [`AiQo/App/AppDelegate.swift:30`; `AiQo/Services/Analytics/AnalyticsService.swift:138`; `AiQo/Services/CrashReporting/CrashReporter.swift:19`; `AiQo/Services/CrashReporting/CrashReporter.swift:17`; `AiQo/Core/CaptainVoiceCache.swift:50`]
- Appendix B contains the extracted defaults-key inventory and Appendix E contains the full `@Model` inventory with field lists. [`AiQo/Features/Captain/CaptainViewModel.swift:126`; `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:10`]

## Raw `@Published` Inventory
- `@Published var isCaptainChatPresented = false` — `AiQo/App/AppRootManager.swift:8`
- `@Published var isLoading = false` — `AiQo/App/LoginViewController.swift:98`
- `@Published var errorMessage: String?` — `AiQo/App/LoginViewController.swift:99`
- `@Published var selectedTab: Tab = .home` — `AiQo/App/MainTabRouter.swift:15`
- `@Published private(set) var currentScreen: RootScreen` — `AiQo/App/SceneDelegate.swift:29`
- `@Published private(set) var refreshID = UUID()` — `AiQo/App/SceneDelegate.swift:30`
- `@Published private(set) var isPlaying: Bool = false` — `AiQo/Core/AiQoAudioManager.swift:10`
- `@Published private(set) var playbackState: VibePlaybackState = .stopped` — `AiQo/Core/AiQoAudioManager.swift:11`
- `@Published private(set) var detailText: String = "AiQo ambient ready"` — `AiQo/Core/AiQoAudioManager.swift:12`
- `@Published private(set) var currentTrackName: String?` — `AiQo/Core/AiQoAudioManager.swift:13`
- `@Published var lastErrorMessage: String?` — `AiQo/Core/AiQoAudioManager.swift:14`
- `@Published var lastErrorCode: String?` — `AiQo/Core/AiQoAudioManager.swift:15`
- `@Published private(set) var isSpeaking = false` — `AiQo/Core/CaptainVoiceService.swift:14`
- `@Published var level: Int = 1` — `AiQo/Core/Models/LevelStore.swift:55`
- `@Published var currentXP: Int = 0` — `AiQo/Core/Models/LevelStore.swift:56`
- `@Published var totalXP: Int = 0` — `AiQo/Core/Models/LevelStore.swift:57`
- `@Published var activeProductId: String? {` — `AiQo/Core/Purchases/EntitlementStore.swift:8`
- `@Published var expiresAt: Date? {` — `AiQo/Core/Purchases/EntitlementStore.swift:15`
- `@Published var currentTier: SubscriptionTier = .none` — `AiQo/Core/Purchases/EntitlementStore.swift:21`
- `@Published private(set) var products: [Product] = []` — `AiQo/Core/Purchases/PurchaseManager.swift:24`
- `@Published private(set) var isLoadingProducts = false` — `AiQo/Core/Purchases/PurchaseManager.swift:25`
- `@Published private(set) var productLoadErrorMessage: String?` — `AiQo/Core/Purchases/PurchaseManager.swift:26`
- `@Published private(set) var productLoadDebugDetails: String?` — `AiQo/Core/Purchases/PurchaseManager.swift:27`
- `@Published private(set) var lastOutcome: PurchaseOutcome?` — `AiQo/Core/Purchases/PurchaseManager.swift:28`
- `@Published private(set) var isConnected: Bool = false` — `AiQo/Core/SpotifyVibeManager.swift:17`
- `@Published private(set) var isSpotifyAppInstalled: Bool = false` — `AiQo/Core/SpotifyVibeManager.swift:18`
- `@Published var currentTrackName: String = "Not Playing"` — `AiQo/Core/SpotifyVibeManager.swift:19`
- `@Published var currentArtistName: String = ""` — `AiQo/Core/SpotifyVibeManager.swift:20`
- `@Published var currentAlbumArt: UIImage? = nil` — `AiQo/Core/SpotifyVibeManager.swift:21`
- `@Published var isPaused: Bool = true` — `AiQo/Core/SpotifyVibeManager.swift:22`
- `@Published private(set) var currentVibeTitle: String?` — `AiQo/Core/SpotifyVibeManager.swift:23`
- `@Published private(set) var playbackState: VibePlaybackState = .stopped` — `AiQo/Core/SpotifyVibeManager.swift:24`
- `@Published var lastErrorMessage: String?` — `AiQo/Core/SpotifyVibeManager.swift:25`
- `@Published var lastErrorCode: String?` — `AiQo/Core/SpotifyVibeManager.swift:26`
- `@Published private(set) var isConnected: Bool = false` — `AiQo/Core/SpotifyVibeManager.swift:656`
- `@Published private(set) var isSpotifyAppInstalled: Bool = false` — `AiQo/Core/SpotifyVibeManager.swift:657`
- `@Published var currentTrackName: String = "Spotify unavailable on Simulator"` — `AiQo/Core/SpotifyVibeManager.swift:658`
- `@Published var currentArtistName: String = ""` — `AiQo/Core/SpotifyVibeManager.swift:659`
- `@Published var currentAlbumArt: UIImage? = nil` — `AiQo/Core/SpotifyVibeManager.swift:660`
- `@Published var isPaused: Bool = true` — `AiQo/Core/SpotifyVibeManager.swift:661`
- `@Published private(set) var currentVibeTitle: String?` — `AiQo/Core/SpotifyVibeManager.swift:662`
- `@Published private(set) var playbackState: VibePlaybackState = .stopped` — `AiQo/Core/SpotifyVibeManager.swift:663`
- `@Published var lastErrorMessage: String?` — `AiQo/Core/SpotifyVibeManager.swift:664`
- `@Published var lastErrorCode: String?` — `AiQo/Core/SpotifyVibeManager.swift:665`
- `@Published private(set) var currentStreak: Int = 0` — `AiQo/Core/StreakManager.swift:9`
- `@Published private(set) var longestStreak: Int = 0` — `AiQo/Core/StreakManager.swift:10`
- `@Published private(set) var lastActiveDate: Date?` — `AiQo/Core/StreakManager.swift:11`
- `@Published private(set) var todayCompleted: Bool = false` — `AiQo/Core/StreakManager.swift:12`
- `@Published var tribePrivacyMode: PrivacyMode = .private {` — `AiQo/Core/UserProfileStore.swift:49`
- `@Published private(set) var currentState = VibeAudioState()` — `AiQo/Core/VibeAudioEngine.swift:141`
- `@Published private(set) var currentProfile: VibeDayProfile` — `AiQo/Core/VibeAudioEngine.swift:142`
- `@Published var lastErrorMessage: String?` — `AiQo/Core/VibeAudioEngine.swift:143`
- `@Published var lastErrorCode: String?` — `AiQo/Core/VibeAudioEngine.swift:144`
- `@Published var pendingNotificationMessage: String?` — `AiQo/Features/Captain/CaptainNotificationRouting.swift:9`
- `@Published var shouldNavigateToCaptain: Bool = false` — `AiQo/Features/Captain/CaptainNotificationRouting.swift:10`
- `@Published var messages: [ChatMessage] = []` — `AiQo/Features/Captain/CaptainViewModel.swift:90`
- `@Published var isLoading = false` — `AiQo/Features/Captain/CaptainViewModel.swift:91`
- `@Published var currentWorkoutPlan: WorkoutPlan?` — `AiQo/Features/Captain/CaptainViewModel.swift:92`
- `@Published var currentMealPlan: MealPlan?` — `AiQo/Features/Captain/CaptainViewModel.swift:93`
- `@Published var inputText: String = ""` — `AiQo/Features/Captain/CaptainViewModel.swift:94`
- `@Published var coachState: CoachCognitiveState = .idle` — `AiQo/Features/Captain/CaptainViewModel.swift:95`
- `@Published var showCustomization: Bool = false` — `AiQo/Features/Captain/CaptainViewModel.swift:96`
- `@Published var showChatHistory: Bool = false` — `AiQo/Features/Captain/CaptainViewModel.swift:97`
- `@Published var showProfile: Bool = false` — `AiQo/Features/Captain/CaptainViewModel.swift:98`
- `@Published var showGratitudeSession: Bool = false` — `AiQo/Features/Captain/CaptainViewModel.swift:99`
- `@Published var customization: CaptainCustomization = .default` — `AiQo/Features/Captain/CaptainViewModel.swift:100`
- `@Published var feedbackTrigger: Int = 0` — `AiQo/Features/Captain/CaptainViewModel.swift:101`
- `@Published var activeModule: ScreenContext = .mainChat` — `AiQo/Features/Captain/CaptainViewModel.swift:102`
- `@Published var quickReplies: [String] = []` — `AiQo/Features/Captain/CaptainViewModel.swift:103`
- `@Published var isAnalyzingEnergy: Bool = false` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:226`
- `@Published private(set) var lastResolvedEnglishIntent: String?` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:227`
- `@Published private(set) var lastPipelineError: String?` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:228`
- `@Published private(set) var lastInjectedSystemContext: String?` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:229`
- `@Published private(set) var phase: CoachBrainPhase = .idle` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:230`
- `@Published private(set) var liveStatusText: String?` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:231`
- `@Published private(set) var debugDiagnosticMessage: String?` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:233`
- `@Published var state: State = .intro` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:370`
- `@Published var loadingTitle = NSLocalizedString("legacy.loading.permissions.title", value: "نطلب Apple Health", comment: "")` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:371`
- `@Published var loadingSubtitle = NSLocalizedString("legacy.loading.permissions.subtitle", value: "مرّة واحدة فقط للوصول إلى تاريخك الصحي الكامل", comment: "")` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:372`
- `@Published private(set) var phase: Phase = .idle` — `AiQo/Features/Gym/HandsFreeZone2Manager.swift:173`
- `@Published private(set) var displayText = "Captain is ready to keep your pace locked in."` — `AiQo/Features/Gym/HandsFreeZone2Manager.swift:174`
- `@Published private(set) var waveformLevels = Array(repeating: CGFloat(0.18), count: 10)` — `AiQo/Features/Gym/HandsFreeZone2Manager.swift:175`
- `@Published var title: String = "Gym Workout"` — `AiQo/Features/Gym/LiveWorkoutSession.swift:45`
- `@Published var phase: Phase = .idle` — `AiQo/Features/Gym/LiveWorkoutSession.swift:46`
- `@Published var heartRate: Double = 0` — `AiQo/Features/Gym/LiveWorkoutSession.swift:49`
- `@Published var activeEnergy: Double = 0` — `AiQo/Features/Gym/LiveWorkoutSession.swift:50`
- `@Published var distanceMeters: Double = 0` — `AiQo/Features/Gym/LiveWorkoutSession.swift:51`
- `@Published var elapsedSeconds: Int = 0` — `AiQo/Features/Gym/LiveWorkoutSession.swift:52`
- `@Published private(set) var zone2AuraState: Zone2AuraState = .inactive` — `AiQo/Features/Gym/LiveWorkoutSession.swift:54`
- `@Published private(set) var zone2LowerBoundBPM: Double = 0` — `AiQo/Features/Gym/LiveWorkoutSession.swift:55`
- `@Published private(set) var zone2UpperBoundBPM: Double = 0` — `AiQo/Features/Gym/LiveWorkoutSession.swift:56`
- `@Published private(set) var resolvedUserAge: Int = 0` — `AiQo/Features/Gym/LiveWorkoutSession.swift:57`
- `@Published private(set) var activeLiveBuffs: [WorkoutActivityAttributes.Buff] = []` — `AiQo/Features/Gym/LiveWorkoutSession.swift:58`
- `@Published private(set) var remoteConnectionState: WorkoutConnectionState = .idle` — `AiQo/Features/Gym/LiveWorkoutSession.swift:59`
- `@Published private(set) var mirroredSessionID: String?` — `AiQo/Features/Gym/LiveWorkoutSession.swift:60`
- `@Published private(set) var isControlPending: Bool = false` — `AiQo/Features/Gym/LiveWorkoutSession.swift:61`
- `@Published var isWatchReachable: Bool = false` — `AiQo/Features/Gym/LiveWorkoutSession.swift:63`
- `@Published var showMilestoneAlert: Bool = false` — `AiQo/Features/Gym/LiveWorkoutSession.swift:66`
- `@Published var milestoneAlertText: String = ""` — `AiQo/Features/Gym/LiveWorkoutSession.swift:67`
- `@Published var lastError: String? = nil` — `AiQo/Features/Gym/LiveWorkoutSession.swift:70`
- `@Published private(set) var samples: [HKQuantitySample] = []` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:756`
- `@Published private(set) var linePoints: [HeartRateLinePoint] = []` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:757`
- `@Published private(set) var zoneSlices: [HeartRateZoneSlice] = HeartRateZoneBucket.allCases.map {` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:758`
- `@Published private(set) var recoveryPoints: [HeartRateRecoveryPoint] = []` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:761`
- `@Published private(set) var peakMoments: [HeartRatePeakMoment] = []` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:762`
- `@Published private(set) var zoneLowerBound: Double = 0` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:763`
- `@Published private(set) var zoneUpperBound: Double = 0` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:764`
- `@Published private(set) var isLoading = false` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:765`
- `@Published private(set) var stages: [QuestStageViewModel]` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:26`
- `@Published private(set) var progressByQuestId: [String: QuestProgressRecord]` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:27`
- `@Published private(set) var isRefreshing: Bool = false` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:28`
- `@Published private(set) var lastRefreshDate: Date?` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:29`
- `@Published private(set) var isHealthAuthorized: Bool = false` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:30`
- `@Published private(set) var hasSleepDataInOvernightWindow: Bool = true` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:31`
- `@Published private(set) var debugOverrides = QuestDebugOverrides()` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:34`
- `@Published private(set) var progressByChallengeID: [String: Double] = [:]` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:44`
- `@Published private(set) var trackingChallengeIDs: Set<String> = []` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:45`
- `@Published private(set) var completedChallengeIDs: Set<String> = []` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:46`
- `@Published private(set) var activeReward: PendingChallengeReward?` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:47`
- `@Published private(set) var isPlankTimerRunning = false` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:49`
- `@Published private(set) var currentPlankSetSeconds = 0` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:50`
- `@Published var selectedPlankPresetSeconds = 30` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:51`
- `@Published private(set) var wins: [WinRecord] = []` — `AiQo/Features/Gym/Quests/Store/WinsStore.swift:6`
- `@Published private(set) var cameraState: CameraState = .idle` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:18`
- `@Published private(set) var repCount: Int = 0` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:19`
- `@Published private(set) var accuracyPercent: Double = 0` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:20`
- `@Published private(set) var coachingHint: String = L10n.t("quests.vision.hint.initial")` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:21`
- `@Published var sections: [WorkoutHistorySection] = []` — `AiQo/Features/Gym/RecapViewController.swift:622`
- `@Published var isLoading: Bool = false` — `AiQo/Features/Gym/RecapViewController.swift:623`
- `@Published var elapsedSeconds: Int = 0` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:16`
- `@Published var heartRate: Int = 122` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:17`
- `@Published var calories: Int = 87` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:18`
- `@Published var distance: Double = 1.26` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:19`
- `@Published var isRunning: Bool = false` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:20`
- `@Published var wheelState: WheelState = .idle` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:23`
- `@Published var selectedMedia: MediaMode = .none` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:24`
- `@Published var rotationAngle: Double = 0` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:25`
- `@Published var workoutVideos: [WorkoutVideo] = [` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:28`
- `@Published private(set) var connectionStatus: WatchConnectionStatus` — `AiQo/Features/Gym/WatchConnectivityService.swift:12`
- `@Published private(set) var isWorkoutStartAllowed: Bool` — `AiQo/Features/Gym/WatchConnectivityService.swift:13`
- `@Published private(set) var watchConnectionStatus: WatchConnectionStatus` — `AiQo/Features/Gym/WorkoutSessionViewModel.swift:15`
- `@Published private(set) var primaryControl: PrimaryControlConfiguration` — `AiQo/Features/Gym/WorkoutSessionViewModel.swift:16`
- `@Published private(set) var stepsToday: Int = 0` — `AiQo/Features/Home/DailyAuraViewModel.swift:7`
- `@Published private(set) var caloriesToday: Double = 0` — `AiQo/Features/Home/DailyAuraViewModel.swift:8`
- `@Published private(set) var goals: DailyGoals` — `AiQo/Features/Home/DailyAuraViewModel.swift:9`
- `@Published private(set) var historyByDay: [String: DailyRecord] = [:]` — `AiQo/Features/Home/DailyAuraViewModel.swift:10`
- `@Published private(set) var metricCards: [MetricCardData] = []` — `AiQo/Features/Home/HomeViewModel.swift:133`
- `@Published private(set) var currentSummary: TodaySummary?` — `AiQo/Features/Home/HomeViewModel.swift:136`
- `@Published private(set) var isLoading: Bool = false` — `AiQo/Features/Home/HomeViewModel.swift:139`
- `@Published private(set) var error: Error?` — `AiQo/Features/Home/HomeViewModel.swift:142`
- `@Published var expandedMetric: MetricKind?` — `AiQo/Features/Home/HomeViewModel.swift:145`
- `@Published private(set) var chartData: ChartSeriesData = .empty` — `AiQo/Features/Home/HomeViewModel.swift:148`
- `@Published var selectedScope: TimeScope = .day {` — `AiQo/Features/Home/HomeViewModel.swift:151`
- `@Published private(set) var currentWaterLiters: Double = 0.0` — `AiQo/Features/Home/HomeViewModel.swift:164`
- `@Published var activeDestination: HomeDestination?` — `AiQo/Features/Home/HomeViewModel.swift:167`
- `@Published var activeDetailMetric: MetricKind?` — `AiQo/Features/Home/HomeViewModel.swift:170`
- `@Published private(set) var selectedMode: VibeMode` — `AiQo/Features/Home/VibeControlSheet.swift:133`
- `@Published private(set) var lastActivatedMode: VibeMode?` — `AiQo/Features/Home/VibeControlSheet.swift:134`
- `@Published var selectedSource: VibePlaybackSource {` — `AiQo/Features/Home/VibeControlSheet.swift:135`
- `@Published var mixWithOthers: Bool {` — `AiQo/Features/Home/VibeControlSheet.swift:140`
- `@Published var nativeIntensity: Double {` — `AiQo/Features/Home/VibeControlSheet.swift:145`
- `@Published var fridgeItems: [FridgeItem] = [] {` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:7`
- `@Published var pinnedPlan: KitchenMealPlan? {` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:14`
- `@Published var shoppingList: [ShoppingListItem] = [] {` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:21`
- `@Published var needsPurchaseOverrides: Set<String> = [] {` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:28`
- `@Published private(set) var permissionState: PermissionState = .idle` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:26`
- `@Published private(set) var scanPhase: ScanPhase = .previewing` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:27`
- `@Published private(set) var capturedImage: UIImage?` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:28`
- `@Published private(set) var analyzedItems: [FridgeItem] = []` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:29`
- `@Published private(set) var processingTextKey: String = "kitchen.scanner.processing.biofuel"` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:30`
- `@Published private(set) var errorTextKey: String?` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:31`
- `@Published private(set) var latestResultID: UUID?` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:32`
- `@Published var records: [LegendaryRecord] = LegendaryRecord.seedRecords` — `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:10`
- `@Published var activeProject: LegendaryProject?` — `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:11`
- `@Published private(set) var currentState: DailyVibeState` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:10`
- `@Published private(set) var isPlaying = false` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:11`
- `@Published private(set) var bioFrequencyStatus: String = "Ready"` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:12`
- `@Published private(set) var spotifyTrackName: String = "Not Playing"` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:13`
- `@Published private(set) var spotifyArtistName: String = ""` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:14`
- `@Published private(set) var isSpotifyConnected = false` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:15`
- `@Published private(set) var spotifyOverrideName: String?` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:16`
- `@Published var showDJChat = false` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:17`
- `@Published var djSearchText = ""` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:18`
- `@Published private(set) var currentState: DailyVibeState` — `AiQo/Features/MyVibe/VibeOrchestrator.swift:18`
- `@Published private(set) var isActive = false` — `AiQo/Features/MyVibe/VibeOrchestrator.swift:19`
- `@Published private(set) var spotifyOverrideActive = false` — `AiQo/Features/MyVibe/VibeOrchestrator.swift:20`
- `@Published private(set) var overridePlaylistName: String?` — `AiQo/Features/MyVibe/VibeOrchestrator.swift:21`
- `@Published private(set) var entries: [ProgressPhotoEntry] = []` — `AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift:9`
- `@Published private(set) var hasMorePages = false` — `AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift:13`
- `@Published private(set) var mode: SmartWakeMode` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:6`
- `@Published private(set) var bedtime: Date` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:7`
- `@Published private(set) var latestWakeTime: Date` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:8`
- `@Published private(set) var wakeWindow: SmartWakeWindow` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:9`
- `@Published private(set) var selectedRecommendationID: String?` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:10`
- `@Published private(set) var featuredRecommendation: SmartWakeRecommendation?` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:11`
- `@Published private(set) var alternateRecommendations: [SmartWakeRecommendation]` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:12`
- `@Published private(set) var inlineMessage: String?` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:13`
- `@Published private(set) var alarmSaveState: AlarmSaveState` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:14`
- `@Published private(set) var currentUser: TribeLeaderboardUser` — `AiQo/Features/Tribe/TribeView.swift:933`
- `@Published var reportData: WeeklyReportData?` — `AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift:9`
- `@Published var isLoading = true` — `AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift:10`
- `@Published var metrics: [ReportMetricItem] = []` — `AiQo/Features/WeeklyReport/WeeklyReportViewModel.swift:11`
- `@Published var isReachable = false` — `AiQo/PhoneConnectivityManager.swift:36`
- `@Published var isPaired = false` — `AiQo/PhoneConnectivityManager.swift:37`
- `@Published var isWatchAppInstalled = false` — `AiQo/PhoneConnectivityManager.swift:38`
- `@Published var activationState: WCSessionActivationState = .notActivated` — `AiQo/PhoneConnectivityManager.swift:39`
- `@Published var currentHeartRate: Double = 0` — `AiQo/PhoneConnectivityManager.swift:41`
- `@Published var currentAverageHeartRate: Double = 0` — `AiQo/PhoneConnectivityManager.swift:42`
- `@Published var activeEnergy: Double = 0` — `AiQo/PhoneConnectivityManager.swift:43`
- `@Published var currentDuration: Double = 0` — `AiQo/PhoneConnectivityManager.swift:44`
- `@Published var currentDistance: Double = 0` — `AiQo/PhoneConnectivityManager.swift:45`
- `@Published private(set) var mirroredSessionID: String?` — `AiQo/PhoneConnectivityManager.swift:47`
- `@Published private(set) var currentWorkoutPhase: WorkoutSessionPhase = .idle` — `AiQo/PhoneConnectivityManager.swift:48`
- `@Published private(set) var workoutConnectionState: WorkoutConnectionState = .idle` — `AiQo/PhoneConnectivityManager.swift:49`
- `@Published private(set) var latestSnapshot: WorkoutSessionStateDTO?` — `AiQo/PhoneConnectivityManager.swift:50`
- `@Published private(set) var latestSnapshotContext: WorkoutSyncSnapshot?` — `AiQo/PhoneConnectivityManager.swift:51`
- `@Published private(set) var lastAcknowledgement: WorkoutSyncAcknowledgement?` — `AiQo/PhoneConnectivityManager.swift:52`
- `@Published private(set) var eventLog: [String] = []` — `AiQo/PhoneConnectivityManager.swift:53`
- `@Published private(set) var hasMirroredSession = false` — `AiQo/PhoneConnectivityManager.swift:54`
- `@Published private(set) var isCommandInFlight = false` — `AiQo/PhoneConnectivityManager.swift:55`
- `@Published var lastReceived: String = "None"` — `AiQo/PhoneConnectivityManager.swift:57`
- `@Published var lastSent: String = "None"` — `AiQo/PhoneConnectivityManager.swift:58`
- `@Published var lastError: String = "None"` — `AiQo/PhoneConnectivityManager.swift:59`
- `@Published private(set) var previewEnabled = false` — `AiQo/Premium/AccessManager.swift:8`
- `@Published private(set) var useMockTribeData = true` — `AiQo/Premium/AccessManager.swift:9`
- `@Published private(set) var selectedPreviewPlan: PremiumPlan = .family` — `AiQo/Premium/AccessManager.swift:10`
- `@Published private(set) var configurationVersion = 0` — `AiQo/Premium/AccessManager.swift:11`
- `@Published private(set) var entitlementSnapshot: EntitlementSnapshot = .locked` — `AiQo/Premium/AccessManager.swift:12`
- `@Published private(set) var trialState: TrialState = .notStarted` — `AiQo/Premium/FreeTrialManager.swift:11`
- `@Published private(set) var products: [Product] = []` — `AiQo/Premium/PremiumStore.swift:43`
- `@Published private(set) var isLoading = false` — `AiQo/Premium/PremiumStore.swift:44`
- `@Published private(set) var statusMessage: String?` — `AiQo/Premium/PremiumStore.swift:45`
- `@Published var selection = FamilyActivitySelection()` — `AiQo/ProtectionModel.swift:14`
- `@Published private(set) var isAuthorized: Bool = false` — `AiQo/ProtectionModel.swift:15`
- `@Published var pendingDeepLink: DeepLink?` — `AiQo/Services/DeepLinkRouter.swift:21`
- `@Published private(set) var isConnected = true` — `AiQo/Services/NetworkMonitor.swift:10`
- `@Published private(set) var connectionType: ConnectionType = .unknown` — `AiQo/Services/NetworkMonitor.swift:11`
- `@Published private(set) var referralCode: String` — `AiQo/Services/ReferralManager.swift:8`
- `@Published private(set) var referralCount: Int` — `AiQo/Services/ReferralManager.swift:9`
- `@Published private(set) var bonusDaysEarned: Int` — `AiQo/Services/ReferralManager.swift:10`
- `@Published var balance: Int = 0 {` — `AiQo/Shared/CoinManager.swift:7`
- `@Published var todaySteps: Int = 0` — `AiQo/Shared/HealthKitManager.swift:43`
- `@Published var todayCalories: Double = 0` — `AiQo/Shared/HealthKitManager.swift:44`
- `@Published var todayDistanceKm: Double = 0` — `AiQo/Shared/HealthKitManager.swift:45`
- `@Published private(set) var completedChallenges: [CompletedChallengeEntry] = []` — `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift:172`
- `@Published var challenges: [TribeChallenge] = []` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:9`
- `@Published var activeChallengeId: String?` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:10`
- `@Published var createScope: ChallengeScope = .personal` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:11`
- `@Published var createCadence: ChallengeCadence = .daily` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:12`
- `@Published var createGoalType: ChallengeGoalType = .steps` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:13`
- `@Published var customTitle = ""` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:14`
- `@Published var message: String?` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:15`
- `/// Lightweight value type for leaderboard rows — avoids tuple in `@Published`.` — `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift:5`
- `@Published private(set) var members: [TribeMember] = []` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:9`
- `@Published private(set) var nodes: [GalaxyNode] = []` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:10`
- `@Published private(set) var edges: [GalaxyEdge] = []` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:11`
- `@Published private(set) var contributions: [ChallengeContribution] = []` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:12`
- `@Published var selectedNodeId: String?` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:13`
- `@Published var toastMessage: String?` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:14`
- `@Published var sparkEvent: GalaxySparkEvent?` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:15`
- `@Published var dragOffset: CGSize = .zero` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:16`
- `@Published var cardMode: GalaxyCardMode` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:17`
- `@Published var connectionStyle: GalaxyConnectionStyle` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:18`
- `@Published var featuredChallenges: [TribeChallenge] = []` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:19`
- `@Published var activeChallengeId: String?` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:20`
- `@Published var simplifiedPreview = false` — `AiQo/Tribe/Galaxy/GalaxyViewModel.swift:21`
- `@Published var state: PreviewState` — `AiQo/Tribe/Preview/TribePreviewController.swift:27`
- `@Published var tribe: Tribe?` — `AiQo/Tribe/Preview/TribePreviewController.swift:28`
- `@Published var members: [TribeMember]` — `AiQo/Tribe/Preview/TribePreviewController.swift:29`
- `@Published var missions: [TribeMission]` — `AiQo/Tribe/Preview/TribePreviewController.swift:30`
- `@Published var events: [TribeEvent]` — `AiQo/Tribe/Preview/TribePreviewController.swift:31`
- `@Published var energyProgress: (current: Int, target: Int)` — `AiQo/Tribe/Preview/TribePreviewController.swift:32`
- `@Published private(set) var challenges: [TribeChallenge] = []` — `AiQo/Tribe/Stores/ArenaStore.swift:12`
- `@Published private(set) var curatedChallenges: [TribeChallenge] = []` — `AiQo/Tribe/Stores/ArenaStore.swift:13`
- `@Published private(set) var pendingSuggestions: [GalaxyChallengeSuggestion] = []` — `AiQo/Tribe/Stores/ArenaStore.swift:14`
- `@Published var selectedCadence: ChallengeCadence = .daily` — `AiQo/Tribe/Stores/ArenaStore.swift:15`
- `@Published var showOnlyMyTribe = false` — `AiQo/Tribe/Stores/ArenaStore.swift:16`
- `@Published var activeChallengeId: String?` — `AiQo/Tribe/Stores/ArenaStore.swift:17`
- `@Published var statusMessage: String?` — `AiQo/Tribe/Stores/ArenaStore.swift:18`
- `@Published private(set) var members: [TribeMember] = []` — `AiQo/Tribe/Stores/GalaxyStore.swift:9`
- `@Published private(set) var nodes: [GalaxyNode] = []` — `AiQo/Tribe/Stores/GalaxyStore.swift:10`
- `@Published private(set) var edges: [GalaxyEdge] = []` — `AiQo/Tribe/Stores/GalaxyStore.swift:11`
- `@Published var selectedNodeId: String?` — `AiQo/Tribe/Stores/GalaxyStore.swift:12`
- `@Published var layoutStyle: GalaxyLayoutStyle = .network` — `AiQo/Tribe/Stores/GalaxyStore.swift:13`
- `@Published var dragOffset: CGSize = .zero` — `AiQo/Tribe/Stores/GalaxyStore.swift:14`
- `@Published var zoomScale: CGFloat = 1` — `AiQo/Tribe/Stores/GalaxyStore.swift:15`
- `@Published var toastMessage: String?` — `AiQo/Tribe/Stores/GalaxyStore.swift:16`
- `@Published var sparkEvent: GalaxySparkEvent?` — `AiQo/Tribe/Stores/GalaxyStore.swift:17`
- `@Published private(set) var events: [TribeEvent] = []` — `AiQo/Tribe/Stores/TribeLogStore.swift:6`
- `@Published var selectedTab: TribeDashboardTab = .tribe` — `AiQo/Tribe/TribeModuleViewModel.swift:7`
- `@Published var arenaScopeFilter: ArenaScopeFilter = .everyone {` — `AiQo/Tribe/TribeModuleViewModel.swift:8`
- `@Published var globalTimeFilter: GlobalTimeFilter = .today {` — `AiQo/Tribe/TribeModuleViewModel.swift:11`
- `@Published private(set) var isLoading = false` — `AiQo/Tribe/TribeModuleViewModel.swift:14`
- `@Published private(set) var heroSummary = TribeSummary(` — `AiQo/Tribe/TribeModuleViewModel.swift:15`
- `@Published private(set) var tribeStats: [TribeStatMiniCardModel] = []` — `AiQo/Tribe/TribeModuleViewModel.swift:25`
- `@Published private(set) var featuredMembers: [TribeRingMember] = []` — `AiQo/Tribe/TribeModuleViewModel.swift:26`
- `@Published private(set) var arenaHeroSummary = ArenaHeroSummary(` — `AiQo/Tribe/TribeModuleViewModel.swift:27`
- `@Published private(set) var arenaCompactChallenges: [ArenaCompactChallenge] = []` — `AiQo/Tribe/TribeModuleViewModel.swift:32`
- `@Published private(set) var arenaStats: [TribeStatMiniCardModel] = []` — `AiQo/Tribe/TribeModuleViewModel.swift:33`
- `@Published private(set) var arenaChallenges: [TribeChallenge] = []` — `AiQo/Tribe/TribeModuleViewModel.swift:34`
- `@Published private(set) var globalHeroTitle = "حضور عالمي هادئ"` — `AiQo/Tribe/TribeModuleViewModel.swift:35`
- `@Published private(set) var globalHeroSubtitle = "ترتيب يعكس الاستمرارية لا الضجيج."` — `AiQo/Tribe/TribeModuleViewModel.swift:36`
- `@Published private(set) var globalTopThree: [TribeGlobalRankEntry] = []` — `AiQo/Tribe/TribeModuleViewModel.swift:37`
- `@Published private(set) var globalRankings: [TribeGlobalRankEntry] = []` — `AiQo/Tribe/TribeModuleViewModel.swift:38`
- `@Published private(set) var currentUserGlobalEntry: TribeGlobalRankEntry?` — `AiQo/Tribe/TribeModuleViewModel.swift:39`
- `@Published private(set) var globalSelfRankSummary = GlobalSelfRankSummary(` — `AiQo/Tribe/TribeModuleViewModel.swift:40`
- `@Published private(set) var globalRankingRows: [GlobalRankingRowItem] = []` — `AiQo/Tribe/TribeModuleViewModel.swift:45`
- `@Published var currentTribe: Tribe?` — `AiQo/Tribe/TribeStore.swift:10`
- `@Published var members: [TribeMember] = []` — `AiQo/Tribe/TribeStore.swift:11`
- `@Published var missions: [TribeMission] = []` — `AiQo/Tribe/TribeStore.swift:12`
- `@Published var events: [TribeEvent] = []` — `AiQo/Tribe/TribeStore.swift:13`
- `@Published var inviteCodeInput = ""` — `AiQo/Tribe/TribeStore.swift:14`
- `@Published var loading = false` — `AiQo/Tribe/TribeStore.swift:15`
- `@Published var error: String?` — `AiQo/Tribe/TribeStore.swift:16`
- `@Published var isPhoneReachable = false` — `AiQoWatch Watch App/Services/WatchConnectivityService.swift:10`
- `@Published var todaySteps: Int = 0` — `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:9`
- `@Published var todayCalories: Int = 0` — `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:10`
- `@Published var todayDistanceKm: Double = 0.0` — `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:11`
- `@Published var todaySleepHours: Double = 0.0` — `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:12`
- `@Published var isActive = false` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:15`
- `@Published var isPaused = false` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:16`
- `@Published var elapsedSeconds: TimeInterval = 0` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:17`
- `@Published var activeCalories: Double = 0` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:18`
- `@Published var heartRate: Double = 0` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:19`
- `@Published var distance: Double = 0` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:20`
- `@Published var showingSummary = false` — `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:21`
- `@Published private(set) var lastMessage: String = ""` — `AiQoWatch Watch App/WatchConnectivityManager.swift:18`
- `@Published private(set) var isPhoneReachable: Bool = false` — `AiQoWatch Watch App/WatchConnectivityManager.swift:19`
- `@Published private(set) var lastMessage: String = ""` — `AiQoWatch Watch App/WatchConnectivityManager.swift:220`
- `@Published private(set) var isPhoneReachable: Bool = false` — `AiQoWatch Watch App/WatchConnectivityManager.swift:221`
- `@Published private(set) var selectedWorkout: HKWorkoutActivityType?` — `AiQoWatch Watch App/WorkoutManager.swift:57`
- `@Published var showingSummaryView = false {` — `AiQoWatch Watch App/WorkoutManager.swift:58`
- `@Published private(set) var running = false` — `AiQoWatch Watch App/WorkoutManager.swift:66`
- `@Published private(set) var workout: HKWorkout?` — `AiQoWatch Watch App/WorkoutManager.swift:67`
- `@Published private(set) var connectionState: WorkoutConnectionState = .idle` — `AiQoWatch Watch App/WorkoutManager.swift:68`
- `@Published private(set) var workoutPhase: WorkoutSessionPhase = .idle` — `AiQoWatch Watch App/WorkoutManager.swift:69`
- `@Published private(set) var averageHeartRate: Double = 0` — `AiQoWatch Watch App/WorkoutManager.swift:71`
- `@Published private(set) var heartRate: Double = 0` — `AiQoWatch Watch App/WorkoutManager.swift:72`
- `@Published private(set) var activeEnergy: Double = 0` — `AiQoWatch Watch App/WorkoutManager.swift:73`
- `@Published private(set) var distance: Double = 0` — `AiQoWatch Watch App/WorkoutManager.swift:74`
- `@Published private(set) var elapsedSeconds: TimeInterval = 0` — `AiQoWatch Watch App/WorkoutManager.swift:75`

# SECTION 8 — HealthKit Integration
- The unified `HealthKitService` reads step count, heart rate, resting heart rate, HRV SDNN, walking heart-rate average, active energy, walking/running distance, dietary water, VO2 max, sleep analysis, apple stand hour, and workouts. [`AiQo/Services/Permissions/HealthKit/HealthKitService.swift:44`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:56`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:73`]
- The unified `HealthKitService` writes dietary water, heart rate, resting heart rate, HRV SDNN, VO2 max, walking/running distance, and workouts. [`AiQo/Services/Permissions/HealthKit/HealthKitService.swift:76`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:98`]
- The shared `HealthKitManager` separately requests read access for heart rate, active energy, walking/running distance, cycling distance, step count, body mass, body fat percentage, lean body mass, sleep analysis, and activity summaries; it only shares workouts. [`AiQo/Shared/HealthKitManager.swift:77`; `AiQo/Shared/HealthKitManager.swift:82`; `AiQo/Shared/HealthKitManager.swift:92`]
- Onboarding requests HealthKit permission in the legacy calculation flow and again through the final onboarding completion path. [`AiQo/Features/First screen/LegacyCalculationViewController.swift:74`; `AiQo/App/SceneDelegate.swift:72`]
- Sleep-stage parsing is detailed: `HealthManager+Sleep` resolves `awake`, `rem`, `core`, and `deep` stages, clusters the dominant session, and merges contiguous segments. [`AiQo/Features/Sleep/HealthManager+Sleep.swift:6`; `AiQo/Features/Sleep/HealthManager+Sleep.swift:206`; `AiQo/Features/Sleep/HealthManager+Sleep.swift:260`]
- Health-to-Captain prompting flows through `CaptainContextBuilder`, which emits a `CaptainSystemContextSnapshot` and then `CaptainContextData`. [`AiQo/Features/Captain/CaptainContextBuilder.swift:119`; `AiQo/Features/Captain/CaptainContextBuilder.swift:191`]
- Health-to-memory bridging copies weight, resting heart rate, average steps, average active calories, and average sleep into Captain memory. [`AiQo/Core/HealthKitMemoryBridge.swift:27`; `AiQo/Core/HealthKitMemoryBridge.swift:59`]
- Background health observation is enabled for step count with hourly delivery and a 60-second throttle. [`AiQo/Shared/HealthKitManager.swift:175`; `AiQo/Shared/HealthKitManager.swift:58`]
- Watch-side HealthKit reads step count, active energy, distance walking/running, heart rate, sleep analysis, and workouts; it shares workouts. [`AiQoWatch Watch App/Services/WatchHealthKitManager.swift:15`; `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:23`]
- Cloud privacy rules deliberately avoid shipping raw personal health context by using cloud-safe categories and bucketed health values. [`AiQo/Core/MemoryStore.swift:173`; `AiQo/Features/Captain/PrivacySanitizer.swift:12`]

# SECTION 9 — Onboarding Flow
- The effective root-flow order is language selection -> login -> profile setup -> legacy calculation -> feature intro -> main tabs. [`AiQo/App/SceneDelegate.swift:188`; `AiQo/App/SceneDelegate.swift:189`; `AiQo/App/SceneDelegate.swift:192`; `AiQo/App/SceneDelegate.swift:196`; `AiQo/App/SceneDelegate.swift:201`]
- Language selection defaults to Arabic and persists the chosen `AppLanguage`. [`AiQo/App/LanguageSelectionView.swift:6`; `AiQo/App/LanguageSelectionView.swift:74`]
- Login is Sign in with Apple only, and the Apple credential is exchanged with Supabase using `signInWithIdToken(provider: .apple, ...)`. [`AiQo/App/LoginViewController.swift:49`; `AiQo/App/LoginViewController.swift:141`; `AiQo/App/LoginViewController.swift:142`]
- Profile setup collects name, username, birth date, gender, weight, height, and profile visibility, then syncs visibility to Supabase in the background. [`AiQo/App/ProfileSetupView.swift:4`; `AiQo/App/ProfileSetupView.swift:10`; `AiQo/App/ProfileSetupView.swift:182`]
- Legacy calculation asks for HealthKit + notification permissions, computes an initial level from historical health data, persists level fields, and allows skipping to home. [`AiQo/Features/First screen/LegacyCalculationViewController.swift:109`; `AiQo/Features/First screen/LegacyCalculationViewController.swift:444`; `AiQo/Features/First screen/LegacyCalculationViewController.swift:168`]
- Feature intro is a three-page walkthrough and completes onboarding through its final CTA. [`AiQo/Features/Onboarding/FeatureIntroView.swift:49`; `AiQo/Features/Onboarding/FeatureIntroView.swift:53`; `AiQo/Features/Onboarding/FeatureIntroView.swift:103`]
- No paywall is wired into the root onboarding state machine; premium paywalls exist separately in `Premium/` and `UI/Purchases/`. [`AiQo/App/SceneDelegate.swift:262`; `AiQo/Premium/PremiumPaywallView.swift:4`; `AiQo/UI/Purchases/PaywallView.swift:4`]
- Onboarding is controlled by defaults flags rather than Info.plist flags; the Info.plist booleans found are the unrelated `TRIBE_*` flags. [`AiQo/App/SceneDelegate.swift:7`; `AiQo/Info.plist:74`]
- A dead / unused onboarding artifact exists: `OnboardingWalkthroughView` is defined but not routed from the root-state machine. [`AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:4`; `AiQo/App/SceneDelegate.swift:233`]

# SECTION 10 — Feature Modules
## Home
- Status: **complete**. Home is one of the three live main tabs. [`AiQo/App/MainTabScreen.swift:28`; `AiQo/Features/Home/HomeView.swift:9`]
- AI routing: No dedicated `ScreenContext`; AI is reached via Captain or kitchen launch flows. [`AiQo/App/MainTabScreen.swift:28`; `AiQo/Features/Home/HomeView.swift:9`]
- Health footprint: Home consumes shared activity / aura data rather than declaring its own HealthKit type list. [`AiQo/App/MainTabScreen.swift:28`; `AiQo/Features/Home/HomeView.swift:9`]
- Feature flags / gates: no module-specific Info.plist feature flag was found in the scan; access is structural, permission-based, or entitlement-based. [`AiQo/App/MainTabScreen.swift:28`; `AiQo/Features/Home/HomeView.swift:9`]
- Key file count in this module bucket: 17 file(s). [`AiQo/App/MainTabScreen.swift:28`; `AiQo/Features/Home/HomeView.swift:9`]
- Key file: `AiQo/Features/Home/ActivityDataProviding.swift` — `AiQo/Features/Home/ActivityDataProviding.swift:1`
- Key file: `AiQo/Features/Home/DJCaptainChatView.swift` — `AiQo/Features/Home/DJCaptainChatView.swift:1`
- Key file: `AiQo/Features/Home/DailyAuraModels.swift` — `AiQo/Features/Home/DailyAuraModels.swift:1`
- Key file: `AiQo/Features/Home/DailyAuraPathData.swift` — `AiQo/Features/Home/DailyAuraPathData.swift:1`
- Key file: `AiQo/Features/Home/DailyAuraView.swift` — `AiQo/Features/Home/DailyAuraView.swift:1`
- Key file: `AiQo/Features/Home/DailyAuraViewModel.swift` — `AiQo/Features/Home/DailyAuraViewModel.swift:1`
- Key file: `AiQo/Features/Home/HealthKitService+Water.swift` — `AiQo/Features/Home/HealthKitService+Water.swift:1`
- Key file: `AiQo/Features/Home/HomeStatCard.swift` — `AiQo/Features/Home/HomeStatCard.swift:1`
- Key file: `AiQo/Features/Home/HomeView.swift` — `AiQo/Features/Home/HomeView.swift:1`
- Key file: `AiQo/Features/Home/HomeViewModel.swift` — `AiQo/Features/Home/HomeViewModel.swift:1`
- Key file: `AiQo/Features/Home/LevelUpCelebrationView.swift` — `AiQo/Features/Home/LevelUpCelebrationView.swift:1`
- Key file: `AiQo/Features/Home/MetricKind.swift` — `AiQo/Features/Home/MetricKind.swift:1`
- Key file: `AiQo/Features/Home/SpotifyVibeCard.swift` — `AiQo/Features/Home/SpotifyVibeCard.swift:1`
- Key file: `AiQo/Features/Home/StreakBadgeView.swift` — `AiQo/Features/Home/StreakBadgeView.swift:1`
- Key file: `AiQo/Features/Home/VibeControlSheet.swift` — `AiQo/Features/Home/VibeControlSheet.swift:1`
- Key file: `AiQo/Features/Home/WaterBottleView.swift` — `AiQo/Features/Home/WaterBottleView.swift:1`
- Key file: `AiQo/Features/Home/WaterDetailSheetView.swift` — `AiQo/Features/Home/WaterDetailSheetView.swift:1`

## Gym/Peaks
- Status: **complete**. Gym is live in the main tabs; Peaks exists inside the gym club / Captain routing stack. [`AiQo/App/MainTabScreen.swift:41`; `AiQo/Features/Captain/ScreenContext.swift:5`; `AiQo/Features/Captain/ScreenContext.swift:7`; `AiQo/Features/Gym/Club/ClubRootView.swift:66`]
- AI routing: `ScreenContext.gym` and `ScreenContext.peaks`. [`AiQo/App/MainTabScreen.swift:41`; `AiQo/Features/Captain/ScreenContext.swift:5`; `AiQo/Features/Captain/ScreenContext.swift:7`; `AiQo/Features/Gym/Club/ClubRootView.swift:66`]
- Health footprint: Gym consumes workouts, heart rate, calories, distance, and recovery surfaces. [`AiQo/App/MainTabScreen.swift:41`; `AiQo/Features/Captain/ScreenContext.swift:5`; `AiQo/Features/Captain/ScreenContext.swift:7`; `AiQo/Features/Gym/Club/ClubRootView.swift:66`]
- Feature flags / gates: Peaks is also entitlement-gated by `AccessManager.canAccessPeaks`. [`AiQo/App/MainTabScreen.swift:41`; `AiQo/Features/Captain/ScreenContext.swift:5`; `AiQo/Features/Captain/ScreenContext.swift:7`; `AiQo/Features/Gym/Club/ClubRootView.swift:66`]
- Key file count in this module bucket: 84 file(s). [`AiQo/App/MainTabScreen.swift:41`; `AiQo/Features/Captain/ScreenContext.swift:5`; `AiQo/Features/Captain/ScreenContext.swift:7`; `AiQo/Features/Gym/Club/ClubRootView.swift:66`]
- Key file: `AiQo/Features/Gym/ActiveRecoveryView.swift` — `AiQo/Features/Gym/ActiveRecoveryView.swift:1`
- Key file: `AiQo/Features/Gym/AudioCoachManager.swift` — `AiQo/Features/Gym/AudioCoachManager.swift:1`
- Key file: `AiQo/Features/Gym/CinematicGrindCardView.swift` — `AiQo/Features/Gym/CinematicGrindCardView.swift:1`
- Key file: `AiQo/Features/Gym/CinematicGrindViews.swift` — `AiQo/Features/Gym/CinematicGrindViews.swift:1`
- Key file: `AiQo/Features/Gym/Club/Body/BodyView.swift` — `AiQo/Features/Gym/Club/Body/BodyView.swift:1`
- Key file: `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift` — `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift:1`
- Key file: `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift` — `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift:1`
- Key file: `AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift` — `AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift:1`
- Key file: `AiQo/Features/Gym/Club/Challenges/ChallengesView.swift` — `AiQo/Features/Gym/Club/Challenges/ChallengesView.swift:1`
- Key file: `AiQo/Features/Gym/Club/ClubRootView.swift` — `AiQo/Features/Gym/Club/ClubRootView.swift:1`
- Key file: `AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift` — `AiQo/Features/Gym/Club/Components/ClubNavigationComponents.swift:1`
- Key file: `AiQo/Features/Gym/Club/Components/RailScrollOffsetPreferenceKey.swift` — `AiQo/Features/Gym/Club/Components/RailScrollOffsetPreferenceKey.swift:1`
- Key file: `AiQo/Features/Gym/Club/Components/RightSideRailView.swift` — `AiQo/Features/Gym/Club/Components/RightSideRailView.swift:1`
- Key file: `AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift` — `AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift:1`
- Key file: `AiQo/Features/Gym/Club/Components/SegmentedTabs.swift` — `AiQo/Features/Gym/Club/Components/SegmentedTabs.swift:1`
- Key file: `AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift` — `AiQo/Features/Gym/Club/Components/SlimRightSideRail.swift:1`
- Key file: `AiQo/Features/Gym/Club/Impact/ImpactAchievementsView.swift` — `AiQo/Features/Gym/Club/Impact/ImpactAchievementsView.swift:1`
- Key file: `AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift` — `AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift:1`
- Key file: `AiQo/Features/Gym/Club/Impact/ImpactSummaryView.swift` — `AiQo/Features/Gym/Club/Impact/ImpactSummaryView.swift:1`
- Key file: `AiQo/Features/Gym/Club/Plan/PlanView.swift` — `AiQo/Features/Gym/Club/Plan/PlanView.swift:1`
- Additional module files omitted from the inline list: 64 more file(s). [`AiQo/App/MainTabScreen.swift:41`; `AiQo/Features/Captain/ScreenContext.swift:5`; `AiQo/Features/Captain/ScreenContext.swift:7`; `AiQo/Features/Gym/Club/ClubRootView.swift:66`]

## Alchemy Kitchen
- Status: **hidden**. Kitchen has a substantial code surface and a deep link, but it is not a live main tab. [`AiQo/Services/DeepLinkRouter.swift:15`; `AiQo/Features/Kitchen/KitchenScreen.swift:3`]
- AI routing: `ScreenContext.kitchen`. [`AiQo/Services/DeepLinkRouter.swift:15`; `AiQo/Features/Kitchen/KitchenScreen.swift:3`]
- Health footprint: Kitchen is meal / fridge / image-analysis oriented and does not declare its own HealthKit type list. [`AiQo/Services/DeepLinkRouter.swift:15`; `AiQo/Features/Kitchen/KitchenScreen.swift:3`]
- Feature flags / gates: no module-specific Info.plist feature flag was found in the scan; access is structural, permission-based, or entitlement-based. [`AiQo/Services/DeepLinkRouter.swift:15`; `AiQo/Features/Kitchen/KitchenScreen.swift:3`]
- Key file count in this module bucket: 33 file(s). [`AiQo/Services/DeepLinkRouter.swift:15`; `AiQo/Features/Kitchen/KitchenScreen.swift:3`]
- Key file: `AiQo/Features/Kitchen/CameraView.swift` — `AiQo/Features/Kitchen/CameraView.swift:1`
- Key file: `AiQo/Features/Kitchen/CompositePlateView.swift` — `AiQo/Features/Kitchen/CompositePlateView.swift:1`
- Key file: `AiQo/Features/Kitchen/FridgeInventoryView.swift` — `AiQo/Features/Kitchen/FridgeInventoryView.swift:1`
- Key file: `AiQo/Features/Kitchen/IngredientAssetCatalog.swift` — `AiQo/Features/Kitchen/IngredientAssetCatalog.swift:1`
- Key file: `AiQo/Features/Kitchen/IngredientAssetLibrary.swift` — `AiQo/Features/Kitchen/IngredientAssetLibrary.swift:1`
- Key file: `AiQo/Features/Kitchen/IngredientCatalog.swift` — `AiQo/Features/Kitchen/IngredientCatalog.swift:1`
- Key file: `AiQo/Features/Kitchen/IngredientDisplayItem.swift` — `AiQo/Features/Kitchen/IngredientDisplayItem.swift:1`
- Key file: `AiQo/Features/Kitchen/IngredientKey.swift` — `AiQo/Features/Kitchen/IngredientKey.swift:1`
- Key file: `AiQo/Features/Kitchen/InteractiveFridgeView.swift` — `AiQo/Features/Kitchen/InteractiveFridgeView.swift:1`
- Key file: `AiQo/Features/Kitchen/KitchenLanguageRouter.swift` — `AiQo/Features/Kitchen/KitchenLanguageRouter.swift:1`
- Key file: `AiQo/Features/Kitchen/KitchenModels.swift` — `AiQo/Features/Kitchen/KitchenModels.swift:1`
- Key file: `AiQo/Features/Kitchen/KitchenPersistenceStore.swift` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:1`
- Key file: `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift` — `AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:1`
- Key file: `AiQo/Features/Kitchen/KitchenSceneView.swift` — `AiQo/Features/Kitchen/KitchenSceneView.swift:1`
- Key file: `AiQo/Features/Kitchen/KitchenScreen.swift` — `AiQo/Features/Kitchen/KitchenScreen.swift:1`
- Key file: `AiQo/Features/Kitchen/KitchenView.swift` — `AiQo/Features/Kitchen/KitchenView.swift:1`
- Key file: `AiQo/Features/Kitchen/KitchenViewModel.swift` — `AiQo/Features/Kitchen/KitchenViewModel.swift:1`
- Key file: `AiQo/Features/Kitchen/LocalMealsRepository.swift` — `AiQo/Features/Kitchen/LocalMealsRepository.swift:1`
- Key file: `AiQo/Features/Kitchen/Meal.swift` — `AiQo/Features/Kitchen/Meal.swift:1`
- Key file: `AiQo/Features/Kitchen/MealIllustrationView.swift` — `AiQo/Features/Kitchen/MealIllustrationView.swift:1`
- Additional module files omitted from the inline list: 13 more file(s). [`AiQo/Services/DeepLinkRouter.swift:15`; `AiQo/Features/Kitchen/KitchenScreen.swift:3`]

## Sleep
- Status: **in-progress**. Sleep analysis, smart wake, and observers exist, but sleep is not surfaced as a top-level tab. [`AiQo/Features/Captain/ScreenContext.swift:6`; `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:8`]
- AI routing: `ScreenContext.sleepAnalysis`. [`AiQo/Features/Captain/ScreenContext.swift:6`; `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:8`]
- Health footprint: Sleep consumes `sleepAnalysis` and derived stage segments / smart-wake windows. [`AiQo/Features/Captain/ScreenContext.swift:6`; `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:8`]
- Feature flags / gates: no module-specific Info.plist feature flag was found in the scan; access is structural, permission-based, or entitlement-based. [`AiQo/Features/Captain/ScreenContext.swift:6`; `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:8`]
- Key file count in this module bucket: 9 file(s). [`AiQo/Features/Captain/ScreenContext.swift:6`; `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:8`]
- Key file: `AiQo/Features/Sleep/AlarmSetupCardView.swift` — `AiQo/Features/Sleep/AlarmSetupCardView.swift:1`
- Key file: `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift` — `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:1`
- Key file: `AiQo/Features/Sleep/HealthManager+Sleep.swift` — `AiQo/Features/Sleep/HealthManager+Sleep.swift:1`
- Key file: `AiQo/Features/Sleep/SleepDetailCardView.swift` — `AiQo/Features/Sleep/SleepDetailCardView.swift:1`
- Key file: `AiQo/Features/Sleep/SleepScoreRingView.swift` — `AiQo/Features/Sleep/SleepScoreRingView.swift:1`
- Key file: `AiQo/Features/Sleep/SleepSessionObserver.swift` — `AiQo/Features/Sleep/SleepSessionObserver.swift:1`
- Key file: `AiQo/Features/Sleep/SmartWakeCalculatorView.swift` — `AiQo/Features/Sleep/SmartWakeCalculatorView.swift:1`
- Key file: `AiQo/Features/Sleep/SmartWakeEngine.swift` — `AiQo/Features/Sleep/SmartWakeEngine.swift:1`
- Key file: `AiQo/Features/Sleep/SmartWakeViewModel.swift` — `AiQo/Features/Sleep/SmartWakeViewModel.swift:1`

## My Vibe
- Status: **hidden**. My Vibe files and Captain routing exist, but it is not part of the main tab shell. [`AiQo/Features/Captain/ScreenContext.swift:9`; `AiQo/Features/MyVibe/MyVibeScreen.swift:3`]
- AI routing: `ScreenContext.myVibe`. [`AiQo/Features/Captain/ScreenContext.swift:9`; `AiQo/Features/MyVibe/MyVibeScreen.swift:3`]
- Health footprint: My Vibe focuses on vibe / Spotify orchestration rather than module-local HealthKit declarations. [`AiQo/Features/Captain/ScreenContext.swift:9`; `AiQo/Features/MyVibe/MyVibeScreen.swift:3`]
- Feature flags / gates: no module-specific Info.plist feature flag was found in the scan; access is structural, permission-based, or entitlement-based. [`AiQo/Features/Captain/ScreenContext.swift:9`; `AiQo/Features/MyVibe/MyVibeScreen.swift:3`]
- Key file count in this module bucket: 8 file(s). [`AiQo/Features/Captain/ScreenContext.swift:9`; `AiQo/Features/MyVibe/MyVibeScreen.swift:3`]
- Key file: `AiQo/Core/SpotifyVibeManager.swift` — `AiQo/Core/SpotifyVibeManager.swift:1`
- Key file: `AiQo/Core/VibeAudioEngine.swift` — `AiQo/Core/VibeAudioEngine.swift:1`
- Key file: `AiQo/Features/Home/SpotifyVibeCard.swift` — `AiQo/Features/Home/SpotifyVibeCard.swift:1`
- Key file: `AiQo/Features/MyVibe/DailyVibeState.swift` — `AiQo/Features/MyVibe/DailyVibeState.swift:1`
- Key file: `AiQo/Features/MyVibe/MyVibeScreen.swift` — `AiQo/Features/MyVibe/MyVibeScreen.swift:1`
- Key file: `AiQo/Features/MyVibe/MyVibeSubviews.swift` — `AiQo/Features/MyVibe/MyVibeSubviews.swift:1`
- Key file: `AiQo/Features/MyVibe/MyVibeViewModel.swift` — `AiQo/Features/MyVibe/MyVibeViewModel.swift:1`
- Key file: `AiQo/Features/MyVibe/VibeOrchestrator.swift` — `AiQo/Features/MyVibe/VibeOrchestrator.swift:1`

## Tribe/Emara
- Status: **hidden / stub**. Tribe is feature-flagged off and still contains mocks / TODOs. [`AiQo/Info.plist:76`; `AiQo/Tribe/Repositories/TribeRepositories.swift:28`]
- AI routing: No dedicated `ScreenContext` was found. [`AiQo/Info.plist:76`; `AiQo/Tribe/Repositories/TribeRepositories.swift:28`]
- Health footprint: Tribe uses synced profile / participation stats rather than direct HealthKit queries. [`AiQo/Info.plist:76`; `AiQo/Tribe/Repositories/TribeRepositories.swift:28`]
- Feature flags / gates: Controlled by `TRIBE_BACKEND_ENABLED`, `TRIBE_FEATURE_VISIBLE`, and `TRIBE_SUBSCRIPTION_GATE_ENABLED`, all currently false. [`AiQo/Info.plist:76`; `AiQo/Tribe/Repositories/TribeRepositories.swift:28`]
- Key file count in this module bucket: 61 file(s). [`AiQo/Info.plist:76`; `AiQo/Tribe/Repositories/TribeRepositories.swift:28`]
- Key file: `AiQo/Features/Tribe/TribeDesignSystem.swift` — `AiQo/Features/Tribe/TribeDesignSystem.swift:1`
- Key file: `AiQo/Features/Tribe/TribeExperienceFlow.swift` — `AiQo/Features/Tribe/TribeExperienceFlow.swift:1`
- Key file: `AiQo/Features/Tribe/TribeView.swift` — `AiQo/Features/Tribe/TribeView.swift:1`
- Key file: `AiQo/Tribe/Arena/TribeArenaView.swift` — `AiQo/Tribe/Arena/TribeArenaView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift` — `AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift` — `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaModels.swift` — `AiQo/Tribe/Galaxy/ArenaModels.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift` — `AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaScreen.swift` — `AiQo/Tribe/Galaxy/ArenaScreen.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaTabView.swift` — `AiQo/Tribe/Galaxy/ArenaTabView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaViewModel.swift` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:1`
- Key file: `AiQo/Tribe/Galaxy/BattleLeaderboard.swift` — `AiQo/Tribe/Galaxy/BattleLeaderboard.swift:1`
- Key file: `AiQo/Tribe/Galaxy/BattleLeaderboardRow.swift` — `AiQo/Tribe/Galaxy/BattleLeaderboardRow.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ConstellationCanvasView.swift` — `AiQo/Tribe/Galaxy/ConstellationCanvasView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/CountdownTimerView.swift` — `AiQo/Tribe/Galaxy/CountdownTimerView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/CreateTribeSheet.swift` — `AiQo/Tribe/Galaxy/CreateTribeSheet.swift:1`
- Key file: `AiQo/Tribe/Galaxy/EditTribeNameSheet.swift` — `AiQo/Tribe/Galaxy/EditTribeNameSheet.swift:1`
- Key file: `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift` — `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift:1`
- Key file: `AiQo/Tribe/Galaxy/EmirateLeadersBanner.swift` — `AiQo/Tribe/Galaxy/EmirateLeadersBanner.swift:1`
- Key file: `AiQo/Tribe/Galaxy/GalaxyCanvasView.swift` — `AiQo/Tribe/Galaxy/GalaxyCanvasView.swift:1`
- Additional module files omitted from the inline list: 41 more file(s). [`AiQo/Info.plist:76`; `AiQo/Tribe/Repositories/TribeRepositories.swift:28`]

## Arena
- Status: **hidden / stub**. Arena code and Supabase services exist, but visibility flags are off and mock data remains. [`AiQo/Info.plist:74`; `AiQo/Services/SupabaseArenaService.swift:10`]
- AI routing: No dedicated `ScreenContext` was found. [`AiQo/Info.plist:74`; `AiQo/Services/SupabaseArenaService.swift:10`]
- Health footprint: Arena uses challenge / participation / synced points state. [`AiQo/Info.plist:74`; `AiQo/Services/SupabaseArenaService.swift:10`]
- Feature flags / gates: Controlled by the same `TRIBE_*` flags because Arena is embedded inside the tribe / galaxy surface. [`AiQo/Info.plist:74`; `AiQo/Services/SupabaseArenaService.swift:10`]
- Key file count in this module bucket: 12 file(s). [`AiQo/Info.plist:74`; `AiQo/Services/SupabaseArenaService.swift:10`]
- Key file: `AiQo/Services/SupabaseArenaService.swift` — `AiQo/Services/SupabaseArenaService.swift:1`
- Key file: `AiQo/Tribe/Arena/TribeArenaView.swift` — `AiQo/Tribe/Arena/TribeArenaView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift` — `AiQo/Tribe/Galaxy/ArenaChallengeDetailView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift` — `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaModels.swift` — `AiQo/Tribe/Galaxy/ArenaModels.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift` — `AiQo/Tribe/Galaxy/ArenaQuickChallengesView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaScreen.swift` — `AiQo/Tribe/Galaxy/ArenaScreen.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaTabView.swift` — `AiQo/Tribe/Galaxy/ArenaTabView.swift:1`
- Key file: `AiQo/Tribe/Galaxy/ArenaViewModel.swift` — `AiQo/Tribe/Galaxy/ArenaViewModel.swift:1`
- Key file: `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift` — `AiQo/Tribe/Galaxy/EmaraArenaViewModel.swift:1`
- Key file: `AiQo/Tribe/Galaxy/MockArenaData.swift` — `AiQo/Tribe/Galaxy/MockArenaData.swift:1`
- Key file: `AiQo/Tribe/Stores/ArenaStore.swift` — `AiQo/Tribe/Stores/ArenaStore.swift:1`

## Profile
- Status: **complete**. A full profile screen exists and is integrated with shared user-profile flows. [`AiQo/Features/Profile/ProfileScreen.swift:208`; `AiQo/App/ProfileSetupView.swift:3`]
- AI routing: No dedicated `ScreenContext` was found. [`AiQo/Features/Profile/ProfileScreen.swift:208`; `AiQo/App/ProfileSetupView.swift:3`]
- Health footprint: Profile leans on shared user-profile and level / streak state rather than module-local HealthKit declarations. [`AiQo/Features/Profile/ProfileScreen.swift:208`; `AiQo/App/ProfileSetupView.swift:3`]
- Feature flags / gates: no module-specific Info.plist feature flag was found in the scan; access is structural, permission-based, or entitlement-based. [`AiQo/Features/Profile/ProfileScreen.swift:208`; `AiQo/App/ProfileSetupView.swift:3`]
- Key file count in this module bucket: 5 file(s). [`AiQo/Features/Profile/ProfileScreen.swift:208`; `AiQo/App/ProfileSetupView.swift:3`]
- Key file: `AiQo/Core/UserProfileStore.swift` — `AiQo/Core/UserProfileStore.swift:1`
- Key file: `AiQo/Features/Profile/LevelCardView.swift` — `AiQo/Features/Profile/LevelCardView.swift:1`
- Key file: `AiQo/Features/Profile/ProfileScreen.swift` — `AiQo/Features/Profile/ProfileScreen.swift:1`
- Key file: `AiQo/Features/Profile/String+Localized.swift` — `AiQo/Features/Profile/String+Localized.swift:1`
- Key file: `AiQo/UI/AiQoProfileButton.swift` — `AiQo/UI/AiQoProfileButton.swift:1`

## Settings
- Status: **complete**. Settings screens exist and are addressable by deep link. [`AiQo/Core/AppSettingsScreen.swift:5`; `AiQo/Services/DeepLinkRouter.swift:16`]
- AI routing: No dedicated `ScreenContext` was found. [`AiQo/Core/AppSettingsScreen.swift:5`; `AiQo/Services/DeepLinkRouter.swift:16`]
- Health footprint: Settings is configuration-focused; no module-local HealthKit declaration was found. [`AiQo/Core/AppSettingsScreen.swift:5`; `AiQo/Services/DeepLinkRouter.swift:16`]
- Feature flags / gates: no module-specific Info.plist feature flag was found in the scan; access is structural, permission-based, or entitlement-based. [`AiQo/Core/AppSettingsScreen.swift:5`; `AiQo/Services/DeepLinkRouter.swift:16`]
- Key file count in this module bucket: 5 file(s). [`AiQo/Core/AppSettingsScreen.swift:5`; `AiQo/Services/DeepLinkRouter.swift:16`]
- Key file: `AiQo/Core/AppSettingsScreen.swift` — `AiQo/Core/AppSettingsScreen.swift:1`
- Key file: `AiQo/Core/AppSettingsStore.swift` — `AiQo/Core/AppSettingsStore.swift:1`
- Key file: `AiQo/Core/CaptainMemorySettingsView.swift` — `AiQo/Core/CaptainMemorySettingsView.swift:1`
- Key file: `AiQo/Core/DeveloperPanelView.swift` — `AiQo/Core/DeveloperPanelView.swift:1`
- Key file: `AiQo/UI/ReferralSettingsRow.swift` — `AiQo/UI/ReferralSettingsRow.swift:1`

## Legendary Challenges
- Status: **in-progress**. The module has SwiftData persistence but still carries migration bridges and seeded records. [`AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:6`; `AiQo/Premium/AccessManager.swift:48`]
- AI routing: No dedicated `ScreenContext` was found; weekly review uses a direct Gemini call. [`AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:6`; `AiQo/Premium/AccessManager.swift:48`]
- Health footprint: Legendary challenges consume synced level / performance state and can observe watch workout metrics through HRR tooling. [`AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:6`; `AiQo/Premium/AccessManager.swift:48`]
- Feature flags / gates: Record projects are entitlement-gated by `AccessManager.canAccessRecordProjects`. [`AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:6`; `AiQo/Premium/AccessManager.swift:48`]
- Key file count in this module bucket: 15 file(s). [`AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:6`; `AiQo/Premium/AccessManager.swift:48`]
- Key file: `AiQo/Features/LegendaryChallenges/Components/RecordCard.swift` — `AiQo/Features/LegendaryChallenges/Components/RecordCard.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Models/LegendaryProject.swift` — `AiQo/Features/LegendaryChallenges/Models/LegendaryProject.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift` — `AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift` — `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift` — `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift` — `AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift` — `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift` — `AiQo/Features/LegendaryChallenges/Views/LegendaryChallengesSection.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Views/ProjectView.swift` — `AiQo/Features/LegendaryChallenges/Views/ProjectView.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift` — `AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift` — `AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewResultView.swift` — `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewResultView.swift:1`
- Key file: `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift` — `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:1`

# SECTION 11 — Gamification System
- Session XP is `truthNumber + luckyNumber`, where `truthNumber = calories + minutes`, heartbeats are estimated from samples or average HR, `luckyNumber` is the sum of heartbeat digits, and `totalXP = truthNumber + luckyNumber`. [`AiQo/XPCalculator.swift:43`; `AiQo/XPCalculator.swift:70`; `AiQo/XPCalculator.swift:71`]
- Coin mining in `XPCalculator` is `steps / 100 + activeCalories / 50 + durationMinutes * 2 when averageHeartRate > 115`. [`AiQo/XPCalculator.swift:24`; `AiQo/XPCalculator.swift:26`; `AiQo/XPCalculator.swift:28`]
- A second coin-award path exists in `HealthKitManager`, creating a formula mismatch with `XPCalculator`. [`AiQo/Shared/HealthKitManager.swift:370`; `AiQo/Shared/HealthKitManager.swift:371`; `AiQo/Shared/HealthKitManager.swift:372`]
- Level progression uses `baseXP = 1000` with a multiplicative factor of `1.2` per level. [`AiQo/Core/Models/LevelStore.swift:64`; `AiQo/Core/Models/LevelStore.swift:65`]
- Shield tiers are wood (1-4), bronze (5-9), silver (10-14), gold (15-19), platinum (20-24), diamond (25-29), obsidian (30-34), and legendary (35+). [`AiQo/Core/Models/LevelStore.swift:13`; `AiQo/Core/Models/LevelStore.swift:20`]
- Shield-tier colors are `#8B4513`, `#CD7F32`, `#C0C0C0`, `#FFD700`, `#E5E4E2`, `#B9F2FF`, `#3D3D3D`, and `#FF6B6B`. [`AiQo/Core/Models/LevelStore.swift:38`; `AiQo/Core/Models/LevelStore.swift:45`]
- The streak system comment defines an active day as 5,000+ steps OR one workout OR 30+ minutes of activity; it persists current / longest / last-active / history keys and keeps 90 days of history. [`AiQo/Core/StreakManager.swift:5`; `AiQo/Core/StreakManager.swift:17`; `AiQo/Core/StreakManager.swift:158`]
- Streak color tiers are sand below 7, orange at 7+, and purple at 30+. [`AiQo/Features/Home/StreakBadgeView.swift:42`; `AiQo/Features/Home/StreakBadgeView.swift:44`]
- Motivation tiers in `StreakManager` are hard-coded for 0, 1, 2-3, 4-6, 7-13, 14-29, 30-59, 60-89, 90-364, and 365+ days. [`AiQo/Core/StreakManager.swift:107`; `AiQo/Core/StreakManager.swift:116`; `AiQo/Core/StreakManager.swift:117`]
- Quest persistence components include `PlayerStats`, `QuestStage`, `QuestRecord`, `Reward`, `UserDefaultsQuestProgressStore`, `QuestDailyStore`, `QuestAchievementStore`, and `WinsStore`. [`AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:11`; `AiQo/Features/Gym/QuestKit/QuestProgressStore.swift:10`; `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:43`; `AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift:19`; `AiQo/Features/Gym/Quests/Store/WinsStore.swift:5`]
- The reward seed catalog currently defines four badge rewards and one chest reward: `reward.streak.7day`, `reward.heart.hero`, `reward.step.master`, `reward.gratitude.mode`, and `reward.weekly.chest`. [`AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:288`; `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:340`]
- Badge unlock conditions are target-value based: 7-day streak, 3 target-BPM hits, one 10k-step day, and 5 gratitude logs; the seed titles are English and no dedicated Arabic badge catalog was found in the seed source. [`AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:294`; `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:333`]
- Legendary Challenges still rely on seeded records and a legacy UserDefaults -> SwiftData migration bridge. [`AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift:49`; `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:28`]
- Watch-side workout XP uses `Int(Double(calories) * 0.8 + (duration / 60) * 2)`, and the phone mirrors that formula for standalone watch-workout completion. [`AiQoWatch Watch App/Views/WatchWorkoutSummaryView.swift:13`; `AiQo/PhoneConnectivityManager.swift:756`]

# SECTION 12 — Monetization & StoreKit 2
- Current subscription product IDs are `aiqo_core_monthly_9_99`, `aiqo_pro_monthly_19_99`, and `aiqo_intelligence_monthly_39_99`. [`AiQo/Core/Purchases/SubscriptionProductIDs.swift:5`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:7`]
- Legacy product IDs are `aiqo_nr_30d_individual_5_99` and `aiqo_nr_30d_family_10_00`. [`AiQo/Core/Purchases/SubscriptionProductIDs.swift:10`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:11`]
- The free-trial duration is 7 days. [`AiQo/Premium/FreeTrialManager.swift:15`]
- The free trial is activated through onboarding / launch refresh flows. [`AiQo/App/SceneDelegate.swift:93`; `AiQo/App/AppDelegate.swift:116`]
- Tier gates are explicit in `AccessManager`: core unlocks Captain / gym / kitchen / My Vibe / challenges / tracking / notifications; pro unlocks peaks / HRR / weekly AI plan / record projects; intelligence unlocks extended memory + intelligence model. [`AiQo/Premium/AccessManager.swift:35`; `AiQo/Premium/AccessManager.swift:45`; `AiQo/Premium/AccessManager.swift:52`]
- Entitlements persist locally under `aiqo.purchases.activeProductId`, `aiqo.purchases.expiresAt`, and `aiqo.purchases.currentTier`. [`AiQo/Core/Purchases/EntitlementStore.swift:91`; `AiQo/Core/Purchases/EntitlementStore.swift:93`]
- StoreKit product loading currently requests only `SubscriptionProductIDs.allCurrentIDs`. [`AiQo/Core/Purchases/PurchaseManager.swift:75`; `AiQo/Core/Purchases/PurchaseManager.swift:93`]
- Purchase flow, restore flow, and detached receipt validation are all present in `PurchaseManager`. [`AiQo/Core/Purchases/PurchaseManager.swift:163`; `AiQo/Core/Purchases/PurchaseManager.swift:204`; `AiQo/Core/Purchases/PurchaseManager.swift:177`]
- Receipt validation targets a Supabase Edge Function. [`AiQo/Core/Purchases/ReceiptValidator.swift:10`]
- The premium paywall defaults to the `.pro` tier and advertises a one-week free trial CTA. [`AiQo/Premium/PremiumPaywallView.swift:10`; `AiQo/Premium/PremiumPaywallView.swift:185`]
- The DEBUG StoreKit file wired by `PurchaseManager` is `AiQo_Test.storekit`. [`AiQo/Core/Purchases/PurchaseManager.swift:39`]
- There is a code / config mismatch: `AiQo_Test.storekit` contains the new 3-tier renewable subscriptions, while `AiQo.storekit` still contains only legacy non-renewing individual / family products. [`AiQo/Resources/AiQo_Test.storekit:43`; `AiQo/Resources/AiQo.storekit:14`]
- There is also a UI mismatch: `UI/Purchases/PaywallView.swift` still contains family-specific legacy branches while current loading is driven by `allCurrentIDs`. [`AiQo/UI/Purchases/PaywallView.swift:16`; `AiQo/UI/Purchases/PaywallView.swift:165`]

# SECTION 13 — Supabase Backend
- Authentication strategy is Sign in with Apple -> Supabase Auth ID-token exchange -> `client.auth.currentUser` session checks. [`AiQo/App/LoginViewController.swift:141`; `AiQo/Services/SupabaseService.swift:114`; `AiQo/App/SceneDelegate.swift:179`]
- The core `SupabaseService` uses the `profiles` table for search, full-profile loading, single-profile loading, and device-token syncing. [`AiQo/Services/SupabaseService.swift:59`; `AiQo/Services/SupabaseService.swift:60`; `AiQo/Services/SupabaseService.swift:142`]
- The arena / tribe service uses `arena_tribes`, `arena_tribe_members`, `arena_tribe_participations`, `arena_weekly_challenges`, `arena_hall_of_fame_entries`, and `profiles`. [`AiQo/Services/SupabaseArenaService.swift:208`; `AiQo/Services/SupabaseArenaService.swift:224`; `AiQo/Services/SupabaseArenaService.swift:173`; `AiQo/Services/SupabaseArenaService.swift:526`; `AiQo/Services/SupabaseArenaService.swift:666`; `AiQo/Services/SupabaseArenaService.swift:562`]
- The only explicit Supabase Edge Function in the scanned code is `validate-receipt` for StoreKit receipt validation. [`AiQo/Core/Purchases/ReceiptValidator.swift:10`]
- No Supabase realtime / presence / broadcast channel usage was found in the scanned app code. [`AiQo/Services/SupabaseArenaService.swift:10`]
- RLS policy definitions are not present in the scanned repo; the app code strongly suggests user-scoped RLS expectations because updates and reads are filtered by `user_id` / `currentUser` client-side. [`AiQo/Services/SupabaseService.swift:143`; `AiQo/Services/SupabaseArenaService.swift:192`]
- Backend readiness is mixed: profiles auth is implemented and receipt validation has a concrete edge endpoint, but Tribe / Arena still carry mocks, disabled flags, and “before launch” TODOs. [`AiQo/Services/SupabaseService.swift:90`; `AiQo/Core/Purchases/ReceiptValidator.swift:10`; `AiQo/Info.plist:76`; `AiQo/Tribe/TribeStore.swift:65`]

# SECTION 14 — Notifications & Background Tasks
- Background task identifiers are `aiqo.captain.spiritual-whispers.refresh` and `aiqo.captain.inactivity-check`, declared in Info.plist and used by `NotificationIntelligenceManager`. [`AiQo/Info.plist:7`; `AiQo/Info.plist:8`; `AiQo/Services/Notifications/NotificationIntelligenceManager.swift:8`; `AiQo/Services/Notifications/NotificationIntelligenceManager.swift:9`]
- Named notification categories found in code include `aiqo.captain.smart`, `CAPTAIN_ANGEL_REMINDER`, `water_reminder`, `workout_motivation`, `sleep_reminder`, `streak_protection`, and `weekly_report`. [`AiQo/Services/Notifications/NotificationService.swift:139`; `AiQo/Services/Notifications/ActivityNotificationEngine.swift:39`; `AiQo/Core/SmartNotificationScheduler.swift:59`; `AiQo/Core/SmartNotificationScheduler.swift:177`]
- The static smart-notification schedule is fixed at water reminders 10/12/14/16/18/20, workout motivation 17:00, sleep reminder 22:30, streak protection 20:00, and weekly report Friday 10:00. [`AiQo/Core/SmartNotificationScheduler.swift:43`; `AiQo/Core/SmartNotificationScheduler.swift:85`; `AiQo/Core/SmartNotificationScheduler.swift:111`; `AiQo/Core/SmartNotificationScheduler.swift:112`; `AiQo/Core/SmartNotificationScheduler.swift:137`; `AiQo/Core/SmartNotificationScheduler.swift:164`]
- Cooldown values are explicit: 45 minutes for Captain inactivity in one service, 3 hours in background scheduling, 2h water, 4h meal, 1h step, and 20h sleep. [`AiQo/Services/Notifications/NotificationService.swift:156`; `AiQo/Services/Notifications/NotificationIntelligenceManager.swift:50`; `AiQo/Services/Notifications/NotificationService.swift:354`; `AiQo/Services/Notifications/NotificationService.swift:355`; `AiQo/Services/Notifications/NotificationService.swift:354`; `AiQo/Services/Notifications/NotificationService.swift:357`]
- Angel-number scheduling uses `01:11`, `02:22`, `03:33`, `04:44`, `05:55`, `10:10`, `11:11`, `12:12`, and `12:21`, with generated identifiers `aiqo.angel.<hour>.<minute>`. [`AiQo/Services/Notifications/ActivityNotificationEngine.swift:327`; `AiQo/Services/Notifications/ActivityNotificationEngine.swift:385`]
- Morning Habit uses `aiqo.morningHabit.notification`, source `morning_habit`, step threshold 25, and a 6-hour monitoring window. [`AiQo/Services/Notifications/MorningHabitOrchestrator.swift:20`; `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:21`; `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:35`; `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:36`]
- Sleep-session observer keys are `aiqo.sleepObserver.anchorData` and `aiqo.sleepObserver.lastNotifiedSleepEnd`. [`AiQo/Features/Sleep/SleepSessionObserver.swift:10`; `AiQo/Features/Sleep/SleepSessionObserver.swift:11`]
- AI workout summary monitoring keys are `aiqo.ai.workout.anchor` and `aiqo.ai.workout.processed.ids`, plus caps of 220 processed IDs, a 180-second fingerprint window, 40 fingerprints, and a 2-hour bootstrap lookback. [`AiQo/Services/Notifications/NotificationService.swift:435`; `AiQo/Services/Notifications/NotificationService.swift:437`; `AiQo/Services/Notifications/NotificationService.swift:438`; `AiQo/Services/Notifications/NotificationService.swift:439`; `AiQo/Services/Notifications/NotificationService.swift:440`]
- AlarmKit is used for smart wake on iOS 26.1+, with a fixed managed alarm UUID and source metadata `smart_wake`. [`AiQo/Services/Notifications/AlarmSchedulingService.swift:4`; `AiQo/Services/Notifications/AlarmSchedulingService.swift:127`; `AiQo/Services/Notifications/AlarmSchedulingService.swift:237`]

# SECTION 15 — Design System
- Named brand colors in `AiQoColors` are `mint = #CDF4E4` and `beige = #F5D5A6`. [`AiQo/DesignSystem/AiQoColors.swift:4`; `AiQo/DesignSystem/AiQoColors.swift:5`]
- The theme palette defines light/dark colors for `primaryBackground`, `surface`, `surfaceSecondary`, `textPrimary`, `textSecondary`, `accent`, `border`, `borderStrong`, `iconBackground`, `ctaGradientLeading`, and `ctaGradientTrailing`. [`AiQo/DesignSystem/AiQoTheme.swift:6`; `AiQo/DesignSystem/AiQoTheme.swift:16`]
- Core color aliases in `Colors.swift` include mint `#C4F0DB`, sand `#F8D6A3`, accent `#FFE68C`, aiqoBeige `#FADEB3`, lemon `#FFECB8`, and lav `#F5E0FF`. [`AiQo/Core/Colors.swift:13`; `AiQo/Core/Colors.swift:18`]
- Typography tokens in `AiQoTheme` are `screenTitle`, `sectionTitle`, `cardTitle`, `body`, `caption`, and `cta`. [`AiQo/DesignSystem/AiQoTheme.swift:19`; `AiQo/DesignSystem/AiQoTheme.swift:25`]
- Spacing tokens are `xs = 8`, `sm = 12`, `md = 16`, and `lg = 24`; radius tokens are `control = 12`, `card = 16`, and `ctaContainer = 24`; minimum tap target is `44`. [`AiQo/DesignSystem/AiQoTokens.swift:4`; `AiQo/DesignSystem/AiQoTokens.swift:13`; `AiQo/DesignSystem/AiQoTokens.swift:17`]
- Reusable accessibility / design-system helpers include `glassCard()`, `AiQoPressButtonStyle`, `AiQoAccessibility` modifiers, and `AccessibilityHelpers` helpers. [`AiQo/App/ProfileSetupView.swift:127`; `AiQo/Features/First screen/LegacyCalculationViewController.swift:145`; `AiQo/Core/AiQoAccessibility.swift:75`; `AiQo/UI/AccessibilityHelpers.swift:9`]
- Glassmorphism is actively used in onboarding / auth surfaces via `glassCard()`. [`AiQo/App/ProfileSetupView.swift:127`; `AiQo/Features/First screen/LegacyCalculationViewController.swift:182`]

# SECTION 16 — Apple Watch Companion
- The watch app entry point is `@main struct AiQoWatchApp: App`, with state objects for `WatchHealthKitManager`, `WatchWorkoutManager`, and `WatchConnectivityService`. [`AiQoWatch Watch App/AiQoWatchApp.swift:41`; `AiQoWatch Watch App/AiQoWatchApp.swift:50`; `AiQoWatch Watch App/AiQoWatchApp.swift:52`]
- Watch boot behavior prefers the active-workout UI when a workout is running and otherwise falls back to the main tab view. [`AiQoWatch Watch App/AiQoWatchApp.swift:57`; `AiQoWatch Watch App/AiQoWatchApp.swift:64`]
- The exact watch/phone schema is centralized in `WorkoutSyncModels.swift` via dictionary keys and typed DTOs for start requests, snapshots, state, commands, acknowledgements, payloads, and companion messages. [`AiQo/Shared/WorkoutSyncModels.swift:3`; `AiQo/Shared/WorkoutSyncModels.swift:75`; `AiQo/Shared/WorkoutSyncModels.swift:391`]
- Raw payload keys include `aiqo.workout.message.data`, `aiqo.workout.snapshot.context`, `companionCommand`, `requestedAt`, `activityTypeRaw`, `locationTypeRaw`, `hasActiveWorkout`, `isRunning`, `workoutName`, `activeEnergy`, `distance`, `heartRate`, `elapsedTime`, `lastUpdated`, `currentState`, `connectionState`, `averageHeartRate`, `workoutType`, and `sessionId`. [`AiQo/Shared/WorkoutSyncModels.swift:4`; `AiQo/Shared/WorkoutSyncModels.swift:22`]
- The compatibility start command string is still `startWalkingWorkout` even though the enum case is `startWorkout`. [`AiQo/Shared/WorkoutSyncModels.swift:27`]
- The watch also emits legacy event-style messages including `rep_detected`, `challenge_completed`, and `workout_completed` payloads. [`AiQoWatch Watch App/WatchConnectivityManager.swift:154`; `AiQoWatch Watch App/WatchConnectivityManager.swift:156`; `AiQoWatch Watch App/Services/WatchWorkoutManager.swift:99`]
- Watch HealthKit types are steps, active energy, distance walking/running, heart rate, sleep analysis, and workouts, with workouts also written back to HealthKit. [`AiQoWatch Watch App/Services/WatchHealthKitManager.swift:15`; `AiQoWatch Watch App/Services/WatchHealthKitManager.swift:23`]
- Watch XP uses `Int(Double(calories) * 0.8 + (duration / 60) * 2)`. [`AiQoWatch Watch App/Views/WatchWorkoutSummaryView.swift:13`]
- Watch UI responsibilities cover home rings / stats, active-workout controls, workout summary, and a workout-notification scene. [`AiQoWatch Watch App/Views/WatchHomeView.swift:3`; `AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift:3`; `AiQoWatch Watch App/Views/WatchWorkoutSummaryView.swift:3`; `AiQoWatch Watch App/AiQoWatchApp.swift:33`]
- Watch haptics are used for rep detection and challenge completion in `WatchConnectivityManager`. [`AiQoWatch Watch App/WatchConnectivityManager.swift:173`; `AiQoWatch Watch App/WatchConnectivityManager.swift:173`]
- Widget targets in the workspace include `AiQoWidget` and `AiQoWatchWidget`. [`AiQo.xcodeproj/project.pbxproj:1269`; `AiQo.xcodeproj/project.pbxproj:1561`]

# SECTION 17 — Analytics & Crash Reporting
- Analytics is provider-based: the app always installs a local JSONL provider and, in DEBUG, also installs a console provider. [`AiQo/Services/Analytics/AnalyticsService.swift:29`; `AiQo/Services/Analytics/AnalyticsService.swift:27`]
- Local analytics storage is `Application Support/Analytics/events.jsonl` with a hard cap of 5,000 events. [`AiQo/Services/Analytics/AnalyticsService.swift:138`; `AiQo/Services/Analytics/AnalyticsService.swift:131`]
- CrashReporter writes local crash JSONL data to `Application Support/CrashReports/crash_log.jsonl` and falls back to `temporaryDirectory/CrashReports/crash_log.jsonl`, trimming to 50 logs. [`AiQo/Services/CrashReporting/CrashReporter.swift:19`; `AiQo/Services/CrashReporting/CrashReporter.swift:17`; `AiQo/Services/CrashReporting/CrashReporter.swift:12`]
- Firebase Crashlytics integration is optional and only configures when the SDK can be imported. [`AiQo/Services/CrashReporting/CrashReportingService.swift:21`; `AiQo/Services/CrashReporting/CrashReportingService.swift:23`]
- Analytics coverage is incomplete in practice because some features still emit ad-hoc event names outside the central `AnalyticsEvent` definition file. [`AiQo/Services/DeepLinkRouter.swift:30`; `AiQo/Services/ReferralManager.swift:58`; `AiQo/Core/Purchases/ReceiptValidator.swift:92`]
## Complete Analytics Event Inventory
- `appLaunched` -> `app_launched` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:21`
- `appBecameActive` -> `app_became_active` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:22`
- `appEnteredBackground` -> `app_entered_background` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:23`
- `onboardingStepViewed` -> `onboarding_step_viewed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:26`
- `onboardingCompleted` -> `onboarding_completed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:29`
- `onboardingSkipped` -> `onboarding_skipped` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:30`
- `loginStarted` -> `login_started` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:33`
- `loginCompleted` -> `login_completed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:34`
- `logoutCompleted` -> `logout_completed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:35`
- `tabSelected` -> `tab_selected` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:38`
- `screenViewed` -> `screen_viewed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:42`
- `captainChatOpened` -> `captain_chat_opened` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:47`
- `captainMessageSent` -> `captain_message_sent` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:48`
- `captainResponseReceived` -> `captain_response_received` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:51`
- `captainResponseFailed` -> `captain_response_failed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:54`
- `captainVoicePlayed` -> `captain_voice_played` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:57`
- `captainHistoryViewed` -> `captain_history_viewed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:58`
- `workoutStarted` -> `workout_started` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:61`
- `workoutCompleted` -> `workout_completed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:64`
- `workoutCancelled` -> `workout_cancelled` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:71`
- `visionCoachStarted` -> `vision_coach_started` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:72`
- `visionCoachCompleted` -> `vision_coach_completed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:73`
- `questStarted` -> `quest_started` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:81`
- `questCompleted` -> `quest_completed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:84`
- `kitchenOpened` -> `kitchen_opened` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:89`
- `mealPlanGenerated` -> `meal_plan_generated` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:90`
- `fridgeItemAdded` -> `fridge_item_added` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:91`
- `tribeCreated` -> `tribe_created` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:94`
- `tribeJoined` -> `tribe_joined` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:95`
- `tribeLeft` -> `tribe_left` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:96`
- `tribeLeaderboardViewed` -> `tribe_leaderboard_viewed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:97`
- `tribeArenaViewed` -> `tribe_arena_viewed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:98`
- `spotifyConnected` -> `spotify_connected` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:101`
- `spotifyTrackPlayed` -> `spotify_track_played` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:102`
- `healthPermissionGranted` -> `health_permission_granted` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:107`
- `healthPermissionDenied` -> `health_permission_denied` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:110`
- `dailySummaryGenerated` -> `daily_summary_generated` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:111`
- `paywallViewed` -> `paywall_viewed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:120`
- `subscriptionStarted` -> `subscription_started` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:121`
- `subscriptionFailed` -> `subscription_failed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:127`
- `subscriptionRestored` -> `subscription_restored` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:133`
- `subscriptionCancelled` -> `subscription_cancelled` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:134`
- `freeTrialStarted` -> `free_trial_started` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:135`
- `notificationPermissionGranted` -> `notification_permission_granted` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:138`
- `notificationPermissionDenied` -> `notification_permission_denied` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:139`
- `notificationTapped` -> `notification_tapped` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:140`
- `languageChanged` -> `language_changed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:145`
- `memoryCleared` -> `memory_cleared` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:148`
- `errorOccurred` -> `error_occurred` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:151`

## Additional Ad-Hoc Analytics Event Calls Outside `AnalyticsEvent.swift`
- `receipt_validation_failed` — `AiQo/Core/Purchases/ReceiptValidator.swift:92`
- `$identify` — `AiQo/Services/Analytics/AnalyticsService.swift:171`
- `deep_link_opened` — `AiQo/Services/DeepLinkRouter.swift:30`
- `connectivity_lost` — `AiQo/Services/NetworkMonitor.swift:42`
- `connectivity_restored` — `AiQo/Services/NetworkMonitor.swift:44`
- `referral_code_applied` — `AiQo/Services/ReferralManager.swift:58`
- `referral_successful` — `AiQo/Services/ReferralManager.swift:73`

# SECTION 18 — Accessibility & Localization
- Accessibility helper coverage exists in dedicated helper files: `AiQoAccessibility` exposes metric-card, progress-ring, navigation-button, scaled-font, VoiceOver announcement, and reduce-motion helpers; `AccessibilityHelpers` adds accessible button / header / card helpers. [`AiQo/Core/AiQoAccessibility.swift:75`; `AiQo/Core/AiQoAccessibility.swift:47`; `AiQo/Core/AiQoAccessibility.swift:67`; `AiQo/UI/AccessibilityHelpers.swift:9`; `AiQo/UI/AccessibilityHelpers.swift:89`]
- Dynamic Type support is present in helper form through `scaledFont` helpers. [`AiQo/Core/AiQoAccessibility.swift:35`; `AiQo/UI/AccessibilityHelpers.swift:80`]
- Reduce Motion is explicitly observed in onboarding / feature-intro animation code through `@Environment(\.accessibilityReduceMotion)` and helper wrappers. [`AiQo/Features/Onboarding/FeatureIntroView.swift:29`; `AiQo/UI/AccessibilityHelpers.swift:89`]
- Localization file counts from the scanned `Localizable.strings` files are `1849` Arabic entries and `1850` English entries. [`AiQo/Resources/ar.lproj/Localizable.strings:26`; `AiQo/Resources/en.lproj/Localizable.strings:26`]
- RTL patterns are explicit on iPhone and watch surfaces through `.environment(\.layoutDirection, .rightToLeft)` in multiple entry screens. [`AiQo/App/LoginViewController.swift:81`; `AiQo/App/ProfileSetupView.swift:137`; `AiQo/App/MainTabScreen.swift:69`; `AiQoWatch Watch App/Views/WatchActiveWorkoutView.swift:17`]
- Feature names intentionally remain English in Arabic Captain replies: `My Vibe`, `Zone 2`, `Alchemy Kitchen`, `Arena`, and `Tribe` are the explicit exceptions. [`AiQo/Features/Captain/CaptainPromptBuilder.swift:90`]

# SECTION 19 — Feature Flags & Configuration
- Info.plist feature flags currently set `TRIBE_BACKEND_ENABLED = false`, `TRIBE_FEATURE_VISIBLE = false`, and `TRIBE_SUBSCRIPTION_GATE_ENABLED = false`. [`AiQo/Info.plist:74`; `AiQo/Info.plist:76`; `AiQo/Info.plist:78`]
- Configured xcconfig / secret keys include `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `CAPTAIN_API_KEY`, `COACH_BRAIN_LLM_API_KEY`, `COACH_BRAIN_LLM_API_URL`, `CAPTAIN_VOICE_API_KEY`, `CAPTAIN_VOICE_API_URL`, `CAPTAIN_VOICE_MODEL_ID`, `CAPTAIN_VOICE_VOICE_ID`, and `SPOTIFY_CLIENT_ID`. [`Configuration/AiQo.xcconfig:8`; `Configuration/Secrets.template.xcconfig:4`; `Configuration/Secrets.template.xcconfig:12`]
- URL schemes configured for the main app are `aiqo` and `aiqo-spotify`; `LSApplicationQueriesSchemes` additionally whitelists `spotify`, `instagram-stories`, and `instagram`. [`AiQo/Info.plist:31`; `AiQo/Info.plist:32`; `AiQo/Info.plist:42`; `AiQo/Info.plist:44`]
- Background modes on iPhone are `audio`, `remote-notification`, and `fetch`; the watch app declares `workout-processing` under `WKBackgroundModes`. [`AiQo/Info.plist:80`; `AiQoWatch-Watch-App-Info.plist:11`]
- NSUserActivityTypes are the eight workout / Captain / summary / kitchen / weekly-report identifiers in Info.plist. [`AiQo/Info.plist:53`]
- Major feature enable / disable levers are split between build secrets (`SUPABASE_*`, `CAPTAIN_*`, `SPOTIFY_CLIENT_ID`), Info.plist tribe flags, onboarding flags, and `AccessManager` entitlement gates. [`AiQo/Info.plist:10`; `AiQo/Info.plist:74`; `AiQo/App/SceneDelegate.swift:7`; `AiQo/Premium/AccessManager.swift:35`]

# SECTION 20 — Known Issues, Gaps & Roadmap
- Tribe / Arena is the clearest unfinished area: feature flags are off and repository / store layers still contain mocks and multiple “before launch” TODOs. [`AiQo/Info.plist:76`; `AiQo/Tribe/Repositories/TribeRepositories.swift:285`; `AiQo/Tribe/TribeStore.swift:65`]
- Onboarding still carries an unused walkthrough screen (`OnboardingWalkthroughView`) that is not wired into the root-state machine. [`AiQo/Features/Onboarding/OnboardingWalkthroughView.swift:4`; `AiQo/App/SceneDelegate.swift:233`]
- StoreKit and paywall migration is incomplete: legacy non-renewing IDs remain in `AiQo.storekit` and old UI branches, while the active code path expects the new three-tier catalog. [`AiQo/Resources/AiQo.storekit:14`; `AiQo/Core/Purchases/SubscriptionProductIDs.swift:5`; `AiQo/UI/Purchases/PaywallView.swift:165`]
- Some runtime configuration remains hard-coded in app code and should likely become remote or build-driven before wider release. [`AiQo/Features/Captain/HybridBrainService.swift:89`; `AiQo/Services/Notifications/MorningHabitOrchestrator.swift:35`; `AiQo/Services/Notifications/NotificationService.swift:437`]

## TODO / FIXME Inventory
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Features/Tribe/TribeExperienceFlow.swift:190`
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Features/Tribe/TribeExperienceFlow.swift:205`
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Features/Tribe/TribeExperienceFlow.swift:299`
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Features/Tribe/TribeExperienceFlow.swift:348`
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Features/Tribe/TribeExperienceFlow.swift:369`
- `// TODO: Remove mock delegation when backend is ready.` — `AiQo/Tribe/Repositories/TribeRepositories.swift:285`
- `// TODO: Remove mock delegation when backend is ready.` — `AiQo/Tribe/Repositories/TribeRepositories.swift:292`
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Tribe/TribeStore.swift:65`
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Tribe/TribeStore.swift:102`
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Tribe/TribeStore.swift:140`
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Tribe/TribeStore.swift:167`
- `// TODO before launch: replace with live SupabaseTribeRepository call.` — `AiQo/Tribe/TribeStore.swift:184`

## Stub / Mock Inventory
- `// Detail mock` — `AiQo/Features/Gym/WinsViewController.swift:54`
- `struct MockActivityProvider: ActivityDataProviding {` — `AiQo/Features/Home/ActivityDataProviding.swift:23`
- `DailyAuraView(viewModel: DailyAuraViewModel(provider: MockActivityProvider()))` — `AiQo/Features/Home/DailyAuraView.swift:428`
- `useMockTribeData ? "mock" : "liveData",` — `AiQo/Premium/AccessManager.swift:86`
- `let snapshot = await MockTribeRepository().loadSnapshot()` — `AiQo/Tribe/Galaxy/GalaxyView.swift:617`
- `enum MockArenaData {` — `AiQo/Tribe/Galaxy/MockArenaData.swift:4`
- `return MockTribeRepository()` — `AiQo/Tribe/Repositories/TribeRepositories.swift:28`
- `return MockChallengeRepository()` — `AiQo/Tribe/Repositories/TribeRepositories.swift:35`
- `struct MockTribeRepository: TribeRepositoryProtocol {` — `AiQo/Tribe/Repositories/TribeRepositories.swift:39`
- `name: tribeRepo("tribe.mock.name"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:43`
- `displayName: tribeRepo("tribe.mock.selfName"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:53`
- `displayNamePublic: tribeRepo("tribe.mock.selfName"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:54`
- `displayNamePrivate: tribeRepo("tribe.mock.selfName"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:55`
- `title: tribeRepo("tribe.mock.mission.energy"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:106`
- `title: tribeRepo("tribe.mock.mission.calm"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:113`
- `TribeEvent(id: "event-01", type: .memberJoined, actorId: "member-07", actorDisplayName: "غيم", message: tribeRepo("tribe.mock.event.memberJoined"), createdAt: now.addingTimeInterval(-60 * 32)),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:121`
- `TribeEvent(id: "event-02", type: .sparkSent, actorId: "local-demo-user", actorDisplayName: tribeRepo("tribe.mock.selfName"), message: tribeRepo("tribe.mock.event.spark"), value: 2, createdAt: now.addingTimeInterval(-60 * 56)),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:122`
- `TribeEvent(id: "event-03", type: .challengeCompleted, actorId: "tribe-admin-1", actorDisplayName: "سكون", message: tribeRepo("tribe.mock.event.challengeCompleted"), createdAt: now.addingTimeInterval(-60 * 90)),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:123`
- `TribeEvent(id: "event-04", type: .leadChanged, actorId: "tribe-owner", actorDisplayName: "ليان", message: tribeRepo("tribe.mock.event.leadChanged"), createdAt: now.addingTimeInterval(-60 * 130)),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:124`
- `TribeEvent(id: "event-05", type: .contribution, actorId: "member-01", actorDisplayName: "أن", message: tribeRepo("tribe.mock.event.contribution"), value: 12, createdAt: now.addingTimeInterval(-60 * 165)),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:125`
- `TribeEvent(id: "event-06", type: .challengeSuggested, actorId: "local-demo-user", actorDisplayName: tribeRepo("tribe.mock.selfName"), message: tribeRepo("tribe.mock.event.suggested"), createdAt: now.addingTimeInterval(-60 * 210))` — `AiQo/Tribe/Repositories/TribeRepositories.swift:126`
- `struct MockChallengeRepository: ChallengeRepositoryProtocol {` — `AiQo/Tribe/Repositories/TribeRepositories.swift:138`
- `title: tribeRepo("tribe.mock.challenge.personalCalm.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:146`
- `subtitle: tribeRepo("tribe.mock.challenge.personalCalm.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:147`
- `title: tribeRepo("tribe.mock.challenge.tribeSteps.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:159`
- `subtitle: tribeRepo("tribe.mock.challenge.tribeSteps.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:160`
- `title: tribeRepo("tribe.mock.challenge.tribeWater.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:172`
- `subtitle: tribeRepo("tribe.mock.challenge.tribeWater.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:173`
- `title: tribeRepo("tribe.mock.challenge.personalMonthlySteps.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:185`
- `subtitle: tribeRepo("tribe.mock.challenge.personalMonthlySteps.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:186`
- `title: tribeRepo("tribe.mock.challenge.tribeSleep.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:198`
- `subtitle: tribeRepo("tribe.mock.challenge.tribeSleep.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:199`
- `title: tribeRepo("tribe.mock.challenge.curatedDailyWater.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:220`
- `subtitle: tribeRepo("tribe.mock.challenge.curatedDailyWater.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:221`
- `title: tribeRepo("tribe.mock.challenge.curatedDailySugar.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:233`
- `subtitle: tribeRepo("tribe.mock.challenge.curatedDailySugar.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:234`
- `title: tribeRepo("tribe.mock.challenge.curatedDailyCalm.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:246`
- `subtitle: tribeRepo("tribe.mock.challenge.curatedDailyCalm.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:247`
- `title: tribeRepo("tribe.mock.challenge.curatedMonthlySteps.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:259`
- `subtitle: tribeRepo("tribe.mock.challenge.curatedMonthlySteps.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:260`
- `title: tribeRepo("tribe.mock.challenge.curatedMonthlySleep.title"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:272`
- `subtitle: tribeRepo("tribe.mock.challenge.curatedMonthlySleep.subtitle"),` — `AiQo/Tribe/Repositories/TribeRepositories.swift:273`
- `// TODO: Remove mock delegation when backend is ready.` — `AiQo/Tribe/Repositories/TribeRepositories.swift:285`
- `await MockTribeRepository().loadSnapshot()` — `AiQo/Tribe/Repositories/TribeRepositories.swift:288`
- `// TODO: Remove mock delegation when backend is ready.` — `AiQo/Tribe/Repositories/TribeRepositories.swift:292`
- `await MockChallengeRepository().loadChallenges()` — `AiQo/Tribe/Repositories/TribeRepositories.swift:295`
- `await MockChallengeRepository().loadCuratedGalaxyChallenges()` — `AiQo/Tribe/Repositories/TribeRepositories.swift:299`
- `self.name = isCurrentUser ? "tribe.mock.selfName".localized : member.visibleDisplayName` — `AiQo/Tribe/TribeModuleModels.swift:168`
- `member.displayName == "tribe.mock.selfName".localized ||` — `AiQo/Tribe/TribeModuleViewModel.swift:229`
- `member.displayNamePublic == "tribe.mock.selfName".localized` — `AiQo/Tribe/TribeModuleViewModel.swift:230`
- `print("🪶 Created tribe \(tribe.name) using local stub data until Supabase tribe tables are ready.")` — `AiQo/Tribe/TribeStore.swift:80`
- `format: "tribe.mock.joinedName".localized,` — `AiQo/Tribe/TribeStore.swift:106`
- `print("🪶 Joined tribe with code \(trimmedCode) using local stub data. Supabase integration can replace this later.")` — `AiQo/Tribe/TribeStore.swift:121`
- `displayName: "tribe.mock.privateMember".localized,` — `AiQo/Tribe/TribeStore.swift:323`

## Hardcoded Values That Should Likely Become Dynamic / Configurable
- `withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {` — `AiQo/App/AuthFlowUI.swift:456`
- `withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {` — `AiQo/App/AuthFlowUI.swift:459`
- `withAnimation(.easeInOut(duration: 0.4)) {` — `AiQo/App/SceneDelegate.swift:165`
- `.animation(.easeInOut(duration: 0.4), value: flow.currentScreen)` — `AiQo/App/SceneDelegate.swift:250`
- `applyEffectiveVolume(duration: 0)` — `AiQo/Core/AiQoAudioManager.swift:110`
- `fadeDuration: TimeInterval = 0.2` — `AiQo/Core/AiQoAudioManager.swift:125`
- `func endSpeechDucking(fadeDuration: TimeInterval = 0.32) {` — `AiQo/Core/AiQoAudioManager.swift:133`
- `let steps = max(1, Int(duration / 0.03))` — `AiQo/Core/AiQoAudioManager.swift:198`
- `let sleepDuration = UInt64((duration / Double(steps)) * 1_000_000_000)` — `AiQo/Core/AiQoAudioManager.swift:199`
- `private static let defaultAPIURL = "https://api.elevenlabs.io/v1/text-to-speech"` — `AiQo/Core/CaptainVoiceAPI.swift:8`
- `URLQueryItem(name: "output_format", value: "mp3_44100_128")` — `AiQo/Core/CaptainVoiceAPI.swift:81`
- `request.timeoutInterval = 30` — `AiQo/Core/CaptainVoiceAPI.swift:90`
- `let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]` — `AiQo/Core/CaptainVoiceCache.swift:49`
- `let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0` — `AiQo/Core/CaptainVoiceCache.swift:169`
- `utterance.pitchMultiplier = 0.96` — `AiQo/Core/CaptainVoiceService.swift:125`
- `private let key = "aiqo.dailyGoals"` — `AiQo/Core/DailyGoals.swift:11`
- `return DailyGoals(steps: 8000, activeCalories: 400)` — `AiQo/Core/DailyGoals.swift:21`
- `limit: 1,` — `AiQo/Core/HealthKitMemoryBridge.swift:83`
- `(#"(?:i want to|my goal is|trying to|i need to)\s*.{0,30}(?:lose weight|build muscle|gain weight|get lean|bulk|cut|cardio|flexibility|endurance)"#, "goal"),` — `AiQo/Core/MemoryExtractor.swift:131`
- `مثال: {"weight": "95", "goal": "تنشيف", "mood": "متحمس"}` — `AiQo/Core/MemoryExtractor.swift:203`
- `request.timeoutInterval = 15` — `AiQo/Core/MemoryExtractor.swift:215`
- `"temperature": 0.1` — `AiQo/Core/MemoryExtractor.swift:230`
- `guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=\(apiKey)") else {` — `AiQo/Core/MemoryExtractor.swift:311`
- `projectDescriptor.fetchLimit = 5` — `AiQo/Core/MemoryStore.swift:136`
- `otherDescriptor.fetchLimit = 30` — `AiQo/Core/MemoryStore.swift:144`
- `descriptor.fetchLimit = 40` — `AiQo/Core/MemoryStore.swift:179`
- `let limited = Array(filtered.prefix(15))` — `AiQo/Core/MemoryStore.swift:183`
- `private static nonisolated let chatFetchLimit = 50` — `AiQo/Core/MemoryStore.swift:276`
- `descriptor.fetchLimit = 500` — `AiQo/Core/MemoryStore.swift:320`
- `descriptor.fetchLimit = 1` — `AiQo/Core/MemoryStore.swift:461`
- `private let baseXP = 1000` — `AiQo/Core/Models/LevelStore.swift:64`
- `private let multiplier = 1.2` — `AiQo/Core/Models/LevelStore.swift:65`
- `private let validationEndpoint = "https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/validate-receipt"` — `AiQo/Core/Purchases/ReceiptValidator.swift:10`
- `request.timeoutInterval = 15` — `AiQo/Core/Purchases/ReceiptValidator.swift:46`
- `let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]` — `AiQo/Core/UserProfileStore.swift:94`
- `if let image, let data = image.jpegData(compressionQuality: 0.85) {` — `AiQo/Core/UserProfileStore.swift:99`
- `baseFrequency = 220` — `AiQo/Core/VibeAudioEngine.swift:110`
- `supportFrequency = 329.63` — `AiQo/Core/VibeAudioEngine.swift:111`
- `shimmerFrequency = 440` — `AiQo/Core/VibeAudioEngine.swift:112`
- `pulseFrequency = 0.18` — `AiQo/Core/VibeAudioEngine.swift:113`
- `baseFrequency = 174` — `AiQo/Core/VibeAudioEngine.swift:115`
- `supportFrequency = 261.63` — `AiQo/Core/VibeAudioEngine.swift:116`
- `shimmerFrequency = 348` — `AiQo/Core/VibeAudioEngine.swift:117`
- `pulseFrequency = 0.08` — `AiQo/Core/VibeAudioEngine.swift:118`
- `baseFrequency = 136.1` — `AiQo/Core/VibeAudioEngine.swift:120`
- `supportFrequency = 204.2` — `AiQo/Core/VibeAudioEngine.swift:121`
- `shimmerFrequency = 272.2` — `AiQo/Core/VibeAudioEngine.swift:122`
- `pulseFrequency = 0.05` — `AiQo/Core/VibeAudioEngine.swift:123`
- `baseFrequency = 196` — `AiQo/Core/VibeAudioEngine.swift:125`
- `supportFrequency = 293.66` — `AiQo/Core/VibeAudioEngine.swift:126`
- `shimmerFrequency = 392` — `AiQo/Core/VibeAudioEngine.swift:127`
- `pulseFrequency = 0.22` — `AiQo/Core/VibeAudioEngine.swift:128`
- `baseFrequency = 110` — `AiQo/Core/VibeAudioEngine.swift:130`
- `supportFrequency = 165` — `AiQo/Core/VibeAudioEngine.swift:131`
- `shimmerFrequency = 220` — `AiQo/Core/VibeAudioEngine.swift:132`
- `pulseFrequency = 0.07` — `AiQo/Core/VibeAudioEngine.swift:133`
- `let leftDetune = preset.baseFrequency * 0.995` — `AiQo/Core/VibeAudioEngine.swift:478`
- `let rightDetune = preset.baseFrequency * 1.005` — `AiQo/Core/VibeAudioEngine.swift:479`
- `let supportLeft = preset.supportFrequency * 0.998` — `AiQo/Core/VibeAudioEngine.swift:480`
- `let supportRight = preset.supportFrequency * 1.002` — `AiQo/Core/VibeAudioEngine.swift:481`
- `MPMediaItemPropertyPlaybackDuration: 0,` — `AiQo/Core/VibeAudioEngine.swift:625`
- `endPoint: UnitPoint(x: phase, y: 0)` — `AiQo/DesignSystem/Components/AiQoSkeletonView.swift:21`
- `.linear(duration: 1.2)` — `AiQo/DesignSystem/Components/AiQoSkeletonView.swift:27`
- `LongPressGesture(minimumDuration: 0.15)` — `AiQo/DesignSystem/Modifiers/AiQoPressEffect.swift:39`
- `.easeInOut(duration: 0.7)` — `AiQo/Features/Captain/CaptainChatView.swift:407`
- `async let stepsValue = withHealthKitTimeout(fallback: 0.0) { [self] in` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:125`
- `async let activeEnergyValue = withHealthKitTimeout(fallback: 0.0) { [self] in` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:132`
- `async let sleepValue = withHealthKitTimeout(fallback: 0.0) { [self] in` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:142`
- `request.timeoutInterval = 25` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:279`
- `guard let simulatorURL = URL(string: "http://localhost:3000/captain-ar") else {` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:322`
- `private static let healthKitQueryTimeout: TimeInterval = 2` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:747`
- `try await Task.sleep(nanoseconds: UInt64(Self.healthKitQueryTimeout * 1_000_000_000))` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:760`
- `limit: 1,` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:884`
- `limit: 150,` — `AiQo/Features/Captain/CaptainIntelligenceManager.swift:920`
- `withAnimation(.smooth(duration: 0.24)) {` — `AiQo/Features/Captain/CaptainScreen.swift:448`
- `withAnimation(.easeOut(duration: 0.24)) {` — `AiQo/Features/Captain/CaptainScreen.swift:452`
- `.animation(.easeInOut(duration: 0.24), value: phase)` — `AiQo/Features/Captain/CaptainScreen.swift:546`
- `let speed = max(1.1, state.rotationDuration * 0.55) + (Double(index) * 0.12)` — `AiQo/Features/Captain/CaptainScreen.swift:670`
- `let progress = time / max(1.8, state.rotationDuration)` — `AiQo/Features/Captain/CaptainScreen.swift:702`
- `withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {` — `AiQo/Features/Captain/CaptainScreen.swift:945`
- `private let minimumLoadingStateDuration: TimeInterval = 0.8` — `AiQo/Features/Captain/CaptainViewModel.swift:112`
- `private let globalProcessingTimeout: TimeInterval = 15` — `AiQo/Features/Captain/CaptainViewModel.swift:113`
- `private let sleepProcessingTimeout: TimeInterval = 25` — `AiQo/Features/Captain/CaptainViewModel.swift:115`
- `private static let maxConversationWindow = 20` — `AiQo/Features/Captain/CaptainViewModel.swift:534`
- `case .captainRateLimited, .serverError(statusCode: 429):` — `AiQo/Features/Captain/CaptainViewModel.swift:651`
- `return image.jpegData(compressionQuality: 0.74) ?? image.pngData()` — `AiQo/Features/Captain/CaptainViewModel.swift:855`
- `request.timeoutInterval = 25` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:95`
- `"temperature": 0.2,` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:109`
- `await transition(to: .reading, minimumDuration: 0.35)` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:281`
- `await transition(to: .thinking, minimumDuration: 0)` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:308`
- `await transition(to: .preparingReply, minimumDuration: 0)` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:327`
- `await transition(to: .preparingReply, minimumDuration: 0)` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:351`
- `await transition(to: .translatingInput, minimumDuration: 0)` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:368`
- `await transition(to: .translatingOutput, minimumDuration: 0)` — `AiQo/Features/Captain/CoachBrainMiddleware.swift:387`
- `private static let defaultEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"` — `AiQo/Features/Captain/CoachBrainTranslationConfig.swift:27`
- `static let baseEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"` — `AiQo/Features/Captain/HybridBrainService.swift:88`
- `static let requestTimeoutSeconds: TimeInterval = 35` — `AiQo/Features/Captain/HybridBrainService.swift:89`
- `"temperature": 0.7` — `AiQo/Features/Captain/HybridBrainService.swift:300`
- `static let onDeviceReplyTimeout: TimeInterval = 8` — `AiQo/Features/Captain/LocalBrainService.swift:402`
- `try await Task.sleep(nanoseconds: UInt64(Self.onDeviceReplyTimeout * 1_000_000_000))` — `AiQo/Features/Captain/LocalBrainService.swift:414`
- `Exercise(name: "تنفّس 4-6", sets: 3, repsOrDuration: "60 ثانية"),` — `AiQo/Features/Captain/LocalBrainService.swift:466`
- `Exercise(name: "مشي خفيف", sets: 2, repsOrDuration: "8 دقائق"),` — `AiQo/Features/Captain/LocalBrainService.swift:467`
- `Exercise(name: "فتح الورك والظهر", sets: 3, repsOrDuration: "45 ثانية"),` — `AiQo/Features/Captain/LocalBrainService.swift:468`
- `Exercise(name: "تمدد أوتار خلفية", sets: 2, repsOrDuration: "45 ثانية")` — `AiQo/Features/Captain/LocalBrainService.swift:469`
- `Exercise(name: "إحماء ديناميكي", sets: 2, repsOrDuration: "60 ثانية"),` — `AiQo/Features/Captain/LocalBrainService.swift:476`
- `Exercise(name: "سكوات وزن جسم", sets: 3, repsOrDuration: "12 تكرار"),` — `AiQo/Features/Captain/LocalBrainService.swift:477`
- `Exercise(name: "ضغط مائل", sets: 3, repsOrDuration: "10 تكرار"),` — `AiQo/Features/Captain/LocalBrainService.swift:478`
- `Exercise(name: "بلانك", sets: 3, repsOrDuration: "30 ثانية")` — `AiQo/Features/Captain/LocalBrainService.swift:479`
- `Exercise(name: "إحماء مفاصل", sets: 2, repsOrDuration: "75 ثانية"),` — `AiQo/Features/Captain/LocalBrainService.swift:486`
- `Exercise(name: "لانجز متبادلة", sets: 3, repsOrDuration: "10 لكل رجل"),` — `AiQo/Features/Captain/LocalBrainService.swift:487`
- `Exercise(name: "سحب مطاط أو دامبل رو", sets: 3, repsOrDuration: "12 تكرار"),` — `AiQo/Features/Captain/LocalBrainService.swift:488`
- `Exercise(name: "مشي سريع", sets: 2, repsOrDuration: "6 دقائق")` — `AiQo/Features/Captain/LocalBrainService.swift:489`
- `Exercise(name: "سكوات", sets: 4, repsOrDuration: "8-10 تكرار"),` — `AiQo/Features/Captain/LocalBrainService.swift:496`
- `Exercise(name: "ضغط أو بنش", sets: 4, repsOrDuration: "8-10 تكرار"),` — `AiQo/Features/Captain/LocalBrainService.swift:497`
- `Exercise(name: "رو", sets: 4, repsOrDuration: "10 تكرار"),` — `AiQo/Features/Captain/LocalBrainService.swift:498`
- `Exercise(name: "بلانك جانبي", sets: 3, repsOrDuration: "40 ثانية")` — `AiQo/Features/Captain/LocalBrainService.swift:499`
- `Exercise(name: "Air Squat", sets: 4, repsOrDuration: "15 تكرار"),` — `AiQo/Features/Captain/LocalBrainService.swift:506`
- `Exercise(name: "Push-Up", sets: 4, repsOrDuration: "10 تكرار"),` — `AiQo/Features/Captain/LocalBrainService.swift:507`
- `Exercise(name: "Mountain Climber", sets: 3, repsOrDuration: "30 ثانية"),` — `AiQo/Features/Captain/LocalBrainService.swift:508`
- `Exercise(name: "Farmer Carry أو مشي سريع", sets: 3, repsOrDuration: "90 ثانية")` — `AiQo/Features/Captain/LocalBrainService.swift:509`
- `Exercise(name: "4-6 Breathing", sets: 3, repsOrDuration: "60 sec"),` — `AiQo/Features/Captain/LocalBrainService.swift:516`
- `Exercise(name: "Light Walk", sets: 2, repsOrDuration: "8 min"),` — `AiQo/Features/Captain/LocalBrainService.swift:517`
- `Exercise(name: "Hip and Thoracic Openers", sets: 3, repsOrDuration: "45 sec"),` — `AiQo/Features/Captain/LocalBrainService.swift:518`
- `Exercise(name: "Hamstring Stretch", sets: 2, repsOrDuration: "45 sec")` — `AiQo/Features/Captain/LocalBrainService.swift:519`
- `Exercise(name: "Dynamic Warm-Up", sets: 2, repsOrDuration: "60 sec"),` — `AiQo/Features/Captain/LocalBrainService.swift:526`
- `Exercise(name: "Bodyweight Squat", sets: 3, repsOrDuration: "12 reps"),` — `AiQo/Features/Captain/LocalBrainService.swift:527`
- `Exercise(name: "Incline Push-Up", sets: 3, repsOrDuration: "10 reps"),` — `AiQo/Features/Captain/LocalBrainService.swift:528`
- `Exercise(name: "Plank Hold", sets: 3, repsOrDuration: "30 sec")` — `AiQo/Features/Captain/LocalBrainService.swift:529`
- `Exercise(name: "Joint Prep Flow", sets: 2, repsOrDuration: "75 sec"),` — `AiQo/Features/Captain/LocalBrainService.swift:536`
- `Exercise(name: "Alternating Lunge", sets: 3, repsOrDuration: "10 each leg"),` — `AiQo/Features/Captain/LocalBrainService.swift:537`
- `Exercise(name: "Band Row or Dumbbell Row", sets: 3, repsOrDuration: "12 reps"),` — `AiQo/Features/Captain/LocalBrainService.swift:538`
- `Exercise(name: "Brisk Walk", sets: 2, repsOrDuration: "6 min")` — `AiQo/Features/Captain/LocalBrainService.swift:539`
- `Exercise(name: "Squat", sets: 4, repsOrDuration: "8-10 reps"),` — `AiQo/Features/Captain/LocalBrainService.swift:546`
- `Exercise(name: "Press or Bench", sets: 4, repsOrDuration: "8-10 reps"),` — `AiQo/Features/Captain/LocalBrainService.swift:547`
- `Exercise(name: "Row", sets: 4, repsOrDuration: "10 reps"),` — `AiQo/Features/Captain/LocalBrainService.swift:548`
- `Exercise(name: "Side Plank", sets: 3, repsOrDuration: "40 sec")` — `AiQo/Features/Captain/LocalBrainService.swift:549`
- `Exercise(name: "Air Squat", sets: 4, repsOrDuration: "15 reps"),` — `AiQo/Features/Captain/LocalBrainService.swift:556`
- `Exercise(name: "Push-Up", sets: 4, repsOrDuration: "10 reps"),` — `AiQo/Features/Captain/LocalBrainService.swift:557`
- `Exercise(name: "Mountain Climber", sets: 3, repsOrDuration: "30 sec"),` — `AiQo/Features/Captain/LocalBrainService.swift:558`
- `Exercise(name: "Farmer Carry or Fast Walk", sets: 3, repsOrDuration: "90 sec")` — `AiQo/Features/Captain/LocalBrainService.swift:559`
- `.onLongPressGesture(minimumDuration: 0.3) {` — `AiQo/Features/Captain/MessageBubble.swift:59`
- `withAnimation(.easeInOut(duration: 0.2)) {` — `AiQo/Features/Captain/MessageBubble.swift:60`
- `/// - Health data bucketed: steps by 50, calories by 10` — `AiQo/Features/Captain/PrivacySanitizer.swift:12`
- `private let kitchenImageCompressionQuality: CGFloat = 0.78` — `AiQo/Features/Captain/PrivacySanitizer.swift:23`
- `private let stepsBucketSize = 50` — `AiQo/Features/Captain/PrivacySanitizer.swift:24`
- `private let caloriesBucketSize = 10` — `AiQo/Features/Captain/PrivacySanitizer.swift:25`
- `try content.write(to: fileURL, atomically: true, encoding: .utf8)` — `AiQo/Features/DataExport/HealthDataExporter.swift:309`
- `.animation(.easeInOut(duration: 0.3), value: hasGrantedPermissions)` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:166`
- `/// Level = lookup table (progressive thresholds up to Level 50)` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:628`
- `durationSeconds: Int = 120,` — `AiQo/Features/Gym/ActiveRecoveryView.swift:26`
- `.animation(.easeInOut(duration: 1.0), value: showRewardCaption)` — `AiQo/Features/Gym/ActiveRecoveryView.swift:91`
- `let nextRemaining = max(durationSeconds - elapsed, 0)` — `AiQo/Features/Gym/ActiveRecoveryView.swift:114`
- `withAnimation(.easeInOut(duration: 4.0)) {` — `AiQo/Features/Gym/ActiveRecoveryView.swift:152`
- `withAnimation(.easeInOut(duration: 6.0)) {` — `AiQo/Features/Gym/ActiveRecoveryView.swift:160`
- `static let warmUpDurationSeconds = 360` — `AiQo/Features/Gym/AudioCoachManager.swift:19`
- `static let feedbackCooldown: TimeInterval = 120` — `AiQo/Features/Gym/AudioCoachManager.swift:20`
- `return URL(string: "https://www.netflix.com/search?q=\(encoded)")` — `AiQo/Features/Gym/CinematicGrindViews.swift:60`
- `return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")` — `AiQo/Features/Gym/CinematicGrindViews.swift:62`
- `private let durations = [30, 45, 60, 90, 120]` — `AiQo/Features/Gym/CinematicGrindViews.swift:321`
- `_selectedDuration = State(initialValue: initialContext?.duration ?? 45)` — `AiQo/Features/Gym/CinematicGrindViews.swift:333`
- `title: L10n.t("cinematic.duration.title"),` — `AiQo/Features/Gym/CinematicGrindViews.swift:350`
- `subtitle: L10n.t("cinematic.duration.subtitle")` — `AiQo/Features/Gym/CinematicGrindViews.swift:351`
- `subtitle: { _ in L10n.t("cinematic.duration.minutes.short") }` — `AiQo/Features/Gym/CinematicGrindViews.swift:358`
- `.animation(.linear(duration: 1.4).repeatForever(autoreverses: false), value: isThinking)` — `AiQo/Features/Gym/CinematicGrindViews.swift:499`
- `RecommendationPill(title: "\(suggestion.duration) \(L10n.t("cinematic.duration.minutes.short"))")` — `AiQo/Features/Gym/CinematicGrindViews.swift:521`
- `backgroundPlayer.setVolume(Self.musicVolume, fadeDuration: 0.8)` — `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift:65`
- `backgroundPlayer.setVolume(0, fadeDuration: 0.35)` — `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift:118`
- `if let bundleURL = Bundle.main.url(forResource: "SerotoninFlow", withExtension: "m4a") {` — `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift:142`
- `utterance.pitchMultiplier = 0.94` — `AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift:169`
- `static let duration: TimeInterval = 150` — `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift:5`
- `let remaining = max(Int(SessionTiming.duration - elapsedTime.rounded(.down)), 0)` — `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift:47`
- `.animation(.easeInOut(duration: 0.28), value: progress)` — `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift:173`
- `.animation(.easeInOut(duration: 0.9), value: currentSentenceIndex)` — `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift:196`
- `withAnimation(.easeInOut(duration: 0.9)) {` — `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift:363`
- `withAnimation(.easeInOut(duration: 0.3)) {` — `AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift:92`
- `.animation(.easeInOut(duration: 0.3), value: selection)` — `AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift:112`
- `.animation(.easeOut(duration: 0.25), value: isEffectivelyHidden)` — `AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift:65`
- `LongPressGesture(minimumDuration: 0.2).onEnded { _ in` — `AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift:93`
- `.animation(.easeOut(duration: 0.18), value: isCollapsed)` — `AiQo/Features/Gym/Club/Components/RightSideVerticalRail.swift:139`
- `withAnimation(.easeInOut(duration: 0.2)) {` — `AiQo/Features/Gym/Club/Components/SegmentedTabs.swift:152`
- `withAnimation(.easeInOut(duration: 0.3)) {` — `AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift:85`
- `.animation(.easeInOut(duration: 0.3), value: selectedTab)` — `AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift:109`
- `withAnimation(.easeInOut(duration: 0.3)) {` — `AiQo/Features/Gym/Club/Plan/PlanView.swift:114`
- `.animation(.easeInOut(duration: 0.3), value: railSelection)` — `AiQo/Features/Gym/Club/Plan/PlanView.swift:138`
- `withAnimation(.easeOut(duration: 0.22)) {` — `AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift:435`
- `withAnimation(.easeOut(duration: 0.25)) {` — `AiQo/Features/Gym/GuinnessEncyclopediaView.swift:204`
- `withDuration: 0.18,` — `AiQo/Features/Gym/LiveMetricsHeader.swift:151`
- `withDuration: 0.18,` — `AiQo/Features/Gym/LiveMetricsHeader.swift:159`
- `private static let captainWarmupAmbientLoopDurationSeconds = 360` — `AiQo/Features/Gym/LiveWorkoutSession.swift:87`
- `let stepDuration = UInt64(40_000_000)` — `AiQo/Features/Gym/LiveWorkoutSession.swift:777`
- `withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {` — `AiQo/Features/Gym/OriginalWorkoutCardView.swift:61`
- `withAnimation(.spring(response: 0.4, dampingFraction: 0.4, blendDuration: 0)) {` — `AiQo/Features/Gym/OriginalWorkoutCardView.swift:67`
- `let durationMinutes = max(Int((duration / 60).rounded()), 1)` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:284`
- `private var expectedDuration: TimeInterval = 0` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:776`
- `expectedDuration = max(duration, 60)` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:786`
- `workoutStartDate = now.addingTimeInterval(-expectedDuration - 90)` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:789`
- `let lookback = now.addingTimeInterval(-6 * 3600)` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:864`
- `limit: 10,` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:877`
- `let maxDiff = max(240, expectedDuration * 0.45)` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:881`
- `abs($0.duration - expectedDuration) <= maxDiff &&` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:883`
- `let durationSeconds = max(1, min(nextDate.timeIntervalSince(sample.startDate), 20))` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:999`
- `zone2Seconds += durationSeconds` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:1004`
- `let recoveryWindowEnd = peakPoint.time.addingTimeInterval(180)` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:1030`
- `$0.time >= peakPoint.time && $0.time <= recoveryWindowEnd` — `AiQo/Features/Gym/PhoneWorkoutSummaryView.swift:1032`
- `let duration = at.timeIntervalSince1970 - start` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:326`
- `guard let data = UserDefaults.standard.data(forKey: "aiqo.dailyGoals") else {` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:54`
- `let duration = timerDataSource.finishSession(questId: questId, at: Date()) ?? 0` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:335`
- `hasSleepDataInOvernightWindow = sleepSummary.hasData || debugSleep > 0` — `AiQo/Features/Gym/QuestKit/QuestEngine.swift:361`
- `thresholds: [2.0, 2.5, 3.0],` — `AiQo/Features/Gym/QuestKit/QuestFormatting.swift:135`
- `thresholds: [7.0, 7.5, 8.0],` — `AiQo/Features/Gym/QuestKit/QuestFormatting.swift:141`
- `thresholds: [20.0, 30.0, 40.0],` — `AiQo/Features/Gym/QuestKit/QuestFormatting.swift:147`
- `guard thresholds.count == 3 else {` — `AiQo/Features/Gym/QuestKit/QuestFormatting.swift:186`
- `return "هدفك الجاي: \(isolated(formatter(thresholds[0])))"` — `AiQo/Features/Gym/QuestKit/QuestFormatting.swift:191`
- `return "هدفك الجاي: \(isolated(formatter(thresholds[1])))"` — `AiQo/Features/Gym/QuestKit/QuestFormatting.swift:194`
- `return "هدفك الجاي: \(isolated(formatter(thresholds[2])))"` — `AiQo/Features/Gym/QuestKit/QuestFormatting.swift:197`
- `var goalText: String { L10n.t(goalTextKey) }` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:121`
- `goalValue: 3,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:155`
- `goalTextKey: "quests.challenge.s1.help.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:157`
- `goalValue: 30,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:169`
- `goalTextKey: "quests.challenge.s1.zone2.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:171`
- `goalValue: 5.0,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:183`
- `goalTextKey: "quests.challenge.s1.walk.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:185`
- `goalValue: 1,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:197`
- `goalTextKey: "quests.challenge.s1.gratitude.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:199`
- `goalValue: 3,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:211`
- `goalTextKey: "quests.challenge.s1.recovery.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:213`
- `goalValue: 10_000,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:228`
- `goalValue: 180,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:242`
- `goalValue: 60,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:256`
- `goalValue: 8,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:270`
- `goalValue: 600,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:284`
- `goalValue: 11_000,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:301`
- `goalTextKey: "quests.challenge.s2.steps.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:303`
- `goalValue: 650,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:315`
- `goalTextKey: "quests.challenge.s2.active.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:317`
- `goalValue: 70,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:329`
- `goalTextKey: "quests.challenge.s2.pushups.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:331`
- `goalValue: 240,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:343`
- `goalTextKey: "quests.challenge.s2.plank.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:345`
- `goalValue: 5.0,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:357`
- `goalTextKey: "quests.challenge.s2.move.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:359`
- `goalValue: 4,` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:373`
- `goalTextKey: "quests.challenge.s2.boss.goal",` — `AiQo/Features/Gym/Quests/Models/Challenge.swift:375`
- `return min(progress(for: challenge) / challenge.goalValue, 1)` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:115`
- `return "\(L10n.t("quests.metric.sleep_streak")): \(Int(achievedValue.rounded()))/\(Int(challenge.goalValue.rounded())) \(L10n.t("quests.unit.days"))"` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:504`
- `detailRow(title: L10n.t("quests.detail.goal"), value: challenge.goalText)` — `AiQo/Features/Gym/Quests/Views/ChallengeDetailView.swift:15`
- `withAnimation(.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0)) {` — `AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift:70`
- `withAnimation(.easeOut(duration: 0.5).delay(0.4)) {` — `AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift:75`
- `if quest.id == "s1q3", engine.isHealthAuthorized, !engine.hasSleepDataInOvernightWindow {` — `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift:124`
- `if quest.id == "s1q3", engine.isHealthAuthorized, !engine.hasSleepDataInOvernightWindow {` — `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift:193`
- `if (quest.id == "s1q3" || quest.id == "s6q5"), !engine.hasSleepDataInOvernightWindow {` — `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift:278`
- `.lineLimit(isSleepQuest ? 1 : nil)` — `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift:417`
- `openHealthURL(from: healthURLStrings, index: 0)` — `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift:727`
- `openHealthURL(from: candidates, index: index + 1)` — `AiQo/Features/Gym/Quests/Views/QuestDetailView.swift:738`
- `return "\(L10n.t("quests.metric.sleep_streak")): \(Int((numericValue ?? 0).rounded()))/\(Int(challenge.goalValue.rounded())) \(L10n.t("quests.unit.days"))"` — `AiQo/Features/Gym/Quests/Views/QuestWinsGridView.swift:168`
- `withAnimation(.easeInOut(duration: 0.22)) {` — `AiQo/Features/Gym/Quests/Views/QuestsView.swift:349`
- `withAnimation(.easeInOut(duration: 0.22)) {` — `AiQo/Features/Gym/Quests/Views/QuestsView.swift:356`
- `withAnimation(.easeInOut(duration: 0.2)) {` — `AiQo/Features/Gym/Quests/Views/StageSelectorBar.swift:13`
- `withAnimation(.easeInOut(duration: 0.2)) {` — `AiQo/Features/Gym/Quests/Views/StageSelectorBar.swift:41`
- `private let downThreshold: CGFloat = 95` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:325`
- `private let upThreshold: CGFloat = 155` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:326`
- `private let cooldown: TimeInterval = 0.45` — `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift:327`
- `let workouts = try await HealthKitService.shared.fetchWorkouts(limit: 60)` — `AiQo/Features/Gym/RecapViewController.swift:638`
- `? formatPace(seconds: workout.duration, meters: distance ?? 0)` — `AiQo/Features/Gym/RecapViewController.swift:704`
- `.init(title: L10n.t("gym.metric.duration"), value: duration, icon: "timer", tint: tint),` — `AiQo/Features/Gym/RecapViewController.swift:710`
- `.animation(.easeOut(duration: 0.25), value: progress)` — `AiQo/Features/Gym/RewardsViewController.swift:287`
- `withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {` — `AiQo/Features/Gym/ShimmeringPlaceholder.swift:29`
- `withAnimation(.spring(duration: 1.2, bounce: 0).repeatForever(autoreverses: true)) {` — `AiQo/Features/Gym/ShimmeringPlaceholder.swift:33`
- `UIView.animate(withDuration: 0.18, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.4) {` — `AiQo/Features/Gym/SoftGlassCardView.swift:88`
- `withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {` — `AiQo/Features/Gym/T/SpinWheelView.swift:50`
- `withAnimation(.easeOut(duration: 3.0)) {` — `AiQo/Features/Gym/T/WorkoutWheelSessionViewModel.swift:86`
- `.animation(.easeOut(duration: 0.18), value: showSheet)` — `AiQo/Features/Gym/WinsViewController.swift:113`
- `withAnimation(.easeOut(duration: 0.18)) {` — `AiQo/Features/Gym/WinsViewController.swift:420`
- `withAnimation(.easeOut(duration: 0.1)) { isPressed = true }` — `AiQo/Features/Gym/WinsViewController.swift:568`
- `withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {` — `AiQo/Features/Gym/WorkoutSessionScreen.swift.swift:538`
- `let randomDuration = Double.random(in: 4.0...6.0)` — `AiQo/Features/Gym/WorkoutSessionScreen.swift.swift:551`
- `withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {` — `AiQo/Features/Gym/WorkoutSessionScreen.swift.swift:560`
- `withAnimation(.spring(response: 0.4, dampingFraction: 0.4, blendDuration: 0)) {` — `AiQo/Features/Gym/WorkoutSessionScreen.swift.swift:565`
- `withAnimation(.easeOut(duration: 0.24)) {` — `AiQo/Features/Home/DJCaptainChatView.swift:217`
- `.easeInOut(duration: 0.7)` — `AiQo/Features/Home/DJCaptainChatView.swift:376`
- `withAnimation(AiQoAccessibility.prefersReducedMotion ? .none : .easeInOut(duration: 1.2)) {` — `AiQo/Features/Home/DailyAuraView.swift:51`
- `withAnimation(AiQoAccessibility.prefersReducedMotion ? .none : .easeInOut(duration: 1.2)) {` — `AiQo/Features/Home/DailyAuraView.swift:64`
- `withAnimation(AiQoAccessibility.prefersReducedMotion ? .none : .easeInOut(duration: 1.2)) {` — `AiQo/Features/Home/DailyAuraView.swift:69`
- `withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {` — `AiQo/Features/Home/DailyAuraView.swift:75`
- `withAnimation(AiQoAccessibility.prefersReducedMotion ? .none : .easeInOut(duration: 1.2)) {` — `AiQo/Features/Home/DailyAuraView.swift:82`
- `.easeInOut(duration: 1.2)` — `AiQo/Features/Home/DailyAuraView.swift:127`
- `.animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: centerBreath)` — `AiQo/Features/Home/DailyAuraView.swift:137`
- `.animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: centerBreath)` — `AiQo/Features/Home/DailyAuraView.swift:143`
- `let stageStart = segment.threshold - 0.25` — `AiQo/Features/Home/DailyAuraView.swift:160`
- `let bucketDelay = Double(segment.bucketIndex) * 0.04` — `AiQo/Features/Home/DailyAuraView.swift:168`
- `let orderDelay = Double(segment.bucketOrder) * 0.007` — `AiQo/Features/Home/DailyAuraView.swift:169`
- `var bucketSizes = [0, 0, 0, 0]` — `AiQo/Features/Home/DailyAuraView.swift:256`
- `bucketSizes[def.stage] += 1` — `AiQo/Features/Home/DailyAuraView.swift:258`
- `var bucketOffsets = [0, 0, 0, 0]` — `AiQo/Features/Home/DailyAuraView.swift:260`
- `bucketOffsets[def.stage] += 1` — `AiQo/Features/Home/DailyAuraView.swift:264`
- `threshold: Double(def.stage + 1) * 0.25,` — `AiQo/Features/Home/DailyAuraView.swift:272`
- `bucketSize: max(bucketSizes[def.stage], 1),` — `AiQo/Features/Home/DailyAuraView.swift:275`
- `set: { viewModel.updateStepsGoal($0) }` — `AiQo/Features/Home/DailyAuraView.swift:341`
- `set: { viewModel.updateCaloriesGoal($0) }` — `AiQo/Features/Home/DailyAuraView.swift:353`
- `let goal = max(goals.steps, 1)` — `AiQo/Features/Home/DailyAuraViewModel.swift:28`
- `let goal = max(goals.activeCalories, 1)` — `AiQo/Features/Home/DailyAuraViewModel.swift:33`
- `goals.steps = max(1000, value)` — `AiQo/Features/Home/DailyAuraViewModel.swift:58`
- `goals.activeCalories = Double(max(100, value))` — `AiQo/Features/Home/DailyAuraViewModel.swift:63`
- `let s = min(Double(record.steps) / Double(max(goals.steps, 1)), 1)` — `AiQo/Features/Home/DailyAuraViewModel.swift:68`
- `let c = min(record.calories / max(goals.activeCalories, 1), 1)` — `AiQo/Features/Home/DailyAuraViewModel.swift:69`
- `withAnimation(.easeInOut(duration: 0.18)) {` — `AiQo/Features/Home/HomeStatCard.swift:92`
- `.easeInOut(duration: 5.0)` — `AiQo/Features/Home/HomeStatCard.swift:178`
- `withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {` — `AiQo/Features/Home/HomeStatCard.swift:191`
- `withAnimation(.spring(response: 0.4, dampingFraction: 0.4, blendDuration: 0)) {` — `AiQo/Features/Home/HomeStatCard.swift:197`
- `withAnimation(.snappy(duration: 0.30, extraBounce: 0.08)) {` — `AiQo/Features/Home/HomeView.swift:295`
- `withAnimation(.snappy(duration: 0.30, extraBounce: 0.08)) {` — `AiQo/Features/Home/HomeView.swift:301`
- `.easeInOut(duration: 2.0)` — `AiQo/Features/Home/HomeView.swift:323`
- `buckets[key, default: 0] += duration` — `AiQo/Features/Home/HomeViewModel.swift:599`
- `buckets[key, default: 0] += 1` — `AiQo/Features/Home/HomeViewModel.swift:659`
- `buckets[key, default: 0] += duration` — `AiQo/Features/Home/HomeViewModel.swift:725`
- `cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? endBucket.addingTimeInterval(1)` — `AiQo/Features/Home/HomeViewModel.swift:734`
- `buckets[key, default: 0] += 1` — `AiQo/Features/Home/HomeViewModel.swift:780`
- `cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? endBucket.addingTimeInterval(1)` — `AiQo/Features/Home/HomeViewModel.swift:789`
- `limit: 1,` — `AiQo/Features/Home/HomeViewModel.swift:817`
- `withAnimation(.easeOut(duration: 0.4).delay(0.3)) {` — `AiQo/Features/Home/LevelUpCelebrationView.swift:47`
- `withAnimation(.easeOut(duration: 0.3)) {` — `AiQo/Features/Home/LevelUpCelebrationView.swift:52`
- `withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {` — `AiQo/Features/Home/VibeControlSheet.swift:1359`
- `withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {` — `AiQo/Features/Home/WaterBottleView.swift:64`
- `withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {` — `AiQo/Features/Home/WaterBottleView.swift:70`
- `var frequency: CGFloat = 2` — `AiQo/Features/Home/WaterBottleView.swift:133`
- `let sine = sin((relativeX * frequency * .pi * 2) + offset)` — `AiQo/Features/Home/WaterBottleView.swift:150`
- `WaveShape(offset: waveOffset, amplitude: 3, frequency: 1.5)` — `AiQo/Features/Home/WaterBottleView.swift:193`
- `withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {` — `AiQo/Features/Home/WaterBottleView.swift:214`
- `bucket.count += 1` — `AiQo/Features/Kitchen/IngredientDisplayItem.swift:35`
- `if bucket.count == 1 {` — `AiQo/Features/Kitchen/IngredientDisplayItem.swift:39`
- `buckets[normalizedName] = (displayName: name, count: 0)` — `AiQo/Features/Kitchen/IngredientDisplayItem.swift:77`
- `buckets[normalizedName]?.count += 1` — `AiQo/Features/Kitchen/IngredientDisplayItem.swift:80`
- `withAnimation(.easeOut(duration: 0.22)) {` — `AiQo/Features/Kitchen/InteractiveFridgeView.swift:126`
- `withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {` — `AiQo/Features/Kitchen/KitchenScreen.swift:390`
- `withAnimation(.easeInOut(duration: 0.12)) {` — `AiQo/Features/Kitchen/KitchenScreen.swift:407`
- `withAnimation(.easeOut(duration: 0.18)) {` — `AiQo/Features/Kitchen/KitchenScreen.swift:413`
- `var calorieGoal: Int = 2200` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:30`
- `var proteinGoal: Double = 150` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:31`
- `var carbGoal: Double = 250` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:32`
- `var fatGoal: Double = 70` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:33`
- `var fiberGoal: Double = 30` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:34`
- `let progress = min(CGFloat(totalCalories) / CGFloat(max(calorieGoal, 1)), 1.0)` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:145`
- `let progress = min(value / max(goal, 1), 1.0)` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:170`
- `Text("\(String(format: "%.0f", goal))\(unit)")` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:187`
- `@AppStorage("aiqo.nutrition.calorieGoal") private var calorieGoal = 2200` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:251`
- `@AppStorage("aiqo.nutrition.proteinGoal") private var proteinGoal = 150.0` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:252`
- `@AppStorage("aiqo.nutrition.carbGoal") private var carbGoal = 250.0` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:253`
- `@AppStorage("aiqo.nutrition.fatGoal") private var fatGoal = 70.0` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:254`
- `@AppStorage("aiqo.nutrition.fiberGoal") private var fiberGoal = 30.0` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:255`
- `String(format: "%.0f غ", proteinGoal),` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:273`
- `String(format: "%.0f غ", carbGoal),` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:282`
- `String(format: "%.0f غ", fatGoal),` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:291`
- `String(format: "%.0f غ", fiberGoal),` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:300`
- `calorieGoal = 2200` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:309`
- `proteinGoal = 150` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:310`
- `carbGoal = 250` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:311`
- `fatGoal = 70` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:312`
- `fiberGoal = 30` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:313`
- `@AppStorage("aiqo.nutrition.calorieGoal") private var calorieGoal = 2200` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:548`
- `@AppStorage("aiqo.nutrition.proteinGoal") private var proteinGoal = 150.0` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:549`
- `@AppStorage("aiqo.nutrition.carbGoal") private var carbGoal = 250.0` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:550`
- `@AppStorage("aiqo.nutrition.fatGoal") private var fatGoal = 70.0` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:551`
- `@AppStorage("aiqo.nutrition.fiberGoal") private var fiberGoal = 30.0` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:552`
- `guard let imageData = sanitizer.sanitizeKitchenImageData(image.jpegData(compressionQuality: 1.0)) else {` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:136`
- `"temperature": 0.2` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:170`
- `let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=\(apiKey)")!` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:174`
- `urlRequest.timeoutInterval = 15` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:177`
- `let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1` — `AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:186`
- `withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {` — `AiQo/Features/Kitchen/SmartFridgeScannerView.swift:270`
- `withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {` — `AiQo/Features/Kitchen/SmartFridgeScannerView.swift:440`
- `// FIXED: Start a timeout — if no HR after 30 seconds, warn user` — `AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift:132`
- `withAnimation(.easeInOut(duration: 0.4)) {` — `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:158`
- `.animation(.easeInOut(duration: 0.3), value: currentCaptainInstruction)` — `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:238`
- `withAnimation(.easeInOut(duration: 0.4)) {` — `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:517`
- `withAnimation(.easeInOut(duration: 0.4)) {` — `AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift:541`
- `.animation(.easeInOut(duration: 0.6), value: project.progressFraction)` — `AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift:82`
- `guard let apiKey, let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=\(apiKey)") else {` — `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:342`
- `request.timeoutInterval = 25` — `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:348`
- `"temperature": 0.7` — `AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:363`
- `.animation(.easeInOut(duration: 1.2), value: state)` — `AiQo/Features/MyVibe/MyVibeSubviews.swift:31`
- `? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)` — `AiQo/Features/MyVibe/MyVibeSubviews.swift:65`
- `.easeInOut(duration: Double.random(in: 0.4...0.8))` — `AiQo/Features/MyVibe/MyVibeSubviews.swift:157`
- `/// من مجموع النقاط نحسب المستوى باستخدام نفس معادلة LevelStore (baseXP=1000, multiplier=1.2)` — `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:41`
- `let baseXP = 1000.0` — `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:45`
- `let multiplier = 1.2` — `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:46`
- `let xpNeeded = Int(baseXP * pow(multiplier, Double(level - 1)))` — `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:51`
- `async let sleepValue = fetchSleepHoursBatched(lookbackMonths: 12)` — `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:92`
- `limit: 200,` — `AiQo/Features/Onboarding/HistoricalHealthSyncEngine.swift:221`
- `withAnimation(.easeInOut(duration: 0.16)) {` — `AiQo/Features/Profile/LevelCardView.swift:130`
- `withAnimation(.easeOut(duration: 0.2)) {` — `AiQo/Features/Profile/LevelCardView.swift:146`
- `withAnimation(.easeInOut(duration: 0.2)) {` — `AiQo/Features/Profile/LevelCardView.swift:150`
- `withAnimation(.easeOut(duration: 0.1)) {` — `AiQo/Features/Profile/LevelCardView.swift:157`
- `withAnimation(.easeInOut(duration: 0.14)) {` — `AiQo/Features/Profile/LevelCardView.swift:161`
- `guard let url = URL(string: "mailto:AppAiQo5@gmail.com") else { return }` — `AiQo/Features/Profile/ProfileScreen.swift:741`
- `.animation(.easeInOut(duration: 0.25), value: syncFailed)` — `AiQo/Features/Profile/ProfileScreen.swift:899`
- `let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]` — `AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift:22`
- `guard let data = image.jpegData(compressionQuality: 0.85) else { return }` — `AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift:40`
- `estimatedSleepDuration: 5 * 90 * 60,` — `AiQo/Features/Sleep/AlarmSetupCardView.swift:549`
- `estimatedSleepDuration: 4 * 90 * 60,` — `AiQo/Features/Sleep/AlarmSetupCardView.swift:561`
- `temperature: 0.5,` — `AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift:93`

# APPENDIX A — Requested Path Resolution
- Expected path mismatch: `AiQoWatch Watch App/Info.plist` does not exist; the watch target actually points to project-root `AiQoWatch-Watch-App-Info.plist`. [`AiQo.xcodeproj/project.pbxproj:1334`]
- Expected path mismatch: `Package.resolved` sits outside the user-specified discovery roots, so it had to be scanned separately under the Xcode workspace metadata folder. [`AiQo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:3`]
- Expected path mismatch: widget entitlements files live at project root as `AiQoWidgetExtension.entitlements` and `AiQoWatchWidgetExtension.entitlements`. [`AiQo.xcodeproj/project.pbxproj:1264`; `AiQo.xcodeproj/project.pbxproj:1556`]
- Expected path mismatch: there is no `AiQo/App/LoginView.swift`; the actual login screen file is `AiQo/App/LoginViewController.swift` defining `LoginScreenView`. [`AiQo/App/LoginViewController.swift:8`]
- Expected path mismatch: the watch entitlements file lives inside the watch target folder as `AiQoWatch Watch App/AiQoWatch Watch App.entitlements` while other watch metadata is split across root-level files. [`AiQo.xcodeproj/project.pbxproj:1328`]

# APPENDIX B — Complete UserDefaults Key Inventory
## Captain / Language
- `AppleLanguages` — `AiQo/Core/Localization/LocalizationManager.swift:19`; `AiQo/Core/Localization/LocalizationManager.swift:26`
- `aiqo.captain.background.lastInactivitySentAt` — `AiQo/Services/Notifications/NotificationIntelligenceManager.swift:51`
- `aiqo.captain.lastInactivitySentAt` — `AiQo/Services/Notifications/NotificationService.swift:155`
- `aiqo.captain.lastMealReminderSentAt` — `AiQo/Services/Notifications/NotificationService.swift:350`
- `aiqo.captain.lastSleepReminderSentAt` — `AiQo/Services/Notifications/NotificationService.swift:352`
- `aiqo.captain.lastStepGoalSentAt` — `AiQo/Services/Notifications/NotificationService.swift:351`
- `aiqo.captain.lastWaterReminderSentAt` — `AiQo/Services/Notifications/NotificationService.swift:349`
- `aiqo.captain.pendingMessage` — `AiQo/Features/Captain/CaptainNotificationRouting.swift:12`
- `captain_memory_enabled` — `AiQo/Core/MemoryStore.swift:20`; `AiQo/Core/MemoryStore.swift:21`; `AiQo/Core/MemoryStore.swift:26`; `AiQo/Core/MemoryStore.swift:27`

## Kitchen
- `\(lastMealReminderSentAtKeyPrefix).\(meal)` — `AiQo/Services/Notifications/NotificationService.swift:365`
- `\(lastMealReminderSentAtKeyPrefix).\(meal.type)` — `AiQo/Services/Notifications/NotificationService.swift:275`
- `aiqo.kitchen.fridge.items` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:41`
- `aiqo.kitchen.needs.purchase` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:44`
- `aiqo.kitchen.plan.pinned` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:42`
- `aiqo.kitchen.shopping.list` — `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:43`

## Core App / Misc
- `\(lastStepGoalSentAtKeyPrefix).\(milestone)` — `AiQo/Services/Notifications/NotificationService.swift:317`; `AiQo/Services/Notifications/NotificationService.swift:371`
- `aiqo.activity.lastAlmostThereDate` — `AiQo/Services/Notifications/ActivityNotificationEngine.swift:31`
- `aiqo.activity.lastAlmostThereMilestone` — `AiQo/Services/Notifications/ActivityNotificationEngine.swift:32`
- `aiqo.activity.lastGoalCompletedDate` — `AiQo/Services/Notifications/ActivityNotificationEngine.swift:30`
- `aiqo.activity.lastProgress` — `AiQo/Services/Notifications/ActivityNotificationEngine.swift:29`
- `aiqo.activity.lastScheduleDate` — `AiQo/Services/Notifications/ActivityNotificationEngine.swift:34`
- `aiqo.activity.yesterdayTimes` — `AiQo/Services/Notifications/ActivityNotificationEngine.swift:35`
- `aiqo.app.language` — `AiQo/Core/AppSettingsStore.swift:13`
- `aiqo.crash.didTerminateCleanly` — `AiQo/Services/CrashReporting/CrashReporter.swift:142`
- `aiqo.currentLevel` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:444`
- `aiqo.currentLevelProgress` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:446`
- `aiqo.dailyAura.history.v1` — `AiQo/Features/Home/DailyAuraViewModel.swift:14`
- `aiqo.dailyGoals` — `AiQo/Core/DailyGoals.swift:11`; `AiQo/Features/Gym/QuestKit/QuestEngine.swift:54`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:145`
- `aiqo.freeTrial.startDate` — `AiQo/Services/ReferralManager.swift:97`
- `aiqo.inactivity.lastActiveDate` — `AiQo/Services/Notifications/InactivityTracker.swift:6`
- `aiqo.legacyTotalPoints` — `AiQo/Features/First screen/LegacyCalculationViewController.swift:447`
- `aiqo.mining.lastAwardedCoins` — `AiQo/Shared/HealthKitManager.swift:367`
- `aiqo.mining.lastDate` — `AiQo/Shared/HealthKitManager.swift:366`
- `aiqo.nutrition.calorieGoal` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:251`; `AiQo/Features/Kitchen/NutritionTrackerView.swift:548`
- `aiqo.nutrition.carbGoal` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:253`; `AiQo/Features/Kitchen/NutritionTrackerView.swift:550`
- `aiqo.nutrition.fatGoal` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:254`; `AiQo/Features/Kitchen/NutritionTrackerView.swift:551`
- `aiqo.nutrition.fiberGoal` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:255`; `AiQo/Features/Kitchen/NutritionTrackerView.swift:552`
- `aiqo.nutrition.proteinGoal` — `AiQo/Features/Kitchen/NutritionTrackerView.swift:252`; `AiQo/Features/Kitchen/NutritionTrackerView.swift:549`
- `aiqo.progressPhotos.entries` — `AiQo/Features/ProgressPhotos/ProgressPhotoStore.swift:18`
- `aiqo.promptManager.cachedRemoteConfiguration` — `AiQo/Features/Captain/AiQoPromptManager.swift:22`
- `aiqo.user.currentXP` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:94`
- `aiqo.user.level` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:93`
- `aiqo.user.totalXP` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift:95`
- `aiqo.userAvatar` — `AiQo/Core/UserProfileStore.swift:46`
- `aiqo.userProfile` — `AiQo/Core/UserProfileStore.swift:45`
- `aiqo.watch.location-type` — `AiQoWatch Watch App/WorkoutManager.swift:26`
- `aiqo.watch.session-id` — `AiQoWatch Watch App/WorkoutManager.swift:24`
- `aiqo_active_cal` — `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:166`; `AiQoWatch Watch App/WorkoutManager.swift:850`; `AiQoWidget/AiQoSharedStore.swift:8`
- `aiqo_active_cal_goal` — `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:168`
- `aiqo_bpm` — `AiQoWatch Watch App/WorkoutManager.swift:851`
- `aiqo_km` — `AiQoWatch Watch App/WorkoutManager.swift:854`
- `aiqo_km_current` — `AiQoWatch Watch App/WorkoutManager.swift:853`
- `aiqo_stand_percent` — `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:169`; `AiQoWatch Watch App/WorkoutManager.swift:852`
- `aiqo_steps` — `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:165`; `AiQoWidget/AiQoSharedStore.swift:7`
- `aiqo_steps_goal` — `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:167`; `AiQoWidget/AiQoSharedStore.swift:9`
- `aiqo_week_daily_km` — `AiQoWatch Watch App/WorkoutManager.swift:870`
- `aiqo_week_km_total` — `AiQoWatch Watch App/WorkoutManager.swift:871`
- `appLanguage` — `AiQo/Features/Onboarding/FeatureIntroView.swift:28`
- `didCompleteDatingProfile` — `AiQo/App/AppDelegate.swift:129`; `AiQo/App/AppDelegate.swift:195`
- `didCompleteFeatureIntro` — `AiQo/App/AppDelegate.swift:131`; `AiQo/App/AppDelegate.swift:197`
- `didCompleteLegacyCalculation` — `AiQo/App/AppDelegate.swift:63`; `AiQo/App/AppDelegate.swift:130`; `AiQo/App/AppDelegate.swift:196`
- `didSelectLanguage` — `AiQo/App/AppDelegate.swift:127`; `AiQo/App/AppDelegate.swift:193`
- `didShowFirstAuthScreen` — `AiQo/App/AppDelegate.swift:128`; `AiQo/App/AppDelegate.swift:194`
- `lastCelebratedLevel` — `AiQo/App/MainTabScreen.swift:84`; `AiQo/App/MainTabScreen.swift:86`
- `user_gender` — `AiQo/App/AppDelegate.swift:166`; `AiQo/Core/Models/NotificationPreferencesStore.swift:9`
- `widget_calories_goal` — `AiQoWatchWidget/AiQoWatchWidget.swift:37`

## Notifications / Workout Sync
- `aiqo.activity.selectedAngelTimes` — `AiQo/Services/Notifications/ActivityNotificationEngine.swift:33`
- `aiqo.ai.workout.anchor` — `AiQo/Services/Notifications/NotificationService.swift:435`
- `aiqo.ai.workout.processed.ids` — `AiQo/Services/Notifications/NotificationService.swift:436`
- `aiqo.notification.language` — `AiQo/Core/Models/NotificationPreferencesStore.swift:10`
- `aiqo.notifications.didPromptPermission` — `AiQo/Services/Notifications/NotificationService.swift:9`
- `aiqo.notifications.enabled` — `AiQo/Core/AppSettingsStore.swift:14`
- `aiqo.watch.workout-type` — `AiQoWatch Watch App/WorkoutManager.swift:25`
- `aiqo.workout.session-id` — `AiQo/PhoneConnectivityManager.swift:23`
- `aiqo.workout.snapshot` — `AiQo/PhoneConnectivityManager.swift:22`
- `notificationLanguage` — `AiQo/Core/AppSettingsScreen.swift:12`; `AiQo/Core/AppSettingsScreen.swift:286`; `AiQo/Core/AppSettingsScreen.swift:313`; `AiQo/Services/Notifications/NotificationIntelligenceManager.swift:44`; `AiQo/Services/Notifications/NotificationService.swift:964`
- `push_device_token` — `AiQo/Services/SupabaseService.swift:118`; `AiQo/Services/SupabaseService.swift:132`

## Tribe / Arena / Referral
- `aiqo.arena.completedChallenges` — `AiQo/Tribe/Galaxy/ArenaChallengeHistoryView.swift:175`
- `aiqo.tribe.preview.forceEnabled` — `AiQo/Tribe/Preview/TribePreviewController.swift:34`
- `aiqo.tribe.spark.eventLog` — `AiQo/Tribe/Views/TribeHubScreen.swift:972`
- `aiqo.tribe.spark.lastSent` — `AiQo/Tribe/Views/TribeHubScreen.swift:971`
- `aiqo.user.tribePrivacyMode` — `AiQo/Core/UserProfileStore.swift:47`

## Gym / Quests / Legendary
- `aiqo.gym.quests.daily-state.v1` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:73`
- `aiqo.gym.quests.daily-state.v2` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:72`
- `aiqo.gym.quests.daily-state.v3` — `AiQo/Features/Gym/Quests/Store/QuestDailyStore.swift:71`
- `aiqo.gym.quests.wins.v1` — `AiQo/Features/Gym/Quests/Store/WinsStore.swift:9`
- `aiqo.legendary.activeProject` — `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:19`
- `aiqo.legendaryChallengesMigrated` — `AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift:16`
- `aiqo.quest.earned_achievements` — `AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift:20`
- `aiqo.quest.kitchen.hasMealPlan` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:449`; `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:46`; `AiQo/Features/Kitchen/KitchenViewModel.swift:20`
- `aiqo.quest.kitchen.logs` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:448`
- `aiqo.quest.kitchen.savedAt` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:450`; `AiQo/Features/Kitchen/KitchenPersistenceStore.swift:47`; `AiQo/Features/Kitchen/KitchenViewModel.swift:21`
- `aiqo.quest.progress.records.v1` — `AiQo/Features/Gym/QuestKit/QuestProgressStore.swift:12`
- `aiqo.quest.share.logs` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:511`
- `aiqo.quest.social.logs` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:404`
- `aiqo.quest.timer.sessions` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:305`
- `aiqo.quest.water.fallback.\(formatter.string(from: Date()))` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:297`
- `aiqo.quest.water.fallback.\(formatter.string(from: date))` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:266`
- `aiqo.quest.workout.logs` — `AiQo/Features/Gym/QuestKit/QuestDataSources.swift:354`
- `aiqo.quests.help-strangers.share-anonymous` — `AiQo/Features/Gym/Quests/Views/HelpStrangersBottomSheet.swift:12`

## Vibe / Spotify
- `coach_language` — `AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift:9`
- `com.aiqo.vibe.mixWithOthers` — `AiQo/Features/Home/VibeControlSheet.swift:180`
- `com.aiqo.vibe.nativeIntensity` — `AiQo/Features/Home/VibeControlSheet.swift:181`
- `com.aiqo.vibe.source` — `AiQo/Features/Home/VibeControlSheet.swift:179`
- `com.aiqo.vibeAudio.profile` — `AiQo/Core/VibeAudioEngine.swift:828`

# APPENDIX C — Complete Analytics Event Inventory
- `appLaunched` => `app_launched` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:21`
- `appBecameActive` => `app_became_active` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:22`
- `appEnteredBackground` => `app_entered_background` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:23`
- `onboardingStepViewed` => `onboarding_step_viewed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:26`
- `onboardingCompleted` => `onboarding_completed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:29`
- `onboardingSkipped` => `onboarding_skipped` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:30`
- `loginStarted` => `login_started` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:33`
- `loginCompleted` => `login_completed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:34`
- `logoutCompleted` => `logout_completed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:35`
- `tabSelected` => `tab_selected` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:38`
- `screenViewed` => `screen_viewed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:42`
- `captainChatOpened` => `captain_chat_opened` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:47`
- `captainMessageSent` => `captain_message_sent` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:48`
- `captainResponseReceived` => `captain_response_received` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:51`
- `captainResponseFailed` => `captain_response_failed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:54`
- `captainVoicePlayed` => `captain_voice_played` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:57`
- `captainHistoryViewed` => `captain_history_viewed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:58`
- `workoutStarted` => `workout_started` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:61`
- `workoutCompleted` => `workout_completed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:64`
- `workoutCancelled` => `workout_cancelled` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:71`
- `visionCoachStarted` => `vision_coach_started` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:72`
- `visionCoachCompleted` => `vision_coach_completed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:73`
- `questStarted` => `quest_started` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:81`
- `questCompleted` => `quest_completed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:84`
- `kitchenOpened` => `kitchen_opened` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:89`
- `mealPlanGenerated` => `meal_plan_generated` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:90`
- `fridgeItemAdded` => `fridge_item_added` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:91`
- `tribeCreated` => `tribe_created` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:94`
- `tribeJoined` => `tribe_joined` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:95`
- `tribeLeft` => `tribe_left` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:96`
- `tribeLeaderboardViewed` => `tribe_leaderboard_viewed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:97`
- `tribeArenaViewed` => `tribe_arena_viewed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:98`
- `spotifyConnected` => `spotify_connected` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:101`
- `spotifyTrackPlayed` => `spotify_track_played` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:102`
- `healthPermissionGranted` => `health_permission_granted` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:107`
- `healthPermissionDenied` => `health_permission_denied` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:110`
- `dailySummaryGenerated` => `daily_summary_generated` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:111`
- `paywallViewed` => `paywall_viewed` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:120`
- `subscriptionStarted` => `subscription_started` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:121`
- `subscriptionFailed` => `subscription_failed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:127`
- `subscriptionRestored` => `subscription_restored` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:133`
- `subscriptionCancelled` => `subscription_cancelled` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:134`
- `freeTrialStarted` => `free_trial_started` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:135`
- `notificationPermissionGranted` => `notification_permission_granted` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:138`
- `notificationPermissionDenied` => `notification_permission_denied` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:139`
- `notificationTapped` => `notification_tapped` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:140`
- `languageChanged` => `language_changed` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:145`
- `memoryCleared` => `memory_cleared` (let) — `AiQo/Services/Analytics/AnalyticsEvent.swift:148`
- `errorOccurred` => `error_occurred` (func) — `AiQo/Services/Analytics/AnalyticsEvent.swift:151`

# APPENDIX D — HealthKit Matrix
## Read Types
- HealthKitService read quantities: stepCount, heartRate, restingHeartRate, heartRateVariabilitySDNN, walkingHeartRateAverage, activeEnergyBurned, distanceWalkingRunning, dietaryWater, vo2Max. [`AiQo/Services/Permissions/HealthKit/HealthKitService.swift:44`]
- HealthKitService read categories: sleepAnalysis, appleStandHour, plus workouts. [`AiQo/Services/Permissions/HealthKit/HealthKitService.swift:56`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:73`]
- Shared HealthKitManager read quantities: heartRate, activeEnergyBurned, distanceWalkingRunning, distanceCycling, stepCount, bodyMass, bodyFatPercentage, leanBodyMass. [`AiQo/Shared/HealthKitManager.swift:82`]
- Shared HealthKitManager also reads sleepAnalysis and activitySummaryType. [`AiQo/Shared/HealthKitManager.swift:92`]
- WatchHealthKitManager reads stepCount, activeEnergyBurned, distanceWalkingRunning, heartRate, sleepAnalysis, and workouts. [`AiQoWatch Watch App/Services/WatchHealthKitManager.swift:15`]

## Write Types
- HealthKitService writes dietaryWater, heartRate, restingHeartRate, heartRateVariabilitySDNN, vo2Max, distanceWalkingRunning, and workouts. [`AiQo/Services/Permissions/HealthKit/HealthKitService.swift:76`; `AiQo/Services/Permissions/HealthKit/HealthKitService.swift:98`]
- Shared HealthKitManager only shares workouts. [`AiQo/Shared/HealthKitManager.swift:77`]
- WatchHealthKitManager shares workouts. [`AiQoWatch Watch App/Services/WatchHealthKitManager.swift:23`]

# APPENDIX E — Complete @Model Inventory
## `CaptainMemory` — area: `Core` — `AiQo/Core/CaptainMemory.swift:6`
- `var id: UUID` — `AiQo/Core/CaptainMemory.swift:9`
- `var category: String` — `AiQo/Core/CaptainMemory.swift:11`
- `var value: String` — `AiQo/Core/CaptainMemory.swift:15`
- `var confidence: Double` — `AiQo/Core/CaptainMemory.swift:17`
- `var source: String` — `AiQo/Core/CaptainMemory.swift:19`
- `var createdAt: Date` — `AiQo/Core/CaptainMemory.swift:20`
- `var updatedAt: Date` — `AiQo/Core/CaptainMemory.swift:21`
- `var accessCount: Int` — `AiQo/Core/CaptainMemory.swift:23`

## `PersistentChatMessage` — area: `Features` — `AiQo/Features/Captain/CaptainModels.swift:8`
- `var messageID: UUID` — `AiQo/Features/Captain/CaptainModels.swift:11`
- `var text: String` — `AiQo/Features/Captain/CaptainModels.swift:12`
- `var isUser: Bool` — `AiQo/Features/Captain/CaptainModels.swift:13`
- `var timestamp: Date` — `AiQo/Features/Captain/CaptainModels.swift:14`
- `var spotifyRecommendationData: Data?` — `AiQo/Features/Captain/CaptainModels.swift:16`
- `var sessionID: UUID = UUID()` — `AiQo/Features/Captain/CaptainModels.swift:18`

## `PlayerStats` — area: `Features` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:11`
- `@Attribute(.unique) var profileID: String var currentLevel: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:15`
- `var currentLevel: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:15`
- `var currentLevelXP: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:16`
- `var totalXP: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:17`
- `var totalAura: Double` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:18`
- `var createdAt: Date` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:19`
- `var updatedAt: Date` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:20`

## `QuestStage` — area: `Features` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:42`
- `@Attribute(.unique) var stageID: String var stageIndex: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:44`
- `var stageIndex: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:44`
- `var titleKey: String` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:45`
- `var tabTitleKey: String` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:46`
- `var sortOrder: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:47`
- `var createdAt: Date` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:48`
- `var updatedAt: Date` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:49`
- `@Relationship(deleteRule: .cascade, inverse: \QuestRecord.stage) var records: [QuestRecord]` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:52`
- `var records: [QuestRecord]` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:52`

## `QuestRecord` — area: `Features` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:74`
- `@Attribute(.unique) var questID: String var stageIndex: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:78`
- `var stageIndex: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:78`
- `var questIndex: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:79`
- `var titleKey: String` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:80`
- `var fallbackTitle: String` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:81`
- `var questType: QuestType` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:82`
- `var questSource: QuestSource` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:83`
- `var metricAKey: QuestMetricKey` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:84`
- `var metricBKey: QuestMetricKey` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:85`
- `var deepLinkAction: QuestDeepLinkAction?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:86`
- `var currentTier: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:88`
- `var metricAValue: Double` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:89`
- `var metricBValue: Double` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:90`
- `var lastUpdated: Date` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:91`
- `var isStarted: Bool` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:92`
- `var startedAt: Date?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:93`
- `var streakCount: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:94`
- `var lastCompletionDate: Date?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:95`
- `var lastStreakDate: Date?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:96`
- `var resetKeyDaily: String?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:97`
- `var resetKeyWeekly: String?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:98`
- `var isCompleted: Bool` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:99`
- `var completedAt: Date?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:100`
- `var stage: QuestStage?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:102`

## `Reward` — area: `Features` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:186`
- `@Attribute(.unique) var rewardID: String var title: String` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:188`
- `var title: String` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:188`
- `var subtitle: String` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:189`
- `var iconSystemName: String` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:190`
- `var tintHex: String` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:191`
- `var kind: RewardKind` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:192`
- `var currentValue: Double` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:193`
- `var targetValue: Double` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:194`
- `var isUnlocked: Bool` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:195`
- `var unlockedAt: Date?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:196`
- `var sourceQuestID: String?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:197`
- `var stageIndex: Int?` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:198`
- `var isFeatured: Bool` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:199`
- `var displayOrder: Int` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:200`
- `var createdAt: Date` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:201`
- `var updatedAt: Date` — `AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift:202`

## `SmartFridgeScannedItemRecord` — area: `Features` — `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:5`
- `var id: UUID` — `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:6`
- `var name: String` — `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:7`
- `var quantity: Double` — `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:8`
- `var unit: String?` — `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:9`
- `var alchemyNoteKey: String?` — `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:10`
- `var capturedAt: Date` — `AiQo/Features/Kitchen/SmartFridgeScannedItemRecord.swift:11`

## `RecordProject` — area: `Features` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:6`
- `var id: UUID` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:7`
- `var recordID: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:9`
- `var recordTitle: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:11`
- `var recordCategory: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:13`
- `var targetValue: Double` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:15`
- `var unit: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:17`
- `var currentRecordHolder: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:19`
- `var holderCountryFlag: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:21`
- `var userWeightAtStart: Double?` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:24`
- `var userFitnessLevelAtStart: String?` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:25`
- `var userBestAtStart: Double` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:27`
- `var totalWeeks: Int` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:31`
- `var currentWeek: Int` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:33`
- `var planJSON: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:35`
- `var difficulty: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:37`
- `var bestPerformance: Double` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:41`
- `var status: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:47`
- `var startDate: Date` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:48`
- `var endDate: Date?` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:49`
- `var lastReviewDate: Date?` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:50`
- `var lastReviewNotes: String?` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:51`
- `var isPinnedToPlan: Bool` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:54`
- `var completedTaskIDsJSON: String` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:58`
- `var hrrPeakHR: Double?` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:62`
- `var hrrRecoveryHR: Double?` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:64`
- `var hrrLevel: String?` — `AiQo/Features/LegendaryChallenges/Models/RecordProject.swift:66`

## `WeeklyLog` — area: `Features` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:6`
- `var id: UUID` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:7`
- `var weekNumber: Int` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:8`
- `var date: Date` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:9`
- `var currentWeight: Double?` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:12`
- `var performanceThisWeek: Double?` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:14`
- `var userFeedback: String?` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:16`
- `var captainNotes: String?` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:18`
- `var adjustments: String?` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:20`
- `var weekRating: Int?` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:24`
- `var isOnTrack: Bool` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:26`
- `var obstacles: String?` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:28`
- `var project: RecordProject?` — `AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift:31`

## `AiQoDailyRecord` — area: `NeuralMemory.swift` — `AiQo/NeuralMemory.swift:6`
- `@Attribute(.unique) var id: String // نخليه بصيغة (yyyy-MM-dd) حتى ما يتكرر اليوم var date: Date` — `AiQo/NeuralMemory.swift:10`
- `var date: Date` — `AiQo/NeuralMemory.swift:10`
- `var currentSteps: Int` — `AiQo/NeuralMemory.swift:13`
- `var targetSteps: Int` — `AiQo/NeuralMemory.swift:14`
- `var burnedCalories: Int` — `AiQo/NeuralMemory.swift:15`
- `var targetCalories: Int` — `AiQo/NeuralMemory.swift:16`
- `var waterCups: Int` — `AiQo/NeuralMemory.swift:17`
- `var targetWaterCups: Int` — `AiQo/NeuralMemory.swift:18`
- `var captainDailySuggestion: String` — `AiQo/NeuralMemory.swift:21`
- `@Relationship(deleteRule: .cascade) var workouts: [WorkoutTask]` — `AiQo/NeuralMemory.swift:25`
- `var workouts: [WorkoutTask]` — `AiQo/NeuralMemory.swift:25`

## `WorkoutTask` — area: `NeuralMemory.swift` — `AiQo/NeuralMemory.swift:47`
- `var id: UUID` — `AiQo/NeuralMemory.swift:48`
- `var title: String // مثل: "تمارين الضغط (3 مجاميع)"` — `AiQo/NeuralMemory.swift:49`
- `var isCompleted: Bool` — `AiQo/NeuralMemory.swift:50`
- `var dailyRecord: AiQoDailyRecord?` — `AiQo/NeuralMemory.swift:53`

## `ArenaTribe` — area: `Tribe` — `AiQo/Tribe/Galaxy/ArenaModels.swift:7`
- `@Attribute(.unique) var id: UUID var name: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:9`
- `var name: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:9`
- `var creatorUserID: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:10`
- `var inviteCode: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:11`
- `var members: [ArenaTribeMember]` — `AiQo/Tribe/Galaxy/ArenaModels.swift:12`
- `var createdAt: Date` — `AiQo/Tribe/Galaxy/ArenaModels.swift:13`
- `var isActive: Bool` — `AiQo/Tribe/Galaxy/ArenaModels.swift:14`
- `var isFrozen: Bool` — `AiQo/Tribe/Galaxy/ArenaModels.swift:15`
- `var frozenAt: Date?` — `AiQo/Tribe/Galaxy/ArenaModels.swift:16`

## `ArenaTribeMember` — area: `Tribe` — `AiQo/Tribe/Galaxy/ArenaModels.swift:42`
- `@Attribute(.unique) var id: UUID var userID: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:44`
- `var userID: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:44`
- `var displayName: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:45`
- `var initials: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:46`
- `var joinedAt: Date` — `AiQo/Tribe/Galaxy/ArenaModels.swift:47`
- `var isCreator: Bool` — `AiQo/Tribe/Galaxy/ArenaModels.swift:48`
- `var tribe: ArenaTribe?` — `AiQo/Tribe/Galaxy/ArenaModels.swift:50`

## `ArenaWeeklyChallenge` — area: `Tribe` — `AiQo/Tribe/Galaxy/ArenaModels.swift:95`
- `@Attribute(.unique) var id: UUID var title: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:97`
- `var title: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:97`
- `var descriptionText: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:98`
- `var metric: ArenaChallengeMetric` — `AiQo/Tribe/Galaxy/ArenaModels.swift:99`
- `var startDate: Date` — `AiQo/Tribe/Galaxy/ArenaModels.swift:100`
- `var endDate: Date` — `AiQo/Tribe/Galaxy/ArenaModels.swift:101`
- `var isActive: Bool` — `AiQo/Tribe/Galaxy/ArenaModels.swift:102`
- `var participations: [ArenaTribeParticipation]` — `AiQo/Tribe/Galaxy/ArenaModels.swift:103`

## `ArenaTribeParticipation` — area: `Tribe` — `AiQo/Tribe/Galaxy/ArenaModels.swift:123`
- `@Attribute(.unique) var id: UUID var tribe: ArenaTribe?` — `AiQo/Tribe/Galaxy/ArenaModels.swift:125`
- `var tribe: ArenaTribe?` — `AiQo/Tribe/Galaxy/ArenaModels.swift:125`
- `var challenge: ArenaWeeklyChallenge?` — `AiQo/Tribe/Galaxy/ArenaModels.swift:126`
- `var currentScore: Double` — `AiQo/Tribe/Galaxy/ArenaModels.swift:127`
- `var rank: Int` — `AiQo/Tribe/Galaxy/ArenaModels.swift:128`
- `var joinedAt: Date` — `AiQo/Tribe/Galaxy/ArenaModels.swift:129`

## `ArenaEmirateLeaders` — area: `Tribe` — `AiQo/Tribe/Galaxy/ArenaModels.swift:142`
- `@Attribute(.unique) var id: UUID var tribe: ArenaTribe?` — `AiQo/Tribe/Galaxy/ArenaModels.swift:144`
- `var tribe: ArenaTribe?` — `AiQo/Tribe/Galaxy/ArenaModels.swift:144`
- `var challenge: ArenaWeeklyChallenge?` — `AiQo/Tribe/Galaxy/ArenaModels.swift:145`
- `var weekNumber: Int` — `AiQo/Tribe/Galaxy/ArenaModels.swift:146`
- `var startDate: Date` — `AiQo/Tribe/Galaxy/ArenaModels.swift:147`
- `var endDate: Date` — `AiQo/Tribe/Galaxy/ArenaModels.swift:148`
- `var isDefending: Bool` — `AiQo/Tribe/Galaxy/ArenaModels.swift:149`

## `ArenaHallOfFameEntry` — area: `Tribe` — `AiQo/Tribe/Galaxy/ArenaModels.swift:163`
- `@Attribute(.unique) var id: UUID var weekNumber: Int` — `AiQo/Tribe/Galaxy/ArenaModels.swift:165`
- `var weekNumber: Int` — `AiQo/Tribe/Galaxy/ArenaModels.swift:165`
- `var tribeName: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:166`
- `var challengeTitle: String` — `AiQo/Tribe/Galaxy/ArenaModels.swift:167`
- `var date: Date` — `AiQo/Tribe/Galaxy/ArenaModels.swift:168`

# APPENDIX F — Directory Tree
```
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
./AiQo/Features/Sleep
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

# APPENDIX G — Complete File Inventory
```
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
AiQo/Core/Purchases/SubscriptionTier.swift
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
AiQo/Features/Sleep/AlarmSetupCardView.swift
AiQo/Features/Sleep/AppleIntelligenceSleepAgent.swift
AiQo/Features/Sleep/HealthManager+Sleep.swift
AiQo/Features/Sleep/SleepDetailCardView.swift
AiQo/Features/Sleep/SleepScoreRingView.swift
AiQo/Features/Sleep/SleepSessionObserver.swift
AiQo/Features/Sleep/SmartWakeCalculatorView.swift
AiQo/Features/Sleep/SmartWakeEngine.swift
AiQo/Features/Sleep/SmartWakeViewModel.swift
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
AiQo/Resources/AiQo.storekit
AiQo/Resources/AiQo_Test.storekit
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
AiQo/Resources/Prompts.xcstrings
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
AiQo/Services/Notifications/SmartNotificationManager.swift
AiQo/Services/Permissions/HealthKit/HealthKitService.swift
AiQo/Services/Permissions/HealthKit/TodaySummary.swift
AiQo/Services/ReferralManager.swift
AiQo/Services/SupabaseArenaService.swift
AiQo/Services/SupabaseService.swift
AiQo/Shared/CoinManager.swift
AiQo/Shared/HealthKitManager.swift
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
Configuration/Secrets.template.xcconfig
Configuration/Secrets.xcconfig
```

