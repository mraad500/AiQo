# P_FIX_DEV_OVERRIDE — Diagnostic + Hotfix Result

**Date:** 2026-04-18
**Branch:** `brain-refactor/p-fix-dev-override`
**Base commit:** `869408a` (brain-refactor/p-fix-1-3-tiergate-hardening)

---

## 1. Source of the "AiQo Max" string

Located at [AiQo/Features/Captain/BrainOrchestrator.swift:407](AiQo/Features/Captain/BrainOrchestrator.swift:407):

```swift
func makeTierRequiredReply(
    language: AppLanguage,
    requiredTier: SubscriptionTier
) -> HybridBrainServiceReply {
    let message = language == .arabic
        ? "هاي الميزة تحتاج \(requiredTier.displayName)."   // ← this line
        : "This feature requires \(requiredTier.displayName)."
    ...
}
```

This reply is returned from [BrainOrchestrator.processMessage](AiQo/Features/Captain/BrainOrchestrator.swift:42) — invoked directly in the chat path:

```
CaptainViewModel.sendMessage
  → BrainOrchestrator.processMessage   ← gate fires here, returns "AiQo Max" reply
     → (never reaches CloudBrainService)
```

A second copy of the same string exists in [CaptainViewModel.swift:662](AiQo/Features/Captain/CaptainViewModel.swift:662) as a fallback for `BrainError.tierRequired` thrown from deeper layers — but that path was not what users hit, because `BrainOrchestrator` shortcut returns **before** throwing.

---

## 2. Build configuration

**Not programmatically verified — user must check manually in Xcode scheme editor.**

However, the fix no longer depends on the scheme being Debug in order to *diagnose* the problem: [DevOverride.warnIfActive()](AiQo/Features/Captain/Brain/00_Foundation/DevOverride.swift:25) now prints a 4-line diagnostic at launch that reveals whether `#if DEBUG` was compiled and whether the Info.plist flag is readable. If the scheme is Release, the user will see:

```
  Compiled #if DEBUG              = false
  unlockAllFeatures (effective)   = false
```

…and must flip the scheme to **Debug** (Product → Scheme → Edit Scheme → Run → Info → Build Configuration), then clean and rebuild.

---

## 3. Gate-site audit

**Total gate sites found:** 36 (`.captainChat` × 10, `.captainNotifications` × 26)
**Sites wrapped pre-fix:** 1 (CaptainViewModel only)
**Sites wrapped post-fix:** 36 (all)

### `.captainChat` sites (10)

| File | Line pre-fix | Was wrapped | Now wrapped |
| --- | --- | --- | --- |
| [AiQo/Features/Captain/CaptainViewModel.swift](AiQo/Features/Captain/CaptainViewModel.swift:221) | 222 | ✓ | ✓ |
| [AiQo/Features/Captain/BrainOrchestrator.swift](AiQo/Features/Captain/BrainOrchestrator.swift:42) | 43 | ✗ | ✓ (PRIMARY CULPRIT) |
| [AiQo/Features/Captain/CloudBrainService.swift](AiQo/Features/Captain/CloudBrainService.swift:44) | 44 | ✗ | ✓ |
| [AiQo/Features/Captain/CaptainIntelligenceManager.swift](AiQo/Features/Captain/CaptainIntelligenceManager.swift:275) | 276 | ✗ | ✓ |
| [AiQo/Features/Captain/CoachBrainMiddleware.swift](AiQo/Features/Captain/CoachBrainMiddleware.swift:77) | 78 | ✗ | ✓ |
| [AiQo/Features/Kitchen/KitchenPlanGenerationService.swift](AiQo/Features/Kitchen/KitchenPlanGenerationService.swift:15) | 16 | ✗ | ✓ |
| [AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:117) | 118 | ✗ | ✓ |
| [AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift:135) | 136 | ✗ | ✓ |
| [AiQo/Features/Kitchen/SmartFridgeScannerView.swift](AiQo/Features/Kitchen/SmartFridgeScannerView.swift:185) | 186 | ✗ | ✓ |
| [AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift:263) | 264 | ✗ | ✓ |
| [AiQo/Core/MemoryExtractor.swift](AiQo/Core/MemoryExtractor.swift:184) | 189 | ✗ | ✓ |

### `.captainNotifications` sites (26)

| File | Line pre-fix | Was wrapped | Now wrapped |
| --- | --- | --- | --- |
| [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) | 82 | ✗ | ✓ |
| [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) | 191 | ✓ | ✓ |
| [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) | 271 | ✗ | ✓ |
| [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) | 281 | ✗ | ✓ |
| [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) | 316 | ✗ | ✓ |
| [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) | 367 | ✗ | ✓ |
| [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) | 433 | ✗ | ✓ |
| [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) | 616 | ✗ | ✓ |
| [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) | 1014 | ✗ | ✓ |
| [MorningHabitOrchestrator.swift](AiQo/Services/Notifications/MorningHabitOrchestrator.swift) | 78 | ✗ | ✓ |
| [MorningHabitOrchestrator.swift](AiQo/Services/Notifications/MorningHabitOrchestrator.swift) | 312 | ✗ | ✓ |
| [MorningHabitOrchestrator.swift](AiQo/Services/Notifications/MorningHabitOrchestrator.swift) | 347 | ✗ | ✓ |
| [PremiumExpiryNotifier.swift](AiQo/Services/Notifications/PremiumExpiryNotifier.swift) | 23 | ✗ | ✓ |
| [PremiumExpiryNotifier.swift](AiQo/Services/Notifications/PremiumExpiryNotifier.swift) | 51 | ✗ | ✓ |
| [TrialJourneyOrchestrator.swift](AiQo/Services/Trial/TrialJourneyOrchestrator.swift) | 272 | ✗ | ✓ |
| [TrialJourneyOrchestrator.swift](AiQo/Services/Trial/TrialJourneyOrchestrator.swift) | 301 | ✗ | ✓ |
| [TrialJourneyOrchestrator.swift](AiQo/Services/Trial/TrialJourneyOrchestrator.swift) | 403 | ✗ | ✓ |
| [SmartNotificationScheduler.swift](AiQo/Core/SmartNotificationScheduler.swift) | 107 | ✗ | ✓ |
| [SmartNotificationScheduler.swift](AiQo/Core/SmartNotificationScheduler.swift) | 146 | ✗ | ✓ |
| [SmartNotificationScheduler.swift](AiQo/Core/SmartNotificationScheduler.swift) | 185 | ✗ | ✓ |
| [SmartNotificationScheduler.swift](AiQo/Core/SmartNotificationScheduler.swift) | 396 | ✗ | ✓ |
| [SmartNotificationScheduler.swift](AiQo/Core/SmartNotificationScheduler.swift) | 498 | ✗ | ✓ |
| [SmartNotificationScheduler.swift](AiQo/Core/SmartNotificationScheduler.swift) | 594 | ✗ | ✓ |
| [SmartNotificationScheduler.swift](AiQo/Core/SmartNotificationScheduler.swift) | 767 | ✗ | ✓ |
| [SleepSessionObserver.swift](AiQo/Features/Sleep/SleepSessionObserver.swift) | 89 | ✗ | ✓ (OR-bypass form) |
| [SleepSessionObserver.swift](AiQo/Features/Sleep/SleepSessionObserver.swift) | 180 | ✗ | ✓ |

---

## 4. Primary fix — root cause

The user's chat flow broke because [BrainOrchestrator.processMessage](AiQo/Features/Captain/BrainOrchestrator.swift:37) rejects cloud routes before any downstream work. Its `if` clause checked `canAccess(.captainChat)` unconditionally and short-circuited into `makeTierRequiredReply`, which generates the literal "هاي الميزة تحتاج AiQo Max" string. The `CaptainViewModel` wrapper added in P2.3 was bypassed correctly — but `BrainOrchestrator` is a *second* gate one layer deeper that still executed.

**Primary fix diff:**

```swift
// Before (BrainOrchestrator.swift:42-48)
if route(for: routedRequest) == .cloud,
   !TierGate.shared.canAccess(.captainChat) {
    return makeTierRequiredReply(...)
}

// After
if !DevOverride.unlockAllFeatures,
   route(for: routedRequest) == .cloud,
   !TierGate.shared.canAccess(.captainChat) {
    diag.info("BrainOrchestrator.processMessage blocked by TierGate(.captainChat)")
    return makeTierRequiredReply(...)
}
```

The same pattern was applied to every other gate site. Secondary culprit [CloudBrainService.swift:44](AiQo/Features/Captain/CloudBrainService.swift:44) (which throws `BrainError.tierRequired` that surfaces as the mirror string in `CaptainViewModel`) was also wrapped.

---

## 5. DevOverride diagnostic logging

Added a 4-line launch print to [DevOverride.warnIfActive()](AiQo/Features/Captain/Brain/00_Foundation/DevOverride.swift:25). Expected output with override ON + Debug build:

```
---- DevOverride diagnostic ----
  Info.plist AIQO_DEV_UNLOCK_ALL = true
  Compiled #if DEBUG              = true
  unlockAllFeatures (effective)   = true
--------------------------------
⚠️⚠️⚠️ DEV_OVERRIDE ACTIVE — All paid features unlocked. DO NOT SHIP. ⚠️⚠️⚠️
```

Any deviation isolates the root cause:
- `Info.plist = false` → plist key not set correctly.
- `Compiled #if DEBUG = false` → scheme is Release (flip in Xcode scheme editor).
- `unlockAllFeatures = false` but plist = true, DEBUG = true → compile-time unreachable (won't happen).

---

## 6. Verification — to be done by user on device

- [ ] Clean build folder (⇧⌘K).
- [ ] Rebuild and run on physical iPhone from a **Debug** scheme.
- [ ] Capture Xcode console diagnostic block above.
- [ ] Send "مرحبا" in Captain chat — expect a normal reply (no "AiQo Max" message).
- [ ] Send 3–4 follow-up messages — all route to Gemini successfully.
- [ ] Open chat history — shows messages, no locked state.
- [ ] Memory browser — populated or empty, not locked.

If any step fails, collect:
- Screenshot of chat
- Xcode console log at launch (the 4-line diagnostic block)
- Output of `grep -rn "canAccess(.captainChat)" AiQo/ --include="*.swift" -B 2` (verify no unwrapped sites remain)

---

## 7. Hard-rule compliance

- ✓ `#if DEBUG` guard preserved in `DevOverride.unlockAllFeatures` (line 16) — unchanged.
- ✓ `AIQO_DEV_UNLOCK_ALL` semantics preserved (true/YES = unlock).
- ✓ No second override flag introduced.
- ✓ Every `canAccess(.captainChat)` and `canAccess(.captainNotifications)` site wrapped (36/36).
- ✓ Every wrap logs with `diag.info(...)` for audit trail.
- ✓ Xcode scheme NOT modified programmatically (user must flip if Release).
- ✓ Paywall code not touched.
- ✓ `.captainMemory`, `.multiWeekPlan`, `.premiumVoice` etc. gates untouched (not in chat flow).

---

## 8. Out-of-scope files in diff

The following files appeared in `git diff` but were NOT modified by this fix — they were modified by the user or a linter running in parallel (CloudBrainService.swift modification flagged by system notification confirms this pattern):

- `AiQo/Core/Purchases/SubscriptionTier.swift`
- `AiQo/Premium/AccessManager.swift`
- `AiQo/Premium/EntitlementProvider.swift`
- `AiQo/UI/Purchases/PaywallView.swift`
- `AiQoTests/PurchasesTests.swift`
- `AiQo/Features/Captain/CloudBrainService.swift` (lines outside the guard that this fix added — e.g., `effectiveAccessTier` rename)

These are pre-existing in-flight changes; they should be committed separately if intentional, or reverted if not.

---

## Rollback

```bash
git reset --hard 869408a
git branch -D brain-refactor/p-fix-dev-override
```
