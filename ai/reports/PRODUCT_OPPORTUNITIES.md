# AiQo — Product Opportunities

> Opportunities across features, UX, retention, growth, and monetization, prioritized by impact vs. effort. Grounded in the current product state (v1.0.6). Implementation of app features is deferred (in-review build); the **AI-discoverability** items in this program are already shipped.

---

## 1. Highest-leverage opportunities

| # | Opportunity | Type | Effort | Why it matters |
|---|---|---|---|---|
| 1 | **Ship Tribe** (flip the feature flags + backend) | Retention | M | A small, private social layer is built and dormant. Social accountability is one of the strongest retention levers in fitness; it's mostly backend work, not new design. |
| 2 | **AI discoverability** (Custom GPT, llms.txt, JSON-LD) | Growth | — | **Done in this program.** A public "AiQo Guide" GPT + answer-engine optimization makes AiQo citable by assistants — a new, near-zero-cost acquisition channel. |
| 3 | **Annual plans** (~$59 Max / ~$119 Pro) | Monetization | S | Annual pricing lifts LTV and reduces churn vs. monthly-only. The tiers exist; only StoreKit products + paywall copy are needed. |
| 4 | **Referral loop** ("invite a friend, both get trial days") | Growth | M | Captain's memory creates a sticky relationship; a referral that gifts trial time turns happy users into a channel — fits the no-ads ethos. |
| 5 | **Streaming Captain replies (SSE)** | UX | M | True token streaming beats the current wait-then-reveal on *perceived* latency — the single biggest felt-quality win for the core loop. |

---

## 2. Feature gaps & enhancements

- **Captain proactive "win" recaps.** The Captain remembers goals; a weekly "you said you wanted X, here's your progress" beat (the website already teases this) deepens the memory moat. Largely present — make it consistent across tiers.
- **Apple Intelligence everywhere it can be.** Lean further on on-device models for short coaching to cut latency and cloud cost — strengthens the privacy story too.
- **Widgets & Live Activities for the Captain**, not just hydration — surface a daily Captain nudge on the lock screen.
- **Onboarding "aha" acceleration.** The trial arc is well-designed; consider front-loading one memorable Captain moment on day 1 (e.g. an instant, dialect-rich reaction to the first HealthKit sync) to anchor the relationship early.
- **Personal AI API (OAuth).** Designed in this program — lets users connect AiQo to their own ChatGPT/agents. A differentiator and a retention hook, gated behind a privacy review.

---

## 3. UX

- **Perceived latency** (see SSE above) is the top UX item for the chat loop.
- **Avatar polish/perf** — pause idle animation when off-screen (battery) and invest in the planned V1/V2 avatar for the premium bar the founder wants.
- **Empty states** — ensure first-run screens (no workouts, no memories yet) showcase the Captain's voice, not blank dashboards.
- **Language toggle** on the website is currently non-functional (English button) — finishing it widens reach for an Arabic-first product courting bilingual Gulf users.

---

## 4. Retention

1. **Tribe** (social accountability) — #1 above.
2. **Streaks & shield tiers** already exist; surface them more prominently at risk-of-churn moments (the post-trial weekly Sunday recap is a smart minimal touch — consider a "your Captain misses you / your streak is at risk" beat).
3. **Memory as the moat** — periodically remind users *how much* the Captain knows about them (a "Captain's memory of you" view) to raise switching cost.
4. **Habit stacking** — Smart Wake → morning brief → first quest is a strong morning chain; reinforce it.

---

## 5. Growth

- **Answer-engine optimization (shipped):** the `/ai/*` knowledge API, `llms.txt`, AI-crawler robots rules, and richer JSON-LD make AiQo discoverable and citable by ChatGPT/Perplexity/Claude — compounding, free reach.
- **The "AiQo Guide" Custom GPT** (this program) is a shareable marketing surface in the GPT Store.
- **Founder/Hamoudi persona** content remains the primary top-of-funnel (per the Hamoudi strategy docs) — the Custom GPT and site reinforce it.
- **Campus launch (AUE)** word-of-mouth → referral loop (#4) captures it.

---

## 6. Monetization

- **Annual tiers** (#3) — the clearest near-term lift.
- **Trial conversion instrumentation** — the trial arc is well-designed; ensure analytics capture day-by-day conversion so the day-6/7 beats can be tuned (remote analytics is planned post-launch).
- **Pro's value clarity** — the naming (`.max` entry vs `.pro` top) is counterintuitive; the website and this knowledge base now state it explicitly, which should reduce confusion-driven downgrades. Consider clearer in-app tier labels.
- **No dark patterns** remains a brand asset — keep it.

---

## 7. What NOT to do

- Don't add ads or data-sale revenue — it would break the core promise and the moat.
- Don't bolt on Android/web prematurely — the deep Apple-framework dependency is a feature, not debt, for the target user.
- Don't over-socialize Tribe — keep it small and private (max 5); that intimacy is the point.

---

## 8. Suggested sequencing

1. **Now (this program):** AI discoverability + Custom GPT — *done*.
2. **Next release:** annual plans; streaming replies; avatar perf gate.
3. **Post-launch:** Tribe backend → flip flags; referral loop; remote analytics.
4. **Later:** personal OAuth API; deeper on-device inference; avatar V1/V2.
