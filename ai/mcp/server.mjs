#!/usr/bin/env node
// AiQo Knowledge — Model Context Protocol (MCP) server.
//
// Exposes the public AiQo knowledge API as MCP tools and resources so any
// MCP-compatible client (Claude Desktop, IDEs, agents) can answer questions
// about AiQo. It is a thin, read-only client of https://aiqo.app/ai/* — no
// user data, no secrets, no LLM calls.
//
// Run:   npm install && AIQO_BASE=https://aiqo.app node server.mjs
// Debug: npm run inspect
//
// Claude Desktop config (claude_desktop_config.json):
//   { "mcpServers": { "aiqo": { "command": "node",
//       "args": ["/abs/path/to/ai/mcp/server.mjs"],
//       "env": { "AIQO_BASE": "https://aiqo.app" } } } }

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const BASE = (process.env.AIQO_BASE ?? "https://aiqo.app").replace(/\/$/, "");

async function getJson(path) {
  const res = await fetch(`${BASE}${path}`, { headers: { accept: "application/json" } });
  if (!res.ok) throw new Error(`AiQo API ${path} returned ${res.status}`);
  return res.json();
}

function ok(data) {
  return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
}
function fail(err) {
  return {
    isError: true,
    content: [{ type: "text", text: `AiQo knowledge lookup failed: ${err?.message ?? String(err)}` }],
  };
}

const server = new McpServer({
  name: "aiqo-knowledge",
  version: "1.0.0",
});

server.tool(
  "aiqo_search",
  "Search the AiQo knowledge base (features, pricing, Captain Hamoudi, glossary, FAQ, vision). Returns ranked chunks with a citable source. Use this first for any specific question about AiQo.",
  { query: z.string().min(2).describe("Natural-language question or keywords"), limit: z.number().int().min(1).max(10).optional().describe("Max results (default 5)") },
  async ({ query, limit }) => {
    try {
      const params = new URLSearchParams({ q: query, limit: String(limit ?? 5) });
      return ok(await getJson(`/api/knowledge/search?${params}`));
    } catch (e) { return fail(e); }
  },
);

server.tool(
  "aiqo_info",
  "Get the AiQo product overview: name, tagline, the Bio-Digital OS philosophy, platforms, language, and privacy summary.",
  {},
  async () => { try { return ok(await getJson("/ai/info.json")); } catch (e) { return fail(e); } },
);

server.tool(
  "aiqo_features",
  "List every AiQo feature with the minimum subscription tier each requires.",
  {},
  async () => { try { return ok(await getJson("/ai/features.json")); } catch (e) { return fail(e); } },
);

server.tool(
  "aiqo_pricing",
  "Get AiQo subscription tiers and pricing (Free, 7-day Trial, Max $9.99, Intelligence Pro $19.99). Note: Pro is the higher tier.",
  {},
  async () => { try { return ok(await getJson("/ai/pricing.json")); } catch (e) { return fail(e); } },
);

server.tool(
  "aiqo_captain",
  "Get the Captain Hamoudi persona profile: role, Iraqi-Arabic dialect, capabilities, and safety posture.",
  {},
  async () => { try { return ok(await getJson("/ai/captain.json")); } catch (e) { return fail(e); } },
);

server.tool(
  "aiqo_glossary",
  "Get the AiQo glossary of product-specific terms and definitions.",
  {},
  async () => { try { return ok(await getJson("/ai/glossary.json")); } catch (e) { return fail(e); } },
);

server.tool(
  "aiqo_faq",
  "List AiQo frequently asked questions and answers, grouped by category.",
  {},
  async () => { try { return ok(await getJson("/ai/faq.json")); } catch (e) { return fail(e); } },
);

// Expose the product overview as a readable resource too.
server.resource(
  "aiqo-info",
  "aiqo://info",
  { mimeType: "application/json", description: "AiQo product overview" },
  async (uri) => {
    const data = await getJson("/ai/info.json");
    return { contents: [{ uri: uri.href, mimeType: "application/json", text: JSON.stringify(data, null, 2) }] };
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[aiqo-knowledge-mcp] connected · base=${BASE}`);
