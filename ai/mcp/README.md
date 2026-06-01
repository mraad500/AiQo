# aiqo-knowledge-mcp

A Model Context Protocol (MCP) server that exposes the AiQo public knowledge API as MCP tools and resources. Read-only, no secrets, no user data.

## Install & run
```bash
npm install
AIQO_BASE=https://aiqo.app node server.mjs
```

## Debug
```bash
npm run inspect   # opens the MCP Inspector
```

## Claude Desktop
Add to `claude_desktop_config.json`:
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

## Tools
`aiqo_search`, `aiqo_info`, `aiqo_features`, `aiqo_pricing`, `aiqo_captain`, `aiqo_glossary`, `aiqo_faq`
Resource: `aiqo://info`

See [../documentation/MCP_READINESS_GUIDE.md](../documentation/MCP_READINESS_GUIDE.md) for the full picture and the planned OAuth personal server.
