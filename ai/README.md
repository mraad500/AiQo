# AiQo · AI Integration Hub (`/ai`)

> **Start here.** This directory is the single home for everything needed to understand AiQo as an AI system and to connect GPT technologies (Custom GPTs, OpenAI Actions, MCP, agents) to it. It is written for both humans and AI systems.
>
> **AiQo** is an Arabic-first, AI-native health companion for iOS, built around **Captain Hamoudi** — an AI coach who speaks the user's own Iraqi/Gulf Arabic dialect, remembers their journey, and reasons over their Apple Health data. Positioned as a **Bio-Digital Operating System**, not a fitness tracker.

---

## 🚀 I want to… (task → file)

| I want to… | Go to |
|---|---|
| **Understand AiQo fast** | [knowledge/AIQO_KNOWLEDGE_BASE.md](knowledge/AIQO_KNOWLEDGE_BASE.md) (TL;DR + index) |
| **Build a Custom GPT for AiQo** | [documentation/GPT_INTEGRATION_GUIDE.md](documentation/GPT_INTEGRATION_GUIDE.md) §1 |
| **Import OpenAI Actions** | [actions/OPENAI_ACTIONS_SCHEMA.json](actions/OPENAI_ACTIONS_SCHEMA.json) (paste into GPT Builder) |
| **See the full API contract** | [schemas/OPENAPI_SPEC.yaml](schemas/OPENAPI_SPEC.yaml) |
| **Run an MCP server** | [mcp/](mcp/) + [documentation/MCP_READINESS_GUIDE.md](documentation/MCP_READINESS_GUIDE.md) |
| **Design an agent on AiQo** | [documentation/AGENT_ARCHITECTURE.md](documentation/AGENT_ARCHITECTURE.md) |
| **Understand the iOS architecture** | [documentation/AIQO_SYSTEM_ARCHITECTURE.md](documentation/AIQO_SYSTEM_ARCHITECTURE.md) |
| **Get ready-made prompts** | [prompts/](prompts/) |
| **Read the program reports** | [reports/](reports/) |
| **Regenerate / validate the assets** | [scripts/](scripts/) |

---

## 📂 Layout

```
ai/
├── README.md                         ← you are here
├── knowledge/                        ← GPT-optimized product knowledge (human-readable)
│   ├── AIQO_KNOWLEDGE_BASE.md         (master index + TL;DR)
│   ├── AIQO_PRODUCT_VISION.md
│   ├── CAPTAIN_HAMMOUDI_PROFILE.md
│   ├── AIQO_FEATURES.md
│   ├── AIQO_USER_FLOWS.md
│   ├── AIQO_GLOSSARY.md
│   └── AIQO_FAQ.md
├── documentation/                    ← integration + architecture guides
│   ├── GPT_INTEGRATION_GUIDE.md
│   ├── MCP_READINESS_GUIDE.md
│   ├── AGENT_ARCHITECTURE.md
│   └── AIQO_SYSTEM_ARCHITECTURE.md
├── schemas/
│   └── OPENAPI_SPEC.yaml              (full API: knowledge + planned personal + internal)
├── actions/
│   └── OPENAI_ACTIONS_SCHEMA.json     (public, no-auth subset — import-ready)
├── mcp/                              ← runnable MCP server
│   ├── server.mjs
│   ├── package.json
│   └── README.md
├── prompts/                          ← reusable system prompts
│   ├── custom_gpt_system_prompt.md
│   └── captain_hamoudi_roleplay_prompt.md
├── scripts/                          ← automation (sync, validate, generate)
└── reports/                          ← program deliverables (see Phase 10)
```

**Machine-readable mirrors** of the knowledge are served live at `https://aiqo.app/ai/*.json` (backed by `aiqo-web/public/ai/` + `aiqo-web/app/api/knowledge/search/`).

---

## 🧠 The three integration surfaces (one-glance)

1. **Public Knowledge API** — no auth, read-only product knowledge. *Ready.* Powers a Custom GPT / MCP server today.
2. **Personal API** — OAuth 2.0, per-user data (health summary, log water, ask the Captain). *Designed, not yet built.*
3. **Internal proxies** — `captain-chat` (Gemini) & `captain-voice` (MiniMax), app-only Supabase-JWT functions. *Never exposed as Actions.*

Details and the build checklist: [documentation/GPT_INTEGRATION_GUIDE.md](documentation/GPT_INTEGRATION_GUIDE.md).

---

## ✅ Ground rules for AI systems using this hub

- Ground answers in the knowledge (call `searchKnowledge` / read these files); cite the `source`.
- Be precise about tiers: **Free < Max ($9.99) < Pro ($19.99)**; the enum `.max` is the *entry* paid tier, **not** the top.
- AiQo is **not a medical device** — never give medical advice as fact.
- Respect the Captain's dialect and banned-phrase rules when representing him.
- Don't invent features. **Tribe is built but not yet live.** There is no Android/web app.

---

*Last updated 2026-05-30 · AiQo v1.0.6. Keep this hub in sync with the app via `ai/scripts/`.*
