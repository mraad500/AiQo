// supabase/functions/captain-voice/index.ts
//
// AiQo Captain voice proxy to MiniMax TTS.
//
// Moves the MiniMax API key server-side so the IPA no longer ships it.
// The iOS app sends its Supabase JWT; we validate it and then call MiniMax
// with the server-held key. Response is passed through as-is so the existing
// client decoder (hex → Data → AVAudioPlayer) keeps working unchanged.
//
// Deploy:
//   supabase functions deploy captain-voice --no-verify-jwt
//
// Required secrets:
//   - SUPABASE_URL                 (auto-populated by Supabase)
//   - SUPABASE_ANON_KEY            (auto-populated by Supabase)
//   - MINIMAX_API_KEY              (set with: supabase secrets set MINIMAX_API_KEY=…)
//   - MINIMAX_API_URL              (optional; defaults to the v2 T2A endpoint)

import { corsHeaders, handlePreflight } from "../_shared/cors.ts";
import { authenticateRequest, AuthError, jsonError } from "../_shared/auth.ts";

const DEFAULT_MINIMAX_URL = "https://api.minimax.io/v1/t2a_v2";

// Allowlisted MiniMax model IDs — mirrors the Swift supportedModels set in
// MiniMaxVoiceConfiguration. Add a new model here first, then in the app,
// so a compromised proxy URL can't route through unsupported variants.
const ALLOWED_MODELS = new Set([
  "speech-2.8-hd",
  "speech-2.8-turbo",
  "speech-2.6-hd",
  "speech-2.6-turbo",
  "speech-02-hd",
  "speech-02-turbo",
  "speech-01-hd",
  "speech-01-turbo",
]);

// The Captain voice path sends a short text cue (coaching phrase or summary
// sentence). 16 KB is more than enough and defends against abuse.
const MAX_BODY_BYTES = 16 * 1024;

interface MiniMaxPayload {
  model?: unknown;
  text?: unknown;
}

Deno.serve(async (request: Request) => {
  const preflight = handlePreflight(request);
  if (preflight) return preflight;

  if (request.method !== "POST") {
    return jsonError(405, "method_not_allowed");
  }

  const contentLength = Number(request.headers.get("content-length") ?? 0);
  if (contentLength > MAX_BODY_BYTES) {
    return jsonError(413, "payload_too_large");
  }

  let user;
  try {
    user = await authenticateRequest(request);
  } catch (error) {
    if (error instanceof AuthError) {
      return jsonError(error.status, error.message);
    }
    return jsonError(500, "auth_unexpected");
  }

  let body: MiniMaxPayload;
  try {
    body = await request.json() as MiniMaxPayload;
  } catch {
    return jsonError(400, "invalid_json");
  }

  const model = typeof body.model === "string" ? body.model : "";
  if (!ALLOWED_MODELS.has(model)) {
    return jsonError(400, "model_not_allowed");
  }

  if (typeof body.text !== "string" || body.text.trim().length === 0) {
    return jsonError(400, "missing_text");
  }

  const minimaxKey = Deno.env.get("MINIMAX_API_KEY");
  const minimaxURL = Deno.env.get("MINIMAX_API_URL") ?? DEFAULT_MINIMAX_URL;
  if (!minimaxKey) {
    return jsonError(500, "upstream_key_missing");
  }

  const upstreamResponse = await fetch(minimaxURL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${minimaxKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  console.log(
    JSON.stringify({
      event: "captain_voice_proxy",
      user: user.id,
      model,
      status: upstreamResponse.status,
    }),
  );

  const upstreamBody = await upstreamResponse.text();
  return new Response(upstreamBody, {
    status: upstreamResponse.status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
});
