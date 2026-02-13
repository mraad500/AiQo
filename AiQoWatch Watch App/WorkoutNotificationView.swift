import SwiftUI

struct WorkoutNotificationPayload {
    enum Kind {
        case milestone
        case summary
    }

    let kind: Kind
    let title: String
    let subtitle: String
    let caloriesText: String
    let minutesText: String
    let distanceText: String
    let caloriesProgress: Double
    let minutesProgress: Double
    let distanceProgress: Double
    let footerText: String
    let weeklyDistanceText: String
    let weeklyProgressPoints: [Double]
    let weeklyMonthText: String

    static var placeholder: WorkoutNotificationPayload {
        WorkoutNotificationPayload(
            kind: .milestone,
            title: "AiQo",
            subtitle: "Weekly update",
            caloriesText: "857/1,600CAL",
            minutesText: "70/45MIN",
            distanceText: "10/13HRS",
            caloriesProgress: 0.54,
            minutesProgress: 1.0,
            distanceProgress: 0.77,
            footerText: "102 BPM",
            weeklyDistanceText: "23.06KM",
            weeklyProgressPoints: [0.08, 0.10, 0.22, 0.38, 0.41, 0.64, 1.0],
            weeklyMonthText: "FEB"
        )
    }
}

struct WorkoutNotificationView: View {
    let payload: WorkoutNotificationPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ringCard
            weekDistanceCard
        }
    }

    private var ringCard: some View {
        HStack(spacing: 10) {
            rings
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 2) {
                metricLine(payload.caloriesText, color: Color(red: 1.0, green: 0.2, blue: 0.45))
                metricLine(payload.minutesText, color: Color(red: 0.62, green: 1.0, blue: 0.2))
                metricLine(payload.distanceText, color: Color(red: 0.25, green: 0.9, blue: 1.0))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground)
    }

    private var weekDistanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                appIcon
                VStack(alignment: .leading, spacing: 1) {
                    Text(payload.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(payload.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(payload.weeklyDistanceText)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(payload.weeklyMonthText)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.14, green: 0.75, blue: 1.0))
                Spacer(minLength: 0)
            }

            weeklyChart
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground)
    }

    private var rings: some View {
        ZStack {
            ringTrack(size: 62)
            ring(progress: payload.caloriesProgress, size: 62, color: Color(red: 1.0, green: 0.2, blue: 0.45))
            ringTrack(size: 46)
            ring(progress: payload.minutesProgress, size: 46, color: Color(red: 0.62, green: 1.0, blue: 0.2))
            ringTrack(size: 30)
            ring(progress: payload.distanceProgress, size: 30, color: Color(red: 0.25, green: 0.9, blue: 1.0))
        }
    }

    private var appIcon: some View {
        Image("AiQoLogo")
            .resizable()
            .scaledToFill()
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
    }

    private var weeklyChart: some View {
        GeometryReader { geo in
            let points = normalizedPoints
            let width = geo.size.width
            let height = geo.size.height
            let topPadding: CGFloat = 8
            let bottomPadding: CGFloat = 8
            let stepX = points.count > 1 ? width / CGFloat(points.count - 1) : 0

            ZStack {
                ForEach(0..<max(points.count, 2), id: \.self) { idx in
                    let x = CGFloat(idx) * stepX
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                }

                Path { path in
                    for (idx, value) in points.enumerated() {
                        let x = CGFloat(idx) * stepX
                        let y = topPadding + (1 - CGFloat(value)) * (height - topPadding - bottomPadding)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.82, blue: 1.0), Color.white.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(height: 38)
    }

    private var normalizedPoints: [Double] {
        let raw = payload.weeklyProgressPoints
        guard !raw.isEmpty else { return [0.08, 0.16, 0.22, 0.35, 0.52, 0.70, 1.0] }
        let maxValue = raw.max() ?? 1
        guard maxValue > 0 else { return Array(repeating: 0.1, count: max(raw.count, 2)) }
        return raw.map { min(max($0 / maxValue, 0.02), 1.0) }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.black.opacity(0.94), Color(red: 0.11, green: 0.13, blue: 0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }

    private func ringTrack(size: CGFloat) -> some View {
        Circle()
            .stroke(Color.white.opacity(0.12), lineWidth: 5)
            .frame(width: size, height: size)
    }

    private func ring(progress: Double, size: CGFloat, color: Color) -> some View {
        Circle()
            .trim(from: 0, to: min(max(progress, 0.03), 1))
            .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: size, height: size)
    }

    private func metricLine(_ value: String, color: Color) -> some View {
        Text(value)
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }
}
