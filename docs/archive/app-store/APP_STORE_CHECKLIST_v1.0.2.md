# App Store Submission Checklist — v1.0.2 (build 19)

**Date:** 2026-05-11
**Marketing version:** `1.0.2`
**Build number:** `19`
**Submission type:** Update after v1.0.1 (current App Store live build)
**Status:** Code-side ready; manual QA + App Store Connect metadata pending.

---

## Build identity

- [x] `MARKETING_VERSION = 1.0.2` in every target's Debug + Release configs (18 occurrences in `AiQo.xcodeproj/project.pbxproj`)
- [x] `CURRENT_PROJECT_VERSION = 19` in every target's Debug + Release configs (18 occurrences)
- [x] `IPHONEOS_DEPLOYMENT_TARGET = 26.2` (matches Xcode 26.4.1 SDK)
- [x] `SWIFT_VERSION = 5.0`
- [x] `TARGETED_DEVICE_FAMILY = "1,2"` for main app (iPhone + iPad), `1` for widget, `4` for watch
- [x] `ITSAppUsesNonExemptEncryption = NO` (export compliance, set via `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption`)
- [x] `INFOPLIST_KEY_NSSupportsLiveActivities = YES`

## Privacy manifest (PrivacyInfo.xcprivacy)

- [x] `NSPrivacyTracking = false` (no third-party tracking)
- [x] `NSPrivacyTrackingDomains` empty array (no SKAdNetwork or tracking domains)
- [x] `NSPrivacyAccessedAPITypes` declares: `UserDefaults` (CA92.1), `FileTimestamp` (0A2A.1)
- [x] `NSPrivacyCollectedDataTypes` declares: Fitness, Health, UserContent, Name, EmailAddress, UserID, PhotosOrVideos — all `Linked=true`, `Tracking=false`, `Purpose=AppFunctionality`

## Usage descriptions (INFOPLIST_KEY_NS…)

- [x] `NSCameraUsageDescription` — covers Vision Coach form analysis, learning-proof verification, Smart Fridge scanning
- [x] `NSMicrophoneUsageDescription` — Zone 2 hands-free coaching
- [x] `NSSpeechRecognitionUsageDescription` — short voice cues for Captain
- [x] `NSHealthShareUsageDescription` — read steps/sleep/hydration for daily/weekly summaries
- [x] `NSHealthUpdateUsageDescription` — write user-chosen hydration/workouts back to Health
- [x] `NSAlarmKitUsageDescription` (in `AiQo/Info.plist`) — save smart wake time as device alarm
- [x] No `NSUserTrackingUsageDescription` (no ATT — we do not track)
- [x] No `NSPhotoLibraryUsageDescription` needed (uses `PhotosPicker` from PhotosUI, out-of-process)

## Entitlements (AiQo.entitlements)

- [x] `aps-environment = production` (push notifications)
- [x] `com.apple.developer.applesignin = [Default]` (Sign in with Apple)
- [x] `com.apple.developer.healthkit = true` + `healthkit.background-delivery = true`
- [x] `com.apple.developer.siri = true` (App Intents)
- [x] `com.apple.security.application-groups = [group.com.aiqo.kernel2, group.aiqo]` (widget + watch shared data)

## Background modes (UIBackgroundModes)

- [x] `audio` — voice coaching during workouts
- [x] `remote-notification` — silent push for Captain proactivity
- [x] `fetch` — background app refresh for stats
- [x] `processing` — BGTaskScheduler nightly brain consolidation
- [x] `BGTaskSchedulerPermittedIdentifiers` lists: `aiqo.notifications.refresh`, `aiqo.notifications.inactivity-check`, `aiqo.brain.nightly`

## URL schemes (CFBundleURLTypes)

- [x] `aiqo://` (app-internal deep links)
- [x] `aiqo-spotify://` (Spotify OAuth redirect)
- [x] `LSApplicationQueriesSchemes = [spotify, spotify-action, instagram-stories, instagram]` (only declared schemes are queried)

## Secrets & cloud surface

- [x] `Configuration/Secrets.xcconfig` is gitignored (`.gitignore` line 8)
- [x] `git ls-files` confirms `Secrets.xcconfig` is NOT tracked
- [x] No API key patterns (`AIza…`, `sk-…`, `sb_…`, `eyJh…`) found by grep in tracked source
- [x] `Configuration/AiQo.xcconfig` (the tracked file) has only empty placeholder assignments
- [x] **NEW in v1.0.2:** API keys moved from URL query strings to `X-goog-api-key` header in the three direct-Gemini callers (`MemoryExtractor`, `SmartFridgeCameraViewModel`, `WeeklyReviewView`). Matches the canonical `HybridBrain` pattern.

## Captain (AI) surface

- [x] `PrivacySanitizer` is invoked before Gemini transport on the canonical chat path through `HybridBrain` / `CloudBrainService`
- [x] `AICloudConsentGate` gates cloud calls on the chat path
- [x] `AIQO_DEV_UNLOCK_ALL = false` in committed `Info.plist`
- [x] `BRAIN_DASHBOARD_ENABLED = false` (DEBUG-only inspector kept off)
- [x] `CAPTAIN_BRAIN_V2_ENABLED = true`, `MEMORY_V4_ENABLED = false` (V4 still feature-flagged)
- [ ] **Known deferred (Blueprint 18 §4.1.1):** `MemoryExtractor`, `WeeklyReviewView`, `SmartFridgeCameraViewModel` bypass `AuditLogger` on the direct-Gemini fallback path. Scoped to v1.1 as the `CaptainCloudGateway` extraction. Mitigated for v1.0.2 by the key-in-header fix (above) — keys no longer leak in URL logs.

## Safety net

- [x] `CrisisDetector` runs in `BrainOrchestrator.wellbeingDecision`
- [x] Regional support links present for UAE, Saudi Arabia, Iraq, and global fallback (verified live on 2026-04-19 per v1.0.1)

## Build quality

- [x] Debug build (`xcodebuild -scheme AiQo -destination 'platform=iOS Simulator,name=Codex iPhone 16 Pro QA' -configuration Debug build`): **BUILD SUCCEEDED**, 0 errors, 0 warnings
- [x] Release build (`-destination 'generic/platform=iOS' -configuration Release CODE_SIGNING_ALLOWED=NO`): **BUILD SUCCEEDED**, 0 errors, 0 warnings, passed `validate-for-store` shallow validation
- [ ] Archive build via Xcode (signed): verify before App Store Connect upload
- [ ] Validate via App Store Connect "Validate App" before upload

## Manual QA (required before submission)

- [ ] Captain chat: open / send / receive / Arabic RTL render / keyboard not cutting last reply
- [ ] Workout Runner: start a session, complete it, see Plan-palette colors render correctly on iPhone + iPad
- [ ] Plan: open Plan, browse templates, scroll Insights, view Weekly Stats
- [ ] Kitchen: scan a fridge image (uses new header-based auth on direct fallback)
- [ ] WeeklyReview: trigger a weekly review (uses new header-based auth on direct fallback)
- [ ] Settings: language toggle, AI cloud consent toggle, memory enable/disable
- [ ] StoreKit: free tier launches without crash, restore purchases works, trial flow works
- [ ] Notifications: receive at least one Captain proactive notification, verify GlobalBudget respects tier cap

## App Store Connect metadata

- [ ] Screenshots refreshed for v1.0.2 (Plan palette redesign is visible; new captures recommended)
- [ ] "What's New" copy — pull from `CHANGELOG.md` v1.0.2 entry
- [ ] Age rating still 12+ (no change in content; no new gambling/violence/etc.)
- [ ] Subscription tiers unchanged: Free / Max ($9.99) / Intelligence Pro ($19.99) / Trial
- [ ] Privacy Policy URL accessible from app Settings
- [ ] Support URL accessible from app Settings

## Deferred to v1.1 (documented in Blueprint 18 §4)

| Item | Blueprint section | Effort | Why deferred |
|---|---|---|---|
| Extract `CaptainCloudGateway` (route all three direct-Gemini callers through `AuditLogger`) | §4.1.1 | 1–2 days | Structural refactor; not safe to land + ship same day. Key-in-header fix landed in v1.0.2 as interim mitigation. |
| Migrate `EntitlementStore` from UserDefaults to Keychain (HMAC-signed) | §4.1.3 | 0.5 day | Touches subscription state load order at app launch; needs paywall A/B coordination. |
| Log non-success `OSStatus` from `KeychainStore` | §4.2.1 | 3 lines | Low blast radius; pair with §4.2.2 cert pinning sprint. |
| Certificate pinning for Supabase / Gemini / MiniMax | §4.2.2 | 0.5 day + rotation runbook | Requires a tracked fingerprint file and CI verifier — needs its own PR. |
| In-memory fallback for `QuestSwiftDataStore` `fatalError` site | §4.2.3 | 2–3 hours | One-line `fatalError`; AppDelegate.swift already has fallback. Schedule together. |
| Consolidate `AiQo/Tribe/` into `AiQo/Features/Tribe/` | §4.4.1 | 1 day | Tribe feature-flagged off in production; safe to defer. |
| Rename `LegacyCalculationViewController` → `OnboardingEntryViewController` | §4.4.2 | 10 min | Cosmetic; safer in a quiet PR. |

## Reviewer notes draft

```text
AiQo v1.0.2 is an update to the Arabic-first wellness companion currently
live on the App Store as v1.0.1.

What's new in v1.0.2:
• Plan world-class upgrade — the workout plan surface (Plan, Workout Runner,
  Insights, Weekly Stats, Exercise Detail, Template Library) is rebuilt on
  a unified four-color brand palette. No new permissions, no new data.
• Captain cognitive brain refactor — a 14-layer cognitive brain across the
  11 Brain subsystems. Same privacy model: PrivacySanitizer redacts PII
  and AuditLogger records every cloud call on the canonical chat path.
• Privacy hardening — API keys are now passed via the X-goog-api-key HTTP
  header instead of URL query strings, eliminating the risk of key leakage
  through HTTP logs.
• Learning Spark Stage 2 — a 5-course picker (Edraak + Coursera). On-device
  certificate verification image-only, image never leaves the device.

Health data is summarized before any cloud use and is never sent in raw form.
Personal memory is stored on-device. Users can view and delete Captain
memory from Settings.

No new App Store privacy labels, no new cloud endpoints, no new data
collected in v1.0.2.
```

---

## Pre-submission grep gates (run these before archive)

```bash
# No secrets in tracked source
git ls-files | xargs grep -lE '(AIza|sk-|sb_|eyJh)[A-Za-z0-9_-]{20,}' 2>/dev/null
# Should print nothing.

# No API key in URL query strings
grep -rn 'generateContent?key=' AiQo/ --include='*.swift'
# Should print nothing (was 3 hits in v1.0.1, now 0).

# Dev override is off
grep -A1 'AIQO_DEV_UNLOCK_ALL' AiQo/Info.plist
# Should show <false/>.

# Version is bumped
grep -c 'MARKETING_VERSION = 1.0.2' AiQo.xcodeproj/project.pbxproj
grep -c 'CURRENT_PROJECT_VERSION = 19' AiQo.xcodeproj/project.pbxproj
# Should both print 18.
```
