import SwiftUI
import UIKit
internal import Combine

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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                vibeGrid
                actionArea
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.28),
                        Color(red: 0.82, green: 0.95, blue: 0.91).opacity(0.18),
                        Color(red: 0.96, green: 0.88, blue: 0.97).opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(red: 0.46, green: 0.90, blue: 0.78).opacity(0.15))
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .offset(x: 120, y: -80)
            }
            .ignoresSafeArea()
        }
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(viewModel.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var vibeGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
            ForEach(Array(vibeRows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    if row.count == 1, let mode = row.first {
                        vibeCard(for: mode)
                            .gridCellColumns(2)
                    } else {
                        ForEach(row) { mode in
                            vibeCard(for: mode)
                        }
                    }
                }
            }
        }
    }

    private var vibeRows: [[VibeMode]] {
        let modes = VibeMode.allCases
        return stride(from: 0, to: modes.count, by: 2).map { startIndex in
            let endIndex = min(startIndex + 2, modes.count)
            return Array(modes[startIndex..<endIndex])
        }
    }

    @ViewBuilder
    private func vibeCard(for mode: VibeMode) -> some View {
        VibeModeCard(
            mode: mode,
            isSelected: viewModel.selectedMode == mode
        ) {
            withAnimation(.spring()) {
                viewModel.select(mode)
            }
        }
    }

    private var actionArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Audio Source")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Picker("Audio Source", selection: $viewModel.selectedSource) {
                ForEach(VibePlaybackSource.allCases) { source in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.selectedSource == .aiqoSounds {
                Toggle(isOn: $viewModel.mixWithOthers) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mix with other audio")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text("Keep AiQo Sounds active while music or podcasts play.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
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

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Intensity")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(viewModel.nativeIntensity * 100))%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $viewModel.nativeIntensity, in: 0.1...1)
                        .tint(Color(red: 0.10, green: 0.56, blue: 0.52))
                        .onChange(of: viewModel.nativeIntensity) { _, newValue in
                            aiqoAudioManager.setVolume(Float(newValue))
                        }
                }
            }

            Text("Selected Mode")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.selectedMode.rawValue)
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                HStack(spacing: 8) {
                    StatusPill(label: sourceStatusLabel)
                    StatusPill(label: "Playback: \(selectedSourcePlaybackState.rawValue)")

                    if viewModel.selectedSource == .aiqoSounds {
                        StatusPill(label: currentNativeDayPartTitle)
                    }
                }

                Text("Current Vibe: \(displayedVibeTitle)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                if viewModel.selectedSource == .aiqoSounds {
                    Text(aiqoAudioManager.detailText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    if aiqoAudioManager.playbackState == .playing {
                        StatusPill(label: "Running in background")
                    }
                } else if vibeManager.currentTrackName != "Not Playing" {
                    Text("Track: \(vibeManager.currentTrackName)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Button(action: handlePlayTapped) {
                HStack(spacing: 12) {
                    if viewModel.selectedSource == .spotify {
                        SpotifyGlyph()
                    } else {
                        AiQoSoundGlyph()
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(primaryButtonTitle)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .contentTransition(.opacity)

                        Text(playButtonDetail)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 62)
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

            HStack(spacing: 12) {
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

            if viewModel.selectedSource == .spotify && !vibeManager.isPlaybackAvailable {
                Button("Why unavailable?") {
                    vibeManager.presentAvailabilityError()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.42, blue: 0.36))
            } else if viewModel.selectedSource == .aiqoSounds {
                Text("AiQo audio can keep playing in the background while active. Pause or stop it instantly at any time.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
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

    private var playButtonDetail: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return "Loops \(selectedAiQoTrackDisplayName) in the background while active"
        case .spotify:
            if !vibeManager.isSpotifyAppInstalled {
                return "Install Spotify to use playlist controls"
            }

            if !vibeManager.canAttemptAuthorization {
                return "Spotify authentication is unavailable"
            }

            if vibeManager.isConnected {
                return "Start the selected playlist in Spotify"
            }

            return "Open Spotify and approve playback control"
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
                    .font(.system(size: 13, weight: .semibold))

                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.28 : 0.18))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.34 : 0.2), lineWidth: 1)
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
    private let buttonSize: CGFloat = 70
    private let imageSize: CGFloat = 64
    private let fallbackSymbolSize: CGFloat = 30
    private let fallbackFrameSize: CGFloat = 42

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

private struct VibeModeCard: View {
    let mode: VibeMode
    let isSelected: Bool
    let action: () -> Void

    @State private var animateGlow = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(isSelected ? 0.28 : 0.18))
                        .frame(width: 42, height: 42)

                    Image(systemName: mode.systemIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .primary.opacity(0.78))
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .primary)

                    Text(mode.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.78) : .secondary)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .background(cardBackground)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                        .padding(14)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isSelected ? 1.0 : 0.985)
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
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: mode.accentColors.map { $0.opacity(isSelected ? 0.72 : 0.16) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isSelected ? (animateGlow ? 1.16 : 0.94) : 0.9)
                    .rotationEffect(.degrees(animateGlow ? 8 : -8))
                    .blur(radius: isSelected ? 0 : 8)
                    .opacity(isSelected ? 1 : 0.48)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(isSelected ? 0.42 : 0.24),
                        lineWidth: isSelected ? 1.2 : 1
                    )
            }
            .shadow(
                color: mode.accentColors.first?.opacity(isSelected ? 0.22 : 0.04) ?? .clear,
                radius: isSelected ? 18 : 10,
                x: 0,
                y: 10
            )
    }
}

private struct StatusPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.3))
            )
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
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
        .presentationBackground(.ultraThinMaterial)
}
