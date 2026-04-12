# AiQo — My Vibe Module Blueprint
**Generated:** 2026-04-11  
**Module version:** unversioned  
**Status:** Production (Hamoudi Blend Engine: In Development — feature-flagged OFF)

---

## ١. Executive Summary (نظرة عامة)

My Vibe (ذوقي) is AiQo's ambient audio and music curation module. It provides two layered audio sub-systems that can run independently or simultaneously:

1. **AiQo Native Audio** — A procedurally-generated binaural tone engine (`VibeAudioEngine`) that synthesizes ambient frequencies mapped to five biological states: Awakening, Deep Focus, Peak Energy, Recovery, and Ego Death. Additionally, an `AiQoAudioManager` can play pre-recorded `.m4a` ambient tracks from the asset catalog. Both systems support background playback, audio session mixing, interruption handling, and Now Playing integration.

2. **Spotify Integration** — A full Spotify iOS SDK integration (`SpotifyVibeManager`) that connects to the Spotify app via `SPTAppRemote` for playback control, and uses the Spotify Web API (via PKCE OAuth) for playlist operations. Each biological state maps to a curated Spotify playlist. DJ Hamoudi can override the Spotify layer without interrupting the local bio-frequency.

3. **Hamoudi Blend Engine** — A new in-memory queue system that blends the user's Spotify top tracks (60%) with picks from Hamoudi's master playlist (40%). Uses seeded Fisher-Yates shuffle for daily-stable ordering. Playback occurs via Spotify Connect enqueue. The blend feature is **currently feature-flagged OFF** (`HAMOUDI_BLEND_ENABLED = false` in Info.plist). The `HamoudiDJPlaylistView` and blend queue logic in `SpotifyVibeManager` are fully implemented but gated.

**Known Issues:** The legacy `generateHamoudiBlendPlaylist()` method creates playlists in the user's Spotify account, which contradicts the compliance goal of no playlist creation. The newer `buildBlendQueue()` method operates in-memory only. Both coexist in `SpotifyVibeManager`. The Web API token is stored in `UserDefaults` (plaintext), not Keychain.

---

## ٢. File Tree

```
AiQo/Features/MyVibe/
├── MyVibeScreen.swift                          (423 lines)
├── MyVibeSubviews.swift                        (199 lines)
├── VibeOrchestrator.swift                      (153 lines)
├── MyVibeViewModel.swift                       (105 lines)
└── DailyVibeState.swift                        (95 lines)

AiQo/Features/Home/  (My Vibe related files only)
├── VibeControlSheet.swift                      (89 lines)
├── VibeControlSheetLogic.swift                 (~1044 lines)
├── VibeControlComponents.swift                 (286 lines)
├── VibeControlSupport.swift                    (183 lines)
├── SpotifyVibeCard.swift                       (262 lines)
├── HamoudiDJPlaylistView.swift                 (595 lines)
└── DJCaptainChatView.swift                     (465 lines)

AiQo/Core/
├── SpotifyVibeManager.swift                    (1577 lines)
├── VibeAudioEngine.swift                       (829 lines)
└── AiQoAudioManager.swift                      (343 lines)

AiQo/Resources/Assets.xcassets/  (audio datasets)
├── SerotoninFlow.dataset/SerotoninFlow.m4a
├── GammaFlow.dataset/GammaFlow.m4a
├── SoundOfEnergy.dataset/SoundOfEnergy.m4a
├── ThetaTrance.dataset/ThetaTrance.m4a
└── Hypnagogic_state.dataset/Hypnagogic_state.m4a

AiQo/Resources/Assets.xcassets/  (image assets)
├── Captain_Hamoudi_DJ.imageset/
├── vibe_ icon.imageset/
└── imageKitchenHamoudi.imageset/

AiQo/Features/Captain/  (shared dependency)
└── CaptainModels.swift                         (contains SpotifyRecommendation struct)
```

**Total MyVibe-specific Swift files:** 14  
**Total lines of code (MyVibe-specific):** ~5,648  
**Total lines including shared dependencies (SpotifyVibeManager, VibeAudioEngine, AiQoAudioManager):** ~8,397

---

## ٣. Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                         VIEWS                                    │
│                                                                  │
│  MyVibeScreen ─────────────── VibeControlSheet                   │
│  ├── djHamoudiHeader          ├── sourceSection (Picker)         │
│  ├── vibeTimeline             ├── aiqoSoundsContent / vibeGrid   │
│  ├── frequencyCard            ├── spotifyContent                 │
│  ├── spotifyCard              ├── compactControlCard             │
│  └── djSearchBar              └── detailsSheet                   │
│                                                                  │
│  HamoudiDJPlaylistView        DJCaptainChatView                  │
│  ├── blendCTAButton           └── (delegates to CaptainViewModel)│
│  ├── nowPlayingCard                                              │
│  ├── queueVisualization       SpotifyVibeCard                    │
│  └── transportControls        └── opens Spotify URI              │
│                                                                  │
│  MyVibeSubviews                                                  │
│  ├── MyVibeBackground                                            │
│  ├── VibeTimelineNode                                            │
│  └── VibeWaveformView                                            │
│                                                                  │
│  VibeControlComponents                                           │
│  ├── VibeDashboardTriggerButton                                  │
│  ├── VibeModeCard                                                │
│  ├── StatusPill                                                  │
│  ├── AiQoSoundGlyph                                              │
│  └── SpotifyGlyph                                                │
└───────────────────────┬──────────────────────────────────────────┘
                        │ @StateObject / @ObservedObject
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│                      VIEW MODELS                                 │
│                                                                  │
│  MyVibeViewModel              VibeControlViewModel               │
│  ├── binds to Orchestrator    ├── selectedMode                   │
│  ├── binds to SpotifyVM       ├── selectedSource                 │
│  ├── binds to VibeEngine      ├── mixWithOthers                  │
│  └── togglePlayback()         └── nativeIntensity                │
│                                                                  │
│  VibeOrchestrator (singleton, @MainActor)                        │
│  ├── activate() / deactivate()                                   │
│  ├── pause() / resume()                                          │
│  ├── forceState()                                                │
│  ├── overrideSpotifyPlaylist() (DJ Hamoudi)                      │
│  ├── clearSpotifyOverride()                                      │
│  └── 30s auto-transition scheduler                               │
└───────────────────────┬──────────────────────────────────────────┘
                        │ .shared singletons
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│                       SERVICES                                   │
│                                                                  │
│  VibeAudioEngine (AVAudioEngine)                                 │
│  ├── Procedural tone synthesis (binaural)                        │
│  ├── Dual-player crossfade                                       │
│  ├── Background + Now Playing                                    │
│  ├── Interruption + route change handling                        │
│  └── Profile persistence (UserDefaults)                          │
│                                                                  │
│  AiQoAudioManager (AVQueuePlayer)                                │
│  ├── Plays .m4a asset tracks                                     │
│  ├── Looped playback                                             │
│  ├── Speech ducking                                              │
│  └── Interruption handling                                       │
│                                                                  │
│  SpotifyVibeManager (SPTAppRemote + Web API)                     │
│  ├── OAuth via SPTSessionManager                                 │
│  ├── PKCE Web API auth (ASWebAuthenticationSession)              │
│  ├── Playback: play / pause / stop / skip                        │
│  ├── Player state subscription                                   │
│  ├── Album art fetching                                          │
│  ├── Blend playlist generation (legacy — creates playlists)      │
│  ├── Blend queue engine (new — in-memory only)                   │
│  └── Blend playback via enqueue                                  │
└───────────────────────┬──────────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────────┐
│                    EXTERNAL APIs / SDKs                           │
│                                                                  │
│  SpotifyiOS.framework (SPTAppRemote, SPTSessionManager)          │
│  AVFoundation (AVAudioEngine, AVAudioSession, AVQueuePlayer)     │
│  MediaPlayer (MPNowPlayingInfoCenter, MPRemoteCommandCenter)     │
│  AuthenticationServices (ASWebAuthenticationSession)             │
│  CryptoKit (SHA256 for PKCE challenge)                           │
└──────────────────────────────────────────────────────────────────┘
```

**State Ownership:**
- `VibeOrchestrator` owns the current `DailyVibeState` and coordinates both audio layers
- `SpotifyVibeManager` owns all Spotify connection/playback state
- `VibeAudioEngine` owns the procedural tone playback state and `VibeDayProfile`
- `AiQoAudioManager` owns the looped ambient track playback state
- `MyVibeViewModel` mirrors state from all three services via Combine bindings
- `VibeControlViewModel` owns user preferences (source, mode, intensity, mix toggle)

---

## ٤. Type Catalog

| File | Type | Kind | Purpose | Public API | Dependencies |
|------|------|------|---------|------------|--------------|
| DailyVibeState.swift:6 | `DailyVibeState` | enum | 5 biological states mapped to time-of-day | `.current()`, `.title`, `.frequencyLabel`, `.vibeMode`, `.spotifyURI`, `.timeWindow`, `.systemIcon`, `.subtitle` | `VibeMode` |
| MyVibeViewModel.swift:6 | `MyVibeViewModel` | class (@MainActor) | ViewModel for MyVibeScreen | `togglePlayback()`, `selectState()`, `stop()`, `submitDJSearch()` | `VibeOrchestrator`, `VibeAudioEngine`, `SpotifyVibeManager`, Combine |
| VibeOrchestrator.swift:13 | `VibeOrchestrator` | class (@MainActor) | Coordinates bio-frequency + Spotify layers | `activate()`, `deactivate()`, `pause()`, `resume()`, `forceState()`, `overrideSpotifyPlaylist()`, `clearSpotifyOverride()` | `VibeAudioEngine`, `SpotifyVibeManager`, `AiQoAudioManager` |
| MyVibeScreen.swift:3 | `MyVibeScreen` | struct (View) | Main My Vibe screen | body | `MyVibeViewModel`, `CaptainViewModel`, `DJCaptainChatView` |
| MyVibeSubviews.swift:5 | `MyVibeBackground` | struct (View) | Gradient background per state | body | `DailyVibeState` |
| MyVibeSubviews.swift:47 | `VibeTimelineNode` | struct (View) | Timeline circle + label | body | `DailyVibeState` |
| MyVibeSubviews.swift:133 | `VibeWaveformView` | struct (View) | Animated bar visualizer | body | None |
| VibeAudioEngine.swift:7 | `VibeDayPart` | enum | 4 day parts (morning/noon/afternoon/night) | `.current()`, `.title` | None |
| VibeAudioEngine.swift:44 | `VibeDayProfile` | struct | Mode assignment per day-part | `mode(for:)`, `set(_:for:)`, `.default` | `VibeMode`, `VibeDayPart` |
| VibeAudioEngine.swift:88 | `VibeAudioState` | struct | Playback state snapshot | `.playbackState`, `.currentMode`, `.isActive`, `.intensity`, `.detailText` | `VibeMode`, `VibeDayPart`, `VibePlaybackState` |
| VibeAudioEngine.swift:138 | `VibeAudioEngine` | class (singleton) | Procedural binaural tone engine | `start()`, `stop()`, `pause()`, `resume()`, `switch(to:)`, `setIntensity()` | AVFoundation, MediaPlayer |
| AiQoAudioManager.swift:7 | `AiQoAudioManager` | class (@MainActor, singleton) | Looped .m4a ambient player | `playAmbient()`, `pauseAmbient()`, `stopAmbient()`, `setVolume()`, `setMixWithOthers()`, `beginSpeechDucking()`, `endSpeechDucking()` | AVFoundation |
| SpotifyVibeManager.swift:16 | `SpotifyVibeManager` | class (singleton) | Spotify SDK + Web API manager | `connect()`, `playVibe()`, `pauseVibe()`, `stopVibe()`, `skipNext()`, `skipPrevious()`, `handleURL()`, `authorizeWebAPI()`, `generateHamoudiBlendPlaylist()`, `buildBlendQueue()`, `playBlendQueue()`, `logoutSpotify()` | SpotifyiOS, AuthenticationServices, CryptoKit |
| SpotifyVibeManager.swift:10 | `VibePlaybackState` | enum | Stopped/Paused/Playing | `.rawValue` | None |
| SpotifyVibeManager.swift:1296 | `BlendTrack` | struct | Full track metadata for blend | `.name`, `.artist`, `.uri`, `.formattedDuration` | None |
| SpotifyVibeManager.swift:1315 | `BlendSource` | enum | `.user` / `.hamoudi` | `.rawValue` | None |
| SpotifyVibeManager.swift:1320 | `BlendQueueTrack` | struct | Lightweight queue entry (URI + source) | `.uri`, `.source` | `BlendSource` |
| VibeControlSupport.swift:17 | `VibeMode` | enum | 5 vibe modes with metadata | `.subtitle`, `.systemIcon`, `.accentColors`, `.aiqoTrackName`, `.spotifyURI` | None |
| VibeControlSupport.swift:117 | `VibePlaybackSource` | enum | AiQo Sounds / Spotify toggle | `.localizedName` | None |
| VibeControlSupport.swift:132 | `VibeControlViewModel` | class (@MainActor) | Preferences for VibeControlSheet | `select()`, `markLastActivatedMode()` | `VibeMode`, `VibePlaybackSource` |
| VibeControlSheet.swift:2 | `VibeControlSheet` | struct (View) | Full-screen vibe control sheet | body | `VibeControlViewModel`, `SpotifyVibeManager`, `AiQoAudioManager`, `VibeAudioEngine`, `CaptainViewModel` |
| VibeControlComponents.swift:4 | `VibeDashboardTriggerButton` | struct (View) | Home screen vibe button | body | None |
| VibeControlComponents.swift:100 | `SpotifyPlaylistPreview` | struct | Playlist card data | `.title`, `.subtitle`, `.uri` | None |
| VibeControlComponents.swift:107 | `VibeModeCard` | struct (View) | Mode selection card | body | `VibeMode` |
| VibeControlComponents.swift:218 | `StatusPill` | struct (View) | Status label pill | body | None |
| VibeControlComponents.swift:238 | `AiQoSoundGlyph` | struct (View) | AiQo sound icon | body | None |
| VibeControlComponents.swift:261 | `SpotifyGlyph` | struct (View) | Spotify icon replica | body | None |
| VibeControlSupport.swift:6 | `RoutePickerView` | struct (UIViewRepresentable) | AirPlay route picker | body | AVKit |
| SpotifyVibeCard.swift:4 | `SpotifyVibeCard` | struct (View) | Card for DJ Hamoudi recommendations | body | `SpotifyRecommendation` |
| HamoudiDJPlaylistView.swift:3 | `HamoudiDJPlaylistView` | struct (View) | Blend playlist UI | body | `SpotifyVibeManager` |
| HamoudiDJPlaylistView.swift:564 | `BlendWaveformView` | struct (View) | Animated waveform for blend | body | None |
| DJCaptainChatView.swift:4 | `DJCaptainChatView` | struct (View) | DJ Hamoudi chat interface | body | `CaptainViewModel` |
| CaptainModels.swift:140 | `SpotifyRecommendation` | struct | Spotify URI + description from Captain | `.vibeName`, `.description`, `.spotifyURI` | None |

---

## ٥. AiQo Native Audio System

### Bio-Frequency Tracks (Procedural — VibeAudioEngine)

The `VibeAudioEngine` does **not** play pre-recorded files. It synthesizes binaural tones procedurally using `AVAudioEngine` with the following tone presets (`VibeAudioEngine.swift:101-136`):

| Mode | Base Freq | Support Freq | Shimmer Freq | Pulse Rate | Buffer Duration |
|------|-----------|-------------|-------------|------------|-----------------|
| Awakening | 220 Hz | 329.63 Hz | 440 Hz | 0.18 Hz | 8 seconds |
| Deep Focus | 174 Hz | 261.63 Hz | 348 Hz | 0.08 Hz | 8 seconds |
| Energy | 196 Hz | 293.66 Hz | 392 Hz | 0.22 Hz | 8 seconds |
| Recovery | 110 Hz | 165 Hz | 220 Hz | 0.07 Hz | 8 seconds |
| Ego Death | 136.1 Hz | 204.2 Hz | 272.2 Hz | 0.05 Hz | 8 seconds |

**Synthesis details** (`VibeAudioEngine.swift:456-512`):
- Stereo binaural: left channel detuned to `base * 0.995`, right to `base * 1.005` (creates ~2Hz binaural beat)
- Support tones similarly detuned (0.998 / 1.002 ratio)
- Shimmer layer at full frequency + 1% offset on right
- Pulse envelope: `0.78 + 0.22 * sin(pulse_rate * t)`
- Shimmer envelope: `0.5 + 0.5 * sin(0.03 * t)`
- Master amplitude: `0.18` (very gentle)
- Buffers cached per mode, scheduled as infinite loops

**Crossfade** (`VibeAudioEngine.swift:399-454`):
- Dual-slot architecture: primary and secondary `AVAudioPlayerNode` + `AVAudioMixerNode`
- 24-step crossfade over 2 seconds via `DispatchSourceTimer`
- Linear volume ramp from 0→target on incoming, target→0 on outgoing

**Background Playback:**
- Audio session category: `.playback` with optional `.mixWithOthers` (`VibeAudioEngine.swift:336`)
- Options: `.allowAirPlay`, `.allowBluetoothHFP`, `.allowBluetoothA2DP`
- `UIBackgroundModes`: `audio` declared in Info.plist:87

**Interruption Handling** (`VibeAudioEngine.swift:669-694`):
- `.began`: pauses playback, sets `shouldResumeAfterInterruption` flag
- `.ended`: checks `.shouldResume` option, auto-resumes if flagged

**Route Change Handling** (`VibeAudioEngine.swift:696-717`):
- `.oldDeviceUnavailable`: auto-pauses (headphone disconnection)
- `.newDeviceAvailable`: updates detail text

**Now Playing** (`VibeAudioEngine.swift:614-643`):
- Title: "My Vibe • {mode.rawValue}"
- Artist: "AiQo Sounds"
- Album: current day-part title
- Remote commands: play, pause, togglePlayPause, stop

**Profile Persistence:**
- `UserDefaults` key: `com.aiqo.vibeAudio.profile` (`VibeAudioEngine.swift:828`)
- Stores `VibeDayProfile` as JSON

### Ambient Tracks (Pre-recorded — AiQoAudioManager)

The `AiQoAudioManager` plays pre-recorded `.m4a` files as looped ambient audio.

| Track Name | Mapped From | Format | Location |
|-----------|------------|--------|----------|
| SerotoninFlow | Awakening | .m4a | Assets.xcassets dataset |
| GammaFlow | Deep Focus | .m4a | Assets.xcassets dataset |
| SoundOfEnergy | Energy (Peak Energy) | .m4a | Assets.xcassets dataset |
| ThetaTrance | Recovery → mapped to Ego Death in VibeMode | .m4a | Assets.xcassets dataset |
| Hypnagogic_state | Recovery in DailyVibeState (inconsistency) | .m4a | Assets.xcassets dataset |

**Note:** There is a mapping inconsistency between `DailyVibeState.frequencyLabel` and `VibeMode.aiqoTrackName`:
- `DailyVibeState.recovery` → frequencyLabel `"ThetaTrance"`, vibeMode `.recovery` → aiqoTrackName `"Hypnagogic_state"`
- `DailyVibeState.egoDeath` → frequencyLabel `"Hypnagogic_state"`, vibeMode `.egoDeath` → aiqoTrackName `"ThetaTrance"`
- These are swapped between the two enums.

**Playback** (`AiQoAudioManager.swift:42-84`):
- Uses `AVQueuePlayer` + `AVPlayerLooper` for seamless infinite looping
- Resolves track URLs: first checks `Bundle.main`, then falls back to `NSDataAsset` (writes to temp directory for `AVPlayer`)
- Speech ducking support: smoothly lowers volume during coaching (eased ramp via IIFE Task)

---

## ٦. Spotify Integration

### ٦.١ Authentication

**OAuth Flow (App Remote):**
1. User taps "Connect to Spotify" (`SpotifyVibeManager.swift:142`)
2. `prepareForConnection()` checks if Spotify app is installed and client ID is valid
3. If no cached session: `sessionManager.initiateSession(with: scopes, options: .default)` — launches Spotify app for OAuth
4. Spotify redirects back via URL scheme `aiqo://spotify-login-callback`
5. `handleURL()` passes to `sessionManager.application(_:open:options:)` (`SpotifyVibeManager.swift:283`)
6. `SPTSessionManagerDelegate.didInitiate(session:)` fires → `connectAppRemote(with: accessToken)` (`SpotifyVibeManager.swift:1082`)
7. `SPTAppRemoteDelegate.appRemoteDidEstablishConnection()` → subscribes to player state, plays pending URI (`SpotifyVibeManager.swift:1101`)

**Scopes Requested** (`SpotifyVibeManager.swift:42-49`):
- `appRemoteControl`
- `playlistReadPrivate`
- `playlistModifyPublic`
- `playlistModifyPrivate`
- `userTopRead`
- `userReadPlaybackState`
- `userModifyPlaybackState`

**Web API PKCE OAuth** (`SpotifyVibeManager.swift:641-745`):
1. Generates 32-byte random code verifier, base64url-encoded
2. SHA256 code challenge via CryptoKit
3. Opens `https://accounts.spotify.com/authorize` via `ASWebAuthenticationSession` with callback scheme `aiqo`
4. Exchanges authorization code for token at `https://accounts.spotify.com/api/token`
5. Token stored in `UserDefaults` key `"spotify_web_api_token"` (plaintext)

**Web API Scopes** (`SpotifyVibeManager.swift:73`):
`playlist-read-private playlist-modify-public playlist-modify-private user-top-read user-read-playback-state user-modify-playback-state`

**Token Storage:**
- App Remote token: managed by `SPTSessionManager` (in-memory session)
- Web API token: `UserDefaults.standard` key `"spotify_web_api_token"` — **NOT Keychain**
- On 401/403 responses, token is auto-cleared and `isWebAPIAuthorized` set to `false` (`SpotifyVibeManager.swift:870-875`)

**Token Refresh:**
- App Remote: automatic via `SPTSessionManager.didRenew(session:)` delegate
- Web API: No refresh token flow implemented. User must re-authorize on expiry.

**Error Handling:**
- All Spotify operations report errors via `@Published lastErrorMessage` / `lastErrorCode`
- Thread-safe state updates via explicit main thread dispatch

### ٦.٢ Web API Calls

| Endpoint | Method | Purpose | Caller | Auth |
|----------|--------|---------|--------|------|
| `GET /v1/playlists/{id}/tracks?limit=100` | GET | Fetch master playlist tracks (legacy blend) | `fetchMasterPlaylistTracks()` | Bearer web token |
| `GET /v1/me/top/tracks?limit=10&time_range=medium_term` | GET | Fetch user top tracks (legacy blend) | `fetchUserTopTracks()` | Bearer web token |
| `GET /v1/me` | GET | Fetch user ID for playlist creation | `fetchCurrentUserID()` | Bearer web token |
| `POST /v1/users/{id}/playlists` | POST | Create blend playlist (legacy) | `createPlaylist()` | Bearer web token |
| `POST /v1/playlists/{id}/tracks` | POST | Add tracks to blend playlist (legacy) | `addTracksToPlaylist()` | Bearer web token |
| `GET /v1/playlists/{id}/tracks?limit=50` | GET | Fetch created playlist tracks | `fetchPlaylistTracks()` | Bearer web token |
| `GET /v1/playlists/{id}/tracks?limit=50&fields=items(track(uri))` | GET | Fetch URIs only from master playlist (new blend engine) | `fetchTrackURIs()` | Bearer web token |
| `GET /v1/me/top/tracks?limit=10&time_range=short_term` | GET | Fetch user top track URIs (new blend engine) | `fetchTrackURIs()` | Bearer web token |
| `POST /api/token` (accounts.spotify.com) | POST | Exchange PKCE code for access token | `exchangeCodeForToken()` | Client ID + code verifier |

### ٦.٣ iOS SDK Usage

**SPTConfiguration** (`SpotifyVibeManager.swift:95-100`):
- Client ID: loaded from `Info.plist` key `SPOTIFY_CLIENT_ID` (via build variable)
- Redirect URI: `aiqo://spotify-login-callback`
- Company name: "AiQo"

**SPTSessionManager:**
- Delegate: `SpotifyVibeManager` (implements `SPTSessionManagerDelegate`)
- Handles: `didInitiate`, `didFailWith`, `didRenew`

**SPTAppRemote:**
- Log level: `.debug`
- Delegate: `SpotifyVibeManager` (implements `SPTAppRemoteDelegate`)
- Player API delegate: `SpotifyVibeManager` (implements `SPTAppRemotePlayerStateDelegate`)

**Connection Lifecycle:**
- `applicationDidBecomeActive`: reconnects if `shouldReconnectWhenActive` and session not expired
- `applicationWillResignActive`: unsubscribes from player state, disconnects App Remote
- On connection established: subscribes to player state, requests current state, plays pending URI

**Simulator Handling** (`SpotifyVibeManager.swift:1176-1292`):
- Entire real implementation wrapped in `#if !targetEnvironment(simulator)`
- Simulator stub provides all the same API surface but returns errors/no-ops
- All methods that require Spotify call `presentAvailabilityError()` which sets:
  - `lastErrorMessage`: "Spotify App Remote يحتاج جهاز iPhone حقيقي. على المحاكي نخليه مطفي."
  - `lastErrorCode`: `"spotify_simulator_unavailable"`
- `canAttemptAuthorization` and `isPlaybackAvailable` always return `false`
- Blend engine methods return `.failure` with "Simulator" error
- This design ensures views never crash on simulator — they just show error/disabled states

**Connection State Management:**
- All state mutations are thread-safe — every `@Published` property setter checks `Thread.isMainThread` and dispatches to main queue if needed (`SpotifyVibeManager.swift:424-462`)
- This is necessary because Spotify SDK callbacks arrive on arbitrary threads
- Pattern used consistently across `setConnectionState()`, `setPausedState()`, `setPlaybackState()`, `setCurrentVibeTitle()`, `clearError()`

---

## ٧. Hamoudi Blend Engine

### Status: IMPLEMENTED but FEATURE-FLAGGED OFF

The blend feature has two implementations in `SpotifyVibeManager`:

### Legacy: `generateHamoudiBlendPlaylist()` (SpotifyVibeManager.swift:753-846)
- **Creates a playlist** in the user's Spotify account named "Hamoudi+you+DJ 🎧"
- Fetches 100 tracks from master playlist ID `7B7uFMB3YjC4oP4D2LhXqI`
- Fetches 10 user top tracks (medium_term)
- Picks 10-15 random Hamoudi tracks + all user tracks
- Shuffles combined list
- Calls `POST /v1/users/{id}/playlists` → creates playlist
- Calls `POST /v1/playlists/{id}/tracks` → adds shuffled tracks
- **Compliance issue:** This creates playlists in the user's account

### New: `buildBlendQueue()` (SpotifyVibeManager.swift:1337-1418)
- **In-memory only** — no playlist creation
- Master playlist ID: `14YVMyaZsefyZMgEIIicao` (different from legacy)
- Fetches only URIs (minimal fields)
- User ratio: configurable, default 60% user / 40% Hamoudi
- Seeded Fisher-Yates shuffle: uses day-based seed for stable daily ordering (`SpotifyVibeManager.swift:1554-1575`)
- Max 20 tracks total
- Returns `[BlendQueueTrack]` (URI + source tag only)

### Blend Playback (SpotifyVibeManager.swift:1476-1541)
- Plays first track via `appRemote.playerAPI?.play()`
- Remaining tracks enqueued one-at-a-time via `enqueueTrackUri()` with 1-second throttle (Spotify TOS compliance)
- Source lookup stored in `blendSourceLookup: [String: BlendSource]` (memory only)
- `playerStateDidChange` updates `currentBlendSource` badge based on playing track URI

### UI: HamoudiDJPlaylistView (HamoudiDJPlaylistView.swift)
- Shows connection state, authorize state, loading, empty, and blend content
- Queue visualization: color-coded dots (mint = user, sand = Hamoudi) in 10-column grid
- Transport controls: previous / play-pause / next
- Footer includes Spotify "Powered by" attribution
- RTL layout forced: `.environment(\.layoutDirection, .rightToLeft)` (line 59)
- Blend ratio read from `Info.plist` key `HAMOUDI_BLEND_RATIO` (default 0.6) (`HamoudiDJPlaylistView.swift:554-559`)

### Feature Flag
- `HAMOUDI_BLEND_ENABLED`: `false` in Info.plist:83
- `HAMOUDI_BLEND_RATIO`: `0.6` in Info.plist:85
- The UI is accessible from VibeControlSheet's Spotify content section (line 54-118 of VibeControlSheetLogic.swift)

---

## ٨. UI Inventory

### MyVibeScreen (MyVibeScreen.swift)
- **Layout:** Vertical scroll with 4 sections: DJ Hamoudi hero header, horizontal timeline, bio-frequency card, Spotify card, bottom DJ search bar
- **Hero Header:** Full-width image ("Captain_Hamoudi_DJ"), gradient scrim overlay, status pill (LIVE/IDLE), title overlay with "MY VIBE" + "DJ Hamoudi"
- **Components:** Uses system SF Symbols, custom gradient circles, `.ultraThinMaterial` glass backgrounds, `.monospaced` header labels
- **RTL:** No explicit RTL enforcement in MyVibeScreen (relies on system layout)
- **Colors:** Primary accent `#8AE3D1` (mint), Spotify green `#1DB954`, per-state accents (Awakening `#FFD166`, Deep Focus `#8AE3D1`, Peak Energy `#FF9F43`, Recovery `#A78BFA`, Ego Death `#6366F1`)
- **Background:** Black base with radial gradient glow that shifts hue per state + ambient mint circle glow

### VibeControlSheet (VibeControlSheet.swift + VibeControlSheetLogic.swift)
- **Layout:** Full-screen with background artwork (Captain_Hamoudi_DJ), top section (title + source picker), content area (AiQo Sounds grid or Spotify list), bottom compact control card
- **Source Picker:** Segmented control (AiQo Sounds / Spotify)
- **AiQo Sounds View:** 2-column asymmetric grid of VibeModeCards (5 modes)
- **Spotify View:** Connect button, Hamoudi+you+DJ blend button, playlist list, logout button
- **Compact Control Card:** Mini player with mode info, play/pause, AirPlay route picker, DJ chat button
- **Details Sheet:** Presented as `.fraction(0.46)` / `.medium` / `.large` with mix toggle, intensity slider, mode summary, play/pause/stop
- **RTL:** Arabic accessibility labels throughout; no explicit `.layoutDirection` override
- **Colors:** `.ultraThinMaterial` backgrounds, Spotify green tint, mint teal control tint

### HamoudiDJPlaylistView (HamoudiDJPlaylistView.swift)
- **Layout:** Light-themed (bgTop `#FAFAF7`, bgBottom `#F3F4F1`) — contrast with dark VibeControlSheet
- **RTL:** Explicitly forced via `.environment(\.layoutDirection, .rightToLeft)` (line 59)
- **Brand Colors:** Mint `#B7E5D2`, Mint Vibrant `#5ECDB7`, Sand `#EBCF97`, Spotify Green
- **Glass Cards:** Custom `.ultraThinMaterial` with white fill overlay and subtle border
- **States:** Not connected → Authorize → Loading (spinning) → Empty (CTA) → Blend content with queue visualization

### SpotifyVibeCard (SpotifyVibeCard.swift)
- **Purpose:** Displays Captain's Spotify recommendation (playlist/album/artist)
- **Layout:** Header with icon, title, destination badge; description text; "Open in Spotify" CTA
- **Interaction:** Taps open Spotify app URI, falls back to web URL

### DJCaptainChatView (DJCaptainChatView.swift)
- **Purpose:** Chat interface for DJ Hamoudi persona
- **Layout:** Dark-themed chat with message bubbles, typing indicator, composer bar
- **Dependencies:** `CaptainViewModel` (the Captain AI engine)

---

## ٩. State Management

### @Published Properties

**MyVibeViewModel:**
| Property | Type | Purpose |
|----------|------|---------|
| `currentState` | `DailyVibeState` | Active biological state |
| `isPlaying` | `Bool` | Whether audio is active |
| `bioFrequencyStatus` | `String` | Detail text from VibeAudioEngine |
| `spotifyTrackName` | `String` | Current Spotify track name |
| `spotifyArtistName` | `String` | Current Spotify artist |
| `isSpotifyConnected` | `Bool` | Spotify connection state |
| `spotifyOverrideName` | `String?` | DJ override playlist name |
| `showDJChat` | `Bool` | DJ chat sheet presentation |
| `djSearchText` | `String` | Search field text |

**VibeOrchestrator:**
| Property | Type | Purpose |
|----------|------|---------|
| `currentState` | `DailyVibeState` | Active biological state |
| `isActive` | `Bool` | Whether orchestrator is running |
| `spotifyOverrideActive` | `Bool` | DJ override flag |
| `overridePlaylistName` | `String?` | Override playlist name |

**VibeControlViewModel:**
| Property | Type | Purpose |
|----------|------|---------|
| `selectedMode` | `VibeMode` | User-selected vibe mode |
| `lastActivatedMode` | `VibeMode?` | Last activated mode |
| `selectedSource` | `VibePlaybackSource` | AiQo Sounds or Spotify |
| `mixWithOthers` | `Bool` | Audio mixing toggle |
| `nativeIntensity` | `Double` | Volume intensity |

### @State / @StateObject in Views

| View | Property | Type | Purpose |
|------|----------|------|---------|
| MyVibeScreen | `viewModel` | `@StateObject MyVibeViewModel` | Main view model |
| MyVibeScreen | `heroNamespace` | `@Namespace` | Hero animation |
| VibeTimelineNode | `pulseScale` | `CGFloat` | Pulse animation |
| VibeWaveformView | `amplitudes` | `[CGFloat]` | Bar heights |
| VibeControlSheet | `isDetailsSheetPresented` | `Bool` | Sheet state |
| VibeControlSheet | `showDJChat` | `Bool` | DJ chat sheet |
| VibeControlSheet | `showBlendPlaylist` | `Bool` | Blend sheet |
| HamoudiDJPlaylistView | `animatePulse` | `Bool` | Loading spinner |
| HamoudiDJPlaylistView | `blendQueue` | `[BlendQueueTrack]` | Local queue state |
| HamoudiDJPlaylistView | `isBuilding` | `Bool` | Build in progress |
| HamoudiDJPlaylistView | `buildError` | `String?` | Error message |

### SwiftData Models
None found touching My Vibe.

### UserDefaults Keys
| Key | Type | Used By | Purpose |
|-----|------|---------|---------|
| `com.aiqo.vibeAudio.profile` | Data (JSON) | `VibeAudioEngine` | Persisted `VibeDayProfile` |
| `com.aiqo.vibe.source` | String | `VibeControlViewModel` | Selected source (AiQo/Spotify) |
| `com.aiqo.vibe.mixWithOthers` | Bool | `VibeControlViewModel` | Mix toggle state |
| `com.aiqo.vibe.nativeIntensity` | Double | `VibeControlViewModel` | Intensity slider value |
| `spotify_web_api_token` | String | `SpotifyVibeManager` | Web API OAuth token (plaintext) |

### Keychain Keys
None. The Web API token is stored in UserDefaults, not Keychain.

---

## ١٠. Configuration

### Info.plist Keys (My Vibe Related)

| Key | Value | Purpose |
|-----|-------|---------|
| `SPOTIFY_CLIENT_ID` | `$(SPOTIFY_CLIENT_ID)` (build variable) | Spotify OAuth client ID |
| `HAMOUDI_BLEND_ENABLED` | `false` | Feature flag: blend engine |
| `HAMOUDI_BLEND_RATIO` | `0.6` | Default user/hamoudi track ratio |
| `CFBundleURLSchemes` | `["aiqo", "aiqo-spotify"]` | URL schemes for Spotify callback |
| `LSApplicationQueriesSchemes` | `["spotify", ...]` | Allows checking if Spotify is installed |
| `UIBackgroundModes` | `["audio", "remote-notification", "fetch", "processing"]` | Background audio playback |
| `NSAppTransportSecurity.NSAllowsLocalNetworking` | `true` | Local networking for development |

### Entitlements (AiQo.entitlements)

| Capability | Value | Relevance to My Vibe |
|-----------|-------|---------------------|
| `aps-environment` | `production` | Push notifications (not directly My Vibe) |
| `com.apple.developer.applesignin` | `["Default"]` | Not directly My Vibe |
| `com.apple.developer.healthkit` | `true` | Not directly My Vibe |
| `com.apple.developer.healthkit.background-delivery` | `true` | Not directly My Vibe |
| `com.apple.developer.siri` | `true` | Not directly My Vibe |
| `com.apple.security.application-groups` | `["group.com.aiqo.kernel2", "group.aiqo"]` | Shared container (not directly My Vibe) |

Note: No audio-specific entitlements needed beyond `UIBackgroundModes: audio` in Info.plist.

No microphone entitlement is declared — the bio-frequency engine generates tones procedurally, it does not capture ambient audio. The `NSAlarmKitUsageDescription` in Info.plist relates to the wake feature, not My Vibe.

### Spotify URL Scheme Configuration

The app registers two URL schemes in `CFBundleURLSchemes`:
- `aiqo` — Primary callback scheme for PKCE Web API auth and deep linking
- `aiqo-spotify` — Secondary scheme (currently not referenced in SpotifyVibeManager; the redirect URI uses `aiqo://spotify-login-callback`)

`LSApplicationQueriesSchemes` includes `"spotify"` to allow `UIApplication.canOpenURL()` checks for Spotify app presence (`SpotifyVibeManager.swift:501-510`).

### Feature Flags

| Flag | Default | Purpose |
|------|---------|---------|
| `HAMOUDI_BLEND_ENABLED` | `false` | Gates the blend playlist feature |
| `HAMOUDI_BLEND_RATIO` | `0.6` | Controls user vs Hamoudi track ratio |
| `CAPTAIN_BRAIN_V2_ENABLED` | `true` | Brain engine version (affects DJ Hamoudi intelligence) |

---

## ١١. Assets

### Audio Files

| Filename | Format | Size | Duration | Used By |
|----------|--------|------|----------|---------|
| SerotoninFlow.m4a | M4A (AAC) | 8.5 MB | Unknown — needs verification | `AiQoAudioManager` (Awakening mode) |
| GammaFlow.m4a | M4A (AAC) | 9.0 MB | Unknown — needs verification | `AiQoAudioManager` (Deep Focus mode) |
| SoundOfEnergy.m4a | M4A (AAC) | 8.5 MB | Unknown — needs verification | `AiQoAudioManager` (Energy mode) |
| ThetaTrance.m4a | M4A (AAC) | 8.4 MB | Unknown — needs verification | `AiQoAudioManager` (Ego Death via VibeMode, Recovery via DailyVibeState) |
| Hypnagogic_state.m4a | M4A (AAC) | 8.5 MB | Unknown — needs verification | `AiQoAudioManager` (Recovery via VibeMode, Ego Death via DailyVibeState) |

**Total audio assets:** 5 files, ~42.9 MB

### Images

| Asset Name | Variants | Used By |
|-----------|----------|---------|
| Captain_Hamoudi_DJ | 1x PNG (3.1 MB) | `MyVibeScreen.swift:51`, `VibeControlSheetLogic.swift:169` |
| vibe_ icon | 1x PNG | `VibeControlComponents.swift:9` (VibeDashboardTriggerButton, note: space in name) |
| imageKitchenHamoudi | 1x PNG | Hamoudi kitchen scene (not directly in My Vibe views) |

### Localized Strings

**Count:** 31 keys per language (10 `vibe.*` + 21 `blend.*`)

| Key | English (en) | Arabic (ar) |
|-----|-------------|-------------|
| `vibe.title` | My Vibe | ذوقي |
| `vibe.audioSource` | Audio Source | مصدر الصوت |
| `vibe.aiqoSounds` | AiQo Sounds | أصوات AiQo |
| `vibe.spotify` | Spotify | Spotify |
| `vibe.soundControls` | Sound Controls | التحكم بالصوت |
| `vibe.mixAudio` | Mix with other audio | مزج مع صوت آخر |
| `vibe.intensity` | Intensity | الشدة |
| `vibe.djPick` | DJ Hamoudi Pick | اختيار دي جي حمّودي |
| `vibe.openSpotify` | Open in Spotify | افتح في Spotify |
| `vibe.live` | LIVE | مباشر |
| `vibe.idle` | IDLE | متوقف |
| `vibe.myVibe` | MY VIBE | ذوقي |
| `vibe.djHamoudi` | DJ Hamoudi | DJ حمّودي |
| `vibe.bioTimeline` | BIOLOGICAL TIMELINE | الخط الزمني البيولوجي |
| `vibe.bioFrequency` | BIO-FREQUENCY | التردد الحيوي |
| `vibe.spotifyLabel` | SPOTIFY | سبوتيفاي |
| `vibe.connected` | CONNECTED | متصل |
| `vibe.djOverride` | DJ Override Active | تجاوز DJ مفعّل |
| `vibe.djPlaceholder` | Ask DJ Hamoudi for a mood override... | اطلب من DJ حمّودي تغيير المود... |
| `blend.header` | My Vibe | ذوقي |
| `blend.subtitle` | Hamoudi's picks + your taste | مزيج حمودي + ذوقك |
| `blend.close` | Close | اغلق |
| `blend.connectFirst` | Connect Spotify first so we can get your tracks | وصّل سبوتيفاي أولاً عشان نجيب أغانيك |
| `blend.connectSpotify` | Connect Spotify | وصّل سبوتيفاي |
| `blend.authorizeNeeded` | Authorize your Spotify account to build the blend | صرّح لحسابك بسبوتيفاي عشان نبني المزيج |
| `blend.authorize` | Authorize | صرّح |
| `blend.loading` | Hamoudi is mixing... | حمودي يجهز المزيج... |
| `blend.loadingSub` | Grabbing your favorites and blending with his picks | نجيب أغانيك المفضلة وندمجها مع اختياراته |
| `blend.startBlend` | Start the Blend | ابدأ المزيج |
| `blend.startBlendSub` | Mix your taste with Hamoudi's picks | مزيج من ذوقك واختيارات حمودي |
| `blend.fromYou` | Your pick | من ذوقك |
| `blend.hamoudiPick` | Hamoudi's Pick 🎧 | اختيار حمودي 🎧 |
| `blend.queueTitle` | Queue | القائمة |
| `blend.regenerate` | New Mix | مزيج جديد |
| `blend.mixDescription` | A blend of your taste and Hamoudi's picks | مزيج من ذوقك واختيارات حمودي |
| `blend.footer` | Playback via the Spotify app. AiQo doesn't save your songs. | التشغيل عبر تطبيق Spotify. AiQo ما يحفظ أغانيك. |
| `blend.previous` | Previous | السابق |
| `blend.next` | Next | التالي |
| `blend.pause` | Pause | إيقاف مؤقت |
| `blend.play` | Play | تشغيل |
| `blend.installSpotify` | Install the Spotify app first | ثبّت تطبيق Spotify أولاً |

---

## ١٢. Dependencies

### Third-Party

| Dependency | Version | Purpose |
|-----------|---------|---------|
| SpotifyiOS.framework | Unknown — needs verification (no version constant found) | `SPTAppRemote`, `SPTSessionManager`, `SPTConfiguration`, `SPTScope` |

### Apple Frameworks

| Framework | Used By | Purpose |
|-----------|---------|---------|
| AVFoundation | `VibeAudioEngine`, `AiQoAudioManager` | Audio session, engine, player nodes, queue player |
| MediaPlayer | `VibeAudioEngine` | Now Playing info, remote command center |
| UIKit | `SpotifyVibeManager`, `VibeControlComponents` | `UIApplication`, `UIImage` |
| SwiftUI | All views | UI framework |
| Combine | `MyVibeViewModel`, `VibeAudioEngine`, `SpotifyVibeManager` | Reactive bindings |
| AuthenticationServices | `SpotifyVibeManager` | `ASWebAuthenticationSession` for PKCE OAuth |
| CryptoKit | `SpotifyVibeManager` | SHA256 for PKCE code challenge |
| AVKit | `VibeControlSupport` | `AVRoutePickerView` for AirPlay |
| Foundation | All files | Core types |

---

## ١٣. Compliance Status

| # | Requirement | Status | Notes |
|---|-----------|--------|-------|
| 1 | No track metadata stored to disk | ⚠️ | New blend engine (`buildBlendQueue`) stores only URIs in memory. But legacy `generateHamoudiBlendPlaylist()` fetches and holds `BlendTrack` with name/artist/album in memory — not persisted to disk but exists in published state. `blendTracks` is `@Published` on `SpotifyVibeManager`. |
| 2 | No playlists created in user's Spotify account | ❌ | Legacy `generateHamoudiBlendPlaylist()` at `SpotifyVibeManager.swift:753` calls `POST /v1/users/{id}/playlists`. The new `buildBlendQueue()` at line 1337 does NOT create playlists. Both methods coexist. |
| 3 | HealthKit data never sent to Spotify | ✅ | No HealthKit references in any My Vibe file. |
| 4 | PrivacySanitizer used for all logged events | ⚠️ | No references to `PrivacySanitizer` found in any My Vibe file. Logging uses raw `print()` statements (e.g., `SpotifyVibeManager.swift:1077`: `print("Aura Vibe: \(message)")`). |
| 5 | Spotify "Powered by" attribution present | ✅ | Present in `HamoudiDJPlaylistView.swift:504-511`: footer with "Powered by Spotify". |
| 6 | Apple background audio mode declared | ✅ | `UIBackgroundModes: ["audio"]` in `Info.plist:87`. |
| 7 | All strings localized (ar + en) | ⚠️ | All 31 `vibe.*` and `blend.*` keys localized. However, some hardcoded English strings exist: `DailyVibeState.title` returns hardcoded English ("Awakening", "Deep Focus", etc. at `DailyVibeState.swift:18-24`). `VibeMode.subtitle` hardcoded English (`VibeControlSupport.swift:26-38`). Some inline Arabic in `VibeControlSheetLogic.swift` (accessibility labels like "افتح سبوتيفاي" at line 51). |
| 8 | RTL layout verified | ⚠️ | `HamoudiDJPlaylistView` forces RTL (line 59). `VibeControlSheet` has Arabic accessibility labels. `MyVibeScreen` has no explicit RTL handling — relies on system. Some hardcoded `.leading` alignments may not flip correctly. |
| 9 | No dark backgrounds (brand consistency) | ❌ | `MyVibeScreen` uses `Color.black.ignoresSafeArea()` as base background (`MyVibeSubviews.swift:10`). `VibeControlSheet` uses dark Captain Hamoudi artwork background. Both are full-dark UIs. `HamoudiDJPlaylistView` uses light background (`#FAFAF7`/`#F3F4F1`). |
| 10 | Feature flags wired correctly | ⚠️ | `HAMOUDI_BLEND_ENABLED` is declared in Info.plist but no code reads it to gate the blend UI. The blend button in `VibeControlSheetLogic.swift:53-118` is always visible when in Spotify mode. The flag appears unused. `HAMOUDI_BLEND_RATIO` is correctly read by `HamoudiDJPlaylistView.swift:554-559`. |

---

## ١٤. Known Issues & Tech Debt

No `TODO`, `FIXME`, `HACK`, or `XXX` comments were found in any My Vibe file.

However, the following issues were identified from code analysis:

1. **Legacy blend method creates playlists** — `generateHamoudiBlendPlaylist()` at `SpotifyVibeManager.swift:753` creates playlists in the user's Spotify account. Should be removed or gated since `buildBlendQueue()` replaces it.

2. **Web API token stored in UserDefaults** — `SpotifyVibeManager.swift:67-69` stores the OAuth token in plaintext `UserDefaults` instead of Keychain. Security risk.

3. **No Web API token refresh** — After PKCE auth, only the access token is stored. No refresh token flow exists (`SpotifyVibeManager.swift:711-725`). Users must re-authorize when the token expires (~1 hour).

4. **Track mapping inconsistency** — `DailyVibeState.frequencyLabel` and `VibeMode.aiqoTrackName` have swapped mappings for Recovery and Ego Death:
   - `DailyVibeState.recovery` → `"ThetaTrance"` but `VibeMode.recovery` → `"Hypnagogic_state"`
   - `DailyVibeState.egoDeath` → `"Hypnagogic_state"` but `VibeMode.egoDeath` → `"ThetaTrance"`

5. **HAMOUDI_BLEND_ENABLED flag unused** — The flag exists in Info.plist but no code checks it. The blend UI button is always visible in Spotify mode.

6. **Two master playlist IDs** — Legacy blend uses `7B7uFMB3YjC4oP4D2LhXqI` (`SpotifyVibeManager.swift:63`), new blend engine uses `14YVMyaZsefyZMgEIIicao` (`SpotifyVibeManager.swift:1330`). Unclear if intentional.

7. **Asset name has a space** — `vibe_ icon.imageset` has a space in the directory name. `VibeDashboardTriggerButton` tries both `"vibe_ icon"` and `"vibe_icon"` as fallback (`VibeControlComponents.swift:9-10`).

8. **PrivacySanitizer not used** — My Vibe logging uses raw `print()` statements. Spotify track names, URIs, and user IDs are logged unfiltered (`SpotifyVibeManager.swift:1077`).

9. **No error handling for audio asset loading** — `AiQoAudioManager.resolveAmbientTrackURL()` silently returns nil if the asset is missing. The error is reported but could leave the user in a broken state.

10. **Timer leak potential** — `VibeWaveformView` creates a `Timer.scheduledTimer` in `onAppear` (`MyVibeSubviews.swift:168`) but never invalidates it. Could leak if the view is recreated.

---

## ١٥. Test Coverage

### Unit Tests
None found. No test files matching `*Vibe*Test*` or `*Spotify*Test*` exist in the project.

### UI Tests
None found for My Vibe.

### Coverage Gaps (ordered by risk)

| Priority | Component | Risk | What to Test |
|----------|-----------|------|-------------|
| Critical | `VibeOrchestrator` | State machine could get stuck | `activate()` → `pause()` → `resume()` → `deactivate()` lifecycle; auto-transition at day-part boundaries; DJ override + clear cycle |
| Critical | `SpotifyVibeManager` OAuth | Auth failures leave user in broken state | Session delegation callbacks; URL handling; PKCE code exchange; 401 token invalidation |
| Critical | `buildBlendQueue()` | Wrong ratio or empty results | Ratio math with edge cases (0 user tracks, 0 master tracks); seeded shuffle determinism; daily seed stability |
| High | `VibeAudioEngine` | Silent audio or crossfade glitches | Buffer synthesis produces non-zero samples; crossfade volume ramps; mode switch during pause |
| High | `DailyVibeState.current()` | Wrong state for time of day | Hour boundary conditions (4:59→5:00, 8:59→9:00, etc.); midnight rollover |
| Medium | `AiQoAudioManager` | Audio interruption recovery | Begin/end interruption with shouldResume; route change pause; speech ducking levels |
| Medium | `VibeControlViewModel` | Lost user preferences | UserDefaults read/write round-trip; default values on fresh install |
| Low | `BlendQueueTrack` source tracking | Wrong badge displayed | `resolveBlendSource()` lookup after queue build; unknown URI returns nil |

---

## ١٦. Open Questions for Mohammed

1. **Which track mapping is correct?** `DailyVibeState` maps Recovery → ThetaTrance and Ego Death → Hypnagogic_state, but `VibeMode` maps the reverse. Which enum should be the source of truth? (See `DailyVibeState.swift:27-33` vs `VibeControlSupport.swift:86-98`)

2. **Should the legacy blend method be removed?** `generateHamoudiBlendPlaylist()` creates playlists in the user's account, contradicting compliance goals. The new `buildBlendQueue()` operates in-memory. Can the legacy method and its API calls be deleted? (`SpotifyVibeManager.swift:753-846`)

3. **Which master playlist ID should the blend engine use?** Legacy uses `7B7uFMB3YjC4oP4D2LhXqI`, new engine uses `14YVMyaZsefyZMgEIIicao`. Are these different playlists intentionally, or should they be consolidated?

4. **Should the Web API token move to Keychain?** Currently in plaintext UserDefaults (`SpotifyVibeManager.swift:67`). Is this acceptable for the current stage, or should it be migrated before enabling the blend feature?

5. **Is the dark background intentional for MyVibeScreen?** The brand guidelines suggest no dark backgrounds, but `MyVibeScreen` and `VibeControlSheet` both use dark/black themes. Is this an intentional exception for the DJ Hamoudi aesthetic?

6. **Should `HAMOUDI_BLEND_ENABLED` actually gate the blend UI?** The flag exists but isn't read anywhere. Should the blend button in `VibeControlSheetLogic.swift:54` be hidden when the flag is `false`?

7. **What is the desired behavior when the VibeAudioEngine (binaural) and AiQoAudioManager (file-based) are both available?** The `VibeOrchestrator` uses `VibeAudioEngine` for bio-frequencies but `VibeControlSheet` can trigger `AiQoAudioManager` independently. Should they be mutually exclusive or layered?

---

## ١٧. Recommended Next Actions

### P0 — Must Fix Before Blend Launch

1. **Wire `HAMOUDI_BLEND_ENABLED` feature flag** — Add a check in `VibeControlSheetLogic.swift` (around line 54) to hide the blend button when the flag is `false`. Currently the blend UI is always visible in Spotify mode despite the flag being OFF.
   - File: `VibeControlSheetLogic.swift:54`
   - Change: Wrap blend button in `if Bundle.main.infoDictionary?["HAMOUDI_BLEND_ENABLED"] as? Bool == true`

2. **Remove legacy `generateHamoudiBlendPlaylist()`** — Delete the method and its related API calls (`createPlaylist`, `addTracksToPlaylist`, `fetchCurrentUserID`, `fetchMasterPlaylistTracks`, `fetchUserTopTracks`, `fetchPlaylistTracks`) from `SpotifyVibeManager.swift:753-1074`. Also remove `blendPlaylistURI`, `blendPlaylistURL`, `blendTracks` properties. This eliminates the compliance violation of creating playlists in the user's account.
   - File: `SpotifyVibeManager.swift`

3. **Fix track mapping inconsistency** — Align `DailyVibeState.frequencyLabel` and `VibeMode.aiqoTrackName` so Recovery and Ego Death map to the same audio tracks. Requires Mohammed's decision on which is correct.
   - Files: `DailyVibeState.swift:27-33`, `VibeControlSupport.swift:86-98`

### P1 — Should Fix Soon

4. **Migrate Web API token to Keychain** — Replace `UserDefaults` storage with `Keychain` for `spotify_web_api_token`. Use the app's existing Keychain infrastructure if available.
   - File: `SpotifyVibeManager.swift:66-69`

5. **Integrate PrivacySanitizer** — Replace `print("Aura Vibe: \(message)")` logging with `PrivacySanitizer`-filtered logging throughout `SpotifyVibeManager`. Track names, user IDs, and URIs should be sanitized.
   - File: `SpotifyVibeManager.swift:1076-1078`

6. **Add unit tests for blend queue logic** — Test `buildBlendQueue()` ratio calculations, `seededShuffle` determinism, edge cases (empty user tracks, empty master tracks), and source lookup.
   - New file: `AiQoTests/BlendEngineTests.swift`

7. **Implement Web API refresh token** — Store and use the refresh token from the PKCE exchange to avoid forcing re-authorization every hour.
   - File: `SpotifyVibeManager.swift:687-727`

### P2 — Nice to Have

8. **Fix Timer leak in VibeWaveformView** — Store the `Timer` reference and invalidate it in `.onDisappear` or use a `TimelineView` instead.
   - File: `MyVibeSubviews.swift:168`

9. **Consolidate master playlist IDs** — Determine if both `7B7uFMB3YjC4oP4D2LhXqI` and `14YVMyaZsefyZMgEIIicao` are needed, or consolidate to one.
   - File: `SpotifyVibeManager.swift:63, 1330`

10. **Fix asset name spacing** — Rename `vibe_ icon.imageset` to `vibe_icon.imageset` to eliminate the fallback logic in `VibeDashboardTriggerButton`.
    - Files: `Assets.xcassets/vibe_ icon.imageset/`, `VibeControlComponents.swift:9-10`

11. **Add localization for hardcoded strings** — Move `DailyVibeState.title` and `VibeMode.subtitle` values into `Localizable.strings` for both `ar` and `en`.
    - Files: `DailyVibeState.swift:17-25`, `VibeControlSupport.swift:26-38`

12. **Add test coverage** — Unit tests for `DailyVibeState.current()`, `VibeOrchestrator` lifecycle, `VibeAudioEngine` crossfade, and `AiQoAudioManager` ducking.
