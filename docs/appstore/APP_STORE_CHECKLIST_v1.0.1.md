# App Store Submission Checklist — v1.0.1

**Date:** 2026-04-19
**Build:** Local `xcodebuild` Release build succeeded; archive build number still pending
**Submission type:** Update after initial v1.0 approval
**Status:** Not ready for submission yet. Open items below must be closed first.

## Privacy & Safety

- [x] `grep -rn "generateArabicAPIReply\|CAPTAIN_ARABIC_API_URL\|CoachBrainLLMTranslator" AiQo/ --include="*.swift"` returns zero matches
- [x] `grep -n "ARABIC_API\|COACH_BRAIN_LLM_API_URL" AiQo/Info.plist` returns zero matches
- [x] `PrivacySanitizer` is invoked before Gemini transport in `CloudBrainService.generateReply`
- [ ] `AuditLogger` records every `.notificationDelivered` + `.cloudCallMade` event
  Current state: notification deliveries are logged and cloud-call metadata is persisted, but there is no `.cloudCallMade` event symbol to verify by name.
- [ ] AI cloud consent approval verified before every cloud path
  Current state: Captain chat consent gate is verified, but a whole-app audit for every network path is still incomplete.
- [x] `NSHealthShareUsageDescription` is truthful
- [x] `NSUserTrackingUsageDescription` is not present in `Info.plist`
- [ ] Privacy Policy URL accessible from Settings
  Current state: Settings opens an in-app legal sheet, not a URL.
- [ ] Support URL accessible from Settings
  Current state: support entry point is a profile mail composer, not a Settings URL.

## Safety

- [x] `CrisisDetector` is active in the `BrainOrchestrator` turn loop
- [x] `SafetyNet` records every evaluated crisis signal
- [x] `ProfessionalReferral` resources were checked against live official pages/directories on 2026-04-19
- [ ] No medical advice claims anywhere in UI copy
  Current state: onboarding disclaimer exists, but a full copy audit is still pending.
- [x] Health disclaimer is visible in onboarding and gated by `didAcknowledgeMedicalDisclaimer`

## Tier / Purchases

- [ ] `AIQO_DEV_UNLOCK_ALL = false` in Release `Info.plist`
  Current state: repository `Info.plist` still has `<true/>`; keep that for dev and switch only in archive/release submission config.
- [ ] Free tier can use the app without crashes
- [ ] Trial flow tested end-to-end
- [ ] Tier limits verified in production-style manual QA
- [ ] Subscription receipt validation works end-to-end
- [ ] Restore purchases works end-to-end

## Notifications

- [x] All notification categories are registered at app launch
- [x] `GlobalBudget` caps at 7/day for Pro or Trial, 4/day for Max, 2/day for Free
- [ ] Quiet hours verified against the user's sleep schedule
  Current state: quiet hours logic exists, but sleep-schedule linkage/manual QA still needs confirmation.
- [x] `BGTaskSchedulerPermittedIdentifiers` includes `aiqo.brain.nightly`
- [ ] No duplicate notifications during legacy-to-`NotificationBrain` transition

## Features

- [ ] Captain chat RTL rendering manually verified
- [ ] Memory screen localization fixed
  Current state: `CaptainMemorySettingsView` still references missing keys like `memory.enable` and `memory.enableSubtitle`.
- [ ] Kitchen / Meal Plan flow manually verified
- [ ] Workout completion flow manually verified
- [ ] Settings / Profile edit flow manually verified

## Build Quality

- [ ] Zero warnings in Release build
  Current state: local Release build succeeded with 62 warnings in `/tmp/aiqo_batch8_release_build.log`.
- [ ] Zero runtime console errors on first launch
- [ ] Zero runtime errors on Captain Chat tab open
- [ ] App launches in under 2 seconds on iPhone 13+

## App Store Metadata

- [ ] Screenshots updated
- [ ] Description updated
- [ ] "What's New" for v1.0.1 entered in App Store Connect
- [ ] Subscription terms URL accessible
- [ ] Age rating confirmed as 12+

## Family Controls

- [x] No Family Controls entitlement/code was found in the repository audit

## Reviewer Notes Draft

Use this only after the unchecked items above are closed:

```text
AiQo is an Arabic-first wellness companion featuring Captain Hamoudi,
an AI coach with persistent on-device memory. Personal memory is stored
on-device. The app uses Google's Gemini Flash family for cloud coaching
responses, with outbound requests sanitized before transport and gated
behind explicit user consent. Health data is summarized before any cloud
use and is not sent in raw form. Users can view and delete Captain memory
from Settings.

v1.0.1 adds proactive notification intelligence, cultural context
(including Ramadan/Jumu'ah/Eid handling), memory callbacks from past
conversations, and a new crisis-safety path that can surface
region-appropriate professional support resources.
```
