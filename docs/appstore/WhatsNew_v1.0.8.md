# App Store — What's New · v1.0.8 (build 31)

Submission copy for App Store Connect. Arabic is the primary locale; English is the secondary.

> ⚠️ **Metadata accuracy:** describe the free Captain functionally — "on your device",
> "offline", "private". Do **not** brand it "Apple Intelligence" in marketing copy (the paid
> Captain is Google Gemini; mixing the two is the 2.3.1 risk that was fixed in 1.0.7). The
> precise tech split belongs in the reviewer Notes below, not the store copy.

---

## العربية (ar) — "الجديد في هذا الإصدار"

**كابتن حمودي صار مجاني للكل — وأذكى.**

• الكابتن انفتح لكل المستخدمين، مجاناً وبلا حدود رسائل. يشتغل **كامل على جهازك** — بدون إنترنت وبدون حساب — فحچيك يضل خاص، ويرد بلهجة عراقية طبيعية.
• **صار يتذكّر المحادثة.** يتابع السياق — اسمك، هدفك، آخر جواب كاله — فما يعيد نفسه ويرد عليك مثل واحد فاهمك فعلاً.
• **يعرفك إنت.** يناديك باسمك ويمشي على النبرة اللي تختارها: عملي، حنون، أو صارم.
• **أرقامك مضبوطة.** أي رقم صحي يذكره (خطوات، سعرات، نبض) يتطابق مع بيانات صحتك الحقيقية — ما يخمّن ولا يبالغ.
• **كابتن حي.** صورة الكابتن صارت تتنفّس وتتفاعل مع حركة جهازك؛ ومع الاشتراك تنوّر حوله هالة تتجاوب وية صوته.

والمشترك (AiQo Max / Pro) ياخذ الطبقة الأعمق: ذاكرة سحابية دائمة، ردود أسرع، تحليل أعمق، وصوت بريميوم.

خصوصيتك أولاً — الكابتن المجاني وتحليلاتك الحسّاسة تظل على جهازك.

---

## English (en) — "What's New"

**Captain Hamoudi is now free for everyone — and smarter.**

• The Captain is open to all users, free and with no message limits. He runs **entirely on your device** — no internet, no account — so your conversations stay private, in natural Iraqi Arabic.
• **He remembers the conversation.** He follows context — your name, your goal, his last reply — so he never repeats himself and answers like he actually understands you.
• **He knows you.** He calls you by name and matches the tone you choose: practical, caring, or strict.
• **Your numbers stay honest.** Any health figure he mentions (steps, calories, heart rate) is checked against your real Health data — never guessed or inflated.
• **A living Captain.** His portrait now breathes and reacts to how you move your phone; subscribing lights up a living aura that responds to his voice.

Subscribers (AiQo Max / Pro) unlock the deeper layer: durable cloud memory, faster replies, deeper analysis, and premium voice.

Your privacy comes first — the free Captain and your sensitive insights stay on your device.

---

## Reviewer notes (App Review → "Notes")

**New in 1.0.8 — Captain Hamoudi (the in-app AI coach chat) is now FREE for all users.**
Previously it required the AiQo Max tier. This is the only substantive change vs. 1.0.7.

### How the free Captain works (accuracy)
- The **free** Captain runs **fully on-device** using the operating system's built-in
  on-device language model (Foundation Models, iOS 26+, on devices where it is available).
  **No chat text leaves the device, no account is required, and there are no message limits.**
  If the on-device model is unavailable, the chat shows a brief honest "try again" line — it
  does **not** silently send the message to a server.
- The **paid** Captain (AiQo Max / Pro) is **unchanged from 1.0.7**: it uses **Google Gemini**
  via our Supabase proxy (cloud), after on-device PII redaction + explicit one-time consent,
  and adds durable cross-session memory.
- Marketing copy intentionally avoids the "Apple Intelligence" brand name; we describe the
  free tier functionally ("on-device", "offline"). The framework split above is the accurate
  technical picture for review.

### Health accuracy
- A deterministic on-device guard checks every number in the Captain's reply against the
  real HealthKit reading and rewrites anything that diverges, so the coach can never state a
  misleading step/calorie/heart-rate figure.

### No new data types / SDKs
- **No new third-party SDKs and no new privacy-label data types vs. 1.0.7.** The on-device
  Captain reads the same, already-authorized HealthKit metrics locally to ground its replies;
  nothing new is collected, and the free path transmits nothing.

### Unchanged since 1.0.7
- **النواة (Kernel)** is exactly as approved in 1.0.7: AiQo Max, Family Controls `.individual`
  (self-control), on-device only, always disableable via the calm-hold / breathing fallback.
  No change to its data handling.
- A real token-streaming path exists in the code but is **OFF behind a feature flag**; the
  shipped behavior is the same proven blocking reply path as 1.0.7.

### How to review
- The Captain is reachable from the main tab **with no subscription**. On a supported device,
  send a message in Arabic or English — the reply is generated on-device. To see multi-turn
  memory: tell it your name, then ask "what's my name?" — it remembers within the session.
- Kernel remains Max-gated (Profile → AiQo); a Max demo account is provided in App Review
  Information as in 1.0.7.
