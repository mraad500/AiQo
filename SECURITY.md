# Security Policy

AiQo handles personal health data, so we take security seriously. Thank you for helping keep AiQo and its users safe.

## Reporting a vulnerability

**Please do not open a public GitHub issue for security reports.**

Email **support@aiqo.app** (subject: `SECURITY`) with:

- A description of the issue and its impact.
- Steps to reproduce (proof-of-concept welcome).
- Affected component (iOS app, `aiqo-web`, Supabase Edge Functions, or the AI knowledge API).

We aim to acknowledge within 72 hours and to keep you updated as we investigate. Please give us a reasonable window to remediate before any public disclosure. We do not currently run a paid bug-bounty program, but we credit reporters who wish to be named.

## Scope

In scope:
- The iOS app (`AiQo/`) and its Supabase Edge Functions (`supabase/functions/`).
- The marketing site and AI knowledge API (`aiqo-web/`, `https://aiqo.app/ai/*`, `https://aiqo.app/api/*`).

Out of scope:
- Reports requiring a jailbroken device or physical access.
- Denial-of-service via volumetric traffic.
- Findings in third-party services we don't control (Apple, Supabase, Google, MiniMax, Spotify).

## Our security posture (summary)

- **No secrets in the repo.** API keys (Gemini, MiniMax) live server-side in Supabase Edge Function secrets, never in the app binary or in git. Local secrets use `Configuration/Secrets.xcconfig`, which is git-ignored.
- **Auth.** Edge Functions validate the caller's Supabase session JWT and enforce model allowlists and request-size caps.
- **Privacy.** Personal identifiers are stripped before any cloud AI call; sleep analysis runs entirely on-device; health metrics are not sold or used for ads.
- **Public AI API.** The `/ai/*` and `/api/knowledge/*` endpoints are read-only product knowledge with no user data.

See `ai/reports/SECURITY_REVIEW.md` for the full review.
