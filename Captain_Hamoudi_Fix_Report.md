# Captain Hamoudi — Fix Report

**Generated:** 2026-04-26
**Branch:** `brain-refactor/p-fix-dev-override`
**Build:** `xcodebuild -scheme AiQo -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**
**Source-of-truth:** [Captain_Hamoudi_Diagnostic_Report.md](Captain_Hamoudi_Diagnostic_Report.md)

Targets the two confirmed bugs:
- **BUG A** — replies truncated mid-Arabic-word (`maxOutputTokens=600` + `finishReason` never decoded).
- **BUG B** — Captain forgets in-session conversation (`PrivacySanitizer` capped history to 4 messages).

---

## 1. Files Changed

| File | Lines | What changed |
|---|---|---|
| [AiQo/Services/Analytics/AnalyticsEvent.swift](AiQo/Services/Analytics/AnalyticsEvent.swift) | 56-58 added | New `captainResponseTruncated(screen:)` analytics factory. |
| [AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift) | 65-77, 166-216, 248-272, 305-385, 412-434 | Reply struct gains `truncatedAtMaxTokens`. `GeminiResponse` decodes `finishReason`, `safetyRatings`, `usageMetadata`. `requestCloudResponse` returns a `CloudCallResult` and emits the new logs. `maxOutputTokens` raised. |
| [AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift) | 285-296, 387-398, 412-423, 437-448, 460-471, 484-495, 557-568, 607-618 | All 8 reply constructors pass an explicit `truncatedAtMaxTokens:` (no default). Local route hardcodes `false` because `LocalBrainServiceReply` does not surface this signal. |
| [AiQo/Features/Captain/LocalIntelligenceService.swift](AiQo/Features/Captain/LocalIntelligenceService.swift) | 38-49 | Local-Foundation reply hardcodes `truncatedAtMaxTokens: false`. |
| [AiQo/Features/Captain/CaptainViewModel.swift](AiQo/Features/Captain/CaptainViewModel.swift) | 517-541, 868-885, 626-628 | UI marks truncated bubbles, fires the new analytics event, raises `maxConversationWindow` to 24, adds `markIfTruncated(...)` static helper. |
| [AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift) | 53-79, 391-453, 695-702 | Conversation cap raised to 16 + 6000-char budget; rewritten `sanitizeConversation` walks newest-first; new `conversationLogger`; doc-comment updated to describe the new policy. |
| [AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift) | 274-313 | `buildCloudSafeRelevantContext` allowed-categories now includes `workout_history` so the cloud Captain can read the rolling 7-workout summary built by `WorkoutHistoryStore`. Closes the user-reported gap where the Captain had to admit "الوقت بالدقيقة ما طالع عندي هسة" when asked to analyze the last workout. |
| [AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift) | 234-281 | `makeSynthesisRequest` now logs the exact failure mode when the proxy gate rejects the request — distinguishes "endpoint missing" (Supabase URL empty), "jwt missing" (user not signed in), and "anon key missing" instead of all collapsing into a silent `configurationMissing`. Also logs the destination URL on every successful proxy hit so you can see in Console that the request is reaching `https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/captain-voice`. |
| [AiQoTests/PrivacySanitizerTests.swift](AiQoTests/PrivacySanitizerTests.swift) | 228-294 added | `testSanitizeConversation_keepsLast16OrCharBudget` covers count cap, char budget, chronological order, and per-message PII redaction. |
| [AiQoTests/HybridBrainResponseDecodingTests.swift](AiQoTests/HybridBrainResponseDecodingTests.swift) | new file | `testFinishReasonDecodes`, `testFinishReasonStop_doesNotMarkTruncated`, `testMissingFinishReason_decodesAsNil`. |

`AiQo.xcodeproj/project.pbxproj` was not edited — the test target uses `PBXFileSystemSynchronizedRootGroup`, so the new test file is auto-discovered.

---

## 2. Before / After Constants

### `maxOutputTokens` (Gemini generation cap)
[HybridBrain.swift:413-426](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:413)

| screenContext | Before | After |
|---|---|---|
| `.mainChat` | 600 | **1400** |
| `.myVibe` | 600 | **1400** |
| `.sleepAnalysis` | 600 | **1200** |
| `.gym` | 900 | **1400** |
| `.kitchen` | 900 | **1400** |
| `.peaks` | 900 | **1400** |

Comment captures the rationale (Arabic ≈ 1.5–2× English BPE; 1400 ≈ 700–900 Arabic words).

### `PrivacySanitizer` conversation cap
[PrivacySanitizer.swift:71-75](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:71)

| Constant | Before | After |
|---|---|---|
| `maxConversationMessages` | 4 | **16** |
| `maxConversationCharBudget` | — | **6000** (new) |

Trim is now two-stage: count cap → newest-first char budget, with a "always keep at least 2 messages" floor.

### Cloud-safe memory categories (`MemoryStore.buildCloudSafeRelevantContext`)
[MemoryStore.swift:279-291](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:279)

| Category | Before | After |
|---|---|---|
| `workout_history` | filtered out | **allowed** |

Other categories (`goal`, `preference`, `mood`, `injury`, `nutrition`, `insight`) unchanged. The intent-weight map already gives `workout_history` a 2.8 weight on `.workout` intent and 2.6 on `.challenge` intent ([CognitivePipeline.swift:65, :87](AiQo/Features/Captain/Brain/03_Reasoning/CognitivePipeline.swift:65)), so retrieval ranking surfaces the recent-workouts memory as soon as the user mentions تمرين / workout.

### `CaptainViewModel.maxConversationWindow`
[CaptainViewModel.swift:625-628](AiQo/Features/Captain/CaptainViewModel.swift:625)

| Before | After |
|---|---|
| 20 | **24** (sized to comfortably exceed sanitizer's 16-msg cap) |

`maxInMemoryMessages = 80` ([CaptainViewModel.swift:125](AiQo/Features/Captain/CaptainViewModel.swift:125)) is unchanged.

### `HybridBrainServiceReply` shape
[HybridBrain.swift:65-77](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:65)

New required field `let truncatedAtMaxTokens: Bool`. All 10 construction sites updated explicitly — no default values that would hide intent.

---

## 3. New Logging / Analytics Keys

### Logs (existing `Logger` style — `os.log`-backed)
| Key | Source | Trigger |
|---|---|---|
| `gemini_finish reason=… inputTokens=… outputTokens=… totalTokens=…` | [HybridBrain.swift:343](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:343) | Every successful Gemini call (`.notice`). |
| `gemini_max_tokens_hit screen=… outputTokens=…` | [HybridBrain.swift:347](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:347) | When `finishReason == "MAX_TOKENS"` (`.error`). |
| `sanitizer_history_trimmed kept=… ofTotal=… charBudgetUsed=…` | [PrivacySanitizer.swift:417](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:417) | When the conversation gets trimmed by the sanitizer (count or char budget). New subsystem category `PrivacySanitizer`. |
| `voice_router_speak tier=… provider=… chars=…` | [CaptainVoiceRouter.swift:107](AiQo/Features/Captain/Voice/CaptainVoiceRouter.swift:107) | Every speaker tap. Shows the resolved provider before any work. |
| `voice_router_resolve picked=appleTTS reason=feature_flag_off …` | [CaptainVoiceRouter.swift:154](AiQo/Features/Captain/Voice/CaptainVoiceRouter.swift:154) | `CAPTAIN_VOICE_CLOUD_ENABLED` is NO. |
| `voice_router_resolve picked=appleTTS reason=minimax_provider_nil` | [CaptainVoiceRouter.swift:158](AiQo/Features/Captain/Voice/CaptainVoiceRouter.swift:158) | The MiniMax provider failed to instantiate (rare). |
| `voice_router_fallback to=appleTTS reason=expected_skip from=miniMax` | [CaptainVoiceRouter.swift:118](AiQo/Features/Captain/Voice/CaptainVoiceRouter.swift:118) | MiniMax threw consent / config / too-long; router silently fell back. |
| `minimax_speak_skipped reason=consent_missing …` | [MiniMaxTTSProvider.swift:65](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift:65) | User has not granted cloud voice consent yet. Open Settings → صوت الكابتن. |
| `minimax_speak_skipped reason=config_missing apiKey=… modelID=… voiceID=… …` | [MiniMaxTTSProvider.swift:75](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift:75) | One of the three voice config values is missing. The booleans tell you which. |
| `minimax_speak_resolved consent=granted model=… voice=… chars=…` | [MiniMaxTTSProvider.swift:80](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift:80) | Consent + config OK; about to build the request. |
| `voice_proxy_request endpoint=… bytes=…` | [MiniMaxTTSProvider.swift:281](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift:281) | Every successful proxy-routed TTS call. Confirms voice is hitting `…/functions/v1/captain-voice`. |
| `voice_proxy_endpoint_missing — check SUPABASE_URL in Secrets.xcconfig` | [MiniMaxTTSProvider.swift:266](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift:266) | `K.Supabase.url` is empty / placeholder. |
| `voice_proxy_jwt_missing — user has no Supabase session (sign in with Apple required)` | [MiniMaxTTSProvider.swift:270](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift:270) | User skipped or lost Apple sign-in. |
| `voice_proxy_anon_key_missing — request will rely on JWT alone` | [MiniMaxTTSProvider.swift:276](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift:276) | `SUPABASE_ANON_KEY` empty — the function still authenticates by JWT, but Supabase's gateway prefers the dual header. |
| `voice_direct_request — USE_CLOUD_PROXY is OFF, hitting MiniMax with client-embedded key` | [MiniMaxTTSProvider.swift:294](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift:294) | The build was made with `USE_CLOUD_PROXY = NO`. Re-build after flipping the flag. |

All keys are ASCII, snake_case, consistent with surrounding `gemini_*` log lines.

### Analytics events
| Event name | Properties | Source |
|---|---|---|
| `captain_response_truncated` | `screen` (e.g. `"mainChat"`) | [AnalyticsEvent.swift:56-58](AiQo/Services/Analytics/AnalyticsEvent.swift:56), fired in [CaptainViewModel.swift:539-541](AiQo/Features/Captain/CaptainViewModel.swift:539) |

Pairs with `captain_response_received` for capacity tuning.

---

## 4. UI Behavior on Truncation

[CaptainViewModel.swift:517-541, :868-885](AiQo/Features/Captain/CaptainViewModel.swift:517)

When `reply.truncatedAtMaxTokens == true`:
- The bubble's display text is appended with a single `…` *only if* the existing tail is not already terminal punctuation (`.`, `؟`, `!`, `…`, `."`).
- The persisted message and the `ConversationThreadManager` log get the same marked text — the sanitizer's next-turn input already reflects the truncation, which lets Gemini "know" the previous turn ended abruptly.
- `AnalyticsService.shared.track(.captainResponseTruncated(screen: screenContext.rawValue))` fires after the latency event.

No auto-retry, no user-facing prompt — per the fix-prompt's deferred-UX directive.

---

## 5. Compile Errors Encountered & Resolution

### Round 1 — first build
```
BrainOrchestrator.swift:292:41: error: value of type 'LocalBrainServiceReply'
                                       has no member 'truncatedAtMaxTokens'
```

**Cause:** `BrainOrchestrator.generateLocalReply(...)` calls `localService.generateReply(...)` which returns `LocalBrainServiceReply`, *not* `HybridBrainServiceReply`. I had assumed the same struct on both sides and tried to pass through `reply.truncatedAtMaxTokens` from a struct that does not have that field.

**Fix:** Local Apple-Foundation generation does not surface a MAX_TOKENS signal at this layer. Hardcoded `truncatedAtMaxTokens: false` at [BrainOrchestrator.swift:295](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:295) with a comment explaining why. Build went green on the second invocation.

No other errors. The SourceKit diagnostics that appear in the editor (e.g. `Cannot find type 'ScreenContext' in scope`) are pre-existing cross-file index noise — they predate this change and do not affect the actual build.

---

## 6. New TODOs Introduced

None. The fix-prompt deferred two future improvements; both are already documented as comments next to the relevant code:
- **Auto-retry / continue UX on `MAX_TOKENS`** — comment at [CaptainViewModel.swift:872-873](AiQo/Features/Captain/CaptainViewModel.swift:872) ("The retry/continue UX is intentionally deferred — see fix prompt.").
- **Per-screen `maxOutputTokens` retuning if logs still show hits** — comment at [HybridBrain.swift:413-417](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:413).

No `TODO:` markers added to source.

---

## 7. Verification Checklist (for device test)

When the new build is installed and Mohammed re-runs the failing chat:
- [ ] `gemini_finish reason=STOP …` shows up in Console for healthy replies.
- [ ] If `gemini_max_tokens_hit screen=mainChat` ever appears, the bubble ends with `…` and an analytics event `captain_response_truncated` is dispatched.
- [ ] After 5+ chat turns, `sanitizer_history_trimmed kept=N ofTotal=M` shows `N` ≥ 4 (not the old hard 4-cap).
- [ ] Captain references context from earlier turns in the same session (e.g. when the user mentions a goal, then 6 messages later asks for a workout, Captain ties them together).
- [ ] When the user asks "حلل تمريني الاخير" on mainChat, the reply cites the actual workout (title, minutes, calories, HR, km) from `WorkoutHistoryStore` — not today's HealthKit step total. Verify by completing a walk/run, waiting for the entry to appear in Captain Memory → "تاريخ التمارين", then asking for an analysis.
- [ ] **Voice routes through the Supabase proxy.** Tap the speaker icon on a Captain bubble. In Console, look for `voice_proxy_request endpoint=https://zidbsrepqpbucqzxnwgk.supabase.co/functions/v1/captain-voice bytes=…`. If you see `voice_direct_request` instead, the build was compiled with `USE_CLOUD_PROXY=NO` — re-build after confirming `Secrets.xcconfig` has `USE_CLOUD_PROXY = YES`. If you see `voice_proxy_jwt_missing`, the user has not completed Sign in with Apple — the Edge Function rejects requests without a valid Supabase user JWT.
- [ ] Apple Review compliance unchanged — safety banner still visible, no medical-disclaimer regression, no hardcoded keys, `validateResponse` punctuation logic untouched.

Build green. Captain_Hamoudi_Fix_Report.md written. Ready for device test.
