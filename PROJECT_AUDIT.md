# PROJECT_AUDIT — مراجعة قراءة فقط (Read-Only Audit)

- **التاريخ:** 2026-06-22
- **النوع:** مراجعة قراءة فقط — لم يُعدّل/يُحذف/يُنقل أي ملف، ولم يُعمل أي commit على ملفات موجودة. الملف الوحيد الجديد هو هذا الملف (`PROJECT_AUDIT.md`).
- **الفرع وقت المراجعة:** `claude/aiqo-phone-audit-3vkso6`
- **الأداة:** Claude Code (تشغيل أوامر فعلية: `git ls-files`, `git grep`, `wc -l`, `find`, `du`, `git log`).

---

## 0. الخلاصة التنفيذية (اقرأها أولاً)

> **النتيجة الأهم والصادقة:** هذا الـrepo **ليس** مشروع "AiQo Salam OS" (نظام الهاتف). هذا الـrepo هو **تطبيق AiQo الصحي على iOS بـSwiftUI** فقط، ومعه تطبيق Apple Watch وWidgets ودوال Supabase.

- **لا يوجد** أي كود لنظام هاتف، ولا GrapheneOS، ولا NASM، ولا سكربتات بناء/فلاش، ولا جدار ناري، ولا launcher، ولا أوضاع وصاية (كبير/طفل). صفر تطابق لكل كلمات نظام الهاتف داخل الكود.
- طلبك "افتح في الـDesktop ملف AiQo Salam OS" **غير قابل للتنفيذ هنا**: البيئة الحالية حاوية سحابية معزولة فيها هذا الـrepo فقط — **لا يوجد Desktop ولا ملف بهذا الاسم** لا في الـrepo ولا في نظام الملفات المتاح.
- كلمة "Operating System" الموجودة بالوثائق هي **استعارة تسويقية** ("Bio-Digital Operating System" / "نظام تشغيل للجسم والعقل")، وليست نظام تشغيل حقيقي للهاتف.
- ما هو حقيقي ومنفّذ فعلاً: **الكابتن حمّودي (RoQo/Hamoudi)** كنظام "Brain" ضخم بـSwift (≈21,480 سطر / 142 ملف)، وتطبيق صحي iOS ناضج (≈133,714 سطر Swift إجمالاً).

| البند | الواقع |
|------|--------|
| AiQo (تطبيق iOS صحي) | 🟢 موجود وناضج — **هو** محتوى هذا الـrepo |
| AiQo Salam OS (نظام هاتف GrapheneOS) | ⚪️ **غير موجود إطلاقاً** في هذا الـrepo |
| النظام القديم NASM من الصفر | ⚪️ **غير موجود** — لا أثر له هنا (لا ملفات `.asm/.s`، ولا ذكر في الكود) |

---

## 1. خريطة الـrepo الحقيقية

### الأرقام الكلية (من `git ls-files` — أي الملفات المتعقَّبة فعلاً)
- **إجمالي الملفات المتعقَّبة:** 949 ملف
- **إجمالي أسطر Swift:** **133,714** سطر

### عدد الملفات حسب الامتداد (أهمها)
| الامتداد | العدد | ملاحظة |
|---------|------|--------|
| `.swift` | 662 | كل الكود الفعلي للتطبيق |
| `.png` | 89 (+5) | أصول/صور |
| `.json` | 62 (+3) | أصول/إعدادات/ألوان |
| `.md` | 51 | وثائق (33 منها بالجذر) |
| `.h` | 31 | **30 منها رؤوس إطار Spotify الخارجي** + 1 فقط `AiQoCore.h` |
| `.ts` | 4 | دوال Supabase Edge (Deno) |
| `.m4a` | 5 | أصوات |
| `.plist`/`.entitlements`/`.strings`/`.storekit`/`.yml` | متفرقة | إعداد iOS وCI |

> **مهم:** الـ31 ملف `.h` ليست لغة C خاصة بالمشروع — 30 منها رؤوس SDK خارجي (Spotify). **لا يوجد NASM ولا C ولا Shell ولا Rust ولا C++ في الـrepo** (صفر ملفات `.asm/.s/.sh/.c/.cpp/.rs`).

### أحجام المجلدات الرئيسية (`du -sh`)
| المجلد | الحجم | المحتوى |
|--------|------|---------|
| `AiQo/` | 102M | الكود + الأصول (Assets الكبيرة) |
| `AiQoWatch Watch App/` | 6.1M | تطبيق الساعة (35 ملف Swift) |
| `AiQoWidget/` | 3.3M | الـwidgets (1,888 سطر) |
| `AiQoTests/` | 380K | 59 ملف اختبار (7,174 سطر) |
| `untitled folder/` | 216K | **وثائق فقط** (تقارير P-prompts، انظر §5) |
| `AiQo.xcodeproj/` | 144K | مشروع Xcode |
| `AiQoWatchWidget/` | 92K | widget الساعة |
| `Configuration/` | 76K | منها رموز Spotify الخارجية (dSYM) |
| `supabase/` | 48K | 4 دوال TS (335 سطر) + README |

### المتجاهَل عبر `.gitignore` (مذكور صراحة كما طلبت)
`.DS_Store`, `build/`, `DerivedData/`, **`Configuration/Secrets.xcconfig`** (مفاتيح API الحقيقية — لا تُلتزم)، `*.xcconfig.local`, `.env*`, `xcuserdata/`, `.build/`, `Packages/`, `.claude/worktrees/`، و**`/aiqo-web/`** (تطبيق ويب يعيش في repo منفصل — ليس هنا).

### أسطر Swift حسب المجلد الرئيسي
| المجلد | أسطر Swift |
|--------|-----------|
| `AiQo/Features` | 87,410 |
| `AiQo/Services` | 7,057 |
| `AiQoTests` | 7,174 |
| `AiQo/Core` | 6,748 |
| `AiQo/App` | 2,453 |
| `AiQoWidget` | 1,888 |
| `AiQo/UI` | 1,735 |
| `AiQo/Shared` | 1,265 |

---

## 2. هوية المشروع (بالدليل من الملفات لا من الوثائق)

### أ) AiQo — تطبيق iOS صحي بـSwiftUI → 🟢 **هو هذا الـrepo**
الدليل: 662 ملف Swift، مجلدات ميزات صحية كاملة (`Sleep`, `Gym`, `Cardio`, `Kitchen`, `SmartWaterTracking`, `Profile`, `Onboarding`, `Tribe`...)، تكامل HealthKit/HKWorkoutSession/StoreKit2، وثيقة `AiQo_AIContext_04_TechStack.md` تنصّ حرفياً: *"iOS only — no Android, no web app, no cross-platform"*. هذا تطبيق واحد لا repo منفصل — هو الـrepo نفسه.

### ب) AiQo Salam OS — نظام هاتف GrapheneOS (الأُفُق 1) → ⚪️ **غير موجود**
الدليل (سلبي وحاسم): `git grep` عن `graphene|salam os|nasm|pixel 9|bootloader|firewall|tor block|roqo|guardian mode|الجدار الناري|الوصاية|launcher` على كامل الكود = **صفر تطابق**. لا سكربتات إعداد/مزامنة/بناء/فلاش، لا scaffolding حتى. **لا شيء منه موجود فعلاً.**

### ج) النظام القديم NASM من الصفر → ⚪️ **غير موجود / لا أثر**
لا ملفات تجميع (`.asm/.s`)، ولا ذكر لـ"NASM" أو "من الصفر" أو "Linux-native" في أي ملف. **مصيره غير قابل للتحديد من هذا الـrepo** — لم يصبح "الأُفُق 2"، ولم يُترك هنا، ببساطة **ليس له وجود في هذا المستودع**. أي قول عن مصيره سيكون تخميناً، وهو **غير واضح**.

> الذكر الوحيد القريب من "الأنظمة/الأجهزة" في خارطة الطريق المستقبلية هو "نسخة Android — محتملة، بلا خطط حالية" (`AiQo_AIContext_07_RoadmapAndState.md`). لا ذكر إطلاقاً لنظام هاتف أو أُفُق 1/2.

---

## 3. حالة كل طبقة + تقييم النضج

### طبقات "نظام الهاتف" المطلوبة في مهمتك — كلها ⚪️ غير موجودة
| الطبقة | الحالة | الدليل |
|--------|:----:|--------|
| نظام البناء (GrapheneOS/Pixel 9)، سكربتات إعداد/مزامنة/فلاش | ⚪️ | صفر ملفات، صفر تطابق كلمات |
| نواة الحماية (فلتر دائم، DNS مُدار، جدار ناري، حجب Tor، سدّ التجاوز) | ⚪️ | صفر تطابق في الكود |
| الواجهة / launcher / ui-shell (لنظام هاتف) | ⚪️ | لا يوجد launcher؛ ما يوجد هو واجهات SwiftUI داخل تطبيق iOS |
| سياسة الجهاز + الوضعان (كبير/طفل) + الوصاية | ⚪️ | لا كود؛ صفر تطابق |

### الطبقات الموجودة فعلاً (لأن هذا تطبيق iOS) — تقييم صادق
| الطبقة | الحالة | أين / ملاحظة |
|--------|:----:|--------------|
| **الكابتن (RoQo / حمّودي)** | 🟢 منفّذ وكبير | `AiQo/Features/Captain/Brain/` — 142 ملف، 21,480 سطر، مهيكل بـ11 طبقة (`00_Foundation` → `10_Observability`): Sensing, Memory (38 ملف، SwiftData + فهرسة/embedding)، Reasoning، Inference (Gemini عبر `HybridBrainService`/`CloudBrainService`)، Privacy (`PrivacySanitizer`)، Proactive (26 ملف). نضج عالٍ نسبياً، مع اختبارات. |
| **التطبيق الصحي iOS** | 🟢 ناضج | 18+ مجلد ميزة، 87K سطر في `Features`، تكامل HealthKit/StoreKit/Watch. |
| **الواجهة / UI** | 🟢 | SwiftUI كامل (`AiQo/UI`, `Features/*/Views`, `Home`, `First screen`). |
| **سياسة الاشتراك/الطبقات + الأوضاع** | 🟢 (بمعنى الاشتراكات) | `SubscriptionTier.swift`, `TierGate.swift`, `AccessManager` — طبقتان (Core / Intelligence Pro). **ليست** وصاية جهاز كبير/طفل. |
| **خلفية Supabase (للكابتن)** | 🟡 جزئي | `supabase/functions/`: `captain-chat` (124 سطر)، `captain-voice` (118)، `_shared/auth` (76) + cors. بروكسي لـGemini/الصوت، صغير لكنه حقيقي. |
| **Tribe (القبيلة) + Crashlytics + Progress Photos + 3D Avatar** | 🟡 جزئي/مخفي | حسب الوثائق والكود: feature flags = false، Crashlytics wrapper موجود لكن SDK غير مربوط. |
| **تطبيق Apple Watch** | 🟢/🟡 | 35 ملف Swift، موجود ويعمل كمرافق. |

---

## 4. فجوة الوثائق مقابل الواقع (الأهم)

### تصحيح فرضيات المهمة نفسها
- **`PROGRESS.html`** المذكور في طلبك → ⚪️ **غير موجود** في الـrepo.
- **`OVERVIEW.md`** → غير موجود بهذا الاسم؛ الأقرب هو `AiQo_AIContext_01_ProductOverview.md`.
- لا توجد أي وثيقة تَعِد بنظام هاتف ثم لا تنفّذه — لأن **وثائق هذا الـrepo نفسها لا تَعِد بنظام هاتف**. الفجوة الكبرى ليست داخل الـrepo، بل **بين فرضية مهمتك (مشروع هاتف) والـrepo الفعلي (تطبيق صحي)**.

### ادعاءات بالوثائق تستحق التحقق (داخل سياق التطبيق الصحي)
- ادعاء "Bio-Digital Operating System" (في `AiQo_AIContext_01` و`Master_Blueprint_16`) → **استعارة** فقط؛ لا نظام تشغيل فعلي. ✅ تم توضيحه.
- ادعاءات "10 prompts done" في سجل العمل → تقرير `untitled folder/BRAIN_OS_AUDIT_2026-04-18.md` (تدقيق سابق بنفسه) يقول إن الواقع 3–4 فقط بسبب تفرّع/فقدان عمل بين الفروع ("silent regression"). أي **توثيق التقدّم نفسه كان مبالَغاً، واعترفت به مراجعة داخلية سابقة**.
- نماذج Gemini المذكورة متضاربة عبر الوثائق (انظر §5).

---

## 5. التكرار والفوضى

### وثائق مكررة/متعددة الإصدارات (مرشّحة للتنظيف)
- **6+ نسخ "Master Blueprint":** `_16`, `_17` (252KB!), `_2 2`, `_Complete`, `_MyVibe`, `_MyVibe_2`. تضخّم وثائقي ضخم (إجمالي ملفات `.md` بالجذر ≈ 1.1MB، 33 ملف).
- **8 ملفات `BATCH_*_RESULT_*` + مجلد `untitled folder/` كامل** فيه تقارير `P0.x/P1.x/P2.x` — كلها تقارير تشغيل تاريخية (artifacts)، **ملفات يتيمة/ميتة** لا يقرؤها الكود.
- مجلد باسم **`untitled folder/`** (اسم افتراضي غير مرتّب) يحوي وثائق فقط.

### تضارب أرقام/قرارات داخل الوثائق
- نماذج Gemini مذكورة بصيَغ مختلفة عبر الوثائق: `gemini-2.0-flash` (في `Master_Blueprint_2 2`) مقابل `gemini-2.5-flash` + `gemini-3-flash-preview` (في `_16`/`_17`/AIContext) — **تضارب نسخ النماذج**.

### تضارب التسميات (كما طلبت)
- **MR-OS / Salam OS / AiQo Salam OS / RoQo** — لا أيٌّ منها يظهر في الكود إطلاقاً. **RoQo** (الكابتن) منفّذ لكن باسم **Hamoudi / Captain** في الشيفرة (`CaptainVoiceService`, `Features/Captain/...`)، فهناك **انفصال تسمية بين العلامة (RoQo) والكود (Hamoudi/Captain)**.
- **"Brain OS"** في `untitled folder/BRAIN_OS_AUDIT...` تعني معمارية دماغ الكابتن، **ليست** نظام تشغيل — تسمية مضلِّلة محتملة.

---

## 6. حالة Git

- **الفرع الحالي:** `claude/aiqo-phone-audit-3vkso6` (شجرة العمل نظيفة).
- **إجمالي الـcommits:** 121.
- **آخر 12 commit:**
  1. `a7fc579` v1.0.3: Privacy hardening + critical telemetry events (#8)
  2. `2450f16` Merge PR #6 brain-refactor/p-fix-dev-override
  3. `b08fd6a` UX pass + level system fix + bump v1.0.1
  4. `55c63dc` Merge PR #7
  5. `f8b6b58` onboarding/settings/profile UX pass
  6. `740af1c` Tighten Captain limits and runtime margins
  7. `9c3d304` Reduce ducked music volume
  8. `589010e` Tune gratitude session audio ducking
  9. `f176f45` Balance captain voice volume
  10. `a26a4ad` Lower gratitude music volume
  11. `a282d65` Switch gratitude audio to shared ambient manager
  12. `11b75c2` Use voice router for gratitude session audio
- **milestones معمولة commit فعلاً:** إصدارات التطبيق (v1.0.1 → v1.0.3)، إعادة هيكلة دماغ الكابتن (brain-refactor)، تحسينات UX/صوت. **لا يوجد أي milestone متعلق بنظام هاتف.**
- **CI:** ملف واحد `.github/workflows/swift.yml` (بناء/اختبار Swift).

---

## 7. المخاطر والثغرات

### ما الناقص لتحقيق "الـroadmap المكتوب" في الوثائق (للتطبيق الصحي)
- ربط Firebase Crashlytics SDK (الـwrapper موجود، الـSDK غير مربوط).
- تفعيل خلفية Tribe ورفع feature flags (حالياً false).
- ضبط أسرار xcconfig (Gemini/ElevenLabs/Spotify/Supabase) لبناء TestFlight.
- (مستقبلي) Fish Speech TTS الذاتي، RunPod، 3D Avatar V1/V2.

### أكبر دين تقني (Technical Debt)
1. **تضخّم وثائقي وفوضى ملفات:** 33 ملف `.md` بالجذر (1.1MB)، 6 نسخ blueprint متضاربة، 8 تقارير batch، ومجلد `untitled folder/` — يصعّب معرفة "مصدر الحقيقة".
2. **انجراف الفروع/فقدان العمل** الموثّق ذاتياً في `BRAIN_OS_AUDIT` (تقدّم مُبالغ على الورق مقابل القرص).
3. **انفصال التسمية** RoQo/Salam OS (علامة) مقابل Hamoudi/Captain (كود).

### أكبر 3 مخاطر
1. **عدم تطابق الهوية:** الجهة الطالبة تظنّ أن هنا مشروع هاتف (Salam OS/NASM/GrapheneOS) — **وهو غير موجود**. خطر تخطيط/توقّعات على أساس خاطئ. (الأعلى أولوية)
2. **تسرّب خصوصية محتمل سابقاً** أُشير إليه في التدقيق الداخلي (raw HealthKit إلى endpoint عربي قبل تطبيق Privacy surgery) — تأكّد أن hardening الخصوصية في v1.0.3 غطّاه فعلاً على فرع الإنتاج.
3. **اعتماد على مفاتيح/خدمات خارجية** (Gemini, ElevenLabs, Spotify, Supabase) غير مُلتزمة في الـrepo؛ أي بناء/إطلاق يعتمد على أسرار خارج المستودع → هشاشة تشغيلية.

---

## 8. توصية ختامية صادقة

إن كان "AiQo Salam OS / النظام NASM / GrapheneOS" مشروعاً حقيقياً عندك، فهو **في مكان آخر** (repo آخر، أو مجلد على جهازك المحلي/Desktop غير متصل بهذه البيئة السحابية). **لا يمكنني فتح ملف على Desktop من هنا** ولا تأكيد وجوده. لمراجعته يجب إتاحة ذلك المستودع/المجلد لهذه الجلسة. أما هذا الـrepo فهو تطبيق AiQo الصحي على iOS — ناضج في طبقتي التطبيق والكابتن، لكنه مثقل بفوضى وثائقية تحتاج تنظيفاً.
