import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject var health: WatchHealthKitManager
    @Environment(\.locale) private var locale

    @State private var centerBreath = false
    @State private var displayedStepsProgress = 0.0
    @State private var displayedCaloriesProgress = 0.0

    private var stepsProgress: Double {
        min(Double(health.todaySteps) / Double(max(health.stepsGoal, 1)), 1)
    }

    private var caloriesProgress: Double {
        min(Double(health.todayCalories) / max(health.caloriesGoal, 1), 1)
    }

    private var goalProgress: Double {
        (stepsProgress + caloriesProgress) / 2
    }

    var body: some View {
        GeometryReader { proxy in
            let ringSize = min(proxy.size.width * 1.06, proxy.size.height * 0.82)
            let primaryText = Color.white
            let secondaryText = Color.white.opacity(0.72)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.09),
                        Color(red: 0.08, green: 0.10, blue: 0.14)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    auraGraphic(size: ringSize)
                        .frame(width: ringSize, height: ringSize)
                        .offset(y: -8)

                    Spacer(minLength: 0)

                    VStack(spacing: 2) {
                        Text(WatchText.percent(goalProgress, locale: locale))
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundColor(primaryText)
                            .monospacedDigit()

                        Text(WatchText.localized(ar: "الهدف اليومي", en: "Daily Goal", locale: locale))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(secondaryText)
                    }
                    .padding(.bottom, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.layoutDirection, WatchText.layoutDirection(for: locale))
        .onAppear {
            health.refresh()
            if !centerBreath {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    centerBreath = true
                }
            }
            animateProgress()
        }
        .onChange(of: health.todaySteps) { _, _ in
            animateProgress()
        }
        .onChange(of: health.todayCalories) { _, _ in
            animateProgress()
        }
        .onChange(of: health.stepsGoal) { _, _ in
            animateProgress()
        }
        .onChange(of: health.caloriesGoal) { _, _ in
            animateProgress()
        }
    }

    private func animateProgress() {
        withAnimation(.easeInOut(duration: 1.2)) {
            displayedStepsProgress = stepsProgress
            displayedCaloriesProgress = caloriesProgress
        }
    }

    private func auraGraphic(size: CGFloat) -> some View {
        let beige = Color(red: 0.91, green: 0.79, blue: 0.59)
        let mint = Color(red: 0.64, green: 0.86, blue: 0.81)

        return ZStack {
            ForEach(WatchDailyAuraVector.segments) { segment in
                WatchAuraArcShape(
                    radiusRatio: segment.radiusRatio,
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle
                )
                .stroke(
                    segment.isGreenGroup ? mint.opacity(0.30) : beige.opacity(0.35),
                    style: StrokeStyle(
                        lineWidth: segment.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }

            ForEach(WatchDailyAuraVector.segments) { segment in
                WatchAuraArcShape(
                    radiusRatio: segment.radiusRatio,
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle
                )
                .trim(from: 0, to: segmentReveal(for: segment, progress: progressForSegment(segment)))
                .stroke(
                    segment.isGreenGroup ? mint : beige,
                    style: StrokeStyle(
                        lineWidth: segment.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .animation(
                    .easeInOut(duration: 1.2)
                        .delay(segmentActivationDelay(for: segment)),
                    value: progressForSegment(segment)
                )
            }

            Circle()
                .fill(Color(red: 0.72, green: 0.90, blue: 0.86).opacity(0.26))
                .frame(width: size * 0.07, height: size * 0.07)
                .scaleEffect(centerBreath ? 1.006 : 0.994)

            Circle()
                .stroke(Color(red: 0.62, green: 0.87, blue: 0.81).opacity(0.58), lineWidth: 3)
                .frame(width: size * 0.12, height: size * 0.12)
                .scaleEffect(centerBreath ? 1.006 : 0.994)

            if goalProgress >= 1 {
                Circle()
                    .stroke(Color.orange.opacity(0.24), lineWidth: 10)
                    .frame(width: size * 1.04, height: size * 1.04)
                    .blur(radius: 3)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
    }

    private func progressForSegment(_ segment: WatchAuraVectorSegment) -> Double {
        segment.isGreenGroup ? displayedStepsProgress : displayedCaloriesProgress
    }

    private func segmentReveal(for segment: WatchAuraVectorSegment, progress: Double) -> CGFloat {
        let stageStart = segment.threshold - 0.25
        let stageProgress = min(max((progress - stageStart) / 0.25, 0), 1)
        let smoothedStage = stageProgress * stageProgress * (3 - 2 * stageProgress)
        let orderedProgress = (smoothedStage * Double(segment.bucketSize)) - Double(segment.bucketOrder)
        return CGFloat(min(max(orderedProgress, 0), 1))
    }

    private func segmentActivationDelay(for segment: WatchAuraVectorSegment) -> Double {
        let bucketDelay = Double(segment.bucketIndex) * 0.04
        let orderDelay = Double(segment.bucketOrder) * 0.007
        return min(bucketDelay + orderDelay, 0.24)
    }
}

private struct WatchAuraArcShape: Shape {
    let radiusRatio: CGFloat
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = size * radiusRatio
        let start = Angle.degrees(startAngle - 90)
        let end = Angle.degrees(normalizedEndAngle - 90)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )
        return path
    }

    private var normalizedEndAngle: Double {
        endAngle < startAngle ? endAngle + 360 : endAngle
    }
}

private struct WatchAuraVectorSegment: Identifiable {
    let id = UUID()
    let radiusRatio: CGFloat
    let startAngle: Double
    let endAngle: Double
    let lineWidth: CGFloat
    let threshold: Double
    let bucketIndex: Int
    let bucketOrder: Int
    let bucketSize: Int
    let isGreenGroup: Bool
}

private enum WatchDailyAuraVector {
    static let segments: [WatchAuraVectorSegment] = {
        let defs: [WatchAuraSegmentDefinition] = [
            .init(radiusRatio: 0.14, startAngle: 208, endAngle: 244, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 262, endAngle: 301, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 334, endAngle: 24, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 45, endAngle: 86, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 112, endAngle: 154, lineWidth: 3.2, stage: 0, isGreenGroup: true),
            .init(radiusRatio: 0.14, startAngle: 174, endAngle: 195, lineWidth: 3.2, stage: 0, isGreenGroup: true),

            .init(radiusRatio: 0.21, startAngle: 196, endAngle: 252, lineWidth: 3.6, stage: 1, isGreenGroup: true),
            .init(radiusRatio: 0.21, startAngle: 272, endAngle: 324, lineWidth: 3.6, stage: 1, isGreenGroup: true),
            .init(radiusRatio: 0.21, startAngle: 352, endAngle: 26, lineWidth: 3.6, stage: 1, isGreenGroup: true),
            .init(radiusRatio: 0.21, startAngle: 66, endAngle: 125, lineWidth: 3.6, stage: 1, isGreenGroup: true),
            .init(radiusRatio: 0.21, startAngle: 146, endAngle: 170, lineWidth: 3.6, stage: 1, isGreenGroup: true),

            .init(radiusRatio: 0.29, startAngle: 182, endAngle: 350, lineWidth: 4.2, stage: 2, isGreenGroup: true),
            .init(radiusRatio: 0.29, startAngle: 20, endAngle: 112, lineWidth: 4.2, stage: 2, isGreenGroup: true),

            .init(radiusRatio: 0.36, startAngle: 212, endAngle: 9, lineWidth: 5, stage: 2, isGreenGroup: true),
            .init(radiusRatio: 0.36, startAngle: 36, endAngle: 164, lineWidth: 5, stage: 2, isGreenGroup: true),

            .init(radiusRatio: 0.43, startAngle: 150, endAngle: 231, lineWidth: 6.5, stage: 3, isGreenGroup: false),
            .init(radiusRatio: 0.43, startAngle: 283, endAngle: 72, lineWidth: 6.5, stage: 3, isGreenGroup: false),
            .init(radiusRatio: 0.52, startAngle: 32, endAngle: 126, lineWidth: 6.5, stage: 3, isGreenGroup: false),
            .init(radiusRatio: 0.52, startAngle: 166, endAngle: 320, lineWidth: 6.5, stage: 3, isGreenGroup: false),
        ]

        var bucketSizes = [0, 0, 0, 0]
        for def in defs {
            bucketSizes[def.stage] += 1
        }

        var bucketOffsets = [0, 0, 0, 0]
        return defs.map { def in
            let bucketOrder = bucketOffsets[def.stage]
            bucketOffsets[def.stage] += 1

            return WatchAuraVectorSegment(
                radiusRatio: def.radiusRatio,
                startAngle: def.startAngle,
                endAngle: def.endAngle,
                lineWidth: def.lineWidth,
                threshold: Double(def.stage + 1) * 0.25,
                bucketIndex: def.stage,
                bucketOrder: bucketOrder,
                bucketSize: max(bucketSizes[def.stage], 1),
                isGreenGroup: def.isGreenGroup
            )
        }
    }()
}

private struct WatchAuraSegmentDefinition {
    let radiusRatio: CGFloat
    let startAngle: Double
    let endAngle: Double
    let lineWidth: CGFloat
    let stage: Int
    let isGreenGroup: Bool
}
