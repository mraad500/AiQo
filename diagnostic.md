# DIAGNOSTIC REPORT — AiQo Notifications

> READ-ONLY تشخيص. صفر تعديلات كود. صفر commits.
> التاريخ: 2026-05-17 — الفرع: `release/v1.0.4-memory-v4` — الإصدار: v1.0.5 (build 21)
> الشكوى: المستخدم ما تصله إشعارات على iPhone إطلاقاً.

> ⚠️ تصحيح فرضيات المهمة قبل ما نبدأ:
> - **`NOTIFICATION_BRAIN_ENABLED` مو `false`** — هو `true` بالـ Info.plist (السطر 104–105). الافتراضي بالكود `false` بس الـ plist يتجاوزه. هذا **مو** سبب المشكلة.
> - مسارات ملفات بالمهمة كانت غلط: `PersonaGuard` في `Features/Captain/Brain/04_Inference/Validation/` (مو 06_Proactive)، و`TierGate` في `Features/Captain/Brain/00_Foundation/` (مو Core/Purchases).
> - أسماء مفاتيح Hard Cap بالـ UserDefaults المذكورة بالقالب غلط — الأسماء الحقيقية محطوطة بالقسم J.

---

## A. Feature Flags (Info.plist)

📁 `AiQo/Info.plist`

| Flag | القيمة | ملاحظة |
|---|---|---|
| **NOTIFICATION_BRAIN_ENABLED** | **`true`** (سطر 104–105) | الـ Brain مفعّل ومشترك بأحداث XP/streak |
| **MEMORY_V4_ENABLED** | **`true`** (سطر 96–97) | يفعّل cascade الـ 15 trigger |
| CAPTAIN_BRAIN_V2_ENABLED | `true` (سطر 26–27) | ProactiveEngine شغّال |
| CRISIS_DETECTOR_ENABLED | `true` (سطر 68–69) | — |
| SMART_WATER_TRACKING_ENABLED | `true` (سطر 126–127) | إشعارات الماء عبر Brain |
| AIQO_CHAT_V1_1_ENABLED | `true` (سطر 5–6) | — |
| LEARNING_CHALLENGE_V2_ENABLED | `true` (سطر 76–77) | — |
| LEARNING_SPARK_STAGE2_ENABLED | `true` (سطر 78–79) | — |
| LEARNING_VERIFICATION_ON_DEVICE_ENABLED | `true` (سطر 80–81) | — |
| SAFARI_VIEW_CONTROLLER_ENABLED | `true` (سطر 148–149) | — |
| AIQO_DEV_UNLOCK_ALL | `false` (سطر 7–8) | **مهم: DevOverride مطفّي** → كل بوابات TierGate فعّالة |
| BRAIN_DASHBOARD_ENABLED | `false` (سطر 22–23) | flag ميت |
| CAPTAIN_QUALITY_REGEN_ENABLED | `false` (سطر 34–35) | — |
| PLANK_LADDER_CHALLENGE_ENABLED | `false` (سطر 124–125) | — |
| PROACTIVE_CULTURAL_ENABLED | `false` (سطر 133–134) | ميت |
| PROACTIVE_EMOTIONAL_ENABLED | `false` (سطر 140–141) | ميت |
| PROACTIVE_MEMORY_CALLBACK_ENABLED | `false` (سطر 146–147) | ميت |
| TRIBE_BACKEND_ENABLED / TRIBE_FEATURE_VISIBLE / TRIBE_SUBSCRIPTION_GATE_ENABLED | `false` | — |
| USE_CLOUD_PROXY / USE_CHAT/VOICE_CLOUD_PROXY | `$(…)` placeholder | يُحَل من xcconfig |

**`UIBackgroundModes`** (سطر 174–180): `audio`, `remote-notification`, `fetch`, `processing` ✓
**`BGTaskSchedulerPermittedIdentifiers`** (سطر 11–16): `aiqo.notifications.refresh`, `aiqo.notifications.inactivity-check`, `aiqo.brain.nightly` ✓

> الخلاصة: كل الفلاغات صحيحة. الـ Brain مفعّل. **الـ feature flags مو سبب المشكلة.**

---

## B. Hard Cap (NotificationBrain.swift)

📁 `AiQo/Features/Captain/Brain/06_Proactive/NotificationBrain.swift:27–28`

- `hardCapInterval` = `4 * 3600` = **14400 ثانية = 4 ساعات** بين أي تسليمين
- `hardCapDailyLimit` = **3** تسليمات بالـ calendar day
- **ديناميكي حسب الـ tier؟ لا** — `static let` ثابتة (مو دالة بالـ tier). نفس السقف للمجاني والمدفوع.
- يُفحص بـ `hardCapRejection(now:)` (سطر 294–308) قبل GlobalBudget — أول بوابة فعلية.
- الرفض يرجّع `.rejected(.cooldown)` أو `.rejected(.dailyLimitReached)` ويُسجَّل بـ `AuditLogger` (log فقط، مو persistent).

> تقييم: مقيّد بشدة بس **ما يسبب صفر إشعارات** لحاله — يسمح بـ 3/يوم على الأقل. مساهم ثانوي، مو السبب الجذري.

---

## C. Quiet Hours — تناقض موجود؟

| المصدر | البداية | النهاية | الملف |
|---|---|---|---|
| `QuietHoursManager` | **22** | **7** | `…/06_Proactive/Budget/QuietHoursManager.swift:8–9` |
| `SmartNotificationScheduler` | **23** | **7** | `…/06_Proactive/SmartNotificationScheduler.swift:12–13` |

### ⚠️ Mismatch: **نعم**

- مسار `NotificationBrain` → `GlobalBudget` يستعمل `QuietHoursManager` (22:00–07:00). إشعار غير `critical` بين 22:00–23:00 → `.deferredToMorning`.
- مسار `SmartNotificationScheduler` (الإشعارات المتكررة المباشرة) يستعمل 23:00–07:00. إشعار مجدول الساعة 22:30 ينعرض عادي بهالمسار، بس لو نفس الإشعار مرّ من Brain ينتأجّل.
- الفرق ساعة وحدة بالبداية فقط. **تناقض حقيقي بس تأثيره محدود** — يسبب سلوك غير متّسق بين 22:00–23:00، **مو** صفر إشعارات.

---

## D. Subscription Budget

📁 `AiQo/Core/Purchases/SubscriptionTier.swift:107–113` (`dailyNotificationBudget` — هذا الي يقراه `GlobalBudget.evaluate`)

| Tier | إشعارات/24س |
|---|---|
| none | **2** |
| max | **4** |
| trial | **7** |
| pro | **7** |

> ⚠️ تضارب أرقام (مو حرج): فيه خاصية ثانية `TierGate.maxNotificationsPerDay` (`TierGate.swift:144–150`) ترجّع pro=7, max=4, **default=0**. لكن `GlobalBudget` ما يستعملها — يستعمل `tier.dailyNotificationBudget` (none=**2**). فالميزانية الفعلية للمجاني = 2/يوم (مو 0). بس انتبه: السقف الصارم (3/يوم) أقوى من ميزانية trial/pro.

---

## E. Authorization Flow

📁 `AiQo/Services/Notifications/NotificationService.swift:19–63` — `ensureAuthorizationIfNeeded()`
الـ caller: `requestPermissions()` (سطر 13–17) → يستدعيها async.

**وين تُستدعى:**
- `AppDelegate.didFinishLaunchingWithOptions` **سطر 236** — `NotificationService.shared.requestPermissions()`
- `SmartNotificationScheduler.requestPermission()` سطر 232–239 (مسار منفصل، نفس options)
- زر الإعدادات `AppSettingsScreen`

**متى: قبل/بعد onboarding؟ → بعد، ومشروط بالكامل.**
السطر 236 محبوس داخل `if didCompleteOnboarding` (AppDelegate سطر 234). و`didCompleteOnboarding` (سطر 225–233) يتطلب **كل** هذي `true` بنفس الوقت:

```
didSelectLanguage && didShowFirstAuthScreen && didCompleteDatingProfile
&& didCompleteLegacyCalculation && didCompleteAIConsent
&& didAcknowledgeMedicalDisclaimer
&& (didCompleteCaptainPersonalization || didCompleteFeatureIntro)
&& didCompleteFeatureIntro
```

**fallback إذا المستخدم تخطى onboarding؟ → لا يوجد فعّال.**
- `applicationDidBecomeActive` (سطر 270–303) عنده **نفس** بوابة `allOnboardingDone` (سطر 277–286)، فما يطلب الإذن إذا onboarding ناقص.
- المسار الوحيد البديل: المستخدم يفتح الإعدادات ويفعّل الإشعارات يدوياً.
- ⇒ لو علم واحد من أعلام onboarding `false`، **iOS ما يُسأل أبداً للإذن**، الحالة تبقى `.notDetermined`، وصفر إشعارات تنعرض. وهذا **سبب جذري محتمل #2**.

---

## F. TierGate.canAccess(.captainNotifications)

📁 `AiQo/Features/Captain/Brain/00_Foundation/TierGate.swift`

```swift
requiredTier(.captainNotifications) → .max          // سطر 89–90
canAccess = currentTier.effectiveAccessTier >= required   // سطر 104–106
```

ترتيب `SubscriptionTier` (`SubscriptionTier.swift:18–30`):
- `rank`: `.none`=0، `.max`=1، `.trial`=2، `.pro`=2
- `effectiveAccessTier`: `.trial` → `.pro`؛ غيرها → نفسها

**هل `.trial` يجتازها بالـ default؟ نعم** — `.trial`.effectiveAccessTier = `.pro` (rank 2) ≥ `.max` (rank 1) ✅
**`.pro`/`.max`** → ✅ يجتازون.
**`.none` (مجاني / تجربة منتهية / غير مشترك)** → effectiveAccessTier = `.none` (rank 0). `0 ≥ 1`؟ **لا** → ❌ **محجوب**.

### 🔴 هذا السبب الجذري #1

`TierGate.shared.canAccess(.captainNotifications)` يُفحَص (و`DevOverride.unlockAllFeatures` = false من plist) بكل هذي المواقع — وكلها تنحجب للمستخدم المجاني:

| الموقع | الأثر عند الحجب |
|---|---|
| `SmartNotificationScheduler.refreshAutomationState()` :102 | يستدعي `cancelAllAutomatedNotifications()` + `cancelScheduledBackgroundTasks()` → **يلغي ماء/تمرين/نوم/streak/تقرير + مهام الخلفية** |
| `SmartNotificationScheduler.scheduleRecurringRequest()` :397 | ما يضيف الإشعار المتكرر |
| `SmartNotificationScheduler.generateAndScheduleCoachNudge()` :504 | ما يرسل coach nudge |
| `SmartNotificationScheduler.performInactivityCheck…()` :590 | ما يرسل إشعار خمول |
| `SmartNotificationScheduler.queueDeveloperTestCoachNudge()` :144 | يفشل اختبار المطوّر |
| `NotificationService.sendImmediateNotification()` :71 | محجوب |
| `TrialJourneyOrchestrator.fireImmediate()` :260 | **كل إشعارات التجربة الفورية محجوبة** |
| `TrialJourneyOrchestrator.scheduleAtDate()` :299 | إشعارات التجربة المجدولة محجوبة |
| `TrialJourneyOrchestrator.scheduleNextSundayPostTrialIfEligible()` :424 | تقرير الأحد محجوب |

المسار الوحيد الي **ما** يفحص TierGate مباشرة: `NotificationBrain.request()` نفسه (يعتمد على `GlobalBudget` الي يعطي `.none` ميزانية 2/يوم). يعني نظرياً إشعارات أحداث XP/streak تشتغل للمجاني — بس هذي نادرة وتتطلب level-up أو streak milestone، وتنحكم بالسقف الصارم + cooldown 6 ساعات/نوع.

> ⇒ **مستخدم مجاني (أو تجربته انتهت) = صفر إشعارات مجدولة/متكررة/تجربة/coach عملياً.** يطابق الشكوى تماماً.

---

## G. PersonaGuard Behavior

📁 `AiQo/Features/Captain/Brain/04_Inference/Validation/PersonaGuard.swift`

- **يرفض أم يلوغ؟ → الاثنين، بس الرفض صامت للمستخدم.**
  `PersonaGuard.validate()` يرجّع `Result(passed:violations:)` فقط — ما يلوغ بنفسه. المُستدعي `NotificationBrain` (سطر 128–143): إذا `!passed` → `diag.error(...)` (os_log) ثم `return .rejected(.tierDisabled)` → **الإشعار يُسقَط بصمت بدون أي إشعار للمستخدم**.

- شروط الرفض (`validate` سطر 21–55):
  1. `forbiddenPatterns` (`CaptainIdentity.swift:28–34`): "you should", "you must", "I know how you feel", "everything happens for a reason", "just be positive" — إنجليزية فقط، خطر ضعيف على النص العربي.
  2. **`emoji_on_non_celebration`** — إذا النوع مو ضمن `emojiAllowedKinds` = `{ .personalRecord, .eidCelebration, .achievementUnlocked }` (`CaptainIdentity.swift:36–44`) **و** فيه أي إيموجي بالعنوان أو النص → رفض.
  3. `title.count > 65` → رفض.
  4. `body.count > 180` → رفض.
  5. شتائم إنجليزية (fuck/shit/damn).
  6. محتوى حرام (خمر/قمار/اباحي…).

### 🔴 مشكلة كبيرة #3 — `emoji_on_non_celebration` يقتل إشعارات التجربة والـ streak بصمت

- إشعارات التجربة تمر عبر `NotificationBrain` بـ `kind: .trialDay` (`TrialJourneyOrchestrator.swift:270, 312`). `.trialDay` **مو** ضمن `emojiAllowedKinds`.
- نصوص `TrialNotificationCopy` مليانة إيموجي. أمثلة تنرفض حتمياً (حتى لمستخدم تجربة يجتاز TierGate):
  - `welcomeEvening`: "هلا 👋" ❌
  - `morningBrief`: "صباح الخير 🌤" ❌
  - `paceSpike`: "👀 بطل كاعد تمشي سريع" ❌
  - `runDetected`: "🔥 شفتك تركض" ❌
  - `goalApproach`: "💪 قربت من هدفك اليوم" ❌
  - `workoutCompleted`: "🔥 أحسنت" ❌
  - `day7WeeklyRecapReady`: "📊 تقريرك الأول جاهز" ❌
  - `postTrialWeeklyReport`: "📊 تقرير الكابتن الأسبوعي" ❌
  (الي بدون إيموجي مثل `inactivityGap`, `sleepDebt`, `featureReveal*`, `day6PaywallPreview`, `day7FinalDay` تعدّي.)
- نفس الشي على أحداث Brain: `.streakSave` و`.streakRisk` **مو** بقائمة الإيموجي المسموح؛ لو `MessageComposer` ضاف إيموجي → رفض. بس `.achievementUnlocked` (XP level-up) **مسموح** ✓.
- ملاحظة: الإشعارات المتكررة (ماء/تمرين/نوم 💧💪😴) **ما تمر** من PersonaGuard (تنجدول مباشرة عبر `center.add()`)، فهي ما تتأثر بهالقاعدة — بس تتأثر بـ TierGate (القسم F).

- **آخر 10 rejections:** لا يوجد ملف log persistent. الرفض يطلع عبر `diag.error` → os_log/unified logging فقط. يتشاف بـ Console.app على الجهاز بفلتر subsystem التطبيق + "PersonaGuard BLOCKED" / "AUDIT [notification]: rejected". **غير قابل للقراءة من هذا الفحص الساكن** (يتطلب جهاز/سجلّ حي).

---

## H. APNs Registration

📁 `AiQo/App/AppDelegate.swift`

- `application.registerForRemoteNotifications()` — **سطر 237** (داخل `if didCompleteOnboarding`).
  وأيضاً `NotificationService.swift:33` و`:52` بعد منح الإذن.
- **شرط الاستدعاء:** نفس بوابة `didCompleteOnboarding` (AppDelegate 234) — إذا onboarding ناقص ما يتسجّل أصلاً.
- `didRegisterForRemoteNotificationsWithDeviceToken` (سطر 334–341): يوصل فقط لو التسجيل نجح (entitlement APNs + شبكة)، يحوّل التوكن hex → `SupabaseService.updateDeviceToken()`.

> الأهم: **ماكو إرسال Push من السيرفر** (ماكو Edge Function ترسل إشعارات — تأكد من `AiQo_Notifications_System.md` §16). كل الإشعارات الحالية **محلية**. ⇒ APNs **مو** سبب غياب الإشعارات المحلية. هذا مسار غير ذي صلة بالشكوى.

---

## I. Runtime Snapshot

> ⚠️ **غير قابل للتنفيذ بهذا الفحص.** هذا تحليل ساكن للريبو (مو جلسة Debug على جهاز/محاكي). ما أقدر أشغّل تطبيق iOS أو أقرأ حالة `UNUserNotificationCenter` الحيّة. **ما راح أختلق قيم.**

للحصول عليها، شغّل بـ Debug ونفّذ بالـ LLDB / كود مؤقت:

```swift
// pending count + IDs
UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
    print("PENDING=\(reqs.count)")
    reqs.forEach { print("• \($0.identifier) cat=\($0.content.categoryIdentifier)") }
}

// authorization status
UNUserNotificationCenter.current().getNotificationSettings { s in
    print("authStatus=\(s.authorizationStatus.rawValue) " +
          "alert=\(s.alertSetting.rawValue) sound=\(s.soundSetting.rawValue)")
}
// authorizationStatus: 0=notDetermined 1=denied 2=authorized 3=provisional 4=ephemeral
```

**شنو نتوقّع حسب التحليل الساكن:**
- لو المستخدم مجاني (`.none`): `PENDING` ≈ 0 من المتكررات (انلغت بـ `cancelAllAutomatedNotifications`)؛ ممكن تشوف بس `trial.*` لو تجربة فعّالة.
- لو onboarding ناقص: `authStatus = 0` (notDetermined) — أقوى دليل.
- لو المستخدم رفض سابقاً: `authStatus = 1` (denied).

---

## J. UserDefaults Hard Cap State

> ⚠️ أسماء المفاتيح بالقالب (`hardCap_lastDelivery` …) **غلط**. الأسماء الحقيقية من `NotificationBrain.swift:30–34` (`enum HardCapKeys`):

| المفتاح الحقيقي | النوع | المعنى |
|---|---|---|
| `aiqo.notif.brain.hardcap.lastDelivered` | `Date` | وقت آخر تسليم (يقارن بـ 4 ساعات) |
| `aiqo.notif.brain.hardcap.dailyCount` | `Int` | عدّاد اليوم (سقف 3) |
| `aiqo.notif.brain.hardcap.dailyCountDate` | `Date` | تاريخ العدّاد (rollover منتصف الليل) |

> ⚠️ **غير قابل للقراءة من هذا الفحص الساكن** — قيم UserDefaults على الجهاز مو بالريبو. للفحص بـ Debug:

```swift
let d = UserDefaults.standard
print("lastDelivered=\(String(describing: d.object(forKey: "aiqo.notif.brain.hardcap.lastDelivered")))")
print("dailyCount=\(d.integer(forKey: "aiqo.notif.brain.hardcap.dailyCount"))")
print("dailyCountDate=\(String(describing: d.object(forKey: "aiqo.notif.brain.hardcap.dailyCountDate")))")
```

مفاتيح ذات صلة للفحص بنفس الوقت: `aiqo.purchases.currentTier` (Int — 0=none/1=max/2=trial/3=pro، يحدد TierGate)، `aiqo.notifications.didPromptPermission` (Bool)، أعلام onboarding (`didSelectLanguage`, `didShowFirstAuthScreen`, `didCompleteDatingProfile`, `didCompleteLegacyCalculation`, `didCompleteAIConsent`, `didAcknowledgeMedicalDisclaimer`, `didCompleteCaptainPersonalization`, `didCompleteFeatureIntro`).

---

## K. الخلاصة — الأعطال مرتّبة من الأخطر للأخف

### 1. 🔴 [الأخطر] بوابة الاشتراك تتطلب `.max` للإشعارات
**الموقع:** `TierGate.swift:89–90` (`requiredTier(.captainNotifications) = .max`) + كل مواقع `canAccess` بالقسم F.
**الأثر:** مستخدم مجاني/تجربة منتهية (`.none`) → `refreshAutomationState()` يلغي **كل** المتكررات ومهام الخلفية، وكل إشعارات التجربة/coach/الفورية محجوبة. صفر إشعارات عملياً.
**الحل (سطر واحد):** اسمح للإشعارات الأساسية للـ `.none` — إمّا `requiredTier(.captainNotifications)` يرجّع `.none`، أو افصل "إشعارات حياتية مجانية" عن "إشعارات الكابتن الذكية" وخلّي المتكررات الأساسية ما تنفحص بـ `.captainNotifications`.

### 2. 🔴 بوابة onboarding تمنع طلب إذن الإشعارات كلياً
**الموقع:** `AppDelegate.swift:225–236` (و`:277–286`) — `requestPermissions()` خلف `didCompleteOnboarding` المركّب من 8 أعلام.
**الأثر:** أي علم onboarding `false` → iOS ما يُسأل للإذن أبداً → `authStatus=.notDetermined` → صفر إشعارات. ماكو fallback غير الإعدادات اليدوية.
**الحل (سطر واحد):** اطلب إذن الإشعارات بنقطة أبكر/مستقلة عن اكتمال كل onboarding، أو ضيف fallback بـ `applicationDidBecomeActive` خارج بوابة `allOnboardingDone`.

### 3. 🔴 PersonaGuard `emoji_on_non_celebration` يرفض ~نص إشعارات التجربة بصمت
**الموقع:** `PersonaGuard.swift:30–33` + `CaptainIdentity.swift:36–44` (`emojiAllowedKinds` 3 أنواع فقط) + `NotificationBrain.swift:128–143`.
**الأثر:** كل إشعار `kind: .trialDay` (وكذلك `.streakSave`/`.streakRisk`) نصّه فيه إيموجي → رفض صامت. نصوص التجربة مليانة إيموجي (👋🔥📊💪🌤👀).
**الحل (سطر واحد):** أضِف `.trialDay` (و`.streakSave`/`.streakRisk`/`.hydrationReminder`) لـ `emojiAllowedKinds`، أو خلّي قاعدة الإيموجي تجرّد الإيموجي بدل ما ترفض الإشعار كامل.

### 4. 🟠 Hard Cap ثابت وخانق (1/4س، 3/يوم) غير حساس للـ tier
**الموقع:** `NotificationBrain.swift:27–28`.
**الأثر:** حتى لو انحلّت 1–3، المدفوع (trial/pro ميزانيته 7) ينحبس على 3/يوم وإشعار كل 4 ساعات. مساهم، مو سبب صفر لحاله.
**الحل (سطر واحد):** خلّي `hardCapDailyLimit`/`hardCapInterval` دالة بالـ tier (مثلاً pro: 6/يوم، 2س) بدل ثابت.

### 5. 🟡 تناقض ساعات الهدوء (22 مقابل 23)
**الموقع:** `QuietHoursManager.swift:8–9` (22–7) مقابل `SmartNotificationScheduler.swift:12–13` (23–7).
**الأثر:** سلوك غير متّسق بين 22:00–23:00 (Brain يؤجّل، المجدول لا). مو سبب صفر.
**الحل (سطر واحد):** وحّد المصدر — خلّي `SmartNotificationScheduler` يقرأ حدود `QuietHoursManager` بدل ثوابت مكرّرة.

### 6. ⚪️ APNs/Push — غير ذي صلة
ماكو إرسال Push من السيرفر؛ كل الإشعارات محلية. تسجيل APNs مو سبب الشكوى. (للعلم فقط.)

---

## التوصية التشخيصية (الخطوة الجاية — تتطلب جهاز)

رتّب التحقق هكذا على جهاز المستخدم بـ Debug:
1. اقرأ `aiqo.purchases.currentTier` + `FreeTrialManager.isTrialActiveSnapshot` → لو النتيجة `.none` ⇒ تأكّد العطل #1 هو السبب.
2. اقرأ `UNUserNotificationCenter.getNotificationSettings().authorizationStatus` → لو `0/notDetermined` ⇒ العطل #2؛ لو `1/denied` ⇒ المستخدم رفض (مشكلة منفصلة، حلّها توجيهه للإعدادات).
3. فلتر Console.app على "PersonaGuard BLOCKED" → لو يطلع بكثرة ⇒ العطل #3 فعّال.
4. اقرأ مفاتيح Hard Cap (القسم J) → لو `dailyCount ≥ 3` ⇒ العطل #4 يساهم اليوم.

**الأرجح إحصائياً:** المستخدم على tier `.none` (مجاني أو تجربة منتهية) → العطل #1 يفسّر الصمت الكامل لحاله.
