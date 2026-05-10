import SwiftUI

// MARK: - Weekly Summary Card

/// 7-day calorie bar chart with a streak flame on top. Read-only.
struct WeeklySummaryCard: View {
    let snapshot: [KitchenPersistenceStore.DailyNutrition]
    let calorieGoal: Int
    let streakDays: Int

    private var maxCalories: Int {
        max(calorieGoal, snapshot.map(\.calories).max() ?? 0, 1)
    }

    private var goalDays: Int {
        snapshot.filter(\.met80PctGoal).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("kitchen.weekly.title".localized)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(
                        String(
                            format: "kitchen.weekly.subtitle".localized,
                            goalDays
                        )
                    )
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                streakBadge
            }

            chart

            HStack(spacing: 6) {
                ForEach(snapshot) { entry in
                    Text(weekdayLetter(for: entry.day))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 8) {
                legendDot(color: NutritionLegend.met, label: "kitchen.weekly.legend.met".localized)
                legendDot(color: NutritionLegend.partial, label: "kitchen.weekly.legend.partial".localized)
                legendDot(color: NutritionLegend.over, label: "kitchen.weekly.legend.over".localized)
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
        )
    }

    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: streakDays > 0 ? "flame.fill" : "flame")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(
                    streakDays > 0
                        ? Color.orange
                        : Color.secondary.opacity(0.5)
                )
            Text(
                String(
                    format: "kitchen.weekly.streak".localized,
                    streakDays
                )
            )
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(streakDays > 0 ? Color.primary : Color.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(streakDays > 0 ? Color.orange.opacity(0.16) : Color(.tertiarySystemFill))
        )
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        GeometryReader { geo in
            let barCount = max(snapshot.count, 1)
            let spacing: CGFloat = 6
            let availableWidth = geo.size.width - spacing * CGFloat(barCount - 1)
            let barWidth = max(availableWidth / CGFloat(barCount), 12)

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(snapshot) { entry in
                    bar(for: entry, totalHeight: geo.size.height, barWidth: barWidth)
                }
            }
        }
        .frame(height: 84)
    }

    private func bar(
        for entry: KitchenPersistenceStore.DailyNutrition,
        totalHeight: CGFloat,
        barWidth: CGFloat
    ) -> some View {
        let progress = min(CGFloat(entry.calories) / CGFloat(maxCalories), 1.0)
        let color = barColor(for: entry)
        let height = max(totalHeight * progress, 6)

        return VStack(spacing: 2) {
            Spacer(minLength: 0)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color)
                    .frame(width: barWidth, height: height)

                if entry.calories > 0 {
                    Text(formattedShortKcal(entry.calories))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(weekdayLetter(for: entry.day)): \(entry.calories) kcal"
        )
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func barColor(for entry: KitchenPersistenceStore.DailyNutrition) -> Color {
        let goalRatio = Double(entry.calories) / Double(max(calorieGoal, 1))

        if entry.calories == 0 {
            return Color.secondary.opacity(0.18)
        }
        if goalRatio > 1.15 {
            return NutritionLegend.over
        }
        if goalRatio >= 0.8 && goalRatio <= 1.15 {
            return NutritionLegend.met
        }
        return NutritionLegend.partial
    }

    private func weekdayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EE"
        return formatter.string(from: date)
    }

    private func formattedShortKcal(_ kcal: Int) -> String {
        if kcal >= 1000 {
            return String(format: "%.1fk", Double(kcal) / 1000.0)
        }
        return "\(kcal)"
    }
}

private enum NutritionLegend {
    static let met = Color(red: 0.36, green: 0.74, blue: 0.55)
    static let partial = Color(red: 0.92, green: 0.78, blue: 0.45)
    static let over = Color(red: 0.86, green: 0.42, blue: 0.36)
}

// MARK: - Smart Insights Card

/// Renders up to 3 smart insights — calorie balance, protein gaps, hydration nudges, etc.
struct SmartInsightsCard: View {
    let insights: [KitchenInsight]

    var body: some View {
        if insights.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 10) {
                ForEach(insights) { insight in
                    SmartInsightRow(insight: insight)
                }
            }
        }
    }
}

private struct SmartInsightRow: View {
    let insight: KitchenInsight

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(toneColor.opacity(0.16))
                Image(systemName: insight.icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(toneColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(insight.detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(toneColor.opacity(0.32), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.detail)")
    }

    private var toneColor: Color {
        switch insight.tone {
        case .positive:
            return Color(red: 0.36, green: 0.74, blue: 0.55)
        case .attention:
            return Color(red: 0.92, green: 0.62, blue: 0.30)
        case .warning:
            return Color(red: 0.86, green: 0.42, blue: 0.36)
        case .info:
            return Color(red: 0.40, green: 0.62, blue: 0.86)
        }
    }
}
