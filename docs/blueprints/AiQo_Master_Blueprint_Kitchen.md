<div align="center">

<img src="AiQo.png" width="160" height="160" alt="AiQo app icon" />

# **AiQo — Alchemy Kitchen**

*Master Blueprint · Kitchen (المطبخ)*

**Fridge-scan vision · goal-calibrated meal plans · macro tracking · emoji plate engine · Captain-in-the-kitchen**

</div>

---

# AiQo Master Blueprint — Kitchen (المطبخ)

*The single authoritative reference for the **Kitchen / Alchemy Kitchen** feature of AiQo. Authored 2026-05-18 from a full, fresh read of all 34 Kitchen source files (~7,150 lines), the Brain integration points (`ScreenContext`, `BrainOrchestrator`, `PromptComposer`, `CloudBrain`, `PrivacySanitizer`), the Home entry/gate, localization (`en`/`ar`), assets, the sanitization test, and git history. This document is **self-contained**: hand it to a new engineer and they will understand the entire Kitchen subsystem — what it is, how data flows, how it talks to the cloud, how it stays private, what is fragile, and what is next — **without reading the code first**. It is a vertical companion to [Blueprint 19](AiQo_Master_Blueprint_19.md) (which covers the whole product); where the two disagree on Kitchen, **this document and the live code win** and the divergence is called out inline (see §0.1).*

---

## ملخّص تنفيذي بالعربية (Arabic Executive Abstract)

**المطبخ** (Alchemy Kitchen) هو واحد من فيتشرات AiQo المدفوعة (يتفتح مع اشتراك **AiQo Max**). الفكرة: المستخدم يصوّر ثلاجته بالكاميرا → الصورة تتعقّم على الجهاز (تشيل GPS/EXIF وتصغّر لـ 1280px) → تروح لـ Gemini Vision → يرجع قائمة مكوّنات → الكابتن حمّودي يولّد خطة وجبات (3 أو 7 أيام) معايرة على هدف المستخدم، مع تحليل ماكروز وقائمة تسوّق ذكية للناقص. لو الكلاود فشل، في خطة احتياطية حتمية (deterministic) شغّالة بدون إنترنت. كل مكوّن ينعرض كإيموجي مرتّب على صحن ملوّن (محرّك رسم بالإيموجي — مو صور فوتوغرافية: أصول الصور المنفصلة غير موجودة فعلياً، النظام يعتمد الإيموجي 100%). الخصوصية معمار مو وعد: الصورة تمرّ إجبارياً عبر `PrivacySanitizer` + موافقة `AIDataConsentManager` + بوّابة `TierGate(.captainChat)` قبل ما تطلع من الجهاز، وكل نداء يتسجّل في `AuditLogger` بـ `purpose: .kitchen`. أهم نقطة هندسية: **في نظامين خطط وجبات متوازيين** (بسيط يومي داخل الذاكرة + متعدّد الأيام مثبّت ومحفوظ) غير متزامنين — مصدر تعقيد أساسي. التخزين كله `UserDefaults` (JSON) ما عدا سجل تدقيق المسح في SwiftData. بقيّة المستند بالإنجليزية تطابقاً مع التوثيق الهندسي القائم.

---

## 0. How to use this document & scope

The blueprint answers, in order:

1. **What is the Kitchen and why does it exist?** → §1
2. **How is it architected — the big shapes?** → §2 (incl. the two-parallel-systems warning)
3. **How does the user reach it and what unlocks it?** → §3 Entry & the Max gate
4. **What is the data model and how is it stored?** → §4 Models, §5 Persistence
5. **How does fridge-scan + cloud vision work and stay private?** → §6
6. **How are meal plans generated?** → §7
7. **How is food drawn on screen?** → §8 The emoji plate engine
8. **What are all the screens?** → §9 UI surfaces
9. **How does Captain Hamoudi "know" the kitchen?** → §10 Brain integration
10. **Nutrition, localization, assets, tests?** → §11–§14
11. **Privacy posture, what's fragile, what's next?** → §15 Privacy, §16 Debt & Roadmap, §17 File map, §18 Git history

**Conventions:** `[FileName.swift](path)` is a repo-relative link; `file:line` pointers are anchors against the working tree at HEAD `cc30c4b` (branch `release/v1.0.4-memory-v4`). Every fragility claim in §16 carries a verifiable pointer.

### 0.1 Corrections to Blueprint 19 (Kitchen section)

Blueprint 19 §3.3 / §6 describe Kitchen as having a *"3D RealityKit kitchen scene"* and list `KitchenSceneView (RealityKit)`. **This is inaccurate.** [`KitchenSceneView.swift`](AiQo/Features/Kitchen/KitchenSceneView.swift) renders a **2D full-bleed image (`imageKitchenHamoudi`) with invisible tap-hotspots** — there is **no RealityKit, ARKit, ModelEntity, or 3D** anywhere in the Kitchen module. Treat "interactive scene," not "3D scene," as the truth. Likewise, Blueprint 19's "Arabic-first ingredient illustration library" is real conceptually but is an **emoji** engine, not a photographic asset library (see §8 and §13).

---

## 1. What the Kitchen is

**Alchemy Kitchen (المطبخ)** is AiQo's nutrition pillar — a **Max-tier** feature surface that turns a phone camera and Captain Hamoudi into a personal nutrition system. It does four things:

1. **Smart Fridge Scan** — point the camera at an open fridge; on-device sanitization → Gemini Vision → a structured list of food items added to a persistent fridge inventory.
2. **Captain-generated meal plans** — a 3-day or 7-day plan, goal-calibrated, fridge-aware, language-routed (Arabic/English), with a deterministic offline fallback so it *never* hard-fails.
3. **Nutrition tracking** — a daily macro summary (calories/protein/carbs/fat/fiber) against editable goals, plus manual meal entry.
4. **Smart shopping list** — auto-derives "what you're missing" from the pinned plan vs. fridge contents, with one-tap add / ingredient replacement / "keep marked" triage.

Every meal and ingredient is rendered as a **stylized emoji composition on a tinted ceramic plate** — a deliberate, culturally-neutral, zero-asset-cost illustration style that works identically in Arabic and English.

It is **not** a calorie database (no USDA lookups), **not** a barcode scanner, and **not** a recipe engine — the cloud model invents plans; the app does not own a recipe corpus (`meals_data.json` is a 6-row demo seed only).

---

## 2. Architecture at a glance

### 2.1 The screen tree

```
HomeKitchenRootView                         (gate boundary — HomeView.swift:266)
  └─ KitchenScreen                          (root tab surface — daily 3-meal summary)
       ├─ MealSection ×3 → RecipeCardView   (breakfast / lunch / dinner cards)
       │     └─ MealDetailSheet             (.medium/.large detents; nutrition + ingredients)
       ├─ → MealPlanView                    (generate · pinned plan · shopping list)
       └─ → KitchenSceneView                (2D image hub w/ 3 hotspots)
             ├─ → InteractiveFridgeView     (drag/badge fridge canvas)
             │     ├─ SmartFridgeScannerView (AVFoundation camera → Gemini Vision)
             │     └─ FridgeInventoryView    (list-style add/edit modal)
             ├─ → MealPlanView
             └─ → KitchenView               (legacy LLM hub — globalBrain path)
```

There are **two root surfaces**: the modern `KitchenScreen` (the live tab) and the older `KitchenView` (LLM-hub, reached only via the scene's "captain" hotspot). They do not share state.

### 2.2 The two-parallel-systems warning (read this first)

The single most important architectural fact: **Kitchen has two unrelated meal-plan systems that never synchronize.**

| | **Simple / daily** | **Complex / multi-day** |
|---|---|---|
| Model | `Meal` + `DailyMealPlan` | `KitchenPlannedMeal` + `KitchenMealPlan` |
| Generator | [`MealPlanGenerator.swift`](AiQo/Features/Kitchen/MealPlanGenerator.swift) (random, offline) | [`KitchenPlanGenerationService.swift`](AiQo/Features/Kitchen/KitchenPlanGenerationService.swift) (cloud + fallback) |
| Owner | `KitchenViewModel` (in-memory only) | `KitchenPersistenceStore.pinnedPlan` (persisted) |
| Source | `meals_data.json` (6 demo rows) | Gemini / deterministic templates |
| Survives restart? | **No** (only Quest flags persist) | **Yes** (UserDefaults JSON) |
| Shown by | `KitchenScreen` meal cards (fallback) | `KitchenScreen` (if pinned & active today), `MealPlanView` |

`KitchenScreen` papers over the split: it shows a pinned-plan meal *if* one exists and is active today, otherwise falls back to the random `KitchenViewModel` meal. Any future Kitchen work must respect — or deliberately collapse — this duality.

### 2.3 Data stores

| Store | Tech | Scope | What |
|---|---|---|---|
| `KitchenPersistenceStore` | UserDefaults (JSON, ISO8601) | `@MainActor ObservableObject` | fridge items, pinned plan, shopping list, "needs-purchase" overrides |
| `KitchenViewModel` | in-memory + UserDefaults flags | `@Observable` | demo meals, transient daily plan |
| `SmartFridgeScannedItemRecord` | SwiftData `@Model` | on-device container | immutable audit trail of camera scans |
| `@AppStorage` | UserDefaults | per-view | nutrition goals (calorie/macro targets) |
| Quest bridge | UserDefaults keys + `NotificationCenter` | cross-feature | `aiqo.quest.kitchen.hasMealPlan` / `.savedAt` + `.questKitchenPlanSaved` |

---

## 3. Entry points & the Max gate

### 3.1 The gate

Kitchen is **Max-gated**, enforced at [`HomeView.swift:266`](AiQo/Features/Home/HomeView.swift) in `HomeKitchenRootView`:

```
if DevOverride.unlockAllFeatures || AccessManager.shared.canAccessKitchen {
    KitchenScreen(...)
} else {
    CaptainLockedView(title:"المطبخ", tier:.max, …)  →  PaywallView(source: .kitchenGate)
}
```

- `AccessManager.canAccessKitchen` ≡ `activeTier >= .max` ([`AccessManager.swift:38`](AiQo/Premium/AccessManager.swift)).
- The host observes `EntitlementStore.shared`, so a purchase/trial unlocks the screen immediately (no relaunch).
- `PaywallSource.kitchenGate` ([`PaywallSource.swift:11`](AiQo/UI/Purchases/PaywallSource.swift)) is the dedicated analytics/source case.
- `DevOverride.unlockAllFeatures` (DEBUG-only) bypasses it for solo-founder dogfooding.
- A **second, deeper gate** exists at the cloud boundary: `TierGate.shared.canAccess(.captainChat)` (Max) is re-checked inside both the scanner ([`SmartFridgeScannerView.swift`](AiQo/Features/Kitchen/SmartFridgeScannerView.swift)) and `CloudBrain.generateKitchenAnalysis()` — so even if the UI gate were bypassed, the network call still refuses without Max.

### 3.2 Ways in

- **Home → Kitchen** card → `HomeViewModel.openKitchen()` → destination `.kitchen` ([`HomeViewModel.swift:440`](AiQo/Features/Home/HomeViewModel.swift)).
- **`MainTabRouter.openKitchen()`** ([`MainTabRouter.swift:25`](AiQo/App/MainTabRouter.swift)) → tracks `.kitchenOpened`, posts `.openKitchenFromHome`.
- **Siri Shortcut** `com.aiqo.openKitchen` — donated with Arabic phrase **"افتح المطبخ"** ([`SiriShortcutsManager.swift:36`](AiQo/Core/SiriShortcutsManager.swift)); voice-activatable.
- **Captain** can route the user here when the conversation turns to food (see §10).

---

## 4. Data model

### 4.1 Simple system — [`Meal.swift`](AiQo/Features/Kitchen/Meal.swift)

`struct Meal: Codable, Identifiable, Equatable` — `id:Int`, `name_ar:String`, `calories_kcal:Int`, `meal_type:MealType{breakfast|lunch|dinner}`. Computed `localizedName` (hardcoded English NSLocalizedString switches keyed on specific IDs 1/2/3/4/5/36/63/69/100/1009) and `imageName`. Decoded straight from `meals_data.json` (snake_case keys, no key strategy). `name_en` exists in JSON but is **not decoded**.

### 4.2 Complex system — [`KitchenModels.swift`](AiQo/Features/Kitchen/KitchenModels.swift)

| Type | Key fields | Notes |
|---|---|---|
| `KitchenMealType` (enum) | breakfast/lunch/dinner/**snack** | default kcal (380/560/430/180), default asset & SF Symbol; `.localized` titles (`KitchenModels.swift:14`) |
| `FridgeItem` | `id:UUID`, `name`, `quantity:Double`, `unit:String?`, `alchemyNoteKey:String?`, `updatedAt:Date` | `emoji` via `IngredientEmojiResolver` (fallback 🧺) |
| `KitchenIngredient` | `id`, `name`, `amount:Double?`, `unit:String?` | recipe-side ingredient; `emoji` fallback 🍽️ |
| `KitchenPlannedMeal` | `id`, `dayIndex:Int`, `type`, `title`, `calories:Int?`, `protein/carbs/fat/fiber:Double?`, `ingredients:[KitchenIngredient]` | `localImageName` keyword-sniffs the title (Arabic+English) → "breakfast/lunch/dinner" asset |
| `KitchenMealPlan` | `id`, `startDate:Date`, `days:Int`, `meals:[KitchenPlannedMeal]` | the pinned, persisted plan |
| `ShoppingListItem` | `id`, `name`, `amount?`, `unit?`, `isChecked:Bool`, `createdAt:Date` | emoji fallback 🛒 |
| `IngredientAvailabilityState` (enum) | available ✅ / low ⚠️ / missing ❌ | drives `MealPlanView` ingredient rows |

All `Codable`/`Equatable`. `SmartFridgeScannedItemRecord` is the only **SwiftData `@Model`** (id, name, quantity, unit, alchemyNoteKey, capturedAt) — a write-only audit record with a convenience init from `FridgeItem`; **never queried by any UI** (§16-F12).

---

## 5. Persistence — [`KitchenPersistenceStore.swift`](AiQo/Features/Kitchen/KitchenPersistenceStore.swift)

`@MainActor ObservableObject`. Four `@Published` properties, each with a `didSet` that re-persists unless an `isBootstrapping` flag is set during load:

| Property | UserDefaults key |
|---|---|
| `fridgeItems:[FridgeItem]` | `aiqo.kitchen.fridge.items` |
| `pinnedPlan:KitchenMealPlan?` | `aiqo.kitchen.plan.pinned` |
| `shoppingList:[ShoppingListItem]` | `aiqo.kitchen.shopping.list` |
| `needsPurchaseOverrides:Set<String>` | `aiqo.kitchen.needs.purchase` |

JSON encoder/decoder both pinned to **ISO8601** date strategy (store-local — a cross-store decode with a different strategy would fail, §16-F8).

**Core behaviors:**
- `addOrMergeFridgeItem` merges by **normalized name** (diacritic/case-insensitive, Arabic-folded) → accumulates quantity. Side effect: "2% milk" and "skim milk" both normalize and merge (§16-F6).
- `setPinnedPlan` also writes the **Quest bridge** keys (`aiqo.quest.kitchen.hasMealPlan=true`, `.savedAt=now`) and posts `Notification.Name.questKitchenPlanSaved` (string-named, defined in `QuestEngine.swift`) — this is how the Quest system learns a plan was made.
- `availability(for:)` / `missingIngredients(in:)` power the shopping derivation; `needsPurchaseKey = "{planUUID}|{normalizedName}"` is the override key.
- `replaceIngredient(mealID:ingredientName:)` swaps an ingredient inside the pinned plan and clears its purchase override.

`KitchenViewModel` separately writes `aiqo.quest.kitchen.hasMealPlan/.savedAt` + posts the same notification in `saveCurrentPlan()` — but **does not persist the actual `DailyMealPlan`** (§16-F2).

---

## 6. Fridge-scan + cloud-vision pipeline (privacy-critical)

This is the highest-stakes path in the module: a camera image leaves the device. It is **mandatorily** gated, sanitized, and audited.

### 6.1 Capture — [`SmartFridgeCameraViewModel.swift`](AiQo/Features/Kitchen/SmartFridgeCameraViewModel.swift) + [`SmartFridgeScannerView.swift`](AiQo/Features/Kitchen/SmartFridgeScannerView.swift)

Native **AVFoundation** (`AVCaptureSession` `.photo`, rear wide-angle, flash off), not `PhotosPicker`. Preview via `AVCaptureVideoPreviewLayer` wrapped in `SmartFridgeCameraPreviewController` (`UIViewRepresentable`). Permission state machine: idle → requesting → granted/denied with a localized fallback UI. `CameraView.swift` is a legacy `UIImagePickerController` fallback used only by the old `KitchenView`.

### 6.2 The mandatory gate→sanitize→audit chain

```
Tap "Capture"
 → TierGate.shared.canAccess(.captainChat)            [Max or showPaywall]
 → AIDataConsentManager.ensureConsent(present:true)   [cloud-AI consent sheet]
 → capture JPEG (quality 1.0)
 → CloudBrain.generateKitchenAnalysis(rawImageData, userName)
     → AICloudConsentGate.requireConsent()            [second consent gate, throws]
     → TierGate(.captainChat) re-check
     → PrivacySanitizer.sanitizeKitchenImageData()    [EXIF/GPS strip + resize ≤1280px + JPEG q0.78]
     → PrivacySanitizer.sanitizePromptForCloud()      [PII redaction, Arabic-digit normalize, health bucketing]
     → POST  https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
        header: X-goog-api-key (NOT ?key= query)      [v1.0.3 hardening]
        body: {contents:[{text:"Return JSON only…"},{inlineData:image/jpeg b64}],
               generationConfig:{maxOutputTokens:220,temperature:0.1,responseMimeType:"application/json"}}
        timeout 15s · NO silent retry for kitchen vision
     → parse candidates[0].content.parts[0].text → strip ```json fences → [FridgeItem]
 → AuditLogger.record(Entry(purpose:.kitchen, sanitizationApplied:true, consentGranted:true, …))
```

- **Model selection is tier-aware:** Pro → `gemini-3-flash-preview`; Max/others → `gemini-2.5-flash`.
- **Direct to Gemini** — no Supabase proxy on this path (the proxy is the chat path; Kitchen vision goes straight out with a header-based key).
- The Kitchen vision **prompt is hardcoded and version-controlled** (`"Return JSON only. Visible food items only…"`) → low prompt-injection surface; the test asserts it survives sanitization.
- Parsed items default `quantity → 1.0`, `unit → nil` when absent; empty result throws `visionAnalysisFailed`.

### 6.3 What the sanitizer guarantees (verified by test)

[`KitchenVision_Sanitization_Test.swift`](AiQoTests/KitchenVision_Sanitization_Test.swift) asserts: GPS dict removed; EXIF `DateTimeOriginal`/`LensModel`/`BodySerialNumber` removed; TIFF `Make`/`Model` removed; 4000×3000 → long-edge ≤1280; 800×600 left intact; nil/garbage input → nil; the hardcoded prompt passes through unmolested; an injected email is `[REDACTED]`. End-to-end network/consent/tier are explicitly out of scope (singleton coordination).

This path was historically a **CRITICAL finding** (a direct `URLSession` bypass at `SmartFridgeCameraViewModel.swift:~190` with the key in the URL query) — **resolved in v1.0.3** (`a7fc579` privacy hardening; `19bb0e1` "kill Arabic API + reroute kitchen"). Photos live in memory only; never written to disk, never on AiQo servers.

---

## 7. Meal-plan generation — [`KitchenPlanGenerationService.swift`](AiQo/Features/Kitchen/KitchenPlanGenerationService.swift)

`generatePlan(days, triggerText, fridgeItems, userGoal, cookingTimeMinutes:30)`:

1. Days normalized to **3 or 7**; `TierGate(.multiWeekPlan(weeks:))` checked (multi-week → Pro).
2. **Language routing** — [`KitchenLanguageRouter.swift`](AiQo/Features/Kitchen/KitchenLanguageRouter.swift): Arabic Unicode `0x0600–0x06FF` present → `.arabicGPT`; else `.englishAppleIntelligence`. Mixed text → Arabic wins.
3. Builds a **structured JSON-schema prompt** ("Captain Hamoudi in Kitchen mode…") with a `fridgeSnapshot(...)` string of current items as a *soft hint* (the model may ignore it).
4. Runs through `BrainOrchestrator.processMessage(request, userName)` with `purpose:.kitchen` — i.e. the same sanitize/audit pipeline as §6.
5. Parses `GeneratedPlanPayload` → `[KitchenPlannedMeal]`; clamps `dayIndex` to `[1,days]`; drops empty titles; inserts the first fridge item if a meal has no ingredients.
6. **Deterministic fallback** (no cloud, no user-input interpolation) on nil/unparseable response: hardcoded bilingual templates varying by day-parity (e.g. AR "لبن يوناني مع شوفان", "دجاج مشوي مع رز"; EN "Greek yogurt with oats", "Grilled chicken and rice"). The user is **not told** the cloud failed (§16-F3).

On success the plan is pinned via `KitchenPersistenceStore.setPinnedPlan` (→ Quest bridge fires). Tier failure surfaces `PremiumPaywallView`.

---

## 8. The emoji plate engine (illustration system)

A raw ingredient string (often Arabic) becomes a tilted emoji on a tinted ceramic plate. **No photographs are used in practice** (see §13).

```
raw string ─ IngredientCatalog.normalize() ─→ IngredientCatalog.match()/.extractAll()
          ─→ IngredientKey (69 canonical) ─→ PlateIngredient(id, localizedTitle, emoji)
          ─→ MealImageSpec(template, ≤6 ingredients) ─→ CompositePlateView ─→ MealIllustrationView
```

- **[`IngredientKey.swift`](AiQo/Features/Kitchen/IngredientKey.swift)** — 69 keys (`ing_*`) across 8 priority-ordered categories (protein 0 → other 7). Each key carries: a Unicode **emoji** (many-to-one), a **bilingual title** (switches on `AppSettingsStore.shared.appLanguage`), an **`estimatedProteinGrams`** hardcoded estimate, a **category**, and **~3–5 aliases** (Arabic w/ & w/o diacritics + English + regional, e.g. rice: `["رز","تمن","rice","white rice"]`) — ~270–280 alias strings total.
- **[`IngredientCatalog.swift`](AiQo/Features/Kitchen/IngredientCatalog.swift)** — `normalize()` does Unicode-fold + lowercase + **8 Arabic letter mappings** (أإآ→ا, ى→ي, ة→ه, ؤ→و, ئ→ي, tatweel removed) + non-alnum strip + whitespace collapse. `match()` substring-matches longest-alias-first; `extractAll()` returns category-then-position-sorted unique keys (also an array overload for title+description).
- **[`MealImageSpec.swift`](AiQo/Features/Kitchen/MealImageSpec.swift)** — `MealImageSpecFactory` picks a `PlateTemplate` from title/type (salad→saladBowl; drink keywords→drinkCup; else by meal type; snack→snackBowl), extracts keys from **both** `name_ar` and localized name, then `composedIngredientKeys` tops up from hardcoded 6-item **defaults per template** to land 3–6 ingredients. Also produces `MealDetailPresentation` (spec + display items + clamped protein `[fallback,48]`).
- **[`PlateTemplate.swift`](AiQo/Features/Kitchen/PlateTemplate.swift)** — 6 vessels (breakfast/lunch/dinner/salad bowls, snack bowl, drink cup w/ handle), each with a layered gradient `backgroundView`, a `plateTint`, and **6 hardcoded `(x,y,scale,rotation)` placements**. Note: `scale` & `rotation` in the tuple are **dead fields** — `CompositePlateView` ignores them.
- **[`CompositePlateView.swift`](AiQo/Features/Kitchen/CompositePlateView.swift)** — renders the plate (frosted material + gradient + gloss + ellipse shadow) and lays ≤6 emojis using `placement[index % 6]`, plus a **deterministic jitter** (hash of ingredient id + index → ±amplitude, stable across renders) and a deterministic **±9° rotation**. Accessibility-labeled "Meal illustration".
- **[`IngredientDisplayItem.swift`](AiQo/Features/Kitchen/IngredientDisplayItem.swift)** — `IngredientDisplayBuilder.mergedItems` buckets ingredients by normalized key, counts duplicates, and **only sums quantities when units match** (mixed units → first quantity shown).
- **[`IngredientAssetCatalog.swift`](AiQo/Features/Kitchen/IngredientAssetCatalog.swift) / [`IngredientAssetLibrary.swift`](AiQo/Features/Kitchen/IngredientAssetLibrary.swift)** — an *optional* photographic-asset layer (`uiImage(for:key)`, `keyWithLocalAsset`, DEBUG `missingAssetNames()`). In the current tree **zero `ing_*` imagesets and no `Food_photos` directory exist**, so every lookup returns nil and the **emoji path is the only path** (§13).
- **[`MealIllustrationView.swift`](AiQo/Features/Kitchen/MealIllustrationView.swift)** — a 9-line wrapper: `body { CompositePlateView(spec:) }`.

---

## 9. UI surfaces

| View | Role | Notable state / polish |
|---|---|---|
| [`KitchenScreen.swift`](AiQo/Features/Kitchen/KitchenScreen.swift) | Live root: 3 daily meal cards + nav to plan/scene | `AnimatedMealButton` floats (2.4s) & tilts via `rotation3DEffect`; tap → 0.94 scale + `.light` haptic; `MealDetailSheet` `.medium/.large` + `.ultraThinMaterial`; `.sensoryFeedback(.selection)` on regenerate; meal text `.trailing` (RTL) |
| [`KitchenView.swift`](AiQo/Features/Kitchen/KitchenView.swift) | **Legacy** LLM hub (`@EnvironmentObject globalBrain: CaptainViewModel`) | mint/sand gradient + blur orbs, camera aperture button, loading overlay; reached only via scene "captain" hotspot |
| [`InteractiveFridgeView.swift`](AiQo/Features/Kitchen/InteractiveFridgeView.swift) | Premium fridge canvas | `The.refrigerator` background (asset **present**), 4 hardcoded shelves (yRatio 0.27/0.41/0.55/0.70, ≤5 cols), draggable `FridgePinnedItemBadge` w/ context-menu ±/remove, bottom `IngredientPickerRailView`; spring animations throughout; aspect ratio **hardcoded 871:1536** (§16-F7) |
| [`FridgeInventoryView.swift`](AiQo/Features/Kitchen/FridgeInventoryView.swift) | List-style add/edit modal | `.insetGrouped` List, 3 fields + scanner section + swipe-delete |
| [`MealPlanView.swift`](AiQo/Features/Kitchen/MealPlanView.swift) | Generate · pinned plan · shopping list | 3/7 segmented picker, generate w/ `ProgressView`, per-day meal cards w/ availability icons, **Impact card** (Replace / Add to Shopping / Keep Marked), `HealthComplianceCard`, `PremiumPaywallView` on tier error |
| [`NutritionTrackerView.swift`](AiQo/Features/Kitchen/NutritionTrackerView.swift) | Macro summary + manual entry + goals | `NutritionSummaryCard` (spring-filled calorie bar, 4 macro chips), `QuickAddMealView`, `NutritionGoalsEditor` (`@AppStorage` steppers), `DailyFoodLogView` merges today's pinned + manual meals; cream/tan glass palette; `.medium` haptic on save |
| [`KitchenSceneView.swift`](AiQo/Features/Kitchen/KitchenSceneView.swift) | 2D image hub (NOT 3D — see §0.1) | full-bleed `imageKitchenHamoudi` (asset **present**, 4.6 MB PNG added 2026-05-17), 3 invisible `Rectangle().opacity(0.001)` hotspots + visible `.ultraThinMaterial` badges at normalized coords → fridge / captain / meal-plan; accessibility-labeled; placeholder fallback string still present |
| [`MealSectionView.swift`](AiQo/Features/Kitchen/MealSectionView.swift) | UIKit `UIStackView` hosting `RecipeCardView` via `UIHostingController` | right-aligned title, tap callback, empty-state label |
| [`RecipeCardView.swift`](AiQo/Features/Kitchen/RecipeCardView.swift) | Small meal card (illustration + name + kcal) | `kitchenMint` rounded bg; `.trailing` VStack; RTL preview |

Manual meals in `DailyFoodLogView` are **ephemeral `@State`** (lost on dismiss); nutrition goals are `@AppStorage` only (no backend sync) — §16-F11.

---

## 10. Captain ↔ Kitchen brain integration

The Kitchen is a first-class **`ScreenContext`** so Captain Hamoudi behaves differently when "in the kitchen":

- [`ScreenContext.swift:4`](AiQo/Features/Captain/Brain/03_Reasoning/ScreenContext.swift) — `case kitchen`; `promptTitle = "Kitchen (المطبخ)"`; `focusSummary = "Food, fridge logic, meal suggestions, and practical nutrition choices."`; **`prefersMealPlan == true`** (only kitchen) — this flag tells the inference layer to expect/emit a meal-plan structure.
- [`BrainOrchestrator.swift:119`](AiQo/Features/Captain/Brain/04_Inference/BrainOrchestrator.swift) — `.kitchen` (with `.gym/.peaks/.myVibe/.mainChat`) routes to **Cloud (Gemini)**, never on-device.
- [`PromptRouter.swift:82`](AiQo/Features/Captain/Brain/04_Inference/PromptRouter.swift) — `.kitchen` injects a topical guardrail: *"Stay inside food, cooking, meal timing, and fridge-based suggestions."*
- [`PromptComposer.swift:430`](AiQo/Features/Captain/Brain/04_Inference/PromptComposer.swift) — if `screenContext == .kitchen && hasAttachedImage`, appends: *"The user attached a photo (likely their fridge or a meal). Prioritize meal guidance based on what you see."* "Alchemy Kitchen" is also on the allow-list of feature names the Captain may say in English mid-Arabic.
- [`HybridBrain.swift:22/24`](AiQo/Features/Captain/Brain/04_Inference/Services/HybridBrain.swift) — `RequestPurpose.kitchen` is the audit-log purpose; `:560` special-cases kitchen/gym in reply handling.
- [`CloudBrain.swift:355`](AiQo/Features/Captain/Brain/04_Inference/Services/CloudBrain.swift) — every kitchen call is bracketed by `AuditLogger.Entry(purpose: RequestPurpose.kitchen.rawValue)`.

Net: Kitchen meal-plan generation (§7) and fridge vision (§6) both flow through the **same Brain pipeline** as chat — same sanitizer, same audit, same tier gate — they just carry `purpose:.kitchen` and a kitchen-specific prompt.

---

## 11. Nutrition tracking

`DailyFoodLogView` (in [`NutritionTrackerView.swift`](AiQo/Features/Kitchen/NutritionTrackerView.swift)) is the macro engine. It composes **today's pinned-plan meals + manual meals**, sums calories/protein/carbs/fat/fiber, and renders `NutritionSummaryCard`: a spring-animated calorie progress bar (`X / Y سعرة`) + four color-coded macro chips (protein green, carbs gold, fat orange, fiber blue). Goals live in `@AppStorage` (calorie default 2200) editable via stepper-based `NutritionGoalsEditor` with a reset-to-defaults. `QuickAddMealView` builds an ad-hoc `KitchenPlannedMeal` (type picker + name + calories + 2×2 macro grid) and returns it via callback with a `.medium` haptic. Caveat: manual meals are not persisted and goals never leave the device.

---

## 12. Localization & RTL

Strong bilingual coverage: **~171 EN / ~172 AR** Kitchen-domain keys (`kitchen.*`, `screen.kitchen.*`, `fridge.*`, `nutrition.*`) — near parity. Two key generations coexist: a **legacy** set (`kitchen.section.*`, `kitchen.meal.<type>.itemN`, hardcoded calorie ranges like "Approx. 380–450 kcal") and a **modern** set (`kitchen.scene.*`, `kitchen.fridge.*`, `kitchen.mealplan.*`, `kitchen.availability.*`, `screen.kitchen.*`). `kitchen.diet.body` is an explicit *"Later we will connect this with AI…"* placeholder string still shipped. RTL is **partial-by-convention**: `.trailing` alignment + Arabic literals in `KitchenScreen`/`RecipeCardView`/`InteractiveFridgeView`/`NutritionTrackerView`, full Arabic labels in nutrition, but `KitchenSceneView` is image-positional (asset must itself be RTL-correct) and `KitchenView` sets no explicit direction.

---

## 13. Assets — the emoji-only reality

Only **three** Kitchen image assets exist in `Assets.xcassets`:

| Asset | State |
|---|---|
| `imageKitchenHamoudi.imageset` | **Present** — 4.6 MB PNG, added 2026-05-17 (the scene background) |
| `The.refrigerator.imageset` | **Present** — 1.0 MB PNG (the interactive-fridge background) |
| `Kitchenـicon.imageset` | Present (tab/feature icon; note the literal U+0640 tatweel in the name) |

There are **zero `ing_*` ingredient imagesets and no `Food_photos` directory**. Consequently the entire `IngredientAssetCatalog`/`IngredientAssetLibrary`/`IngredientLocalAssetView` photographic layer is **dead in practice** — every food visual is the emoji plate engine (§8). This is not necessarily a bug (emoji is the chosen aesthetic and is zero-cost, RTL-safe, and consistent) but it means a large block of asset-resolution code is aspirational. The earlier "missing asset → post-launch" placeholder in `KitchenSceneView` is now **stale** (its asset shipped 2026-05-17) though the fallback branch remains.

---

## 14. Testing & QA

One dedicated test: [`KitchenVision_Sanitization_Test.swift`](AiQoTests/KitchenVision_Sanitization_Test.swift) — 7 assertions covering EXIF/GPS stripping, image resize cap, nil/garbage safety, prompt pass-through, and PII scrub (see §6.3). There are **no tests** for: the two meal-plan generators, the ingredient matcher/normalizer (the most logic-dense, Arabic-sensitive code in the module), persistence/merge, the shopping derivation, or the plate layout math. Given the Arabic alias surface and the dual-system risk, `IngredientCatalog` and `KitchenPlanGenerationService.parsePlan/fallback` are the highest-value untested units.

---

## 15. Privacy & security posture (Kitchen-specific)

- **Boundary, not promise:** the only data that leaves the device is (a) a sanitized, downsized, EXIF/GPS-stripped JPEG and (b) a sanitized prompt — both behind two consent gates (`AIDataConsentManager` UI + `AICloudConsentGate` cloud) and a tier gate, audited with `purpose:.kitchen`.
- **Resolved CRITICAL:** the historical direct-`URLSession`/`?key=` bypass in `SmartFridgeCameraViewModel` was closed in v1.0.3 (header-based key, routed through `CloudBrain`/sanitizer). The formal single-cloud-door extraction + CI grep guard remains a product-wide **P2** (Blueprint 19 §9.4.1).
- **Photos** are `@State`/in-memory only — never persisted, never on AiQo infra.
- **API key** travels in the `X-goog-api-key` header (not query); resolved from Info.plist (Secrets.xcconfig) with env fallback and placeholder rejection.
- **Surprise (intentional):** the user's first name is *not* redacted in prompts — it's passed via `CloudSafeProfile`; redacting it would contradict the system prompt.
- **Surprise (dual gate):** consent is checked both in the scanner UI and again in `CloudBrain`; revocation between the two yields an error overlay (acceptable, slightly redundant).

---

## 16. Fragility, debt & roadmap

| # | Issue | Pointer | Severity |
|---|---|---|---|
| F1 | **Two parallel meal-plan systems** never synchronize; `KitchenScreen` masks it | §2.2 | **High (architectural)** |
| F2 | `KitchenViewModel.saveCurrentPlan()` persists *flags only* — the daily `DailyMealPlan` is lost on restart | `KitchenViewModel.swift:~104` | High |
| F3 | Cloud→deterministic fallback is **silent**; user can't tell the plan was offline-generated | `KitchenPlanGenerationService.swift` fallback | Medium |
| F4 | `LocalMealsRepository` swallows file-missing & decode errors → returns `[]` (indistinguishable from success) | [`LocalMealsRepository.swift:~33`](AiQo/Features/Kitchen/LocalMealsRepository.swift) | Medium |
| F5 | `MealPlanGenerator.generateDailyPlan(targetCalories:)` — `targetCalories` accepted but **unused**; plan may be unbalanced | `MealPlanGenerator.swift:~18` | Medium |
| F6 | Fridge merge by normalized name conflates product variants ("2% milk" ≡ "skim milk" → "milk") | `KitchenPersistenceStore.swift:~65` | Low |
| F7 | `InteractiveFridgeView` hardcoded **871:1536** aspect + literal shelf coords; not adaptive | `InteractiveFridgeView.swift` | Low |
| F8 | ISO8601 date strategy is store-local; a cross-store decode with a different strategy fails | `KitchenPersistenceStore.swift:~54` | Low |
| F9 | `IngredientCatalog.match` substring `.contains()` — short aliases can mis-hit; repeated words not deduped | `IngredientCatalog.swift:~57` | Low |
| F10 | `PlatePlacement.scale`/`.rotation` are **dead fields** (CompositePlateView recomputes) | `PlateTemplate.swift:3` | Cosmetic |
| F11 | Manual meals ephemeral; nutrition goals `@AppStorage`-only (no sync/portability) | `NutritionTrackerView.swift` | Medium |
| F12 | `SmartFridgeScannedItemRecord` SwiftData audit is **write-only** — never queried or surfaced | `SmartFridgeScannedItemRecord.swift` | Low |
| F13 | Entire photographic ingredient-asset layer is dead (no `ing_*` assets) — large aspirational code block | §13 | Cleanup |
| F14 | Logic-dense, Arabic-sensitive matcher & both plan generators are **untested** | §14 | Medium |
| F15 | `kitchen.diet.body` ships an explicit "Later…" placeholder string | `Localizable.strings` | Cosmetic |

**Suggested roadmap (priority order):** (1) decide the F1 duality — collapse to the persisted `KitchenMealPlan` system and delete the demo path, or formalize the bridge; (2) surface F3 (a subtle "offline plan" badge); (3) unit-test `IngredientCatalog` + plan parse/fallback (F14); (4) persist manual meals + goals (F11); (5) delete or implement the dead asset layer (F13) and dead placement fields (F10); (6) decide whether the scan audit (F12) should power a "scan history" surface or be removed.

---

## 17. File map (34 files, `AiQo/Features/Kitchen/`)

**Models/data:** `Meal.swift`, `KitchenModels.swift`, `MealsRepository.swift`, `LocalMealsRepository.swift`, `MealPlanGenerator.swift`, `SmartFridgeScannedItemRecord.swift`, `meals_data.json`.
**State/persistence:** `KitchenViewModel.swift`, `KitchenPersistenceStore.swift`.
**Cloud/services:** `KitchenPlanGenerationService.swift`, `KitchenLanguageRouter.swift`, `SmartFridgeCameraViewModel.swift`.
**Camera:** `SmartFridgeScannerView.swift`, `CameraView.swift`, `SmartFridgeCameraPreviewController.swift`.
**Illustration engine:** `IngredientKey.swift`, `IngredientCatalog.swift`, `IngredientAssetCatalog.swift`, `IngredientAssetLibrary.swift`, `IngredientDisplayItem.swift`, `MealImageSpec.swift`, `PlateTemplate.swift`, `CompositePlateView.swift`, `MealIllustrationView.swift`.
**UI surfaces:** `KitchenScreen.swift`, `KitchenView.swift`, `InteractiveFridgeView.swift`, `FridgeInventoryView.swift`, `MealPlanView.swift`, `NutritionTrackerView.swift`, `MealSectionView.swift`, `RecipeCardView.swift`, `KitchenSceneView.swift`.
**Test:** `AiQoTests/KitchenVision_Sanitization_Test.swift`.
**Integration (outside the module):** `HomeView.swift` (gate), `AccessManager.swift`, `PaywallSource.swift`, `MainTabRouter.swift`, `SiriShortcutsManager.swift`, `ScreenContext.swift`, `BrainOrchestrator.swift`, `PromptRouter.swift`, `PromptComposer.swift`, `HybridBrain.swift`, `CloudBrain.swift`, `PrivacySanitizer.swift`, `QuestEngine.swift`.

---

## 18. Git history (Kitchen-relevant)

| Commit | Relevance |
|---|---|
| `00f120f` | `fix(ui): kitchen scene + nutrition card + profile + chat bubble polish` (latest Kitchen touch) |
| `a7fc579` | `v1.0.3: Privacy hardening + critical telemetry events` — closed the vision-bypass CRITICAL |
| `f431f30` | `P0.3: harden sanitizer regexes + add on-device AuditLogger` |
| `19bb0e1` | `P0.2: kill Arabic API + reroute kitchen + template notifications` |
| `8dfeb0c` | `Wire tier gating across remaining premium paths` (Kitchen → Max) |
| `59bc97b` | `Prepare V1 release by hiding Tribe and removing Kitchen mock data` |

---

## 19. Footer

*Authored 2026-05-18 against HEAD `cc30c4b`, branch `release/v1.0.4-memory-v4`. Scope: the Kitchen / Alchemy Kitchen feature and its integration seams. For product-wide context (Brain OS, monetization, the other 17 modules) see [AiQo_Master_Blueprint_19.md](AiQo_Master_Blueprint_19.md). Where this document and Blueprint 19 disagree on Kitchen, this document and the live code are authoritative (see §0.1). Every fragility in §16 carries a verifiable file pointer.*
