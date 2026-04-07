import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject var health: WatchHealthKitManager

    var body: some View {
        ScrollView {
            VStack(spacing: AiQoWatch.gridSpacing) {
                auraRing
                statsGrid
                distanceBar
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .background(AiQoWatch.background)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { health.refresh() }
    }

    // MARK: - Aura Ring (matches iPhone concentric rings)
    private var auraRing: some View {
        let stepsProgress = min(Double(health.todaySteps) / 10000.0, 1.0)
        let calProgress = min(Double(health.todayCalories) / 800.0, 1.0)
        let auraPercent = Int((stepsProgress + calProgress) / 2.0 * 100)

        return ZStack {
            // Outer ring track
            Circle()
                .stroke(AiQoWatch.ringTrack, lineWidth: 5)
                .frame(width: 68, height: 68)
            // Outer ring — Sand (calories)
            Circle()
                .trim(from: 0, to: calProgress)
                .stroke(AiQoWatch.auraSand, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 68, height: 68)
                .rotationEffect(.degrees(-90))

            // Inner ring track
            Circle()
                .stroke(AiQoWatch.ringTrack, lineWidth: 4)
                .frame(width: 52, height: 52)
            // Inner ring — Mint (steps)
            Circle()
                .trim(from: 0, to: stepsProgress)
                .stroke(AiQoWatch.auraMint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(-90))

            // Center percentage
            VStack(spacing: 0) {
                Text("\(auraPercent)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AiQoWatch.accent)
                Text("الأورا")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(AiQoWatch.textLight)
            }
        }
        .frame(height: 76)
        .animation(.easeInOut(duration: 1.2), value: health.todaySteps)
    }

    // MARK: - 2×2 Stats Grid (same layout as iPhone)
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AiQoWatch.gridSpacing) {
            // Row 1: Calories (sand) + Steps (mint) — same as iPhone
            WatchStatCard(
                sfSymbol: "flame.fill",
                label: "السعرات",
                value: "\(health.todayCalories)",
                unit: "kcal",
                cardBg: AiQoWatch.sandCard,
                iconBg: AiQoWatch.sandIcon
            )
            WatchStatCard(
                sfSymbol: "figure.walk",
                label: "الخطوات",
                value: health.todaySteps.formatted(),
                unit: "",
                cardBg: AiQoWatch.mintCard,
                iconBg: AiQoWatch.mintIcon
            )
            // Row 2: Water (mint) + Sleep (sand)
            WatchStatCard(
                sfSymbol: "drop.fill",
                label: "الماء",
                value: "2",
                unit: "L",
                cardBg: AiQoWatch.mintCard,
                iconBg: AiQoWatch.mintIcon
            )
            WatchStatCard(
                sfSymbol: "moon.fill",
                label: "النوم",
                value: String(format: "%.1f", health.todaySleepHours),
                unit: "h",
                cardBg: AiQoWatch.sandCard,
                iconBg: AiQoWatch.sandIcon
            )
        }
    }

    // MARK: - Distance Bar
    private var distanceBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.run")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AiQoWatch.textSecondary)
                .frame(width: 22, height: 22)
                .background(AiQoWatch.mintIcon)
                .clipShape(Circle())

            Text("المسافة")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AiQoWatch.textSecondary)

            Spacer()

            Text(String(format: "%.1f", health.todayDistanceKm))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AiQoWatch.textPrimary)
            Text("km")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AiQoWatch.textSecondary)
        }
        .padding(.horizontal, AiQoWatch.cardPadding)
        .padding(.vertical, 7)
        .background(AiQoWatch.mintCard)
        .cornerRadius(AiQoWatch.cardRadius)
    }
}

// MARK: - Stat Card Component
struct WatchStatCard: View {
    let sfSymbol: String
    let label: String
    let value: String
    let unit: String
    let cardBg: Color
    let iconBg: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Icon + label row
            HStack(spacing: 4) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AiQoWatch.textSecondary)
                    .frame(width: AiQoWatch.iconSize, height: AiQoWatch.iconSize)
                    .background(iconBg)
                    .clipShape(Circle())

                Spacer()

                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AiQoWatch.textSecondary)
            }

            // Value row
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Spacer()
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(AiQoWatch.textPrimary)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AiQoWatch.textSecondary)
                }
            }
        }
        .padding(AiQoWatch.cardPadding)
        .background(cardBg)
        .cornerRadius(AiQoWatch.cardRadius)
    }
}
