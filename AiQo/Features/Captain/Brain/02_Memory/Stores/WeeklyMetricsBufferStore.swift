import Foundation
import SwiftData

@MainActor
final class WeeklyMetricsBufferStore {
    static let shared = WeeklyMetricsBufferStore()

    private var container: ModelContainer?
    private var context: ModelContext? { container?.mainContext }

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    func upsertToday(steps: Int, activeCalories: Double, restingHeartRate: Double?, sleepHours: Double?, workoutMinutes: Int, workoutCount: Int) {
        guard let context else { return }

        let dayStart = Calendar.current.startOfDay(for: Date())
        let predicate = #Predicate<WeeklyMetricsBuffer> { $0.dayStart == dayStart }
        let descriptor = FetchDescriptor<WeeklyMetricsBuffer>(predicate: predicate)

        if let existing = try? context.fetch(descriptor).first {
            existing.steps = steps
            existing.activeCalories = activeCalories
            existing.restingHeartRate = restingHeartRate
            existing.sleepHours = sleepHours
            existing.workoutMinutes = workoutMinutes
            existing.workoutCount = workoutCount
        } else {
            context.insert(WeeklyMetricsBuffer(
                dayStart: dayStart,
                steps: steps,
                activeCalories: activeCalories,
                restingHeartRate: restingHeartRate,
                sleepHours: sleepHours,
                workoutMinutes: workoutMinutes,
                workoutCount: workoutCount
            ))
        }
        try? context.save()
    }

    func allBuffered() -> [WeeklyMetricsBuffer] {
        guard let context else { return [] }
        let descriptor = FetchDescriptor<WeeklyMetricsBuffer>(sortBy: [SortDescriptor(\.dayStart)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func clearAll() {
        guard let context else { return }
        for row in allBuffered() { context.delete(row) }
        try? context.save()
    }
}
