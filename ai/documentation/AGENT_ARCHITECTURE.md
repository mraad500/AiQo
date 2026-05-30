# AiQo — Agent Architecture

> Reference for building AI agents on top of AiQo, and a map of the agent-shaped architecture AiQo already runs internally. For OpenAI Actions, MCP, the Assistants/Responses API, or custom agent frameworks.

---

## 1. Two kinds of agent

### A. The AiQo Knowledge Agent (buildable today)
An external agent that **explains** AiQo. It has no account access. Its tool belt is the public knowledge API:

```
Tools:
  searchKnowledge(q, limit)   ← primary retrieval
  getProductInfo()            getCaptainProfile()
  listFeatures()              getGlossary()
  getPricing()                listFaq()

Grounding: ai/knowledge/*.md  (vector store or system prompt)
Guardrails: no medical advice as fact; accurate tiers; no invented features
System prompt: ai/prompts/custom_gpt_system_prompt.md
```
Use cases: a support GPT, a sales/marketing assistant, an in-docs helper, an MCP tool for a coding agent.

### B. The AiQo Personal Agent (planned, OAuth)
An agent a **user connects to their own account**. It adds per-user tools behind OAuth scopes:

```
Tools (planned, scoped):
  getMyHealthSummary()        scope health:read
  askCaptain(message)         scope captain:chat   → routes through the hardened captain-chat pipeline
  logWater(milliliters)       scope log:write

Guardrails: consent gate, PrivacySanitizer, model allowlist, crisis-safety layer (reused from the app)
```
This requires the OAuth server + endpoints described in [GPT_INTEGRATION_GUIDE.md](GPT_INTEGRATION_GUIDE.md) §4. Until built, treat these as design-only.

---

## 2. Recommended agent loop (knowledge agent)

```
user question
  → classify: catalogue (features/pricing/glossary/faq) or specific?
      catalogue → call the matching list/get tool
      specific  → searchKnowledge(q) → read top chunks
  → synthesize a grounded answer, citing `source`
  → if the tools don't cover it → say so, link https://aiqo.app/support
```
Keep the loop shallow (1–2 tool calls). The corpus is small; preloading `info.json` + `pricing.json` once per session is a fine optimization.

---

## 3. AiQo is already an agent internally

Building agents *on* AiQo is easier once you see AiQo's own **Captain Brain** is an agent architecture (`AiQo/Features/Captain/Brain/`). It is a useful reference model:

| Agent concept | AiQo implementation |
|---|---|
| **Router / planner** | `BrainOrchestrator` — picks on-device vs. cloud per intent, runs a fallback chain |
| **Tools / skills** | structured outputs: workout plan, meal plan, Spotify rec, reminder, saved memory |
| **Memory** | 5 stores — Episodic, Semantic, Procedural, Emotional, Relationship — with hybrid (lexical + embedding) RAG, salience & temporal indexing |
| **Long-context handling** | `ConversationCompactor` → a faithful `ConversationDigest` with a grounding lock (never invent/contradict) |
| **Standing instructions** | `Directives` — user-taught rules mirrored into every prompt and executed automatically |
| **Proactive triggers** | sleep-debt, inactivity, PR, recovery, streak-risk → notifications (an event-driven agent loop) |
| **Guardrails** | `PrivacySanitizer` (PII), model allowlist, crisis detection, `TierGate` |
| **Prompt assembly** | a 7-layer system prompt (identity → profile → memory → bio-state → circadian tone → screen context → output contract) |

If you are designing a personal agent, **reuse these primitives** rather than reinventing them — especially the sanitizer, the model allowlist, and the crisis-safety layer.

---

## 4. Safety & guardrails (non-negotiable for any AiQo agent)

1. **Health is sensitive.** Never present coaching as medical advice. Defer to professionals on injury, medication, pregnancy, eating disorders, and mental-health crises. Surface professional resources when distress is detected.
2. **Privacy boundary.** A personal agent must strip PII before any third-party model call (reuse `PrivacySanitizer` semantics) and must never send sleep raw data off-device without explicit consent.
3. **Tier honesty.** Don't promise Pro features to a Max/Free user, or vice versa.
4. **No quota abuse.** Never expose the internal `captain-chat`/`captain-voice` proxies as agent tools.
5. **Brand integrity.** If speaking as Captain Hamoudi, follow the dialect and banned-phrase rules in [../knowledge/CAPTAIN_HAMMOUDI_PROFILE.md](../knowledge/CAPTAIN_HAMMOUDI_PROFILE.md).

---

## 5. Framework mapping

| Framework | How AiQo plugs in |
|---|---|
| **Custom GPT / Actions** | Import `ai/actions/OPENAI_ACTIONS_SCHEMA.json`; see GPT guide §1 |
| **OpenAI Assistants / Responses** | Define `searchKnowledge` (+ catalogue tools) as functions; see GPT guide §2 |
| **MCP (Claude Desktop, IDEs)** | Run `ai/mcp/server.mjs`; see [MCP_READINESS_GUIDE.md](MCP_READINESS_GUIDE.md) |
| **LangChain / LlamaIndex / custom** | Wrap the `/ai/*.json` + `/api/knowledge/search` HTTP endpoints as tools; load `ai/knowledge/*.md` into a vector store |

---

## 6. Multi-agent / future patterns

- **Guide + Captain split:** a public "Guide" agent for product Q&A, handing off to a personal "Captain" agent (OAuth) for account-specific coaching.
- **Retrieval + verify:** for high-stakes answers (pricing, medical-adjacent), a second pass verifies the claim against `searchKnowledge` before replying.
- **Localization agent:** an agent that answers in Gulf/Iraqi Arabic, using `captain.json` for tone calibration.

All of these compose from the same public tool belt; none require new infrastructure until the personal API ships.
