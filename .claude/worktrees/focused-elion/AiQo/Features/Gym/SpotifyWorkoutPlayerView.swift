import SwiftUI
import UIKit

struct SpotifyWorkoutPlayerView: View {
    @ObservedObject var vibeManager = SpotifyVibeManager.shared
    var onOpenLibrary: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 16) {
            libraryTrigger
            controls
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color(red: 0.07, green: 0.14, blue: 0.12).opacity(0.36)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 10)
        .environment(\.colorScheme, .dark)
        .animation(.spring(), value: vibeManager.currentTrackName)
        .animation(.spring(), value: vibeManager.currentAlbumArt)
        .animation(.spring(), value: vibeManager.isPaused)
    }

    private var libraryTrigger: some View {
        Group {
            if let onOpenLibrary {
                Button(action: onOpenLibrary) {
                    libraryTriggerContent
                }
                .buttonStyle(.plain)
            } else {
                libraryTriggerContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var libraryTriggerContent: some View {
        HStack(spacing: 14) {
            albumArt
            trackDetails

            if onOpenLibrary != nil {
                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.34))
            }
        }
        .contentShape(Rectangle())
    }

    private var albumArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.01)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let art = vibeManager.currentAlbumArt {
                Image(uiImage: art)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))

                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 22, height: 3)
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var trackDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(vibeManager.currentTrackName)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .contentTransition(.opacity)

            Text(vibeManager.currentArtistName.isEmpty ? "Spotify App Remote" : vibeManager.currentArtistName)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
                .lineLimit(1)
                .contentTransition(.opacity)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            controlButton(systemName: "backward.fill", action: vibeManager.skipPrevious)

            Button(action: togglePlayback) {
                Circle()
                    .fill(Color(red: 0.0, green: 0.85, blue: 0.65))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: vibeManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.black.opacity(0.86))
                    }
                    .shadow(
                        color: Color(red: 0.0, green: 0.85, blue: 0.65).opacity(0.36),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
            }
            .buttonStyle(.plain)

            controlButton(systemName: "forward.fill", action: vibeManager.skipNext)
        }
    }

    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.72))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    private func togglePlayback() {
        if vibeManager.isPaused {
            vibeManager.resumeVibe()
        } else {
            vibeManager.pauseVibe()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SpotifyWorkoutPlayerView()
            .padding(20)
    }
}
