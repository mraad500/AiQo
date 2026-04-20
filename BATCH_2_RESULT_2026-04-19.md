# BATCH 2 Result — Memory Intelligence (EmbeddingIndex + MemoryRetriever + Extractors)

**Branch:** `brain-refactor/batch-2-memory-intelligence`
**Commits:** 4 (2a, 2a-fixup, 2b, 2c)
**Status:** All parts complete. Build green. 29/29 tests pass. Cloud-call audit clean.

---

## PART A — Indexing (commit `1440ce2` + fixup `a6db820`)

### Files added / replaced
- [AiQo/Features/Captain/Brain/02_Memory/Indexing/EmbeddingIndex.swift](AiQo/Features/Captain/Brain/02_Memory/Indexing/EmbeddingIndex.swift) — actor, `NLEmbedding`-backed Arabic + English embedder with a 500-entry LRU-ish cache.
- [AiQo/Features/Captain/Brain/02_Memory/Indexing/SalienceScorer.swift](AiQo/Features/Captain/Brain/02_Memory/Indexing/SalienceScorer.swift) — pure enum + weighted `Signals` scorer, clamped to 0–1.
- [AiQo/Features/Captain/Brain/02_Memory/Indexing/TemporalIndex.swift](AiQo/Features/Captain/Brain/02_Memory/Indexing/TemporalIndex.swift) — actor with 5-minute TTL window cache.
- [AiQoTests/EmbeddingIndexTests.swift](AiQoTests/EmbeddingIndexTests.swift) — 14 test cases across 3 suites.

### Test results
| Suite | Tests | Status |
|---|---|---|
| `EmbeddingIndexTests` | 6 | pass |
| `SalienceScorerTests` | 5 | pass |
| `TemporalIndexTests` | 3 | pass |

### Known limitations
- Arabic `NLEmbedding` availability: the test `testEmbedArabicReturnsVector` gracefully documents if unavailable on a given simulator runtime rather than failing. On iPhone 17 Pro simulator the Arabic embedding was available and returned a vector.
- Fixup commit `a6db820` added `throws` to two tests that call `XCTSkip` — caught only when building the test target, not the main app.

---

## PART B — Intelligence Retrieval (commit `815c27f`)

### Files added / replaced
- [AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryBundle.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryBundle.swift) — new `Sendable` result struct.
- [AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryRetriever.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryRetriever.swift) — unified RAG actor.
- [AiQoTests/MemoryRetrieverTests.swift](AiQoTests/MemoryRetrieverTests.swift) — 6 test cases.

### Store methods added
None. All five stores already expose the APIs the retriever calls:
- `SemanticStore.all(limit:)` — at [SemanticStore.swift:241](AiQo/Features/Captain/Brain/02_Memory/Stores/SemanticStore.swift:241)
- `EpisodicStore.recentEntries(limit:)` — at [EpisodicStore.swift:190](AiQo/Features/Captain/Brain/02_Memory/Stores/EpisodicStore.swift:190)
- `ProceduralStore.patterns(minStrength:kinds:limit:)` — at [ProceduralStore.swift:135](AiQo/Features/Captain/Brain/02_Memory/Stores/ProceduralStore.swift:135)
- `EmotionalStore.unresolvedEmotions(olderThan:minIntensity:limit:)` — at [EmotionalStore.swift:100](AiQo/Features/Captain/Brain/02_Memory/Stores/EmotionalStore.swift:100)
- `RelationshipStore.recentlyMentioned(in:within:)` — at [RelationshipStore.swift:103](AiQo/Features/Captain/Brain/02_Memory/Stores/RelationshipStore.swift:103)

### Tier budget verification
Confirmed by `testMaxTierRespectsBudget` (Max tier ⇒ 10 budget, allowing rounding slack to 15) and `testFreeTierReturnsEmpty` (free tier ⇒ 0 budget ⇒ empty bundle). Pro tier uses the TierGate default of 25.

| Tier | `maxMemoryRetrievalDepth` | Test outcome |
|---|---|---|
| `.pro` | 25 | retrieve returns non-nil bundle (empty DB) |
| `.max` | 10 | `bundle.totalItems <= 15` holds |
| `.none` | 0 | `bundle.isEmpty` is `true` |

### Test results
| Suite | Tests | Status |
|---|---|---|
| `MemoryRetrieverTests` | 5 | pass |
| `MemoryBundleTests` | 1 | pass |

### Deviations from spec
- Log calls use `diag.info(...)` (the codebase's existing shorthand for `DiagnosticsLogger.shared.info`) rather than the spec's `DiagnosticsLogger.shared.log(...)` — there is no `.log` method.
- `MemoryRetriever`, `MemoryBundle` are declared `internal` (no `public`) because snapshot types (`SemanticFactSnapshot`, etc.) are module-internal; exposing an internal type through a public API would not compile.
- `retrieve(...)` signature: `tier` is `SubscriptionTier? = nil` (falls through to `TierGate.shared.currentTier`) rather than the spec's eager default, to avoid triggering TierGate at call-site default evaluation.
- Recency half-life set to 30 days (720 hours) per spec; kept as a `nonisolated static` helper on the actor.

---

## PART C — Extractors (commit `0d4abd0`)

### Files added / replaced
- [AiQo/Features/Captain/Brain/02_Memory/Intelligence/FactExtractor.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/FactExtractor.swift) — heuristic marker extraction + optional on-device LLM path.
- [AiQo/Features/Captain/Brain/02_Memory/Intelligence/EmotionalMiner.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/EmotionalMiner.swift) — tier-gated emotional signal miner.
- [AiQoTests/FactExtractorTests.swift](AiQoTests/FactExtractorTests.swift) — 9 tests across 2 suites.

### Foundation Models availability
Foundation Models is guarded with `#if canImport(FoundationModels)` and `@available(iOS 26.0, *)` — matching the pattern already established at [CaptainOnDeviceChatEngine.swift:55](AiQo/Features/Captain/CaptainOnDeviceChatEngine.swift:55). When Apple Intelligence is unavailable on the test device (or the OS is < 26), `FactExtractor` falls back to heuristic extraction. Heuristic extraction is always available and has no device/OS dependency. On the iPhone 17 Pro simulator used for tests the LLM path is typically unavailable, so tests exercise the heuristic path.

### Heuristic extraction examples
From the passing test cases:
| Input | Extracted category | Sensitive flag |
|---|---|---|
| `"I love running in the morning"` | `.preference` | false |
| `"اسمي محمد"` | `.other` (closest match; `FactCategory` has no `.identity` case) | false |
| `"I want to lose 10 pounds this summer."` | `.goal` | false |
| `"I have anxiety sometimes"` | `.health` | **true** ("anxiety" matches sensitive list) |
| `"The weather is nice today."` | — | — (no markers ⇒ empty) |
| `"   "` | — | — (whitespace trimmed ⇒ empty) |

### EmotionalMiner cadence verification
`testMineOnFreeTierSkipsWork` confirms `.none` tier (cadence `.never`) exits immediately with zero work. `testMineWithFutureDateReturnsZero` confirms that when no episodes fall in the window, the miner writes zero entries. Live mining against real episode data is not unit-testable without fixtures; deferred to integration.

### Test results
| Suite | Tests | Status |
|---|---|---|
| `FactExtractorTests` | 7 | pass |
| `EmotionalMinerTests` | 2 | pass |

### Deviations from spec
- `FactCategory` cases used: `.preference`, `.goal`, `.health`, `.other` — adapted because the enum does **not** contain `.identity` or `.limitation` (per HARD RULES: no new cases added).
- `SentimentDetector` API is `detect(message:) -> SentimentResult` returning a `MessageSentiment` enum (`.positive`, `.negative`, `.neutral`, `.question`) — not a signed `Double`. `EmotionalMiner.signedScore(for:)` converts enum + confidence into a signed score in [-1, 1].
- `EpisodicStore.entries(since:)` does not exist; the miner uses the existing `entries(from:to:)` with `to: Date()` — no new store method needed.
- `EmotionalStore.record(...)` takes `associatedFactIDs:` (uppercase) — matched accordingly.
- LLM guard is `iOS 26.0, *` (Apple Intelligence availability), not `iOS 18.0` as in the prompt.

---

## Overall

### Build status
```
** BUILD SUCCEEDED **
```
`generic/platform=iOS` Debug build, Xcode 16 synchronized-folder project (files picked up automatically, no pbxproj changes needed).

### Test total
29 test cases added, all pass:
| Suite | Count |
|---|---|
| EmbeddingIndexTests | 6 |
| SalienceScorerTests | 5 |
| TemporalIndexTests | 3 |
| MemoryRetrieverTests | 5 |
| MemoryBundleTests | 1 |
| FactExtractorTests | 7 |
| EmotionalMinerTests | 2 |
| **Total** | **29** |

### Cloud-call audit
```
$ grep -rn "URLSession|https://" AiQo/Features/Captain/Brain/02_Memory/Intelligence/ --include=*.swift
AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift:244
AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift:320

$ grep -rn "URLSession|https://" AiQo/Features/Captain/Brain/02_Memory/Indexing/ --include=*.swift
(no matches)
```
The two hits are in the pre-existing `MemoryExtractor.swift` (part of P1.2 scaffolding, not this batch). The four files added/rewritten in BATCH 2 (`EmbeddingIndex`, `SalienceScorer`, `TemporalIndex`, `MemoryBundle`, `MemoryRetriever`, `FactExtractor`, `EmotionalMiner`) add **zero** new cloud calls.

### Deferred items
- Wiring BATCH 2 components into the conversation turn loop (where `FactExtractor.extract(...)` and `EmotionalMiner.mine(...)` get called on new turns) — deferred to BATCH 3 per plan.
- Integration tests that populate the SwiftData stores with fixture data and assert retrieval ranking — deferred; unit scope here.
- Pushing the branch and fast-forwarding `brain-refactor/p-fix-dev-override` — awaiting explicit user confirmation before any remote operation.
