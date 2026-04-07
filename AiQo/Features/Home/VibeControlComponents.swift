import SwiftUI
import UIKit

struct VibeDashboardTriggerButton: View {
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let preferredVibeIconName = "vibe_ icon"
    private let fallbackVibeIconName = "vibe_icon"
    private let buttonSize: CGFloat = 65
    private let imageSize: CGFloat = 65
    private let fallbackSymbolSize: CGFloat = 34
    private let fallbackFrameSize: CGFloat = 52

    private var borderTint: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.14)
        : Color.white.opacity(0.62)
    }

    private var shadowTint: Color {
        colorScheme == .dark
        ? Color.black.opacity(0.18)
        : Color.black.opacity(0.08)
    }

    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.08 : 0.54),
                Color.aiqoMint.opacity(colorScheme == .dark ? 0.08 : 0.16),
                Color.aiqoSand.opacity(colorScheme == .dark ? 0.05 : 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var iconGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.aiqoMint.opacity(colorScheme == .dark ? 0.10 : 0.18),
                        Color.aiqoSand.opacity(colorScheme == .dark ? 0.06 : 0.12),
                        .clear
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: 22
                )
            )
            .frame(width: 56, height: 56)
            .blur(radius: 7)
    }

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
            Group {
                if let vibeIconName {
                    Image(vibeIconName)
                        .renderingMode(.original)
                        .interpolation(.high)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize, height: imageSize)
                } else {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)

                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: fallbackSymbolSize, weight: .semibold))
                            .foregroundStyle(Color(red: 0.34, green: 0.30, blue: 0.26))
                            .frame(width: fallbackFrameSize, height: fallbackFrameSize)
                    }
                    .frame(width: buttonSize, height: buttonSize)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("افتح ماي فايب")
    }
}

struct SpotifyPlaylistPreview: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let uri: String
}

struct VibeModeCard: View {
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
        .accessibilityLabel("اختر \(mode.accessibilityTitle)")
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

extension VibeMode {
    var accessibilityTitle: String {
        switch self {
        case .awakening:
            return "وضع الاستيقاظ"
        case .deepFocus:
            return "وضع التركيز العميق"
        case .egoDeath:
            return "وضع الهدوء العميق"
        case .energy:
            return "وضع الطاقة"
        case .recovery:
            return "وضع التعافي"
        }
    }
}

struct StatusPill: View {
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

struct AiQoSoundGlyph: View {
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

struct SpotifyGlyph: View {
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
