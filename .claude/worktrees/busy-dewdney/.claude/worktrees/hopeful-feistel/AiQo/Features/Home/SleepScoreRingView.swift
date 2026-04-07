import SwiftUI

struct SleepScoreRingView: View {
    @Environment(\.colorScheme) private var colorScheme

    let score: Int?
    let hasData: Bool
    let size: CGFloat

    @State private var animatedScore: Double = 0
    @State private var animatedSegmentProgress: [String: Double]
    @State private var segmentAnimationTask: Task<Void, Never>?
    @State private var hasAppeared = false

    init(score: Int?, hasData: Bool, size: CGFloat = 236) {
        self.score = score
        self.hasData = hasData
        self.size = size
        _animatedSegmentProgress = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: Self.segments.map { ($0.assetName, 0) }
            )
        )
    }

    private enum Layout {
        static let centerInset: CGFloat = 0.19
    }

    // These angles were measured from the supplied PDF assets on their shared square canvas.
    private static let segments: [SleepRingAssetSegment] = makeSegments()

    private var clampedScore: Int {
        min(max(score ?? 0, 0), 100)
    }

    private var targetScore: Double {
        hasData ? Double(clampedScore) : 0
    }

    private var centerInset: CGFloat {
        size * Layout.centerInset
    }

    private var inactiveOpacity: Double {
        colorScheme == .dark ? 0.34 : 0.24
    }

    private var displayScoreText: String {
        hasData ? "\(Int(animatedScore.rounded()))" : "—"
    }

    var body: some View {
        ZStack {
            ringAssets

            VStack(spacing: 4) {
                Text(displayScoreText)
                    .font(.system(size: size * 0.19, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)

                Text("من 100")
                    .font(.system(size: size * 0.05, weight: .semibold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textSecondary)

                Text("تقييم النوم")
                    .font(.system(size: size * 0.055, weight: .bold, design: .rounded))
                    .foregroundStyle(AiQoTheme.Colors.textPrimary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: size - (centerInset * 2))
        }
        .frame(width: size, height: size)
        .padding(.vertical, 8)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            animatedScore = 0
            resetSegmentProgress()
            animateToTarget(initialAppearance: true)
        }
        .onChange(of: score) { _, _ in
            animateToTarget()
        }
        .onChange(of: hasData) { _, _ in
            animateToTarget()
        }
        .onDisappear {
            segmentAnimationTask?.cancel()
            segmentAnimationTask = nil
        }
    }

    private var ringAssets: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                ForEach(Self.segments) { segment in
                    SleepRingAssetLayer(
                        assetName: segment.assetName,
                        progress: animatedSegmentProgress[segment.assetName] ?? 0,
                        startAngle: segment.revealStartAngle,
                        endAngle: segment.revealEndAngle,
                        inactiveOpacity: inactiveOpacity * segment.inactiveOpacityMultiplier,
                        revealEdgeSoftness: segment.revealEdgeSoftness
                    )
                    .frame(width: side, height: side)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func animateToTarget(initialAppearance: Bool = false) {
        segmentAnimationTask?.cancel()
        segmentAnimationTask = nil

        withAnimation(.easeInOut(duration: 1.0)) {
            animatedScore = targetScore
        }

        let delays = initialAppearance && hasData ? [0.0, 0.06, 0.12] : [0.0, 0.0, 0.0]

        segmentAnimationTask = Task { @MainActor in
            var previousDelay = 0.0

            for (index, segment) in Self.segments.enumerated() {
                if Task.isCancelled { return }

                let delay = delays[index]
                let incrementalDelay = max(delay - previousDelay, 0)
                if incrementalDelay > 0 {
                    try? await Task.sleep(
                        nanoseconds: UInt64(incrementalDelay * 1_000_000_000)
                    )
                }

                withAnimation(.easeInOut(duration: 0.92)) {
                    animatedSegmentProgress[segment.assetName] = targetProgress(for: segment)
                }

                previousDelay = delay
            }
        }
    }

    private func resetSegmentProgress() {
        animatedSegmentProgress = Dictionary(
            uniqueKeysWithValues: Self.segments.map { ($0.assetName, 0) }
        )
    }

    private func targetProgress(for segment: SleepRingAssetSegment) -> Double {
        let totalProgress = min(max(targetScore / 100, 0), 1)
        let filledWeight = min(max(totalProgress - segment.leadingWeight, 0), segment.weight)
        return segment.weight == 0 ? 0 : filledWeight / segment.weight
    }

    private static func makeSegments() -> [SleepRingAssetSegment] {
        let definitions: [
            (
                assetName: String,
                weight: Double,
                startAngle: Double,
                endAngle: Double,
                inactiveOpacityMultiplier: Double,
                revealEdgeSoftness: CGFloat
            )
        ] = [
            ("SleepRing_Mint", 0.30, 200.79, 91.10, 1.0, 0),
            ("SleepRing_Orange", 0.20, 88.99, 14.24, 1.0, 0),
            ("SleepRing_Purple", 0.50, 13.75, 201.59, 0.82, 1.2)
        ]

        var leadingWeight = 0.0

        return definitions.map { definition in
            defer { leadingWeight += definition.weight }
            return SleepRingAssetSegment(
                assetName: definition.assetName,
                weight: definition.weight,
                leadingWeight: leadingWeight,
                revealStartAngle: definition.startAngle,
                revealEndAngle: definition.endAngle,
                inactiveOpacityMultiplier: definition.inactiveOpacityMultiplier,
                revealEdgeSoftness: definition.revealEdgeSoftness
            )
        }
    }
}

private struct SleepRingAssetLayer: View {
    let assetName: String
    let progress: Double
    let startAngle: Double
    let endAngle: Double
    let inactiveOpacity: Double
    let revealEdgeSoftness: CGFloat

    var body: some View {
        ZStack {
            ringAsset
                .opacity(inactiveOpacity)

            ringAsset
                .mask {
                    SleepRingSweepMask(
                        progress: progress,
                        startAngle: startAngle,
                        endAngle: endAngle
                    )
                    .fill(Color.white)
                    .blur(radius: revealEdgeSoftness)
                }
        }
        .compositingGroup()
    }

    private var ringAsset: some View {
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SleepRingSweepMask: Shape {
    var progress: Double
    let startAngle: Double
    let endAngle: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }

        let clampedProgress = min(max(progress, 0), 1)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = hypot(rect.width, rect.height)
        let revealAngle = interpolateClockwiseAngle(
            from: startAngle,
            to: endAngle,
            progress: clampedProgress
        )
        let sweep = clockwiseSweep(from: startAngle, to: revealAngle)
        let stepCount = max(1, Int(ceil(sweep / 2)))

        var path = Path()
        path.move(to: center)

        for step in 0...stepCount {
            let stepProgress = Double(step) / Double(stepCount)
            let angle = interpolateClockwiseAngle(
                from: startAngle,
                to: revealAngle,
                progress: stepProgress
            )
            path.addLine(to: point(for: angle, radius: radius, center: center))
        }

        path.closeSubpath()
        return path
    }

    private func interpolateClockwiseAngle(from start: Double, to end: Double, progress: Double) -> Double {
        normalizedAngle(start - (clockwiseSweep(from: start, to: end) * progress))
    }

    private func clockwiseSweep(from start: Double, to end: Double) -> Double {
        normalizedAngle(start - end)
    }

    private func normalizedAngle(_ angle: Double) -> Double {
        let remainder = angle.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }

    private func point(for angle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(
            x: center.x + (CGFloat(Foundation.cos(radians)) * radius),
            y: center.y - (CGFloat(Foundation.sin(radians)) * radius)
        )
    }
}

private struct SleepRingAssetSegment: Identifiable {
    let assetName: String
    let weight: Double
    let leadingWeight: Double
    let revealStartAngle: Double
    let revealEndAngle: Double
    let inactiveOpacityMultiplier: Double
    let revealEdgeSoftness: CGFloat

    var id: String { assetName }
}

#Preview("Sleep Score Ring") {
    ZStack {
        LinearGradient(
            colors: [
                Color(hex: "EEF3FA"),
                Color(hex: "DCE6F3"),
                Color(hex: "C8D7E7")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        SleepScoreRingView(score: 78, hasData: true)
    }
}

#Preview("Sleep Score Ring Empty") {
    ZStack {
        LinearGradient(
            colors: [
                Color(hex: "EEF3FA"),
                Color(hex: "DCE6F3"),
                Color(hex: "C8D7E7")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        SleepScoreRingView(score: nil, hasData: false)
    }
}
