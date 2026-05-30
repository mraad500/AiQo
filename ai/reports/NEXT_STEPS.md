# AiQo — Next Steps (action checklist)

> Concrete, ordered actions to take the GPT integration from "built locally" to "live." Copy-paste commands included. Nothing here was auto-deployed — these are your decisions to make.

---

## 0. Review (5 min)
- Skim [`ai/README.md`](../README.md) and [`MASTER_AIQO_GPT_REPORT.md`](MASTER_AIQO_GPT_REPORT.md).
- Read [`IMPLEMENTED_CHANGES.md`](IMPLEMENTED_CHANGES.md) for the exact file list.

## 1. Commit the AiQo-repo assets
```bash
cd /Users/mohammedraad/Desktop/AiQo
# already on a feature branch (program/world-class-completion)
git add ai/ SECURITY.md
git commit -m "feat(ai): GPT integration hub — knowledge base, Actions/OpenAPI, MCP, web AI optimization"
```

## 2. Deploy the public knowledge API (aiqo-web)
> `aiqo-web` auto-deploys on push to `main` (GitHub → Vercel). Review the diff first.
```bash
cd /Users/mohammedraad/Desktop/AiQo/aiqo-web
node ../ai/scripts/validate-ai-assets.mjs    # should print "All AI assets valid. ✅"
npm run build                                 # confirm a clean production build
git add app/ public/
git commit -m "feat(ai): AI knowledge API, llms.txt, AI-crawler robots, FAQ/WebSite JSON-LD"
git push origin main                          # triggers Vercel deploy
```
Then verify live:
```bash
curl -s https://aiqo.app/ai/info.json | head
curl -s "https://aiqo.app/api/knowledge/search?q=pricing"
curl -s https://aiqo.app/llms.txt | head
curl -s https://aiqo.app/robots.txt
```

## 3. Publish the "AiQo Guide" Custom GPT (~10 min)
1. ChatGPT → **Explore GPTs → Create → Configure**.
2. **Instructions:** paste [`ai/prompts/custom_gpt_system_prompt.md`](../prompts/custom_gpt_system_prompt.md).
3. **Actions → Create → Schema:** paste all of [`ai/actions/OPENAI_ACTIONS_SCHEMA.json`](../actions/OPENAI_ACTIONS_SCHEMA.json). Auth: **None**.
4. Test: "How much is AiQo?", "Is Kitchen free?", "Who is Captain Hamoudi?", "Does it work offline?"
5. Name it **AiQo Guide**, add the brand portrait, publish.

## 4. (Optional) Run the MCP server
```bash
cd /Users/mohammedraad/Desktop/AiQo/ai/mcp
npm install
AIQO_BASE=https://aiqo.app node server.mjs
```
Add to Claude Desktop's `claude_desktop_config.json` (see [`ai/mcp/README.md`](../mcp/README.md)).

## 5. Security hardening (this week)
- [ ] **Rotate** the Gemini + MiniMax keys (precautionary) and move them to Supabase Vault / a secret manager.
- [ ] Add `node ai/scripts/validate-ai-assets.mjs` + a secret scanner (e.g. gitleaks) to CI.
- [ ] Add web security headers (with a tested CSP) to `aiqo-web`.
- [ ] Add per-user rate limiting to the Edge Functions.
See [`SECURITY_REVIEW.md`](SECURITY_REVIEW.md) §10.

## 6. Keep it in sync (whenever the product changes)
```bash
# 1) edit ai/knowledge/*.md and aiqo-web/public/ai/*.json
node ai/scripts/sync-ai-knowledge.mjs
node ai/scripts/build-context-pack.mjs
node ai/scripts/validate-ai-assets.mjs
# 2) commit + push aiqo-web
```

## 7. Plan the personal (per-user) integration — when ready
- Run a **privacy review** (health data leaving the device is a material change).
- Build the OAuth 2.0 server + `/api/v1/me/*` endpoints per [`GPT_INTEGRATION_GUIDE.md`](../documentation/GPT_INTEGRATION_GUIDE.md) §4.
- Then add OAuth to the GPT and/or ship the `aiqo-personal` MCP server.

---

### Quick wins, ranked
1. **Deploy `aiqo-web`** → instant answer-engine discoverability + a working knowledge API.
2. **Publish the Custom GPT** → a shareable AiQo assistant.
3. **Rotate keys + CI secret scan** → close the only residual security item.
