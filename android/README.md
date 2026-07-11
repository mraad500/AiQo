# AiQo Android

This is the first native Android scaffold for AiQo. It mirrors the live iOS tab structure:

- Home
- Gym
- Kitchen
- Captain

## Build locally

Android Studio is installed on this machine, so the bundled JDK can be used:

```bash
cd /Users/mohammedraad/Desktop/AiQo/android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
./gradlew :app:assembleDebug
```

## Optional Supabase login

The Android app can run without Supabase by tapping `تابع بدون حساب`.
To enable real email/password auth, copy `local.properties.example` to `local.properties` and fill:

```properties
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-public-anon-key
```

Install on a connected Pixel:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
"$ANDROID_HOME/platform-tools/adb" install -r app/build/outputs/apk/debug/app-debug.apk
```

## Port map

| iOS AiQo | Android target |
|---|---|
| SwiftUI | Kotlin + Jetpack Compose |
| HealthKit | Health Connect |
| StoreKit | Google Play Billing |
| Supabase Swift SDK | Supabase Kotlin/Ktor client |
| Apple notifications | Android notifications + WorkManager |
| Apple Intelligence path | Android on-device fallback, then cloud Captain through Supabase |
| WidgetKit/Watch | Android widgets first, Wear OS later |

## Next implementation steps

1. Add onboarding/auth flow that matches `AppFlowController`.
2. Connect Supabase auth and shared backend tables.
3. Replace mock Home metrics with Health Connect reads.
4. Wire Captain chat to the existing Captain cloud path.
5. Add Kitchen camera capture and sanitized upload.
6. Add Play Billing products for Max and Pro.
