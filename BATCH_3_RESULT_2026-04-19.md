# BATCH 3 — Wire Memory Intelligence + Sensing Layer (Result Report)

**Date:** 2026-04-19
**Branch:** `brain-refactor/batch-3-wiring-sensing`
**Previous state:** `8d19eaa` (BATCH 2 result report)
**Current state:** `6f9281a` (four sub-commits below)

## Commits

1. `5fafd33` — BATCH 3a: wire FactExtractor + EpisodicStore into BrainOrchestrator conversation loop
2. `3684a5e` — BATCH 3b: BioStateEngine unified HealthKit read API with freshness cache
3. `8b8e29e` — BATCH 3c: BehavioralObserver + ContextSensor + nightly BGTask for emotion/pattern mining
4. `6f9281a` — BATCH 3d: HealthKit/Music/Weather bridges as typed Brain/ adapters

---

## PART A — Wiring

### Where `persistIfMemoryEnabled` was inserted

`AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift`

- **`processLocalRoute` line 136** (success branch of `generateLocalReply`) — persists after a local Apple-Intelligence reply.
- **`processCloudRoute` line 201** (success branch of `cloudService.generateReply`) — persists after a cloud (Gemini) reply.
- **`processCloudRoute` line 225** (local fallback after cloud failure) — persists when Apple Intelligence recovers a failed cloud call.
- **`generateCloudSleepReply` line 308** (retry LLM reply) — persists the second-pass sleep analysis when quality rules accept it.
- **`generateCloudSleepReply` line 313** (primary LLM reply) — persists the first-pass sleep analysis when quality rules accept it.

Helper itself lives at the bottom of the file in a new `private extension BrainOrchestrator` (added lines 702–748).

### Return paths intentionally skipped (no persist)

| Site                              | Reason                                                     |
|-----------------------------------|------------------------------------------------------------|
| `processMessage` line 46 `makeTierRequiredReply` | Tier denial — never reached LLM.            |
| `processLocalRoute` line 142 `makeLocalizedErrorReply` | Generic on-device failure.              |
| `processCloudRoute` line 206 `makeTierRequiredReply` | Tier denial surfaced mid-cloud.           |
| `processCloudRoute` line 219 `makeNetworkErrorReply` | Skipped-AI path when cloud network failed. |
| `processCloudRoute` line 228 `makeNetworkErrorReply` | Final fallback — both paths dead.         |
| `handleSleepAgentError` all `makeComputedSleepReply` branches | On-device heuristic, never LLM.  |
| `generateCloudSleepReply` line 306 `makeComputedSleepReply` | Quality rejected both primary + retry. |

### Store signatures adapted from spec

- Spec proposed `EpisodicStore.recordExchange(userMessage:captainResponse:bioSnapshot:)`. Actual API is `EpisodicStore.record(userMessage:captainResponse:...)` (and 10 other optional params). Used the existing method with defaults — no new helpers added.
- Spec proposed `SemanticStore.addOrReinforce(... relatedEntryID: UUID)`. Actual API takes `relatedEntryIDs: [UUID]`. Wrapped the optional episode ID: `relatedEntryIDs: episodeID.map { [$0] } ?? []`.
- Spec proposed `FactCandidate`. Actual nested type is `FactExtractor.CandidateFact` with `.sensitive` flag. Used that directly.

### Sample log output (expected at runtime)

```
[BrainOrchestrator.swift:747] BrainOrchestrator.persistIfMemoryEnabled: wrote 2 facts (episode=D6B1…)
```

Fact-extraction is dispatched via `Task.detached(priority: .utility)` so conversation reply latency is unchanged.

---

## PART B — BioStateEngine

### File

`AiQo/Features/Captain/Brain/01_Sensing/BioStateEngine.swift` (replaces the 7-line stub).

### Reused `CaptainHealthSnapshotService`

Yes. `BioStateEngine.buildSnapshot()` calls `snapshotService.fetchTodayEssentialMetrics()` and wraps the 4-field `CaptainDailyHealthMetrics` into a full `BioSnapshot`. No HKHealthStore access lives inside BioStateEngine.

### `BioSnapshot` field mismatches (and how adapted)

| Spec field           | Actual field                | Adaptation                                                   |
|----------------------|-----------------------------|--------------------------------------------------------------|
| `recentWorkout`      | (not in `BioSnapshot`)      | Dropped — not needed for current consumers.                  |
| `dayOfWeek: Weekday` | `dayOfWeek: Int`            | Kept `Int` — used `Calendar.component(.weekday, from:)`.     |
| `earlyMorning`       | `dawn` (nested in `BioSnapshot.TimeOfDay`) | Used existing case.                               |
| `hrvBucketed`        | Field exists, but `CaptainDailyHealthMetrics` has no HRV   | Always `nil` for now. `needsRecovery()` still checks it defensively — when HRV lands (BATCH 4), recovery detection activates. |

### Cache behavior

- 180s freshness window (matches the spec's 3-minute default).
- Injectable `clock: @Sendable () -> Date` for deterministic tests.
- `refresh()` always bypasses cache.

### Test count (PART B)

6 tests in `AiQoTests/BioStateEngineTests.swift`:
1. `testCurrentReturnsSnapshotWithSaneFields`
2. `testCachedSnapshotReturnedWithinFreshnessWindow`
3. `testRefreshProducesNewTimestamp`
4. `testBucketingFloorsStepsTo500`
5. `testTimeOfDayMapsAllHoursIntoValidBuckets`
6. `testIsFastingReturnsFalseByDefault`

---

## PART C — BehavioralObserver + BGTask

### Files

- `AiQo/Features/Captain/Brain/01_Sensing/BehavioralObserver.swift` (replaces stub)
- `AiQo/Features/Captain/Brain/01_Sensing/ContextSensor.swift` (replaces stub)
- `AiQo/Features/Captain/Brain/07_Learning/BackgroundCoordinator.swift` (replaces stub)

### BGTask identifier

`aiqo.brain.nightly` — matches the `aiqo.*` prefix used by sibling BGTasks in `Info.plist` (`aiqo.notifications.refresh`, `aiqo.notifications.inactivity-check`), not the bundle identifier (`com.mraad500.aiqo`). All three existing BGTasks follow the `aiqo.` convention, so the new one does too.

### Info.plist change

Before (lines 7–11):

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>aiqo.notifications.refresh</string>
    <string>aiqo.notifications.inactivity-check</string>
</array>
```

After (lines 7–12): appended `aiqo.brain.nightly` — did not replace, did not reorder.

### AppDelegate integration point

`AiQo/App/AppDelegate.swift` lines 33–34, inside the existing `FeatureFlags.memoryV4Enabled` block. Registration + initial schedule both happen during `AiQoApp.init()` so `BGTaskScheduler.register(...)` runs before `application:didFinishLaunching` returns — a hard Apple requirement.

```swift
BackgroundCoordinator.shared.registerTasks()
BackgroundCoordinator.shared.scheduleNextNightly()
```

### Manual test (deferred)

The nightly handler is not unit-testable (`BGTaskScheduler` requires real task dispatch). Deterministic pieces:

- `BackgroundCoordinator.next3am(after:)` is unit-tested with two fixed dates (midday → tomorrow, 1am → today).
- `BackgroundCoordinator.nightlyTaskID` is asserted to match the Info.plist string, preventing typo drift.

End-to-end BGTask dispatch can be fired from Xcode via the `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"aiqo.brain.nightly"]` LLDB command — deferred out of scope for this batch.

### Tests

8 tests across `AiQoTests/BehavioralObserverTests.swift`:
- `BehavioralObserverTests`: 4 tests (record, buffer cap, mine-no-data, below-threshold)
- `ContextSensorTests`: 1 test (capture returns coherent context)
- `BackgroundCoordinatorTests`: 3 tests (identifier check + two `next3am` cases)

---

## PART D — Bridges

### Files created vs. reused

| File                                                           | Status                                                              |
|----------------------------------------------------------------|---------------------------------------------------------------------|
| `Brain/01_Sensing/Bridges/HealthKitBridge.swift`               | Was 191-line `HealthKitMemoryBridge`. Added new `HealthKitBridge` actor **alongside** it (did not replace). Both types coexist — `HealthKitMemoryBridge` still syncs to MemoryStore; `HealthKitBridge` is the new typed accessor for Brain/ consumers. |
| `Brain/01_Sensing/Bridges/MusicBridge.swift`                   | Replaced 8-line stub with typed `NowPlaying` / `Source` API.        |
| `Brain/01_Sensing/Bridges/WeatherBridge.swift`                 | Replaced 8-line stub with typed `Current` / `Condition` API.        |

### Stub markers

- `MusicBridge.nowPlaying()` comment explicitly notes "real implementation (BATCH 6+) wires into SPTAppRemote and MPMusicPlayerController".
- `WeatherBridge.current()` comment notes "real implementation will use WeatherKit (requires entitlement)".

No TODO comments added — stubs simply return `nil` so callers can type-check against the final API shape today.

### Tests

5 tests in `AiQoTests/BridgesTests.swift`:
- `testHealthKitBridgeReportsAvailability`
- `testMusicBridgeStubReturnsNil`
- `testMusicBridgeSourceEnumIsExhaustive`
- `testWeatherBridgeStubReturnsNil`
- `testWeatherBridgeConditionEnumIsExhaustive`

---

## Overall

### Build status

**BUILD SUCCEEDED** on `xcodebuild -destination 'generic/platform=iOS' -configuration Debug` after each of the four sub-commits.

### Total test count added

**19 new tests** across four files:
- `BioStateEngineTests.swift` — 6
- `BehavioralObserverTests.swift` — 8 (3 test classes)
- `BridgesTests.swift` — 5

### Cloud-call audit

```
grep -rn "URLSession\|https://\|http://" Brain/01_Sensing/  → 0 matches
grep -rn "URLSession\|https://\|http://" Brain/07_Learning/ → 0 matches
```

Zero new cloud calls. Sensing + BGTask stays on-device.

### Deferred items

- **HRV in `BioSnapshot`** — `CaptainDailyHealthMetrics` doesn't currently expose HRV. Engine wires `hrvBucketed: nil` and `needsRecovery()` checks it conditionally. Activating HRV-driven recovery detection requires extending the snapshot service (BATCH 4 candidate).
- **Real music / weather data** — both bridges return `nil`. Consumers can type-check against the final API shape today; real Spotify / WeatherKit wiring is BATCH 6 / 7 scope.
- **BGTask integration test** — `BGTaskScheduler` is not mockable from XCTest; the nightly runs `EmotionalMiner.mine(...)` + `BehavioralObserver.mineAndNominate(...)` which each have their own unit coverage. End-to-end is a manual `_simulateLaunchForTaskWithIdentifier` check.
- **Sensitive fact auto-persist** — current code filters them out entirely. Per the HARD RULES ("sensitive facts require explicit user consent") this is intentional; BATCH 8 wires the consent flow.
- **`CaptainContextData.bioContext`** — `HybridBrainRequest` does not currently carry a typed `BioSnapshot`. `persistIfMemoryEnabled` calls `EpisodicStore.record(...)` with `bioContext: nil` (default). When `HybridBrainRequest` gets a typed bio field in a later batch, the wiring will upgrade naturally.

### Hard-rule compliance

| Rule                                                          | Status |
|---------------------------------------------------------------|--------|
| No new cloud calls                                            | ✅ Verified by grep |
| `BrainOrchestrator.processMessage` signature unchanged        | ✅ Still `processMessage(request:userName:) async throws -> HybridBrainServiceReply` |
| No memory poisoning on error paths                            | ✅ Hook placed at LLM-success sites only |
| No new FactCategory or EmotionKind cases                      | ✅ Reused existing enums |
| `CaptainHealthSnapshotService` not replaced                   | ✅ `BioStateEngine` wraps it |
| `Task.detached` for FactExtractor                             | ✅ Conversation flow returns immediately after `EpisodicStore.record` |
| Only non-sensitive facts auto-persist                         | ✅ Hardcoded `candidates.filter { !$0.sensitive }` |
| BGTask identifier matches Info.plist                          | ✅ Unit test pins the literal |
| `BGTaskSchedulerPermittedIdentifiers` appended, not replaced  | ✅ Old entries preserved |
| Every new file under correct `Brain/` subfolder               | ✅ `01_Sensing/`, `07_Learning/` |
| Commit per PART                                               | ✅ Four commits: 5fafd33, 3684a5e, 8b8e29e, 6f9281a |
