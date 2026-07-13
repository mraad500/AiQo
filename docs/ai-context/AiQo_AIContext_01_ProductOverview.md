# AiQo AI Context -- 01 Product Overview

This file gives any AI assistant a complete top-level understanding of what AiQo is. Read this file first before any other file in the context pack. It covers the product identity, target user, core pillars, and cultural positioning.

---

## What AiQo Is

AiQo is an Arabic-first iOS health and wellness app built natively in SwiftUI. It positions itself as a "Bio-Digital Operating System" rather than a fitness tracker -- meaning it interprets the user's body data through a personal AI coach named Captain Hamoudi (كابتن حمّودي) who speaks Iraqi/Gulf Arabic dialect, rather than presenting raw charts and numbers. The primary user is an Arabic-speaking adult in the Gulf region who wants a wellness companion that speaks their dialect, understands their culture, and feels like a friend -- not a translated Western app. AiQo ships as a single iOS app with an Apple Watch companion, targeting a May 2026 campus launch at the American University of the Emirates (AUE).

---

## The Core Idea in One Paragraph

Every existing wellness app -- Whoop, MyFitnessPal, Strava, Apple Fitness -- speaks English and presents data as dashboards. AiQo takes the opposite approach: it hides raw numbers behind a persistent AI persona (Captain Hamoudi) who reads the user's HealthKit data, remembers personal facts across sessions, and talks to the user in warm Iraqi Arabic. The user never needs to interpret a chart. Instead, the Captain tells them what their sleep means, what to eat today, and when to move. The data still exists (steps, calories, sleep stages, heart rate, VO2 max) but it serves as input to the Captain's reasoning, not as the user interface itself.

---

## The User

- **Age range:** 18-35, primarily university students and young professionals
- **Region:** Gulf countries -- UAE first (AUE campus launch), then broader GCC
- **Language:** Arabic-first. The app defaults to Arabic (RTL layout) and supports English as a secondary language. The Captain speaks Iraqi/Gulf dialect, not Modern Standard Arabic.
- **Technical sophistication:** Comfortable with iPhones and Apple Watch. Not necessarily fitness-savvy. May have never used a serious health app before.
- **What they care about:** Looking and feeling better. Having someone who "gets" them. Privacy. Not being lectured. Getting actionable advice, not data dumps.
- **What they do not care about:** VO2 max charts. Calorie counting spreadsheets. English-only experiences. Social comparison with strangers. Subscription fatigue from apps that do not deliver.

---

## The "Bio-Digital Operating System" Concept

"Bio-Digital OS" is not a marketing phrase in AiQo -- it is an architectural philosophy. It means:

1. **The body is the input device.** HealthKit streams steps, heart rate, sleep stages, calories, and workouts into the app continuously. The user does not manually log anything (except water and fridge items).
2. **The AI is the interface.** Captain Hamoudi sits between raw data and the user. He reads the data, remembers context, and produces natural-language guidance in dialect Arabic. The user talks to the Captain, not to a dashboard.
3. **The system adapts to circadian rhythm.** AiQo divides the day into five bio-phases (Awakening, Energy, Focus, Recovery, Zen) and adjusts the Captain's tone, advice specificity, and notification timing accordingly. A morning message is calm and brief; an afternoon message during peak energy is direct and commanding.
4. **Privacy is structural, not just policy.** Health data never leaves the device in raw form. A PrivacySanitizer strips PII and buckets numerical data before anything reaches the cloud AI (Gemini). Sleep stage analysis runs entirely on-device via Apple Intelligence.

---

## The Major Experiential Pillars

### 1. Captain Hamoudi (كابتن حمّودي)

The AI coach at the center of everything. Captain Hamoudi is an Iraqi-dialect Arabic persona who remembers the user across sessions (up to 200 facts for Core subscribers, 500 for Intelligence Pro), reads their HealthKit data in real time, and produces workout plans, meal plans, sleep analysis, and motivational coaching. He speaks through text chat (primary), voice (ElevenLabs TTS), and push notifications. He never breaks character, never uses marketing language, and never speaks Modern Standard Arabic unless the user switches to English.

### 2. Sleep Architecture

AiQo treats sleep as a first-class health signal, not an afterthought. The Smart Wake calculator computes optimal wake times based on 90-minute sleep cycles, sleep onset delay, and the user's bedtime. Sleep analysis runs on-device using Apple Intelligence to keep raw sleep stage data private. The Captain delivers a personalized sleep briefing each morning based on the previous night's deep, core, REM, and awake phases.

### 3. Alchemy Kitchen (المطبخ)

A meal planning and fridge management system. The user can scan their fridge using the camera (AI-powered ingredient detection), and the Captain generates meal plans calibrated to their goals (weight loss, muscle building, etc.) using only available ingredients. Meals are organized into breakfast, lunch, and dinner with full macro breakdowns. A shopping list auto-populates with missing ingredients.

### 4. Gym and Zone 2 Coaching

The Gym tab provides structured workout plans generated by the Captain based on the user's goal, fitness level, and available equipment. Zone 2 cardio coaching is a standout feature: during a workout, the user can activate hands-free voice coaching where the Captain monitors heart rate via Apple Watch in real time and gives spoken guidance in Iraqi Arabic to keep the user in their optimal heart rate zone. The Apple Watch companion app tracks workouts with live metrics.

### 5. Tribe (القبيلة / الإمارة)

A private social layer where users form small groups (tribes) of up to 5 members. Tribes have shared energy goals, daily challenges, spark exchanges (encouragement), and a log of group events. The tribe feature is designed around Arabic cultural concepts of family and community loyalty rather than Western leaderboard competition. Currently compiled but hidden behind feature flags pending backend completion.

### 6. Legendary Challenges (قِمَم / Peaks)

Long-term 16-week structured challenges inspired by world-record-breaking concepts. Users choose a record-style goal (e.g., most consecutive workout days, longest running streak) and the Captain builds a weekly progression plan. Intelligence Pro subscribers get full access; Core subscribers can browse challenges in view-only mode. Weekly review sessions track progress with the Captain.

### 7. My Vibe (ذبذباتي)

A Spotify-integrated mood and music feature. The Captain acts as "DJ Hamoudi" and recommends playlists based on the user's current biometric state (heart rate, activity level, time of day) and expressed mood. The user can control playback, request vibe changes, and the Captain adjusts recommendations dynamically. Available to Intelligence Pro subscribers and trial users.

### 8. XP and Leveling

Every action in AiQo earns experience points (XP): completing workouts, hitting step goals, logging meals, maintaining streaks. The XP system uses an exponential curve (base 1000 XP, multiplied by 1.2 per level). Levels map to shield tiers: Wood, Bronze, Silver, Gold, Platinum, Diamond, Obsidian, and Legendary. Level-ups trigger celebration animations and haptic feedback.

---

## What AiQo Is NOT

- **Not a calorie-counting app.** AiQo generates meal plans but does not ask the user to log every bite.
- **Not a social network.** Tribes are small, private, and family-like. There is no public feed, no follower count, no virality mechanics.
- **Not a translated English wellness app.** The Arabic is native -- Iraqi dialect, RTL layout, culturally appropriate language. It was written in Arabic first, not localized from English.
- **Not a chatbot wrapper around GPT.** AiQo uses a hybrid AI architecture (Apple Intelligence on-device + Gemini cloud) with a custom 7-layer prompt system, persistent memory, and strict persona constraints. The Captain is a character, not a generic assistant.
- **Not for elite athletes only.** The target user may have never tracked a workout before. The app meets them where they are.
- **Not a medical device.** AiQo does not diagnose, prescribe, or replace professional medical advice.

---

## Geographic and Cultural Focus

AiQo is built for the Arabic-speaking Gulf region. This is not a localization decision -- it is a product decision that shapes everything:

- **Iraqi dialect for the Captain** was chosen because Mohammed (the solo developer) is Iraqi, and the dialect is warm, informal, and widely understood across the Gulf. The Captain says "هلا بالذيب" (hello, lion), "هسه" (now), "شلون" (how), "عاشت ايدك" (well done), and "بطل" (champion). These are not formal Arabic -- they are how friends talk.
- **القبيلة (the tribe)** is a deep cultural concept in Gulf society. AiQo's social feature is deliberately called "tribe" to invoke family-like bonds, not gym-buddy competition.
- **إمارة (emirate)** appears in the Arena context, connecting to the UAE's national identity.
- **Privacy expectations** are high in Gulf culture. AiQo never shares health data with other users. Tribe members see only what privacy mode allows.
- **Religious sensitivity**: The Captain never uses religious phrases unprompted. No "إن شاء الله" or "ماشاء الله" unless the user initiates.

---

## Current State

AiQo is in pre-launch development, built by a solo developer (Mohammed), targeting a May 2026 campus launch at the American University of the Emirates. The codebase contains 423 Swift files across the iPhone app, Apple Watch app, and widgets. Two subscription tiers are live (AiQo Core at $9.99/month, AiQo Intelligence Pro at $29.99/month) with a 7-day free trial. The Tribe feature is compiled but hidden behind feature flags. No remote analytics provider is connected yet (local JSONL only).

---

## How to Use This File With Another AI

Paste this file as the first context document when asking any AI about AiQo. It provides enough product understanding for the AI to answer high-level questions, make feature suggestions, or write marketing copy. For deeper understanding of specific areas, add the relevant numbered file from this context pack.
