// supabase/functions/captain-chat/index.ts
//
// AiQo Captain chat + memory-extraction proxy to Google Gemini.
//
// Why this function exists:
//   The iOS app used to call `generativelanguage.googleapis.com` directly with
//   the Gemini API key shipped inside the binary (via Info.plist injection).
//   Anyone could extract the IPA and exfiltrate the key, then burn our quota.
//   This function moves the key server-side: the app sends its Supabase JWT,
//   we validate it, then we call Gemini with the server-held key.
//
// Deploy:
//   supabase functions deploy captain-chat --no-verify-jwt
//   (We verify the JWT ourselves inside the function so we can return custom
//   error codes; --no-verify-jwt skips the built-in gateway check.)
//
// Required secrets:
//   - SUPABASE_URL            (auto-populated by Supabase)
//   - SUPABASE_ANON_KEY       (auto-populated by Supabase)
//   - GEMINI_API_KEY          (set with: supabase secrets set GEMINI_API_KEY=…)

import { corsHeaders, handlePreflight } from "../_shared/cors.ts";
import { authenticateRequest, AuthError, jsonError } from "../_shared/auth.ts";

const GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

// Strict allowlist — the app may ONLY request these models. Anything else
// returns 400 so an attacker who learned the proxy URL can't use our Gemini
// quota for arbitrary models (vision, long-context, etc.).
const ALLOWED_MODELS = new Set([
  "gemini-2.5-flash",
  "gemini-3-flash-preview",
]);

// Hard cap on request body size (system prompt + conversation + profile).
// The real app payload is typically 4–12 KB; 256 KB is a generous ceiling
// that still rejects obviously abusive requests.
const MAX_BODY_BYTES = 256 * 1024;

interface ProxyRequestBody {
  model?: unknown;
  payload?: unknown;
}

Deno.serve(async (request: Request) => {
  const preflight = handlePreflight(request);
  if (preflight) return preflight;

  if (request.method !== "POST") {
    return jsonError(405, "method_not_allowed");
  }

  // 1. Size cap (before we parse, so a 50 MB body doesn't OOM us).
  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > MAX_BODY_BYTES) {
    return jsonError(413, "payload_too_large");
  }

  // 2. Authenticate.
  let user;
  try {
    user = await authenticateRequest(request);
  } catch (error) {
    if (error instanceof AuthError) {
      return jsonError(error.status, error.message);
    }
    return jsonError(500, "auth_unexpected");
  }

  // 3. Parse + validate body.
  let body: ProxyRequestBody;
  try {
    body = await request.json() as ProxyRequestBody;
  } catch {
    return jsonError(400, "invalid_json");
  }

  const model = typeof body.model === "string" ? body.model : "";
  if (!ALLOWED_MODELS.has(model)) {
    return jsonError(400, "model_not_allowed");
  }

  if (body.payload == null || typeof body.payload !== "object") {
    return jsonError(400, "missing_payload");
  }

  // 4. Forward to Gemini with the server-held key.
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiKey) {
    return jsonError(500, "upstream_key_missing");
  }

  const upstreamURL = new URL(`${GEMINI_BASE}/${model}:generateContent`);
  const upstreamResponse = await fetch(upstreamURL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": geminiKey,
    },
    body: JSON.stringify(body.payload),
  });

  // Log the outcome (not the payload) for ops. `user.id` is the Supabase user
  // UUID, usable for rate-limit-per-user analysis later.
  console.log(
    JSON.stringify({
      event: "captain_chat_proxy",
      user: user.id,
      model,
      status: upstreamResponse.status,
    }),
  );

  // Pass the upstream response body straight through. Gemini returns a JSON
  // object the app already knows how to decode; we don't rewrap.
  const upstreamBody = await upstreamResponse.text();
  return new Response(upstreamBody, {
    status: upstreamResponse.status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
});
