import SwiftUI

struct ModernCognitiveIndicatorView: View {
    let state: CoachCognitiveState

    @Environment(\.colorScheme) private var colorScheme
    private var theme: CaptainTheme { CaptainTheme(colorScheme: colorScheme) }

    private var leadingColor: Color {
        state.accentColors.first ?? Color.white.opacity(0.24)
    }

    private var trailingColor: Color {
        state.accentColors.last ?? Color.white.opacity(0.16)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                ModernCognitiveGlowView(
                    leadingColor: leadingColor,
                    trailingColor: trailingColor
                )

                Image(systemName: state.symbolName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.96),
                                Color.white.opacity(0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(width: 66, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("Captain Consciousness")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(theme.subtext.opacity(0.74))

                Text(state.statusText ?? "الكابتن حاضر")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(theme.text)
                    .lineLimit(1)

                Text(state.detailText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(theme.subtext)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ModernCognitiveActivityBarsView(
                state: state,
                leadingColor: leadingColor,
                trailingColor: trailingColor
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.18 : 0.38),
                                    leadingColor.opacity(0.36),
                                    trailingColor.opacity(0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.16 : 0.34),
                            leadingColor.opacity(0.22),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 96, height: 1.1)
                .padding(.top, 8)
                .padding(.leading, 14)
        }
        .shadow(
            color: trailingColor.opacity(colorScheme == .dark ? 0.18 : 0.10),
            radius: 18,
            x: 0,
            y: 10
        )
        .contentTransition(.opacity)
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: state)
    }
}

private struct ModernCognitiveGlowView: View {
    let leadingColor: Color
    let trailingColor: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if #available(iOS 18.0, *) {
                ModernCognitiveMeshGlowView(
                    leadingColor: leadingColor,
                    trailingColor: trailingColor
                )
            } else {
                ModernCognitiveFallbackGlowView(
                    leadingColor: leadingColor,
                    trailingColor: trailingColor
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
        )
    }
}

@available(iOS 18.0, *)
private struct ModernCognitiveMeshGlowView: View {
    let leadingColor: Color
    let trailingColor: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let driftA = Float((sin(time * 0.85) + 1) * 0.5)
            let driftB = Float((cos(time * 0.68) + 1) * 0.5)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    MeshGradient(
                        width: 2,
                        height: 2,
                        points: [
                            SIMD2<Float>(0.02 + (driftA * 0.10), 0.05 + (driftB * 0.08)),
                            SIMD2<Float>(0.94 - (driftB * 0.10), 0.04 + (driftA * 0.06)),
                            SIMD2<Float>(0.06 + (driftB * 0.08), 0.96 - (driftA * 0.08)),
                            SIMD2<Float>(0.95 - (driftA * 0.07), 0.95 - (driftB * 0.10))
                        ],
                        colors: [
                            leadingColor.opacity(0.95),
                            trailingColor.opacity(0.90),
                            trailingColor.opacity(0.84),
                            leadingColor.opacity(0.72)
                        ]
                    )
                )
                .blur(radius: 10)
                .scaleEffect(1.06)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 34
                            )
                        )
                        .blendMode(.screen)
                )
        }
    }
}

private struct ModernCognitiveFallbackGlowView: View {
    let leadingColor: Color
    let trailingColor: Color

    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(leadingColor.opacity(0.42))
                .frame(
                    width: isExpanded ? 42 : 28,
                    height: isExpanded ? 42 : 28
                )
                .offset(x: isExpanded ? -10 : -2, y: isExpanded ? -4 : 2)

            Circle()
                .fill(trailingColor.opacity(0.38))
                .frame(
                    width: isExpanded ? 34 : 22,
                    height: isExpanded ? 34 : 22
                )
                .offset(x: isExpanded ? 10 : 3, y: isExpanded ? 6 : 0)

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(
                    width: isExpanded ? 24 : 16,
                    height: isExpanded ? 24 : 16
                )
                .offset(x: isExpanded ? 2 : -1, y: isExpanded ? -8 : -2)
        }
        .blur(radius: 9)
        .scaleEffect(isExpanded ? 1.04 : 0.92)
        .onAppear {
            isExpanded = true
        }
        .animation(
            .spring(response: 2.1, dampingFraction: 0.76)
                .repeatForever(autoreverses: true),
            value: isExpanded
        )
    }
}

private struct ModernCognitiveActivityBarsView: View {
    let state: CoachCognitiveState
    let leadingColor: Color
    let trailingColor: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    let speed = max(1.1, state.rotationDuration * 0.62) + (Double(index) * 0.16)
                    let wave = (sin((time / speed) + Double(index)) + 1) * 0.5
                    let height = 8 + (wave * (10 + Double(index * 2)))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    leadingColor.opacity(0.94),
                                    trailingColor.opacity(0.44)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: height)
                }
            }
            .frame(width: 20, height: 24)
        }
    }
}
