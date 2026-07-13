# AiQo — System Architecture

> The technical architecture of AiQo, for engineers and for AI agents reasoning about the system. Synthesized from a direct read of the iOS source (`AiQo/`), the Supabase Edge Functions (`supabase/functions/`), and `docs/ai-context/AiQo_AIContext_04_TechStack.md`.
>
> **Scope:** ~574 Swift files. iOS 26+ / watchOS. SwiftUI + SwiftData, async/await + actors. See [ARCHITECTURE_DIAGRAMS.md](../reports/ARCHITECTURE_DIAGRAMS.md) for visual diagrams.

---

## 1. High-level shape

```
┌─────────────────────────────────────────────────────────────┐
│  iOS App (SwiftUI, SwiftData)                                 │
│                                                               │
│  App entry (AiQoApp @main) ── SceneDelegate / AppDelegate     │
│        │                                                      │
│        ├── Features/* (Home, Captain, Gym, Kitchen, Sleep …)  │
│        ├── Captain "Brain" (on-device + cloud orchestration)  │
│        ├── Core (Purchases/Tiers, Config, Keychain, Models)   │
│        └── Services (HealthKit, Notifications, Analytics …)   │
│                                                               │
│  Persistence: SwiftData · UserDefaults · Keychain             │
└───────────────┬───────────────────────────────┬─────────────┘
                │ Supabase session JWT           │ on-device
                ▼                                ▼
┌──────────────────────────────┐   ┌───────────────────────────┐
│ Supabase Edge Functions       │   │ Apple Intelligence         │
│  • captain-chat → Gemini       │   │  (Foundation Models)       │
│  • captain-voice → MiniMax TTS │   │  sleep analysis, fallback  │
│  (server-held API keys)        │   └───────────────────────────┘
└───────────────┬───────────────┘
                ▼
   Google Gemini · MiniMax · (Supabase Postgres / Auth / Realtime)
```

---

## 2. App entry & composition

- **`AiQo/App/AppDelegate.swift`** holds both the `@main` SwiftUI `App` (`AiQoApp`) and the `UIApplicationDelegate`.
  - Builds the SwiftData container for Captain memory (with `SchemaV3→V4→V5` migration support).
  - Injects `CaptainViewModel` (the "globalBrain") as an environment root.
  - Initializes the memory stores (`MemoryStore`, `EpisodicStore`, `SemanticStore`, `ProceduralStore`, `EmotionalStore`, `RelationshipStore`, `DirectiveStore`).
  - Registers proactive triggers (sleep-debt, inactivity, PR, recovery, streak-risk, …).
- **`SceneDelegate.swift`** wires the `WindowGroup` → `AppRootView`, deep-link routing, and Spotify session.
- **Auth/onboarding entry:** `AuthFlowUI.swift`, `LoginViewController.swift`, `ProfileSetupView.swift`, `LanguageSelectionView.swift`.
- **Tab shell:** `MainTabScreen.swift` + `MainTabRouter.swift`.

---

## 3. Architecture pattern

- **MVVM, SwiftUI-first**, with a strong observation layer.
- Mix of **`@Observable`** (modern) and **`ObservableObject`** (legacy) for view models and stores.
- **Actors** isolate data stores and services (`HealthKitService`, memory stores) for thread safety.
- **Concurrency:** async/await throughout; `@MainActor` for UI; `Sendable` payloads across the cloud boundary.
- **Routing/DI:** environment injection (`@EnvironmentObject` / `.environment()`), shared singletons, and a `DeepLinkRouter` for URL schemes (`aiqo://`, `aiqo-spotify://`).

---

## 4. The Captain "Brain" (AI pipeline)

The most distinctive subsystem. Lives under **`AiQo/Features/Captain/Brain/`**, organized into numbered layers (`00_Foundation`, `01_Sensing`, `02_Memory`, `04_Inference`, `06_Proactive`, `11_Directives`, …).

**Request flow:**
```
User message
  → BrainOrchestrator.processMessage()      (04_Inference/BrainOrchestrator.swift)
      ├─ intent == .sleepAnalysis ──────────► LocalBrainService (on-device, Apple Intelligence)
      └─ .gym/.kitchen/.peaks/.myVibe/.chat ─► CloudBrainService
                                                  → PrivacySanitizer.sanitizeForCloud()
                                                  → PromptComposer (7-layer system prompt)
                                                  → HybridBrainService.generateReply()
                                                       → captain-chat Edge Function → Gemini
                                                  → LLMJSONParser → CaptainStructuredResponse
  → memory extraction + persistence
  → CaptainViewModel renders bubbles + structured cards
```

**Key files:**
| Concern | File |
|---|---|
| Routing & fallback | `04_Inference/BrainOrchestrator.swift` |
| Cloud path + privacy | `04_Inference/Services/CloudBrainService.swift` |
| On-device path | `04_Inference/Services/LocalBrainService.swift` + `CaptainOnDeviceChatEngine.swift` |
| Gemini transport | `04_Inference/Services/HybridBrain.swift` |
| Proxy config (paths/base URL) | `04_Inference/Services/CaptainProxyConfig.swift` |
| Model policy | `04_Inference/GeminiModelPolicy.swift` |
| Prompt assembly | `04_Inference/PromptComposer.swift`, `PromptRouter.swift`, `AiQoPromptManager.swift` |
| Response parsing | `04_Inference/LLMJSONParser.swift`, `CaptainModels.swift` |
| Tier gate | `00_Foundation/TierGate.swift` |
| Directives | `11_Directives/{DirectiveStore,DirectiveEngine,DirectiveLearner,DirectiveCoordinator}.swift` |

**Memory (`02_Memory/`):** five SwiftData-backed stores — **Episodic** (full exchanges), **Semantic** (durable facts + embeddings, cloud-safe), **Procedural** (learned patterns), **Emotional** (mood snapshots), **Relationship** (people). An `EmbeddingIndex` + `SalienceScorer` + `TemporalIndex` power hybrid (lexical + semantic) RAG. `ConversationCompactor` folds long chats into a `ConversationDigest` carried in `conversationState`.

**Routing rule of thumb:** *sleep stays on-device, everything else may go to the cloud — and the cloud path is always sanitized first.*

---

## 5. Backend — Supabase Edge Functions (the entire server API surface)

Only two live functions, both thin **secure proxies** (Deno):

| Function | Upstream | Auth | Guards |
|---|---|---|---|
| **`captain-chat`** | Google Gemini `generateContent` | Supabase JWT (validated in-function) | model allowlist (`gemini-2.5-flash`, `gemini-3-flash-preview`); 256 KB body cap; server-held `GEMINI_API_KEY` |
| **`captain-voice`** | MiniMax TTS | Supabase JWT | model allowlist; 16 KB body cap; server-held `MINIMAX_API_KEY` |

Shared helpers: `_shared/auth.ts` (JWT validation via `supabase.auth.getUser`) and `_shared/cors.ts`. Deployed with `--no-verify-jwt` so each function can return custom error codes after validating the JWT itself.

**Why this matters for GPT integration:** these functions are **app-only** — they require a first-party session JWT and are opaque model proxies. They are deliberately **not** suitable as OpenAI Actions. The public GPT surface is a separate knowledge API (see [GPT_INTEGRATION_GUIDE.md](GPT_INTEGRATION_GUIDE.md)).

Other Supabase usage: **Auth** (Sign in with Apple relay), **Postgres** (`profiles`, arena/tribe tables), and a `validate-receipt` function for non-blocking server-side receipt checks.

---

## 6. HealthKit

- **`AiQo/Services/Permissions/HealthKit/HealthKitService.swift`** — actor-based singleton.
  - **Reads:** stepCount, heartRate, restingHeartRate, HRV (SDNN), activeEnergyBurned, distanceWalkingRunning, dietaryWater, VO₂max, sleepAnalysis, appleStandHour, workouts.
  - **Writes:** water, heart rate, HRV, VO₂, distance, workouts.
  - **Background delivery** via `HKObserverQuery`; caches a snapshot and debounces widget reloads.
- **`SleepSessionProvider.swift`** — queries sleep stages; sleep data is processed on-device only.
- Apple Watch uses `HKWorkoutSession` for live workouts.

---

## 7. Purchases & tiers

- **`Core/Purchases/SubscriptionTier.swift`** — `enum SubscriptionTier: Int { none=0, max=1, trial=2, pro=3 }`. Tier-scaled capacity (memory limit, max proactive notifications, token budget). **`.max` is the entry paid tier, `.pro` is the top** — compare by raw value, never by name.
- **`EntitlementStore.swift`** — persists `activeProductId` + `expiresAt`, computes `currentTier` synchronously (readable from any context).
- **`PurchaseManager.swift`** — StoreKit 2 transaction listener + entitlement sync; **`ReceiptValidator.swift`** does non-blocking server validation (client remains source of truth).
- **`TierGate.shared.canAccess(_:)`** — the single feature gate (e.g. `.captainChat`, `.multiWeekPlan`, `.photoAnalysis`).

---

## 8. Services

| Service | Role | Provider |
|---|---|---|
| Analytics | event tracking (50+ events) | local JSONL today; remote (Mixpanel/PostHog) planned |
| CrashReporting | crash + error capture | Crashlytics wrapper (SDK link deferred; local JSONL fallback) |
| Location | outdoor-run GPS, route snapshots | CoreLocation / MapKit |
| Notifications | local + proactive Captain pushes | UserNotifications + BackgroundTasks |
| Permissions | HealthKit + AI-data consent gating | HealthKit, `AIDataConsentManager` |
| Trial | trial eligibility, journey, expiry | `FreeTrialManager`, `TrialJourneyOrchestrator` |

---

## 9. Data persistence

| Store | Tech | Scope |
|---|---|---|
| Captain memory (5 stores) | SwiftData (`captain_memory.store`) | device-local, versioned schema |
| Daily records, workouts, quests, arena | SwiftData (shared container) | device-local |
| Chat history / threads | SwiftData (`PersistentChatMessage`) | per session |
| User profile | Supabase `profiles` + local cache | cloud-synced |
| Entitlements / trial | UserDefaults + Supabase | local + server |
| Secrets (voice consent, tokens) | Keychain | device-local |
| Preferences, onboarding flags | UserDefaults | device-local |

---

## 10. Watch & widgets

- **Watch app** (`AiQoWatch Watch App/`): `WorkoutManager` (HKWorkoutSession), `WatchConnectivityManager` (phone↔watch sync), session/metrics/summary views, activity rings.
- **Widgets** (`AiQoWidget/`, `AiQoWatchWidget/`): home-screen widget, watch-face rings/complications, Live Activities (Dynamic Island), hydration quick actions.

---

## 11. Tech stack summary

- **Language/UI:** Swift 5, SwiftUI (+ minimal UIKit interop), SwiftData, Swift Package Manager.
- **Apple frameworks:** HealthKit, StoreKit 2, UserNotifications, BackgroundTasks, AVFoundation, Speech, AuthenticationServices, WatchConnectivity, RealityKit, FoundationModels (Apple Intelligence), AlarmKit, AppIntents/SiriKit, WidgetKit, Vision, NaturalLanguage, WeatherKit, MapKit/CoreLocation.
- **Cloud/3rd-party:** Google Gemini (chat), MiniMax (premium voice), Supabase (auth/DB/edge/realtime), Spotify iOS SDK (My Vibe). Firebase Crashlytics wrapper present (SDK link deferred).
- **Build:** Xcode; secrets injected from `Configuration/Secrets.xcconfig` (gitignored) into Info.plist at build time; feature flags as Info.plist booleans + remote kill switches.

---

## 12. Notable design decisions

1. **Server-side keys.** Gemini/MiniMax keys moved off the client into Edge Functions (no key in the IPA).
2. **On-device privacy boundary.** Sleep never leaves the device; PII is sanitized before the cloud; health metrics are exact (not bucketed) as of v1.0.6.
3. **Two tiers, not three** (plus trial). Legacy enum values retained for back-compat.
4. **Apple-native everything** — the deep Apple-framework dependency is the reason AiQo is iOS-only.
5. **Hybrid brain with a fallback chain** — cloud → on-device → localized offline message, so the Captain always responds.
