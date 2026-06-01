# AiQo AI Context -- 06 Brand and Design

This file gives any AI complete understanding of AiQo's visual and verbal identity so it can create matching content, suggest design directions, or write copy that feels native to the product.

---

## Brand Colors

### Primary palette

| Name | Hex | Usage |
|------|-----|-------|
| Mint (primary) | #C4F0DB | Primary action cards, stat card tints (steps, calories, stand, distance), user chat bubbles, Kitchen accent |
| Mint (deeper) | #CDF4E4 | Brand mint (AiQoColors.mint), backgrounds |
| Accent (sand/gold) | #F8D6A3 | Captain chat bubbles, gold highlights, stat card tints (water, sleep), beige accent |
| Accent (deeper gold) | #EBCF97 | Quick reply chips, Intelligence Pro glow, paywall accent |
| AiQo Accent (lemon) | #FFE68C | Tab bar accent color, system tint |
| Beige | #FADEB3 | Soft warm backgrounds, AiQo beige accent |

### Semantic colors (light / dark adaptive)

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| primaryBackground | #F5F7FB | #0B1016 | App background |
| surface | white | #121922 | Card surface |
| surfaceSecondary | #EEF2F7 | #18212B | Nested card surface |
| textPrimary | #0F1721 | #F6F8FB | Headlines, primary text |
| textSecondary | #5F6F80 | #A3AFBC | Subtitles, captions |
| accent | #5ECDB7 | #8AE3D1 | Interactive elements, CTA gradient |
| border | black 8% | white 8% | Subtle borders |

### Captain chat bubble colors

- User bubble: mint (#C4F0DB) with asymmetric corners (rounded top and sides, tight bottom-trailing)
- Captain bubble: sand (#F8D6A3) with asymmetric corners (rounded top and sides, tight bottom-leading)

### How colors are used

- **Mint** is for primary actions, health metrics, progress indicators, and the user's side of conversation
- **Sand/Gold** is for the Captain's responses, achievements, premium moments, and warm emphasis
- **Background is light and soft** -- never pure white. Light mode uses #F5F7FB. Dark mode uses #0B1016.
- **Text is bold black for primary** content, muted gray for secondary. No colored text except in badges and accent elements.

---

## Typography

- **Font family**: SF Pro Rounded throughout the entire app. No custom fonts.
- **Weight hierarchy**:
  - Screen titles: `.title2` rounded bold
  - Section titles / card titles: `.headline` rounded semibold
  - Body text: `.subheadline` rounded
  - Captions: `.caption` rounded
  - CTA buttons: `.headline` rounded semibold
- **Arabic typography**: Handled natively by the system. SF Pro Rounded supports Arabic glyphs. No custom Arabic font files.
- **RTL-first layout**: When language is Arabic, `layoutDirection` is `.rightToLeft` applied at the root view level.

---

## Visual Language

### Cards

- **Glassmorphism**: Cards use `.ultraThinMaterial` backgrounds for a frosted-glass effect
- **Rounded corners**: 16pt standard for cards, 12pt for chips and small elements, 24pt for hero cards and CTA containers, 28pt for sheets
- **No drop shadows**: Elevation is conveyed through material blur, not shadow. This keeps the UI clean and modern.
- **No gradients** except:
  - Subtle vertical fades on backgrounds
  - Paywall hero accent circles (teal, gold, mint blurs)
  - Smart Wake featured recommendation (green-blue-purple gradient)
  - Captain screen mesh gradient background (iOS 18+)

### Spacing

| Token | Value | Usage |
|-------|-------|-------|
| xs | 8pt | Tight spacing, inline elements |
| sm | 12pt | Card internal padding |
| md | 16pt | Standard card spacing |
| lg | 24pt | Section spacing |

### Animation

- **Spring animations** throughout: `.spring(response: 0.35, dampingFraction: 0.8)` is the standard
- Quick reply chips: `.spring(response: 0.28, dampingFraction: 0.86)`
- Card press effect: `.spring(response: 0.28, dampingFraction: 0.78)`
- Level-up celebration: full-screen overlay with opacity transition
- Daily Aura: breathing dot (2.4s repeat), staggered arc fill (1.2s easeInOut per segment)
- Kitchen recipe cards: floating bob animation (1.2pt Y offset, 0.45 degree rotation, 2.4s repeat)
- Captain typing indicator: 3 bouncing dots, 0.18s stagger, 0.7s easeInOut
- Native Apple components preferred over custom imitations

### General principles

- **Generous whitespace**: The app breathes. Screens are not packed.
- **Minimal decoration**: Fewer borders, fewer icons, more text and material.
- **Single focal point per screen**: Each screen has one primary element that draws the eye.
- **Haptic feedback**: Selection feedback on tab changes, light impact on 100% goal completion, success notification on level-up.

---

## Iconography

- **SF Symbols** throughout -- no custom icon set
- Common icons: `house.fill` (home), `figure.strengthtraining.traditional` (gym), `wand.and.stars` (captain), `moon.zzz.fill` (sleep), `fork.knife.circle.fill` (kitchen), `drop.fill` (water), `flame.fill` (calories), `figure.walk` (steps)
- Emoji used sparingly inside cards for warmth -- maximum one emoji per card
- No emoji in navigation, headers, or system elements

---

## What the Design Is NOT

- **Not loud**: No neon colors, no aggressive contrast, no attention-grabbing animations
- **Not gradient-heavy**: Gradients are rare and subtle, never the primary visual element
- **Not childish**: Rounded corners and warmth do not mean cartoonish. The design is adult and considered.
- **Not Western fitness aesthetic**: No dark backgrounds with neon green, no aggressive typography, no "BEAST MODE" energy
- **Not cluttered**: Each screen has clear hierarchy and breathing room
- **Not a "data dashboard"**: Numbers exist but are presented conversationally, not in grid dashboards
- **Not dark-mode-first**: Light mode is the primary experience. Dark mode is supported but secondary.

---

## Verbal Identity (Arabic)

### Captain Hamoudi's dialect

Iraqi/Gulf Arabic dialect for all Captain interactions. See file 03 (Captain Hamoudi) for the complete voice guide.

### System labels and navigation

Modern Standard Arabic is acceptable for UI labels, button text, and navigation items. The dialect is reserved for the Captain's personality; system chrome speaks standard Arabic for clarity.

### Tone principles

- **Casual and warm**: Never formal. Never bureaucratic.
- **Never uses religious phrases unprompted**: No "إن شاء الله", "ماشاء الله", "الحمد لله" unless the user initiates
- **Never uses gendered assumptions**: Notifications and system copy avoid assuming gender. When gender matters (grammatical Arabic), it reads from the user's stored preference.

---

## Verbal Identity (English Fallback)

- Conversational, second-person ("you")
- Short sentences. No compound sentences where a simple one works.
- No marketing words: never "powerful", "revolutionary", "cutting-edge", "game-changing", "seamless"
- Direct and honest. "Your sleep was short" not "We noticed your sleep metrics indicate suboptimal duration"

---

## App Icon Concept

- Mint/teal background
- Sand/gold figure suggesting brain + bicep (intelligence + fitness)
- Increased saturation and deepened outlines for visibility on crowded home screens
- Clean, recognizable at small sizes

---

## Sample Copy in Arabic (Actual App Strings)

| Context | Arabic | English Translation |
|---------|--------|-------------------|
| Tab: Home | الرئيسية | Home |
| Tab: Gym | الجيم | Gym |
| Tab: Captain | الكابتن | Captain |
| Captain welcome | هلا! أنا كابتن حمّودي. شنو هدفك اليوم؟ | Hello! I'm Captain Hamoudi. What's your goal today? |
| Captain status | يفكر هسه | Thinking now |
| Captain ready | جاهز | Ready |
| Chat placeholder | اكتب رسالتك للكابتن... | Write your message to the Captain... |
| Workout card | خطة التمرين جاهزة | Workout plan ready |
| Memory title | ذاكرة الكابتن | Captain's Memory |
| Chat history | المحادثات | Conversations |
| New chat | محادثة جديدة | New conversation |
| Water reminder | جسمك يحتاج ماء -- اشرب كوب الحين | Your body needs water -- drink a cup now |
| Sleep reminder | النوم أهم من التمرين! تصبح على خير | Sleep is more important than exercise! Good night |
| Streak alert | لسه ما حققت هدفك اليوم! | You haven't hit today's goal yet! |
| Trial pill | 7 أيام مجانية | 7 free days |
| Paywall headline | اكتشف قدراتك الحقيقية مع AiQo | Discover your true potential with AiQo |

---

## How Another AI Should Write Content for AiQo

### Length limits

- **Notifications**: Under 80 characters for title, under 160 characters for body
- **Captain chat replies**: Under 280 characters for general responses, up to 4 sentences for sleep analysis
- **Quick reply chips**: Under 25 characters each, maximum 3 chips
- **Marketing copy**: Under 140 characters per line for social media

### Forbidden words

Never use in any AiQo content:
- "powerful", "revolutionary", "cutting-edge", "game-changing", "seamless", "world-class"
- "leverage", "synergy", "paradigm", "ecosystem" (tech jargon)
- "بالتأكيد", "بكل سرور", "يسعدني مساعدتك" (Captain banned phrases)
- "As an AI", "I'm an artificial intelligence" (character-breaking)

### Required register

- Warm, observant, never pushy
- Action-oriented: every message should end with something the user can do
- Specific, not generic: reference the user's actual data, goals, or context
- Iraqi/Gulf dialect for Captain content, MSA for system UI, casual English for English mode

### When to use English vs Arabic

- Arabic is the default for all user-facing content
- English is used when: the app language is set to English, or when bilingual content is needed (weekly reports include both Arabic and English summaries)
- Feature names like "My Vibe", "Zone 2", "Alchemy Kitchen", "Arena", "Tribe" are kept in English even in Arabic contexts (they are brand names)

---

## How to Use This File With Another AI

Paste this file when the AI needs to create visual designs, write copy, design notifications, produce marketing content, or extend the UI system. Pair with file 01 (Product Overview) for product context, file 03 (Captain Hamoudi) for voice-specific guidance, and file 02 (User Experience) for screen-level understanding.
