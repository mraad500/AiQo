# Paste-Ready App Review Reply

Hello App Review Team,

Thank you for the additional review. We updated the binary for build 1.0 (24) to address the remaining items.

We also fixed the mixed-language issue shown in Apple’s screenshot. The Kitchen Foundation challenge and related Battle/Cardio screens now display English content in English mode and Arabic content in Arabic mode.

## 1. Guideline 1.4.1 - Safety - Physical Harm

We added visible in-app health and wellness source citations and a visible wellness disclaimer in both English and Arabic.

The app now includes an easy-to-find `Sources` entry directly on health-related guidance surfaces, including Captain and other wellness recommendation areas. Tapping `Sources` opens a screen with tappable references to reputable sources including Apple HealthKit, WHO Physical Activity, CDC Sleep, the American Heart Association, NIH MedlinePlus Nutrition, and ACSM guidance.

We also added this visible disclaimer in-app:

"AiQo provides general wellness and fitness guidance only. It is not a medical device and does not provide medical diagnosis, treatment, or emergency advice. Consult a qualified healthcare professional before making medical decisions."

## 2. Guidelines 5.1.1(i) and 5.1.2(i) - Privacy - Data Collection / Data Use

We implemented a required in-app `AI Data Use` consent flow before any personal data is sent to third-party AI services.

Before the first cloud AI request, the app now clearly explains:

- What data may be sent:
  - user messages typed to Captain,
  - limited app context needed to answer,
  - summarized health and wellness context when relevant,
  - sanitized kitchen images if food / fridge analysis is used,
  - generated text sent to ElevenLabs only when the user chooses voice playback.
- Who receives the data:
  - Google Gemini for AI responses, plans, analysis, and image understanding,
  - ElevenLabs for optional text-to-speech playback.
- Why it is sent:
  - AI coaching replies,
  - workout / meal suggestions,
  - kitchen image understanding,
  - optional voice playback.
- What is not sent:
  - raw HealthKit history is not sent by default,
  - data is minimized / sanitized before cloud requests,
  - no data is sold or used for tracking.

The user must tap `I Agree` before cloud AI features continue. If the user taps `Not now`, cloud AI requests are blocked.

Users can also review or revoke consent later from:

- `Profile > App Settings > Privacy & AI Data`

## 3. Guideline 2.1 - Screen Time functionality

AiQo does not include Screen Time functionality in this version.

## Verification paths

- Health sources path:
  - `AiQo > Captain > Sources`
- AI consent path:
  - `AiQo > Captain > send a message`
  - the `AI Data Use` consent sheet appears before any cloud AI request
- Settings privacy path:
  - `AiQo > Profile > App Settings > Privacy & AI Data`
- Screen Time:
  - not included in this version

## Test account

- Username: `mraad`
- Password: `12345`

Thank you.
