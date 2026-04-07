import SwiftUI
import WidgetKit

struct AiQoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AiQoEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallCard
        case .systemMedium:
            mediumCard
        case .accessoryInline:
            inlineAccessory
        case .accessoryCircular:
            circularAccessory
        case .accessoryRectangular:
            rectangularAccessory
        default:
            mediumCard
        }
    }

    private var mediumCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )

            Circle()
                .fill(Palette.glow)
                .frame(width: 220, height: 220)
                .blur(radius: 28)
                .offset(x: 115, y: -15)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Palette.teal)
                            .frame(width: 8, height: 8)
                        Text("DAILY MOTION")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.textSecondary)
                    }

                    Spacer()

                    Text("LIVE")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formattedInt(entry.steps))
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        Text("STEPS TODAY")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.textMuted)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("STAND")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.textSecondary)

                        Text(entry.standHoursText)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(Palette.textPrimary)

                        progressBar(progress: entry.safeStandProgress)
                            .frame(width: 110, height: 7)
                    }
                }

                Rectangle()
                    .fill(Palette.stroke)
                    .frame(height: 1)

                HStack(spacing: 8) {
                    metricTile(icon: "figure.walk", title: "STEPS", value: formattedInt(entry.steps))
                    metricTile(icon: "flame.fill", title: "KCAL", value: formattedInt(entry.activeCalories))
                    metricTile(icon: "figure.stand", title: "STAND", value: "\(entry.standPercent)%")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
    }

    private var smallCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Palette.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Palette.stroke, lineWidth: 1)
                )

            Circle()
                .fill(Palette.glow)
                .frame(width: 180, height: 180)
                .blur(radius: 24)
                .offset(x: 88, y: -22)

            VStack(spacing: 6) {
                smallAuraGraphic
                    .frame(width: 108, height: 108)

                Text(entry.auraPercentText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(12)
        }
    }

    private func metricTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.teal)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
            }

            Text(value)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geo in
            let width = max(10, geo.size.width * progress)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.track)
                Capsule()
                    .fill(Palette.teal)
                    .frame(width: width)
            }
        }
    }

    private var smallAuraGraphic: some View {
        let beige = Color(red: 0.91, green: 0.79, blue: 0.59)
        let mint = Color(red: 0.64, green: 0.86, blue: 0.81)

        return ZStack {
            ForEach(WidgetDailyAuraVector.segments) { segment in
                WidgetAuraArcShape(
                    radiusRatio: segment.radiusRatio,
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle
                )
                .stroke(
                    segmentBaseColor(segment, beige: beige, mint: mint),
                    style: StrokeStyle(
                        lineWidth: segment.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }

            ForEach(WidgetDailyAuraVector.segments) { segment in
                WidgetAuraArcShape(
                    radiusRatio: segment.radiusRatio,
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle
                )
                .trim(from: 0, to: segmentReveal(for: segment, progress: progressForSegment(segment)))
                .stroke(
                    segmentActiveColor(segment, beige: beige, mint: mint),
                    style: StrokeStyle(
                        lineWidth: segment.lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }

            Circle()
                .fill(Color(red: 0.72, green: 0.90, blue: 0.86).opacity(0.26))
                .frame(width: 8, height: 8)

            Circle()
                .stroke(Color(red: 0.62, green: 0.87, blue: 0.81).opacity(0.58), lineWidth: 2)
                .frame(width: 14, height: 14)

            if entry.safeAuraProgress >= 1 {
                Circle()
                    .stroke(Color.orange.opacity(0.24), lineWidth: 7)
                    .frame(width: 114, height: 114)
                    .blur(radius: 2)
            }
        }
    }

    private func progressForSegment(_ segment: WidgetAuraVectorSegment) -> Double {
        segment.isGreenGroup ? entry.safeStepsProgress : entry.safeCaloriesProgress
    }

    private func segmentReveal(for segment: WidgetAuraVectorSegment, progress: Double) -> CGFloat {
        let stageStart = segment.threshold - 0.25
        let stageProgress = min(max((progress - stageStart) / 0.25, 0), 1)
        let smoothedStage = stageProgress * stageProgress * (3 - 2 * stageProgress)
        let orderedProgress = (smoothedStage * Double(segment.bucketSize)) - Double(segment.bucketOrder)
        return CGFloat(min(max(orderedProgress, 0), 1))
    }

    private func segmentBaseColor(_ segment: WidgetAuraVectorSegment, beige: Color, mint: Color) -> Color {
        segment.isGreenGroup ? mint.opacity(0.30) : beige.opacity(0.35)
    }

    private func segmentActiveColor(_ segment: WidgetAuraVectorSegment, beige: Color, mint: Color) -> Color {
        segment.isGreenGroup ? mint.opacity(1.0) : beige.opacity(1.0)
    }

    private func formattedInt(_ value: Int) -> String {
        max(value, 0).formatted()
    }

    private var inlineAccessory: some View {
        Text("AiQo \(formattedInt(entry.steps)) • \(entry.heartRate)bpm")
            .font(.caption2.monospacedDigit())
    }

    private var circularAccessory: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                Text("\(max(0, entry.heartRate))")
                    .font(.caption2.weight(.bold).monospacedDigit())
            }
            .foregroundStyle(Palette.teal)
        }
    }

    private var rectangularAccessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AiQoWatch Live")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 8) {
                Label("\(max(0, entry.heartRate)) bpm", systemImage: "heart.fill")
                Label(String(format: "%.2f km", max(0, entry.distanceKm)), systemImage: "figure.run")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Palette.textPrimary)
        }
    }
}

private struct WidgetAuraArcShape: Shape {
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

private struct WidgetAuraVectorSegment: Identifiable {
    let id: Int
    let radiusRatio: CGFloat
    let startAngle: Double
    let endAngle: Double
    let lineWidth: CGFloat
    let threshold: Double
    let bucketOrder: Int
    let bucketSize: Int
    let isGreenGroup: Bool
}

private enum WidgetDailyAuraVector {
    static let segments: [WidgetAuraVectorSegment] = {
        let defs: [WidgetAuraSegmentDefinition] = [
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
            .init(radiusRatio: 0.52, startAngle: 166, endAngle: 320, lineWidth: 6.5, stage: 3, isGreenGroup: false)
        ]

        var bucketSizes = [0, 0, 0, 0]
        for def in defs {
            bucketSizes[def.stage] += 1
        }
        var bucketOffsets = [0, 0, 0, 0]

        return defs.enumerated().map { idx, def in
            let bucketOrder = bucketOffsets[def.stage]
            bucketOffsets[def.stage] += 1

            return WidgetAuraVectorSegment(
                id: idx,
                radiusRatio: def.radiusRatio,
                startAngle: def.startAngle,
                endAngle: def.endAngle,
                lineWidth: def.lineWidth,
                threshold: Double(def.stage + 1) * 0.25,
                bucketOrder: bucketOrder,
                bucketSize: max(bucketSizes[def.stage], 1),
                isGreenGroup: def.isGreenGroup
            )
        }
    }()
}

private struct WidgetAuraSegmentDefinition {
    let radiusRatio: CGFloat
    let startAngle: Double
    let endAngle: Double
    let lineWidth: CGFloat
    let stage: Int
    let isGreenGroup: Bool
}

private enum Palette {
    static let teal = Color(red: 0.10, green: 0.86, blue: 0.78)
    static let glow = Color(red: 0.47, green: 0.76, blue: 0.72).opacity(0.30)

    static let cardGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.09, blue: 0.11),
            Color(red: 0.06, green: 0.17, blue: 0.17),
            Color(red: 0.11, green: 0.16, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.78)
    static let textMuted = Color.white.opacity(0.58)
    static let stroke = Color.white.opacity(0.13)
    static let track = Color.white.opacity(0.16)
}
