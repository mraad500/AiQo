# نظام الإشعارات في AiQo — شرح كامل لشلون يشتغل

> وثيقة تقنية تشرح كل إشعار بالتطبيق: منين يطلع، شنو يقرر يرسله، شوكت يرسل، وشلون يوصل للمستخدم.
> آخر تحديث: 2026-05-17 — يغطي إصدار v1.0.5 (build 21)، فرع `release/v1.0.4-memory-v4`.

---

## 1. الفكرة العامة (المعمارية)

كل إشعار "موجّه للمستخدم" بالتطبيق لازم يمر من **باب واحد** اسمه `NotificationBrain`. ماكو إشعار يطلع للمستخدم مباشرة من أي مكان بالكود — كله يدخل عبر:

```
NotificationBrain.shared.request(intent:)
```

النظام مبني على فلسفة "بوابة مركزية + طبقات حماية" حتى ما نزعج المستخدم بإشعارات وايد. التدفق العام:

```
مصدر الإشعار (مجدول / حدث / خلفية)
        │
        ▼
   NotificationIntent  ← يوصف "شنو نريد نرسل" + الأولوية + الإشارات
        │
        ▼
┌─────────────────────────────────────────────┐
│  NotificationBrain.request()  (الباب الوحيد) │
│                                              │
│  بوابة 0:  Hard Cap (سقف صارم)               │
│  بوابة 1:  GlobalBudget (ميزانية + هدوء)     │
│  بوابة 2:  تأليف الرسالة (MessageComposer)   │
│  بوابة 2.5: PersonaGuard (فحص الشخصية)       │
│  بوابة 3:  PrivacySanitizer (تنظيف الخصوصية) │
│  بوابة 4:  جدولة عبر iOS (UNUserNotif…)      │
└─────────────────────────────────────────────┘
        │
        ▼
   iOS يعرض الإشعار → المستخدم ينقر → AppDelegate يوجّهه للكابتن
```

**نقطة مهمة:** فيه طبقتين ميزانية فوق بعض — `Hard Cap` (دفاعية، أُضيفت بـ v1.0.4) و `GlobalBudget` (الأساسية). السبب: لمن Memory V4 انفعّل عالمياً، صار فيه ~15 محفّز (trigger) يسجّلون كلهم بنفس الوقت، فحطّينا سقف صارم حتى ما يصير "سيل إشعارات" بأول جلسة للمستخدم.

---

## 2. الباب الوحيد: `NotificationBrain`

📁 `AiQo/Features/Captain/Brain/06_Proactive/NotificationBrain.swift`

`actor` (آمن للتزامن) — `NotificationBrain.shared`. الدالة الرئيسية:

```swift
func request(
    _ intent: NotificationIntent,
    fireDate: Date? = nil,            // جدولة لوقت مستقبلي بدل الآن
    precomposedTitle: String? = nil,  // عنوان جاهز (يتخطى MessageComposer)
    precomposedBody: String? = nil,   // نص جاهز
    categoryIdentifier: String? = nil,// تجاوز الفئة الافتراضية
    userInfo: [String:String] = [:],  // حمولة للتوجيه (source, deepLink, trialKind…)
    identifier: String? = nil         // معرّف ثابت للإلغاء/منع التكرار
) async -> DeliveryResult
```

### البوابات بالترتيب (داخل `request()`)

| البوابة | السطر | شنو تسوي |
|---|---|---|
| **0 — Hard Cap** | 65–80 | يرفض إذا آخر إشعار قبل **أقل من 4 ساعات**، أو إذا انرسلت **3 إشعارات** اليوم. مخزّنة بـ `UserDefaults`. |
| **1 — GlobalBudget** | 82–98 | يستدعي `GlobalBudget.evaluate()` — ميزانية الاشتراك + ساعات الهدوء + cooldown (تفاصيل بالقسم 4). |
| **2 — تأليف الرسالة** | 100–125 | إذا فيه `precomposedTitle/Body` يستعملهم (مثل نصوص التجربة). وإلا `MessageComposer.composeRich()` يولّد نص بلهجة عراقية + سياق ثقافي + قراءة عاطفية. |
| **2.5 — PersonaGuard** | 128–143 | يفحص العنوان/النص: إذا فيه خرق لشخصية الكابتن → يرفض الإشعار. |
| **3 — PrivacySanitizer** | 145–153 | تنظيف دفاعي ثاني للـ PII (يشتغل على `MainActor`). |
| **4 — جدولة iOS** | 155–211 | يبني `UNMutableNotificationContent`، صوت `.default`، فئة حسب النوع، ومستوى المقاطعة حسب الأولوية، ثم `UNUserNotificationCenter.add()`. |

### مستوى المقاطعة حسب الأولوية (iOS 15+)

| الأولوية | `interruptionLevel` | السلوك |
|---|---|---|
| `ambient`, `low` | `.passive` | بدون صوت/اهتزاز، يجي بمركز الإشعارات بس |
| `medium`, `high` | `.active` | إشعار عادي بصوت |
| `critical` | `.timeSensitive` | يخترق وضع التركيز/عدم الإزعاج |

### بعد النجاح
- `GlobalBudget.recordDelivered()` — يزيد عدّاد اليوم + يسجّل cooldown
- `recordHardCapDelivery()` — يحدّث السقف الصارم
- `AuditLogger.record(.notificationDelivered)` — سجل تدقيق (log فقط)

ويرجّع `DeliveryResult` فيه: `intentID`, `decision` (Allowed/Rejected/Deferred…), `deliveredAt`, `systemRequestID`.

---

## 3. `NotificationIntent` — وصف الطلب

📁 `AiQo/Features/Captain/Brain/06_Proactive/Types/NotificationIntent.swift`

كل طلب إشعار يتحوّل لـ `NotificationIntent` فيه:

- **`kind`** — نوع الإشعار (28 نوع، انظر تحت)
- **`priority`** — `ambient(0)`, `low(1)`, `medium(2)`, `high(3)`, `critical(4)`
- **`signals`** — إشارات اختيارية: `memoryFactID`, `bioSnapshotSummary`, `emotionSummary`, `customPayload`
- **`requestedBy`** — اسم المُرسِل (للتدقيق)
- **`expiresAt`** — وقت انتهاء اختياري (إذا فات → يُسقَط بصمت)

### أنواع الإشعارات (`NotificationKind`)

| المجموعة | الأنواع |
|---|---|
| **صحة** | `morningKickoff`, `sleepDebtAcknowledgment`, `inactivityNudge`, `personalRecord`, `recoveryReminder` |
| **سلوكية** | `streakRisk`, `streakSave`, `disengagement`, `engagementMomentum` |
| **ذاكرة** | `memoryCallback` (السحر — يرجّع للمستخدم حقيقة قالها سابقاً) |
| **عاطفية** | `emotionalFollowUp`, `moodShift`, `relationshipCheckIn` |
| **زمنية/ثقافية** | `weeklyInsight`, `monthlyReflection`, `ramadanMindful`, `eidCelebration`, `jumuahSpecial`, `circadianNudge`, `weatherAdaptive` |
| **دورة الحياة** | `trialDay`, `achievementUnlocked` |
| **تمرين** | `workoutSummary` |
| **ماء** | `hydrationReminder` (ميزة مجانية) |

كل نوع يتربط بفئة (category) لـ iOS — مثلاً `morningKickoff → CAPTAIN_MORNING`, `streakRisk → CAPTAIN_STREAK`, الباقي → `CAPTAIN_DEFAULT` (السطور 326–346).

---

## 4. طبقات الميزانية والحماية (شنو يمنع السبام)

### 4.1 السقف الصارم (Hard Cap) — `NotificationBrain`
- **إشعار واحد كل 4 ساعات** (`hardCapInterval = 4*3600`)
- **3 إشعارات كحد أقصى باليوم** (`hardCapDailyLimit = 3`)
- مخزّن بـ `UserDefaults`، يُفحص قبل كل شي. هذا خط دفاع أخير فوق `GlobalBudget`.

### 4.2 `GlobalBudget`
📁 `AiQo/Features/Captain/Brain/06_Proactive/Budget/GlobalBudget.swift`

يفحص بالترتيب:
1. **انتهاء الـ intent** → إسقاط صامت
2. **حد iOS الـ 64 معلّق** — يحجز 4 خانات احتياط (يرفض إذا المعلّق ≥ 60)
3. **ميزانية الاشتراك اليومية** (انظر الجدول تحت). `critical` يقدر يتخطى السقف بإشعار واحد إضافي.
4. **ساعات الهدوء** — إذا غير `critical` → يؤجّل للصباح
5. **Cooldown** (عام + لكل نوع) — إذا غير `critical` → يرفض
6. **أنواع محجوبة حسب الاشتراك** — `monthlyReflection` للـ Pro/Trial فقط

### 4.3 ميزانية الاشتراك اليومية
📁 `AiQo/Core/Purchases/SubscriptionTier.swift:107`

| الاشتراك | إشعارات/24 ساعة |
|---|---|
| `none` (مجاني) | **2** |
| `max` (Core) | **4** |
| `trial` / `pro` | **7** |

> ملاحظة: السقف الصارم (3/يوم) أقوى من ميزانية trial/pro (7/يوم)، فعملياً المستخدم ما يشوف أكثر من 3 باليوم مهما كان اشتراكه — هذا مقصود لـ v1.0.4.

### 4.4 `CooldownManager`
📁 `AiQo/Features/Captain/Brain/06_Proactive/Budget/CooldownManager.swift`
- **Cooldown عام:** ساعتين بين أي إشعارين (`globalCooldownSeconds = 2*3600`)
- **Cooldown لكل نوع:** 6 ساعات لنفس النوع (`perKindCooldownSeconds = 6*3600`)

### 4.5 `QuietHoursManager`
📁 `AiQo/Features/Captain/Brain/06_Proactive/Budget/QuietHoursManager.swift`
- افتراضي: **22:00 → 07:00** محلي
- الإشعارات غير الحرجة بساعات الهدوء تتأجّل لـ `nextWakeDate` (الساعة 7 صباحاً)

> انتبه: المجدول `SmartNotificationScheduler` عنده ساعات هدوء **مختلفة شوية**: `23:00 → 07:00` (السطور 12–13). الإشعارات المجدولة بهذي الساعات تنزاح للساعة 7 صباحاً.

---

## 5. الإشعارات المجدولة المتكررة — `SmartNotificationScheduler`

📁 `AiQo/Features/Captain/Brain/06_Proactive/SmartNotificationScheduler.swift`

طبقة التنسيق الموحّدة لكل الإشعارات الآلية المتكررة. تستعمل `UNCalendarNotificationTrigger` (تكرار يومي/أسبوعي). تنجدول من `refreshAutomationState()` بشرط:
- `TierGate.canAccess(.captainNotifications)` يسمح (أو `DevOverride.unlockAllFeatures`)
- إذن الإشعارات ممنوح
- `AppSettingsStore.shared.notificationsEnabled == true`

### الإشعارات المتكررة (النصوص الحقيقية)

| النوع | المعرّف | الوقت | العنوان | النص |
|---|---|---|---|---|
| **ماء** 💧 | `water_reminder_{10,12,14,16,18,20}` | 10ص، 12، 2، 4، 6، 8م | `💧 وقت الماء` | 5 نصوص تتبادل، مثل: `"وقت الماء! 💧 خلّي جسمك رطب"` / `"كابتن حمّودي يقول: اشرب ماي يا بطل 💧"` |
| **تمرين** 💪 | `workout_motivation_daily` | وقت المستخدم المفضّل (مساءً افتراضياً) | `💪 وقت التمرين!` | عشوائي من 7: `"يلا يا بطل! وقت التمرين 💪 جسمك ينتظرك"` / `"ما في عذر اليوم! يلا قوم 🔥"` / `"كابتن حمّودي يقول: يلا نشغّل المحرك! 🚀"` |
| **نوم** 😴 | `sleep_reminder_nightly` | وقت المستخدم (10:30م افتراضي) | `😴 وقت النوم` | `"كابتن حمّودي يقول: النوم أهم من التمرين! خلّي جسمك ينتعش الليلة. تصبح على خير 🌙"` |
| **حماية الـ Streak** 🔥 | `streak_protection_evening` | 8:00 مساءً | `🔥 الـ Streak بخطر!` | `"لسه ما حققت هدفك اليوم! مشي سريع 15 دقيقة يكفي. لا تخلي الـ streak ينكسر 💪"` — مستوى `.timeSensitive` |
| **التقرير الأسبوعي** 📊 | `weekly_report_friday` | الجمعة 10ص | `📊 تقريرك الأسبوعي جاهز!` | `"كابتن حمّودي حضّر ملخص أسبوعك. تعال شوف شلون كان أداءك! 🏆"` |

> إشعار الماء يستعمل اسم المستخدم بأول نص: `"\(الاسم)! جسمك يحتاج ماء 💧 اشرب كوب الحين"`.

> هذي الإشعارات تنجدول مباشرة عبر `center.add()` (مو عبر `NotificationBrain`)، لأنها متكررة وثابتة. بس لا تزال محكومة بـ `TierGate`.

---

## 6. مهام الخلفية (Background Tasks)

تسجّل بـ `registerBackgroundTasks()` (تُستدعى من `AppDelegate`):

### 6.1 `aiqo.notifications.refresh` (BGAppRefreshTask)
- **متى:** الساعة 7:15 صباحاً أو 5:30 مساءً (`nextPreferredRefreshDate`)
- **شنو يسوي:** يولّد "coach nudge" — أول شي يستشير `ProactiveEngine` (الدماغ الذكي)، إذا قرر `.sendNotification` يرسل نص مخصّص بعنوان `"كابتن حمودي"`. وإلا يرجع لـ `IraqiCoachTemplates` (نص عراقي حسب الخطوات/النوم/الوقت).

### 6.2 `aiqo.notifications.inactivity-check` (BGProcessingTask)
- **متى:** من 2:05 ظهراً حتى 8:30 مساءً، يفحص كل ساعتين (`nextPreferredInactivityCheckDate`)
- **الشروط:** الساعة ≥ 14، مو بساعات الهدوء، الخطوات < 3000، وما انرسل إشعار خمول بآخر 3 ساعات (`backgroundInactivityCooldown = 3h`)
- **شنو يسوي:** يستشير `ProactiveEngine`، وإلا `CaptainBackgroundNotificationComposer.composeInactivityNotification()` (نص عربي محفّز حسب المستوى)

> النص الافتراضي إذا فشل التأليف:
> - عربي: `"هلا بطل، خلي هسه حركة صغيرة تعطي يومك روح. قوم وامش دقيقتين وخليها بداية قوية."`
> - إنجليزي: `"Captain Hamoudi says: start with one strong move now and build momentum before the day runs away from you."`

---

## 7. الإشعارات المبنية على الأحداث (Event-driven)

`NotificationBrain.subscribe()` تُستدعى من `AppDelegate` إذا الفلاغ `NOTIFICATION_BRAIN_ENABLED` مفعّل (افتراضياً `false` — dark launch). تشترك بـ 3 أحداث:

| الحدث (`Notification.Name`) | المُرسِل | الشرط | الإشعار الناتج |
|---|---|---|---|
| `.aiqoXPGranted` | `LevelStore.addXP()` | `didLevelUp == true` فقط (مو كل XP) | `.achievementUnlocked` — أولوية `high` |
| `.aiqoStreakIncremented` | `StreakManager.markTodayAsActive()` | streak ∈ `[3,7,14,30,60,90,180,365]` فقط | `.streakSave` — أولوية `medium` |
| `.aiqoStreakRisk` | `StreakManager.checkStreakContinuity()` | مرّ 22 ساعة+ بدون نشاط واليوم ما اكتمل | `.streakRisk` — أولوية `high` |

السبب من فلترة الـ milestones: ما نريد نزعج المستخدم كل يوم على الـ streak — بس بالأرقام المهمة.

---

## 8. إشعارات رحلة التجربة (Trial Journey)

📁 `AiQo/Services/Trial/TrialNotificationCopy.swift` — يديرها `TrialJourneyOrchestrator`

17 نوع إشعار خاص بفترة التجربة المجانية، نصوصها **جاهزة** (precomposed) بعربي/إنجليزي وتمر عبر `NotificationBrain` بـ `precomposedTitle/Body` + فئة `aiqo.trial.journey`:

| النوع | عينة (عربي) |
|---|---|
| `welcomeEvening` | `"هلا 👋"` — `"مشيت {خطوات} خطوة. شفتك اليوم — باجر راح أبدي أحجيك عدل."` |
| `morningBrief` | `"صباح الخير 🌤"` — `"نمت {س} ساعة. الجسم جاهز اليوم."` |
| `paceSpike` | `"👀 بطل كاعد تمشي سريع"` |
| `runDetected` | `"🔥 شفتك تركض"` |
| `inactivityGap` | `"صار لك شوية قاعد"` |
| `sleepDebt` | `"نومك اليوم قليل"` |
| `goalApproach` | `"💪 قربت من هدفك اليوم"` |
| `workoutCompleted` | `"🔥 أحسنت"` |
| `featureRevealSmartWake/Kitchen/Zone2` | كشف ميزات (نومك يحتاج ترتيب / خل أساعدك بالأكل / وقت تشتغل عدل) |
| `day6PaywallPreview` | `"بعد يوم وراح تنتهي تجربتك"` |
| `day7FinalDay` | `"اليوم آخر يوم بتجربتك"` |
| `day7WeeklyRecapReady` | `"📊 تقريرك الأول جاهز"` |
| `postTrialWeeklyReport` | `"📊 تقرير الكابتن الأسبوعي"` |

النصوص ديناميكية حسب: الاسم، الخطوات، السعرات، ساعات النوم، الرياضة المفضّلة، الهدف، رقم الأسبوع.

---

## 9. إشعارات انتهاء البريميوم — `PremiumExpiryNotifier`

📁 `AiQo/Services/Notifications/PremiumExpiryNotifier.swift`

3 إشعارات (تمر عبر `NotificationBrain`، تتعدّل لساعات الهدوء):

| التوقيت | العنوان | النص |
|---|---|---|
| **قبل يومين** | `باقي يومين على انتهاء البريميوم` | `"باقي يومين على انتهاء اشتراكك. إذا تريد، جدده يدوياً حتى يستمر بدون انقطاع."` |
| **قبل يوم** | `باقي يوم واحد على انتهاء البريميوم` | `"باقي يوم واحد على انتهاء اشتراكك. التجديد بقرارك إذا تحب تكمل."` |
| **عند الانتهاء** | `انتهت مدة بريميوم` | `"انتهت مدة بريميوم. إذا تريد ترجع الميزات، تقدر تشتري 30 يوم جديدة."` |

النبرة محايدة وغير ضاغطة عمداً (متطلب مراجعة App Store).

---

## 10. إشعار الصباح — `MorningHabitOrchestrator`

📁 `AiQo/Services/Notifications/MorningHabitOrchestrator.swift`

- يراقب عدد الخطوات بعد الاستيقاظ
- يطلق إشعار `morningKickoff` (أولوية `.low` → صامت على iOS 15+) لمن المستخدم يمشي **25 خطوة+ خلال نافذة 6 ساعات** صباحاً
- مرة وحدة باليوم. يُلغى إذا المستخدم قرأ الـ insight
- النص يتألّف عبر `CaptainBackgroundNotificationComposer` حسب وقت الاستيقاظ والخطوات، ويُسجّل بـ `ConversationThreadManager`

---

## 11. ملخّص التمرين — `AIWorkoutSummaryService` + ساعة Apple Watch

### التطبيق الرئيسي
📁 `AiQo/Services/Notifications/NotificationService.swift` (السطور 590–1047)
- يراقب نهاية تمارين HealthKit عبر `HKObserverQuery`
- يولّد ملخّص تمرين مع تحليل الـ zones (Zone 2 / Peak / متوازن)
- منع تكرار عبر بصمة (fingerprint) بنافذة 3 دقايق
- نص عربي/إنجليزي، مثال (Zone 2 ≥55%): `"عفية بطل، تمرين {النوع} لمدة {الدقايق} دقيقة كان موزون جداً بالزون تو، كمل بنفس الثبات…"`

### ساعة Apple Watch
📁 `AiQoWatch Watch App/WorkoutNotificationCenter.swift`
- فئة `AIQO_WORKOUT_LIVE`
- إشعار **ميلستون** أثناء التمرين (لمن الكيلومترات > 0): نبض + سعرات + الوقت المنقضي. معرّف `AIQO_WORKOUT_MILESTONE`
- إشعار **ملخّص** عند حفظ التمرين: مسافة + وقت + سعرات بعربي/إنجليزي. معرّف `AIQO_WORKOUT_SUMMARY`

---

## 12. الأذونات (Authorization)

📁 `AiQo/Services/Notifications/NotificationService.swift:19` — `ensureAuthorizationIfNeeded()`

التدفّق:
1. يفحص `UNUserNotificationCenter.getNotificationSettings()`
2. **`.authorized/.provisional/.ephemeral`** → يسجّل لـ APNs (`registerForRemoteNotifications`) ويرجّع `true`
3. **`.notDetermined`** → يطلب الإذن `requestAuthorization(options: [.alert, .sound, .badge])`. إذا انمنح → يسجّل APNs
4. **`.denied`** → يرجّع `false` وما يطلب مرة ثانية تلقائياً

**وين يُستدعى:**
- `AppDelegate.didFinishLaunchingWithOptions` (السطر 236) — بعد اكتمال الـ onboarding كامل
- `SmartNotificationScheduler.refreshAutomationState()` (السطر 110)
- زر الإعدادات لمن المستخدم يفعّل الإشعارات

---

## 13. الفئات والأزرار التفاعلية

📁 `AiQo/Services/Notifications/NotificationCategoryManager.swift`

| الفئة | الأزرار | الخيارات |
|---|---|---|
| `aiqo.captain.smart` | `OPEN_CAPTAIN` | `.customDismissAction` |
| `aiqo.trial.journey` | `OPEN_CAPTAIN` + `OPEN_DEEPLINK` | `.customDismissAction` |
| `AIQO_WORKOUT_LIVE` (ساعة) | خاص بالتمرين | — |

تُسجّل من `AppDelegate.didFinishLaunchingWithOptions` (السطر 220) عبر `registerAllCategories()`.

---

## 14. الـ Delegate — العرض والنقر والتوجيه

📁 `AiQo/App/AppDelegate.swift` (السطور 359–395) — `UNUserNotificationCenterDelegate`

### `willPresent` (إشعار يجي والتطبيق مفتوح)
يعرضه دائماً كبانر: `[.banner, .list, .sound, .badge]` (iOS 14+).

### `didReceive` (المستخدم نقر الإشعار)
1. يقرأ `userInfo`، يجيب `source` (مثل `captain_hamoudi`, `premium_expiry`)
2. تتبّع تحليلات: `notificationTapped`, `trialNotificationOpened`
3. `CaptainNotificationHandler.handleIncomingNotification()` — يخزّن الرسالة، يسجّل الفتح بـ `ConversationThreadManager`، يطلق حدث `captainLaunchFromNotification`
4. بعد 0.2 ثانية: `CaptainNavigationHelper.navigateToCaptainScreen()` — يفتح تبويب الكابتن

📁 التوجيه: `AiQo/Features/Captain/CaptainNotificationRouting.swift`

أيضاً `NotificationService.handle(response:)` يدعم deep-link عبر مفتاح `deepLink` (مثل `aiqo://captain`) عبر `DeepLinkRouter`، وتوجيه الأنواع القديمة (`NotificationType`) للتبويبات (gym/kitchen/home).

---

## 15. إعدادات المستخدم

📁 `AiQo/Core/AppSettingsScreen.swift`

| الإعداد | السلوك |
|---|---|
| **تفعيل الإشعارات** (toggle) | عند التفعيل: `requestPermissions()` + `refreshAutomationState()`. عند الإيقاف: `removeAllPendingNotificationRequests()` + إلغاء مهام الخلفية |
| **لغة الإشعارات** (Picker) | عربي / إنجليزي — يُخزّن بـ `NotificationPreferencesStore` (مفتاح `notificationLanguage`) ويُعاد جدولة المجدول |

> ماكو حالياً واجهة لتخصيص أنواع معيّنة أو ساعات الهدوء — هذي ثابتة بالكود.

---

## 16. الإشعارات البعيدة (Push / APNs) — الحالة

- التسجيل: `AppDelegate` → `application.registerForRemoteNotifications()`
- استلام التوكن: `didRegisterForRemoteNotificationsWithDeviceToken` → يحوّله hex → `SupabaseService.updateDeviceToken()`
- التخزين: التوكن يُحفظ بـ `UserDefaults` ("push_device_token") ويُزامَن لـ Supabase `auth.users` ضمن `user_metadata.device_token`
- الاستلام: `didReceiveRemoteNotification` → `handleRemoteNotification()`

**ملاحظة:** ماكو حالياً Edge Function مخصّصة لإرسال Push من السيرفر. التوكنات تُخزّن للاستخدام المستقبلي. عملياً كل الإشعارات الحالية **محلية (local)**.

---

## 17. الجدول الشامل — كل الإشعارات

| الإشعار | المُطلِق | التكرار | التوقيت | يمر عبر Brain؟ | Cooldown |
|---|---|---|---|---|---|
| ماء | مجدول | 6×/يوم | 10،12،2،4،6،8 | لا (مباشر) | تقويم متكرر |
| تمرين | مجدول | 1×/يوم | وقت المستخدم | لا (مباشر) | تقويم متكرر |
| نوم | مجدول | 1×/يوم | 10:30م (افتراضي) | لا (مباشر) | تقويم متكرر |
| حماية Streak | مجدول | 1×/يوم | 8م | لا (مباشر) | تقويم متكرر |
| تقرير أسبوعي | مجدول | 1×/أسبوع | الجمعة 10ص | لا (مباشر) | تقويم متكرر |
| Coach Nudge | مهمة خلفية | متغيّر | 7:15ص / 5:30م | لا (مباشر) | عام 2س |
| فحص الخمول | مهمة خلفية | متغيّر | 2:05م–8:30م كل 2س | لا (مباشر) | 3 ساعات |
| إشعار الصباح | محفّز خطوات | 1×/يقظة | بعد 25 خطوة+ | **نعم** | مرة باليوم |
| ترقية مستوى | حدث XP | متغيّر | عند `didLevelUp` | **نعم** | 2س عام / 6س نوع |
| ميلستون Streak | حدث streak | عند [3,7,14,30,60,90,180,365] | عند الزيادة | **نعم** | 2س عام / 6س نوع |
| خطر Streak | حدث streak | 1× عند الخطر | 22س+ بدون نشاط | **نعم** | 2س عام / 6س نوع |
| ملخّص تمرين | حدث HealthKit | 1×/تمرين | عند حفظ التمرين | جزئياً | بصمة 3 دقايق |
| انتهاء بريميوم | مجدول | 3 إجمالي | -2ي، -1ي، الانتهاء | **نعم** | مرة لكل انتهاء |
| رحلة التجربة | منسّق التجربة | 17 نوع | حسب يوم التجربة | **نعم** | عبر الميزانية |

**الكوابح المجمّعة:** سقف صارم 1/4س + 3/يوم — Cooldown عام 2س — Cooldown نوع 6س — ساعات هدوء 22:00–07:00 (المجدول 23:00–07:00) — ميزانية الاشتراك (2/4/7).

---

## 18. خريطة الملفات الأساسية

| الملف | الدور |
|---|---|
| `AiQo/Features/Captain/Brain/06_Proactive/NotificationBrain.swift` | الباب الوحيد + الاشتراك بالأحداث |
| `AiQo/Features/Captain/Brain/06_Proactive/Types/NotificationIntent.swift` | نوع الطلب + الأنواع + الأولويات |
| `AiQo/Features/Captain/Brain/06_Proactive/SmartNotificationScheduler.swift` | الإشعارات المجدولة + مهام الخلفية |
| `AiQo/Features/Captain/Brain/06_Proactive/Budget/GlobalBudget.swift` | الميزانية الأساسية |
| `AiQo/Features/Captain/Brain/06_Proactive/Budget/CooldownManager.swift` | الـ cooldown (عام + نوع) |
| `AiQo/Features/Captain/Brain/06_Proactive/Budget/QuietHoursManager.swift` | ساعات الهدوء |
| `AiQo/Services/Notifications/NotificationService.swift` | الأذونات + خدمات قديمة + ملخّص التمرين |
| `AiQo/Services/Notifications/NotificationCategoryManager.swift` | الفئات والأزرار التفاعلية |
| `AiQo/Services/Notifications/MorningHabitOrchestrator.swift` | إشعار الصباح |
| `AiQo/Services/Notifications/PremiumExpiryNotifier.swift` | انتهاء البريميوم |
| `AiQo/Services/Notifications/CaptainBackgroundNotificationComposer.swift` | تأليف نصوص الخلفية |
| `AiQo/Services/Trial/TrialNotificationCopy.swift` | نصوص رحلة التجربة |
| `AiQo/App/AppDelegate.swift` | دورة الحياة + الـ delegate + توكن APNs |
| `AiQo/Features/Captain/CaptainNotificationRouting.swift` | التوجيه وفتح الكابتن |
| `AiQo/Core/AppSettingsScreen.swift` | إعدادات المستخدم |
| `AiQo/Core/Purchases/SubscriptionTier.swift` | ميزانية الإشعارات لكل اشتراك |
| `AiQoWatch Watch App/WorkoutNotificationCenter.swift` | إشعارات تمرين الساعة |

---

## الخلاصة

نظام الإشعارات بـ AiQo **مركزي، مُحكَم ضد السبام، ومعرّب بلهجة عراقية** عبر شخصية "كابتن حمّودي". كل إشعار يمر (أو المفروض يمر) من `NotificationBrain` الذي يطبّق: سقف صارم → ميزانية → تأليف ذكي → فحص شخصية → تنظيف خصوصية → جدولة. الإشعارات المتكررة الثابتة (ماء/تمرين/نوم/streak/تقرير) تنجدول مباشرة لكن تبقى محكومة بـ `TierGate`. كل الإشعارات حالياً **محلية** — البنية التحتية للـ Push موجودة بس مو مفعّلة من السيرفر.
