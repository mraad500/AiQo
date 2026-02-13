import WidgetKit
import SwiftUI

struct AiQoWatchFaceWidget: Widget {
    let kind = "AiQoWatchFaceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AiQoProvider()) { entry in
            AiQoWatchFaceWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("AiQo Face Cards")
        .description("Workout cards for Apple Watch faces.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private struct AiQoWatchFaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AiQoEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("AiQo \(max(0, entry.heartRate))bpm \(String(format: "%.2fkm", max(0, entry.distanceKm)))")
                .font(.caption2.monospacedDigit())
        case .accessoryCircular:
            circularCard
        case .accessoryRectangular:
            rectangularCard
        default:
            rectangularCard
        }
    }

    private var circularCard: some View {
        ZStack {
            AccessoryWidgetBackground()
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: entry.safeProgress)
                    .stroke(Color(red: 0.1, green: 0.9, blue: 0.8), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(6)

            VStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                Text("\(max(0, entry.heartRate))")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
    }

    private var rectangularCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AiQo Watch")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            Text("\(max(0, entry.activeCalories)) CAL  •  \(max(0, entry.heartRate)) BPM")
                .font(.caption2.weight(.heavy).monospacedDigit())
                .foregroundStyle(Color(red: 1.0, green: 0.25, blue: 0.45))

            Text(String(format: "%.2f KM  •  %@ STEPS", max(0, entry.distanceKm), max(0, entry.steps).formatted()))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 1.0))
        }
    }
}
