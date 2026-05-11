# Captain Hamoudi Brain — Recon Report
**Date:** 2026-04-18
**Scope:** Brain Core, Memory, Notifications

## 1. Executive Summary
- The live Captain runtime is not one brain stack; it is a layered mix of `CaptainViewModel`, `BrainOrchestrator`, `CloudBrainService`, `LocalBrainService`, `HybridBrainService`, `CaptainContextBuilder`, `CaptainCognitivePipeline`, and the older `CaptainIntelligenceManager` path, all active in the repo today (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:12-15`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:89-974`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:11-57`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:73-356`).
- The main chat path is fairly clean: UI send tap -> `CaptainViewModel.sendMessage` -> `CaptainCognitivePipeline` + `CaptainContextBuilder` -> `BrainOrchestrator` -> local or cloud inference -> reply validation -> SwiftData persistence -> background memory extraction (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainChatView.swift:126-129`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:209-279`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:401-535`).
- The cloud path is privacy-hardened: `CloudBrainService` fetches cloud-safe memories, runs `PrivacySanitizer.sanitizeForCloud`, and only then calls Gemini through `HybridBrainService` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:40-75`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PrivacySanitizer.swift:96-123`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift:185-333`).
- The notification side still has legacy unsanitized AI paths: inactivity copy and workout-summary copy call `CaptainIntelligenceManager.generateCaptainResponse`, which can include raw HealthKit-derived metrics in prompts and route Arabic requests to the separate Arabic API path without going through `PrivacySanitizer` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:489-509`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:619-645`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:171-189`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:274-313`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:438-462`).
- Memory is broader than “facts.” The dedicated Captain SwiftData store contains `CaptainMemory`, `PersistentChatMessage`, `CaptainPersonalizationProfile`, `WeeklyMetricsBuffer`, `WeeklyReportEntry`, `ConversationThreadEntry`, plus other Captain-adjacent models (`RecordProject`, `WeeklyLog`) in the same schema container (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:16-35`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV1.swift:7-19`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV2.swift:6-20`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV3.swift:6-21`).
- `AccessManager` defines the intended premium gates for Captain, notifications, and extended memory, but repo-wide references in this audit found those gates only at their definitions. The tab, chat send path, and notification schedulers do not currently consume them (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:36-42`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:68-80`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/MainTabScreen.swift:51-64`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:209-279`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:105-118`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:188-221`).
- Proactive notifications are fragmented across five senders: `SmartNotificationScheduler`, `CaptainSmartNotificationService`, `MorningHabitOrchestrator`, `SleepSessionObserver`, and `AIWorkoutSummaryService`. They share no single pending-count guard and only partially share cooldown/budget logic (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:105-946`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:156-537`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:56-347`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:37-183`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:556-1005`).
- `ProactiveEngine` is real but only partially fed. `SmartNotificationScheduler.buildProactiveContext()` hardcodes `stepGoal = 10_000`, `calorieGoal = 500`, `waterIntakePercent = 0.5`, `isCurrentlyWorkingOut = false`, `lastWorkoutEndedAt = nil`, and `trendSnapshot = nil`, so several triggers are structurally unreachable or distorted (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:918-945`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift:136-249`).
- Blueprint drift is material: the live prompt builder has 8 emitted sections, not 7; angel-number scheduling is not implemented; memory scoring is richer than the blueprint says; and Captain is mounted in the UI without an active tier gate despite blueprint text saying Max is required (`/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:196-211`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainPromptBuilder.swift:14-32`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:548-585`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/MainTabScreen.swift:51-64`).
- A pure file move is technically feasible because Swift symbol resolution is module-based, not folder-based, but the current code is tightly coupled through singleton ownership, Xcode project references, notification identifiers, and the dedicated Captain SwiftData container bootstrapped from `AiQoApp` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:12-64`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/SceneDelegate.swift:271-296`).

## 2. Brain Core
### 2.1 Inventory
Discovery notes:
- `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/Brain/` does not exist in the current tree.
- The live app entry is `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift`, not a standalone `/Users/mohammedraad/Desktop/AiQo/AiQo/AiQoApp.swift`.
- `Prompts.xcstrings` exists, but its current prompt keys are Zone 2 keys only: `zone2-coach-v1.0` and `zone2-coach-v2.0` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Resources/Prompts.xcstrings:4`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Resources/Prompts.xcstrings:21`).

Main runtime/control files:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift` | 974 | Main | App-facing chat state owner and orchestration entrypoint; owns send, prompt prep, persistence, memory extraction dispatch (`CaptainViewModel.swift:209-279`, `CaptainViewModel.swift:401-535`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift` | 653 | Main | Local/cloud routing, sleep rerouting, fallback policy, reply personalization (`BrainOrchestrator.swift:37-56`, `BrainOrchestrator.swift:88-210`, `BrainOrchestrator.swift:425-455`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift` | 77 | Main | Cloud-safe memory fetch, sanitizer wrapper, tier-based Gemini model selection (`CloudBrainService.swift:40-75`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift` | 453 | Main | Gemini transport, prompt emission, JSON parsing, request assembly (`HybridBrainService.swift:153-333`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LocalBrainService.swift` | 835 | Main | Local structured-response generator used by orchestrator and notification composer (`LocalBrainService.swift:62-835`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift` | 402 | Main | HealthKit/system-context builder; Brain V2 emotional/trend enrichment; recent interaction stitching (`CaptainContextBuilder.swift:171-258`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift` | 480 | Main | Stable profile summary, intent summary, working-memory retrieval, active project injection (`CaptainCognitivePipeline.swift:283-414`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainPromptBuilder.swift` | 537 | Main | Cloud system prompt builder; live output is 8 sections (`CaptainPromptBuilder.swift:14-32`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PromptRouter.swift` | 137 | Helper | Local system prompt builder for on-device branch (`PromptRouter.swift:15-58`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PrivacySanitizer.swift` | 452 | Main | Cloud redaction, health bucketing, kitchen-image EXIF strip, user-name reinjection (`PrivacySanitizer.swift:96-198`, `PrivacySanitizer.swift:202-300`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift` | 916 | Main/Legacy | Older route-aware inference manager still used heavily by notifications and kitchen (`CaptainIntelligenceManager.swift:155-356`, `CaptainIntelligenceManager.swift:438-514`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift` | 324 | Main | Brain V2 proactive decision engine for notification selection (`ProactiveEngine.swift:94-252`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LLMJSONParser.swift` | 425 | Helper | Structured-response parser/fallback used by Gemini path (`HybridBrainService.swift:155-156`, `HybridBrainService.swift:297-306`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainFallbackPolicy.swift` | 212 | Helper | Human-readable fallback copy for network and generic failure cases (`BrainOrchestrator.swift:346-384`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainPersonaBuilder.swift` | 81 | Helper | Persona cleanup and canonical banned-phrase rules (`HybridBrainService.swift:198`, `BrainOrchestrator.swift:232-239`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/EmotionalStateEngine.swift` | 230 | Helper | Computes emotional posture and recommended tone from activity/sleep metadata (`CaptainContextBuilder.swift:238-251`, `SmartNotificationScheduler.swift:837-851`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/SentimentDetector.swift` | 128 | Helper | Brain V2 sentiment inference for latest user text (`CaptainViewModel.swift:425-429`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/TrendAnalyzer.swift` | 219 | Helper | Weekly trend snapshot computation, currently used in chat context but not populated into proactive context (`CaptainContextBuilder.swift:262-307`, `SmartNotificationScheduler.swift:921-923`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ScreenContext.swift` | 52 | Model | Routing and prompt-focus enum (`BrainOrchestrator.swift:89-96`, `PromptRouter.swift:15-58`). |

Captain-adjacent helper and crossover files:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainModels.swift` | 487 | Model | Contains `PersistentChatMessage`, `ChatSession`, structured response, workout/meal/Spotify payloads. `PersistentChatMessage` is part of the Captain SwiftData store (`CaptainModels.swift:7-84`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift` | 209 | Crossover model/helper | Interaction timeline model and manager. Physically in Captain, but functionally bridges brain, memory, and notifications (`ConversationThread.swift:26-209`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift` | 80 | Crossover helper | Notification-open handoff into Captain UI and thread logging (`CaptainNotificationRouting.swift:18-48`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/AiQoPromptManager.swift` | 132 | Helper | Prompt registry for Zone 2 on-device coaching; not part of main Captain chat path (`AiQoPromptManager.swift:39-78`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CoachBrainMiddleware.swift` | 775 | Legacy/helper | Translation-heavy middleware. Its translator is reused by `SmartNotificationScheduler`, but the middleware class itself was not surfaced as an active Captain chat dependency in this audit (`CoachBrainMiddleware.swift:10-127`, `SmartNotificationScheduler.swift:45-46`, `SmartNotificationScheduler.swift:76`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CoachBrainTranslationConfig.swift` | 91 | Helper | Translation endpoint resolver used by `CoachBrainLLMTranslator` (`CoachBrainTranslationConfig.swift:23-90`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift` | 236 | Helper | Actor wrapper for on-device generation experiments (`CaptainOnDeviceChatEngine.swift:29-236`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LocalIntelligenceService.swift` | 160 | Legacy/helper | Older on-device service wrapper; candidate dead code because repo-wide reference scan did not surface callers outside its own file. |

UI surfaces in the Captain folder:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainChatView.swift` | 656 | UI | Chat screen, composer, quick replies, and morning sleep analysis trigger (`CaptainChatView.swift:126-145`, `CaptainChatView.swift:642-647`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainScreen.swift` | 1265 | UI | Main tab surface, avatar shell, customization sheet, chat container, processing-state visuals (`CaptainScreen.swift:196-1265`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ChatHistoryView.swift` | 158 | UI | Session browser backed by `MemoryStore.fetchSessions()` (`ChatHistoryView.swift:54`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainAvatar3DView.swift` | 79 | UI | 3D avatar view candidate; no runtime references surfaced in the repo-wide scan. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/MessageBubble.swift` | 108 | UI | Generic bubble wrapper. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/VibeMiniBubble.swift` | 54 | UI | Mini vibe capsule. |

Supporting context files that materially wire the brain:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift` | 465 | Support | Owns global `CaptainViewModel`, Captain SwiftData container, startup wiring, notification delegate, background task registration (`AppDelegate.swift:12-64`, `AppDelegate.swift:106-151`, `AppDelegate.swift:171-216`, `AppDelegate.swift:270-309`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/App/MainTabScreen.swift` | 129 | Support | Mounts `CaptainScreen()` unconditionally in the main tab bar (`MainTabScreen.swift:51-64`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/App/SceneDelegate.swift` | 335 | Support | Propagates `scenePhase` into `CaptainViewModel.handleScenePhaseTransition` (`SceneDelegate.swift:271-296`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift` | 243 | Support | Defines intended Captain, notification, and memory tier gates (`AccessManager.swift:36-42`, `AccessManager.swift:68-80`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Resources/Prompts.xcstrings` | 39 | Support | Only contains Zone 2 prompt keys, not general Captain prompt keys (`Prompts.xcstrings:4`, `Prompts.xcstrings:21`). |

### 2.2 Public API
Ownership and top-level API surface:

| Type or file group | Kind | Ownership | Key surface | Notes |
|---|---|---|---|---|
| `CaptainViewModel` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:89-974` | `ObservableObject` | Single app-wide `@StateObject` in `AiQoApp` (`AppDelegate.swift:12-15`) and injected through `.environmentObject(globalBrain)` (`AppDelegate.swift:67-76`) | `sendMessage` (`CaptainViewModel.swift:209-279`), `processMessage` (`CaptainViewModel.swift:401-535`), `handleScenePhaseTransition` (`CaptainViewModel.swift:352-355`), session/history helpers (`CaptainViewModel.swift:363-609`) | This is the live entrypoint most UI callers use. |
| `BrainOrchestrator` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:11-57` | `struct` service | Instantiated by `CaptainViewModel` default init (`CaptainViewModel.swift:137-147`) | `processMessage` (`BrainOrchestrator.swift:37-56`), `startStreamingReply` (`BrainOrchestrator.swift:59-76`) | Encapsulates route choice and fallback chain. |
| `CloudBrainService` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:11-77` | `struct` service | Held by `BrainOrchestrator` (`BrainOrchestrator.swift:18-32`) | `generateReply` (`CloudBrainService.swift:40-75`) | Single public method. |
| `HybridBrainService` plus `HybridBrainRequest`, `HybridBrainServiceReply`, `CaptainConversationMessage`, `CaptainConversationRole`, `HybridBrainStreamingSession`, `HybridBrainServiceError` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift:6-453` | transport + DTOs | `CloudBrainService` owns a default instance (`CloudBrainService.swift:17-31`) | `generateReply` (`HybridBrainService.swift:185-205`), `startStreamingReply` (`HybridBrainService.swift:207-223`) | This is the actual Gemini transport layer. |
| `LocalBrainService` plus `LocalBrainRequest`, `LocalBrainServiceReply`, `LocalConversationMessage`, `LocalConversationRole`, `LocalBrainServiceError` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LocalBrainService.swift:8-835` | local inference + DTOs | Owned by `BrainOrchestrator` and `CaptainBackgroundNotificationComposer` (`BrainOrchestrator.swift:18-32`, `CaptainBackgroundNotificationComposer.swift:9-15`) | `generateReply` (file body), fallback plan builders, local JSON shaping | Primary on-device path in the live orchestrator. |
| `CaptainContextBuilder`, `CaptainContextData`, `CaptainSystemContextSnapshot`, `BioTimePhase` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:6-402` | context service + DTOs | Singleton `shared` (`CaptainContextBuilder.swift:140-169`), used by `CaptainViewModel` (`CaptainViewModel.swift:137-147`) | `buildSystemContext` (`CaptainContextBuilder.swift:171-203`), `buildContextData` (`CaptainContextBuilder.swift:205-258`) | Pulls HealthKit, level, vibe, personalization, emotion, trends, recent interactions. |
| `CaptainCognitivePipeline`, `CaptainPromptContext`, `CaptainMessageIntent`, `CaptainEmotionalSignal`, `CaptainCognitiveTextAnalyzer` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift:3-480` | prompt-context service | Singleton `shared` by default (`CaptainViewModel.swift:137-147`) | `buildPromptContext` (`CaptainCognitivePipeline.swift:283-307`) plus private stable-profile, intent, and working-memory builders (`CaptainCognitivePipeline.swift:311-425`) | This is where memory retrieval is activated for replies. |
| `CaptainPromptBuilder` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainPromptBuilder.swift:12-537` | prompt builder | Owned by `HybridBrainService` (`HybridBrainService.swift:155-180`) | `build(for:)` (`CaptainPromptBuilder.swift:14-32`) | Comment still says 7-layer; live build emits 8 sections. |
| `PromptRouter` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PromptRouter.swift:3-137` | local prompt builder | Created inside `BrainOrchestrator.generateLocalReply` (`BrainOrchestrator.swift:215-230`) | `generateSystemPrompt` (`PromptRouter.swift:15-58`) | Only used by local branch. |
| `PrivacySanitizer` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PrivacySanitizer.swift:15-452` | privacy service | Held by `BrainOrchestrator`, `CloudBrainService`, `SmartNotificationManager`, and other helpers (`BrainOrchestrator.swift:20-32`, `CloudBrainService.swift:18-30`, `SmartNotificationManager.swift:6`) | `sanitizeForCloud` (`PrivacySanitizer.swift:96-123`), `sanitizeText` (`PrivacySanitizer.swift:127-164`), `injectUserName` (`PrivacySanitizer.swift:168-198`), `sanitizeKitchenImageData` (`PrivacySanitizer.swift:202-235`) | Central privacy boundary, but not all outbound AI paths use it. |
| `CaptainIntelligenceManager`, `CaptainDailyHealthMetrics`, `CaptainIntelligenceError`, `CaptainResponseRoute` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:9-916` | legacy/main service | Singleton `shared` (`CaptainIntelligenceManager.swift:73-97`), used by `CaptainContextBuilder`, `SmartNotificationScheduler`, `NotificationService`, kitchen flows | `requestHealthPermissions` (`CaptainIntelligenceManager.swift:101-116`), `fetchTodayEssentialMetrics` (`CaptainIntelligenceManager.swift:118-152`), `generateCaptainResponse` overloads (`CaptainIntelligenceManager.swift:155-203`) | This is now a parallel “brain” path beside `BrainOrchestrator`. |
| `ProactiveEngine`, `ProactiveContext`, `ProactiveDecision`, `NotificationBudget`, `ProactivePriority` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift:12-324` | decision engine | Singleton `shared` (`ProactiveEngine.swift:90-92`), used by `SmartNotificationScheduler` (`SmartNotificationScheduler.swift:495`, `SmartNotificationScheduler.swift:605`) | `evaluate(context:)` (`ProactiveEngine.swift:94-252`) | Brain V2 proactive brain. |
| `EmotionalStateEngine` and `EmotionalState` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/EmotionalStateEngine.swift:27-230` | helper | Singleton used by `CaptainContextBuilder` and `SmartNotificationScheduler` (`CaptainContextBuilder.swift:238-251`, `SmartNotificationScheduler.swift:837-851`) | `evaluate(...)` | Used both in chat and proactive notifications. |
| `SentimentDetector` and `SentimentResult` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/SentimentDetector.swift:12-128` | helper | Singleton used by `CaptainViewModel` (`CaptainViewModel.swift:425-429`) | `detect(message:)` | Only active behind Brain V2 path. |
| `TrendAnalyzer`, `TrendSnapshot`, `DailyHealthPoint`, `TrendDirection`, `StreakMomentum` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/TrendAnalyzer.swift:12-219` | helper | Singleton used by `CaptainContextBuilder` (`CaptainContextBuilder.swift:276-307`) | `compute(...)` | Computed for chat context; not yet injected into proactive context. |
| `CaptainNotificationHandler` and `CaptainNavigationHelper` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:6-80` | notification bridge | Singleton-like shared instances (`CaptainNotificationRouting.swift:6-16`, `CaptainNotificationRouting.swift:66-74`) | `handleIncomingNotification` (`CaptainNotificationRouting.swift:18-43`), `clearPendingMessage` (`CaptainNotificationRouting.swift:45-49`), `hasPendingMessage` (`CaptainNotificationRouting.swift:51-63`) | Bridges notification taps into Captain UI state. |
| `CaptainModels.swift` types in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainModels.swift:7-487` | models | Value types passed through brain and UI | `PersistentChatMessage` persisted chat model; `CaptainStructuredResponse` Gemini/local response schema; `WorkoutPlan`, `MealPlan`, `SpotifyRecommendation`, `ChatSession` | Core DTO file. |
| `CaptainFallbackPolicy` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainFallbackPolicy.swift:7-212` | helper | Static policy enum | Fallback string factories | Used by `BrainOrchestrator` and `CaptainViewModel` fallbacks. |
| `CaptainPersonaBuilder` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainPersonaBuilder.swift:5-81` | helper | Static helper | `buildInstructions`, `sanitizeResponse`, banned phrases | Canonical persona cleanup. |
| `LLMJSONParser` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LLMJSONParser.swift:11-425` | helper | Owned by `HybridBrainService` (`HybridBrainService.swift:155-180`) | `decode(rawText:fallback:)` | Normalizes Gemini JSON-ish output. |
| `AiQoPromptManager` and internal prompt config types in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/AiQoPromptManager.swift:8-132` | helper | Singleton `shared` (`AiQoPromptManager.swift:8-37`) | `getZone2CoachPrompt` (`AiQoPromptManager.swift:39-50`), `fetchRemotePrompts` (`AiQoPromptManager.swift:52-78`) | Not on main Captain chat path. |
| `CoachBrainLLMTranslator`, `CoachBrainMiddleware`, config/error/phase types in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CoachBrainMiddleware.swift:10-775` and `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CoachBrainTranslationConfig.swift:4-91` | helper/legacy | Scheduler uses the translator implementation, not the middleware class (`SmartNotificationScheduler.swift:45-46`, `SmartNotificationScheduler.swift:76`) | Translation pipeline methods, middleware state transitions | This is a live dependency for translation but not for main reply generation. |
| `CaptainOnDeviceChatEngine` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:29-236` | actor | Instantiable helper | On-device generation session helpers | Not surfaced in the main Captain path during this audit. |
| `LocalIntelligenceService` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LocalIntelligenceService.swift:22-160` | helper/legacy | Struct with no caller surfaced by repo-wide scan | Local structured response generation | Candidate dead code. |
| UI-only types across `CaptainChatView.swift`, `CaptainScreen.swift`, `ChatHistoryView.swift`, `CaptainAvatar3DView.swift`, `MessageBubble.swift`, and `VibeMiniBubble.swift` | `View` structs | SwiftUI-created, usually with `@EnvironmentObject` CaptainViewModel or local state | `body`, closures that call `globalBrain.sendMessage`, UI helpers | They do not own persistence or routing decisions; they delegate into `CaptainViewModel`. |

Who owns live instances:
- `CaptainViewModel` is the principal live owner, created once in `AiQoApp` and injected into the app root (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:12-15`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:67-76`).
- `BrainOrchestrator`, `CaptainContextBuilder`, and `CaptainCognitivePipeline` default to per-view-model construction or singleton sharing inside `CaptainViewModel.init` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:137-149`).
- `MemoryStore`, `CaptainPersonalizationStore`, `WeeklyMetricsBufferStore`, `WeeklyMemoryConsolidator`, and `ConversationThreadManager` are bootstrapped with the dedicated Captain `ModelContainer` in `AiQoApp.init` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:54-64`).
- `AccessManager`, `FreeTrialManager`, `EntitlementStore`, `NotificationService`, `SmartNotificationScheduler`, and `CaptainNotificationHandler` are all singleton-style shared owners used across systems (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:5-6`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/FreeTrialManager.swift:8-9`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Purchases/EntitlementStore.swift:5-6`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:6-7`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:7-8`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:6-16`).

### 2.3 Dependency Graph
Primary code-level dependency edges:
- `CaptainChatView` -> `CaptainViewModel.sendMessage` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainChatView.swift:126-129`).
- `CaptainViewModel` -> `ConversationThreadManager`, `CaptainCognitivePipeline`, `CaptainContextBuilder`, `BrainOrchestrator`, `MemoryStore`, `MemoryExtractor` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:258-277`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:421-519`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:606-608`).
- `CaptainCognitivePipeline` -> `MemoryStore`, `RecordProjectManager`, `CaptainPersonalizationStore` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift:316-342`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift:364-406`).
- `CaptainContextBuilder` -> `CaptainIntelligenceManager`, `LevelStore`, `VibeAudioEngine`, `SpotifyVibeManager`, `CaptainPersonalizationStore`, `EmotionalStateEngine`, `TrendAnalyzer`, `ConversationThreadManager`, `WeeklyMetricsBufferStore` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:151-169`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:171-258`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:262-329`).
- `BrainOrchestrator` -> `LocalBrainService`, `CloudBrainService`, `PromptRouter`, `PrivacySanitizer`, `CaptainPersonaBuilder`, `CaptainFallbackPolicy`, `AppleIntelligenceSleepAgent` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:18-32`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:215-240`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:346-455`).
- `CloudBrainService` -> `AccessManager`, `MemoryStore`, `PrivacySanitizer`, `HybridBrainService` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:17-31`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:48-75`).
- `HybridBrainService` -> `CaptainPromptBuilder`, `LLMJSONParser`, Gemini config (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift:153-180`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift:243-333`).
- `SmartNotificationScheduler` depends back into brain-core types: `CaptainIntelligenceManager`, `CaptainBackgroundNotificationComposer`, `CoachBrainLLMTranslator`, `ProactiveEngine`, `EmotionalStateEngine`, `CaptainPersonalizationStore`, `ConversationThreadManager` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:43-76`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:488-946`).

ASCII graph of the main reply path:

```text
CaptainChatView / KitchenView / PlanView
            |
            v
     CaptainViewModel
      |      |      |
      |      |      +--> MemoryStore.persistMessageAsync
      |      +---------> CaptainCognitivePipeline
      |                    |--> MemoryStore.retrieveRelevantMemories
      |                    |--> CaptainPersonalizationStore
      |                    +--> RecordProjectManager
      |
      +----------> CaptainContextBuilder
      |             |--> CaptainIntelligenceManager.fetchTodayEssentialMetrics
      |             |--> EmotionalStateEngine
      |             |--> TrendAnalyzer
      |             +--> ConversationThreadManager.buildPromptSummary
      |
      +----------> BrainOrchestrator
                    |--> PromptRouter -> LocalBrainService
                    |
                    +--> CloudBrainService
                           |--> AccessManager.activeTier
                           |--> MemoryStore.buildCloudSafeRelevantContext
                           |--> PrivacySanitizer.sanitizeForCloud
                           +--> HybridBrainService
                                   |--> CaptainPromptBuilder
                                   +--> LLMJSONParser
```

Suspicious or high-coupling edges:
- The notification system reaches straight into brain internals instead of talking through one facade. `SmartNotificationScheduler` uses brain heuristics, personalization, emotion, trend-adjacent context, and thread history itself (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:488-946`).
- `CaptainIntelligenceManager` is effectively a second brain transport stack beside `BrainOrchestrator`. Kitchen and notification code can bypass the newer sanitized chat path (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:27-73`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:489-509`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:619-645`).
- No compile-time circular import exists because everything is inside one app module, but there is a behavioral loop: notification send/open events write into `ConversationThreadManager`; that thread data then influences future proactive-budget decisions and prompt context (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:265-267`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:28-31`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:903-916`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:254`).

### 2.4 Data Flow
Single user-message trace, from tap to persistence:

1. The chat UI composes a message and invokes the send closure from `ChatComposerBar`, which calls `globalBrain.sendMessage(text, context: .mainChat)` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainChatView.swift:126-129`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainChatView.swift:642-647`).
2. `CaptainViewModel.sendMessage` normalizes the active context, trims text, blocks concurrent sends, and requires AI cloud consent for every non-sleep context (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:214-221`).
3. On first real user interaction it persists the welcome message, appends the user message, flips `isLoading`, and persists the user message asynchronously through `MemoryStore.persistMessageAsync` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:231-240`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:606-608`).
4. The background `Task` immediately logs the user message to the 7-day conversation thread (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:251-259`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:85-87`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:173-193`).
5. `CaptainViewModel.buildConversationHistory()` compresses the in-memory message window to the last 20 non-empty turns (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:591-604`).
6. `CaptainCognitivePipeline.buildPromptContext` derives three textual prompt inputs: stable profile, intent summary, and working-memory summary (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:262-267`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift:283-307`).
7. Stable profile summary combines `UserProfileStore` fields, chat customization, and optional Captain personalization snapshot (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift:312-342`).
8. Working-memory summary calls `MemoryStore.retrieveRelevantMemories(limit: 8)` and may append an active record-project block for Peaks/challenge contexts (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift:359-420`).
9. `CaptainViewModel.processMessage` asks `CaptainContextBuilder` for health/system context and, when Brain V2 is enabled, adds sentiment for the latest user message (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:421-429`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:205-258`).
10. `CaptainContextBuilder.buildContextData` internally calls `buildSystemContext`, which fetches today’s essential metrics via `CaptainIntelligenceManager.fetchTodayEssentialMetrics()` and folds in Level, My Vibe, day part, tone hint, optional personalization times, emotional state, trend snapshot, and recent interaction summary (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:171-203`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:227-255`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:318-329`).
11. `CaptainViewModel` packages those pieces into a `HybridBrainRequest` and hands it to `BrainOrchestrator.processMessage` under a timeout that is extended for sleep-like requests (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:431-457`).
12. `BrainOrchestrator` first reroutes non-sleep messages that look like strict sleep requests into `.sleepAnalysis` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:41-42`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:100-117`).
13. Route choice is simple: `.sleepAnalysis` is local; all other screen contexts are cloud (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:88-96`).
14. For a local route, `BrainOrchestrator.generateLocalReply` builds a `LocalBrainRequest`, produces a local system prompt through `PromptRouter.generateSystemPrompt`, and then delegates to `LocalBrainService.generateReply` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:215-240`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PromptRouter.swift:15-58`).
15. For a cloud route, `CloudBrainService.generateReply` re-checks cloud consent, reads `AccessManager.shared.activeTier`, builds cloud-safe relevant memories, sanitizes the request through `PrivacySanitizer`, selects the Gemini model, and calls `HybridBrainService.generateReply` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:44-75`).
16. `PrivacySanitizer.sanitizeForCloud` truncates conversation to the last four messages, redacts PII, clears `userProfileSummary`, sanitizes `intentSummary`, buckets `steps` and `calories`, normalizes vibe to `General`, and strips kitchen-image EXIF by re-encoding if needed (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PrivacySanitizer.swift:96-123`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PrivacySanitizer.swift:264-300`).
17. `HybridBrainService.makeRequestBody` embeds the `CaptainPromptBuilder` output as `systemInstruction`, converts conversation turns into Gemini `contents`, and chooses `maxOutputTokens` by screen context before posting to Gemini (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift:243-333`).
18. `LLMJSONParser` decodes the model output into a `CaptainStructuredResponse`; `HybridBrainService` sanitizes final message phrasing through `CaptainPersonaBuilder.sanitizeResponse` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift:191-205`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift:297-306`).
19. `BrainOrchestrator.personalizeReply` optionally reinjects the user name with `PrivacySanitizer.injectUserName` for non-sleep contexts (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:425-455`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PrivacySanitizer.swift:168-198`).
20. Back in `CaptainViewModel.processMessage`, the reply is cleaned, validated, appended to `messages`, persisted through `MemoryStore.persistMessageAsync`, and logged to the conversation thread (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:470-504`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:606-608`).
21. Finally, `MemoryExtractor.extract` runs detached in the background. It always performs rule-based extraction and every third message also performs LLM extraction on sanitized text (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:509-519`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:17-37`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:184-287`).

Brain-core route summary:

```text
UI tap
 -> CaptainViewModel.sendMessage
 -> ConversationThreadManager.logUserMessage
 -> CaptainCognitivePipeline.buildPromptContext
 -> CaptainContextBuilder.buildContextData
 -> BrainOrchestrator.processMessage
    -> route(local) -> PromptRouter -> LocalBrainService
    -> route(cloud) -> CloudBrainService
       -> MemoryStore.buildCloudSafeRelevantContext
       -> PrivacySanitizer.sanitizeForCloud
       -> HybridBrainService
          -> CaptainPromptBuilder
          -> Gemini
          -> LLMJSONParser
 -> BrainOrchestrator.personalizeReply
 -> CaptainViewModel.validateResponse
 -> MemoryStore.persistMessageAsync
 -> ConversationThreadManager.logCaptainResponse
 -> MemoryExtractor.extract
```

### 2.5 State & Persistence
SwiftData and disk state touched by brain-core flow:

| Store location | What brain-core reads or writes | Refs |
|---|---|---|
| Captain SwiftData container at `Application Support/captain_memory.store` | Dedicated Captain store bootstrapped in `AiQoApp`; used by `MemoryStore`, `CaptainPersonalizationStore`, `WeeklyMetricsBufferStore`, `WeeklyMemoryConsolidator`, `ConversationThreadManager` | `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:16-35`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:54-64` |
| `PersistentChatMessage` model in Captain container | Every persisted user/assistant chat turn | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainModels.swift:7-74`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:391-539` |
| `ConversationThreadEntry` model in Captain container | User messages, Captain replies, notification events used for prompt context and notification budgets | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:26-209`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV3.swift:9-18` |

UserDefaults used directly by brain-core code:

| Key | Purpose | Writer/reader refs |
|---|---|---|
| `captain_user_name` | Captain customization name | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:128-135`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:281-307` |
| `captain_user_age` | Captain customization age | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:128-135`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:281-307` |
| `captain_user_height` | Captain customization height | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:128-135`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:281-307` |
| `captain_user_weight` | Captain customization weight | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:128-135`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:281-307` |
| `captain_calling` | Captain nickname/calling name | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:128-135`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:281-307`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/SmartNotificationManager.swift:61-76` |
| `captain_tone` | Preferred tone enum raw value | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:128-135`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:281-307` |
| `aiqo.captain.pendingMessage` | Pending notification-open handoff into Captain chat | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:12-16`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:28-48` |
| `aiqo.promptManager.cachedRemoteConfiguration` | Cached remote prompt manifest for Zone 2 prompt manager | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/AiQoPromptManager.swift:20-23`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/AiQoPromptManager.swift:90-113` |
| `CAPTAIN_BRAIN_V2_ENABLED` in `Info.plist` | Brain V2 feature gate for emotional/trend/proactive logic | `/Users/mohammedraad/Desktop/AiQo/AiQo/Info.plist:75-76`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:143-144`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift:95-98` |

In-memory brain state:

| Owner | In-memory state | Refs |
|---|---|---|
| `CaptainViewModel` | `messages`, `isLoading`, `coachState`, `currentSessionID`, `responseTask`, `activeRequestID`, plan outputs, quick replies, customization sheet state | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:89-149` |
| `CaptainContextBuilder` | Static cached trend snapshot and timestamp | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:146-149`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:262-313` |
| `BrainOrchestrator` | No persistent state beyond held services and logger | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:11-33` |
| `AiQoPromptManager` | Actor-held remote prompt configuration cache | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/AiQoPromptManager.swift:122-132` |

Keychain usage relevant to brain-core:
- None in the main reply pipeline itself.
- Indirect premium/trial state can affect cloud model choice and memory limits through `AccessManager.activeTier`, which reads `EntitlementStore` and `FreeTrialManager`; the latter persists trial start date in Keychain under service `com.aiqo.trial` and account `trialStartDate` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:27-31`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/FreeTrialManager.swift:98-115`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/FreeTrialManager.swift:148-179`).

### 2.6 Background & Lifecycle
Brain-related lifecycle hooks:
- `AiQoApp.init` creates the dedicated Captain container and wires all Captain stores before the first screen render (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:54-64`).
- `AiQoApp.schedulePostLaunchWarmup()` removes stale memories and optionally runs `HealthKitMemoryBridge.syncHealthDataToMemory()` after first frame (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:296-309`).
- `AppRootView` forwards every `scenePhase` change to `CaptainViewModel.handleScenePhaseTransition`; the view model only reacts on background by removing read ephemeral messages (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/SceneDelegate.swift:271-296`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:352-355`).
- `CaptainChatView.onAppear` calls `globalBrain.generateMorningSleepAnalysis()` when the Captain chat screen appears (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainChatView.swift:142-145`).
- `AppDelegate.applicationDidBecomeActive` can immediately evaluate inactivity notifications, which may send the user back into Captain flows through `CaptainNotificationHandler` on next tap (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:171-201`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:18-43`).

Brain-related background work:
- There is no dedicated BG task just for chat inference.
- The brain is nonetheless touched from notification BG tasks because `SmartNotificationScheduler` builds proactive context using brain types and `CaptainIntelligenceManager` in background refresh/processing handlers (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:444-485`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:488-647`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:829-946`).

## 3. Memory System
### 3.1 Inventory
Discovery notes:
- `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Memory/` does not exist in the current tree.
- The memory system is spread across `/Core`, `/Core/Schema`, `/Services/Memory`, `/Features/Captain/ConversationThread.swift`, and the persisted chat model inside `/Features/Captain/CaptainModels.swift`.

Core memory files:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainMemory.swift` | 62 | Main model | Defines `CaptainMemory` and `CaptainMemorySnapshot` (`CaptainMemory.swift:5-62`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift` | 690 | Main service | CRUD, retrieval scoring, chat persistence, stale-memory pruning, cloud-safe memory context (`MemoryStore.swift:8-690`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift` | 341 | Main helper | Rule-based and periodic LLM fact extraction (`MemoryExtractor.swift:17-319`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/HealthKitMemoryBridge.swift` | 190 | Main helper | Syncs HealthKit body/sleep/activity metrics into `MemoryStore` and weekly buffer (`HealthKitMemoryBridge.swift:13-83`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainPersonalization.swift` | 405 | Main model/store | Captain personalization model, snapshot codec, reminder-time mappers, SwiftData+UserDefaults store (`CaptainPersonalization.swift:177-405`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift` | 209 | Main crossover model/store | Unified 7-day interaction timeline for user messages, Captain replies, and notification events (`ConversationThread.swift:26-209`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainModels.swift` | 487 | Main crossover model | Holds `PersistentChatMessage`, the persisted chat transcript model used by `MemoryStore` (`CaptainModels.swift:7-84`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainMemorySettingsView.swift` | 321 | UI/admin | Memory settings UI, toggle, and destructive clear-all action (`CaptainMemorySettingsView.swift:49-58`, `CaptainMemorySettingsView.swift:97-111`). |

Schema and migration files:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV1.swift` | 19 | Schema | V1 models: `CaptainMemory`, `CaptainPersonalizationProfile`, `PersistentChatMessage`, `RecordProject`, `WeeklyLog` (`CaptainSchemaV1.swift:7-18`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV2.swift` | 20 | Schema | Adds `WeeklyMetricsBuffer` and `WeeklyReportEntry` (`CaptainSchemaV2.swift:6-18`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV3.swift` | 21 | Schema | Adds `ConversationThreadEntry` (`CaptainSchemaV3.swift:6-18`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaMigrationPlan.swift` | 24 | Schema | Lightweight migrations V1->V2 and V2->V3 (`CaptainSchemaMigrationPlan.swift:4-23`). |

Weekly memory and adjacent persistence files:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMetricsBufferStore.swift` | 56 | Helper store | Daily rolling buffer persisted in Captain container (`WeeklyMetricsBufferStore.swift:17-55`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift` | 96 | Helper store | Consolidates buffered metrics into weekly reports every 7 days from last report or trial start (`WeeklyMemoryConsolidator.swift:17-79`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/WeeklyMetricsBuffer.swift` | 42 | Model | Captain-container metric buffer model. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/WeeklyReportEntry.swift` | 61 | Model | Captain-container weekly summary model. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/NeuralMemory.swift` | 60 | Adjacent model | Defines `AiQoDailyRecord` and `WorkoutTask` for the main app model container, not the Captain container. Included here because it matched the read scope, but it is not part of the dedicated Captain memory stack (`NeuralMemory.swift:5-60`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:77-86`). |

Supporting/premium files memory depends on:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift` | 243 | Support | Supplies `captainMemoryLimit` (`AccessManager.swift:73-80`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/FreeTrialManager.swift` | 181 | Support | Weekly consolidation anchor falls back to public trial start date (`FreeTrialManager.swift:85-88`, `WeeklyMemoryConsolidator.swift:23-26`). |

### 3.2 Public API
Primary types and ownership:

| Type or file group | Kind | Ownership | Key surface | Notes |
|---|---|---|---|---|
| `CaptainMemory` and `CaptainMemorySnapshot` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainMemory.swift:5-62` | `@Model` + value snapshot | Persisted in Captain SwiftData container | Stored fields: `key`, `value`, `category`, `source`, `confidence`, timestamps, `accessCount` | Core durable fact store. |
| `MemoryStore` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:8-690` | `@MainActor @Observable` singleton | `shared`, configured from `AiQoApp.init` (`AppDelegate.swift:56`) | `configure` (`MemoryStore.swift:35-40`), `set` (`MemoryStore.swift:45-83`), `get`, `getByCategory`, `allMemories` (`MemoryStore.swift:86-130`), `retrieveRelevantMemories` (`MemoryStore.swift:133-192`), cloud-safe context builders (`MemoryStore.swift:194-304`), `removeStale` (`MemoryStore.swift:307-329`), `clearAll` (`MemoryStore.swift:354-371`), chat persistence APIs (`MemoryStore.swift:391-539`) | Central memory service. |
| `MemoryExtractor` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:5-341` | `struct` helper | Called detached by `CaptainViewModel` (`CaptainViewModel.swift:512-519`) | `extract` (`MemoryExtractor.swift:17-37`) | Runs rules every message and LLM extraction every 3 messages. |
| `HealthKitMemoryBridge` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/HealthKitMemoryBridge.swift:6-190` | `struct` helper | Called during post-launch warmup (`AppDelegate.swift:305-306`) | `syncHealthDataToMemory` (`HealthKitMemoryBridge.swift:13-83`) | Writes health-derived facts and weekly buffers. |
| `CaptainPersonalizationProfile`, `CaptainPersonalizationSnapshot`, goal/sport/workout-time enums, reminder helpers, and `CaptainPersonalizationStore` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainPersonalization.swift:4-405` | models + singleton store | `CaptainPersonalizationStore.shared` configured in `AiQoApp.init` (`AppDelegate.swift:57`) | `currentSnapshot` (`CaptainPersonalization.swift:324-328`), `save` (`CaptainPersonalization.swift:330-360`), `workoutReminderTime` (`CaptainPersonalization.swift:362-364`), `sleepReminderTime` (`CaptainPersonalization.swift:366-375`) | Personalization lives in the same Captain store but is distinct from `CaptainMemory`. |
| `ConversationThreadEntry`, `ThreadEntryType`, and `ConversationThreadManager` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:13-209` | `@Model` + singleton manager | `ConversationThreadManager.shared`, configured in `AiQoApp.init` (`AppDelegate.swift:61-62`) | Logging methods (`ConversationThread.swift:65-107`), `recentEntries` (`ConversationThread.swift:111-118`), `recentNotifications` (`ConversationThread.swift:120-137`), `buildPromptSummary` (`ConversationThread.swift:139-153`), `pruneOldEntries` (`ConversationThread.swift:157-169`) | This is both memory and notification history. |
| `PersistentChatMessage` and `ChatSession` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainModels.swift:7-84` | `@Model` + DTO | Managed through `MemoryStore` (`MemoryStore.swift:391-539`) | Session transcript persistence and session-list summaries | Chat history is part of the Captain store. |
| `WeeklyMetricsBufferStore` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMetricsBufferStore.swift:5-56` | singleton store | Configured in `AiQoApp.init` (`AppDelegate.swift:59`) | `upsertToday`, `allBuffered`, `clearAll` (`WeeklyMetricsBufferStore.swift:17-55`) | Feeds weekly consolidation. |
| `WeeklyMemoryConsolidator` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift:5-96` | singleton service | Configured in `AiQoApp.init` (`AppDelegate.swift:60`) | `shouldConsolidateNow` (`WeeklyMemoryConsolidator.swift:17-20`), `consolidateIfDue` (`WeeklyMemoryConsolidator.swift:28-79`), report accessors (`WeeklyMemoryConsolidator.swift:81-88`) | Generates weekly reports from buffer. |
| Captain schema enums and migration plan in `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/*.swift` | versioned schema types | Used only by `AiQoApp` container creation (`AppDelegate.swift:18-35`) | `CaptainSchemaV1`, `V2`, `V3`, `CaptainSchemaMigrationPlan` | V3 is current production schema in the Captain store. |
| `CaptainMemorySettingsView` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainMemorySettingsView.swift:4-321` | `View` | SwiftUI view | `onAppear` loads memories and reports (`CaptainMemorySettingsView.swift:49-52`), toggle uses `MemoryStore.shared.isEnabled` (`CaptainMemorySettingsView.swift:97-111`), destructive clear button only calls `MemoryStore.shared.clearAll()` (`CaptainMemorySettingsView.swift:53-58`) | Important because the UI label “Clear All” is narrower than the whole Captain store. |

External callers outside the memory files themselves:
- `CaptainViewModel` persists chat history and calls background extraction (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:388`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:516`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:608`).
- `CloudBrainService` requests cloud-safe relevant context (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:52-56`).
- `CaptainContextBuilder` reads recent thread summaries and personalization (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:231-255`).
- `SmartNotificationScheduler`, `MorningHabitOrchestrator`, and `NotificationService` read `ConversationThreadManager` for budget/history decisions (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:903-916`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:97-100`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:196-201`).
- Onboarding and Legendary Challenges also write memory facts or personalization state (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Onboarding/CaptainPersonalizationOnboardingView.swift:708-753`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift:89-168`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:288`).

### 3.3 Dependency Graph
Primary memory edges:
- `AiQoApp` -> `MemoryStore`, `CaptainPersonalizationStore`, `WeeklyMetricsBufferStore`, `WeeklyMemoryConsolidator`, `ConversationThreadManager` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:54-64`).
- `CaptainViewModel` -> `MemoryStore` and `ConversationThreadManager` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:258`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:503`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:608`).
- `CaptainCognitivePipeline` -> `MemoryStore.retrieveRelevantMemories` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift:364-413`).
- `CloudBrainService` -> `MemoryStore.buildCloudSafeRelevantContext` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:48-58`).
- `HealthKitMemoryBridge` -> `MemoryStore` + `WeeklyMetricsBufferStore` + `WeeklyMemoryConsolidator` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/HealthKitMemoryBridge.swift:15-16`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/HealthKitMemoryBridge.swift:64-82`).
- `MemoryExtractor` -> `PrivacySanitizer` + Gemini endpoint + `MemoryStore.set` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:189-195`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:214-281`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:302-319`).
- Notification orchestration -> `ConversationThreadManager` for send/open counts (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:903-916`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:265-267`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:28-31`).

ASCII graph:

```text
AiQoApp
  |
  +--> Captain ModelContainer (captain_memory.store)
          |
          +--> MemoryStore
          |      |--> CaptainMemory
          |      +--> PersistentChatMessage
          |
          +--> CaptainPersonalizationStore
          |      +--> CaptainPersonalizationProfile
          |
          +--> WeeklyMetricsBufferStore
          |      +--> WeeklyMetricsBuffer
          |
          +--> WeeklyMemoryConsolidator
          |      +--> WeeklyReportEntry
          |
          +--> ConversationThreadManager
                 +--> ConversationThreadEntry

CaptainViewModel
  |--> MemoryStore.persistMessageAsync
  |--> ConversationThreadManager.logUserMessage/logCaptainResponse
  +--> MemoryExtractor.extract --> MemoryStore.set

CaptainCognitivePipeline --> MemoryStore.retrieveRelevantMemories
CloudBrainService -------> MemoryStore.buildCloudSafeRelevantContext
HealthKitMemoryBridge ---> MemoryStore.set + WeeklyMetricsBufferStore.upsertToday
Notifications -----------> ConversationThreadManager.recentNotifications
```

Suspicious dependencies:
- Chat history, long-term facts, personalization, weekly reports, and notification timeline all share one physical Captain store. A storage-layer issue or schema mistake can affect all four domains (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:16-35`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV3.swift:9-18`).
- `ConversationThread.swift` is physically in `Features/Captain` but functionally belongs to both memory and notifications. That split identity will matter in any folder-based restructure (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:1-209`).
- `MemoryStore` mixes two responsibilities: durable fact storage and chat transcript/session management (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:45-371`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:388-539`).

### 3.4 Data Flow
Conversation-entry lifecycle:

1. `CaptainViewModel.sendMessage` appends a `ChatMessage` and persists it via `MemoryStore.persistMessageAsync` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:236-240`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:606-608`).
2. `MemoryStore.persistMessageAsync` hops to the next `MainActor` turn and calls `persistMessage` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:412-416`).
3. `MemoryStore.persistMessage` inserts `PersistentChatMessage(chatMessage:sessionID:)`, saves, increments the write counter, and trims history every 12 writes if needed (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:391-406`).
4. Chat retrieval later uses `fetchMessages(for:)` for one session and `fetchSessions()` for grouped session metadata (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:419-495`).

Durable fact lifecycle:

1. `MemoryExtractor.extract` is scheduled after a successful assistant reply (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:509-519`).
2. Rule extraction always runs first and writes facts like weight, height, age, injury, goal, sleep hours, and names straight into `MemoryStore.set` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:24-37`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:42-180`).
3. Every third message, LLM extraction also runs if cloud consent exists. It sanitizes the user message, limits keys, hits Gemini Flash Preview, parses a flat JSON dictionary, maps keys to categories, and writes those facts through `MemoryStore.set` at confidence `0.8` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:184-287`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:302-319`).
4. `MemoryStore.set` either updates an existing memory or inserts a new one. On update it bumps `confidence` by `0.05` up to `1.0`; on insert it enforces the tier-based limit and evicts the lowest-confidence non-project item if needed (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:45-83`).

Health-derived memory lifecycle:

1. `AiQoApp.schedulePostLaunchWarmup` optionally calls `HealthKitMemoryBridge.syncHealthDataToMemory()` after launch (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:304-307`).
2. `HealthKitMemoryBridge` fetches latest body mass, resting HR, seven-day average steps, seven-day average active calories, and seven-day sleep average, then writes them into `MemoryStore` with `source = "healthkit"` and confidence `1.0` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/HealthKitMemoryBridge.swift:21-60`).
3. The same bridge also writes a daily buffer row through `WeeklyMetricsBufferStore.upsertToday(...)` and immediately triggers `WeeklyMemoryConsolidator.consolidateIfDue()` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/HealthKitMemoryBridge.swift:64-82`).

Weekly consolidation lifecycle:

1. `WeeklyMemoryConsolidator.anchorDate()` uses the latest report’s `rangeEnd`, else the free-trial public start date (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift:23-26`).
2. `shouldConsolidateNow()` requires at least 7 days since that anchor (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift:17-20`).
3. `consolidateIfDue()` averages buffered steps, calories, sleep, resting HR, workout minutes, and workout counts; computes best-day labels; inserts a `WeeklyReportEntry`; saves; clears the buffer; and tracks analytics (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift:28-79`).

Retrieval lifecycle:

1. `CaptainCognitivePipeline.buildWorkingMemorySummary` calls `MemoryStore.retrieveRelevantMemories(for:screenContext:limit: 8)` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift:359-368`).
2. `MemoryStore.retrieveRelevantMemories` loads the 100 most recent memories, filters optional categories, scores each using confidence, intent weights, screen weights, category boosts, token overlap, source weight, recency, and access-count penalty, then saves incremented `accessCount` asynchronously (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:133-192`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:548-585`).
3. `CloudBrainService` uses the narrower `buildCloudSafeRelevantContext` path, limited to categories `goal`, `preference`, `mood`, `injury`, `nutrition`, and `insight` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:194-221`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:48-58`).

Pruning rules:

| Data type | Rule | Refs |
|---|---|---|
| `CaptainMemory` | `removeStale` deletes memories older than 90 days and below confidence `0.3`, except `active_record_project` entries | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:307-329` |
| `PersistentChatMessage` | Trim to at most 200 persisted chat messages; check every 12 writes | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:388-389`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:515-539` |
| `ConversationThreadEntry` | Prune entries older than 7 days | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:157-169` |
| `WeeklyMetricsBuffer` | Cleared completely after weekly consolidation | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift:74-79`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMetricsBufferStore.swift:51-55` |
| `CaptainPersonalizationProfile` | No automatic prune | No prune logic surfaced in `CaptainPersonalization.swift:306-405` |
| `WeeklyReportEntry` | No automatic prune | No prune logic surfaced in `WeeklyMemoryConsolidator.swift:81-88` |

Schema versions and migration logic:

| Schema | Models in version | Migration notes |
|---|---|---|
| `CaptainSchemaV1` | `CaptainMemory`, `CaptainPersonalizationProfile`, `PersistentChatMessage`, `RecordProject`, `WeeklyLog` | Baseline Captain container (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV1.swift:7-18`) |
| `CaptainSchemaV2` | V1 + `WeeklyMetricsBuffer`, `WeeklyReportEntry` | Purely additive (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV2.swift:6-18`) |
| `CaptainSchemaV3` | V2 + `ConversationThreadEntry` | Purely additive (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV3.swift:6-18`) |
| `CaptainSchemaMigrationPlan` | `[V1, V2, V3]` | Lightweight V1->V2 and V2->V3 only (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaMigrationPlan.swift:4-23`) |

### 3.5 State & Persistence
SwiftData entities in the dedicated Captain container:

| Entity | Storage role | Primary refs |
|---|---|---|
| `CaptainMemory` | Long-term facts | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainMemory.swift:5-42` |
| `PersistentChatMessage` | Persisted chat transcript | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainModels.swift:7-74`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:391-539` |
| `CaptainPersonalizationProfile` | Captain personalization snapshot | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainPersonalization.swift:217-266`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainPersonalization.swift:330-360` |
| `WeeklyMetricsBuffer` | Rolling daily metrics for consolidation | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMetricsBufferStore.swift:17-55` |
| `WeeklyReportEntry` | Consolidated weekly reports | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift:58-88` |
| `ConversationThreadEntry` | 7-day interaction timeline | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:26-209` |
| `RecordProject` | Captain-adjacent legendary challenge record project | Present in schema V1-V3 (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV1.swift:12-17`) |
| `WeeklyLog` | Captain-adjacent weekly log | Present in schema V1-V3 (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV1.swift:12-17`) |

UserDefaults keys in the memory system:

| Key | Stored by | Meaning |
|---|---|---|
| `captain_memory_enabled` | `MemoryStore` (`MemoryStore.swift:22-31`) | Master enable/disable toggle for long-term memory. |
| `aiqo.captainPersonalization.snapshot` | `CaptainPersonalizationStore` (`CaptainPersonalization.swift:309-311`, `CaptainPersonalization.swift:333`, `CaptainPersonalization.swift:396-402`) | Cached serialized personalization snapshot fallback when SwiftData is unavailable. |
| `aiqo.morningHabit.cachedInsight` | `MorningHabitOrchestrator` (`MorningHabitOrchestrator.swift:23-27`, `MorningHabitOrchestrator.swift:353-360`) | Not strictly “memory,” but it behaves like ephemeral notification memory and influences Captain chat experience. |

Files on disk:
- The dedicated Captain store file lives at `Application Support/captain_memory.store` and is created by `AiQoApp` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:21-35`).
- The personalization fallback cache and other defaults-backed memory state live in the standard `UserDefaults` domain, not in a custom file (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainPersonalization.swift:309-316`).

Keychain:
- Memory itself does not use Keychain.
- `WeeklyMemoryConsolidator` depends on `FreeTrialManager.trialStartDatePublic`, and that manager persists the trial start date in Keychain so the weekly-memory anchor can survive reinstalls (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/FreeTrialManager.swift:98-115`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/FreeTrialManager.swift:148-179`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift:23-26`).

In-memory state:
- `MemoryStore` caches prompt-context strings and cloud-safe-context strings in memory and tracks a write counter for chat trimming (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:11-19`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:543-546`).
- `CaptainPersonalizationStore` keeps its `ModelContainer` reference and serializes fetch/save through a private queue (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainPersonalization.swift:306-320`).
- `ConversationThreadManager` holds a `ModelContext?` reference and writes via deferred `Task` save (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:54-61`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:173-193`).

### 3.6 Background & Lifecycle
Memory-relevant lifecycle hooks:
- Captain memory stores are configured once in `AiQoApp.init` before UI render (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:54-64`).
- `ConversationThreadManager.pruneOldEntries()` is run during app init (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:61-62`).
- `MemoryStore.removeStale()` runs in post-launch warmup after the first frame (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:296-303`).
- `HealthKitMemoryBridge.syncHealthDataToMemory()` also runs in that warmup when the legacy calculation onboarding flag is set (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:304-307`).
- There is no BGTaskScheduler registration dedicated to memory maintenance; memory refresh piggybacks on launch, chat sends, and HealthKit bridge calls.

## 4. Notification System
### 4.1 Inventory
Main notification/control files:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift` | 947 | Main | Unified recurring scheduler plus background refresh and proactive-context builder (`SmartNotificationScheduler.swift:7-946`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift` | 1119 | Main | Notification auth/category gateway, Captain smart-notification service, workout summary AI service (`NotificationService.swift:6-1005`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift` | 399 | Main | Wake-window step observer and passive morning insight notification (`MorningHabitOrchestrator.swift:6-347`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift` | 218 | Main | HealthKit sleep observer and sleep-completion passive notification (`SleepSessionObserver.swift:6-218`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift` | 219 | Main/helper | Builds local-notification copy using `LocalBrainService` and personalization context (`CaptainBackgroundNotificationComposer.swift:17-218`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift` | 324 | Main decision engine | Used by `SmartNotificationScheduler` when Brain V2 context exists (`SmartNotificationScheduler.swift:495`, `SmartNotificationScheduler.swift:605`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift` | 80 | Delivery bridge | Handles Captain notification opens and pending-message routing (`CaptainNotificationRouting.swift:18-48`). |

Notification support files:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationCategoryManager.swift` | 41 | Support | Registers categories at launch (`NotificationCategoryManager.swift:16-39`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationLocalization.swift` | 43 | Support | Resolves notification language from `notificationLanguage` or legacy store (`NotificationLocalization.swift:3-10`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/SmartNotificationManager.swift` | 78 | Support | Deterministic fallback notification copy plus user-name injection (`SmartNotificationManager.swift:8-77`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/InactivityTracker.swift` | 21 | Support | Tracks app inactivity in `UserDefaults` (`InactivityTracker.swift:3-19`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/PremiumExpiryNotifier.swift` | 107 | Support | Schedules premium-expiry reminders adjusted for quiet hours (`PremiumExpiryNotifier.swift:22-100`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/AlarmSchedulingService.swift` | 262 | Support | Alarm-kit bridge for smart wake time; also configures morning habit wake date (`AlarmSchedulingService.swift:123-131`, `AlarmSchedulingService.swift:189`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationRepository.swift` | 37 | Support/placeholder | Hardcoded fallback dataset repository; candidate dead code because no external reference surfaced in repo scan. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/NotificationPreferencesStore.swift` | 36 | Support | Legacy language/gender notification preferences store (`NotificationPreferencesStore.swift:8-34`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/ActivityNotification.swift` | 26 | Support | Types used by older notification-repository path. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/NotificationType.swift` | 11 | Support | Deep-link routing enum for non-Captain notification types. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Trial/TrialNotificationCopy.swift` | 142 | Support | Trial-journey notification text helpers. |

App lifecycle and config files that wire notifications:

| Path | Lines | Role | Notes |
|---|---:|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift` | 465 | Main support | Registers categories and BG tasks, requests permissions, starts orchestrators, handles delivery and taps (`AppDelegate.swift:106-151`, `AppDelegate.swift:171-216`, `AppDelegate.swift:258-293`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Info.plist` | 91 | Config | BG task identifiers, background modes, feature flags, API URLs/keys (`Info.plist:5-89`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsScreen.swift` | 470 | Support | Notification master switch and language picker; refreshes or cancels scheduler (`AppSettingsScreen.swift:13`, `AppSettingsScreen.swift:329-359`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsStore.swift` | 45 | Support | Persists master notifications-enabled flag (`AppSettingsStore.swift:13-39`). |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/DeepLinkRouter.swift` | 127 | Support | Routes `aiqo://captain` and other notification deep links (`DeepLinkRouter.swift:11-63`, `DeepLinkRouter.swift:82-125`). |

### 4.2 Public API
Primary notification types and ownership:

| Type or file group | Kind | Ownership | Key surface | Notes |
|---|---|---|---|---|
| `SmartNotificationScheduler` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:7-947` | singleton service | `shared`; registered and invoked from `AppDelegate` and settings UI (`AppDelegate.swift:124`, `AppSettingsScreen.swift:334-358`) | `registerBackgroundTasks` (`SmartNotificationScheduler.swift:79-103`), `refreshAutomationState` (`SmartNotificationScheduler.swift:105-118`), `scheduleBackgroundTasksIfNeeded`/`cancelScheduledBackgroundTasks` (`SmartNotificationScheduler.swift:128-136`), background handlers (`SmartNotificationScheduler.swift:444-485`), proactive-context builder (`SmartNotificationScheduler.swift:829-946`) | This is the most central scheduler, but not the only sender. |
| `NotificationService` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:6-126` | singleton gateway | `shared` | `requestPermissions` (`NotificationService.swift:13-17`), `ensureAuthorizationIfNeeded` (`NotificationService.swift:19-63`), `configureCategories` (`NotificationService.swift:65-67`), `sendImmediateNotification` (`NotificationService.swift:69-83`), `handle(response:)` (`NotificationService.swift:91-113`) | Handles global auth and non-Captain routes. |
| `CaptainSmartNotificationService` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:156-537` | singleton service | `shared`; called from `AppDelegate`, `HealthKitManager`, workout screen, and scheduler-generated notifications | `evaluateInactivityAndNotifyIfNeeded` (`NotificationService.swift:188-221`), `handleWorkoutCompleted` (`NotificationService.swift:223-235`) | Sends immediate Captain-branded notifications outside BG scheduler. |
| `AIWorkoutSummaryService` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:556-1005` | singleton service | `shared`; started from `AppDelegate` (`AppDelegate.swift:143-145`, `AppDelegate.swift:190-193`) | `startMonitoringWorkoutEnds` (`NotificationService.swift:588-595`), `handleWorkoutEnded` (`NotificationService.swift:597-648`) | Separate HK observer pipeline that sends Captain notifications. |
| `MorningHabitOrchestrator` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:6-347` | singleton `NSObject` | `shared`; started from `AppDelegate` (`AppDelegate.swift:139`, `AppDelegate.swift:187`, `AppDelegate.swift:192`) | `start` (`MorningHabitOrchestrator.swift:56-61`), `configureScheduledWake` (`MorningHabitOrchestrator.swift:63-75`), `refreshMonitoringState` (`MorningHabitOrchestrator.swift:77-110`), `consumeEphemeralInsightIfNeeded`, `markEphemeralInsightRead`, `cancelMorningNotification` (`MorningHabitOrchestrator.swift:112-148`) | Owns wake-window step observer and passive morning push. |
| `SleepSessionObserver` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:6-218` | singleton `NSObject` | `shared`; started from `AppDelegate` (`AppDelegate.swift:141`, `AppDelegate.swift:188`) | `start` (`SleepSessionObserver.swift:37-40`) and private HK observer/scheduling pipeline (`SleepSessionObserver.swift:45-183`) | Observes sleep-analysis samples and schedules post-sleep notification. |
| `CaptainBackgroundNotificationComposer` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:3-218` | value helper | Instantiated by `SmartNotificationScheduler`, `MorningHabitOrchestrator`, and `SleepSessionObserver` (`SmartNotificationScheduler.swift:44`, `MorningHabitOrchestrator.swift:33`, `SleepSessionObserver.swift:17`) | `composeMorningSleepNotification` (`CaptainBackgroundNotificationComposer.swift:17-56`), `composeSleepCompletionNotification` (`CaptainBackgroundNotificationComposer.swift:58-94`), `composeInactivityNotification` (`CaptainBackgroundNotificationComposer.swift:96-140`) | Uses `LocalBrainService`, not Gemini. |
| `NotificationCategoryManager` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationCategoryManager.swift:4-41` | singleton | `shared` | `registerAllCategories` (`NotificationCategoryManager.swift:16-39`) | Registers only two categories today. |
| `SmartNotificationManager` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/SmartNotificationManager.swift:3-78` | value helper | `shared` | `morningSleepNotificationBody`, `inactivityNotificationBody`, `currentUserName` (`SmartNotificationManager.swift:8-77`) | Deterministic fallback copy. |
| `NotificationLocalization` free functions in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationLocalization.swift:3-43` | free functions | Global | `resolvedCoachNotificationLanguage`, `localizedNotificationString` | Normalizes notification language selection. |
| `NotificationPreferencesStore` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/NotificationPreferencesStore.swift:3-36` | singleton | `shared` | `gender`, `language` computed properties | Legacy fallback store. |
| `CaptainNotificationHandler` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:6-64` | `ObservableObject` singleton | `shared` | `handleIncomingNotification`, `clearPendingMessage`, `hasPendingMessage` | Receives Captain notification opens only. |
| `PremiumExpiryNotifier` in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/PremiumExpiryNotifier.swift:11-107` | static enum | Global | `scheduleAllNotifications`, `plannedNotifications` (`PremiumExpiryNotifier.swift:22-100`) | Quiet-hour adjusted but not Captain-specific. |
| `AlarmSchedulingService` types in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/AlarmSchedulingService.swift:6-262` | protocol support | Factory-created | Alarm auth/save state and AlarmKit integration | Relevant because it feeds scheduled wake into `MorningHabitOrchestrator`. |

### 4.3 Dependency Graph
Primary edges:
- `AppDelegate` registers categories and background tasks on launch, then starts `MorningHabitOrchestrator`, `TrialJourneyOrchestrator`, `SleepSessionObserver`, `AIWorkoutSummaryService`, and scheduler refresh depending on onboarding and settings (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:123-151`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:171-216`).
- `AppSettingsScreen` toggles `AppSettingsStore.shared.notificationsEnabled`, requests permissions, and refreshes or cancels the scheduler (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsScreen.swift:329-359`).
- `SmartNotificationScheduler` depends on `CaptainIntelligenceManager`, `CaptainBackgroundNotificationComposer`, `CoachBrainLLMTranslator`, `ProactiveEngine`, `CaptainPersonalizationStore`, `ConversationThreadManager`, and `EmotionalStateEngine` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:43-76`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:488-946`).
- `CaptainSmartNotificationService` depends on `ConversationThreadManager`, `InactivityTracker`, `HealthKitManager`, and the legacy `CaptainIntelligenceManager.generateCaptainResponse` path (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:188-221`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:489-536`).
- `MorningHabitOrchestrator` and `SleepSessionObserver` both depend on `CaptainBackgroundNotificationComposer`, which depends on `LocalBrainService` and `CaptainPersonalizationStore` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:9-15`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:143-194`).
- `AIWorkoutSummaryService` depends on HealthKit observers, the legacy Captain intelligence service, and `ConversationThreadManager` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:556-1005`).
- Delivery routing goes through `UNUserNotificationCenterDelegate` in `AppDelegate`, then into `CaptainNotificationHandler`, `AppRootManager`, or `NotificationService.handle(response:)` + `DeepLinkRouter` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:258-293`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:91-126`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/DeepLinkRouter.swift:41-63`).

ASCII graph:

```text
AppDelegate
  |--> NotificationCategoryManager.registerAllCategories
  |--> SmartNotificationScheduler.registerBackgroundTasks
  |--> MorningHabitOrchestrator.start
  |--> SleepSessionObserver.start
  |--> AIWorkoutSummaryService.startMonitoringWorkoutEnds
  +--> SmartNotificationScheduler.refreshAutomationState

SmartNotificationScheduler
  |--> recurring UNNotificationRequests
  |--> BGAppRefreshTask / BGProcessingTask
  |--> CaptainIntelligenceManager.fetchTodayEssentialMetrics
  |--> ProactiveEngine.evaluate
  |--> CaptainBackgroundNotificationComposer
  +--> UNUserNotificationCenter.add

CaptainSmartNotificationService
  |--> InactivityTracker / HealthKitManager
  |--> CaptainIntelligenceManager.generateCaptainResponse
  +--> UNUserNotificationCenter.add

MorningHabitOrchestrator
  |--> HK step observer
  |--> CaptainBackgroundNotificationComposer
  +--> UNUserNotificationCenter.add

SleepSessionObserver
  |--> HK sleep observer
  |--> CaptainBackgroundNotificationComposer
  +--> UNUserNotificationCenter.add

AIWorkoutSummaryService
  |--> HK workout observer
  |--> CaptainIntelligenceManager.generateCaptainResponse
  +--> UNUserNotificationCenter.add
```

Suspicious dependencies:
- Notification sending is duplicated across four different code paths, each with its own scheduling request builder and its own assumptions about categories, copy, and cooldowns (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:770-801`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:242-268`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:303-347`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:147-183`).
- The live proactive engine depends on the memory thread history but not on full memory retrieval or trend snapshot injection from the chat pipeline (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:903-916`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:921-945`).

### 4.4 Data Flow
Recurring schedule + background path:

1. `AppDelegate.didFinishLaunchingWithOptions` sets `UNUserNotificationCenter.current().delegate`, registers categories, registers BG tasks, then starts notification services only if onboarding is complete (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:106-151`).
2. `SmartNotificationScheduler.registerBackgroundTasks()` registers `aiqo.notifications.refresh` as `BGAppRefreshTask` and `aiqo.notifications.inactivity-check` as `BGProcessingTask` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:79-103`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Info.plist:5-8`).
3. When notifications are enabled, `SmartNotificationScheduler.refreshAutomationState()` requests notification permission and then schedules recurring notifications plus the next background tasks (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:105-118`).
4. The recurring scheduler installs:
   - six hydration reminders at 10:00, 12:00, 14:00, 16:00, 18:00, 20:00 (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:261-284`);
   - one workout reminder at personalization-derived or default evening time (`SmartNotificationScheduler.swift:286-310`);
   - one sleep reminder at personalization-derived or default `22:30` (`SmartNotificationScheduler.swift:313-328`);
   - one streak-protection reminder at 20:00 (`SmartNotificationScheduler.swift:330-343`);
   - one weekly-report reminder on Friday at 10:00 (`SmartNotificationScheduler.swift:345-357`).
5. When the app enters background, `AppDelegate.applicationDidEnterBackground` queues any developer nudge and schedules or cancels background tasks based on the master notifications toggle (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:208-216`).
6. `handleBackgroundRefresh` reschedules the next refresh and runs `generateAndScheduleCoachNudge()` under expiration handling (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:444-464`).
7. `generateAndScheduleCoachNudge()` first tries Brain V2: it builds `ProactiveContext`, asks `ProactiveEngine.evaluate(context:)`, and if approved schedules a Captain local notification. If the proactive path fails or context cannot be built, it falls back to legacy health-context generation and optional Iraqi-Arabic translation via `CoachBrainLLMTranslator` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:488-548`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:720-737`).
8. `handleInactivityProcessing` similarly reschedules the next processing task and runs `performInactivityCheckAndNotifyIfNeeded()` under expiration handling (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:466-485`).
9. `performInactivityCheckAndNotifyIfNeeded()` only proceeds after 14:00, only if steps are below 3000, only outside quiet hours, and only if its 3-hour background cooldown is clear. It then prefers `ProactiveEngine`, else falls back to `CaptainBackgroundNotificationComposer.composeInactivityNotification(...)` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:581-647`).

Proactive decision path:

1. `SmartNotificationScheduler.buildProactiveContext()` fetches today’s essential metrics with `CaptainIntelligenceManager`, computes `EmotionalState`, loads Captain personalization, derives tier from free trial or StoreKit entitlement, and reads recent notification events from `ConversationThreadManager` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:829-916`).
2. The same builder hardcodes several crucial fields: fallback bedtime/wake strings `23:00` / `07:00`, `stepGoal = 10_000`, `calorieGoal = 500`, `waterIntakePercent = 0.5`, `isCurrentlyWorkingOut = false`, `lastWorkoutEndedAt = nil`, `trendSnapshot = nil` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:855-856`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:918-945`).
3. `ProactiveEngine.evaluate` enforces the Brain V2 kill switch, checks subscription/tier-derived daily budget, checks a 120-minute cooldown, applies quiet hours, and blocks after repeated dismissals (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift:94-132`).
4. Trigger priority is: workout ended, currently working out, ring almost complete, low steps after 14:00, low water after noon, declining sleep trend in the evening, streak breaking, morning kickoff after wake (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift:136-249`).

Immediate-app inactivity path:

1. On app active, `AppDelegate` calls `CaptainSmartNotificationService.evaluateInactivityAndNotifyIfNeeded()` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:190-194`).
2. That service gates on notifications enabled, 45+ minutes inactivity, internal cooldown, and a hardcoded budget of fewer than 4 recent notification sends in 24 hours (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:188-201`).
3. It then generates a message from raw step count through `CaptainIntelligenceManager.generateCaptainResponse(for: prompt)` and sends a local notification with Captain metadata into `UNUserNotificationCenter` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:203-220`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:242-268`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:489-536`).

Morning habit path:

1. `MorningHabitOrchestrator.start()` enables step observation and refreshes monitoring state (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:56-61`).
2. `refreshMonitoringState()` requires a saved wake date, being inside a 6-hour monitoring window, and at least 25 steps since wake (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:77-83`).
3. It generates or reuses an ephemeral insight message through `CaptainBackgroundNotificationComposer`, skips if already read or already scheduled, applies a hardcoded `todayNotifCount < 4` check, then schedules a passive local notification unless the user is inside the trial window (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:85-107`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:222-239`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:303-347`).

Sleep completion path:

1. `SleepSessionObserver.start()` enables HealthKit background delivery for sleep-analysis samples (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:45-59`).
2. The observer query calls `syncSleepUpdates(shouldNotify: true)` when new sleep data arrives (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:60-84`).
3. `syncSleepUpdates` advances the anchor, selects the latest relevant sleep end within the last 4 hours, asks `CaptainBackgroundNotificationComposer.composeSleepCompletionNotification(...)` for body text, and schedules a passive Captain notification (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:86-107`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:135-183`).

Workout summary path:

1. `AIWorkoutSummaryService.startMonitoringWorkoutEnds()` ensures authorization, enables background delivery, installs a workout observer, and syncs anchored workouts (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:588-595`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:652-731`).
2. For each workout, `handleWorkoutEnded` deduplicates by workout ID/fingerprint, builds a language-specific prompt that contains duration, calories, average HR, distance, and HR-zone distribution, and calls `CaptainIntelligenceManager.generateCaptainResponse(for: prompt)` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:597-648`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:850-909`).
3. The final 20-word message is delivered as an immediate Captain notification and logged into the thread history (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:978-1005`).

Delivery and open routing:

1. `AppDelegate.userNotificationCenter(_:didReceive:...)` inspects `userInfo["source"]` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:270-293`).
2. `source == "captain_hamoudi"` routes to `CaptainNotificationHandler`, which stores the pending message in `UserDefaults`, logs an “opened” thread entry, and posts a launch notification (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:279-283`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:18-43`).
3. `source == "morning_habit"` opens Captain chat through `AppRootManager` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:284-287`).
4. Everything else goes through `NotificationService.handle(response:)`, which either follows `deepLink` via `DeepLinkRouter` or routes on `NotificationType` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:91-126`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/DeepLinkRouter.swift:41-63`).

### 4.5 State & Persistence
UserDefaults keys used by notifications:

| Key | Meaning | Refs |
|---|---|---|
| `aiqo.notifications.enabled` | Master notifications toggle | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsStore.swift:13-39` |
| `notificationLanguage` | Primary notification language key | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsScreen.swift:13`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationLocalization.swift:3-10`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:52` |
| `aiqo.notification.language` | Legacy notification language fallback | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/NotificationPreferencesStore.swift:9-34` |
| `user_gender` | Legacy notification gender preference | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/NotificationPreferencesStore.swift:8-20` |
| `aiqo.notifications.didPromptPermission` | Whether auth prompt was already shown | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:8-9`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:37` |
| `aiqo.notifications.background.lastInactivitySentAt` | BG inactivity cooldown marker | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:58-59`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:615-616`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:804-809` |
| `aiqo.captain.lastInactivitySentAt` | Foreground inactivity cooldown marker | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:179-180`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:220`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:237-239` |
| `aiqo.captain.lastWaterReminderSentAt` | Water reminder cooldown marker | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:301`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:457-469` |
| `aiqo.captain.lastMealReminderSentAt.<meal>` | Meal reminder cooldown markers | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:351`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:458`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:472-475` |
| `aiqo.captain.lastStepGoalSentAt.<milestone>` | Step progress cooldown markers | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:416`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:459`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:478-481` |
| `aiqo.captain.lastSleepReminderSentAt` | Sleep reminder cooldown marker | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:452`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:460`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:484-486` |
| `aiqo.inactivity.lastActiveDate` | Last app activity timestamp | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/InactivityTracker.swift:6-19` |
| `aiqo.morningHabit.scheduledWakeTimestamp` | Morning habit wake anchor | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:23-27`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:67` |
| `aiqo.morningHabit.notificationWakeTimestamp` | Morning notification de-dupe for a wake cycle | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:23-27`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:343`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:349-350` |
| `aiqo.morningHabit.cachedInsight` | Cached morning insight payload | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:23-27`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:156-159`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:353-360` |
| `aiqo.ai.workout.anchor` | Anchored HK workout query position | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:565`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:583`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:1087-1097` |
| `aiqo.ai.workout.processed.ids` | De-duped workout IDs | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:566`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:581` |
| `aiqo.sleepObserver.anchorData` | Anchored HK sleep query position | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:9-11`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:201-217` |
| `aiqo.sleepObserver.lastNotifiedSleepEnd` | Sleep-end de-dupe marker | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:9-11`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:142-145`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:178-180` |
| `aiqo.captain.pendingMessage` | Pending Captain message opened from notification | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:12-16`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:28-48` |

SwiftData touched by notifications:

| Entity | Notification usage | Refs |
|---|---|---|
| `ConversationThreadEntry` | Send/open/dismiss counts and history-driven budgets | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:65-107`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:903-916`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:196-201`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:265-267`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:28-31` |
| `CaptainPersonalizationProfile` | Supplies workout reminder time, sleep reminder time, goal, sport, wake/bed times | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:289-317`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:861-869`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:179-194` |

In-memory notification state:
- `SmartNotificationScheduler` keeps a pending developer notification buffer, an `NSLock`, and several immutable timing constants in memory (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:46-61`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:812-824`).
- `MorningHabitOrchestrator` holds step observer query state and `hasStartedStepObserver` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:38-39`).
- `SleepSessionObserver` holds sleep observer query state, current anchor, and `hasStartedObserver` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:19-21`).
- `AIWorkoutSummaryService` holds workout observer query, HK anchor, dedupe IDs, fingerprint cache, and sync flags (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:572-578`).

### 4.6 Background & Lifecycle
BG task identifiers and handlers:

| Identifier | Declared in | Handler | Refs |
|---|---|---|---|
| `aiqo.notifications.refresh` | `Info.plist` and `SmartNotificationScheduler.backgroundRefreshIdentifier` | `SmartNotificationScheduler.handleBackgroundRefresh(task:)` -> `generateAndScheduleCoachNudge()` | `/Users/mohammedraad/Desktop/AiQo/AiQo/Info.plist:5-8`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:10`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:79-90`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:444-464` |
| `aiqo.notifications.inactivity-check` | `Info.plist` and `SmartNotificationScheduler.inactivityProcessingTaskIdentifier` | `SmartNotificationScheduler.handleInactivityProcessing(task:)` -> `performInactivityCheckAndNotifyIfNeeded()` | `/Users/mohammedraad/Desktop/AiQo/AiQo/Info.plist:5-8`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:11`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:92-103`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:466-485` |

Other timers/scheduled work:
- Developer nudge delay: 5 seconds (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:57`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:171-176`).
- Background inactivity cooldown: 3 hours (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:58-59`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:804-809`).
- Foreground inactivity cooldown: 45 minutes (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:179-180`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:237-239`).
- Water reminder cooldown: 2 hours; meal reminder cooldown: 4 hours; step-goal cooldown: 1 hour; sleep-reminder cooldown: 20 hours (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:457-486`).
- Morning-habit monitoring window: 6 hours after wake (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:35-36`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:363-366`).
- Sleep observer only notifies if latest sleep end is within 4 hours (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:135-139`).

Lifecycle hooks touching notifications:
- Launch registration and startup orchestration: `AppDelegate.didFinishLaunchingWithOptions` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:92-165`).
- Foreground reevaluation: `applicationDidBecomeActive` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:171-201`).
- Background scheduling/cancel: `applicationDidEnterBackground` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:208-216`).
- User tap delivery: `userNotificationCenter(_:didReceive:...)` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:270-293`).
- Settings screen manual refresh/cancel on toggles or language changes (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsScreen.swift:329-359`).

## 5. Integration Points
### 5.1 Brain ↔ Memory
- The main brain path reads memory through `CaptainCognitivePipeline.buildWorkingMemorySummary`, which calls `MemoryStore.retrieveRelevantMemories(limit: 8)` and splits results into constraints vs strategy anchors (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift:359-414`).
- Retrieval scoring is more sophisticated than the blueprint says. `MemoryStore.relevanceScore` combines confidence, intent-category weights, screen-context weights, direct category boosts, token overlap, source weight, recency weight, access-count penalty, and an active-record-project boost for Peaks/challenge flows (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:548-585`).
- The cloud path reads a narrower subset of memory through `MemoryStore.buildCloudSafeRelevantContext` and passes that string to `PrivacySanitizer.sanitizeForCloud`, which places it into `workingMemorySummary` only after stripping PII elsewhere (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:194-221`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:48-66`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PrivacySanitizer.swift:96-123`).
- The brain also writes back into memory at two levels: persisted transcripts via `MemoryStore.persistMessageAsync` and durable facts via `MemoryExtractor.extract` -> `MemoryStore.set` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:236-240`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:509-519`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:17-37`).
- Recent interaction memory is separate from long-term fact memory. `CaptainContextBuilder` reads a thread summary from `ConversationThreadManager.buildPromptSummary(maxEntries: 5)` and stores that as `contextData.recentInteractions` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:253-255`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift:139-153`).

### 5.2 Brain ↔ Notifications
- Notifications reuse brain-core reasoning rather than a notification-specific model stack. `SmartNotificationScheduler` calls `ProactiveEngine.evaluate(context:)`, and `CaptainBackgroundNotificationComposer` calls `LocalBrainService.generateReply` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:495`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:605`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:196-206`).
- Foreground inactivity and workout summaries bypass `BrainOrchestrator` entirely and instead call the older `CaptainIntelligenceManager.generateCaptainResponse(...)` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:489-509`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:619-629`).
- Notification-open events flow back into brain UI through `CaptainNotificationHandler`, which stores the pending message, logs the open, and sets `shouldNavigateToCaptain = true`; `AppDelegate` then routes the user to the Captain tab or chat (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift:18-43`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:197-200`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:279-283`).

### 5.3 Brain ↔ HealthKit
- `CaptainContextBuilder` gets live metrics only through `CaptainIntelligenceManager.fetchTodayEssentialMetrics()`, which itself requests HealthKit permissions and performs time-bounded step, calorie, heart-rate, and sleep queries (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:318-320`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:101-152`).
- `CaptainIntelligenceManager.buildContextPrompt` includes raw step count, active calories, heart rate, and sleep hours in its prompt text for the legacy on-device/Arabic API route (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:438-462`).
- Memory also reads HealthKit through `HealthKitMemoryBridge.syncHealthDataToMemory()` and writes it into durable fact memory plus the weekly buffer (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/HealthKitMemoryBridge.swift:13-83`).
- Notifications separately read HealthKit through `CaptainIntelligenceManager.fetchTodayEssentialMetrics()`, `HealthKitManager`, HK step observers, HK sleep observers, and HK workout observers; they do not share one consolidated health-read façade (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:651-656`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:204`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:275-300`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:110-132`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:652-731`).

### 5.4 AccessManager Gating Matrix

| Capability | Gate defined in `AccessManager` | Actual caller found in audited code | Result |
|---|---|---|---|
| Captain UI access | `canAccessCaptain` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:36`) | No caller surfaced in repo-wide gate scan; `MainTabScreen` mounts `CaptainScreen()` unconditionally (`MainTabScreen.swift:51-64`) | Gate defined but not enforced at UI mount. |
| Captain notification access | `canReceiveCaptainNotifications` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:42`) | No caller surfaced in repo-wide gate scan; notification services start from `AppDelegate` without tier check (`AppDelegate.swift:135-151`, `AppDelegate.swift:185-194`) | Gate defined but not enforced in startup or send paths. |
| Extended memory access | `canAccessExtendedMemory` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:68`) | No direct caller surfaced; only `captainMemoryLimit` is consumed via `MemoryStore.maxMemories` (`MemoryStore.swift:17-19`) | Memory limit is enforced, but “extended memory” named gate itself is not used. |
| Tier-aware memory size | `captainMemoryLimit` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:73-80`) | Consumed by `MemoryStore.maxMemories` (`MemoryStore.swift:17-19`) | This is the one AccessManager memory gate that is actually wired. |
| Cloud model tier policy | `activeTier` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:27-31`) | Consumed by `CloudBrainService` (`CloudBrainService.swift:49-58`, `CloudBrainService.swift:68-75`) | Wired and active. |

### 5.5 PrivacySanitizer Call Sites

| Call site | Method | Purpose | Refs |
|---|---|---|---|
| `CloudBrainService` | `sanitizeForCloud` | Main cloud privacy boundary before Gemini | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:62-66` |
| `MemoryExtractor` | `sanitizeText` | Sanitizes user text before LLM fact extraction | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:191-195` |
| `CoachBrainMiddleware` | `sanitizeText` | Sanitizes input before external translation | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CoachBrainMiddleware.swift:373-378` |
| `BrainOrchestrator` | `injectUserName` | Re-personalizes final reply after cloud/local generation | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift:433-435` |
| `SmartNotificationManager` | `injectUserName` | Adds user name into deterministic notification fallbacks | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/SmartNotificationManager.swift:21`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/SmartNotificationManager.swift:54` |
| `SmartFridgeCameraViewModel` | `sanitizeKitchenImageData` | Kitchen image EXIF/GPS strip before upload | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:141` |
| `WeeklyReviewView` | `sanitizeText` | Sanitizes text before weekly-review path | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:418` |

Important gap:
- NotificationService inactivity/workout-summary generation and `CaptainIntelligenceManager` Arabic API path do not call `sanitizeForCloud`, so those outbound prompts are not protected by the same conversation truncation, health bucketing, or name-normalization boundary as the main chat flow (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:489-509`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:619-645`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:274-313`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:438-462`).

## 6. Problem Surface
### 6.1 Hardcoded Values

| File:line | Hardcoded value | Why it matters |
|---|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:13-15` | `gemini-2.5-flash` and `gemini-3-flash-preview` | Cloud model policy is code-fixed rather than config-driven. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift:89-91` | Gemini base endpoint, 35s request timeout, 40s resource timeout | Transport policy is code-fixed. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:281` | Arabic API timeout `25` seconds | Legacy external Arabic route has independent timeout policy. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift:324-333` | `http://localhost:3000/captain-ar` simulator fallback and `CAPTAIN_ARABIC_API_DEVICE_URL` expectation | Separate non-Gemini Arabic endpoint is still live. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:12` | `llmExtractionInterval = 3` | Durable fact extraction cadence is arbitrary and fixed in code. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:217` | LLM extraction timeout `15` seconds | Memory extraction has a different timeout budget from main brain transport. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift:314-318` | Hardcoded Gemini Flash Preview URL template | Memory extraction transport ignores the more centralized `HybridBrainService` config. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:150` | Fetch limit `100` for retrieval ranking | Retrieval quality and performance are coupled to a fixed recent-window size. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:199-205` | Fixed cloud-safe categories set | Cloud memory inclusion policy is hardcoded. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:307-316` | Prune after 90 days and confidence `< 0.3` | Long-term retention policy is code-fixed. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:388-389` | `maxPersistedMessages = 200`, `trimCheckInterval = 12` | Transcript retention is code-fixed. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PrivacySanitizer.swift:22-29` | Last 4 messages, 1280 px, JPEG 0.78, steps bucket 50, calories bucket 10 | Main privacy policy constants are code-fixed. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift:69-81` | Budget map trial/core/pro and `minIntervalMinutes = 120` | Notification budget policy is embedded in code. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift:174-205` | `stepGoal/2`, water `< 0.5`, sleep change `< -15`, time windows | Trigger thresholds are code-fixed. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift:259-261` | Quiet-hours fallback `23:00-07:00` | Duplicates scheduler quiet hours. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:12-13` | Quiet hours `23` and `7` | Scheduling policy is hardcoded. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:57-59` | Developer nudge delay `5s`, BG inactivity cooldown `3h` | Operational behaviors are fixed in code. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:272` | Water reminder hours `[10,12,14,16,18,20]` | Recurring schedule is hardcoded. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:317` | Default sleep reminder `22:30` | Personalization fallback is hardcoded. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:855-856` | Fallback bedtime/wake `23:00` / `07:00` in proactive context | Personalization fallback duplicates quiet-hour assumptions. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:918-932` | `stepGoal = 10_000`, `calorieGoal = 500`, `waterIntakePercent = 0.5` | Proactive context is partially mocked. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:180` | Foreground inactivity cooldown `45 min` | Separate from BG inactivity cooldown. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:201` | Hardcoded daily budget `< 4` for inactivity | Duplicates proactive budget policy. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:462-465` | 2h/4h/1h/20h per-category cooldowns | Category cooldowns are code-fixed. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:35-36` | Step threshold `25`, monitoring window `6h` | Wake-insight heuristics are code-fixed. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:138` | Notify only if sleep ended within `4h` | Sleep-notification freshness policy is fixed. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainPersonalization.swift:150-161` | Workout reminder mapping to `06:30`, `08:00`, `13:00`, `18:00`, `21:00` | Reminder-time mapping is embedded in code. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainPersonalization.swift:274-280` | Sleep reminder = bedtime minus 30 minutes | Reminder derivation policy is fixed. |

### 6.2 TODO / FIXME / HACK
- No `TODO`, `FIXME`, or `HACK` comments were found in the audited brain/memory/notification files during the repo-wide scoped search run for this audit on 2026-04-18.

### 6.3 Force Unwraps

| File:line | Expression | Risk |
|---|---|---|
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CoachBrainTranslationConfig.swift:89` | `URL(string: defaultEndpoint)!` | Safe in practice if the constant stays valid, but still an avoidable crash point in translation config. |
| `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/AlarmSchedulingService.swift:127` | `UUID(uuidString: "B8B502C3-4F52-4C18-B4E6-7E718F00A1F4")!` | Safe while the literal stays valid, but still an unnecessary crash point in alarm scheduling. |

### 6.4 Duplicate Logic

| Duplicate area | Evidence | Why it is a restructure problem |
|---|---|---|
| Captain notification request builders | `SmartNotificationScheduler.makeLocalNotificationRequest` (`SmartNotificationScheduler.swift:770-801`), `CaptainSmartNotificationService.sendCaptainNotification` (`NotificationService.swift:242-268`), `MorningHabitOrchestrator.scheduleMorningNotification` (`MorningHabitOrchestrator.swift:303-347`), `SleepSessionObserver.scheduleSleepNotification` (`SleepSessionObserver.swift:147-183`) | Four code paths build Captain-ish notifications separately. |
| Quiet-hours policy | `SmartNotificationScheduler` hardcodes `23-7` (`SmartNotificationScheduler.swift:12-13`, `SmartNotificationScheduler.swift:193-221`); `ProactiveEngine` derives from personalization but falls back to `23:00-07:00` (`ProactiveEngine.swift:79-84`, `ProactiveEngine.swift:257-275`) | Same concept, two implementations. |
| Daily notification budget logic | `ProactiveEngine.NotificationBudget.forContext` (`ProactiveEngine.swift:67-85`) vs `todayNotifCount < 4` in `CaptainSmartNotificationService` (`NotificationService.swift:195-201`) and `MorningHabitOrchestrator` (`MorningHabitOrchestrator.swift:96-100`) | Budget rules are inconsistent across paths. |
| Username source keys | `CaptainViewModel` uses `captain_user_name` / `captain_calling` (`CaptainViewModel.swift:128-135`, `CaptainViewModel.swift:281-307`); `SmartNotificationManager` reads the same keys (`SmartNotificationManager.swift:61-76`); `SmartNotificationScheduler` reads different keys `aiqo.captain.customization.calling` / `.name` (`SmartNotificationScheduler.swift:872-875`) | Personalized name insertion can disagree across subsystems. |
| Cloud-safe memory assembly | `buildCloudSafeRelevantContext` (`MemoryStore.swift:194-221`) and `buildCloudSafeContext` (`MemoryStore.swift:268-304`) both assemble cloud-safe context strings with overlapping category logic | Two similar but distinct privacy/memory assembly methods. |
| Health-based notification copy generation | `CaptainBackgroundNotificationComposer` uses `LocalBrainService` (`CaptainBackgroundNotificationComposer.swift:196-206`); inactivity and workout summaries use `CaptainIntelligenceManager.generateCaptainResponse` (`NotificationService.swift:489-509`, `NotificationService.swift:619-629`) | Two brain pathways generate notification copy with different privacy boundaries. |

### 6.5 Dead Code
These are candidates, not proven deletions. The evidence is “defined in code, but repo-wide reference scans during this audit did not surface a runtime caller outside the defining file.”

| Candidate | Evidence | Confidence |
|---|---|---|
| `LocalIntelligenceService` | Defined in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LocalIntelligenceService.swift:22-160`; repo-wide search surfaced only self-file references during this audit | Medium |
| `CaptainAvatar3DView` | Defined in `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainAvatar3DView.swift:11-79`; repo-wide search surfaced no caller | Medium |
| `NotificationRepository` | Defined in `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationRepository.swift:3-37`; repo-wide search surfaced no caller | High |
| `CoachBrainMiddleware` class | `CoachBrainLLMTranslator` is used by the scheduler (`SmartNotificationScheduler.swift:45-46`, `SmartNotificationScheduler.swift:76`), but the `CoachBrainMiddleware` class defined at `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CoachBrainMiddleware.swift:227-775` did not surface a runtime caller | Medium |

### 6.6 Missing Tier Gates

| Place that likely should gate by tier | Current behavior | Evidence |
|---|---|---|
| Captain tab mount | Always shows `CaptainScreen()` | `/Users/mohammedraad/Desktop/AiQo/AiQo/App/MainTabScreen.swift:51-64` |
| Captain chat send path | Requires AI cloud consent for non-sleep, but not `AccessManager.canAccessCaptain` | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:219-221` |
| Notification startup | Starts Captain/morning/sleep/workout notification systems after onboarding, without `canReceiveCaptainNotifications` | `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:135-151`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:185-194` |
| Scheduler recurring/background setup | Controlled by app settings only, not by tier | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:105-118` |
| Foreground inactivity Captain notification | Controlled by app settings and cooldown only, not by tier | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:188-221` |
| Morning habit notification | Controlled by wake/steps/trial window only, not by tier | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:77-107`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:303-347` |
| Sleep completion notification | Controlled by HealthKit observer and quiet-hour adjustment only, not by tier | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:86-107`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift:147-183` |

### 6.7 Apple Compliance Risks

| Risk | Evidence | Severity |
|---|---|---|
| Raw HealthKit-derived values can leave the device outside `PrivacySanitizer` | Inactivity prompt includes exact current steps and goes through `CaptainIntelligenceManager.generateCaptainResponse` (`NotificationService.swift:493-509`); workout summary prompt includes calories, average HR, distance, zone distribution and also goes through `CaptainIntelligenceManager.generateCaptainResponse` (`NotificationService.swift:619-645`, `NotificationService.swift:874-909`); `CaptainIntelligenceManager.buildContextPrompt` injects raw health snapshot into prompt text (`CaptainIntelligenceManager.swift:438-462`) | High |
| Missing pending-notification cap enforcement | No sender path checks the 64-pending iOS limit before `UNUserNotificationCenter.add`; recurring scheduler alone can install 10 baseline notifications (`SmartNotificationScheduler.swift:261-357`, `SmartNotificationScheduler.swift:388`, `NotificationService.swift:242-268`, `MorningHabitOrchestrator.swift:329-340`, `SleepSessionObserver.swift:169-180`) | Medium |
| Background task time-budget risk | Both BG task handlers do real inference/context work and only cancel on expiration; there is no staged degradation beyond fallback after proactive failure (`SmartNotificationScheduler.swift:444-485`, `SmartNotificationScheduler.swift:488-647`) | Medium |
| Missing provisional-auth fallback | Auth requests use `.alert, .sound, .badge` only in both `NotificationService` and `SmartNotificationScheduler`; no provisional flow surfaced (`NotificationService.swift:41-42`, `SmartNotificationScheduler.swift:224-227`) | Medium |
| Categories/actions mismatch | Scheduler uses categories `water_reminder`, `workout_motivation`, `sleep_reminder`, `streak_protection`, `weekly_report` (`SmartNotificationScheduler.swift:274-279`, `SmartNotificationScheduler.swift:302-307`, `SmartNotificationScheduler.swift:319-324`, `SmartNotificationScheduler.swift:333-338`, `SmartNotificationScheduler.swift:348-353`), but `NotificationCategoryManager` only registers `aiqo.captain.smart` and `aiqo.trial.journey` (`NotificationCategoryManager.swift:16-39`) | Medium |
| Legacy external Arabic API path beside centralized sanitizer | `CaptainIntelligenceManager.generateArabicAPIReply` sends JSON `{ text: userInput }` directly to external API endpoint configured via `CAPTAIN_ARABIC_API_URL` / device URL (`CaptainIntelligenceManager.swift:274-313`, `CaptainIntelligenceManager.swift:315-334`) | High |

### 6.8 Feature Flags Inventory

| Flag or config key | Location | Current use |
|---|---|---|
| `CAPTAIN_BRAIN_V2_ENABLED` | `Info.plist:75-76` | Read by `CaptainContextBuilder.isBrainV2Enabled` to gate emotional state, trend snapshot, recent interactions, and by `ProactiveEngine` as a hard kill switch (`CaptainContextBuilder.swift:143-144`, `CaptainContextBuilder.swift:227-255`, `ProactiveEngine.swift:95-98`) |
| `TRIBE_BACKEND_ENABLED` | `Info.plist:77-78` | Sibling feature flag present in plist; not surfaced as a gate in the audited brain/memory/notification code |
| `TRIBE_FEATURE_VISIBLE` | `Info.plist:79-80` | Sibling feature flag present in plist; not surfaced in audited systems |
| `TRIBE_SUBSCRIPTION_GATE_ENABLED` | `Info.plist:81-82` | Sibling feature flag present in plist; not surfaced in audited systems |
| `captain_memory_enabled` | `UserDefaults` via `MemoryStore` | Enables/disables durable memory writes and retrieval (`MemoryStore.swift:22-31`) |
| `aiqo.notifications.enabled` | `UserDefaults` via `AppSettingsStore` | Enables/disables scheduler and notification services (`AppSettingsStore.swift:14-39`, `AppSettingsScreen.swift:329-339`) |
| `notificationLanguage` | `@AppStorage` / `UserDefaults` | Controls notification language resolution (`AppSettingsScreen.swift:13`, `NotificationLocalization.swift:3-10`) |
| Onboarding booleans such as `didCompleteCaptainPersonalization`, `didCompleteFeatureIntro`, `didCompleteLegacyCalculation` | `UserDefaults` checked in `AppDelegate` | Gate when notification services and HealthKit-dependent startup work begin (`AppDelegate.swift:128-151`, `AppDelegate.swift:177-194`, `AppDelegate.swift:305-306`) |

### 6.9 Blueprint Drift

| Blueprint claim | Blueprint ref | Actual code | Drift |
|---|---|---|---|
| Captain requires tier `Max` and `Intelligence Pro` unlocks premium model + extended memory | `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:196` | Tier helpers exist, but Captain tab is mounted unconditionally and no `canAccessCaptain` caller surfaced (`MainTabScreen.swift:51-64`, `AccessManager.swift:36`) | Product policy documented, not enforced in runtime UI path. |
| `CaptainPromptBuilder` is a 7-layer prompt | `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:199`, `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:207`, `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:211` | Live `build(for:)` emits Identity, Stable Profile, Working Memory, Bio State, Circadian Tone, Screen Context, Medical Disclaimer, Output Contract = 8 sections (`CaptainPromptBuilder.swift:17-29`) | Blueprint undercounts the live prompt layout. |
| Memory retrieval scoring is confidence × intent × screen-context × recency | `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:207` | Live scoring also uses token overlap, source weight, direct category boost, access-count penalty, and Peaks/project boost (`MemoryStore.swift:564-585`) | Retrieval behavior is richer than blueprint. |
| Angel-number notifications are scheduled through `ProactiveEngine` + `SmartNotificationScheduler` | `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:210` | Live scheduler installs fixed daily/weekly reminders and BG-driven nudges; no angel-number implementation surfaced in notification code (`SmartNotificationScheduler.swift:261-357`, `SmartNotificationScheduler.swift:488-700`) | Blueprint feature is not implemented in live code. |
| Arabic cloud route goes through Gemini abstraction | `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:382-395` | Legacy `CaptainIntelligenceManager` still routes Arabic requests to a separate external Arabic API endpoint (`CaptainIntelligenceManager.swift:185-196`, `CaptainIntelligenceManager.swift:274-334`) | Runtime still has a parallel Arabic API path. |
| Quiet hours hardcoded in scheduler and notification language key is `notificationLanguage` | `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:707-710` | This is still true (`SmartNotificationScheduler.swift:12-13`, `SmartNotificationScheduler.swift:52`) | No drift; blueprint matches code here. |
| ElevenLabs fallback timeout 10s | `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:711` | Supporting context still documents this, but voice is orthogonal to the main brain/memory/notification audit | No contradiction found in scoped systems. |
| `Prompts.xcstrings` inventories Captain prompt keys | implied by support-context expectation | Live resource file only contains `zone2-coach-v1.0` and `zone2-coach-v2.0` (`Prompts.xcstrings:4`, `Prompts.xcstrings:21`) | Captain chat prompts are code-built, not localized string-resource-driven. |

## 7. Restructure Readiness
### 7.1 Brain Core
#### 7.1.1 What breaks if moved into `AiQo/Features/Captain/Brain/brain/`
- Swift symbol resolution itself should survive a path-only move because all types are in the same app module.
- Xcode project/group references will need to be updated for every moved file.
- Developer assumptions and hardcoded path expectations in documentation will drift again; the current blueprint already references flat Captain paths (`/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md:197-205`).
- UI previews and any file-based onboarding breadcrumbs in the repo will need relinking, even if runtime behavior stays the same.

#### 7.1.2 Public APIs consumed from outside the three systems
- `CaptainViewModel` is used by app root injection and by other feature screens like Kitchen and Gym club plan flows (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:14`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Kitchen/KitchenView.swift:5`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Kitchen/KitchenView.swift:38`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift:154`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Gym/Club/Plan/WorkoutPlanFlowViews.swift:429`).
- `CaptainIntelligenceManager` is used by Kitchen plan generation and notification services (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:27-73`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:508`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:629`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:594`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:651`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:832`).
- `AiQoPromptManager` is used by `HandsFreeZone2Manager` (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Gym/HandsFreeZone2Manager.swift:414`).

#### 7.1.3 Which SwiftData schema would need a new version bump?
- A path-only move of brain files does not require a SwiftData bump.
- If the move includes renaming or altering `PersistentChatMessage` or `ConversationThreadEntry`, the Captain schema would need a new version beyond V3 because both are persisted `@Model` types (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV3.swift:9-18`).

#### 7.1.4 Which feature flags currently gate this system?
- `CAPTAIN_BRAIN_V2_ENABLED` is the main brain feature flag (`/Users/mohammedraad/Desktop/AiQo/AiQo/Info.plist:75-76`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift:143-144`).
- Cloud consent is runtime-gated through AI consent managers, not `Info.plist` feature flags (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:219-221`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:44`).

### 7.2 Memory System
#### 7.2.1 What breaks if moved into `AiQo/Features/Captain/Brain/memory/`
- Runtime should survive a path-only move once project references are updated.
- The main conceptual risk is not the folder move; it is the current mixed ownership of `ConversationThread.swift` and `PersistentChatMessage`, which straddle memory and notification responsibilities.
- Any restructure that also renames `@Model` types or moves them across modules would require schema migration work.

#### 7.2.2 Public APIs consumed from outside the three systems
- `MemoryStore.shared` is consumed by Captain UI, CloudBrainService, Legendary Challenges, onboarding personalization, and weekly review flows (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift:52-56`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift:89-168`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:288`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Onboarding/CaptainPersonalizationOnboardingView.swift:718-753`).
- `CaptainPersonalizationStore.shared` is consumed by onboarding, trial personalization, scheduler, context builder, composer, and cognitive pipeline (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Onboarding/CaptainPersonalizationOnboardingView.swift:22`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Onboarding/CaptainPersonalizationOnboardingView.swift:708`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:289-317`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift:179-194`).
- `ConversationThreadManager.shared` is consumed by both Captain chat and notification systems (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:258`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift:503`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:905-916`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift:196-201`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift:97-100`).

#### 7.2.3 Which SwiftData schema would need a new version bump?
- Path-only move: no bump.
- Model rename/shape change: yes. Any change to `CaptainMemory`, `CaptainPersonalizationProfile`, `PersistentChatMessage`, `WeeklyMetricsBuffer`, `WeeklyReportEntry`, or `ConversationThreadEntry` would need a new Captain schema version above V3 (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV3.swift:9-18`).

#### 7.2.4 Which feature flags currently gate this system?
- `captain_memory_enabled` gates fact-memory behavior (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:22-31`).
- The memory-size tier policy is effectively gated by `AccessManager.captainMemoryLimit`, not a plist flag (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:73-80`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:17-19`).

### 7.3 Notification System
#### 7.3.1 What breaks if moved into `AiQo/Features/Captain/Brain/notifications/`
- Runtime should survive a path-only move once project references are updated.
- `Info.plist` identifiers and category names will not need changes unless symbol names or registration code change.
- Cross-system import pressure will remain because notifications currently reach into brain and memory singletons directly.

#### 7.3.2 Public APIs consumed from outside the three systems
- `SmartNotificationScheduler.shared` is called by `AppDelegate`, settings UI, onboarding, trial journey, premium-expiry scheduling, morning habit, sleep observer, and `NotificationService.sendImmediateNotification` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:124`, `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:148-150`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsScreen.swift:334-358`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Trial/TrialJourneyOrchestrator.swift:101-158`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/PremiumExpiryNotifier.swift:96`).
- `CaptainSmartNotificationService.shared` is used by `AppDelegate`, workout screen, and `HealthKitManager` (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:193`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Gym/WorkoutSessionScreen.swift.swift:285`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Shared/HealthKitManager.swift:344`).
- `MorningHabitOrchestrator.shared` and `SleepSessionObserver.shared` are both started from app lifecycle code and fed from alarm/wake flows (`/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift:139-141`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/AlarmSchedulingService.swift:189`).

#### 7.3.3 Which SwiftData schema would need a new version bump?
- Path-only move: no bump.
- If notification restructuring changes `ConversationThreadEntry` semantics or migrates notification history out of the Captain container, that would require a new Captain schema version beyond V3 (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV3.swift:9-18`).

#### 7.3.4 Which feature flags currently gate this system?
- `aiqo.notifications.enabled` is the functional master switch (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsStore.swift:14-39`).
- `notificationLanguage` controls language output (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsScreen.swift:13`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationLocalization.swift:3-10`).
- `CAPTAIN_BRAIN_V2_ENABLED` changes whether `ProactiveEngine` is even consulted (`/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift:95-98`).

## 8. Open Questions for Mohammed
1. **هل تريد Captain يكون فعلاً gated by tier؟** The code defines `canAccessCaptain` and `canReceiveCaptainNotifications`, but the runtime does not use them (`/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift:36-42`).
2. **شنو هو “source of truth” للـ brain?** Right now `BrainOrchestrator` and `CaptainIntelligenceManager` are both live inference paths.
3. Do you want one unified privacy boundary for every outbound AI request, including notification copy and kitchen flows, or is the legacy Arabic API path intentional?
4. Should `ConversationThreadEntry` live with memory or with notifications after the restructure? Today it belongs to both.
5. Should `MemoryStore` continue to own persisted chat transcript APIs, or should chat transcript persistence split out from long-term fact memory?
6. Is the Brain V2 proactive system supposed to be production-live, or still partially staged? Right now key proactive fields are mocked/hardcoded (`stepGoal`, `waterIntakePercent`, `isCurrentlyWorkingOut`, `trendSnapshot`) (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift:918-945`).
7. **هل salience intended missing؟** Retrieval scoring uses many signals, but there is no explicit “salience” field in `CaptainMemory`; if you want salience as a design concept, it is not modeled directly.
8. Are morning habit, sleep completion, workout summary, proactive nudges, and foreground inactivity notifications supposed to share one global budget, or keep separate budgets?
9. Should quiet hours come only from Captain personalization, or stay globally fixed at 23:00-07:00 when personalization is absent?
10. Which username keys are canonical? The repo currently uses both `captain_*` keys and `aiqo.captain.customization.*` keys.
11. Should `CaptainMemorySettingsView` “Clear All” clear only `CaptainMemory`, or truly wipe chat transcripts, personalization, weekly reports, and thread history too? Today it clears only `CaptainMemory` rows (`/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainMemorySettingsView.swift:53-58`, `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift:354-371`).
12. Are recurring angel-number notifications still a product requirement, or should the blueprint be updated to match the actual scheduler?
13. Do you want `Prompts.xcstrings` to own Captain prompt variants eventually, or is code-only prompt assembly the intended long-term design?
14. Should notification categories/actions be expanded for all recurring reminder categories, or are silent/passive categories intentional?
15. **شلون تريد weekly memory يعيش؟** Right now the weekly consolidation anchor starts from the last report or the free-trial start date, which couples weekly-memory cadence to monetization state (`/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift:23-26`).
16. Is `LocalIntelligenceService` meant to replace part of `LocalBrainService`, or can it be removed?
17. Is `CoachBrainMiddleware` still part of the future architecture, or should only its translator survive as a notification-translation helper?
18. Should workout-summary notifications continue using LLM-generated exact 20-word copy, or would deterministic local templates be safer for background execution?
19. **هل تريد Captain tab نفسه يفتح `CaptainScreen` أو مباشرة `CaptainChatView`؟** Today the main tab mounts `CaptainScreen`, and notification opens may jump to `CaptainChatView` through `AppRootManager`, so there are effectively two chat surfaces.
20. If you move everything under `AiQo/Features/Captain/Brain/<system>/`, do you want schema/model files to move too, or stay centralized under `/Core/Schema` and `/Core/Models` to preserve storage clarity?

## 9. Appendix: Full File Tree
Every file read for this audit, with line count:

| Lines | Path |
|---:|---|
| 846 | `/Users/mohammedraad/Desktop/AiQo/AiQo_Master_Blueprint_16.md` |
| 465 | `/Users/mohammedraad/Desktop/AiQo/AiQo/App/AppDelegate.swift` |
| 129 | `/Users/mohammedraad/Desktop/AiQo/AiQo/App/MainTabScreen.swift` |
| 335 | `/Users/mohammedraad/Desktop/AiQo/AiQo/App/SceneDelegate.swift` |
| 470 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsScreen.swift` |
| 45 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/AppSettingsStore.swift` |
| 62 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainMemory.swift` |
| 321 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainMemorySettingsView.swift` |
| 405 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainPersonalization.swift` |
| 228 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainVoiceAPI.swift` |
| 412 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/CaptainVoiceService.swift` |
| 190 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/HealthKitMemoryBridge.swift` |
| 341 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryExtractor.swift` |
| 690 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/MemoryStore.swift` |
| 26 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/ActivityNotification.swift` |
| 36 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/NotificationPreferencesStore.swift` |
| 42 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/WeeklyMetricsBuffer.swift` |
| 61 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Models/WeeklyReportEntry.swift` |
| 95 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Purchases/EntitlementStore.swift` |
| 66 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Purchases/SubscriptionTier.swift` |
| 24 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaMigrationPlan.swift` |
| 19 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV1.swift` |
| 20 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV2.swift` |
| 21 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/Schema/CaptainSchemaV3.swift` |
| 947 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Core/SmartNotificationScheduler.swift` |
| 132 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/AiQoPromptManager.swift` |
| 653 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/BrainOrchestrator.swift` |
| 79 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainAvatar3DView.swift` |
| 656 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainChatView.swift` |
| 480 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainCognitivePipeline.swift` |
| 402 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainContextBuilder.swift` |
| 212 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainFallbackPolicy.swift` |
| 916 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainIntelligenceManager.swift` |
| 487 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainModels.swift` |
| 80 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainNotificationRouting.swift` |
| 236 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift` |
| 81 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainPersonaBuilder.swift` |
| 537 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainPromptBuilder.swift` |
| 1265 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainScreen.swift` |
| 974 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CaptainViewModel.swift` |
| 158 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ChatHistoryView.swift` |
| 77 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CloudBrainService.swift` |
| 775 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CoachBrainMiddleware.swift` |
| 91 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/CoachBrainTranslationConfig.swift` |
| 209 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ConversationThread.swift` |
| 230 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/EmotionalStateEngine.swift` |
| 453 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/HybridBrainService.swift` |
| 425 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LLMJSONParser.swift` |
| 835 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LocalBrainService.swift` |
| 160 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/LocalIntelligenceService.swift` |
| 108 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/MessageBubble.swift` |
| 452 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PrivacySanitizer.swift` |
| 324 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ProactiveEngine.swift` |
| 137 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/PromptRouter.swift` |
| 52 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/ScreenContext.swift` |
| 128 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/SentimentDetector.swift` |
| 219 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/TrendAnalyzer.swift` |
| 54 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Captain/VibeMiniBubble.swift` |
| 218 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Features/Sleep/SleepSessionObserver.swift` |
| 91 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Info.plist` |
| 60 | `/Users/mohammedraad/Desktop/AiQo/AiQo/NeuralMemory.swift` |
| 243 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/AccessManager.swift` |
| 74 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/EntitlementProvider.swift` |
| 181 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Premium/FreeTrialManager.swift` |
| 39 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Resources/Prompts.xcstrings` |
| 127 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/DeepLinkRouter.swift` |
| 96 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMemoryConsolidator.swift` |
| 56 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Memory/WeeklyMetricsBufferStore.swift` |
| 11 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/NotificationType.swift` |
| 262 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/AlarmSchedulingService.swift` |
| 219 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift` |
| 21 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/InactivityTracker.swift` |
| 399 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/MorningHabitOrchestrator.swift` |
| 41 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationCategoryManager.swift` |
| 43 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationLocalization.swift` |
| 37 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationRepository.swift` |
| 1119 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/NotificationService.swift` |
| 107 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/PremiumExpiryNotifier.swift` |
| 78 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Notifications/SmartNotificationManager.swift` |
| 142 | `/Users/mohammedraad/Desktop/AiQo/AiQo/Services/Trial/TrialNotificationCopy.swift` |
