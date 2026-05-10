import Foundation
import SwiftData
import SwiftUI

// MARK: - Weekly stats hero
//
// Aggregates the trailing-7-day pinned plan history into 4 metric cards:
// completed sessions, completion rate, total minutes, and current streak.

struct PlanWeeklyStats {
    let sessionsCompleted: Int       // days where ≥1 workout was checked off
    let totalSessions: Int           // days that had a pinned plan
    let completionRatio: Double      // sum(done) / sum(total) across week
    let totalMinutes: Int            // estimated minutes invested
    let streakDays: Int              // consecutive trailing days with ≥1 completion
}

extension WorkoutPlanMemoryStore {
    static func fetchWeeklyStats(modelContext: ModelContext, language: AppLanguage) -> PlanWeeklyStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        let descriptor = FetchDescriptor<AiQoDailyRecord>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let allRecords = (try? modelContext.fetch(descriptor)) ?? []
        let weekly = allRecords.filter { record in
            let day = calendar.startOfDay(for: record.date)
            return day >= weekStart && day <= today && !record.workouts.isEmpty
        }

        var totalDone = 0
        var totalSets = 0
        var totalSeconds = 0
        var sessionsCompleted = 0
        var totalSessions = 0

        for record in weekly {
            totalSessions += 1
            let done = record.workouts.filter(\.isCompleted).count
            let total = record.workouts.count
            if done > 0 { sessionsCompleted += 1 }
            totalDone += done
            totalSets += total

            // Estimate seconds from the title round-trip (per-exercise insight)
            for task in record.workouts where task.isCompleted {
                guard let exercise = ExerciseSerialization.parse(taskTitle: task.title) else {
                    totalSeconds += 90
                    continue
                }
                totalSeconds += exercise.insights(language: language).estimatedSeconds
            }
        }

        let ratio = totalSets == 0 ? 0 : Double(totalDone) / Double(totalSets)
        let minutes = max(0, Int((Double(totalSeconds) / 60).rounded()))

        // Streak: trailing days ending today where the day had at least one
        // completion. We walk backwards from `today`.
        var streak = 0
        var cursor = today
        while true {
            let dayStart = calendar.startOfDay(for: cursor)
            let record = allRecords.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) })
            if let record, record.workouts.contains(where: \.isCompleted) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            } else {
                break
            }
        }

        return PlanWeeklyStats(
            sessionsCompleted: sessionsCompleted,
            totalSessions: totalSessions,
            completionRatio: ratio,
            totalMinutes: minutes,
            streakDays: streak
        )
    }
}

// MARK: - Stats hero strip

struct PlanWeeklyStatsHero: View {
    let stats: PlanWeeklyStats
    let language: AppLanguage

    private var isArabic: Bool { language == .arabic }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color(red: 0.55, green: 0.72, blue: 0.95))
                Text(isArabic ? "أرقامك بالأسبوع" : "Your week in numbers")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
            }

            HStack(spacing: 9) {
                statCard(
                    title: isArabic ? "جلسات" : "Sessions",
                    value: "\(stats.sessionsCompleted)",
                    subtitle: stats.totalSessions == 0 ? "—" : "/ \(stats.totalSessions)",
                    icon: "checkmark.circle.fill",
                    tint: Color(red: 0.45, green: 0.83, blue: 0.78)
                )

                statCard(
                    title: isArabic ? "دقائق" : "Minutes",
                    value: "\(stats.totalMinutes)",
                    subtitle: isArabic ? "هاي الأسبوع" : "this week",
                    icon: "clock.fill",
                    tint: Color(red: 0.55, green: 0.72, blue: 0.95)
                )

                statCard(
                    title: isArabic ? "إنجاز" : "Completion",
                    value: "\(Int((stats.completionRatio * 100).rounded()))%",
                    subtitle: completionLabel,
                    icon: "target",
                    tint: Color(red: 0.99, green: 0.78, blue: 0.45)
                )

                statCard(
                    title: isArabic ? "سلسلة" : "Streak",
                    value: "\(stats.streakDays)",
                    subtitle: isArabic ? "أيام متتالية" : "days in a row",
                    icon: "flame.fill",
                    tint: Color(red: 0.96, green: 0.50, blue: 0.55)
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    private var completionLabel: String {
        let pct = Int((stats.completionRatio * 100).rounded())
        if pct >= 90 { return isArabic ? "ممتاز" : "elite" }
        if pct >= 70 { return isArabic ? "قوي" : "strong" }
        if pct >= 40 { return isArabic ? "جيد" : "solid" }
        return isArabic ? "إبدأ بقوة" : "ramp up"
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .heavy))
                Text(title)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}
