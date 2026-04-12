# AiQo — My Vibe (ذوقي) Blueprint v2

> Last updated: 2026-04-12
> Status: Wave 1 cleanup complete, Wave 2 blend engine live, Spotify integration functional on device

---

## 1. Feature Overview

**ذوقي (My Vibe)** is AiQo's dual-layer audio experience that combines:

1. **AiQo Native Sounds** — Bio-frequency synthesis engine generating real-time brainwave-optimized audio (alpha, theta, gamma frequencies) through AVAudioEngine
2. **Spotify Integration** — DJ Hamoudi curated playlists + personalized blend engine that mixes user's top tracks with Hamoudi's picks via Spotify App Remote

The system automatically transitions between 5 biological states throughout the day:

| State | Time Window | Frequency | Track Name | Hz Range |
|-------|-----------|-----------|------------|----------|
| Awakening | 5–9 AM | Serotonin activation | SerotoninFlow | ~220 Hz |
| Deep Focus | 9 AM–12 PM | Gamma-wave clarity | GammaFlow | ~174 Hz |
| Peak Energy | 12–5 PM | Dopamine ignition | SoundOfEnergy | ~196 Hz |
| Recovery | 5–9 PM | Theta-wave repair | Hypnagogic_state | ~110 Hz |
| Ego Death | 9 PM–5 AM | Hypnagogic dissolve | ThetaTrance | ~136.1 Hz |

**DJ Hamoudi** can override the Spotify layer at any time without interrupting the local bio-frequency, creating a layered audio experience.

---

## 2. Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                     MyVibeScreen (SwiftUI)                     │
│  ├─ MyVibeViewModel (@MainActor)                              │
│  │   ├─ binds: VibeOrchestrator                               │
│  │   ├─ binds: SpotifyVibeManager                             │
│  │   └─ binds: VibeAudioEngine                                │
│  └─ Subviews: Header, Timeline, FrequencyCard, SpotifyCard    │
└───────────────────────┬───────────────────────────────────────┘
                        │
          ┌─────────────▼──────────────┐
          │    VibeOrchestrator         │
          │    (Coordinator Singleton)  │
          │    @MainActor              │
          └──────┬──────────┬──────────┘
                 │          │
    ┌────────────▼┐   ┌────▼───────────────┐
    │VibeAudio    │   │SpotifyVibeManager  │
    │Engine       │   │(SPTAppRemote +     │
    │(AVAudio     │   │ Web API)           │
    │Engine)      │   └────────┬───────────┘
    └─────────────┘            │
                    ┌──────────▼───────────┐
                    │  Blend Engine Layer   │
                    │  ├─ BlendEngine       │
                    │  │   (actor)          │
                    │  ├─ BlendPlayback     │
                    │  │   Controller       │
                    │  └─ HamoudiBlend      │
                    │      ViewModel        │
                    └──────────────────────┘
```

---

## 3. File Inventory

### MyVibe Core (~993 LOC)

| File | Path | Lines | Purpose |
|------|------|-------|---------|
| DailyVibeState.swift | AiQo/Features/MyVibe/ | 95 | 5 biological states, time windows, frequency labels, vibeMode mapping |
| MyVibeScreen.swift | AiQo/Features/MyVibe/ | 425 | Main screen: DJ header, timeline, frequency card, Spotify card, search bar |
| MyVibeViewModel.swift | AiQo/Features/MyVibe/ | 110 | @MainActor state management, bindings to orchestrator/Spotify/engine |
| MyVibeSubviews.swift | AiQo/Features/MyVibe/ | 210 | MyVibeBackground (light/dark), VibeTimelineNode, VibeWaveformView |
| VibeOrchestrator.swift | AiQo/Features/MyVibe/ | 153 | Coordinator: syncs DailyVibeState to audio + Spotify, 30s auto-scheduler, DJ override |

### Blend Engine (~320 LOC)

| File | Path | Lines | Purpose |
|------|------|-------|---------|
| BlendModels.swift | AiQo/Features/MyVibe/Blend/ | 56 | BlendTrackItem, BlendSourceTag, BlendConfiguration, BlendError |
| BlendEngine.swift | AiQo/Features/MyVibe/Blend/ | 61 | Actor: builds in-memory queue with seeded LCG shuffle, daily-stable |
| BlendPlaybackController.swift | AiQo/Features/MyVibe/Blend/ | 103 | @MainActor: transport controls, source tracking, SpotifyVibeManager bridge |
| HamoudiBlendViewModel.swift | AiQo/Features/MyVibe/Blend/ | 100 | Orchestrates: Spotify auth → fetch URIs → build blend → start playback |

### Home Integration (~621 LOC)

| File | Path | Lines | Purpose |
|------|------|-------|---------|
| HamoudiDJPlaylistView.swift | AiQo/Features/Home/ | 621 | Full blend UI: empty/auth/loading/playing states, transport, error alerts |
| VibeControlSheet.swift | AiQo/Features/Home/ | 90 | Sheet container with AiQo/Spotify segment picker |
| VibeControlSheetLogic.swift | AiQo/Features/Home/ | ~200 | Spotify content, blend button (feature-flagged), playlist cards |
| VibeControlSupport.swift | AiQo/Features/Home/ | 184 | RoutePickerView, VibeMode enum, VibePlaybackSource, VibeControlViewModel |

### Core Managers

| File | Path | Lines | Purpose |
|------|------|-------|---------|
| SpotifyVibeManager.swift | AiQo/Core/ | 1,426 | Spotify SDK: auth, playback, blend queue, Web API, Keychain token |
| VibeAudioEngine.swift | AiQo/Core/ | 829 | AVAudioEngine: dual-slot crossfade, frequency synthesis, day profiles |
| AiQoAudioManager.swift | AiQo/Core/ | 343 | AVQueuePlayer: ambient loops, speech ducking |
| KeychainStore.swift | AiQo/Core/Keychain/ | 38 | Security.framework wrapper: set/get/delete generic passwords |
| AiQoFeatureFlags.swift | AiQo/Core/Config/ | 8 | Reads HAMOUDI_BLEND_ENABLED from Info.plist |
| PrivacySanitizer.swift | AiQo/Features/Captain/ | 439 | PII redaction, sanitized logging, kitchen image EXIF strip |

**Total: ~4,500 LOC**

---

## 4. Core Components

### 4.1 VibeOrchestrator

**File:** `AiQo/Features/MyVibe/VibeOrchestrator.swift` (153 lines)
**Role:** Single coordinator that keeps the two audio layers in sync.

```
@MainActor final class VibeOrchestrator: ObservableObject
├── @Published currentState: DailyVibeState
├── @Published isActive: Bool
├── @Published spotifyOverrideActive: Bool
├── @Published overridePlaylistName: String?
│
├── activate(mixWithOthers:)     // Start both layers
├── deactivate()                  // Stop everything
├── pause() / resume()            // Both layers
├── overrideSpotifyPlaylist(uri:) // DJ Hamoudi override (Spotify only)
├── clearSpotifyOverride()        // Return to auto playlist
├── forceState(_:)                // Manual state from timeline tap
└── checkForTransition()          // 30s poll for day-part changes
```

**Key behavior:** DJ override changes ONLY the Spotify playlist — the bio-frequency layer keeps playing the current state's frequency. This creates the dual-layer experience.

### 4.2 VibeAudioEngine

**File:** `AiQo/Core/VibeAudioEngine.swift` (829 lines)
**Role:** Real-time audio synthesis using AVAudioEngine.

- **Dual-slot crossfade** between primary/secondary players
- **TonePreset** per VibeMode: baseFrequency, supportFrequency, shimmerFrequency, pulseFrequency
- **VibeDayProfile** persisted to UserDefaults (morning/noon/afternoon/night presets)
- **Interruption handling** with automatic resume

### 4.3 SpotifyVibeManager

**File:** `AiQo/Core/SpotifyVibeManager.swift` (1,426 lines)
**Role:** All Spotify communication — auth, playback, blend.

**Two-track auth:**
1. **App Remote** (SPTSessionManager) — opens Spotify for consent, gets session token for playback control
2. **Web API** (PKCE via ASWebAuthenticationSession) — gets OAuth token for top tracks / playlist data

**Connection lifecycle:**
- `connect()` → `sessionManager.initiateSession()` → Spotify opens → user consents → callback → `connectAppRemote()`
- Background: socket disconnects (normal) → `shouldReconnectWhenActive = true`
- Foreground: 1s delay → `connectAppRemote()` with cached session
- Retry: 3 attempts with exponential backoff (1.5s × attempt count)
- All retries fail → fresh auth initiated

**Scopes:**
- SPTScope: `appRemoteControl`, `playlistReadPrivate`, `userTopRead`, `userReadPlaybackState`, `userModifyPlaybackState`
- Web API: same 5 scopes (string format)
- **NO** `playlist-modify-public` or `playlist-modify-private` — we never create playlists

### 4.4 BlendEngine

**File:** `AiQo/Features/MyVibe/Blend/BlendEngine.swift` (61 lines)
**Role:** Actor-isolated track queue builder. Zero metadata storage.

```
actor BlendEngine {
    func build(userTopURIs:, masterURIs:, config:) throws -> [BlendTrackItem]
}
```

- **Input:** Arrays of Spotify URIs only (no track names/artists)
- **Algorithm:** Seeded Fisher-Yates shuffle using LCG PRNG (daily seed = epoch / 86400)
- **Output:** `[BlendTrackItem]` — each item is just `(uri: String, source: BlendSourceTag)`
- **Fallback:** If masterURIs empty, uses 100% user tracks (no error thrown)

### 4.5 BlendPlaybackController

**File:** `AiQo/Features/MyVibe/Blend/BlendPlaybackController.swift` (103 lines)
**Role:** Transport controls + source tracking.

```
@MainActor final class BlendPlaybackController: ObservableObject
├── @Published currentSource: BlendSourceTag?
├── @Published isPlaying: Bool
├── @Published error: BlendError?
│
├── startBlend(tracks:)    // Build lookup, play first track, enqueue rest
├── togglePlayPause()
├── skipNext() / skipPrevious()
└── stop()                 // Clear all state
```

Bridges to `SpotifyVibeManager.playBlendQueue()` for actual playback. Observes `currentBlendSource` for source badge updates.

---

## 5. Data Models

### DailyVibeState
```swift
enum DailyVibeState: String, CaseIterable, Identifiable, Codable {
    case awakening, deepFocus, peakEnergy, recovery, egoDeath
    var frequencyLabel: String    // e.g., "GammaFlow"
    var vibeMode: VibeMode
    var spotifyURI: String
    var timeWindow: String        // e.g., "9 AM – 12 PM"
    static func current(for date:) -> DailyVibeState  // Time-based resolution
}
```

### VibeMode
```swift
enum VibeMode: String, CaseIterable, Identifiable, Codable {
    case awakening, deepFocus, egoDeath, energy, recovery
    var aiqoTrackName: String     // Audio file name
    var spotifyURI: String        // Hardcoded Spotify playlist URI
    var accentColors: [Color]     // UI gradient
}
```

### Blend Models
```swift
enum BlendSourceTag: String, Codable, Equatable { case user, hamoudi }
struct BlendTrackItem: Identifiable, Equatable { let uri: String; let source: BlendSourceTag }
struct BlendConfiguration: Sendable { let userShare: Double; let totalTracks: Int; let masterPlaylistId: String }
enum BlendError: LocalizedError, Equatable { /* 8 cases with localized descriptions */ }
```

---

## 6. Spotify Integration

### Auth Flow Diagram

```
User taps "Connect" ──► sessionManager.initiateSession()
                              │
                    ┌─────────▼──────────┐
                    │   Spotify app opens │
                    │   User grants auth  │
                    └─────────┬──────────┘
                              │
              AiQo callback: aiqo://spotify-login-callback
                              │
                    ┌─────────▼──────────┐
                    │ sessionManager      │
                    │ .didInitiate()      │
                    │ → SPTSession token  │
                    └─────────┬──────────┘
                              │
                    connectAppRemote(token)
                              │
                    ┌─────────▼──────────┐
                    │ App Remote socket   │
                    │ on port 9095        │
                    │ (local IPC)         │
                    └─────────┬──────────┘
                              │
                    playerAPI.subscribe()
                    → isConnected = true
```

### Web API (PKCE) Flow
```
authorizeWebAPI() → ASWebAuthenticationSession
    → code_challenge (SHA256)
    → Spotify web consent
    → auth code callback
    → exchangeCodeForToken()
    → POST /api/token (code + verifier)
    → webAPIToken → KeychainStore
```

### Token Storage
| Token | Storage | Key | Lifecycle |
|-------|---------|-----|-----------|
| App Remote session | SPTSessionManager (in-memory) | N/A | Ephemeral, per app launch |
| Web API token | Keychain | `aiqo.spotify.webapi.token` | Persistent, survives restart |
| Legacy token | UserDefaults (migrated) | `spotify_web_api_token` | Deleted on migration |

### Connection Retry Logic
1. Attempt 1 → fail → wait 1.5s
2. Attempt 2 → fail → open `spotify:` URL to wake app → wait 3.0s
3. Attempt 3 → fail → wait 4.5s
4. All fail → initiate fresh auth flow (clears stale session)

### Simulator Support
`#if !targetEnvironment(simulator)` wraps all Spotify SDK code. Simulator build provides stub `SpotifyVibeManager` with matching interface but all methods return errors/no-ops.

---

## 7. UI System

### View Hierarchy
```
MyVibeScreen
├── ScrollView
│   ├── djHamoudiHeader (260pt hero image + gradient scrim)
│   ├── vibeTimeline (horizontal scroll of 5 VibeTimelineNodes)
│   ├── frequencyCard (waveform icon + play/pause + VibeWaveformView)
│   └── spotifyCard (track name + artist + DJ override badge)
├── djSearchBar (safe area inset, bottom)
└── MyVibeBackground (conditional light/dark based on isDJModeActive)

VibeControlSheet (presented as sheet from home)
├── backgroundArtwork (Captain_Hamoudi_DJ image)
├── topContent (source picker: Spotify / AiQo)
├── aiqoSoundsContent (vibeGrid of 5 modes)
├── spotifyContent (connect button + blend button + playlist cards)
└── compactControlCard (bottom safe area)

HamoudiDJPlaylistView (presented as sheet from blend button)
├── headerBar (title + close button)
├── States: empty / auth / loading / playing
├── nowPlayingCard (source badge + waveform)
├── queueVisualization (10-column dot grid)
├── transportControls (skip/play/pause)
└── footer (privacy note + Spotify attribution)
```

### Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| Primary Mint | #8AE3D1 | Main accent, bio-frequency, badges |
| Mint Vibrant | #5ECDB7 | Buttons, gradients |
| Sand | #EBCF97 | Hamoudi source badge |
| Spotify Green | #1DB954 | Spotify status indicators |
| Light BG Top | #FAFAF7 | Light mode gradient start |
| Light BG Bottom | #F3F4F1 | Light mode gradient end |
| Awakening | #FFD166 | Yellow sunrise accent |
| Deep Focus | #8AE3D1 | Mint clarity accent |
| Peak Energy | #FF9F43 | Orange dopamine accent |
| Recovery | #A78BFA | Purple theta accent |
| Ego Death | #6366F1 | Indigo hypnagogic accent |

### Dark/Light Mode
- **Default:** Light background (`#FAFAF7` → `#F3F4F1`)
- **DJ Mode Active:** Dark background (`Color.black` + radial accent glow)
- **Transition:** `.animation(.easeInOut(duration: 0.6), value: isDJModeActive)`
- **Cards:** `.environment(\.colorScheme, isDJModeActive ? .dark : .light)` on `.ultraThinMaterial`

### Typography
| Style | Spec | Usage |
|-------|------|-------|
| Monospaced Caps | 10-11pt, .heavy, .monospaced, 1.2-2.4 tracking | Section labels |
| Headline | 28pt, .bold, .rounded | DJ Hamoudi title |
| Card Title | 18-20pt, .bold/.heavy, .rounded | Card headings |
| Body | 13-15pt, .medium, .rounded | Subtitles, status |
| Micro | 10-11pt, .medium | Attribution, timestamps |

### Glass Card Pattern
```swift
RoundedRectangle(cornerRadius: 22-24, style: .continuous)
    .fill(.ultraThinMaterial)
    .environment(\.colorScheme, isDJModeActive ? .dark : .light)
    .overlay { stroke(accent.opacity(0.08-0.12), lineWidth: 1) }
    .shadow(color: .black.opacity(0.04-0.18), radius: 12-16)
```

### Animations
| Animation | Spec | Where |
|-----------|------|-------|
| DJ mode toggle | `.easeInOut(duration: 0.6)` | Background, text colors |
| State transition | `.easeInOut(duration: 1.2)` | Background accent shift |
| Timeline select | `.spring(response: 0.4, dampingFraction: 0.78)` | Node selection |
| Play button | `.spring(response: 0.3, dampingFraction: 0.7)` | Scale/opacity |
| Pulse ring | `1.08x scale, .repeatForever(autoreverses: true)` | Active playing node |
| Waveform | 24 bars, random 6-28pt, 0.8s timer, 0.04s delay | Bio-frequency card |
| Source badge | `.opacity.combined(with: .scale)` | Blend now-playing |
| Loading spin | `.linear(duration: 1.2).repeatForever` | Blend loading state |

### RTL Support
- HamoudiDJPlaylistView: `.environment(\.layoutDirection, .rightToLeft)`
- All strings use `NSLocalizedString()` or `.localized` extension

---

## 8. Localization Keys

### vibe.* keys (ar / en)
```
vibe.title = "ذوقي" / "My Vibe"
vibe.audioSource = "مصدر الصوت" / "Audio Source"
vibe.aiqoSounds = "أصوات AiQo" / "AiQo Sounds"
vibe.spotify = "Spotify"
vibe.live = "LIVE" / "LIVE"
vibe.idle = "IDLE" / "IDLE"
vibe.myVibe = "MY VIBE"
vibe.djHamoudi = "DJ حمودي" / "DJ Hamoudi"
vibe.bioTimeline = "BIO TIMELINE"
vibe.bioFrequency = "BIO-FREQUENCY"
vibe.spotifyLabel = "SPOTIFY"
vibe.connected = "CONNECTED"
vibe.djOverride = "DJ Override"
vibe.djPlaceholder = "اسأل DJ حمودي..." / "Ask DJ Hamoudi..."
```

### blend.* keys (ar / en)
```
blend.title = "ذوقي" / "My Vibe"
blend.subtitle = "مزيج حمودي + ذوقك" / "Hamoudi + your taste"
blend.close = "أغلق" / "Close"
blend.empty.title = "وصّل سبوتيفاي" / "Connect Spotify"
blend.empty.subtitle = "عشان حمودي يعرف ذوقك ويدمجه وياه" / "So Hamoudi can learn your taste and blend with it"
blend.empty.cta = "ربط سبوتيفاي" / "Connect Spotify"
blend.cta.title = "Hamoudi+you+DJ 🎧"
blend.cta.subtitle = "مزيج من ذوقك واختيارات حمودي" / "A blend of your taste and Hamoudi's picks"
blend.source.user = "من ذوقك" / "From your taste"
blend.source.hamoudi = "اختيار حمودي 🎧" / "Hamoudi's pick 🎧"
blend.queue.title = "القائمة" / "Queue"
blend.regenerate = "مزيج جديد" / "New Mix"
blend.footer.privacy = "AiQo ما يحفظ أغانيك. التشغيل عبر تطبيق Spotify." / "AiQo doesn't store your music. Playback runs through the Spotify app."
blend.disabled.placeholder = "هذي الميزة قريباً" / "This feature is coming soon"
blend.loading = "يحضّر المزيج..." / "Preparing the blend..."
blend.error.no_spotify_app = "ثبّت تطبيق Spotify أولاً" / "Please install the Spotify app first"
blend.error.requires_premium = "محتاج Spotify Premium لهاي الميزة" / "Spotify Premium is required"
blend.error.auth_expired = "انتهت صلاحية الاتصال. وصّل مرة ثانية." / "Connection expired. Please reconnect."
blend.error.no_master_tracks = "صار خطأ بسحب قائمة حمودي. جرب مرة ثانية." / "Couldn't load Hamoudi's playlist."
blend.error.rate_limited = "كثرت الطلبات. جرب بعد دقيقة." / "Too many requests."
```

---

## 9. Privacy & Security

### Data Classification

| Data | Storage | Sensitivity |
|------|---------|-------------|
| Web API token | Keychain (`aiqo.spotify.webapi.token`) | High — encrypted at rest |
| App Remote session | In-memory (SPTSessionManager) | Medium — ephemeral |
| Blend source lookup | In-memory (`[String: BlendSource]`) | Low — URIs only |
| Blend queue | In-memory (`[BlendTrackItem]`) | Low — URIs only |
| Track names/artists | **NEVER stored** | N/A — read from playerState, displayed, discarded |
| Vibe preferences | UserDefaults | Low — playback source, volume, intensity |

### PrivacySanitizer Integration
- All `SpotifyVibeManager` logging → `PrivacySanitizer.log()`
- Spotify URIs auto-redacted: `spotify:track:abc123` → `spotify:<redacted>`
- Token exchange response body → deleted entirely (never logged)
- Track names from playerState → logged as `spotify:<redacted>` only

### What We Never Do
- Create playlists in user's Spotify account
- Store track titles, artist names, album names, or cover art to disk
- Display track metadata in our UI (only source badges: "من ذوقك" / "اختيار حمودي")
- Log user IDs or tokens
- Send track data to our servers

---

## 10. Feature Flags

### Info.plist

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `HAMOUDI_BLEND_ENABLED` | Boolean | `true` | Gates blend button in VibeControlSheetLogic + HamoudiDJPlaylistView body |
| `HAMOUDI_BLEND_RATIO` | Double | `0.6` | User share in blend (0.0 = all Hamoudi, 1.0 = all user) |
| `SPOTIFY_CLIENT_ID` | String | `$(SPOTIFY_CLIENT_ID)` | Resolved from xcconfig at build time |

### AiQoFeatureFlags.swift
```swift
enum AiQoFeatureFlags {
    static var hamoudiBlendEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "HAMOUDI_BLEND_ENABLED") as? Bool ?? false
    }
}
```

---

## 11. Known Issues & Tech Debt

### Must Fix Before App Store

| # | Issue | File | Priority |
|---|-------|------|----------|
| 1 | Master playlist `14YVMyaZsefyZMgEIIicao` returns 403 (private) | SpotifyVibeManager.swift | **P0** — make playlist public on Spotify |
| 2 | `print()` in AiQoAudioManager (lines 104, 257) not routed through PrivacySanitizer | AiQoAudioManager.swift | P1 |
| 3 | Spotify Development Mode — must add test users or request Extended Quota | Spotify Dashboard | P0 |

### Should Fix

| # | Issue | File | Impact |
|---|-------|------|--------|
| 4 | VibeDayProfile stored in UserDefaults (line 172) — should be Keychain | VibeAudioEngine.swift | Low risk — preferences not secrets |
| 5 | VibeControlViewModel uses UserDefaults for source/mix/intensity | VibeControlSupport.swift | Low risk — non-sensitive preferences |
| 6 | 5 Spotify playlist URIs hardcoded in VibeMode enum | VibeControlSupport.swift | Config-driven would be better |
| 7 | Old `BlendTrack` struct with metadata fields still exists (unused) | SpotifyVibeManager.swift:988 | Dead code — delete |
| 8 | Old `BlendQueueTrack` and `BlendSource` still exist alongside new types | SpotifyVibeManager.swift:1007-1016 | Rename/consolidate |
| 9 | SpotifyVibeManager at 1,426 lines — too large | SpotifyVibeManager.swift | Split into auth/playback/blend extensions |

---

## 12. Manual Test Checklist

### Spotify Connection
- [ ] Open VibeControlSheet → Spotify tab → tap "Connect to Spotify"
- [ ] Spotify opens → grant permission → return to AiQo
- [ ] Button changes to "Spotify Connected"
- [ ] Go to background → return → verify auto-reconnect (no error popup)
- [ ] Tap "سجل خروج من سبوتيفاي" → verify full reset

### Blend Playback
- [ ] Tap "Hamoudi+you+DJ" → blend sheet opens
- [ ] If not connected → shows "وصّل سبوتيفاي" empty state
- [ ] After connecting → tap "ابدأ المزيج"
- [ ] Spotify starts playing within 3 seconds
- [ ] Source badge shows "من ذوقك" or "اختيار حمودي" — NOT track names
- [ ] Skip tracks → badge updates
- [ ] Tap pause → tap play → resumes
- [ ] Tap "مزيج جديد" → new queue builds and plays

### AiQo Native Sounds
- [ ] Switch to "أصوات AiQo" tab
- [ ] Tap Deep Focus → audio plays
- [ ] Tap different mode → crossfade transition
- [ ] Verify bio-frequency card shows correct label
- [ ] Mix with Spotify: enable both layers simultaneously

### Error States
- [ ] Uninstall Spotify → tap connect → error "ثبّت تطبيق Spotify أولاً"
- [ ] Force-quit Spotify → tap play → graceful error
- [ ] Disable internet → tap blend → appropriate error
- [ ] Check Console.app → verify zero track names or user IDs in logs

### Feature Flag
- [ ] Set `HAMOUDI_BLEND_ENABLED = false` → blend button hidden, HamoudiDJPlaylistView shows "هذي الميزة قريباً"
- [ ] Set `HAMOUDI_BLEND_ENABLED = true` → full blend feature active

---

## 13. App Store Submission Checklist

- [ ] Spotify Extended Quota Mode approved (exit Development Mode)
- [ ] Master playlist `14YVMyaZsefyZMgEIIicao` set to Public
- [ ] "Powered by Spotify" attribution visible in blend footer
- [ ] Privacy policy updated for Spotify data usage
- [ ] `HAMOUDI_BLEND_ENABLED = true` in production Info.plist
- [ ] `spotify-action` in LSApplicationQueriesSchemes
- [ ] App Store screenshots capture blend UI
- [ ] Test with Spotify Free account → verify Premium-required error
