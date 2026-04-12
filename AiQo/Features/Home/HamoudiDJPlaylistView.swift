import SwiftUI

struct HamoudiDJPlaylistView: View {
    @StateObject private var viewModel = HamoudiBlendViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var animatePulse = false

    // Brand colors
    private let mint = Color(hex: "B7E5D2")
    private let mintVibrant = Color(hex: "5ECDB7")
    private let sand = Color(hex: "EBCF97")
    private let bgTop = Color(hex: "FAFAF7")
    private let bgBottom = Color(hex: "F3F4F1")
    private let spotifyGreen = Color(red: 0.12, green: 0.85, blue: 0.38)

    var body: some View {
        if !AiQoFeatureFlags.hamoudiBlendEnabled {
            blendDisabledPlaceholder
        } else {
            mainContent
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                if viewModel.isBuilding {
                    loadingState
                } else if !viewModel.isConnectedToSpotify && viewModel.blendQueue.isEmpty {
                    spotifyConnectEmptyState
                } else if viewModel.isConnectedToSpotify && !viewModel.isWebAPIAuthorized && viewModel.blendQueue.isEmpty {
                    authorizeState
                } else if viewModel.blendQueue.isEmpty {
                    blendCTAState
                } else {
                    blendContent
                }

                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !viewModel.blendQueue.isEmpty {
                    transportControls
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
        .task { await viewModel.onSheetAppear() }
        .environment(\.layoutDirection, .rightToLeft)
        .alert(
            NSLocalizedString("blend.error.title", comment: ""),
            isPresented: showErrorAlert,
            presenting: viewModel.error
        ) { error in
            switch error {
            case .spotifyAppNotInstalled:
                Button(NSLocalizedString("blend.error.open_appstore", comment: "")) {
                    if let url = URL(string: "https://apps.apple.com/app/spotify/id324684580") {
                        UIApplication.shared.open(url)
                    }
                }
                Button(NSLocalizedString("blend.error.dismiss", comment: ""), role: .cancel) {
                    viewModel.error = nil
                }
            case .requiresPremium:
                Button(NSLocalizedString("blend.error.learn_more", comment: "")) {
                    if let url = URL(string: "https://www.spotify.com/premium") {
                        UIApplication.shared.open(url)
                    }
                }
                Button(NSLocalizedString("blend.error.dismiss", comment: ""), role: .cancel) {
                    viewModel.error = nil
                }
            default:
                Button(NSLocalizedString("blend.error.dismiss", comment: ""), role: .cancel) {
                    viewModel.error = nil
                }
            }
        } message: { error in
            Text(error.errorDescription ?? "")
        }
    }

    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [bgTop, bgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

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

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("blend.title", comment: ""))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))

                Text(NSLocalizedString("blend.subtitle", comment: ""))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
        }
    }

    // MARK: - Spotify Connect Empty State

    private var spotifyConnectEmptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(mintVibrant.opacity(0.12))
                    .frame(width: 80, height: 80)
                    .blur(radius: 8)

                Image(systemName: "headphones")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(mintVibrant)
            }

            VStack(spacing: 8) {
                Text(NSLocalizedString("blend.empty.title", comment: ""))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))

                Text(NSLocalizedString("blend.empty.subtitle", comment: ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                viewModel.connectSpotify()
            } label: {
                Text(NSLocalizedString("blend.empty.cta", comment: ""))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "5ECDB7"), Color(hex: "4AB89F")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: mintVibrant.opacity(0.3), radius: 12, x: 0, y: 6)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Authorize Web API

    private var authorizeState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.badge.key")
                .font(.system(size: 36))
                .foregroundStyle(mintVibrant)

            Text(NSLocalizedString("blend.authorize.title", comment: ""))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                viewModel.authorizeWebAPI()
            } label: {
                Text(NSLocalizedString("blend.authorize.button", comment: ""))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(mintVibrant))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
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

                Text("\u{1F3A7}")
                    .font(.system(size: 22))
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

    // MARK: - Blend CTA (authorized, no queue yet)

    private var blendCTAState: some View {
        VStack(spacing: 24) {
            Spacer()

            Button {
                Task { await viewModel.buildAndPlay() }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(mintVibrant.opacity(0.18))
                            .frame(width: 48, height: 48)

                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(mintVibrant)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("blend.cta.title", comment: ""))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.85))

                        Text(NSLocalizedString("blend.cta.subtitle", comment: ""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(mintVibrant)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(glassCard)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Blend Content (playing)

    private var blendContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                nowPlayingCard
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                queueVisualization
                    .padding(.horizontal, 20)

                // Regenerate ("مزيج جديد")
                Button {
                    Task { await viewModel.regenerateBlend() }
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

                blendFooter
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
            }
        }
    }

    // MARK: - Now Playing Card

    private var nowPlayingCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Text("\u{1F3A7}")
                    .font(.system(size: 28))

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

            // Source badge — animates between user/hamoudi
            if let source = viewModel.playback.currentSource {
                sourceBadge(source)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.4), value: viewModel.playback.currentSource)
            } else {
                sourceBadge(.hamoudi)
                    .opacity(0.5)
            }

            // Current track info (in-memory only — never persisted)
            if let trackName = viewModel.playback.currentTrackName {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trackName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let artistName = viewModel.playback.currentArtistName {
                        Text(artistName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.45))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.35), value: viewModel.playback.currentTrackName)
            }

            // Waveform
            if viewModel.playback.isPlaying {
                BlendWaveformView(accentColor: mintVibrant)
                    .frame(height: 32)
            }
        }
        .padding(20)
        .background(glassCard)
    }

    // MARK: - Source Badge

    private func sourceBadge(_ source: BlendSourceTag) -> some View {
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
                .fill(source == .user ? mintVibrant.opacity(0.3) : sand.opacity(0.3))
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

    // MARK: - Queue Visualization

    private var queueVisualization: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("blend.queue.title", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.5))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                ForEach(viewModel.blendQueue) { track in
                    Circle()
                        .fill(track.source == .user ? mintVibrant : sand)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                        )
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle().fill(mintVibrant).frame(width: 8, height: 8)
                    Text(NSLocalizedString("blend.source.user", comment: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.5))
                }

                HStack(spacing: 6) {
                    Circle().fill(sand).frame(width: 8, height: 8)
                    Text(NSLocalizedString("blend.source.hamoudi", comment: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
            }
        }
        .padding(16)
        .background(glassCard)
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 12) {
            if let source = viewModel.playback.currentSource {
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
                    viewModel.playback.skipPrevious()
                }

                transportButton(
                    systemName: viewModel.playback.isPlaying ? "pause.fill" : "play.fill",
                    size: 16,
                    isPrimary: true
                ) {
                    viewModel.playback.togglePlayPause()
                }

                transportButton(systemName: "forward.fill", size: 13) {
                    viewModel.playback.skipNext()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(glassCard)
        .animation(.spring(), value: viewModel.playback.isPlaying)
        .animation(.spring(), value: viewModel.playback.currentSource)
    }

    private func transportButton(systemName: String, size: CGFloat, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
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

    // MARK: - Footer

    private var blendFooter: some View {
        VStack(spacing: 8) {
            Text(NSLocalizedString("blend.footer.privacy", comment: ""))
                .font(.system(size: 11))
                .foregroundStyle(Color.black.opacity(0.35))
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text("Powered by")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.3))
                Text("Spotify")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(spotifyGreen)
            }
        }
    }

    // MARK: - Disabled Placeholder

    private var blendDisabledPlaceholder: some View {
        ZStack {
            background

            Text(NSLocalizedString("blend.disabled.placeholder", comment: ""))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.4))
        }
    }

    // MARK: - Glass Card

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

// MARK: - Waveform Animation

struct BlendWaveformView: View {
    let accentColor: Color
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<16, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.4), accentColor.opacity(0.8)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3)
                    .frame(height: animating ? CGFloat.random(in: 8...28) : CGFloat.random(in: 4...12))
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.3...0.7))
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.05),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

#Preview {
    HamoudiDJPlaylistView()
}
