# AiQo Master Blueprint 16

> **Purpose.** Single source of truth for the AiQo iOS ecosystem as of 2026-04-16. Any future Claude Code session (or developer) reading this document should understand the entire product — iPhone app, Apple Watch companion, widgets, backend surface, AI pipeline, monetization, and roadmap — without having to re-scan the codebase.
>
> **Evidence policy.** Facts in this document come from direct reads of live Swift files, `project.pbxproj`, `Info.plist`, entitlements, `.storekit` catalogs, and Apple localization files. Founder intent comes from `AiQo_AIContext_0*.md` and Blueprint 15. Where live code and founder intent disagree, both are shown and the drift is called out.

---

## Table of Contents

1. [Executive Summary](#1--executive-summary)
2. [Tech Stack & Architecture](#2--tech-stack--architecture)
3. [Project File Tree](#3--project-file-tree)
4. [Feature Modules (detailed)](#4--feature-modules-detailed)
5. [HealthKit Integration](#5--healthkit-integration)
6. [AI Pipeline](#6--ai-pipeline)
7. [Supabase Backend](#7--supabase-backend)
8. [WatchOS Companion](#8--watchos-companion)
9. [Design System](#9--design-system)
10. [Localization](#10--localization)
11. [💰 Subscription Tiers (CRITICAL)](#11--subscription-tiers-critical)
12. [Pre-Launch Checklist](#12--pre-launch-checklist)
13. [Known Issues & Technical Debt](#13--known-issues--technical-debt)
14. [Coding Conventions](#14--coding-conventions)
15. [Claude Code Workflow Guidelines](#15--claude-code-workflow-guidelines)
16. [Roadmap](#16--roadmap)
17. [Philosophy & Non-Negotiables](#17--philosophy--non-negotiables)
18. [Change Log](#18--change-log)

---

## 1 — Executive Summary

**Mission.** AiQo is technology that protects humans. It fuses faith, discipline, and AI into a single Arabic-first, RTL-native iOS operating system for the body and mind. It interprets Apple Health signals, coaches through Captain Hamoudi (a culturally specific Iraqi/Gulf Arabic AI character), and turns raw metrics into calm, grounded action — never into another dashboard.

**Founder.** Mohammed Raad Aziz ("Hamoudi"), solo founder. Iraqi, PR student at the American University of the Emirates (AUE), based in Dubai. Builds with Claude Code + Xcode end-to-end.

**Current status.**
- **App version / build**: `1.0 (17)` — evidence: `AiQo.xcodeproj/project.pbxproj` (`MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 17`).
- **Git branch**: `main` (working tree clean except `LiveWorkoutSession.swift`).
- **Live Swift footprint**: `462` Swift files across four runtime targets (`AiQo`, `AiQoWatch Watch App`, `AiQoWidget`, `AiQoWatchWidget`) totalling `~114,800` lines.
- **Active TODOs in Swift**: `5`, all in [`AiQo/Features/Tribe/TribeExperienceFlow.swift`](AiQo/Features/Tribe/TribeExperienceFlow.swift) — Tribe still hidden behind feature flags.
- **Deployment targets**: iOS `26.2`, watchOS `26.2` (Xcode 26 / Swift 5.10+).

**Long-term vision timeline.**

| Year | Milestone |
|---|---|
| **2026 — May** | **AiQo v1.0 launch at AUE campus**, Instagram campaign (`@aiqoapp`), initial UAE rollout. |
| **2026 — H2** | Post-launch hardening: Tribe backend live, Firebase Crashlytics, annual subscription, broader GCC |
| **2027** | **Phone prototype R&D** — "MR-OS" — a phone-class hardware concept where AiQo is the native OS, not a third-party app |
| **2028** | **MR-OS phone commercial launch** |
| **2030+** | **Noor City** — long-term physical/community destination anchoring the AiQo ecosystem |

---

## 2 — Tech Stack & Architecture

### Runtime
- **iOS**: `26.2` minimum (`IPHONEOS_DEPLOYMENT_TARGET = 26.2`)
- **watchOS**: `26.2` minimum (`WATCHOS_DEPLOYMENT_TARGET = 26.2`)
- **Xcode**: 16.3+ in CI (`.github/workflows/swift.yml`), 26 locally
- **Language**: Swift 5.10+, SwiftUI-first, UIKit-bridged where required (e.g. `LoginViewController.swift`, `LegacyCalculationViewController.swift`)

### Architecture style
- **Hybrid SwiftUI + UIKit**. Main shell ([`AiQo/App/MainTabScreen.swift`](AiQo/App/MainTabScreen.swift)) is SwiftUI; authentication and the legacy level-reveal flow are UIKit.
- **Pattern**: loose MVVM. `View` → `ViewModel` (ObservableObject / `@Observable`) → domain store / service singletons. Shared state lives in `.shared` singletons wired as EnvironmentObjects.
- **Persistence**: three independent SwiftData containers (main app, Captain memory, QuestLoot), UserDefaults for flags/levels, Keychain for trial date, JPEG files in `Documents/ProgressPhotos` for photos.

### Core frameworks
- HealthKit + HealthKit background delivery
- Apple Foundation Models (`LanguageModelSession`) on-device path, in the Captain local brain
- StoreKit 2 (two-tier catalog)
- SwiftData (three containers)
- WatchConnectivity (two-way iPhone↔Watch sync)
- UserNotifications + BackgroundTasks
- AlarmKit (Smart Wake)
- AVFoundation (TTS playback, Spotify URL routing, camera in Kitchen)
- CoreHaptics (spin-wheel, quest rewards)
- SiriKit / NSUserActivity (eight declared shortcut intents)
- AppIntents / WidgetKit (iPhone + Watch widgets)

### External services
- **Gemini API** (cloud brain) — endpoint `https://generativelanguage.googleapis.com/v1beta/models` (`HybridBrainService.swift:89`)
  - Core: `gemini-2.5-flash`
  - Intelligence Pro: `gemini-3-flash-preview`
- **ElevenLabs TTS** — model `eleven_multilingual_v2` (`CaptainVoiceAPI.swift:8-9`)
- **Supabase** — auth, profile, device-token, arena/tribe, `validate-receipt` Edge Function
- **Spotify iOS SDK** — embedded binary framework (`AiQo/Frameworks/SpotifyiOS.framework`)
- **GPT API (OpenAI)** — Arabic fallback pathway per founder brief (handled through `CloudBrainService` abstraction; current shipping model routes Arabic through Gemini)

### Swift Package Manager dependencies
No `Package.swift` is checked in — SPM references live in `AiQo.xcodeproj/project.pbxproj`:

| Package | Version rule | Purpose |
|---|---|---|
| `supabase-swift` | `upToNextMajor from 2.5.1` | Auth + PostgREST + Realtime |
| `SDWebImageSwiftUI` | `upToNextMajor from 3.1.4` | Remote image loading |
| `swift-system` | `upToNextMajor from 1.6.4` | Low-level system bridges |

Absent by design: no Firebase SPM, no Mixpanel/PostHog, no RevenueCat (StoreKit 2 handled natively), no third-party auth SDK.

---

## 3 — Project File Tree

```text
AiQo/  (solo-founder monorepo)
├── AiQo/                                iPhone app target
│   ├── App/                             AppDelegate, SceneDelegate, MainTabScreen, login, onboarding shells
│   ├── Core/                            Cross-cutting stores, schemas, settings, voice, memory
│   │   ├── Purchases/                   StoreKit 2 + entitlements + receipt validation
│   │   ├── Schema/                      Captain SwiftData v1 → v3 migrations
│   │   ├── Localization/                Language manager
│   │   ├── Models/                      LevelStore, WeeklyReportEntry, buffers
│   │   ├── Keychain/                    Keychain wrappers (trial date)
│   │   ├── Utilities/                   Small cross-feature helpers
│   │   └── Config/                      Build-config glue
│   ├── DesignSystem/                    AiQoTheme, AiQoColors, reusable components
│   │   ├── Components/                  GlassCard, GlassBubbleTabBar, stat cards, shield badges
│   │   └── Modifiers/                   .ultraThinMaterial wrappers, gradient overlays
│   ├── Features/                        User-visible surfaces
│   │   ├── Captain/                     3D character chat, BrainOrchestrator, prompts, voice
│   │   ├── Home/                        Dashboard, DailyAura, metric cards, vibe shortcut
│   │   ├── Gym/                         Club tabs (Body/Plan/Peaks/Battle/Impact), workouts, Quests
│   │   │   ├── Club/                    Sub-tab implementations
│   │   │   ├── QuestKit/                Gym quest SwiftData store
│   │   │   └── Quests/                  Quest views + VisionCoach camera coach
│   │   ├── Kitchen/                     Alchemy Kitchen, fridge scanner, nutrition tracking
│   │   ├── Sleep/                       Smart Wake, sleep observer, AI sleep agent
│   │   ├── LegendaryChallenges/         Peaks, HRR assessment, RecordProject
│   │   ├── MyVibe/                      DJ Hamoudi, vibe orchestrator, Spotify bridge
│   │   ├── Tribe/                       Social layer — hidden behind feature flags
│   │   ├── Profile/                     User profile, body data, username formatter
│   │   ├── WeeklyReport/                Weekly summary + Instagram Stories export
│   │   ├── ProgressPhotos/              Photo capture + compare
│   │   ├── Onboarding/                  Feature intro, Captain personalization
│   │   ├── First screen/                Legacy level-reveal (UIKit VC)
│   │   ├── Compliance/                  Legal / consent flows
│   │   └── DataExport/                  User-data export scaffolding
│   ├── Premium/                         AccessManager, PremiumStore, FreeTrialManager, paywall wrapper
│   ├── UI/Purchases/                    Live PaywallView (SwiftUI) — canonical
│   ├── Services/                        Supabase, DeepLinkRouter, Notifications, CrashReporting, Analytics
│   │   ├── Analytics/                   Local event tracking
│   │   ├── CrashReporting/              Local JSONL logger + optional Firebase wrapper
│   │   ├── Notifications/               Scheduler, morning orchestrator, categories
│   │   ├── Permissions/                 HealthKit permission helpers
│   │   ├── Trial/                       TrialJourneyOrchestrator
│   │   └── Memory/                      Captain memory helpers
│   ├── Tribe/                           Legacy Tribe/arena scaffolding (Galaxy, Arena, Log, Stores)
│   ├── Shared/                          Cross-feature managers (HealthKit, CoinManager)
│   ├── Frameworks/SpotifyiOS.framework  Embedded Spotify iOS SDK
│   ├── Resources/
│   │   ├── Assets.xcassets/             App icons, Captain images, USDZ placeholders
│   │   ├── ar.lproj / en.lproj          Localizable.strings (~2,185 keys)
│   │   ├── Prompts.xcstrings            Bilingual Captain prompt catalog
│   │   ├── AiQo.storekit                Live StoreKit source of truth
│   │   └── AiQo_Test.storekit           DEBUG-only StoreKit config
│   ├── Info.plist                       Feature flags, shortcuts, usage strings
│   ├── AiQo.entitlements                Capabilities (push, HealthKit, Sign-in-with-Apple, app groups)
│   └── PrivacyInfo.xcprivacy            App privacy manifest
├── AiQoWatch Watch App/                 watchOS companion app
│   ├── AiQoWatchApp.swift               @main entry + WKApplicationDelegateAdaptor
│   ├── Views/                           Home, active workout, summary cards
│   ├── Services/                        WatchHealthKitManager, WatchWorkoutManager, WatchConnectivityService
│   ├── Models/                          Watch-side models
│   ├── Shared/                          Sync codec shared with phone
│   └── Design/                          Watch-specific tokens
├── AiQoWidget/                          iPhone widget extension
├── AiQoWatchWidget/                     Watch widget extension
├── AiQoTests/                           Main app unit tests (~15 files)
├── AiQoWatch Watch AppTests/            Watch unit tests
├── AiQoWatch Watch AppUITests/          Watch UI tests
├── AiQo.xcodeproj/                      Project graph, SPM refs, build settings
├── Configuration/
│   ├── AiQo.xcconfig                    Base xcconfig w/ optional Secrets include
│   ├── Secrets.xcconfig                 Local secrets (git-ignored)
│   ├── ExternalSymbols/                 Spotify dSYM
│   └── SETUP.md                         Secret/bootstrap instructions
├── aiqo-web/                            Next.js marketing/support site (privacy, terms, support)
├── AiQo_AIContext_*.md                  Founder context pack (seven files)
├── AiQo_Master_Blueprint_*.md           Versioned blueprints (2 → 15)
├── .github/workflows/swift.yml          CI build
└── AiQoWatch-Watch-App-Info.plist       Root watch HealthKit usage strings
```

---

## 4 — Feature Modules (detailed)

> Status legend: `Shipped` / `In Progress` / `Hidden behind flag` / `Planned`
> Tier legend (see §11): `Free` / `Max` (a.k.a. Core) / `Intelligence Pro` / `Trial behaves as Intelligence Pro`

### 4.1 Captain Hamoudi — الكابتن حمّودي
- **Purpose.** Iraqi-accented AI character that is the voice of AiQo — calm, grounded, never hallucinatory about health data. Routes between an on-device local brain and a cloud brain based on intent/screen.
- **Status**: `Shipped` — required tier `Max`, `Intelligence Pro` unlocks premium model + extended memory.
- **Key files**:
  - [`AiQo/Features/Captain/CaptainScreen.swift`](AiQo/Features/Captain/CaptainScreen.swift) — main chat surface
  - [`AiQo/Features/Captain/CaptainPromptBuilder.swift`](AiQo/Features/Captain/CaptainPromptBuilder.swift) — 7-layer prompt (Identity / Stable Profile / Working Memory / Bio-State / Circadian Tone / Screen Context / Output Contract)
  - [`AiQo/Features/Captain/BrainOrchestrator.swift`](AiQo/Features/Captain/BrainOrchestrator.swift) — local vs cloud routing
  - [`AiQo/Features/Captain/CloudBrainService.swift`](AiQo/Features/Captain/CloudBrainService.swift) — Gemini client
  - [`AiQo/Features/Captain/HybridBrainService.swift`](AiQo/Features/Captain/HybridBrainService.swift) — transport
  - [`AiQo/Features/Captain/PrivacySanitizer.swift`](AiQo/Features/Captain/PrivacySanitizer.swift) — email/phone/URL redaction, numeric bucketing, image EXIF strip
  - [`AiQo/Features/Captain/ProactiveEngine.swift`](AiQo/Features/Captain/ProactiveEngine.swift) — schedules Captain-initiated notifications
  - [`AiQo/Features/Captain/CaptainIntelligenceManager.swift`](AiQo/Features/Captain/CaptainIntelligenceManager.swift) — HK trend caching for reasoning
  - [`AiQo/Features/Captain/ConversationThread.swift`](AiQo/Features/Captain/ConversationThread.swift) — `ConversationThreadEntry` (SwiftData V3), 7-day pruning
- **Architecture**: 7-layer prompt builder → BrainOrchestrator → LocalBrain (Apple Foundation Models) OR CloudBrain (Gemini via sanitizer). Memory retrieval scored with confidence × intent × screen-context × recency.
- **Dependencies**: HealthKit, Apple Foundation Models, Gemini, ElevenLabs, SwiftData (Captain container), AccessManager.
- **Glassmorphism**: `.ultraThinMaterial` bubble renderer; 3D Captain avatar referenced via `Assets.xcassets/Captain_Hamoudi_DJ` and `Hammoudi5.imageset` (3D USDZ / rigged model is listed on roadmap, current implementation uses layered 2D/parallax until V1 avatar ships).
- **Angel Numbers deep linking**: `aiqo://captain` + `ProactiveEngine` schedules notifications at recurring angel-number minutes (e.g., 11:11, 22:22) using `SmartNotificationScheduler`. Taps route via `DeepLinkRouter`.
- **Known TODOs**: older docs still say "six-layer prompt" — live is seven.

### 4.2 Tribe — القبيلة / Emirate / Arena / Galaxy
- **Purpose.** Social layer — ghost-mode visibility, Shield tiers (Wood → Bronze → Silver → Gold → Legendary), weekly tribe challenges, leaderboards, user search, Hall of Fame.
- **Status**: `Hidden behind flag` — `TRIBE_FEATURE_VISIBLE=false`, `TRIBE_BACKEND_ENABLED=false`, `TRIBE_SUBSCRIPTION_GATE_ENABLED=false` in [`AiQo/Info.plist`](AiQo/Info.plist).
- **Key files**:
  - [`AiQo/Features/Tribe/TribeView.swift`](AiQo/Features/Tribe/TribeView.swift)
  - [`AiQo/Features/Tribe/TribeExperienceFlow.swift`](AiQo/Features/Tribe/TribeExperienceFlow.swift) — all 5 live TODOs live here
  - [`AiQo/Tribe/Models/TribeFeatureModels.swift`](AiQo/Tribe/Models/TribeFeatureModels.swift)
  - [`AiQo/Tribe/Galaxy/ArenaModels.swift`](AiQo/Tribe/Galaxy/ArenaModels.swift) — 6 `@Model` types
  - [`AiQo/Services/SupabaseArenaService.swift`](AiQo/Services/SupabaseArenaService.swift)
- **Architecture**: Supabase-backed (`arena_tribes`, `arena_tribe_members`, `arena_weekly_challenges`, `arena_tribe_participations`, `arena_hall_of_fame_entries`). SwiftData mirrors for offline.
- **Ghost Mode**: user toggle `is_profile_public` / `is_private` in `profiles` table — hides user from leaderboards without leaving the tribe.
- **Shield tiers**: cosmetic badges tied to XP + weekly contribution. Rendered in `TribeHeroCard` / `TribeMemberRow`.
- **Known TODOs**: 5 placeholders for `SupabaseTribeRepository` in `TribeExperienceFlow.swift`; hardcoded hero stats `#2` and `12 challenges` in `TribeHeroCard.swift:26-28`; `@@username` double-at risk in `TribeMemberRow.swift:44`, `TribeView.swift:630,710`.

### 4.3 Club / النادي (Gym)
- **Purpose.** Fitness hub — sub-tabs: `Impact` (founder brief: `Trace`), `Battle`, `Peaks`, `Plan`, `Body`.
- **Status**: `Shipped` — `Max` for Body/Plan/Battle; `Intelligence Pro` for full Peaks.
- **Key files**:
  - [`AiQo/Features/Gym/Club/ClubRootView.swift`](AiQo/Features/Gym/Club/ClubRootView.swift)
  - [`AiQo/Features/Gym/Club/Body/BodyView.swift`](AiQo/Features/Gym/Club/Body/BodyView.swift)
  - [`AiQo/Features/Gym/Club/Plan/PlanView.swift`](AiQo/Features/Gym/Club/Plan/PlanView.swift)
  - [`AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift`](AiQo/Features/Gym/Club/Impact/ImpactContainerView.swift)
  - [`AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift`](AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift)
- **Header**: horizontal + vertical segmented control (header locally forced LTR at `ClubRootView.swift:130-131`). Achievement badges animate on XP milestones.
- **Dependencies**: HealthKit workouts, QuestLoot SwiftData container, LevelStore, Captain coaching handoff.

### 4.4 Gym (workouts + Zone 2 + Live session + WatchOS handoff)
- **Purpose.** `GlassBubbleTabBar` navigation, spin-wheel rewards with CoreHaptics, YouTube workout integration (URL embeds), confetti + sound on PR, WatchOS "Now Playing"-style live cards (mint/beige pastel).
- **Status**: `Shipped`.
- **Key files**:
  - [`AiQo/Features/Gym/LiveWorkoutSession.swift`](AiQo/Features/Gym/LiveWorkoutSession.swift) — currently modified in working tree
  - [`AiQo/Features/Gym/WorkoutSessionViewModel.swift`](AiQo/Features/Gym/WorkoutSessionViewModel.swift)
  - [`AiQo/Features/Gym/WorkoutSessionSheetView.swift`](AiQo/Features/Gym/WorkoutSessionSheetView.swift)
  - [`AiQo/Features/Gym/HandsFreeZone2Manager.swift`](AiQo/Features/Gym/HandsFreeZone2Manager.swift)
  - [`AiQo/Features/Gym/AudioCoachManager.swift`](AiQo/Features/Gym/AudioCoachManager.swift)
  - [`AiQo/Features/Gym/WorkoutLiveActivityManager.swift`](AiQo/Features/Gym/WorkoutLiveActivityManager.swift)
  - [`AiQo/PhoneConnectivityManager.swift`](AiQo/PhoneConnectivityManager.swift) — phone side of WatchConnectivity
- **Live Activities**: surface workout state on Dynamic Island / Lock Screen.
- **Known TODOs**: none specific; watch connectivity polling runs on a 2s `Timer` (see §8).

### 4.5 Home — الرئيسية
- **Purpose.** Dashboard — `DailyAuraView` ring, six `HomeStatCard`s, `WaterBottleView` with wave animation, kitchen shortcut, vibe entry.
- **Status**: `Shipped`.
- **Key files**:
  - [`AiQo/Features/Home/HomeView.swift`](AiQo/Features/Home/HomeView.swift)
  - [`AiQo/Features/Home/HomeViewModel.swift`](AiQo/Features/Home/HomeViewModel.swift)
  - [`AiQo/Features/Home/MetricKind.swift`](AiQo/Features/Home/MetricKind.swift) — steps, calories, stand, water, sleep, distance
  - [`AiQo/Features/Home/DJCaptainChatView.swift`](AiQo/Features/Home/DJCaptainChatView.swift) — DJ Hamoudi mini-chat
- **HealthKit cards**: each `HomeStatCard` binds to a HealthKit observer query for live update.

### 4.6 Profile
- **Purpose.** User avatar, body stats, level, weekly report shortcut, Instagram-style stories export.
- **Status**: `Shipped`.
- **Key files**:
  - [`AiQo/Features/Profile/ProfileScreen.swift`](AiQo/Features/Profile/ProfileScreen.swift)
  - [`AiQo/Features/Profile/ProfileScreenLogic.swift`](AiQo/Features/Profile/ProfileScreenLogic.swift) — formatter bug: `@@username` if input already starts with `@` (lines 102-105)

### 4.7 Onboarding
- **Purpose.** Language → Apple Sign In/Guest → Profile → HealthKit → Notifications → Captain personalization → Level reveal → Feature intro → Main.
- **Status**: `Shipped`.
- **Key files**:
  - [`AiQo/App/SceneDelegate.swift`](AiQo/App/SceneDelegate.swift) — flow controller
  - [`AiQo/App/LanguageSelectionView.swift`](AiQo/App/LanguageSelectionView.swift)
  - [`AiQo/App/LoginViewController.swift`](AiQo/App/LoginViewController.swift) — Sign in with Apple + guest path
  - [`AiQo/App/ProfileSetupView.swift`](AiQo/App/ProfileSetupView.swift)
  - [`AiQo/Features/First screen/LegacyCalculationViewController.swift`](AiQo/Features/First%20screen/LegacyCalculationViewController.swift)
  - [`AiQo/Features/Onboarding/CaptainPersonalizationOnboardingView.swift`](AiQo/Features/Onboarding/CaptainPersonalizationOnboardingView.swift)
  - [`AiQo/Features/Onboarding/FeatureIntroView.swift`](AiQo/Features/Onboarding/FeatureIntroView.swift)
- **Known TODOs**: legacy UserDefault keys still use names like `didCompleteDatingProfile` (SceneDelegate.swift:67, AppDelegate.swift:129-135).

### 4.8 Paywall ← **critical, see §11**
- **Purpose.** Convert free / trial users to Max or Intelligence Pro.
- **Status**: `Shipped`.
- **Key files**:
  - [`AiQo/UI/Purchases/PaywallView.swift`](AiQo/UI/Purchases/PaywallView.swift) — canonical SwiftUI paywall
  - [`AiQo/Premium/PremiumPaywallView.swift`](AiQo/Premium/PremiumPaywallView.swift) — thin wrapper (not a legacy duplicate)
  - [`AiQo/Premium/PremiumStore.swift`](AiQo/Premium/PremiumStore.swift) — product loader / purchase UI state
  - [`AiQo/Premium/AccessManager.swift`](AiQo/Premium/AccessManager.swift) — tier gating (see §11.5)
  - [`AiQo/Premium/FreeTrialManager.swift`](AiQo/Premium/FreeTrialManager.swift) — 7-day trial + Keychain persistence
  - [`AiQo/Core/Purchases/PurchaseManager.swift`](AiQo/Core/Purchases/PurchaseManager.swift) — StoreKit 2 transaction pipeline
  - [`AiQo/Core/Purchases/EntitlementStore.swift`](AiQo/Core/Purchases/EntitlementStore.swift) — cross-app entitlement snapshot
  - [`AiQo/Core/Purchases/ReceiptValidator.swift`](AiQo/Core/Purchases/ReceiptValidator.swift) — hits Supabase Edge `validate-receipt`
  - [`AiQo/Core/Purchases/SubscriptionTier.swift`](AiQo/Core/Purchases/SubscriptionTier.swift)
  - [`AiQo/Core/Purchases/SubscriptionProductIDs.swift`](AiQo/Core/Purchases/SubscriptionProductIDs.swift) — **current IDs**: `com.mraad500.aiqo.max`, `com.mraad500.aiqo.intelligence.pro`

### 4.9 Settings
- **Purpose.** Language toggle, notification prefs, Captain memory control, legal links, account deletion.
- **Status**: `Shipped`.
- **Key files**:
  - [`AiQo/Core/AppSettingsScreen.swift`](AiQo/Core/AppSettingsScreen.swift) — account deletion RPC at line 371
  - [`AiQo/Core/AppSettingsStore.swift`](AiQo/Core/AppSettingsStore.swift) — `ar`/`en` enum, defaults to Arabic
  - [`AiQo/Core/CaptainMemorySettingsView.swift`](AiQo/Core/CaptainMemorySettingsView.swift) — forced RTL

### 4.10 Other shipped modules (summary)
- **Sleep**: `Features/Sleep/` — AlarmKit Smart Wake, HealthKit sleep analysis, AppleIntelligenceSleepAgent local path.
- **Kitchen**: `Features/Kitchen/` — camera fridge scanner (Gemini vision via PrivacySanitizer), macros tracker.
- **Legendary Challenges / Peaks**: `Features/LegendaryChallenges/` — RecordProject + WeeklyLog.
- **My Vibe / DJ Hamoudi**: `Features/MyVibe/` — biometric mood state drives Spotify playlist selection.
- **Weekly Report**: `Features/WeeklyReport/` — share sheet, Instagram Stories, PDF, CSV.
- **Progress Photos**: `Features/ProgressPhotos/` — file-based storage, not SwiftData.
- **Compliance / DataExport**: skeleton scaffolding for GDPR export.

---

## 5 — HealthKit Integration

### 5.1 Read types (iPhone, from [`AiQo/App/SceneDelegate.swift:129-142`](AiQo/App/SceneDelegate.swift))
- Step count
- Active energy burned
- Walking/running distance
- Cycling distance
- Heart rate
- HRV (SDNN)
- Resting heart rate
- Walking heart rate average
- Oxygen saturation
- VO₂ max
- Body mass
- Dietary water
- Stand time
- Sleep analysis
- Activity summary
- Workouts

### 5.2 Write types (iPhone, from `SceneDelegate.swift:153-159`)
- Heart rate
- HRV
- Resting heart rate
- VO₂ max
- Walking/running distance
- Dietary water
- Body mass
- Workouts

### 5.3 Permission request flow
1. App launch → SceneDelegate decides root screen.
2. On onboarding completion, [`AppDelegate.swift`](AiQo/App/AppDelegate.swift) calls `HealthKitManager.shared.requestAuthorization` with the explicit read/write sets above.
3. Results drive HomeViewModel, Captain bio-state, and Weekly Report pipelines.
4. Usage strings in [`Info.plist`](AiQo/Info.plist):
   - `NSHealthShareUsageDescription`: _"AiQo reads selected Health data like steps, sleep, and hydration to power your daily and weekly summaries."_
   - `NSHealthUpdateUsageDescription`: _"AiQo writes the Health entries you choose, such as hydration logs and workouts, back to the Health app."_

### 5.4 Background delivery
- Entitled via `com.apple.developer.healthkit.background-delivery` in both [`AiQo/AiQo.entitlements`](AiQo/AiQo.entitlements) and [`AiQoWatch Watch App.entitlements`](AiQoWatch%20Watch%20App/AiQoWatch%20Watch%20App.entitlements).
- Background task IDs: `aiqo.notifications.refresh`, `aiqo.notifications.inactivity-check` (`Info.plist`).
- Background modes: `audio`, `remote-notification`, `fetch`, `processing` (iPhone); `workout-processing` (watch).

### 5.5 WatchOS sync
- `HKHealthStore.startWatchApp(with:)` flow lives in [`AiQoWatch Watch App/Services/WatchWorkoutManager.swift`](AiQoWatch%20Watch%20App/Services/WatchWorkoutManager.swift).
- Two-way sync via `WatchConnectivity` — [`AiQo/PhoneConnectivityManager.swift`](AiQo/PhoneConnectivityManager.swift) and [`AiQoWatch Watch App/WatchConnectivityManager.swift`](AiQoWatch%20Watch%20App/WatchConnectivityManager.swift).

### 5.6 Known limitations
- Watch `WatchConnectivityService` polls every 2s via `Timer` (functional but not ideal — should migrate to delta-sync).
- Some sleep-stage-aware logic is Apple Foundation Models gated; fallback path exists in `BrainOrchestrator.swift:142-174`.

---

## 6 — AI Pipeline

### 6.1 Routing (BrainOrchestrator)
| Screen/intent | Path | Model |
|---|---|---|
| `sleepAnalysis` | **Local** (Apple Foundation Models) | `LanguageModelSession` |
| `gym`, `kitchen`, `peaks`, `myVibe`, `mainChat` | **Cloud** (Gemini via PrivacySanitizer) | see below |

- Sleep-like intent detected from other screens is rerouted to local (`BrainOrchestrator.swift:100-109`).
- Local failure → cloud fallback with aggregated summary (no raw stages) (`BrainOrchestrator.swift:142-174`).
- Cloud failure → local fallback when safe; else deterministic localized error (`BrainOrchestrator.swift:195-207, 345-389`).

### 6.2 Language routing
- **English** → Apple Foundation Models on-device when possible; cloud = Gemini.
- **Arabic** → cloud = Gemini today; founder intent is a **GPT API Arabic fallback** for dialect/quality edge cases (routed through the `CloudBrainService` abstraction so model choice is a single switch).
- Prompt locale locked in [`CaptainPromptBuilder.swift:36-146`](AiQo/Features/Captain/CaptainPromptBuilder.swift):
  - Arabic = Iraqi dialect, no Modern Standard Arabic, English allowed only for certain feature names.
  - English = casual, no forced formality.

### 6.3 Cloud model policy ([`CloudBrainService.swift:8-13, 39-69`](AiQo/Features/Captain/CloudBrainService.swift))
| Tier | Model |
|---|---|
| Free / Max | `gemini-2.5-flash` |
| Intelligence Pro (or active trial) | `gemini-3-flash-preview` |

Transport: `https://generativelanguage.googleapis.com/v1beta/models`, 35 s timeout (`HybridBrainService.swift:89-90,238`).

### 6.4 Captain Hamoudi personality rules (canon)
- **Calm, Iraqi, grounded.** Never hype, never "Mr. Motivator" AI.
- **NEVER hallucinate health data.** The Bio-State layer injects real HealthKit values before every reply; the prompt contract forbids fabricating steps/calories/sleep.
- **Never generic AI phrasing.** Explicitly banned in the Identity layer.
- **Honest about limits.** If HealthKit is unavailable, Captain says so.
- Canonical personality reference: [`AiQo_AIContext_03_CaptainHamoudi.md`](AiQo_AIContext_03_CaptainHamoudi.md) and the 7-layer prompt.

### 6.5 ElevenLabs TTS ([`CaptainVoiceAPI.swift:8-9, 22-28, 118`](AiQo/Core/CaptainVoiceAPI.swift))
- Base URL: `https://api.elevenlabs.io/v1/text-to-speech`
- Model: `eleven_multilingual_v2`
- Timeouts: request 8 s, resource 10 s
- Voice IDs: configured via xcconfig; standard Iraqi voice for Max, premium cloned voice for Intelligence Pro (see §11.2).
- **Fallback**: [`CaptainVoiceService.swift:203-235`](AiQo/Core/CaptainVoiceService.swift) races remote speech against a 10 s timeout and falls back to `AVSpeechSynthesizer` on timeout/error.

### 6.6 PrivacySanitizer ([`PrivacySanitizer.swift`](AiQo/Features/Captain/PrivacySanitizer.swift))
- Redacts: emails, phone numbers, UUIDs, IP addresses, URLs, `@mentions`, base64-like tokens, long numeric sequences.
- Normalizes names to `User`.
- Only last 4 messages sent as cloud conversation context.
- Numeric bucketing: steps in groups of 50, calories in groups of 10.
- Image sanitization for Kitchen: EXIF/GPS stripped by re-encode, max dimension 1280 px, JPEG 0.78.

### 6.7 Push-up / form analysis pipeline
- Rep counting (Max): `AiQo/Features/Gym/Quests/VisionCoach/` — uses Vision framework on-device, no frames leave the device.
- **Form feedback (Intelligence Pro)**: same VisionCoach pipeline with additional landmark analytics surfaced as coaching cues; roadmap includes richer multi-angle form scoring.

---

## 7 — Supabase Backend

### 7.1 Tables visible in Swift ([`SupabaseService.swift`](AiQo/Services/SupabaseService.swift), [`SupabaseArenaService.swift`](AiQo/Services/SupabaseArenaService.swift))
| Table | Columns referenced in code |
|---|---|
| `profiles` | `user_id`, `display_name`, `username`, `public_id` (implicit), `level`, `total_points`, `tribe_points`, `is_profile_public` / `is_private`, `device_token`, legacy search fields (`name`, `age`, `height_cm`, `weight_kg`, `goal_text`) |
| `arena_tribes` | `id`, `name`, `owner_id`, `invite_code`, `created_at`, `is_active`, `is_frozen`, `frozen_at` |
| `arena_tribe_members` | `id`, `tribe_id`, `user_id`, `role`, `contribution_points`, `joined_at` |
| `arena_weekly_challenges` | `id`, `title`, `description_text`, `metric`, `start_date`, `end_date` |
| `arena_tribe_participations` | `id`, `tribe_id`, `challenge_id`, `score`, `rank`, `joined_at` |
| `arena_hall_of_fame_entries` | `id`, `tribe_name`, `challenge_title`, `achieved_at` |

### 7.2 Edge Functions
- `validate-receipt` — server-side StoreKit 2 receipt validation, called from [`ReceiptValidator.swift:31-43`](AiQo/Core/Purchases/ReceiptValidator.swift).

### 7.3 RPC actions
- `delete_user_account` — called from [`AppSettingsScreen.swift:371`](AiQo/Core/AppSettingsScreen.swift) on account deletion.

### 7.4 Auth flow
1. Apple Sign In → ID token + nonce ([`LoginViewController.swift:131-138`](AiQo/App/LoginViewController.swift))
2. `supabase.auth.signInWithIdToken(...)` exchange (`LoginViewController.swift:175-181`)
3. User metadata update (`LoginViewController.swift:183-197`)
4. User ID bound to CrashReporter ([`AppDelegate.swift:101-103`](AiQo/App/AppDelegate.swift))
- Guest path: `continueWithoutAccount()` (`LoginViewController.swift:154-158`).

### 7.5 RLS policies
**TBD — not checked into repo.** Policies live in Supabase dashboard. Any RLS rule referenced in code must be added here before launch.

### 7.6 Storage buckets
**TBD — not checked into repo.**

### 7.7 Secrets
Loaded via `Configuration/AiQo.xcconfig` + `Configuration/Secrets.xcconfig` (git-ignored since commit `108a8f1 2026-04-09`). Keys consumed: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`, `ELEVENLABS_API_KEY`, `SPOTIFY_CLIENT_ID`.

---

## 8 — WatchOS Companion

### 8.1 Target structure
- Bundle: `com.mraad500.aiqo.watchkitapp`
- Deployment target: watchOS `26.2`
- Entry: [`AiQoWatch Watch App/AiQoWatchApp.swift`](AiQoWatch%20Watch%20App/AiQoWatchApp.swift) uses `@WKApplicationDelegateAdaptor`.
- `25` Swift files / `~4,665` lines (from Blueprint 15 sweep; current count similar).

### 8.2 Services
- [`Services/WatchHealthKitManager.swift`](AiQoWatch%20Watch%20App/Services/WatchHealthKitManager.swift) — HealthKit access on watch.
- [`Services/WatchWorkoutManager.swift`](AiQoWatch%20Watch%20App/Services/WatchWorkoutManager.swift) — `HKWorkoutSession`, `HKLiveWorkoutBuilder`.
- [`Services/WatchConnectivityService.swift`](AiQoWatch%20Watch%20App/Services/WatchConnectivityService.swift) — 2 s `Timer`-based poll loop (known debt).
- [`WatchConnectivityManager.swift`](AiQoWatch%20Watch%20App/WatchConnectivityManager.swift) — phone↔watch message routing.

### 8.3 UI
- [`Views/`](AiQoWatch%20Watch%20App/Views) — Home, active workout card, summary card.
- Card UI uses alternating mint (`#B7E5D2` area) and beige (`#EBCF97` area) pastels per founder brief.
- Watch widgets: [`AiQoWatchWidget/`](AiQoWatchWidget) — complication-style surfaces.

### 8.4 Data handoff
- Start workout on phone → `HKWorkoutSession` started via `PhoneConnectivityManager`, mirrored on watch.
- End of session → summary flows back for Captain debrief.

### 8.5 Usage strings
Root `AiQoWatch-Watch-App-Info.plist` includes Arabic HealthKit strings explicitly (watch app defaults to Arabic at launch).

---

## 9 — Design System

### 9.1 Canonical palette (founder brief → Blueprint 15)
| Token | Hex | Notes |
|---|---|---|
| Primary mint | `#B7E5D2` | Hero backgrounds, tribe shields |
| Deep mint / CTA | `#5ECDB7` | Primary button / CTA |
| Sand / gold accent | `#EBCF97` | Paywall gold gradients, watch beige cards |
| Yellow primary (legacy) | `#FFE68C` | Older accent (see `Core/Colors.swift`) |
| Ink / text primary | `#0F1721` (light) / `#F6F8FB` (dark) |
| Sub-text | `#5F6F80` (light) / `#A3AFBC` (dark) |
| Surface | `#FFFFFF` / `#121922` |

Evidence: [`AiQo/DesignSystem/AiQoTheme.swift`](AiQo/DesignSystem/AiQoTheme.swift), [`AiQo/DesignSystem/AiQoColors.swift`](AiQo/DesignSystem/AiQoColors.swift), [`AiQo/UI/Purchases/PaywallView.swift:82-225`](AiQo/UI/Purchases/PaywallView.swift).

**Palette drift**: legacy `Core/Colors.swift` still uses older `#C4F0DB` mint / `#F8D6A3` sand. New screens (Paywall, Tribe hero) use canonical values.

### 9.2 Glassmorphism materials
- Primary surface material: `.ultraThinMaterial` (SwiftUI).
- Rule (founder brief): **no drop shadows** — enforced in new components; drift exists in legacy paywall/hero screens that still use soft shadows.
- Gold gradient spec used on Intelligence Pro CTA: linear `#EBCF97 → #C9AE72`.

### 9.3 Typography scale
- Latin: `SF Pro Rounded` via `.font(.system(..., design: .rounded))`.
- Arabic: system Arabic rendering (no custom Noto font file bundled).
- Scale roughly: `.largeTitle (34)`, `.title (28)`, `.title2 (22)`, `.headline (17 bold)`, `.body (17)`, `.footnote (13)`, `.caption (12)`.

### 9.4 Reusable components
- **`GlassCard`** — `.ultraThinMaterial` + rounded corners + subtle stroke; used across Home, Captain, Tribe.
- **`GlassBubbleTabBar`** — Gym tab bar with liquid-glass animation.
- **`HomeStatCard`** — `HKQuery`-bound tile with numeric display + trend sparkline.
- **`WaterBottleView`** — animated SwiftUI shape with `TimelineView`-driven wave.
- **Shield badges** — Wood / Bronze / Silver / Gold / Legendary variants; cosmetic Pro-exclusive versions planned.
- **`DailyAuraView`** — Home hero ring.

### 9.5 Haptic patterns
Centralized in `CoreHaptics` helpers:
- **Spin-wheel tick** — short `.sharpness=1, intensity=0.7` pulse per tick.
- **PR unlock** — 3-pulse crescendo + `UIImpactFeedbackGenerator(.heavy)`.
- **Captain voice start** — 1-pulse `.intensity=0.3`.
- **Quest complete** — AHAP pattern with fade-out.

### 9.6 RTL rules
- Global shell forced RTL ([`MainTabScreen.swift:66`](AiQo/App/MainTabScreen.swift)).
- Club header forced LTR for segmented control usability ([`ClubRootView.swift:130-131`](AiQo/Features/Gym/Club/ClubRootView.swift)).
- Auth screens switch dynamically based on app language ([`LoginViewController.swift:111-116`](AiQo/App/LoginViewController.swift)).

---

## 10 — Localization

### 10.1 Supported languages
- Arabic (`ar`) — **default** ([`AppSettingsStore.swift:16-27`](AiQo/Core/AppSettingsStore.swift))
- English (`en`)

### 10.2 Coverage (from Blueprint 15 live count)
| Catalog | Arabic | English |
|---|---|---|
| `Localizable.strings` | `2183 / 2185` = **99.91%** | `2184 / 2185` = **99.95%** |
| `Prompts.xcstrings` | `2 / 2` = 100% | `2 / 2` = 100% |

Missing keys:
- Arabic: `meal.eggVeggies`, `meal.eggVeggies.calories`
- English: `screen.kitchen.calorie`

### 10.3 RTL handling
See §9.6. RTL is enforced globally except intentional LTR islands (Club segmented header).

### 10.4 Pending strings
- Fill the three gaps above before App Store submission.
- English Terms of Service copy in `en.lproj/Localizable.strings:50` still references `$5.99 individual / $10 family / no auto-renew` — must be rewritten to match the live two-tier StoreKit catalog.

---

## 11 — 💰 Subscription Tiers (CRITICAL)

> **Two-tier model.** `AiQo Max` ($9.99/mo) for the complete fitness + lifestyle ecosystem. `AiQo Intelligent Pro` ($19.99/mo) for the premium intelligence layer — Captain as a true AI life coach. 7-day free trial on both; while a trial is active, `AccessManager.activeTier` behaves as `Intelligence Pro`.

### 11.1 AiQo Max — $9.99 / month
The **core tier**. Unlocks the full fitness + lifestyle ecosystem:
- Full Captain Hamoudi chat (unlimited messages)
- Complete HealthKit dashboard + all stat cards
- Gym module with spin wheel, YouTube workouts, WatchOS companion
- Tribe social features (Ghost Mode, Shield tiers, leaderboards) _(when the feature flag ships on)_
- Club achievements + badges
- Angel Numbers push notifications
- Standard Apple Foundation Models AI (on-device, English) + Gemini (cloud) for Arabic + English cloud routes
- Standard ElevenLabs TTS voice for Captain (standard Iraqi)

**Target user**: Everyday user who wants the complete self-improvement app.

### 11.2 AiQo Intelligent Pro — $19.99 / month
Everything in Max, **PLUS the premium intelligence layer**:
- **Advanced AI reasoning** — deeper, longer Captain conversations with full memory (500 entries vs 200).
- **Priority Arabic GPT routing** (higher-tier model, faster responses).
- **Premium ElevenLabs voice** (higher-quality cloned Iraqi voice).
- **Personal AI coach mode** — Captain proactively analyzes HealthKit trends weekly and sends insights (`ProactiveEngine` already wired; Pro unlocks the richer cadence).
- **Advanced workout programming** — AI-generated multi-week plans adapting to performance.
- **Priority feature access** — new features ship to Pro 2–4 weeks before Max.
- **Expanded push-up & form analysis** — camera-based form feedback, not just counting.
- **Unlimited spin wheel rerolls + bonus rewards.**
- **Pro-only Shield tier cosmetics.**
- **Peaks** full access (view-only on Max).
- **Legendary Challenges** full start/project access (view-only on Max).

**Target user**: Power users, athletes, and founders who treat AiQo as their daily operating system for health + discipline.

### 11.3 Strategic Difference (Positioning)

| Dimension | AiQo Max ($9.99) | AiQo Intelligent Pro ($19.99) |
|---|---|---|
| **Philosophy** | "Complete fitness ecosystem" | "Your AI life coach" |
| **Captain depth** | Standard chat | Deep memory, proactive insights |
| **AI Model Access** | Standard (Gemini 2.5 Flash) | Premium routing + priority (Gemini 3 Flash Preview + GPT Arabic priority) |
| **Voice** | Standard Iraqi | Premium cloned voice |
| **Workout Plans** | Curated | AI-generated adaptive |
| **Form Analysis** | Rep counting | Camera form feedback |
| **Feature Access** | Standard release | 2–4 weeks early |
| **Cosmetics** | All shield tiers | Pro-exclusive variants |
| **Memory limit** | 200 entries | 500 entries |
| **Peaks** | — | Full |
| **Price / month** | $9.99 | $19.99 |
| **Price / year (suggest 2-month discount)** | $99.99 | $199.99 |

**Positioning logic.** Max is the full ethical fitness app — nobody should feel they're missing essentials at $9.99. Pro is a premium intelligence upgrade for users who want the Captain as a true AI coach with memory, proactivity, and premium compute. This mirrors how Apple positions iCloud+ tiers or how ChatGPT positions Plus vs Pro — the lower tier must feel complete, the upper tier must feel exceptional.

### 11.4 StoreKit 2 Product IDs

**Current catalog (live source of truth).** Evidence: [`AiQo/Resources/AiQo.storekit`](AiQo/Resources/AiQo.storekit) + [`AiQo/Core/Purchases/SubscriptionProductIDs.swift`](AiQo/Core/Purchases/SubscriptionProductIDs.swift).

| Tier | Product ID | Display name | Live price | Trial |
|---|---|---|---|---|
| AiQo Max | `com.mraad500.aiqo.max` | `AiQo Max` | `$9.99/mo` | 1 week free (P1W) |
| AiQo Intelligent Pro | `com.mraad500.aiqo.intelligence.pro` | `AiQo Intelligence Pro` | `$19.99/mo` | 1 week free (P1W) |

**Legacy / grandfathered IDs** (kept only to decode older entitlements — not in current catalog):
- `com.mraad500.aiqo.pro.monthly` — retired middle tier
- `com.mraad500.aiqo.standard.monthly` — prior Max SKU
- `com.mraad500.aiqo.intelligencepro.monthly` — prior Pro SKU
- `aiqo_core_monthly_9_99`, `aiqo_pro_monthly_19_99`, `aiqo_intelligence_monthly_39_99` — oldest SKUs

**Annual**: `TODO` — not yet configured (founder roadmap item, see §16).

### 11.5 Entitlement Gating

All tier checks flow through a single singleton. Canonical file: [`AiQo/Premium/AccessManager.swift`](AiQo/Premium/AccessManager.swift).

Core accessor: `AccessManager.shared.activeTier` which reads `EntitlementStore.shared.currentTier`; if no subscription and a trial is active, returns `.intelligencePro`.

| Feature | Gate in code | File:line |
|---|---|---|
| Captain chat | `canAccessCaptain` (`activeTier >= .core`) | `AccessManager.swift:36` |
| Gym | `canAccessGym` | `AccessManager.swift:37` |
| Kitchen | `canAccessKitchen` | `AccessManager.swift:38` |
| My Vibe | `canAccessMyVibe` | `AccessManager.swift:39` |
| Challenges (browse) | `canAccessChallenges` | `AccessManager.swift:40` |
| Data tracking (HK premium surfaces) | `canAccessDataTracking` | `AccessManager.swift:41` |
| HRR assessment | `canAccessHRRAssessment` | `AccessManager.swift:46` |
| Weekly AI workout plan | `canAccessWeeklyAIWorkoutPlan` | `AccessManager.swift:47` |
| Record Projects | `canAccessRecordProjects` | `AccessManager.swift:48` |
| Legendary Challenges (browse vs start) | `legendaryChallengeAccess` (`.viewOnly` on Max, `.full` on Pro) | `AccessManager.swift:58-63` |
| Peaks | `canAccessPeaks` (`activeTier >= .intelligencePro`) | `AccessManager.swift:67` |
| Extended memory (500 vs 200) | `canAccessExtendedMemory` + `captainMemoryLimit` | `AccessManager.swift:68, 73-80` |
| Premium reasoning model (Gemini 3 Flash Preview) | `canAccessIntelligenceModel` | `AccessManager.swift:69` |
| Tribe creation | `canCreateTribe` (Pro) / `canAccessTribe` (any tier + flag) | `AccessManager.swift:84-90` |
| Product-ID → Pro features | `SubscriptionProductIDs.unlocksIntelligenceProFeatures` | `SubscriptionProductIDs.swift:47-60` |

**Free trial.** [`FreeTrialManager.swift`](AiQo/Premium/FreeTrialManager.swift) persists the trial start date in Keychain (`service=com.aiqo.trial`, `account=trialStartDate`) so it survives reinstall. 7 days. During trial, all Pro gates unlock.

**Receipt validation.** [`ReceiptValidator.swift:31-43`](AiQo/Core/Purchases/ReceiptValidator.swift) posts to Supabase Edge `validate-receipt`. StoreKit 2 `Transaction.updates` stream drives `EntitlementStore`.

---

## 12 — Pre-Launch Checklist

| Item | Status |
|---|---|
| Arabic localization coverage ≥ 99.9% | 🟡 (3 keys missing — see §10.4) |
| English localization coverage ≥ 99.9% | 🟡 (1 key missing) |
| HealthKit sync (water, sleep, workouts) | ✅ |
| WatchOS companion ships with phone | ✅ |
| StoreKit 2 paywall live (two-tier) | ✅ |
| Free trial wired + Keychain persisted | ✅ |
| Fallback price matches live StoreKit | ✅ ($19.99 fallback matches live) |
| English Terms of Service updated to match live pricing | ❌ (TODO — `en.lproj/Localizable.strings:50`) |
| Privacy Policy URL | ✅ (served via `aiqo-web/app/privacy`) |
| Terms of Service URL | ✅ (served via `aiqo-web/app/terms`) — copy needs resync |
| Support URL | ✅ (`aiqo-web/app/support`) |
| `PrivacyInfo.xcprivacy` present + complete | ✅ |
| Secrets removed from repo | ✅ (since `108a8f1`) |
| Crash testing iPhone SE → iPhone 17 Pro Max | 🟡 (manual; no automated matrix) |
| App Store screenshots (EN + AR) | ❌ (operational task, not in repo) |
| App Store description (EN + AR) | ❌ |
| Reviewer notes covering HealthKit + local-vs-cloud AI | ❌ |
| Tribe flags confirmed false before TestFlight | ✅ |
| Firebase Crashlytics SDK linked | 🟡 (wrapper exists, SDK not linked) |
| Supabase RLS policies hardened | ❓ (not in repo — verify in dashboard) |

---

## 13 — Known Issues & Technical Debt

### 13.1 Live Swift TODO/FIXME/HACK sweep (2026-04-16)
Grep: `grep -rn "TODO\|FIXME\|HACK" --include=*.swift` → **5 matches, all in Tribe.**
- `AiQo/Features/Tribe/TribeExperienceFlow.swift:190` — replace placeholder with `SupabaseTribeRepository`
- `AiQo/Features/Tribe/TribeExperienceFlow.swift:205` — same
- `AiQo/Features/Tribe/TribeExperienceFlow.swift:299` — same
- `AiQo/Features/Tribe/TribeExperienceFlow.swift:348` — same
- `AiQo/Features/Tribe/TribeExperienceFlow.swift:369` — same

### 13.2 Monetization / Legal drift
- **English Terms copy stale**: `AiQo/Resources/en.lproj/Localizable.strings:50` still lists `$5.99 individual / $10 family / no auto-renew`. Must be rewritten before App Store Review.

### 13.3 Tribe / social
- All flags in [`AiQo/Info.plist`](AiQo/Info.plist) currently false (`TRIBE_FEATURE_VISIBLE`, `TRIBE_BACKEND_ENABLED`, `TRIBE_SUBSCRIPTION_GATE_ENABLED`).
- **Placeholder hero stats**: `#2` rank, `12` challenges hardcoded in [`AiQo/Tribe/Galaxy/TribeHeroCard.swift:26-28`](AiQo/Tribe/Galaxy/TribeHeroCard.swift).
- **`@@username` risk**: [`AiQo/Features/Profile/ProfileScreenLogic.swift:102-105`](AiQo/Features/Profile/ProfileScreenLogic.swift), [`AiQo/Tribe/Galaxy/TribeMemberRow.swift:44`](AiQo/Tribe/Galaxy/TribeMemberRow.swift), [`AiQo/Features/Tribe/TribeView.swift:630,710`](AiQo/Features/Tribe/TribeView.swift).
- **Member default drift**: non-current Tribe members fall back to `points=0`, `level=1` in [`AiQo/Tribe/Galaxy/TribeMembersList.swift:28-29`](AiQo/Tribe/Galaxy/TribeMembersList.swift).

### 13.4 Notifications / AI transport hardcoding
- Quiet hours hardcoded `23:00–07:00` in [`AiQo/Core/SmartNotificationScheduler.swift:12-13,855-856`](AiQo/Core/SmartNotificationScheduler.swift).
- Notification language key is `notificationLanguage` (not `captainLanguage`) — `SmartNotificationScheduler.swift:52`.
- Gemini endpoint + 35 s timeout hardcoded in [`HybridBrainService.swift:89-90`](AiQo/Features/Captain/HybridBrainService.swift).
- ElevenLabs fallback timeout hardcoded 10 s in [`CaptainVoiceService.swift:203`](AiQo/Core/CaptainVoiceService.swift).

### 13.5 Analytics / crash fragmentation
- Local `AnalyticsService` + local `CrashReporter` (JSONL) + optional Firebase wrapper (SDK not linked) + scattered `print`. Pre-launch this is acceptable; unify post-launch.

### 13.6 Naming drift
- Gym sub-tab named `Impact` in code vs founder brief `Trace`.
- Older docs still say "six-layer prompt"; live is seven.
- Legacy UserDefault key `didCompleteDatingProfile` reflects old flow name.
- Old `Core` tier naming in `SubscriptionTier.swift` — canonical user-facing name is now `AiQo Max` (display strings already use "AiQo Max" — see `SubscriptionProductIDs.displayName`).

### 13.7 Live Swift counts
- `462` Swift files / `~114,800` lines (sweep on 2026-04-16).

---

## 14 — Coding Conventions

### 14.1 Naming
- Swift API Design Guidelines: `lowerCamelCase` properties, `UpperCamelCase` types, avoid abbreviations.
- Prefix cross-cutting types with a module/domain noun (`Captain*`, `Arena*`, `Home*`).
- Async: prefer `async/await` and `Task` over Combine in new code; Combine kept for existing stores (`AccessManager`).

### 14.2 File organization per feature
```
Features/<FeatureName>/
    <FeatureName>View.swift          SwiftUI entry point
    <FeatureName>ViewModel.swift     @Observable or ObservableObject
    <FeatureName>Logic.swift         Pure functions, formatters, helpers
    Components/                      Small subviews
    Models/                          Feature-local models (SwiftData @Model lives in Core/Models or Features/<F>/Models)
```

### 14.3 View / ViewModel / Model split
- View: SwiftUI, stateless where possible, binds to ViewModel via `@StateObject` / `@Observable`.
- ViewModel: owns async work and state; pulls from shared singletons (`HealthKitManager.shared`, `AccessManager.shared`).
- Model: `@Model` for persisted, `struct` for transient.

### 14.4 Glassmorphism reuse rules
- Use `GlassCard` or `.background(.ultraThinMaterial)` — never a manual blurred view.
- No drop shadows on new components. Depth is expressed through material opacity + strokes.
- Gold gradient only on paid/aspirational CTAs (Intelligence Pro, Peaks).

### 14.5 Captain personality constants
- 7-layer prompt: [`AiQo/Features/Captain/CaptainPromptBuilder.swift`](AiQo/Features/Captain/CaptainPromptBuilder.swift) is the **only** place personality strings live. Do not inline Captain text elsewhere.
- Localized prompt snippets: [`AiQo/Resources/Prompts.xcstrings`](AiQo/Resources/Prompts.xcstrings).

### 14.6 Access gates
- All feature access checks route through `AccessManager.shared.*` — do not read `EntitlementStore` directly from Views.

---

## 15 — Claude Code Workflow Guidelines

1. **Default model**: Sonnet 4.6 for implementation. **Escalate to Opus 4.6** for architecture decisions, schema migrations, multi-file refactors, and AI-prompt redesign.
2. **Read this blueprint first** in every new session (`Read AiQo_Master_Blueprint_16.md`). It replaces 2,000+ lines of re-scanning.
3. **Use `/clear` between unrelated modules** to preserve context window.
4. **Use `/compact` when context exceeds ~60%**.
5. **Task-segment sessions** — one module per session (Captain, Gym, Paywall, etc.). Cross-cutting refactors get their own session.
6. **Always verify** (before editing) that `AccessManager`, `CaptainPromptBuilder`, or StoreKit files haven't been changed since this blueprint was written.
7. **Never add emojis or comments** unless the diff is self-evident without them.
8. **Never break RTL** — any new screen must render correctly in Arabic before merging.
9. **Never hallucinate HealthKit values** in Captain output. Use `BioStateBuilder` / `CaptainContextBuilder`.
10. **Respect the no-shadow rule** on new design-system components.
11. **Respect the Tribe flags** — do not expose Tribe UI unless `TRIBE_FEATURE_VISIBLE=true`.

---

## 16 — Roadmap

### 16.1 Immediate (next 2 weeks — through end of April 2026)
- Fill three missing localization keys (§10.4).
- Rewrite English ToS copy to match live StoreKit (§13.2).
- Close the 5 Tribe TODOs OR keep Tribe hidden through launch.
- Crash-test across iPhone SE (2nd/3rd gen) → iPhone 17 Pro Max.
- Generate App Store screenshots EN + AR.
- Finalize reviewer notes explaining HealthKit + local-vs-cloud AI data flow.

### 16.2 Pre-launch (next 2 months — May 2026 AUE launch)
- TestFlight external build.
- Instagram 12-post campaign (`@aiqoapp`).
- AUE campus launch activation.
- Link Firebase Crashlytics SDK.
- Tribe backend end-to-end validation (behind flag).

### 16.3 Post-launch 2026 (H2)
- Annual subscription tier (two-month discount: Max $99.99/yr, Pro $199.99/yr).
- Remote analytics (Mixpanel / PostHog / Amplitude — pick one).
- Ship Tribe publicly (flag flip after backend hardened).
- Fish Speech S1-mini on RunPod Serverless — ElevenLabs replacement.
- 3D Captain Avatar V1 (USDZ-driven, idle + listen + speak poses).
- GCC expansion (KSA, Kuwait, Qatar).

### 16.4 2027
- **MR-OS phone prototype** — Mohammed's long-form hardware R&D. AiQo runs as the native OS, not an app.
- Captain Avatar V2 with lip-sync.
- Avatar builder / appearance customization.

### 16.5 2028
- **MR-OS phone commercial launch.**

### 16.6 2030+
- **Noor City** — physical/community destination anchoring the AiQo ecosystem.

---

## 17 — Philosophy & Non-Negotiables

1. **Tech that protects humans.** Never sacrifice user wellbeing for flash, engagement farming, or growth hacks. No ads. No selling data. No dark patterns.
2. **Captain stays Iraqi.** Calm, grounded, dialect-native. Never Modern Standard Arabic when speaking as Captain. Never Western pep-talk tone.
3. **NEVER hallucinate health data.** If HealthKit is unavailable, Captain says so. Every health claim must be traceable to a real HK value through `CaptainContextBuilder`.
4. **Prayer + exercise + healthy eating** is the foundation. AiQo is a behavioral/ethical system first, a fitness app second.
5. **Arabic-first, RTL-native.** Never treat Arabic as a "translation" — it is the default. English is the secondary locale.
6. **On-device by default.** Cloud only when sanitized and necessary. Privacy is not optional.
7. **Solo-founder discipline.** Every new dependency, every new singleton, every new abstraction must earn its place. Three similar lines beat a premature framework.

---

## 18 — Change Log

| Version | Date | Summary |
|---|---|---|
| **v16** | **2026-04-16** | Full codebase audit; subscription tiers fully documented as **AiQo Max ($9.99)** and **AiQo Intelligent Pro ($19.99)** with product IDs `com.mraad500.aiqo.max` and `com.mraad500.aiqo.intelligence.pro`; entitlement gating table sourced from `AccessManager`; file tree refreshed; 18-section structure per current blueprint spec; roadmap extended through MR-OS (2028) and Noor City (2030+). |
| v15 | 2026-04-11 | Evidence-policy overhaul, 2,108 lines, full decision log, drift reporting. |
| v14 | ~2026-04 | Previous baseline — used as source for v15's founder-intent layer. |
| v13 | ~2026-03 | Pre-localization-overhaul blueprint. |
| v12 | ~2026-03 | Monetization-focused pass. |
| v11 | ~2026-02 | Captain V2 / BrainOrchestrator landing. |
| v10 | ~2026-02 | HealthKit + sleep expansion. |
| v9 | ~2026-01 | Early Captain personality pass. |
| v5–v4–v3–v2 | 2025–2026 | Early blueprints documenting onboarding, brand, and initial feature set. |
| Blueprint_Complete | — | Consolidated early reference before versioning. |

---

*End of AiQo Master Blueprint 16. Generated 2026-04-16 in `Asia/Dubai`. Next blueprint should be written after the AUE launch (May 2026) to document v1.0→v1.x drift.*
