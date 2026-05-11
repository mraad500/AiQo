<div align="center">

<img src="AiQo.png" width="160" height="160" alt="AiQo app icon" />

# **AiQo**

*Master Blueprint · v18*

**Arabic-first AI health & coaching · iOS · Captain Hamoudi**

</div>

---

# AiQo Master Blueprint 18

*The current, forward-looking master document for the AiQo iOS app. Authored 2026-05-10 by the in-tree hygiene pass. **Supersedes** [Blueprint 17](AiQo_Master_Blueprint_17.md) for forward guidance only — Blueprint 17 remains the canonical historical snapshot at commit `39ca529` and the deep-reference text for the eleven Brain subsystems, the conversation-turn data flow, the proactive-notification data flow, and the §1–§36 batch chronology. Read 17 for "how was this built"; read 18 for "what's the state today and what's next."*

---

## 0. How to use this document

This blueprint is structured to answer five questions in order:

1. **What is AiQo today?** — §1 Executive Summary
2. **What changed in this hygiene pass?** — §2 The 2026-05-10 Hygiene Pass
3. **How is the codebase laid out now?** — §3 Codebase Map (post-cleanup)
4. **What's actually wrong and what should we fix?** — §4 Security Posture, §5 Architecture Debt
5. **What's the path to v1.1 and beyond?** — §6 Roadmap, §7 Operational Notes

Cross-references use this convention: `Blueprint 17 §3.2.5` means "section 3.2.5 in the prior blueprint," `[CaptainViewModel.swift:225]` means "absolute file path with line number." Every concrete claim in §4 has a `file:line` reference so anyone can verify and fix it.

---

## 1. Executive Summary

AiQo is an Arabic-first iOS health-and-coaching app whose differentiator is **Captain Hamoudi (الكابتن حمّودي)** — a culturally-rooted AI coach with on-device memory, dialect-aware language, and a wellbeing safety net. AiQo v1.0.1 (build 18, product version `1.0.1`) is on the App Store; the active branch `brain-refactor/p-fix-dev-override` carries the §32–§36 work from Blueprint 17 (App-Knowledge layer, dynamic welcome, comparative workout analysis, Plan world-class upgrade, Kitchen world-class upgrade, the §35 14-layer cognitive brain refactor).

**Snapshot at this hygiene pass:**

| Dimension | Value |
|---|---|
| iOS app source | **590 Swift files**, ~117k LOC across the main target |
| Test target | ~63 Swift test files |
| Brain OS | 11 numbered subsystems (`00_Foundation` → `10_Observability`), ~131 Swift files |
| Active branch | `brain-refactor/p-fix-dev-override` (HEAD `39ca529`) |
| Subscription tiers | Free (`.none`) · Max ($9.99) · Intelligence Pro ($19.99) · Trial ≡ Pro |
| Cloud surface | Gemini (chat + extraction + verification), MiniMax (TTS), Supabase (proxy + auth + leaderboard) |
| App Store status | v1.0.1 live; v1.0.2 brain-refactor branch in progress |
| Live region | UAE launch (American University of the Emirates partnership), Saudi + Iraq + Gulf-other support shipping |

**Three load-bearing facts before you read further:**

1. **Privacy is enforced at the boundary, not by convention.** Every cloud call should pass through `PrivacySanitizer` (PII redaction + numeric bucketing + 4-message conversation cap) and be recorded in `AuditLogger`. The pipeline works for the canonical Captain chat path through `HybridBrain`, but **three feature-level callers bypass it** (see §4.1.1) — the hygiene pass elevates this from "tech debt" to a **P0 fix-before-the-next-release**.
2. **Tier-gating and DevOverride are the two switches that matter.** `TierGate.shared` is the single gate for paid features; `DevOverride.unlockAllFeatures` (DEBUG-only, Info.plist `AIQO_DEV_UNLOCK_ALL`) bypasses every gate so Mohammed can dogfood without paying his own paywall. Of the 46 `canAccess` call sites, 43 are wrapped with the DevOverride bypass pattern.
3. **The Brain has eleven subsystems but they form one pipeline.** A user message flows Sensing → Memory → Reasoning → Inference (cloud or on-device LLM) → Persona → Privacy → Wellbeing → reply. Proactive notifications run a parallel pipeline driven by Triggers and gated by GlobalBudget. See Blueprint 17 §3 for the full diagram and §4 for the data-flow trace.

---

## 2. The 2026-05-10 Hygiene Pass

This blueprint is itself the deliverable of a project-wide cleanup pass run on 2026-05-10. The pass touched **only files that were not part of the active in-flight branch work** — every modified Swift file in the brain-refactor branch (PromptComposer + Plan/* + the new PlanPalette) was preserved untouched. The cleanup sits *around* that work, not on top of it.

### 2.1 What was deleted

| Item | Size / count | Rationale |
|---|---|---|
| `build/` directory | **1.5 GB** | Xcode-generated, gitignored, regenerated on next build |
| `.DS_Store` files | 19 files | macOS Finder metadata, gitignored, never useful |
| `AiQo_Master_Blueprint_2 2.md` | 128 KB | Finder " 2"-suffix duplicate of an older blueprint that no longer exists at the original path; superseded by Blueprints 16/17 |
| `notes.txt` | 1 KB | Stale P_MERGE_LOST_WORK working notes from 2026-04-18 — the merge has long since landed |
| `untitled folder/` | 13 markdown files | Working-notes stash from the P0/P1/P2 brain-refactor phases (April 18) — content moved to `docs/archive/p-fix/`, then the unnamed folder was removed |

**Total disk reclaimed:** ~1.5 GB.

### 2.2 What was reorganized into `docs/`

The project root previously held **30+ historical markdown files** mixed in with current code-adjacent docs. These are now organized into a discoverable tree:

```
docs/
├── archive/
│   ├── app-store/         ← AppStore_Resubmission_Audit, AppStore_Reviewer_Reply,
│   │                        APP_STORE_CHECKLIST_v1.0.1
│   ├── batch-results/     ← BATCH_1..8_RESULT_*.md (Brain refactor batch logs)
│   ├── blueprints/        ← AiQo_Master_Blueprint_Complete, _16, _MyVibe, _MyVibe_2
│   ├── captain-brain/     ← CAPTAIN_BRAIN_RECON, CAPTAIN_CHAT_V1_1_CHANGELOG,
│   │                        Captain_Hamoudi_Diagnostic_Report, Captain_Hamoudi_Fix_Report
│   ├── handoffs/          ← HOME_SCREEN_CODEX_HANDOFF
│   └── p-fix/             ← BRAIN_OS_AUDIT, P0.1_PRIVACY_SURGERY_MAP, P0.2..P2.3_RESULT,
│                            P_FIX_1.3_RESULT, P_FIX_DEV_OVERRIDE_RESULT,
│                            P_MERGE_LOST_WORK_RESULT
├── explainers/
│   ├── ar/                ← AiQo_شرح_شامل_01..05 (Arabic product context, 2026-05-09)
│   └── en/                ← AiQo_AIContext_00..07 (English product context, 2026-04-10)
└── security/              ← (reserved for security audits — see §4)
```

Nothing was deleted from these moves — every historical document is still on disk, just discoverable now. Git treats this as a rename when content is unchanged, so blame history is preserved.

### 2.3 What stayed at root

The root is now a clean professional landing surface:

```
/
├── AiQo/                      # Main iOS app target (590 Swift files)
├── AiQoTests/                 # Test target (~63 files)
├── AiQoWatch Watch App/       # watchOS app
├── AiQoWatch Watch AppTests/
├── AiQoWatch Watch AppUITests/
├── AiQoWatchWidget/           # watchOS widget
├── AiQoWidget/                # iOS widget
├── AiQo.xcodeproj/            # Xcode project
├── Configuration/             # xcconfig files (incl. gitignored Secrets.xcconfig) + SETUP.md
├── supabase/                  # Edge Functions (captain-chat, captain-voice, etc.)
├── aiqo-web/                  # Sub-repo (gitignored, separate git history)
├── docs/                      # NEW: organized documentation tree
│   ├── archive/               # historical working notes
│   ├── explainers/            # product-context explainer series
│   └── security/              # (reserved)
│
├── AiQo_Master_Blueprint_17.md  # canonical historical reference
├── AiQo_Master_Blueprint_18.md  # this file (current/forward)
├── AIQO_TECH_DEBT.md            # living tech-debt log
├── CHANGELOG.md                 # release-notes changelog
├── LICENSE.txt
├── AiQo.png                     # app icon
├── AiQoWatch-Watch-App-Info.plist
├── AiQoWatchWidgetExtension.entitlements
├── AiQoWidgetExtension.entitlements
├── .gitignore
├── .github/
└── .claude/                   # local Claude Code workspace data (gitignored worktrees)
```

The root is no longer 65 entries deep with three competing blueprint families and two sets of explainer docs. It is now ~22 visible items, every one of which is either *active source*, *active config*, *current top-level documentation*, or a clearly-organized subdirectory.

### 2.4 Total impact

- **Disk freed:** ~1.5 GB
- **Root noise reduced:** 30+ stale markdown files moved out of the top level
- **Discoverability:** linear file dump → tree by purpose
- **Active in-flight work:** zero touched (all 11 modified files in the brain-refactor branch preserved exactly as they were)
- **Git history:** preserved (renames detected by git when committed)
- **Build/test impact:** none (nothing in `AiQo/`, `AiQoTests/`, `AiQoWatch*`, `AiQoWidget*`, `Configuration/`, or the Xcode project was touched)

---

## 3. Codebase Map (post-cleanup)

### 3.1 The five top-level Swift targets

| Target | Path | Files | Purpose |
|---|---|---|---|
| **iOS app** | `AiQo/` | 590 | The flagship target |
| **iOS tests** | `AiQoTests/` | ~63 | Unit + voice tests |
| **iOS widget** | `AiQoWidget/` | 12 | Lockscreen + Home Screen widgets (incl. Smart Water Tracking widget — §22) |
| **watchOS app** | `AiQoWatch Watch App/` | 25 | Mirrors a subset of the iPhone surface |
| **watchOS widget** | `AiQoWatchWidget/` | 0 | Assets-only at present |

Plus three test targets: `AiQoWatch Watch AppTests`, `AiQoWatch Watch AppUITests`, and the implicit unit-test target for the iOS app.

### 3.2 The iOS app internal layout

```
AiQo/
├── App/                   # 10 files — AppDelegate, SceneDelegate, MainTabView, routing, auth flows
├── AiQo.entitlements
├── AiQoCore/              # Empty placeholder (header + docc only) — see §5.4
├── Core/                  # 40 files — Config, Keychain, Localization, Models, Purchases, Security, Utilities
├── DesignSystem/          # 13 files — AiQoTheme, AiQoColors, AiQoTokens, Components, Modifiers
├── Features/              # 411 files — 18 feature modules
│   ├── Captain/           #   171 files — Brain (11 subsystems) + Voice
│   ├── Cardio/            #     1 file  — ZoneCoachingVoiceService (live, not a stub)
│   ├── Challenges/        #    10 files — General challenge system
│   ├── Compliance/        #     6 files — Legal, privacy, disclaimers
│   ├── DataExport/        #     1 file  — Export user data
│   ├── First screen/      #     1 file  — LegacyCalculationViewController (misnamed, see §4.4.2)
│   ├── Gym/               #   102 files — Workouts + Club + Plan + Quests
│   ├── Home/              #    22 files — Dashboard, charts, ScreenshotMode
│   ├── Kitchen/           #    34 files — Nutrition, smart fridge, meal plans, CookMode (§35)
│   ├── LegendaryChallenges/#    16 files
│   ├── MyVibe/            #     6 files — Spotify-blended music
│   ├── Onboarding/        #     8 files
│   ├── Profile/           #     6 files
│   ├── ProgressPhotos/    #     2 files
│   ├── Sleep/             #    11 files — Apple Intelligence on-device path
│   ├── SmartWaterTracking/#     7 files — §22 hydration with widget
│   ├── Tribe/             #     3 files — partial duplicate of /Tribe/ (see §4.4.1)
│   └── WeeklyReport/      #     4 files — Pro-tier digest
├── Frameworks/            # Spotify SDK binary
├── NeuralMemory.swift, AppGroupKeys.swift, PhoneConnectivityManager.swift, XPCalculator.swift, Info.plist, PrivacyInfo.xcprivacy
├── Premium/               # 5 files — FreeTrialManager, AccessManager, paywall logic
├── Resources/             # Localizations (ar.lproj, en.lproj), Assets.xcassets, achievement specs JSON
├── Services/              # 28 files — Analytics, CrashReporting, Notifications, Permissions, Trial
├── Shared/                # 7 files — HealthKit, level system, coin manager, watch sync codecs
├── Tribe/                 # 58 files — full Tribe module (Arena, Galaxy, Log, Models, Repositories, Stores, Views)
└── UI/                    # 13 files — Paywall + purchase UI
```

### 3.3 The Brain OS (`AiQo/Features/Captain/Brain/`)

Eleven numbered subsystems, ~131 files. See [Blueprint 17 §3.2](AiQo_Master_Blueprint_17.md) for the full file-by-file inventory.

| # | Subsystem | Files | Role |
|---|---|---:|---|
| 00 | Foundation | 6 | TierGate, DevOverride, BrainBus, BrainError, CaptainLockedView, DiagnosticsLogger |
| 01 | Sensing | 9 | BioStateEngine, CaptainHealthSnapshotService, BehavioralObserver, ContextSensor, HealthKitBridge, MusicBridge, WeatherBridge, CircadianReasoner (stub), SignalBus (stub) |
| 02 | Memory | 37 | 5 SwiftData stores, MemoryRetriever, EmotionalMiner, FactExtractor, EmbeddingIndex, SalienceScorer, TemporalIndex, MemorySchemaV1–V4 + migration plan, plus the legacy `MemoryStore.swift` (1312L) and `MemoryExtractor.swift` (the only outbound-HTTP file in the Brain — see §4.1.1) |
| 03 | Reasoning | 13 | EmotionalEngine, IntentClassifier, CulturalContextEngine, PersonaAdapter, ContextualPredictor, SentimentDetector, TrendAnalyzer, CaptainContextBuilder, CognitivePipeline (legacy), ScreenContext |
| 04 | Inference | 13 | BrainOrchestrator (846L conductor), HybridBrain (canonical Gemini caller), CloudBrain, FallbackBrain, LocalBrain, PromptComposer, PromptRouter, LLMJSONParser, PersonaGuard, plus stubs (RoutingPolicy, CulturalValidator, ResponseValidator) |
| 05 | Privacy | 5 | PrivacySanitizer (658L, the boundary), AuditLogger (106L ring buffer), plus stubs (ConsentGate, DataClassifier, DifferentialPrivacy) |
| 06 | Proactive | 26 | NotificationBrain (the single door), GlobalBudget, CooldownManager, QuietHoursManager, MessageComposer, TemplateLibrary, TriggerEvaluator, 15 trigger types |
| 07 | Learning | 7 | BackgroundCoordinator (BGTask 03:00), FeedbackLearner, WeeklyMemoryConsolidator, plus stubs |
| 08 | Persona | 9 | CaptainIdentity, DialectLibrary (4×9 phrase banks), HumorEngine, WisdomLibrary, CaptainPersonaBuilder, CaptainPersonalization, plus stubs |
| 09 | Wellbeing | 4 | CrisisDetector, InterventionPolicy, SafetyNet, ProfessionalReferral (region-aware) |
| 10 | Observability | 5 | BrainDashboard (DEBUG-only), CaptainMemorySettingsView, plus stubs |

### 3.4 What lives at the root of `AiQo/`

Four files float at the top of the iOS app target rather than living inside a feature module:

- `AppGroupKeys.swift` — shared App Group identifiers used by the iOS app, watch app, and widgets
- `NeuralMemory.swift` — older memory model, predates Brain V4 stores
- `PhoneConnectivityManager.swift` — WatchConnectivity bridge between iPhone and watchOS targets
- `XPCalculator.swift` — XP / leveling math used across features

These are intentionally module-free — they cross feature boundaries and don't belong in any single one.

---

## 4. Security Posture

This is the active "ثغرات" (vulnerabilities) section the user asked for. Every item below is concrete: file path, line number, what is wrong, what to do, and what priority. Findings are rooted in a fresh audit run on 2026-05-10. Nothing here is theoretical "best practice" advice — these are real issues in this codebase, ranked by blast radius.

### 4.1 CRITICAL — fix before the next release

#### 4.1.1 Three features bypass the privacy boundary on outbound LLM calls

This is the single most important finding of the hygiene pass. The Brain's privacy contract is that *every cloud call* passes through `PrivacySanitizer` (PII redaction + numeric bucketing + 4-message cap) **and** is recorded in `AuditLogger`. The canonical implementation is [HybridBrain.swift:122](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift) wrapped by [CloudBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift). Three feature-level callers do **not** route through this path:

| File | Line | What it does |
|---|---|---|
| [MemoryExtractor.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift) | 239 | Direct `URLSession.shared.data(for:)` to Gemini for memory-fact extraction. Sanitizes the input text but the request itself bypasses `AuditLogger`. |
| [WeeklyReviewView.swift](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift) | 398 | Same pattern, embedded inside a SwiftUI view (compounds the issue — UI code making cloud calls). |
| [SmartFridgeCameraViewModel.swift](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift) | 190 | Same pattern, with image bytes — the riskiest of the three because Vision payloads can leak more than text. |

Each of the three currently does a `CaptainProxyConfig.isChatEnabled` check and routes through the Supabase Edge Function when on, falling back to direct Gemini when off — so they all *do* understand the proxy architecture, but they never get the sanitization-and-audit pass that `CloudBrainService.generateReply(...)` provides.

**The fix is structural, not a patch:**

1. Extract a `CaptainCloudGateway` (working name) under `Brain/04_Inference/Services/` that becomes the single function any feature calls when it wants a Gemini round-trip. Existing `HybridBrainService` stays as the implementation of the chat path; the new gateway becomes the public API. Signatures should accept the prompt + intent + tier + screen context, return the response + an `AuditLogger.Entry`.
2. Migrate `MemoryExtractor`, `WeeklyReviewView`, `SmartFridgeCameraViewModel` to call the gateway. Each call site loses ~80–100 lines of URL construction, body assembly, and JSON parsing.
3. Delete the legacy `URLSession.shared.data(for:)` paths from the three files. Search for `URLSession.shared.data` outside `04_Inference/Services/` after the migration — should return zero hits.
4. Add a CI grep guard: `! grep -R "URLSession.shared" AiQo/ --include='*.swift' | grep -v '04_Inference/Services'` should be a build-time check.

**Effort:** 1–2 days for a focused refactor + smoke testing the three call sites. Low risk if the gateway is purely additive at first (introduce, migrate, delete legacy).

**Why this is CRITICAL:** the entire premise of "AiQo respects your privacy" rests on the audit log being a complete record of what left the device. Three features punching holes in that record turns the audit log from a contract into a marketing claim.

#### 4.1.2 API keys interpolated into URL query strings

In all three files above, when the proxy is *off*, the API key is built into the URL via `?key=\(apiKey)`. Concrete locations:

- [MemoryExtractor.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift) ~line 357
- [WeeklyReviewView.swift](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift) ~line 368
- [SmartFridgeCameraViewModel.swift](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift) ~line 182

URL query strings appear in HTTP request logs, in NSURLSession debug output, in Console.app on-device logs, and (worst-case) in proxy server logs if any TLS-terminating proxy is in the path. Even though the live build runs through the Supabase proxy where this is moot, the legacy fallback path is live code that ships in the binary.

**Fix:** during the §4.1.1 refactor, the gateway must use `Authorization: Bearer <token>` headers, never URL parameters. The Gemini direct-mode fallback (when proxy is off) is rare; it should be loud (DEBUG-only) and use the header.

#### 4.1.3 Subscription metadata in plaintext UserDefaults

[EntitlementStore.swift:36-78](AiQo/Core/Purchases/EntitlementStore.swift) writes `activeProductId`, `expiresAt`, and `currentTier` to `UserDefaults`. On a jailbroken device, an attacker can edit `expiresAt` to extend a trial indefinitely or flip `currentTier` to `.pro`. The signal is also *read* from UserDefaults at app launch before StoreKit reconciliation completes, so a tampered value is briefly authoritative.

**Fix:** migrate the three keys to `KeychainStore` (already exists at [Core/Keychain/KeychainStore.swift](AiQo/Core/Keychain/KeychainStore.swift)). Use a deterministic key like `aiqo.purchases.entitlement.v2`. Sign the JSON blob with HMAC keyed by an Info.plist constant for tamper detection — a mismatch should fall back to "free tier until StoreKit reconciles."

**Effort:** half a day. Touches one file plus the Keychain helper.

### 4.2 HIGH — fix in the next sprint

#### 4.2.1 Keychain failures swallowed silently

[KeychainStore.swift:26-29, 53-54](AiQo/Core/Keychain/KeychainStore.swift) discards `OSStatus` from `SecItemCopyMatching` and `SecItemAdd`. A real-world failure (permission denied after a device unlock loop, corrupted Keychain DB after a restore-from-backup) returns `nil` and the calling code thinks "no value stored." This silently degrades into "user is logged out."

**Fix:** log non-`errSecSuccess` / non-`errSecItemNotFound` statuses through `DiagnosticsLogger.diag` so we get telemetry on real failures. Three-line change.

#### 4.2.2 No certificate pinning on the cloud surface

The app talks to three sensitive endpoints — Supabase (`zidbsrepqpbucqzxnwgk.supabase.co`), Gemini (`generativelanguage.googleapis.com`), MiniMax (`api.minimax.io`). All rely on system-level TLS validation only.

**Fix:** add `URLSessionConfiguration` with pinned leaf certificates for all three. Bundle the public-key fingerprints in the IPA. Use `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)` to compare. Provide a `PINNING_DISABLED` Info.plist flag for dev/QA convenience that is hard-rejected in RELEASE.

**Effort:** half a day of plumbing + one rotation runbook in §7.3 below.

#### 4.2.3 `fatalError` on SwiftData container init

[AppDelegate.swift:18](AiQo/App/AppDelegate.swift) and [QuestSwiftDataStore.swift:29](AiQo/Features/Gym/Quests/Store/QuestSwiftDataStore.swift) both call `fatalError(...)` when the persistent container fails to spin up. In production this manifests as a bricked app with no recovery — the user can't even launch to a setting that would clear data.

**Fix:** fall back to an in-memory container with a banner that flags "memory persistence is unavailable." Schedule a retry on next foreground. Crash reports to Sentry-equivalent (already integrated in `Services/CrashReporting/`).

**Effort:** 2–3 hours per call site. Touches two files.

### 4.3 MEDIUM — fix opportunistically

#### 4.3.1 Force-unwrapped URL construction

8+ sites use `URL(string: "...")!`. Most are static literals (low risk) but a handful interpolate values. Examples:

- [SpotifyVibeManager+Auth.swift:29, 216, 268](AiQo/Core/SpotifyVibeManager+Auth.swift)
- [SmartFridgeCameraViewModel.swift:182](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift) — interpolates `apiKey`

**Fix:** replace all dynamic-URL force unwraps with `guard let url = URL(string: ...) else { throw URLError(.badURL) }`. Static literals are fine to leave (the app will fail to launch on a typo, which is loud and catchable).

#### 4.3.2 `try!` audit (38 occurrences)

Most are static `NSRegularExpression` patterns where the literal cannot be wrong. Worth one audit pass to confirm none has crept into a code path that takes user input.

**Fix:** grep + manual triage. Replace any dynamic `try!` with `do { … } catch { fallback }`.

#### 4.3.3 No certificate pinning verifier in CI

Even after §4.2.2 lands, there is no CI step that reads the IPA, extracts the embedded fingerprints, and verifies they match a tracked file in source control.

**Fix:** add a release-build step that asserts the bundled fingerprint matches `Configuration/CertPinning.json`.

### 4.4 LOW — quality / hygiene

#### 4.4.1 Tribe module duplication

There are two top-level Tribe surfaces:

- `AiQo/Features/Tribe/` — 3 files, **1,793 LOC** (TribeView, TribeExperienceFlow, TribeDesignSystem)
- `AiQo/Tribe/` — 13 root files + 6 subdirectories (Arena, Galaxy, Log, Models, Preview, Repositories, Stores, Views), **5,295 LOC across the top files alone**

Both are genuinely live: `Tribe/TribeScreen.swift` is a 17-line wrapper that instantiates `TribeView()` from `Features/Tribe/`. So the larger `Tribe/` directory is *not* dead code — it's a parallel-and-collaborating module. But the split is not principled (why does TribeView live in Features/ while TribeStore lives in /Tribe/?) and any new Tribe contributor will burn an hour orienting.

**Fix:** consolidate. Pick one canonical home (`AiQo/Features/Tribe/`) and migrate everything in `AiQo/Tribe/` into it. Estimated 1 day of move-and-adjust-imports work + smoke test of all Tribe surfaces (Arena, Galaxy, Pulse, Hub, Leaderboard).

**Note:** Tribe is currently feature-flagged off in production (per Blueprint 17 §2.2), so this consolidation can land without user-visible risk.

#### 4.4.2 `LegacyCalculationViewController` is misnamed

[AiQo/Features/First screen/LegacyCalculationViewController.swift](AiQo/Features/First screen/LegacyCalculationViewController.swift) is *not* legacy — it is the live first-launch screen, referenced from `SceneDelegate.swift` and `HistoricalHealthSyncEngine.swift`. The name is a footgun: anyone scanning the file tree for dead code would assume this is removable.

**Fix:** rename to `OnboardingEntryViewController.swift` (or `FirstLaunchViewController.swift`). Rename the parent directory from `First screen/` (which has a space and looks accidental) to `FirstLaunch/`. ~10 minutes work; touches the two callers.

#### 4.4.3 `AiQoCore/` is an empty placeholder

[AiQo/AiQoCore/](AiQo/AiQoCore/) contains only `AiQoCore.h` and a `.docc` folder — no Swift files. Either it was scaffolded for a future shared-framework extraction that never happened, or it's leftover from an Xcode template wizard.

**Fix:** decide. Two options:

1. **Use it.** Promote a small set of cross-target shared types (`AppGroupKeys`, `XPCalculator`, the Brain message types) into `AiQoCore` as a real Swift module that the iOS app, watch app, and both widgets can link. Pays off because the four targets currently duplicate or copy-paste these types.
2. **Delete it.** Remove the directory and the `.h` file. Saves nothing but removes confusion.

The first option is the right move for a global-quality app, but it's a 1–2 day project. The second option is 5 minutes. Either is fine; the placeholder is the worst of both.

#### 4.4.4 Brain stub backlog

Sixteen 7-line stub files exist across the Brain. Most are placeholders from the original 91-stub scaffold (P1.1 commit `874c683`). Listed in Blueprint 17 §16. The most-quoted are `RoutingPolicy`, `ResponseValidator`, `CulturalValidator`, `SignalBus`, `CircadianReasoner`, `ConsentGate`, `DataClassifier`, `DifferentialPrivacy`, `MoodModulator`, `VoiceProfile`, `DynamicPersonalizer`, `NotificationDelivery`, `IntentPlanner`, `FeedbackTracker`, `PriorityRanker`, `AchievementTrigger`, `CulturalContext`, `MemoryUsageTracker`, `PerformanceMetrics`, `BrainHealthMonitor`, `DecayEngine`, `NightlyConsolidation`, `PersonalizationEvolver`, `WeeklyConsolidation`.

**Fix:** triage in two passes. Pass 1: identify which stubs have real call sites (`grep` reveals stubs with zero callers can be deleted now). Pass 2: schedule the remaining ones for v1.1 implementation per Blueprint 17 §3.2.

**Effort:** 2 hours triage; per-stub implementation cost varies.

#### 4.4.5 Three `Info.plist` flags are unused or stale

- `BRAIN_DASHBOARD_ENABLED` (line 19, default `false`) — only used for the DEBUG-only inspector
- `CRISIS_DETECTOR_ENABLED` (line 51, default `true` in some builds) — `BrainOrchestrator.wellbeingDecision` runs *unconditionally*, ignoring this flag (Blueprint 17 §3.2.10 confirms)
- `PLANK_LADDER_CHALLENGE_ENABLED` (line 88, default `false`) — kept compilable for rollback; intentionally retained per CHANGELOG.md v1.0.2

**Fix:** delete `BRAIN_DASHBOARD_ENABLED` (DEBUG ifdef is sufficient) and `CRISIS_DETECTOR_ENABLED` (since the orchestrator ignores it). Document `PLANK_LADDER_CHALLENGE_ENABLED` as the intentional back-compat flag it is.

---

## 5. Architecture Debt

Items not security-graded but architecturally important for the "global / professional" goal the user asked for.

### 5.1 The "single door" pattern is incomplete for cloud calls

The `NotificationBrain` is the verified single door for notifications — Blueprint 17 §7.1 confirms zero direct `UNUserNotificationCenter.current().add(...)` calls outside the brain. But the *cloud-LLM* equivalent of NotificationBrain is missing. `HybridBrainService` is the single canonical caller for the chat path, but feature-level callers (§4.1.1) bypass it freely.

**Action:** §4.1.1's `CaptainCloudGateway` is the structural fix. After it lands, audit:

```bash
grep -R "URLSession" AiQo/ --include='*.swift' | grep -v 'CaptainCloudGateway\|MiniMaxTTSProvider\|Supabase\|Spotify\|ReceiptValidator'
```

The output should be empty. Anything that remains is a new hole.

### 5.2 `MEMORY_V4_ENABLED` is still false

Blueprint 17 §3.2.3 documents that Brain Memory V4 (the five-store SwiftData architecture) is fully written but gated behind an Info.plist flag that is `false` in this branch. The legacy V3 store ([MemoryStore.swift](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift), 1312 lines) is what actually runs in production. V4 has been ready since BATCH 2; the cutover is blocked on validation that the V3→V4 custom migration doesn't drop user memories.

**Action:** schedule a v1.1 cutover. Steps:

1. Build a side-by-side validator that runs both V3 reads and V4 reads on the same query and asserts equivalence.
2. Run the validator on a corpus of recorded test conversations.
3. Flip the flag in an internal TestFlight build.
4. Watch for memory-related crashes or "the Captain doesn't remember me anymore" feedback.
5. Promote to a public release.

### 5.3 No network-layer abstraction outside cloud LLM

There is no shared `Networking` / `APIClient` module. Every feature that needs a cloud call writes its own URL construction, JSONEncoder, retry logic, and error mapping. Examples: `SpotifyVibeManager`, `ReceiptValidator`, `SupabaseArenaService`, `MiniMaxTTSProvider`. Each is correct in isolation but together they mean any cross-cutting concern (timeouts, retries, observability, certificate pinning) requires 5+ separate touches.

**Action:** lower priority than §4.1.1 because the LLM gateway covers the highest-risk path. Schedule for v1.2: extract a `CloudNetwork` module under `AiQoCore` (see §4.4.3 option 1) that all four cloud-talking features use.

### 5.4 Test coverage is thin (~10%)

63 test files vs 590 source files = ~10% file-ratio. A few subsystems have strong coverage (the Brain's `Reasoning/` and `Wellbeing/` got dedicated test sweeps in BATCH 4 + 8). Most features have zero tests.

**Action:** not all 590 files need tests, but the cloud + privacy + entitlement boundary should be near-100% covered. Prioritize: (a) `PrivacySanitizer`, (b) `AuditLogger`, (c) `TierGate`, (d) `EntitlementStore`, (e) the new `CaptainCloudGateway` once it lands. Each has 1–2 days of test work.

### 5.5 Stub-file index needs maintenance

Blueprint 17 §16 names 16 specific stub files. Some have been implemented since (e.g., `EmotionalEngineAPI` was a stub, now is real). The list needs a refresh.

**Action:** part of §4.4.4 triage. Output: an updated AIQO_TECH_DEBT.md entry per still-stub file with a concrete implementation trigger.

---

## 6. Roadmap

Concrete, prioritized items. Each maps to a section in §4 / §5 above.

### P0 — ship-blockers for v1.0.2 / v1.1

Fix before the next App Store release:

| Item | Section | Effort | Owner trigger |
|---|---|---|---|
| `CaptainCloudGateway` extraction + 3-caller migration | §4.1.1 | 1–2 days | Before any new cloud-calling feature |
| API keys out of URL query strings | §4.1.2 | (folds into above) | Same |
| Subscription state to Keychain | §4.1.3 | 0.5 day | Before next paywall A/B |

### P1 — production hardening

Fix in the next sprint after P0 lands:

| Item | Section | Effort |
|---|---|---|
| Keychain error logging | §4.2.1 | 1 hour |
| Certificate pinning on cloud surface | §4.2.2 | 0.5 day |
| `fatalError` graceful-degrade | §4.2.3 | 0.5 day |
| Force-unwrap URL audit | §4.3.1 | 2 hours |

### P2 — architecture consolidation

Take in the v1.1 → v1.2 window:

| Item | Section | Effort |
|---|---|---|
| Tribe consolidation | §4.4.1 | 1 day |
| `LegacyCalculationViewController` rename | §4.4.2 | 30 min |
| `AiQoCore` decision (use vs delete) | §4.4.3 | 5 min decide; 1–2 days execute if "use" |
| Brain stub triage + delete dead stubs | §4.4.4 | 2 hours triage |
| `Info.plist` flag cleanup | §4.4.5 | 30 min |
| MEMORY_V4_ENABLED cutover | §5.2 | 1 week (validator + TestFlight + monitor) |

### P3 — quality

Ongoing:

| Item | Section |
|---|---|
| `try!` audit | §4.3.2 |
| CI cert-pinning verifier | §4.3.3 |
| Test-coverage push on the privacy + entitlement boundary | §5.4 |
| Network-layer abstraction (CloudNetwork module) | §5.3 |
| Living `AIQO_TECH_DEBT.md` updates | §5.5 |

### Beyond v1.1

Strategic items from Blueprint 17 §15 + §17 worth re-flagging:

- **Tribe re-enablement** with a redesigned social model (currently feature-flagged off).
- **Apple Intelligence on-device path** for the chat fallback (the §3.2.5 LocalBrain is in place but Foundation Models on iOS 26 isn't broadly tested yet).
- **Sleep architecture rollout** (Blueprint 17 §3.2.5 plus AIQO_TECH_DEBT entry on Foundation Models helper extraction).
- **Saudi + Iraq launch** — the wellbeing layer's region detection already supports these, but the App Store Connect catalog and pricing per market need a deliberate rollout.
- **Watch app feature parity** — currently mirrors a subset of the iPhone surface; the Tribe + Captain Memory + Notifications could all extend to the wrist.

---

## 7. Operational Notes

### 7.1 Where to find things

| What you want | Where to look |
|---|---|
| Master deep reference (history, full inventory) | [AiQo_Master_Blueprint_17.md](AiQo_Master_Blueprint_17.md) |
| Master forward guidance (this file) | [AiQo_Master_Blueprint_18.md](AiQo_Master_Blueprint_18.md) |
| Living tech-debt log | [AIQO_TECH_DEBT.md](AIQO_TECH_DEBT.md) |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |
| Build / dev setup | [Configuration/SETUP.md](Configuration/SETUP.md) |
| English product context (8-doc explainer) | [docs/explainers/en/](docs/explainers/en/) |
| Arabic product context (5-doc شرح شامل) | [docs/explainers/ar/](docs/explainers/ar/) |
| Historical batch logs from Brain refactor | [docs/archive/batch-results/](docs/archive/batch-results/) |
| App Store submission history | [docs/archive/app-store/](docs/archive/app-store/) |
| Captain refactor recon + diagnostic reports | [docs/archive/captain-brain/](docs/archive/captain-brain/) |
| P-fix phase logs (P0.1 → P_FIX_DEV_OVERRIDE) | [docs/archive/p-fix/](docs/archive/p-fix/) |
| Old MyVibe + pre-16 blueprints | [docs/archive/blueprints/](docs/archive/blueprints/) |

### 7.2 What NOT to do

- **Do not** add any new ad-hoc `URLSession` call to a feature module. All cloud LLM calls go through `04_Inference/Services/` (see §4.1.1).
- **Do not** write secrets, tokens, or subscription state to `UserDefaults`. Use `KeychainStore` (see §4.1.3).
- **Do not** disable `PrivacySanitizer` "for performance." It is the boundary — see Blueprint 17 §3.2.6.
- **Do not** modify files in `AiQo/Features/Gym/Club/Plan/` or `AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift` without reading the §32 / §36 timeline in Blueprint 17 — these have active in-flight work in the brain-refactor branch.
- **Do not** use `git add -A` or `git add .` from the root after this hygiene pass without reviewing the staged renames first — git will detect the docs/ moves as renames but you should verify before committing.
- **Do not** commit `Configuration/Secrets.xcconfig`. It is gitignored. If you ever accidentally stage it, treat it as a key-rotation event.

### 7.3 Runbooks

#### Clean rebuild from scratch

```bash
rm -rf build/
xcodebuild clean -project AiQo.xcodeproj -scheme AiQo
```

The `build/` directory is gitignored and regenerable. The hygiene pass deleted it; Xcode will recreate it on the next build.

#### Add a new permission string

Edit four places, all in lockstep:

1. `AiQo/Info.plist` — the technical permission key (e.g. `NSCameraUsageDescription`)
2. `AiQo/Resources/en.lproj/InfoPlist.strings` — English copy
3. `AiQo/Resources/ar.lproj/InfoPlist.strings` — Arabic copy
4. The pbxproj if a new framework is needed

Verify with: `grep -R "NSCameraUsageDescription" AiQo/` — must show all three locales + Info.plist.

#### Rotate an API key

Updates in two places:

1. `Configuration/Secrets.xcconfig` — local
2. The corresponding Supabase Edge Function env var (`captain-chat`, `captain-voice`)

Re-deploy the Edge Function. Revoke the old key from the provider console (Google AI Studio / MiniMax dashboard).

History reference: 7524f88 (`fix(security): restore xcconfig placeholder pattern, rotate MiniMax + Gemini keys`).

#### Toggle Brain V4

When ready (see §5.2):

1. Edit `AiQo/Info.plist`: `MEMORY_V4_ENABLED` from `false` to `true`.
2. Internal TestFlight build first.
3. Watch crash reports for SwiftData migration failures.
4. Promote to production once the validator (built per §5.2 step 1) reports zero divergence.

#### Ship a hotfix

Follow Blueprint 17 §28 / §31 patterns: small focused branch, tightly-scoped commit, App Store Connect resubmit. v1.0.1 → v1.0.2 happened via PR #6.

### 7.4 Onboarding a new contributor

If someone joins the project, point them at this document in this order:

1. Read this file (Blueprint 18) end-to-end.
2. Skim Blueprint 17 §1–§3 for the architecture.
3. Read `docs/explainers/en/AiQo_AIContext_00_README.md` for product context.
4. Run `Configuration/SETUP.md` to get a build going.
5. Check the AIQO_TECH_DEBT.md for "trigger to revisit" items that match what they want to work on.

For Arabic-fluent contributors, swap step 3 for `docs/explainers/ar/`.

### 7.5 The "global / professional" bar

The user's brief was "اجعل تطبيق عالمي و ممتاز جداً" — make it a global, excellent app. The hygiene pass landed the *organizational* half of that bar:

- ✅ Clean root with everything where you'd expect it
- ✅ Documentation discoverable by purpose, not by accident of filing
- ✅ A clear separation between the in-flight brain-refactor work and the surrounding stable surface
- ✅ A living blueprint that supersedes 17 and points forward
- ✅ A concrete, prioritized security + architecture roadmap

The *engineering* half of that bar is the §6 P0 items. Until §4.1.1 lands, the audit-log claim is incomplete — and that's the table-stakes promise of an Arabic-first app whose differentiator is privacy-respecting AI.

---

## 8. Footer

**Author:** Mohammed Raad (mraad500), with the 2026-05-10 hygiene pass.
**Generated:** 2026-05-10.
**Repo HEAD at generation:** `39ca529` (`fix(captain-brain): mark HRMoodReading.unknown nonisolated`).
**Active branch:** `brain-refactor/p-fix-dev-override`.
**Supersedes:** Blueprint 17 for forward guidance only. Blueprint 17 remains the canonical historical reference.
**Status:** ready to read; ready to drive the v1.0.2 → v1.1 work.

— *الكابتن حمّودي بانتظار الترقية القادمة.*
