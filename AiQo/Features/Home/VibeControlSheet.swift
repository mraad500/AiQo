import SwiftUI
import UIKit
internal import Combine

enum VibeMode: String, CaseIterable, Identifiable {
    case awakening = "Awakening"
    case deepFocus = "Deep Focus"
    case egoDeath = "Ego-Death (Zen)"
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
        case .recovery:
            return [
                Color(red: 0.12, green: 0.18, blue: 0.34),
                Color(red: 0.05, green: 0.08, blue: 0.17)
            ]
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
        case .recovery:
            return "spotify:playlist:37i9dQZF1DX4sWSpwq3LiO"
        }
    }
}

@MainActor
final class VibeControlViewModel: ObservableObject {
    @Published private(set) var selectedMode: VibeMode
    @Published private(set) var lastSyncedMode: VibeMode?

    var onSyncToSpotify: ((VibeMode) -> Void)?

    init(
        selectedMode: VibeMode = .deepFocus,
        onSyncToSpotify: ((VibeMode) -> Void)? = nil
    ) {
        self.selectedMode = selectedMode
        self.onSyncToSpotify = onSyncToSpotify
    }

    var title: String { "My Vibe" }
    var subtitle: String { "Subconscious Audio Sync" }
    var castTargetsLabel: String { "Alexa / JBL" }

    func select(_ mode: VibeMode) {
        guard selectedMode != mode else { return }
        selectedMode = mode
    }

    func markLastSyncedMode() {
        lastSyncedMode = selectedMode
    }

    func syncToSpotify() {
        markLastSyncedMode()
        onSyncToSpotify?(selectedMode)
    }
}

struct VibeControlSheet: View {
    @ObservedObject var viewModel: VibeControlViewModel
    @ObservedObject var vibeManager = SpotifyVibeManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

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
        .animation(.spring(), value: vibeManager.isConnected)
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
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(VibeMode.allCases) { mode in
                VibeModeCard(
                    mode: mode,
                    isSelected: viewModel.selectedMode == mode
                ) {
                    withAnimation(.spring()) {
                        viewModel.select(mode)
                    }
                }
            }
        }
    }

    private var actionArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected: \(viewModel.selectedMode.rawValue)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring()) {
                        viewModel.markLastSyncedMode()
                    }
                    vibeManager.playVibe(uri: viewModel.selectedMode.spotifyURI)
                } label: {
                    HStack(spacing: 12) {
                        SpotifyGlyph()

                        VStack(alignment: .leading, spacing: 3) {
                            Text(vibeManager.isConnected ? "Play Vibe" : "Connect & Sync")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .contentTransition(.opacity)

                            Text(vibeManager.isConnected ? viewModel.selectedMode.spotifyURI : "Launch Spotify and authenticate App Remote")
                                .font(
                                    .system(
                                        size: 11,
                                        weight: .medium,
                                        design: vibeManager.isConnected ? .monospaced : .rounded
                                    )
                                )
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .contentTransition(.opacity)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: vibeManager.isConnected ? "play.circle.fill" : "link.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(vibeManager.isConnected ? Color(red: 0.12, green: 0.85, blue: 0.38) : .primary.opacity(0.66))
                            .shadow(
                                color: Color(red: 0.12, green: 0.85, blue: 0.38).opacity(vibeManager.isConnected ? 0.32 : 0),
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
                                            colors: vibeManager.isConnected
                                                ? [
                                                    Color(red: 0.12, green: 0.85, blue: 0.38).opacity(0.26),
                                                    Color(red: 0.46, green: 0.90, blue: 0.78).opacity(0.18)
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
                                vibeManager.isConnected
                                    ? Color.white.opacity(0.42)
                                    : Color.white.opacity(0.32),
                                lineWidth: vibeManager.isConnected ? 1.2 : 1
                            )
                    }
                    .shadow(
                        color: Color(red: 0.12, green: 0.85, blue: 0.38).opacity(vibeManager.isConnected ? 0.18 : 0.05),
                        radius: vibeManager.isConnected ? 18 : 10,
                        x: 0,
                        y: 10
                    )
                    .scaleEffect(vibeManager.isConnected ? 1 : 0.985)
                }
                .buttonStyle(.plain)
                .animation(.spring(), value: vibeManager.isConnected)

                VibeCastBadge(label: viewModel.castTargetsLabel)
            }
        }
    }
}

struct VibeDashboardTriggerButton: View {
    var action: () -> Void

    private let preferredVibeIconName = "vibe_ icon"
    private let fallbackVibeIconName = "vibe_icon"

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
                    } else {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.78))
                    }
                }
                .frame(width: 32, height: 32)
            }
            .frame(width: 54, height: 54)
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

private struct VibeCastBadge: View {
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.72))

            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 76, height: 62)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.34))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        }
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
