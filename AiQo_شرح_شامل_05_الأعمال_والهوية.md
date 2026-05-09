# AiQo — الملف الخامس: الأعمال، الهوية البصرية، وخريطة الطريق

> هذا الملف يشرح **كيف AiQo يربح فلوس**، كيف يطلق نفسه، شلون شكله ولونه، وشنو خطّته للمستقبل. اقرأه إذا تبي تفهم النموذج التجاري، التسعير، الـ branding، أو الـ roadmap.

---

# الجزء الأول: نموذج الأعمال

## 1. التيرين الاثنين للاشتراك

AiQo فيه **بالضبط تيرين اشتراك**. لا ثالث. لا lifetime (لحد هسه). لا annual (لحد هسه).

### 1.1 AiQo Core — $9.99/شهر

**تيير الأساس اليومي**. يشمل:

✅ كابتن حمّودي chat (نموذج Gemini 2.5 Flash)
✅ ذاكرة الكابتن (حد ٢٠٠ معلومة)
✅ صوت الكابتن (ElevenLabs TTS)
✅ ميزات الجيم الكاملة (خطط تمارين، Zone 2 coaching، تتبّع التمارين)
✅ ميزات المطبخ الكاملة (ماسح الثلاجة، خطط الوجبات، قائمة التسوق)
✅ ميزات النوم الكاملة (Smart Wake calculator، تحليل النوم)
✅ تتبّع نمط الحياة الكامل (خطوات، سعرات، ماي، وقوف، مسافة)
✅ Daily Aura visualization
✅ نظام XP والمستويات
✅ نظام Quests
✅ تتبّع streaks
✅ كل إشعارات الـ push (ماي، تمرين، نوم، streak، خمول)
✅ رفيق Apple Watch
✅ HRR Assessment
✅ خطط تمرين أسبوعية بالـ AI
✅ Record Projects (مشاهدة فقط — البدء يحتاج Pro)

**ما يشمل**:
❌ My Vibe (تكامل Spotify)
❌ Legendary Challenges (الوصول الكامل)
❌ ذاكرة الكابتن الموسّعة (حد ٥٠٠)
❌ نموذج Gemini 3.1 Pro
❌ إنشاء Tribe

### 1.2 AiQo Intelligence Pro — $29.99/شهر

**كل شي في Core، زائد**:

🌟 كابتن حمّودي بـ Gemini 3.1 Pro (نموذج reasoning — ردود أعمق وأكثر تحليلاً)
🌟 ذاكرة الكابتن الموسّعة (٥٠٠ معلومة، ٧٠٠ token budget مقابل ٤٠٠)
🌟 My Vibe / DJ Hamoudi (تكامل Spotify بتوصيات playlist بيومترية)
🌟 Legendary Challenges — وصول كامل (بدء، تتبّع، مراجعات أسبوعية)
🌟 إنشاء Tribe (يقدر يخلق ويملك قبيلة)
🌟 كل ميزات Core مشمولة

---

## 2. التيير المجاني (بعد الـ Trial، بدون اشتراك)

بعد ما الـ trial ٧ أيام تنتهي والمستخدم ما يشترك:

### شنو يقدر يسوّي؟
- يفتح التطبيق
- يشوف الشاشة الرئيسية بالمقاييس اليومية (خطوات، سعرات، ...)
- يشوف Daily Aura
- يشوف ملفه الشخصي ومستواه
- يستلم إشعار التقرير الأسبوعي يوم الأحد

### شنو مغلق؟
- ❌ كابتن حمّودي chat
- ❌ صوت الكابتن
- ❌ تحليل النوم وSmart Wake
- ❌ المطبخ (ماسح الثلاجة، خطط الوجبات)
- ❌ الجيم (خطط التمرين، Zone 2، الجلسات الحية)
- ❌ My Vibe
- ❌ Legendary Challenges
- ❌ Quests
- ❌ كل الإشعارات إلا التقرير الأسبوعي الأحد
- ❌ المشاركة في القبيلة

> الحالة المغلقة تُفرض عبر `AccessManager.shared` اللي يفحص `activeTier`. لما `activeTier == .none`، خصائص feature gate ترجع false، والـ UI يعرض paywall.

---

## 3. التجربة المجانية ٧ أيام

### 3.1 الميكانيكية

| البند | التفصيل |
|------|---------|
| **المدة** | ٧ أيام من لحظة إكمال الـ Onboarding (تحديداً، لما خطوة Legacy Calculation تخلص) |
| **الميزات** | كل ميزات Intelligence Pro مفتوحة. المستخدم يجرب أحسن نسخة من AiQo |
| **بدون فلوس** | الـ trial ما يحتاج credit card. **مو** StoreKit free trial — هي عدّاد مستقل يديره `FreeTrialManager` |
| **حفظ تاريخ البدء** | يُخزَّن في **اثنين**: UserDefaults و Keychain. Keychain entry يتجاوز إعادة التثبيت — يمنع إعادة الـ trial |
| **trial واحد لكل Apple ID** | يُفرض عبر Keychain + StoreKit `Transaction.currentEntitlements` |

### 3.2 سلوك الكابتن خلال الـ trial

| اليوم | السلوك | الإشعارات |
|------|--------|----------|
| **١** | تحية ترحيب. لمسة خفيفة. يسأل عن الأهداف | ١ كحد أقصى (welcome مساء ١٩:٣٠ إذا الخطوات > ٠) |
| **٢** | الموجزات الصباحية تبدأ. يشير لبيانات HealthKit | ٢ كحد أقصى يومياً |
| **٣** | كشف ميزة: Smart Wake (مُشغَّل ببيانات النوم) | المشغّلات الديناميكية تبدأ |
| **٤** | كشف ميزة: المطبخ (مُشغَّل عضوياً) | حتى ٣ يومياً |
| **٥** | كشف ميزة: Zone 2 | حتى ٣ يومياً |
| **٦** | تفاعل أعمق. يشير لمعلومات متذكَّرة | إشعار preview للـ paywall في ٢٠:٠٠ |
| **٧** | الملخص الأسبوعي يُولَّد. أول تقرير ذاكرة أسبوعي | إشعار recap في ١٨:٠٠ |

### 3.3 السلوك بعد الـ trial
- ٩٠٪ من الإشعارات تتوقف فوراً
- إشعار التقرير الأسبوعي الأحد يستمر **بدون نهاية** للمستخدمين غير المشتركين (re-engagement)
- chat الكابتن وكل ميزات الـ premium مغلقة خلف الـ paywall
- الـ paywall يعرض رسائل سياقية حسب المصدر (feature gate، يوم ٦ preview، انتهاء الـ trial، إلخ.)

### 3.4 المشغّلات الديناميكية للإشعارات خلال الـ trial

| المشغّل | الشرط | فترة التهدئة |
|---------|------|---------------|
| **قفزة سرعة** | سرعة المشي > ٥.٥ كم/س لـ ٣ دقائق | ٩٠ دقيقة |
| **اقتراب هدف الخطوات** | ≥ ٨٠٪ من الهدف، بعد ٥ م | ٩٠ دقيقة |
| **فجوة خمول** | ٣ ساعات+ بدون خطوات، بين ٩ ص – ٦ م | ٩٠ دقيقة |
| **اكتشاف تمرين** | إكمال تمرين في HealthKit | ٩٠ دقيقة |
| **اكتشاف ركض** | تمرين running-type | ٩٠ دقيقة |

---

## 4. التيير السنوي (Annual)

**الحالة**: مخطّط بعد إطلاق AUE (ماي ٢٠٢٦)، **لم يُنفَّذ بعد**.

**الأسعار المستهدفة** (غير نهائية):
- **Core Annual**: ~$59/سنة (تخفيض ~٥٠٪ مقابل الشهري)
- **Intelligence Pro Annual**: ~$119/سنة (تخفيض ~٦٥٪ مقابل الشهري)

---

## 5. التحقق من الإيصالات (Receipt Validation)

### 5.1 Client-side (الأساسي)
StoreKit 2 `Transaction` verification = **مصدر الحقيقة** للـ entitlements.
- التطبيق يفحص `Transaction.currentEntitlements`
- يبحث عن transactions صالحة وغير ملغاة
- مدة الاشتراك ٣٠ يوم لكل دورة، تُحسب يدوياً وتتراكم إذا المستخدم جدّد قبل الانتهاء

### 5.2 Server-side (ثانوي، non-blocking)
**Supabase Edge Function** اسمها `validate-receipt` تتحقق من الإيصالات للـ analytics وكشف الاحتيال.
- تستلم: `transactionId`, `productId`, تواريخ الشراء
- **فشل التحقق ما يلغي** entitlements محلياً — الـ client يثق بـ StoreKit الخاص به
- التحقق على الخادم موجود **للـ telemetry**، مو للتنفيذ

---

## 6. خطة الإطلاق

### 6.1 الإطلاق المستهدف: ماي ٢٠٢٦ في AUE

**الجامعة الأمريكية بالإمارات (AUE)** في دبي = ساحة الإطلاق.
**الاستراتيجية**: campus-first — بناء قاعدة مستخدمين مركّزة بـ feedback مباشر، ثم التوسّع.

### 6.2 مراحل الإطلاق

#### المرحلة ١: ما قبل الإطلاق (الآن)
- إكمال التطوير
- تجهيز App Store listing
- تنفيذ استراتيجية ١٢ post على Instagram على @aiqoapp:
  - كشف الـ brand
  - teasers ميزات
  - social proof
  - يوم الإطلاق

#### المرحلة ٢: الإطلاق الجامعي (ماي ٢٠٢٦)
- النشر في AUE
- عروض شخصية في الموقع
- word-of-mouth بين الطلاب
- جمع feedback مباشر

#### المرحلة ٣: ما بعد الجامعة (يونيو ٢٠٢٦+)
- تسويق UAE الأوسع بناءً على دليل الحملة الجامعية
- تفكير في التوسّع لدول الخليج

### 6.3 استراتيجية Instagram

**١٢ post مخطّطة**، تشمل:
- كشف هوية الـ brand (من هو AiQo، من هو كابتن حمّودي)
- teasers للميزات (chat الكابتن، النوم، المطبخ، Zone 2، My Vibe)
- social proof (ردود beta users، شهادات جامعية)
- countdown + إعلان توفّر يوم الإطلاق

---

## 7. فلسفة التسعير

AiQo موضوع كـ **premium-but-accessible** في سوق تطبيقات اللياقة:

| التطبيق | السعر الشهري | شنو تحصل |
|---------|--------------|----------|
| **Whoop** | $30/mo | hardware + analytics بيانات، **بدون** AI coaching |
| **Strava Premium** | $12/mo | لياقة اجتماعية، تخطيط مسارات، **بدون** AI |
| **MyFitnessPal Premium** | $20/mo | حساب سعرات، logging أكل، **بدون** AI coaching |
| **🟢 AiQo Core** | **$9.99/mo** | **AI coach، خطط وجبات، خطط تمارين، تحليل نوم، تتبع كامل** |
| **🟡 AiQo Intelligence Pro** | **$29.99/mo** | **كل شي + نموذج AI متقدّم، تكامل Spotify، Legendary Challenges** |

**Core** يضرب أسعار معظم المنافسين بينما يعطي تجربة AI-powered.
**Intelligence Pro** premium بس مبرَّر بنموذج Gemini المتقدّم، الذاكرة الموسّعة، وميزات فريدة مثل DJ Hamoudi و Peaks.

---

## 8. شنو AiQo "أبداً" ما يسوّي للربح

- ❌ **No ads** — أبداً ما يعرض إعلانات. الاشتراك = الدخل الوحيد
- ❌ **No selling user data** — البيانات الصحية تبقى على الجهاز أو في حساب Supabase الخاص بالمستخدم. أبداً ما تُباع، ما تُشارَك، ما تُستثمر
- ❌ **No dark patterns** — لا "عرض محدود الوقت" countdowns، لا scarcity مزيّف، لا فخاخ auto-renewal مخفية. الـ paywall شفاف
- ❌ **No fake urgency** — الـ trial ينتهي طبيعي. إشعار يوم ٦ معلوماتي، **ليس ضاغط**
- ❌ **No supplements or affiliate products** — AiQo منتج برمجي. **أبداً** ما يبيع منتجات مادية أو يكسب عمولات affiliate
- ❌ **No pay-to-win in social features** — طاقة Tribe و leaderboards مبنية على النشاط، **مو** الإنفاق

---

## 9. استراتيجية التحويل (Conversion)

قمع الـ trial-to-paid يعتمد على ٣ مبادئ:

### 9.1 إثبات القيمة قبل طلب الفلوس
الـ ٧ أيام trial تعطي وصول كامل لـ Intelligence Pro. المستخدم يجرّب:
- بناء ذاكرة الكابتن
- coaching شخصي
- تحليل نوم
- خطط وجبات
- تكامل Spotify

كل هذا **قبل** ما يشوف paywall. باليوم ٧، الكابتن يعرف اسمه، أهدافه، إصاباته، عاداته.

### 9.2 البيانات الشخصية تخلق switching cost
كل ما طوّل المستخدم بالتطبيق، الكابتن يتذكّر أكثر. بعد ٧ أيام، الكابتن خزّن:
- تفضيلات التمرين
- احتياجات غذائية
- أنماط النوم
- تاريخ الإصابات

البدء من الصفر مع تطبيق عام = فقدان هذي المعرفة الشخصية. **هذا مو lock-in** — المستخدم يقدر يصدّر بياناته — بس هي **حصن طبيعي**.

### 9.3 كابتن حمّودي = علاقة، مو ميزة
المستخدمين **ما يلغون** صديق. بإعطاء الكابتن شخصية ثابتة، لهجة، ذاكرة، وصوت، AiQo يخلق رابط عاطفي ما تقدر تطبيقات اللياقة العامة توفّره. الكابتن **ما يقدر يُستبدل** بـ AI تطبيق ثاني — هو شخصية محدّدة المستخدم بنى تاريخ معاها.

---

## 10. حماية الـ IP

| البند | الحالة |
|------|--------|
| **علامة UAE التجارية** | مُقدَّمة عبر وزارة الاقتصاد لاسم وشعار "AiQo" |
| **حقوق التأليف** | الكود والتصميم محفوظة لمحمد |
| **براءات اختراع محتملة** | ميزات جديدة تحت النظر للتسجيل |

### الميزات المرشحة لبراءات:
1. **Hybrid brain routing architecture** (على الجهاز + سحابة مع PrivacySanitizer)
2. **PrivacySanitizer pattern** (PII redaction قبل cloud AI inference)
3. **My Vibe biometric playlist control** (نبض القلب + مزاج → توصيات Spotify)
4. **Circadian tone adaptation** (تكيف نبرة AI حسب bio-phase)

---

# الجزء الثاني: الهوية البصرية والـ Brand

## 11. ألوان الـ Brand

### 11.1 اللوحة الأساسية

| الاسم | Hex | الاستخدام |
|------|-----|----------|
| **Mint (الأساسي)** | `#C4F0DB` | بطاقات الـ action الأساسية، خلفيات بطاقات المقاييس (خطوات، سعرات، وقوف، مسافة)، فقاعات chat المستخدم، accent المطبخ |
| **Mint (أعمق)** | `#CDF4E4` | brand mint (`AiQoColors.mint`)، خلفيات |
| **Accent (Sand/Gold)** | `#F8D6A3` | فقاعات chat الكابتن، gold highlights، خلفيات بطاقات المقاييس (ماي، نوم)، beige accent |
| **Accent (Gold أعمق)** | `#EBCF97` | quick reply chips، توهّج Intelligence Pro، accent paywall |
| **AiQo Accent (Lemon)** | `#FFE68C` | accent tab bar، system tint |
| **Beige** | `#FADEB3` | خلفيات دافئة ناعمة، accent بيج |

### 11.2 الألوان الدلالية (Light / Dark Adaptive)

| Token | Light | Dark | الاستخدام |
|-------|-------|------|----------|
| `primaryBackground` | `#F5F7FB` | `#0B1016` | خلفية التطبيق |
| `surface` | white | `#121922` | سطح البطاقة |
| `surfaceSecondary` | `#EEF2F7` | `#18212B` | سطح بطاقة متداخلة |
| `textPrimary` | `#0F1721` | `#F6F8FB` | عناوين، نص أساسي |
| `textSecondary` | `#5F6F80` | `#A3AFBC` | عناوين فرعية، captions |
| `accent` | `#5ECDB7` | `#8AE3D1` | عناصر تفاعلية، CTA gradient |
| `border` | black 8% | white 8% | حدود لطيفة |

### 11.3 ألوان فقاعات chat الكابتن
- **فقاعة المستخدم**: mint (`#C4F0DB`) بزوايا غير متماثلة (مدوّرة فوق + الجوانب، ضيقة bottom-trailing)
- **فقاعة الكابتن**: sand (`#F8D6A3`) بزوايا غير متماثلة (مدوّرة فوق + الجوانب، ضيقة bottom-leading)

### 11.4 كيف تُستخدم الألوان

- 🟢 **Mint** للأكشنات الأساسية، مقاييس الصحة، مؤشرات التقدم، جانب المستخدم في المحادثة
- 🟡 **Sand/Gold** لردود الكابتن، الإنجازات، اللحظات premium، التركيز الدافئ
- 🤍 **الخلفية ناعمة وفاتحة** — أبداً white خالص. Light mode: `#F5F7FB`. Dark mode: `#0B1016`
- ⚫ **النص أسود قوي للأساسي**، رمادي مكتوم للثانوي. ما اكو نص ملوّن إلا في badges وعناصر accent

---

## 12. التايبوغرافي

| البند | التفصيل |
|------|---------|
| **عائلة الخط** | **SF Pro Rounded** على كل التطبيق. ما اكو خطوط مخصّصة |
| **عناوين الشاشات** | `.title2` rounded bold |
| **عناوين الأقسام / البطاقات** | `.headline` rounded semibold |
| **نص الـ body** | `.subheadline` rounded |
| **Captions** | `.caption` rounded |
| **أزرار CTA** | `.headline` rounded semibold |
| **الكتابة العربية** | يُعالجها النظام أصلياً. SF Pro Rounded يدعم glyphs العربية. ما اكو ملفات خط عربي مخصّصة |
| **RTL-first** | لما اللغة عربية، `layoutDirection` = `.rightToLeft` يُطبَّق على مستوى الـ root view |

---

## 13. اللغة البصرية

### 13.1 البطاقات
- **Glassmorphism**: البطاقات تستخدم `.ultraThinMaterial` لتأثير frosted-glass
- **زوايا مدوّرة**: ١٦pt قياسي للبطاقات، ١٢pt للـ chips والعناصر الصغيرة، ٢٤pt لبطاقات hero و CTA containers، ٢٨pt للـ sheets
- **بدون drop shadows**: الارتفاع يُنقَل عبر material blur، **مو** ظل. هذا يبقي UI نظيف ومودرن
- **بدون gradients** إلا:
  - تدرّجات vertical خفيفة على الخلفيات
  - دوائر accent paywall hero (teal, gold, mint blurs)
  - توصية Smart Wake المميّزة (gradient أخضر-أزرق-بنفسجي)
  - خلفية mesh gradient لشاشة الكابتن (iOS 18+)

### 13.2 المسافات (Spacing)

| Token | القيمة | الاستخدام |
|-------|--------|----------|
| `xs` | 8pt | spacing ضيّق، عناصر inline |
| `sm` | 12pt | padding داخلي للبطاقة |
| `md` | 16pt | spacing قياسي للبطاقات |
| `lg` | 24pt | spacing الأقسام |

### 13.3 الـ Animation

- **Spring animations** على كل التطبيق: `.spring(response: 0.35, dampingFraction: 0.8)` هو القياسي
- **Quick reply chips**: `.spring(response: 0.28, dampingFraction: 0.86)`
- **تأثير ضغط البطاقة**: `.spring(response: 0.28, dampingFraction: 0.78)`
- **احتفال رفع المستوى**: full-screen overlay مع opacity transition
- **Daily Aura**: نقطة تنفس (٢.٤s repeat)، ملء قوس متراص (١.٢s easeInOut لكل قطعة)
- **بطاقات وصفات المطبخ**: animation عائم (1.2pt Y offset، 0.45 درجة دوران، 2.4s repeat)
- **مؤشّر كتابة الكابتن**: ٣ نقاط نطاطة، 0.18s stagger، 0.7s easeInOut
- **مكوّنات Apple الأصلية مفضّلة** على تقليدات مخصّصة

### 13.4 المبادئ العامة

- **مساحة بيضاء سخيّة**: التطبيق يتنفس. الشاشات مو محشورة
- **زخرفة خفيفة**: borders أقل، أيقونات أقل، نص و material أكثر
- **نقطة تركيز واحدة لكل شاشة**: كل شاشة فيها عنصر أساسي يجذب العين
- **Haptic feedback**: ردود لمسية عند تغيير الـ tab، ضربة خفيفة عند ١٠٠٪ هدف، تنبيه نجاح عند رفع المستوى

---

## 14. الأيقونات (Iconography)

- **SF Symbols** على كل التطبيق — ما اكو مجموعة أيقونات مخصّصة
- **أيقونات شائعة**:
  - `house.fill` (الرئيسية)
  - `figure.strengthtraining.traditional` (الجيم)
  - `wand.and.stars` (الكابتن)
  - `moon.zzz.fill` (النوم)
  - `fork.knife.circle.fill` (المطبخ)
  - `drop.fill` (الماي)
  - `flame.fill` (السعرات)
  - `figure.walk` (الخطوات)
- **Emoji** يُستخدم بحذر داخل البطاقات للدفء — حد أقصى emoji واحد لكل بطاقة
- **بدون emoji** في navigation، headers، أو عناصر النظام

---

## 15. شنو التصميم "مو"؟

- ❌ **مو صاخب**: لا ألوان neon، لا تباين عدواني، لا animations جذّابة-للانتباه
- ❌ **مو gradient-heavy**: gradients نادرة وخفيفة، **أبداً** عنصر بصري أساسي
- ❌ **مو طفولي**: زوايا مدوّرة ودفء **ما تعني** كرتوني. التصميم بالغ ومدروس
- ❌ **مو aesthetic لياقة غربية**: لا خلفيات داكنة بـ neon green، لا typography عدواني، لا طاقة "BEAST MODE"
- ❌ **مو مزدحم**: كل شاشة فيها هرمية واضحة و breathing room
- ❌ **مو "data dashboard"**: الأرقام موجودة بس تُعرض حوارياً، **مو** في grid dashboards
- ❌ **مو dark-mode-first**: Light mode هو التجربة الأساسية. Dark مدعوم بس ثانوي

---

## 16. الهوية اللفظية (Verbal Identity)

### 16.1 العربية

#### لهجة كابتن حمّودي
عربية عراقية / خليجية لكل تفاعلات الكابتن. شوف الملف ٣ (كابتن حمّودي) للدليل الكامل.

#### labels النظام والـ navigation
**العربية الفصحى المعاصرة** مقبولة لـ UI labels، نص الأزرار، عناصر navigation. اللهجة محفوظة لشخصية الكابتن؛ chrome النظام يحجي عربي قياسي للوضوح.

#### مبادئ النبرة
- **عفوية ودافئة**: **أبداً** رسمية. **أبداً** بيروقراطية
- **أبداً عبارات دينية بدون مبادرة**: لا "إن شاء الله"، "ماشاء الله"، "الحمد لله" إلا إذا المستخدم بدأ
- **أبداً افتراضات جنسانية**: الإشعارات ونسخة النظام تتجنّب افتراض الجنس. لما الجنس يهم (نحوياً)، يُقرأ من تفضيل المستخدم المخزَّن

### 16.2 الإنجليزية (fallback)

- محادثاتي، second-person ("you")
- جمل قصيرة. **بدون** جمل مركّبة لما البسيط يكفي
- **بدون** كلمات تسويقية: أبداً "powerful"، "revolutionary"، "cutting-edge"، "game-changing"، "seamless"
- مباشر وصادق. "Your sleep was short" مو "We noticed your sleep metrics indicate suboptimal duration"

---

## 17. مفهوم App Icon

- خلفية mint/teal
- شخصية sand/gold توحي بـ brain + bicep (ذكاء + لياقة)
- إشباع زائد + خطوط أعمق للظهور على شاشات home مزدحمة
- نظيف، يُتعرَّف عليه في أحجام صغيرة

---

## 18. عيّنات نسخة عربية (نصوص فعلية في التطبيق)

| السياق | العربية | الترجمة |
|--------|---------|---------|
| Tab: Home | الرئيسية | Home |
| Tab: Gym | الجيم | Gym |
| Tab: Captain | الكابتن | Captain |
| Captain welcome | هلا! أنا كابتن حمّودي. شنو هدفك اليوم؟ | Hello! I'm Captain Hamoudi. What's your goal today? |
| Captain status | يفكر هسه | Thinking now |
| Captain ready | جاهز | Ready |
| Chat placeholder | اكتب رسالتك للكابتن... | Write your message to the Captain... |
| Workout card | خطة التمرين جاهزة | Workout plan ready |
| Memory title | ذاكرة الكابتن | Captain's Memory |
| Chat history | المحادثات | Conversations |
| New chat | محادثة جديدة | New conversation |
| Water reminder | جسمك يحتاج ماء — اشرب كوب الحين | Your body needs water — drink a cup now |
| Sleep reminder | النوم أهم من التمرين! تصبح على خير | Sleep is more important than exercise! Good night |
| Streak alert | لسه ما حققت هدفك اليوم! | You haven't hit today's goal yet! |
| Trial pill | ٧ أيام مجانية | 7 free days |
| Paywall headline | اكتشف قدراتك الحقيقية مع AiQo | Discover your true potential with AiQo |

---

## 19. كيف AI ثاني يكتب محتوى لـ AiQo؟

### حدود الطول
- **إشعارات**: تحت ٨٠ حرف للعنوان، تحت ١٦٠ حرف للـ body
- **ردود chat الكابتن**: تحت ٢٨٠ حرف للردود العامة، حتى ٤ جمل لتحليل النوم
- **Quick reply chips**: تحت ٢٥ حرف لكل واحد، حد أقصى ٣ chips
- **نسخة marketing**: تحت ١٤٠ حرف لكل سطر للسوشيال

### الكلمات الممنوعة
**أبداً** ما تستخدم في أي محتوى AiQo:
- "powerful"، "revolutionary"، "cutting-edge"، "game-changing"، "seamless"، "world-class"
- "leverage"، "synergy"، "paradigm"، "ecosystem" (jargon تقني)
- "بالتأكيد"، "بكل سرور"، "يسعدني مساعدتك" (عبارات الكابتن الممنوعة)
- "As an AI"، "I'm an artificial intelligence" (يكسر الشخصية)

### الـ Register المطلوب
- دافئ، مراقب، **أبداً** ضاغط
- موجَّه للأكشن: كل رسالة تختم بشي يقدر المستخدم يسوّيه
- محدّد، مو عام: يشير لبيانات المستخدم الفعلية، أهدافه، أو سياقه
- لهجة عراقية/خليجية للكابتن، فصحى لـ UI النظام، إنجليزي محادثاتي للوضع الإنجليزي

### متى تستخدم إنجليزي مقابل عربي؟
- **العربية افتراضية** لكل المحتوى الموجَّه للمستخدم
- **الإنجليزية تُستخدم لما**: لغة التطبيق إنجليزي، أو لما المحتوى ثنائي اللغة (التقارير الأسبوعية تشمل ملخصات عربي + إنجليزي)
- **أسماء ميزات** مثل "My Vibe"، "Zone 2"، "Alchemy Kitchen"، "Arena"، "Tribe" تبقى بالإنجليزي حتى في السياقات العربية (هي brand names)

---

# الجزء الثالث: خريطة الطريق

## 20. شنو شُحن (Working in Current Build)

### نظام كابتن حمّودي
✅ chat كامل بأفاتار RealityKit ثلاثي الأبعاد (idle animation)
✅ معمارية الدماغ الهجين: Apple Intelligence + Gemini سحابي
✅ نظام prompt من ٧ طبقات مع تكيّف نبرة circadian
✅ نظام ذاكرة بـ rule-based + LLM extraction (حدود ٢٠٠/٥٠٠ حسب التيير)
✅ PrivacySanitizer لكل البيانات السحابية
✅ ElevenLabs TTS مع ١٣ عبارة عربية مخزّنة مسبقاً
✅ AVSpeechSynthesizer fallback
✅ تخزين تاريخ chat بتجميع جلسات
✅ pipeline معرفي: كشف intent، تحليل إشارات عاطفية، استرجاع ذاكرة
✅ توجيه BrainOrchestrator (محلي للنوم، سحابي للباقي)
✅ سلسلة fallback: سحابي → محلي → حتمي

### معمارية النوم
✅ Smart Wake calculator مع محرك دورات ٩٠ دقيقة
✅ وضعين: من bedtime، من wake time
✅ اختيار wake window (١٠/٢٠/٣٠ دقيقة)
✅ تسجيل ثقة بـ labels عربية
✅ حفظ منبّه AlarmKit (iOS 26.1+)
✅ تحليل مراحل نوم على الجهاز عبر Apple Intelligence
✅ موجز نوم صباحي من الكابتن
✅ مراقب جلسة نوم (HealthKit في الخلفية)

### المطبخ السحري
✅ ماسح ثلاجة بكاميرا مع AI لكشف المكونات
✅ مخزون ثلاجة دائم بتتبّع الكميات
✅ توليد خطة وجبات (٣ أو ٧ أيام) باستخدام عناصر الثلاجة
✅ فحص توفّر المكونات (متوفر/منخفض/ناقص)
✅ قائمة تسوق مع auto-populate للمكونات الناقصة
✅ اقتراحات استبدال مكونات
✅ تفصيل ماكروز كامل لكل وجبة
✅ Kitchen scene بخلفية كابتن حمّودي مرسومة

### الجيم والتمارين
✅ خطط تمارين توليدية من الكابتن
✅ شاشة جلسة تمرين حية (مؤقّت، نبض، سعرات، مسافة)
✅ Zone 2 hands-free voice coaching (Speech Recognition + TTS)
✅ تتبّع تمرين Apple Watch
✅ Siri Shortcuts لبدء تمارين بصوت
✅ ملخص تمرين مع تعليق الكابتن
✅ تكامل Spotify لـ playlists التمرين
✅ Live Activity لجلسات التمرين

### XP والمستويات
✅ منحنى XP exponential
✅ ٨ تيرز دروع
✅ animation احتفال + هابتيك
✅ مزامنة XP لـ Supabase

### نظام Streak
✅ تتبّع نشاط يومي
✅ streak الحالي، الأطول، اتساق أسبوعي
✅ تاريخ ٩٠ يوم
✅ رسائل تحفيز عربية حسب التيير

### نظام Quest
✅ QuestKit مع quests يومية
✅ تخزين SwiftData
✅ تعريفات + محرك تقييم

### الاشتراك والـ Trial
✅ تيرين اشتراك StoreKit 2 native
✅ ٧ أيام trial مع Keychain persistence
✅ Trial Journey Orchestrator: ١٤ نوع إشعار عبر ٧ أيام
✅ إشعارات diamond ديناميكية
✅ إشعار recap الأحد الأسبوعي
✅ paywall بـ glassmorphic dark UI
✅ تحقق إيصال Server-side عبر Supabase Edge Function
✅ إشعارات انتهاء premium (يومين، يوم، انتهى)
✅ Feature gating عبر AccessManager
✅ Legendary Challenge paywall gate

### التوحيد الأسبوعي للذاكرة
✅ buffers HealthKit يومية
✅ توحيد أسبوعي في تقارير دائمة
✅ ملخصات ثنائية اللغة
✅ ملخصات أسبوعية ظاهرة في إعدادات ذاكرة الكابتن

### Apple Watch
✅ شاشة home بملخص يومي
✅ اختيار نوع تمرين (٧ أنواع، indoor/outdoor)
✅ شاشة تمرين حي بمقاييس
✅ شاشة ملخص تمرين
✅ مزامنة WatchConnectivity
✅ App group مشترك

### Profile والإعدادات
✅ إعداد ملف شخصي
✅ إعدادات تخصيص الكابتن
✅ عرض إدارة ذاكرة الكابتن
✅ اختيار اللغة
✅ Toggle إشعارات
✅ شاشة إعدادات
✅ لوحة تطوير (DEBUG فقط)

### Onboarding
✅ اختيار اللغة
✅ Sign in with Apple + guest
✅ إعداد ملف شخصي
✅ Legacy calculation (HealthKit sync)
✅ تخصيص الكابتن
✅ جولة معرفة بالميزات

### البيانات والـ Analytics
✅ analytics محلية (console + JSONL مع ٥٠+ نوع event)
✅ تصدير HealthKit
✅ Progress photos (مجلد الميزة موجود)
✅ تاريخ Daily Aura ١٤ يوم

---

## 21. شنو شُحن جزئياً (مكتمل بس مخفي/ناقص)

### Tribe (القبيلة / الإمارة)
- **الحالة**: مُجمّعة، تشتغل ببيانات demo محلية، **مخفية** خلف ٣ feature flags (كلها false)
- **شنو يشتغل**: إنشاء، انضمام بكود، قائمة أعضاء، مساهمات طاقة، تبادل sparks، تتبّع mission، event log، تحديات Arena، عرض Galaxy
- **شنو ناقص**: تكامل Supabase backend live (٥ TODOs متبقّية في `TribeExperienceFlow.swift`)
- **يعطّل**: تنفيذ + اختبار الـ backend قبل تفعيل الـ flags

### Firebase Crashlytics
- **الحالة**: wrapper موجود (`CrashReportingService.swift`) بس Firebase SDK غير مرتبط في Xcode project
- **fallback نشط**: تسجيل JSONL محلي للـ crash/error

### HRR Assessment
- ميزة موجودة في الكود (`HRRWorkoutManager`، `FitnessAssessmentView`)
- مغلقة خلف Core tier
- شغّالة بس قد تحتاج اختبار إضافي

### Progress Photos
- مجلد ميزة موجود (`Features/ProgressPhotos/`)
- ❓ غير معروف — يحتاج فحص للاكتمال

### أفاتار 3D للكابتن
- عرض RealityKit أساسي يشتغل (model اسمه "my" بـ idle animation)
- **مخطّط V1**: idle animation كامل + صوت مخصّص
- **مخطّط V2**: lip sync + حركة تعبيرية
- **الحالة الحالية**: animation تنفس/هزّة أساسي فقط

---

## 22. مخطّط لما بعد إطلاق AUE

### Near-term (يونيو – أغسطس ٢٠٢٦)
- ✅ تيير اشتراك سنوي: ~$59/سنة Core، ~$119/سنة Pro
- ✅ Analytics عن بُعد: تكامل Mixpanel/PostHog/Amplitude
- ✅ Firebase Crashlytics: ربط SDK، تفعيل تقارير crash
- ✅ Tribe backend: إكمال تكامل Supabase، تفعيل feature flags

### Medium-term (٢٠٢٦ Q3-Q4)
- ✅ Fish Speech S1-mini: TTS مُستضاف ذاتياً متخصّص على صوت محمد، يحل محل ElevenLabs
- ✅ RunPod Serverless: استضافة GPU inference
- ✅ أفاتار 3D للكابتن V1: idle animation + صوت مخصّص
- ✅ توسّع UAE الأوسع: مبني على دليل الحملة الجامعية

### Long-term (٢٠٢٧+)
- ✅ أفاتار 3D للكابتن V2: lip sync + حركة تعبيرية
- ✅ Avatar builder / تخصيص شخصية
- ✅ توسّع دول الخليج: السعودية، الكويت، قطر، البحرين، عمان
- ❓ نسخة Android: محتمل، **ما اكو خطط حالية**
- ✅ تنهية IP: تسجيل علامة تجارية، تقديم براءات محتملة

---

## 23. القرارات المُقفلة (لا يُعاد فتحها)

هذي القرارات نهائية. AI ما يلزم يشكّك بها:

1. **تيرين، مو ثلاثة**: بعد التفكير في هيكل ٣ تيرز، محمد استقر على Core + Intelligence Pro
2. **Legendary Challenges مشاهدة فقط لـ Core**: Core users يقدرون يصفّحون التحديات بس بدء واحد يطلق paywall
3. **عراقي بدلاً من فصحى**: الكابتن يحجي عراقي/خليجي حصراً في الوضع العربي
4. **كل شي Apple-native**: لا React Native، لا Flutter، لا cross-platform
5. **ما اكو fake/mock data في الميزات الاجتماعية**: القبائل تستخدم demo محلي خلال التطوير، **ما تعرض** أعضاء وهميين أو نشاط مزيّف للمستخدمين الحقيقيين
6. **VersionedSchema لـ migration ذاكرة الكابتن**: SwiftData VersionedSchema (V1 → V2)
7. **MorningHabitOrchestrator موقوف خلال الـ trial**: Trial Journey Orchestrator يملك كل إشعارات الصباح خلال الـ ٧ أيام
8. **إشعار الأحد الأسبوعي يستمر بعد الـ trial**: إشعار واحد كل أحد ١٨:٠٠ — touchpoint أدنى لـ re-engagement
9. **سعر Intelligence Pro fallback $29.99**: الـ codebase يعرض `intelligenceProFallbackPrice = "$29.99"`

---

## 24. القرارات المفتوحة (مواضيع نقاش جيدة)

- ❓ **تسعير الاشتراك السنوي**: الأسعار الدقيقة للخطط السنوية غير نهائية
- ❓ **إذا تيير ثالث يُضاف لاحقاً**: محتمل "Lite" أو "Pro" بين Core و Intelligence Pro
- ❓ **جدول توسّع دول الخليج**
- ❓ **جدول تدريب صوت Fish Speech**: يعتمد على توفر RunPod GPU وجودة عينات الصوت
- ❓ **مزوّد analytics عن بُعد**: Mixpanel vs. PostHog vs. Amplitude — غير مقرّر
- ❓ **Tribe monetization**: إذا يُغلق خلف تيير معين أو يبقى متاح لكل المشتركين
- ❓ **جدول Android**: **ما اكو خطط حالية** بس مو مستبعد لـ ٢٠٢٧+

---

## 25. كيف AI يلزم يتعامل مع المشروع

لما محمد يسأل AI عن AiQo:

1. **افتراضياً Apple-native**: SwiftUI، SwiftData، HealthKit، StoreKit 2، Apple Intelligence. **أبداً** ما يقترح React Native، Flutter، Firebase Realtime Database، أو مكتبات subscription management خارجية
2. **احترم نموذج التيرين الموجود**: لا تقترح إضافة tiers، تغيير أسعار، أو إعادة هيكلة monetization بدون طلب
3. **أبداً اقتراحات hype أو dark patterns**: لا "limited time offer"، لا scarcity مزيّف، لا free trial mechanics مضلّلة، لا upselling عدواني
4. **دائماً افحص إذا الميزة موجودة**: AiQo فيه ٤٢٣ ملف Swift. قبل اقتراح ميزة جديدة، ابحث في الـ codebase الموجود
5. **التواصل الافتراضي**: لهجة عراقية مع مصطلحات تقنية إنجليزية مقبولة. محمد مرتاح بالاثنين بس المنتج يحجي عربي أولاً
6. **فكّر بقيود المطوّر الفردي**: محمد يبني هذا لحاله. كل اقتراح يلزم يفكر: هل شخص واحد يقدر ينفّذ هذا؟ هل يستحق الوقت؟ هل يحرّك المؤشّر لإطلاق AUE؟
7. **اضبط لـ deadline إطلاق AUE (ماي ٢٠٢٦)**: أي شي مو مطلوب للإطلاق يُؤجَّل
8. **شخصية كابتن حمّودي مقدّسة**: **أبداً** اقتراح جعل الكابتن عام، رسمي، أو إنجليزي-أولاً

---

## كيف تستخدم هذا الملف؟
- **اقرأه أخير** — يجمع نموذج الأعمال، الهوية البصرية، خريطة الطريق
- **مفيد لـ**: قرارات تسعير، marketing، تصميم بصري، تخطيط الإطلاق، فهم خريطة الطريق
- **شارِكه مع**: مستثمرين، شركاء تسويق، معلّقين، مصممين

---

# الخاتمة

هذا آخر ملف في الـ ٥ ملفات. لو قرأ احد الملفات الـ ٥ كلها، يكون عنده **فهم كامل ١٠٠٪** لـ AiQo:

| الملف | المحتوى |
|------|---------|
| **١. نظرة عامة** | شنو AiQo، المستخدم، الفلسفة |
| **٢. تجربة المستخدم** | الشاشات، الـ flows، الميزات |
| **٣. كابتن حمّودي** | الشخصية، الذاكرة، الـ AI |
| **٤. البنية التقنية** | الـ frameworks، الـ services، المعمارية |
| **٥. الأعمال والهوية** | التسعير، الـ branding، الـ roadmap |

**AiQo مبني فردياً في الإمارات** بواسطة محمد، يستهدف إطلاق ماي ٢٠٢٦ في AUE — مع رؤية لإعادة تعريف معنى "تطبيق الصحة" للناطقين بالعربية في الخليج.
