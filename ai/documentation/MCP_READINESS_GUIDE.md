# AiQo × MCP — Readiness Guide

> How AiQo is prepared for the **Model Context Protocol (MCP)**: what's shipped, how to run it, the tool/resource mapping, and the roadmap to a personal MCP server. Companion to the runnable scaffold in [`../mcp/`](../mcp/).

---

## 1. What MCP is, in one paragraph

MCP is an open standard that lets AI applications (Claude Desktop, IDEs, agents) connect to external **tools** and **resources** through a uniform interface. A model client speaks MCP to a server; the server advertises tools (callable functions) and resources (readable documents). AiQo ships an MCP server that turns its public knowledge API into MCP tools, so any MCP client can answer questions about AiQo.

---

## 2. What's ready today

✅ **`aiqo-knowledge` MCP server** — [`../mcp/server.mjs`](../mcp/server.mjs), built on the official `@modelcontextprotocol/sdk`. Read-only, no secrets, no user data. It is a thin client of `https://aiqo.app/ai/*`.

### Tools exposed
| Tool | Purpose |
|---|---|
| `aiqo_search` | Keyword search across the whole knowledge base (primary retrieval) |
| `aiqo_info` | Product overview |
| `aiqo_features` | All features + required tier |
| `aiqo_pricing` | Tiers and pricing |
| `aiqo_captain` | Captain Hamoudi persona profile |
| `aiqo_glossary` | Product terms |
| `aiqo_faq` | FAQ |

### Resources exposed
| Resource URI | Content |
|---|---|
| `aiqo://info` | Product overview JSON |

---

## 3. Run it

```bash
cd ai/mcp
npm install
AIQO_BASE=https://aiqo.app node server.mjs    # stdio MCP server
# or debug with the inspector:
npm run inspect
```

**Connect from Claude Desktop** — add to `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "aiqo": {
      "command": "node",
      "args": ["/absolute/path/to/AiQo/ai/mcp/server.mjs"],
      "env": { "AIQO_BASE": "https://aiqo.app" }
    }
  }
}
```
Restart Claude Desktop; the AiQo tools appear in the tools menu.

> Set `AIQO_BASE=http://localhost:3000` to test against a local `aiqo-web` dev server.

---

## 4. Design principles (why it's safe)

- **Read-only & public.** Only the no-auth knowledge surface is exposed. No health data, no account access, no model quota.
- **Single source of truth.** The server fetches the same JSON the website serves, so MCP answers can never drift from the Custom GPT or the site.
- **No secrets in the server.** Nothing sensitive is bundled; the server can be shared freely.

---

## 5. Roadmap — a personal MCP server (planned)

A second server, `aiqo-personal`, would expose per-user tools behind OAuth — mirroring the `personal` tag in [`../schemas/OPENAPI_SPEC.yaml`](../schemas/OPENAPI_SPEC.yaml):

| Planned tool | Maps to | Scope |
|---|---|---|
| `aiqo_my_health_summary` | `GET /api/v1/me/health-summary` | `health:read` |
| `aiqo_ask_captain` | `POST /api/v1/me/captain/ask` | `captain:chat` |
| `aiqo_log_water` | `POST /api/v1/me/water` | `log:write` |

Prerequisites (same as the personal API in the GPT guide): an OAuth 2.0 server backed by Supabase Auth, the three endpoint implementations, a consented health-summary sync, and a privacy review. MCP supports OAuth-based auth for remote servers, so this slots in cleanly once the API exists.

---

## 6. Readiness scorecard

| Capability | Status |
|---|---|
| Public knowledge over MCP | ✅ shipped (scaffold) |
| Official SDK, stdio transport | ✅ |
| Claude Desktop / IDE compatible | ✅ |
| Remote (HTTP/SSE) transport | ⚪ add when hosting remotely |
| Per-user tools (OAuth) | 🟡 designed, not built |
| Write actions (log water, etc.) | 🟡 designed, not built |

**Bottom line:** AiQo is MCP-ready for knowledge today, and architected for a clean OAuth-gated personal server next.
