# AiQo AI Context -- 02 User Experience

This file walks an AI through what it actually feels like to use AiQo, screen by screen, day by day. It covers the full onboarding flow, the daily home screen, every major feature surface, notifications, and the Apple Watch companion. The goal is to make any AI understand the lived experience of an AiQo user without reading code.

---

## First Launch Experience

A brand-new user opening AiQo for the first time goes through six sequential steps before reaching the main app. Each step is a full-screen view with animated transitions.

### Step 1: Language Selection

The first screen presents two language options. Arabic is the default. Selecting a language sets the app's layout direction (RTL for Arabic, LTR for English) and persists the choice for all future sessions. The app restarts its UI with the selected locale.

### Step 2: Sign In

The user sees the AiQo logo and a "Sign in with Apple" button. There is also a "Continue without account" option for guest access. Sign in with Apple is the only authentication method -- no email/password, no Google, no phone number. Guest users can use the app but cannot sync data to Supabase or participate in Tribes.

### Step 3: Profile Setup

The user enters their basic profile information:

- Name
- Age
- Height (in cm)
- Weight (in kg)
- Goal text (free-form, e.g., "Stronger, Leaner")
- Optional: username, gender, birthdate

This screen uses a clean form layout with the AiQo design language (rounded cards, mint/sand accent colors). Profile data feeds into the Captain's memory and notification personalization.

### Step 4: Legacy Calculation (Health Sync)

A screen titled with a loading animation that requests HealthKit permissions and performs an initial sync of the user's historical health data. The app requests read access to: steps, active energy, walking/running distance, cycling distance, heart rate, HRV, resting heart rate, walking HR average, oxygen saturation, VO2 max, body mass, dietary water, stand time, sleep analysis, activity summaries, and workouts. Write access is requested for: heart rate, HRV, resting HR, VO2 max, distance, water, body mass, and workouts.

After permissions are granted, the app syncs historical HealthKit data into Captain's memory (weight, resting heart rate, 7-day step average, 7-day calorie average, 7-day sleep average). The free trial begins at this point (7-day clock starts).

### Step 5: Captain Personalization

The user configures Captain Hamoudi's coaching style through a series of choices:

- **Primary goal**: Lose weight (ينزل وزنه), Gain weight (يصعد وزنه), Cut fat (ينشف دهون), Build muscle (بناء العضلات), Improve fitness (زيادة لياقة)
- **Favorite sport**: Walking (المشي), Running (الجري), Gym/Resistance (الجيم / مقاومة), Football (كرة القدم), Swimming (السباحة), Cycling (الدراجة), Boxing (الملاكمة), Yoga (اليوغا)
- **Preferred workout time**: Dawn (الفجر / بدري), Morning (الصبح), Afternoon (الظهر), Evening (المساء), Night (الليل)
- **Bedtime and wake time**: Time pickers for sleep window
- **Smart Wake recommendation**: The Smart Wake engine calculates optimal wake times based on the selected bedtime

These choices persist in SwiftData and directly influence the Captain's prompt context, workout scheduling notifications, and sleep reminders.

### Step 6: Feature Introduction

A brief walkthrough introducing the app's main features. After completion, the user arrives at the main tab screen.

---

## The Home Screen

The home screen is the first thing the user sees on day 2 and every subsequent app open. It is organized vertically:

### Top Chrome

A header bar with:
- Profile avatar button (left in RTL) -- opens the Profile sheet
- Vibe dashboard trigger button -- opens the My Vibe sheet

### Daily Aura

A centered 172x172 animated circular graphic called the "Daily Aura." It consists of 19 concentric arc segments that fill progressively as the user hits their daily goals:

- Green/mint arcs represent step progress
- Beige/sand arcs represent calorie progress
- A pulsing mint dot at the center breathes with a slow animation
- When progress reaches 100%, an orange glow ring appears with haptic feedback

Tapping the Daily Aura opens a Goals sheet where the user can adjust their daily step goal (1,000-50,000, step 500) and calorie goal (100-5,000, step 50), and view a 14-day history.

### Metric Cards

A 2-column grid of six metric cards:

| Card | Icon | Color | Value Example |
|------|------|-------|---------------|
| Steps | figure.walk | Mint | 8,766 |
| Calories | flame.fill | Mint | 841 |
| Sleep | moon.zzz.fill | Sand | 9.0h |
| Water | drop.fill | Sand | 2.3 L |
| Stand | figure.stand | Mint | 91% |
| Distance | figure.walk.motion | Mint | 6.57 km |

Cards update in real time via HealthKit Combine bindings. Tapping a card opens a detail sheet with a time-scoped chart (Day, Week, Month, Year, All Time). Tapping Water opens the Water Detail sheet for logging water intake.

### Kitchen Shortcut

A floating 100x100 animated button with a gentle bobbing animation that opens the Alchemy Kitchen as a bottom sheet.

---

## Captain Hamoudi Conversations

The Captain tab (center tab, wand-and-stars icon) is the primary interaction surface. Opening it shows:

### Captain Screen

- A 3D avatar of Captain Hamoudi (RealityKit-rendered) with idle breathing and swaying animation
- A chat container below that slides up as conversation grows
- A text input field at the bottom: "اكتب رسالتك للكابتن..." (Write your message to the Captain...)
- Quick reply chips in gold capsules for suggested responses
- Top bar with History button and Profile button

### Conversation Feel

The Captain responds in Iraqi Arabic dialect. Messages appear in colored bubbles:
- User messages: mint green (#C4F0DB)
- Captain messages: sand (#F8D6A3)

A typing indicator (3 bouncing dots) shows while the Captain thinks. The cognitive state is displayed below the avatar:

- "الكابتن يقرأ رسالتك" (Captain is reading your message)
- "الكابتن يشغّل Apple Intelligence" (Captain is running Apple Intelligence)
- "الكابتن يرتب الرد باللهجة العراقية" (Captain is composing the reply in Iraqi dialect)
- "الكابتن يكتب الرد" (Captain is writing the reply)

### Example Exchanges

**User:** شلون نومي البارحة؟
**Captain:** هلا بطل. نومك البارحة كان ٧ ساعات ونص — النوم العميق ساعة و٢٠ دقيقة وهذا زين. بس REM كان أقل من المطلوب. نصيحتي: خفف الشاشات قبل النوم بنص ساعة وخل جسمك يرتاح بهدوء.
*(English: User asks about last night's sleep. Captain gives specific breakdown with actionable advice.)*

**User:** ابي خطة تمرين اليوم
**Captain:** تمام يا سبع. مستواك ١٢ وخطواتك ٣,٢٠٠ لحد هسه. فرتبتلك جلسة ٣٠ دقيقة تناسب وقت المساء...
*(English: User asks for a workout plan. Captain references their level, steps, and preferred time.)*

**User:** شنو آكل؟
**Captain:** بناءً على هدفك — بناء العضلات — واللي عندك بالثلاجة، رتبتلك ٣ وجبات: فطور بيض مع خضار (٣٨٠ سعرة)، غداء ستيك مع رز (٥٦٠ سعرة)، عشاء سلطة تونة (٤٣٠ سعرة).
*(English: User asks what to eat. Captain builds meals from fridge contents aligned to their goal.)*

### Captain Memory

The Captain remembers facts across sessions. Each conversation extracts and stores information:
- Rule-based extraction runs on every message (name, weight, height, age, injuries, goals, sleep)
- LLM-based extraction runs every 3 messages for deeper inference (mood, preferences, feedback)
- HealthKit data syncs automatically (weight, resting heart rate, step average, calorie average, sleep average)

The user can view and manage stored memories by tapping "ذاكرة الكابتن" (Captain's Memory) in settings. Memories are grouped by category: Identity, Goal, Body, Preference, Mood, Injury, Nutrition, Workout History, Sleep, Insight, Record Project. Each memory shows its value, confidence percentage, and source.

---

## Sleep Flow

1. **Bedtime setup**: During onboarding, the user sets their target bedtime and wake time
2. **Smart Wake Calculator**: Available in the Sleep section. The user picks a mode:
   - "From bedtime" -- enter when they plan to sleep, get optimal wake times
   - "From wake time" -- enter when they must wake, get optimal bedtimes
   The engine calculates recommendations based on 90-minute sleep cycles (14-minute sleep onset delay). Each suggestion shows cycle count, expected duration, confidence score, and an Arabic badge: "الأفضل" (Best), "متوازن" (Balanced), or "أخف" (Lighter)
3. **Alarm saving**: On iOS 26.1+, the app can save the selected wake time as a system alarm via AlarmKit
4. **Morning analysis**: When the user wakes, the Captain automatically generates a sleep analysis from HealthKit sleep stage data (deep, core, REM, awake). This runs entirely on-device.

---

## Kitchen Flow

The Alchemy Kitchen opens as a sheet from the home screen or from the Gym tab.

1. **Kitchen Scene**: A full-screen illustrated scene with Captain Hamoudi in a kitchen. Three hotspot areas: Fridge, Captain, Meal Plan
2. **Fridge Scanner**: A camera-based scanner that detects ingredients. The user points their camera at their fridge, captures an image, and the AI identifies items with quantities. Detected items are added to a persistent fridge inventory.
3. **Interactive Fridge**: A visual inventory of all scanned and manually added items. Items show name, quantity, emoji icon, and alchemy notes.
4. **Meal Plan**: The user selects a duration (3 or 7 days) and generates a plan. The Captain builds meals using available fridge items, calibrated to the user's calorie target and goal. Each meal shows name, calories, protein, and ingredient availability (green check = available, orange warning = low, red X = missing).
5. **Shopping List**: Missing ingredients auto-populate. The user can check off items as purchased.
6. **Daily Kitchen Screen**: Shows today's three meals (Breakfast, Lunch, Dinner) with animated recipe cards. Tapping opens full macro details and ingredient list.

---

## Workout Flow

1. **Gym Tab**: The second tab shows workout-related features. The user sees their current active workout plan (if any), quest progress, and the Club section.
2. **Captain-generated workouts**: The user asks the Captain for a workout plan. The Captain generates structured plans with exercises, sets, reps, and rest periods based on the user's goal, level, and preferred sport.
3. **Live Workout Session**: A full-screen session view with timer, heart rate (with pulse animation), calories, distance, and status. Zone 2 guided sessions show a pulsing aura that changes based on heart rate zone status.
4. **Zone 2 Hands-Free Coaching**: During cardio, the user can activate voice coaching. The Captain listens via speech recognition (on-device only), monitors heart rate from Apple Watch, and speaks guidance: "يا بطل، نبضك ١٤٥، هسه هدّي السرعة" (Your HR is 145, slow down now).
5. **Workout Summary**: After completion, a summary screen shows duration, calories, average HR, distance, and the Captain's commentary.

---

## Tribe Flow

Tribes are currently hidden behind feature flags but are compiled and functional:

1. **Creating a Tribe**: Intelligence Pro subscribers can create a tribe, name it, and receive an invite code
2. **Joining**: Members enter the invite code. Maximum 5 members per tribe.
3. **Hub**: Shows tribe name, members with their privacy-respecting display names, energy contributions, and a shared mission (e.g., "Reach 500 combined energy this week")
4. **Sparks**: Members send "sparks" (encouragement) to each other. Each spark adds +2 energy.
5. **Arena**: Tribe-level and galaxy-level challenges with daily/monthly cadences across metrics (steps, water, sleep, active minutes, sugar-free days, calm minutes)
6. **Log**: An event feed showing contributions, sparks, challenge completions, and member joins
7. **Galaxy**: A broader view of all tribes (planned for post-launch)

---

## Legendary Challenges Flow

1. **Browse**: The user sees a list of record-style challenges (available via the Peaks context)
2. **Start**: Intelligence Pro users can start a 16-week structured challenge. Core users see challenges in view-only mode with a paywall gate when attempting to start.
3. **Weekly Progression**: Each week has specific targets. The Captain builds weekly review sessions.
4. **Weekly Review**: The user reviews their progress with the Captain, who adjusts the plan.
5. **Completion**: After 16 weeks, the challenge concludes with a summary.

---

## XP and Leveling

- Every meaningful action earns XP: workouts, step goals, meal plans, streaks, quest completions
- XP formula: `xpForNextLevel = 1000 * 1.2^(level - 1)` -- starts at 1,000 XP, grows exponentially
- Levels map to shield tiers: Wood (1-4), Bronze (5-9), Silver (10-14), Gold (15-19), Platinum (20-24), Diamond (25-29), Obsidian (30-34), Legendary (35+)
- Level-ups trigger a full-screen celebration animation with haptic feedback
- Level and XP sync to Supabase for tribe leaderboards

---

## Captain Memory Settings

Tapping "ذاكرة الكابتن" in the profile or settings shows:

- A toggle to enable/disable Captain memory entirely
- Memory count: "15 / 200" (current memories vs. tier limit)
- Memories grouped by category with expandable sections
- Each memory shows: key label, value, confidence badge (green if >70%, orange otherwise)
- A "Clear All" button with confirmation dialog
- Weekly Reports section showing consolidated weekly summaries (generated every 7 days)

---

## Notifications

A typical day's notifications for an active trial user might include:

| Time | Notification | Trigger |
|------|-------------|---------|
| 08:00 | "صباح الخير [Name] -- خطواتك أمس وصلت ٦,٥٠٠ وكابتن حمّودي جهز لك خطة اليوم" | Morning brief (trial) |
| 10:00 | "[Name]! جسمك يحتاج ماء -- اشرب كوب الحين" | Water reminder |
| 14:00 | "صار لك شوية قاعد" | Inactivity gap (3+ hours) |
| 17:00 | "وقت التمرين! جسمك ينتظرك" | Workout motivation |
| 20:00 | "لسه ما حققت هدفك اليوم! مشي سريع ١٥ دقيقة يكفي" | Streak protection |
| 22:30 | "كابتن حمّودي يقول: النوم أهم من التمرين! تصبح على خير" | Sleep reminder (30 min before bedtime) |

Post-trial, non-subscribers receive only the weekly Sunday report notification. Subscribers continue receiving all notifications.

---

## Apple Watch Experience

The AiQo Watch app provides:

1. **Home View**: Quick daily metrics summary
2. **Workout List**: Choose from workout types (running, walking, cycling, strength, HIIT, swimming, yoga) with indoor/outdoor options
3. **Active Workout View**: Live metrics during a session (timer, heart rate, calories, distance)
4. **Workout Summary**: Post-workout stats
5. **Watch Connectivity**: Syncs with the iPhone app via WatchConnectivity for goals, workout state, and daily summary data

---

## What the User Cannot Do

- Cannot manually enter heart rate, sleep stages, or most health metrics (HealthKit is the source of truth)
- Cannot see other tribe members' detailed health data (privacy mode controls visibility)
- Cannot use Spotify features without Intelligence Pro or an active trial
- Cannot start Legendary Challenges without Intelligence Pro or an active trial
- Cannot create a Tribe without Intelligence Pro
- Cannot exceed memory limits for their subscription tier (200 for free/Core, 500 for Pro)
- Cannot switch the Captain to speak Modern Standard Arabic or English when the app language is Arabic (the Captain always speaks dialect)
- Cannot access the app without completing the onboarding flow (no skip-all shortcut)

---

## How to Use This File With Another AI

Paste this file when the AI needs to understand what using AiQo actually feels like -- for UX design, content writing, notification copy, onboarding improvements, or user research. Pair with file 01 (Product Overview) for full context, and file 03 (Captain Hamoudi) if the task involves the AI persona.
