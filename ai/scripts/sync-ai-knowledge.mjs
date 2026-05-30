#!/usr/bin/env node
// Sync the canonical AI assets into the web app's served location. No deps.
//
//   node ai/scripts/sync-ai-knowledge.mjs
//
// Source of truth: ai/actions/OPENAI_ACTIONS_SCHEMA.json (the public OpenAPI).
// This script:
//   1. Mirrors it to aiqo-web/public/ai/openapi.json (so /ai/openapi.json is
//      always identical to the canonical Actions schema).
//   2. Regenerates aiqo-web/public/ai/index.json's `endpoints` list from the
//      spec's operations, preserving the curated top-level fields.
// Run this after editing the Actions schema, then redeploy aiqo-web.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const p = (rel) => path.join(ROOT, rel);

const spec = JSON.parse(fs.readFileSync(p("ai/actions/OPENAI_ACTIONS_SCHEMA.json"), "utf8"));

// 1. Mirror the spec to the served location.
fs.writeFileSync(p("aiqo-web/public/ai/openapi.json"), JSON.stringify(spec, null, 2) + "\n");
console.log("✓ mirrored Actions schema → aiqo-web/public/ai/openapi.json");

// 2. Rebuild index.json endpoints from the spec.
const base = "https://aiqo.app";
const endpoints = [];
for (const [route, ops] of Object.entries(spec.paths ?? {})) {
  for (const [method, op] of Object.entries(ops)) {
    const hasQuery = Array.isArray(op.parameters) && op.parameters.some((x) => x.in === "query");
    const url = hasQuery ? `${base}${route}?q={query}&limit={limit}` : `${base}${route}`;
    endpoints.push({
      operationId: op.operationId,
      method: method.toUpperCase(),
      url,
      description: op.summary ?? "",
    });
  }
}

const indexPath = p("aiqo-web/public/ai/index.json");
const index = JSON.parse(fs.readFileSync(indexPath, "utf8"));
index.endpoints = endpoints;
index.updated = process.env.AIQO_BUILD_DATE || index.updated; // pass a date in CI; never auto-stamps
fs.writeFileSync(indexPath, JSON.stringify(index, null, 2) + "\n");
console.log(`✓ rebuilt index.json (${endpoints.length} endpoints)`);

console.log("\nDone. Next: `node ai/scripts/validate-ai-assets.mjs`, then redeploy aiqo-web.");
