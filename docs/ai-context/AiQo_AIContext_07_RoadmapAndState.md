# AiQo AI Context -- 07 Roadmap and State

This file gives any AI a clear picture of what is done, what is in progress, and what is next -- so it does not suggest things that already exist or skip context that matters.

---

## Project Age and Current State

- **Development started**: Approximately 9 months ago (mid-2025)
- **Solo developer**: Mohammed (Iraqi, based in UAE)
- **Current phase**: Pre-launch, targeting May 2026 campus launch at AUE (American University of the Emirates)
- **Codebase size**: 423 Swift files, approximately 106,000 lines of Swift code
- **Repository**: mraad500/AiQo on GitHub (private)
- **Test coverage**: Unknown -- needs investigation. No test suite was found during recon.
- **Latest commit at time of writing**: 0de4b3e (Add weekly memory consolidation and challenge paywall gates)

---

## What Is Shipped (Working in the Current Build)

### Captain Hamoudi AI System

- Full chat interface with 3D RealityKit avatar (idle animation)
- Hybrid brain architecture: Apple Intelligence on-device + Gemini cloud
- 7-layer prompt system with circadian tone adaptation
- Memory system with rule-based + LLM extraction (200/500 fact limits by tier)
- PrivacySanitizer for all cloud-bound data
- ElevenLabs TTS voice with 13 pre-cached Arabic phrases
- AVSpeechSynthesizer fallback
- Chat history persistence with session grouping
- Cognitive pipeline: intent detection, emotional signal analysis, relevant memory retrieval
- BrainOrchestrator routing (local for sleep, cloud for everything else)
- Fallback chain: cloud -> local -> deterministic

### Sleep Architecture

- Smart Wake calculator with 90-minute cycle engine
- Two modes: from bedtime, from wake time
- Wake window selection (10/20/30 minutes)
- Confidence scoring with Arabic labels
- AlarmKit alarm saving (iOS 26.1+)
- On-device sleep stage analysis via Apple Intelligence
- Morning sleep briefing from Captain
- Sleep session observer (background HealthKit monitoring)

### Alchemy Kitchen

- Camera-based fridge scanner with AI ingredient detection
- Persistent fridge inventory with quantity tracking
- Meal plan generation (3 or 7 day) using fridge items
- Ingredient availability checking (available/low/missing)
- Shopping list with auto-population of missing ingredients
- Ingredient replacement suggestions
- Full macro breakdown per meal (calories, protein, carbs, fat)
- Kitchen scene with Captain Hamoudi illustrated background

### Gym and Workouts

- Captain-generated workout plans (structured exercises, sets, reps, rest)
- Live workout session screen with timer, HR, calories, distance
- Zone 2 hands-free voice coaching (on-device speech recognition + Captain TTS)
- Apple Watch workout tracking (WatchConnectivity sync)
- Siri Shortcuts for starting workouts via voice
- Workout summary with Captain commentary
- Spotify integration for workout playlists
- Live Activity for workout sessions

### XP and Leveling

- Exponential XP curve (base 1000, x1.2 per level)
- 8 shield tiers: Wood through Legendary
- Level-up celebration animation with haptics
- XP sync to Supabase for tribe leaderboards

### Streak System

- Daily activity tracking (5000+ steps or 300+ calories or 30+ activity minutes)
- Current streak, longest streak, weekly consistency percentage
- 90-day history retention
- Tier-based Arabic motivational messages

### Quest System

- QuestKit with daily quests (steps, workouts, kitchen plans)
- SwiftData persistence
- Quest definitions and evaluation engine

### Subscription and Trial

- Two-tier subscription: Core ($9.99/mo) and Intelligence Pro ($29.99/mo)
- StoreKit 2 native implementation
- 7-day free trial with Keychain persistence (reinstall protection)
- Trial Journey Orchestrator: 14 notification types across 7 days
- Dynamic trial notifications (pace spike, inactivity, goal approach, workout detection)
- Post-trial weekly Sunday re-engagement notification
- Paywall with glassmorphic dark UI and contextual source banners
- Server-side receipt validation via Supabase Edge Function (non-blocking)
- Premium expiry notifications (2 days, 1 day, expired)
- Feature gating via AccessManager (per-feature boolean gates)
- Legendary Challenge paywall gate: view-only for Core, full for Pro

### Weekly Memory Consolidation

- Daily HealthKit metrics buffered in SwiftData
- Weekly consolidation into permanent reports (every 7 days, anchored to trial start)
- Bilingual summaries (Arabic + English)
- Weekly reports visible in Captain Memory settings
- Does not count toward user-facing memory limit

### Notifications

- Water reminders (6 daily, rotating Arabic copy)
- Workout motivation (daily at personalized time)
- Sleep reminders (30 min before bedtime)
- Streak protection (daily at 20:00)
- Weekly report (Friday 10:00)
- Inactivity nudges (AI-generated + LLM-translated to Iraqi Arabic)
- Morning habit insights (post-wake AI analysis)
- Captain proactive notifications (smart scheduling, quiet hours 23:00-07:00)
- Trial journey notifications (14 types, context-aware)
- Notification categories with action buttons

### Apple Watch App

- Watch home view with daily summary
- Workout type selection (7 types, indoor/outdoor)
- Active workout view with live metrics
- Workout summary view
- WatchConnectivity sync with iPhone
- Shared app group for goals

### Profile and Settings

- Profile setup (name, age, height, weight, goal, avatar)
- Captain personalization settings (goal, sport, workout time, sleep window, tone)
- Captain memory management view (browse, delete individual, clear all)
- Language selection (Arabic/English)
- Notification toggle
- App settings screen
- Developer panel (DEBUG only)

### Onboarding

- Language selection
- Sign in with Apple + guest login
- Profile setup
- Legacy calculation (HealthKit sync)
- Captain personalization
- Feature introduction walkthrough

### Data and Analytics

- Local analytics (console + JSONL with 50+ event types)
- HealthKit data export
- Progress photos (feature folder exists)
- Daily Aura 14-day history

---

## What Is Partially Shipped (Built but Hidden or Incomplete)

### Tribe (القبيلة / الإمارة)

- **Status**: Compiled, functional with local demo data, but hidden behind three feature flags (all set to false in Info.plist)
- **What works**: Tribe creation, joining via invite code, member list, energy contributions, spark exchanges, mission tracking, event log, Arena challenges, Galaxy view, challenge suggestions
- **What is missing**: Live Supabase backend integration (5 remaining TODOs in TribeExperienceFlow.swift for replacing demo data with real API calls), privacy mode sync to server, global leaderboard population
- **Blocking**: Backend implementation and testing before flags can be enabled

### Firebase Crashlytics

- **Status**: Wrapper code exists (CrashReportingService.swift) but Firebase SDK is not linked in the Xcode project
- **Active fallback**: Local JSONL crash/error logging

### HRR Assessment

- Feature exists in code (HRRWorkoutManager, FitnessAssessmentView)
- Gated behind Core tier
- Functional but may need further testing

### Progress Photos

- Feature folder exists (Features/ProgressPhotos/)
- Unknown -- needs investigation for completeness

### 3D Captain Avatar

- Basic RealityKit avatar rendering works (model named "my" with idle animation)
- Planned V1: full idle animation + custom voice
- Planned V2: lip sync + expressive movement
- Current state: basic breathing/swaying animation only

---

## What Is Planned for After AUE Launch

### Near-term (June-August 2026)

- **Annual subscription tier**: ~$59/year Core, ~$119/year Pro (prices not finalized)
- **Remote analytics**: Mixpanel, PostHog, or Amplitude integration
- **Firebase Crashlytics**: Link SDK, enable remote crash reporting
- **Tribe backend**: Complete Supabase integration, enable feature flags

### Medium-term (2026 Q3-Q4)

- **Fish Speech S1-mini**: Self-hosted TTS fine-tuned on Mohammed's voice, replacing ElevenLabs
- **RunPod Serverless**: GPU inference hosting for Fish Speech
- **3D Captain Avatar V1**: Idle animation + custom voice
- **Broader UAE launch**: Based on AUE campus evidence

### Long-term (2027+)

- **3D Captain Avatar V2**: Lip sync + expressive movement
- **Avatar builder / character customization**: Let users customize Captain appearance
- **Gulf country expansion**: Consider Saudi Arabia, Kuwait, Qatar, Bahrain, Oman
- **Android version**: Potential, but no current plans
- **IP finalization**: Trademark registration, potential patent filings

---

## Known Blockers for TestFlight

Based on codebase analysis:

- Firebase Crashlytics SDK not linked (wrapper exists, SDK missing)
- Tribe feature flags all set to false (feature works but cannot be tested socially)
- Supabase secrets must be properly configured via xcconfig for TestFlight builds
- Gemini API key must be valid for cloud Captain functionality
- ElevenLabs API key must be valid for Captain voice
- Spotify client ID must be valid for My Vibe
- Unknown: whether App Transport Security exceptions are properly configured
- Unknown: test coverage status

---

## Known Blockers for App Store Submission

- App Store Connect listing needs to be prepared (screenshots, description, keywords)
- Privacy policy and terms of service URLs must be live (currently referenced in app)
- StoreKit product IDs must be configured in App Store Connect
- Review notes needed for HealthKit usage explanations
- Potential review concern: "Sign in with Apple" being the sole auth method is fine (Apple prefers this)
- Unknown: whether all Info.plist privacy usage descriptions are complete

---

## Recent Decisions Worth Knowing

These decisions are locked in and an AI should not second-guess them:

1. **Two tiers, not three**: After considering a three-tier structure, Mohammed settled on Core + Intelligence Pro. The retired "Pro" middle tier is preserved only for legacy entitlement decoding.

2. **View-only Legendary Challenges for Core**: Rather than fully locking Legendary Challenges behind Intelligence Pro, Core users can browse challenges but starting one triggers the paywall. This previews the feature and creates desire.

3. **Iraqi dialect over MSA for Captain**: The Captain speaks Iraqi/Gulf dialect exclusively in Arabic mode. This is a brand decision, not a limitation. Modern Standard Arabic sounds formal and impersonal; Iraqi dialect sounds like a friend.

4. **Apple-native everything**: No React Native, no Flutter, no cross-platform. SwiftUI + SwiftData + HealthKit + StoreKit 2 + Apple Intelligence. This limits audience to iOS but maximizes quality and system integration.

5. **No fake/mock data in social features**: Tribes use local demo data during development but will never show fake members or fake activity to real users. When the feature ships, it will be real or it will not be visible.

6. **VersionedSchema for Captain memory migration**: SwiftData VersionedSchema (V1 -> V2) was chosen for safe schema evolution. This is more complex but prevents data loss during updates.

7. **MorningHabitOrchestrator suspended during trial**: The Trial Journey Orchestrator owns all morning notifications during the 7-day trial. The regular MorningHabitOrchestrator defers to it. After trial, the regular orchestrator resumes.

8. **Weekly Sunday notification continues post-trial**: Instead of stopping all notifications for non-subscribers, a single weekly report notification fires every Sunday at 18:00. This maintains a minimal touchpoint for re-engagement without being annoying.

9. **Intelligence Pro fallback price $29.99**: The codebase shows `intelligenceProFallbackPrice = "$29.99"` (not $19.99 as might be mentioned in older documents). The live StoreKit price may differ.

---

## Decisions Still Open

- **Annual subscription pricing**: Exact prices for yearly plans not finalized
- **Whether to add a third tier later**: Possible "Lite" tier or "Pro" tier between Core and Intelligence Pro
- **Gulf country expansion timeline**: Whether to launch in Saudi Arabia, Kuwait, etc. simultaneously with broader UAE push
- **Fish Speech voice training timeline**: Depends on RunPod GPU availability and voice sample quality
- **Remote analytics provider**: Mixpanel vs. PostHog vs. Amplitude -- not decided
- **Tribe monetization**: Whether to gate Tribe behind any tier or keep it accessible to all subscribers
- **Android timeline**: No current plans but not ruled out for 2027+

---

## How an AI Should Engage With This Project

When Mohammed asks an AI for help on AiQo:

1. **Default to Apple-native solutions**: SwiftUI, SwiftData, HealthKit, StoreKit 2, Apple Intelligence. Never suggest React Native, Flutter, Firebase Realtime Database, or third-party subscription management libraries.

2. **Respect the existing two-tier model**: Do not suggest adding tiers, changing prices, or restructuring monetization without being asked.

3. **Never suggest hype or dark patterns**: No "limited time offer", no fake scarcity, no misleading free trial mechanics, no aggressive upselling.

4. **Always check if a feature already exists**: AiQo has 423 Swift files. Before proposing a new feature, search the existing codebase. Cite this blueprint set to confirm.

5. **Default communication**: Iraqi dialect Arabic with English technical terms acceptable. Mohammed is comfortable with both Arabic and English but the product speaks Arabic first.

6. **Think solo-founder constraints**: Mohammed is building this alone. Every suggestion should consider: Can one person implement this? Is this worth the time? Does this move the needle for the AUE launch?

7. **Optimize for AUE launch deadline (May 2026)**: Everything not required for launch should be deferred. Focus on what makes the campus launch successful.

8. **Captain Hamoudi's character is sacred**: Never suggest making the Captain generic, formal, or English-first. The Iraqi dialect personality is the product's core differentiator.

---

## How to Use This File With Another AI

Paste this file when making planning, scoping, or prioritization decisions. It tells the AI what exists (do not rebuild it), what is missing (potential work), what is decided (do not re-litigate), and what is open (good topics for discussion). Pair with file 01 (Product Overview) for product context and file 04 (Tech Stack) for implementation feasibility.
