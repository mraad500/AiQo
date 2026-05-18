# AiQo AI Context -- 05 Business Model

This file gives any AI complete clarity on how AiQo makes money, who pays, the subscription structure, the free trial mechanics, and the launch plan. It covers pricing, tier feature gates, receipt validation, conversion strategy, and revenue philosophy.

---

## The Two Subscription Tiers

AiQo has exactly two subscription tiers. No third tier. No lifetime option (yet). No annual option (yet).

### AiQo Core -- $9.99/month

The daily foundation tier. Includes:

- Captain Hamoudi chat (Gemini 2.5 Flash model)
- Captain memory (200 facts limit)
- Captain voice (ElevenLabs TTS)
- Full Gym features (workout plans, Zone 2 coaching, workout tracking)
- Full Kitchen features (fridge scanner, meal plans, shopping list)
- Full Sleep features (Smart Wake calculator, sleep analysis)
- Full lifestyle tracking (steps, calories, water, stand, distance)
- Daily Aura progress visualization
- XP and leveling system
- Quest system
- Streak tracking
- All push notifications (water, workout, sleep, streak, inactivity)
- Apple Watch companion
- HRR Assessment
- Weekly AI workout plans
- Record Projects (Legendary Challenges -- view-only browsing, starting requires Pro)

Does NOT include:
- My Vibe (Spotify integration)
- Legendary Challenges (starting/full access)
- Extended Captain memory (500 limit)
- Gemini 3.1 Pro reasoning model
- Tribe creation

### AiQo Intelligence Pro -- $29.99/month

Everything in Core, plus:

- Captain Hamoudi with Gemini 3.1 Pro (reasoning model -- deeper, more analytical responses)
- Extended Captain memory (500 facts limit, 700 token budget for cloud context vs. 400)
- My Vibe / DJ Hamoudi (Spotify integration with biometric playlist recommendations)
- Legendary Challenges -- full access (start, track, weekly reviews)
- Tribe creation (can create and own a tribe)
- All Core features included

---

## The Free Tier (Post-Trial, No Subscription)

After the 7-day trial expires and the user does not subscribe:

**What they can still do:**
- Open the app
- See the home screen with daily metrics (steps, calories, etc.)
- View their Daily Aura
- See their profile and level
- Receive the weekly Sunday report notification

**What is locked:**
- Captain Hamoudi chat
- Captain voice
- Sleep analysis and Smart Wake
- Kitchen (fridge scanner, meal plans)
- Gym (workout plans, Zone 2 coaching, live sessions)
- My Vibe
- Legendary Challenges
- Quests
- All notifications except the weekly Sunday report
- Tribe participation

The locked state is enforced by `AccessManager.shared` which checks `activeTier`. When `activeTier == .none`, feature gate properties return false, and the UI presents a paywall.

---

## The 7-Day Free Trial

### Mechanics

- **Length**: 7 days from the moment onboarding completes (specifically, when the Legacy Calculation step finishes)
- **Features**: All Intelligence Pro features are unlocked during the trial. The user experiences the best version of AiQo.
- **No payment required**: The trial does not require a credit card. It is not a StoreKit free trial -- it is an independent timer managed by `FreeTrialManager`.
- **Trial start persistence**: The start date is stored in both UserDefaults AND Keychain. The Keychain entry survives app reinstall, preventing re-trial.
- **One trial per Apple ID**: Enforced via Keychain persistence and StoreKit Transaction.currentEntitlements check.

### Trial day behavior

| Day | Captain Behavior | Notifications |
|-----|-----------------|---------------|
| 1 | Welcome greeting. Light touch. Asks about goals. | Maximum 1 notification (welcome evening at 19:30 if steps > 0) |
| 2 | Morning brief begins. References HealthKit data. | Maximum 2 notifications per day |
| 3 | Feature reveal: Smart Wake (triggered by sleep data) | Dynamic triggers begin (pace spike, inactivity, goal approach) |
| 4 | Feature reveal: Kitchen (triggered organically) | Up to 3 notifications per day |
| 5 | Feature reveal: Zone 2 | Up to 3 notifications per day |
| 6 | Deeper engagement. References remembered facts. | Paywall preview notification at 20:00 |
| 7 | Weekly recap generated. First weekly memory report. | Weekly recap notification at 18:00 |

### Post-trial behavior

- 90% of notifications stop immediately
- A single Sunday weekly report notification continues indefinitely for non-subscribers (re-engagement)
- Captain chat and all premium features are gated behind the paywall
- The paywall shows with contextual messaging depending on the source (feature gate, day 6 preview, trial ended, etc.)

### Dynamic notification triggers during trial

| Trigger | Condition | Cooldown |
|---------|-----------|----------|
| Pace spike | Walking speed > 5.5 km/h for 3 minutes | 90 min between any triggers |
| Step goal approach | >= 80% of daily goal, after 5 PM | 90 min |
| Inactivity gap | 3+ hours without steps, between 9 AM - 6 PM | 90 min |
| Workout detected | HealthKit workout completion | 90 min |
| Run detected | Running-type workout completion | 90 min |

---

## Annual Tier

**Status**: Planned for after AUE launch (May 2026), not yet implemented.

**Target prices** (not finalized):
- Core Annual: approximately $59/year (roughly 50% discount vs. monthly)
- Intelligence Pro Annual: approximately $119/year (roughly 65% discount vs. monthly)

---

## Receipt Validation

### Client-side (primary)

StoreKit 2 Transaction verification is the source of truth for entitlements. The app checks `Transaction.currentEntitlements` for valid, non-revoked transactions. Subscription period is 30 days per cycle, computed manually and stacked if the user renews before expiry.

### Server-side (secondary, non-blocking)

A Supabase Edge Function (`validate-receipt`) validates receipts for analytics and fraud detection. It receives transactionId, productId, and purchase dates. Validation failure does not revoke local entitlements -- the client trusts its own StoreKit verification. Server validation exists for telemetry, not enforcement.

---

## The Launch Plan

### Target launch: May 2026 at AUE

The American University of the Emirates (AUE) in Dubai is the launch venue. The strategy is campus-first: build a concentrated user base with direct feedback, then expand.

### Launch phases

1. **Pre-launch (now)**: Complete development. Prepare App Store listing. Execute 12-post Instagram strategy on @aiqoapp covering brand reveal, feature teasers, social proof, and launch day.
2. **Campus launch (May 2026)**: Deploy at AUE. In-person demonstrations. Student word-of-mouth. Direct feedback collection.
3. **Post-campus (June 2026+)**: Broader UAE marketing based on campus evidence. Gulf country expansion consideration.

### Instagram marketing strategy

12 posts planned, covering:
- Brand identity reveal (who is AiQo, who is Captain Hamoudi)
- Feature teasers (Captain chat, Sleep, Kitchen, Zone 2, My Vibe)
- Social proof (beta user reactions, campus testimonials)
- Launch day countdown and availability announcement

---

## Pricing Philosophy

AiQo is positioned as premium-but-accessible in the wellness app market:

| App | Monthly Price | What You Get |
|-----|--------------|--------------|
| Whoop | $30/mo | Hardware + data analytics, no AI coaching |
| Strava Premium | $12/mo | Social fitness, route planning, no AI |
| MyFitnessPal Premium | $20/mo | Calorie counting, food logging, no AI coaching |
| **AiQo Core** | **$9.99/mo** | **AI coach, meal plans, workout plans, sleep analysis, full tracking** |
| **AiQo Intelligence Pro** | **$29.99/mo** | **Everything + advanced AI model, Spotify integration, Legendary Challenges** |

The Core tier undercuts most competitors while offering an AI-powered experience. The Intelligence Pro tier is premium but justified by the advanced Gemini model, expanded memory, and unique features like DJ Hamoudi and Peaks.

---

## What AiQo Will NEVER Do for Revenue

- **No ads**: AiQo will never show advertisements. The subscription model is the only revenue source.
- **No selling user data**: Health data stays on-device or in the user's own Supabase account. Never sold, never shared, never monetized.
- **No dark patterns**: No "limited time offer" countdowns, no fake scarcity, no hidden auto-renewal traps. The paywall is transparent.
- **No fake urgency**: The trial expires naturally. The only day-6 notification is informational, not pressuring.
- **No supplements or affiliate products**: AiQo is a software product. It will never sell physical products or earn affiliate commissions.
- **No pay-to-win in social features**: Tribe energy and leaderboards are based on activity, not spending.

---

## Conversion Strategy

The trial-to-paid funnel relies on three principles:

### 1. Prove value before asking for money

The 7-day free trial gives full Intelligence Pro access. The user experiences the Captain's memory building, personalized coaching, sleep analysis, meal plans, and Spotify integration before seeing a paywall. By day 7, the Captain knows their name, goals, injuries, and habits.

### 2. Personal data creates switching cost

The longer a user stays, the more the Captain remembers. After 7 days, the Captain has stored workout preferences, dietary needs, sleep patterns, and injury history. Starting over with a generic app means losing that personalized knowledge. This is not a lock-in -- the user can export their data -- but it is a natural moat.

### 3. Captain Hamoudi is a relationship, not a feature

Users do not cancel a friend. By giving the Captain a consistent personality, dialect, memory, and voice, AiQo creates an emotional connection that generic fitness apps cannot. The Captain is not interchangeable with another app's AI -- he is a specific character the user has built a history with.

---

## IP Protection

- **UAE trademark**: Filed via Ministry of Economy for "AiQo" brand name and logo
- **Copyright**: Code and design are copyrighted by Mohammed
- **Potential patents**: Novel features under consideration for patent filing:
  - Hybrid brain routing architecture (on-device + cloud with privacy sanitization)
  - PrivacySanitizer pattern (PII redaction before cloud AI inference)
  - My Vibe biometric playlist control (heart rate + mood -> Spotify recommendations)
  - Circadian tone adaptation (bio-phase-aware AI tone shifting)

---

## How to Use This File With Another AI

Paste this file when discussing monetization strategy, pricing decisions, conversion optimization, marketing copy, paywall design, trial mechanics, or launch planning. Pair with file 01 (Product Overview) for product context and file 07 (Roadmap) for timeline context.
