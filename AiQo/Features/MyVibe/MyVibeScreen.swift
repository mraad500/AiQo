import SwiftUI

struct MyVibeScreen: View {
    @StateObject private var viewModel = MyVibeViewModel()
    @EnvironmentObject private var captainBrain: CaptainViewModel
    @Namespace private var heroNamespace

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                djHamoudiHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                vibeTimeline
                    .padding(.top, 28)

                frequencyCard
                    .padding(.horizontal, 20)
                    .padding(.top, 24)

                spotifyCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Spacer(minLength: 20)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            djSearchBar
        }
        .background {
            MyVibeBackground(state: viewModel.currentState, isDJModeActive: viewModel.isDJModeActive)
                .allowsHitTesting(false)
        }
        .preferredColorScheme(viewModel.isDJModeActive ? .dark : nil)
        .animation(.easeInOut(duration: 0.6), value: viewModel.isDJModeActive)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showDJChat) {
            DJCaptainChatView()
                .environmentObject(captainBrain)
        }
    }
}

// MARK: - DJ Hamoudi Header

private extension MyVibeScreen {
    var djHamoudiHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Captain image
            Image("Captain_Hamoudi_DJ")
                .resizable()
                .scaledToFill()
                .frame(height: 260)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay {
                    // Gradient scrim
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.65),
                            Color.black.opacity(0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .topTrailing) {
                    // Glowing status pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isPlaying ? Color(hex: "8AE3D1") : Color.white.opacity(0.4))
                            .frame(width: 7, height: 7)
                            .shadow(color: viewModel.isPlaying ? Color(hex: "8AE3D1").opacity(0.8) : .clear, radius: 4)

                        Text(viewModel.isPlaying ? NSLocalizedString("vibe.live", comment: "") : NSLocalizedString("vibe.idle", comment: ""))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                    .padding(16)
                }

            // Title overlay at bottom-left
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("vibe.myVibe", comment: ""))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(Color(hex: "8AE3D1").opacity(0.9))

                Text(NSLocalizedString("vibe.djHamoudi", comment: ""))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(viewModel.currentState.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.64))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 14)
        .contentShape(.interaction, RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

// MARK: - Timeline

private extension MyVibeScreen {
    var vibeTimeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(NSLocalizedString("vibe.bioTimeline", comment: ""))
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(viewModel.isDJModeActive ? Color.white.opacity(0.4) : .secondary)
                .padding(.leading, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DailyVibeState.allCases) { state in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                                viewModel.selectState(state)
                            }
                        } label: {
                            VibeTimelineNode(
                                state: state,
                                isActive: state == viewModel.currentState,
                                isPlaying: viewModel.isPlaying && state == viewModel.currentState
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Bio-Frequency Card

private extension MyVibeScreen {
    var frequencyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8AE3D1").opacity(0.3), Color(hex: "8AE3D1").opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "waveform")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "8AE3D1"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(NSLocalizedString("vibe.bioFrequency", comment: ""))
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(viewModel.isDJModeActive ? Color.white.opacity(0.46) : .secondary)

                    Text(viewModel.currentState.frequencyLabel.replacingOccurrences(of: "_", with: " "))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(viewModel.isDJModeActive ? .white : .primary)
                }

                Spacer()

                // Play/Pause
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.togglePlayback()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "8AE3D1"), Color(hex: "5ECDB7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: "8AE3D1").opacity(0.3), radius: 10, x: 0, y: 4)

                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.8))
                            .offset(x: viewModel.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
            }

            // Status detail
            Text(viewModel.bioFrequencyStatus)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(viewModel.isDJModeActive ? Color.white.opacity(0.5) : .secondary)
                .lineLimit(2)

            // Waveform visualizer placeholder
            if viewModel.isPlaying {
                VibeWaveformView()
                    .frame(height: 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, viewModel.isDJModeActive ? .dark : .light)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "8AE3D1").opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
        .contentShape(.interaction, RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Spotify Card

private extension MyVibeScreen {
    var spotifyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "1DB954").opacity(0.3), Color(hex: "1DB954").opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "music.note.list")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "1DB954"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(NSLocalizedString("vibe.spotifyLabel", comment: ""))
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(viewModel.isDJModeActive ? Color.white.opacity(0.46) : .secondary)

                        if viewModel.isSpotifyConnected {
                            Text(NSLocalizedString("vibe.connected", comment: ""))
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .foregroundStyle(Color(hex: "1DB954"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color(hex: "1DB954").opacity(0.14))
                                )
                        }
                    }

                    if let overrideName = viewModel.spotifyOverrideName {
                        Text(overrideName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(viewModel.isDJModeActive ? .white : .primary)
                    } else {
                        Text(viewModel.spotifyTrackName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(viewModel.isDJModeActive ? .white : .primary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Spotify connect / open button
                Button {
                    SpotifyVibeManager.shared.connect()
                } label: {
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(viewModel.isDJModeActive ? Color.white.opacity(0.6) : .secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            if !viewModel.spotifyArtistName.isEmpty {
                Text(viewModel.spotifyArtistName)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(viewModel.isDJModeActive ? Color.white.opacity(0.46) : .secondary)
            }

            if viewModel.spotifyOverrideName != nil {
                HStack(spacing: 6) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 11, weight: .semibold))
                    Text(NSLocalizedString("vibe.djOverride", comment: ""))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color(hex: "8AE3D1").opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(hex: "8AE3D1").opacity(0.10))
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, viewModel.isDJModeActive ? .dark : .light)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(hex: "1DB954").opacity(0.10), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
        .contentShape(.interaction, RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - DJ Search Bar

private extension MyVibeScreen {
    var djSearchBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "music.mic")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: "8AE3D1").opacity(0.7))

            TextField(NSLocalizedString("vibe.djPlaceholder", comment: ""), text: $viewModel.djSearchText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(viewModel.isDJModeActive ? .white : .primary)
                .submitLabel(.send)
                .onSubmit {
                    let text = viewModel.djSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    captainBrain.sendMessage(text, context: .myVibe)
                    viewModel.djSearchText = ""
                    viewModel.showDJChat = true
                }

            Button {
                viewModel.showDJChat = true
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "8AE3D1"), Color(hex: "5ECDB7")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)

                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, viewModel.isDJModeActive ? .dark : .light)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke((viewModel.isDJModeActive ? Color.white : Color.black).opacity(0.10), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MyVibeScreen()
            .environmentObject(CaptainViewModel())
    }
    .preferredColorScheme(.dark)
}
