# App Store — What's New · v1.0.7 (build 30)

Submission copy for App Store Connect. Arabic is the primary locale; English is the secondary.

---

## العربية (ar) — "الجديد في هذا الإصدار"

أكبر إضافة من مدة: **النواة** — قفل تطبيقات تفتحه بحركتك.

• اختار التطبيقات اللي تسحبك، والنواة تدرّعها إلك. تريد تفتح واحد؟ تحرّك — خطواتك الحقيقية (من تطبيق الصحة) ترفع الدرع. كل درع يصير أصعب شوية حتى تنكسر دوامة التمرير، بس يضل ممكن جسدياً دائماً.
• كابتن حمودي يوكّف جنبك بكل تحدّي ويشجّعك صوتياً وأنت تتحرك — كلشي على جهازك، بدون إنترنت بالحلقة.
• كلشي بيدك: تكدر تطفّي الحماية وكت ما تريد — بعد وقفة هادئة قصيرة حتى يضل القرار مقصود — وخياراتك للتطبيقات المحجوبة ما تطلع أبداً من جهازك. ضمن AiQo Max.

وويّاها شغل دقّة على التطبيق كله:

• **الإنجليزي صار صح.** شاشات كانت تسرّب نص عربي (أو تسميات خام) وقت اللغة إنجليزية — التقرير الأسبوعي، صور التقدّم، شيت "ذوقي"، ملخّص التمرين، ومنتقي اللغة — كلها هسة تنقرأ صح بأي لغة تختارها.
• **الإشعارات بلغتك.** نصائح الكابتن والتذكيرات اليومية (ماي، تمرين، نوم، ستريك، التقرير الأسبوعي) صارت توصل بالإنجليزي للمستخدم الإنجليزي.
• **تحديات تكدر تخلّصها.** تحديات الكاميرا كانت تطلب دقّة 100% مستحيلة بأعلى مرحلة — هسة صارت 95% صعبة بس ممكنة.
• **حذف الحساب صار أمين.** إذا ما كدر السيرفر يكمل الحذف، التطبيق يكَلك ويخلّيك داخل حسابك حتى تعيد المحاولة — بدل ما يطلّعك ويوهمك إنه انمسح.

خصوصيتك أولاً — تحليل النوم وقياس النبض يضلّون على جهازك بالكامل.

---

## English (en) — "What's New"

Our biggest addition yet: **Kernel** — an app lock you open with movement.

• Pick the apps that pull you in and Kernel shields them. Want to open one? Move — your real steps (from Health) lift the shield. Each shield gets a little harder so the doomscroll loop breaks, but it always stays physically possible.
• Captain Hamoudi coaches you live through every challenge, cheering you on by voice as you move — entirely on your device, no internet in the loop.
• It's all on your terms: turn protection off whenever you want (after a short, deliberate pause to keep it meaningful), and your blocked-app choices never leave your device. Part of AiQo Max.

Plus a polish pass across the whole app:

• **English, done right.** Several screens leaked Arabic text (or raw labels) in English mode — Weekly Report, Progress Photos, the "My Vibe" music sheet, the post-workout summary, and the language picker all read correctly now.
• **Notifications speak your language.** Captain's nudges and daily reminders (water, workout, sleep, streak, weekly report) now arrive in English for English users.
• **Quests you can finish.** Camera-form quests demanded an unreachable 100% at their top tier; the bar is now a demanding-but-attainable 95%.
• **Honest account deletion.** If the server can't complete the deletion, the app tells you and keeps you signed in to retry — instead of signing you out as if your data were already erased.

Privacy first — sleep analysis and pulse measurement stay fully on your device.

---

## Reviewer notes (App Review → "Notes")

**New in 1.0.7 — النواة / "Kernel", a personal digital-wellbeing app lock (AiQo Max tier).** This is the only substantive new capability vs. 1.0.6.

### Family Controls usage
- AiQo requests **`.individual` authorization only** (personal self-control). It is **not** a parental-control or MDM product: it never requests `.child` authorization and never manages another person's device. The Family Controls (Distribution) entitlement is approved for the app and its three extensions.
- The user's blocked-app selection is an opaque `FamilyActivitySelection` of system-provided tokens. It is stored only in the app's App Group **on-device** and **never leaves the device** — no app names, bundle IDs, or usage data are transmitted to any server.
- Shields are applied with `ManagedSettings` and scheduled with `DeviceActivity`. All logic runs on-device.

### The user is never locked out
- Protection can always be turned off. The disable path uses a brief calm-hold as deliberate friction — a 30-second calm-heart-rate hold (≤80 bpm), measured by a paired Apple Watch **or** the back-camera PPG — with a **guided-breathing fallback** and an **absolute 90-second cap**, so the user is never trapped.
- Deleting the app or revoking Screen Time access releases every shield immediately (OS guarantee).
- Shields unlock via **real physical movement** (steps from HealthKit/CoreMotion). The step target is always hard-capped to a walkable number, so unlocking stays physically possible.

### Privacy & permissions
- **Health (steps):** read on-device to lift shields. **Motion (CoreMotion):** live step count during a challenge (`NSMotionUsageDescription`). **Camera:** on-device PPG pulse measurement for the calm-hold only (`NSCameraUsageDescription`) — no photo or video is recorded, stored, or transmitted. Heart rate may instead come from a paired Apple Watch.
- The calm 60–80 bpm range is shown with a clear **non-medical wellness disclaimer**. AiQo is a wellness coach, not a medical provider.
- **Zero in-app purchases and zero network calls inside the lock/challenge loop.** The live Captain coaching uses Apple's on-device text-to-speech.

### How to review (Kernel is Max-gated)
- Entry point: **Profile → AiQo**. It requires the **AiQo Max** tier. A demo account with Max enabled (or a promo code) is provided in App Store Connect → App Review Information; more available on request.
- End-to-end on device: grant Screen Time / Family Controls when prompted → pick one app to shield → exceed the usage threshold to trigger a shield → walk to accumulate steps and watch the shield lift. To disable: open the Kernel sheet → turn protection off → complete the calm-hold (or use the breathing fallback).

### Other 1.0.7 changes (compliance / housekeeping — no new data types)
- The age/health setup that blocks under-18 (Guideline 1.4.1) is now a required onboarding step (existing users grandfathered).
- Account deletion now surfaces server failures instead of signing the user out as if data were erased (Guideline 5.1.1(v)).
- English-localization fixes, English notification localization, camera-quest accuracy threshold 100% → 95%, and removal of a few inert UI controls.
- **No new third-party SDKs, no new data collection, and no new privacy-label data types vs. 1.0.6.**
