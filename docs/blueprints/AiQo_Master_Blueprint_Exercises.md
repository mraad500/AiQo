<div align="center">

<img src="AiQo.png" width="140" height="140" alt="AiQo" />

# **AiQo — مرجع التمارين الكامل**

*Master Blueprint · Exercises*

**كل تمرين بالتطبيق + شلون يشتغل بالتفصيل التقني**

</div>

---

## مقدمة

هذا الملف يشرح **كل التمارين الموجودة بتطبيق AiQo** و**شلون يشتغل كل وحد منهم تقنياً** — من لحظة ما المستخدم يضغط على كرت التمرين، مروراً بتتبّع البيانات لحظياً عبر ساعة Apple، إلى الملخّص الصوتي من الكابتن حمّودي بعد الجلسة. كُتب من قراءة الكود الحي مباشرة. المصطلحات التقنية (أسماء الملفات، أنواع HealthKit، المعادلات) بالإنجليزية للدقّة؛ الشرح بالعربية.

**المصدر التقني الأساسي:** [GymExercise.swift](AiQo/Features/Gym/Models/GymExercise.swift) (كتالوج الـ23 تمرين) · [WorkoutCategoriesView.swift](AiQo/Features/Gym/Club/Body/WorkoutCategoriesView.swift) (واجهة التصنيفات) · [LiveWorkoutSession.swift](AiQo/Features/Gym/LiveWorkoutSession.swift) (محرّك الجلسة) · [WatchWorkoutType.swift](AiQoWatch%20Watch%20App/Models/WatchWorkoutType.swift) (أنواع الساعة).

---

## 1. نظرة عامة — الكتالوج والتصنيفات

### 1.1 نموذج التمرين `GymExercise`

كل تمرين بالتطبيق هو `struct GymExercise` يحمل:

| الحقل | المعنى |
|---|---|
| `titleKey` / `subtitleKey` | مفاتيح الترجمة (عربي/إنجليزي عبر `L10n.t`) |
| `type: HKWorkoutActivityType` | نوع النشاط بـ HealthKit (running, walking, cycling, swimming, traditionalStrengthTraining, …) |
| `location: HKWorkoutSessionLocationType` | داخلي `.indoor` أو خارجي `.outdoor` |
| `icon` / `tint` | رمز SF Symbol + لون (مينت `.aiqoMint` / بيج `.aiqoBeige` / لافندر `.aiqoLav`) |
| `workoutKind: GymWorkoutKind` | `.standard` · `.cardioWithCaptainHamoudi` · `.cinematicGrind` · `.outdoorRun` |
| `coachingProfile: WorkoutCoachingProfile` | `.standard` (بدون كوتشينج صوتي) · `.captainHamoudiZone2` (كوتشينج زون 2 صوتي) |

نوعان فقط من ملفات التعريف الصوتي يحدّدان "هل الكابتن يحجي وياك أثناء التمرين":
- **`.standard`** — تتبّع صامت (مؤقّت + نبض + سعرات + مسافة)، بدون صوت أثناء الجلسة.
- **`.captainHamoudiZone2`** — كوتشينج صوتي حي بصوت الكابتن حمّودي يثبّتك بزون 2.

### 1.2 الـ 23 تمرين (من `GymExercise.samples`)

| # | التمرين (titleKey) | HK Type | المكان | Kind | Coaching |
|---|---|---|---|---|---|
| 1 | Cinematic Grind — سينماتك غرايند | `.mixedCardio` | indoor | `.cinematicGrind` | **Zone2** |
| 2 | كارديو ويا الكابتن حمّودي | `.mixedCardio` | outdoor | `.cardioWithCaptainHamoudi` | **Zone2** |
| 3 | Outdoor Running (GPS) — جري خارجي بالخريطة | `.running` | outdoor | `.outdoorRun` | standard |
| 4 | الجري | `.running` | outdoor | standard | standard |
| 5 | المشي | `.walking` | outdoor | standard | standard |
| 6 | الدراجة | `.cycling` | outdoor | standard | standard |
| 7 | السباحة | `.swimming` | indoor | standard | standard |
| 8 | تمارين القوة | `.traditionalStrengthTraining` | indoor | standard | standard |
| 9 | HIIT | `.highIntensityIntervalTraining` | indoor | standard | standard |
| 10 | اليوغا | `.yoga` | indoor | standard | standard |
| 11 | الفروسية | `.equestrianSports` | outdoor | standard | standard |
| 12 | كاليسثينِكس (وزن الجسم) | `.functionalStrengthTraining` | indoor | standard | standard |
| 13 | بيلاتس | `.pilates` | indoor | standard | standard |
| 14 | الامتنان (Gratitude) | `.mindAndBody` | indoor | standard | standard |
| 15 | دراجة داخلية | `.cycling` | indoor | standard | standard |
| 16 | إليبتكال | `.elliptical` | indoor | standard | standard |
| 17 | صعود الدرج | `.stairClimbing` | indoor | standard | standard |
| 18 | كرة القدم | `.soccer` | outdoor | standard | standard |
| 19 | بادل / تنس | `.tennis` | outdoor | standard | standard |
| 20 | كرة السلة | `.basketball` | indoor | standard | standard |
| 21 | الملاكمة | `.boxing` | indoor | standard | standard |
| 22 | فنون قتالية | `.martialArts` | indoor | standard | standard |
| 23 | نطّ الحبل | `.jumpRope` | indoor | standard | standard |

### 1.3 التصنيفات بالواجهة (`WorkoutCategoriesView`)

تبويب **Body** بشاشة الجيم يعرض التمارين بثلاث فئات على فلتر عمودي جانبي:

- **كارديو (Cardio):** كارديو ويا الكابتن · Outdoor Running · الجري · المشي · الدراجة · السباحة.
- **قوة (Strength):** تمارين القوة · HIIT · الفروسية · كاليسثينِكس.
- **صفاء (Serenity/Clarity):** التنفّس* · الامتنان · اليوغا · شحن الأورا* · صفاء عميق*.

\* الكروت المعلّمة بنجمة (`exerciseKey: nil` بـ `WorkoutCategoriesCatalog`) هي **شاشات تحضيرية/قريباً** ما مربوطة بجلسة فعلية بعد (التنفّس، شحن الأورا، الصفاء العميق). الباقي مربوط بـ `GymExercise` فعلي عبر `linkedExercise(for:)`.

الكرت الأول بفئة الكارديو يكون **مميّز** (`isFeatured`) بحجم أكبر وعنوان فرعي. الكروت تتلوّن مينت/بيج بالتناوب وتدخل بحركة spring متدرّجة.

---

## 2. محرّك الجلسة المشترك — شلون يشتغل أي تمرين قياسي

كل التمارين القياسية تمرّ بنفس المحرّك: **[LiveWorkoutSession.swift](AiQo/Features/Gym/LiveWorkoutSession.swift)** على الأيفون + **[WorkoutManager.swift](AiQoWatch%20Watch%20App/WorkoutManager.swift)** على الساعة، مربوطين بـ **WatchConnectivity** عبر [PhoneConnectivityManager.swift](AiQo/PhoneConnectivityManager.swift).

### 2.1 دورة حياة الجلسة

`LiveWorkoutSession.Phase`: `.idle → .starting → .running → (.paused) → .ending`.

1. **البدء (`startFromPhone()`):** يستدعي `PhoneConnectivityManager.launchWatchAppForWorkout(activityType:locationType:)` — يفتح تطبيق الساعة تلقائياً بنفس نوع/مكان النشاط. الطور → `.starting`، يحضّر Live Activity، ويشغّل الصوت المحيط لو التمرين كارديو-كابتن.
2. **التتبّع الحي:** الساعة هي مصدر الحقيقة. تنشئ `HKWorkoutSession` + `HKLiveWorkoutBuilder` وتدزّ لقطات كل **0.75 ثانية** (`livePushInterval`) للأيفون. الأيفون يستقبلها عبر `PhoneConnectivityManager.$latestSnapshot` (Combine) ويطبّقها بـ `applyRemoteSnapshot()`. المقاييس المنشورة:
   - `heartRate` (نبض القلب) · `activeEnergy` (سعرات) · `distanceMeters` (مسافة) · `elapsedSeconds` (الوقت المنقضي).
   - مؤقّت محلي كل ثانية (`tickElapsedDisplay()`) ينعّم عرض الوقت.
3. **معالم الكيلومتر (`checkForMilestone()`):** كل كيلومتر مكتمل → تنبيه بصري + اهتزاز (`UINotificationFeedbackGenerator`) يختفي تلقائياً بعد 3 ثوان.
4. **إيقاف/استئناف:** `pauseFromPhone()` / `resumeFromPhone()` يدزّون أوامر للساعة؛ الساعة تطبّق `session.pauseActivity()` / `resumeActivity()` وترجع لقطة حالة.
5. **الإنهاء (`endFromPhone()` أو `forceEndFromPhoneImmediately()`):** الساعة تسوّي `builder.finishCollection()` ثم `session.end()` → يُحفظ `HKWorkout` بـ HealthKit. الأيفون عبر `handleRemoteEnded()` يسجّل بـ `WorkoutHistoryStore.shared.recordCompletion()` (العنوان، المدة، السعرات، النبض، المسافة) ويطلق `AnalyticsService.track(.workoutCompleted(...))`.
6. **بعد الجلسة:** ملخّص الكابتن (انظر §8) + تحديث Live Activity النهائي + سجل التمرين يدخل ذاكرة الكابتن (آخر 30 تمرين، 14 تنطوي بالبرومبت).

### 2.2 الحفظ بـ HealthKit (من الساعة)

`HKLiveWorkoutBuilder` يجمع لحظياً: `builder.elapsedTime` · `statistics(for: .heartRate)` · `statistics(for: .activeEnergyBurned)` · `statistics(for: .distanceWalkingRunning)` أو `.distanceCycling` حسب النوع. الساعة هي اللي تكتب `HKWorkout` النهائي (مو الأيفون) — هذا يضمن دقّة المستشعرات والاستمرارية لو الأيفون مو موجود.

---

## 3. نظام زون 2 (Zone 2) — قلب الكوتشينج الصوتي

زون 2 = شدّة منخفضة-معتدلة (60–70% من أقصى نبض) — الأفضل لحرق الدهون وبناء القاعدة الهوائية. التمارين بملف `.captainHamoudiZone2` تشغّل هذا النظام.

### 3.1 حساب نطاق زون 2

من [LiveWorkoutSession.swift](AiQo/Features/Gym/LiveWorkoutSession.swift):

```
age            = resolveUserAge()         // 13–100، الافتراضي 30
maxHeartRate   = max(100, 220 - age)
zone2Lower     = maxHeartRate × 0.60
zone2Upper     = maxHeartRate × 0.70
```

مثال: عمر 40 → أقصى نبض 180 → **زون 2 = 108–126 نبضة/دقيقة**. لو ما توفّر العمر، يستخدم القيمة الافتراضية للكابتن: `Zone2Target(lowerBoundBPM: 118, upperBoundBPM: 137)`. حالة الأورا `Zone2AuraState`: `.inactive`, `.warmingUp`, `.inZone2`, `.tooFast`, `.tooSlow` (تتحوّل لمؤشّر بصري ملوّن + شريط نطاق مثل "118-137 bpm").

### 3.2 خدمات الصوت — ثلاث طبقات

**أ) [ZoneCoachingVoiceService.swift](AiQo/Features/Cardio/ZoneCoachingVoiceService.swift)** — العبارات المُسبقة (deterministic):
- يشترك بـ `LiveWorkoutSession.captainVoiceZoneTransitions` (PassthroughSubject) — يفصل الجلسة عن خدمة الكوتشينج (singleton).
- أحداث `CoachingEvent`: `.workoutStart` · `.warmupEnd` · `.aboveZone(bpm,max)` · `.belowZone(bpm,min)` · `.enteredZone` · `.halfway` · `.cooldownStart`.
- خريطة التحوّلات: محايد→تسخين = بداية · تسخين→زون2 = نهاية الإحماء · أي→فوق = "هدّئ، إنت فوق الزون" · أي→تحت = "زيد شوية، نرجع للزون" · فوق/تحت→زون2 = "تمام، صرت بالزون".
- **التهدئة:** لكل فئة 30 ثانية + عام 15 ثانية (يُفحصان قبل النطق). العبارات **ثابتة مُسبقة عربي/إنجليزي** (مو LLM) تُنطق عبر `CaptainVoiceRouter.shared.speak(text:tier:.premium)`.

**ب) [AudioCoachManager.swift](AiQo/Features/Gym/AudioCoachManager.swift)** — الكوتشينج الديناميكي:
- `handleDynamicZone2Coaching(heartRate:distanceMeters:isRunning:)` يُستدعى كل تحديث من `syncCoachingState()`.
- تهدئة عامة + لكل فئة 120 ثانية. عند تغيّر الحالة يبني نصّ عبر `CaptainVoiceService.makeWorkoutPromptText()` وينطقه بطبقة premium.

**ج) [HandsFreeZone2Manager.swift](AiQo/Features/Gym/HandsFreeZone2Manager.swift)** — وضع بدون يدين (تفاعلي):
- أطوار: `.idle`, `.requestingAccess`, `.listening`, `.processing`, `.speaking`, `.unavailable`.
- **تعرّف كلام على الجهاز** `SFSpeechRecognizer` بـ `requiresOnDeviceRecognition: true` (ما يطلع صوت للسحابة).
- موجة صوتية حيّة (10 عناصر) عبر `installTap` على `AVAudioEngine`. أذونات الميكروفون + الكلام.
- الردّ من ذكاء **على الجهاز**: `CaptainHealthSnapshotService.generateOnDeviceReply(prompt:instructions:)` ببرومبت `AiQoPromptManager.shared.getZone2CoachPrompt()`؛ لو فشل → ردّ عربي/إنجليزي مُسبق. جلسة صوت `.playAndRecord` مع `[.mixWithOthers, .defaultToSpeaker, .allowBluetoothHFP]`.

---

## 4. التمارين الخاصّة — شرح مفصّل لكل وحد

### 4.1 كارديو ويا الكابتن حمّودي (`cardioWithCaptainHamoudi`)
كارديو خارجي `.mixedCardio` بملف `.captainHamoudiZone2`. الجلسة القياسية (§2) + نظام زون 2 الكامل (§3): الكابتن يكوتشك صوتياً ليثبّتك بالنطاق، صوت محيط خفيف بالخلفية، تنبيهات عند الخروج/الدخول للزون. الملخّص الصوتي بعد الجلسة من الكابتن.

### 4.2 Cinematic Grind — سينماتك غرايند (`cinematicGrind`)
**الفكرة:** كارديو زون 2 وانت تتفرّج Netflix أو YouTube — تمرّن بدون ملل. ملفّاته: [CinematicGrindViews.swift](AiQo/Features/Gym/CinematicGrindViews.swift) · [CinematicGrindCardView.swift](AiQo/Features/Gym/CinematicGrindCardView.swift).
- المستخدم يختار **المنصّة** (`CinematicPlatform`: Netflix / YouTube)، **المزاج** (`CinematicMood`: أكشن/ملحمي · كوميدي · إلهام/تحفيز · هادئ/قصّة)، والمدّة.
- النظام يولّد اقتراح عنوان جلسة (`generateSuggestion()` — مثل "Action Pilot Rush"، "Epic Franchise Night").
- **روابط عميقة:** يفتح Netflix (`nflx://`) أو YouTube (`youtube://`) ببحث مُعبّأ مسبقاً حسب المزاج (fallback ويب لو التطبيق مو منصّب).
- التتبّع نفس كارديو زون 2 (نبض، مسافة، سعرات، وقت، نسبة الزون) + كوتشينج صوتي.

### 4.3 Outdoor Running — جري خارجي بالخريطة (`outdoorRun`)
مسار خاص بـ GPS. ملفّاته: [OutdoorRunSession.swift](AiQo/Features/Gym/OutdoorRun/OutdoorRunSession.swift) · [OutdoorRunSessionView.swift](AiQo/Features/Gym/OutdoorRun/OutdoorRunSessionView.swift) · [RunSummaryView.swift](AiQo/Features/Gym/OutdoorRun/RunSummaryView.swift) · [RunLocationManager.swift](AiQo/Services/Location/RunLocationManager.swift) · [RunRouteSnapshotter.swift](AiQo/Services/Location/RunRouteSnapshotter.swift).
- أطوار `OutdoorRunSession.Phase`: `.ready → .running → (.paused) → .finished`.
- **المسافة من GPS:** `updateDistance()` يتحدّث من `RunLocationManager`. الوقت مؤقّت محلي (tick 0.5 ث) يتراكم عبر الإيقاف/الاستئناف.
- **الإيقاع (Pace):** متوسط = `elapsedSeconds / (distanceMeters/1000)` (يرجع `nil` لو المسافة < 20م). الإيقاع الحي: لو السرعة > 0.5 م/ث → `1000/speed`، وإلا يرجع للمتوسط.
- **السعرات:** لو الساعة شغّالة يأخذ `connectivity.activeEnergy`؛ غير هيك تقدير `(distanceMeters/1000) × 62` سعرة/كم (لعدّاء ~70كغ).
- **خريطة المسار:** `RunRouteSnapshotter` يلتقط صورة خريطة فيها خط مسار الجري (polyline) تظهر بالملخّص.
- **رفيق الساعة:** `startWatchCompanionIfAvailable()` يشغّل جلسة الساعة (نبض + سعرات حيّة)؛ عند الإنهاء `endWorkoutOnWatch()`. يُسجّل بـ `WorkoutHistoryStore` عند `.finished`. معالم كل كيلومتر (تنبيه + اهتزاز).

### 4.4 الامتنان / جلسات الصفاء (Gratitude)
HK type `.mindAndBody`. ملفّاته: [GratitudeSessionView.swift](AiQo/Features/Gym/Club/Body/GratitudeSessionView.swift) · [GratitudeAudioManager.swift](AiQo/Features/Gym/Club/Body/GratitudeAudioManager.swift) · [ActiveRecoveryView.swift](AiQo/Features/Gym/ActiveRecoveryView.swift).
- مدّة ثابتة **150 ثانية (2.5 دقيقة)**. جمل امتنان **دوّارة يومياً** ثنائية اللغة من `gratitudeBundles(for:)`؛ الفاصل = 150 ÷ عدد الجمل.
- **مقفولة بعد الظهر** محلياً (`isLocked` — جلسة صباحية بطبيعتها).
- الصوت (`GratitudeAudioManager`): خلفية "SerotoninFlow" (m4a) بمستوى `0.10` (تنخفض لـ `0.04` أثناء كلام الكابتن)، صوت الكابتن `1.0`. التدفّق: `startSessionAudio()` → كل فاصل `speak(text,language)` عبر `CaptainVoiceRouter` (premium) والموسيقى تخفت ثم ترجع → `stopAll()`. يُسجّل كتمرين `mindAndBody` بدون مسافة/نبض.

### 4.5 Vision Coach — مدرّب الرؤية (تصحيح الأداء + تحدّي الضغط)
رؤية حاسوبية **على الجهاز** لعدّ التكرارات وتقييم الأداء. ملفّاته: [VisionCoachView.swift](AiQo/Features/Gym/Quests/VisionCoach/VisionCoachView.swift) · [VisionCoachViewModel.swift](AiQo/Features/Gym/Quests/VisionCoach/VisionCoachViewModel.swift) · [VisionCoachAudioFeedback.swift](AiQo/Features/Gym/Quests/VisionCoach/VisionCoachAudioFeedback.swift) · [QuestPushupChallengeView.swift](AiQo/Features/Gym/QuestKit/Views/QuestPushupChallengeView.swift).
- **تقدير الوضعية:** `AVCaptureSession` (كاميرا أمامية، خلفية احتياط) → `VNDetectHumanBodyPoseRequest` (إطار Vision) على `visionQueue`. كل إطار: `VNImageRequestHandler(...).perform([poseRequest])`. **الصورة ما تطلع من الجهاز أبداً.**
- **عدّ التكرارات:** `PushupRepCounter` يحلّل معالم الجسم (أكتاف/أكواع/معاصم) ليكشف المدى الكامل للحركة ويعدّ التكرارات الصحيحة.
- **الدقّة:** `accuracyPercent = (goodFormFrameCount / evaluatedFrameCount) × 100`.
- **تلميحات حيّة:** نصّية مترجمة حسب حالة الوضعية ("انزل ثم ادفع"، "خلّي جسمك خط مستقيم")، تُنشر `@Published coachingHint`.
- **صوت:** `VisionCoachAudioFeedback` ينطق تشجيع/تصحيح عبر `CaptainVoiceRouter.shared.speak(text:tier:.realtime)`. النتيجة `(reps, accuracy)` تُغذّي تقييم التحدّيات (Battle s2q1).

### 4.6 التمارين القياسية الباقية
كل الباقي (المشي، الجري، الدراجة خارجي/داخلي، السباحة، القوة، HIIT، اليوغا، الفروسية، كاليسثينِكس، بيلاتس، إليبتكال، صعود الدرج، كرة القدم، بادل/تنس، السلة، الملاكمة، فنون قتالية، نطّ الحبل) تشتغل بمحرّك الجلسة القياسي (§2): فتح جلسة الساعة بنوع HK المناسب → تتبّع حي (نبض/سعرات/وقت + مسافة للأنشطة المتحرّكة) → معالم كيلومتر للمناسب → حفظ `HKWorkout` → سجل + ملخّص الكابتن. الفرق بينهم فقط `HKWorkoutActivityType` و`location` (داخلي/خارجي) — هذا اللي يقرّر أي مقاييس HealthKit تنجمع وكيف تُحسب السعرات.

---

## 5. خطة التمرين المولّدة من الكابتن (Plan) — مختلفة عن الجلسة الحيّة

هذا **مو** جلسة كارديو حيّة، هاي **برنامج تمرين منظّم** (مجموعات/تكرارات) يولّده الكابتن حمّودي. ملفّاته بـ `AiQo/Features/Gym/Club/Plan/`: [PlanView.swift](AiQo/Features/Gym/Club/Plan/PlanView.swift) · [WorkoutPlanIntakeChips.swift](AiQo/Features/Gym/Club/Plan/WorkoutPlanIntakeChips.swift) · [WorkoutPlanCards.swift](AiQo/Features/Gym/Club/Plan/WorkoutPlanCards.swift) · [PlanWorkoutRunner.swift](AiQo/Features/Gym/Club/Plan/PlanWorkoutRunner.swift) · [WorkoutPlanInsights.swift](AiQo/Features/Gym/Club/Plan/WorkoutPlanInsights.swift) · [ExerciseDetailSheet.swift](AiQo/Features/Gym/Club/Plan/ExerciseDetailSheet.swift) · [WorkoutTemplateLibrary.swift](AiQo/Features/Gym/Club/Plan/WorkoutTemplateLibrary.swift).

1. **الطلب (Intake Chips):** المستخدم يختار بسرعة عبر شرائح: الهدف · المستوى · وقت الجلسة الواحدة · **طول البرنامج** (1/2/4/8 أسابيع) · المعدّات المتوفّرة · **صورة جسم اختيارية** (بموافقة `BodyPhotoConsent` المنفصلة، تُعقّم EXIF/GPS وتُرسل لـ Gemini مرّة وحدة، ما تُحفظ).
2. **التوليد:** هذي تروح للكابتن (`CaptainViewModel`) اللي يرجّع `WorkoutPlan` منظّم متعدّد الأيّام: `title`, `durationWeeks?`, `days[]` (كل يوم `name`, `focus?`, `exercises[]` فيها sets/reps). الديكودر متسامح: لو بس `exercises` مسطّحة موجودة → الخطّة لا تزال تُقرأ (مسار قديم).
3. **منتقي اليوم:** كرت الخطّة النشطة يعرض منتقي أيّام أفقي؛ اختيار يوم يعيد تحديد قائمة التمارين والإحصائيات وزرّ "ابدأ التمرين".
4. **منفّذ الخطّة (`PlanWorkoutRunner`):** شاشة كاملة بدون تشتيت تمشي يوم واحد فقط: التمرين الحالي + sets/reps/rest، تتبّع المجموعات `setsCompleted[index]`, **مؤقّت راحة تلقائي** بين المجموعات، مؤقّت جلسة كلّي، شريط تقدّم (مجموعات منجزة/الكلّي)، شريط "القادم" (التمارين الجاية)، واحتفال شاشة كاملة عند إكمال كل المجموعات. `ExerciseDetailSheet` يعرض شرح الأداء + بدائل لكل تمرين، و`WorkoutPlanInsights` يصنّف العضلات ويعطي ملاحظات.

---

## 6. تدفّق التمرين على ساعة Apple

[WatchWorkoutType.swift](AiQoWatch%20Watch%20App/Models/WatchWorkoutType.swift) يعرّف **9 أنواع** على الساعة (مع اسم عربي/إنجليزي، رمز، نوع HK، مكان):

| النوع | HK Type | المكان |
|---|---|---|
| `walkOutdoor` مشي خارجي · `walkIndoor` مشي داخلي | `.walking` | خارجي / داخلي |
| `runOutdoor` ركض خارجي · `runIndoor` ركض داخلي | `.running` | خارجي / داخلي |
| `cycling` دراجة | `.cycling` | خارجي |
| `hiit` تمرين HIIT | `.highIntensityIntervalTraining` | داخلي |
| `strengthTraining` تمارين القوة | `.traditionalStrengthTraining` | داخلي |
| `yoga` يوغا | `.yoga` | داخلي |
| `swimming` سباحة | `.swimming` | داخلي |

محرّك الساعة [WorkoutManager.swift](AiQoWatch%20Watch%20App/WorkoutManager.swift) (singleton، أطوار `idle/launching/awaitingMirror/mirrored/reconnecting/ended/failed`):
1. `requestAuthorization()` أذونات HealthKit (نبض/سعرات/مسافة).
2. `startWorkout(workoutType:locationType:)` → `HKWorkoutConfiguration` → `HKWorkoutSession` + `session.associatedWorkoutBuilder()` → `session.prepare()` → `startActivity(with:)` → `builder.beginCollection(at:)`.
3. مؤقّت دفع حي كل **0.75 ث** يلقّط (نبض/مسافة/سعرات/وقت/طور) كـ `WorkoutSyncPayload` للأيفون عبر WatchConnectivity.
4. أوامر من الأيفون (إيقاف/استئناف/إنهاء/تغيير طور) تُطبّق محلياً على الجلسة.
5. `builder.finishCollection()` → `session.end()` → يُحفظ `HKWorkout`. الانعكاس ثنائي الاتجاه: الأيفون يعرض مقاييس الساعة الحيّة لحظياً.

---

## 7. تحدّيات التمارين بـ المعركة/المهمّات (Quests/Battle)

[QuestEvaluator.swift](AiQo/Features/Gym/QuestKit/QuestEvaluator.swift) · [QuestDefinitions.swift](AiQo/Features/Gym/QuestKit/QuestDefinitions.swift) · [QuestDataSources.swift](AiQo/Features/Gym/QuestKit/QuestDataSources.swift).

- **أنواع المهمّة:** `.oneTime` · `.daily` · `.weekly` · `.streak` (سلسلة أيّام متتالية، تنكسر لو فات يوم) · `.combo` · `.cumulative` (مجموع تراكمي).
- **مصادر التقييم:** `.healthkit` (نوم/خطوات/مسافة/دقائق زون2) · `.workout` (دقائق زون2/مسافة/مدّة من التمارين المسجّلة) · `.camera` (تكرارات+دقّة الضغط من Vision Coach) · `.manual` (تسجيل يدوي) · `.learning` (شهادة كورس) · `.water`.
- أمثلة: **"نبض زون 2"** (تراكمي) 20/30/40 دقيقة → مستوى 1/2/3 · **"دقّة آلة الرؤية"** 10/15/20 ضغطة بدقّة 70%/85%/100% · **"الحركة بيوم واحد"** (يومي) 3/5/6 كم.
- `applyPeriodResets()` يصفّر عند حدود اليوم/الأسبوع؛ `evaluateAndAssignTier()` يحدّث `metricAValue/metricBValue/currentTier/isCompleted`. التمارين الحيّة تغذّي هذي المصادر تلقائياً (مثلاً دقائق زون 2 من كارديو الكابتن، تكرارات Vision Coach للضغط).

---

## 8. بعد التمرين → تحليل الكابتن والأوامر الدائمة

سلسلة الإنهاء: الساعة تخلّص → `HKWorkout` → إشارة للأيفون → `LiveWorkoutSession.handleRemoteEnded()` → `WorkoutHistoryStore.recordCompletion()` + analytics → **`DirectiveEngine.handleWorkoutCompleted(_:)`** (عبر `AIWorkoutSummaryService.handleWorkoutEnded` بـ [NotificationService.swift](AiQo/Services/Notifications/NotificationService.swift) — يطلق بعد **كل** تمرين HealthKit: ساعة/خارجي/داخل التطبيق).

- **`DirectiveWorkoutSnapshot`:** `workoutType`, `durationSeconds`, `activeCalories`, `averageHeartRate`, `distanceKm`, `zone2Percent`, `peakPercent`, `endedAt`.
- **لو فيه أمر دائم `.afterWorkout` مفعّل** (المستخدم علّم الكابتن "بعد كل تمرين حلّل وقارن ودزّلي إشعار" — انظر طبقة `11_Directives`): `WorkoutComparisonComposer.compose(current:previous:fireCount:localeCode:)` يبني تحليل **حتمي، أوفلاين، بدون LLM/شبكة/كلفة** يقارن التمرين الحالي بالسابق (من `WorkoutHistoryStore.recentEntries()` — أحدث تمرين قبل > 120 ث):
  - إحصائيات اليوم: مدّة، سعرات، نسبة زون 2، شدّة.
  - الفروقات vs السابق: فرق المدّة، فرق السعرات، فرق متوسط النبض (لو > 3 نبضة)، فرق المسافة (لو > 0.3 كم).
  - خاتمة تحفيزية حسب الفروقات. عربي عراقي + إنجليزي.
- لو ما فيه أمر دائم → سطر ملخّص ثابت قصير. يُرسل عبر `NotificationBrain.shared.request()`، مبوّب بـ `TierGate.captainDirectives` (`.max`+). التحليل الأعمق المكتوب من النموذج يصير لمّن المستخدم يفتح التطبيق ويسأل.
- **خصوصية:** كل البيانات الصحّية تُجزّأ (steps×500, HR×5, sleep×0.5h, cal×10) قبل أي نداء سحابي؛ ملخّص ما بعد التمرين الفوري **أوفلاين بالكامل** (ما يحتاج إنترنت).

---

## 9. مرجع سريع — شلون يشتغل كل تمرين باختصار

| التمرين | المحرّك | يُتتبّع | مميّزات | المُخرَج |
|---|---|---|---|---|
| كارديو ويا الكابتن | Zone2 موجّه | نبض(نطاق)، وقت، مسافة، سعرات | كوتشينج صوتي حي + صوت محيط | سجل + Directive + صوت |
| Cinematic Grind | Zone2 موجّه | نفس فوق | رابط Netflix/YouTube + عنوان بالمزاج | سجل + Directive + صوت |
| Outdoor Running (GPS) | GPS | مسافة GPS، إيقاع، وقت، سعرات | خريطة مسار + رفيق ساعة | سجل + Directive |
| الجري/المشي/الدراجة/إليبتكال/درج | قياسي | نبض، مسافة، وقت، سعرات | معالم كم | سجل + Directive |
| السباحة | قياسي | نبض، وقت، سعرات | بلا مسافة (مسبح) | سجل + Directive |
| القوة/HIIT/كاليسثينِكس/بيلاتس | قياسي | نبض، وقت، سعرات | شدّة عالية لـ HIIT | سجل + Directive |
| كرة قدم/سلة/تنس/ملاكمة/فنون/نطّ | قياسي | نبض، وقت، سعرات | شدّة رياضة | سجل + Directive |
| اليوغا | قياسي | نبض، وقت، سعرات | تركيز تعافٍ | سجل + Directive |
| الامتنان | ذهن وجسد | وقت | جمل دوّارة يومياً، مقفول بعد الظهر | سجل (`mindAndBody`) |
| Vision Coach (ضغط) | كاميرا + عدّ | تكرارات، دقّة% | تقدير وضعية على الجهاز + صوت | تقدّم تحدّي |
| الفروسية | قياسي | نبض، وقت، سعرات | — | سجل + Directive |
| خطّة الكابتن (Plan) | مدرّب-موجّه | إكمال مجموعات/تمارين | مؤقّت راحة تلقائي + بصائر عضلات | تقدّم خطّة |

كل التمارين تُسجّل عبر **HealthKit** (`HKWorkoutSession` / `HKLiveWorkoutBuilder` / `HKWorkout`). تحليل ما بعد التمرين **حتمي وأوفلاين** وثنائي اللغة (عراقي/إنجليزي).

---

## الفوتر

**المنتج:** AiQo — تطبيق صحّة عربيّ-أوّلاً، iOS + watchOS، الكابتن حمّودي.
**المؤلّف:** محمد رعد (`mraad500`).
**كُتب:** 2026-05-18 من قراءة الكود الحي مباشرة (`GymExercise.swift`, `WorkoutCategoriesView.swift`, `LiveWorkoutSession.swift`, `WatchWorkoutType.swift`, `ZoneCoachingVoiceService.swift`, `OutdoorRun/*`, `VisionCoach/*`, `WorkoutManager.swift` وغيرها).
**حالة الريبو:** فرع `release/v1.0.4-memory-v4`، HEAD `cc30c4b` · الإصدار 1.0.5 / build 23.
**مراجع مكمّلة:** [AiQo_Master_Blueprint_19.md](AiQo_Master_Blueprint_19.md) (المرجع الشامل) · §3 الركيزة الرياضية و§5 الـ Brain OS فيه.

— *الكابتن حمّودي: «ها بطل، خلّينا نشتغل.»*
