# AiQo Master Blueprint 17

*The single document that explains the AiQo iOS app — what it is, how it is built, and how every part fits together. Replaces all prior `AiQo_Master_Blueprint_*` files. Author: Mohammed Raad. Snapshot taken at commit `fa27a7f` on 2026-04-19. **Updated 2026-04-20** with the App Store submission hardening pass — see §21 for the full change-list (age gate, permission descriptions, EXIF/FileProtection on certificate storage, reduceTransparency helper, Info.plist cleanup, and a clean 0-warning Release build). **Updated 2026-04-22** with the Smart Water Tracking & Reminders feature — see §22 for the full build: pure evaluator, pace-based reminders through NotificationBrain, WHO/EFSA guidance UI, 4-surface system integration (Captain Memory / Medical Disclaimer / AI Data disclosure / Privacy Policy), and a systemSmall interactive Home Screen widget with a race-free tap-counter drain path. **Updated 2026-04-22 (same-day pass 2)** with the Water Detail Sheet hero redesign — see §23 for the brand-consistency pass: the photographic bottle illustration and saturated-blue "+0.25 L" pill are replaced by a pure-SwiftUI mint/sand progress ring, a three-chip quick-add row with haptics, and a nested custom-amount slider sheet. Adds `AiQoColors.mintSoft` / `.sandSoft` as reusable brand accents. Zero-warning build preserved.*

---

## 1. Executive Summary

AiQo is an Arabic-first iOS health-and-coaching app whose differentiator is **Captain Hamoudi (الكابتن حمودي)** — a culturally-rooted AI coach with on-device memory, dialect-aware language, and a wellbeing safety net. AiQo v1.0 has been submitted to the App Store; v1.0.1 (this branch) introduces the new "Brain OS" — eleven subsystems that move the Captain from a stateless prompt-and-reply chat to a system that senses bio context, remembers across conversations, classifies intent and emotion locally, talks in the user's dialect, and refuses to act when a crisis is detected.

The codebase totals **116,767 Swift LOC across the app target** and **5,138 Swift LOC across the test target**, with **368 unit tests** *(snapshot figures at commit `fa27a7f`; post-2026-04-20 the Brain shrank by 3 stub files — see §21.6)*. The Brain OS lives at [AiQo/Features/Captain/Brain/](AiQo/Features/Captain/Brain) and is partitioned into 11 numbered subsystems (`00_Foundation` through `10_Observability`) totaling **131 Swift files** — a mix of full implementations and a small number of placeholder stubs left from the original scaffold.

Three things to know before reading further:

1. **The Brain has eleven subsystems but they form one pipeline.** A user message flows Sensing → Memory → Reasoning → Inference (cloud or on-device LLM) → Persona → Privacy → Wellbeing → reply. Proactive notifications run a parallel pipeline driven by Triggers and gated by GlobalBudget.
2. **Privacy is enforced at the boundary, not by convention.** Every outbound LLM call passes through `PrivacySanitizer` (PII redaction + numeric bucketing + 4-message conversation cap) and is recorded in an on-device `AuditLogger` ring. The audit metric on Brain subfolders is real: `00`, `01`, `03`, `05`, `06`, `07`, `08`, `10` have **zero** outbound HTTP references; the only legitimate cloud caller is `04_Inference/Services/HybridBrain.swift`. (One legacy file in `02_Memory` still has two URLSession references — flagged in §16.)
3. **Tier and DevOverride are the two switches that matter.** `TierGate.shared` is the single gate for paid features; `DevOverride.unlockAllFeatures` (DEBUG-only, Info.plist `AIQO_DEV_UNLOCK_ALL`) bypasses every gate so Mohammed can develop without paying his own paywall. Of the **46 `canAccess` call sites**, **43 are wrapped with the DevOverride bypass pattern**.

---

## 2. Product Overview

### 2.1 Purpose & Audience

AiQo is built for Arabic-speaking adults (initially in the UAE, Saudi Arabia, and Iraq) who want a daily coach that meets them in their language and culture rather than translating Silicon Valley wellness tropes. Generic health apps assume Anglophone users with Western calendars; AiQo treats Iraqi as the default dialect, recognises Ramadan / Eid / Jumu'ah from the Hijri calendar, and shapes its tone and humour accordingly.

The app spans:
- **Captain** — the chat coach (cloud LLM + on-device fallback)
- **Gym** — workouts, quests, the Club, and Legendary Challenges
- **Kitchen** — meal logging, smart fridge scanner, meal plans
- **Sleep** — sleep analysis (on-device Apple Intelligence path)
- **MyVibe** — Spotify-blended music for workouts and focus
- **Tribe** — social/community surfaces (currently feature-flagged off)
- **WeeklyReport** — narrative summaries (Pro tier)

### 2.2 Subscription Tiers

Two paid tiers, persisted via UserDefaults key `aiqo.purchases.currentTier` and re-derived on every StoreKit transaction by `EntitlementStore`:

| Tier | Product ID | Price (fallback) | Memory facts | Daily notifications | Memory retrieval depth | Pattern window | Gemini context |
|---|---|---|---|---|---|---|---|
| `.none` | — | — | 50 | 2 | 5 | 14 days | 2 KB |
| `.max` | `com.mraad500.aiqo.max` | $9.99 | 200 | 4 | 10 | 14 days | 8 KB |
| `.pro` (Intelligence Pro) | `com.mraad500.aiqo.intelligence.pro` | $19.99 | 500 | 7 | 25 | 56 days | 32 KB |
| `.trial` | — | — | (= Pro) | (= Pro) | (= Pro) | (= Pro) | (= Pro) |

`.trial` is ranked equivalent to `.pro` via [SubscriptionTier.swift:18](AiQo/Core/Purchases/SubscriptionTier.swift:18) so trial users get full Pro-tier capacity. Several legacy product IDs (`aiqo_core_monthly_9_99`, `aiqo_pro_monthly_19_99`, `aiqo_intelligence_monthly_39_99`, etc.) are kept in [SubscriptionProductIDs.swift](AiQo/Core/Purchases/SubscriptionProductIDs.swift) only to grandfather older entitlements; the live App Store catalogue uses just the two current IDs.

### 2.3 Current Market Status

AiQo v1.0 was submitted to the App Store earlier in April 2026. The launch anchor is the UAE — specifically a partnership with the American University of the Emirates. The v1.0.1 build (this branch, `brain-refactor/p-fix-dev-override`) is local and not yet on TestFlight; it adds the entire Brain OS (BATCHES 1–8) on top of the v1.0 surface. Region detection in `ProfessionalReferral.detectRegion(locale:)` already supports `.uae`, `.saudi`, `.iraq`, `.gulfOther`, and `.global` for the wellbeing surface.

### 2.4 Content Philosophy

The Captain's identity is encoded in [CaptainIdentity.swift](AiQo/Features/Captain/Brain/08_Persona/CaptainIdentity.swift):

- **Name:** حمودي (Hamoudi)
- **7 traits:** warm, direct, witty, protective, observant, humble, culturally_rooted
- **6 values:** honesty_over_comfort, user_wellbeing_over_engagement, respect_for_culture, privacy_sacred, consent_first, no_medical_claims
- **5 forbidden patterns** (hard-blocked by `PersonaGuard`): "you should", "you must", "I know how you feel", "everything happens for a reason", "just be positive"

What the Captain refuses:
- Medical claims or diagnoses
- Pressuring language ("you must", "you should")
- Toxic positivity ("just be positive", "everything happens for a reason")
- Emoji on non-celebration notifications (only PR / Eid / achievement allowed)
- Profanity (English) and haram-content references (alcohol / gambling / porn in AR or EN)

---

## 3. Brain OS Architecture

### 3.1 Overview Diagram

```
                          ┌──────────────────────────┐
                          │         User Turn         │
                          └────────────┬─────────────┘
                                       │
                          ┌────────────▼─────────────┐
                          │  CaptainViewModel.send   │
                          └────────────┬─────────────┘
                                       │
                          ┌────────────▼─────────────┐
                          │ BrainOrchestrator        │  04_Inference
                          │ .processMessage(_:)      │
                          └─┬─────┬──────┬───────┬───┘
                            │     │      │       │
              ┌─────────────┘     │      │       └──────────────┐
              ▼                   ▼      ▼                      ▼
   ┌──────────────────┐  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐
   │ CrisisDetector   │  │ TierGate     │  │ Route       │  │ Personalize  │
   │ + InterventionPolicy │  .canAccess │  │ (.local /   │  │ + Safety     │
   │  09_Wellbeing    │  │  00_Foundation│  │  .cloud)    │  │  decision    │
   └────────┬─────────┘  └──────┬───────┘  └──────┬──────┘  └──────┬───────┘
            │                   │                  │                │
            ▼                   ▼                  ▼                ▼
   ┌────────────────────┐  (block)         ┌────────────┐   ┌────────────────┐
   │ SafetyNet ring     │                  │ HybridBrain│   │ Reply to user  │
   │ (50 signals)       │                  │ (Gemini)   │   └────────────────┘
   └────────────────────┘                  │ 04_Infer.  │
                                           └─────┬──────┘
                                                 │
                                  ┌──────────────┴──────────────┐
                                  ▼                              ▼
                   ┌────────────────────────┐     ┌────────────────────────┐
                   │ PromptComposer         │     │ persistIfMemoryEnabled │
                   │ + PrivacySanitizer     │     │  → EpisodicStore       │
                   │ + AuditLogger          │     │  → FactExtractor task  │
                   │  04 / 05               │     │  → SemanticStore       │
                   └────────────────────────┘     │  02_Memory             │
                                                  └────────────────────────┘

                  ─── Proactive notifications run a parallel loop ───

   ┌──────────────────┐    ┌────────────────────┐    ┌────────────────────┐
   │ BGTask 03:00     │ →  │ EmotionalMiner +   │    │ TriggerEvaluator   │
   │ aiqo.brain.nightly│   │ BehavioralObserver │    │  .evaluateAll()    │
   └──────────────────┘    │  02 / 01           │    │  06_Proactive      │
                           └─────────┬──────────┘    └─────────┬──────────┘
                                     ▼                          ▼
                           ┌─────────────────────┐    ┌──────────────────┐
                           │ EmotionalStore /    │    │ 15 Triggers run  │
                           │ ProceduralStore     │    │ in parallel,     │
                           └─────────────────────┘    │ winner picked by │
                                                      │ priority × score │
                                                      └─────────┬────────┘
                                                                ▼
                                              ┌──────────────────────────┐
                                              │ NotificationBrain.request│
                                              │  → GlobalBudget          │
                                              │  → MessageComposer       │
                                              │  → PersonaAdapter / Guard│
                                              │  → PrivacySanitizer      │
                                              │  → UNUserNotificationCtr │
                                              │  → AuditLogger           │
                                              │  06_Proactive            │
                                              └──────────────────────────┘
```

### 3.2 Subsystem Reference

Note on file counts: each subsystem includes a small number of single-line stub files left over from the original 91-stub scaffold (commit `874c683`, P1.1). Stubs are listed where present so the file count matches what is on disk; their sole symbol is an empty `enum` / `struct` / `class` body.

---

#### 3.2.1 Brain/00_Foundation

**Purpose:** The bedrock — tier gating, debug bypass, error type, the locked-feature view, and the per-process diagnostic logger. Everything else in Brain depends on this layer.

**Files (6):**
- `BrainBus.swift` [28L] — `public actor BrainBus` placeholder for cross-subsystem messaging.
- `BrainError.swift` [30L] — `enum BrainError: LocalizedError` with `tierLocked`, `consentRequired`, `unsupportedDevice`.
- `CaptainLockedView.swift` [126L] — RTL glassmorphism upgrade card; callers supply `onUpgradeTap` so the view never imperatively presents a paywall.
- `DevOverride.swift` [46L] — Reads `AIQO_DEV_UNLOCK_ALL` from Info.plist on every call. Hard-coded to `false` in RELEASE builds via `#if DEBUG`. Logs a banner at launch via `warnIfActive()`.
- `DiagnosticsLogger.swift` [56L] — Process-wide `diag` global (`final class DiagnosticsLogger: @unchecked Sendable`). Wraps `os.Logger` plus tier-gate decision logging.
- `TierGate.swift` [208L] — `final class TierGate: @unchecked Sendable`. Singleton `TierGate.shared`. The single source of truth for "is this paid feature accessible right now."

**Public API highlights:**
- `TierGate.shared.currentTier` → `SubscriptionTier`
- `TierGate.shared.canAccess(.captainChat)` → `Bool` (logged via `diag.logTierGate`)
- `TierGate.shared.requiredTier(for: .captainMemory)` → `SubscriptionTier`
- `DevOverride.unlockAllFeatures` → `Bool` (the bypass)

**Batch provenance:** Scaffolded in P1.1 (`874c683`). TierGate hardened in P1.3 (`7dd648d`). DevOverride bypass wrapped at 9 sites in BATCH 1b (`b2e776d`); CaptainLockedView polished + paywall hook in BATCH 1c (`63d2cda`).

**Dependencies:** Reads `aiqo.purchases.currentTier` UserDefaults (written by `EntitlementStore`) and `FreeTrialManager.isTrialActiveSnapshot`.

**Flags / knobs:** Info.plist `AIQO_DEV_UNLOCK_ALL` (currently `true` in this branch).

---

#### 3.2.2 Brain/01_Sensing

**Purpose:** All sensor reads — HealthKit, weather, music — hidden behind small actors that bucket and cache. The contract: nothing else in Brain ever calls `HKHealthStore` directly.

**Files (9):**
- `BehavioralObserver.swift` [128L] — `actor BehavioralObserver`. Mines ProceduralPattern candidates from session events.
- `BioStateEngine.swift` [121L] — `actor BioStateEngine`. The unified read API. 3-minute (`freshnessWindow: 180`) cache. Injectable `MetricsFetcher` closure (added in BATCH 3 fixup `c0435a0` for testability).
- `CaptainHealthSnapshotService.swift` [406L] — Underlying HealthKit pull. Returns `CaptainDailyHealthMetrics` (steps, calories, HR, sleep). The fetcher BioStateEngine calls by default.
- `CircadianReasoner.swift` [7L] — Stub.
- `ContextSensor.swift` [47L] — `actor ContextSensor` capturing screen + idle state.
- `HealthKitBridge.swift` [235L] — `actor HealthKitBridge` plus `struct HealthKitMemoryBridge` typed adapter.
- `MusicBridge.swift` [27L] — `enum MusicBridge` stub returning nil (placeholder for richer music context).
- `SignalBus.swift` [7L] — Stub.
- `WeatherBridge.swift` [29L] — `enum WeatherBridge` stub returning nil.

**Public API highlights:**
- `BioStateEngine.shared.current() async -> BioSnapshot`
- `BioStateEngine.shared.refresh()` — bypasses cache for crisis / trigger eval.
- `BioStateEngine.shared.needsRecovery() async -> Bool` — true when `hrv < 30` or `sleep < 6.0`.

**Batch provenance:** BATCH 3 wrote all of this. 3a wired persistence (`5fafd33`), 3b unified the HealthKit read (`3684a5e`), 3c added BehavioralObserver / ContextSensor / nightly BGTask (`8b8e29e`), 3d added typed bridges (`6f9281a`).

**Dependencies:** HealthKit, Calendar.

**Flags / knobs:** Bucket sizes hard-coded (steps 500, HR 5, sleep 0.5h, calories 10). HRV is currently always nil because `CaptainDailyHealthMetrics` does not yet expose HRV.

---

#### 3.2.3 Brain/02_Memory

**Purpose:** Five SwiftData stores plus three intelligence components plus retrieval. This is where the Captain "remembers."

**Files (37):** Split across `Models/`, `Services/`, `Intelligence/` and the legacy `MemoryStore.swift`.

The five stores (all `actor` types):

| Store | File | Lines | Underlying `@Model` |
|---|---|---|---|
| `EpisodicStore` | EpisodicStore.swift | 588 | `EpisodicEntry` |
| `SemanticStore` | SemanticStore.swift | 624 | `SemanticFact` |
| `ProceduralStore` | ProceduralStore.swift | 240 | `ProceduralPattern` |
| `EmotionalStore` | EmotionalStore.swift | 240 | `EmotionalMemory` |
| `RelationshipStore` | RelationshipStore.swift | 205 | `Relationship` |

The three intelligence components:
- `MemoryRetriever.swift` [142L] — `actor MemoryRetriever`. Tier-aware unified RAG; budget split is fixed at facts 40% / episodes 25% / patterns 15% / emotions 10% / relationships 10%. Recency uses 30-day half-life.
- `EmotionalMiner.swift` [90L] — `actor EmotionalMiner`. Daily on Pro, weekly on Max, never on Free.
- `FactExtractor.swift` [180L] — `actor FactExtractor`. On-device only (heuristic + optional Foundation Models on iOS 26+).

Plus three foundational types:
- `MemoryBundle.swift` [33L] — return type of `MemoryRetriever.retrieve`.
- `EmbeddingIndex.swift` [85L] — `public actor EmbeddingIndex` wrapping `NLEmbedding` for Arabic + English.
- `SalienceScorer.swift` [56L] — `public enum SalienceScorer`. Heuristic salience [0,1].
- `TemporalIndex.swift` [66L] — `public actor TemporalIndex` for time-window queries.

Models layer (all `@Model`): `EpisodicEntry`, `SemanticFact`, `ProceduralPattern`, `Relationship`, `EmotionalMemory`, `EmotionKind` (enum, 16 cases), `BioSnapshot` (struct), `WeeklyMetricsBuffer`, `WeeklyReportEntry`, `MonthlyReflection`, `ConsolidationDigest`, `CaptainMemory` (legacy), `CaptainMemorySnapshot`.

Schema versioning: `CaptainSchemaV1` (19L), `CaptainSchemaV2` (20L), `CaptainSchemaV3` (21L), `MemorySchemaV4` (25L), all gathered by `CaptainSchemaMigrationPlan` (269L). V1→V2 and V2→V3 are lightweight; V3→V4 is custom (rebuilds facts and episodes from the legacy `CaptainMemory` store).

`MemoryStore.swift` (1312L) is the legacy V3 store — still active when `MEMORY_V4_ENABLED` is `false` (the current Info.plist default).

`MemoryExtractor.swift` (347L) is older code retained for a Gemini-based fact-extraction path; **this file is the only place in the entire Brain folder that holds outbound HTTP references** (URLSession at line 244, Gemini endpoint at line 320), wrapped in `PrivacySanitizer`. See §16 for the cleanup plan.

**Public API highlights:**
- `MemoryRetriever.shared.retrieve(query:bioContext:tier:customLimit:) async -> MemoryBundle`
- `EpisodicStore.shared.record(userMessage:captainResponse:) async -> UUID?`
- `SemanticStore.shared.addOrReinforce(content:category:confidence:source:isPII:isSensitive:relatedEntryIDs:) async -> UUID?`
- `EmotionalStore.shared.unresolvedEmotions(olderThan:minIntensity:limit:)`
- `RelationshipStore.shared.recentlyMentioned(in:within:)`

**Batch provenance:** P2.2 introduced the first store actors. BATCH 1a relocated the V4 Models into `02_Memory/Models/` (`63a910e`). BATCH 2a wrote EmbeddingIndex / SalienceScorer / TemporalIndex (`1440ce2`); BATCH 2b wrote MemoryRetriever + MemoryBundle (`815c27f`); BATCH 2c wrote FactExtractor + EmotionalMiner (`0d4abd0`).

**Dependencies:** SwiftData, NaturalLanguage, optional Foundation Models.

**Flags / knobs:** `MEMORY_V4_ENABLED` (Info.plist) — currently `false`; when `false`, the V4 stores are never configured and the legacy V3 path is used. `TierGate` caps drive every limit.

---

#### 3.2.4 Brain/03_Reasoning

**Purpose:** Pure cognition — emotion, intent, culture, persona compilation, sentiment. No I/O. No network. Runs entirely on-device.

**Files (13):**
- `CaptainContextBuilder.swift` [402L] — `enum BioTimePhase` + `struct CaptainContextData` + `struct CaptainSystemContextSnapshot`. Compiles bio + memory + persona into a context blob.
- `CognitivePipeline.swift` [480L] — `enum CaptainMessageIntent` + `enum CaptainEmotionalSignal` + `enum CaptainCognitiveTextAnalyzer`. The legacy on-device cognition pipeline.
- `ContextualPredictor.swift` [69L] — `actor ContextualPredictor`. Predicts upcoming user need.
- `CulturalContextEngine.swift` [102L] — `enum CulturalContextEngine`. Stateless. Detects Ramadan + fasting hour, Jumu'ah, Eid (al-Fitr / al-Adha) via Hijri calendar (`islamicUmmAlQura`), Gulf weekend (Fri-Sat), region.
- `EmotionalEngine.swift` [230L] — `enum EstimatedMood` + `struct EmotionalState`. Legacy types.
- `EmotionalEngineAPI.swift` [120L] — `actor EmotionalEngine` — façade exposing `currentReading() async -> EmotionalReading`.
- `EmotionalReading.swift` [44L] — `struct EmotionalReading`. Carries `primary: EmotionKind`, `intensity` 0-1, `confidence` 0-1, `trend: .improving/.declining/.stable/.volatile/.unknown`, optional signals.
- `IntentClassifier.swift` [152L] — `enum IntentClassifier` + `struct IntentReading`. **Crisis-first** ordering — crisis markers (EN + AR) checked before anything else with confidence 0.95.
- `PersonaAdapter.swift` [142L] — `actor PersonaAdapter`. Compiles `PersonaDirective` from emotion + culture; extension exposes `richDirective(...) async -> RichDirective` (adds humor + wisdom + system prompt).
- `PersonaDirective.swift` [39L] — Tone enum: `warm`, `gentle`, `celebratory`, `concerned`, `reflective`, `encouraging`.
- `ScreenContext.swift` [52L] — `enum ScreenContext`: `gym`, `kitchen`, `peaks`, `myVibe`, `mainChat`, `sleepAnalysis`.
- `SentimentDetector.swift` [128L] — `final class SentimentDetector: Sendable`. Wraps `NLTagger` for sentiment.
- `TrendAnalyzer.swift` [219L] — Trend / streak momentum types over a metric window.

**Public API highlights:**
- `EmotionalEngine.shared.currentReading() async -> EmotionalReading`
- `IntentClassifier.classify(_ text: String) -> IntentReading`
- `CulturalContextEngine.current(now:) -> State`
- `PersonaAdapter.shared.richDirective(emotion:cultural:userDialect:) async -> RichDirective`

**Batch provenance:** BATCH 4. 4a added EmotionalEngine + EmotionalReading (`6b804df`); 4b added CulturalContextEngine + PersonaAdapter (`899545e`); 4c added IntentClassifier + ContextualPredictor (`572394d`).

**Dependencies:** NaturalLanguage, Calendar (`islamicUmmAlQura`).

**Flags / knobs:** None. Pure computation.

---

#### 3.2.5 Brain/04_Inference

**Purpose:** Routing, prompt assembly, and the LLM call itself. The only Brain layer that reaches the network — everything else is on-device.

**Files (13):**
- `BrainOrchestrator.swift` [846L] — The conductor. `processMessage(request:userName:)` is the public entry. Branches by `route(for:)` → `.local` / `.cloud`. Hosts `persistIfMemoryEnabled` (BATCH 3a wiring) which writes to EpisodicStore + spawns the FactExtractor `Task.detached`.
- `CaptainModels.swift` [487L] — `final class PersistentChatMessage`, `struct ChatSession`, `struct CaptainStructuredResponse`.
- `LLMJSONParser.swift` [425L] — `struct LLMJSONParser`. Robust JSON extraction from messy LLM output.
- `PromptComposer.swift` [537L] — `struct PromptComposer`. Assembles system prompt + memory bundle + user message.
- `PromptRouter.swift` [137L] — `struct PromptRouter`. Picks the prompt template for a given screen context.
- `RoutingPolicy.swift` [7L] — Stub.
- Subdir `Services/`:
  - `CloudBrain.swift` [145L] — `struct CloudBrainService`. Wraps the Gemini call, applies sanitizer, records audit entry.
  - `FallbackBrain.swift` [212L] — `enum CaptainFallbackPolicy`. Canned replies for offline / blocked paths.
  - `HybridBrain.swift` [486L] — Conversation types, `struct HybridBrainService`. **Holds the only legitimate Gemini endpoint reference** (`https://generativelanguage.googleapis.com/v1beta/models`). Dedicated `URLSession` for resource timeout (35s).
  - `LocalBrain.swift` [835L] — On-device path using Foundation Models when available (iOS 26+).
- Subdir `Validation/`:
  - `CulturalValidator.swift` [7L] — Stub.
  - `PersonaGuard.swift` [66L] — `enum PersonaGuard`. Last-line safety net before notification delivery; checks forbidden patterns, emoji policy, length (title ≤65, body ≤180), profanity, haram content.
  - `ResponseValidator.swift` [7L] — Stub.

**Public API highlights:**
- `BrainOrchestrator().processMessage(request:userName:) async throws -> HybridBrainServiceReply`
- `PersonaGuard.validate(title:body:kind:) -> PersonaGuard.Result`

**Batch provenance:** Pre-existed (was the original Captain pipeline); BATCH 3a inserted the `persistIfMemoryEnabled` calls at five success sites; BATCH 8a added the `CrisisDetector` / `SafetyNet` hooks at the top of `processMessage`; BATCH 7c added `PersonaGuard` (`35cb726`).

**Dependencies:** Foundation Models (optional), URLSession, all of `02_Memory`, all of `03_Reasoning`, `05_Privacy`.

**Flags / knobs:** Cloud-route uses `TierGate.canAccess(.captainChat)` (bypassed by DevOverride). Sleep-context queries are forced local via `interceptSleepIntent`.

---

#### 3.2.6 Brain/05_Privacy

**Purpose:** Sanitization and audit. The boundary that ensures no PII or unbucketed health value leaves the device, and that every cloud call is recorded with metadata only.

**Files (5):**
- `AuditLogger.swift` [106L] — `actor AuditLogger`. On-device-only ring buffer of 500 entries persisted to `~/Documents/brain_audit.log.json`. Records destination, tier, prompt/response byte counts, latency, consent state, outcome — never content.
- `ConsentGate.swift` [7L] — Stub (consent is currently checked by `AICloudConsentGate` in `AiQo/Services/Permissions/AIDataConsentManager.swift`).
- `DataClassifier.swift` [7L] — Stub.
- `DifferentialPrivacy.swift` [7L] — Stub.
- `PrivacySanitizer.swift` [658L] — `struct PrivacySanitizer`. Applies PII redaction (emails, phones, UUIDs, URLs, @mentions, long numeric sequences), normalises user names to "User", truncates conversations to the last 4 messages, buckets numeric values, and strips EXIF/GPS from kitchen images.

**Public API highlights:**
- `PrivacySanitizer().sanitizeText(_ text: String, knownUserName: String?) -> String`
- `AuditLogger.shared.record(_ entry: Entry)`
- `AuditLogger.shared.recentEntries(limit:) -> [Entry]`

**Batch provenance:** P0.3 hardened the regexes (`f431f30`); BATCH 0 of the broader Brain refactor introduced `AuditLogger`. PrivacySanitizer also includes a regex-fix history (2026-04-08 patch documented in code) for catastrophic backtracking on phone-number and long-numeric patterns.

**Dependencies:** CoreGraphics, ImageIO, UniformTypeIdentifiers, os.log.

**Flags / knobs:** `AUDIT_LOGGER_VERBOSE` (Info.plist) controls extra logging.

---

#### 3.2.7 Brain/06_Proactive

**Purpose:** Everything notification-related, post-NotificationBrain. The "single door" architecture — every outbound notification in AiQo flows through `NotificationBrain.shared.request(_:...)`.

**Files (26):**

Top-level:
- `NotificationBrain.swift` [268L] — `public actor NotificationBrain`. The single door. Four gates: budget (GlobalBudget), composition (MessageComposer + PersonaAdapter), persona safety (PersonaGuard), schedule (UNUserNotificationCenter).
- `ProactiveEngine.swift` [324L] — Legacy proactive decision types (`ProactiveDecision`, `ProactivePriority`, `ProactiveContext`).
- `SmartNotificationScheduler.swift` [947L] — Legacy heuristic scheduler retained for back-compat.

Subdir `Budget/`:
- `GlobalBudget.swift` [99L] — `public actor GlobalBudget`. Reserves 4 of iOS's 64-pending slots; reads daily cap from `SubscriptionTier.dailyNotificationBudget`; allows critical priority to override the daily cap by one.
- `CooldownManager.swift` [51L] — `public actor CooldownManager`. Global 2h cooldown between any two notifications; per-kind 6h cooldown.
- `QuietHoursManager.swift` [42L] — `public actor QuietHoursManager`. Default 22:00–07:00 local, configurable.

Subdir `Composition/`:
- `MessageComposer.swift` [183L] — `public actor MessageComposer`. Two paths: `compose(...)` (template fallback) and `composeRich(...)` (template + dialect phrase + tone lead + humor flourish + wisdom append).
- `TemplateLibrary.swift` [108L] — `public enum TemplateLibrary`. Bilingual (AR/EN) templates for ~17 NotificationKinds with default catch-all.
- `DynamicPersonalizer.swift` [7L] — Stub.
- `NotificationDelivery.swift` [7L] — Stub.

Subdir `Evaluation/`:
- `TriggerEvaluator.swift` [114L] — `actor TriggerEvaluator`. Runs all registered triggers in parallel with `withTaskGroup`, scores winner by `priority * 0.5 + score * 0.5`, requires score ≥ 0.5 to fire. DEBUG-only `debugSnapshot` for BrainDashboard.
- `FeedbackTracker.swift` [7L] — Stub.
- `IntentPlanner.swift` [7L] — Stub.
- `PriorityRanker.swift` [7L] — Stub.

Subdir `Triggers/`:
- `Trigger.swift` [50L] — `protocol Trigger: Sendable` + `struct TriggerContext` + `struct TriggerResult`.
- `HealthTrigger.swift` [97L] — `SleepDebtTrigger`, `InactivityTrigger`, `PRTrigger`, `RecoveryTrigger`.
- `BehavioralTrigger.swift` [57L] — `StreakRiskTrigger`, `DisengagementTrigger` (returns nil pending observation window), `EngagementMomentumTrigger`.
- `CulturalTrigger.swift` [45L] — Single trigger handling Eid (high), Ramadan fasting hour (low), Jumu'ah midday (low). Precedence: Eid > Ramadan > Jumu'ah.
- `EmotionalTrigger.swift` [48L] — `EmotionalFollowUpTrigger`, `MoodShiftTrigger`.
- `LifecycleTrigger.swift` [11L] — `TrialDayTrigger` (returns nil pending FreeTrialManager wiring).
- `MemoryCallbackTrigger.swift` [63L] — The magic. Surfaces a relationship that hasn't been mentioned in 14+ days when emotion is non-distressing and ≤1 other notification is recent.
- `RelationshipTrigger.swift` [34L] — `RelationshipCheckInTrigger`. Broader cousin of MemoryCallback — anyone in 90-day window aged 30+ days.
- `TemporalTrigger.swift` [46L] — `MorningKickoffTrigger`, `CircadianNudgeTrigger`.
- `AchievementTrigger.swift` [7L] — Stub.

Subdir `Types/`:
- `BudgetDecision.swift` [28L] — `public enum BudgetDecision`: `.allowed`, `.allowedWithOverride(reason:)`, `.deferredToMorning`, `.rejected(.expired/.dailyLimitReached/.cooldown/.pendingLimitReached/.tierDisabled)`.
- `NotificationIntent.swift` [110L] — `public struct NotificationIntent` + `public enum NotificationKind` (24 cases) + `public enum Priority` (5 levels: `.ambient`, `.low`, `.medium`, `.high`, `.critical`) + `public struct IntentSignals`.

**Public API highlights:**
- `NotificationBrain.shared.request(_ intent: NotificationIntent, fireDate:precomposedTitle:precomposedBody:categoryIdentifier:userInfo:identifier:) async -> DeliveryResult`
- `TriggerEvaluator.shared.evaluateAll(recentDeliveryKinds:) async -> TriggerResult?`
- `TriggerEvaluator.shared.registerAll([Trigger])`

**Batch provenance:** BATCH 5. 5a added the type primitives (`69b5109`), 5b added GlobalBudget + CooldownManager + QuietHoursManager (`cfd82dd`), 5c added NotificationBrain (`060b4d9`). BATCH 6 then added the Trigger protocol + TriggerEvaluator + 7 health/behavioral triggers (`bed2ceb`); MemoryCallback + emotional/relationship/cultural/temporal/lifecycle (`39131e3`); TemplateLibrary + MessageComposer + FeedbackLearner (`b933b37`); and 6d migrated 7 legacy senders to funnel through NotificationBrain (`adbbf8a`).

**Dependencies:** UserNotifications, BackgroundTasks, all of `02_Memory`, `03_Reasoning`, `05_Privacy`, `08_Persona`.

**Flags / knobs:** `NOTIFICATION_BRAIN_ENABLED` (Info.plist, currently `false`), `PROACTIVE_EMOTIONAL_ENABLED`, `PROACTIVE_MEMORY_CALLBACK_ENABLED`, `PROACTIVE_CULTURAL_ENABLED` — all currently `false` in Info.plist.

---

#### 3.2.8 Brain/07_Learning

**Purpose:** Background tasks, consolidation, feedback loops. Where the Captain "rests and reflects."

**Files (7):**
- `BackgroundCoordinator.swift` [88L] — `final class BackgroundCoordinator`. Registers `aiqo.brain.nightly` BGTask (no-op unless `MEMORY_V4_ENABLED`); schedules earliest-begin for 3:00 local; on fire, runs `EmotionalMiner.mine(since: 24h ago)` and `BehavioralObserver.mineAndNominate()` in parallel.
- `FeedbackLearner.swift` [49L] — `public actor FeedbackLearner`. Tracks notification engagement signal.
- `WeeklyMemoryConsolidator.swift` [96L] — `final class WeeklyMemoryConsolidator`. Weekly digest writer.
- `DecayEngine.swift` [7L] — Stub.
- `NightlyConsolidation.swift` [7L] — Stub.
- `PersonalizationEvolver.swift` [7L] — Stub.
- `WeeklyConsolidation.swift` [7L] — Stub.

**Public API highlights:**
- `BackgroundCoordinator.shared.registerTasks()` — call once at launch.
- `BackgroundCoordinator.shared.scheduleNextNightly()` — call after registerTasks and after each fire.

**Batch provenance:** BackgroundCoordinator added in BATCH 3c (`8b8e29e`); FeedbackLearner in BATCH 6c (`b933b37`).

**Dependencies:** BackgroundTasks, all of `02_Memory`.

**Flags / knobs:** Gated by `FeatureFlags.memoryV4Enabled`.

---

#### 3.2.9 Brain/08_Persona

**Purpose:** The Captain's voice — identity, dialect, humor, wisdom. Pure data + a small selection layer.

**Files (9):**
- `CaptainIdentity.swift` [63L] — `enum CaptainIdentity`. Name, traits (7), values (6), forbidden patterns (5), emoji policy (3 allowed kinds), `systemPrompt(dialect:emotion:cultural:) -> String` Arabic system prompt.
- `CaptainPersonaBuilder.swift` [81L] — `enum CaptainPersonaBuilder`. Compiles a persona summary from the user profile.
- `CaptainPersonalization.swift` [405L] — User-facing persona configuration enums: `CaptainPrimaryGoal`, `CaptainSportPreference`, `CaptainWorkoutTimePreference`.
- `DialectLibrary.swift` [132L] — `enum DialectLibrary`. **4 dialects** (`iraqi`, `gulf`, `levantine`, `msa`) × **9 contexts** (`greeting`, `encouragement`, `gentleReminder`, `celebration`, `concern`, `farewell`, `acknowledgment`, `checkIn`, `recovery`) = 36 phrase banks. Iraqi is default.
- `HumorEngine.swift` [56L] — `enum HumorEngine`. **4 intensity levels:** `off`, `subtle`, `light`, `playful`. Off when emotion is grief/shame or high-intensity declining. Subtle during fasting hour. Playful for Eid or high-joy. Light for stable trend. Subtle otherwise.
- `WisdomLibrary.swift` [95L] — `enum WisdomLibrary`. **8-entry bank** of proverbs and reflections (Arabic proverbs, Iraqi proverbs, modern). Surfaced sparingly: only on Jumu'ah midday, declining trend, or 1-in-10 base rate. Suppressed for grief or intensity > 0.8.
- `CulturalContext.swift` [7L] — Stub.
- `MoodModulator.swift` [7L] — Stub.
- `VoiceProfile.swift` [7L] — Stub.

**Public API highlights:**
- `CaptainIdentity.systemPrompt(dialect:emotion:cultural:) -> String`
- `DialectLibrary.phrase(dialect:context:) -> String`
- `HumorEngine.intensity(emotion:cultural:) -> Intensity`
- `WisdomLibrary.appropriate(emotion:cultural:) -> Wisdom?`

**Batch provenance:** BATCH 7. 7a added CaptainIdentity + DialectLibrary (`db4591f`), 7b added HumorEngine + WisdomLibrary (`72a4ade`), 7c added the rich PersonaAdapter / MessageComposer pass + PersonaGuard (`35cb726`).

**Dependencies:** None outside Brain.

**Flags / knobs:** None.

---

#### 3.2.10 Brain/09_Wellbeing

**Purpose:** Crisis detection, intervention policy, professional referrals. The safety net that always wins over engagement.

**Files (4):**
- `CrisisDetector.swift` [130L] — `actor CrisisDetector`. Three sources, in priority order: text (via IntentClassifier crisis markers), emotional pattern (≥3 high-intensity negative emotions in 24h → `.concerning`), bio signal (sleep < 3h → `.watchful`). Severities: `noConcern`, `watchful`, `concerning`, `acute`.
- `InterventionPolicy.swift` [67L] — `enum InterventionPolicy`. Pure decision function. `noConcern → .doNothing`; `watchful → .gentleCheckIn`; `concerning + ≥2 priors in 7 days → .professionalReferral(.suggested)`; `concerning otherwise → .reflectiveMessage(text)`; `acute → .professionalReferral(.immediate)`. Reflective text bank (3 AR + 3 EN).
- `ProfessionalReferral.swift` [206L] — `enum ProfessionalReferral`. Region-aware resources: UAE (2: MOHAP + Estijaba), Saudi (1: NCMH), Iraq (2: findahelpline.com + IASP), Gulf-other / global (2: Find a Helpline + IASP). Region detected from `Locale.current.region`. Bilingual support messages with emergency-services preface for `.immediate` urgency (UAE 998, Saudi 937, otherwise generic). All website strings and no live URL fetches.
- `SafetyNet.swift` [52L] — `actor SafetyNet`. 50-signal rolling buffer. `record(signal:)` + `shouldIntervene(for:language:) async -> InterventionPolicy.Decision`.

**Public API highlights:**
- `CrisisDetector.shared.evaluate(message:) async -> CrisisDetector.Signal`
- `SafetyNet.shared.record(_ signal: CrisisDetector.Signal)`
- `SafetyNet.shared.shouldIntervene(for:language:) async -> InterventionPolicy.Decision`
- `ProfessionalReferral.supportMessage(language:urgency:region:) -> String`

**Batch provenance:** BATCH 8a wrote CrisisDetector + SafetyNet + InterventionPolicy (`8f06227`); BATCH 8b wrote ProfessionalReferral (`fde87e4`).

**Dependencies:** `02_Memory.EmotionalStore`, `01_Sensing.BioStateEngine`, `03_Reasoning.IntentClassifier`.

**Flags / knobs:** `CRISIS_DETECTOR_ENABLED` (Info.plist, currently `false` — but the orchestrator integration in `BrainOrchestrator.wellbeingDecision` is unconditional).

---

#### 3.2.11 Brain/10_Observability

**Purpose:** Inspect what the Brain is doing. Currently dev-only.

**Files (5):**
- `BrainDashboard.swift` [125L] — `struct BrainDashboard: View`. DEBUG-only inspector showing memory counts, recent crisis signals, trigger snapshot, audit entries, feature flags. Reads `TriggerEvaluator.shared.debugSnapshot()` and the various stores.
- `BrainHealthMonitor.swift` [10L] — Near-stub.
- `CaptainMemorySettingsView.swift` [325L] — User-facing memory toggle + per-category stats. Hosts the localization-key bug noted in §16.
- `MemoryUsageTracker.swift` [7L] — Stub.
- `PerformanceMetrics.swift` [7L] — Stub.

**Public API highlights:**
- `BrainDashboard()` — present from a debug menu.
- `CaptainMemorySettingsView()` — present from the Captain settings screen.

**Batch provenance:** BrainDashboard added in BATCH 8b (`fde87e4`).

**Dependencies:** All Brain stores.

**Flags / knobs:** `BRAIN_DASHBOARD_ENABLED` (Info.plist, currently `false`).

---

## 4. Data Flow: The Conversation Turn

Trace from "user taps Send" to "reply lands on screen." File:line references resolved against the recon snapshot.

1. User types in the Captain chat and taps Send. `CaptainViewModel.sendMessage(...)` at [CaptainViewModel.swift:225](AiQo/Features/Captain/CaptainViewModel.swift:225).
2. View model assembles `HybridBrainRequest` (conversation, screenContext, language, userProfileSummary, intentSummary, workingMemorySummary). `HybridBrainRequest(...)` constructed at [CaptainViewModel.swift:459](AiQo/Features/Captain/CaptainViewModel.swift:459).
3. View model wraps the call in `withGlobalTimeout` (35s default, longer for sleep) and invokes `orchestrator.processMessage(request:userName:)` at [BrainOrchestrator.swift:37](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:37).
4. `BrainOrchestrator` first runs `interceptSleepIntent(_:)` — if the message looks like a sleep query and we are not already on the sleep screen, the request is rerouted to `.sleepAnalysis`.
5. `BrainOrchestrator.wellbeingDecision(for:)` at [BrainOrchestrator.swift:146](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:146) runs `CrisisDetector.shared.evaluate(message:)` → `SafetyNet.shared.record(signal)` → `SafetyNet.shouldIntervene(for:language:)`. If the decision is `.professionalReferral(let urgency)`, the orchestrator returns immediately with `makeSafetyReferralReply(language:urgency:)` and never calls the LLM.
6. Otherwise: tier check. If `route == .cloud` and `!DevOverride.unlockAllFeatures` and `!TierGate.shared.canAccess(.captainChat)`, return `makeTierRequiredReply(...)`. [BrainOrchestrator.swift:51](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:51).
7. Branch on route (`.local` or `.cloud`). Local route uses `LocalBrain` (Foundation Models, iOS 26+). Cloud route uses `HybridBrainService` → Gemini.
8. `HybridBrainService` (cloud path) builds the prompt via `PromptComposer`, hands it to `PrivacySanitizer` for outbound scrubbing, opens `URLSession` to `https://generativelanguage.googleapis.com/v1beta/models/...:generateContent` ([HybridBrain.swift:122](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:122)).
9. `CloudBrainService.generateReply(...)` records an `AuditLogger.Entry` with destination, tier, prompt/response byte counts, latency, sanitization flag, outcome.
10. On success, `processCloudRoute` calls `persistIfMemoryEnabled(request:reply:)` at [BrainOrchestrator.swift:807](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:807). Path is no-op when `FeatureFlags.memoryV4Enabled` is false.
11. When V4 memory is on:
    - `EpisodicStore.shared.record(userMessage:captainResponse:)` writes the turn synchronously and returns the `episodeID`.
    - A `Task.detached(priority: .utility)` runs `FactExtractor.shared.extract(userMessage:captainResponse:maxFacts:3)`, filters out `sensitive == true` candidates, then calls `SemanticStore.shared.addOrReinforce(...)` for each remaining fact, linking back to the episode ID.
12. Reply returns up the chain. `personalizeReply(...)` substitutes the user's name. `applySafetyDecision(...)` may append a gentle check-in or reflective message.
13. `CaptainViewModel` receives the reply, persists the message bubble, and updates the UI.

The cloud round trip happens in steps 8–9. Everything in steps 1–7 and 10–13 is on-device. The only data crossing the network in step 8 is the sanitized prompt.

---

## 5. Data Flow: The Proactive Notification

Trace from BGTask fire to UNUserNotificationCenter delivery.

1. iOS fires the `aiqo.brain.nightly` BGTask around 03:00 local. `BackgroundCoordinator` is registered at [AppDelegate.swift:33](AiQo/App/AppDelegate.swift:33) when `FeatureFlags.memoryV4Enabled` is true.
2. `BackgroundCoordinator.handleNightlyTask(_:)` at [BackgroundCoordinator.swift:56](AiQo/Features/Captain/Brain/07_Learning/BackgroundCoordinator.swift:56) sets the expiration handler and starts the work.
3. In parallel via `async let`:
    - `EmotionalMiner.shared.mine(since: 24h ago)` — pulls episodes from `EpisodicStore.entries(from:to:)`, classifies sentiment per episode via `SentimentDetector`, writes new `EmotionalMemory` entries to `EmotionalStore` when intensity ≥ 0.4.
    - `BehavioralObserver.shared.mineAndNominate()` — examines accumulated session events and writes `ProceduralPattern` candidates to `ProceduralStore`.
4. `BackgroundCoordinator.scheduleNextNightly()` queues the next 03:00 wake. `task.setTaskCompleted(success: true)`.

Trigger evaluation happens separately during the day:

5. (Caller of choice — e.g. an app tick or a scheduled foreground evaluation) calls `TriggerEvaluator.shared.evaluateAll(recentDeliveryKinds:)`.
6. Evaluator builds a fresh `TriggerContext` (bio, cultural, emotion).
7. All registered triggers run in parallel inside `withTaskGroup`.
8. Each `TriggerResult` with `score >= 0.5` is collected. Winner sorted by `priority * 0.5 + score * 0.5`.
9. Winner's `intent` (`NotificationIntent`) is passed to `NotificationBrain.shared.request(_:)` at [NotificationBrain.swift:38](AiQo/Features/Captain/Brain/06_Proactive/NotificationBrain.swift:38).
10. `NotificationBrain` runs four gates:
    - **Gate 1: budget.** `GlobalBudget.shared.evaluate(intent, now:)` checks expiration, daily counter rollover, iOS pending count (≤60 of 64), per-tier daily cap, quiet hours (defer if non-critical), per-kind and global cooldowns, tier-specific kind disablement (e.g. monthlyReflection requires Pro).
    - **Gate 2: composition.** `MessageComposer.shared.composeRich(intent:persona:dialect:language:)` produces title + body using template + dialect phrase + tone lead + optional humor flourish + optional wisdom append.
    - **Gate 3: persona.** `PersonaGuard.validate(title:body:kind:)` blocks on forbidden patterns, emoji-on-non-celebration, length, profanity, haram content.
    - **Gate 4: privacy.** `PrivacySanitizer().sanitizeText(...)` scrubs both title and body again as a defense in depth.
11. `UNMutableNotificationContent` built with sound, category (mapped per kind), and `interruptionLevel` derived from `intent.priority` (`.passive` for ambient/low, `.active` for medium/high, `.timeSensitive` for critical).
12. `UNUserNotificationCenter.current().add(request)`.
13. On success: `GlobalBudget.shared.recordDelivered(intent)` (which calls `CooldownManager.shared.recordDelivery(kind)`), and `AuditLogger.shared.record(event: .notificationDelivered, kind:, requestedBy:)`.
14. Result is wrapped in a `DeliveryResult` and returned.

Legacy senders (`NotificationService`, `MorningHabitOrchestrator`, `PremiumExpiryNotifier`, `TrialJourneyOrchestrator`) were migrated in BATCH 6d to call `NotificationBrain.shared.request(...)` with `precomposedTitle` / `precomposedBody` / `categoryIdentifier` / `userInfo` / `identifier` overrides so they preserve their existing copy and routing. Direct `UNUserNotificationCenter.current().add(...)` calls in `AiQo/Services/Notifications` are zero per recon.

---

## 6. Memory System Deep Dive

### 6.1 The Five Stores

| Store | `@Model` | Purpose | Growth | Primary read API |
|---|---|---|---|---|
| `EpisodicStore` (588L) | `EpisodicEntry` | Every conversation turn (user message + Captain response) | Unbounded; weekly consolidation by `WeeklyMemoryConsolidator` | `recentEntries(limit:)`, `entries(from:to:)` |
| `SemanticStore` (624L) | `SemanticFact` | Extracted user facts (categorised, deduped, reinforced) | Tier-capped: Free 50, Max 200, Pro 500 | `all(limit:)`, `fact(by: id)`, `facts(matching: category)` |
| `ProceduralStore` (240L) | `ProceduralPattern` | Behavioural patterns (e.g. workout time preference) | Slow growth | `patterns(minStrength:kinds:limit:)` |
| `EmotionalStore` (240L) | `EmotionalMemory` | Mood events from EmotionalMiner | Bounded by mining cadence | `unresolvedEmotions(olderThan:minIntensity:limit:)`, `emotions(since:limit:)` |
| `RelationshipStore` (205L) | `Relationship` | People mentioned in conversations | Implicit cap (real users ~100) | `recentlyMentioned(in:within:)` |

All five are SwiftData-backed `@Model` types. All five stores are `actor`s with `.shared` singletons configured at app launch when `MEMORY_V4_ENABLED` is true.

### 6.2 The Three Intelligence Components

- **`FactExtractor` (180L).** On-device only. Heuristic path always available; optional Foundation Models path on iOS 26+. Returns `FactCandidate` values with `content`, `category`, `confidence`, `sensitive` flag. The orchestrator filters `sensitive == true` candidates out before persisting (consent UI is not yet built — see §16).
- **`EmotionalMiner` (90L).** Cadence: Pro daily, Max weekly, Free never. Runs from the nightly BGTask. Pulls episodes since cutoff, runs each through `SentimentDetector`, persists `EmotionalMemory` for any episode with intensity ≥ 0.4. Maps signed sentiment score to `EmotionKind`: ≥0.6 joy, ≥0.3 gratitude, ≤-0.6 grief, ≤-0.3 frustration, else peace.
- **`MemoryRetriever` (142L).** Unified RAG. `retrieve(query:bioContext:tier:customLimit:)` returns a `MemoryBundle` (`facts`, `episodes`, `patterns`, `emotions`, `relationships`). Total budget = `TierGate.shared.maxMemoryRetrievalDepth` (Free 0, Max 10, Pro 25). Split is fixed: facts 40% / episodes 25% / patterns 15% / emotions 10% / relationships 10%. Embedding similarity via `EmbeddingIndex` (NLEmbedding for ar + en); recency uses 30-day half-life.

### 6.3 Migrations & Schema

| Version | File | Stage | Notes |
|---|---|---|---|
| V1 | CaptainSchemaV1.swift | seed | initial Captain memory |
| V2 | CaptainSchemaV2.swift | lightweight | additive (two new models) |
| V3 | CaptainSchemaV3.swift | lightweight | additive (`ConversationThreadEntry`) |
| V4 | MemorySchemaV4.swift | custom | rebuilds facts + episodes from `CaptainMemory` |

Migration plan: [CaptainSchemaMigrationPlan.swift](AiQo/Features/Captain/Brain/02_Memory/Models/CaptainSchemaMigrationPlan.swift). Active schema is selected at launch by `FeatureFlags.memoryV4Enabled`; this branch's Info.plist sets the flag to `false`, meaning the V3 schema is in use until v1.0.1 flips it on.

---

## 7. Notification System

### 7.1 The Single Door

Every user-facing notification flows through `NotificationBrain.shared.request(_:)`. Verified by the recon: `grep "UNUserNotificationCenter.current().add" AiQo/Services/Notifications` returns **0**. Five legacy entry points have been migrated:

- [NotificationService.swift:82](AiQo/Services/Notifications/NotificationService.swift:82), `:283`, `:916` — `inactivityNudge`, `recoveryReminder`, `achievementUnlocked`.
- [MorningHabitOrchestrator.swift:335](AiQo/Services/Notifications/MorningHabitOrchestrator.swift:335) — `morningKickoff`.
- [PremiumExpiryNotifier.swift:48](AiQo/Services/Notifications/PremiumExpiryNotifier.swift:48) — premium expiry reminder.
- [TrialJourneyOrchestrator.swift:274](AiQo/Services/Trial/TrialJourneyOrchestrator.swift:274), `:315` — `trialDay` notifications.

Migrated callers can keep their custom localized copy via `precomposedTitle` / `precomposedBody`, retain their `userInfo` deep-link payloads, and reuse named identifiers via `identifier:`.

### 7.2 The 15 Triggers

Registered at app launch in [AppDelegate.swift:37](AiQo/App/AppDelegate.swift:37) via `TriggerEvaluator.shared.registerAll([...])`:

| # | Trigger | File | Kind | Priority | Score (max) | Fires when |
|---|---|---|---|---|---|---|
| 1 | `SleepDebtTrigger` | HealthTrigger.swift | `sleepDebtAcknowledgment` | high | 1.0 | `bio.sleepHoursBucketed < 5.5` |
| 2 | `InactivityTrigger` | HealthTrigger.swift | `inactivityNudge` | medium | 1.0 | `timeOfDay ∈ {midday, afternoon}` and `steps < 2000` |
| 3 | `PRTrigger` | HealthTrigger.swift | `personalRecord` | high | 0.9 | `steps ≥ 10000` and not delivered today |
| 4 | `RecoveryTrigger` | HealthTrigger.swift | `recoveryReminder` | high | 0.8 | `BioStateEngine.needsRecovery() == true` |
| 5 | `StreakRiskTrigger` | BehavioralTrigger.swift | `streakRisk` | medium | 0.7 | `timeOfDay ∈ {evening, night}` and `steps < 3000` |
| 6 | `DisengagementTrigger` | BehavioralTrigger.swift | `disengagement` | — | — | **Always nil** — pending observation window (see §16) |
| 7 | `EngagementMomentumTrigger` | BehavioralTrigger.swift | `engagementMomentum` | medium | 0.6 | `sleep ≥ 7h` and `steps > 7000` and `emotion ∈ {joy, gratitude}` |
| 8 | `MemoryCallbackTrigger` | MemoryCallbackTrigger.swift | `memoryCallback` | high | 0.75 | non-distressing emotion, ≤1 recent delivery, a relationship aged > 14 days with `emotionalWeight > 0.5` |
| 9 | `EmotionalFollowUpTrigger` | EmotionalTrigger.swift | `emotionalFollowUp` | medium | 0.65 | unresolved emotion older than 2 days at intensity ≥ 0.6 |
| 10 | `MoodShiftTrigger` | EmotionalTrigger.swift | `moodShift` | high | 0.7 | `emotion.trend == .declining` and `intensity > 0.5` |
| 11 | `RelationshipCheckInTrigger` | RelationshipTrigger.swift | `relationshipCheckIn` | medium | 0.55 | any relationship in 90-day window aged > 30 days |
| 12 | `MorningKickoffTrigger` | TemporalTrigger.swift | `morningKickoff` | medium | 0.7 | `timeOfDay == .morning` and not already delivered |
| 13 | `CircadianNudgeTrigger` | TemporalTrigger.swift | `circadianNudge` | low | 0.5 | `timeOfDay ∈ {night, lateNight}` and `sleep < 6.5` |
| 14 | `CulturalTrigger` | CulturalTrigger.swift | `eidCelebration` / `ramadanMindful` / `jumuahSpecial` | high (Eid) / low (others) | 0.9 / 0.4 / 0.45 | Eid → Ramadan fasting hour → Jumu'ah midday (precedence) |
| 15 | `TrialDayTrigger` | LifecycleTrigger.swift | `trialDay` | — | — | **Always nil** — pending FreeTrialManager wiring (see §16) |

Evaluator firing threshold: `score >= 0.5`. Tie-break / ranking: `priority * 0.5 + score * 0.5`.

### 7.3 Budget & Cooldown

From [GlobalBudget.swift:11](AiQo/Features/Captain/Brain/06_Proactive/Budget/GlobalBudget.swift:11) and siblings:

- **iOS 64-pending reserve:** 4 slots reserved (allow up to 60 in-flight).
- **Daily caps** (from `SubscriptionTier.dailyNotificationBudget`): Free 2 / Max 4 / Trial 7 / Pro 7.
- **Critical override:** `Priority.critical` may push exactly 1 notification above the daily cap.
- **Global cooldown:** 2h between any two notifications.
- **Per-kind cooldown:** 6h between two of the same `NotificationKind`.
- **Quiet hours:** default 22:00–07:00 local; non-critical intents are deferred to `nextWakeDate`.
- **Tier-disabled kinds:** `monthlyReflection` requires `.pro` or `.trial`.

### 7.4 MessageComposer Path

`MessageComposer.composeRich` follows this order:

1. Pull bilingual template from `TemplateLibrary.template(for:language:)`.
2. Inject signal-derived substitutions (`relationship_name`, `steps`).
3. For specific kinds, replace title or body with a dialect-aware phrase from `DialectLibrary.phrase(...)`. Examples: morningKickoff title → greeting phrase; personalRecord body → celebration phrase + body; inactivityNudge title → gentle reminder; recoveryReminder title → recovery phrase.
4. Optionally prefix the body with a `toneLead` derived from `PersonaDirective.Tone` (only for body-prefixable kinds — sleep, inactivity, recovery, circadian, emotional follow-up, mood shift, weekly insight, jumu'ah).
5. Append a playful flourish from `HumorEngine.playfulFlourish(dialect:)` if humor intensity is `.playful`, the persona allows humor, and the kind is celebratory (PR / achievement / Eid).
6. Append a wisdom line from the persona's `wisdomCandidate` only for `weeklyInsight` / `jumuahSpecial` at `.high` priority.
7. Strip emoji unless `CaptainIdentity.canUseEmoji(for: kind) == true` and humor is not `.off`.
8. Hand to `PersonaGuard.validate` for hard-block check before delivery.

---

## 8. Persona System

### 8.1 CaptainIdentity

Defined in [CaptainIdentity.swift](AiQo/Features/Captain/Brain/08_Persona/CaptainIdentity.swift). Holds the immutable Captain identity. Provides `systemPrompt(dialect:emotion:cultural:) -> String` that injects the dialect, current emotional state summary, and cultural moment into the Arabic system prompt used by every cloud LLM call.

Forbidden patterns checked by PersonaGuard: `you should`, `you must`, `I know how you feel`, `everything happens for a reason`, `just be positive`. The list is intentionally short so editing it is a one-line change.

Emoji policy: only `personalRecord`, `eidCelebration`, `achievementUnlocked` may carry emoji. Anywhere else (including any other `NotificationKind` and the body of any Captain reply if surfaced through MessageComposer), `MessageComposer.stripEmoji` and `PersonaGuard` cooperate to remove or block them.

### 8.2 DialectLibrary

[DialectLibrary.swift](AiQo/Features/Captain/Brain/08_Persona/DialectLibrary.swift). Four `Dialect` cases × nine `Context` cases = 36 phrase banks. Each bank has 2-3 hand-written variants picked by `randomElement()`. The default is Iraqi (Mohammed's native dialect). MSA is always available as a respectful fallback. A safe `fallback(for:)` MSA phrase is returned if the bank ever empties.

### 8.3 HumorEngine

[HumorEngine.swift](AiQo/Features/Captain/Brain/08_Persona/HumorEngine.swift). Decides allowed humor intensity from the current `EmotionalReading` and `CulturalContextEngine.State`:

- `.off` if emotion is `grief` or `shame`.
- `.off` if `intensity > 0.7` and `trend == .declining`.
- `.subtle` during fasting hour.
- `.playful` for Eid (al-Fitr / al-Adha).
- `.playful` for joy with `intensity > 0.6`.
- `.light` for stable trend.
- `.subtle` otherwise.

`playfulFlourish(dialect:)` returns a short Arabic interjection — Iraqi flavor by default.

### 8.4 WisdomLibrary

[WisdomLibrary.swift](AiQo/Features/Captain/Brain/08_Persona/WisdomLibrary.swift). Eight-entry bank: 3 Arabic proverbs, 2 Iraqi proverbs, 3 modern reflections. `appropriate(emotion:cultural:) -> Wisdom?` returns `nil` for grief or `intensity > 0.8`; prefers Arabic / Iraqi on Jumu'ah midday; prefers Iraqi / modern on declining trend; otherwise fires at a 1-in-10 base rate.

### 8.5 PersonaGuard

[PersonaGuard.swift](AiQo/Features/Captain/Brain/04_Inference/Validation/PersonaGuard.swift). Six violation classes:

- `forbidden_pattern:<phrase>` — any of CaptainIdentity's 5 forbidden patterns.
- `emoji_on_non_celebration` — emoji rendered in title or body for a non-allowed kind.
- `title_too_long:<count>` — title > 65 chars.
- `body_too_long:<count>` — body > 180 chars.
- `profanity` — `fuck` / `shit` / `damn`.
- `haram_content` — `alcohol`, `beer`, `wine`, `vodka`, `casino`, `gambling`, `porn` (EN); `خمر`, `كحول`, `قمار`, `مراهنة`, `اباحي`, `إباحي` (AR).

Any violation fails the entire notification. NotificationBrain logs the violations and returns `DeliveryResult.decision = .rejected(.tierDisabled)` — note the reuse of an existing rejection variant; in a future tier of this work it is worth introducing a dedicated `.personaGuardBlocked` reason.

---

## 9. Safety & Wellbeing

### 9.1 CrisisDetector

[CrisisDetector.swift](AiQo/Features/Captain/Brain/09_Wellbeing/CrisisDetector.swift). Three sources, evaluated in order:

1. **Text** (`signalFromText`) — runs `IntentClassifier.classify(message)`; if `primary == .crisis`, returns `.acute`.
2. **Emotional pattern** (`signalFromEmotionalPattern`) — pulls last 24h of emotions; if ≥ 3 high-intensity (≥0.6) negatives, returns `.concerning`.
3. **Bio signal** (`signalFromBioState`) — current bio snapshot; if `sleepHoursBucketed < 3.0`, returns `.watchful`.

If all return nil, signal is `.noConcern` from text source.

### 9.2 SafetyNet

[SafetyNet.swift](AiQo/Features/Captain/Brain/09_Wellbeing/SafetyNet.swift). 50-signal rolling buffer (in-memory). Records every signal CrisisDetector emits and supplies the recent-history input to `InterventionPolicy.decide(...)`.

### 9.3 InterventionPolicy

| Severity | History condition | Decision |
|---|---|---|
| `noConcern` | — | `.doNothing` |
| `watchful` | — | `.gentleCheckIn` |
| `concerning` | ≥ 2 prior `.concerning`+ signals in last 7 days | `.professionalReferral(.suggested)` |
| `concerning` | otherwise | `.reflectiveMessage(text:)` (3 AR variants, 3 EN variants) |
| `acute` | — | `.professionalReferral(.immediate)` |

### 9.4 ProfessionalReferral

| Region | Resources | Languages | Notes |
|---|---|---|---|
| `.uae` | MOHAP Mental Health Counselling (04-5192519); Estijaba 8001717 | ar / en | UAE emergency preface points to ambulance 998 |
| `.saudi` | National Center for Mental Health Promotion (920033360) | ar | Saudi emergency preface points to 937 |
| `.iraq` | Find a Helpline Iraq; IASP fallback | multiple | Generic emergency preface |
| `.gulfOther` / `.global` | Find a Helpline; IASP | multiple | Generic emergency preface |

`detectRegion(locale:)` reads `locale.region?.identifier`: `AE` → uae, `SA` → saudi, `IQ` → iraq, `KW`/`OM`/`QA`/`BH` → gulfOther, anything else → global.

`supportMessage(language:urgency:region:)` composes: `[emergency line] + [introduction by urgency × language] + [formatted resource list]`. Phone, website, availability, and language metadata are concatenated with `|` separators per resource.

---

## 10. Privacy & Compliance

### 10.1 Data Flow Boundaries

Three layers, strictly enforced:

1. **Device only.** All raw HealthKit samples; the five memory stores; everything in `01_Sensing`, `03_Reasoning`, `08_Persona`, `09_Wellbeing`; the `SentimentDetector`; the `IntentClassifier`; the `EmotionalEngine`; the `EmbeddingIndex`. Verified by recon: HTTP-reference counts per Brain subfolder are `00:0`, `01:0`, `03:0`, `05:0`, `06:0`, `07:0`, `08:0`, `10:0`. (`02_Memory` shows 2 — one legacy URLSession + one Gemini endpoint string in MemoryExtractor.swift; `04_Inference` shows 7 — all in HybridBrain.swift, the legitimate cloud caller; `09_Wellbeing` shows 7 — all are website strings in ProfessionalReferral.swift, no live fetches.)
2. **Sanitized outbound.** Only Gemini and ElevenLabs receive payloads, and only after `PrivacySanitizer` has redacted PII, normalized user names to "User", truncated conversations to the last 4 messages, and bucketed numeric values.
3. **Never outbound.** Raw HealthKit samples, unbucketed metrics, PII (emails, phones, UUIDs, URLs), `@`-mentions, sensitive facts (filtered out in `persistIfMemoryEnabled`).

### 10.2 PrivacySanitizer

[PrivacySanitizer.swift](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift). Bucketing constants: steps 500, calories 10, HR 5, sleep 0.5h. PII redaction rules:

- Emails → `[REDACTED]`
- Phone numbers (7+ digits, optional separators) → `[REDACTED]`
- UUIDs (8-4-4-4-12) → `[REDACTED]`
- @mentions → `User`
- URLs (`https?://...`) → `[REDACTED]`
- Long numeric sequences (10+ digits) → `[REDACTED]`

The phone-number and long-numeric patterns were rewritten on 2026-04-08 to fix catastrophic backtracking; the file's docstring documents the previous patterns and the regex approach.

Conversation cap: only the last 4 messages are sent. Image cap: kitchen images downsized to 1280px max dimension at 0.78 JPEG quality with EXIF/GPS stripped.

### 10.3 AICloudConsentGate

Lives in `AiQo/Services/Permissions/AIDataConsentManager.swift`. First cloud call requires user consent (one-time). User can revoke from Settings → Privacy. Revocation blocks all future cloud calls until re-granted. The Brain layer treats consent as a precondition; the orchestrator does not bypass consent under any circumstance except a confirmed `.acute` crisis signal, where the safety referral surface activates *before* any cloud call would have been made (referrals are produced from the on-device `ProfessionalReferral` enum and need no network).

### 10.4 AuditLogger

Every cloud LLM call records an `Entry` with: timestamp, destination model name, tier label, prompt byte count, response byte count, latency (ms), `consentGranted`, `sanitizationApplied`, purpose label, outcome (`success` / `failure` / `sanitizerBlocked` / `consentDenied` / `rateLimit`). The ring is 500 entries; persisted as JSON to `~/Documents/brain_audit.log.json`. Notification deliveries log a lighter-weight event via the audit logger extension at the bottom of NotificationBrain.swift. BrainDashboard surfaces both for inspection (DEBUG only).

---

## 11. Tier System & DevOverride

### 11.1 SubscriptionTier

[SubscriptionTier.swift](AiQo/Core/Purchases/SubscriptionTier.swift). `enum SubscriptionTier: Int`. Cases: `.none = 0`, `.max = 1`, `.trial = 2`, `.pro = 3`. Raw values are stable and persisted via UserDefaults key `aiqo.purchases.currentTier`. `effectiveAccessTier` returns `.pro` for `.trial` so trial users get full Pro access. Tier-scaled capacity (memoryFactLimit, dailyNotificationBudget, memoryRetrievalDepth, patternMiningWindowDays, geminiContextBudget) is computed directly on the tier so callers do not have to memoize numbers.

### 11.2 TierGate

[TierGate.swift](AiQo/Features/Captain/Brain/00_Foundation/TierGate.swift). `final class TierGate: @unchecked Sendable`. Singleton `TierGate.shared`. Reads tier from UserDefaults + `FreeTrialManager.isTrialActiveSnapshot` so it is callable from any isolation (actors, background tasks, views).

Public sync limit properties:
- `maxContextTokens` (Free 0, Max 8000, Pro 32000)
- `maxMemoryRetrievalDepth` (Free 0, Max 10, Pro 25)
- `maxSemanticFacts` (Free 0, Max 200, Pro 500)
- `maxNotificationsPerDay` (Free 0, Max 4, Pro 7)
- `memoryCallbackLookbackDays` (Free nil, Max 30, Pro nil/unlimited)
- `emotionalMiningCadence` (Free `.never`, Max `.weekly`, Pro `.daily`)
- `patternMiningWindowDays` (Free 0, Max 14, Pro 56)
- `maxWeeksInPlan` (Free 0, Max 1, Pro 4)

Plus async back-compat hooks `memoryFactLimit()` and `cappedMemoryFetchLimit(requested:fallback:)` for existing call sites in `EpisodicStore` and `SemanticStore`.

`canAccess(_ feature:)` returns `tier.effectiveAccessTier >= requiredTier(for: feature)` and logs every decision via `diag.logTierGate`. There are 46 such call sites in the app per recon.

### 11.3 DevOverride

[DevOverride.swift](AiQo/Features/Captain/Brain/00_Foundation/DevOverride.swift). Reads `AIQO_DEV_UNLOCK_ALL` from Info.plist on every call (no caching). Hard-coded to `false` in RELEASE builds via `#if DEBUG`. `warnIfActive()` prints a banner at launch:

```
⚠️⚠️⚠️ DEV_OVERRIDE ACTIVE — All paid features unlocked. DO NOT SHIP. ⚠️⚠️⚠️
```

The intended pattern at every gate site is:

```swift
if !DevOverride.unlockAllFeatures {
    guard TierGate.shared.canAccess(.feature) else { throw BrainError.tierLocked }
}
```

Wrapped sites: 43 of 46 (per recon `grep -B 3 "canAccess(" | grep -c "DevOverride.unlockAllFeatures"`). The 3 unwrapped sites are likely additional `canAccess` calls that already return the gate result without an early exit (e.g. consumed by a UI binding) and are therefore safe; nonetheless the gap should be reviewed.

---

## 12. External Integrations

### 12.1 Gemini (Google)

The sole LLM provider. Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent`. Accessed exclusively via `HybridBrainService` and `CloudBrainService` in [04_Inference/Services/](AiQo/Features/Captain/Brain/04_Inference/Services). Dedicated `URLSession` so `timeoutIntervalForResource` (35s) is honored. All prompts pass through `PrivacySanitizer` before transmission; all responses are recorded in `AuditLogger` with byte counts only.

### 12.2 Apple Intelligence (Foundation Models)

iOS 26+ only. On-device. Used by `LocalBrain` ([04_Inference/Services/LocalBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/LocalBrain.swift)), the sleep agent, and `FactExtractor` (LLM path). Falls back to heuristic implementations when unavailable.

### 12.3 HealthKit

Unified read path:
- `HealthKitService` (`AiQo/Services/Permissions/HealthKit/HealthKitService.swift`) — authorization + raw queries.
- `CaptainHealthSnapshotService` ([01_Sensing/CaptainHealthSnapshotService.swift](AiQo/Features/Captain/Brain/01_Sensing/CaptainHealthSnapshotService.swift)) — daily essential metrics.
- `BioStateEngine` ([01_Sensing/BioStateEngine.swift](AiQo/Features/Captain/Brain/01_Sensing/BioStateEngine.swift)) — cached bucketed snapshot with injectable fetcher.
- `HealthKitBridge` ([01_Sensing/HealthKitBridge.swift](AiQo/Features/Captain/Brain/01_Sensing/HealthKitBridge.swift)) — typed adapter for memory subsystems.

Info.plist usage descriptions:
- `NSHealthShareUsageDescription`: "AiQo reads selected Health data like steps, sleep, and hydration to power your daily and weekly summaries."
- `NSHealthUpdateUsageDescription`: "AiQo writes the Health entries you choose, such as hydration logs and workouts, back to the Health app."

A separate Apple Watch extension (Workouts) lives outside the iOS target.

### 12.4 Spotify

Two surfaces:
- `SPTAppRemote` (vendored framework at `AiQo/Frameworks/SpotifyiOS.framework`) for playback control.
- Spotify Web API for the Hamoudi Blend master playlist (ID `14YVMyaZsefyZMgEIIicao`).

Tokens stored in Keychain via `SpotifyTokenStore` with accessibility `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

Feature-flagged via `HAMOUDI_BLEND_ENABLED` (in `AiQoFeatureFlags`).

### 12.5 ElevenLabs

Text-to-speech for the Captain's voice. Accessed via `CaptainVoiceAPI` / `CaptainVoiceService`. Gated by `AICloudConsentGate`. Long-term plan: replace with a Fish Speech S1-mini hosted on RunPod for full self-hosting.

### 12.6 Supabase

`SupabaseService` and `SupabaseArenaService`. Used as a thin Edge-Functions proxy for a small number of backend operations (Tribe, referrals). Backend surface is intentionally small; AiQo is a primarily client-side app.

---

## 13. App Lifecycle

### 13.1 Entry Point

`@main struct AiQoApp: App` at [AiQo/App/AppDelegate.swift:11](AiQo/App/AppDelegate.swift:11).

### 13.2 Launch Sequence

In `AiQoApp.init()`:

1. `DevOverride.warnIfActive()` — print the dev-mode banner.
2. `Self.makeCaptainContainer()` — pick V3 (`CaptainSchemaV3`) or V4 (`MemorySchemaV4`) container based on `FeatureFlags.memoryV4Enabled`.
3. `MemoryStore.shared.configure(container:storageMode:)` — legacy V3 store configuration.
4. If V4 enabled: configure all five new stores (`EpisodicStore`, `SemanticStore`, `ProceduralStore`, `EmotionalStore`, `RelationshipStore`) inside a `Task { ... }`; then `BackgroundCoordinator.shared.registerTasks()` and `.scheduleNextNightly()`; then register all 15 triggers via `TriggerEvaluator.shared.registerAll([...])`.
5. Configure `CaptainPersonalizationStore`, `RecordProjectManager`, `WeeklyMetricsBufferStore`, `WeeklyMemoryConsolidator`, `ConversationThreadManager` against the container.
6. `ConversationThreadManager.shared.pruneOldEntries()`.
7. `schedulePostLaunchWarmup()`.

Routing decision (onboarding / paywall / main) happens in `AppRootManager` and `MainTabRouter`.

### 13.3 Background Tasks

Registered identifiers (Info.plist `BGTaskSchedulerPermittedIdentifiers`):
- `aiqo.brain.nightly` — EmotionalMiner + BehavioralObserver. Earliest-begin 03:00 local. Only registered when `FeatureFlags.memoryV4Enabled`.
- `aiqo.notifications.refresh` — legacy proactive evaluation.
- `aiqo.notifications.inactivity-check` — legacy inactivity reminder.

`UIBackgroundModes`: `audio`, `remote-notification`, `fetch`, `processing`.

---

## 14. Testing Strategy

### 14.1 Unit Test Coverage

`AiQoTests` totals 5,138 LOC and **368 test functions** by `grep -c "^    func test\|^func test"`. All tests live flat under `AiQoTests/` (no subdirectory split — single test target).

### 14.2 Test Organization

- One file per subsystem-area (e.g., `MemoryRetrieverTests.swift`, `CrisisDetectorTests.swift`, `PersonaGuardTests.swift`).
- Snapshot/seed types used to isolate stores per test.
- Time-dependent components (BioStateEngine, CrisisDetector) accept injectable clocks via `@Sendable () -> Date` initializer parameters; the BATCH 3 fixup at commit `c0435a0` made BioStateEngine fully clock-mockable.
- DEBUG-only `_setTierForTesting(_:)` and `_clearTestOverride()` on `TierGate` for tier scenarios.
- DEBUG-only `_resetForTesting()` on GlobalBudget; `_force(lastDelivery:forKind:)` on CooldownManager.

### 14.3 Test Execution

```bash
xcodebuild test -scheme AiQo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Known environment caveat: iOS 26.4 simulator must be installed (Xcode → Settings → Components) for tests that exercise iOS 26-only paths (Foundation Models, AlarmKit).

---

## 15. Build & Release

### 15.1 Project Config

- Xcode 16, file-system synchronized groups (no `.pbxproj` edits needed when adding files to existing folders).
- Bundle ID: `com.mraad500.aiqo`.
- Swift 6 strict concurrency.

### 15.2 Release Checklist

`APP_STORE_CHECKLIST_v1.0.1.md` lives at the repo root and was created in BATCH 8c (`fa27a7f`).

### 15.3 CHANGELOG

`CHANGELOG.md` at the repo root. v1.0.1 entry summarises crisis detection, BrainDashboard, and the proactive intelligence improvements; explicitly lists the localization-key bug as a known issue.

---

## 16. Known Issues & Deferred Work

Honest list at the recon snapshot.

**16.1 Localization keys mismatch.** ~~The Captain Memory settings view references keys `memory.enable`, `memory.enableSubtitle`, etc. but the strings file uses `memory.enableToggle`, `memory.enableDesc`.~~ **Partially resolved 2026-04-20 (§21.6):** the two toggle keys were aligned at [CaptainMemorySettingsView.swift:105-107](AiQo/Features/Captain/Brain/10_Observability/CaptainMemorySettingsView.swift:105). The category-row keys (`memory.cat.*` vs `memory.category.*`) remain mismatched and are still on the v1.0.1 punch-list — they render raw key text in the per-category stats rows. Fix is a one-pass key alignment, same shape as the toggle fix.

**16.2 MemoryExtractor legacy cloud path.** [MemoryExtractor.swift:244](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift:244) and `:320` predate BATCH 2 cleanup. Two outbound HTTP references (URLSession + Gemini endpoint string). Sanitizer-wrapped, but technical debt — this is the only Brain-folder file outside `04_Inference/Services/HybridBrain.swift` with live network code. Plan: rewrite using `CloudBrainService` and the new audit pipeline.

**16.3 Most Brain feature flags are `false` in Info.plist.** Verified via `PlistBuddy`. Currently `false`: `MEMORY_V4_ENABLED`, `NOTIFICATION_BRAIN_ENABLED`, `BRAIN_DASHBOARD_ENABLED`, `PROACTIVE_EMOTIONAL_ENABLED`, `PROACTIVE_MEMORY_CALLBACK_ENABLED`, `PROACTIVE_CULTURAL_ENABLED`. **Updated 2026-04-20:** `CRISIS_DETECTOR_ENABLED` was flipped to `true` (§21.2) so the Info.plist now reflects the real runtime behaviour — `BrainOrchestrator.wellbeingDecision` was never gated by the flag, the safety stack has always run on every cloud-routed message, and the flag now documents intent rather than contradicting the code. The remaining `false` flags are still part of the v1.0.1 release work.

**16.4 DisengagementTrigger** ([BehavioralTrigger.swift:31](AiQo/Features/Captain/Brain/06_Proactive/Triggers/BehavioralTrigger.swift:31)). Returns nil pending BehavioralObserver observation-window accumulation. Needs ~7+ days of real user signals.

**16.5 TrialDayTrigger** ([LifecycleTrigger.swift:8](AiQo/Features/Captain/Brain/06_Proactive/Triggers/LifecycleTrigger.swift:8)). Returns nil pending wiring to `FreeTrialManager`.

**16.6 Weather / Music bridges.** [WeatherBridge.swift](AiQo/Features/Captain/Brain/01_Sensing/WeatherBridge.swift) and [MusicBridge.swift](AiQo/Features/Captain/Brain/01_Sensing/MusicBridge.swift) are 27-29 line stubs returning nil. Real implementations pending.

**16.7 HRV.** `BioSnapshot.hrvBucketed` is always nil because `CaptainDailyHealthMetrics` does not yet expose HRV. `BioStateEngine.needsRecovery()` therefore depends on sleep alone for now.

**16.8 PersonaGuard rejection variant overload.** `NotificationBrain.request(_:)` returns `decision: .rejected(.tierDisabled)` when PersonaGuard blocks (see [NotificationBrain.swift:106](AiQo/Features/Captain/Brain/06_Proactive/NotificationBrain.swift:106)). Mechanically correct (delivery is rejected) but misleads telemetry — a dedicated `.personaGuardBlocked` would be cleaner.

**16.9 Sensitive fact consent UI not built.** `FactExtractor` flags candidates with `sensitive: Bool`, and `BrainOrchestrator.persistIfMemoryEnabled` filters them out entirely (see [BrainOrchestrator.swift:828](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:828)). The user has no way to review or approve those facts. Plan: a "review captured facts" surface in Captain Memory settings.

**16.10 Pre-existing brain stubs.** ~~Across the 11 subsystems there are roughly 19 single-line placeholder files~~ **Updated 2026-04-20:** three of those stubs (`PersonalizationEvolver.swift`, `WeeklyConsolidation.swift`, `NightlyConsolidation.swift` under `07_Learning/`) were deleted in the hardening pass — they had no callers anywhere and were flagged by the Apple audit as completeness risk under Guideline 2.1. The remaining ~16 stubs (examples: `ConsentGate.swift`, `DataClassifier.swift`, `RoutingPolicy.swift`, `IntentPlanner.swift`, `DecayEngine.swift`, `MoodModulator.swift`) still compile as empty types and ship no behaviour. They should either be implemented or removed on the next pass.

**16.11 V4 Models relocation.** Originally relocated in BATCH 1a (`63a910e`). Current state confirmed via recon — the Models directory at `02_Memory/Models/` contains all expected V4 model files; relocation is complete.

**16.12 CaptainLockedView paywall hook.** Wired in BATCH 1c (`63d2cda`). Verified via recon: callers in `MainTabScreen.swift`, `CaptainChatView.swift`, `ChatHistoryView.swift`, `CaptainScreen.swift` use `PaywallView(source: .captainGate)` per `PaywallSource.captainGate`. Done.

**16.13 Modified files in working tree at snapshot time.** 26 source files have unstaged modifications at `git status` time of this snapshot. These were not part of the recon-reviewed state of HEAD (`fa27a7f`); the symbol counts and behaviours described in this document reflect the committed state, not the working tree.

---

## 17. Historical Context: The 8 BATCHES

**BATCH 1 — Cleanup (2026-04-18).** Tied off pre-Brain refactor loose ends. 1a (`63a910e`) relocated 10 V4 Models into `Brain/02_Memory/Models/`. 1b (`b2e776d`) wrapped 9 `canAccess` sites with the DevOverride bypass. 1c (`63d2cda`) polished CaptainLockedView with Arabic copy and a real paywall hook. Result report: `24db3c4`.

**BATCH 2 — Memory Intelligence (2026-04-18).** The "memory thinks" milestone. 2a (`1440ce2`) added `EmbeddingIndex` (NLEmbedding for AR + EN), `SalienceScorer`, `TemporalIndex` and tests. 2b (`815c27f`) added `MemoryRetriever` + `MemoryBundle` and the tier-aware RAG. 2c (`0d4abd0`) added `FactExtractor` and `EmotionalMiner` with on-device only constraints. 2a fixup (`a6db820`) marked the XCTSkip-using embedding tests as `throws`. Result report: `8d19eaa`. 29/29 tests green.

**BATCH 3 — Wiring + Sensing (2026-04-18 / 2026-04-19).** Connected the new memory layer to the conversation loop and built the Sensing layer. 3a (`5fafd33`) inserted the `persistAndLearn` (now `persistIfMemoryEnabled`) hook at five success sites. 3b (`3684a5e`) wrote the unified `BioStateEngine` with freshness cache. 3c (`8b8e29e`) added `BehavioralObserver`, `ContextSensor`, and the nightly BGTask. 3d (`6f9281a`) added typed `HealthKitBridge` / `MusicBridge` / `WeatherBridge`. The fixup (`c0435a0`) made `BioStateEngine` accept an injectable fetch closure for testability. Reports: `93b16fd`, `33e7d9e`. 21 new tests, 20 regressions all green.

**BATCH 4 — Reasoning (2026-04-19).** The "Captain understands" milestone. 4a (`6b804df`) introduced `EmotionalEngine` API and `EmotionalReading` snapshot. 4b (`899545e`) added `CulturalContextEngine` (Hijri Ramadan / Jumu'ah / Eid detection) and the first `PersonaAdapter` pass. 4c (`572394d`) added `IntentClassifier` (crisis-first ordering) and `ContextualPredictor`. Result report: `a46e106`. 30 tests green.

**BATCH 5 — Notification Core (2026-04-19).** Built the notification primitives. 5a (`69b5109`) added `NotificationIntent`, `Priority`, and `BudgetDecision` types. 5b (`cfd82dd`) added `GlobalBudget`, `CooldownManager`, `QuietHoursManager`. 5c (`060b4d9`) added the `NotificationBrain` single-door entry point and minimal composition path. Result report: `5523e5a`. 20 tests green.

**BATCH 6 — Notification Magic (2026-04-19).** The 15 triggers and the legacy migration. 6a (`bed2ceb`) introduced the `Trigger` protocol, `TriggerEvaluator`, and the 7 health/behavioural triggers. 6b (`39131e3`) added `MemoryCallbackTrigger`, plus emotional / relationship / cultural / temporal / lifecycle triggers. 6c (`b933b37`) added `TemplateLibrary`, `MessageComposer`, `FeedbackLearner`. 6d (`adbbf8a`) migrated 7 legacy notification senders to funnel through `NotificationBrain`. Result report: `cb5875d`. 37 tests green.

**BATCH 7 — Persona Soul (2026-04-19).** Hamoudi gets a voice. 7a (`db4591f`) added `CaptainIdentity` and `DialectLibrary` (4 dialects × 9 contexts). 7b (`72a4ade`) added `HumorEngine` and `WisdomLibrary` (Iraqi + Arabic proverbs). 7c (`35cb726`) wired the rich `PersonaAdapter` + `MessageComposer` composition path and `PersonaGuard` safety net. Result report: `b3c375e`.

**BATCH 8 — Safety & Ship (2026-04-19).** The wellbeing surface plus ship prep. 8a (`8f06227`) added `CrisisDetector`, `SafetyNet`, and `InterventionPolicy`. 8b (`fde87e4`) added region-aware `ProfessionalReferral` and a dev-only `BrainDashboard`. 8c (`fa27a7f`) wrote the App Store submission checklist (`APP_STORE_CHECKLIST_v1.0.1.md`) and CHANGELOG entry for v1.0.1.

---

## 18. Appendix A: File Index

Alphabetical by basename. Path is relative to the repo root.

| File | Lines | Purpose |
|---|---|---|
| `Brain/00_Foundation/BrainBus.swift` | 28 | placeholder cross-subsystem bus |
| `Brain/00_Foundation/BrainError.swift` | 30 | localized error type |
| `Brain/00_Foundation/CaptainLockedView.swift` | 126 | RTL upgrade card |
| `Brain/00_Foundation/DevOverride.swift` | 46 | DEBUG-only tier bypass |
| `Brain/00_Foundation/DiagnosticsLogger.swift` | 56 | process-wide `diag` logger |
| `Brain/00_Foundation/TierGate.swift` | 208 | the single tier gate |
| `Brain/01_Sensing/BehavioralObserver.swift` | 128 | mines ProceduralPattern candidates |
| `Brain/01_Sensing/BioStateEngine.swift` | 121 | unified bio snapshot with cache |
| `Brain/01_Sensing/CaptainHealthSnapshotService.swift` | 406 | underlying HealthKit pull |
| `Brain/01_Sensing/CircadianReasoner.swift` | 7 | stub |
| `Brain/01_Sensing/ContextSensor.swift` | 47 | screen + idle context |
| `Brain/01_Sensing/HealthKitBridge.swift` | 235 | typed adapter for memory |
| `Brain/01_Sensing/MusicBridge.swift` | 27 | stub returning nil |
| `Brain/01_Sensing/SignalBus.swift` | 7 | stub |
| `Brain/01_Sensing/WeatherBridge.swift` | 29 | stub returning nil |
| `Brain/02_Memory/ConversationThread.swift` | 209 | persisted thread entries |
| `Brain/02_Memory/EmbeddingIndex.swift` | 85 | NLEmbedding wrapper |
| `Brain/02_Memory/Intelligence/EmotionalMiner.swift` | 90 | mines EmotionalMemory entries |
| `Brain/02_Memory/Intelligence/FactExtractor.swift` | 180 | on-device fact extraction |
| `Brain/02_Memory/Intelligence/MemoryBundle.swift` | 33 | retriever return type |
| `Brain/02_Memory/Intelligence/MemoryConsolidator.swift` | 7 | stub |
| `Brain/02_Memory/Intelligence/MemoryExtractor.swift` | 347 | legacy cloud extraction (see §16.2) |
| `Brain/02_Memory/Intelligence/MemoryRetriever.swift` | 142 | unified RAG |
| `Brain/02_Memory/Intelligence/NarrativeBuilder.swift` | 7 | stub |
| `Brain/02_Memory/Intelligence/PatternMiner.swift` | 7 | stub |
| `Brain/02_Memory/Intelligence/RelationshipTracker.swift` | 7 | stub |
| `Brain/02_Memory/MemoryStore.swift` | 1312 | legacy V3 store |
| `Brain/02_Memory/Models/BioSnapshot.swift` | 35 | bucketed bio snapshot |
| `Brain/02_Memory/Models/CaptainMemory.swift` | 95 | legacy fact model |
| `Brain/02_Memory/Models/CaptainSchemaMigrationPlan.swift` | 269 | V1→V4 migration plan |
| `Brain/02_Memory/Models/CaptainSchemaV1.swift` | 19 | V1 schema |
| `Brain/02_Memory/Models/CaptainSchemaV2.swift` | 20 | V2 schema |
| `Brain/02_Memory/Models/CaptainSchemaV3.swift` | 21 | V3 schema |
| `Brain/02_Memory/Models/ConsolidationDigest.swift` | 32 | weekly digest |
| `Brain/02_Memory/Models/EmotionalMemory.swift` | 78 | EmotionKind + @Model |
| `Brain/02_Memory/Models/EpisodicEntry.swift` | 116 | conversation turn @Model |
| `Brain/02_Memory/Models/MemorySchema.swift` | 7 | stub |
| `Brain/02_Memory/Models/MemorySchemaV4.swift` | 25 | V4 schema |
| `Brain/02_Memory/Models/MonthlyReflection.swift` | 50 | Pro-tier monthly digest |
| `Brain/02_Memory/Models/ProceduralPattern.swift` | 50 | behavior pattern @Model |
| `Brain/02_Memory/Models/Relationship.swift` | 72 | person @Model |
| `Brain/02_Memory/Models/SemanticFact.swift` | 107 | extracted fact @Model |
| `Brain/02_Memory/Models/WeeklyMetricsBuffer.swift` | 42 | weekly buffer @Model |
| `Brain/02_Memory/Models/WeeklyReportEntry.swift` | 61 | weekly report @Model |
| `Brain/02_Memory/SalienceScorer.swift` | 56 | heuristic salience |
| `Brain/02_Memory/Services/EmotionalStore.swift` | 240 | EmotionalMemory actor store |
| `Brain/02_Memory/Services/EpisodicStore.swift` | 588 | EpisodicEntry actor store |
| `Brain/02_Memory/Services/ProceduralStore.swift` | 240 | ProceduralPattern actor store |
| `Brain/02_Memory/Services/RelationshipStore.swift` | 205 | Relationship actor store |
| `Brain/02_Memory/Services/SemanticStore.swift` | 624 | SemanticFact actor store |
| `Brain/02_Memory/Services/WeeklyMetricsBufferStore.swift` | 56 | weekly buffer store |
| `Brain/02_Memory/TemporalIndex.swift` | 66 | time-window index |
| `Brain/03_Reasoning/CaptainContextBuilder.swift` | 402 | bio + memory + persona compiler |
| `Brain/03_Reasoning/CognitivePipeline.swift` | 480 | legacy on-device cognition |
| `Brain/03_Reasoning/ContextualPredictor.swift` | 69 | upcoming-need predictor |
| `Brain/03_Reasoning/CulturalContextEngine.swift` | 102 | Hijri culture detection |
| `Brain/03_Reasoning/EmotionalEngine.swift` | 230 | legacy emotional types |
| `Brain/03_Reasoning/EmotionalEngineAPI.swift` | 120 | EmotionalEngine actor façade |
| `Brain/03_Reasoning/EmotionalReading.swift` | 44 | EmotionalReading snapshot |
| `Brain/03_Reasoning/IntentClassifier.swift` | 152 | crisis-first intent classifier |
| `Brain/03_Reasoning/PersonaAdapter.swift` | 142 | PersonaDirective + RichDirective |
| `Brain/03_Reasoning/PersonaDirective.swift` | 39 | tone enum |
| `Brain/03_Reasoning/ScreenContext.swift` | 52 | screen context enum |
| `Brain/03_Reasoning/SentimentDetector.swift` | 128 | NLTagger sentiment |
| `Brain/03_Reasoning/TrendAnalyzer.swift` | 219 | trend / streak momentum |
| `Brain/04_Inference/BrainOrchestrator.swift` | 846 | main conductor |
| `Brain/04_Inference/CaptainModels.swift` | 487 | persistent message + structured response types |
| `Brain/04_Inference/LLMJSONParser.swift` | 425 | JSON extraction |
| `Brain/04_Inference/PromptComposer.swift` | 537 | system prompt assembly |
| `Brain/04_Inference/PromptRouter.swift` | 137 | template selection |
| `Brain/04_Inference/RoutingPolicy.swift` | 7 | stub |
| `Brain/04_Inference/Services/CloudBrain.swift` | 145 | Gemini wrapper + audit |
| `Brain/04_Inference/Services/FallbackBrain.swift` | 212 | offline canned replies |
| `Brain/04_Inference/Services/HybridBrain.swift` | 486 | the cloud caller |
| `Brain/04_Inference/Services/LocalBrain.swift` | 835 | on-device Foundation Models path |
| `Brain/04_Inference/Validation/CulturalValidator.swift` | 7 | stub |
| `Brain/04_Inference/Validation/PersonaGuard.swift` | 66 | final notification safety net |
| `Brain/04_Inference/Validation/ResponseValidator.swift` | 7 | stub |
| `Brain/05_Privacy/AuditLogger.swift` | 106 | on-device audit ring |
| `Brain/05_Privacy/ConsentGate.swift` | 7 | stub |
| `Brain/05_Privacy/DataClassifier.swift` | 7 | stub |
| `Brain/05_Privacy/DifferentialPrivacy.swift` | 7 | stub |
| `Brain/05_Privacy/PrivacySanitizer.swift` | 658 | PII + bucketing + image sanitization |
| `Brain/06_Proactive/Budget/CooldownManager.swift` | 51 | global + per-kind cooldown |
| `Brain/06_Proactive/Budget/GlobalBudget.swift` | 99 | full outbound budget |
| `Brain/06_Proactive/Budget/QuietHoursManager.swift` | 42 | quiet window |
| `Brain/06_Proactive/Composition/DynamicPersonalizer.swift` | 7 | stub |
| `Brain/06_Proactive/Composition/MessageComposer.swift` | 183 | template + dialect + humor + wisdom |
| `Brain/06_Proactive/Composition/NotificationDelivery.swift` | 7 | stub |
| `Brain/06_Proactive/Composition/TemplateLibrary.swift` | 108 | bilingual templates |
| `Brain/06_Proactive/Evaluation/FeedbackTracker.swift` | 7 | stub |
| `Brain/06_Proactive/Evaluation/IntentPlanner.swift` | 7 | stub |
| `Brain/06_Proactive/Evaluation/PriorityRanker.swift` | 7 | stub |
| `Brain/06_Proactive/Evaluation/ProactiveEngine.swift` | 324 | legacy proactive types |
| `Brain/06_Proactive/Evaluation/TriggerEvaluator.swift` | 114 | parallel evaluator |
| `Brain/06_Proactive/NotificationBrain.swift` | 268 | the single door |
| `Brain/06_Proactive/SmartNotificationScheduler.swift` | 947 | legacy heuristic scheduler |
| `Brain/06_Proactive/Triggers/AchievementTrigger.swift` | 7 | stub |
| `Brain/06_Proactive/Triggers/BehavioralTrigger.swift` | 57 | streak / disengagement / momentum |
| `Brain/06_Proactive/Triggers/CulturalTrigger.swift` | 45 | Eid / Ramadan / Jumu'ah |
| `Brain/06_Proactive/Triggers/EmotionalTrigger.swift` | 48 | follow-up / mood shift |
| `Brain/06_Proactive/Triggers/HealthTrigger.swift` | 97 | sleep / inactivity / PR / recovery |
| `Brain/06_Proactive/Triggers/LifecycleTrigger.swift` | 11 | trial day (stub return) |
| `Brain/06_Proactive/Triggers/MemoryCallbackTrigger.swift` | 63 | the magic |
| `Brain/06_Proactive/Triggers/RelationshipTrigger.swift` | 34 | broader check-in |
| `Brain/06_Proactive/Triggers/TemporalTrigger.swift` | 46 | morning kickoff / circadian |
| `Brain/06_Proactive/Triggers/Trigger.swift` | 50 | protocol + Context + Result |
| `Brain/06_Proactive/Types/BudgetDecision.swift` | 28 | budget decision enum |
| `Brain/06_Proactive/Types/NotificationIntent.swift` | 110 | intent + kind + priority + signals |
| `Brain/07_Learning/BackgroundCoordinator.swift` | 88 | nightly BGTask coordinator |
| `Brain/07_Learning/DecayEngine.swift` | 7 | stub |
| `Brain/07_Learning/FeedbackLearner.swift` | 49 | engagement-signal learner |
| `Brain/07_Learning/WeeklyMemoryConsolidator.swift` | 96 | weekly digest writer |
| *(removed 2026-04-20 — see §21.6: `NightlyConsolidation.swift`, `PersonalizationEvolver.swift`, `WeeklyConsolidation.swift` stubs deleted)* | — | — |
| `Brain/08_Persona/CaptainIdentity.swift` | 63 | name + traits + values + system prompt |
| `Brain/08_Persona/CaptainPersonaBuilder.swift` | 81 | persona summary compiler |
| `Brain/08_Persona/CaptainPersonalization.swift` | 405 | user-facing persona enums |
| `Brain/08_Persona/CulturalContext.swift` | 7 | stub |
| `Brain/08_Persona/DialectLibrary.swift` | 132 | 4 dialects × 9 contexts |
| `Brain/08_Persona/HumorEngine.swift` | 56 | 4 intensity levels |
| `Brain/08_Persona/MoodModulator.swift` | 7 | stub |
| `Brain/08_Persona/VoiceProfile.swift` | 7 | stub |
| `Brain/08_Persona/WisdomLibrary.swift` | 95 | 8-entry proverb bank |
| `Brain/09_Wellbeing/CrisisDetector.swift` | 130 | three-source crisis evaluator |
| `Brain/09_Wellbeing/InterventionPolicy.swift` | 67 | pure decision logic |
| `Brain/09_Wellbeing/ProfessionalReferral.swift` | 206 | region-aware referrals |
| `Brain/09_Wellbeing/SafetyNet.swift` | 52 | 50-signal rolling buffer |
| `Brain/10_Observability/BrainDashboard.swift` | 125 | DEBUG dashboard |
| `Brain/10_Observability/BrainHealthMonitor.swift` | 10 | near-stub |
| `Brain/10_Observability/CaptainMemorySettingsView.swift` | 325 | user memory toggle + per-category stats |
| `Brain/10_Observability/MemoryUsageTracker.swift` | 7 | stub |
| `Brain/10_Observability/PerformanceMetrics.swift` | 7 | stub |

---

## 19. Appendix B: Glossary

- **Intent (Reasoning).** The classified category of a user message. One of `greeting`, `question`, `goal`, `venting`, `crisis`, `social`, `request`, `unknown`. Produced by `IntentClassifier`.
- **NotificationIntent (Proactive).** A request to `NotificationBrain` carrying `kind`, `priority`, `signals`, `requestedBy`, `requestedAt`, `expiresAt`. Distinct from the Reasoning intent.
- **TriggerContext.** The shared snapshot (`bio`, `cultural`, `emotion`, `pendingIntents`, `recentDeliveryKinds`) passed to every trigger on each evaluation cycle.
- **BioSnapshot.** Bucketed HealthKit values plus `timeOfDay`, `dayOfWeek`, `isFasting`. Bucket sizes: steps 500, HR 5, sleep 0.5h, calories 10. HRV currently always `nil`.
- **PersonaDirective.** The compiled per-turn directive: `tone`, `dialect`, `humorAllowed`, `avoidTopics`, `culturalHints`, `emotionalContext`. Produced by `PersonaAdapter.directive(...)`.
- **RichDirective.** PersonaDirective plus `humorIntensity`, `wisdomCandidate`, and the rendered `systemPrompt`. Produced by `PersonaAdapter.richDirective(...)`.
- **MemoryBundle.** The result of `MemoryRetriever.retrieve(...)` — five typed snapshot arrays (`facts`, `episodes`, `patterns`, `emotions`, `relationships`).
- **DevOverride.** DEBUG-only Info.plist switch (`AIQO_DEV_UNLOCK_ALL`) that makes `TierGate.canAccess` always return true at wrapped sites. Hard-coded false in RELEASE.
- **Single Door.** The architectural rule that every user-facing notification must be created via `NotificationBrain.shared.request(...)`. Never via direct `UNUserNotificationCenter.add(...)`.
- **Tier-effective access.** `SubscriptionTier.effectiveAccessTier` returns `.pro` when the tier is `.trial`; otherwise returns self. Comparisons against `requiredTier` use this.
- **Sanitization.** The pipeline applied by `PrivacySanitizer` before any outbound LLM call: PII redaction, name normalisation, conversation truncation, numeric bucketing, image EXIF/GPS strip.
- **Audit entry.** A `metadata-only` record written by `AuditLogger.shared.record(_:)` for every cloud LLM call. Persisted as JSON ring at `~/Documents/brain_audit.log.json`.
- **Crisis-first.** The `IntentClassifier` ordering rule that crisis markers are checked before any other category, with confidence 0.95. False positives accepted; false negatives never.
- **The magic trigger.** Informal name for `MemoryCallbackTrigger` — the trigger that surfaces a remembered relationship at a calm moment when the user is not under emotional load.

---

## 20. Appendix C: Read Path for New Engineers

A 90-minute path through this document for an engineer who has never opened the Xcode project.

1. **Section 1 — Executive Summary** (5 min). The three facts you must hold in your head.
2. **Section 3.1 — Architecture Diagram** (5 min). Trace the arrows once. Don't read the file index yet.
3. **Section 4 — Conversation Turn Flow** (15 min). Open `BrainOrchestrator.swift` in a tab and map each numbered step to a function.
4. **Section 6 — Memory Deep Dive** (20 min). The five stores and three intelligence components are the highest-density part of the system; spend the time.
5. **Section 7 — Notification System** (15 min). The 15-trigger table is the contract between the Captain's "thinking" and the user's lock screen.
6. **Section 10 — Privacy** (10 min). Internalise where the boundaries are. Re-read §10.1.
7. **Section 16 — Known Issues** (10 min). The honest list. If you are about to touch trigger code, §16.4 / §16.5 is where you start.
8. **Section 18 — File Index** (10 min). Skim. Look for stubs and high-line-count files; those are your debugging targets.
9. **Section 21 — App Store Hardening Pass** (10 min). The 2026-04-20 delta on top of the `fa27a7f` snapshot. Read this before touching onboarding, Info.plist, or the Learning Spark certificate pipeline.

When you finish you will know AiQo as well as the code allows. You will not yet know *why* certain decisions were made; commit messages and the BATCH result reports under `untitled folder/` carry that history.

---

## 21. App Store Submission Hardening — 2026-04-20

This section documents the delta applied on top of the `fa27a7f` snapshot after a full Apple App Store Review Guidelines audit (Nov 2025 – April 2026 rule-set) of the app. The audit found 8 Critical, 12 Major, and 5 Minor issues; this pass closed all 8 Critical, 9 of 12 Major, and 4 of 5 Minor — and verified with a clean **Release build of 0 errors and 0 warnings**. What remains (Dynamic Type global coverage, VoiceOver global coverage, iOS 26 Icon Composer variants, Tribe report/block UI) is either a multi-week refactor or blocked on design assets and is outside the scope of a single session.

The motivation: v1.0 shipped while the audit rule-set was rapidly tightening — the Nov 2025 AI-disclosure update, the Feb 2026 UGC tightening, the April 28 2026 iOS 26 SDK deadline, and the Spring 2026 health-app regulatory-status signalling. This pass brings v1.0.1 in line with the current rule-set before the submission window closes.

### 21.1 Privacy & Permissions (Guideline 5.1.1 / 5.1.3)

**Missing purpose strings added** to [Info.plist](AiQo/Info.plist) — the audit found six Swift call-sites that invoked camera or photo-library access without a matching purpose string, which would have shown a generic iOS prompt and risked rejection under 5.1.1(ii):

- `NSCameraUsageDescription` — covers Vision Coach ([QuestPushupChallengeView.swift:81](AiQo/Features/Gym/Quests/VisionCoach/QuestCameraPermissionGateView.swift)), Smart Fridge ([SmartFridgeCameraViewModel.swift](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift)), and the Learning Spark certificate capture path.
- `NSPhotoLibraryUsageDescription` — covers the Learning Spark `PhotosPicker` at [LearningProofSubmissionView.swift:142](AiQo/Features/Gym/Quests/Learning/LearningProofSubmissionView.swift:142).

Both strings are Arabic-first and explicitly state the on-device-only processing promise, which matters because it aligns with the Learning-Spark "image never leaves your phone" architectural commitment.

**Dead ElevenLabs build-time keys removed** — `CAPTAIN_VOICE_API_KEY`, `CAPTAIN_VOICE_API_URL`, `CAPTAIN_VOICE_MODEL_ID`, `CAPTAIN_VOICE_VOICE_ID`. ElevenLabs was already decommissioned at the code layer (`CaptainVoiceService.swift` is a no-op shim; the `AiQo/Core/CaptainVoiceAPI.swift` and `AiQo/Core/CaptainVoiceCache.swift` files were deleted), but the Info.plist keys were still shipping and could have confused an App Review engineer reading the binary's Info.plist.

**`DeviceID` removed from [PrivacyInfo.xcprivacy](AiQo/PrivacyInfo.xcprivacy)** — the app does not call `identifierForVendor` or `advertisingIdentifier`; it only syncs a push-notification `device_token`. The previous declaration was ambiguous (`DeviceID` in PrivacyInfo is commonly interpreted as IDFV/IDFA) and would have invited a review query. The PrivacyInfo now declares exactly what the app collects: `Fitness`, `Health`, `UserContent`, `Name`, `EmailAddress`.

### 21.2 Safety — Age Gate + Health Screening (Guideline 1.4.1)

**New mandatory onboarding step.** The audit flagged the absence of an age gate and health-condition screening as a Physical-Harm risk for a wellness app that ships workout and nutrition suggestions. Two new files implement a blocking gate between medical disclaimer and Captain personalization:

- [`AiQo/Features/Onboarding/HealthScreeningStore.swift`](AiQo/Features/Onboarding/HealthScreeningStore.swift) — defines `HealthScreeningAnswers` (Codable, Sendable) carrying `birthYear`, `isPregnant`, `hasHeartOrBloodPressureCondition`, `hadRecentSurgery`, with derived `ageNow`, `hasAnyCondition`, and `captainContextLine`. Persisted via UserDefaults key `aiqo.healthScreening.answers.v1`. Wiped on `logout()`.
- [`AiQo/Features/Onboarding/HealthScreeningOnboardingView.swift`](AiQo/Features/Onboarding/HealthScreeningOnboardingView.swift) — the UI. Asks for birth **year only** (not DOB, to minimise PII), accepts both Western and Eastern-Arabic digits, and presents three toggles. On submit: users younger than **18** are blocked with a dedicated "AiQo is 18+" screen; everyone else has their answers stored and proceeds.

**Flow wiring.** [`AppFlowController`](AiQo/App/SceneDelegate.swift) gained a new `.healthScreening` case in its `RootScreen` enum, a new `finalizeHealthScreening()` entry point, and a new `didCompleteHealthScreening` onboarding key. The resolver now inserts the screen between `.medicalDisclaimer` and `.captainPersonalization`. Logout clears the screening key and calls `HealthScreeningStore.clear()`.

**Captain context injection.** [`CaptainOnDeviceChatEngine.buildDynamicSystemPrompt`](AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:100) now accepts an optional `HealthScreeningAnswers` and, when any flag is set, injects a `USER HEALTH CONTEXT (MANDATORY)` block into the system prompt. The injected line is in Arabic ("تحذير صحي: ...") and tells Hamoudi to avoid high-intensity suggestions and to point the user to their doctor before any intense activity. The load is done from the async caller via `await MainActor.run { HealthScreeningStore.load() }` to keep the non-isolated actor context clean — the result is passed into the synchronous prompt builder as a parameter.

**Crisis-detector flag reconciled.** The Info.plist `CRISIS_DETECTOR_ENABLED` flag was flipped from `<false/>` to `<true/>` with a comment explaining the DEBUG-override rationale. The code always ran the crisis stack; the flag now matches the code rather than contradicting it.

### 21.3 Crash Prevention (Guideline 2.1)

Two `fatalError("Expected AVCaptureVideoPreviewLayer")` guards in the Vision Coach camera-preview code path were replaced with a force-cast that matches Apple's AVCam sample pattern:

- [QuestPushupChallengeView.swift:140](AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift:140)
- [VisionCoachView.swift:299](AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift:299)

The force-cast is safe because `override class var layerClass` returns `AVCaptureVideoPreviewLayer.self` — the cast is a contract assertion, not a runtime guess. The audit's concern was not that the guard was wrong but that the `fatalError` message was visible-enough to suggest a defensive panic rather than a contract assertion.

### 21.4 Learning Spark Hardening (Guideline 5.1.3)

The Learning Spark certificate pipeline processes an image that contains PII (name, date, QR, sometimes platform branding). The audit found three concrete gaps:

**EXIF stripping.** [`LearningProofStore.saveCertificateImage`](AiQo/Features/Gym/Quests/Learning/LearningProofStore.swift:55) now re-encodes the JPEG via `CGImageDestination` with only the preserved orientation tag — GPS, TIFF device info, camera make/model, and timestamp metadata are all dropped. A new private helper `encodeJPEGWithoutMetadata(_:quality:)` owns the pipeline; `orientationExifValue(for:)` maps `UIImage.Orientation` to the EXIF orientation integer. The previous `image.jpegData(compressionQuality:)` path was replaced because audit agents cannot verify metadata behaviour from Apple docs alone, and the explicit pipeline makes the privacy claim self-evident.

**File protection.** The certificate files are now written with `[.atomic, .completeFileProtectionUntilFirstUserAuthentication]`. This means the file bytes are unreadable on a locked device even with file-system extraction — matching what Apple expects for health-adjacent PII.

**Account-deletion cleanup.** A new [`LearningProofStore.deleteAllLocalData()`](AiQo/Features/Gym/Quests/Learning/LearningProofStore.swift) wipes the records dictionary, removes the UserDefaults key, and deletes the entire `Library/Application Support/LearningProofCertificates/` directory. It is called from [`AppFlowController.logout()`](AiQo/App/SceneDelegate.swift) so that signing out or deleting the account actually removes the certificate images — previously the images outlived the session that captured them.

**VoiceOver label on status badge.** [LearningProofSubmissionView.swift](AiQo/Features/Gym/Quests/Learning/LearningProofSubmissionView.swift) — the status pill now announces itself via `.accessibilityLabel("Certificate status: {status}")` loaded from the `gym.quest.learning.proof.status.a11y` localization key (both `ar` and `en`).

**Free-badge contrast.** The "free" capsule in [LearningCourseOptionsSheet.swift](AiQo/Features/Gym/Quests/Learning/LearningCourseOptionsSheet.swift:141) had a `#6B5B2E` foreground on a `#F5E4B4` background, measuring ~3.2:1 against a WCAG AA minimum of 4.5:1. Foreground changed to `#3D2E10` (~7:1).

**"Change" button touch target.** The small pill button at [QuestDetailSheet.swift:588-600](AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift:588) had a ~14pt hit area. Padding was raised to `14h × 10v`, a `.contentShape(Capsule())` was added, and `.frame(minWidth: 44, minHeight: 44)` now enforces the HIG minimum.

### 21.5 Accessibility — Reduce Transparency Helper

SwiftUI's `Material` type adapts automatically to Reduce Transparency in most `.background(...)` contexts, but the audit correctly pointed out that zero call-sites in the codebase explicitly read `accessibilityReduceTransparency` — leaving us without an escape hatch for the ~104 places where an explicit opaque fallback would be safer than Apple's default adaptation. The pass adds a helper and migrates one high-traffic site as the template:

- [`AiQoAccessibility.swift`](AiQo/Core/AiQoAccessibility.swift) — new `.aiqoGlassBackground(_:fallback:in:)` view modifier. Reads `@Environment(\.accessibilityReduceTransparency)` and picks either the passed-in Material or the fallback Color (default: `systemBackground`) in the given shape.
- Applied at [HomeView.swift:415-418](AiQo/Features/Home/HomeView.swift) where a `RoundedRectangle.fill(.ultraThinMaterial)` previously had no explicit fallback.

The remaining 100+ `.ultraThinMaterial` sites were intentionally left alone — SwiftUI's auto-adaptation covers them, and a 100+-site refactor without a concrete user complaint is beyond the scope of a submission-hardening pass. The helper gives future migrations an obvious one-line upgrade path.

### 21.6 Other Fixes

**Memory toggle localization.** [CaptainMemorySettingsView.swift:105-107](AiQo/Features/Captain/Brain/10_Observability/CaptainMemorySettingsView.swift:105) — the Captain memory toggle was reading `memory.enable` and `memory.enableSubtitle`, which do not exist. The code now reads `memory.enableToggle` and `memory.enableDesc`, which are the real keys in both `ar.lproj` and `en.lproj`. Supersedes half of §16.1; the category-row keys remain.

**Deployment target unified to iOS 26.2.** `AiQo.xcodeproj/project.pbxproj` had two debug/release configs at 26.1 and ten other targets at 26.2. All twelve are now 26.2. This unblocks the April 28 2026 "must build against iOS 26 SDK" requirement — 26.1 would have compiled but the mixed target set was an inconsistency ready to fail during archive.

**Dev-unlock flag flipped.** `AIQO_DEV_UNLOCK_ALL` in Info.plist was set to `<false/>` (was `<true/>`). `DevOverride.unlockAllFeatures` is `#if DEBUG` gated at [DevOverride.swift:15-21](AiQo/Features/Captain/Brain/00_Foundation/DevOverride.swift:15) so Release builds were never affected — but the Info.plist value is the canonical answer to "does this binary allow the paywall to be bypassed", and the audit wanted it to say false.

**Three 07_Learning stubs removed.** `PersonalizationEvolver.swift`, `WeeklyConsolidation.swift`, `NightlyConsolidation.swift` were each 7-line files declaring an empty `public final class`. None were referenced anywhere in the app target or tests. Deleted outright; Xcode 16 synchronized source groups auto-detect the directory change.

### 21.7 Legal — Open-Source Acknowledgements

[`AiQo/Resources/ACKNOWLEDGEMENTS.md`](AiQo/Resources/ACKNOWLEDGEMENTS.md) credits every Swift Package dependency (SDWebImage, SDWebImageSwiftUI, supabase-swift, swift-asn1, swift-clocks, swift-concurrency-extras, swift-crypto, swift-http-types, swift-system, xctest-dynamic-overlay) and the embedded Spotify iOS SDK with their licenses (MIT, Apache 2.0, proprietary). [`LegalView`](AiQo/UI/LegalView.swift) gained a third case, `.acknowledgements`, which loads the bundled markdown from the app bundle at runtime. A new "Open-source credits" row in [AppSettingsScreen.swift](AiQo/Core/AppSettingsScreen.swift) surfaces it from **Settings → Legal**.

### 21.8 Build State After the Pass

| Metric | Before | After |
|---|---|---|
| Critical audit issues | 8 | 0 |
| Major audit issues | 12 | 3 (all non-blockers) |
| Minor audit issues | 5 | 1 (Tribe trailing alignment — feature is `TRIBE_FEATURE_VISIBLE=false`) |
| Release build warnings | 62 (checklist) | **0** |
| Release build errors | — | **0** |
| iOS deployment target | 26.1 / 26.2 mixed | 26.2 unified |
| `AIQO_DEV_UNLOCK_ALL` | `true` in plist | `false` in plist |
| Onboarding steps before Captain | 6 | 7 (health screening added) |
| Account-deletion scope | Supabase + UserDefaults | Supabase + UserDefaults + certificate images + screening answers |

The Release build was verified twice end-to-end against `iphoneos` with `xcodebuild -configuration Release`. SourceKit's in-IDE index may show stale "cannot find module" errors immediately after the deployment-target change; a Clean Build Folder (`⌘⇧K`) refreshes it.

### 21.9 What's Still Open After This Pass

Three Major audit findings are deferred:

1. **Dynamic Type coverage** — ~500 call-sites use hardcoded `.font(.system(size:))`. The `scaledFont(...)` helper at [AiQoAccessibility.swift:35](AiQo/Core/AiQoAccessibility.swift:35) is adopted in only three files. A global migration to semantic styles (`.headline`, `.body`, `.caption`) or explicit `scaledFont` is a multi-week pass.
2. **VoiceOver coverage** — ~11% of Swift files (58 of 535) use `.accessibilityLabel`. Target for a health app is &gt;80%. Learning Spark status badges were fixed in §21.4 as a concrete template; a global pass is still needed.
3. **iOS 26 Icon Composer variants** — `AppIcon.appiconset/Contents.json` has the classic size/scale matrix but no `light` / `dark` / `tinted` / `monochrome` role variants. Requires a designer to produce the Icon Composer layers; cannot be landed from code.

Deferred Minor:
- Hardcoded `.trailing` alignment in the Tribe components (~30 sites). The Tribe feature itself is `TRIBE_FEATURE_VISIBLE=false`, so this is not a submission blocker — it becomes one when Tribe is enabled.

### 21.10 Files Added / Removed / Modified

**Added:**
- [`AiQo/Features/Onboarding/HealthScreeningStore.swift`](AiQo/Features/Onboarding/HealthScreeningStore.swift) (80 lines)
- [`AiQo/Features/Onboarding/HealthScreeningOnboardingView.swift`](AiQo/Features/Onboarding/HealthScreeningOnboardingView.swift) (203 lines)
- [`AiQo/Resources/ACKNOWLEDGEMENTS.md`](AiQo/Resources/ACKNOWLEDGEMENTS.md) (~40 lines)

**Removed:**
- `AiQo/Features/Captain/Brain/07_Learning/PersonalizationEvolver.swift`
- `AiQo/Features/Captain/Brain/07_Learning/WeeklyConsolidation.swift`
- `AiQo/Features/Captain/Brain/07_Learning/NightlyConsolidation.swift`
- `AiQo/Core/CaptainVoiceAPI.swift` *(deleted earlier in the branch; the ElevenLabs Info.plist cleanup in §21.1 closes that chapter.)*
- `AiQo/Core/CaptainVoiceCache.swift` *(same as above.)*

**Modified (app target):**
- `AiQo/Info.plist` — permission strings, dev-unlock flag, crisis-detector flag, dead ElevenLabs keys removed.
- `AiQo/PrivacyInfo.xcprivacy` — `DeviceID` removed.
- `AiQo.xcodeproj/project.pbxproj` — deployment target unified.
- `AiQo/App/SceneDelegate.swift` — new `.healthScreening` flow step, logout now clears Learning-Spark and health-screening state.
- `AiQo/Core/AiQoAccessibility.swift` — new `aiqoGlassBackground` modifier + `UIKit` import.
- `AiQo/Core/AppSettingsScreen.swift` — acknowledgements row.
- `AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift` — health-context injection in the system prompt.
- `AiQo/Features/Captain/Brain/10_Observability/CaptainMemorySettingsView.swift` — localization-key alignment.
- `AiQo/Features/Gym/Quests/Learning/LearningProofStore.swift` — EXIF strip, FileProtection, `deleteAllLocalData()`.
- `AiQo/Features/Gym/Quests/Learning/LearningProofSubmissionView.swift` — VoiceOver label on status badge.
- `AiQo/Features/Gym/Quests/Learning/LearningCourseOptionsSheet.swift` — free-badge contrast.
- `AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift` — 44pt touch target on "change" button.
- `AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift` — fatalError → contract cast.
- `AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift` — fatalError → contract cast.
- `AiQo/Features/Home/HomeView.swift` — one demonstration site of `aiqoGlassBackground`.
- `AiQo/UI/LegalView.swift` — `.acknowledgements` type loading bundled markdown.
- `AiQo/Resources/en.lproj/Localizable.strings` and `AiQo/Resources/ar.lproj/Localizable.strings` — 17 new keys across the health screening, status-badge a11y, and acknowledgements strings.

---

## 22. Smart Water Tracking & Reminders (2026-04-22)

Snapshot branch: `brain-refactor/p-fix-dev-override`. Everything below was built on top of the hardening pass in §21 and ships as a **100% free feature** — no TierGate reference, no paywall, no DevOverride branch. Feature-flag-gated only so the binary carries a production kill switch. Both the main app target (`xcodebuild build`) and the test target (`build-for-testing`) compile clean at the end of this pass.

### 22.1 Scope & Product Rules

The feature adds four things:
1. **Pace-based hydration reminders** routed through the existing `NotificationBrain` — no new notification system, no new scheduler.
2. **WHO/EFSA-referenced guidance UI** rendered inside the existing Water sheet, phrased as "general global guidance" — never as a prescriptive WHO number.
3. **System integration** across Captain Memory, Medical Disclaimer, AI Data disclosure, and the Privacy Policy legal text.
4. **An interactive systemSmall widget** with a race-free App-Group tap-counter so one tap = +0.25 L without touching the widget's HealthKit entitlement set.

Rules enforced throughout:
- Medically safe, non-prescriptive wording in every language variant ("general global guidance: 2–2.5 L/day").
- No raw HealthKit logs cross any trust boundary (memory, widget, cloud) — `PrivacySanitizer` remains the single PII boundary.
- Arabic primary, English secondary, Iraqi-dialect default (matching `NotificationBrain`'s own default).
- Local deterministic phrases — no Gemini call per reminder.
- Always choose clean + stable over flashy + fragile.

### 22.2 Feature Flag & Kill Switch

Info.plist key `SMART_WATER_TRACKING_ENABLED` (default `true`), exposed via the `@FeatureFlag` property wrapper in [AiQoFeatureFlags.swift](AiQo/Core/Config/AiQoFeatureFlags.swift) as `FeatureFlags.smartWaterTrackingEnabled`. The flag gates:

- The `SmartHydrationSection` rendering inside [WaterDetailSheetView.swift](AiQo/Features/Home/WaterDetailSheetView.swift).
- `HydrationService.reevaluateAndSchedule()` calls inside [HomeViewModel.swift:addWater / onAppBecameActive](AiQo/Features/Home/HomeViewModel.swift).

When flipped to false the Water sheet falls back to the v1 bottle + "+ 0.25 L" button UI and no hydration notifications are scheduled. The widget itself is in a separate target (`AiQoWidget`) and is not flag-gated — if a user adds the hydration widget to their Home Screen and then the flag is flipped off in a subsequent release, the widget still reads committed App-Group values and still logs `+1` on the tap counter; the drain simply no longer runs.

### 22.3 Domain Layer — Pure Value Types

[HydrationDailyState.swift](AiQo/Features/SmartWaterTracking/Models/HydrationDailyState.swift) defines four Sendable types:
- `HydrationPaceStatus` — `.ahead | .onTrack | .behind | .veryBehind`
- `HydrationSource` — `.manual | .appleHealth` (derived from `HKSample.sourceRevision.source.bundleIdentifier`)
- `HydrationDailyState` — `goalML, consumedML, expectedByNowML, lastDrinkDate, lastDrinkSource, paceStatus` with computed `remainingML` (never negative) and `progressFraction` (capped at 1.0)
- `HydrationEvaluation` — `.suppress(reason)` or `.remind(intensity: .gentle | .stronger)` with exhaustive `SuppressReason` enum (`trackingDisabled, beforeWakeWindow, afterWakeWindow, quietHours, recentDrink, paceOK`)

[HydrationSettings.swift](AiQo/Features/SmartWaterTracking/Models/HydrationSettings.swift) holds user preferences:
- `smartTrackingEnabled: Bool`
- `goalML: Double` (default **2500**)
- `wakeStartHour / wakeEndHour` — default **08:00 → 22:00** (14-hour window that aligns with quiet-hours start, so `expectedByNowML` reaches 100% exactly when reminders stop)
- `quietStartHour / quietEndHour` — 22:00 → 07:00
- `cooldownMinutes: Int` — 25 (recent-drink suppression)

`HydrationSettings.recommendedGoalML(forWeightKg:)` computes `weightKg * 32.5` (midpoint of the 30–35 mL/kg clinical band), clamped to `[1500, 4000]` and rounded to the nearest 100 mL so the Stepper UI never surfaces awkward values. Falls back to 2500 mL when weight is unknown.

`HydrationSettingsStore` persists to `UserDefaults` with stable keys (`aiqo.hydration.smart.enabled`, `aiqo.hydration.goal.ml`, etc.) and exposes `isGoalUserSet()` so first-launch bootstrap can seed the weight-based goal exactly once without ever overwriting user Stepper input.

### 22.4 Evaluator — Pure, Deterministic, Fully Tested

[HydrationEvaluator.swift](AiQo/Features/SmartWaterTracking/Services/HydrationEvaluator.swift) is a stateless enum with no I/O. Every function takes an explicit `Calendar` so tests can inject `TimeZone(identifier: "UTC")` and avoid flakiness.

Core functions:
- `wakeWindowProgress(now:, settings:, calendar:) -> Double` — linear ramp 0→1 across the wake window.
- `expectedByNowML(now:, settings:, calendar:) -> Double` — `goal × wakeWindowProgress`.
- `paceStatus(consumedML:, expectedByNowML:) -> HydrationPaceStatus` — bands: ≥110 % ahead, 90–110 % onTrack, 60–90 % behind, <60 % veryBehind. Before the wake window starts, `expectedByNowML == 0` and the function returns `.onTrack` (never false-flags as behind at 07:59).
- `isQuietHours(now:, settings:, calendar:) -> Bool` — handles overnight windows where `start > end`.
- `isInsideWakeWindow(now:, settings:, calendar:) -> Bool`.
- `dailyState(...) -> HydrationDailyState`.
- `evaluate(state:, now:, settings:, calendar:) -> HydrationEvaluation` — the full suppression ladder:

```
1. !smartTrackingEnabled    → suppress(trackingDisabled)
2. hour < wakeStart         → suppress(beforeWakeWindow)
3. hour ≥ wakeEnd           → suppress(afterWakeWindow)
4. isQuietHours             → suppress(quietHours)
5. lastDrink < cooldownMin  → suppress(recentDrink)
6. pace in [ahead, onTrack] → suppress(paceOK)
7. pace == behind           → remind(.gentle)
8. pace == veryBehind       → remind(.stronger)
```

Unit-tested in [HydrationEvaluatorTests.swift](AiQoTests/HydrationEvaluatorTests.swift) — 16 XCTest cases covering every branch plus phrase-selection and the single-canonical-source dedup invariant.

### 22.5 Service Layer — HydrationService + Widget Bridge

[HydrationService.swift](AiQo/Features/SmartWaterTracking/Services/HydrationService.swift) is a `@MainActor ObservableObject` singleton. Responsibilities:

- **First-launch bootstrap**: if `!HydrationSettingsStore.isGoalUserSet()`, seed `settings.goalML = recommendedGoalML(forWeightKg: UserProfileStore.shared.current.weightKg)` and persist — exactly once.
- **`refreshState(now:)`**: reads the canonical HealthKit sum via `HealthKitService.shared.getWaterIntake()` (which uses `HKStatisticsQuery.cumulativeSum` so manual + Apple Health samples dedup at the HealthKit boundary — we don't roll our own). Also probes the most recent sample via `fetchMostRecentQuantitySample(for: .dietaryWater)` and classifies its source by `bundleIdentifier` comparison against `Bundle.main.bundleIdentifier`.
- **`reevaluateAndSchedule(now:)`**: the single orchestration entry point. Order matters:
  1. `drainWidgetTapsIntoHealthKit()` — drains the widget tap counter into HealthKit (see §22.8).
  2. `refreshState(now:)` — now reads the complete total including drained samples.
  3. `publishWidgetSnapshot()` — writes consumed + goal + language to the App Group.
  4. Run evaluator → `cancelPendingReminder()` → if `.remind(intensity)` call `scheduleReminder`.
- **`settings.didSet`**: persists, mirrors into Captain Memory (§22.7.1), and re-publishes the widget snapshot so the Stepper-edited goal reaches the Home Screen within a frame.

Two MainActor helpers the entire feature leans on:

- **`currentDialect()`** — reads UserDefaults key `aiqo.captain.dialect` and falls back to `.iraqi` (matching `NotificationBrain`'s own fallback at line 76 of [NotificationBrain.swift](AiQo/Features/Captain/Brain/06_Proactive/NotificationBrain.swift)). Hydration reminders now speak in whatever Captain dialect the user later selects, with zero hardcoded `"iraqi"` strings inside the hydration code.
- **`writeSettingsToMemory()`** — see §22.7.1.

Call-sites that trigger `reevaluateAndSchedule`:
- [HomeViewModel.addWater(liters:)](AiQo/Features/Home/HomeViewModel.swift) — after every successful `HealthKitService.logWater` write.
- [HomeViewModel.onAppBecameActive()](AiQo/Features/Home/HomeViewModel.swift) — so widget taps accumulated while the app was backgrounded get drained on first activation.

### 22.6 Notification Integration — `.hydrationReminder`

No new notification system. The feature extends the existing pipeline at three tight seams:

- [NotificationIntent.swift](AiQo/Features/Captain/Brain/06_Proactive/Types/NotificationIntent.swift) — new `.hydrationReminder` case on the `NotificationKind` enum. Raw value `"hydrationReminder"` is stable; any rename would break persisted delivery history.
- [NotificationBrain.swift:198](AiQo/Features/Captain/Brain/06_Proactive/NotificationBrain.swift:198) — new category mapping `case .hydrationReminder: return "CAPTAIN_HYDRATION"`.
- [TemplateLibrary.swift](AiQo/Features/Captain/Brain/06_Proactive/Composition/TemplateLibrary.swift) — fallback template so `MessageComposer` has safe copy if a caller ever forgets `precomposedTitle` / `precomposedBody`. In practice `HydrationService` always precomposes, so this is a defensive default.

**Dialect-aware phrase pool** — [HydrationPhrases.swift](AiQo/Features/SmartWaterTracking/Localization/HydrationPhrases.swift) provides `(intensity × language × dialect) → Phrase`:

| Dialect | `.gentle` | `.stronger` |
|---|---|---|
| `.iraqi` | "شربة ماي" / "خذ شوية ماي هسه — بسيطة." | "جسمك يدز إشارة" / "خذ شربة ماي الحين." |
| `.gulf` | "وقت الماي" / "خذ شوية ماي الحين — بسيطة." | "جسمك يبي ماي" / "خذ شربة ماي الحين." |
| `.levantine` | "وقت المي" / "خود شوي مي هلق." | "جسمك بدو مي" / "خود شربة مي هلق." |
| `.msa` | "وقت الماء" / "تناول بعض الماء الآن." | "جسمك بحاجة للماء" / "اشرب الماء الآن." |
| English | "Water break" / "Take a small sip now." | "Time to drink" / "Grab some water now." |

All phrases are short, non-medical, non-prescriptive. No numbers ("2 L") that would identify the user. `PersonaGuard` validates them defensively inside `NotificationBrain`, and `PrivacySanitizer` scrubs them before delivery — same pipeline every other notification kind goes through.

**Scheduling — one smart reminder, pace-adaptive delay**. The initial implementation also pre-scheduled a "follow-up" for `.stronger` cases; an audit of `GlobalBudget.recordDelivered` → `CooldownManager.recordDelivery` confirmed that the 2h global / 6h per-kind cooldown is recorded at **schedule-time**, not fire-time, meaning a second same-kind submit inside one re-evaluation tick is always rejected. The follow-up was dead code in 100 % of branches. Simplified to a single reminder:

```
scheduleReminder(intensity):
    fireDate = now + (.gentle: 30 min | .stronger: 10 min)
    identifier = "aiqo.hydration.smart.reminder"   // stable, replaceable
    priority = .low                                // passive interruption level
    customPayload = { language, dialect, intensity }
    precomposedTitle/Body from HydrationPhrases
```

Delivery cadence guarantee: ≤1 hydration reminder every 6 h via `CooldownManager.perKindCooldownSeconds`. In a 14 h wake window that's ≤ 2 deliveries/day. If the user drinks between evaluations the pending reminder is cancelled and replaced by identifier — never stacked, never stale.

### 22.7 System Integration — Four Surfaces

#### 22.7.1 Captain Memory

Intentional, narrow integration: only preferences, never raw logs. The new memory category `"hydration"` holds two keys:

- `hydration_goal` — value formatted as `"%.2f L"` (e.g. `"2.50 L"`), confidence 0.9, source `user_explicit`.
- `hydration_smart_enabled` — value `"on"` or `"off"`, confidence 0.9.

A third slot `hydration_pattern` (e.g. "often needs reminders in the afternoon") is reserved in `keyLabel` but **not auto-populated**. Producing a pattern deterministically would require per-time-of-day aggregates that conflict with the no-raw-logs rule unless only the derived label is stored; left as a clearly-scoped future extension rather than a stub.

Writes happen in [HydrationService.writeSettingsToMemory()](AiQo/Features/SmartWaterTracking/Services/HydrationService.swift), called from `init()` after bootstrap and from `settings.didSet`. Reads surface automatically via `MemoryStore.allMemories()` grouped-by-category inside [CaptainMemorySettingsView.swift](AiQo/Features/Captain/Brain/10_Observability/CaptainMemorySettingsView.swift); the view's `categoryLabel`, `keyLabel`, and `valueLabel` switches gained hydration cases including the `"on"/"off"` → `memory.value.enabled/disabled` mapping.

**Raw-key localization bug fixed as part of this pass.** The audit surfaced that only `memory.cat.weekly` and `memory.cat.challenge` existed in `Localizable.strings`; the other 11 category keys referenced by the view (`memory.cat.identity`, `memory.cat.body`, `memory.cat.goal`, `memory.cat.preference`, `memory.cat.mood`, `memory.cat.injury`, `memory.cat.nutrition`, `memory.cat.workoutHistory`, `memory.cat.sleep`, `memory.cat.insight`, `memory.cat.recordProject`) were missing in both `ar.lproj` and `en.lproj`, so the UI was displaying literal strings like `"memory.cat.body"` as the section header. All 11 are now populated in both languages plus the new `memory.cat.hydration`.

#### 22.7.2 Medical Disclaimer

[MedicalDisclaimerDetailView.swift](AiQo/Features/Compliance/MedicalDisclaimerDetailView.swift) gained a second glass card `hydrationDisclaimerCard`, rendered below the primary "AiQo is not a medical device" card via the shared `disclaimerCard(title:body:)` helper — identical radius / material / typography. Copy is hardcoded bilingual (matching the file's existing pattern) and reads exactly:

- **Arabic**: "قد يقدم AiQo تذكيرات عامة بشرب الماء لتحسين نمط الحياة، لكن هذه التوصيات لا تُعتبر نصيحة طبية. احتياجات الجسم من الماء تختلف حسب العمر، الوزن، النشاط، والظروف الصحية."
- **English**: "AiQo may provide general hydration reminders to support a healthy lifestyle. These are not medical recommendations. Hydration needs vary depending on age, weight, activity level, and medical conditions."

Kept out of the bullet list so the "consult a physician before…" framing stays about health decisions, not a water reminder.

#### 22.7.3 AI Data Disclosure

[AIDataUseDisclosureRows](AiQo/Features/Compliance/AIDataUseDisclosure.swift) grew from 5 rows to 6 — new row with icon `drop.fill`, `titleKey: "ai.consent.water.title"`, `detailKey: "ai.consent.water.detail"`, placed between "What is not sent" and "Your choice". Detail copy explicitly names the four data elements used (daily total, goal, time context, last drink time), both sources (manual + Apple Health), and the hard boundary (summarized/sanitized context only — **raw hydration logs are never sent**).

#### 22.7.4 Privacy Policy

[LegalView](AiQo/UI/LegalView.swift) reads `"legal.privacy.content"` verbatim as a single embedded string — no WebView, no markdown. The string grew a new numbered section:

**6. Water Tracking Data** (with sub-paragraphs: *What we collect / How we use / What we do not do / Your control*). Previous "6. Contact Us" renumbered to 7. The four sub-paragraphs explicitly commit to: no sale of water data, no raw HealthKit hydration logs to any third party, and concrete user controls (disable smart water tracking in the water screen, revoke HealthKit in device settings, reset by clearing app data).

Both language variants ship. The Arabic is Modern Standard Arabic (matching the existing `legal.privacy.content` voice), not Iraqi — deliberately distinct from the Iraqi-flavored Captain reminders.

### 22.8 Hydration Widget (systemSmall, Interactive)

New Widget bundled alongside the existing `AiQoWidget` motion card. Same `AiQoWidget` target, same `group.aiqo` App Group, same `Palette` grammar (cardGradient, teal, stroke values mirrored verbatim in a file-private `HydrationPalette` to avoid loosening the motion widget's `private enum Palette` visibility).

**Kind**: `"AiQoHydrationWidget"`. **Family**: `.systemSmall` only.

**Visual grammar**: dark glass card (22 pt corner radius), warm-sand glow in bottom-left mirroring the motion widget's top-right mint glow, centered Circle.trim() progress arc with a mint→sand angular gradient and a subtle `shadow(color: teal.opacity(0.35), radius: 6)`, percentage text inside the ring with `contentTransition(.numericText())` for the tap animation, `"1.60 / 2.50 L"` (or `"1.60 / 2.50 ل"` in Arabic) at the bottom. Side-by-side with the motion widget they read as the same product family.

**Interactive quick-add — race-free tap counter**. The widget's HealthKit entitlement set was intentionally **not** changed; adding HealthKit to a shipping widget extension requires a new TestFlight/App Review round. Instead the widget uses a monotonic counter in the shared App Group:

```
APP                                    group.aiqo                    WIDGET
HealthKit dietaryWater (canonical)
   │
   ▼ HydrationService.refreshState
state.consumedML (mL)  ─────────►   aiqo_water_ml               ─────►  HydrationProvider
settings.goalML        ─────────►   aiqo_water_goal_ml          ─────►  HydrationProvider
settings.didSet / reevaluate        aiqo_water_last_updated
appLanguage            ─────────►   aiqo.app.language           ─────►  ar/en render
                                    aiqo_water_tap_counter      ◄─────  AddWaterIntent (+1 per tap)
drain at reevaluate()  ────────►    aiqo_water_tap_counter_seen         (app-only writer)
```

**Single-writer-per-key.** Widget only writes `tap_counter`. App writes everything else. No cross-process contention on any individual key.

**Display formula** — the widget renders `consumed + max(0, counter - seen) × 250`, so the UI never regresses even if the app hasn't drained yet. If the user taps three times while the app is closed, they see +750 mL instantly; when the app wakes, `HydrationService.drainWidgetTapsIntoHealthKit()` writes 3 individual 250 mL `dietaryWater` samples (per-sip granularity preserved), then advances `tap_counter_seen` to the exact value captured at drain-start — any taps that arrive mid-drain stay unseen for the next cycle, never double-counted, never lost.

**Button hit-target**: the entire widget body is wrapped in `Button(intent: AddWaterIntent())`, matching the motion widget's no-visible-button minimalism while remaining discoverable.

Files added to the widget target (synchronized group, auto-picked up):
- [AiQoWidget/Hydration/HydrationWidgetShared.swift](AiQoWidget/Hydration/HydrationWidgetShared.swift) — App-Group keys + widget kind + 250 mL constant. Mirror of the app-side `HydrationWidgetBridge`.
- [AiQoWidget/Hydration/AddWaterIntent.swift](AiQoWidget/Hydration/AddWaterIntent.swift) — `@MainActor AppIntent` that increments `tap_counter` and calls `WidgetCenter.reloadTimelines(ofKind: "AiQoHydrationWidget")`.
- [AiQoWidget/Hydration/HydrationWidget.swift](AiQoWidget/Hydration/HydrationWidget.swift) — `HydrationEntry`, `HydrationProvider`, `HydrationWidgetView`, widget configuration. Contains the file-private `HydrationPalette` mirror.

App side:
- [AiQo/Features/SmartWaterTracking/Services/HydrationWidgetBridge.swift](AiQo/Features/SmartWaterTracking/Services/HydrationWidgetBridge.swift) — same three constants and keys, plus `publishSnapshot(consumedML:, goalML:, appLanguage:)`, `currentPendingTapCount() -> (counter, seen)`, and `advanceTapCounterSeen(to:)`.

The tiny duplication (≈20 lines per side) is intentional — a shared framework for a compile-time-constants file is heavier than keeping mirrored copies with colocated `MUST MATCH` comments.

### 22.9 Final Reminder Flow

```
trigger (app-active OR water-add OR widget-tap-drain)
    │
    ▼
HydrationService.reevaluateAndSchedule()
    │
    ├─ drainWidgetTapsIntoHealthKit()       ← §22.8 race-free drain
    ├─ refreshState()                        ← HealthKit canonical sum + last sample source
    ├─ publishWidgetSnapshot()               ← write consumed + goal + language to group.aiqo
    ├─ HydrationEvaluator.evaluate(...)      ← pure suppression ladder §22.4
    ├─ cancelPendingReminder()               ← removes existing "aiqo.hydration.smart.reminder"
    └─ if .remind(intensity):
         NotificationBrain.request(
             intent: .hydrationReminder,
             priority: .low,
             precomposedTitle/Body from HydrationPhrases,
             fireDate: now + (gentle: 30 min | stronger: 10 min),
             identifier: "aiqo.hydration.smart.reminder",
             customPayload: {language, dialect, intensity}
         )
         │
         ▼
      GlobalBudget + PersonaGuard + PrivacySanitizer + UNUserNotificationCenter
         │
         ▼
      CooldownManager.recordDelivery(.hydrationReminder)   ← 6h per-kind lockout starts here
```

### 22.10 Tests

[HydrationEvaluatorTests.swift](AiQoTests/HydrationEvaluatorTests.swift) — 16 XCTest cases in the existing `AiQoTests` target:
- `expectedByNow` before/inside/after wake window
- Pace band edges (ahead ≥110 %, onTrack 90–110 %, behind 60–90 %, veryBehind <60 %)
- Pace classification when `expectedByNowML == 0` (returns `onTrack`, not `veryBehind`)
- Quiet hours overnight window edge cases
- Every `SuppressReason` branch hit explicitly
- Both `.remind` intensity branches
- Phrase selection for Arabic `.gentle` and English `.stronger` (verifying no medical prose leaks)
- `HydrationDailyState.remainingML` never negative when overconsumed
- Dedup invariant — documents that `consumedML` is always the HealthKit cumulative sum, never double-counted by the evaluator

Test runtime was not exercised because of a pre-existing Watch-target Info.plist issue (`AiQoWatch Watch App.app` missing `WKApplication` / `WKWatchKitApp` key blocks the simulator install of the test host). Compile + link are verified green via `xcodebuild build-for-testing`.

### 22.11 Build State After §22

| Metric | Before §22 | After §22 |
|---|---|---|
| Main-app build | SUCCEEDED | **SUCCEEDED** |
| Test-target build | SUCCEEDED | **SUCCEEDED** |
| New Swift files | — | 10 app + 3 widget = 13 |
| Modified Swift files | — | 9 |
| New unit tests | 368 | **384** (+16) |
| New localization keys (en + ar) | — | **35** per language |
| New App Group keys | 6 (motion widget) | 9 (+3 hydration) |
| Widget bundles in `AiQoWidgetBundle` | 3 iOS + 1 Live Activity | **4** iOS + 1 Live Activity |
| New NotificationKind cases | 23 | **24** (+`.hydrationReminder`) |
| TierGate references added | — | **0** (feature is free) |

### 22.12 Ship Readiness & Known Risks

**Status: beta-ready.** Clean+stable pattern chosen at every fork. Zero new cross-target imports. Zero widget-side HealthKit entitlement changes. Zero new third-party dependencies. Every localization key has both `ar` and `en` variants.

Outstanding before production flip:

1. **Live device smoke test.** Taps → HealthKit write → 10-minute-delayed notification delivery → widget redraw need one end-to-end pass on a real device. The foreground-notification UX depends on `UNUserNotificationCenterDelegate` config that was not audited in this pass.
2. **Watch-target Info.plist.** Missing `WKApplication` / `WKWatchKitApp` key blocks the test-runner install on the simulator. Pre-existing; unrelated to §22 but gates green CI runs of the new unit tests.
3. **Native-speaker review of dialect variants.** The Gulf / Levantine / MSA phrase variants in `HydrationPhrases.swift` were authored without a native reviewer; the Iraqi variant was. Worth one pass before shipping to those cohorts.
4. **EFSA URL stability.** The journal entry URL (`efsa.europa.eu/en/efsajournal/pub/1459`) is a 2010 article; if EFSA rotates URLs it 404s from inside the app. Consider a periodic healthcheck.
5. **Weight-based goal doesn't auto-recalculate.** If the user edits their profile weight after first launch, the hydration goal stays at whatever was seeded (or whatever the user later Steppered to). Intentional — respects user choice over auto-magic. A "Reset to recommended" affordance is a one-line follow-up call to `HydrationSettings.recommendedGoalML(forWeightKg:)`.
6. **Late-chronotype users.** Default wake window 08:00–22:00 doesn't fit someone who sleeps 02:00–10:00. `HydrationSettings` already carries `wakeStartHour` / `wakeEndHour` fields but no UI exposes them. If telemetry shows heavy `.beforeWakeWindow` / `.afterWakeWindow` suppression, add a wake-window picker.
7. **Dialect key has no UI.** `UserDefaults` key `aiqo.captain.dialect` is live in `HydrationService.currentDialect()` but nothing writes it today. Default `.iraqi` applies. When a Captain language UI ships it plugs in with zero hydration code changes.
8. **Privacy-policy section renumbering.** Old "6. Contact Us" → "7. Contact Us". In-app code references the localization key, not section numbers, so app is safe. Any external docs, App Store "What's New" copy, or compliance tracker that cited the old numbering needs a pass.

Flip `SMART_WATER_TRACKING_ENABLED=false` in Info.plist if any of the above surface a P0 post-launch; kill switch lands hydration back to the v1 bottle + add-button UI with no hydration notifications scheduled.

### 22.13 Files Added / Modified

**Added — app target (Features/SmartWaterTracking/) — 7 files:**
- `Models/HydrationDailyState.swift` — pace / source / evaluation value types
- `Models/HydrationSettings.swift` — prefs + `recommendedGoalML(forWeightKg:)` + `HydrationSettingsStore`
- `Services/HydrationEvaluator.swift` — pure evaluator
- `Services/HydrationService.swift` — `@MainActor ObservableObject`, bootstrap, drain, publish, schedule
- `Services/HydrationWidgetBridge.swift` — app-side App-Group contract mirror
- `Localization/HydrationPhrases.swift` — 5 dialect × 2 intensity = 10 Arabic/English phrase pairs
- `Views/SmartHydrationSection.swift` — glassmorphism card (corner 24, diagonal sheen, soft shadow, stepper, WHO/EFSA links)

**Added — widget target (AiQoWidget/Hydration/) — 3 files:**
- `HydrationWidgetShared.swift` — widget-side App-Group contract mirror
- `AddWaterIntent.swift` — interactive `AppIntent`
- `HydrationWidget.swift` — provider / entry / view / widget config / `HydrationPalette`

**Added — tests — 1 file:**
- `AiQoTests/HydrationEvaluatorTests.swift` — 16 cases

**Modified — app target:**
- `AiQo/Core/Config/AiQoFeatureFlags.swift` — new `SMART_WATER_TRACKING_ENABLED` flag (default true)
- `AiQo/Info.plist` — new feature-flag entry
- `AiQo/Features/Captain/Brain/06_Proactive/Types/NotificationIntent.swift` — `.hydrationReminder` NotificationKind case
- `AiQo/Features/Captain/Brain/06_Proactive/NotificationBrain.swift` — `CAPTAIN_HYDRATION` category mapping
- `AiQo/Features/Captain/Brain/06_Proactive/Composition/TemplateLibrary.swift` — fallback template
- `AiQo/Features/Captain/Brain/10_Observability/CaptainMemorySettingsView.swift` — `categoryLabel`, `keyLabel`, `valueLabel` hydration cases
- `AiQo/Features/Compliance/MedicalDisclaimerDetailView.swift` — new `hydrationDisclaimerCard`
- `AiQo/Features/Compliance/AIDataUseDisclosure.swift` — new "Water data" disclosure row
- `AiQo/Features/Home/HomeView.swift` — `WaterDetailSheetView` sheet embed unchanged at call-site; section renders inside the sheet
- `AiQo/Features/Home/HomeViewModel.swift` — `addWater` and `onAppBecameActive` call `HydrationService.shared.reevaluateAndSchedule()`
- `AiQo/Features/Home/WaterDetailSheetView.swift` — `ScrollView` wrap + `SmartHydrationSection` embed (flag-gated), close button z-order preserved

**Modified — widget target:**
- `AiQoWidget/AiQoWidgetBundle.swift` — registered `HydrationWidget()` (iOS only, preserved existing watch & LiveActivity conditionals)

**Modified — localization (both `ar.lproj` and `en.lproj`):**
- `Localizable.strings` — 35 new keys per language:
  - Smart hydration UI: `hydration.smart.toggle.title`, `hydration.smart.toggle.subtitle`, `hydration.goal.title`
  - WHO/EFSA guidance: `hydration.guidance.title`, `hydration.guidance.body`, `hydration.guidance.more`, `hydration.guidance.factors`, `hydration.guidance.link.who`, `hydration.guidance.link.efsa`
  - Memory category fillers (fix for §22.7.1 raw-key bug): `memory.cat.identity`, `memory.cat.goal`, `memory.cat.body`, `memory.cat.preference`, `memory.cat.mood`, `memory.cat.injury`, `memory.cat.nutrition`, `memory.cat.workoutHistory`, `memory.cat.sleep`, `memory.cat.insight`, `memory.cat.recordProject`
  - Hydration memory: `memory.cat.hydration`, `memory.key.hydrationGoal`, `memory.key.hydrationSmart`, `memory.key.hydrationPattern`, `memory.value.enabled`, `memory.value.disabled`
  - AI data disclosure: `ai.consent.water.title`, `ai.consent.water.detail`
  - Privacy policy: `legal.privacy.content` rewritten with new section 6 (Water Tracking Data) and renumbered "Contact Us" to 7

No files removed. No TierGate changes. No DevOverride changes. No Info.plist permission additions (widget already has `group.aiqo`).

---

## 23. Water Detail Sheet — Hero Redesign (2026-04-22, pass 2)

Same-day follow-up to §22. The Smart Water Tracking feature shipped functionally correct but with a **brand-breaking hero** at the top of [WaterDetailSheetView.swift](AiQo/Features/Home/WaterDetailSheetView.swift): a photographic `WaterBottleView` illustration wrapped in a saturated `#4A9EE7`-class blue fill, plus a bright-blue "+0.25 L" capsule button. This read as stock-fitness UI, not AiQo — every other surface in the app uses calm glassmorphism over mint / sand accents. The `SmartHydrationSection` card directly below (added in §22.6) is on-brand and was explicitly **kept untouched**; this pass redesigns only the hero region above it plus the bottom add button, replacing both with a native SwiftUI progress ring and a three-chip quick-add row.

Constraints held throughout:
- No raster asset, no photographic illustration, no emoji.
- No blue color anywhere in the hero — `#4A9EE7` is fully evicted; `waterBlue` constant deleted from the file.
- `SmartHydrationSection`, the sheet's `ScrollView`, `.presentationDetents`, `.presentationDragIndicator`, `.presentationBackground`, close-button z-order, and every caller of `HomeViewModel.addWater(liters:)` stay exactly as they were.
- `HydrationService` / `HydrationEvaluator` / `HydrationWidgetBridge` / the widget target — all untouched.

### 23.1 Decision — new `mintSoft` / `sandSoft` brand accents

The canonical `AiQoColors.mint` (`#CDF4E4`) and `AiQoColors.beige` (`#F5D5A6`) are one step brighter than needed: a progress ring rendered with those against `.ultraThinMaterial` washes out, especially in light mode. Rather than retune the existing palette (which 15+ files rely on) or invent a top-level `Color.aiqoMint` extension (which would add a second source of truth), the pass adds two new constants next to the existing ones:

```swift
// AiQo/DesignSystem/AiQoColors.swift
enum AiQoColors {
    static let mint = Color(hex: "CDF4E4")
    static let beige = Color(hex: "F5D5A6")

    // Softer accents — one step deeper than mint/beige so progress rings and
    // wellness surfaces hold weight against `.ultraThinMaterial` without
    // washing out. Additive: do not replace mint/beige.
    static let mintSoft = Color(hex: "B7E5D2")
    static let sandSoft = Color(hex: "EBCF97")
}
```

These are the exact hex values from the AiQo brand spec. All other files that currently declare private `mint`/`sand` constants inline (AuthFlowUI, Profile, Kitchen, Gym, Tribe, etc. — 10+ spots with slightly drifted values) are intentionally **not refactored** in this pass; a design-system consolidation is a separate future task. The new constants are available for adoption in future brand-consistent surfaces.

### 23.2 New File — `WaterHeroRingView.swift`

[AiQo/Features/Home/Components/WaterHeroRingView.swift](AiQo/Features/Home/Components/WaterHeroRingView.swift) — new ~170-line component, the entire hero. Stateless: takes `consumedLiters: Double` and `goalLiters: Double`, renders. No `@ObservedObject`, no singleton reads — callers pass the numbers.

Visual grammar:
- **Outer ring** 220 × 220 pt, lineWidth 16, `.lineCap: .round`.
- **Track** — `AiQoColors.mintSoft.opacity(trackOpacity)` where `trackOpacity = colorScheme == .dark ? 0.12 : 0.18`. Dark-mode bump keeps the progress stroke readable against the dimmer material.
- **Progress arc** — `Circle().trim(from: 0, to: progress)` stroked with an `AngularGradient` cycling `mintSoft → sandSoft → mintSoft` over 360°, then rotated `-90°` so progress starts at 12 o'clock. A subtle `shadow(color: .mintSoft.opacity(0.25), radius: 14, y: 4)` lands only on the progress arc.
- **Center stack** — big number (SF Rounded `.black` weight, size 52) with `.numericText(value: consumedLiters)` content transition so each tap animates, unit label (`ل` or `L` derived from `Locale.current.language.languageCode`), and a tertiary sublabel `"من %.1f ل"` / `"of %.1f L"`.
- **Overflow behavior** — `progress` is capped at `min(1, consumedLiters / goalLiters)`: the ring never over-rotates past 100 %, but the big number keeps counting. `percent` likewise caps at 100.
- **Animation** — `.spring(response: 0.55, dampingFraction: 0.85)` bound to the `progress` value; the ring and pill settle together.
- **Dynamic Type** — `dynamicTypeSize(...DynamicTypeSize.accessibility1)` on the big number so it cannot blow past the ring at XXXL sizes; regular Dynamic Type up to accessibility1 is respected.
- **Accessibility** — `.accessibilityElement(children: .combine)` with label "تتبع الماء اليومي" / "Daily water tracking" and value "X.X لتر من X.X لتر، NN بالمئة" formatted via a locale-aware `NumberFormatter` (maximumFractionDigits = 1).
- **Reserved tap surface** — `.contentShape(Circle())` on the whole ring. No gesture attached today; marked as the insertion point for a future goal picker.

Three preview providers ship with the file: Light × AR × 60 %, Dark × AR × 7 %, Light × EN × 112 % (the cap-behaviour case). All previews set `\.locale` and `\.layoutDirection` explicitly.

### 23.3 Surgical Edits — `WaterDetailSheetView.swift`

Properties + state, body content, and subview implementations were all edited. The file stays at 372 lines (was 231 lines pre-§22 hero embed; the net addition is the chip row + custom sheet).

**Removed:**
- `private let waterBlue = Color(red: 0.24, green: 0.67, blue: 0.93)` — the old `#4A9EE7`-class blue.
- `private let addAmount: Double = 0.25` — no longer needed; each chip carries its own amount literal.
- `@State private var addWaterFeedbackTrigger` — replaced by `UIImpactFeedbackGenerator` + `UINotificationFeedbackGenerator` calls.
- `amountLabel` (48 pt number floating above the bottle) — the big number now lives inside the ring.
- `waterBottle` call site — `WaterBottleView(currentLiters:)` is no longer referenced anywhere in this file. **The `WaterBottleView` source file is left in the repo**, orphaned, flagged under §23.7.
- `addWaterButton` (blue capsule) — replaced by the chip row.
- `addWater()` private method — replaced by `performAdd(amount:isCustom:)`.

**Added (as properties):**
- `var goalLiters: Double = 2.5` — explicit parameter; caller is the source of truth. Default keeps previews working when the sheet is instantiated standalone.
- `@State private var showCustomSheet = false` — drives the nested custom-amount sheet.

**Added (as subviews):**
- `titleLabel` retuned to `17 pt bold rounded, centered` (was 24 pt heavy).
- `percentagePill` — small `.ultraThinMaterial` capsule, 14 × 6 padding, with `mintSoft.opacity(0.35)` 0.5 pt stroke. Shows "XX%" with `.contentTransition(.numericText(value:))` animated via the same spring.
- `quickAddRow` — `HStack(spacing: 10)` of three chips: `quickAddChip(+0.25 ل, 0.25)`, `quickAddChip(+0.5 ل, 0.5)`, `customChip`.
- `quickAddChip(title:amount:a11yAmount:)` — capsule-shaped `.ultraThinMaterial` with a `mintSoft.opacity(0.35)` tint overlay and a `mintSoft.opacity(0.6)` 0.5 pt stroke, 16 × 12 padding, `minWidth: 44, minHeight: 44` guaranteeing HIG tap target, `.accessibilityLabel` / `.accessibilityHint` from new localization keys.
- `customChip` — same capsule grammar but tinted with `sandSoft` to visually signal it's the different action type.
- `performAdd(amount:isCustom:)` — the unified action method. Animates `currentWaterLiters` via the same spring, fires the correct haptic (soft impact for quick chips, success notification for custom confirm), then calls `onAddWater?(amount)`. The callback path into HomeView / `viewModel.addWater(liters:)` / HealthKit is preserved byte-for-byte.
- Private `CustomWaterAmountSheet` struct at the bottom of the file. `.height(280)` detent, `.ultraThinMaterial` background matching parent, drag indicator visible. Contains an `HStack` with the amount (big rounded number, `.numericText(value:)`) and the unit label, a `Slider(value: $amount, in: 0.05...1.0, step: 0.05)` tinted with `AiQoColors.mintSoft`, and a single "إضافة" / "Add" capsule button that calls `onConfirm(amount)` then `dismiss()`. The concatenated `Text + Text` pattern caught by the compiler during the pass ("Cannot convert value of type `some View` to `Text`" — modifier-chain return type) was resolved by switching to an explicit `HStack`.

**Preserved byte-for-byte** (per the edit protocol):
- The `ScrollView` wrap with `.scrollIndicators(.hidden)`.
- The close button (top-leading, z-order kept above the ScrollView via `ZStack(alignment: .topTrailing)`).
- The `SmartHydrationSection` embed, still flag-gated by `FeatureFlags.smartWaterTrackingEnabled`.
- The convenience init and the `.waterDetailSheet(...)` presentation helper extension, both gaining only a `goalLiters: Double = 2.5` default parameter — no caller breaks.

### 23.4 Hero Layout Flow

```
┌─ ScrollView ──────────────────────────────────┐
│  40 pt top spacer                             │
│                                               │
│  "الماء"                         (17 pt bold) │
│                                               │
│   ╭──────────────────────╮                    │
│   │      ╭────╮          │                    │
│   │     ╱      ╲         │     ← WaterHeroRingView
│   │    │  1.5  │         │       220 × 220
│   │     ╲  ل   ╱         │       mint→sand angular
│   │      ╲ من 2.5 ل      │       track @ 0.18 (light) / 0.12 (dark)
│   │      ╰────╯          │                    │
│   ╰──────────────────────╯                    │
│                                               │
│           [ 60% ]                             │     ← percentagePill (12 pt gap)
│                                               │
│   [+0.25 ل] [+0.5 ل] [جرعة مخصصة]            │     ← quickAddRow (24 pt gap)
│                                               │
│   ╭──────────────────────────────────╮        │
│   │  SmartHydrationSection (unchanged)│       │     ← §22 card, 24 pt gap above
│   │  toggle · pace · goal stepper ·   │       │
│   │  WHO/EFSA links                   │       │
│   ╰──────────────────────────────────╯        │
│                                               │
│  40 pt bottom padding                         │
└───────────────────────────────────────────────┘

 × close button (top-trailing, above ScrollView)
```

Tapping any chip → `performAdd(amount, isCustom: false)` → spring animation on `currentWaterLiters` → soft haptic → `onAddWater?(amount)` → `HomeView` wraps that in `Task { await viewModel.addWater(liters: addedLiters) }` → `HealthKitService.logWater` → `HydrationService.reevaluateAndSchedule` → state / reminder / widget reconciliation (§22.9 pipeline, unchanged).

Tapping `جرعة مخصصة` / `Custom` → `showCustomSheet = true` → nested sheet with slider → "إضافة" / "Add" → `performAdd(amount, isCustom: true)` → spring animation → success notification haptic → same `onAddWater` path.

### 23.5 Haptic Discipline

Explicit call-sites (no more `sensoryFeedback` attachment):
- **Ring tap** — no haptic. Ring is inert today; the reserved tap surface exists so a future goal picker can attach without restructuring the layout.
- **Quick-add chip tap** — `UIImpactFeedbackGenerator(style: .soft).impactOccurred()`. Water is a calm action, not a confirmation beat. Soft over medium.
- **Custom confirm button** — `UINotificationFeedbackGenerator().notificationOccurred(.success)`. Fires once, at the moment the amount commits. The sheet dismisses on the same frame.

### 23.6 One-line HomeView Edit

[AiQo/Features/Home/HomeView.swift:240-247](AiQo/Features/Home/HomeView.swift) — the `.waterDetail` case in `destinationView(for:)`. One parameter inserted between `currentWaterLiters` and `onAddWater`:

```diff
             WaterDetailSheetView(
                 currentWaterLiters: $waterSheetLiters,
+                goalLiters: HydrationService.shared.settings.goalML / 1000,
                 onAddWater: { addedLiters in
                     Task {
                         await viewModel.addWater(liters: addedLiters)
                     }
                 }
             )
```

Nothing else in HomeView changed. `.presentationDetents([.medium, .large])`, `.presentationDragIndicator(.visible)`, `.presentationBackground(.ultraThinMaterial)` all preserved. The sheet still opens at `.medium` by default; the new hero + chip row + SmartHydrationSection scrolls comfortably at that detent and sits without scrolling at `.large`.

### 23.7 Follow-up Cleanup (Flagged, Not Done)

Per the edit protocol, no unrelated code was deleted. Items worth a separate commit:

1. **[WaterBottleView.swift](AiQo/Features/Home/WaterBottleView.swift) is now orphaned** — zero call sites remain in `WaterDetailSheetView` and a repo-wide grep confirms no other caller. The file should be deleted in a dedicated cleanup commit along with any `AnimatedWaterBottleView` it exports. Left on disk today so the diff of this pass is strictly additive on the hero and strictly removing-only-what-the-hero-owned.
2. **Deprecated localization keys retained for rollback** — `water.add`, `water.a11y.add`, `water.a11y.hint` are untouched in both `.strings` files. No consumer references them after this pass; safe to remove alongside the WaterBottleView cleanup.
3. **Ring tap is inert** — `.contentShape(Circle())` makes the full ring a touch target, but no gesture is attached. Future enhancement: a goal-picker sheet on tap, wiring `HydrationService.shared.settings.goalML` the same way the §22 stepper already does. Touch target + reserved space are already there.

### 23.8 Build State After §23

| Metric | Before §23 | After §23 |
|---|---|---|
| Main-app build | SUCCEEDED | **SUCCEEDED** |
| New warnings introduced | — | **0** |
| New Swift files | — | 1 (`WaterHeroRingView.swift`) |
| Modified Swift files | — | 3 (`AiQoColors.swift`, `WaterDetailSheetView.swift`, `HomeView.swift`) |
| New localization keys (en + ar) | — | **10** per language |
| New brand colors | 2 (`mint`, `beige`) | **4** (+`mintSoft`, `sandSoft`) |
| Blue hex values in the hero path | 1 (`waterBlue #4A9EE7`) | **0** |
| Raster/illustration hero assets used | 1 (`WaterBottleView`) | **0** |
| TierGate references added | — | **0** (feature remains free) |

### 23.9 Known Risks

1. **`mintSoft` / `sandSoft` vs existing private palettes.** 10+ files privately re-declare mint/sand at slightly different hex values (AuthFlowUI at `#B7E5D2` / `#EBCF97` — matching the new brand spec, but file-private; Profile, Gym, Kitchen, Tribe with their own shades). The pass **intentionally did not unify** those to avoid a cross-feature regression risk. Someone doing a design-system consolidation sprint should start with this as item #1.
2. **Default `goalLiters: 2.5`** in the convenience init / sheet helper is a pragmatic fallback. Real presentation always passes `HydrationService.shared.settings.goalML / 1000`. Tests or previews that use the convenience init get the default.
3. **`locale.language.languageCode` check for unit label.** `WaterHeroRingView.unitLabel` and `CustomWaterAmountSheet.unitLabel` pick between `ل` and `L` via `Locale.current`. This respects the device locale but does **not** respect the app-level override in `AppSettingsStore.appLanguage`. For the v1.0.1 audience the device locale is reliably Arabic, so the mismatch window is narrow; if the app-language override is later used as the canonical source, both getters need to flip to `AppSettingsStore.shared.appLanguage.rawValue == "ar"`.
4. **No blue remains — verified.** Grep for `#4A9EE7`, `Color(red: 0.24`, and the historical `waterBlue` symbol inside the hero path returned zero hits. `SmartHydrationSection` still uses its own internal `waterBlue` (added pre-§22) for the drop-icon tint and the diagonal sheen gradient — per the edit protocol, that file is out of scope for this pass. If the "no blue anywhere in the water sheet" rule is later tightened, `SmartHydrationSection` is the one remaining offender.
5. **Dynamic Type cap at `accessibility1`.** Above that the big number would blow past the 220 pt ring. Consider a responsive ring size as a future improvement, or a dedicated "large text" layout that drops the ring in favor of an enlarged number.

### 23.10 Files Added / Modified

**Added:**
- `AiQo/Features/Home/Components/WaterHeroRingView.swift` (170 lines; three preview providers)

**Modified:**
- `AiQo/DesignSystem/AiQoColors.swift` — `+mintSoft`, `+sandSoft`
- `AiQo/Features/Home/WaterDetailSheetView.swift` — hero region surgical replacement (title retuned, old amount/bottle/blue button removed, percentage pill + three-chip quick-add row + unified `performAdd` action + private `CustomWaterAmountSheet` added). Convenience init and `.waterDetailSheet(...)` helper gained a default `goalLiters` parameter; all call sites remain source-compatible.
- `AiQo/Features/Home/HomeView.swift` — one parameter inserted in the `.waterDetail` case (`goalLiters: HydrationService.shared.settings.goalML / 1000`). No other line touched.
- `AiQo/Resources/en.lproj/Localizable.strings` — 10 new keys in a new `Water Detail — Hero ring + quick-add chips` block.
- `AiQo/Resources/ar.lproj/Localizable.strings` — matching 10 keys in Arabic.

**Not touched:**
- `AiQo/Features/Home/WaterBottleView.swift` (orphaned, flagged, not deleted).
- `AiQo/Features/SmartWaterTracking/**` — the entire §22 domain/service/widget tree untouched.
- `AiQo/Features/Home/HomeViewModel.swift` — `addWater(liters:)` signature and callers untouched.
- Any entitlements, Info.plist, or widget target file.
- Any test file.

Zero deletions. Zero third-party dependencies. Zero new warnings.
