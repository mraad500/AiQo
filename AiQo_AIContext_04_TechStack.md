# AiQo AI Context -- 04 Tech Stack

This file gives any AI a fast, accurate map of what AiQo is built on, so it can answer "can we add X?" or "should we use Y?" correctly. It covers the platform, frameworks, services, data layers, AI architecture, and build configuration.

---

## Platform

- **iOS only** -- no Android, no web app, no cross-platform
- **Minimum iOS version**: iOS 16.0 (some features like Foundation Models require iOS 26.0+, AlarmKit requires iOS 26.1+)
- **Native SwiftUI throughout** -- no UIKit views except legacy LegacyCalculationViewController and LoginViewController (both being maintained, not rewritten)
- **No React Native, no Flutter, no web views** except where Spotify SDK requires a callback URL scheme
- **Apple Watch companion app** built with SwiftUI + WatchKit + HealthKit + WatchConnectivity

---

## Apple Frameworks

| Framework | Purpose in AiQo |
|-----------|----------------|
| SwiftUI | Entire UI layer, all screens, all components |
| SwiftData | Captain memory persistence, chat history, weekly reports, personalization profiles, record projects, quest data, tribe models, daily records |
| HealthKit | Primary health data source: steps, calories, HR, HRV, sleep stages, VO2 max, body mass, distance, workouts, water, stand time |
| HKWorkoutSession | Apple Watch live workout tracking |
| StoreKit 2 | Subscription management (two tiers), transaction verification, entitlement tracking |
| UserNotifications | Local push notifications (water, workout, sleep, streak, trial journey, inactivity, premium expiry) |
| BackgroundTasks | BGAppRefreshTask for notification refresh, BGProcessingTask for inactivity checks |
| AVFoundation | Audio playback for Captain voice (ElevenLabs TTS and AVSpeechSynthesizer fallback) |
| Speech | On-device speech recognition for hands-free Zone 2 coaching |
| AuthenticationServices | Sign in with Apple (sole authentication method) |
| WatchConnectivity | Phone-Watch data sync for goals, workout state, daily summaries |
| RealityKit | 3D Captain avatar rendering (idle breathing/swaying animation) |
| FoundationModels | Apple Intelligence on-device LLM (iOS 26+) for sleep analysis and general chat |
| AlarmKit | System alarm scheduling for Smart Wake (iOS 26.1+) |
| AppIntents | Siri Shortcuts for starting workouts via voice |
| WidgetKit | Home screen and watch face widgets |
| FamilyControls | Screen time awareness (optional, requested during onboarding) |

---

## Third-Party Services

| Service | Purpose | Current State |
|---------|---------|--------------|
| Gemini API (Google) | Cloud LLM for Captain Hamoudi. Two models: Gemini 2.5 Flash (free/Core), Gemini 3.1 Pro (Intelligence Pro) | Active, API key via xcconfig |
| ElevenLabs | Text-to-speech for Captain's voice. Model: eleven_multilingual_v2. Output: MP3 44100Hz/128kbps | Active, API key via xcconfig |
| Supabase | Auth (Sign in with Apple relay), Postgres database (user accounts, tribe data, leaderboards), Edge Functions (receipt validation) | Active, URL + anon key via xcconfig |
| Firebase Crashlytics | Crash reporting wrapper exists but Firebase SDK not yet in xcodeproj. Local JSONL fallback is active | Wrapper ready, SDK not linked |
| Spotify iOS SDK | SPTAppRemote for playback control, SPTSessionManager for auth. Scope: appRemoteControl | Active, client ID via plist |

---

## Planned Third-Party Additions

| Service | Purpose | Timeline |
|---------|---------|----------|
| Fish Speech S1-mini | Self-hosted TTS fine-tuned on Mohammed's voice, replacing ElevenLabs | Post-launch |
| RunPod Serverless | GPU inference hosting for Fish Speech | Post-launch |
| Mixpanel, PostHog, or Amplitude | Remote analytics (currently local-only JSONL) | Post-launch |
| MetaHuman + Unreal Engine | 3D Captain avatar V1 (idle animation + voice) and V2 (lip sync + expressions) | Post-launch |

---

## Data Persistence Layers

### SwiftData (primary structured storage)

AiQo uses two separate SwiftData ModelContainers:

**Captain Memory Container** (dedicated store at `captain_memory.store`):
- CaptainMemory -- long-term facts about the user
- CaptainPersonalizationProfile -- goal, sport, workout time, sleep window
- PersistentChatMessage -- chat history with session grouping
- RecordProject -- Legendary Challenge tracking
- WeeklyLog -- challenge weekly logs
- WeeklyMetricsBuffer -- daily HealthKit snapshots (temporary, deleted after consolidation)
- WeeklyReportEntry -- permanent weekly summaries

Uses VersionedSchema (V1 -> V2 migration) for safe schema evolution.

**App-wide Container** (default store):
- AiQoDailyRecord -- daily metric snapshots
- WorkoutTask -- workout plans
- ArenaTribe, ArenaTribeMember, ArenaWeeklyChallenge, ArenaTribeParticipation, ArenaEmirateLeaders, ArenaHallOfFameEntry -- Tribe/Arena data
- QuestKit models -- daily quest tracking

### UserDefaults (preferences and lightweight state)

Used for: app language, notification preferences, trial state, feature flags, onboarding completion flags, daily goals, streak data, entitlement cache, alarm state, personalization snapshot cache, various "has seen" flags.

### Keychain (secure persistence)

Used for: trial start date (survives app reinstall -- one trial per Apple ID enforcement).

### Supabase Postgres (remote)

Used for: user accounts, tribe data, leaderboards, level/XP sync, device tokens for remote notifications.

### Local file system

Used for: analytics JSONL events (ApplicationSupport/Analytics/events.jsonl), voice cache (documents/HamoudiVoiceCache/), user avatar (documents/avatar.jpg).

### App Group (group.aiqo)

Used for: sharing daily goals (step target, calorie target) with widgets and Watch app.

---

## AI Architecture: The Dual-Layer Hybrid Brain

AiQo uses a two-layer AI architecture with privacy as the primary constraint.

### Layer 1: On-Device (Apple Intelligence / Foundation Models)

- Runs on the user's device with zero network calls
- Used for: sleep analysis (always), general chat when Apple Intelligence is available (iOS 26+), Zone 2 voice coaching prompts
- Input: raw HealthKit data including sleep stages -- never sent to cloud
- Output: CaptainStructuredResponse JSON

### Layer 2: Cloud (Gemini API)

- Used for: Arabic-language responses (primary path for non-sleep contexts), complex coaching, workout/meal plan generation
- Model selection by tier: Gemini 2.5 Flash (free/Core) or Gemini 3.1 Pro (Intelligence Pro)
- Max output tokens: 600 (chat, vibe, sleep) or 900 (gym, kitchen, peaks)
- Temperature: 0.7
- Timeout: 35 seconds

### Routing: BrainOrchestrator

The BrainOrchestrator decides per-message which path to use:
- Sleep analysis -> always local (raw stages never leave device)
- Gym, Kitchen, Peaks, My Vibe, Main Chat -> cloud (Gemini)

### Fallback chain (3 tiers)

1. Primary path (cloud or local as routed)
2. If primary fails -> try the other path
3. If both fail -> deterministic fallback (hardcoded Arabic responses from CaptainFallbackPolicy)

### Privacy: PrivacySanitizer

Before any data reaches the cloud:
- Emails, phone numbers, UUIDs, URLs, long numeric sequences, IP addresses, base64 tokens -> redacted
- User names -> replaced with "User"
- Conversation truncated to last 4 messages
- Steps bucketed by 50, calories by 10
- Kitchen images re-encoded at max 1280px, 0.78 JPEG quality, all EXIF/GPS metadata stripped
- PII detection patterns are pre-compiled to avoid catastrophic backtracking

### Translation bridge (Arabic on-device path)

When using on-device Apple Intelligence for Arabic users:
1. User's Arabic message -> translated to English via Gemini
2. English message -> processed by Apple Intelligence on-device
3. English response -> translated back to Iraqi Arabic via Gemini

Simple intents (greetings, time, date, AiQo explanation) bypass this pipeline with deterministic Iraqi Arabic responses.

### Prompt system: 7-layer architecture (cloud path)

The CaptainPromptBuilder constructs a system prompt with 7 layers:
1. **Identity** -- Captain Hamoudi persona definition, language lock, behavioral code, banned phrases, response length rules
2. **Stable Profile** -- durable user profile (name, goals, age, preferences)
3. **Working Memory** -- up to 8 relevant long-term memories + intent summary
4. **Bio-State** -- live HealthKit metrics (steps, calories, sleep, HR, level) marked as internal-only
5. **Circadian Tone** -- BioTimePhase directive adjusting energy and sentence length
6. **Screen Context** -- per-screen behavioral rules (kitchen, gym, sleep, peaks, myVibe, mainChat)
7. **Output Contract** -- strict JSON schema enforcement

---

## Background Work

| Task | Mechanism | Trigger |
|------|-----------|---------|
| Notification refresh | BGAppRefreshTask | Scheduled at 7:15 AM and 5:30 PM |
| Inactivity detection | BGProcessingTask | Every 2 hours between 2:05 PM and 8:30 PM |
| HealthKit background delivery | HKObserverQuery | Steps, workouts, sleep changes |
| Morning insight generation | MorningHabitOrchestrator | 25+ steps detected after scheduled wake time |
| Weekly memory consolidation | WeeklyMemoryConsolidator | Every 7 days anchored to trial start |
| Workout end monitoring | AIWorkoutSummaryService | HealthKit workout completion |

---

## Build Configuration

- **IDE**: Xcode (latest stable)
- **Secrets management**: xcconfig files inject API keys into Info.plist at build time (CAPTAIN_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY, SPOTIFY_CLIENT_ID, CAPTAIN_VOICE_API_KEY, etc.)
- **Feature flags**: Info.plist boolean keys (TRIBE_BACKEND_ENABLED, TRIBE_SUBSCRIPTION_GATE_ENABLED, TRIBE_FEATURE_VISIBLE -- all currently false)
- **StoreKit testing**: Local StoreKit configuration file (AiQo_Test.storekit) for development
- **App Group**: group.aiqo (shared between main app, widgets, and Watch app)

---

## What AiQo Deliberately Does NOT Use

- **No React Native or Flutter** -- pure SwiftUI native
- **No web views** -- except Spotify auth callback
- **No Firebase Realtime Database** -- Supabase Postgres instead
- **No third-party analytics SDK** yet -- local JSONL logging only (Mixpanel/PostHog planned post-launch)
- **No paid SDK for fitness data** -- HealthKit only (free, Apple-native)
- **No subscription management library** -- StoreKit 2 native implementation
- **No third-party crash reporting linked** yet -- Firebase Crashlytics wrapper exists but SDK not in project
- **No Core Data** -- SwiftData with VersionedSchema exclusively
- **No Combine-heavy architecture** -- used selectively for HealthKit live bindings, mostly async/await

---

## Repository

- **GitHub**: mraad500/AiQo (private)
- **Solo developer**: Mohammed
- **Development workflow**: Claude.ai for architecture and strategy, Claude Code CLI for implementation, Xcode for testing and debugging
- **Codebase size**: 423 Swift files, approximately 106,000 lines of Swift code
- **Test coverage**: Unknown -- needs investigation

---

## How to Use This File With Another AI

Paste this file when the AI needs to make technical decisions about AiQo: whether a feature is feasible, which framework to use, how to integrate a new service, or how the existing architecture constrains a proposed change. Always pair with file 01 (Product Overview) for product context.
