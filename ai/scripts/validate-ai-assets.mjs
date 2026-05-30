#!/usr/bin/env node
// Validate every AiQo AI integration asset. No dependencies.
//
//   node ai/scripts/validate-ai-assets.mjs
//
// Checks:
//   1. All published knowledge JSON parses.
//   2. The OpenAPI spec (YAML) and Actions schema (JSON) have the expected shape.
//   3. The public openapi.json operationIds match the canonical Actions schema.
//   4. Every feature.minTier and pricing tier id is a known tier.
//   5. The static endpoints referenced by index.json exist on disk.
// Exits non-zero on any failure (CI-friendly).

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const TIERS = new Set(["free", "trial", "max", "pro"]);
let failures = 0;
const ok = (m) => console.log(`  ✓ ${m}`);
const bad = (m) => { console.error(`  ✗ ${m}`); failures++; };

function readJson(rel) {
  return JSON.parse(fs.readFileSync(path.join(ROOT, rel), "utf8"));
}

console.log("AiQo AI assets — validation\n");

// 1. Knowledge JSON parses.
const jsonFiles = [
  "aiqo-web/public/ai/info.json",
  "aiqo-web/public/ai/features.json",
  "aiqo-web/public/ai/pricing.json",
  "aiqo-web/public/ai/captain.json",
  "aiqo-web/public/ai/glossary.json",
  "aiqo-web/public/ai/faq.json",
  "aiqo-web/public/ai/index.json",
  "aiqo-web/public/ai/openapi.json",
  "aiqo-web/public/.well-known/ai-plugin.json",
  "ai/actions/OPENAI_ACTIONS_SCHEMA.json",
];
const data = {};
for (const f of jsonFiles) {
  try { data[f] = readJson(f); ok(`parsed ${f}`); }
  catch (e) { bad(`parse ${f}: ${e.message}`); }
}

// 2. OpenAPI YAML shape.
try {
  const yaml = fs.readFileSync(path.join(ROOT, "ai/schemas/OPENAPI_SPEC.yaml"), "utf8");
  for (const k of ["openapi:", "info:", "paths:", "components:"]) {
    if (!yaml.includes(k)) bad(`OPENAPI_SPEC.yaml missing '${k}'`);
  }
  if (!failures) ok("OPENAPI_SPEC.yaml structure present");
} catch (e) { bad(`read OPENAPI_SPEC.yaml: ${e.message}`); }

// 3. operationId parity between the canonical Actions schema and public openapi.json.
const opsOf = (doc) => new Set(Object.values(doc.paths ?? {}).flatMap((p) => Object.values(p).map((op) => op.operationId)));
const actions = data["ai/actions/OPENAI_ACTIONS_SCHEMA.json"];
const publicSpec = data["aiqo-web/public/ai/openapi.json"];
if (actions && publicSpec) {
  const a = opsOf(actions), b = opsOf(publicSpec);
  const missing = [...a].filter((x) => !b.has(x));
  if (missing.length) bad(`public openapi.json missing operationIds: ${missing.join(", ")} (run sync-ai-knowledge.mjs)`);
  else ok(`operationId parity (${a.size} operations)`);
}

// 4. Tier sanity.
const features = data["aiqo-web/public/ai/features.json"]?.features ?? [];
for (const f of features) if (!TIERS.has(f.minTier)) bad(`feature '${f.id}' has unknown tier '${f.minTier}'`);
if (features.length && !failures) ok(`${features.length} features have valid tiers`);
const tiers = data["aiqo-web/public/ai/pricing.json"]?.tiers ?? [];
for (const t of tiers) if (!TIERS.has(t.id)) bad(`pricing tier '${t.name}' has unknown id '${t.id}'`);
if (tiers.length) ok(`${tiers.length} pricing tiers present`);

// 5. index.json static endpoints exist.
const endpoints = data["aiqo-web/public/ai/index.json"]?.endpoints ?? [];
for (const e of endpoints) {
  const m = (e.url ?? "").match(/^https:\/\/aiqo\.app(\/ai\/[a-z]+\.json)$/);
  if (m && !fs.existsSync(path.join(ROOT, "aiqo-web/public" + m[1]))) {
    bad(`index.json references missing file ${m[1]}`);
  }
}
ok(`index.json references checked (${endpoints.length} endpoints)`);

console.log(failures ? `\nFAILED with ${failures} issue(s).` : "\nAll AI assets valid. ✅");
process.exit(failures ? 1 : 0);
