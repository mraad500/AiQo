# AiQo Cloud-Proxy Deployment Runbook

*Created 2026-04-23 as part of Package C — Gemini + MiniMax API-key hardening.*

## What this is

Two Supabase Edge Functions (`captain-chat`, `captain-voice`) that proxy AiQo's Gemini + MiniMax calls. The app authenticates with its Supabase JWT; the Edge Functions hold the actual API keys server-side. After this ships, **the IPA will no longer contain Gemini or MiniMax API keys.**

## Why it matters

Currently `Secrets.xcconfig` populates `CAPTAIN_API_KEY` (Gemini) and `CAPTAIN_VOICE_API_KEY` (MiniMax) into `Info.plist` at build time. Anyone who extracts a shipped `.ipa` can recover these keys and burn your Gemini / MiniMax quotas.

Moving to a proxy closes that hole. The `.ipa` only contains the Supabase anon key (which is public by design — it's scoped to a single project and requires user auth for privileged actions).

## Architecture

```
┌───────────────────────────┐
│  iOS app (authenticated)  │
│  Supabase JWT in header   │
└─────────────┬─────────────┘
              │ POST /functions/v1/captain-chat
              │ POST /functions/v1/captain-voice
              ▼
┌───────────────────────────┐
│  Supabase Edge Functions  │
│  - validate JWT           │
│  - model allowlist check  │
│  - body size limit        │
└─────────────┬─────────────┘
              │ forwards with server-held key
              ▼
┌───────────────────────────┐
│     Gemini / MiniMax      │
└───────────────────────────┘
```

## Prerequisites

- Supabase CLI installed (`brew install supabase/tap/supabase`)
- Logged in: `supabase login`
- Linked to your project: `supabase link --project-ref <your-project-ref>`
- New, rotated Gemini + MiniMax keys ready (the old keys are compromised and must be deactivated)

## Step-by-step deploy

### 1. Set the Edge Function secrets

Never commit these. Set them on Supabase itself:

```bash
supabase secrets set GEMINI_API_KEY=<your-rotated-gemini-key>
supabase secrets set MINIMAX_API_KEY=<your-rotated-minimax-key>

# Optional — only if you use a non-default MiniMax endpoint
supabase secrets set MINIMAX_API_URL=https://api.minimax.io/v1/t2a_v2
```

Verify:

```bash
supabase secrets list
# Expect: GEMINI_API_KEY, MINIMAX_API_KEY, MINIMAX_API_URL (if set)
#         plus the auto-populated SUPABASE_URL, SUPABASE_ANON_KEY.
```

### 2. Deploy both functions

```bash
cd /Users/mohammedraad/Desktop/AiQo
supabase functions deploy captain-chat  --no-verify-jwt
supabase functions deploy captain-voice --no-verify-jwt
```

The `--no-verify-jwt` flag skips Supabase's gateway-level JWT check because the functions call `authenticateRequest()` themselves — this lets them return structured error codes instead of an opaque 401.

### 3. Smoke-test the endpoints

Get a test JWT from a real signed-in iOS device (log out and back in; copy `session.accessToken` via a debug print), then:

```bash
# Replace <jwt> and <project-ref> + <anon-key>.
curl -X POST "https://<project-ref>.supabase.co/functions/v1/captain-chat" \
  -H "Authorization: Bearer <jwt>" \
  -H "apikey: <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-2.5-flash",
    "payload": {
      "contents": [{ "role": "user", "parts": [{ "text": "Say hi in one word." }] }]
    }
  }'

# Expect: a 200 with Gemini's JSON response, containing a "candidates" array.
```

Repeat for `captain-voice`:

```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/captain-voice" \
  -H "Authorization: Bearer <jwt>" \
  -H "apikey: <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "speech-2.5-hd",
    "text": "مرحبا",
    "voice_setting": { "voice_id": "<your-voice-id>" },
    "audio_setting": { "sample_rate": 32000, "bitrate": 128000, "format": "mp3", "channel": 1 },
    "output_format": "hex"
  }'

# Expect: a 200 with MiniMax's JSON response containing a "data.audio" hex string.
```

### 4. Flip the app flag

Edit `Configuration/Secrets.xcconfig` (NOT `AiQo.xcconfig`) and set:

```
USE_CLOUD_PROXY = YES
```

Build + run. The app should now log `gemini_request via=proxy` instead of `via=direct`. MiniMax behaves the same — the router's existing fallback handles any transient proxy failure.

### 5. Ship to TestFlight, monitor, then purge the old keys

- Ship a TestFlight build with `USE_CLOUD_PROXY = YES`.
- Watch Supabase function logs (`supabase functions logs captain-chat --tail`) for anomalies.
- After 24–48 h with no issues, **delete the old client-side keys from `Secrets.xcconfig`**:
  - `CAPTAIN_API_KEY`
  - `CAPTAIN_VOICE_API_KEY`
  - (`COACH_BRAIN_LLM_API_KEY` too if duplicated)
- Ship one more build. At this point the IPA carries zero third-party API credentials.

### 6. Rotate (if not already done)

**Do this even if the TestFlight rollout is smooth.** The old keys were in every shipped IPA — assume they're compromised:

- Rotate the Gemini API key in Google AI Studio → revoke the old one.
- Rotate the MiniMax API key in MiniMax dashboard → revoke the old one.
- Update `GEMINI_API_KEY` and `MINIMAX_API_KEY` Edge Function secrets.

## Rollback

If anything goes wrong at any step, flip `USE_CLOUD_PROXY = NO` in `Secrets.xcconfig` and rebuild. The legacy direct path is retained until step 5, so rollback is instant.

## Security posture after deploy

| Surface | Before | After |
|---|---|---|
| Gemini key location | Inside every IPA | Server-side on Supabase (never in IPA) |
| MiniMax key location | Inside every IPA | Server-side on Supabase |
| User authentication | None (raw API key) | Supabase JWT (per-user) |
| Abuse risk | Any IPA extraction → quota burn | Requires a valid Supabase session |
| Rate limiting | None | Can be added per-user in Edge Function |
| Revocation | Rotate key + push new IPA | Rotate key in Supabase secret (no app update) |

## Function design notes

**Allowlists.** Both functions hard-code the set of models the app is allowed to request. An attacker who steals a valid JWT can still only use the models AiQo uses — not e.g. Gemini Pro vision or unreleased variants.

**Size caps.** `captain-chat` caps bodies at 256 KB, `captain-voice` at 16 KB. Both well above real traffic; both reject obvious abuse.

**Auth helper.** `_shared/auth.ts` validates the JWT against Supabase's auth API. Returns `AuthenticatedUser { id, email, jwt }`. The `user.id` is logged (not the JWT) for audit.

**No payload logging.** Function logs include `{event, user, model, status}` only — never the prompt, conversation, or response. User content stays private even from ops.

## Future work (not in scope today)

- Rate limits per user (Supabase Edge has basic `fetch`-level rate limiting).
- Cost tracking per user (add a `captain_usage` table and record `tokens_in/out` on success).
- Streaming responses (Gemini supports `generateContentStream` — current function is non-streaming to match the iOS client).
- CaptainProxyConfig could also route the Gemini-backed certificate verifier — currently an explicit kill switch keeps that on-device only (see `FeatureFlags.learningVerificationOnDeviceEnabled`).
