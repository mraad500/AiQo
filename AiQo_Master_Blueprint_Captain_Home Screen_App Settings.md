<div align="center">

<img src="AiQo.png" width="140" height="140" alt="AiQo" />

# **AiQo — كابتن حمّودي · الشاشة الرئيسية · إعدادات التطبيق**

*Master Blueprint · Captain · Home Screen · App Settings*

**شرح تقني كامل لعقل الكابتن وواجهته، وشاشة البيت، وكل إعداد بالتطبيق**

</div>

---

## مقدمة

هذا الملف يشرح **ثلاث ركائز** من تطبيق AiQo بالتفصيل التقني، مكتوب من **قراءة الكود الحيّ مباشرة** (مو من ذاكرة أو تخمين):

1. **كابتن حمّودي بالكامل** — الهوية والصوت، عقل الـ Brain OS، طبقات البرومبت السبع، عقد المخرجات JSON، خط الاستدلال، الذاكرة الدلالية، طبقة الأوامر، الصوت، الترحيب، الذاكرات والتذكيرات، بوابات الاشتراك، وواجهة المحادثة.
2. **الشاشة الرئيسية** — هيكل التبويبات، الهالة اليومية، شبكة المقاييس الستة، كرت الماء، الـ Vibe، المطبخ، ومصادر البيانات.
3. **إعدادات التطبيق** — كل قسم وزرّ وتبديل بشاشة الإعدادات والملف الشخصي، نظام المستويات والدروع، الاشتراك، والدعم.

> **⚠️ ملاحظة دقّة مهمّة:** نسخة "النظام الكنسي" (canonical prompt) اللي يكتبها المؤلّف يدوياً تختلف عن الكود المشحون. **المصدر الحقيقي لما يرسله/يتوقّعه التطبيق** هو [PromptComposer.swift](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift) (مؤلّف 7 طبقات) + [CaptainModels.swift](AiQo/Features/Captain/Brain/04_Inference/CaptainModels.swift) (عقد `CaptainStructuredResponse`). هذا الملف يوثّق **الكود المشحون** لا النص الكنسي.

المصطلحات التقنية (أسماء الملفات، أنواع Swift، المعادلات) بالإنجليزية للدقّة؛ الشرح بالعربية.

**حالة الريبو وقت الكتابة:** فرع `release/v1.0.4-memory-v4` · HEAD `cc30c4b` · الإصدار 1.0.5 / build 23.

---

# الجزء الأول — كابتن حمّودي بالكامل

---

## 1. الهوية والصوت

كابتن حمّودي هو **العقل العالمي** لتطبيق AiQo — مدرّب ذكاء اصطناعي يحجي باللهجة العراقية/الخليجية حصراً، صوته يُولّد عبر **MiniMax TTS** ويُنطق للمستخدم. كل كلمة يكتبها بحقل `message` تُقرأ بصوت ذكر عراقي.

**قواعد الصوت (Voice-First) المضمّنة بطبقة الهوية** ([PromptComposer.swift:95](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)):
- يجاوب على **النيّة أوّلاً** (تحية → يحيّي، تنفيس → يتعاطف، سؤال → يجاوب مباشرة).
- مو لوحة بيانات صحّية — ما يرمي إحصائيات بدون طلب.
- مختصر: فكرة وحدة واضحة > ثلاث أفكار مخفّفة. سقف صارم: ≤ 90 كلمة أو ≤ 5 جُمل قصيرة إلا إذا المستخدم طلب خطّة صراحة.
- نصيحة محدّدة قابلة للتنفيذ ("3 مجاميع سكوات" مو "جرّب تتمرّن").
- السخرية العراقية الخفيفة مسموحة؛ الإيجابية المصطنعة ممنوعة. الأصالة ("ما أعرف") > ادّعاء العلم بكلشي.
- **حجب المتغيّرات الداخلية:** ما يقول أبداً "مرحلتك البيولوجية تعافي" أو يرجّع أرقام الخطوات/نطاقات النبض الخام للمستخدم — يستخدمها بصمت.
- الاسم الأول فقط، كل 3-4 رسائل مرّة، ما يستخدم "User" أو "Captain" كبديل.

**ست قواعد طول الرد** (محدّدة بالطبقة): سؤال بسيط → جملة-جملتين · سؤال متعدّد المقاييس → جملة مضغوطة لكل مقياس + سؤال متابعة واحد · خطّة → نقاط مختصرة بدون مقدّمة · دعم عاطفي → جملة دافئة + سؤال واحد.

---

## 2. عقل الكابتن — Brain OS (12 نظام فرعي)

عقل الكابتن منظّم بـ **12 مجلّد مرقّم** تحت [AiQo/Features/Captain/Brain/](AiQo/Features/Captain/Brain/):

| المجلّد | الوظيفة |
|---|---|
| `00_Foundation` | الأساس — `TierGate`، `CaptainLockedView`، الأنواع المشتركة. |
| `01_Sensing` | الاستشعار — جلب HealthKit وبناء `CaptainContextData`. |
| `02_Memory` | الذاكرة — `MemoryStore`، `MemoryRetriever`، `ChatMemoryEnricher`، `CaptainMemoryActionHandler`. |
| `03_Reasoning` | الاستدلال — `ScreenContext`، الـ Cognitive Pipeline، تلخيص النيّة. |
| `04_Inference` | الاستدلال السحابي — `PromptComposer`، `CaptainModels`، `HybridBrain`، `CloudBrain`، `DynamicWelcomeComposer`. |
| `05_Privacy` | الخصوصية — `PrivacySanitizer`، تجزئة البيانات الصحّية، حجب PII. |
| `06_Proactive` | الاستباقية — `SmartNotificationScheduler` والإشعارات الذكية. |
| `07_Learning` | التعلّم — استخراج الذاكرة بعد كل رد. |
| `08_Persona` | الشخصية — `CaptainPersonaBuilder`، العبارات الممنوعة. |
| `09_Wellbeing` | الرفاه — التأطير الصحّي وحدود السلامة. |
| `10_Observability` | المراقبة — سجلّ التدقيق، قياس الكُمون. |
| `11_Directives` | **طبقة التعلّم/التنفيذ** — `DirectiveLearner`، `DirectiveEngine`، `WorkoutComparisonComposer` (v1.0.5/23). |

بالإضافة لمجلّد الصوت [AiQo/Features/Captain/Voice/](AiQo/Features/Captain/Voice/) — `CaptainVoiceRouter`، `MiniMaxTTSProvider`، `CaptainVoiceConsent`.

---

## 3. PromptComposer — طبقات البرومبت السبع

كل رسالة تروح للنموذج تُبنى عبر [PromptComposer.swift](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift). تعليق رأس الملف يحدّد **7 طبقات كنسيّة** بالترتيب، مع طبقات مساعدة قبلها وبينها:

| # | الطبقة | الدالّة (سطر) | شنو تحقن |
|---|---|---|---|
| — | **قفل لغة الرد** | `layerReplyLanguageLock` ([:45](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | توجيه مطلق "رُدّ بهاي اللغة فقط" — يمنع انجراف اللغة. |
| — | **قواعد السلامة** | `layerSafetyRules` ([:68](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | Apple 1.4.1 — مدرّب رفاه مو طبيب، لا تشخيص ولا أدوية، الأرقام الطبّية تُحوّل لطبيب. |
| **1** | **الهوية** | `layerIdentity` ([:95](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | الكود السلوكي، العبارات الممنوعة، حدود طول الرد، حجب المتغيّرات الداخلية، استخدام الاسم. |
| **2** | **الملف الثابت** | `layerStableProfile` ([:221](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | الهدف، الجنس، العمر، العادات، التفضيلات الدائمة (يُتخطّى لو فاضي). |
| **3** | **الذاكرة العاملة** | `layerWorkingMemory` ([:236](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | تلخيص النيّة + الذاكرة بعيدة المدى المنشّطة لهاي الرسالة + خط آخر 5-7 تفاعلات بالطوابع الزمنية. |
| **4** | **الحالة الحيوية** | `layerBioState` ([:287](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | خطوات/سعرات/نوم/نبض/وقت + اتجاهات 7 أيام + الحالة العاطفية. **داخلي فقط — ما يُعرض للمستخدم.** |
| **5** | **النبرة اليومية** | `layerCircadianTone` ([:384](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | نبرة حسب وقت اليوم: استيقاظ/طاقة/تركيز/تعافي/زِن، مع تجاوز عاطفي لو المستخدم تعبان. |
| **6** | **سياق الشاشة** | `layerScreenContext` ([:422](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | أي شاشة (mainChat/gym/kitchen/sleepAnalysis/peaks/myVibe) + معالجة صورة الجسم بشاشة الجيم + جسر الموسيقى. |
| **7** | **عقد المخرجات** | `layerOutputContract` ([:543](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | شكل JSON الصارم + قواعد كل حقل. |
| — | **أطروحة الكوتشينج** | `layerCoachingThesis` ([:749](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | قراءة استراتيجية: الهدف مقابل الواقع (يُتخطّى بشاشة تحليل النوم). |
| — | **التنويه الطبّي** | `layerMedicalDisclaimer` ([:779](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift)) | الأرقام الصحّية تشير لـ WHO/ACSM. |

**معالجة صورة الجسم (شاشة الجيم فقط):** لو فيه صورة مرفقة، النموذج يقرأ العضلات → يحدّد النقاط الضعيفة → يكيّف الخطّة (مثلاً يميل تمارين الإسناد للمجاميع المتأخّرة). **قواعد صارمة:** ممنوع تقدير وزن/نسبة دهون/BMI، ممنوع لغة تجريح، فقط العضلات ذات الصلة بالتدريب.

---

## 4. عقد المخرجات — `CaptainStructuredResponse`

النموذج لازم يرجّع **كائن JSON واحد صالح**. الديكودر هو [CaptainModels.swift:84](AiQo/Features/Captain/Brain/04_Inference/CaptainModels.swift):

```swift
struct CaptainStructuredResponse: Codable, Sendable {
    let message: String                              // مطلوب، غير فارغ، طبيعي 100%
    let quickReplies: [String]?                      // 2-3 اقتراحات، ≤25 حرف، تُقصّ لـ prefix(3)
    let workoutPlan: WorkoutPlan?                    // كائن كامل أو nil
    let mealPlan: MealPlan?                          // كائن كامل أو nil
    let spotifyRecommendation: SpotifyRecommendation? // كائن كامل أو nil
    let savedMemory: CaptainSavedMemory?             // {"note": "...", "title": "...?"}
    let reminder: CaptainReminder?                   // {"body": "...", "time": "HH:mm", "date": "...?"}
}
```

**الكائنات الفرعية:**

| الكائن | الحقول | قواعد التحقّق |
|---|---|---|
| `WorkoutPlan` | `title`, `exercises[]`, `days[]?`, `durationWeeks?` | لو `days` موجودة تُفضّل وتُستخرج منها التمارين؛ كل تمرين: `name` + `sets > 0` + `repsOrDuration`. |
| `WorkoutDay` | `name`, `focus?`, `exercises[]` | اسم + تمرين واحد على الأقل. |
| `MealPlan` | `meals[]` (`type`, `description`, `calories`) | وجبة واحدة على الأقل، السعرات > 0. |
| `SpotifyRecommendation` | `vibeName`, `description`, `spotifyURI` | fallback عبر `myVibeFallback(...)` يطابق كلمات الرسالة (طاقة/تركيز/مزاج). |
| `CaptainSavedMemory` | `note`, `title?` (≤40 حرف) | فقط لو المستخدم طلب صراحة "احفظ/تذكّر". يُخزّن `category:"saved"`, `source:"user_explicit"`. |
| `CaptainReminder` | `body`, `time` ("HH:mm" 24س)، `date?` ("yyyy-MM-dd") | `isValidTime()` يفحص 0-23/0-59؛ `normalizedTime()` يحوّل "7:5" → "07:05". |

**التحقّق عند الـ init:** `message` يُقصّ ولازم غير فارغ (يرمي خطأ لو فارغ)؛ `quickReplies` تُزال التكرارات والفوارغ؛ كل كائن فرعي يمرّ بفحص `.isMeaningful`.

---

## 5. خط الاستدلال — `CaptainViewModel`

مسار الرسالة من الواجهة للرد ([CaptainViewModel.swift](AiQo/Features/Captain/CaptainViewModel.swift)):

```
المستخدم يدزّ رسالة
  ↓ [MainActor] sendMessage()
  ├─ حارس: بوابة الاشتراك، فحص الموافقة، منع التكرار
  ├─ حفظ رسالة المستخدم بـ SwiftData
  └─ Task { ... }
      ├─ كشف الأوامر الدائمة (DirectiveLearner)
      ├─ بناء تاريخ المحادثة (آخر 24 رسالة) + خلاصة الجلسة
      ├─ بناء CaptainPromptContext (متزامن، MainActor)
      └─ processMessage() [خارج MainActor]
          ├─ بالتوازي: قراءة HealthKit + RAG الدلالي (ChatMemoryEnricher)
          ├─ كشف المشاعر (SentimentDetector)
          ├─ BrainOrchestrator.processMessage() → نوم؟ محلي : سحابي
          ├─ تحقّق (PrivacySanitizer، إزالة الجُمل المكرّرة)
          ├─ أرضية تحميل دنيا 0.8s
          ├─ كشف تدريجي (revealReply) أو إلحاق فوري
          ├─ حفظ الرد + استخراج الذاكرة (async)
          └─ تطبيق آثار savedMemory / reminder + قياس الكُمون
```

**الكشف التدريجي (Streaming)** ([CaptainViewModel.swift:770](AiQo/Features/Captain/CaptainViewModel.swift)): **مو SSE حقيقي** — كشف تدريجي للنص المكتمل محاكاةً. النص يُقسّم لـ `min(max(total,1), 40)` خطوة، كل خطوة كل ~16ms. يحترم `UIAccessibility.isReduceMotionEnabled` (إلحاق فوري لو مفعّل). عند الانتهاء `appendFinal()` يبدّل فقاعة الستريم بالرسالة الحقيقية بطفرة متزامنة واحدة (ما يعيد فرق المحادثات الطويلة).

**ميزانيات المهلة:**
- عام (كل الشاشات إلا النوم): `globalProcessingTimeout = 30s` — يغطّي DNS بارد + TLS + بدء النموذج البارد + برومبت 7 طبقات (Gemini عادة 12-22s). URLSession = 35s.
- تحليل النوم (محلّي + Foundation Models): `sleepProcessingTimeout = 25s`. يُكتشف بـ `looksLikeSleepRequest()` (كلمات: حلّل/نوم/sleep/REM).

---

## 6. شبكة الاستدلال — Gemini + خصوصية

**النموذج والمزوّد** ([04_Inference/Services/CloudBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift)):

```swift
enum GeminiModel {
  static let fast      = "gemini-2.5-flash"          // Max وما دون
  static let reasoning = "gemini-3-flash-preview"    // Pro
}
let aiModel = activeTier.effectiveAccessTier == .pro ? .reasoning : .fast
```

**الإعداد** ([HybridBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift)): نقطة النهاية `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` · مهلة الطلب 35s، المورد 40s · المفتاح من Info.plist (من `Secrets.xcconfig`) ثم متغيّر بيئة (CI/TestFlight).

**خطّ التعقيم قبل الإرسال** ([CloudBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift)): يقصّ المحادثة لآخر 4 رسائل · يحجب PII (إيميل/هاتف/UUID/IP) · يطبّع الاسم → "User" · يجزّأ البيانات الصحّية (خطوات ÷50، سعرات ÷10) · سقف ذاكرة سحابية: 700 توكن (Pro) / 400 (غيره) · سجلّ تدقيق (بايتات البرومبت/الرد، الكُمون، التير، الموافقة).

**التعافي:** لو المستخدم طلب خطّة بوضوح والنموذج رجّع نصّ فقط → إعادة محاولة صامتة ببرومبت مركّز، يدمج الرسالة الغنيّة + الخطّة المستردّة، ما يكشف الفشل للمستخدم.

---

## 7. الاستدعاء الدلالي — RAG هجين

[MemoryRetriever.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryRetriever.swift) يجيب الذاكرة المنشّطة لكل رسالة. التوزيع: حقائق 40% · حلقات 25% · أنماط 15% · مشاعر 10% · علاقات 10% من `TierGate.shared.maxMemoryRetrievalDepth`.

**درجة هجينة (دلالي + معجمي):**
```
حقائق:  similarity×0.5 + lexicalOverlap×0.30 + confidence×0.15 + recency×0.05
حلقات:  similarity×0.4 + lexicalOverlap×0.25 + recency×0.2     + salience×0.15
```

`lexicalOverlap` (تقاطع التوكنات) هو **fallback متين** لمّا تكون الـ embeddings غير متاحة — حسّاس للعربية على الأجهزة القديمة.

**فرق التيرات (تصميمي، مو خلل):**
- **مجّاني (`none`):** عمق الاسترجاع = 0 → ما فيه استدعاء دلالي، الحزمة فارغة، ما يُلحق بلوك "ذاكرة مستدعاة" (لا انحدار). معجمي فقط.
- **مدفوع:** عمق غير صفري حسب التير. `ChatMemoryEnricher` يلحق `[recalled_memory]` بعد إزالة المكرّر من القاعدة المعجمية.

---

## 8. طبقة الأوامر — `11_Directives` (تعلّم/تنفيذ)

طبقة تخلّي المستخدم "يعلّم" الكابتن قاعدة دائمة (مثلاً: "بعد كل تمرين حلّل وقارن ودزّلي إشعار").

**`DirectiveLearner`** ([11_Directives/DirectiveLearner.swift](AiQo/Features/Captain/Brain/11_Directives/DirectiveLearner.swift)) — كشف **على الجهاز، بدون شبكة/LLM**، regex بحت. يحتاج تطابق ثلاثي: علامة تكرار ("بعد كل"/"كل مرة"/"from now on") + فعل ("حلّل"/"دزّلي"/"قارن") + نطاق (تمرين/نوم/صباح/أسبوعي).

**`DirectiveEngine`** ([11_Directives/DirectiveEngine.swift](AiQo/Features/Captain/Brain/11_Directives/DirectiveEngine.swift)) — يُطلق غير متزامن من `AIWorkoutSummaryService.handleWorkoutEnded()`:

```swift
func handleWorkoutCompleted(_ snapshot: DirectiveWorkoutSnapshot) async -> String? {
  let directives = await store.directives(trigger: .afterWorkout, enabledOnly: true)
  guard let directive = directives.first else { return nil }
  let previous = await previousWorkout(before: snapshot.endedAt)
  switch directive.action {
  case .analyzeAndCompareWorkout:
    body = WorkoutComparisonComposer.compose(current: snapshot, previous: previous,
                                             fireCount: directive.fireCount,
                                             localeCode: directive.localeCode)
  case .notify:
    body = directive.params["text"] ?? defaultComparison()
  }
  await store.recordFired(id: directive.id)
  return body
}
```

**`WorkoutComparisonComposer`** يبني تحليلاً **حتمياً أوفلاين بدون LLM/شبكة/كلفة** يقارن التمرين الحالي بالسابق: فرق المدّة، السعرات، النبض المعدّل (لو > 3)، المسافة (لو > 0.3كم)، نسبة زون 2/الذروة، زخم السلسلة — عربي عراقي + إنجليزي. يُرسل عبر `NotificationBrain`، مبوّب بـ `TierGate.captainDirectives` (`.max`+).

---

## 9. الصوت — TTS

[CaptainVoiceRouter](AiQo/Features/Captain/Voice/CaptainVoiceRouter.swift) موزّع واحد للنطق، توجيه بطبقتين:

| الطبقة | المزوّد | الشرط |
|---|---|---|
| **Premium** | MiniMax TTS سحابي ([MiniMaxTTSProvider.swift](AiQo/Features/Captain/Voice/MiniMaxTTSProvider.swift)) | موافقة `CaptainVoiceConsent` + إعداد `Secrets.xcconfig` + تير `.pro`. كاش ملفّي عبر `VoiceCacheStore`. مهلة طلب 25s. |
| **Fallback** | Apple `AVSpeechSynthesizer` على الجهاز | بدون موافقة. يُستخدم لو السحابة غير متاحة/الموافقة ناقصة/الإعداد ناقص. 3 إخفاقات MiniMax متتالية → توست + تحوّل صامت. |

`@Published isSpeaking` و`activeProvider` تراقبهم الواجهة لإظهار حالة السمّاعة. زرّ السمّاعة على رسائل الكابتن يبيّن نقطة مينت لو الصوت المحسّن فعّال. شيت الموافقة `VoiceConsentSheet` يظهر تفاعلياً عند ضغط السمّاعة بدون موافقة. `ZoneCoachingVoiceService` (عبارات زون 2 المسبقة) يستخدم نفس الموزّع بطبقة premium.

---

## 10. رسالة الترحيب الديناميكية

[DynamicWelcomeComposer.swift](AiQo/Features/Captain/Brain/04_Inference/DynamicWelcomeComposer.swift) يؤلّف افتتاحية شخصية عند فتح المحادثة باردة.

**ميزانية المكالمة الباردة:** `timeoutSeconds = 30.0` — أوّل وأبرد مكالمة سحابية بالجلسة (DNS + TLS + بدء النموذج البارد + برومبت 7 طبقات). كانت 7s سابقاً (قصيرة جداً — الترحيب الديناميكي تقريباً ما كان يشتغل، انظر commit `2eae39b`).

**المدخلات:** اللغة + ملف المستخدم + `BioStateEngine.current()` + ماء اليوم + الاسم → برومبت مضغوط "ألّف ترحيباً شخصياً". يرجّع `nil` عند أي فشل (أوفلاين/موافقة ناقصة/مبوّب للمجّاني/شبكة/مهلة/رد فارغ) → المتّصل يعرض البديل الثابت "هلا! أنا كابتن حمّودي." الترحيب يصير أوّل رسالة مساعد بالمحادثة (صف عادي بأفاتار يسار).

---

## 11. الذاكرات المحفوظة والتذكيرات

[CaptainMemoryActionHandler.swift](AiQo/Features/Captain/Brain/02_Memory/CaptainMemoryActionHandler.swift) يطبّق آثار `savedMemory` و`reminder`:

**ذاكرة محفوظة:** فقط لو `savedMemory != nil` بالرد. تُخزّن بـ `MemoryStore` (`category:"saved"`, `source:"user_explicit"`, `confidence:1.0`, مفتاح `saved_<UUID>`). تظهر بشاشة "الذاكرة" ويقدر المستخدم يحذفها.

**تذكير:**
1. تحليل `time` (HH:mm) + `date?` (yyyy-MM-dd).
2. `CaptainReminderScheduler.schedule()` → `UNNotificationRequest` بمشغّل تقويمي، عنوان "الكابتن حمّودي"، deep-link `aiqo://captain`.
3. لو نجح: يُخزّن `CaptainReminderRecord` (JSON) بالذاكرات المحفوظة كصف قابل للإلغاء.

**قاعدة الصدق:** الكابتن **ما يقول أبداً "راح أذكّرك"** إلا إذا فعلاً رجّع `CaptainReminder` بوقت صالح → إشعار محلّي مجدول حقيقي. التذكيرات وقتية لمرّة واحدة (المتكرّر/الحدثي مؤجّل بقرار المؤلّف).

---

## 12. بوابات الاشتراك داخل الكابتن

[TierGate.swift](AiQo/Features/Captain/Brain/00_Foundation/TierGate.swift) — كتالوج الميزات وعتبات الوصول:

| الميزة | التير المطلوب |
|---|---|
| `basicLifeNotifications` (ماء/سلسلة/نوم/تمرين/أسبوعي) | `.none` (مجّاني) |
| `captainChat` · `captainMemory` · `captainNotifications` · `captainDirectives` | `.max`+ |
| `multiWeekPlan(weeks>1)` · `weeklyInsightsNarrative` · `monthlyReflection` · `photoAnalysis` · `premiumVoice` · `advancedCulturalAwareness` | `.pro`+ |

**مصدر التير:** `UserDefaults("aiqo.purchases.currentTier")` + فحص تجربة `FreeTrialManager.isTrialActiveSnapshot`؛ الكتابة عبر `EntitlementStore` (مراقب StoreKit 2). **نقاط البوابة داخل الكابتن:** دخول المحادثة، عمق الاسترجاع (0 للمجّاني)، الأوامر، الصوت، الترحيب الديناميكي.

---

## 13. واجهة محادثة الكابتن

| المكوّن | الملف | تفاصيل |
|---|---|---|
| **شاشة ما-قبل-الدردشة** | [CaptainScreen.swift:196](AiQo/Features/Captain/CaptainScreen.swift) | وضعان: `showcaseMode` (صندوق مضغوط فوق أفاتار كامل) و`chatMode` (دردشة كاملة بأفاتار 56×56 مثبّت فوق الإدخال). |
| **شاشة الدردشة** | [CaptainChatView.swift](AiQo/Features/Captain/CaptainChatView.swift) | تحلّ محل `CaptainScreen` بعد أوّل رسالة عبر `appRootManager.isCaptainChatPresented`. |
| **الفقاعة** | [MessageBubble.swift](AiQo/Features/Captain/MessageBubble.swift) | مستخدم = مينت `#C4F0DB`، كابتن = رملي `#F8D6A3`، نصّ `#0F1721`، زوايا غير متماثلة. |
| **كرت الخطّة** | [CaptainChatView.swift](AiQo/Features/Captain/CaptainChatView.swift) `WorkoutPlanReadyCard` | "🎯 خطّة التمرين جاهزة" + معاينة 4 تمارين بكبسولات لمّا `currentWorkoutPlan != nil`. |
| **كرت الفايب** | [VibeMiniBubble.swift](AiQo/Features/Captain/VibeMiniBubble.swift) | رمز نوتة + اسم الفايب + وصف + زرّ تشغيل، يظهر تحت رسالة الكابتن لو فيه `spotifyRecommendation`. |
| **ردود سريعة** | [CaptainChatView.swift](AiQo/Features/Captain/CaptainChatView.swift) | ScrollView أفقي كبسولات، ضغطة → `sendMessage(reply)`. |
| **تاريخ المحادثات / الذاكرة** | [ChatHistoryView.swift](AiQo/Features/Captain/ChatHistoryView.swift) | مبوّب بـ `canAccess(.captainMemory)`؛ لو مقفول → `CaptainLockedView`. مصدر `MemoryStore.fetchSessions()`. |
| **حالة مقفولة** | [CaptainLockedView.swift](AiQo/Features/Captain/Brain/00_Foundation/CaptainLockedView.swift) | كرت زجاجي + زرّ "افتح [TIER]" → `PaywallView(source: .captainGate)`. |

**نقطة الدخول:** التبويب الثالث بـ [MainTabScreen.swift](AiQo/App/MainTabScreen.swift) — لو ما عنده `.captainChat` يظهر `CaptainLockedView`. Deep-link من الإشعارات عبر `CaptainNavigationHelper.navigateToCaptainScreen()`. الـ `ScreenContext` الافتراضي `.mainChat`؛ شاشات السياق (gym/kitchen) تمرّر سياقها لتخصيص سلوك النموذج.

---

# الجزء الثاني — الشاشة الرئيسية (الشاشة الرئيسية)

---

## 1. هيكل التطبيق والتبويبات

[MainTabScreen.swift](AiQo/App/MainTabScreen.swift) — `TabView(selection:)` مع `MainTabRouter.shared`. **3 تبويبات فقط** ([MainTabRouter.swift:9](AiQo/App/MainTabRouter.swift)):

| # | التبويب | الرمز | المحتوى |
|---|---|---|---|
| 0 | **البيت** (`.home`) | `house.fill` | `HomeView()` (الافتراضي) |
| 1 | **الجيم** (`.gym`) | `figure.strengthtraining.traditional` | `GymView()` |
| 2 | **الكابتن** (`.captain`) | `wand.and.stars` | `CaptainScreen()` أو `CaptainLockedView()` لو مبوّب |

**الملف الشخصي والمطبخ مو تبويبات** — يُفتحان كـ sheets. كل تبويب ملفوف بـ `NavigationStack`. RTL عام (`.environment(\.layoutDirection, .rightToLeft)`). لون التير ذهبي `#FFDF63`. عند `.levelDidLevelUp` تظهر `LevelUpCelebrationView()` (بفحص `lastCelebratedLevel` لمنع التكرار).

---

## 2. تخطيط الشاشة الرئيسية

[HomeView.swift](AiQo/Features/Home/HomeView.swift):

```
HomeView
├─ topChrome (AiQoScreenTopChrome)  — صف الهيدر
├─ dailyAuraSection (DailyAuraView) — حلقة الهالة الدائرية
├─ metricsGrid                      — 6 كروت مقاييس بشبكة عمودين
└─ kitchenSection                   — زرّ المطبخ العائم
```

**الهيدر** ([AiQoScreenHeader.swift](AiQo/UI/AiQoScreenHeader.swift)): يسار (بـ RTL) زرّ `VibeDashboardTrigger`، يمين `AiQoProfileButton` (دائري بأفاتار/أحرف، هدف 44×44). **ما فيه نصّ تحية ديناميكي بالهيدر** — الهيدر فقط أزرار.

---

## 3. الهالة اليومية — DailyAura

[DailyAuraView.swift](AiQo/Features/Home/DailyAuraView.swift) — حلقة 172×172:
- حلقة داخلية (خطوات) مينت أخضر · حلقة خارجية (سعرات) رملي · كرة مركزية تتنفّس (2.4s) · هالة برتقالية عند `auraProgress >= 1.0`.
- 18 قوس متّجه بأربع مراحل (مراحل 0-2 خطوات، مرحلة 3 سعرات).
- `stepsProgress = min(steps/goal,1)` · `caloriesProgress = min(cal/goal,1)` · `auraProgress = (الاثنين)/2`.
- المصدر `DailyAuraViewModel` يبتلع من `HomeViewModel.ingest(todaySteps:todayCalories:)`. ضغطة → `DailyGoalsSheetView()` (تبويبات: أهداف قابلة للتعديل + تاريخ 14 يوم).

---

## 4. شبكة المقاييس الستة

[HomeStatCard.swift](AiQo/Features/Home/HomeStatCard.swift) — ترتيب: `[steps, calories, sleep, water, stand, distance]`.

| المقياس | القيمة | المصدر | الضغطة |
|---|---|---|---|
| **خطوات** (مينت) | `steps.arabicFormatted` | `HealthKitManager.$todaySteps` | شيت رسم يوم/أسبوع/شهر/سنة/الكل |
| **سعرات** (مينت) | `activeKcal.arabicFormatted` | `fetchActiveEnergySeries()` | نفس الشيت |
| **نوم** (رملي) | `sleepHours` (عشري واحد) | `HKCategoryType(.sleepAnalysis)` | شيت خاص `SleepDetailCardView` |
| **ماء** (رملي) | `waterML/1000` + " L" | `HKQuantityType(.dietaryWater)` | **شيت مختلف:** `WaterDetailSheetView` |
| **وقوف** (مينت) | `standPercent` + "%" | `HKCategoryType(.appleStandHour)` | نفس شيت الرسم |
| **مسافة** (مينت) | `distanceMeters/1000` + " km" | `HKQuantityType(.distanceWalkingRunning)` | نفس شيت الرسم |

كرت 80pt ارتفاع، حافّة 24pt، عنوان+شارة فوق وقيمة 34pt تحت يمين. دخول متدرّج (`index×0.06`، spring 0.4/0.8) + طفو خفيف (-6pt، 5s) يحترم Reduce Motion. مصدر البيانات `TodaySummary` (steps, activeKcal, standPercent, waterML, sleepHours, distanceMeters).

---

## 5. كرت الماء وشيت الترطيب

ضغطة كرت الماء تفتح [WaterDetailSheetView.swift](AiQo/Features/Home/WaterDetailSheetView.swift) (detents `.medium/.large`):
- حلقة بطل `WaterHeroRingView` (`consumed/goal`، الافتراضي 2.5L) + كبسولة نسبة متحرّكة.
- **صف الإضافة السريعة:** **+0.25L** · **+0.5L** · **مخصّص** (شيت متداخل، slider 0.05-1.0L خطوة 0.05).
- قسم الترطيب الذكي `SmartHydrationSection(HydrationService.shared)` — **ميزة مجّانية** (مبوّب بفلاغ).

**تدفّق الإضافة:** يحدّث `currentWaterLiters += amount` → `viewModel.addWater(liters:)` → `healthService.logWater(ml:)` → تحديث الـ widget → اهتزاز ناعم. (هذا "ضغطة واحدة +0.25L" الموجود بالويدجت والشاشة).

---

## 6. شيتات التفاصيل والـ Vibe والمطبخ

- **شيت تفاصيل المقياس** ([HomeView.swift](AiQo/Features/Home/HomeView.swift) `MetricDetailSheet`): عنوان + قيمة 32pt + منتقي نطاق (يوم/أسبوع/شهر/سنة/الكل) + `SimpleBarChart` 140pt. النوم يستخدم `SleepDetailCardView` بدلاً عن الرسم العام.
- **ذوقي/Vibe** ([VibeControlSheet.swift](AiQo/Features/Home/VibeControlSheet.swift)): زرّ بالهيدر → شيت (`.fraction(0.6)/.large`). **مبوّب `.max`** — لو مقفول `CaptainLockedView` → `PaywallView(source:.myVibeGate)`. محتوى: منتقي مصدر (Spotify/أصوات AiQo) + كروت أوضاع (Awakening/Deep Focus/Ego Death/Energy/Recovery) + تحكّم تشغيل.
- **المطبخ** ([HomeView.swift](AiQo/Features/Home/HomeView.swift)): زرّ 100×100 أسفل الشاشة. **مبوّب `.max`** (`AccessManager.canAccessKitchen`). ضغطة → `activeDestination = .kitchen` → شيت (`.fraction(0.75)/.large`) → `HomeKitchenRootView()` أو paywall.

---

## 7. التنقّل ومصادر البيانات

**تنقّل قائم على Sheets** (مو NavigationLink): `MetricDetailSheet` · `VibeControlSheet` · `destinationView(.kitchen/.waterDetail)` · `aiqoProfileSheet → ProfileScreen`.

**دورة حياة البيانات** ([HomeViewModel.swift](AiQo/Features/Home/HomeViewModel.swift)): `onAppear()` → فحص وضع العرض → `setupHealthAndAutoRefresh()` → إذن HealthKit → `loadTodayFromHealth()`. ربط حيّ عبر Combine (`$todaySteps/$todayCalories/$todayDistanceKm` مع debounce). مؤقّت تحديث 60s أثناء الظهور. `onAppBecameActive()` يعيد جلب ويعيد جدولة تذكيرات الترطيب الذكية. وضع العرض (debug) يستخدم بيانات `DemoConfiguration` ثابتة للقطات الشاشة.

---

# الجزء الثالث — إعدادات التطبيق (إعدادات التطبيق)

---

## 1. شاشة الإعدادات — `AppSettingsScreen`

[AppSettingsScreen.swift](AiQo/Core/AppSettingsScreen.swift) — `Form` تُفتح من الملف الشخصي. الأقسام بالترتيب:

| القسم | الصفوف |
|---|---|
| **الإشعارات** | تبديل "الإشعارات" (تذكيرات النشاط) → `AppSettingsStore.notificationsEnabled` · منتقي "لغة الكابتن" (عربي/إنجليزي) → `UserDefaults("notificationLanguage")`. |
| **اللغة** | منتقي "لغة التطبيق" (عربي `ar` / إنجليزي `en`) → `AppSettingsStore.appLanguage` (مفتاح `aiqo.app.language`) → `LocalizationManager.setLanguage()`. |
| **ذاكرة الكابتن** | رابط "ذاكرة الكابتن 🧠" → `CaptainMemorySettingsView()`. |
| **الخصوصية وبيانات الذكاء** | 5 صفوف (انظر §4). |
| **الإحالة** | `ReferralSettingsRow()`. |
| **الحساب** | "تسجيل الخروج" → `AppFlowController.logout()` · "حذف الحساب" (أحمر) → RPC `delete_user_account()`. |
| **القانوني** | سياسة الخصوصية · شروط الخدمة · الإقرارات → `LegalView(...)`. |

---

## 2. الإشعارات — استراتيجية الميزانية المبوّبة

التبديل الرئيسي عند التفعيل ينادي `NotificationService.requestPermissions()` + `SmartNotificationScheduler.refreshAutomationState()`؛ عند الإطفاء يلغي كل الإشعارات المعلّقة عبر `UNUserNotificationCenter`.

**الميزانية اليومية المبوّبة** ([SubscriptionTier.swift](AiQo/Core/Purchases/SubscriptionTier.swift) `dailyNotificationBudget`):

| التير | السقف / 24س |
|---|---|
| مجّاني (`none`) | **2** |
| Max | **4** |
| تجربة (`trial`) | **7** |
| Pro | **7** |

`CoachNotificationLanguage` (arabic/english) → `NotificationPreferencesStore.shared.language`. (يطابق استراتيجية الإشعارات: مجّاني = حياة-أساسية، تجربة = مسار تفاعلي، سقف متدرّج حسب التير).

---

## 3. اللغة والوحدات

منتقي لغة التطبيق (عربي/إنجليزي) يُحفظ بـ `aiqo.app.language` ويُطبّق عبر `LocalizationManager.setLanguage()` (كل النصوص `NSLocalizedString`). **الوحدات مو تبديل منفصل** — مشتقّة من اللغة (متري كغم/سم؛ ما فيه نسخة إمبريالية بالكود الظاهر؛ نصّ الوحدة الافتراضي `kg` من [ProfileScreenLogic.swift](AiQo/Features/Profile/ProfileScreenLogic.swift)).

---

## 4. الخصوصية وبيانات الذكاء (5 صفوف)

1. **التنويه الطبّي** → `MedicalDisclaimerDetailView(mode:.settings)` ("AiQo ليس جهازاً طبياً").
2. **استخدام بيانات الذكاء** → `AIDataPrivacySettingsView()` (عنوان فرعي ديناميكي من `AIDataConsentManager.acceptedAt`).
3. **صوت الكابتن** → `VoiceSettingsScreen()` (مدفوع، مبوّب بفلاغ `FeatureFlags.captainVoiceCloudEnabled` + `CaptainVoiceConsent`: "قريباً"/"الصوت المحسّن مفعّل"/"الصوت المحلي فقط").
4. **صورة الجسم (الخطّة)** → `BodyPhotoSettingsScreen()` (`BodyPhotoConsent`؛ تُصغّر الصورة، تُجرّد EXIF/GPS، تُرسل لـ Gemini مرّة، ما تُحفظ).
5. **تحقّق كابتن حمّودي** — تبديل: تحليل شهادات الكورسات على الجهاز، الصورة ما تغادر الهاتف (`OnDeviceVerificationConsent`).

---

## 5. شاشة الملف الشخصي

[ProfileScreen.swift](AiQo/Features/Profile/ProfileScreen.swift):

- **Hero Card** ([ProfileScreenComponents.swift](AiQo/Features/Profile/ProfileScreenComponents.swift)): `PhotosPicker` للأفاتار → `UserProfileStore.saveAvatar()` · الاسم (قابل للتعديل) · **المستوى والدرع** + شريط XP · **Line Score** (إجمالي XP).
- **بيانات جسمك** (شبكة 2×2 قابلة للتعديل): العمر · الطول (سم) · الوزن (كغم) · الجنس — تحقّق (أعداد موجبة) ويُحفظ بـ `UserProfileStore.current`.
- **الاشتراك** (صف واحد): اسم الخطّة + "فعّال حتى [تاريخ]" / "اعرض الخطط" → paywall.
- **قسم "AiQo"** (4 صفوف): إعدادات التطبيق → `AppSettingsScreen()` · تقرير الأسبوع → `WeeklyReportView()` · صور التقدّم → `ProgressPhotosView()` · تواصل مع الدعم → `contactSupport()`.

---

## 6. نظام المستويات والدروع

[LevelStore.swift](AiQo/Core/Models/LevelStore.swift) (الكنسي) — 8 تيرات، الدرع يتغيّر كل 5 مستويات (`tierIndex = level / 5`):

| الدرع | المستويات | اللون |
|---|---|---|
| Wood | 1-4 | `#8B4513` |
| Bronze | 5-9 | `#CD7F32` |
| Silver | 10-14 | `#C0C0C0` |
| Gold | 15-19 | `#FFD700` |
| Platinum | 20-24 | `#E5E4E2` |
| Diamond | 25-29 | `#B9F2FF` |
| Obsidian | 30-34 | `#3D3D3D` |
| Legendary | 35+ | `#FF6B6B` |

`totalXP` مصدر الحقيقة (محفوظ)؛ `level` يُحسب عبر `AiQoLeveling.level(forTotalXP:)`. `addXP(_:)` يزيد الإجمالي، يعيد الحساب، يكشف الترقّي وينشر `.levelDidLevelUp` + `.aiqoXPGranted`، ويزامن لـ Supabase. مفاتيح `aiqo.user.level/currentXP/totalXP`. الـ XP يجي من تحدّيات المعركة، كورسات شرارة التعلّم، التمارين.

---

## 7. الاشتراك والـ Paywall والدعم

**التيرات** ([SubscriptionTier.swift](AiQo/Core/Purchases/SubscriptionTier.swift)): `.none` → مجّاني · `.max` → AiQo Max · `.trial` → تجربة مجانية · `.pro` → AiQo Intelligence Pro.

[EntitlementStore.shared](AiQo/Core/Purchases/EntitlementStore.swift) (مراقب): `currentTier`, `activeProductId`, `expiresAt`, `isActive`. تعيين `from(productID:)`: `coreMonthly/legacy*` → `.max` · `intelligenceProMonthly/proMonthly/...` → `.pro`. صفّ الاشتراك → `ProfilePaywallSheet` (`fullScreenCover`) → `PaywallView(source:.manual)`.

**الدعم** ([ProfileScreenLogic.swift](AiQo/Features/Profile/ProfileScreenLogic.swift)): الإيميل `AppAiQo5@gmail.com`. لو الجهاز يكدر يدزّ بريد → `MFMailComposeViewController` بموضوع "AiQo Support"؛ غير هيك → `mailto:` عبر `UIApplication.open`.

---

## مرجع سريع — كل شي بسطر

| المنطقة | المكوّن الأساسي | الملف |
|---|---|---|
| عقل الكابتن | برومبت 7 طبقات | [PromptComposer.swift](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift) |
| عقد المخرجات | `CaptainStructuredResponse` (7 مفاتيح) | [CaptainModels.swift:84](AiQo/Features/Captain/Brain/04_Inference/CaptainModels.swift) |
| التنسيق | UI→سياق→Gemini→ديكود→عرض، ستريم محاكى، مهلة 30s | [CaptainViewModel.swift](AiQo/Features/Captain/CaptainViewModel.swift) |
| الشبكة | Gemini 2.5-flash / 3-flash-preview حسب التير | [CloudBrain.swift](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift) |
| الذاكرة | RAG هجين، مجّاني=معجمي فقط | [MemoryRetriever.swift](AiQo/Features/Captain/Brain/02_Memory/Intelligence/MemoryRetriever.swift) |
| الأوامر | تعلّم/تنفيذ، مقارنة تمرين أوفلاين | [DirectiveEngine.swift](AiQo/Features/Captain/Brain/11_Directives/DirectiveEngine.swift) |
| الصوت | MiniMax + Apple fallback | [CaptainVoiceRouter.swift](AiQo/Features/Captain/Voice/CaptainVoiceRouter.swift) |
| الترحيب | ميزانية باردة 30s | [DynamicWelcomeComposer.swift](AiQo/Features/Captain/Brain/04_Inference/DynamicWelcomeComposer.swift) |
| واجهة الدردشة | شاشتين + فقاعات + كروت | [CaptainScreen.swift](AiQo/Features/Captain/CaptainScreen.swift) · [CaptainChatView.swift](AiQo/Features/Captain/CaptainChatView.swift) |
| الشاشة الرئيسية | 3 تبويبات + هالة + 6 مقاييس | [HomeView.swift](AiQo/Features/Home/HomeView.swift) · [MainTabScreen.swift](AiQo/App/MainTabScreen.swift) |
| الإعدادات | Form بأقسام + خصوصية | [AppSettingsScreen.swift](AiQo/Core/AppSettingsScreen.swift) |
| الملف الشخصي | Hero + جسم + اشتراك + AiQo | [ProfileScreen.swift](AiQo/Features/Profile/ProfileScreen.swift) |
| المستويات | 8 دروع، كل 5 مستويات | [LevelStore.swift](AiQo/Core/Models/LevelStore.swift) |

---

## الفوتر

**المنتج:** AiQo — تطبيق صحّة عربيّ-أوّلاً، iOS + watchOS، الكابتن حمّودي.
**المؤلّف:** محمد رعد (`mraad500`).
**كُتب:** 2026-05-18 من قراءة الكود الحيّ مباشرة والتحقّق من: `PromptComposer.swift` (7 طبقات مؤكّدة بتعليق الرأس)، `CaptainModels.swift` (عقد 7 مفاتيح)، `CaptainViewModel.swift`، `MainTabRouter.swift` (3 تبويبات)، `HomeView.swift`، `AppSettingsScreen.swift`، `ProfileScreen.swift`، `LevelStore.swift`، و12 نظام `Brain/` الفرعي.
**حالة الريبو:** فرع `release/v1.0.4-memory-v4` · HEAD `cc30c4b` · الإصدار 1.0.5 / build 23.
**ملاحظة دقّة:** النصّ الكنسي اليدوي للبرومبت يختلف عن الكود المشحون — هذا الملف يوثّق **الكود المشحون** (`PromptComposer` + `CaptainModels`) كمصدر حقيقة.
**مراجع مكمّلة:** [AiQo_Master_Blueprint_19.md](AiQo_Master_Blueprint_19.md) (المرجع الشامل — §4 الكابتن، §5 الـ Brain OS) · [AiQo_Master_Blueprint_Exercises.md](AiQo_Master_Blueprint_Exercises.md) (مرجع التمارين).

— *الكابتن حمّودي: «ها بطل، هسة تعرف العقل كلّه. خلّينا نشتغل.»*
