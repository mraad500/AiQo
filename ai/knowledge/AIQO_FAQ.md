# AiQo — FAQ

> Frequently asked questions with canonical answers, grouped by category. Mirrors the public FAQ on [aiqo.app](https://aiqo.app) and extends it. Safe for a support/marketing GPT to quote.

---

## Availability & platform

**Is AiQo available now?**
Yes — AiQo is live on the App Store. Download it free and start your trial; updates ship continuously.

**Which devices does it need?**
An iPhone running iOS 26+. An **Apple Watch is optional** — it adds more accurate heart-rate, sleep, and workout data, but AiQo is fully functional from iPhone alone.

**Is there an Android or web version?**
No. AiQo is iOS-only by design (it is built deeply on Apple frameworks — HealthKit, Apple Intelligence, StoreKit, AlarmKit). There are no current plans for Android.

**Does it work offline?**
Most features work offline: health tracking, workouts, sleep, and quests. Captain Hamoudi needs internet for deep conversations, but **basic guidance runs on-device** via Apple Intelligence.

---

## Captain Hamoudi & AI

**Who is Captain Hamoudi?**
Your personal AI health coach. He speaks your Arabic **dialect** (Iraqi/Gulf), remembers your journey, and reads your health data to give advice in context — not a generic chatbot. See the persona profile for detail.

**What language does he speak?**
Iraqi/Gulf Arabic dialect when the app is in Arabic, and casual English when the app is in English. He never speaks in stiff Modern Standard Arabic in conversation.

**Does the Captain remember me?**
Yes. He keeps a durable memory of your goals, preferences, body, and history — about 200 facts on Max and 500 on Pro. The more you talk, the better he knows you.

**Is the AI on-device or in the cloud?**
Both. A **hybrid brain** runs privacy-sensitive work (like sleep analysis) entirely on-device with Apple Intelligence, and uses Google Gemini in the cloud for richer conversations and plans — always after stripping personal identifiers.

---

## Privacy & data

**How is my health data protected?**
Your health data stays on your device. Any request that goes to the cloud is **stripped of your identity first** (a `PrivacySanitizer` removes emails, phone numbers, IDs, and replaces your name). Sleep analysis never leaves the device. We don't sell your data. No ads. Ever.

**Are my health numbers altered before being sent?**
Your *identity* is removed, but your health *metrics* (steps, heart rate, sleep durations) are sent **exactly** so the coaching is accurate — they are not personally identifying on their own. (This is the v1.0.6 behavior: exact, not bucketed.)

**Where are the API keys?**
Server-side. Gemini (chat) and MiniMax (voice) keys live in Supabase Edge Functions, never in the app. The app authenticates with its own session token.

**Can I export or delete my data?**
Yes — full export (CSV/JSON/PDF) and deletion are available. Health data portability is built in.

---

## Billing & tiers

**What does it cost?**
Two paid tiers: **AiQo Max** at **$9.99/month** (the full daily app) and **AiQo Intelligence Pro** at **$19.99/month** (adds the advanced model, extended memory, full Peaks, My Vibe, Directives, and photo analysis). A free tier covers tracking, quests, and the dashboard.

**What's the difference between Max and Pro?**
Max is the complete daily experience — the Captain, health dashboard, club, workouts, My-Vibe-less core, Sleep, Kitchen, and Apple Watch. Pro adds a higher-intelligence layer: extended memory, a stronger model, premium voice, adaptive multi-week plans, and the **full** Peaks / Legendary Challenges. *(Note: despite the name, "Pro" is the higher tier.)*

**Is there a free trial? Does it need a credit card?**
Yes — a **7-day free trial**. It requires a payment method on your App Store account (like any subscription), but **nothing is charged** during the 7 days, and you can cancel anytime in Settings.

**What happens after the trial if I don't subscribe?**
You keep the free features and your data. Premium features (Captain chat, plans, Peaks, etc.) lock, and proactive notifications drop to a single weekly Sunday recap. Your relationship with the Captain is preserved if you subscribe later.

---

## Features

**Is Kitchen / the fridge scanner free?**
No — Kitchen is a Max feature. You photograph your fridge and the Captain builds a meal plan from your ingredients.

**What is Learning Spark?**
A **free** starter challenge — the first quest in the Battle (معركة) ladder, in Stage 1 ("Awakening"). You complete one of two hand-picked free online courses (Edraak's *Planning a Successful Career Path* in Arabic, ~6h; or Coursera's *Learning How to Learn* in English, ~15h), then upload your certificate (photo or link) to prove it. Verification happens **entirely on-device** — your certificate never leaves your phone — and a verified completion earns **+1,000 XP**. It's there to plant the learning habit from day one.

**Can I use Peaks on Max?**
On Max you can **view** Peaks (Legendary Challenges) but not start one. Starting and tracking a Peak requires Pro.

**What is My Vibe?**
A Pro feature: Spotify-powered music that adapts to your biometric state and the time of day. The Captain ("DJ Hamoudi") recommends playlists.

**Is the social / Tribe feature available?**
Not yet. Tribe is built but currently turned off behind feature flags pending its backend. It is not available to users today.

---

## Health & safety

**Is AiQo a medical device?**
No. AiQo is a coaching and wellness companion, not a medical device. It does not diagnose or treat conditions. For medical concerns, consult a professional. The Captain defers to professionals on serious health and mental-health topics.

**Does it handle mental-health crises?**
A crisis-detection layer can surface professional resources (e.g. a suicide-prevention lifeline) when it detects distress — without blocking the conversation.

---

## Contact

- Support: https://aiqo.app/support · support@aiqo.app
- Instagram: [@aiqoapp](https://instagram.com/aiqoapp)
- Made by Mohammed Raad 🇮🇶, designed in the UAE 🇦🇪.
