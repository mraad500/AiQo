import SwiftUI

struct TribeRingView: View {
    let summary: TribeHeroSummary
    let featuredMembers: [TribeFeaturedMember]

    @State private var displayedProgress = 0.0
    @State private var hasAnimated = false

    private var progress: Double {
        min(max(summary.progress, 0), 1)
    }

    private var activeMemberCount: Int {
        featuredMembers.filter { $0.isVacant == false }.count
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                ambientGlowLayer(size: size)
                ringTrackLayer(size: size)
                ringFillLayer(size: size)

                TribeRingCenterCard(summary: summary)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .shadow(color: TribeModernPalette.shadow.opacity(0.08), radius: 18, x: 0, y: 14)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            guard hasAnimated == false else { return }
            hasAnimated = true
            withAnimation(.spring(response: 1.1, dampingFraction: 0.88).delay(0.08)) {
                displayedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.9, dampingFraction: 0.9)) {
                displayedProgress = newValue
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("حلقة القبيلة، \(activeMemberCount) أعضاء نشطين")
    }

    @ViewBuilder
    private func ambientGlowLayer(size: CGFloat) -> some View {
        ForEach(TribeRingSegmentToken.ringOrder) { segment in
            let segmentProgress = progressForSegment(segment)

            Circle()
                .fill(segment.glowColor)
                .frame(width: size * 0.33, height: size * 0.33)
                .blur(radius: size * 0.11)
                .offset(
                    x: segment.ambientOffset.width * size,
                    y: segment.ambientOffset.height * size
                )
                .opacity(0.06 + (segmentProgress * 0.24))
        }
    }

    @ViewBuilder
    private func ringTrackLayer(size: CGFloat) -> some View {
        ForEach(TribeRingSegmentToken.ringOrder) { segment in
            ringImage(for: segment, size: size)
                .opacity(0.18)
                .saturation(0.45)
                .brightness(0.04)
        }
    }

    @ViewBuilder
    private func ringFillLayer(size: CGFloat) -> some View {
        ForEach(TribeRingSegmentToken.ringOrder) { segment in
            let segmentProgress = progressForSegment(segment)

            ringImage(for: segment, size: size)
                .opacity(segmentProgress == 0 ? 0 : 1)
                .mask {
                    TribeRingRevealMask(
                        startAngle: segment.revealStartAngle,
                        endAngle: segment.revealStartAngle + (segment.revealSweep * segmentProgress)
                    )
                }
                .scaleEffect(0.985 + (segmentProgress * 0.015))
                .shadow(color: segment.accent.opacity(0.22), radius: size * 0.045, x: 0, y: size * 0.02)
        }
    }

    private func ringImage(for segment: TribeRingSegmentToken, size: CGFloat) -> some View {
        Image(segment.assetName)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
    }

    private func progressForSegment(_ segment: TribeRingSegmentToken) -> Double {
        guard let index = TribeRingSegmentToken.revealOrder.firstIndex(of: segment) else {
            return 0
        }

        let step = 1 / Double(TribeRingSegmentToken.revealOrder.count)
        let lowerBound = Double(index) * step
        return min(max((displayedProgress - lowerBound) / step, 0), 1)
    }
}

private struct TribeRingCenterCard: View {
    let summary: TribeHeroSummary

    var body: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.92),
                                    TribeModernPalette.sandSoft.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(TribeModernPalette.borderStrong, lineWidth: 1)
                }
                .overlay {
                    Circle()
                        .stroke(TribeModernPalette.surfaceHighlight, lineWidth: 0.8)
                        .padding(2)
                }

            VStack(spacing: 5) {
                Text(summary.centerValue)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textPrimary)

                Text(summary.centerLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(TribeModernPalette.textSecondary)
            }
            .multilineTextAlignment(.center)
        }
    }
}

private struct TribeRingRevealMask: Shape {
    var startAngle: Double
    var endAngle: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle, endAngle) }
        set {
            startAngle = newValue.first
            endAngle = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = hypot(rect.width, rect.height)
        let resolvedEnd = max(endAngle, startAngle)

        var path = Path()
        path.move(to: center)
        path.addLine(to: point(in: rect, angle: startAngle, radius: radius))

        for angle in stride(from: startAngle, through: resolvedEnd, by: 1) {
            path.addLine(to: point(in: rect, angle: angle, radius: radius))
        }

        path.addLine(to: center)
        path.closeSubpath()
        return path
    }

    private func point(in rect: CGRect, angle: Double, radius: CGFloat) -> CGPoint {
        let radians = (angle - 90) * Double.pi / 180
        let center = CGPoint(x: rect.midX, y: rect.midY)

        return CGPoint(
            x: center.x + (CGFloat(cos(radians)) * radius),
            y: center.y + (CGFloat(sin(radians)) * radius)
        )
    }
}
