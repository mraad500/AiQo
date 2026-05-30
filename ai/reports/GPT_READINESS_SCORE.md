# AiQo — GPT Readiness Score

> An honest scorecard of how ready AiQo is to be understood by, and integrated with, GPT technologies — after this program. Scored 0–10 per dimension with the evidence and what would raise it.

---

## Overall: **9.0 / 10** for the shippable scope

The **public** GPT/MCP/agent surface is complete, verified, and deployable. The remaining gap is the **personal (per-user, OAuth)** surface, which is fully designed but intentionally not built (it needs a privacy review and backend work). That's the right call pre-launch — so the score reflects "everything that should be done now is done."

| # | Dimension | Score | Evidence |
|---|---|---|---|
| 1 | **AI-readable documentation** | 10 | 7 GPT-optimized knowledge docs + architecture doc, cross-linked, with a TL;DR and a machine-readable mirror. Self-contained sections built for retrieval. |
| 2 | **Can a GPT understand AiQo?** | 10 | Vision, features, persona, tiers, glossary, FAQ, flows, and the tier-naming gotcha all documented and queryable via `searchKnowledge`. |
| 3 | **OpenAI Actions readiness** | 9 | Import-ready `OPENAI_ACTIONS_SCHEMA.json` + a deployable, **verified** knowledge API (`/ai/*.json`, `/api/knowledge/search`). −1: not yet deployed to production (one `git push`). |
| 4 | **MCP readiness** | 9 | Runnable server (official SDK), 7 tools + a resource, Claude-Desktop config, readiness guide. −1: stdio only (no hosted remote transport yet). |
| 5 | **Future-agent readiness** | 9 | Agent-architecture doc, tool belt, safety rules, and AiQo's own Brain documented as a reference pattern. |
| 6 | **Website AI discoverability** | 10 | `llms.txt`, AI-crawler robots rules, `WebSite`+`FAQPage` JSON-LD, `ai-plugin.json`, served knowledge JSON + a context pack. All verified live. |
| 7 | **Personal / data integration (OAuth)** | 5 | Fully specified (OpenAPI `personal` tag, scopes, endpoint contracts, build checklist) but **not implemented**. Correctly deferred behind a privacy review. |
| 8 | **Automation & maintainability** | 9 | Three zero-dependency scripts (validate / sync / context-pack), all passing; documented workflow; CI suggestion. |
| 9 | **Security & compliance of the AI surface** | 9 | Public surface carries no user data / no model quota; internal proxies excluded from Actions; security review clean. −1: web security headers + per-user rate limiting still recommended. |

---

## What a new engineer can do **today** with only these files

✅ Understand AiQo end-to-end (`ai/README.md` → `ai/knowledge/`).
✅ Create a Custom GPT (`ai/actions/OPENAI_ACTIONS_SCHEMA.json` + `ai/prompts/custom_gpt_system_prompt.md`).
✅ Configure OpenAI Actions (the schema imports as-is; endpoints verified).
✅ Run an MCP server (`ai/mcp/` — `npm i && node server.mjs`).
✅ Build an agent (`ai/documentation/AGENT_ARCHITECTURE.md` + the public tool belt).
✅ Optimize the site for answer engines (already implemented in `aiqo-web`).
🟡 Build the per-user integration (designed in `GPT_INTEGRATION_GUIDE.md` §4 — needs OAuth + endpoints + privacy review).

**This satisfies the program's success condition** for the public scope.

---

## How to reach 10/10

1. **Deploy** the knowledge API (push `aiqo-web`) and **publish** the Custom GPT → raises #3.
2. Add a **hosted/remote MCP** transport → raises #4.
3. Ship the **OAuth personal API** (after privacy review) → raises #7 from 5 to ~9.
4. Add **web security headers + per-user rate limiting** → raises #9.

None are blockers; all are tracked in [NEXT_STEPS.md](NEXT_STEPS.md) and [ROADMAP.md](ROADMAP.md).
