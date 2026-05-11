# AiQo — الملف الرابع: البنية التقنية والمعمارية

> هذا الملف يشرح **كيف AiQo مبني تقنياً** — التقنيات، الـ frameworks، الخدمات، تخزين البيانات، ومعمارية الـ AI. اقرأه إذا تبي تتخذ قرارات تقنية أو تفهم القيود المعمارية.

---

## 1. المنصّة

| البند | القيمة |
|------|--------|
| **المنصة** | iOS فقط — لا Android، لا web app، لا cross-platform |
| **الحد الأدنى** | iOS 16.0 |
| **بعض الميزات تتطلّب** | iOS 26.0+ (Foundation Models)، iOS 26.1+ (AlarmKit) |
| **UI** | SwiftUI أصلي بالكامل — ما اكو UIKit إلا في `LegacyCalculationViewController` و `LoginViewController` (يُحافَظ عليهم، ما يُعاد كتابتهم) |
| **Cross-platform**: | ❌ ما اكو React Native، ❌ ما اكو Flutter، ❌ ما اكو web views (إلا لـ Spotify auth callback) |
| **رفيق Apple Watch** | تطبيق SwiftUI + WatchKit + HealthKit + WatchConnectivity |

---

## 2. Apple Frameworks المستخدمة

| الـ Framework | الاستخدام في AiQo |
|---------------|-------------------|
| **SwiftUI** | كل طبقة UI، كل الشاشات، كل الـ components |
| **SwiftData** | ذاكرة الكابتن، تاريخ المحادثات، التقارير الأسبوعية، ملفات الشخصية، مشاريع الأرقام، quests، نماذج القبيلة، السجلات اليومية |
| **HealthKit** | مصدر البيانات الصحية الأساسي: خطوات، سعرات، نبض، HRV، مراحل النوم، VO2 max، كتلة جسم، مسافة، تمارين، ماي، وقت وقوف |
| **HKWorkoutSession** | تتبّع تمارين Apple Watch لحظياً |
| **StoreKit 2** | إدارة الاشتراكات (تيرين)، التحقق من المعاملات، تتبّع الـ entitlements |
| **UserNotifications** | إشعارات push محلية (ماي، تمرين، نوم، streak، رحلة الـ trial، خمول، انتهاء premium) |
| **BackgroundTasks** | `BGAppRefreshTask` لتحديث الإشعارات، `BGProcessingTask` لفحوصات الخمول |
| **AVFoundation** | تشغيل الصوت لصوت الكابتن (ElevenLabs TTS + AVSpeechSynthesizer fallback) |
| **Speech** | التعرف على الكلام على الجهاز لـ Zone 2 hands-free coaching |
| **AuthenticationServices** | Sign in with Apple (طريقة المصادقة الوحيدة) |
| **WatchConnectivity** | مزامنة الـ phone-watch للأهداف، حالة التمرين، الملخصات اليومية |
| **RealityKit** | عرض أفاتار الكابتن ثلاثي الأبعاد (تنفس/هزّة) |
| **FoundationModels** | Apple Intelligence على الجهاز (iOS 26+) لتحليل النوم والـ chat العام |
| **AlarmKit** | جدولة منبّهات النظام لـ Smart Wake (iOS 26.1+) |
| **AppIntents** | Siri Shortcuts لبدء التمارين بالصوت |
| **WidgetKit** | widgets الشاشة الرئيسية + Watch face |
| **FamilyControls** | الوعي بـ screen time (اختياري، يُطلب أثناء الـ Onboarding) |

---

## 3. الخدمات الخارجية (Third-Party Services)

| الخدمة | الغرض | الحالة الحالية |
|--------|-------|----------------|
| **Gemini API (Google)** | السحابة LLM للكابتن. نموذجين: Gemini 2.5 Flash (مجاني/Core)، Gemini 3.1 Pro (Pro) | نشط، API key عبر xcconfig |
| **ElevenLabs** | TTS لصوت الكابتن. نموذج: `eleven_multilingual_v2`. مخرج: MP3 44100Hz/128kbps | نشط، API key عبر xcconfig |
| **Supabase** | Auth (Sign in with Apple relay)، Postgres database (حسابات، قبائل، leaderboards)، Edge Functions (التحقق من الإيصالات) | نشط، URL + anon key عبر xcconfig |
| **Firebase Crashlytics** | تقارير crash. Wrapper موجود بس Firebase SDK مو في Xcode project | Wrapper جاهز، SDK غير مرتبط — fallback محلي JSONL |
| **Spotify iOS SDK** | `SPTAppRemote` لتحكم التشغيل، `SPTSessionManager` للمصادقة. Scope: `appRemoteControl` | نشط، client ID عبر plist |

---

## 4. الإضافات الخارجية المخطّطة

| الخدمة | الغرض | الجدول الزمني |
|--------|-------|----------------|
| **Fish Speech S1-mini** | TTS مُستضاف ذاتياً متخصّص على صوت محمد، ليحل محل ElevenLabs | بعد الإطلاق |
| **RunPod Serverless** | استضافة GPU inference لـ Fish Speech | بعد الإطلاق |
| **Mixpanel / PostHog / Amplitude** | analytics عن بعد (حالياً JSONL محلي فقط) | بعد الإطلاق |
| **MetaHuman + Unreal Engine** | أفاتار الكابتن ثلاثي الأبعاد V1 (animation idle + صوت) ثم V2 (lip sync + تعابير) | بعد الإطلاق |

---

## 5. طبقات تخزين البيانات

### 5.1 SwiftData (التخزين المنظّم الأساسي)

AiQo يستخدم **اثنين ModelContainers منفصلين**:

#### Captain Memory Container
متجر مخصّص في `captain_memory.store`:
- **CaptainMemory** — حقائق طويلة المدى عن المستخدم
- **CaptainPersonalizationProfile** — الهدف، الرياضة، وقت التمرين، إطار النوم
- **PersistentChatMessage** — تاريخ المحادثة بتجميع جلسات
- **RecordProject** — تتبّع Legendary Challenge
- **WeeklyLog** — سجلات أسبوعية للتحديات
- **WeeklyMetricsBuffer** — لقطات HealthKit يومية (مؤقتة، تُحذف بعد التوحيد)
- **WeeklyReportEntry** — ملخصات أسبوعية دائمة

> يستخدم **VersionedSchema** (V1 → V2 migration) لتطوّر schema آمن.

#### App-wide Container
المتجر الافتراضي:
- **AiQoDailyRecord** — لقطات مقاييس يومية
- **WorkoutTask** — خطط التمارين
- **ArenaTribe, ArenaTribeMember, ArenaWeeklyChallenge, ArenaTribeParticipation, ArenaEmirateLeaders, ArenaHallOfFameEntry** — بيانات Tribe/Arena
- **QuestKit models** — تتبّع quests يومية

### 5.2 UserDefaults (التفضيلات + الحالة الخفيفة)

يُستخدم لـ:
- لغة التطبيق
- تفضيلات الإشعارات
- حالة الـ trial
- feature flags
- علامات إكمال الـ Onboarding
- الأهداف اليومية
- بيانات streak
- cache الـ entitlements
- حالة المنبّه
- snapshot cache للـ personalization
- علامات "has seen" متنوعة

### 5.3 Keychain (تخزين آمن)

يُستخدم لـ:
- **تاريخ بدء الـ trial** — يبقى عبر إعادة تثبيت التطبيق (تطبيق "trial واحد لكل Apple ID")

### 5.4 Supabase Postgres (عن بُعد)

يُستخدم لـ:
- حسابات المستخدمين
- بيانات القبائل
- leaderboards
- مزامنة المستوى/XP
- device tokens للإشعارات عن بُعد

### 5.5 نظام الملفات المحلي

يُستخدم لـ:
- **analytics JSONL events** (`ApplicationSupport/Analytics/events.jsonl`)
- **voice cache** (`documents/HamoudiVoiceCache/`)
- **avatar المستخدم** (`documents/avatar.jpg`)

### 5.6 App Group (`group.aiqo`)

يُستخدم لـ:
- **مشاركة الأهداف اليومية** (هدف الخطوات، هدف السعرات) مع widgets وتطبيق Watch

---

## 6. معمارية الـ AI: الدماغ الهجين بطبقتين

AiQo يستخدم معمارية AI من طبقتين، **الخصوصية** هي القيد الأساسي.

### 6.1 الطبقة ١: على الجهاز (Apple Intelligence / Foundation Models)
- يعمل على جهاز المستخدم بـ **صفر** اتصالات شبكة
- **يُستخدم لـ**: تحليل النوم (دائماً)، الـ chat العام لما Apple Intelligence متوفر (iOS 26+)، prompts تدريب Zone 2
- **المدخلات**: بيانات HealthKit الخام بما فيها مراحل النوم — **أبداً ما تُرسل للسحابة**
- **المخرجات**: `CaptainStructuredResponse` JSON

### 6.2 الطبقة ٢: السحابة (Gemini API)
- **يُستخدم لـ**: ردود اللغة العربية (المسار الأساسي للسياقات غير النوم)، coaching معقّد، توليد خطط التمرين/الوجبات
- **اختيار النموذج حسب التيير**:
  - Gemini 2.5 Flash (مجاني/Core)
  - Gemini 3.1 Pro (Intelligence Pro)
- **حد الـ output tokens**: ٦٠٠ (chat، vibe، sleep) أو ٩٠٠ (gym، kitchen، peaks)
- **Temperature**: 0.7
- **Timeout**: 35 ثانية

### 6.3 التوجيه: BrainOrchestrator

**BrainOrchestrator** يقرر لكل رسالة المسار:

```
sleep analysis ─────────────────► local (raw stages stay on device)
gym, kitchen, peaks, myVibe ────► cloud (Gemini)
mainChat ───────────────────────► cloud (Gemini)
```

### 6.4 سلسلة الـ Fallback (٣ مستويات)
1. **المسار الأساسي** (سحابي أو محلي حسب التوجيه)
2. إذا فشل → جرّب المسار الآخر
3. إذا فشل الاثنين → **fallback حتمي** (ردود عربية مُبرمجة من `CaptainFallbackPolicy`)

### 6.5 الخصوصية: PrivacySanitizer

قبل ما أي بيانات تروح للسحابة:

| البيانات | المعالجة |
|----------|---------|
| Emails, phone numbers, UUIDs, URLs | تُمسح |
| Long numeric sequences, IP addresses, base64 tokens | تُمسح |
| User names | تُستبدل بـ "User" |
| المحادثة | تُقصَّر لآخر ٤ رسائل |
| الخطوات | bucketed بـ ٥٠ |
| السعرات | bucketed بـ ١٠ |
| Kitchen images | يُعاد ترميز بـ ١٢٨٠px max، جودة ٠.٧٨ JPEG، كل EXIF/GPS metadata يُجرَّد |

أنماط كشف PII **pre-compiled** لتجنّب catastrophic backtracking.

### 6.6 جسر الترجمة (Translation Bridge)

لما يستخدم Apple Intelligence على الجهاز للمستخدمين العرب:
1. رسالة المستخدم العربية → تُترجم لإنجليزي عبر Gemini
2. الرسالة الإنجليزية → تُعالج بـ Apple Intelligence على الجهاز
3. الرد الإنجليزي → يُترجم رجوع لعراقي عبر Gemini

**النوايا البسيطة** (تحيات، وقت، تاريخ، شرح AiQo) **تتجاوز** هذا الـ pipeline بردود عراقية حتمية.

### 6.7 نظام Prompt من ٧ طبقات (مسار السحابة)

**CaptainPromptBuilder** يبني system prompt من ٧ طبقات:

| الطبقة | المحتوى |
|--------|---------|
| **١. Identity** | تعريف شخصية كابتن حمّودي، قفل اللغة، الكود السلوكي، العبارات الممنوعة، قواعد طول الرد |
| **٢. Stable Profile** | ملف شخصي دائم (الاسم، الأهداف، العمر، التفضيلات) |
| **٣. Working Memory** | حتى ٨ ذكريات طويلة المدى ذات صلة + intent summary |
| **٤. Bio-State** | مقاييس HealthKit حية (خطوات، سعرات، نوم، نبض، مستوى) — معلَّمة كـ internal-only |
| **٥. Circadian Tone** | توجيه BioTimePhase يضبط الطاقة وطول الجمل |
| **٦. Screen Context** | قواعد سلوك لكل شاشة (kitchen, gym, sleep, peaks, myVibe, mainChat) |
| **٧. Output Contract** | فرض JSON schema الصارم |

---

## 7. العمل في الخلفية (Background Work)

| المهمة | الآلية | المُشغِّل |
|--------|--------|--------|
| **تحديث الإشعارات** | `BGAppRefreshTask` | مجدول ٧:١٥ ص و ٥:٣٠ م |
| **اكتشاف الخمول** | `BGProcessingTask` | كل ساعتين بين ٢:٠٥ م و ٨:٣٠ م |
| **توصيل HealthKit في الخلفية** | `HKObserverQuery` | تغييرات الخطوات، التمارين، النوم |
| **توليد رؤية صباحية** | `MorningHabitOrchestrator` | اكتشاف ٢٥+ خطوة بعد وقت الاستيقاظ المجدول |
| **توحيد الذاكرة الأسبوعي** | `WeeklyMemoryConsolidator` | كل ٧ أيام مرتبطة ببداية الـ trial |
| **مراقبة نهاية التمرين** | `AIWorkoutSummaryService` | إكمال تمرين HealthKit |

---

## 8. إعدادات البناء (Build Configuration)

| البند | التفصيل |
|------|---------|
| **IDE** | Xcode (آخر مستقر) |
| **إدارة الأسرار** | ملفات xcconfig تحقن API keys في Info.plist وقت البناء |
| **مفاتيح الأسرار** | `CAPTAIN_API_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SPOTIFY_CLIENT_ID`, `CAPTAIN_VOICE_API_KEY` وغيرها |
| **Feature flags** | Info.plist boolean keys (`TRIBE_BACKEND_ENABLED`, `TRIBE_SUBSCRIPTION_GATE_ENABLED`, `TRIBE_FEATURE_VISIBLE` — كلها حالياً false) |
| **اختبار StoreKit** | ملف StoreKit محلي (`AiQo_Test.storekit`) للتطوير |
| **App Group** | `group.aiqo` (مشترك بين التطبيق الرئيسي، widgets، Watch app) |

---

## 9. شنو AiQo ما يستخدم (قرار متعمَّد)

- ❌ **No React Native or Flutter** — SwiftUI أصلي صرف
- ❌ **No web views** — إلا لـ Spotify auth callback
- ❌ **No Firebase Realtime Database** — Supabase Postgres بدلاً
- ❌ **No third-party analytics SDK** بعد — JSONL محلي فقط (Mixpanel/PostHog مخطّط بعد الإطلاق)
- ❌ **No paid SDK for fitness data** — HealthKit فقط (مجاني، Apple-native)
- ❌ **No subscription management library** — StoreKit 2 native implementation
- ❌ **No third-party crash reporting linked** — Firebase Crashlytics wrapper موجود بس SDK غير مرتبط
- ❌ **No Core Data** — SwiftData with VersionedSchema حصراً
- ❌ **No Combine-heavy architecture** — يُستخدم بشكل انتقائي لـ HealthKit live bindings، الأكثر async/await

---

## 10. هيكل المشروع (Project Structure)

### 10.1 الملفات الرئيسية

```
AiQo/
├── AiQo/                              # iPhone app
│   ├── Features/
│   │   ├── Captain/                   # كل ما يخص الكابتن
│   │   │   ├── Brain/
│   │   │   │   ├── 01_Memory/         # ذاكرة الكابتن
│   │   │   │   ├── 02_Persona/        # شخصية الكابتن
│   │   │   │   ├── 03_Privacy/        # PrivacySanitizer
│   │   │   │   └── 04_Inference/      # PromptComposer + Brain logic
│   │   │   ├── Voice/                 # ElevenLabs TTS
│   │   │   ├── Avatar/                # RealityKit 3D
│   │   │   └── Chat/                  # واجهة الـ Chat
│   │   ├── Sleep/
│   │   ├── Kitchen/
│   │   ├── Gym/
│   │   ├── Tribe/
│   │   ├── Peaks/
│   │   ├── MyVibe/
│   │   ├── Profile/
│   │   ├── Onboarding/
│   │   └── ProgressPhotos/
│   ├── Shared/
│   ├── Services/
│   └── Models/
├── AiQoWatch Watch App/               # تطبيق Apple Watch
├── AiQoWidget/                        # widgets للـ iPhone
├── AiQoWatchWidget/                   # widgets للـ Apple Watch
├── AiQoTests/                         # tests
├── supabase/                          # Supabase Edge Functions
└── aiqo-web/                          # موقع marketing (Next.js)
```

### 10.2 المكوّنات الإضافية

- **AiQoWidget**: ودجت iPhone (مثلاً hydration widget)
- **AiQoWatchWidget**: ودجت Apple Watch
- **aiqo-web**: موقع تسويقي مبني بـ Next.js + Tailwind CSS
- **supabase/functions**: edge functions (مثل validate-receipt)

---

## 11. تفاصيل تقنية إضافية مهمة

### 11.1 ترتيب موديلات الذاكرة (SwiftData VersionedSchema)
- **V1**: schema أساسي
- **V2**: مع تحسينات (مثل `WeeklyReportEntry`، تحسينات `CaptainMemory`)
- migrations تلقائية بدون فقدان بيانات

### 11.2 الـ Receipt Validation
- **Client-side (الأساسي)**: StoreKit 2 `Transaction` verification — مصدر الحقيقة للـ entitlements
- **Server-side (ثانوي، non-blocking)**: Supabase Edge Function `validate-receipt` — للـ analytics وكشف الاحتيال
- **مهم**: فشل الـ server validation **ما يلغي** entitlements محلياً — الـ client يثق بـ StoreKit الخاص به

### 11.3 الـ Analytics المحلية
- ٥٠+ نوع event
- console + JSONL في `ApplicationSupport/Analytics/events.jsonl`
- الأنواع تشمل:
  - أحداث الـ Captain (إرسال رسالة، استلام رد، fallback)
  - أحداث الـ HealthKit (مزامنة، تحديث)
  - أحداث الـ Subscription (شراء، انتهاء، renew)
  - أحداث الـ Onboarding (إكمال خطوة، ترك)
  - أحداث الإشعارات (إرسال، فتح، تجاهل)

### 11.4 الـ Speech Recognition (Zone 2)
- على الجهاز فقط (`SFSpeechRecognizer` بـ `requiresOnDeviceRecognition = true`)
- يدعم العربية والإنجليزية
- يُستخدم لتفعيل الكابتن صوتياً أثناء التمرين

### 11.5 الـ AlarmKit (iOS 26.1+)
- يحفظ منبّه نظام عند اختيار وقت Smart Wake
- يحترم quiet hours
- يدعم snooze
- على iOS أقل من 26.1: notification fallback

---

## 12. التدفقات الحرجة (Critical Flows)

### 12.1 رسالة من المستخدم → رد الكابتن (Cloud Path)

```
1. User types message in Captain chat
2. Memory extractor scans for facts (rule-based)
3. Every 3 messages → LLM-based memory extraction
4. PrivacySanitizer redacts PII
5. CaptainPromptBuilder builds 7-layer prompt:
   - Layer 1: Identity (Captain Hamoudi system prompt)
   - Layer 2: Stable Profile (durable user data)
   - Layer 3: Working Memory (top 8 relevant memories)
   - Layer 4: Bio-State (HealthKit live data)
   - Layer 5: Circadian Tone (current bio-phase)
   - Layer 6: Screen Context (current screen rules)
   - Layer 7: Output Contract (JSON schema)
6. Send to Gemini API (model selected by tier)
7. Receive JSON response
8. Validate schema
9. If valid → display message
10. If invalid → fallback chain
11. Optionally synthesize voice via ElevenLabs
12. Persist message in chat history
```

### 12.2 تحليل النوم (Local Path)

```
1. HKObserverQuery detects new sleep stage data
2. Sleep stages stay on device — never sent to cloud
3. Apple Intelligence (FoundationModels) processes raw data
4. Generates Arabic sleep briefing
5. Captain delivers briefing as morning notification
6. User opens app → sees full analysis in Captain chat
```

### 12.3 توليد خطة وجبات (Cloud Path with Fridge Data)

```
1. User opens Kitchen → asks for meal plan
2. Fetch fridge inventory from SwiftData
3. Fetch user goal from CaptainPersonalizationProfile
4. Build prompt with kitchen context + fridge items + goal
5. Send to Gemini API (model by tier)
6. Receive JSON with mealPlan field populated
7. Display recipe cards
8. Auto-populate shopping list with missing ingredients
```

### 12.4 الـ Trial Lifecycle

```
1. User completes onboarding (Legacy Calculation step)
2. FreeTrialManager.startTrial() called
3. Trial start date persisted in:
   - UserDefaults (for fast access)
   - Keychain (survives reinstall)
4. AccessManager grants .trial tier
5. All Intelligence Pro features unlocked
6. TrialJourneyOrchestrator schedules 14 notifications across 7 days
7. Day 6: Paywall preview notification at 20:00
8. Day 7: Weekly recap notification at 18:00
9. Day 7+1: Trial expires → AccessManager.activeTier = .none
10. 90% of notifications stop
11. Sunday 18:00: weekly re-engagement notification continues indefinitely
```

---

## 13. القيود التقنية والمخاوف

### 13.1 الـ Blockers لـ TestFlight
- ❌ Firebase Crashlytics SDK غير مرتبط (wrapper موجود)
- ⚠️ Tribe feature flags كلها false (ميزة شغالة بس ما تنتشف اجتماعياً)
- ⚠️ أسرار Supabase يلزم تكون مُعدّة بشكل صحيح عبر xcconfig لـ TestFlight builds
- ⚠️ Gemini API key يلزم تكون valid لوظائف الكابتن السحابي
- ⚠️ ElevenLabs API key يلزم تكون valid لصوت الكابتن
- ⚠️ Spotify client ID يلزم تكون valid لـ My Vibe
- ❓ غير معروف: إذا App Transport Security exceptions مُعدّة بشكل صحيح
- ❓ غير معروف: حالة test coverage

### 13.2 الـ Blockers لـ App Store Submission
- App Store Connect listing يلزم يكون مُعدّ (screenshots، description، keywords)
- privacy policy + terms of service URLs يلزم تكون live
- StoreKit product IDs يلزم تكون مُعدّة في App Store Connect
- review notes يلزم لشروحات استخدام HealthKit
- ❓ غير معروف: إذا كل Info.plist privacy usage descriptions كاملة

---

## 14. Repository وWorkflow

| البند | التفصيل |
|------|---------|
| **GitHub** | `mraad500/AiQo` (private) |
| **المطوّر الفردي** | محمد |
| **Workflow التطوير** | Claude.ai للمعمارية والاستراتيجية، Claude Code CLI للتنفيذ، Xcode للاختبار والتصحيح |
| **حجم الـ codebase** | ~٤٢٣ ملف Swift، ~١٠٦,٠٠٠ سطر |
| **Test coverage** | غير معروف — يحتاج فحص |

---

## 15. ملخص قرارات معمارية مهمة

1. **Two ModelContainers**: فصل ذاكرة الكابتن عن البيانات العامة لعزل التطوير وحماية الـ migrations
2. **VersionedSchema**: SwiftData VersionedSchema (V1 → V2) للتطور الآمن لـ schema بدون فقدان بيانات
3. **Hybrid AI**: Apple Intelligence على الجهاز + Gemini سحابي = خصوصية + قدرة
4. **Translation Bridge**: المستخدم العربي يستخدم Apple Intelligence (إنجليزي على الجهاز) عبر طبقة ترجمة
5. **PrivacySanitizer**: نمط موحّد لتنظيف PII قبل أي اتصال سحابي
6. **App Group**: `group.aiqo` لمشاركة بيانات بين iPhone، Watch، widgets
7. **Keychain للـ trial**: يتجاوز إعادة التثبيت لمنع reuse
8. **Feature Flags**: للقبيلة (٣ flags كلها false حالياً) — تطوير بدون كشف
9. **Local-first analytics**: JSONL محلي حتى ما بعد الإطلاق — يجنّب dependency على SDK خارجي
10. **No Combine-everywhere**: يُستخدم انتقائياً لـ HealthKit live، باقي الـ app على async/await

---

## كيف تستخدم هذا الملف؟
- **اقرأه رابع** — بعد ٣ ملفات السابقة
- **مفيد لـ**: مهندسين، architects، اللي يبي يفهم الـ tech stack أو يقرر إذا ميزة قابلة للتنفيذ
- **متى تشاركه**: لما يكون فيه نقاش تقني يحتاج فهم القيود والـ stack

**التالي**: الملف ٥ — الأعمال، الإطلاق، والهوية البصرية.
