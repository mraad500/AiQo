import SwiftUI

enum TribeMarketingSource {
    case settings
    case premium
    case tab
}

enum TribeScreenshotMode {
    static let key = "aiqo.debug.screenshotModeEnabled"
}

enum TribeMarketingInterest: String, CaseIterable, Hashable, Identifiable {
    case fitness = "Fitness"
    case discipline = "Discipline"
    case mindset = "Mindset"

    var id: String { rawValue }
}

enum TribePremiumPalette {
    static let midnightTop = Color(red: 0.04, green: 0.07, blue: 0.13)
    static let midnightBottom = Color(red: 0.08, green: 0.10, blue: 0.16)
    static let charcoal = Color(red: 0.10, green: 0.11, blue: 0.15)
    static let highlight = Color(red: 0.47, green: 0.69, blue: 0.95)
    static let glow = Color(red: 0.76, green: 0.83, blue: 1.0)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.72)
    static let stroke = Color.white.opacity(0.16)
}

struct PremiumBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TribePremiumPalette.midnightTop,
                    TribePremiumPalette.charcoal,
                    TribePremiumPalette.midnightBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    TribePremiumPalette.highlight.opacity(0.22),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 260
            )
            .offset(x: 80, y: -110)

            RadialGradient(
                colors: [
                    TribePremiumPalette.glow.opacity(0.16),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 12,
                endRadius: 240
            )
            .offset(x: -90, y: 140)

            PremiumConstellationOverlay()
            PremiumNoiseOverlay()
        }
        .ignoresSafeArea()
    }
}

struct PremiumGlassCard<Content: View>: View {
    let tint: UIColor
    @ViewBuilder private let content: Content

    init(
        tint: UIColor = UIColor(red: 0.35, green: 0.45, blue: 0.68, alpha: 1),
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background {
                PremiumGlassCardBackground(tint: tint)
            }
            .shadow(color: Color.white.opacity(0.05), radius: 18, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.22), radius: 28, x: 0, y: 14)
    }
}

struct PrimaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .background(
                LinearGradient(
                    colors: [
                        TribePremiumPalette.highlight.opacity(configuration.isPressed ? 0.76 : 0.92),
                        Color(red: 0.29, green: 0.47, blue: 0.80).opacity(configuration.isPressed ? 0.74 : 0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: TribePremiumPalette.highlight.opacity(0.24), radius: 18, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

private struct PremiumGlassCardBackground: UIViewRepresentable {
    let tint: UIColor

    func makeUIView(context: Context) -> GlassCardView {
        let view = GlassCardView()
        view.isUserInteractionEnabled = false
        view.setTint(tint)
        return view
    }

    func updateUIView(_ uiView: GlassCardView, context: Context) {
        uiView.setTint(tint)
    }
}

private struct PremiumConstellationOverlay: View {
    private let normalizedPoints: [CGPoint] = [
        CGPoint(x: 0.10, y: 0.14),
        CGPoint(x: 0.28, y: 0.20),
        CGPoint(x: 0.48, y: 0.12),
        CGPoint(x: 0.74, y: 0.21),
        CGPoint(x: 0.90, y: 0.15),
        CGPoint(x: 0.18, y: 0.44),
        CGPoint(x: 0.36, y: 0.36),
        CGPoint(x: 0.58, y: 0.46),
        CGPoint(x: 0.80, y: 0.40),
        CGPoint(x: 0.22, y: 0.72),
        CGPoint(x: 0.47, y: 0.64),
        CGPoint(x: 0.71, y: 0.78)
    ]

    private let links: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 4),
        (1, 6), (6, 7), (7, 8),
        (5, 6), (6, 2), (7, 10),
        (9, 10), (10, 11), (5, 9),
        (3, 8)
    ]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let points = normalizedPoints.map { point in
                    CGPoint(x: point.x * size.width, y: point.y * size.height)
                }

                var path = Path()
                for link in links {
                    path.move(to: points[link.0])
                    path.addLine(to: points[link.1])
                }

                context.stroke(
                    path,
                    with: .color(TribePremiumPalette.glow.opacity(0.08)),
                    lineWidth: 1
                )

                for point in points {
                    let nodeRect = CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)
                    context.fill(Path(ellipseIn: nodeRect), with: .color(Color.white.opacity(0.28)))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
    }
}

private struct PremiumNoiseOverlay: View {
    private let speckles: [CGPoint] = [
        CGPoint(x: 0.12, y: 0.10), CGPoint(x: 0.21, y: 0.16), CGPoint(x: 0.66, y: 0.09),
        CGPoint(x: 0.82, y: 0.13), CGPoint(x: 0.17, y: 0.29), CGPoint(x: 0.34, y: 0.26),
        CGPoint(x: 0.54, y: 0.33), CGPoint(x: 0.76, y: 0.28), CGPoint(x: 0.08, y: 0.49),
        CGPoint(x: 0.28, y: 0.56), CGPoint(x: 0.44, y: 0.48), CGPoint(x: 0.62, y: 0.58),
        CGPoint(x: 0.84, y: 0.50), CGPoint(x: 0.16, y: 0.76), CGPoint(x: 0.39, y: 0.72),
        CGPoint(x: 0.58, y: 0.80), CGPoint(x: 0.73, y: 0.68), CGPoint(x: 0.90, y: 0.74)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(speckles.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(Color.white.opacity(index.isMultiple(of: 3) ? 0.12 : 0.08))
                        .frame(width: index.isMultiple(of: 4) ? 2.5 : 1.5, height: index.isMultiple(of: 4) ? 2.5 : 1.5)
                        .position(
                            x: point.x * geometry.size.width,
                            y: point.y * geometry.size.height
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
