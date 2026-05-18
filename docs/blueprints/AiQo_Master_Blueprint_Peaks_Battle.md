<div align="center">

<img src="AiQo.png" width="160" height="160" alt="AiQo app icon" />

# **AiQo**

*Master Blueprint · قِمَم & معركة (Peaks & Battle)*

**مرجع هندسي مكتفٍ ذاتياً لميزتَي التحدّيات — iOS · Captain Hamoudi (الكابتن حمّودي)**

</div>

---

# مخطّط قِمَم / معركة — التوثيق الكامل

*المرجع الموثوق الوحيد لميزتَي **قِمَم (Peaks)** و**معركة (Battle)** في تطبيق AiQo. مكتوب 2026-05-18 من قراءة كاملة وطازجة للكود الحيّ على الفرع `release/v1.0.4-memory-v4` (HEAD `cc30c4b`). هذا المستند **مكتفٍ ذاتياً**: سلّمه لمهندس جديد أو لذكاء اصطناعي آخر وسيفهم الميزتين بالكامل — ما هما، ماذا يحتويان، كيف يعملان داخلياً، أين الهشاشة — **بدون قراءة الكود**. كل رقم وكل عتبة وكل اسم مرحلة موثّق مع مرساة `path:line` قابلة للتحقق.*

> **العلاقة بـ Blueprint 19.** هذا المستند يوسّع §3 (الركيزتان 6 و8) و§6 من [AiQo_Master_Blueprint_19.md](AiQo_Master_Blueprint_19.md) إلى عمق تنفيذي كامل لهاتين الميزتين تحديداً. حيث تتعارض «معرفة الكابتن Part 12» (وثيقة الذاكرة) مع الكود الحيّ، **الكود يربح والاختلاف يُذكر صراحةً**.

---

## ملخّص تنفيذي (Arabic Executive Abstract)

**قِمَم (Peaks)** و**معركة (Battle)** هما نظاما التحدّي في AiQo، ويعيشان معاً في تبويبات نادي الجيم (`ClubRootView`) لكنهما **منفصلان تماماً في الكود والمنطق والاشتراك**:

- **قِمَم** = نظام «التحدّيات الأسطورية» (`Features/LegendaryChallenges/`): **8 أرقام قياسية عالمية** (مثل 152 ضغطة بدقيقة، بلانك 9.5 ساعة، 210,000 خطوة بـ24 ساعة). المستخدم يختار رقماً → يمرّ بفحص استرداد القلب **«قياس المحرك» (HRR)** على ساعة Apple → يولّد له النظام **مشروعاً متعدّد الأسابيع من 4 مراحل** (تأسيس → بناء → تكثيف → ذروة) → يسجّل أداءه أسبوعياً → الكابتن يراجع كل أسبوع عبر **Gemini**. **مقفولة على AiQo Intelligence Pro** (`canAccessPeaks → activeTier >= .pro`).

- **معركة** = نظام «QuestKit» (`Features/Gym/QuestKit/`): **10 مراحل × 5 تحدّيات لكل مرحلة**، كل تحدٍّ له **3 مستويات (مركز 3 → 2 → 1)**، بعضها يُتتبَّع تلقائياً من HealthKit وبعضها يدوي. المرحلة التالية تُفتح فقط عند إكمال **كل** تحدّيات المرحلة السابقة لأعلى مستوى. **مقفولة على AiQo Max** (`canAccessChallenges → activeTier >= .max`).

**ثلاث حقائق حمّالة قبل المتابعة:**

1. **«المركز» مقلوب عن «الـ tier» الداخلي.** داخلياً tier من 0 إلى 3 (3 = الأصعب). لكن واجهة المرحلة 1 تعرض **مركز 1 = الأصعب (tier 3)** ومركز 3 = الأسهل (tier 1). هذا أكثر تفصيل مضلِّل في النظام كلّه — §B2.
2. **الخطّة الأولية في قِمَم خوارزمية، ليست ذكاءً اصطناعياً.** الـ Gemini يُستدعى **فقط** في المراجعة الأسبوعية (`gemini-3-flash-preview`). توليد الخطّة الأولى رياضي صرف بدون شبكة — §A6.
3. **XP في معركة شبه معدوم.** رغم نسخة الكابتن «كل تحدّي يعطي XP»، الكود يمنح XP لتحدّيين فقط: `s1qLearn` (1000) و`s2qLearn` (2000). البقية صفر بالتصميم — §B7.

---

## 0. كيف تقرأ هذا المستند

| السؤال | القسم |
|---|---|
| ما هما، وأين يعيشان في الكود؟ | §1 خريطة المصطلحات + §A1 / §B1 |
| ما محتوى قِمَم (الأرقام، المشروع، الفحص)؟ | §A2 → §A6 |
| كيف تعمل قِمَم داخلياً (البيانات، الحالة)؟ | §A7 → §A9 |
| ما محتوى معركة (السلّم الكامل بكل العتبات)؟ | §B3 |
| كيف تعمل معركة داخلياً (التتبّع، الفتح، المحرّك)؟ | §B5 → §B8 |
| كيف يصل المستخدم إليهما والاشتراك؟ | §A3 / §B9 |
| ما الفروق الجوهرية بينهما؟ | §2 جدول المقارنة |
| أين الهشاشة وماذا أنتبه له؟ | §A10 / §B12 |
| فهرس `file:line` الكامل | §3 خريطة المصدر |

اصطلاح: `[ملف.swift](path)` مسار نسبي للمستودع؛ كل ادّعاء يحمل مرساة `path:line` تم التحقق منها بقراءة الملف كاملاً.

---

## 1. خريطة المصطلحات (Naming Map)

التطبيق عربي-أوّلاً؛ المعرّفات في الكود إنجليزية. الجدول يربط الاثنين:

| الواجهة (عربي) | الواجهة (إنجليزي) | المعرّف في الكود | الموقع |
|---|---|---|---|
| قِمَم / قمم | Peaks | `ClubTopTab.peaks`, `PeaksRecordsView`, `canAccessPeaks` | تبويب + شاشة |
| التحدّيات الأسطورية | Legendary Challenges | `LegendaryChallengesViewModel`, `LegendaryRecord` | نظام قِمَم بالكامل |
| قياس المحرك | Engine / HRR Assessment | `FitnessAssessmentView`, `HRRWorkoutManager` | فحص استرداد القلب |
| مشروع كسر الرقم | Record-breaking project | `RecordProject` (SwiftData), `RecordProjectManager` | المشروع متعدّد الأسابيع |
| المراجعة وضبط البوصلة | Weekly review | `WeeklyReviewView`, `WeeklyLog` | المراجعة الأسبوعية (LLM) |
| معركة | Battle | `ClubTopTab.battle`, `BattleChallengesView` | تبويب + شاشة |
| تحدّيات / كويست | Quests | `QuestEngine`, `QuestDefinition`, QuestKit | نظام معركة بالكامل |
| مرحلة | Stage | `stageIndex` (1…10) | المستوى الأعلى في السلّم |
| مركز | Center / Tier | `currentTier` (0…3) **مقلوب** | مستوى التحدّي الواحد |
| كابتن حمّودي | Captain Hamoudi | Gemini integration | المراجعة الأسبوعية فقط |

> **تحذير تسمية حرج:** يوجد في الكود نظامان منفصلان لكلٍّ من الميزتين، أحدهما حيّ والآخر ميّت:
> - **قِمَم:** `RecordProject` (SwiftData، **الحيّ**) مقابل `LegendaryProject` (struct، **جسر قديم** يغذّي `ProjectView` القديمة).
> - **معركة:** `QuestKit` (`QuestDefinition`/`QuestEngine`، **الحيّ**) مقابل نظام `Challenge` القديم (`Challenge.swift`, `ChallengeStage.swift`، **ميّت** — `BattleChallengesView` لا يلمسه إطلاقاً). لا تخلط `Challenge.stage1` بسلّم المعركة.

---

## 2. قِمَم مقابل معركة — جدول المقارنة الجوهري

| البُعد | قِمَم (Peaks) | معركة (Battle) |
|---|---|---|
| النظام في الكود | `Features/LegendaryChallenges/` | `Features/Gym/QuestKit/` + `Quests/Views/` |
| الواجهة الرئيسية | `PeaksRecordsView` ([QuestsView.swift:7](AiQo/Features/Gym/Quests/Views/QuestsView.swift)) | `BattleChallengesView` ([QuestsView.swift:39](AiQo/Features/Gym/Quests/Views/QuestsView.swift)) |
| المحرّك | `RecordProjectManager.shared` | `QuestEngine.shared` |
| الاشتراك | **Pro** (`canAccessPeaks ≥ .pro`) | **Max** (`canAccessChallenges ≥ .max`) |
| البنية | رقم واحد → مشروع طويل (10–24 أسبوع) | 50 تحدّياً (10 مراحل × 5) |
| التقدّم | زمني (`currentWeek/totalWeeks`) | إنجازي (إكمال tier 3 لكل تحدّي) |
| المثيل النشط | **مشروع واحد فقط** على مستوى التطبيق | كل التحدّيات متاحة بالتوازي |
| الذكاء الاصطناعي | **فقط** المراجعة الأسبوعية (Gemini) | **لا يوجد** (تتبّع بيانات صرف) |
| HealthKit | عبر الساعة (فحص HRR) + وزن يدوي | تتبّع تلقائي مكثّف (خطوات/نوم/مسافة…) |
| XP | **صفر** (لا XP في قِمَم إطلاقاً) | تحدّيان فقط (Learning 1000/2000) |
| التخزين | SwiftData (`captainContainer`) | SwiftData `QuestRecord` + UserDefaults fallback |
| الترس النموذجي | تأسيس→بناء→تكثيف→ذروة (4 مراحل) | tier 0→1→2→3 (3 عتبات) |

---

# الجزء A — قِمَم (Peaks)

## A1. ما هي، وأين تعيش

قِمَم هي الاسم الواجهي لنظام «التحدّيات الأسطورية»: المستخدم يتحدّى **رقماً قياسياً عالمياً حقيقياً** عبر مشروع تدريبي مُهيكل متعدّد الأسابيع، مع فحص لياقة افتتاحي وخطّة 4-مراحل ومراجعة أسبوعية من الكابتن.

- المجلّد: [AiQo/Features/LegendaryChallenges/](AiQo/Features/LegendaryChallenges/) — Models / ViewModels / Views / Components.
- نقطة الدخول: تبويب `.peaks` في [ClubRootView.swift:177](AiQo/Features/Gym/Club/ClubRootView.swift) → `PeaksRecordsView()`.
- المحرّك/الكاتب الوحيد: `RecordProjectManager.shared` (`@MainActor @Observable` singleton).

**فلسفة الميزة:** ليست «تمرين اليوم» — بل **التزام طويل** (10 إلى 24 أسبوعاً) نحو إنجاز خارق. لذلك التقدّم زمني (الأسبوع X من Y) لا أدائي، والمشروع النشط **واحد فقط** على مستوى التطبيق كلّه (`canStartNewProject() == (activeProject() == nil)`، [RecordProjectManager.swift:26](AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift)).

## A2. المحتوى — الأرقام القياسية الثمانية

مصدر الحقيقة: `LegendaryRecord.seedRecords` في [LegendaryRecord.swift:65-216](AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift). ثمانية سجلّات ثابتة (hardcoded). كل سجلّ `struct LegendaryRecord: Identifiable, Codable, Hashable` بحقول: `id`, `titleKey`, `targetValue: Double`, `unitKey`, `recordHolderKey`, `country` (عَلَم emoji), `year`, `category`, `difficulty`, `estimatedWeeks`, `storyKey`, `requirementKeys[]`, `iconName` (SF Symbol). النصوص العربية في [ar.lproj/Localizable.strings:2039-2106](AiQo/Resources/ar.lproj/Localizable.strings).

| # | id | العنوان (عربي) | الهدف | الوحدة | صاحب الرقم | الدولة/السنة | الفئة | الصعوبة | الأسابيع |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `pushup_1min` | أكثر ضغط بدقيقة | **152** | مرة | كوجي إيتشيهارا | 🇯🇵 2024 | قوة | أسطوري | **16** |
| 2 | `plank_hold` | أطول بلانك متواصل | **9.5** | ساعة | دانيال سكالي | 🇨🇿 2024 | تحمّل | أسطوري | **24** |
| 3 | `squats_1min` | أكثر سكوات بدقيقة | **70** | مرة | سلطان المرشدي | 🇰🇼 2023 | قوة | متقدم | **10** |
| 4 | `walk_24h` | أطول مشي بـ24 ساعة | **228.93** | كم | جيسي كاستاندا | 🇺🇸 2024 | كارديو | أسطوري | **20** |
| 5 | `burpees_1min` | أكثر بيربي بدقيقة | **48** | مرة | نيك أناستاسيو | 🇺🇸 2023 | كارديو | متقدم | **12** |
| 6 | `pullups_1min` | أكثر عقلة بدقيقة | **62** | مرة | مايكل إيكارد | 🇺🇸 2023 | قوة | أسطوري | **16** |
| 7 | `breath_hold` | أطول حبس نَفَس تحت الماء | **24.37** | دقيقة | بوديمير شوبات | 🇭🇷 2021 | صفاء | أسطوري | **12** |
| 8 | `steps_24h` | أكثر خطوات بـ24 ساعة | **210,000** | خطوة | ستيفن واتكينز | 🇬🇧 2023 | كارديو | أسطوري | **16** |

**التعدادات (Enums):**
- `ChallengeCategory: String` — قيمها العربية حرفياً ([LegendaryRecord.swift:31-45](AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift)): `.strength="قوة"`, `.cardio="كارديو"`, `.endurance="تحمّل"`, `.clarity="صفاء"`.
- `ChallengeDifficulty: Int` ([:49-61](AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift)): `.beginner=1`, `.advanced=2`, `.legendary=3`. (لا سجلّ يستخدم `.beginner` حالياً.)
- `formattedTarget` ([:219-230](AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift)): صحيح <1000 → `%.0f`؛ ≥1000 → NumberFormatter عربي (210000 → «٢١٠٬٠٠٠»)؛ غير ذلك → `%.1f` (9.5؛ 24.37→«24.4»).

`estimatedWeeks` هو **المُحدِّد الوحيد لطول المشروع** عند الإنشاء — لا إدخال من المستخدم يغيّره (المراجعة الأسبوعية اللاحقة فقط تستطيع تمديد `updatedTotalWeeks`).

## A3. الدخول والاشتراك (Pro)

في [ClubRootView.swift:177-188](AiQo/Features/Gym/Club/ClubRootView.swift):

```swift
case .peaks:
    if DevOverride.unlockAllFeatures || AccessManager.shared.canAccessPeaks {
        PeaksRecordsView()
    } else {
        CaptainLockedView(config: .init(
            title: "قِمَم",
            subtitle: "قِمَم تحتاج اشتراك AiQo Intelligence Pro — مشاريع كسر الأرقام القياسية.",
            iconSystemName: "mountain.2.fill", tier: .pro,
            onUpgradeTap: { showPeaksPaywall = true }))
    }
```

- `canAccessPeaks` = `activeTier >= .pro` ([AccessManager.swift:67](AiQo/Premium/AccessManager.swift)). **التبويب نفسه Pro حصراً.**
- `activeTier` ([AccessManager.swift:27-32](AiQo/Premium/AccessManager.swift)): مستوى `EntitlementStore` الحيّ؛ وإن كان `.none` و`FreeTrialManager.isTrialActive` → `.pro`. **التجربة المجانية تُحتسب Pro.**
- طبقة ثانية أدقّ: `LegendaryChallengeAccess` ([AccessManager.swift:52-63](AiQo/Premium/AccessManager.swift)): `.none/.max → .viewOnly`؛ `.trial/.pro → .full`. أي أن مستخدم **Max** قد يتصفّح بطاقات الأرقام في سطح `LegendaryChallengesSection` (viewOnly) لكن «ابدأ المشروع» يفتح الـ paywall — والتبويب الرئيسي يبقى Pro عبر `canAccessPeaks`.
- `DevOverride.unlockAllFeatures` (DEBUG فقط، Info.plist `AIQO_DEV_UNLOCK_ALL`؛ ثابت `false` في RELEASE) يتجاوز البوابة.

## A4. قياس المحرك — فحص استرداد القلب (HRR)

**ما الذي يقيسه:** سرعة عودة نبض القلب للهدوء بعد مجهود = قوة الجهاز نظير الودّي («البريك»). شرح المستخدم ([ar.lproj:1982-1989](AiQo/Resources/ar.lproj/Localizable.strings)): «جسمك فيه نظامين… السمبثاوي يدوس بنزين 🔥 والباراسمبثاوي يدوس بريك 🧊… هالفحص يكشف قوة البريك حقّك».

**البروتوكول — `FitnessAssessmentView`** ([Views/FitnessAssessmentView.swift](AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift)) آلة حالة من 4 خطوات (`@State step`):

1. **شرح** ([:64-186](AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift)): يوضّح النظامين + بطاقة «تحتاج Apple Watch». زرّ «يلا نبدأ الفحص ⚡» → `hrrManager.requestAuthorization()`. زرّ «تخطّي» → `skipAssessment()` (مشروع بدون بيانات HRR، خطّة `good` افتراضية).
2. **اختبار نشط 180 ثانية** ([:201-294](AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift)، `startActiveTest()` [:493](AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift)): صعود/نزول درجة بكادينس **24 صعدة/دقيقة**؛ مؤقّت 1Hz؛ يعرض النبض الحيّ + كبسولة المنطقة (<100 إحماء، <130 معتدل، <160 مكثّف، ≥160 أقصى) + تعليمات الكابتن الدوّارة. عند 0 → خطوة 3.
3. **استرداد 60 ثانية** ([:298-345](AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift)، `startRecoveryPhase()` [:517](AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift)): جلوس؛ يعرض هبوط النبض. عند 0 → `captureRecoveryHR()` يلتقط `recoveryHeartRate = currentHeartRate` بالضبط في نهاية النافذة، ثم `endWorkout()`.
4. **النتيجة** ([:349-430](AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift)): `level = calculateRecoveryLevel()`؛ بطاقة (Peak HR / Recovery HR / الفرق) + تعليق الكابتن. «ابدأ الخطة 🚀» → `createProjectWithHRR()`.

**المعادلة — `HRRWorkoutManager.calculateRecoveryLevel()`** ([HRRWorkoutManager.swift:228-236](AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift)) — التصنيف على **نبض الاسترداد المطلق بعد دقيقة**، **ليس** على الفرق peak−recovery:

```swift
if recoveryHeartRate < 100 { return .excellent }   // ممتاز 🔥
else if recoveryHeartRate <= 110 { return .good }  // جيد 👍
else { return .needsWork }                          // قابل للتطوير 💪
```

> `hrrDrop = max(peakHeartRate - recoveryHeartRate, 0)` ([:238-240](AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift)) يُعرض كـ«الفرق» لكنه **لا يُستخدم في التصنيف** — مصيدة شائعة.

**المعمار:** iPhone بلا حسّاس نبض. `HRRWorkoutManager` (`@MainActor @Observable`) يكلّم الساعة عبر `PhoneConnectivityManager.shared`؛ الساعة تشغّل جلسة `.highIntensityIntervalTraining` وتبثّ النبض snapshots عبر Combine ([:140-201](AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift)). مؤقّت 30ث: إن بقي `currentHeartRate==0` → خطأ «ما نقدر نقرأ النبض ⌚» ([:245-254](AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift)).

`RecoveryLevel: String` ([:8-47](AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift)) قيمها `"excellent"/"good"/"needsWork"` مع `titleAr`/`captainComment`/أيقونة/لون/emoji لكل حالة.

## A5. هيكل المشروع — الأربع مراحل ورياضيات الهدف

الخطّة تُولَّد في `RecordProjectManager.generateDefaultPlan(for:totalWeeks:hrrLevel:)` ([RecordProjectManager.swift:178-268](AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift)). لكل أسبوع `intensityFraction = weekNum / totalWeeks`، ثم المرحلة بالعتبة ([:196-204](AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift)):

| المرحلة | الشرط | المعنى |
|---|---|---|
| **تأسيس** | `intensityFraction <= 0.25` | Foundation |
| **بناء** | `<= 0.6` | Building |
| **تكثيف** | `<= 0.85` | Intensification |
| **ذروة** | `else` (> 0.85) | Peak |

مثال (16 أسبوع): تأسيس 1–4، بناء 5–9، تكثيف 10–13، ذروة 14–16. مثال (24 أسبوع — بلانك): تأسيس 1–6، بناء 7–14، تكثيف 15–20، ذروة 21–24.

**هدف الأسبوع** ([:181-207](AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift)): `startFraction` حسب مستوى HRR — `excellent → 0.25`، `good/default → 0.15`، `needsWork → 0.10`. ثم:

```
weeklyTarget = record.targetValue * (startFraction + intensityFraction * (1.0 - startFraction))
```

فالأسبوع 1 لمشروع ضغط `good` بـ16 أسبوع ≈ 152 × (0.15 + 0.0625×0.85) ≈ **30**؛ الأسبوع الأخير ≈ 152 × 1.0 = **152**.

**خطّة اليوم** ([:210-258](AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift)): 7 أيام. إن `hrrLevel=="needsWork"` فأول 4 أسابيع 4 أيام تدريب (يوم 3 راحة أيضاً)، غير ذلك 5. يوم 4 و7 «راحة نشطة»؛ يوم 6 «اختبار أسبوعي»؛ أيام التدريب: `setCount = min(3 + weekNum/4, 6)`، `repsPerSet = weeklyTarget/أيام/setCount`. نصيحة تغذية تدور من 4 نصوص (بروتين 1.6–2 غ/كغ، ≥3 لتر ماء، إلخ). المخرج JSON `{"weeklyPlan":[…]}` يُخزَّن في `RecordProject.planJSON`.

> **الخطّة الأولية خوارزمية بحتة — ليست Gemini.** رغم نسخة الواجهة «ابدأ المشروع ويا الكابتن»، تأليف الكابتن للخطّة الأولى **تجميلي**. المُدخلات: السجلّ المختار + `hrrLevel` فقط. لا شبكة، لا prompt.

## A6. المراجعة الأسبوعية — استدعاء Gemini الحقيقي الوحيد

`WeeklyReviewView.sendReviewToLLM()` ([WeeklyReviewView.swift:318-429](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift)) هو التكامل الفعلي الوحيد مع الدماغ/Gemini في قِمَم:

1. **قصر-دائرة بالاشتراك** ([:319-330](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift)): إن لم يكن `DevOverride` و`!TierGate.shared.canAccess(.weeklyInsightsNarrative)` (يتطلّب `.pro`) → قالب محدّد عبر `WeeklyReviewTemplateGenerator` (بدون شبكة). فالـ**Max يحصل على قالب، الـPro يحصل على Gemini**.
2. **بوابة موافقة** ([:332-335](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift)): `AIDataConsentManager.shared.ensureConsent(...)`؛ إلغاء إن لا موافقة.
3. **تعقيم**: `PrivacySanitizer().sanitizeText(...)` على النصوص الحرّة + تقريب الأرقام لخانة عشرية.
4. **النموذج/الـ endpoint** ([:371](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift)): `gemini-3-flash-preview:generateContent`، `timeout=25s`، `maxOutputTokens=220`, `temperature=0.35`, `responseMimeType=application/json`. مفتاح API: env/Info.plist `CAPTAIN_API_KEY` ← `COACH_BRAIN_LLM_API_KEY`.
5. **النظام-prompt**: «You are Captain Hamoudi reviewing a sanitized weekly fitness check-in. Return JSON only with keys: isOnTrack, captainMessage, adjustments, updatedTotalWeeks, warningIfAny.»
6. **النتيجة** → `ReviewResult` ([:465-472](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift)). ملاحظة: `nextWeekPlanJSON` **دائماً `nil`** من مسار الـLLM — الـLLM يمدّد `updatedTotalWeeks` فقط ولا يعيد كتابة خطّة الأيام. أي خطأ → `nil` → رسالة معلّبة «أحسنت! كمّل بنفس المستوى 💪».

`WeeklyReviewTemplateGenerator` ([WeeklyReviewTemplateGenerator.swift:3-78](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewTemplateGenerator.swift)): بديل offline ثنائي اللغة؛ `isOnTrack = weekRating>=4 || improvedPerformance`؛ تحذير إن احتوى العائق «إصابة/injury».

## A7. نموذج البيانات والتخزين

- **SwiftData**: `RecordProject` و`WeeklyLog` كلاهما `@Model`، مسجّلان في schema الكابتن/الذاكرة (`MemorySchemaV4/V5`، `CaptainSchemaV1/V2/V3`)، يعيشان في `captainContainer`. الربط: [AppDelegate.swift:62](AiQo/AppDelegate.swift) — `RecordProjectManager.shared.configure(container: captainContainer)`.
- **`RecordProject`** ([Models/RecordProject.swift:5-111](AiQo/Features/LegendaryChallenges/Models/RecordProject.swift)): `id, recordID, targetValue, totalWeeks, currentWeek (يبدأ 1), planJSON, bestPerformance, status ("active"|"completed"|"abandoned"), startDate, weeklyLogs[] (cascade), isPinnedToPlan (افتراضي true), completedTaskIDsJSON, hrrPeakHR?, hrrRecoveryHR?, hrrLevel?`. `progressFraction = currentWeek/totalWeeks` ([:107-110](AiQo/Features/LegendaryChallenges/Models/RecordProject.swift)) — **زمني، ليس أدائياً**.
- **`WeeklyLog`** ([Models/WeeklyLog.swift:5-39](AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift)): `weekNumber, date, currentWeight?, performanceThisWeek?, userFeedback?, captainNotes? (مخرج LLM), weekRating? (1–5), isOnTrack, obstacles?, project?`.
- **`RecordProjectManager`** ([RecordProjectManager.swift:8-315](AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift)) الكاتب/القارئ الوحيد: `activeProject()` يبحث `status=="active"`؛ `createProject` يحرس `canStartNewProject()` ويكتب مفاتيح `MemoryStore`؛ `addWeeklyLog` يربط السجلّ و**`currentWeek = min(currentWeek+1, totalWeeks)`** (هكذا يتقدّم المشروع)؛ `abandonProject`/`completeProject`.
- جسر قديم: `LegendaryProject`/`WeeklyCheckpoint`/`DailyTask` (structs `Codable` فقط، لا SwiftData) يغذّي `ProjectView` القديمة. هجرة لمرّة واحدة بعلَم `aiqo.legendaryChallengesMigrated` ([LegendaryChallengesViewModel.swift:33-78](AiQo/Features/LegendaryChallenges/ViewModels/LegendaryChallengesViewModel.swift)).

## A8. آلة الحالة ودورة الحياة

الحالة الحقيقية في `RecordProjectManager`: `status` ينتقل `active → completed/abandoned`؛ `currentWeek` يتقدّم بـ`addWeeklyLog` فقط ويُسقَّف عند `totalWeeks`. التقدّم = الزمن. **لا إكمال تلقائي عند بلوغ الهدف** — `completeProject()` موجود في المدير لكنه **لا يُستدعى من أي شاشة**؛ مسار «إنهاء المشروع» يستدعي `abandonProject` فقط. مشروع نشط **واحد** على مستوى التطبيق.

## A9. تدفّق الواجهة شاشة-بشاشة

1. **`PeaksRecordsView`** ([QuestsView.swift:7-35](AiQo/Features/Gym/Quests/Views/QuestsView.swift)): قائمة عمودية `RecordCardVertical` (شارة الفئة، `formattedTarget` ضخم + الوحدة، العنوان، «صاحب الرقم: … 🏳»). نقر → `RecordDetailView`.
2. **`RecordDetailView`** ([Views/RecordDetailView.swift](AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift)): بطل + 3 بطاقات (الصعوبة/المدة/الفئة) + القصّة + المتطلّبات + «ابدأ المشروع ويا الكابتن 🚀». يحرس `legendaryChallengeAccess == .full`؛ وإن وُجد مشروع نشط → تنبيه «عندك مشروع نشط، لازم تنهيه أول».
3. **`FitnessAssessmentView`** — فحص HRR ذو 4 خطوات (§A4). ينتهي بإنشاء `RecordProject` ودفع `RecordProjectView`.
4. **`RecordProjectView`** ([Views/RecordProjectView.swift](AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift)) — الشاشة الرئيسية: حلقة تقدّم `progressFraction` + «الأسبوع X من Y»؛ خطّة أيام الأسبوع الحالي؛ حقل تسجيل أداء → `logPerformance`؛ زرّ «المراجعة» → `WeeklyReviewView`؛ بطاقة رسالة كابتن معلّبة؛ زرّ إنهاء بتأكيد مزدوج → `abandonProject`.
5. **`WeeklyReviewView`** → إدخالات (وزن، أداء، تقييم 1–5، عائق) → `sendReviewToLLM` → `WeeklyLog` → `addWeeklyLog` (يقدّم الأسبوع) → `WeeklyReviewResultView`.
- سطح بديل: `LegendaryChallengesSection` (شريط أفقي مدمج) يستخدم `RecordCard` 280×180 ويظهر paywall `PremiumPaywallView(source: .legendaryChallenges)` لغير Pro.

## A10. مصائد وهشاشة (قِمَم)

1. **لا XP في قِمَم إطلاقاً** — صفر مكافآت/أوسمة. XP موجود حصراً في نظام معركة (ملف مشترك، ميزة مختلفة).
2. **التصنيف على النبض المطلق** (<100/≤110/>110)، ليس على الفرق المعروض.
3. **التقدّم زمني** لا أدائي؛ `completeProject()` لا يُستدعى من الواجهة (فقط `abandonProject`).
4. **نموذجا مشروع متعايشان** — `RecordProject` (SwiftData، الحيّ) و`LegendaryProject` (جسر قديم → `ProjectView`).
5. **مفاتيح الترجمة الإنجليزية غير متزامنة جزئياً** مع الكود؛ ملف **ar.lproj هو المرجع** (التطبيق عربي-أوّلاً).
6. الخطّة الأولية ليست AI — تجميل واجهي قد يُساء فهمه.

---

# الجزء B — معركة (Battle)

## B1. ما هي، وأين تعيش

معركة = «QuestKit»: **سلّم تقدّم من 10 مراحل، كل مرحلة 5 تحدّيات، كل تحدّي 3 مستويات (مركز)**. بعض التحدّيات يُتتبَّع تلقائياً من HealthKit وبعضها بإجراء يدوي. تُفتح المراحل بالتسلسل.

- المجلّد: [AiQo/Features/Gym/QuestKit/](AiQo/Features/Gym/QuestKit/) (المحرّك/البيانات) + [AiQo/Features/Gym/Quests/Views/](AiQo/Features/Gym/Quests/Views/) (الواجهة).
- نقطة الدخول: تبويب `.battle` في [ClubRootView.swift:190](AiQo/Features/Gym/Club/ClubRootView.swift) → `BattleChallengesView(questEngine:)`.
- المحرّك: `QuestEngine.shared` (`@MainActor ObservableObject` singleton، [QuestEngine.swift:23](AiQo/Features/Gym/QuestKit/QuestEngine.swift)).
- بيانات السلّم: `QuestDefinitions.baseDefinitions` ([QuestDefinitions.swift:8-922](AiQo/Features/Gym/QuestKit/QuestDefinitions.swift)).

## B2. ⚠️ انقلاب «المركز» ↔ «الـ tier» — اقرأ هذا أوّلاً

أكثر حقيقة مضلِّلة في النظام:

- `QuestProgressRecord.currentTier` عدد **0…3**. 0 = لا شيء، 3 = مكتمل تماماً.
- مصفوفة `tiers` فيها **3 عناصر بالضبط**. `tiers[0]` = العتبة **الأسهل**، `tiers[2]` = **الأصعب**. بلوغ `tiers[0]` → `currentTier=1`؛ بلوغ `tiers[2]` → `currentTier=3` (`evaluateTier`, [QuestEvaluator.swift:68-86](AiQo/Features/Gym/QuestKit/QuestEvaluator.swift)).
- **«المركز» المعروض مقلوب** عن الـtier، **وفقط للمرحلة 1** (`Stage1QuestFormatter.center(fromTier:)`, [QuestFormatting.swift:121-132](AiQo/Features/Gym/QuestKit/QuestFormatting.swift)):

| tier داخلي | مركز معروض | المعنى |
|---|---|---|
| 1 (بلغ `tiers[0]`) | **مركز 3** | الأدنى رتبةً (أسهل عتبة) |
| 2 (بلغ `tiers[1]`) | **مركز 2** | الوسط |
| 3 (بلغ `tiers[2]`) | **مركز 1** | الأعلى رتبةً (أصعب عتبة) |
| 0 | 0 | «غير مكتمل» |

> إذًا في السلّم: **«مركز 3 → 2 → 1» تعني `tiers[0] → tiers[1] → tiers[2]`** = الأسهل → الأصعب. **مركز 1 هو القمّة المرموقة.**

- **المراحل 2–10 لا تستخدم انقلاب «المركز» في شارة البطاقة** — تعرض `"المستوى %d/3"` بالـtier الخام مباشرة (`QuestCard.pillText`, [QuestCard.swift:84-94](AiQo/Features/Gym/Quests/Views/QuestCard.swift)). إطار «مركز 3→2→1» اصطلاح واجهي للمرحلة 1 + النموذج المفاهيمي في نصوص المستويات؛ المحرّك موحّد tier 0→3 في كل مكان.
- نصوص العتبات في الترجمة مكتوبة **الأصعب-أوّلاً** عرضياً (مثلاً «40د / 30د / 20د») بينما مصفوفة `tiers[]` **الأسهل-أوّلاً** (20, 30, 40). الترتيب النصّي تجميلي؛ **الأرقام الموثوقة هي مصفوفات `tiers:` في `QuestDefinitions.swift`**.

## B3. المحتوى — السلّم الكامل (10 مراحل × 5 تحدّيات)

مصدر الحقيقة: `QuestDefinitions.baseDefinitions` ([QuestDefinitions.swift:8-922](AiQo/Features/Gym/QuestKit/QuestDefinitions.swift)) + خانة المرحلة-2-مكان-3 المُعلَّمة ([:924-1018](AiQo/Features/Gym/QuestKit/QuestDefinitions.swift)). كل صف: `id` · العنوان (عربي / إنجليزي) · `type` · `source` · المقياس · **العتبات `tiers[0]/tiers[1]/tiers[2]`** (= مركز 3 / 2 / 1، الأسهل→الأصعب).

### المرحلة 1 — الاستيقاظ / Awakening
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s1q1` | شرارة الخير (مكافأة) | oneTime | manual | manualCount | 1/1/1 — **منطقي** (§B6) |
| `s1qLearn` | شرارة التعلم | oneTime | learning | learningCertificate | 1/1/1 — منطقي · **XP 1000** |
| `s1q4` | نبض زون 2 (تراكمي) | cumulative | workout | zone2Minutes | **20 / 30 / 40** دقيقة |
| `s1q3` | عرش التعافي (يومي) | daily | healthkit | sleepHours | **7.0 / 7.5 / 8.0** ساعة |
| `s1q2` | نبع الماء (يومي) | daily | water | waterLiters | **2.0 / 2.5 / 3.0** لتر |

### المرحلة 2 — تشغيل المحرك / Engine Start
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s2q1` | دقة آلة الرؤية (كاميرا) | oneTime | camera | ضغط + دقّة | **ثنائي:** 10@70% / 15@85% / 20@100% |
| `s2q2` | الحركة في يوم واحد | daily | healthkit | distanceKM | **3 / 5 / 6** كم |
| خانة 3 | *مُعلَّمة بفلاغ* — §B4 | — | — | — | — |
| `s2q4` | جلسة امتنان | daily | timer | timerMinutes | **2 / 3 / 5** دقيقة |
| `s2q5` | سلسلة الوقود | streak | water | comboStreakDays | **1 / 2 / 3** يوم (يوم يتأهّل ≥2.0ل) |

### المرحلة 3 — كسر منطقة الراحة / Breaking the Comfort Zone
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s3q1` | نسبة هدف الحركة | daily | healthkit | movePercent | **70 / 90 / 100** % |
| `s3q2` | بناء الضغط | cumulative | manual | manualCount | **20 / 40 / 50** عدّة |
| `s3q3` | حارس زون 2 | cumulative | workout | zone2Minutes | **30 / 45 / 60** دقيقة |
| `s3q4` | سلسلة التعافي | streak | healthkit | comboStreakDays | **1 / 2 / 3** يوم (≥7س نوم) |
| `s3q5` | ساعد شخصين (مكافأة) | weekly | manual | manualCount | 1 / 2 / 2 (الهدف المعروض 2) |

### المرحلة 4 — عجلة الزخم / Momentum Wheel
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s4q1` | الخطوات | daily | healthkit | steps | **8000 / 10000 / 12000** |
| `s4q2` | سلم البلانك | cumulative | timer | timerSeconds | **60 / 120 / 180** ثانية |
| `s4q3` | ضغط بالرؤية (كاميرا) | oneTime | camera | ضغط + دقّة | **ثنائي:** 15@70% / 25@85% / 30@100% |
| `s4q4` | نسبة هدف الحركة | daily | healthkit | movePercent | **80 / 100 / 110** % |
| `s4q5` | سلسلة الماء | streak | water | comboStreakDays | **2 / 3 / 4** يوم (عتبات يومية [2.0,2.5,3.0]ل) |

### المرحلة 5 — الانضباط الحديدي / Iron Discipline
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s5q1` | سلسلة زون 2 | streak | workout | comboStreakDays | **2 / 3 / 4** يوم (عتبات [25,30,35]د) |
| `s5q2` | بناء الضغط | cumulative | manual | manualCount | **40 / 60 / 70** عدّة |
| `s5q3` | سلسلة الخطوات | streak | healthkit | comboStreakDays | **2 / 3 / 4** يوم (عتبات [8000,10000,10000]) |
| `s5q4` | جلسة صفاء | daily | timer | timerMinutes | **3 / 5 / 7** دقيقة |
| `s5q5` | ساعد 3 غرباء (مكافأة) | weekly | manual | manualCount | 1 / 2 / 3 (الهدف المعروض 3) |

### المرحلة 6 — التدفّق / The Flow
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s6q1` | دقة الرؤية المطلقة (كاميرا) | oneTime | camera | ضغط + دقّة | **ثنائي:** 30@70% / 40@85% / 50@100% |
| `s6q2` | مسافة ممتدة | daily | healthkit | distanceKM | **6 / 8 / 10** كم |
| `s6q3` | سلسلة الحركة | streak | healthkit | comboStreakDays | **2 / 3 / 4** يوم (عتبات [90,100,110]%) |
| `s6q4` | بلانك | cumulative | timer | timerSeconds | **120 / 180 / 240** ثانية |
| `s6q5` | سلسلة النوم | streak | healthkit | comboStreakDays | **2 / 3 / 4** يوم (عتبات [7,7.5,8]س) |

### المرحلة 7 — وعي القبيلة / Tribe Consciousness
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s7q1` | نبض القبيلة (الساحة) | cumulative | social | socialInteractions | **1 / 2 / 3** (deepLink الساحة) |
| `s7q2` | زون 2 العظيم | cumulative | workout | zone2Minutes | **45 / 60 / 75** دقيقة |
| `s7q3` | الخطوات | daily | healthkit | steps | **10000 / 12000 / 14000** |
| `s7q4` | سلسلة الماء | streak | water | comboStreakDays | **3 / 4 / 5** يوم (≥2.5ل/يوم) |
| `s7q5` | مشاركة إنجاز (مكافأة) | oneTime | share | shares | **1 / 2 / 3** (deepLink مشاركة) |

### المرحلة 8 — التحكم الذهني / Mind Control
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s8q1` | الخطوات | daily | healthkit | steps | **12000 / 14000 / 16000** |
| `s8q2` | بناء الضغط | cumulative | manual | manualCount | **60 / 80 / 100** عدّة |
| `s8q3` | الرؤية المثالية (كاميرا) | oneTime | camera | ضغط + دقّة | **ثنائي:** 40@70% / 50@85% / 60@100% |
| `s8q4` | سلسلة الحركة | streak | healthkit | comboStreakDays | **2 / 3 / 4** يوم (≥100% حركة) |
| `s8q5` | سلسلة الامتنان | streak | timer | comboStreakDays | **2 / 3 / 4** يوم (≥120ث) |

### المرحلة 9 — موت الأنا / Ego Death
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s9q1` | الحركة في يوم واحد | daily | healthkit | movePercent | **110 / 130 / 150** % |
| `s9q2` | بلانك | cumulative | timer | timerSeconds | **180 / 240 / 300** ثانية |
| `s9q3` | الساحة المتقدمة | cumulative | social | socialInteractions | **2 / 3 / 5** (deepLink الساحة) |
| `s9q4` | سلسلة الخطوات | streak | healthkit | comboStreakDays | **3 / 4 / 5** يوم (≥10000 خطوة) |
| `s9q5` | أثر حقيقي: ساعد 5 غرباء (مكافأة) | oneTime | manual | manualCount | **1 / 3 / 5** |

### المرحلة 10 — أسطورة AiQo / AiQo Legend
| id | العنوان | type | source | المقياس | مركز 3 / 2 / 1 |
|---|---|---|---|---|---|
| `s10q1` | أسبوع المحارب | weekly | healthkit | stepDaysInWeek | **3 / 4 / 5** يوم (يوم يُحتسب ≥10000 خطوة) |
| `s10q2` | دقة الرؤية الأسطورية (كاميرا) | oneTime | camera | ضغط + دقّة | **ثنائي:** 60@85% / 80@95% / 100@100% |
| `s10q3` | سلسلة التعافي المركبة | **combo** | healthkit | comboStreakDays | **2 / 3 / 4** يوم (نوم≥7س **و** ماء≥2.5ل معاً) |
| `s10q4` | قلب الأسد (كارديو) | cumulative | workout | cardioMinutes | **60 / 90 / 120** دقيقة |
| `s10q5` | مشاركة «شارة الأسطورة» (مكافأة) | oneTime | share | shares | **1 / 2 / 3** (deepLink مشاركة) |

`TierRequirement` ([QuestKitModels.swift:66-69](AiQo/Features/Gym/QuestKit/QuestKitModels.swift)): `.singleMetric(value,unit)` أو `.dualMetric(valueA,unitA,valueB,unitB)`. `QuestMetricUnit` ([:25-35](AiQo/Features/Gym/QuestKit/QuestKitModels.swift)): count, liters, hours, minutes, seconds, kilometers, percent, days, none.

## B4. خانة المرحلة-2-مكان-3 (متغيّر مُعلَّم بفلاغ)

[QuestDefinitions.swift:924-1018](AiQo/Features/Gym/QuestKit/QuestDefinitions.swift). تُحَلّ مرّة عند تهيئة `QuestEngine.shared` (قلب الفلاغ يحتاج إعادة تشغيل). ثلاث إمكانيات (كلّها `rewardImageOverride: "2.3"`):

- **`learningSparkStage2Quest`** (الافتراضي، الإنتاج) — `s2qLearn`، شرارة التعلّم، `oneTime/learning`، tier واحد `[1]`، **XP 2000**. نشط عند `FeatureFlags.learningSparkStage2Enabled`.
- **`plankLadderQuest`** (تراجُع) — `s2q3`، سلم البلانك، `cumulative/timer`، **30/60/90 ثانية**. نشط عند إطفاء فلاغ التعلّم وتشغيل `plankLadderChallengeEnabled`.
- **`stage2PlaceholderQuest`** (طوارئ، لم يُشحَن) — `s2q3_placeholder`، «قريباً»، غير تفاعلي (`.disabled` في [QuestsView.swift:90](AiQo/Features/Gym/Quests/Views/QuestsView.swift)). فقط عند إطفاء الفلاغين.

## B5. آلية التتبّع — تلقائي (HealthKit) مقابل يدوي

يحرّكها `QuestSource` ([QuestKitModels.swift:12-23](AiQo/Features/Gym/QuestKit/QuestKitModels.swift)): `manual, water, healthkit, camera, timer, workout, social, kitchen, share, learning`. حلقة التحديث: `QuestEngine.performRefresh` ([QuestEngine.swift:339-482](AiQo/Features/Gym/QuestKit/QuestEngine.swift)).

**HealthKit (تلقائي، `source==.healthkit`)** عبر `QuestHealthKitDataSource` (actor، [QuestDataSources.swift:65-244](AiQo/Features/Gym/QuestKit/QuestDataSources.swift)):
- `stepCount` → `.steps` (مجموع تراكمي اليوم)
- `distanceWalkingRunning` → `.distanceKM` (متر/1000)
- `activeEnergyBurned` → `.movePercent` (kcal / `moveGoalKcal`؛ الهدف من UserDefaults، fallback **400.0**)
- `sleepAnalysis` → `.sleepHours` (نافذة `startOfDay−6h` … `+12h`؛ يجمع core/deep/REM/unspecified؛ `hasData` يبوّب حالة «لا بيانات نوم»)
- `.stepDaysInWeek` (المرحلة 10 س1): يعدّ أيام الأسبوع ISO بـ`fetchDailySteps ≥ 10000` (**ثابت 10000** لا عتبة التحدّي).

**يدوي/أحداث تطبيق:** `.water` (سهم +0.25ل + fallback UserDefaults يومي) · `.timer` (start/stop) · `.workout` (إدخال دقائق، `.zone2|.cardio`) · `.camera` (تحدّي ضغط بالرؤية → `QuestPushupChallengeView` يرجّع `(reps, accuracy)`) · `.social` (تسجيل تفاعل + توجيه للساحة — **«V2 Post-Launch» غير موصول بمصدر ساحة حقيقي بعد**) · `.share` (`UIActivityViewController`، يُحتسب فقط إن `completed==true`) · `.manual` (زرّ «أكد الإنجاز») · `.learning` (`CertificateVerifier` بـApple Vision على الجهاز، 5-حالات).

**كيف يُمنح «المركز» — `QuestEvaluator.evaluateAndAssignTier`** ([QuestEvaluator.swift:88-130](AiQo/Features/Gym/QuestKit/QuestEvaluator.swift)): تحدّيات المرحلة-1 المنطقية تُختصَر؛ القيمة تُقصَّ لـ`[0, آخر هدف]`؛ `evaluateTier` يمرّ على العتبات الثلاث (`singleMetric`: `metricA≥value`؛ `dualMetric`: `metricA≥valueA AND metricB≥valueB`)؛ `currentTier=أعلى عتبة مُحقَّقة`؛ `isCompleted = tier>=3`.

**السلاسل (streak/combo)** ([:132-175](AiQo/Features/Gym/QuestKit/QuestEvaluator.swift)): يوم «يتأهّل» إن بلغ مقياسه عتبة اليوم؛ العتبة من `streakTierTargetsA[min(tier,2)]` أو `streakDailyTargetA`؛ ثم `metricAValue = طول السلسلة` ويُقارَن بعتبات عدد-الأيام. `s10q3` (combo) يتطلّب نوم≥A **و** ماء≥B معاً. **إعادات الفترة** ([:16-66](AiQo/Features/Gym/QuestKit/QuestEvaluator.swift)): `.daily` يُصفَّر عند تغيّر مفتاح اليوم؛ `.weekly` عند تغيّر أسبوع ISO؛ `.oneTime/.cumulative` **لا تُصفَّر أبداً** (تقدّم دائم).

## B6. منطق الفتح والتقدّم

`QuestEngine.isStageUnlocked(_:)` ([QuestEngine.swift:149-162](AiQo/Features/Gym/QuestKit/QuestEngine.swift)):
- **المرحلتان 1 و2 مفتوحتان دائماً** (`stageIndex <= 2`).
- المرحلة N (N≥3) تُفتح **إذا وفقط إذا كل تحدّيات المرحلة N−1 عند `currentTier >= 3`** (أي كلّها وصلت مركز 1 / الأصعب): `previousQuests.allSatisfy { getProgress($0).currentTier >= 3 }`. لا فتح جزئي ولا تحدّي «بوس».
- دقّة مهمّة: التحدّيات اليومية تُصفَّر منتصف كل ليلة، فيجب أن تكون **كل** الخمسة عند tier 3 **في آن واحد** (التراكمي/oneTime دائم، اليومي/الأسبوعي متقلّب) كي تُفتح التالية.

`stageCompletion` = (عدد التحدّيات عند tier≥3) / (العدد). مرحلة مقفولة → أيقونة قفل + `.disabled` + رسالة «أكمل جميع تحديات المرحلة السابقة» ([QuestsView.swift:249-271](AiQo/Features/Gym/Quests/Views/QuestsView.swift)).

**تحدّيات المرحلة-1 المنطقية** (`s1q1`، `s1qLearn`): done/not-done صرف — إن اكتمل: `metricA=1, tier=3`؛ وإلا صفر ([QuestEvaluator.swift:93-112](AiQo/Features/Gym/QuestKit/QuestEvaluator.swift)).

## B7. XP والمكافآت — الواقع مقابل النسخة

- **XP يُمنح لكل تحدّي فقط إن كان له مدخل صريح في `QuestXPRewards.perQuestID`** ([QuestXPRewards.swift:15-20](AiQo/Features/Gym/Quests/Store/QuestXPRewards.swift)). حالياً **اثنان فقط**: `s1qLearn = 1000`، `s2qLearn = 2000`. البقية تُرجِع `nil` → **لا منح XP** (صمّام أمان متعمّد؛ لا default، لا `addXP(0)`).
- مسار المنح: `BattleChallengesView.saveQuestAchievement` ([QuestsView.swift:281-306](AiQo/Features/Gym/Quests/Views/QuestsView.swift)) عند إغلاق احتفال الإكمال؛ محروس بـ`QuestAchievementStore` (`guard !achievements.contains(questId)`) → **مرّة واحدة لكل تحدّي للأبد**. ثم `LevelStore.shared.addXP(xp)` + إشعار `XPUpdated`.
- **لا XP لكل مركز ولا لكل مرحلة** في الكود. نسخة الكابتن «كل تحدّي يكمله المستخدم يعطي XP ويرفع المستوى» **طموحية**؛ الواقع جدول التحدّيين أعلاه.
- `RewardSeed.defaultCatalog` ([QuestSwiftDataStore.swift:309-376](AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift)) يبذر 5 أوسمة/صناديق `Reward` (كتالوج منفصل، غير موصول بتدفّق إكمال المعركة في المسارات المقروءة — معلوماتي).

## B8. دواخل QuestEngine والتخزين

`@MainActor final class QuestEngine: ObservableObject`، singleton `.shared` ([QuestEngine.swift:23](AiQo/Features/Gym/QuestKit/QuestEngine.swift)). حالة `@Published`: `stages` (تُبنى مرّة عند التهيئة)، **`progressByQuestId: [String: QuestProgressRecord]`** (الخريطة الحيّة؛ `BattleChallengesView` يراقبها بـ`.onChange`)، `isRefreshing`, `isHealthAuthorized`, `hasSleepDataInOvernightWindow`. `#if DEBUG debugOverrides`.

تدفّق التحديث: `refreshAllProgress` → `Task { performRefresh }` → يبذر السجلّات الناقصة، يسحب كل مقاييس HK + أحداث التطبيق مرّة، يطبّق `applyPeriodResets` ثم التقييم، يكتب `progressByQuestId`، `persist()`. محفّزات: التهيئة، `willEnterForeground`، إشعار خطّة المطبخ، `BattleChallengesView.onAppear`.

**تخزين بطبقتين:**
1. `UserDefaultsQuestProgressStore` — JSON تحت `aiqo.quest.progress.records.v1`.
2. **SwiftData override** — `QuestPersistenceController.shared` ([QuestSwiftDataStore.swift:11-215](AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift)) بحاوية «QuestLootEngine» (schema: `PlayerStats, QuestStage, QuestRecord, Reward, AiQoDailyRecord, WorkoutTask, Arena*`). تُلصَق في `AppRootView` وتتجاوز الحاوية الخارجية، لذلك تسرد كل نماذج السياق. `installQuestPersistence` يبدّل المحرّك لـ`SwiftDataQuestProgressStore`؛ أوّل تشغيل يهاجر سجلّات UserDefaults القديمة.

`QuestProgressRecord` ([QuestKitModels.swift:176-259](AiQo/Features/Gym/QuestKit/QuestKitModels.swift)): `{questId, currentTier, metricAValue, metricBValue, lastUpdated, isStarted, startedAt?, streakCount, lastCompletionDate?, lastStreakDate?, resetKeyDaily?, resetKeyWeekly?, isCompleted, completedAt?}` + decoder دفاعي (`decodeIfPresent` لكل حقل — متوافق-أماماً).

## B9. الدخول والاشتراك (Max)

[ClubRootView.swift:190-201](AiQo/Features/Gym/Club/ClubRootView.swift):

```swift
case .battle:
    if DevOverride.unlockAllFeatures || AccessManager.shared.canAccessChallenges {
        BattleChallengesView(questEngine: questEngine)
    } else {
        CaptainLockedView(config: .init(
            title: "معركة",
            subtitle: "افتح معركة مع اشتراك AiQo Max — 10 مراحل تحديات على بياناتك.",
            iconSystemName: "flag.checkered", tier: .max,
            onUpgradeTap: { showBattlePaywall = true }))
    }
```

- `canAccessChallenges` = `activeTier >= .max` ([AccessManager.swift:40](AiQo/Premium/AccessManager.swift)).
- **`SubscriptionTier`** ([SubscriptionTier.swift:7-30](AiQo/Core/Purchases/SubscriptionTier.swift)): الخام `none=0, max=1, trial=2, pro=3` لكن المقارنة بـ`rank`: `none→0, max→1, trial→2, pro→2`. فـ`>= .max` يحقّقه **Max و Pro والتجربة النشطة**؛ يُحجَب فقط لـ`.none`.
- نفس بوابة `>= .max` تحرس الكابتن/الجيم/المطبخ/MyVibe. (وفق ذاكرة المشروع: نموذج «paywall قابل للتخطّي + بوابات داخلية» في v1.0.5.)
- لا `TierGate`/فحوص tier داخل `BattleChallengesView`؛ البوابة كلّها عند حدّ التبويب. داخلياً كل المراحل متاحة رهناً بمنطق الفتح المتسلسل فقط.

## B10. تدفّق الواجهة شاشة-بشاشة

`BattleChallengesView` ([QuestsView.swift:39-390](AiQo/Features/Gym/Quests/Views/QuestsView.swift))، RTL مفروض للعربية:
1. **شريط المراحل (يسار):** عمود 10 دوائر مرقّمة؛ المقفولة `lock.fill` + شفافية 50% + `.disabled`؛ المختارة ذهبية `#EBCF97`.
2. **`stageHeader`:** «المرحلة N» + اسم المرحلة.
3. **بطاقات التحدّي:** إن `isStageUnlocked` → `ForEach selectedStage.quests` → `QuestCard`. خانة placeholder غير تفاعلية. مقفولة → رسالة قفل.
4. **`QuestCard`** ([QuestCard.swift](AiQo/Features/Gym/Quests/Views/QuestCard.swift)): صورة الشارة، العنوان، نصّ المستويات، شارة (مرحلة 1 = «مركز N»؛ 2–10 = «المستوى N/3»)، تقدّم `current/target`، `ProgressView`. لون البطاقة يتناوب بيج/نعناعي حسب فردية المرحلة.
5. **نقر بطاقة →** `.sheet QuestDetailSheet` (`.medium`/`.large`).
6. **`QuestDetailSheet`** ([QuestDetailSheet.swift](AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift)): شارة 78pt، شرح، فوائد، كيفية، تقدّم حالي، ثم **زرّ إجراء حسب المصدر** (healthkit=بطاقة تتبّع تلقائي + ربط HK؛ camera=بدء تحدّي الرؤية؛ water=+0.25ل؛ timer=start/stop؛ workout=تسجيل دقائق؛ social=تسجيل + توجيه للساحة؛ share=مشاركة iOS؛ manual=أكد؛ learning=مكدّس إثبات 5-حالات). مكتمل → «مكتمل ✓» أخضر بلا إجراء.
7. **ترقية مركز:** الإجراء → `finishQuestSession` → `evaluateAndAssignTier` → `progressByQuestId` يُنشَر. `BattleChallengesView.onChange` → `handleStageOneCenterUpgrades` ([:343-369](AiQo/Features/Gym/Quests/Views/QuestsView.swift)): لتحدّيات المرحلة 1، إن تحسّن المركز يُظهر toast «ترقيت إلى مركز N» (1.8ث + هابتك).
8. **إكمال التحدّي:** → تأخير 0.4ث → `.sheet QuestCompletionCelebration` (شارة تقفز، «مبروك!»، XP-pill إن وُجد، هابتك نجاح، «تمام»). الإغلاق → `saveQuestAchievement` (حفظ الإنجاز + منح XP لمرّة واحدة).
9. **إكمال المرحلة:** انبثاقي صرف — عند بلوغ آخر تحدّي tier 3 تنفتح دائرة المرحلة التالية في الشريط عند النشر التالي. **لا شاشة/أنيميشن مخصّص لإكمال المرحلة** في المسار الحيّ.
- مؤقّت دقيقة: `BattleChallengesView` يعيد نشر `currentTime` كل 60ث للنصوص الزمنية.

## B11. مطابقة «معرفة الكابتن Part 12»

«Part 12 / شاشة معركة» **ليست في كود Swift**. الـprompt الحيّ يُبنى ديناميكياً بـ`PromptComposer` (7 طبقات، [PromptComposer.swift](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) ولا يحوي سلّماً ثابتاً. النصّ الموثوق يعيش فقط كمواصفة في ذاكرة المشروع `captain_hamoudi_system_prompt.md` (وتحمل تحذير «REALITY CHECK»). المطابقة مع `QuestDefinitions.swift`: تتّفق على الأسماء والعتبات، مع تحفّظات:
- Part 12 يسرد العتبات **الأصعب-أوّلاً** (مطابق لنصوص العرض)؛ `tiers[]` **الأسهل-أوّلاً** (نفس الأرقام، ترتيب معكوس).
- خانة المرحلة-2-مكان-3: الافتراضي الإنتاجي **شرارة التعلّم Stage 2** (XP 2000)؛ «30/60/90ث» تخصّ متغيّر سلم البلانك (التراجُع) فقط.
- «كل تحدّي يعطي XP» **غير صحيح حرفياً** — فقط `s1qLearn`/`s2qLearn` (§B7).

## B12. مصائد وهشاشة (معركة)

1. **انقلاب المركز** (مركز 1 = الأصعب = tier 3) — مرحلة 1 فقط في الشارة؛ 2–10 تعرض «المستوى N/3» خام. أكثر مصدر التباس.
2. **ترتيب نصوص العتبات معكوس** عن `tiers[]` — الأرقام في `QuestDefinitions.swift` هي المرجع.
3. **فتح المرحلة يحتاج كل الخمسة عند tier 3 آنياً** — واليومي يُصفَّر منتصف الليل؛ نافذة الفتح ضيقة.
4. **`.social` غير موصول** بمصدر ساحة حقيقي («V2 Post-Launch») — تسجيل يدوي مؤقّت.
5. **نظامان للتحدّيات في الكود** — QuestKit حيّ؛ `Challenge.swift/ChallengeStage.swift` ميّت (لا يلمسه `BattleChallengesView`).
6. **حاوية SwiftData المتجاوِزة** يجب أن تسرد كل نماذج السياق وإلا تنهار التهيئة (تعليق طويل في [QuestSwiftDataStore.swift:29-42](AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift)).
7. **فلاغات الخانة-3** تُحَلّ مرّة عند التهيئة — قلبها يحتاج إعادة تشغيل التطبيق.

---

## 3. خريطة المصدر (Source Map · file:line)

**قِمَم (Peaks):**
- الأرقام: [LegendaryRecord.swift:31-216](AiQo/Features/LegendaryChallenges/Models/LegendaryRecord.swift)
- المشروع: [RecordProject.swift:5-111](AiQo/Features/LegendaryChallenges/Models/RecordProject.swift) · [WeeklyLog.swift:5-39](AiQo/Features/LegendaryChallenges/Models/WeeklyLog.swift)
- المدير: [RecordProjectManager.swift:8-315](AiQo/Features/LegendaryChallenges/ViewModels/RecordProjectManager.swift) (الخطّة :178-268)
- HRR: [HRRWorkoutManager.swift:8-267](AiQo/Features/LegendaryChallenges/ViewModels/HRRWorkoutManager.swift) (التصنيف :228-236) · [FitnessAssessmentView.swift](AiQo/Features/LegendaryChallenges/Views/FitnessAssessmentView.swift)
- المراجعة: [WeeklyReviewView.swift:318-472](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewView.swift) · [WeeklyReviewTemplateGenerator.swift:3-78](AiQo/Features/LegendaryChallenges/Views/WeeklyReviewTemplateGenerator.swift)
- الواجهة: [QuestsView.swift:7-35](AiQo/Features/Gym/Quests/Views/QuestsView.swift) (`PeaksRecordsView`) · [RecordDetailView.swift](AiQo/Features/LegendaryChallenges/Views/RecordDetailView.swift) · [RecordProjectView.swift](AiQo/Features/LegendaryChallenges/Views/RecordProjectView.swift)
- البوّابة: [ClubRootView.swift:177-188](AiQo/Features/Gym/Club/ClubRootView.swift) · [AccessManager.swift:52-67](AiQo/Premium/AccessManager.swift)

**معركة (Battle):**
- السلّم: [QuestDefinitions.swift:8-1031](AiQo/Features/Gym/QuestKit/QuestDefinitions.swift)
- المحرّك: [QuestEngine.swift:23-694](AiQo/Features/Gym/QuestKit/QuestEngine.swift) (الفتح :149-162؛ التحديث :339-482)
- التقييم/المركز: [QuestEvaluator.swift:16-175](AiQo/Features/Gym/QuestKit/QuestEvaluator.swift)
- النماذج: [QuestKitModels.swift:1-308](AiQo/Features/Gym/QuestKit/QuestKitModels.swift)
- التخزين: [QuestProgressStore.swift](AiQo/Features/Gym/QuestKit/QuestProgressStore.swift) · [QuestSwiftDataStore.swift:11-376](AiQo/Features/Gym/QuestKit/QuestSwiftDataStore.swift) · [QuestSwiftDataModels.swift](AiQo/Features/Gym/QuestKit/QuestSwiftDataModels.swift)
- المصادر/HealthKit: [QuestDataSources.swift:65-547](AiQo/Features/Gym/QuestKit/QuestDataSources.swift)
- انقلاب المركز: [QuestFormatting.swift:121-153](AiQo/Features/Gym/QuestKit/QuestFormatting.swift)
- XP/الإنجازات: [QuestXPRewards.swift](AiQo/Features/Gym/Quests/Store/QuestXPRewards.swift) · [QuestAchievementStore.swift](AiQo/Features/Gym/Quests/Store/QuestAchievementStore.swift)
- الواجهة: [QuestsView.swift:39-390](AiQo/Features/Gym/Quests/Views/QuestsView.swift) · [QuestCard.swift](AiQo/Features/Gym/Quests/Views/QuestCard.swift) · [QuestDetailSheet.swift](AiQo/Features/Gym/Quests/Views/QuestDetailSheet.swift) · [QuestCompletionCelebration.swift](AiQo/Features/Gym/Quests/Views/QuestCompletionCelebration.swift)
- البوّابة: [ClubRootView.swift:190-201](AiQo/Features/Gym/Club/ClubRootView.swift) · [AccessManager.swift:27-40](AiQo/Premium/AccessManager.swift) · [SubscriptionTier.swift:7-30](AiQo/Core/Purchases/SubscriptionTier.swift)

**مشترك:** [ClubRootView.swift](AiQo/Features/Gym/Club/ClubRootView.swift) · [DevOverride.swift](AiQo/Features/Captain/Brain/00_Foundation/DevOverride.swift) · [ar.lproj/Localizable.strings](AiQo/Resources/ar.lproj/Localizable.strings) (قِمَم :1980-2144؛ معركة :964-1093) · مواصفة الكابتن (ذاكرة، ليست كوداً): `~/.claude/projects/-Users-mohammedraad-Desktop-AiQo/memory/captain_hamoudi_system_prompt.md` (PART 12 §A)

---

*انتهى مخطّط قِمَم / معركة. مكتوب 2026-05-18 من قراءة كاملة موثَّقة للكود الحيّ على `release/v1.0.4-memory-v4` @ `cc30c4b`. كل عتبة ورقم وانقلاب تم التحقق منه بقراءة الملف نفسه.*
