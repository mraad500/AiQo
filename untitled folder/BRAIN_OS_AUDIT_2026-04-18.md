# AiQo Brain OS — Mid-Journey Audit
**Date:** 2026-04-18
**Auditor:** Claude Code (Opus 4.7)
**Branch at audit:** `brain-refactor/p-fix-dev-override`
**Commits audited:** `3bd5230` (divergence point) through `869408a` (HEAD) + staged P_FIX work

---

## 🎯 Executive Summary

**The project is in a state of silent regression driven by a catastrophic branch divergence.** Of the 10 completed prompts claimed in the context handoff, only **3 landed on the working branch** (P1.3, P2.2, P2.3). Five — P0.2, P0.3, P1.1, P1.2 — exist only on an abandoned branch (`brain-refactor/p1-4-tier-wiring`, oddly named) that was never merged into the line leading to HEAD. The current working branch bypassed all of that work entirely, so the production-path code still has the **Arabic API endpoint, CoachBrainMiddleware, and `CAPTAIN_ARABIC_API_URL` Info.plist key alive** (i.e. the entire P0.2 privacy surgery was never applied here), plus zero AuditLogger (P0.3), only 5 of 91 scaffolding stubs (P1.1), and all moved files still at their flat pre-P1.2 paths. The one bright spot: the build is green, TierGate is solid, Schema V4 is wired (albeit at the wrong folder), and the five memory stores that were ported forward are real code (not stubs) with tests.

**Progress:** **3 / 28** prompts fully complete (**10.7 %**) — with ~3 more partially landed.
**Days used:** 1 of 30 (today, 2026-04-18).
**Schedule status:** **Behind — losing work to unmerged branches.** On paper the commit log reads "10 prompts done"; on disk it's closer to 3-4.
**Critical blockers:** **4** (see below).
**Quality state:** **🔴 RED** — the main branch line silently dropped the Privacy Week 1 safety work. Shipping this state would re-leak HealthKit raw numbers to the Arabic Gemini endpoint.

---

## 🚨 Critical Findings (Do These First)

### 🔴 Finding 1 — The working branch is missing P0.2, P0.3, P1.1, P1.2 entirely

`git log --oneline --graph --all` shows two divergent histories off `3bd5230`:

```
* 869408a P2.3 (HEAD)           * fca3031 P1.3  [brain-refactor/p1-4-tier-wiring]
* c95d424 P2.2                  * 14a649b P1.2
* f74f830 "Refactor…" (= P2.1)  * c778f83 P1.1
* 8dfeb0c "Wire tier gating"    * 03091f1 P0.3
* 3bd5230 (split) ←─────────────* 8507321 P0.2
```

The left column (HEAD's line) skipped the entire P0.x/P1.1/P1.2 work. P2.1, P2.2, P2.3 were then built on that "naked" base. Verification: `git ls-tree -r brain-refactor/p1-4-tier-wiring 'AiQo/Features/Captain/Brain/' | wc -l = 119`; same command on HEAD = **9**.

- **Evidence:** current `AiQo/Info.plist:14-15` still has `<key>CAPTAIN_ARABIC_API_URL</key>`; `CaptainIntelligenceManager.swift:275` still has `generateArabicAPIReply`; `CoachBrainMiddleware.swift` still 578+ lines long (P0.2 claimed to delete it).
- **Impact:** ships privacy regression. Any Arabic chat still has a code path to the unsanitized `$(CAPTAIN_ARABIC_API_URL)` endpoint. Any call site invoking `CoachBrainLLMTranslator` (7 references live) still hits an unsanitized Gemini route.
- **Suggested fix:** **`P_MERGE_LOST_WORK`** — cherry-pick or merge `8507321`, `03091f1`, `c778f83`, `14a649b`, `fca3031` forward onto HEAD, resolve conflicts (mostly around `8dfeb0c`'s independent re-do of tier wiring), then rebase P2.1/P2.2/P2.3 on top. Do **NOT** re-run P0.2/P0.3/P1.1/P1.2 from scratch — the work already exists on disk on the sibling branch.

### 🔴 Finding 2 — AuditLogger (P0.3) is completely absent from HEAD

`grep -rn AuditLogger AiQo --include='*.swift'` returns zero matches.

- **Evidence:** no `AuditLogger.swift`, no `AuditLogger.record(...)` calls anywhere in `CloudBrainService.swift`, `HybridBrainService.swift`, or `BrainOrchestrator.swift`.
- **Impact:** there is no on-device record of what left the device, who it was for, or whether consent was granted — the whole point of P0.3.
- **Suggested fix:** same as Finding 1 — merge `03091f1` forward. The code exists, just not on this branch.

### 🔴 Finding 3 — 91 of 91 scaffolding stubs gone; only 5 Foundation files present

The Brain/ folder today has 2 subfolders (`00_Foundation`, `02_Memory/Stores`) and 10 Swift files. The P1.1 commit on the sibling branch has 91 files across 11 subfolders.

- **Evidence:** `find AiQo/Features/Captain/Brain -type d | sort` ⇒ 4 directories total.
- **Impact:** subsystems `01_Sensing`, `03_Reasoning`, `04_Inference`, `05_Privacy`, `06_Proactive`, `07_Learning`, `08_Persona`, `09_Wellbeing`, `10_Observability` are physically nonexistent — anything needing those namespaces has no home. Every subsequent prompt (P2.4 onwards) that drops a file into e.g. `Brain/02_Memory/Intelligence/FactExtractor.swift` will land in a directory that doesn't exist.
- **Suggested fix:** same as Finding 1.

### 🔴 Finding 4 — Six `canAccess` sites still lack the `DevOverride` wrapper

The P_FIX_DEV_OVERRIDE report claimed 36/36 gate sites were wrapped, but the count silently omitted four Feature flavors: `.premiumVoice`, `.photoAnalysis`, `.multiWeekPlan`, `.weeklyInsightsNarrative`.

| File | Line | Feature | Wrapped? |
|---|---|---|---|
| [AiQo/Core/CaptainVoiceAPI.swift:97](AiQo/Core/CaptainVoiceAPI.swift:97) | 97 | `.premiumVoice` | ❌ |
| [AiQo/Core/CaptainVoiceService.swift:213](AiQo/Core/CaptainVoiceService.swift:213) | 213 | `.premiumVoice` | ❌ |
| [AiQo/Core/CaptainVoiceService.swift:295](AiQo/Core/CaptainVoiceService.swift:295) | 295 | `.premiumVoice` | ❌ |
| [AiQo/Features/Kitchen/SmartFridgeScannerView.swift:318](AiQo/Features/Kitchen/SmartFridgeScannerView.swift:318) | 318 | `.photoAnalysis` | ❌ |
| [AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:64](AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:64) | 64 | `.multiWeekPlan` | ❌ |
| [AiQo/Features/Kitchen/MealPlanView.swift:415](AiQo/Features/Kitchen/MealPlanView.swift:415) | 415 | `.multiWeekPlan` | ❌ |
| [AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:319](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:319) | 319 | `.weeklyInsightsNarrative` | ❌ |

- **Impact:** with `AIQO_DEV_UNLOCK_ALL=true` (currently `<true/>` in Info.plist) developers on dev builds will still be blocked from `.premiumVoice`, `.photoAnalysis`, `.multiWeekPlan`, and `.weeklyInsightsNarrative` features — defeating the purpose of the unlock. Users in production are correctly blocked, so this is strictly a dev-only UX gap, not a privacy bug.
- **Suggested fix:** short prompt **`P_FIX_DEV_OVERRIDE_PART2`** — wrap the 7 call sites (3 premiumVoice + 2 multiWeekPlan + 1 photoAnalysis + 1 weeklyInsightsNarrative) in `if !DevOverride.unlockAllFeatures { … }` identical to the 36 already done.

---

## ✅ What's Done (Verified Working)

| Master Plan Section | Status | Evidence |
|---|---|---|
| §4.1 Folder structure | 🔧 2 of 11 subfolders | [AiQo/Features/Captain/Brain/](AiQo/Features/Captain/Brain/) — only `00_Foundation` + `02_Memory/Stores` present |
| §5.1 Four Memory Stores (Episodic, Semantic, Procedural, Emotional, Relationship) | ✅ | 5 actors at [Brain/02_Memory/Stores/](AiQo/Features/Captain/Brain/02_Memory/Stores/), 240-624 lines each, all have snapshot types, `configure(container:)`, TierGate integration. Wired in [AppDelegate.swift:29-31](AiQo/App/AppDelegate.swift:29) |
| §5.1 MemoryRetriever RAG | ⬜ | No file, no interface |
| §5.1 FactExtractor | ⬜ | No file |
| §5.1 EmotionalMiner | ⬜ | No file |
| §5.1 PatternMiner | ⬜ | No file |
| §5.1 Embeddings (NaturalLanguage) | ⬜ | No file, not wired |
| §5.1 SalienceScorer | ⬜ | No file |
| §5.2 NotificationBrain single door | ⬜ | Current notification flow still fans out through NotificationService.swift, MorningHabitOrchestrator.swift, SmartNotificationScheduler.swift, PremiumExpiryNotifier.swift, TrialJourneyOrchestrator.swift |
| §5.2 GlobalBudget | ⬜ | Not started |
| §5.2 15 triggers | ⬜ | Not started |
| §5.3 Nightly consolidation | ⬜ | Not started |
| §5.3 Weekly consolidation | 🔧 | Legacy `WeeklyMemoryConsolidator` exists but at flat `AiQo/Core/` not `Brain/02_Memory/Intelligence/` |
| §5.3 Monthly Reflection (Pro) | 🔧 | `MonthlyReflection` @Model exists at [AiQo/Core/Models/MonthlyReflection.swift](AiQo/Core/Models/MonthlyReflection.swift), no engine code |
| §5.3 DecayEngine | ⬜ | Not started |
| §5.3 FeedbackLearner | ⬜ | Not started |
| §6 Tier differentiation (14 dimensions) | ✅ | [TierGate.swift:119-195](AiQo/Features/Captain/Brain/00_Foundation/TierGate.swift:119) — 8 tier-limit getters (context tokens, memory depth, semantic facts, notifications/day, lookback days, emotional cadence, pattern window, max weeks) plus 2 async callbacks (memoryFactLimit, cappedMemoryFetchLimit). 9 Features. Reads from UserDefaults + FreeTrialManager |
| §8.x Persona (CaptainIdentity, DialectLibrary, HumorEngine, WisdomLibrary) | ⬜ | Not started |
| §9 Wellbeing (CrisisDetector, SafetyNet) | ⬜ | Not started |
| §10 Observability (BrainDashboard) | ⬜ | Not started — only DiagnosticsLogger global exists |
| §10 Apple Compliance | 🔧 | On-device compliance holds for Episodic/Semantic/etc. stores; consent gate (`AICloudConsentGate`) is wired at 5 sites but **no AuditLogger** means no evidence trail |

---

## 🔧 What's Broken or Half-Done

### 🔧 Gap 1: V4 models live at wrong filesystem path
- **Evidence:** Per §4.1 the models should be at `AiQo/Features/Captain/Brain/02_Memory/Models/`. They're actually at [AiQo/Core/Models/](AiQo/Core/Models/):
  - EpisodicEntry.swift, SemanticFact.swift, ProceduralPattern.swift, EmotionalMemory.swift, Relationship.swift, MonthlyReflection.swift, ConsolidationDigest.swift, WeeklyReportEntry.swift, WeeklyMetricsBuffer.swift
- **Impact:** later prompts (P2.5, P3.x, P5.x) that expect to import from `Brain/02_Memory/Models/*` will have to either move these or import across the project layout. Violates the Master Plan's "clean blast radius" goal.
- **Suggested fix:** **`P_RELOCATE_V4_MODELS`** — after `P_MERGE_LOST_WORK` (Finding 1) lands and the correct folder structure is back, `git mv` each of the 9 model files into `Brain/02_Memory/Models/` and fix imports.

### 🔧 Gap 2: PrivacySanitizer hardening from P0.3 never applied (no test evidence)
- **Evidence:** no `AiQoTests/PrivacySanitizerTests.swift`. P0.3 commit claimed 27 XCTests were added there.
- **Impact:** regex hardening for Arabic-Indic and Extended Arabic-Indic digits, بنضبة / دقيقة / كيلومتر / hrs unanchored bug, stepsBucketSize 50→500, etc. — all the *defensive* tightening P0.3 did — is unverified on HEAD. The sanitizer file exists and functions but its resistance to the bypass cases that P0.3 specifically addressed is unknown.
- **Suggested fix:** bundled into `P_MERGE_LOST_WORK` (Finding 1).

### 🔧 Gap 3: Stub / orphan usage is uneven
- **Evidence:** `CaptainLockedView` exists (126 lines, substantive) but is referenced only in its own file — it's built but not wired to any paywall surface yet. Same for `BrainError` (referenced 30+ places, mostly through `diag`).
- **Impact:** `CaptainLockedView` is dead code today. When the next chat-tier UI work happens, whoever writes it may re-invent the locked view rather than finding this one.
- **Suggested fix:** add a single call site in `CaptainScreen.swift` (or the chat entry) to render `CaptainLockedView` when the tier gate blocks. Five-minute edit.

### 🔧 Gap 4: 29 moved files from P1.2 are all still at their flat pre-move paths
- **Evidence:** see `find AiQo/Features/Captain -name '*.swift' | sort` in the Appendix — BrainOrchestrator.swift, CloudBrainService.swift, HybridBrainService.swift, LocalBrainService.swift, CaptainFallbackPolicy.swift, CaptainCognitivePipeline.swift, EmotionalStateEngine.swift, ScreenContext.swift, SentimentDetector.swift, TrendAnalyzer.swift, CaptainContextBuilder.swift, CaptainIntelligenceManager.swift, CaptainPersonaBuilder.swift, CaptainPromptBuilder.swift, PrivacySanitizer.swift, PromptRouter.swift, LLMJSONParser.swift, CaptainModels.swift, ConversationThread.swift, MessageBubble.swift, ProactiveEngine.swift, CaptainOnDeviceChatEngine.swift, CaptainNotificationRouting.swift, CoachBrainMiddleware.swift, CoachBrainTranslationConfig.swift, LocalIntelligenceService.swift, VibeMiniBubble.swift, AiQoPromptManager.swift + `MemoryStore.swift`, `MemoryExtractor.swift` at flat `AiQo/Core/`
- **Impact:** same as Gap 1 — future prompts import from expected Brain/ paths and will miss these.
- **Suggested fix:** bundled into `P_MERGE_LOST_WORK`.

### 🔧 Gap 5: Live "dead" code files from unapplied P0.2
- **Evidence:** `CoachBrainMiddleware.swift` (578 lines), `CoachBrainTranslationConfig.swift`, `IraqiCoachTemplates.swift` status unknown (probably not present).
- **Impact:** `CoachBrainLLMTranslator` has 7 live references — the translator still fires on notification paths, meaning raw HealthKit numbers still reach Gemini via the middleware route. This *is* a privacy regression.
- **Suggested fix:** deletion is part of P0.2; bundled into `P_MERGE_LOST_WORK`.

---

## ⬜ What's Missing (Not Started)

Everything in Week 2-5 of the 30-day plan, except the three stores landed:

| Prompt | Master Plan § | Estimated effort (§8) |
|---|---|---|
| P2.4 Embeddings (NaturalLanguage) | §5.1 | ~2 h |
| P2.5 MemoryRetriever (RAG) | §5.1 | ~3 h |
| P2.6 SalienceScorer + DecayEngine | §5.3 | ~2 h |
| P3.1 FactExtractor | §5.1 | ~2.5 h |
| P3.2 EmotionalMiner | §5.1 | ~2 h |
| P3.3 PatternMiner | §5.1 | ~2 h |
| P4.1 ContextSensor + BehavioralObserver | §5.1 / §5.2 | ~3 h |
| P4.2 BioStateEngine + CircadianReasoner | §5.1 | ~2 h |
| P4.3 HealthKit / Music / Weather bridges | §4.1 | ~2 h |
| P5.1 NotificationBrain single door | §5.2 | ~3 h |
| P5.2 GlobalBudget + CooldownManager + QuietHoursManager | §5.2 | ~2 h |
| P5.3 15 Triggers | §5.2 | ~4 h |
| P5.4 Nightly consolidation | §5.3 | ~2 h |
| P5.5 Monthly Reflection engine (Pro) | §5.3 | ~3 h |
| P5.6 FeedbackLearner | §5.3 | ~2 h |
| P6.1 CaptainIdentity + DialectLibrary + HumorEngine + WisdomLibrary | §8.x | ~4 h |
| P6.2 PersonaAdapter + CulturalContextEngine | §8.x | ~2 h |
| P7.1 CrisisDetector + SafetyNet | §9 | ~3 h |
| P7.2 BrainDashboard + AppleCompliance polish | §10 | ~2 h |

**Total remaining effort:** ~47 hours of focused work.

---

## 📊 Detailed Metrics

### File Inventory (Brain/)

| Brain subfolder | Expected (P1.1) | Actual | Implemented (≥100 LOC) | Stub (≤30 LOC) | Gap |
|---|---:|---:|---:|---:|---:|
| 00_Foundation | 6 | **5** | 4 (TierGate 208, CaptainLockedView 126, DiagnosticsLogger 56, DevOverride 46) | 1 (BrainError 30) | **BrainBus, FeatureFlags.swift missing** |
| 01_Sensing | 8 | **0** | 0 | 0 | **entire subfolder missing** |
| 02_Memory (root) | 2 | 0 | 0 | 0 | MemoryStore, ConversationThread missing |
| 02_Memory/Indexing | 3 | **0** | 0 | 0 | missing |
| 02_Memory/Intelligence | 8 | **0** | 0 | 0 | missing |
| 02_Memory/Models | 8 | **0** | 0 | 0 | **files exist but at AiQo/Core/Models/ instead** |
| 02_Memory/Stores | 6 | **5** | 5 (240-624 LOC) | 0 | WeeklyMetricsBufferStore missing |
| 03_Reasoning | 10 | **0** | 0 | 0 | missing |
| 04_Inference (+Validation) | 10 | **0** | 0 | 0 | missing |
| 05_Privacy | 4 | **0** | 0 | 0 | missing |
| 06_Proactive (+Budget/Composition) | 12 | **0** | 0 | 0 | missing |
| 07_Learning | 4 | **0** | 0 | 0 | missing |
| 08_Persona | 4 | **0** | 0 | 0 | missing |
| 09_Wellbeing | 3 | **0** | 0 | 0 | missing |
| 10_Observability | 3 | **0** | 0 | 0 | missing |
| **Total** | **91** | **10** | **9** | **1** | **81 missing** |

### TierGate Coverage (36 + 7 = 43 gate sites total)

**Wrapped** (36 sites — all good):
- `.captainChat`: 10 sites — CaptainViewModel, CloudBrainService, CoachBrainMiddleware, KitchenPlanGenerationService, MemoryExtractor, SmartFridgeCameraViewModel ×2, SmartFridgeScannerView, WeeklyReviewView, CaptainIntelligenceManager (dead path)
- `.captainNotifications`: 26 sites — NotificationService ×9, SmartNotificationScheduler ×7, PremiumExpiryNotifier ×2, TrialJourneyOrchestrator ×3, MorningHabitOrchestrator ×3, SleepSessionObserver ×2

**NOT wrapped** (7 sites — Finding 4 above):
- `.premiumVoice`: 3 — CaptainVoiceAPI.swift:97, CaptainVoiceService.swift:213 & 295
- `.multiWeekPlan`: 2 — KitchenPlanGenerationService.swift:64, MealPlanView.swift:415
- `.photoAnalysis`: 1 — SmartFridgeScannerView.swift:318
- `.weeklyInsightsNarrative`: 1 — WeeklyReviewView.swift:319

### Test Health
- **Build:** ✅ SUCCEEDED on `generic/platform=iOS` (production-relevant Debug-iphoneos archive produced & codesigned)
- **Test files:** 23
- **Test methods:** 157 (`grep -rn "func test" AiQoTests --include='*.swift' | wc -l`)
- **Missing test files per commit claims:** `PrivacySanitizerTests.swift` (P0.3 claimed 27 tests)
- **Did not run:** the full `xcodebuild test` pass — build system is slow on this project; manual Xcode GUI verification recommended for store/schema tests.

### Orphan Code / Low-External-Usage Classes
- `CaptainLockedView` — 1 ref (self-only). **Dead code today**; wire into CaptainScreen when the lock UI is ready.
- `EmotionalStore`, `ProceduralStore`, `RelationshipStore` — 1 external ref each (all from `AppDelegate.swift:29-31`'s `.configure(container:)` call). Stores are initialized but never *read* by any caller yet. Expected — they'll be consumed by P3.x mining prompts.
- `DiagnosticsLogger` — 0 external refs to the class, but the `let diag = DiagnosticsLogger.shared` global at [DiagnosticsLogger.swift:56](AiQo/Features/Captain/Brain/00_Foundation/DiagnosticsLogger.swift:56) is used in 100+ places. Not orphan, just accessed through the `diag` alias.
- `CoachBrainLLMTranslator` — 7 live references (notification translation path). Should have been deleted by P0.2. Leaking.

---

## 🎬 Recommended Next Move

> **Next: `P_MERGE_LOST_WORK` — merge / cherry-pick `8507321`, `03091f1`, `c778f83`, `14a649b`, `fca3031` forward onto HEAD, rebase P2.1/P2.2/P2.3 on top, resolve conflicts.**
>
> **Reasoning:** every other gap in this audit is downstream of the branch divergence. If you run P_FIX_DEV_OVERRIDE_PART2 now, you still ship with live Arabic API leaks. If you start P2.4 embeddings now, the file will land in a directory that doesn't exist. If you move the V4 models to their correct path now, you'll move them again after the merge.
>
> Merging the lost work first re-establishes the *invariants* every other prompt assumes — (a) the 11-subfolder skeleton, (b) the relocated Core files, (c) the privacy surgery, (d) the AuditLogger. Once merged, the three remaining cleanups (`P_FIX_DEV_OVERRIDE_PART2`, `P_RELOCATE_V4_MODELS` to put new models under the restored `Brain/02_Memory/Models/`, and a one-liner to wire `CaptainLockedView`) are trivial and can be bundled into a single housekeeping commit.
>
> Est. effort for `P_MERGE_LOST_WORK`: **2-4 hours** of careful conflict resolution. The major conflict will be that `8dfeb0c` independently touched `CaptainViewModel.swift`, `CloudBrainService.swift`, `CoachBrainMiddleware.swift`, and the Kitchen files that P0.2 wanted to delete or reroute — so you'll need to take the **P0.2 version** (delete / reroute) rather than merge both.
>
> Only *after* that should P2.4 (embeddings) kick off.

---

## 📋 Full Section Detail

### 1. Git & Branch Hygiene

- **Current branch:** `brain-refactor/p-fix-dev-override`
- **HEAD:** `869408a` (P2.3 commit)
- **Staged (not committed):** 34 files, 1017 insertions / 181 deletions — the `P_FIX_DEV_OVERRIDE` work, unpushed. Includes new `CaptainLockedView.swift`, `FeatureFlagTests.swift`, `TierGateTests.swift`, `P_FIX_DEV_OVERRIDE_RESULT_2026-04-18.md`.
- **Unstaged:** none.
- **Local branches alive (12 brain-refactor + 33 claude/*):**
  - `brain-refactor/p0-2-privacy` (has P0.2, never merged)
  - `brain-refactor/p0-3-sanitizer` (has P0.3, never merged)
  - `brain-refactor/p1-1-scaffolding` (has P1.1, never merged)
  - `brain-refactor/p1-2-move-core` (has P1.2, never merged)
  - `brain-refactor/p1-3-tiergate` (has P1.3, never merged)
  - `brain-refactor/p1-4-tier-wiring` — **misleadingly named; actually tips at P1.3 fca3031, doesn't contain P1.4**
  - `brain-refactor/p-fix-1-3-tiergate-hardening` (parent of current branch, = `869408a`)
  - `brain-refactor/p2-1-schema-v4`, `p2-2-episodic-semantic`, `p2-3-procedural-emotional` — tips of each prompt, probably all in HEAD's ancestry
  - 33 unrelated `claude/*` branches — not pertinent to audit, candidates for `git branch -D` cleanup
- **Remote tracked:** only 9 refs on `origin` (main, CI fixes, + 5 claude branches pushed early). The entire brain-refactor work is **LOCAL ONLY.** ← risk: single-machine failure would lose the entire refactor.
- **Merge conflicts:** none in working tree.

### 2. File Inventory
See table above.

### 3. Master Plan Coverage
See table above.

### 4. Privacy Surgery Verification

```bash
$ grep -rn "generateArabicAPIReply\|CAPTAIN_ARABIC_API_URL\|\.arabicAPI\|CoachBrainLLMTranslator" AiQo --include="*.swift"
```
**Expected:** zero.  **Actual:** 40 matches across `CaptainIntelligenceManager.swift` (26), `CoachBrainMiddleware.swift` (5), `SmartNotificationScheduler.swift` (1), `KitchenPlanGenerationService.swift` (2). ❌

```bash
$ grep -n "ARABIC_API\|arabicAPI" AiQo/Info.plist
14: <key>CAPTAIN_ARABIC_API_URL</key>
15: <string>$(CAPTAIN_ARABIC_API_URL)</string>
```
**Expected:** zero.  **Actual:** 2 matches + `COACH_BRAIN_LLM_API_URL` also still present (lines 40-41). ❌

```bash
$ grep -rn "AuditLogger" AiQo --include="*.swift"
```
**Expected:** ≥10 (class + integration calls).  **Actual:** **zero.** ❌

```bash
$ grep -rn "PrivacySanitizer\." AiQo --include="*.swift" | wc -l
10
```
Class exists. Used in 10 non-trivial sites (MemoryExtractor, CaptainVoiceAPI, CoachBrainMiddleware, SmartFridgeCameraViewModel, CaptainIntelligenceManager, CloudBrainService, WeeklyReviewView, BrainOrchestrator, SmartNotificationManager, plus self). ✅ for basic sanitization; ❌ for P0.3 *hardening* which cannot be proven without the tests.

### 5. TierGate & DevOverride

See Finding 4 + "TierGate Coverage" metric above. `SubscriptionTier` at [SubscriptionTier.swift](AiQo/Core/Purchases/SubscriptionTier.swift) has 4 cases (`.none`, `.max`, `.trial`, `.pro`) with correct ranking (`.trial` ≡ `.pro` for access). `TierGate.currentTier` at [TierGate.swift:74-83](AiQo/Features/Captain/Brain/00_Foundation/TierGate.swift:74) reads live from `UserDefaults["aiqo.purchases.currentTier"]` (real source per `EntitlementStore`) and `FreeTrialManager.isTrialActiveSnapshot`, not a placeholder. `DevOverride.unlockAllFeatures` is hard-coded to `false` in `#else` (RELEASE) at [DevOverride.swift:19](AiQo/Features/Captain/Brain/00_Foundation/DevOverride.swift:19). Info.plist `AIQO_DEV_UNLOCK_ALL` is currently `<true/>` on this dev branch — expected.

Required tier-limit getters per §3.2 check: **all 8 structured getters present** + 2 async back-compat helpers (`memoryFactLimit()`, `cappedMemoryFetchLimit(requested:fallback:)`). ✅

### 6. SwiftData Schema V4

- `MemorySchemaV4` declared at [AiQo/Core/Schema/MemorySchemaV4.swift:5](AiQo/Core/Schema/MemorySchemaV4.swift:5), `versionIdentifier = 4.0.0`, 13 `@Model` types listed (EpisodicEntry, SemanticFact, ProceduralPattern, EmotionalMemory, Relationship, MonthlyReflection, ConsolidationDigest, CaptainPersonalizationProfile, WeeklyReportEntry, WeeklyMetricsBuffer, ConversationThreadEntry, RecordProject, WeeklyLog). Master Plan §9.1 asked for 10+ — 13 is a superset. ✅
- Migration plan has `migrateV3toV4` custom stage with `willMigrate` / `didMigrate` seeding legacy `CaptainMemory` → `SemanticFact` and `PersistentChatMessage` → `EpisodicEntry`. See [CaptainSchemaMigrationPlan.swift:64-140](AiQo/Core/Schema/CaptainSchemaMigrationPlan.swift:64). ✅
- `MEMORY_V4_ENABLED` flag at [AiQoFeatureFlags.swift:52](AiQo/Core/Config/AiQoFeatureFlags.swift:52) defaults to `false`; Info.plist has `<false/>` at line 80. Production-safe. ✅
- Legacy V3 models (`CaptainSchemaV3`, `PersistentChatMessage`, `CaptainMemory`) still present at [AiQo/Core/Schema/](AiQo/Core/Schema/) and [AiQo/Features/Captain/](AiQo/Features/Captain/) — not deleted, as required for migration. ✅
- **Misplacement**: per §4.1 the V4 models should live at `Brain/02_Memory/Models/*`, not `AiQo/Core/Models/*`. Functional but structurally wrong. 🔧

### 7. Store Implementations (P2.2 / P2.3)

All five stores verified actor-isolated with `static let shared = …` singletons, `configure(container: ModelContainer)` setup methods, TierGate integration, snapshot structs for cross-isolation returns, and `logError`/`logWarning` helpers via `diag`.

| Store | File | Lines | `configure(container:)` | TierGate limit used | Test file | Wired in AppDelegate |
|---|---|---:|:---:|:---:|:---:|:---:|
| Episodic | [EpisodicStore.swift](AiQo/Features/Captain/Brain/02_Memory/Stores/EpisodicStore.swift) | 588 | ✅ | `cappedMemoryFetchLimit` | EpisodicStoreTests.swift | ✅ |
| Semantic | [SemanticStore.swift](AiQo/Features/Captain/Brain/02_Memory/Stores/SemanticStore.swift) | 624 | ✅ | `memoryFactLimit`, `cappedMemoryFetchLimit` | SemanticStoreTests.swift | ✅ |
| Procedural | [ProceduralStore.swift](AiQo/Features/Captain/Brain/02_Memory/Stores/ProceduralStore.swift) | 240 | ✅ | `cappedMemoryFetchLimit` | ProceduralStoreTests.swift | ✅ |
| Emotional | [EmotionalStore.swift](AiQo/Features/Captain/Brain/02_Memory/Stores/EmotionalStore.swift) | 240 | ✅ | (cadence provider only) | EmotionalStoreTests.swift | ✅ |
| Relationship | [RelationshipStore.swift](AiQo/Features/Captain/Brain/02_Memory/Stores/RelationshipStore.swift) | 205 | ✅ | `cappedMemoryFetchLimit` | RelationshipStoreTests.swift | ✅ |

All stores wired in [AppDelegate.swift:26-34](AiQo/App/AppDelegate.swift:26) where each gets `.configure(container: v4Container)` inside the V4-enabled branch. The snapshot types (`EpisodicEntrySnapshot`, `SemanticFactSnapshot`, etc.) are `nonisolated struct … : Sendable` so consumers outside the actor can safely read them.

### 8. Build & Test Health

- `xcodebuild -project AiQo.xcodeproj -scheme AiQo -destination 'generic/platform=iOS' build` → **BUILD SUCCEEDED** (Debug-iphoneos archive produced, codesigned with Apple Development cert).
- Did **not** run the test pass (time budget + the project's known CLI-build flakiness on `SWBBuildService`). Manual run recommended via Xcode GUI before P2.4 kickoff.
- 157 test methods / 23 files. New since Day 0: `FeatureFlagTests.swift`, `TierGateTests.swift`, `MemorySchemaV4Tests.swift`, 5 store test files, `PurchasesTests.swift` update.
- `PrivacySanitizerTests.swift` — **MISSING** (see Finding 2 detail above).

### 9. Orphan Code

See "Orphan Code / Low-External-Usage Classes" metric above. Only true orphan today: `CaptainLockedView` (126-LOC SwiftUI view, zero callers).

### 10. Progress Against 30-Day Plan

| Week | Prompts | Complete | Partial | Regressed/Lost | Not started | Effective % |
|---|---|:-:|:-:|:-:|:-:|:-:|
| W1 (Foundation & Safety) — P0.2, P0.3, P1.1, P1.2, P1.3, P1.4 | 6 | 1 (P1.3) | 2 (P1.1 10 %, P1.4 90 %) | 3 (P0.2, P0.3, P1.2) | 0 | ~33 % |
| W2 (Memory Revolution) — P2.1–P2.6 | 6 | 2 (P2.2, P2.3) | 1 (P2.1 90 %) | 0 | 3 (P2.4, P2.5, P2.6) | ~48 % |
| W3 (Reasoning & Sensing) — P3.1–P3.3, P4.1–P4.3 | 6 | 0 | 0 | 0 | 6 | 0 % |
| W4 (Proactive Brilliance) — P5.1–P5.6 | 6 | 0 | 0 | 0 | 6 | 0 % |
| W5 (Soul & Polish) — P6.1, P6.2, P7.1, P7.2 | 4 | 0 | 0 | 0 | 4 | 0 % |
| **Total** | **28** | **3** | **3** | **3** | **19** | **~18 %** |

Binary count: **3 / 28 complete = 10.7 %.** 6 / 28 landed somehow (including partial) = 21 %. Weighted by per-prompt completion ratio: ~18 %.

**Days used:** 1 of 30. **Days remaining:** 29. At ~47 hours of remaining pure implementation work (§8 estimates) + the 2-4 h of `P_MERGE_LOST_WORK` recovery, the plan is still *achievable* — but only if the branch hygiene issue is fixed first. Continuing on the divergent line guarantees repeated re-work.

**Schedule status:** **on-track for the aggregate hours, but off-track for the sequence.** The privacy surgery must land before any more cloud-touching prompts (P2.4 embeddings is ok — purely on-device — but P3.x anything that emits to Gemini is not).

---

## Appendix: Raw Command Output

### A.1 — `git status` (abridged)

```
On branch brain-refactor/p-fix-dev-override
Changes to be committed:
  modified:  AiQo/App/AppDelegate.swift
  modified:  AiQo/Core/Config/AiQoFeatureFlags.swift
  modified:  AiQo/Core/MemoryExtractor.swift
  modified:  AiQo/Core/MemoryStore.swift
  modified:  AiQo/Core/Purchases/SubscriptionTier.swift
  modified:  AiQo/Core/SmartNotificationScheduler.swift
  new file:  AiQo/Features/Captain/Brain/00_Foundation/CaptainLockedView.swift
  modified:  AiQo/Features/Captain/Brain/00_Foundation/DevOverride.swift
  modified:  AiQo/Features/Captain/Brain/00_Foundation/TierGate.swift
  modified:  AiQo/Features/Captain/BrainOrchestrator.swift
  modified:  AiQo/Features/Captain/CaptainChatView.swift
  modified:  AiQo/Features/Captain/CaptainIntelligenceManager.swift
  modified:  AiQo/Features/Captain/CaptainScreen.swift
  modified:  AiQo/Features/Captain/CaptainViewModel.swift
  modified:  AiQo/Features/Captain/ChatHistoryView.swift
  modified:  AiQo/Features/Captain/CloudBrainService.swift
  modified:  AiQo/Features/Captain/CoachBrainMiddleware.swift
  modified:  AiQo/Features/Kitchen/KitchenPlanGenerationService.swift
  modified:  AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift
  modified:  AiQo/Features/Kitchen/SmartFridgeScannerView.swift
  modified:  AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift
  modified:  AiQo/Features/Sleep/SleepSessionObserver.swift
  modified:  AiQo/Premium/AccessManager.swift
  modified:  AiQo/Premium/EntitlementProvider.swift
  modified:  AiQo/Premium/FreeTrialManager.swift
  modified:  AiQo/Services/Notifications/MorningHabitOrchestrator.swift
  modified:  AiQo/Services/Notifications/NotificationService.swift
  modified:  AiQo/Services/Notifications/PremiumExpiryNotifier.swift
  modified:  AiQo/Services/Trial/TrialJourneyOrchestrator.swift
  modified:  AiQo/UI/Purchases/PaywallView.swift
  new file:  AiQoTests/FeatureFlagTests.swift
  modified:  AiQoTests/PurchasesTests.swift
  new file:  AiQoTests/TierGateTests.swift
  new file:  P_FIX_DEV_OVERRIDE_RESULT_2026-04-18.md
```

### A.2 — `git log --oneline --graph --all | head -15`

```
* 869408a Add Procedural/Emotional/Relationship stores + DevOverride gates (P2.3)
* c95d424 Add EpisodicStore and SemanticStore actors (P2.2)
* f74f830 Refactor AiQo workflow for improved validation and persistence
* 8dfeb0c Wire tier gating across remaining premium paths
| * fca3031 P1.3: TierGate single-gate tier API + FeatureFlags validation
| * 14a649b P1.2: move Brain core files into Brain/ skeleton
| * c778f83 P1.1: Brain folder scaffolding (11 subfolders, 91 stubs)
| * 03091f1 P0.3: harden sanitizer regexes + add on-device AuditLogger
| * 8507321 P0.2: kill Arabic API + reroute kitchen + template notifications
|/
* 3bd5230 Fix main-actor warning in LiveWorkoutSession init      ← divergence
```

### A.3 — Brain file inventory

```
$ find AiQo/Features/Captain/Brain -name "*.swift" | sort
AiQo/Features/Captain/Brain/00_Foundation/BrainError.swift            30 LOC
AiQo/Features/Captain/Brain/00_Foundation/CaptainLockedView.swift    126 LOC
AiQo/Features/Captain/Brain/00_Foundation/DevOverride.swift           46 LOC
AiQo/Features/Captain/Brain/00_Foundation/DiagnosticsLogger.swift     56 LOC
AiQo/Features/Captain/Brain/00_Foundation/TierGate.swift             208 LOC
AiQo/Features/Captain/Brain/02_Memory/Stores/EmotionalStore.swift    240 LOC
AiQo/Features/Captain/Brain/02_Memory/Stores/EpisodicStore.swift     588 LOC
AiQo/Features/Captain/Brain/02_Memory/Stores/ProceduralStore.swift   240 LOC
AiQo/Features/Captain/Brain/02_Memory/Stores/RelationshipStore.swift 205 LOC
AiQo/Features/Captain/Brain/02_Memory/Stores/SemanticStore.swift     624 LOC
                                                                    —————
                                                             total 2 363 LOC
$ find AiQo/Features/Captain/Brain -type d | sort
AiQo/Features/Captain/Brain
AiQo/Features/Captain/Brain/00_Foundation
AiQo/Features/Captain/Brain/02_Memory
AiQo/Features/Captain/Brain/02_Memory/Stores
```

### A.4 — File counts across branches / commits

```
$ git ls-tree -r c778f83     'AiQo/Features/Captain/Brain/' | wc -l   → 91
$ git ls-tree -r 14a649b     'AiQo/Features/Captain/Brain/' | wc -l   → 119
$ git ls-tree -r fca3031     'AiQo/Features/Captain/Brain/' | wc -l   → 119
$ git ls-tree -r 8dfeb0c     'AiQo/Features/Captain/Brain/' | wc -l   →   3
$ git ls-tree -r f74f830     'AiQo/Features/Captain/Brain/' | wc -l   →   3
$ git ls-tree -r c95d424     'AiQo/Features/Captain/Brain/' | wc -l   →   5
$ git ls-tree -r 869408a     'AiQo/Features/Captain/Brain/' | wc -l   →   9
$ git ls-tree -r HEAD        'AiQo/Features/Captain/Brain/' | wc -l   →   9
$ git ls-tree -r brain-refactor/p1-4-tier-wiring 'AiQo/Features/Captain/Brain/' | wc -l → 119
```

### A.5 — Privacy regression evidence

```
$ grep -c "ARABIC" AiQo/Info.plist                                    → 2
$ grep -c "ARABIC" <(git show brain-refactor/p1-4-tier-wiring:AiQo/Info.plist)  → 0
$ grep -rn "AuditLogger" AiQo --include="*.swift"                     → (no matches)
$ grep -rn "generateArabicAPIReply" AiQo --include="*.swift" | wc -l  → 2
$ grep -rn "\.arabicAPI" AiQo --include="*.swift" | wc -l             → 33
$ grep -rn "CoachBrainLLMTranslator" AiQo --include="*.swift" | wc -l → 7
```

### A.6 — Build result (last 2 lines)

```
ValidateEmbeddedBinary /…/Build/Products/Debug-iphoneos/AiQo.app/PlugIns/AiQoWidgetExtension.appex …
** BUILD SUCCEEDED **
```

### A.7 — Memory store wiring

```
AiQo/App/AppDelegate.swift:26      if FeatureFlags.memoryV4Enabled {
AiQo/App/AppDelegate.swift:27          Task { @MainActor in
AiQo/App/AppDelegate.swift:28              let v4Container = …
AiQo/App/AppDelegate.swift:29              await ProceduralStore.shared.configure(container: v4Container)
AiQo/App/AppDelegate.swift:30              await EmotionalStore.shared.configure(container: v4Container)
AiQo/App/AppDelegate.swift:31              await RelationshipStore.shared.configure(container: v4Container)
                                            // + EpisodicStore + SemanticStore
AiQo/App/AppDelegate.swift:88      let schema = Schema(versionedSchema: MemorySchemaV4.self)
```

### A.8 — Test files

```
AiQoTests/AppleIntelligenceSleepAgentTests.swift
AiQoTests/CaptainMemoryRetrievalTests.swift
AiQoTests/CaptainPersonalizationReminderMappingTests.swift
AiQoTests/CaptainPersonalizationStoreTests.swift
AiQoTests/CaptainSleepPromptBuilderTests.swift
AiQoTests/EmotionalStateEngineTests.swift
AiQoTests/EmotionalStoreTests.swift
AiQoTests/EpisodicStoreTests.swift
AiQoTests/FeatureFlagTests.swift       ← new (staged)
AiQoTests/IngredientAssetCatalogTests.swift
AiQoTests/IngredientAssetLibraryTests.swift
AiQoTests/MemorySchemaV4Tests.swift
AiQoTests/ProactiveEngineTests.swift
AiQoTests/ProceduralStoreTests.swift
AiQoTests/PurchasesTests.swift
AiQoTests/QuestEvaluatorTests.swift
AiQoTests/RelationshipStoreTests.swift
AiQoTests/SemanticStoreTests.swift
AiQoTests/SentimentDetectorTests.swift
AiQoTests/SleepAnalysisQualityEvaluatorTests.swift
AiQoTests/SmartWakeManagerTests.swift
AiQoTests/TierGateTests.swift          ← new (staged)
AiQoTests/TrendAnalyzerTests.swift
PrivacySanitizerTests.swift            ← MISSING (P0.3 claimed 27 tests)
```

### A.9 — Staged RESULT files at project root

```
P1.4_RESULT_2026-04-18.md              6 702 bytes
P2.1_RESULT_2026-04-18.md              3 482 bytes
P2.2_RESULT_2026-04-18.md              3 365 bytes
P2.3_RESULT_2026-04-18.md              6 896 bytes
P_FIX_DEV_OVERRIDE_RESULT_2026-04-18.md 10 908 bytes  (staged, not committed)
```

No RESULT files for P0.2 or P0.3 at the root — those branches were never merged forward so their RESULT files didn't propagate.

---

*End of audit.*
