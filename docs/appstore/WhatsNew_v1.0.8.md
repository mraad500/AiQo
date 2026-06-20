# App Store — What's New · v1.0.8 (build 31)

Submission copy for App Store Connect. Arabic is the primary locale; English is the secondary.

> ⚠️ **Metadata accuracy:** describe the free Captain functionally — "on your device",
> "offline", "private". Do **not** brand it "Apple Intelligence" in marketing copy (the paid
> Captain is Google Gemini; mixing the two is the 2.3.1 risk fixed in 1.0.7). The precise
> tech split belongs in the reviewer Notes below, not the store copy.

---

## العربية (ar) — "الجديد في هذا الإصدار"  ← PASTE THIS

كابتن حمودي صار مجاني للكل — وأذكى.

• الكابتن مجاني الآن لكل المستخدمين وبلا حدود — يشتغل على جهازك، يحجي عراقي طبيعي، يتذكّر محادثتك، وكل رقم صحي يذكره مضبوط على بياناتك الحقيقية.
• جديد: صمّم شخصية كابتنك (مع AiQo Max) — اختر من ٦ شخصيات: عملي، حنون، صارم، محلّل، واسع الأفق، أو مرشد. ومع Pro اكتب شخصيته بكلماتك.
• كابتن حي: صورته تتنفّس وتتفاعل مع حركة جهازك، وبالاشتراك تنوّر حوله هالة تتجاوب مع صوته.
• النواة: درّع تطبيقاتك وافتحها بحركتك الحقيقية — مجاناً تحمي تطبيقاً واحداً، ومع Max بلا حدود.
• تحسينات وضوح ومعالجة هفوات عبر التطبيق.

---

## English (en) — "What's New"  ← PASTE THIS

Captain Hamoudi is now free for everyone — and smarter.

• The Captain is now free for all users, with no limits — he runs on your device, speaks natural Iraqi Arabic, remembers your chat, and keeps every health number honest against your real data.
• New: design your Captain's personality (with AiQo Max) — pick from 6 styles: practical, caring, strict, analytical, visionary, or mentor. With Pro, write his personality in your own words.
• A living Captain: his portrait breathes and reacts to how you move your phone; subscribing lights up an aura that responds to his voice.
• Kernel: shield your apps and open them with real movement — free protects one app, Max is unlimited.
• Clarity improvements and bug fixes across the app.

---

## Reviewer notes (App Review → "Notes")

**New in 1.0.8 — Captain Hamoudi (the in-app AI coach chat) is FREE for all users, plus a new
paid "Captain personality" customization.** These are the substantive changes vs. 1.0.7.

### How the free Captain works (accuracy)
- The **free** Captain runs **fully on-device** using the OS's built-in on-device language
  model (Foundation Models, iOS 26+, where available). **No chat text leaves the device, no
  account is required, no message limits.** If the model is unavailable, the chat shows a brief
  honest "try again" line — it does **not** silently send the message to a server.
- It is intentionally a **lightweight helper** (short replies). For a full multi-week plan,
  nutrition program, or deep analysis it gives a brief, genuine tip and notes those are part of
  **AiQo Max** — a value-first invitation, never a hard wall.
- The **paid** Captain (AiQo Max / Pro) uses **Google Gemini** via our Supabase proxy (cloud),
  after on-device PII redaction + explicit one-time consent, and adds durable memory + plans.

### Captain personality (paid)
- Max users can pick a Captain personality preset; Pro users can additionally type a free-text
  persona. This only changes the **style/tone** of the coaching text — no new data is collected
  and nothing new is transmitted on the free path (free has no personality picker).

### No new data types / SDKs
- **No new third-party SDKs and no new privacy-label data types vs. 1.0.7.** The on-device
  Captain reads the same, already-authorized HealthKit metrics locally; the free path transmits
  nothing. A deterministic on-device guard rewrites any health number that contradicts HealthKit.

### Unchanged since 1.0.7
- **النواة (Kernel)** is exactly as approved: AiQo Max, Family Controls `.individual`
  (self-control), on-device only, always disableable. No change to its data handling.
- A real token-streaming path exists in code but is **OFF behind a feature flag**; the shipped
  behavior is the proven blocking reply path.

### How to review
- The Captain is reachable from the main tab **with no subscription**. On a supported device,
  send a message in Arabic or English — the reply is generated on-device.
- Captain personality lives in the Captain → customize sheet: free sees a locked card, Max sees
  the preset styles, Pro adds a custom field. A Max demo account is provided in App Review
  Information (also unlocks Kernel, which remains Max-gated).
