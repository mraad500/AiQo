import SwiftUI
import Combine

// MARK: - Curated track seed
//
// This is the Hamoudi master track list, embedded directly in the app.
// It replaces the former Web-API playlist fetch (which Spotify's Development
// Mode forbids for any non-self playlist — even editorial ones). Mohammed
// owns this list end-to-end: swap / append URIs whenever Hamoudi's rotation
// changes, then ship via app update.
//
// How to grab a Spotify track URI:
//   - Spotify desktop → Preferences → Developer → "Show Spotify URIs"
//   - Right-click a track → Share → Copy Spotify URI
//
enum HamoudiCurated {
    struct SeedTrack {
        let uri: String
        let name: String
        let artist: String
        /// 300px-ish album cover hosted on Spotify's public CDN. Available
        /// without auth — so it renders immediately, independent of Web API.
        let imageURL: URL?
    }

    /// Default seed tracks with bundled metadata. Safe to replace entirely.
    /// Image URLs intentionally nil — the album-art icon placeholder fills
    /// in, and the real cover will populate automatically once Spotify's
    /// App Remote player-state event fires for the track (which exposes
    /// artwork via `appRemote.imageAPI` for the currently-playing track).
    static let tracks: [SeedTrack] = [
        SeedTrack(uri: "spotify:track:0VjIjW4GlUZAMYd2vXMi3b",
                  name: "Blinding Lights", artist: "The Weeknd", imageURL: nil),
        SeedTrack(uri: "spotify:track:7qiZfU4dY1lWllzX7mPBI3",
                  name: "Shape of You", artist: "Ed Sheeran", imageURL: nil),
        SeedTrack(uri: "spotify:track:6UelLqGlWMcVH1E5c4H7lY",
                  name: "Watermelon Sugar", artist: "Harry Styles", imageURL: nil),
        SeedTrack(uri: "spotify:track:4iLqG9SeJSnt0cSPICSjxv",
                  name: "Heat Waves", artist: "Glass Animals", imageURL: nil),
        SeedTrack(uri: "spotify:track:1rgnBhdG2JDFTbYkYRZAku",
                  name: "As It Was", artist: "Harry Styles", imageURL: nil),
        SeedTrack(uri: "spotify:track:463CkQjx2Zk1yXoBuierM9",
                  name: "Levitating", artist: "Dua Lipa", imageURL: nil),
        SeedTrack(uri: "spotify:track:5HCyWlXZPP0y6Gqq8TgA20",
                  name: "STAY", artist: "The Kid LAROI, Justin Bieber", imageURL: nil),
        SeedTrack(uri: "spotify:track:3KkXRkHbMCARz0aVfEt68P",
                  name: "Sunflower", artist: "Post Malone, Swae Lee", imageURL: nil),
        SeedTrack(uri: "spotify:track:2XU0oxnq2qxCpomAAuJY8K",
                  name: "Dance Monkey", artist: "Tones and I", imageURL: nil),
        SeedTrack(uri: "spotify:track:3ZCTVFBt2Brf31RLEnCkWA",
                  name: "everything i wanted", artist: "Billie Eilish", imageURL: nil),
        SeedTrack(uri: "spotify:track:1r9xUipOqoNwggBpENDsvJ",
                  name: "Circles", artist: "Post Malone", imageURL: nil),
        SeedTrack(uri: "spotify:track:0pqnGHJpmpxLKifKRmU6WP",
                  name: "Believer", artist: "Imagine Dragons", imageURL: nil),
        SeedTrack(uri: "spotify:track:7KA4W4McWYRpgf0fWsJZWB",
                  name: "SICKO MODE", artist: "Travis Scott", imageURL: nil),
        SeedTrack(uri: "spotify:track:2Fxmhks0bxGSBdJ92vM42m",
                  name: "bad guy", artist: "Billie Eilish", imageURL: nil),
        SeedTrack(uri: "spotify:track:6DCZcSspjsKoFjzjrWoCdn",
                  name: "God's Plan", artist: "Drake", imageURL: nil)
    ]

    static var trackURIs: [String] { tracks.map(\.uri) }
    static var metadataByURI: [String: HamoudiTrackMeta] {
        Dictionary(uniqueKeysWithValues: tracks.map {
            ($0.uri, HamoudiTrackMeta(name: $0.name, artist: $0.artist, imageURL: $0.imageURL))
        })
    }
}

// MARK: - Blend Source

enum HamoudiDJSource: String, Codable, Equatable {
    case user
    case hamoudi
}

struct HamoudiQueuedTrack: Identifiable, Equatable {
    let id: String           // use URI as stable id
    let uri: String
    let source: HamoudiDJSource

    init(uri: String, source: HamoudiDJSource) {
        self.id = uri
        self.uri = uri
        self.source = source
    }
}

struct HamoudiTrackMeta: Equatable {
    let name: String
    let artist: String
    let imageURL: URL?
}

// MARK: - Local error

enum HamoudiDJError: LocalizedError, Equatable {
    case notConnected
    case buildFailed

    var errorDescription: String? {
        switch self {
        case .notConnected: return NSLocalizedString("blend.error.auth_expired", comment: "")
        case .buildFailed:  return NSLocalizedString("blend.error.no_master_tracks", comment: "")
        }
    }
}

// MARK: - View Model

@MainActor
final class HamoudiDJViewModel: ObservableObject {
    /// Singleton — outlives the sheet. Opening / closing / re-opening the
    /// Hamoudi+you+DJ view always reads the same VM, so the queue, source
    /// badge, and playback state persist across navigation.
    static let shared = HamoudiDJViewModel()

    enum State: Equatable {
        case idle
        case loading
        case playing
        case error(HamoudiDJError)
    }

    @Published var state: State = .idle
    @Published var currentSource: HamoudiDJSource?
    @Published var currentURI: String?
    @Published var builtQueue: [HamoudiQueuedTrack] = []
    /// Track metadata (name + artist) keyed by URI. Populated once per
    /// queue build from Spotify's catalog endpoint — which works in Dev Mode.
    @Published var trackMetadata: [String: HamoudiTrackMeta] = [:]

    private let spotify = SpotifyVibeManager.shared
    private var sourceByURI: [String: HamoudiDJSource] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var isBuilding = false

    private init() {
        // Update the badge when the Spotify player transitions to a new track.
        NotificationCenter.default.publisher(for: .spotifyPlayerTrackChanged)
            .compactMap { $0.userInfo?["uri"] as? String }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] uri in
                guard let self else { return }
                self.currentURI = uri
                if let source = self.sourceByURI[uri] {
                    self.currentSource = source
                }
            }
            .store(in: &cancellables)

        // Auto-build when both the SDK session and the Web-API token resolve.
        Publishers.CombineLatest(spotify.$isConnected, spotify.$isWebAPIAuthorized)
            .map { $0 && $1 }
            .removeDuplicates()
            .filter { $0 }
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if case .error = self.state { self.state = .idle }
                if self.state == .idle {
                    Task { [weak self] in await self?.buildAndPlay() }
                }
            }
            .store(in: &cancellables)

        // On explicit logout the Web-API token is cleared. Reset the VM so
        // the next connect flow starts clean. App-backgrounding only flips
        // `isConnected` (not `isWebAPIAuthorized`), so this does NOT fire
        // when the user just switches apps.
        spotify.$isWebAPIAuthorized
            .removeDuplicates()
            .dropFirst()
            .filter { !$0 }
            .sink { [weak self] _ in
                guard let self else { return }
                self.state = .idle
                self.currentSource = nil
                self.currentURI = nil
                self.sourceByURI = [:]
                self.builtQueue = []
                self.trackMetadata = [:]
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func connect() {
        spotify.connect()
    }

    func buildAndPlay() async {
        guard !isBuilding else { return }
        isBuilding = true
        defer { isBuilding = false }

        state = .loading

        // Single Web API call — `/v1/me/top/tracks` — returns URIs AND full
        // track metadata (name + artist + album art). That's the only
        // endpoint permitted in Spotify Dev Mode anyway; everything else
        // (individual playlist reads, /v1/tracks batch catalog) 403s.
        let userTracks: [SpotifyTopTrack]
        do {
            userTracks = try await spotify.fetchUserTopTracksWithMetadata(limit: 30)
        } catch {
            state = .error(.buildFailed)
            return
        }

        let userURIs = userTracks.map(\.uri)
        let hamoudiURIs = HamoudiCurated.trackURIs
        guard !hamoudiURIs.isEmpty else {
            state = .error(.buildFailed)
            return
        }

        let queue = Self.buildQueue(
            userURIs: userURIs,
            hamoudiURIs: hamoudiURIs,
            userShare: 0.6,
            totalCount: 12
        )
        guard !queue.isEmpty else {
            state = .error(.buildFailed)
            return
        }

        // Build the URI→source lookup the notification listener uses for the badge.
        sourceByURI = Dictionary(uniqueKeysWithValues: queue)
        builtQueue = queue.map { HamoudiQueuedTrack(uri: $0.0, source: $0.1) }
        currentURI = queue.first?.0

        // Merge metadata: user tracks (from API) + Hamoudi seeds (hardcoded).
        // User-track metadata always wins if a URI somehow collides.
        var merged: [String: HamoudiTrackMeta] = HamoudiCurated.metadataByURI
        for track in userTracks {
            merged[track.uri] = HamoudiTrackMeta(
                name: track.name,
                artist: track.artist,
                imageURL: track.imageURL
            )
        }
        trackMetadata = merged

        startPlayback(queue: queue)
        state = .playing
    }

    // MARK: - Jump to a track in the queue

    /// Tapped a row — play that URI immediately and re-queue the ones after it.
    /// Playing a new URI via App Remote clears Spotify's existing queue, so
    /// we rebuild it from this track onward.
    func playFromQueue(startingAt index: Int) {
        guard index >= 0, index < builtQueue.count else { return }

        let entry = builtQueue[index]
        spotify.playTrack(uri: entry.uri)
        currentURI = entry.uri
        currentSource = entry.source

        let remaining = Array(builtQueue.dropFirst(index + 1))
        Task { [weak self] in
            for (offset, track) in remaining.enumerated() {
                try? await Task.sleep(nanoseconds: UInt64(Double(offset) * 0.2 * 1_000_000_000))
                guard let self else { return }
                await MainActor.run { self.spotify.enqueueTrack(uri: track.uri) }
            }
        }
    }

    func regenerate() async {
        state = .idle
        await buildAndPlay()
    }

    func togglePlayPause() {
        if spotify.playbackState == .playing {
            spotify.pauseVibe()
        } else {
            spotify.resumeVibe()
        }
    }

    func skipNext()     { spotify.skipNext() }
    func skipPrevious() { spotify.skipPrevious() }

    func dismissError() {
        state = .idle
        if spotify.isConnected, spotify.isWebAPIAuthorized {
            Task { [weak self] in await self?.buildAndPlay() }
        }
    }

    // MARK: - Private

    private func startPlayback(queue: [(String, HamoudiDJSource)]) {
        let firstURI = queue[0].0
        spotify.playTrack(uri: firstURI)
        currentSource = queue[0].1

        // Fire the remaining enqueues in a tight burst. 200ms is enough to
        // stay under Spotify's enqueue rate limit while still completing all
        // ~11 inserts in ~2s — well inside the window before the user can
        // background the app (which tears down the App Remote transport).
        Task { [weak self] in
            for (index, entry) in queue.dropFirst().enumerated() {
                try? await Task.sleep(nanoseconds: UInt64(Double(index) * 0.2 * 1_000_000_000))
                guard let self else { return }
                await MainActor.run { self.spotify.enqueueTrack(uri: entry.0) }
            }
        }
    }

    /// Interleave user + Hamoudi picks according to `userShare`, shuffled with
    /// a per-day seed so the order is stable within a day but varies across days.
    static func buildQueue(
        userURIs: [String],
        hamoudiURIs: [String],
        userShare: Double,
        totalCount: Int
    ) -> [(String, HamoudiDJSource)] {
        let target = min(totalCount, userURIs.count + hamoudiURIs.count)
        let desiredUser = min(userURIs.count, Int(round(Double(target) * userShare)))
        let hamoudiCount = target - desiredUser

        let userPicks = Array(userURIs.prefix(desiredUser))
        let hamoudiPicks = Array(hamoudiURIs.shuffled().prefix(hamoudiCount))

        var mixed: [(String, HamoudiDJSource)] = []
        mixed += userPicks.map { ($0, .user) }
        mixed += hamoudiPicks.map { ($0, .hamoudi) }

        return seededShuffle(mixed, seed: daySeed())
    }

    private static func daySeed() -> UInt64 {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return UInt64(comps.year ?? 2026) * 10_000
             + UInt64(comps.month ?? 1) * 100
             + UInt64(comps.day ?? 1)
    }

    private static func seededShuffle<T>(_ array: [T], seed: UInt64) -> [T] {
        guard array.count > 1 else { return array }
        var out = array
        var rng = seed
        for i in stride(from: out.count - 1, through: 1, by: -1) {
            rng = rng &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let j = Int(rng >> 33) % (i + 1)
            if i != j { out.swapAt(i, j) }
        }
        return out
    }
}

// MARK: - View

struct HamoudiDJView: View {
    @ObservedObject private var viewModel = HamoudiDJViewModel.shared
    @ObservedObject private var spotify = SpotifyVibeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var presentedError: HamoudiDJError?

    // Brand colors (match the rest of AiQo)
    private let mint         = Color(hex: "B7E5D2")
    private let mintVibrant  = Color(hex: "5ECDB7")
    private let sand         = Color(hex: "EBCF97")
    private let bgTop        = Color(hex: "FAFAF7")
    private let bgBottom     = Color(hex: "F3F4F1")
    private let spotifyGreen = Color(red: 0.12, green: 0.85, blue: 0.38)

    private var trackName: String? {
        let name = spotify.currentTrackName
        return (name.isEmpty || name == "Not Playing") ? nil : name
    }
    private var artistName: String? {
        let name = spotify.currentArtistName
        return name.isEmpty ? nil : name
    }
    private var isPlaying: Bool { spotify.playbackState == .playing }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                switch viewModel.state {
                case .idle:
                    if spotify.isConnected {
                        ctaView
                    } else {
                        connectView
                    }
                case .loading:
                    loadingView
                case .playing:
                    playingView
                case .error:
                    ctaView
                }

                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if case .playing = viewModel.state {
                    transportBar
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                        .background(
                            LinearGradient(
                                colors: [.clear, bgBottom.opacity(0.6), bgBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                        )
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task(id: viewModel.state) {
            if case .error(let err) = viewModel.state {
                presentedError = err
            } else {
                presentedError = nil
            }
        }
        .alert(item: $presentedError) { err in
            Alert(
                title: Text(NSLocalizedString("blend.error.title", comment: "")),
                message: Text(err.errorDescription ?? ""),
                dismissButton: .cancel(Text(NSLocalizedString("blend.error.dismiss", comment: ""))) {
                    presentedError = nil
                    viewModel.dismissError()
                }
            )
        }
    }

    // MARK: Backgrounds

    private var background: some View {
        LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: Header

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.black.opacity(0.3))
                }
                .accessibilityLabel(NSLocalizedString("blend.close", comment: ""))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("blend.title", comment: ""))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))

                Text(NSLocalizedString("blend.subtitle", comment: ""))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
        }
    }

    // MARK: Shared hero shell

    private var heroCircle: some View {
        ZStack {
            Circle()
                .fill(mintVibrant.opacity(0.12))
                .frame(width: 160, height: 160)
                .blur(radius: 22)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 116, height: 116)
                .overlay(Circle().fill(Color.white.opacity(0.6)))
                .overlay(Circle().strokeBorder(mintVibrant.opacity(0.24), lineWidth: 1))
                .shadow(color: mintVibrant.opacity(0.12), radius: 16, x: 0, y: 6)

            Image(systemName: "headphones")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(mintVibrant)
        }
        .accessibilityHidden(true)
    }

    private var hamoudiSilhouette: some View {
        GeometryReader { proxy in
            Image("Captain_Hamoudi_DJ")
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width * 0.6)
                .opacity(0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }

    private var heroIntroStack: some View {
        VStack(spacing: 18) {
            heroCircle

            VStack(spacing: 6) {
                Text(NSLocalizedString("blend.cta.title", comment: ""))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))

                Text(NSLocalizedString("blend.cta.subtitle", comment: ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private func primaryCTA(title: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    ZStack {
                        Capsule().fill(Color.white)
                        Capsule().fill(
                            LinearGradient(
                                colors: [mint.opacity(0.35), sand.opacity(0.35)],
                                startPoint: UnitPoint(x: 0, y: 0.65),
                                endPoint: UnitPoint(x: 1, y: 0.35)
                            )
                        )
                    }
                )
                .overlay(Capsule().strokeBorder(mintVibrant.opacity(0.5), lineWidth: 1))
                .shadow(color: mintVibrant.opacity(0.14), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var privacyFooter: some View {
        Text(NSLocalizedString("blend.footer.privacy", comment: ""))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.4))
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private func heroShell(ctaTitle: String, ctaAction: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            ZStack {
                hamoudiSilhouette
                heroIntroStack
            }

            Spacer(minLength: 16)

            primaryCTA(title: ctaTitle, action: ctaAction)
                .padding(.horizontal, 28)
                .padding(.bottom, 14)

            privacyFooter
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: States

    /// Pre-authorization screen. Structured as a scrollable, tight-rhythm
    /// layout with an explicit permissions disclosure — required for Apple
    /// Guideline 5.1.1 (transparency) so the user sees exactly what Spotify
    /// access AiQo is about to request before tapping through to Spotify's
    /// own OAuth consent screen.
    private var connectView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Hero — compact, centered.
                VStack(spacing: 14) {
                    heroCircle
                        .padding(.top, 8)

                    VStack(spacing: 6) {
                        Text(NSLocalizedString("blend.cta.title", comment: ""))
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.85))

                        Text(NSLocalizedString("blend.cta.subtitle", comment: ""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                // Permissions disclosure — what Spotify access we're about to request.
                permissionDisclosureCard

                // CTA.
                primaryCTA(title: NSLocalizedString("blend.empty.cta", comment: "")) {
                    viewModel.connect()
                }
                .padding(.horizontal, 20)

                // Privacy footer.
                VStack(spacing: 6) {
                    Text(NSLocalizedString("blend.perm.privacy", comment: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.45))
                        .multilineTextAlignment(.center)

                    Text(NSLocalizedString("blend.perm.revoke", comment: ""))
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.black.opacity(0.35))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
    }

    private var permissionDisclosureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(mintVibrant)
                Text(NSLocalizedString("blend.perm.title", comment: ""))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.7))
                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                permissionRow(
                    icon: "music.note.list",
                    title: NSLocalizedString("blend.perm.tracks", comment: ""),
                    desc: NSLocalizedString("blend.perm.tracks.desc", comment: "")
                )
                permissionRow(
                    icon: "waveform",
                    title: NSLocalizedString("blend.perm.playback", comment: ""),
                    desc: NSLocalizedString("blend.perm.playback.desc", comment: "")
                )
                permissionRow(
                    icon: "play.circle.fill",
                    title: NSLocalizedString("blend.perm.control", comment: ""),
                    desc: NSLocalizedString("blend.perm.control.desc", comment: "")
                )
            }
        }
        .padding(18)
        .background(glassCard)
        .padding(.horizontal, 20)
    }

    private func permissionRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(mintVibrant.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(mintVibrant)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Text(desc)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private var ctaView: some View {
        heroShell(
            ctaTitle: NSLocalizedString("blend.cta.button", comment: "")
        ) {
            Task { await viewModel.buildAndPlay() }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 3)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(mintVibrant, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(animatePulse ? 360 : 0))
                    .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: animatePulse)

                Text("🎧").font(.system(size: 22))
            }
            .onAppear { animatePulse = true }

            VStack(spacing: 6) {
                Text(NSLocalizedString("blend.loading", comment: ""))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))

                Text(NSLocalizedString("blend.loading.sub", comment: ""))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    @State private var animatePulse = false

    private var playingView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                nowPlayingCard
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                if !viewModel.builtQueue.isEmpty {
                    upNextCard
                        .padding(.horizontal, 20)
                }

                Button {
                    Task { await viewModel.regenerate() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                        Text(NSLocalizedString("blend.regenerate", comment: ""))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(mintVibrant)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(mintVibrant.opacity(0.12))
                            .overlay(Capsule().strokeBorder(mintVibrant.opacity(0.3), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)

                footerStack
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
            }
        }
    }

    private var nowPlayingCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Text("🎧").font(.system(size: 28))

                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("blend.cta.title", comment: ""))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.85))

                    Text(NSLocalizedString("blend.cta.subtitle", comment: ""))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.5))
                }

                Spacer()
            }

            sourceBadge(viewModel.currentSource ?? .hamoudi)
                .opacity(viewModel.currentSource == nil ? 0.5 : 1)
                .animation(.easeInOut(duration: 0.4), value: viewModel.currentSource)

            if let name = trackName {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let artist = artistName {
                        Text(artist)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.45))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut(duration: 0.35), value: trackName)
            }

            if !viewModel.builtQueue.isEmpty {
                queueDots
            }
        }
        .padding(20)
        .background(glassCard)
    }

    /// Full list of tracks in the queue, with current-track highlight.
    private var upNextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(NSLocalizedString("blend.queue.title", comment: ""))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.5))
                Spacer()
                Text(queuePositionLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.45))
            }

            VStack(spacing: 6) {
                ForEach(Array(viewModel.builtQueue.enumerated()), id: \.element.id) { index, track in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.playFromQueue(startingAt: index)
                    } label: {
                        trackRow(track: track, index: index)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(glassCard)
    }

    private var queuePositionLabel: String {
        let total = viewModel.builtQueue.count
        guard total > 0 else { return "" }
        let currentIndex = viewModel.builtQueue.firstIndex { $0.uri == viewModel.currentURI }.map { $0 + 1 } ?? 1
        return "\(currentIndex) / \(total)"
    }

    private func trackRow(track: HamoudiQueuedTrack, index: Int) -> some View {
        let isActive = track.uri == viewModel.currentURI
        let meta = viewModel.trackMetadata[track.uri]
        let accent: Color = track.source == .user ? mintVibrant : sand

        return HStack(spacing: 12) {
            // Album art (or placeholder while loading).
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.10))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
                    )

                if let imageURL = meta?.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        default:
                            Image(systemName: track.source == .user ? "person.fill" : "headphones")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                    }
                } else {
                    Image(systemName: track.source == .user ? "person.fill" : "headphones")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(meta?.name ?? "—")
                    .font(.system(size: 14, weight: isActive ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(isActive ? 0.88 : 0.75))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let artist = meta?.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.45))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            } else {
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.35))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? accent.opacity(0.08) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.25), value: isActive)
    }

    /// Row of dots — one per track in the built queue, colored by source,
    /// and slightly emphasized on whichever track is currently playing.
    private var queueDots: some View {
        HStack(spacing: 6) {
            ForEach(viewModel.builtQueue) { track in
                let isActive = track.uri == viewModel.currentURI
                Circle()
                    .fill(track.source == .user ? mintVibrant : sand)
                    .frame(width: isActive ? 10 : 7, height: isActive ? 10 : 7)
                    .opacity(isActive ? 1.0 : 0.4)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .animation(.easeInOut(duration: 0.25), value: isActive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceBadge(_ source: HamoudiDJSource) -> some View {
        HStack(spacing: 10) {
            Image(systemName: source == .user ? "person.fill" : "headphones")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(source == .user ? mintVibrant : sand)

            Text(source == .user
                 ? NSLocalizedString("blend.source.user", comment: "")
                 : NSLocalizedString("blend.source.hamoudi", comment: ""))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.75))

            Spacer()

            Circle()
                .fill((source == .user ? mintVibrant : sand).opacity(0.3))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill((source == .user ? mintVibrant : sand).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder((source == .user ? mintVibrant : sand).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var transportBar: some View {
        HStack(spacing: 12) {
            if let source = viewModel.currentSource {
                HStack(spacing: 8) {
                    Image(systemName: source == .user ? "person.fill" : "headphones")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(source == .user ? mintVibrant : sand)

                    Text(source == .user
                         ? NSLocalizedString("blend.source.user", comment: "")
                         : NSLocalizedString("blend.source.hamoudi", comment: ""))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.75))
                        .lineLimit(1)
                }
            } else {
                Text(NSLocalizedString("blend.cta.title", comment: ""))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                transportButton(systemName: "backward.fill", size: 13) {
                    viewModel.skipPrevious()
                }

                transportButton(
                    systemName: isPlaying ? "pause.fill" : "play.fill",
                    size: 16,
                    isPrimary: true
                ) {
                    viewModel.togglePlayPause()
                }

                transportButton(systemName: "forward.fill", size: 13) {
                    viewModel.skipNext()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(glassCard)
        .animation(.spring(), value: isPlaying)
        .animation(.spring(), value: viewModel.currentSource)
    }

    private func transportButton(
        systemName: String,
        size: CGFloat,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(isPrimary ? mintVibrant : Color.black.opacity(0.6))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color.black.opacity(isPrimary ? 0.08 : 0.04))
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.8))
                )
        }
        .buttonStyle(.plain)
    }

    private var footerStack: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("blend.footer.privacy", comment: ""))
                .font(.system(size: 11))
                .foregroundStyle(Color.black.opacity(0.35))
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text(NSLocalizedString("blend.footer.powered_by", comment: ""))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.3))
                Text("Spotify")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(spotifyGreen)
            }
        }
    }

    // MARK: Glass card

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
}

// MARK: - HamoudiDJError conformance for .alert(item:)

extension HamoudiDJError: Identifiable {
    var id: String {
        switch self {
        case .notConnected: return "notConnected"
        case .buildFailed:  return "buildFailed"
        }
    }
}

#Preview {
    HamoudiDJView()
}
