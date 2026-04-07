// Supabase hook: keep the shared styling in this file and feed it with remote colors
// or theme flags once the Tribe payload becomes server-driven.
import SwiftUI
import UIKit

enum TribePalette {
    static let backgroundTop = Color(red: 0.95, green: 0.98, blue: 0.96)
    static let backgroundBottom = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let glowMint = Color.aiqoMint.opacity(0.42)
    static let glowSand = Color.aiqoSand.opacity(0.34)
    static let star = Color(red: 0.44, green: 0.58, blue: 0.52)

    static let surface = Color.white.opacity(0.78)
    static let surfaceStrong = Color.white.opacity(0.92)
    static let surfaceMint = Color.aiqoMint.opacity(0.26)
    static let surfaceSand = Color.aiqoSand.opacity(0.24)
    static let iconBadge = Color.white.opacity(0.5)

    static let border = Color.black.opacity(0.06)
    static let shadow = Color(red: 0.58, green: 0.67, blue: 0.62).opacity(0.20)

    static let textPrimary = Color.black.opacity(0.82)
    static let textSecondary = Color.black.opacity(0.58)
    static let textTertiary = Color.black.opacity(0.42)

    static let chip = Color.aiqoMint.opacity(0.34)
    static let chipStrong = Color.aiqoMint.opacity(0.52)
    static let actionPrimary = Color.aiqoSand.opacity(0.92)
    static let actionSecondary = Color.aiqoMint.opacity(0.34)

    static let progressTrack = Color.aiqoMint.opacity(0.34)
    static let progressFill = Color.aiqoSand.opacity(0.92)
}

struct TribeGalaxyBackground: View {
    private let starField: [CGPoint] = [
        CGPoint(x: 0.08, y: 0.11), CGPoint(x: 0.14, y: 0.18), CGPoint(x: 0.26, y: 0.08),
        CGPoint(x: 0.42, y: 0.14), CGPoint(x: 0.59, y: 0.09), CGPoint(x: 0.77, y: 0.16),
        CGPoint(x: 0.91, y: 0.10), CGPoint(x: 0.17, y: 0.36), CGPoint(x: 0.31, y: 0.28),
        CGPoint(x: 0.53, y: 0.33), CGPoint(x: 0.70, y: 0.29), CGPoint(x: 0.86, y: 0.35),
        CGPoint(x: 0.10, y: 0.58), CGPoint(x: 0.24, y: 0.64), CGPoint(x: 0.44, y: 0.56),
        CGPoint(x: 0.62, y: 0.67), CGPoint(x: 0.79, y: 0.61), CGPoint(x: 0.92, y: 0.72),
        CGPoint(x: 0.19, y: 0.83), CGPoint(x: 0.36, y: 0.78), CGPoint(x: 0.58, y: 0.88),
        CGPoint(x: 0.76, y: 0.82)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TribePalette.backgroundTop,
                    Color.white,
                    TribePalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    TribePalette.glowMint,
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 280
            )
            .offset(x: 80, y: -90)

            RadialGradient(
                colors: [
                    TribePalette.glowSand,
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 24,
                endRadius: 260
            )
            .offset(x: -90, y: 140)

            GeometryReader { geometry in
                Canvas { context, size in
                    for (index, point) in starField.enumerated() {
                        let dot = CGRect(
                            x: (point.x * size.width) - 1,
                            y: (point.y * size.height) - 1,
                            width: index.isMultiple(of: 4) ? 2.6 : 1.6,
                            height: index.isMultiple(of: 4) ? 2.6 : 1.6
                        )
                        context.fill(
                            Path(ellipseIn: dot),
                            with: .color(TribePalette.star.opacity(index.isMultiple(of: 3) ? 0.18 : 0.10))
                        )
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

struct TribeGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 30
    var padding: CGFloat = 18
    var tint: Color = TribePalette.surfaceMint
    @ViewBuilder private let content: Content

    init(
        cornerRadius: CGFloat = 30,
        padding: CGFloat = 18,
        tint: Color = TribePalette.surfaceMint,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(TribePalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(TribePalette.border, lineWidth: 1)
                    )
            }
            .shadow(color: TribePalette.shadow, radius: 24, x: 0, y: 14)
    }
}

struct TribeSegmentedPill<Option: Identifiable & Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var selectedTextColor: Color = TribePalette.textPrimary
    var unselectedTextColor: Color = TribePalette.textSecondary
    var activeFill: Color = TribePalette.chipStrong
    var backgroundFill: Color = TribePalette.surfaceStrong
    var borderColor: Color = TribePalette.border

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options) { option in
                let isSelected = option == selection

                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? selectedTextColor : unselectedTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isSelected ? activeFill : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            Capsule()
                .fill(backgroundFill)
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }
}

private enum GalaxyProjectImageAsset {
    static let candidateNames: [String] = [
        "galaxyـscreen",
        "galaxy-screen",
        "galaxy_screen",
        "Galaxyـscreen",
        "Galaxy-screen",
        "Galaxy_screen",
        "GalaxyScreen",
        "Galaxy_iconh",
        "Galaxy_icon"
    ]

    static var image: UIImage? {
        candidateNames.lazy.compactMap { UIImage(named: $0) }.first
    }
}

struct GalaxyProjectImageCard: View {
    var cornerRadius: CGFloat = 28
    var height: CGFloat? = nil
    var contentMode: ContentMode = .fit

    var body: some View {
        TribeGlassCard(
            cornerRadius: cornerRadius,
            padding: 12,
            tint: TribePalette.surfaceStrong.opacity(0.08)
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.aiqoMint.opacity(0.10),
                                Color.aiqoSand.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let image = GalaxyProjectImageAsset.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))

                        Text("galaxyـscreen")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))

                        Text("أضف الصورة إلى Assets.xcassets لعرضها هنا.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .multilineTextAlignment(.center)
                    .padding(20)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 8, style: .continuous))
        }
    }
}
