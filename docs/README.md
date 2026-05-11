# AiQo Documentation

This directory holds AiQo's non-source documentation, organized by purpose.

It is structured to keep the project root clean: only the *current* top-level documents (Blueprint 17, Blueprint 18, AIQO_TECH_DEBT, CHANGELOG, LICENSE) live at the repo root. Everything else — historical working notes, completed audit reports, multi-language explainers — lives here.

For project-level orientation, start at [`/AiQo_Master_Blueprint_18.md`](../AiQo_Master_Blueprint_18.md). It is the canonical forward-looking master document.

---

## Tree

```
docs/
├── archive/              ← Historical working notes, completed audits, deprecated docs
│   ├── app-store/        ← App Store submission audits, reviewer replies, checklists
│   ├── batch-results/    ← BATCH_1..8 result logs from the 2026-04 Brain OS refactor
│   ├── blueprints/       ← Pre-17 blueprint versions (Complete, 16, MyVibe, MyVibe_2)
│   ├── captain-brain/    ← Captain Brain recon, diagnostic, fix reports, chat changelog
│   ├── handoffs/         ← Handoff documents to other contributors / agents
│   └── p-fix/            ← P0/P1/P2 phase result logs + P_MERGE / P_FIX dev-override notes
├── explainers/           ← Product-context explainer series (multi-language)
│   ├── ar/               ← Arabic — شرح شامل لتطبيق AiQo (5 files, 2026-05-09)
│   └── en/               ← English — AiQo_AIContext (8 files, 2026-04-10)
└── security/             ← Reserved for security audits (see Blueprint 18 §4)
```

---

## When to look here

| If you want… | Go to |
|---|---|
| The *current* master plan and roadmap | [`/AiQo_Master_Blueprint_18.md`](../AiQo_Master_Blueprint_18.md) |
| The *deep* historical architecture reference | [`/AiQo_Master_Blueprint_17.md`](../AiQo_Master_Blueprint_17.md) |
| Why a Brain subsystem was built the way it was | `archive/batch-results/` and `archive/captain-brain/` |
| The state of an old App Store submission | `archive/app-store/` |
| English product context for a new team member | `explainers/en/AiQo_AIContext_00_README.md` |
| Arabic product context for a new team member | `explainers/ar/AiQo_شرح_شامل_01_نظرة_عامة.md` |
| Pre-17 versions of the master blueprint | `archive/blueprints/` |

---

## Conventions

- **Nothing in `docs/archive/` is "actively maintained."** These are point-in-time snapshots. If a finding from one of these files is still relevant, it should be promoted into Blueprint 18 §4/§5 or AIQO_TECH_DEBT.md.
- **Explainer docs are paired across languages.** When updating `explainers/en/AiQo_AIContext_03_CaptainHamoudi.md`, also update `explainers/ar/AiQo_شرح_شامل_03_كابتن_حمودي.md` (or vice-versa). Mismatch → file an AIQO_TECH_DEBT.md entry.
- **`docs/security/` is reserved.** New security audits should land there as `YYYY-MM-DD-<topic>.md`, then be summarized in Blueprint 18 §4.
