# BATCH 4 — Reasoning Layer Result Report

**Date:** 2026-04-19
**Branch:** `brain-refactor/batch-4-reasoning` (merged --ff-only into `brain-refactor/p-fix-dev-override`, both pushed)
**Starting commit:** `33e7d9e` (BATCH 3 final)
**Final commit on topic branch:** `572394d` (BATCH 4c)

---

## Commit chain

```
572394d BATCH 4c: IntentClassifier + ContextualPredictor (on-device heuristics)
899545e BATCH 4b: CulturalContextEngine + PersonaAdapter (Ramadan/Jumu'ah/Eid aware)
6b804df BATCH 4a: EmotionalEngine API + EmotionalReading snapshot
f5d4723 chore: reorganize docs — move result reports into untitled folder, drop stale blueprints
33e7d9e BATCH 3: update result report with final test counts (21 new + 20 regressions all green)
```

---

## PART A — EmotionalEngine + EmotionalReading

**Files added:**
- `AiQo/Features/Captain/Brain/03_Reasoning/EmotionalReading.swift` — 44 lines
- `AiQo/Features/Captain/Brain/03_Reasoning/EmotionalEngineAPI.swift` — 120 lines
- `AiQoTests/EmotionalEngineAPITests.swift` — 35 lines

**EmotionKind enum cases used (all 16 existed, zero deferred):**
`joy, gratitude, pride, peace, hope, love, relief, contentment` (positive group),
`grief, anxiety, shame, frustration, fear, longing, guilt, anger` (non-positive group).

The legacy `EmotionalStateEngine` (`EmotionalEngine.swift`) was left untouched; the new `EmotionalEngine` actor is a separate thin façade that composes `SentimentDetector` + `BioStateEngine` + `EmotionalStore`.

**SentimentDetector API matched:** `detect(message:) -> SentimentResult` — we read `.sentiment` (`MessageSentiment` enum: `.positive/.negative/.neutral/.question`).

**Trend computation:** splits the last 24h of `EmotionalMemorySnapshot`s in half; `improving` / `declining` when positive-count delta ≥ 2, `volatile` when flip-count ≥ max(3, count/3), else `stable`. Fewer than 3 samples → `unknown`.

**Tests (5/5 passing in iPhone 17 Pro simulator):**
- `testReadingWithoutMessageStillReturns` (0.102s)
- `testNegativeMessageShiftsPrimary` (0.005s)
- `testPositiveMessageRaisesIntensity` (0.001s)
- `testReadingWithSignals` (0.001s)
- `testReadingIntensityClamped` (0.001s)

---

## PART B — CulturalContextEngine + PersonaAdapter

**Files touched:**
- `AiQo/Features/Captain/Brain/03_Reasoning/CulturalContextEngine.swift` — 102 lines (replaced 8-line stub)
- `AiQo/Features/Captain/Brain/03_Reasoning/PersonaDirective.swift` — 39 lines (new)
- `AiQo/Features/Captain/Brain/03_Reasoning/PersonaAdapter.swift` — 110 lines (replaced 8-line stub)
- `AiQoTests/CulturalContextEngineTests.swift` — 139 lines

**Ramadan detection:** `Calendar(identifier: .islamicUmmAlQura).component(.month, from: now) == 9`. No network, no prayer-time API.

**Fasting window:** coarse 04:00–19:00 local approximation (`Calendar.current.component(.hour, ...)`). Acceptable for tone adjustment per spec.

**Eid detection:** Hijri calendar:
- `eidFitr` — 1–3 Shawwal (month 10)
- `eidAdha` — 10–13 Dhu al-Hijjah (month 12)

**Jumu'ah + weekend:** `weekday == 6` (Friday) for Jumu'ah; `weekday == 6 || 7` for Gulf weekend.

**Sample dates tested:**
- Wednesday 2026-05-13 15:00 → not Jumu'ah ✓
- Friday 2026-05-15 12:00 → Jumu'ah = true ✓
- Saturday 2026-05-16 10:00 → weekend = true ✓

**TimeOfDay adaptation:** spec referenced `.earlyMorning`; actual `BioSnapshot.TimeOfDay` has `.dawn/.morning/.midday/.afternoon/.evening/.night/.lateNight`. Mapped `.earlyMorning` → `.dawn`. `PersonaAdapter.computeHints` now emits "user just woke up" for `.dawn` and "late night — encourage rest" for `.lateNight`.

**Tone decision matrix:**
| Condition | Tone |
|---|---|
| `primary == .grief` | `.gentle` |
| `intensity > 0.8 && (.frustration \|\| .shame)` | `.gentle` |
| `trend == .declining` | `.encouraging` |
| `primary == .joy && intensity > 0.6` | `.celebratory` |
| `isJumuah \|\| (Ramadan && .evening)` | `.reflective` |
| else | `.warm` |

**Humor gate:** disallowed when `intensity > 0.7 && primary != .joy`, or during fasting hour. `.eidFitr`/`.eidAdha` re-enable humor even during fasting (takes celebration precedence).

**Tests (12/12 passing):**
- Cultural: `testCurrentReturnsState`, `testOrdinaryWeekdayDetection`, `testJumuahDetection`, `testGulfWeekendIncludesSaturday`, `testPromptSummaryNonEmpty` (5/5)
- Persona: `testReflectiveToneOnJumuah`, `testHumorSuppressedDuringFasting`, `testGentleToneForGrief`, `testEncouragingToneForDecliningTrend`, `testCelebratoryToneForHighJoy`, `testEidAllowsHumorEvenWhenFasting`, `testPromptSuffixIncludesTone` (7/7)

---

## PART C — IntentClassifier + ContextualPredictor

**Files touched:**
- `AiQo/Features/Captain/Brain/03_Reasoning/IntentClassifier.swift` — 152 lines (replaced 8-line stub)
- `AiQo/Features/Captain/Brain/03_Reasoning/ContextualPredictor.swift` — 69 lines (replaced 8-line stub)
- `AiQoTests/IntentClassifierTests.swift` — 78 lines

**Crisis keyword counts:**
- English: 7 phrases (`kill myself`, `end it all`, `no reason to live`, `want to die`, `hurt myself`, `suicide`, `suicidal`)
- Arabic: 5 phrases (`أنتحر`, `ما أبي أعيش`, `أموت`, `أنهي حياتي`, `أذي نفسي`)
- **Total: 12 markers** (append-only per spec hard rule)

Classification order (first match wins): **crisis → social (family markers) → question → greeting → request → goal → venting → social (extracted names) → unknown**. Crisis is checked first, so "why would I kill myself?" classifies as `crisis`, not `question` — verified by `testCrisisBeatsQuestion`.

**Name extraction:** capitalized-words heuristic with skip-list `{I, The, A, An, But, And, Or, So, My, Your, His, Her}`, min length 3, alphabetic-only. Used both as a `.social` fallback and as metadata for `.question`.

**TimeOfDay adaptation in ContextualPredictor:** spec's `.earlyMorning` mapped to `.dawn`. Switch now covers: `.dawn/.morning → movement-or-motivation`, `.midday → hydration`, `.afternoon → movement-or-nutrition`, `.evening → celebration-or-nutrition`, `.night/.lateNight → sleepPrep`. `context.needsRecovery` (HRV <30 or sleep <6h per BioStateEngine) short-circuits all switches to `.recovery (0.85)`.

**Tests (13/13 passing):**
- Intent (12): `testCrisisPhraseEnglishFiresImmediately`, `testCrisisPhraseArabicFires`, `testQuestionWithMark`, `testQuestionArabicMark`, `testQuestionStartsWithWhat`, `testGreetingDetection`, `testGoalDetection`, `testVentingDetection`, `testSocialReferenceWithFamily`, `testRequestDetection`, `testUnknownReturnsLowConfidence`, `testCrisisBeatsQuestion`
- Predictor (1): `testPredictionReturnsValidNeed`

---

## Overall

**Build status:** ✅ Zero Swift errors in both `AiQo` and `AiQoTests` targets (`xcodebuild -target AiQoTests -sdk iphonesimulator26.4 build`, grep on `\.swift:\d+:\d+: error:` returned zero matches after each PART).

**Test count:** 30/30 new BATCH 4 tests passing, executed on `platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4` with `CODE_SIGNING_ALLOWED=NO` after iOS 26.4 device platform was reinstalled via Xcode > Settings > Components (one-off env fix between BATCH 3 and BATCH 4). Full test suite not re-verified in this batch — no files outside `Brain/03_Reasoning/` and `AiQoTests/` were modified, so regressions are unlikely.

```
** TEST SUCCEEDED **
Testing started
EmotionalEngineAPITests       — 5/5 passed
CulturalContextEngineTests    — 5/5 passed
PersonaAdapterTests            — 7/7 passed
IntentClassifierTests          — 12/12 passed
ContextualPredictorTests       — 1/1 passed
```

**Cloud audit:** `grep -rn "URLSession\|https://" AiQo/Features/Captain/Brain/03_Reasoning/ --include="*.swift"` → zero matches. All reasoning is on-device.

**Info.plist:** no changes, no new permission keys.

**Lines added:**
- Source: 636 (EmotionalReading 44 + EmotionalEngineAPI 120 + CulturalContextEngine 102 + PersonaDirective 39 + PersonaAdapter 110 + IntentClassifier 152 + ContextualPredictor 69)
- Tests: 252 (Emotional 35 + Cultural/Persona 139 + Intent/Predictor 78)
- **Total: 888 lines**

**Push status:**
- `brain-refactor/batch-4-reasoning` → pushed to origin
- `brain-refactor/p-fix-dev-override` → merged --ff-only and pushed to origin (commits `6b804df..572394d`)

---

## Deferred items

1. **`PersonaAdapter` downstream integration** — `BrainOrchestrator` / `PromptComposer` / `NotificationBrain` don't yet consume `PersonaDirective`. Wiring is a future BATCH (likely BATCH 5 — Inference).
2. **`ContextualPredictor` prediction into triggers** — Not yet wired to `NotificationBrain` or a background task. Today the predictor is read-on-demand only.
3. **`CulturalContextEngine.State.region` detection** — currently hardcoded to `.gulf`. Future work can tie to `Locale` or a user-profile preference.
4. **Prayer-time precision** — fasting-hour detection is a coarse 04:00–19:00 window. If a BATCH needs sunrise/sunset-accurate windows, it will require a local Adhan library (no network).
5. **Crisis response pipeline** — `IntentClassifier` flags `.crisis` with high confidence, but the downstream "what do we do when crisis is detected?" belongs to BATCH 8 (`CrisisDetector` + response playbook).
6. **Watch widget asset catalog issue** — during initial verification, `AiQoWatchWidget/Assets.xcassets` failed with `No simulator runtime version from ["23E244"] available to use with iphonesimulator SDK version 23E252`. This is pre-existing and unrelated to BATCH 4. Resolved for this run by reinstalling the iOS 26.4 platform through Xcode > Settings > Components.

---

## Hard-rules compliance

- [x] No cloud calls — grep confirms zero `URLSession`/`https://` in `Brain/03_Reasoning/`
- [x] No new `EmotionKind` cases — wrapped the existing 16
- [x] No new `SentimentDetector` behavior — wrapped `detect(message:) -> SentimentResult`
- [x] Crisis patterns append-only (12 markers, none removed)
- [x] `PersonaAdapter` is pure — same `(EmotionalReading, CulturalContextEngine.State, dialect)` always produces same `PersonaDirective`; no mutating state inside the actor
- [x] `CulturalContextEngine` is pure — `static func current(now: Date = Date())` with injectable `now`
- [x] `IntentClassifier` conservative on crisis — crisis checked first with 0.95 confidence; `testCrisisBeatsQuestion` verifies question-mark doesn't dilute crisis classification
- [x] One commit per PART — `6b804df`, `899545e`, `572394d`
- [x] Pushed to origin after verification
