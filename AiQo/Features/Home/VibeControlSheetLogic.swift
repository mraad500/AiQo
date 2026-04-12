import SwiftUI

extension VibeControlSheet {
    var bottomDockClearance: CGFloat {
        88
    }

    var bottomGridPadding: CGFloat {
        136
    }

    var aiqoSoundsContent: some View {
        VStack {
            Spacer(minLength: 0)
            vibeGrid
                .padding(.horizontal, 18)
                .padding(.bottom, bottomGridPadding)
        }
    }

    var spotifyContent: some View {
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
                .accessibilityLabel(vibeManager.isConnected ? "افتح سبوتيفاي" : "وصّل سبوتيفاي")

                // Hamoudi+you+DJ Blend button
                if AiQoFeatureFlags.hamoudiBlendEnabled {
                Button {
                    showBlendPlaylist = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.12, green: 0.85, blue: 0.38).opacity(0.32),
                                            Color(red: 0.46, green: 0.90, blue: 0.78).opacity(0.22)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 42, height: 42)

                            Text("🎧")
                                .font(.system(size: 18))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Hamoudi+you+DJ 🎧")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)

                            Text("امزج ذوقك مع حمودي")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.72))
                        }

                        Spacer()

                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.12, green: 0.85, blue: 0.38))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.12, green: 0.85, blue: 0.38).opacity(0.14),
                                                Color(red: 0.46, green: 0.90, blue: 0.78).opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(Color(red: 0.12, green: 0.85, blue: 0.38).opacity(0.32), lineWidth: 1.2)
                            }
                            .shadow(color: Color(red: 0.12, green: 0.85, blue: 0.38).opacity(0.12), radius: 14, x: 0, y: 6)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("افتح مزيج حمودي+انت+دي جي")
                } // end hamoudiBlendEnabled

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

                // Spotify Logout
                if vibeManager.isConnected {
                    Button {
                        vibeManager.logoutSpotify()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 12, weight: .semibold))

                            Text("سجل خروج من سبوتيفاي")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                                }
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("سجل خروج من سبوتيفاي")
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 112)
        }
    }

    var backgroundArtwork: some View {
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

    var topContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            sourceSection
        }
        .frame(maxWidth: 340, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 22)
    }

    var header: some View {
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

    var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("vibe.audioSource".localized)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))

            Picker("vibe.audioSource".localized, selection: $viewModel.selectedSource) {
                ForEach(VibePlaybackSource.allCases) { source in
                    Text(source.localizedName).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color(red: 0.15, green: 0.70, blue: 0.64))
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionBackground(cornerRadius: 18))
    }

    var vibeGrid: some View {
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

    var deckCardWidth: CGFloat { 132 }

    var deckCenterGap: CGFloat { 68 }

    @ViewBuilder
    func vibeCard(for mode: VibeMode, isWide: Bool) -> some View {
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

    var compactControlCard: some View {
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
            .accessibilityLabel("افتح إعدادات الفايب")

            Button(action: handleCompactPlayPauseTapped) {
                Image(systemName: currentPlaybackState == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(controlOrbBackground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(compactPlayPauseAccessibilityLabel)

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
            .accessibilityLabel("افتح دردشة الدي جي")
        }
        .padding(10)
        .background(sectionBackground(cornerRadius: 24))
    }

    var detailsSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("vibe.soundControls".localized)
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
                    .accessibilityLabel("تم")
                }

                detailSheetContent
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
    }

    var detailSheetContent: some View {
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
                    isEnabled: isPauseResumeAvailable,
                    accessibilityLabel: currentPlaybackState == .playing ? "أوقف التشغيل مؤقتًا" : "استأنف التشغيل"
                ) {
                    handlePauseResumeTapped()
                }

                secondaryControlButton(
                    title: "Stop",
                    systemName: "stop.fill",
                    isEnabled: currentPlaybackState != .stopped,
                    accessibilityLabel: "أوقف التشغيل"
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

    var mixSection: some View {
        Toggle(isOn: $viewModel.mixWithOthers) {
            VStack(alignment: .leading, spacing: 2) {
                Text("vibe.mixAudio".localized)
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

    var intensitySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("vibe.intensity".localized)
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

    var modeSummarySection: some View {
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
                    .accessibilityLabel("اعرف سبب عدم توفر سبوتيفاي")
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

    var playButton: some View {
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
        .accessibilityLabel(primaryAccessibilityLabel)
    }

    func sectionBackground(cornerRadius: CGFloat) -> some View {
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

    var activeAlertMessage: String? {
        aiqoAudioManager.lastErrorMessage ?? vibeManager.lastErrorMessage
    }

    var errorAlertIsPresented: Binding<Bool> {
        Binding(
            get: { activeAlertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    scheduleActiveAlertClear()
                }
            }
        )
    }

    var sourceStatusLabel: String {
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

    var currentNativeDayPartTitle: String {
        VibeDayPart.current().title
    }

    var selectedSourcePlaybackState: VibePlaybackState {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return aiqoAudioManager.playbackState
        case .spotify:
            return vibeManager.playbackState
        }
    }

    var currentPlaybackState: VibePlaybackState {
        switch controlledSource {
        case .aiqoSounds:
            return aiqoAudioManager.playbackState
        case .spotify:
            return vibeManager.playbackState
        }
    }

    var controlledSource: VibePlaybackSource {
        if aiqoAudioManager.playbackState != .stopped {
            return .aiqoSounds
        }

        if vibeManager.playbackState != .stopped {
            return .spotify
        }

        return viewModel.selectedSource
    }

    var displayedVibeTitle: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return viewModel.selectedMode.rawValue
        case .spotify:
            return vibeManager.currentVibeTitle ?? viewModel.selectedMode.rawValue
        }
    }

    var primaryButtonTitle: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return aiqoAudioManager.playbackState == .paused ? "Resume AiQo Sounds" : "Play AiQo Sounds"
        case .spotify:
            return vibeManager.isConnected ? "Play in Spotify" : "Connect Spotify"
        }
    }

    var primaryButtonSystemImage: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return "waveform.circle.fill"
        case .spotify:
            return vibeManager.isConnected ? "play.circle.fill" : "link.circle.fill"
        }
    }

    var primaryButtonTintColor: Color {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return Color(red: 0.10, green: 0.56, blue: 0.52)
        case .spotify:
            return vibeManager.isConnected
                ? Color(red: 0.12, green: 0.85, blue: 0.38)
                : .primary.opacity(0.66)
        }
    }

    var buttonGlowOpacity: Double {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return 0.24
        case .spotify:
            return vibeManager.isConnected ? 0.32 : 0
        }
    }

    var buttonShadowOpacity: Double {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return 0.18
        case .spotify:
            return vibeManager.isConnected ? 0.18 : 0.05
        }
    }

    var buttonShadowRadius: Double {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return 18
        case .spotify:
            return vibeManager.isConnected ? 18 : 10
        }
    }

    var isPlayActionAvailable: Bool {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return true
        case .spotify:
            return vibeManager.isPlaybackAvailable
        }
    }

    var isPauseResumeAvailable: Bool {
        switch controlledSource {
        case .aiqoSounds:
            return aiqoAudioManager.playbackState != .stopped
        case .spotify:
            return vibeManager.isConnected
        }
    }

    var selectedAiQoTrackDisplayName: String {
        viewModel.selectedMode.aiqoTrackName.replacingOccurrences(of: "_", with: " ")
    }

    var compactCardSystemImage: String {
        viewModel.selectedSource == .spotify ? "music.note" : "waveform"
    }

    var compactCardSubtitle: String {
        switch currentPlaybackState {
        case .playing:
            return viewModel.selectedSource == .spotify ? "Spotify is live" : "Tap for volume and text"
        case .paused:
            return "Paused"
        case .stopped:
            return viewModel.selectedSource == .spotify ? "Tap to configure Spotify" : "Tap for volume and text"
        }
    }

    var controlOrbBackground: some View {
        Circle()
            .fill(Color.white.opacity(0.14))
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
    }

    var spotifyPlaylistPreviews: [SpotifyPlaylistPreview] {
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

    var playButtonDetail: String {
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

    var compactPlayPauseAccessibilityLabel: String {
        switch currentPlaybackState {
        case .playing:
            return "أوقف الفايب مؤقتًا"
        case .paused:
            return "استأنف الفايب"
        case .stopped:
            return "شغّل الفايب"
        }
    }

    var primaryAccessibilityLabel: String {
        switch viewModel.selectedSource {
        case .aiqoSounds:
            return aiqoAudioManager.playbackState == .paused ? "استأنف أصوات AiQo" : "شغّل أصوات AiQo"
        case .spotify:
            return vibeManager.isConnected ? "شغّل القائمة في سبوتيفاي" : "وصّل سبوتيفاي"
        }
    }

    func handleSpotifyConnectTapped() {
        let previousSource = viewModel.selectedSource
        viewModel.selectedSource = .spotify
        handlePlayTapped()
        if previousSource != .spotify {
            viewModel.selectedSource = .spotify
        }
    }

    func handlePlayTapped() {
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

    func handleCompactPlayPauseTapped() {
        if currentPlaybackState == .stopped {
            handlePlayTapped()
        } else {
            handlePauseResumeTapped()
        }
    }

    @ViewBuilder
    func spotifyPlaylistCard(_ playlist: SpotifyPlaylistPreview) -> some View {
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
        .accessibilityLabel("شغّل قائمة \(playlist.title) في سبوتيفاي")
    }

    func handlePauseResumeTapped() {
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

    func handleStopTapped() {
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

    func restartNativeAudio() {
        aiqoAudioManager.setMixWithOthers(viewModel.mixWithOthers)
        aiqoAudioManager.setVolume(Float(viewModel.nativeIntensity))
    }

    func syncAiQoTrackToSelectedModeIfNeeded() {
        guard aiqoAudioManager.isPlaying else { return }

        let nextTrackName = viewModel.selectedMode.aiqoTrackName
        guard aiqoAudioManager.currentTrackName != nextTrackName else { return }

        aiqoAudioManager.setMixWithOthers(viewModel.mixWithOthers)
        aiqoAudioManager.setVolume(Float(viewModel.nativeIntensity))
        aiqoAudioManager.playAmbient(trackName: nextTrackName)
    }

    func stopSpotifyIfNeeded() {
        if vibeManager.playbackState != .stopped || vibeManager.isConnected {
            vibeManager.stopVibe()
        }
    }

    func scheduleActiveAlertClear() {
        DispatchQueue.main.async {
            clearActiveAlert()
        }
    }

    func clearActiveAlert() {
        aiqoAudioManager.clearError()
        vibeAudioEngine.clearError()
        vibeManager.clearError()
    }

    func secondaryControlButton(
        title: String,
        systemName: String,
        isEnabled: Bool,
        accessibilityLabel: String,
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
        .accessibilityLabel(accessibilityLabel)
    }
}
