# AiQo Android Port Plan

## Decision

AiQo on iOS is a native SwiftUI app, not Flutter or React Native. The Android version should therefore be a native Kotlin + Jetpack Compose app, with shared backend contracts through Supabase and shared product behavior through documented data models.

The Android app lives in:

```text
/Users/mohammedraad/Desktop/AiQo/android
```

## Current milestone

The initial Android scaffold is an MVP shell:

- Arabic-first RTL interface
- AiQo app id: `com.mraad500.aiqo`
- App icon from the existing AiQo brand assets
- Four tabs matching the live iOS code: Home, Gym, Kitchen, Captain
- Placeholder Home metrics, Gym plan, Kitchen Vision, and Captain chat
- Gradle wrapper included for repeatable builds

## Feature migration order

| Phase | Goal | Notes |
|---|---|---|
| 1 | App shell | Compose tabs, theme, basic navigation, Arabic/English resources |
| 2 | Account | Supabase auth, session restore, continue-without-account if retained |
| 3 | Health | Health Connect permissions, steps, sleep, calories, heart rate |
| 4 | Captain | Cloud Captain through Supabase Edge Functions, local fallback, privacy sanitizer |
| 5 | Kitchen | Camera, image redaction policy, Gemini vision through backend |
| 6 | Gym | Plans, live workout tracking, outdoor run, achievements |
| 7 | Monetization | Google Play Billing products equivalent to Max and Pro |
| 8 | Salam OS polish | Default allowlist, deeper notification/policy integration where Salam OS permits |

## Salam OS boundary

Salam OS and AiQo Android should stay separate:

- Salam OS owns device policy, network guard, app store rules, and Pixel build work.
- AiQo Android is a normal Android app that should run on Pixel/GrapheneOS/Salam OS.
- Any privileged Salam OS integration should be added later behind a separate flavor, not in the public Play build.

## Build commands

```bash
cd /Users/mohammedraad/Desktop/AiQo/android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
./gradlew :app:assembleDebug
```
