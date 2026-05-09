# Captain Hamoudi — Diagnostic Report

**Generated:** 2026-04-26
**Scope:** Read-only audit of the Captain Hamoudi chat pipeline — answers two reported issues:
1. Replies feel truncated mid-sentence (e.g. `"...واصل ل"`).
2. Captain does not seem to remember the full conversation within a single session.

> Every claim below cites `file:line` evidence. No source files were modified.

---

## 1. File Map

### 1.1 UI / Chat Surface
- [AiQo/Features/Captain/CaptainChatView.swift](AiQo/Features/Captain/CaptainChatView.swift) — main chat surface, struct declared at [CaptainChatView.swift:4](AiQo/Features/Captain/CaptainChatView.swift:4).
- [AiQo/Features/Captain/CaptainScreen.swift](AiQo/Features/Captain/CaptainScreen.swift) — alternative Captain screen (Avatar/chat hybrid). `ChatMessageRow` rendering and `messages: viewModel.messages` binding are here.
- [AiQo/Features/Captain/ChatHistoryView.swift](AiQo/Features/Captain/ChatHistoryView.swift) — past-sessions list, declared [ChatHistoryView.swift:6](AiQo/Features/Captain/ChatHistoryView.swift:6).
- [AiQo/Features/Captain/CaptainViewModel.swift](AiQo/Features/Captain/CaptainViewModel.swift) — `@MainActor final class CaptainViewModel` declared at [CaptainViewModel.swift:89](AiQo/Features/Captain/CaptainViewModel.swift:89).
- [AiQo/Features/Captain/MessageBubble.swift](AiQo/Features/Captain/MessageBubble.swift) — bubble shell.
- [AiQo/Features/Home/DJCaptainChatView.swift](AiQo/Features/Home/DJCaptainChatView.swift) — DJ Hamoudi (My Vibe) variant; reuses `CaptainViewModel`.

### 1.2 Brain Pipeline (Inference)
- [AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift) — routing engine (cloud vs local).
- [AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift) — privacy/audit wrapper.
- [AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift) — Gemini transport.
- [AiQo/Features/Captain/Brain/04_Inference/Services/LocalBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/LocalBrain.swift) — Apple Foundation Models on-device path.
- [AiQo/Features/Captain/Brain/04_Inference/Services/CaptainProxyConfig.swift](AiQo/Features/Captain/Brain/04_Inference/Services/CaptainProxyConfig.swift) — Supabase Edge Function proxy (gated by `USE_CLOUD_PROXY`, default OFF).
- [AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift) — 7-layer system-prompt builder.
- [AiQo/Features/Captain/Brain/04_Inference/LLMJSONParser.swift](AiQo/Features/Captain/Brain/04_Inference/LLMJSONParser.swift) — robust JSON parser with partial-recovery.
- [AiQo/Features/Captain/Brain/08_Persona/CaptainPersonaBuilder.swift](AiQo/Features/Captain/Brain/08_Persona/CaptainPersonaBuilder.swift) — banned-phrase + length rules; `sanitizeResponse` does NOT truncate.
- [AiQo/Features/Captain/Brain/03_Reasoning/CognitivePipeline.swift](AiQo/Features/Captain/Brain/03_Reasoning/CognitivePipeline.swift) — builds `profileSummary / intentSummary / workingMemorySummary`.

### 1.3 Privacy & Sanitization
- [AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift) — PII redactor. **Truncates conversation to last 4 messages before cloud (line 71, 377).**
- [AiQo/Features/Captain/Brain/05_Privacy/AuditLogger.swift](AiQo/Features/Captain/Brain/05_Privacy/AuditLogger.swift) — append-only Gemini audit log.

### 1.4 Memory & Persistence
- [AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift) — SwiftData store for `CaptainMemory` (V3) / `SemanticFact` + `EpisodicEntry` (V4).
- [AiQo/Features/Captain/Brain/02_Memory/Models/CaptainMemory.swift](AiQo/Features/Captain/Brain/02_Memory/Models/CaptainMemory.swift) — `@Model` at [CaptainMemory.swift:6](AiQo/Features/Captain/Brain/02_Memory/Models/CaptainMemory.swift:6).
- [AiQo/Features/Captain/Brain/02_Memory/ConversationThread.swift](AiQo/Features/Captain/Brain/02_Memory/ConversationThread.swift) — telemetry log of user/captain exchanges (NOT the cloud-call history).
- [AiQo/Features/Captain/Brain/02_Memory/Models/CaptainSchemaV1.swift / V2.swift / V3.swift / CaptainSchemaMigrationPlan.swift](AiQo/Features/Captain/Brain/02_Memory/Models/) — schema evolution.
- [AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift) — async fact extractor invoked AFTER each reply.
- [AiQo/Features/Captain/Brain/02_Memory/Stores/WorkoutHistoryStore.swift](AiQo/Features/Captain/Brain/02_Memory/Stores/WorkoutHistoryStore.swift) — workout summary memory feeder.

### 1.5 Voice / TTS
- [AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift) — cloud TTS provider.
- [AiQo/Features/Captain/Voice/AppleTTSProvider.swift](AiQo/Features/Captain/Voice/AppleTTSProvider.swift) — on-device fallback.
- [AiQo/Features/Captain/Voice/CaptainVoiceRouter.swift](AiQo/Features/Captain/Voice/CaptainVoiceRouter.swift) — selects provider per-utterance.
- [AiQo/Core/CaptainVoiceService.swift](AiQo/Core/CaptainVoiceService.swift) — UI-facing TTS coordinator.

### 1.6 Configuration / Flags
- [AiQo/Core/Config/AiQoFeatureFlags.swift](AiQo/Core/Config/AiQoFeatureFlags.swift) — `MEMORY_V4_ENABLED`, `USE_CLOUD_PROXY` (default OFF, [AiQoFeatureFlags.swift:214](AiQo/Core/Config/AiQoFeatureFlags.swift:214)), `CAPTAIN_VOICE_CLOUD_ENABLED`.

---

## 2. Send-Message Call Chain

User taps Send in `ChatComposerBar` ([CaptainChatView.swift:83](AiQo/Features/Captain/CaptainChatView.swift:83)). Trace, every hop:

1. **Composer callback → ViewModel**
   `globalBrain.sendMessage(text, context: .mainChat)` at [CaptainChatView.swift:84](AiQo/Features/Captain/CaptainChatView.swift:84) → routes into `sendMessage(text:image:context:)` at [CaptainViewModel.swift:225](AiQo/Features/Captain/CaptainViewModel.swift:225).

2. **Pre-flight checks** ([CaptainViewModel.swift:231-250](AiQo/Features/Captain/CaptainViewModel.swift:231))
   - Trim & empty guard.
   - Tier gate (`TierGate.canAccess(.captainChat)`) unless emergency-bypass or `DevOverride.unlockAllFeatures`.
   - AI consent gate (`AIDataConsentManager.shared.ensureConsent`) unless sleep analysis or crisis.

3. **Append user bubble + persist** ([CaptainViewModel.swift:264-268](AiQo/Features/Captain/CaptainViewModel.swift:264))
   - `messages.append(userMessage)`
   - `persistChatMessage(userMessage)` → `MemoryStore.shared.persistMessageAsync(...)` ([MemoryStore.swift:556](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:556)).
   - `isLoading = true`, `coachState = .readingMessage`.

4. **Spawn `responseTask`** ([CaptainViewModel.swift:279-306](AiQo/Features/Captain/CaptainViewModel.swift:279))
   - `await Task.yield()` so the UI renders the typing indicator.
   - `ConversationThreadManager.shared.logUserMessage(content:)` (telemetry only).
   - `buildConversationHistory()` → `messages.suffix(maxConversationWindow=20)` mapped to `[CaptainConversationMessage]` at [CaptainViewModel.swift:622-632](AiQo/Features/Captain/CaptainViewModel.swift:622). **Cap is 20 in-VM messages.**
   - `cognitivePipeline.buildPromptContext(...)` ([CognitivePipeline.swift:283](AiQo/Features/Captain/Brain/03_Reasoning/CognitivePipeline.swift:283)) → returns `CaptainPromptContext { profileSummary, intentSummary, workingMemorySummary }`.
     - `workingMemorySummary` = `MemoryStore.retrieveRelevantMemories(...)` ranked by intent + tokens + recency ([MemoryStore.swift:226](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:226)).

5. **`processMessage(...)`** ([CaptainViewModel.swift:429](AiQo/Features/Captain/CaptainViewModel.swift:429))
   - `contextBuilder.buildContextData()` (HealthKit-cached snapshot).
   - Optionally adds `messageSentiment` (Brain V2).
   - Builds `HybridBrainRequest` ([CaptainViewModel.swift:459-468](AiQo/Features/Captain/CaptainViewModel.swift:459)).
   - `withGlobalTimeout(seconds: 15 or 25)` wraps `orchestrator.processMessage(...)` ([CaptainViewModel.swift:480-485](AiQo/Features/Captain/CaptainViewModel.swift:480)). Sleep keywords get the 25s budget ([CaptainViewModel.swift:937](AiQo/Features/Captain/CaptainViewModel.swift:937)).

6. **`BrainOrchestrator.processMessage(...)`** ([BrainOrchestrator.swift:37](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:37))
   - Crisis evaluation via `CrisisDetector.shared.evaluate(message:)`.
   - Sleep-intent interception → may force `screenContext = .sleepAnalysis` ([BrainOrchestrator.swift:125](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:125)).
   - Tier gate again ([BrainOrchestrator.swift:51-58](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:51)).
   - Routing: `.sleepAnalysis → local`; `.mainChat / .gym / .kitchen / .peaks / .myVibe → cloud` ([BrainOrchestrator.swift:113-120](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:113)).
   - For cloud: `processCloudRoute → cloudService.generateReply(...)` ([BrainOrchestrator.swift:223-263](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:223)).

7. **`CloudBrainService.generateReply(...)`** ([CloudBrain.swift:40](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:40))
   - One MainActor hop reads tier, cloud-safe memories, consent, profile ([CloudBrain.swift:55-66](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:55)).
   - Selects model: `gemini-3-flash-preview` (Pro) or `gemini-2.5-flash` (free) ([CloudBrain.swift:94-96](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:94)).
   - **Calls `sanitizer.sanitizeForCloud(...)` ([CloudBrain.swift:87](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:87))** — this is where conversation length collapses.
   - `transport.generateReply(request: sanitizedRequest, model: aiModel)` ([CloudBrain.swift:100-103](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:100)).
   - Audit-logs success or failure ([CloudBrain.swift:105-134](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:105)).

8. **`HybridBrainService.generateReply(...)`** ([HybridBrain.swift:218](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:218))
   - `validate(request)` — non-empty + has user role ([HybridBrain.swift:264-272](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:264)).
   - `requestCloudResponse(...)` ([HybridBrain.swift:276-330](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:276)).
     - Builds URLRequest (proxy-or-direct).
     - `session.data(for: urlRequest)`.
     - Decodes `GeminiResponse` ([HybridBrain.swift:161](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:161)).
     - Joins all `parts[].text` with `.trimmingCharacters(in: .whitespacesAndNewlines)` ([HybridBrain.swift:174-181](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:174)).
     - Passes `outputText` through `LLMJSONParser.decode(...)` ([HybridBrain.swift:323](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:323)).
   - Returns `HybridBrainServiceReply { message: sanitizeResponse(structuredResponse.message), … }` ([HybridBrain.swift:230-237](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:230)).

9. **Back in `BrainOrchestrator`** ([BrainOrchestrator.swift:70-80](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:70))
   - `personalizeReply(...)` injects user name into placeholders ([BrainOrchestrator.swift:523](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:523)).
   - `applySafetyDecision(...)` may prepend a wellbeing nudge or override with referral message.
   - `persistIfMemoryEnabled(...)` (Memory V4) writes to `EpisodicStore` and async-extracts facts ([BrainOrchestrator.swift:807](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:807)).

10. **Back in `CaptainViewModel.processMessage`** ([CaptainViewModel.swift:498-535](AiQo/Features/Captain/CaptainViewModel.swift:498))
    - `cleanAssistantReplyMessage(reply.message)` → `LLMJSONParser.cleanDisplayText(...)` + `stripInlineMedicalDisclaimerTail(...)` ([CaptainViewModel.swift:830-859](AiQo/Features/Captain/CaptainViewModel.swift:830)).
    - `validateResponse(...)` removes duplicate sentences and gates English-leakage in Arabic mode ([CaptainViewModel.swift:950-1021](AiQo/Features/Captain/CaptainViewModel.swift:950)).
    - Appends `replyMessage` to `messages`, persists via `MemoryStore`, logs to `ConversationThreadManager`, trims in-memory list to 80 ([CaptainViewModel.swift:526-532](AiQo/Features/Captain/CaptainViewModel.swift:526), [:613-617](AiQo/Features/Captain/CaptainViewModel.swift:613)).

11. **Async fact extraction** ([CaptainViewModel.swift:540-547](AiQo/Features/Captain/CaptainViewModel.swift:540))
    - Detached low-priority `MemoryExtractor.extract(userMessage:assistantReply:store:messageCount:)`
    - Rule-based every message + LLM extractor every 3rd message ([MemoryExtractor.swift:12, 30-37](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift:12)).

---

## 3. Request Body — Exact Current Shape

Built in `HybridBrainService.makeRequestBody(request:)` at [HybridBrain.swift:412-434](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:412):

```swift
func makeRequestBody(request: HybridBrainRequest) -> [String: Any] {
    let maxOutputTokens: Int = {
        switch request.screenContext {
        case .mainChat, .myVibe, .sleepAnalysis:
            return 600                                      // ← chat cap = 600
        case .gym, .kitchen, .peaks:
            return 900
        }
    }()

    return [
        "systemInstruction": [
            "parts": [
                ["text": promptBuilder.build(for: request)] // 7-layer prompt
            ]
        ],
        "contents": makeGeminiContents(for: request),       // ≤ 4 turns (post-sanitizer)
        "generationConfig": [
            "maxOutputTokens": maxOutputTokens,
            "temperature": 0.7
        ]
    ]
}
```

`makeGeminiContents` at [HybridBrain.swift:436-481](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:436) maps the (already-truncated) conversation to alternating `user / model` parts, attaches a kitchen image to the last user turn when applicable, and auto-prepends a `"…"` user filler if the first entry is `model` (Gemini requires user-first).

Notes:
- **No `stopSequences`.**
- **No `responseSchema` / `responseMimeType: "application/json"`** in the chat path. The `MemoryExtractor` extractor request DOES set `responseMimeType: "application/json"` ([MemoryExtractor.swift:233](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift:233)) — chat does not.
- Endpoint: `https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent` ([HybridBrain.swift:122-148](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:122)). Auth header is `X-goog-api-key`.
- Direct request timeout = **35 s** ([HybridBrain.swift:123, :363](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:123)). Resource timeout = 40 s ([HybridBrain.swift:124, :200](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:124)).
- `URLSession` is dedicated (NOT `.shared`) so the 7-day default resource timeout cannot leak ([HybridBrain.swift:195-204](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:195)).
- Single-shot — `URLSession.data(for:)`. **Not streaming.** `tokenStream(...)` chunks the already-fetched final string into 24-char ticks for animation ([HybridBrain.swift:499-523](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:499)).
- Proxy variant wraps as `{"model": …, "payload": <body>}` and POSTs to `functions/v1/captain-chat` with a Supabase JWT ([HybridBrain.swift:377-408](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:377)). `USE_CLOUD_PROXY` defaults to OFF ([AiQoFeatureFlags.swift:214](AiQo/Core/Config/AiQoFeatureFlags.swift:214)).

### 3.1 What "history" actually reaches Gemini

The pipeline narrows in three steps:
1. `CaptainViewModel.buildConversationHistory()` — last **20** in-memory messages ([CaptainViewModel.swift:620-632](AiQo/Features/Captain/CaptainViewModel.swift:620)).
2. `PrivacySanitizer.sanitizeConversation(...)` — last **4** of those ([PrivacySanitizer.swift:71, :377](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:71)):
   ```swift
   private let maxConversationMessages = 4
   …
   let truncated = Array(conversation.suffix(maxConversationMessages))
   ```
3. `makeGeminiContents` strips `system` role messages ([HybridBrain.swift:450](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:450)) — there are none in practice (only `user`/`assistant` reach it).

So **Gemini sees at most 4 turns of conversation**, period.

### 3.2 What memory IS injected (and how)

Long-term memory does NOT enter `contents`; it is folded into `systemInstruction` via PromptComposer's "ACTIVE WORKING MEMORY" layer ([PromptComposer.swift:222-269](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift:222)). The data path is:

- `CognitivePipeline.buildWorkingMemorySummary(...)` retrieves up to 8 ranked memories regardless of category ([CognitivePipeline.swift:359-414](AiQo/Features/Captain/Brain/03_Reasoning/CognitivePipeline.swift:359)).
- `PrivacySanitizer.sanitizeForCloud` then OVERWRITES that with the cloud-safe slice ([PrivacySanitizer.swift:188](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:188)):
  ```swift
  workingMemorySummary: safeWorkingMemory     // = cloudSafeMemories arg
  ```
- `cloudSafeMemories` is `MemoryStore.buildCloudSafeRelevantContext(...)` ([CloudBrain.swift:58-62](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:58), [MemoryStore.swift:274-301](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:274)) — restricted to categories `goal`, `preference`, `mood`, `injury`, `nutrition`, `insight`. Token budget 700 (Pro) or 400 (free) ([CloudBrain.swift:57](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:57)).
- `userProfileSummary` is replaced with `CloudSafeProfile.asSummaryLines()` ([PrivacySanitizer.swift:179, :26-46](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:179)) — first name, age, gender, bucketed height/weight only. Identity / body / sleep / workout_history / active_record_project memories never reach the prompt.

**Implication:** Captain remembers durable facts ("user is vegan", "knee injury") across sessions, but NOT what the user said three turns ago in the same chat.

---

## 4. Response Parsing — Exact Current Shape

`GeminiResponse` decoder ([HybridBrain.swift:161-182](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:161)):

```swift
private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }

    let candidates: [Candidate]?

    var outputText: String {
        candidates?
            .compactMap { $0.content }
            .flatMap { $0.parts ?? [] }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
```

Key facts:
- **`finishReason` is NOT decoded.** A `MAX_TOKENS` finish goes by silently. Grep confirmed zero hits across the Swift codebase for `finishReason`, `FinishReason`, or `MAX_TOKENS`.
- `safetyRatings`, `usageMetadata` likewise not parsed.
- Trimming is whitespace-only — does NOT chop characters.
- All `parts[].text` strings are `.joined()` together (no separator), then passed to `LLMJSONParser.decode(...)` ([HybridBrain.swift:323](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:323)).
- Empty `outputText` throws `HybridBrainServiceError.emptyResponse` ([HybridBrain.swift:316-318](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:316)).
- HTTP non-2xx → `badStatusCode(Int)` ([HybridBrain.swift:301-304](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:301)).
- Decode failure → `invalidResponse` ([HybridBrain.swift:309-312](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:309)).
- JSON parse fallback (parser couldn't extract `message`) → `parsingFallbackMessage(for: request.language)` is returned but logged as `gemini_parse_fallback_applied` ([HybridBrain.swift:325-327, :547-553](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:325)).

### 4.1 LLMJSONParser recovery behavior

[LLMJSONParser.swift](AiQo/Features/Captain/Brain/04_Inference/LLMJSONParser.swift) has multi-stage recovery:
1. Strict `JSONDecoder().decode(CaptainStructuredResponse.self, …)` ([LLMJSONParser.swift:218-231](AiQo/Features/Captain/Brain/04_Inference/LLMJSONParser.swift:218)).
2. Partial recovery from `JSONSerialization` object → reads `message`, optional plans, quickReplies ([LLMJSONParser.swift:234-253](AiQo/Features/Captain/Brain/04_Inference/LLMJSONParser.swift:234)).
3. Regex extraction of `"message":"…"` capture — quotes stop at first unescaped `"` ([LLMJSONParser.swift:289-313](AiQo/Features/Captain/Brain/04_Inference/LLMJSONParser.swift:289)).
4. Streaming preview helper `unescapedJSONStringPrefix(...)` ([LLMJSONParser.swift:380-404](AiQo/Features/Captain/Brain/04_Inference/LLMJSONParser.swift:380)) — also stops at the first `"`.

If Gemini returns a truncated JSON like `{"message":"…واصل ل` (no closing quote), stages 1 & 2 fail, stage 3's regex `"((?:\\.|[^"\\])*)"` likewise needs a closing quote, and stage 4 streaming-preview runs only when reading from a streaming buffer. The terminal fallback is `parsingFallbackMessage` ("صار خلل بالاتصال…").

**However:** if Gemini hits `maxOutputTokens` mid-`message` BUT closes the JSON object (Gemini sometimes auto-completes), the parser succeeds and a string truncated mid-Arabic-word is delivered to the UI verbatim. That matches the reported sample exactly.

### 4.2 Post-parser processing in CaptainViewModel

[CaptainViewModel.swift:501-511](AiQo/Features/Captain/CaptainViewModel.swift:501):
- `cleanAssistantReplyMessage(reply.message)` (`replyJSONParser.cleanDisplayText` + medical-tail strip) — does NOT truncate, only filters.
- `validateResponse(...)` ([CaptainViewModel.swift:950-1021](AiQo/Features/Captain/CaptainViewModel.swift:950)):
  - Splits on `.،؟!\n`, filters fragments ≤ 3 chars.
  - Deduplicates (case- + diacritic-folded).
  - **Only rebuilds when `unique.count < sentences.count`**, then joins with literal `.` separator — non-period punctuation is lost in that case ([CaptainViewModel.swift:974-976](AiQo/Features/Captain/CaptainViewModel.swift:974)).
  - English-ratio guard (>40 %) replaces the message with a generic Arabic fallback ([CaptainViewModel.swift:980-1006](AiQo/Features/Captain/CaptainViewModel.swift:980)).

For the reported sample (`"...واصل ل"`), `validateResponse` does not match a duplicate so the original string passes through unmodified.

---

## 5. Memory & History Handling

### 5.1 `CaptainMemory` SwiftData model
[CaptainMemory.swift:6-42](AiQo/Features/Captain/Brain/02_Memory/Models/CaptainMemory.swift:6):
- `id: UUID`
- `category: String` — `identity, goal, body, preference, mood, injury, nutrition, workout_history, sleep, insight, active_record_project`
- `key: String` (`@Attribute(.unique)`)
- `value: String`
- `confidence: Double`
- `source: String` — `user_explicit, extracted, healthkit, inferred, llm_extracted`
- `createdAt: Date`, `updatedAt: Date`
- `accessCount: Int`

`CaptainMemorySnapshot` ([CaptainMemory.swift:44-95](AiQo/Features/Captain/Brain/02_Memory/Models/CaptainMemory.swift:44)) is the Sendable transport copy.

### 5.2 Where messages live
- **In-memory `messages: [ChatMessage]`** ([CaptainViewModel.swift:90](AiQo/Features/Captain/CaptainViewModel.swift:90)) — UI source. Capped at 80 ([CaptainViewModel.swift:125, :613-617](AiQo/Features/Captain/CaptainViewModel.swift:125)).
- **Persistent SwiftData**:
  - V3: `PersistentChatMessage(sessionID:…)` ([MemoryStore.swift:529](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:529)).
  - V4: `EpisodicEntry(sessionID, timestamp, userMessage, captainResponse, …)` ([MemoryStore.swift:1031-1077](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:1031)).
  - Total cap: **200 persisted messages** ([MemoryStore.swift:518](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:518)). Trim runs every 12 writes ([MemoryStore.swift:519, :532-535](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:519)).

### 5.3 Persist timing
- **User message** persisted **before** AI replies, immediately on append ([CaptainViewModel.swift:268](AiQo/Features/Captain/CaptainViewModel.swift:268)).
- **Welcome message** persisted lazily on the first user send so cold-launch sessions do not litter SwiftData with one-message phantoms ([CaptainViewModel.swift:260-262](AiQo/Features/Captain/CaptainViewModel.swift:260), comment at [CaptainViewModel.swift:409-410](AiQo/Features/Captain/CaptainViewModel.swift:409)).
- **Captain reply** persisted **after** the orchestrator returns, before `MemoryExtractor` runs ([CaptainViewModel.swift:530](AiQo/Features/Captain/CaptainViewModel.swift:530)).
- Persistence is `Task(priority: .utility) { @MainActor … }` so writes never block the UI ([MemoryStore.swift:556-560](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:556)).

### 5.4 Session model (the critical bit)
- `currentSessionID: UUID` is regenerated **every cold launch** ([CaptainViewModel.swift:131, :397](AiQo/Features/Captain/CaptainViewModel.swift:131)).
- `loadPersistedHistory()` simply calls `startNewChat()` ([CaptainViewModel.swift:391-393](AiQo/Features/Captain/CaptainViewModel.swift:391)):
  ```swift
  /// كل فتحة تطبيق تبدأ بمحادثة جديدة — المحادثات القديمة متاحة عبر زر التاريخ
  private func loadPersistedHistory() {
      startNewChat()
  }
  ```
  → wipes `messages`, `messageCount`, plans, quickReplies; pushes a fresh welcome message ([CaptainViewModel.swift:396-411](AiQo/Features/Captain/CaptainViewModel.swift:396)).
- `loadSession(_:)` is the only path that re-hydrates an old session, triggered by tapping a session row in `ChatHistoryView` ([CaptainViewModel.swift:414-422](AiQo/Features/Captain/CaptainViewModel.swift:414); [ChatHistoryView.swift:113-118](AiQo/Features/Captain/ChatHistoryView.swift:113)).

So past sessions are NEVER loaded into the cloud-call context unless the user manually opens them.

### 5.5 What goes to the cloud, summarized

| Source | Reaches cloud? | Mechanism |
|---|---|---|
| Last 4 in-session turns | ✅ via `contents[]` | `PrivacySanitizer.sanitizeConversation` |
| Turns 5..20 of current session | ❌ dropped by sanitizer | `maxConversationMessages=4` |
| Turns 21..80 of current session | ❌ dropped by VM cap | `maxConversationWindow=20` |
| Past sessions in SwiftData | ❌ unless `loadSession` invoked | session-id reset on launch |
| `goal/preference/mood/injury/nutrition/insight` memories | ✅ via `systemInstruction` | `buildCloudSafeRelevantContext` (700/400 token budget) |
| `identity/body` (name, age, height, weight) | ✅ but bucketed | `CloudSafeProfile.asSummaryLines()` |
| `sleep/workout_history/active_record_project` memories | ❌ filtered out | not in `allowedCategories` set |
| HealthKit context | ✅ bucketed | `PrivacySanitizer.sanitizeHealthContext` |
| Kitchen image (only on `.kitchen`) | ✅ EXIF-stripped, ≤1280 px | `sanitizeKitchenImageData` |

---

## 6. Truncation Root Cause — Ranked Hypotheses

Reported sample: `"عاشت ايدك يا محمد، اليوم شغلك كلش حلو. واصل ل"` — ends mid-Arabic-word.

### Rank 1 (highest likelihood) — `maxOutputTokens` too low for Arabic chat replies
Evidence:
- `maxOutputTokens = 600` for `.mainChat / .myVibe / .sleepAnalysis` ([HybridBrain.swift:413-420](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:413)).
- The system prompt instructs verbose Iraqi Arabic, multi-section warmups, and quick replies. Arabic tokenizes inefficiently in Gemini's BPE — verbose replies easily exceed 600 tokens.
- Sample sentence count, a structured reply with greeting + recap + advice + question naturally lands ~700-1100 tokens; a single-paragraph 4-sentence sleep reply (the exact format mandated by [PromptComposer.swift:478-481](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift:478)) plus quickReplies + JSON envelope can also brush the cap.
- A truncation at the cap looks exactly like the reported sample: a complete preceding clause, then a partial trailing word.
- Gym/Kitchen/Peaks already get 900 tokens — implicit acknowledgment from the same code path that 600 is tight.

### Rank 2 — `finishReason: MAX_TOKENS` not detected, no retry, no UI signal
- `GeminiResponse` only decodes `candidates[].content.parts[].text` ([HybridBrain.swift:161-182](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:161)).
- Grep across repo: zero references to `finishReason` / `MAX_TOKENS`.
- This compounds Rank 1: even when Gemini reports a clean `MAX_TOKENS`, the app accepts the partial string verbatim, persists it, runs TTS on it, and silently retains it as conversation history.

### Rank 3 — Network 35-second timeout cutting Gemini mid-generation (LOWER likelihood)
- `GeminiConfig.requestTimeoutSeconds = 35` ([HybridBrain.swift:123](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:123)).
- Single-shot, not streaming — a timeout would surface as `URLSession` error → `requestFailed` → toast, NOT as a partial bubble. Unlikely to manifest as "complete-clause-then-mid-word".
- Plausible only if a flaky server connection delivers some bytes then stalls; in that case URLSession typically returns the partial Data on timeout, but `JSONDecoder` would fail (truncated JSON → `invalidResponse`) and the user would see the localized error, not the partial Arabic.

### Rank 4 — Response parsing trims the string
- `outputText` only `.trimmingCharacters(in: .whitespacesAndNewlines)` ([HybridBrain.swift:180](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:180)).
- `LLMJSONParser` does normalize smart quotes and strip code-fences ([LLMJSONParser.swift:163-191](AiQo/Features/Captain/Brain/04_Inference/LLMJSONParser.swift:163)) but does not chop characters inside the message.
- `CaptainPersonaBuilder.sanitizeResponse` only deletes banned phrases and collapses whitespace ([CaptainPersonaBuilder.swift:34-46](AiQo/Features/Captain/Brain/08_Persona/CaptainPersonaBuilder.swift:34)).
- `validateResponse` rebuild path can lose Arabic punctuation when duplicates exist ([CaptainViewModel.swift:974-976](AiQo/Features/Captain/CaptainViewModel.swift:974)) — but it only triggers when duplicates were present and rejoins with `.`. Not a fit for the reported case.
- **Verdict:** unlikely root cause for the reported sample.

### Rank 5 — Streaming assembly drops final chunk
- The chat path is single-shot. `tokenStream(...)` chunks the already-fetched final string for animation ([HybridBrain.swift:499-523](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:499)). Cannot cause real text loss.
- **Verdict:** ruled out.

### Rank 6 — TTS cap chopping displayed text
- `MiniMaxTTSProvider.speak(...)` rejects > 4 000 chars but does not modify shorter strings ([MiniMaxTTSProvider.swift:59-61](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift:59)).
- TTS receives the displayed string AFTER it's set; truncation in the bubble cannot be caused by TTS.
- **Verdict:** ruled out.

---

## 7. Memory Continuity Root Cause — Ranked Hypotheses

User report: "Captain does NOT seem to remember the FULL conversation history within a single session".

### Rank 1 (highest likelihood) — Conversation truncated to last 4 messages by PrivacySanitizer
Evidence:
- [PrivacySanitizer.swift:71](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:71): `private let maxConversationMessages = 4`.
- [PrivacySanitizer.swift:373-398](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:373):
  ```swift
  func sanitizeConversation(
      _ conversation: [CaptainConversationMessage],
      knownUserName: String?
  ) -> [CaptainConversationMessage] {
      let truncated = Array(conversation.suffix(maxConversationMessages))
      …
  }
  ```
- Class doc-comment at [PrivacySanitizer.swift:55-63](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:55) confirms the policy: *"Conversation truncated to LAST 4 messages only (prevents hallucination, saves tokens)"*.
- `CloudBrainService.generateReply` calls `sanitizer.sanitizeForCloud(...)` unconditionally on the cloud path ([CloudBrain.swift:87-92](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:87)).
- 4 messages = roughly 2 user/assistant pairs. Anything earlier in the same session is invisible to the model.

### Rank 2 — Cold-launch resets the in-memory message list to zero
Evidence:
- `init()` calls `loadPersistedHistory()` ([CaptainViewModel.swift:153](AiQo/Features/Captain/CaptainViewModel.swift:153)).
- `loadPersistedHistory()` defers entirely to `startNewChat()` ([CaptainViewModel.swift:391-393](AiQo/Features/Captain/CaptainViewModel.swift:391)).
- `startNewChat()` rolls a new `currentSessionID`, removes all messages, resets `messageCount`, and pushes a fresh welcome bubble ([CaptainViewModel.swift:396-411](AiQo/Features/Captain/CaptainViewModel.swift:396)).
- Past sessions remain in SwiftData but are only re-hydrated via `loadSession(_:)` — invoked solely from the chat-history sheet ([CaptainViewModel.swift:414-422](AiQo/Features/Captain/CaptainViewModel.swift:414); [ChatHistoryView.swift:113-118](AiQo/Features/Captain/ChatHistoryView.swift:113)).

### Rank 3 — Roles correct, system messages stripped (NOT a bug, just confirming it isn't this)
- `CaptainConversationRole` is `system / user / assistant` ([HybridBrain.swift:6-10](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:6)).
- `CaptainViewModel.buildConversationHistory()` maps `isUser ? .user : .assistant` only — never `.system` ([CaptainViewModel.swift:626-630](AiQo/Features/Captain/CaptainViewModel.swift:626)).
- `makeGeminiContents` filters `system` and maps assistant→`model` ([HybridBrain.swift:450, :452](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:450)). Roles are correct; the model can distinguish turns. **Not a fit.**

### Rank 4 — Memory IS injected but only the cloud-safe slice (compounds Rank 1)
- `workingMemorySummary` reaching the prompt is the cloud-safe rewrite, not the full retrieval ([PrivacySanitizer.swift:188](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:188)).
- `body / sleep / workout_history / active_record_project / identity` memories are filtered out of `buildCloudSafeRelevantContext`'s allowed set ([MemoryStore.swift:279](AiQo/Features/Captain/Brain/02_Memory/MemoryStore.swift:279)).
- `CloudSafeProfile` carries name + bucketed body stats separately ([PrivacySanitizer.swift:17-51](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:17)).
- This is privacy-by-design, not a bug, but it does mean Captain's "memory" is sparse on health/identity specifics — which can read as forgetfulness.

### Rank 5 — In-VM cap further narrows the upstream window (compounds Rank 1)
- `maxConversationWindow = 20` ([CaptainViewModel.swift:620](AiQo/Features/Captain/CaptainViewModel.swift:620)) and `maxInMemoryMessages = 80` ([CaptainViewModel.swift:125](AiQo/Features/Captain/CaptainViewModel.swift:125)) are both above the sanitizer's 4-cap, so they have no incremental effect today. They would only matter if the sanitizer cap were raised.

### Rank 6 — Streaming reset between sessions (NOT applicable)
- Single-shot transport. **Ruled out.**

---

## 8. Apple Compliance Flags

- **`fatalError` in production paths:** none in `AiQo/Features/Captain/**`. Grep returned no matches.
- **Missing `PrivacyInfo.xcprivacy` references:** `AiQo/PrivacyInfo.xcprivacy` exists at the project root (and is git-modified). Out of scope for this audit; verify against current Gemini + MiniMax API-call privacy reasons before App Review.
- **Health/medical-claim language in prompts:**
  - Strict guardrails in [PromptComposer.swift:67-90](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift:67): "wellness coach, NOT a doctor", redirects to physician for specific weight-loss / calorie / symptom queries, references WHO/ACSM.
  - Persistent `CaptainSafetyBanner` above the chat ([CaptainChatView.swift:31](AiQo/Features/Captain/CaptainChatView.swift:31)).
  - `stripInlineMedicalDisclaimerTail` regex strips legacy "consult your doctor" tails as a backstop ([CaptainViewModel.swift:845-859](AiQo/Features/Captain/CaptainViewModel.swift:845)).
  - Wellbeing intervention path: `CrisisDetector` + `SafetyNet` + `ProfessionalReferral.supportMessage` ([BrainOrchestrator.swift:146-156, :463-483](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift:146)).
  - **Status: looks compliant**, contingent on the safety banner remaining visible at all times.
- **Hardcoded API keys:** none found in code. `CAPTAIN_API_KEY` flows through `Bundle.main.object(forInfoDictionaryKey:)` and `ProcessInfo.processInfo.environment` ([HybridBrain.swift:128-141](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:128); [MemoryExtractor.swift:347-364](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryExtractor.swift:347)). Validation rejects unexpanded `$()` placeholders ([HybridBrain.swift:151-156](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:151)). However, when `USE_CLOUD_PROXY` is OFF (default — [AiQoFeatureFlags.swift:214](AiQo/Core/Config/AiQoFeatureFlags.swift:214)), the keys ship inside the IPA via `Secrets.xcconfig`. The proxy migration described in [CaptainProxyConfig.swift:11-17](AiQo/Features/Captain/Brain/04_Inference/Services/CaptainProxyConfig.swift:11) and [supabase/functions/README.md](supabase/functions/README.md) addresses this.
- **Missing error UI for network failures:** present and localized — `fallbackMessage(for:screenContext:)` covers `CaptainProcessingTimeoutError`, `HybridBrainServiceError.networkUnavailable / requestFailed / badStatusCode(429/503)`, `AIDataConsentError.consentRequired`, and `LocalBrainServiceError.*` ([CaptainViewModel.swift:670-813](AiQo/Features/Captain/CaptainViewModel.swift:670)). Bilingual strings.
- **Telemetry:** `AnalyticsService.shared.track(.captainMessageSent / .captainResponseReceived(latencyMs:) / .captainResponseFailed(error:))` ([CaptainViewModel.swift:253, :534-535, :552](AiQo/Features/Captain/CaptainViewModel.swift:253)). Audit-log rows written via `AuditLogger.shared.record(...)` ([CloudBrain.swift:69-81, :105-134](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:69)).

---

## 9. Open Questions (UNKNOWNs needing Mohammed's input)

1. **Was the truncated reply observed on a free or Pro tier?** Free uses `gemini-2.5-flash`, Pro uses `gemini-3-flash-preview` ([CloudBrain.swift:13-14, :94-96](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift:13)). The 600-token cap is identical, but tokenizer behavior between models differs slightly.
2. **Was `USE_CLOUD_PROXY` ON or OFF for the affected build?** Default is OFF ([AiQoFeatureFlags.swift:214](AiQo/Core/Config/AiQoFeatureFlags.swift:214)). The proxy adds JWT validation latency that could push close calls past the 35s timeout — UNKNOWN whether the proxy is currently enabled in production.
3. **Was the affected screen `.mainChat` (600 tokens) or `.gym/.kitchen/.peaks` (900 tokens)?** The reported sample looks like main chat, but confirmation would let us scope the fix.
4. **Conversation length when truncation occurred — how many turns deep?** Helps confirm whether the in-VM 20-cap or sanitizer 4-cap is the user's first noticeable hit, and validates Memory hypothesis Rank 1.
5. **Logged signals at the time of the bug?** The transport already logs `gemini_request model=… via=…`, `gemini_response status=…`, `gemini_output length=…` ([HybridBrain.swift:282-315](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:282)). If the user can capture a Console run, the `gemini_output length` value tied to the bad reply would directly distinguish "Gemini cut at 600 tokens" from a network event.
6. **Was the `PrivacySanitizer.maxConversationMessages = 4` cap a deliberate hallucination-control choice, or a stale token-budget heuristic?** Doc-comment at [PrivacySanitizer.swift:55-63](AiQo/Features/Captain/Brain/05_Privacy/PrivacySanitizer.swift:55) cites both reasons; product intent matters before raising it.
7. **Is "session = each app launch" intentional UX, or a hangover from a simpler model?** Documented behavior in [CaptainViewModel.swift:391](AiQo/Features/Captain/CaptainViewModel.swift:391) (`كل فتحة تطبيق تبدأ بمحادثة جديدة`), but it directly conflicts with the user's "remember the full conversation" expectation.
8. **Are there any production logs of `gemini_parse_fallback_applied`?** ([HybridBrain.swift:326](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift:326)) — would prove or refute Rank 4 (parser losing characters).

---

## 10. Suggested Fix Order (high-level, no code)

Listed by impact / risk; do not interpret as a final plan — Mohammed should ratify and we'll generate code per item.

1. **Decode `finishReason` from the Gemini response.** Without it the app is blind to truncation. Once visible, all four downstream choices below can be made data-driven rather than speculative.
2. **Raise `maxOutputTokens` for `.mainChat` / `.myVibe`.** Current 600 → 1024-1500 is the obvious starting bracket. Verify with the audit log that median+p95 reply length stays well under the new cap, then keep tuning.
3. **Surface `MAX_TOKENS` properly:** when detected, either (a) auto-retry once with a higher cap, (b) keep the truncated string but UI-mark it as continued and offer a "أكمل" tap, or (c) discard and show the localized error fallback. Each has different UX/cost trade-offs.
4. **Re-evaluate `PrivacySanitizer.maxConversationMessages = 4`.** Raising to ~10-16 messages preserves cloud privacy posture (PII redaction is independent of length) while restoring single-session continuity. Token budget impact is moderate; pair with a token-aware trim (sum of `content.utf8.count` ≤ X) rather than a fixed message count.
5. **Address the cold-launch session reset.** Two reasonable directions:
   - Auto-resume the last session if it has ≥1 user message and is < N hours old (lightweight, preserves the "new chat = new session" affordance).
   - Or load the tail (e.g. last 12 messages) of the most-recent session into `messages` on launch so the model and the user can pick up where they left off.
6. **Cover `validateResponse`'s punctuation-loss edge case.** When duplicates trigger a rebuild, rejoin with the original separator captured during split (or simply skip the rebuild when only one duplicate exists). Nice-to-have, not a primary bug.
7. **Telemetry on `gemini_output length` ↔ `finishReason`.** Once fix #1 ships, log both side-by-side per request so the team can monitor truncation rate post-deploy. Existing audit-log infra supports it.
8. **Long-term: enable `USE_CLOUD_PROXY` once Supabase Edge Functions are deployed** ([CaptainProxyConfig.swift:11-17](AiQo/Features/Captain/Brain/04_Inference/Services/CaptainProxyConfig.swift:11), [supabase/functions/README.md](supabase/functions/README.md)). Removes IPA-shipped API keys (compliance + quota-protection win). Independent of the truncation/memory fixes.

---

Report written to [Captain_Hamoudi_Diagnostic_Report.md](Captain_Hamoudi_Diagnostic_Report.md). No source files were modified.
