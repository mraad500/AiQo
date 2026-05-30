# AiQo — AI Automation Scripts

Zero-dependency Node ESM scripts (Node ≥18) that keep the AI integration assets
consistent and deployable. Run from the repo root.

| Script | What it does |
|---|---|
| `validate-ai-assets.mjs` | Validates all knowledge JSON, the OpenAPI/Actions schemas, operationId parity, tier sanity, and index references. CI-friendly (exits non-zero on failure). |
| `sync-ai-knowledge.mjs` | Mirrors the canonical Actions schema → `aiqo-web/public/ai/openapi.json` and rebuilds `index.json`'s endpoint list. Run after editing the Actions schema. |
| `build-context-pack.mjs` | Concatenates `ai/knowledge/*.md` into `aiqo-web/public/ai/context.md` for one-shot LLM ingestion. |

## Typical workflow

```bash
# After changing the product or the knowledge files:
#  1. edit ai/knowledge/*.md  (human-readable source of truth)
#  2. edit aiqo-web/public/ai/*.json  (machine-readable mirror) and/or the Actions schema
node ai/scripts/sync-ai-knowledge.mjs     # keep openapi.json + index.json in sync
node ai/scripts/build-context-pack.mjs    # regenerate the combined context pack
node ai/scripts/validate-ai-assets.mjs    # gate before committing / deploying
# then push aiqo-web to deploy (auto-deploys to Vercel)
```

## CI suggestion

Add `node ai/scripts/validate-ai-assets.mjs` to a CI step so a malformed
knowledge asset fails the build before it reaches production. (Pass a build date
via `AIQO_BUILD_DATE` to `sync-ai-knowledge.mjs` if you want `index.json.updated`
stamped in CI.)

## Source-of-truth model

- **Human-readable:** `ai/knowledge/*.md` + `ai/documentation/*.md`.
- **Machine-readable (served):** `aiqo-web/public/ai/*.json`, `/llms.txt`, `/.well-known/ai-plugin.json`.
- **Canonical API contract:** `ai/schemas/OPENAPI_SPEC.yaml` (full) and `ai/actions/OPENAI_ACTIONS_SCHEMA.json` (public subset). The web `openapi.json` is generated from the latter.
