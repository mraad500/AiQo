# AiQo Master Blueprint 17

*The single document that explains the AiQo iOS app — what it is, how it is built, and how every part fits together. Replaces all prior `AiQo_Master_Blueprint_*` files. Author: Mohammed Raad. Snapshot taken at commit `fa27a7f` on 2026-04-19. **Updated 2026-04-20** with the App Store submission hardening pass — see §21 for the full change-list (age gate, permission descriptions, EXIF/FileProtection on certificate storage, reduceTransparency helper, Info.plist cleanup, and a clean 0-warning Release build).*

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
