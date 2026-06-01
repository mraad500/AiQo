# AiQo — Security Review

> Security audit performed as part of the GPT-integration program. Covers secrets, auth, permissions, privacy, health-data handling, and App Store / OpenAI compliance. **Date:** 2026-05-30. **Verdict: strong posture, no committed secrets, no critical issues.**

---

## 1. Executive verdict

AiQo's security posture is **strong for a pre-launch app**. The most important property — *no live secrets are committed to the repository or its git history* — was verified directly. Secret handling correctly moved API keys server-side. Privacy is enforced in architecture, not just policy. The findings below are **hardening recommendations**, not active vulnerabilities.

| Severity | Count |
|---|---|
| 🔴 Critical (committed live secret, RCE, auth bypass) | **0** |
| 🟠 High | 0 |
| 🟡 Medium (hardening) | 3 |
| 🔵 Low / Info | 6 |

---

## 2. Secrets — verified clean ✅

- **No secrets are tracked or in git history.** `git ls-files` shows `Configuration/Secrets.xcconfig` and `aiqo-web/.env.local` are **not tracked**; `git log --all -S` for the Gemini key string returns **nothing** — it was never committed. `.gitignore` correctly excludes `Configuration/Secrets.xcconfig`, `*.xcconfig.local`, `.env`, and `.env.*`.
- **Live keys exist only in the local, git-ignored `Configuration/Secrets.xcconfig`** (Gemini API key, MiniMax API key). This is the intended pattern.
- **Server-side keys.** The Supabase Edge Functions (`captain-chat`, `captain-voice`) hold `GEMINI_API_KEY` / `MINIMAX_API_KEY` as Supabase secrets (`Deno.env.get`) — they are **not** in the iOS binary. This is the correct design and a real improvement over the old in-binary key.
- **Public-by-design values** (Supabase **anon** key, Spotify **client ID**) are safe to ship — they are publishable identifiers, not secrets.

> 🟡 **Recommendation (precautionary):** the Gemini and MiniMax keys were displayed in a local analysis transcript during this review. They were never exposed publicly, but if you want zero residual risk, **rotate both keys** and move them into a managed secret store (Supabase Vault / 1Password CLI) rather than a plaintext local `.xcconfig`.

---

## 3. Authentication & authorization

- **Edge Functions validate the Supabase JWT in-function** (`_shared/auth.ts` → `supabase.auth.getUser(jwt)`), returning clean error codes. Deployed with `--no-verify-jwt` deliberately so the function owns error semantics. ✅
- **Defense-in-depth on the proxies:** strict **model allowlists** (Gemini: `gemini-2.5-flash`, `gemini-3-flash-preview`; MiniMax: 8 speech models) and **body-size caps** (256 KB chat / 16 KB voice) prevent quota abuse and oversized payloads. ✅
- **Tier gating** is centralized in `TierGate` / `AccessManager`, with the client as the source of truth and server-side receipt validation as non-blocking secondary. Reasonable for the threat model. 🔵
- 🟡 **Recommendation:** add **per-user rate limiting** to the Edge Functions (the code already logs `user.id` for this purpose). Without it, a valid session could exhaust Gemini/MiniMax quota.

---

## 4. Privacy & health data

- **PrivacySanitizer** redacts emails, phones, UUIDs, and IPs and normalizes names to "User" before any cloud call; the conversation is capped (~16 messages / ~6000 chars). ✅
- **Sleep data never leaves the device** — analyzed on-device via Apple Intelligence. ✅
- **Health metrics are sent exactly (not bucketed)** as of v1.0.6. This is acceptable: the privacy boundary is *consent + identifier removal*, and de-identified metrics are not personally identifying on their own. The website's "anonymized cloud requests" claim is consistent with this. ✅
- **Kitchen images** are stripped of EXIF/GPS and re-encoded (≤1280px) before upload. ✅
- 🔵 **Note for the planned personal API:** any endpoint that syncs a health *summary* to the server (for `GET /api/v1/me/health-summary`) is a material change to the current "health stays on-device" promise. It must be explicitly consented, minimized, and reflected in the privacy policy before shipping.

---

## 5. iOS configuration

- **Capabilities:** HealthKit (+ background delivery), Sign in with Apple, Siri, App Groups (`group.aiqo`, `group.com.aiqo.kernel2`). ✅
- **URL schemes:** `aiqo`, `aiqo-spotify` (OAuth callback). ✅
- **App Transport Security:** only `NSAllowsLocalNetworking` — **no blanket ATS exception**. ✅
- **Secrets injected at build time** via `$(VAR)` substitution from the xcconfig into Info.plist; the app rejects unexpanded placeholders. ✅

---

## 6. Web (`aiqo-web`) & the new AI API

- The new public AI endpoints (`/ai/*.json`, `/api/knowledge/search`) are **read-only, no auth, no user data, no LLM calls** — minimal attack surface. ✅
- The search route validates input (`q` length, `limit` clamped 1–10) and sets permissive CORS (`*`) appropriate for public, non-sensitive data. ✅
- 🟡 **Recommendation:** add HTTP **security headers** to `aiqo-web` (`X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Frame-Options: DENY`, and a tuned `Content-Security-Policy`). Deferred from this change because a CSP must be tested against the site's inline JSON-LD and animation libraries to avoid breakage — see NEXT_STEPS.
- 🔵 `aiqo-web/.env.local` (a Vercel OIDC token) is git-ignored and was never committed. ✅

---

## 7. Supply chain

- `aiqo-web` dependencies are current major versions (Next 16.2.3, React 19.2.4, Tailwind 4); no commit-pinned or suspicious packages. 🔵
- Swift Package Manager dependencies are standard (Supabase, etc.). 🔵
- The new MCP scaffold depends only on `@modelcontextprotocol/sdk` + `zod`. 🔵

---

## 8. OpenAI / Custom GPT compliance

- The Custom GPT surface is **public product knowledge only** — no personal data, no medical claims presented as fact, clear "not a medical device" framing in the system prompt and knowledge files. ✅
- The internal Gemini/MiniMax proxies are explicitly **excluded** from the Actions surface, so no third party can route through AiQo's model quota. ✅
- The planned personal API is correctly gated behind OAuth scopes with a consent + privacy-review prerequisite. ✅

---

## 9. App Store compliance (relevant to this work)

- The new AI files are repo/website assets and **do not change the iOS binary** — no App Review impact. ✅
- HealthKit usage strings, Sign in with Apple, subscription disclosures, and privacy-policy/ToS URLs are present (tracked in `docs/appstore/`). 🔵 (Outside this program's scope; flagged for the release checklist.)

---

## 10. Prioritized actions

| Priority | Action | Owner | Risk if skipped |
|---|---|---|---|
| 🟡 1 | Rotate Gemini + MiniMax keys (precautionary) and move to a managed secret store | Founder | Low (keys never leaked publicly) |
| 🟡 2 | Add per-user rate limiting to Edge Functions | Backend | Quota exhaustion by a valid user |
| 🟡 3 | Add web security headers (with a tested CSP) | Web | Defense-in-depth gap |
| 🔵 4 | Add `node ai/scripts/validate-ai-assets.mjs` + a secret-scanner (e.g. gitleaks) to CI | DevOps | Drift / accidental future leak |
| 🔵 5 | Privacy review before the personal (OAuth) API ships | Founder | Consent/policy gap |

**Bottom line:** nothing blocks the GPT integration or the release. The recommendations are incremental hardening.
