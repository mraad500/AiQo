# App Store — What's New · v1.0.8 (build 31)

Submission copy for App Store Connect. Arabic is the primary locale; English is the secondary.

> ⚠️ **Metadata accuracy:** describe the free Captain functionally — "on your device",
> "offline", "private". Do **not** brand it "Apple Intelligence" in marketing copy (the paid
> Captain is Google Gemini; mixing the two is the 2.3.1 risk fixed in 1.0.7). The precise
> tech split belongs in the reviewer Notes below, not the store copy.

---

## العربية (ar) — "الجديد في هذا الإصدار"

**كابتن حمودي صار مجاني للكل — وتكدر تصمّم شخصيته.**

• الكابتن انفتح لكل المستخدمين، مجاناً وبلا حدود رسائل. يشتغل **كامل على جهازك** — بدون إنترنت وبدون حساب — فحچيك يضل خاص، ويرد بلهجة عراقية طبيعية.
• المجاني **مساعد سريع وبسيط**: يتذكّر محادثتك، يناديك باسمك، وأي رقم صحي يذكره يتطابق مع بيانات صحتك الحقيقية — ما يخمّن.
• **جديد — صمّم شخصية كابتنك (مع Max):** اختار من ٦ شخصيات — عملي، حنون، صارم، محلّل، واسع الأفق، أو مرشد — والكابتن يتغيّر فعلاً على ذوقك. ومع **Pro** تكدر **تكتب شخصيته بكلماتك**.
• **كابتن حي:** صورة الكابتن تتنفّس وتتفاعل مع حركة جهازك؛ ومع الاشتراك تنوّر حوله هالة تتجاوب وية صوته.

ولمن تطلب من الكابتن المجاني خطة كاملة أو نظام غذائي، يعطيك نبذة سريعة ويدلّك على Max للخطة الكاملة اللي يتابعها ويتذكّرها وياك.

خصوصيتك أولاً — الكابتن المجاني وتحليلاتك الحسّاسة تظل على جهازك.

---

## English (en) — "What's New"

**Captain Hamoudi is now free for everyone — and you can shape his personality.**

• The Captain is open to all users, free and with no message limits. He runs **entirely on your device** — no internet, no account — so your conversations stay private, in natural Iraqi Arabic.
• The free Captain is a **quick, simple helper**: he remembers your chat, calls you by name, and keeps every health number honest against your real Health data — never guessed.
• **New — design your Captain (with Max):** choose from 6 personalities — practical, caring, strict, analytical, visionary, or mentor — and he truly changes to match you. With **Pro**, you can even **write his personality in your own words**.
• **A living Captain:** his portrait breathes and reacts to how you move your phone; subscribing lights up a living aura that responds to his voice.

When you ask the free Captain for a full plan or nutrition program, he gives you a quick taste and points you to Max for the complete plan he tracks and remembers with you.

Your privacy comes first — the free Captain and your sensitive insights stay on your device.

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
