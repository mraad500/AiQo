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

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Palette.teal)
                        .frame(width: 7, height: 7)
                    Text("DAILY")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text("LIVE")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.textMuted)
                }

                Text(formattedInt(entry.steps))
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                progressBar(progress: entry.safeProgress)
                    .frame(height: 7)

                HStack {
                    Text("KCAL \(formattedInt(entry.activeCalories))")
                    Spacer()
                    Text("STAND \(entry.standPercent)%")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(14)
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
