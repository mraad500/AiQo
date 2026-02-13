import WidgetKit
import SwiftUI

struct AiQoWatchWidget: Widget {
    let kind = "AiQoWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AiQoWatchWidgetProvider()) { entry in
            AiQoWatchWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("AiQo Rings (Watch)")
        .description("Complication cards for Apple Watch faces.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct AiQoWeeklyWidget: Widget {
    let kind = "AiQoWeeklyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AiQoWatchWidgetProvider()) { entry in
            AiQoWeeklyWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("AiQo Week (Watch)")
        .description("AiQo icon with weekly distance line.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}

private struct AiQoWatchWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AiQoWatchEntry

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
            Text("\(moveValue)/\(moveGoal)CAL \(exerciseValue)/\(exerciseGoal)MIN \(standValue)/\(standGoal)HRS")
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

private struct AiQoWeeklyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AiQoWatchEntry

    private var kmText: String {
        String(format: "%.2fKM", max(0, entry.weeklyTotalKm))
    }

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter.string(from: .now).uppercased()
    }

    private var points: [Double] {
        let raw = entry.weeklyDailyKm
        if raw.isEmpty {
            let total = max(0.3, entry.weeklyTotalKm)
            let factors: [Double] = [0.10, 0.16, 0.24, 0.34, 0.52, 0.71, 1.0]
            return factors.map { total * $0 }
        }
        return raw
    }

    private var normalizedPoints: [Double] {
        let maxValue = points.max() ?? 1
        guard maxValue > 0 else { return Array(repeating: 0.12, count: 7) }
        return points.map { min(max($0 / maxValue, 0.05), 1.0) }
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("AiQo \(kmText) \(monthText)")
                .font(.caption2.monospacedDigit())
        case .accessoryRectangular:
            rectangularWeekCard
        default:
            rectangularWeekCard
        }
    }

    private var rectangularWeekCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image("AiQoLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("AiQo")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                Text(kmText)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(monthText)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.16, green: 0.78, blue: 1.0))
                Spacer(minLength: 0)
            }

            lineChart
        }
    }

    private var lineChart: some View {
        GeometryReader { geo in
            let values = normalizedPoints
            let width = geo.size.width
            let height = geo.size.height
            let topPadding: CGFloat = 2
            let bottomPadding: CGFloat = 2
            let stepX = values.count > 1 ? width / CGFloat(values.count - 1) : 0

            ZStack {
                ForEach(0..<max(values.count, 2), id: \.self) { idx in
                    let x = CGFloat(idx) * stepX
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }

                Path { path in
                    for (idx, value) in values.enumerated() {
                        let x = CGFloat(idx) * stepX
                        let y = topPadding + (1 - CGFloat(value)) * (height - topPadding - bottomPadding)
                        if idx == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.82, blue: 1.0), Color.white.opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(height: 18)
    }
}
