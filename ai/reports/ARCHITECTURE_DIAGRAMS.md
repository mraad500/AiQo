# AiQo — Architecture Diagrams

> Mermaid diagrams (render on GitHub and in most Markdown viewers). They cover the system, the Captain "Brain" pipeline, the GPT-integration topology, and the knowledge-asset data flow.

---

## 1. System architecture

```mermaid
flowchart TB
  subgraph Device["iPhone / Apple Watch (iOS 26+)"]
    UI["SwiftUI features<br/>Home · Captain · Gym · Kitchen · Sleep · …"]
    Brain["Captain Brain<br/>(orchestrator + memory + directives)"]
    HK["HealthKit<br/>(actor, background delivery)"]
    AppleAI["Apple Intelligence<br/>(on-device: sleep, fallback)"]
    Store["SwiftData · Keychain · UserDefaults"]
    UI --> Brain
    Brain --> HK
    Brain --> AppleAI
    Brain --> Store
    UI --> Store
  end

  subgraph Supabase["Supabase Edge Functions (Deno)"]
    Chat["captain-chat<br/>JWT + model allowlist + 256KB cap"]
    Voice["captain-voice<br/>JWT + allowlist + 16KB cap"]
  end

  Gemini["Google Gemini"]
  MiniMax["MiniMax TTS"]
  Auth["Supabase Auth / Postgres / Realtime"]

  Brain -- "session JWT + sanitized payload" --> Chat
  Brain -- "session JWT + text" --> Voice
  Chat -- "server-held GEMINI_API_KEY" --> Gemini
  Voice -- "server-held MINIMAX_API_KEY" --> MiniMax
  UI --> Auth
```

---

## 2. Captain "Brain" request pipeline

```mermaid
flowchart LR
  Msg["User message"] --> Orch{"BrainOrchestrator<br/>route by intent"}
  Orch -- "sleep analysis" --> Local["LocalBrainService<br/>(Apple Intelligence, on-device)"]
  Orch -- "chat / gym / kitchen / peaks / myVibe" --> Cloud["CloudBrainService"]
  Cloud --> San["PrivacySanitizer<br/>(strip PII, cap history)"]
  San --> Prompt["PromptComposer<br/>(7-layer system prompt)"]
  Prompt --> Hybrid["HybridBrainService"]
  Hybrid --> Proxy["captain-chat → Gemini"]
  Proxy --> Parse["LLMJSONParser →<br/>CaptainStructuredResponse"]
  Local --> Parse
  Parse --> Mem["Memory extraction<br/>(5 stores + RAG)"]
  Parse --> Render["CaptainViewModel<br/>(bubbles + cards)"]
  Hybrid -. "on failure" .-> Local
  Local -. "on failure" .-> Offline["Localized offline message"]
```

---

## 3. GPT-integration topology (the three surfaces)

```mermaid
flowchart TB
  subgraph Public["1 · PUBLIC KNOWLEDGE API — no auth ✅ ready"]
    direction LR
    JSON["/ai/*.json (static)"]
    Search["/api/knowledge/search"]
  end
  subgraph Personal["2 · PERSONAL API — OAuth 2.0 🟡 planned"]
    direction LR
    HSum["/api/v1/me/health-summary"]
    Ask["/api/v1/me/captain/ask"]
    Water["/api/v1/me/water"]
  end
  subgraph Internal["3 · INTERNAL PROXIES — app JWT ⛔ never an Action"]
    direction LR
    IChat["captain-chat"]
    IVoice["captain-voice"]
  end

  GPT["Custom GPT / Actions"]
  MCP["MCP clients (Claude Desktop, IDEs)"]
  Agents["Agents / Assistants API"]
  iOS["AiQo iOS app"]

  GPT --> Public
  MCP --> Public
  Agents --> Public
  GPT -. "after OAuth ships" .-> Personal
  iOS --> Internal
  Personal -. "server-side reuse" .-> Internal
```

---

## 4. Knowledge-asset data flow

```mermaid
flowchart LR
  MD["ai/knowledge/*.md<br/>(human source of truth)"] --> Pack["build-context-pack.mjs"]
  Actions["ai/actions/OPENAI_ACTIONS_SCHEMA.json<br/>(canonical public spec)"] --> Sync["sync-ai-knowledge.mjs"]
  Data["aiqo-web/public/ai/*.json<br/>(machine-readable)"]
  Sync --> WebSpec["public/ai/openapi.json"]
  Sync --> Index["public/ai/index.json"]
  Pack --> Ctx["public/ai/context.md"]
  Data --> Route["/api/knowledge/search"]
  Data --> Served["Served at https://aiqo.app/ai/*"]
  WebSpec --> Served
  Validate["validate-ai-assets.mjs"] --> Gate{"CI gate"}
  Served --> Consumers["Custom GPT · MCP · agents · answer engines"]
```

---

## 5. Tier model (note the enum quirk)

```mermaid
flowchart LR
  Free["Free<br/>.none · rank 0<br/>$0 · no Captain chat"] --> Max["AiQo Max<br/>.max · rank 1<br/>$9.99 · entry paid"]
  Max --> Pro["AiQo Intelligence Pro<br/>.pro · rank 3<br/>$19.99 · TOP tier"]
  Trial["Trial · .trial · rank 2<br/>7 days · Pro-equivalent"] -.-> Pro
  classDef note fill:#FFE68C,stroke:#333;
  class Trial note;
```

> `.max` is the **entry** paid tier, not the maximum. Always compare tiers by `rank`, never by the enum name.
