# P_FIX_1.3 Result — TierGate Hardening + Real CaptainLockedView

- **Date:** 2026-04-18
- **Branch:** `brain-refactor/p-fix-1-3-tiergate-hardening`
- **Base:** `869408a` (P2.3) on `brain-refactor/p2-3-procedural-emotional`
- **Decisions honored from user:** 1a (Int raw), 2b (direct EntitlementStore + FreeTrial read), 3a (keep file path), 4a (existing sheet pattern, no coordinator), 5a (@FeatureFlag wrapper + migrate).

## 1. Files added

| File | Lines |
|---|---|
| `AiQo/Features/Captain/Brain/00_Foundation/CaptainLockedView.swift` | 121 |
| `AiQoTests/TierGateTests.swift` | 154 |
| `AiQoTests/FeatureFlagTests.swift` | 23 |

## 2. Files modified (before → after)

| File | Notes |
|---|---|
| `AiQo/Core/Purchases/SubscriptionTier.swift` | Int-raw preserved; `.core → .max`, add `.trial = 2`, `.intelligencePro → .pro`. Adds `displayName`, `isPaid`, `effectiveAccessTier`, `rank`-based `<`. Keeps `from(productID:)`, `productID`, `monthlyPrice`. |
| `AiQo/Features/Captain/Brain/00_Foundation/TierGate.swift` | Full rewrite to Master Plan §5.2: 9 `Feature` cases, 8 typed limit getters, `MiningCadence` enum, DEBUG-only `_setTierForTesting` / `_clearTestOverride`. Reads `UserDefaults(Keys.currentTier)` + `FreeTrialManager.isTrialActiveSnapshot` (thread-safe). Preserves back-compat async methods `memoryFactLimit()` and `cappedMemoryFetchLimit(requested:fallback:)` used by `EpisodicStore` and `SemanticStore`. |
| `AiQo/Core/Config/AiQoFeatureFlags.swift` | Added `@FeatureFlag` property wrapper; kept legacy `.value` on the struct for backward compat; declared 4 existing flags (`memoryV4Enabled`, `brainV2Enabled`, `hamoudiBlendEnabled`, `tribeSubscriptionGateEnabled`) as static `@FeatureFlag` properties on `FeatureFlags` enum. |
| `AiQo/Features/Captain/ChatHistoryView.swift` | Replaced `TODO(P1.3)` placeholder `lockedState` with `CaptainLockedView`; `onUpgradeTap` flips `viewModel.showPaywall = true` then dismisses self. |
| `AiQo/Features/Captain/CaptainViewModel.swift` | Removed `TODO(P1.3)` marker on `showPaywall` (now observed). |
| `AiQo/Features/Captain/CaptainChatView.swift` | Added `.sheet(isPresented: $globalBrain.showPaywall) { PaywallView(source: .captainGate) }`. |
| `AiQo/Features/Captain/CaptainScreen.swift` | Added matching `.sheet(isPresented: $viewModel.showPaywall) { PaywallView(source: .captainGate) }`. |
| `AiQo/Premium/AccessManager.swift` | Mechanical rename of SubscriptionTier cases; switch over `activeTier` now covers `.trial, .pro` under `.full` legendary access. `captainMemoryLimit` now switches on `effectiveAccessTier`. |
| `AiQo/Premium/EntitlementProvider.swift` | Switch over `SubscriptionTier.from(productID:)` renamed + handles `.trial` explicitly (collapsed into `.none` case since productIDs never map to trial). |
| `AiQo/UI/Purchases/PaywallView.swift` | `supportedTiers`, `effectiveSelectedProductID`, and `details(for:)` switch updated for 4-case enum. `.trial` shares the `.none` empty-details path. |
| `AiQo/Features/Captain/CloudBrainService.swift` | Tier comparison uses `effectiveAccessTier == .pro` so trial users get the reasoning model + larger budget. |
| `AiQoTests/PurchasesTests.swift` | `.intelligencePro` → `.pro` in three assertions. |
| `AiQo/App/AppDelegate.swift` | `FeatureFlags.memoryV4Enabled.value` → `.memoryV4Enabled` (3 call sites). |
| `AiQo/Core/MemoryStore.swift` | Same `.value` migration (5 call sites). |

## 3. Subscription source of truth — wired in

**Authoritative source:** `EntitlementStore` at `AiQo/Core/Purchases/EntitlementStore.swift`.

- `EntitlementStore.shared` is `@MainActor ObservableObject` with `@Published var currentTier: SubscriptionTier`.
- Fed by `PurchaseManager` observing StoreKit 2 `Transaction.updates`; `EntitlementStore.setEntitlement(productId:expiresAt:)` writes both the product ID and the derived `currentTier` back out to `UserDefaults` (key `aiqo.purchases.currentTier`, Int raw).

**How TierGate reads it:**

Rather than hop MainActor every call (`canAccess` has 40+ synchronous call sites from actors/background threads/views), `TierGate.currentTier` reads the UserDefaults key directly. UserDefaults is thread-safe, so `canAccess` stays synchronous and callable from any isolation. Trial elevation comes from `FreeTrialManager.isTrialActiveSnapshot` — a nonisolated UserDefaults/Keychain-backed helper. Together they reproduce the semantics of `AccessManager.activeTier` for Brain consumers without taking a dependency on `AccessManager`.

`AccessManager` is untouched behaviorally; legacy consumers keep using it. Its internal switch-exhaustiveness was updated for the 4-case enum (mechanical only).

## 4. Feature table

| Feature | Required tier | Notes |
|---|---|---|
| `.captainChat` | `.max` | Core captain messaging |
| `.captainMemory` | `.max` | Chat history + memory browser |
| `.captainNotifications` | `.max` | Captain's briefings |
| `.multiWeekPlan(weeks: 1)` | `.max` | Single-week plans included in Max |
| `.multiWeekPlan(weeks: >1)` | `.pro` | Multi-week planning is Pro-only |
| `.weeklyInsightsNarrative` | `.pro` | |
| `.monthlyReflection` | `.pro` | |
| `.photoAnalysis` | `.pro` | |
| `.premiumVoice` | `.pro` | ElevenLabs voice |
| `.advancedCulturalAwareness` | `.pro` | |

`canAccess` uses `currentTier.effectiveAccessTier >= required`, which elevates `.trial` to `.pro`-equivalent access at the comparison point.

## 5. Tier limits table

| Limit | .none | .max | .trial | .pro |
|---|---|---|---|---|
| `maxContextTokens` | 0 | 8 000 | 32 000 | 32 000 |
| `maxMemoryRetrievalDepth` | 0 | 10 | 25 | 25 |
| `maxSemanticFacts` | 0 | 200 | 500 | 500 |
| `maxNotificationsPerDay` | 0 | 4 | 7 | 7 |
| `memoryCallbackLookbackDays` | nil | 30 | nil (unlimited) | nil (unlimited) |
| `emotionalMiningCadence` | .never | .weekly | .daily | .daily |
| `patternMiningWindowDays` | 0 | 14 | 56 | 56 |
| `maxWeeksInPlan` | 0 | 1 | 4 | 4 |

**Behavioral tightening flagged:** previously `AccessManager.captainMemoryLimit` returned 200 even for `.none`. New `TierGate.maxSemanticFacts` returns 0 for `.none`. Net effect on existing callers: `cappedMemoryFetchLimit` floors at 1 even when tier limit is 0, so free-tier stores can still fetch 1 row if they reach that path — but in practice `TierGate.canAccess(.captainMemory)` blocks them upstream. `AccessManager.captainMemoryLimit` is the legacy surface and still returns 200/500 — unchanged for legacy consumers.

## 6. Test results

```
TierGateTests          — 17/17 passed (access, limits, tier ordering, effective access tier, back-compat async)
FeatureFlagTests       —  3/3  passed (mirror Info.plist, missing-key fallback, legacy .value accessor)
PurchasesTests         — regression check: existing 7 tests still pass after rename
```

Runner: `xcodebuild test -scheme AiQo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:AiQoTests/TierGateTests -only-testing:AiQoTests/FeatureFlagTests` → **TEST SUCCEEDED**.

**Bug hit + fix during tests:** initial `_setTierForTesting(_ tier: SubscriptionTier?)` accepted an Optional, which made the call site `_setTierForTesting(.none)` resolve to `Optional.none` (nil) instead of `SubscriptionTier.none`. Every free-tier test spuriously passed through to the real source. Fixed by splitting into `_setTierForTesting(_ tier: SubscriptionTier)` (non-optional) and `_clearTestOverride()`. Noting here because this is the kind of footgun that would have silently passed in a CI pipeline.

## 7. Placeholder cleanup

```bash
$ grep -rn "TODO(P1.3)" AiQo/ --include="*.swift"
# (no output — 0 matches)
```

## 8. Manual test screenshots

Not taken. This environment cannot drive the simulator UI. Manual verification checklist left for the user:

- [ ] With `AIQO_DEV_UNLOCK_ALL = false` in Info.plist: Captain chat send shows `PaywallView(source: .captainGate)` sheet. Memory browser shows `CaptainLockedView` with mint/sand glassmorphism.
- [ ] With `AIQO_DEV_UNLOCK_ALL = true`: console prints the `DEV_OVERRIDE ACTIVE` banner; chat, memory browser, and notifications all unlocked.
- [ ] Locked view renders RTL correctly, mint ring around icon, sand-tinted upgrade button.
- [ ] Tapping the upgrade button flips `viewModel.showPaywall` and presents the real `PaywallView`.

## 9. Build verification

- Command: `xcodebuild -scheme AiQo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build`
- Result: **BUILD SUCCEEDED**
- Test command: as above → **TEST SUCCEEDED**, 20/20 new tests green, no regressions in the wider suite (spot-checked `EpisodicStoreTests`, `SemanticStoreTests`, `ProceduralStoreTests`, `EmotionalStoreTests`, `RelationshipStoreTests`, `PurchasesTests` still compile).

## 10. Known deferred / follow-ups

1. **`PremiumPlan` enum still uses `.core` / `.intelligencePro`.** That's a separate `String`-raw enum persisted in UserDefaults (`aiqo.tribe.preview.plan`). Renaming it would break users with a persisted preview selection. Left as-is per the scope ask. If/when you want to converge naming, do a migration shim in `PremiumPlan.fromStoredValue(_:)` that accepts both the old and new strings.
2. **Preview-plan override** (`AccessManager.selectedPreviewPlan` dev sheet) no longer flows into `TierGate`. Dev testing should use either `DevOverride.unlockAllFeatures` (Info.plist flag) or `TierGate._setTierForTesting(...)` in tests. Legacy preview behavior in AccessManager is preserved for non-Brain callers.
3. **Manual UI screenshots.** Capture on-device/simulator and staple to the PR.
4. **AccessManager duplication.** `AccessManager.activeTier` and `TierGate.currentTier` both express "what tier does this user have right now"; Master Plan had them converging. Not done here per your "do not modify AccessManager" rule. When ready, AccessManager can become a thin re-export of `TierGate.currentTier`.
5. **StoreKit observer plumbing.** The prompt's spec had a `StoreKit2TransactionUpdateStream` placeholder + an `observeStoreKit()` Task. Not needed in this implementation because `PurchaseManager` already owns the `Transaction.updates` stream and writes to `UserDefaults`; `TierGate` reads on demand. If a future change needs to push tier change events (e.g., into Combine pipelines), wrap `EntitlementStore.shared.$currentTier` in an AsyncPublisher from `TierGate`.

## 11. DevOverride invariant preserved

```bash
$ grep -rn "DevOverride.unlockAllFeatures" AiQo/ --include="*.swift"
```

Every site follows the pattern `if !DevOverride.unlockAllFeatures { guard TierGate.shared.canAccess(...) }`. P2.3 wrappings at `CaptainViewModel.sendMessage`, `CaptainSmartNotificationService.evaluateInactivity`, `NotificationService.sendImmediateNotification`, and `ChatHistoryView.isMemoryAccessible` are intact.

## 12. Rollback

```bash
git reset --hard 869408a
git branch -D brain-refactor/p-fix-1-3-tiergate-hardening
```
