# Captain Chat v1.1 — App Store Resubmission Changelog

**Rejection:** App Store Submission `49728905-f7c6-4b0e-829f-f7b0e2628751`
**Guidelines addressed:** 1.4.1 (Physical Harm) · 2.1.0 (App Completeness) · 4.0.0 (Design)
**Target device verified:** iPhone 17 Pro Max · iOS 26.4 (simulator build succeeded)
**Kill switch:** `Info.plist → AIQO_CHAT_V1_1_ENABLED` (default `true`). Flip to `false` and the fixed header + persistent safety banner retract; the chat returns to the v1.0 scroll-embedded header with `HealthComplianceCard`. Prompt / sanitizer / feature-flag bug fixes stay on under either setting because they are fixes, not styling.

---

## Files changed

### New files
- [AiQo/Features/Compliance/MedicalDisclaimerDetailView.swift](AiQo/Features/Compliance/MedicalDisclaimerDetailView.swift) · 127 lines — full medical disclaimer screen (bilingual), two modes (`.firstRun` / `.settings`). Named `...DetailView` to avoid collision with the existing `MedicalDisclaimerView` banner in `AiQo/Shared/`.
- [AiQo/Features/Captain/CaptainSafetyBanner.swift](AiQo/Features/Captain/CaptainSafetyBanner.swift) · 53 lines — thin persistent banner shown above the chat scroll. Tapping opens the disclaimer detail as a `.large` sheet.

### Modified files
- [AiQo/App/SceneDelegate.swift](AiQo/App/SceneDelegate.swift) · +16 lines — adds `@AppStorage("aiqo.medicalDisclaimer.acknowledgedV1")` to `AppRootView`, a `.fullScreenCover` that gates `.main` on acknowledgement (covers legacy v1.0 users upgrading), and mirrors the ack into the new key when onboarding's `finalizeMedicalDisclaimer` runs.
- [AiQo/Core/AppSettingsScreen.swift](AiQo/Core/AppSettingsScreen.swift) · +21 lines — new `NavigationLink` row "الإخلاء الطبي" with SF Symbol `heart.text.square` (mint tint) at the top of the Privacy & AI Data section.
- [AiQo/Core/CaptainVoiceService.swift](AiQo/Core/CaptainVoiceService.swift) · +21 lines — adds `@Published isTTSAvailable` + `@Published displayedToast`; on synthesis failure the service flips the flag, emits the Arabic toast "الصوت غير متاح حالياً" for 2.5s, and the chat dims the speaker icon.
- [AiQo/Core/Config/AiQoFeatureFlags.swift](AiQo/Core/Config/AiQoFeatureFlags.swift) · +10 lines — declares `FeatureFlags.captainChatV1_1Enabled` (Info.plist key `AIQO_CHAT_V1_1_ENABLED`, default `true`).
- [AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift) · +88 lines net — prepends two new layers (`layerReplyLanguageLock`, `layerSafetyRules`); rewrites `layerMedicalDisclaimer` so the LLM no longer appends "⚕️ This is educational info — consult your doctor" / "هذي معلومات تثقيفية — استشر طبيبك" to message bodies.
- [AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift) · −21 / +14 lines — `injectUserName` now only replaces explicit placeholder tokens (`[USER_NAME]`, `{{userName}}`, `{{user_name}}`, `{USER_NAME}`, `%USER_NAME%`). The prepend-if-missing path that produced "John, Got it. 60kg…" in Apple's screenshot is deleted.
- [AiQo/Features/Captain/CaptainChatView.swift](AiQo/Features/Captain/CaptainChatView.swift) · replaced — fixed header above scroll, persistent `CaptainSafetyBanner` below the header, `LazyVStack(spacing: 0)` with role-aware per-row bottom padding (6pt same-role, 18pt role transition), stable `id: \.element.id` on the ForEach, speaker-icon dimming driven by `CaptainVoiceService.isTTSAvailable`, avatar moved to the trailing side, subtitle "متصل الآن" / "يفكر الحين". All changes gated by `FeatureFlags.captainChatV1_1Enabled` — legacy path preserved via `legacyHeaderCard` + `HealthComplianceCard`.
- [AiQo/Features/Captain/CaptainViewModel.swift](AiQo/Features/Captain/CaptainViewModel.swift) · +24 lines — `cleanAssistantReplyMessage` now runs through `stripInlineMedicalDisclaimerTail`, a regex pass that removes any lingering "⚕️ …" / "This is educational info" / "استشر طبيب…" / "هذي معلومات تثقيفية…" trailers from cached prompts or stale replies.
- [AiQo/Features/Captain/MessageBubble.swift](AiQo/Features/Captain/MessageBubble.swift) · ±29 lines — bubble tokens switched to the v1.1 palette: user mint `#B7E5D2`, assistant sand `#EBCF97 @ 35% alpha`, text ink `#0F1721`. Corner radii retuned to 18/6. Removed the redundant drop-shadow that made adjacent same-role bubbles look merged in Apple's screenshot.
- [AiQo/Info.plist](AiQo/Info.plist) · +2 lines — registers `AIQO_CHAT_V1_1_ENABLED = true`.

---

## Fix matrix — which change addresses which guideline

### Guideline 1.4.1 — Physical Harm

| Before | After | Where |
|---|---|---|
| Disclaimer was only a light inline strip (`HealthComplianceCard`) inside the scroll; users could scroll past it. | Persistent top-of-chat safety banner `CaptainSafetyBanner`; full disclaimer accessible from the banner, from settings, and as a first-run `.fullScreenCover` for legacy v1.0 users upgrading. | [CaptainSafetyBanner.swift](AiQo/Features/Captain/CaptainSafetyBanner.swift), [MedicalDisclaimerDetailView.swift](AiQo/Features/Compliance/MedicalDisclaimerDetailView.swift), [SceneDelegate.swift](AiQo/App/SceneDelegate.swift) |
| Hamoudi's cloud prompt had a long medical-advice layer that told him to append a doctor disclaimer AND cite sources, producing "specific numbers + doctor tail" in the same bubble — what Apple's screenshot flagged. | Added a non-negotiable `SAFETY RULES` layer: no diagnosis, no prescription, redirect specific weight-loss / calorie questions to "This needs a qualified physician". Medical-disclaimer layer reduced to "cite WHO/ACSM for numbers, never write a disclaimer tail — the UI banner handles it". | [PromptComposer.swift](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift) layers `layerSafetyRules`, `layerMedicalDisclaimer` |
| Old cached replies or remote configs could still slip a "⚕️ استشر طبيبك" trailer into a bubble. | Client-side regex backstop strips the trailer before render. | [CaptainViewModel.swift](AiQo/Features/Captain/CaptainViewModel.swift) `stripInlineMedicalDisclaimerTail` |

### Guideline 2.1.0 — App Completeness

| Before | After | Where |
|---|---|---|
| Hamoudi's first reply could silently fail (TTS throws, prompt malformed) with no user-visible signal — the icon kept looking tappable. | `CaptainVoiceService` publishes `isTTSAvailable` and a 2.5s toast "الصوت غير متاح حالياً"; chat dims the speaker icon when TTS is unavailable. Existing `HybridBrainServiceError` / `AiQoError` fallbacks remain for the text path, now surfaced through the same clean pipeline. | [CaptainVoiceService.swift](AiQo/Core/CaptainVoiceService.swift), [CaptainChatView.swift](AiQo/Features/Captain/CaptainChatView.swift) toast overlay |
| Message list used `LazyVStack(spacing: 14)` with the chat header + compliance card inline — on slow networks the header jittered during scroll and two consecutive assistant messages could render as one visual bubble (what Apple screenshot showed). | Fixed header above the scroll; `LazyVStack(spacing: 0)` with role-aware per-row `.padding(.bottom, sameRole ? 6 : 18)`; every row keyed by `message.id`; assistant bubble redundant drop-shadow removed so same-role bubbles stay visibly separate. | [CaptainChatView.swift](AiQo/Features/Captain/CaptainChatView.swift) `messagesList`, `spacing(forIndex:)`; [MessageBubble.swift](AiQo/Features/Captain/MessageBubble.swift) |

### Guideline 4.0.0 — Design

| Before | After | Where |
|---|---|---|
| User's first name ("John") was automatically prepended to every assistant reply via `PrivacySanitizer.injectUserName` → produced "John, Got it. 60kg is a solid baseline…" in the rejection screenshot. | `injectUserName` now *only* replaces explicit tokens — never prepends. Hamoudi says the user's name only when he naturally writes one of the placeholder tokens in his own generated text. | [PrivacySanitizer.swift](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift) `injectUserName` |
| Prompt-level language drift — Hamoudi sometimes replied in English while the app UI was Arabic. | `layerReplyLanguageLock` prepended before all other prompt layers; reconciles `AppSettingsStore.shared.appLanguage` with `Locale.current.language.languageCode` and emits an absolute "Reply ONLY in …" directive. | [PromptComposer.swift](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift) `layerReplyLanguageLock` |
| Bubbles used soft pastels that clashed with the sand background at 100% alpha — Apple screenshot showed muddy contrast. | User bubbles `#B7E5D2` mint, assistant bubbles sand `#EBCF97 @ 35% alpha`, text ink `#0F1721`, corner radii 18/6 per role. All tokens now match the brief. | [MessageBubble.swift](AiQo/Features/Captain/MessageBubble.swift) `bubbleColor`, `textColor`, `bubbleCorners` |
| Header cramped — avatar, title, status chip, clock button all on the leading side in RTL. | Header rebuilt: clock + book icons leading (44×44 hit area each), title block "كابتن حمودي" + subtitle "متصل الآن" centered, avatar trailing with mint ring. | [CaptainChatView.swift](AiQo/Features/Captain/CaptainChatView.swift) `headerBar` |

---

## Compliance / accessibility posture

- Full RTL: every new view applies `.environment(\.layoutDirection, .rightToLeft)` at its root; the English disclaimer card flips back to LTR locally via a scoped `.environment` on the card, matching the design spec.
- Dynamic Type: `MedicalDisclaimerDetailView` caps at `.accessibility2`; existing chat views already inherit the app-wide cap.
- Accessibility labels: every interactive element in the new surfaces has `.accessibilityLabel` — safety banner, disclaimer acknowledge button, header clock / book / avatar, speaker icons (with dimmed vs active variants), send button.
- Non-dismissible first-run gate: `.interactiveDismissDisabled(mode == .firstRun)` on `MedicalDisclaimerDetailView` + `.fullScreenCover` driven by a read-only binding on `AppRootView` prevents gesture dismissal.

## Build verification

```
xcodebuild -project AiQo.xcodeproj -scheme AiQo \
  -destination "platform=iOS Simulator,id=CF2AF80A-EC06-422F-A7FC-D7C56B666EFD" \
  -configuration Debug build
…
** BUILD SUCCEEDED **
```

No compiler errors. SourceKit-level warnings about `AVAudioSession`/`UIKit`/`Supabase` being "unavailable in macOS" are pre-existing indexing noise from the language server evaluating iOS-only modules in a macOS context — the real iOS build succeeds.

## What was intentionally NOT changed

- Onboarding's `MedicalDisclaimerOnboardingView` (legacy v1.0 first-run gate) is preserved — `finalizeMedicalDisclaimer` now mirrors its confirmation into the new v1.1 key so users completing onboarding don't see both gates.
- `prependUserNameIfNeeded` in `CaptainViewModel` (used only for the morning-habit ephemeral insight) — that is curated content, not an LLM reply, and keeping the prepend there is intentional.
- Spotify, Tribe, Blend, Fridge Scan, Sleep, Watch modules — untouched per the brief.
- Every feature remained; nothing deleted. Only restyles and prompt refinements.
