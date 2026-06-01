# AiQo — Performance Review

> A **static, architecture-level** performance review (memory, battery, SwiftUI/render, HealthKit, AI inference). It is **not** an Instruments profile — no runtime measurements were taken — so each item ends with how to confirm it. No Swift source was modified, to preserve the in-review build. **Date:** 2026-05-30.

---

## 1. Method & caveat

This review reads the architecture (the Captain "Brain", HealthKit service, SwiftUI feature modules) and flags likely hot spots and confirmed good patterns. **Do not treat estimates as measured.** The single most valuable next step is a profiling pass (§8). The team's standing principle applies: *fix the root-cause CPU/render hog; never paper over a freeze by lowering a timeout.*

---

## 2. What's already done well ✅

- **Off-main-thread sanitization.** `CloudBrainService` runs `PrivacySanitizer.sanitizeForCloud()` on the cooperative pool, so regex over the conversation never blocks the UI.
- **Batched MainActor access.** A single `@MainActor` hop fetches tier + memories + consent + profile in one round-trip instead of many.
- **HealthKit is actor-isolated** with `HKObserverQuery` background delivery and **debounced** widget reloads — avoids redundant timeline rebuilds.
- **Conversation compaction** caps prompt size (a `ConversationDigest` instead of unbounded history) — fewer tokens, lower latency and cost.
- **Centralized model policy** (`GeminiModelPolicy`) + a fallback chain (cloud → on-device → offline message) avoids stalls when the network is slow.
- **Network timeouts** are explicit (35 s request / 40 s resource) — prevents hung requests.

---

## 3. Likely hot spots (verify before acting)

| Area | Hypothesis | How to confirm |
|---|---|---|
| **On-device RAG** | The 5 memory stores + `NaturalLanguage` embedding + cosine-similarity scan can be CPU-heavy as memory grows (esp. Pro ~500 facts), potentially adding latency before each cloud turn. | Instruments **Time Profiler** while sending a chat with a large memory; watch `EmbeddingIndex`/`SalienceScorer`. |
| **3D Captain avatar** | A RealityKit scene with continuous idle animation draws GPU/CPU even when the Captain is idle on screen — a battery and thermal cost. | **Energy Log** / GPU report while the Captain tab is foregrounded and idle; consider pausing animation when not visible. |
| **SwiftData on main context** | Memory writes (episodic exchanges, fact extraction) after each turn, if on the main `ModelContext`, can hitch the UI. | Time Profiler during a chat; check for `ModelContext.save` on the main thread. |
| **Home "Daily Aura"** | 19 concentric animated arcs + an interactive water bottle redrawing can be expensive if not throttled. | **Core Animation** instrument / SwiftUI render-count overlay while scrolling Home. |
| **HealthKit historical sync** | Onboarding back-fill (steps/calories/sleep averages) is a burst of queries; first-run latency risk. | Time Profiler during onboarding's "Legacy Calculation" step. |

None of these are confirmed regressions — they are the places a profiler should look first.

---

## 4. Memory (RAM)

- Five SwiftData stores in a dedicated container is reasonable; the risk is **loading too much into memory at once** (e.g. fetching all facts rather than a top-K). Confirm fetches are bounded by `FetchDescriptor.fetchLimit`.
- Image handling (Kitchen fridge scans) re-encodes to ≤1280px before upload — good for both memory and bandwidth.

---

## 5. Battery & energy

- **Background tasks** (morning insight `BGAppRefreshTask`, inactivity `BGProcessingTask`) are the right API and are bounded; confirm they don't over-schedule.
- **Quiet hours** (21:00–08:00) reduce wake-ups.
- The **avatar animation** is the most likely avoidable battery cost — gate it on visibility/`scenePhase`.
- Continuous HR/workout sessions on Apple Watch are inherently costly but expected for a fitness app.

---

## 6. AI inference latency

- **Cloud path** dominates perceived latency. Mitigations already present: model allowlist + flash models, compaction, timeouts, and a prior fix that removed an artificial ~0.82 s delay and client-side simulated reveal.
- **Opportunity:** true streaming (SSE) from the Edge Function would improve *perceived* latency vs. the current wait-then-render. Currently deliberate scope; tracked as a future enhancement.
- **On-device path** (Apple Intelligence) avoids network entirely for sleep/fallback — good.

---

## 7. Safe optimizations (low risk, deferred to avoid touching the in-review build)

These are **recommended**, not applied, because the iOS binary is in review and the program's mandate is to preserve functionality:

1. Pause the RealityKit idle animation when the Captain view is not visible (`scenePhase`/`onDisappear`).
2. Ensure all memory `FetchDescriptor`s carry a `fetchLimit` (top-K retrieval).
3. Move SwiftData memory writes to a background `ModelContext` if profiling shows main-thread saves.
4. Add `.drawingGroup()`/`TimelineView` throttling to the Daily Aura if Core Animation shows excessive redraws.

Apply each only after a profiler confirms the hot spot, and ship on a non-release branch first.

---

## 8. Recommended profiling pass (the real next step)

Run on a physical device (not the simulator) with a realistic, populated account:

1. **Time Profiler** — cold launch, open Captain, send a chat with large memory.
2. **Core Animation / SwiftUI** — scroll Home; open the Captain tab.
3. **Energy Log** — 10 min with the Captain tab idle (avatar animating).
4. **Allocations / Leaks** — navigate all tabs, run a workout, generate a meal plan.
5. **Network** — measure end-to-end chat latency vs. the Gemini round-trip to isolate app overhead.

Capture before/after for any change. This review gives the map; the profiler gives the numbers.
