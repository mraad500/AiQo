# AiQo App Store Resubmission Audit

Date: 2026-04-16
Build under review: 1.0 (24)
Project: AiQo

## Scope

This resubmission addresses only the remaining App Review items:

1. Guideline 1.4.1 - Safety - Physical Harm
2. Guidelines 5.1.1(i) and 5.1.2(i) - Privacy - Data Collection / Data Use
3. Guideline 2.1 - Information Needed (Screen Time functionality)

### Additional localization quality fix

- Fixed mixed-language localization in Gym/Battle/Body screens. Battle Stage 1, Stage 2, Kitchen Foundation, and Cardio exercise screens now respect the selected app language.

## 1. Guideline 1.4.1 - Health citations and wellness disclaimer

Implemented production UI changes so citations are visible in-app, not only in prompts or reviewer notes.

### In-app compliance UI added

- `HealthComplianceCard` now appears on health and wellness recommendation surfaces.
- `MedicalDisclaimerView` now shows this visible disclaimer in English and Arabic:
  - "AiQo provides general wellness and fitness guidance only. It is not a medical device and does not provide medical diagnosis, treatment, or emergency advice. Consult a qualified healthcare professional before making medical decisions."
- `HealthSourcesView` provides easy-to-find tappable source cards and links.

### Source links added in-app

- Apple HealthKit
  - https://developer.apple.com/documentation/healthkit
- WHO Physical Activity
  - https://www.who.int/news-room/fact-sheets/detail/physical-activity
- CDC Sleep
  - https://www.cdc.gov/sleep/
- American Heart Association Physical Activity
  - https://www.heart.org/en/healthy-living/fitness
- NIH / MedlinePlus Nutrition
  - https://medlineplus.gov/nutrition.html
- ACSM Exercise Guidance
  - https://www.acsm.org/education-resources/trending-topics-resources/physical-activity-guidelines

### Screens updated with visible sources/disclaimer

- Captain main screen
- Captain chat
- Kitchen main screen
- Meal Plan
- Sleep detail / Smart Wake-related surface
- Weekly Report
- Gym workout plan flow
- Fitness assessment
- Onboarding sleep personalization surface

### Safety wording tightened

- Removed or softened diagnostic / guaranteed-injury-prevention style language where touched by this fix.
- Guidance is now framed as general wellness and fitness support rather than medical advice.

## 2. Guidelines 5.1.1(i) and 5.1.2(i) - Explicit AI data-use consent

Implemented an in-app consent gate that blocks cloud AI requests until the user explicitly agrees.

### Consent behavior

- Before first cloud AI transmission, the app presents an AI Data Use Consent sheet.
- The user must tap `I Agree` before cloud AI features continue.
- If the user taps `Not now`, cloud AI requests are blocked and local-only behavior remains available where possible.
- Consent is reviewable and revocable from:
  - `Profile > App Settings > Privacy & AI Data`

### Consent storage

- `aiqo.aiDataConsent.accepted`
- `aiqo.aiDataConsent.acceptedAt`

Legacy keys are migrated forward automatically if present.

### Disclosure content shown in-app

The consent UI clearly explains:

- What data may be sent:
  - messages typed to Captain,
  - limited app context needed to answer,
  - summarized health and wellness context when relevant,
  - sanitized kitchen images for food / fridge analysis,
  - generated text sent to ElevenLabs only when voice playback is used.
- Who receives it:
  - Google Gemini for AI responses, plans, analysis, and image understanding,
  - ElevenLabs for optional text-to-speech playback.
- Why it is sent:
  - AI coaching replies,
  - workout or meal suggestions,
  - kitchen image understanding,
  - optional voice playback.
- What is not sent:
  - raw HealthKit history is not sent by default,
  - data is minimized / sanitized before cloud requests,
  - no data is sold or used for tracking.

### Runtime gating added

Cloud requests now require consent before transmission in the following paths:

- Captain / cloud brain requests
- Arabic remote reply path
- Coach translation middleware
- Memory extraction to cloud model
- Weekly review LLM submission
- Smart Fridge Gemini image analysis
- Meal plan generation
- ElevenLabs text-to-speech

### Privacy hardening

- Kept `PrivacySanitizer` in the cloud AI path.
- Removed / sanitized debug logging that exposed health values, prompt content, or detailed cloud payload text.
- Updated `PrivacyInfo.xcprivacy` to include collected `User Content` for app functionality.

## 3. Guideline 2.1 - Screen Time functionality status

Audit result:

- AiQo does not include Screen Time functionality in this version.

### Binary changes made

- Removed hidden / unused Screen Time and FamilyControls references from the shipped app target where safe:
  - `FamilyControls`
  - `DeviceActivity`
  - `ManagedSettings`
  - onboarding request path tied to those APIs
- Removed unused related source files that were not part of a reachable feature.
- Removed unused framework references from the Xcode project.

Reviewer answer to use:

- "AiQo does not include Screen Time functionality in this version."

## Reviewer verification paths

### Health sources / citations

- Open `AiQo > Captain`
- The health disclaimer and `Sources` access are visible directly on the Captain screen
- Tap `Sources` to open the citation list

Additional visible citation locations:

- `AiQo > Kitchen`
- `AiQo > Meal Plan`
- `AiQo > Profile > Weekly Report`

### AI consent before third-party AI

- Open `AiQo > Captain`
- Send a message to Captain
- Before any cloud AI request is sent, the `AI Data Use` consent sheet is shown

### Privacy review / revoke path

- Open `AiQo > Profile > App Settings > Privacy & AI Data`

### Screen Time

- AiQo does not include Screen Time functionality in this version

## Test account

- Username: `mraad`
- Password: `12345`

## Build verification

Requested destination `iPhone 16` was not installed on this machine.

Verified with:

- `xcodebuild -showdestinations -project AiQo.xcodeproj -scheme AiQo`
- `xcodebuild build -project AiQo.xcodeproj -scheme AiQo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4'`

Result:

- Build succeeded on `iPhone 17` simulator, iOS `26.4`

## Test verification

Executed:

- `xcodebuild test -project AiQo.xcodeproj -scheme AiQo -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4' -only-testing:AiQoTests`

Result:

- Test command completed with failures in unrelated existing app areas outside the compliance fix scope:
  - `PurchasesTests.testLegacyProProductMapsToIntelligenceProTier`
  - `IngredientAssetLibraryTests.testAllMappedIngredientAssetsExistInFoodPhotosCatalog`
  - `IngredientAssetCatalogTests.testAllMappedIngredientAssetsExistInFoodPhotosCatalog`
  - `ProactiveEngineTests.testGate3_cooldownExpired_passes`
