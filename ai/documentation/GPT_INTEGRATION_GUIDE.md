# AiQo × GPT — Integration Guide

> How to connect OpenAI GPT technologies to AiQo: a Custom GPT, OpenAI Actions, the Assistants/Responses API, and the path to a personal (per-user) integration. This is the practical companion to [../schemas/OPENAPI_SPEC.yaml](../schemas/OPENAPI_SPEC.yaml) and [../actions/OPENAI_ACTIONS_SCHEMA.json](../actions/OPENAI_ACTIONS_SCHEMA.json).

---

## 0. The integration model (read this first)

AiQo exposes **three surfaces**, separated by trust level. Pick the one that matches your use case:

| Surface | Auth | Use case | Status |
|---|---|---|---|
| **Public Knowledge API** | none | A Custom GPT / agent that answers questions *about* AiQo (features, pricing, the Captain, how-to). | ✅ Ready to deploy (ship `aiqo-web`) |
| **Personal API** | OAuth 2.0 | A GPT a *user* connects to their own account to read their health summary, log water, or chat with the Captain in context. | 🟡 Designed, not yet built |
| **Internal proxies** | Supabase JWT | The iOS app's own `captain-chat` (Gemini) and `captain-voice` (MiniMax) functions. | ⛔ App-only — **never** expose as an Action |

> **Why the internal proxies are not Actions:** they require a first-party app session JWT (no third-party OAuth), and they are opaque model proxies — turning them into an Action would just hand out AiQo's Gemini/MiniMax quota and bypass app-side safety. The public surface below is the correct foundation.

---

## 1. Build a public AiQo Custom GPT (no code, ~10 minutes)

This produces a GPT that can knowledgeably answer anything about AiQo.

1. **Deploy the knowledge API.** The endpoints live in the `aiqo-web` repo:
   - Static JSON: `aiqo-web/public/ai/{info,features,pricing,captain,glossary,faq,openapi}.json`
   - Search: `aiqo-web/app/api/knowledge/search/route.ts`
   Push `aiqo-web` to `main` (auto-deploys to Vercel) and confirm `https://aiqo.app/ai/info.json` and `https://aiqo.app/api/knowledge/search?q=pricing` return JSON.
2. **Create the GPT.** In ChatGPT → *Explore GPTs → Create → Configure*.
3. **Add the actions.** *Actions → Create new action → Schema*. Paste the **entire** contents of [../actions/OPENAI_ACTIONS_SCHEMA.json](../actions/OPENAI_ACTIONS_SCHEMA.json). Authentication: **None**. (Server is already `https://aiqo.app`.)
4. **Set the instructions.** Paste the system prompt from [../prompts/custom_gpt_system_prompt.md](../prompts/custom_gpt_system_prompt.md).
5. **Name & brand it.** e.g. "AiQo Guide" — use the brand portrait and mint/sand palette.
6. **Test.** Ask: "How much is AiQo?", "Is Kitchen free?", "Who is Captain Hamoudi?", "Does it work offline?" Confirm it calls `searchKnowledge`/the JSON endpoints and cites sources.
7. **Publish** (private link or public).

**Privacy:** this GPT touches **no user data** and spends **no** AiQo model quota — it only reads public product knowledge.

---

## 2. Use the knowledge API from the OpenAI API (function calling / Responses)

For your own backend (e.g. a support bot), expose the same endpoints as tools.

```python
# pip install openai
from openai import OpenAI
import requests

client = OpenAI()
BASE = "https://aiqo.app"

tools = [{
    "type": "function",
    "function": {
        "name": "searchKnowledge",
        "description": "Search the AiQo knowledge base for features, pricing, the Captain, glossary, or FAQ.",
        "parameters": {
            "type": "object",
            "properties": {"q": {"type": "string"}, "limit": {"type": "integer", "default": 5}},
            "required": ["q"],
        },
    },
}]

def search_knowledge(q, limit=5):
    return requests.get(f"{BASE}/api/knowledge/search", params={"q": q, "limit": limit}, timeout=10).json()

resp = client.responses.create(
    model="gpt-5.1",                 # or your current model
    input="Is the fridge scanner free on AiQo?",
    tools=tools,
    instructions=open("ai/prompts/custom_gpt_system_prompt.md").read(),
)
# When the model calls searchKnowledge, run search_knowledge(**args) and feed the result back.
```

The same JSON endpoints (`/ai/*.json`) can be fetched directly if you prefer to preload the catalogue into context instead of tool-calling.

---

## 3. Ground a model with the knowledge files (retrieval / fine-tune context)

- **Vector store / file search:** upload the markdown in `ai/knowledge/*` as the corpus. They are written in short, self-contained sections specifically for chunked retrieval.
- **System-prompt grounding:** for a small bot, paste `ai/knowledge/AIQO_KNOWLEDGE_BASE.md` (the TL;DR + index) and let the model call the JSON endpoints for detail.
- **Always cite** the `source` field returned by `searchKnowledge`.

---

## 4. The personal (per-user) integration — design & checklist

To let a *user* connect their AiQo account to a GPT and ask about **their** data, you need the OAuth surface defined in `OPENAPI_SPEC.yaml` under the `personal` tag:

- `GET /api/v1/me/health-summary` — today's metrics (scope `health:read`)
- `POST /api/v1/me/captain/ask` — Captain reply with the user's context (scope `captain:chat`)
- `POST /api/v1/me/water` — log hydration (scope `log:write`)

**To ship it:**
1. **OAuth 2.0 Authorization-Code server.** Back it with Supabase Auth. Expose `/oauth/authorize` and `/oauth/token`; issue short-lived access tokens with the scopes above. (A Next.js route or a dedicated edge function.)
2. **New edge functions / route handlers** implementing the three endpoints, each verifying the OAuth token → mapping to the Supabase user → reading from `profiles` / a health snapshot the app syncs (the app currently keeps health on-device, so this requires an explicit, consented sync of a *summary* to the server).
3. **`/api/v1/me/captain/ask`** should call the existing hardened `captain-chat` path server-side (re-using `PrivacySanitizer`, the model allowlist, and safety gates) — never expose the raw proxy.
4. **Register in the GPT** with `Authentication → OAuth`, the scopes, and the authorize/token URLs.
5. **Consent & privacy review** before launch (health data leaving the device is a material change — see [SECURITY_REVIEW.md](../reports/SECURITY_REVIEW.md)).

Until then, the personal endpoints are marked `x-planned: true` and should not be advertised as live.

---

## 5. Keeping it accurate

- The JSON served at `/ai/*` is the machine-readable mirror of `ai/knowledge/*.md`. Regenerate/validate with `ai/scripts/sync-ai-knowledge.mjs` and `ai/scripts/validate-openapi.mjs` (see [../../ai/scripts/README.md](../scripts/README.md)).
- When the app changes, update `ai/knowledge/*.md`, re-run the sync script, and redeploy `aiqo-web`.

---

## 6. Quick reference

| Thing | Where |
|---|---|
| Full API spec | `ai/schemas/OPENAPI_SPEC.yaml` |
| Import-ready Actions schema | `ai/actions/OPENAI_ACTIONS_SCHEMA.json` |
| Custom GPT system prompt | `ai/prompts/custom_gpt_system_prompt.md` |
| Knowledge (human) | `ai/knowledge/*.md` |
| Knowledge (machine) | `https://aiqo.app/ai/*.json` |
| Search endpoint | `https://aiqo.app/api/knowledge/search?q=` |
| MCP server | `ai/mcp/` (see [MCP_READINESS_GUIDE.md](MCP_READINESS_GUIDE.md)) |
| Agent patterns | [AGENT_ARCHITECTURE.md](AGENT_ARCHITECTURE.md) |
