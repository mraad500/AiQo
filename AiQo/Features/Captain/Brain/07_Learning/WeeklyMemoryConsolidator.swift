import Foundation
import SwiftData

@MainActor
final class WeeklyMemoryConsolidator {
    static let shared = WeeklyMemoryConsolidator()

    private var container: ModelContainer?
    private var context: ModelContext? { container?.mainContext }

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    func shouldConsolidateNow() -> Bool {
        guard let anchor = anchorDate() else { return false }
        let days = Calendar.current.dateComponents([.day], from: anchor, to: Date()).day ?? 0
        return days >= 7
    }

    private func anchorDate() -> Date? {
        if let latest = latestReport() { return latest.rangeEnd }
        return FreeTrialManager.shared.trialStartDatePublic
    }

    func consolidateIfDue() {
        guard shouldConsolidateNow() else { return }
        guard let context else { return }

        let buffered = WeeklyMetricsBufferStore.shared.allBuffered()
        guard !buffered.isEmpty else { return }

        let count = buffered.count
        let avgSteps = buffered.map(\.steps).reduce(0, +) / max(count, 1)
        let avgCalories = Int(buffered.map(\.activeCalories).reduce(0, +) / Double(max(count, 1)))
        let sleepValues = buffered.compactMap(\.sleepHours)
        let avgSleep = sleepValues.isEmpty ? 0 : sleepValues.reduce(0, +) / Double(sleepValues.count)
        let rhrValues = buffered.compactMap(\.restingHeartRate)
        let avgRhr: Double? = rhrValues.isEmpty ? nil : rhrValues.reduce(0, +) / Double(rhrValues.count)
        let totalWorkoutMinutes = buffered.map(\.workoutMinutes).reduce(0, +)
        let workoutCount = buffered.map(\.workoutCount).reduce(0, +)

        let bestDay = buffered.max(by: { $0.steps < $1.steps })
        let bestDayLabelAr = bestDay.flatMap { dayLabel(for: $0.dayStart, language: "ar") }
        let bestDayLabelEn = bestDay.flatMap { dayLabel(for: $0.dayStart, language: "en") }

        let weekNumber = (latestReport()?.weekNumber ?? 0) + 1
        let rangeStart = buffered.first?.dayStart ?? Date()
        let rangeEnd   = buffered.last?.dayStart ?? Date()

        let summaryAr = "أسبوعك \(weekNumber): متوسط \(avgSteps) خطوة باليوم، نوم \(String(format: "%.1f", avgSleep)) ساعة."
            + (bestDayLabelAr.map { " أقوى يوم: \($0)." } ?? "")
        let summaryEn = "Week \(weekNumber): \(avgSteps) avg steps/day, \(String(format: "%.1f", avgSleep))h sleep."
            + (bestDayLabelEn.map { " Best day: \($0)." } ?? "")

        let report = WeeklyReportEntry(
            weekNumber: weekNumber,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            avgSteps: avgSteps,
            avgCalories: avgCalories,
            avgSleepHours: avgSleep,
            avgRestingHeartRate: avgRhr,
            totalWorkoutMinutes: totalWorkoutMinutes,
            workoutCount: workoutCount,
            bestDayLabelAr: bestDayLabelAr,
            bestDayLabelEn: bestDayLabelEn,
            summaryAr: summaryAr,
            summaryEn: summaryEn
        )

        context.insert(report)
        try? context.save()

        WeeklyMetricsBufferStore.shared.clearAll()
        AnalyticsService.shared.track(.weeklyReportGenerated(weekNumber: weekNumber))
    }

    func allReports() -> [WeeklyReportEntry] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<WeeklyReportEntry>(sortBy: [SortDescriptor(\.weekNumber, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func latestReport() -> WeeklyReportEntry? { allReports().first }
    func latestWeekNumber() -> Int? { latestReport()?.weekNumber }

    private func dayLabel(for date: Date, language: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
