import Foundation

struct ActivitySnapshot: Sendable {
    let steps: Int
    let calories: Double
}

protocol ActivityDataProviding: Sendable {
    func fetchTodayActivity() async -> ActivitySnapshot
}

struct HealthKitActivityProvider: ActivityDataProviding {
    func fetchTodayActivity() async -> ActivitySnapshot {
        do {
            let summary = try await HealthKitService.shared.fetchTodaySummary()
            return ActivitySnapshot(steps: Int(summary.steps), calories: summary.activeKcal)
        } catch {
            return ActivitySnapshot(steps: 0, calories: 0)
        }
    }
}

struct MockActivityProvider: ActivityDataProviding {
    var snapshot: ActivitySnapshot = ActivitySnapshot(steps: 7_847, calories: 855)

    func fetchTodayActivity() async -> ActivitySnapshot {
        snapshot
    }
}
