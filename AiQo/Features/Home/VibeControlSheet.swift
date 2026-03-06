import SwiftUI
import UIKit
import AVKit
internal import Combine

struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemMint
        picker.tintColor = .white
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

enum VibeMode: String, CaseIterable, Identifiable, Codable {
    case awakening = "Awakening"
    case deepFocus = "Deep Focus"
    case egoDeath = "Ego-Death (Zen)"
    case energy = "Energy"
    case recovery = "Recovery"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .awakening:
            return "Bright frequency lift"
        case .deepFocus:
            return "Precision and clarity"
        case .egoDeath:
            return "Stillness and dissolve"
        case .energy:
            return "Brain ignition and warmup"
        case .recovery:
            return "Slow reset and repair"
        }
    }

    var systemIcon: String {
        switch self {
        case .awakening:
            return "sun.max.fill"
        case .deepFocus:
            return "scope"
        case .egoDeath:
            return "sparkles"
        case .energy:
            return "bolt.fill"
        case .recovery:
            return "moon.stars.fill"
        }
    }

    var accentColors: [Color] {
        switch self {
        case .awakening:
            return [
                Color(red: 1.00, green: 0.82, blue: 0.42),
                Color(red: 1.00, green: 0.61, blue: 0.38)
            ]
        case .deepFocus:
            return [
                Color(red: 0.46, green: 0.90, blue: 0.78),
                Color(red: 0.28, green: 0.74, blue: 0.63)
            ]
        case .egoDeath:
            return [
                Color(red: 0.76, green: 0.62, blue: 0.98),
                Color(red: 0.56, green: 0.45, blue: 0.92)
            ]
        case .energy:
            return [
                Color(red: 1.00, green: 0.67, blue: 0.24),
                Color(red: 0.63, green: 0.93, blue: 0.29)
            ]
        case .recovery:
            return [
                Color(red: 0.12, green: 0.18, blue: 0.34),
                Color(red: 0.05, green: 0.08, blue: 0.17)
            ]
        }
    }

    var aiqoTrackName: String {
        switch self {
        case .awakening:
            return "SerotoninFlow"
        case .deepFocus:
            return "GammaFlow"
        case .egoDeath:
            return "ThetaTrance"
        case .energy:
            return "SoundOfEnergy"
        case .recovery:
            return "Hypnagogic_state"
        }
    }

    // Replace these with AiQo-owned playlists when production routing is ready.
    var spotifyURI: String {
        switch self {
        case .awakening:
            return "spotify:playlist:37i9dQZF1DX3rxVfibe1L0"
        case .deepFocus:
            return "spotify:playlist:37i9dQZF1DWZeKCadgRdKQ"
        case .egoDeath:
            return "spotify:playlist:37i9dQZF1DWU0ScTcjJBdj"
        case .energy:
            return "spotify:playlist:37i9dQZF1DX76Wlfdnj7AP"
        case .recovery:
            return "spotify:playlist:37i9dQZF1DX4sWSpwq3LiO"
        }
    }
}

enum VibePlaybackSource: String, CaseIterable, Identifiable {
    case aiqoSounds = "AiQo Sounds"
    case spotify = "Spotify"

    var id: String { rawValue }
}

@MainActor
final class VibeControlViewModel: ObservableObject {
    @Published private(set) var selectedMode: VibeMode
    @Published private(set) var lastActivatedMode: VibeMode?
    @Published var selectedSource: VibePlaybackSource {
        didSet {
            UserDefaults.standard.set(selectedSource.rawValue, forKey: Self.sourceDefaultsKey)
        }
    }
    @Published var mixWithOthers: Bool {
        didSet {
            UserDefaults.standard.set(mixWithOthers, forKey: Self.mixDefaultsKey)
        }
    }
    @Published var nativeIntensity: Double {
        didSet {
            UserDefaults.standard.set(nativeIntensity, forKey: Self.intensityDefaultsKey)
        }
    }

    init(selectedMode: VibeMode = .deepFocus) {
        self.selectedMode = selectedMode
        self.selectedSource = VibePlaybackSource(
            rawValue: UserDefaults.standard.string(forKey: Self.sourceDefaultsKey) ?? ""
        ) ?? .aiqoSounds
        self.mixWithOthers = UserDefaults.standard.object(forKey: Self.mixDefaultsKey) as? Bool ?? true
        self.nativeIntensity = UserDefaults.standard.object(forKey: Self.intensityDefaultsKey) as? Double ?? 0.55
    }

    var title: String { "My Vibe" }
    var subtitle: String {
        switch selectedSource {
        case .aiqoSounds:
            return "AiQo background ambient audio"
        case .spotify:
            return "Spotify playlist control"
        }
    }

    func select(_ mode: VibeMode) {
        guard selectedMode != mode else { return }
        selectedMode = mode
    }

    func markLastActivatedMode() {
        lastActivatedMode = selectedMode
    }

    private static let sourceDefaultsKey = "com.aiqo.vibe.source"
    private static let mixDefaultsKey = "com.aiqo.vibe.mixWithOthers"
    private static let intensityDefaultsKey = "com.aiqo.vibe.nativeIntensity"
}

struct VibeControlSheet: View {
    @ObservedObject var viewModel: VibeControlViewModel
    @ObservedObject var vibeManager = SpotifyVibeManager.shared
    @ObservedObject var aiqoAudioManager = AiQoAudioManager.shared
    @ObservedObject var vibeAudioEngine = VibeAudioEngine.shared
    @EnvironmentObject private var captainBrain: CaptainViewModel
    @State private var isDetailsSheetPresented = false
    @State private var showDJChat = false

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                backgroundArtwork

                topContent

                if viewModel.selectedSource == .aiqoSounds {
                    aiqoSoundsContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    spotifyContent
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                compactControlCard
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.12),
                                Color.black.opacity(0.34)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    )
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.spring(), value: viewModel.selectedMode)
        .animation(.spring(), value: viewModel.selectedSource)
        .animation(.spring(), value: vibeManager.isConnected)
        .animation(.spring(), value: vibeManager.playbackState)
        .animation(.spring(), value: aiqoAudioManager.playbackState)
        .onChange(of: viewModel.selectedMode) { _, _ in
            syncAiQoTrackToSelectedModeIfNeeded()
        }
        .alert("My Vibe", isPresented: errorAlertIsPresented) {
            Button("OK", role: .cancel) {
                scheduleActiveAlertClear()
            }
        } message: {
            Text(activeAlertMessage ?? "Something went wrong while starting audio.")
        }
        .sheet(isPresented: $isDetailsSheetPresented) {
            detailsSheet
                .presentationDetents([.fraction(0.46), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showDJChat) {
            DJCaptainChatView()
                .environmentObject(captainBrain)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
    }

    private var bottomDockClearance: CGFloat {
        88
    }

    private var bottomGridPadding: CGFloat {
        136
    }

    private var aiqoSoundsContent: some View {
        VStack {
            Spacer(minLength: 0)
            vibeGrid
                .padding(.horizontal, 18)
                .padding(.bottom, bottomGridPadding)
        }
    }

    private var spotifyContent: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 14) {
                Button(action: handleSpotifyConnectTapped) {
                    HStack(spacing: 12) {
                        SpotifyGlyph()

                        VStack(alignment: .leading, spacing: 3) {
                            Text(vibeManager.isConnected ? "Spotify Connected" : "Connect to Spotify")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(vibeManager.isConnected ? "Open DJ Hamoudi playlists" : "Tap to link Spotify playback")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.76))
                        }

                        Spacer()

                        Image(systemName: vibeManager.isConnected ? "waveform.circle.fill" : "link.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(red: 0.12, green: 0.85, blue: 0.38))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(sectionBackground(cornerRadius: 26))
                }
                .buttonStyle(.plain)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DJ Hamoudi's Playlists")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        ForEach(spotifyPlaylistPreviews) { playlist in
                            spotifyPlaylistCard(playlist)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 112)
        }
    }

    private var backgroundArtwork: some View {
        GeometryReader { proxy in
            ZStack {
                Image("Captain_Hamoudi_DJ")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.16),
                        Color.black.opacity(0.46)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.clear,
                        Color(red: 0.01, green: 0.05, blue: 0.08).opacity(0.22),
                        Color(red: 0.01, green: 0.03, blue: 0.07).opacity(0.48)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color(red: 0.26, green: 0.82, blue: 0.74).opacity(0.10),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 30,
                    endRadius: 320
                )
                .ignoresSafeArea()
            }
        }
    }

    private var topContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            sourceSection
        }
        .frame(maxWidth: 340, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 22)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title)
                .font(.system(size: 29, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)

            Text(viewModel.subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .shadow(color: .black.opacity(0.26), radius: 16, x: 0, y: 8)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Audio Source")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))

            Picker("Audio Source", selection: $viewModel.selectedSource) {
                ForEach(VibePlaybackSource.allCases) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color(red: 0.15, green: 0.70, blue: 0.64))
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionBackground(cornerRadius: 18))
    }

    private var vibeGrid: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                vibeCard(for: .awakening, isWide: false)
                vibeCard(for: .egoDeath, isWide: false)
                vibeCard(for: .recovery, isWide: false)
            }
            .frame(width: deckCardWidth)

            Spacer(minLength: deckCenterGap)

            VStack(spacing: 8) {
                vibeCard(for: .deepFocus, isWide: false)
                vibeCard(for: .energy, isWide: false)
            }
            .frame(width: deckCardWidth)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private var deckCardWidth: CGFloat { 132 }

    private var deckCenterGap: CGFloat { 68 }

    @ViewBuilder
    private func vibeCard(for mode: VibeMode, isWide: Bool) -> some View {
        VibeModeCard(
            mode: mode,
            isSelected: viewModel.selectedMode == mode,
            isWide: isWide
        ) {
            withAnimation(.spring()) {
                viewModel.select(mode)
            }
        }
    }

    private var compactControlCard: some View {
        HStack(spacing: 10) {
            Button {
                isDetailsSheetPresented = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 34, height: 34)

                        Image(systemName: compactCardSystemImage)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(primaryButtonTintColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayedVibeTitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(compactCardSubtitle)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.74))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)

            Button(action: handleCompactPlayPauseTapped) {
                Image(systemName: currentPlaybackState == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(controlOrbBackground)
            }
            .buttonStyle(.plain)

            RoutePickerView().frame(width: 32, height: 32)

            Button {
                showDJChat = true
            } label: {
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(controlOrbBackground)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(sectionBackground(cornerRadius: 24))
    }

    private var detailsSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sound Controls")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(displayedVibeTitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Done") {
                        isDetailsSheetPresented = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                }

                detailSheetContent
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
    }

    private var detailSheetContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.selectedSource == .aiqoSounds {
                mixSection
                intensitySection
            }

            modeSummarySection

            HStack(spacing: 10) {
                secondaryControlButton(
                    title: currentPlaybackState == .playing ? "Pause" : "Resume",
                    systemName: currentPlaybackState == .playing ? "pause.fill" : "play.fill",
                    isEnabled: isPauseResumeAvailable
                ) {
                    handlePauseResumeTapped()
                }

                secondaryControlButton(
                    title: "Stop",
                    systemName: "stop.fill",
                    isEnabled: currentPlaybackState != .stopped
                ) {
                    handleStopTapped()
                }
            }

            playButton
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionBackground(cornerRadius: 28))
    }

    private var mixSection: some View {
        Toggle(isOn: $viewModel.mixWithOthers) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mix with other audio")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Text("Keep AiQo Sounds active while music or podcasts play.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineLimit(1)
            }
        }
        .toggleStyle(.switch)
        .tint(Color(red: 0.10, green: 0.56, blue: 0.52))
        .onChange(of: viewModel.mixWithOthers) { _, _ in
            aiqoAudioManager.setMixWithOthers(viewModel.mixWithOthers)

            if aiqoAudioManager.playbackState == .playing {
                restartNativeAudio()
            }
        }
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Intensity")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))

                Spacer()

                Text("\(Int(viewModel.nativeIntensity * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))
            }

            Slider(value: $viewModel.nativeIntensity, in: 0.1...1)
                .tint(Color(red: 0.10, green: 0.56, blue: 0.52))
                .onChange(of: viewModel.nativeIntensity) { _, newValue in
                    aiqoAudioManager.setVolume(Float(newValue))
                }
        }
    }

    private var modeSummarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Selected Mode")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.82))

                    Text(displayedVibeTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Text(viewModel.selectedMode.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                }

                Spacer(minLength: 0)

                if viewModel.selectedSource == .spotify && !vibeManager.isPlaybackAvailable {
                    Button("Why unavailable?") {
                        vibeManager.presentAvailabilityError()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.46, green: 0.90, blue: 0.78))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    StatusPill(label: sourceStatusLabel)
                    StatusPill(label: selectedSourcePlaybackState.rawValue)

                    if viewModel.selectedSource == .aiqoSounds {
                        StatusPill(label: currentNativeDayPartTitle)
                    }
                }
            }
        }
    }

    private var playButton: some View {
        Button(action: handlePlayTapped) {
            HStack(spacing: 12) {
                if viewModel.selectedSource == .spotify {
                    SpotifyGlyph()
                } else {
                    AiQoSoundGlyph()
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(primaryButtonTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .contentTransition(.opacity)

                    Text(playButtonDetail)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.76))
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }

                Spacer(minLength: 0)

                Image(systemName: primaryButtonSystemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(primaryButtonTintColor)
                    .shadow(
                        color: primaryButtonTintColor.opacity(buttonGlowOpacity),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: viewModel.selectedSource == .spotify && vibeManager.isConnected
                                        ? [
                                            Color(red: 0.12, green: 0.85, blue: 0.38).opacity(0.26),
                                            Color(red: 0.46, green: 0.90, blue: 0.78).opacity(0.18)
                                        ]
                                        : viewModel.selectedSource == .aiqoSounds
                                        ? [
                                            Color(red: 0.10, green: 0.56, blue: 0.52).opacity(0.22),
                                            Color(red: 0.30, green: 0.78, blue: 0.70).opacity(0.16)
                                        ]
                                        : [
                                            Color.white.opacity(0.26),
                                            Color.white.opacity(0.1)
                                        ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        (viewModel.selectedSource == .spotify && vibeManager.isConnected) || viewModel.selectedSource == .aiqoSounds
                            ? Color.white.opacity(0.42)
                            : Color.white.opacity(0.32),
                        lineWidth: ((viewModel.selectedSource == .spotify && vibeManager.isConnected) || viewModel.selectedSource == .aiqoSounds) ? 1.2 : 1
                    )
            }
            .shadow(
                color: primaryButtonTintColor.opacity(buttonShadowOpacity),
                radius: buttonShadowRadius,
                x: 0,
                y: 10
            )
            .scaleEffect(((viewModel.selectedSource == .spotify && vibeManager.isConnected) || viewModel.selectedSource == .aiqoSounds) ? 1 : 0.985)
        }
        .buttonStyle(.plain)
        .disabled(!isPlayActionAvailable)
        .opacity(isPlayActionAvailable ? 1 : 0.58)
        .animation(.spring(), value: viewModel.selectedSource)
    }

    private func sectionBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.10))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 8)
    }

    private var activeAlertMessage: String? {
        aiqoAudioManager.lastErrorMessage ?? vibeManager.lastErrorMessage
    }

    private var errorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { activeAlertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    scheduleActiveAlertClear()
                }
            }
        )
    }

    private var sourceStatusLabel: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            switch aiqoAudioManager.playbackState {
            case .playing:
                return "AiQo Sounds active"
            case .paused:
                return "AiQo Sounds paused"
            case .stopped:
                return "AiQo Sounds ready"
            }
        case .spotify:
            if vibeManager.isConnected {
                return "Spotify connected"
            }

            if vibeManager.isPlaybackAvailable {
                return "Spotify disconnected"
            }

            return "Spotify unavailable"
        }
    }

    private var currentNativeDayPartTitle: String {
        VibeDayPart.current().title
    }

    private var selectedSourcePlaybackState: VibePlaybackState {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return aiqoAudioManager.playbackState
        case .spotify:
            return vibeManager.playbackState
        }
    }

    private var currentPlaybackState: VibePlaybackState {
        switch controlledSource {
        case .aiqoSounds:
            return aiqoAudioManager.playbackState
        case .spotify:
            return vibeManager.playbackState
        }
    }

    private var controlledSource: VibePlaybackSource {
        if aiqoAudioManager.playbackState != .stopped {
            return .aiqoSounds
        }

        if vibeManager.playbackState != .stopped {
            return .spotify
        }

        return viewModel.selectedSource
    }

    private var displayedVibeTitle: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return viewModel.selectedMode.rawValue
        case .spotify:
            return vibeManager.currentVibeTitle ?? viewModel.selectedMode.rawValue
        }
    }

    private var primaryButtonTitle: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return aiqoAudioManager.playbackState == .paused ? "Resume AiQo Sounds" : "Play AiQo Sounds"
        case .spotify:
            return vibeManager.isConnected ? "Play in Spotify" : "Connect Spotify"
        }
    }

    private var primaryButtonSystemImage: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return "waveform.circle.fill"
        case .spotify:
            return vibeManager.isConnected ? "play.circle.fill" : "link.circle.fill"
        }
    }

    private var primaryButtonTintColor: Color {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return Color(red: 0.10, green: 0.56, blue: 0.52)
        case .spotify:
            return vibeManager.isConnected
                ? Color(red: 0.12, green: 0.85, blue: 0.38)
                : .primary.opacity(0.66)
        }
    }

    private var buttonGlowOpacity: Double {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return 0.24
        case .spotify:
            return vibeManager.isConnected ? 0.32 : 0
        }
    }

    private var buttonShadowOpacity: Double {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return 0.18
        case .spotify:
            return vibeManager.isConnected ? 0.18 : 0.05
        }
    }

    private var buttonShadowRadius: Double {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return 18
        case .spotify:
            return vibeManager.isConnected ? 18 : 10
        }
    }

    private var isPlayActionAvailable: Bool {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return true
        case .spotify:
            return vibeManager.isPlaybackAvailable
        }
    }

    private var isPauseResumeAvailable: Bool {
        switch controlledSource {
        case .aiqoSounds:
            return aiqoAudioManager.playbackState != .stopped
        case .spotify:
            return vibeManager.isConnected
        }
    }

    private var selectedAiQoTrackDisplayName: String {
        viewModel.selectedMode.aiqoTrackName.replacingOccurrences(of: "_", with: " ")
    }

    private var compactCardSystemImage: String {
        viewModel.selectedSource == .spotify ? "music.note" : "waveform"
    }

    private var compactCardSubtitle: String {
        switch currentPlaybackState {
        case .playing:
            return viewModel.selectedSource == .spotify ? "Spotify is live" : "Tap for volume and text"
        case .paused:
            return "Paused"
        case .stopped:
            return viewModel.selectedSource == .spotify ? "Tap to configure Spotify" : "Tap for volume and text"
        }
    }

    private var controlOrbBackground: some View {
        Circle()
            .fill(Color.white.opacity(0.14))
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
    }

    private var spotifyPlaylistPreviews: [SpotifyPlaylistPreview] {
        [
            SpotifyPlaylistPreview(
                title: "Deep Work Beats",
                subtitle: "Low-noise focus selection",
                uri: VibeMode.deepFocus.spotifyURI
            ),
            SpotifyPlaylistPreview(
                title: "Morning Wakeup",
                subtitle: "Bright start with forward motion",
                uri: VibeMode.awakening.spotifyURI
            ),
            SpotifyPlaylistPreview(
                title: "Zen Mode",
                subtitle: "Still, clean, and spacious",
                uri: VibeMode.egoDeath.spotifyURI
            )
        ]
    }

    private var playButtonDetail: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return "\(selectedAiQoTrackDisplayName) in background"
        case .spotify:
            if !vibeManager.isSpotifyAppInstalled {
                return "Install Spotify"
            }

            if !vibeManager.canAttemptAuthorization {
                return "Spotify auth unavailable"
            }

            if vibeManager.isConnected {
                return "Start selected playlist"
            }

            return "Open Spotify to connect"
        }
    }

    private func handleSpotifyConnectTapped() {
        let previousSource = viewModel.selectedSource
        viewModel.selectedSource = .spotify
        handlePlayTapped()
        if previousSource != .spotify {
            viewModel.selectedSource = .spotify
        }
    }

    private func handlePlayTapped() {
        withAnimation(.spring()) {
            viewModel.markLastActivatedMode()
        }

        switch viewModel.selectedSource {
        case .aiqoSounds:
            stopSpotifyIfNeeded()
            if vibeAudioEngine.currentState.isActive {
                vibeAudioEngine.stop()
            }

            aiqoAudioManager.setMixWithOthers(viewModel.mixWithOthers)
            aiqoAudioManager.setVolume(Float(viewModel.nativeIntensity))
            aiqoAudioManager.playAmbient(trackName: viewModel.selectedMode.aiqoTrackName)
        case .spotify:
            guard vibeManager.isPlaybackAvailable else {
                vibeManager.presentAvailabilityError()
                return
            }

            aiqoAudioManager.stopAmbient()
            if vibeAudioEngine.currentState.isActive {
                vibeAudioEngine.stop()
            }

            vibeManager.playVibe(
                uri: viewModel.selectedMode.spotifyURI,
                vibeTitle: viewModel.selectedMode.rawValue
            )
        }
    }

    private func handleCompactPlayPauseTapped() {
        if currentPlaybackState == .stopped {
            handlePlayTapped()
        } else {
            handlePauseResumeTapped()
        }
    }

    @ViewBuilder
    private func spotifyPlaylistCard(_ playlist: SpotifyPlaylistPreview) -> some View {
        Button {
            guard vibeManager.isPlaybackAvailable else {
                vibeManager.presentAvailabilityError()
                return
            }

            viewModel.selectedSource = .spotify
            vibeManager.playVibe(uri: playlist.uri, vibeTitle: playlist.title)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.85, blue: 0.38).opacity(0.22))
                        .frame(width: 38, height: 38)

                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(red: 0.12, green: 0.85, blue: 0.38))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(playlist.subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.74))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(sectionBackground(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private func handlePauseResumeTapped() {
        switch controlledSource {
        case .aiqoSounds:
            if aiqoAudioManager.playbackState == .playing {
                aiqoAudioManager.pauseAmbient()
            } else {
                aiqoAudioManager.playAmbient(trackName: viewModel.selectedMode.aiqoTrackName)
            }
        case .spotify:
            if vibeManager.playbackState == .playing {
                vibeManager.pauseVibe()
            } else {
                vibeManager.resumeVibe()
            }
        }
    }

    private func handleStopTapped() {
        switch controlledSource {
        case .aiqoSounds:
            aiqoAudioManager.stopAmbient()
            if vibeAudioEngine.currentState.isActive {
                vibeAudioEngine.stop()
            }
        case .spotify:
            vibeManager.stopVibe()
        }
    }

    private func restartNativeAudio() {
        aiqoAudioManager.setMixWithOthers(viewModel.mixWithOthers)
        aiqoAudioManager.setVolume(Float(viewModel.nativeIntensity))
    }

    private func syncAiQoTrackToSelectedModeIfNeeded() {
        guard aiqoAudioManager.isPlaying else { return }

        let nextTrackName = viewModel.selectedMode.aiqoTrackName
        guard aiqoAudioManager.currentTrackName != nextTrackName else { return }

        aiqoAudioManager.setMixWithOthers(viewModel.mixWithOthers)
        aiqoAudioManager.setVolume(Float(viewModel.nativeIntensity))
        aiqoAudioManager.playAmbient(trackName: nextTrackName)
    }

    private func stopSpotifyIfNeeded() {
        if vibeManager.playbackState != .stopped || vibeManager.isConnected {
            vibeManager.stopVibe()
        }
    }

    private func scheduleActiveAlertClear() {
        DispatchQueue.main.async {
            clearActiveAlert()
        }
    }

    private func clearActiveAlert() {
        aiqoAudioManager.clearError()
        vibeAudioEngine.clearError()
        vibeManager.clearError()
    }

    private func secondaryControlButton(
        title: String,
        systemName: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(0.55))
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.16 : 0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.26 : 0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
    }
}

struct VibeDashboardTriggerButton: View {
    var action: () -> Void

    private let preferredVibeIconName = "vibe_ icon"
    private let fallbackVibeIconName = "vibe_icon"
    private let buttonSize: CGFloat = 64
    private let imageSize: CGFloat = 58
    private let fallbackSymbolSize: CGFloat = 28
    private let fallbackFrameSize: CGFloat = 38

    private var vibeIconName: String? {
        if UIImage(named: preferredVibeIconName) != nil {
            return preferredVibeIconName
        }

        if UIImage(named: fallbackVibeIconName) != nil {
            return fallbackVibeIconName
        }

        return nil
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.36))

                Circle()
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)

                Group {
                    if let vibeIconName {
                        Image(vibeIconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageSize, height: imageSize)
                    } else {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: fallbackSymbolSize, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.78))
                            .frame(width: fallbackFrameSize, height: fallbackFrameSize)
                    }
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open My Vibe")
    }
}

private struct SpotifyPlaylistPreview: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let uri: String
}

private struct VibeModeCard: View {
    let mode: VibeMode
    let isSelected: Bool
    let isWide: Bool
    let action: () -> Void

    @State private var animateGlow = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(isSelected ? 0.18 : 0.10))
                        .frame(width: isWide ? 20 : 18, height: isWide ? 20 : 18)

                    Image(systemName: mode.systemIcon)
                        .font(.system(size: isWide ? 8 : 7, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary.opacity(0.78))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.rawValue)
                        .font(.system(size: isWide ? 9 : 8, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(2)

                    Text(mode.subtitle)
                        .font(.system(size: 6, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.76) : .secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: isWide ? 0 : 0, maxHeight: isWide ? 44 : 50, alignment: .topLeading)
            .background(cardBackground)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                        .padding(4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                animateGlow.toggle()
            }
        }
        .animation(.spring(), value: isSelected)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.04 : 0.02))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: mode.accentColors.map { $0.opacity(isSelected ? 0.42 : 0.08) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isSelected ? (animateGlow ? 1.01 : 0.99) : 0.98)
                    .rotationEffect(.degrees(animateGlow ? 1 : -1))
                    .blur(radius: 4)
                    .opacity(isSelected ? 0.86 : 0.34)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(isSelected ? 0.18 : 0.08),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: mode.accentColors.first?.opacity(isSelected ? 0.10 : 0.02) ?? .clear,
                radius: isSelected ? 4 : 2,
                x: 0,
                y: 2
            )
    }
}

private struct StatusPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.16))
            )
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            }
    }
}

private struct AiQoSoundGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.56, blue: 0.52),
                            Color(red: 0.26, green: 0.78, blue: 0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "waveform.path")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.96))
        }
        .frame(width: 28, height: 28)
    }
}

private struct SpotifyGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.12, green: 0.85, blue: 0.38))

            VStack(spacing: 3) {
                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 16, height: 2.4)
                    .rotationEffect(.degrees(8))

                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 13, height: 2.2)
                    .rotationEffect(.degrees(8))

                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 10, height: 2.0)
                    .rotationEffect(.degrees(8))
            }
        }
        .frame(width: 28, height: 28)
    }
}

#Preview {
    VibeControlSheet(viewModel: VibeControlViewModel())
        .environmentObject(CaptainViewModel())
        .presentationBackground(.ultraThinMaterial)
}
