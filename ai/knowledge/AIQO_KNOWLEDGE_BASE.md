# AiQo Knowledge Base

> **Read this first.** This is the canonical, GPT-optimized knowledge base for **AiQo** — an Arabic-first, AI-native health companion for iOS. It is written to be consumed by AI systems (Custom GPTs, OpenAI Actions, MCP servers, autonomous agents) as well as new engineers.
>
> **Last updated:** 2026-05-30 · **App version:** 1.0.6 (build 29) · **Source of truth:** the AiQo repository + [aiqo.app](https://aiqo.app)

---

## 0. TL;DR (for fast grounding)

- **What it is:** AiQo is a **Bio-Digital Operating System** — a personal health companion built around **Captain Hamoudi** (كابتن حمودي), an AI coach that speaks the user's own **Iraqi/Gulf Arabic dialect**, remembers their journey, and reasons over their Apple Health data.
- **Not:** a calorie counter, a step tracker, a translated Western fitness app, or a thin ChatGPT wrapper.
- **Platform:** iOS 26+ and watchOS. Built in SwiftUI + SwiftData. iOS-only (no Android, no web app).
- **AI:** Hybrid brain — **Apple Intelligence on-device** (sleep, fallback, privacy-sensitive work) + **Google Gemini in the cloud** (chat, plans) through a hardened Supabase Edge Function proxy.
- **Tiers:** **Free** → **AiQo Max ($9.99/mo)** → **AiQo Intelligence Pro ($19.99/mo)**, plus a **7-day free trial** (no card charge). ⚠️ Note: *Pro is the higher tier*; the internal enum value `.max` is the **entry** paid tier, not the top.
- **Privacy:** On-device first. PII (names, emails, phones, IDs) is stripped before any cloud call; sleep analysis never leaves the device; health metrics are sent **exactly** (never bucketed). Zero ads, zero data sales.
- **Maker:** Mohammed Raad (Iraqi 🇮🇶, solo founder), designed in the UAE 🇦🇪. Instagram [@aiqoapp](https://instagram.com/aiqoapp).

---

## 1. How this knowledge base is organized

| Document | What it covers | Use it to answer… |
|---|---|---|
| **AIQO_KNOWLEDGE_BASE.md** (this file) | Master index + TL;DR | "What is AiQo?" "Where do I find X?" |
| [AIQO_PRODUCT_VISION.md](AIQO_PRODUCT_VISION.md) | Mission, philosophy, positioning, target user, moats | "Why does AiQo exist?" "Who is it for?" |
| [CAPTAIN_HAMMOUDI_PROFILE.md](CAPTAIN_HAMMOUDI_PROFILE.md) | The Captain persona — identity, dialect, capabilities, safety | "Who is Captain Hamoudi?" "How does he talk?" |
| [AIQO_FEATURES.md](AIQO_FEATURES.md) | Every feature + the tier each requires | "What can AiQo do?" "Is Kitchen free?" |
| [AIQO_USER_FLOWS.md](AIQO_USER_FLOWS.md) | Onboarding, daily loop, key journeys | "How do I set up Smart Wake?" "What happens on day 1?" |
| [AIQO_GLOSSARY.md](AIQO_GLOSSARY.md) | Every AiQo-specific term | "What is a Peak?" "What's a Directive?" |
| [AIQO_FAQ.md](AIQO_FAQ.md) | Frequently asked questions + answers | "Does it need internet?" "Is my health data sold?" |
| [../documentation/AIQO_SYSTEM_ARCHITECTURE.md](../documentation/AIQO_SYSTEM_ARCHITECTURE.md) | Technical architecture for engineers | "How does the brain route?" "Where is memory stored?" |

**Machine-readable mirrors** of this knowledge are published as JSON under `https://aiqo.app/ai/*.json` (see [../actions/OPENAI_ACTIONS_SCHEMA.json](../actions/OPENAI_ACTIONS_SCHEMA.json)) and described by [../schemas/OPENAPI_SPEC.yaml](../schemas/OPENAPI_SPEC.yaml).

---

## 2. Product snapshot

| Attribute | Value |
|---|---|
| Name | AiQo |
| Category | Bio-Digital Operating System (health companion) |
| Tagline (AR) | "ليس تطبيقاً فقط، بل بُعدٌ جديد للصحة" |
| Tagline (EN) | "Not just an app — a new dimension for health." |
| Hero AI | Captain Hamoudi (كابتن حمودي) |
| Primary language | Arabic (Iraqi/Gulf dialect, RTL); English supported |
| Platforms | iOS 26+, watchOS (Apple Watch optional) |
| App Store | https://apps.apple.com/ae/app/aiqo/id6755132504 |
| Website | https://aiqo.app |
| Company / origin | AiQo — designed in the UAE 🇦🇪 |
| Founder & CEO | Mohammed Raad 🇮🇶 |
| Social | Instagram [@aiqoapp](https://instagram.com/aiqoapp) |
| Support | https://aiqo.app/support · support@aiqo.app |

---

## 3. Pricing at a glance

| Tier | Price | Internal enum | What it unlocks |
|---|---|---|---|
| **Free** | $0 | `.none` (rank 0) | Home dashboard, Apple Health tracking, XP & levels, daily quests, Learning Spark, progress photos, basic hydration, a weekly Sunday recap notification. **No Captain chat.** |
| **Trial** | Free, 7 days | `.trial` (rank 2) | Full **Pro-equivalent** access. No charge during the trial (an App Store payment method is required, like any subscription). One trial per Apple ID. |
| **AiQo Max** | **$9.99/mo** | `.max` (rank 1) | Everything in Free **+** full Captain Hamoudi chat, Captain memory (~200 facts), Captain voice, full Gym & workouts, full Kitchen, full Sleep (Smart Wake + analysis), all notifications, My Vibe, Apple Watch app, Battle, **view-only** Peaks. |
| **AiQo Intelligence Pro** | **$19.99/mo** *(Most Popular)* | `.pro` (rank 3) | Everything in Max **+** advanced AI model, extended memory (~500 facts), premium voice, weekly insight narratives, multi-week workout plans, photo/form analysis, **full Peaks (Legendary Challenges)**, Directives, early access to new features. |

> **Engineer note:** the `SubscriptionTier` enum is `none(0) < max(1) < trial(2) < pro(3)`. The name `.max` is historical and means the *entry* paid tier — it is **not** the maximum. The top tier is `.pro`. Always compare by `rank`, never by name.

---

## 4. Trust & privacy summary

- **On-device first:** Apple Intelligence (Foundation Models) handles sleep analysis and on-device chat/fallback. Sleep stage data **never** leaves the device.
- **Anonymized cloud:** Before any cloud (Gemini) call, a `PrivacySanitizer` redacts emails, phone numbers, UUIDs, and IPs, and replaces names with "User". The conversation is capped (~16 messages / ~6000 chars).
- **Exact metrics:** Health metrics (steps, calories, heart rate, sleep durations) are forwarded **exactly**, never bucketed — the privacy boundary is consent + PII redaction, not data degradation. (Changed in v1.0.6.)
- **Keys are server-side:** Gemini and MiniMax (voice) API keys live in Supabase Edge Functions, not in the app binary. The app authenticates with its Supabase session JWT.
- **Business model:** subscription only. **No ads, no data sales, ever.** Full export and deletion on request.

---

## 5. Guidance for AI systems answering about AiQo

1. **Ground answers in this knowledge base.** Prefer the `searchKnowledge` action (or these files) over prior assumptions. Cite the source document.
2. **Respect the dialect.** When quoting or roleplaying Captain Hamoudi, use Iraqi/Gulf Arabic, never Modern Standard Arabic, and never the banned phrases listed in [CAPTAIN_HAMMOUDI_PROFILE.md](CAPTAIN_HAMMOUDI_PROFILE.md).
3. **Be precise about tiers.** Free has no Captain chat. Max is $9.99 and is the entry paid tier. Pro is $19.99 and is the top tier. Peaks (full) and the advanced model are Pro-only.
4. **Never give medical advice as fact.** AiQo is **not a medical device**. For health-sensitive questions, recommend a professional and reflect the Captain's safety posture.
5. **Don't expose internals as user-facing.** Raw health variables and internal model names are for calibration; speak about them conversationally, not as a data dump.
6. **No invented features.** If something isn't in this knowledge base, say so rather than guessing. Tribe, for example, is built but **not yet live** (gated behind feature flags).

---

## 6. Provenance

This knowledge base is synthesized from the AiQo repository's internal documentation set (`docs/ai-context/`, `AiQo_Master_Blueprint.md`, `CHANGELOG.md`), the live marketing site ([aiqo.app](https://aiqo.app)), and a direct read of the iOS source and Supabase Edge Functions. Where the marketing site and internal docs differed (e.g. memory-fact counts), the **user-facing** figures from the website are used here so that a support/marketing GPT tells users what they are actually promised.
