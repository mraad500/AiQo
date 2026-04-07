import WidgetKit
import SwiftUI

struct AiQoRingsFaceWidget: Widget {
    let kind = "AiQoRingsFaceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AiQoProvider()) { entry in
            AiQoRingsFaceWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("AiQo Rings")
        .description("Activity-rings style complication cards.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private struct AiQoRingsFaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AiQoEntry

    private let moveGoal = 1600
    private let exerciseGoal = 45
    private let standGoal = 13

    private var moveValue: Int { max(0, entry.activeCalories) }
    private var exerciseValue: Int {
        let distanceEstimatedMinutes = Int(round(max(0, entry.distanceKm) * 10.0))
        let standEstimatedMinutes = Int(round(Double(max(0, entry.standPercent)) * 0.45))
        return max(distanceEstimatedMinutes, standEstimatedMinutes)
    }
    private var standValue: Int {
        Int(round(Double(max(0, entry.standPercent)) / 100.0 * Double(standGoal)))
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(moveValue)/\(moveGoal)CAL \(exerciseValue)/\(exerciseGoal)MIN \(standValue)/\(standGoal)H")
                .font(.caption2.monospacedDigit())
        case .accessoryCircular:
            circularRingsCard
        case .accessoryRectangular:
            rectangularRingsCard
        default:
            rectangularRingsCard
        }
    }

    private var circularRingsCard: some View {
        ZStack {
            AccessoryWidgetBackground()
            rings(size: 58, lineWidth: 5)
            Text("A")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var rectangularRingsCard: some View {
        HStack(spacing: 8) {
            rings(size: 48, lineWidth: 4)
                .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 1) {
                metricLine("\(moveValue)/\(moveGoal)CAL", color: Color(red: 1.0, green: 0.2, blue: 0.45))
                metricLine("\(exerciseValue)/\(exerciseGoal)MIN", color: Color(red: 0.62, green: 1.0, blue: 0.2))
                metricLine("\(standValue)/\(standGoal)HRS", color: Color(red: 0.25, green: 0.9, blue: 1.0))
            }
        }
    }

    private func rings(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            ring(progress: Double(moveValue) / Double(moveGoal), size: size, lineWidth: lineWidth, color: Color(red: 1.0, green: 0.2, blue: 0.45))
            ring(progress: Double(exerciseValue) / Double(exerciseGoal), size: size - 12, lineWidth: lineWidth, color: Color(red: 0.62, green: 1.0, blue: 0.2))
            ring(progress: Double(standValue) / Double(standGoal), size: size - 24, lineWidth: lineWidth, color: Color(red: 0.25, green: 0.9, blue: 1.0))
        }
    }

    private func ring(progress: Double, size: CGFloat, lineWidth: CGFloat, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: min(max(progress, 0.03), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
        }
    }

    private func metricLine(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
