import Foundation
import SwiftUI
internal import Combine

@MainActor
final class DailyAuraViewModel: ObservableObject {
    @Published private(set) var stepsToday: Int = 0
    @Published private(set) var caloriesToday: Double = 0
    @Published private(set) var goals: DailyGoals
    @Published private(set) var historyByDay: [String: DailyRecord] = [:]

    private let provider: ActivityDataProviding
    private let defaults: UserDefaults
    private let historyKey = "aiqo.dailyAura.history.v1"

    init(provider: ActivityDataProviding, defaults: UserDefaults = .standard) {
        self.provider = provider
        self.defaults = defaults
        self.goals = GoalsStore.shared.current
        self.historyByDay = Self.loadHistory(defaults: defaults, key: historyKey)
    }

    convenience init() {
        self.init(provider: HealthKitActivityProvider(), defaults: .standard)
    }

    var stepsProgress: Double {
        let goal = max(goals.steps, 1)
        return min(Double(stepsToday) / Double(goal), 1)
    }

    var caloriesProgress: Double {
        let goal = max(goals.activeCalories, 1)
        return min(caloriesToday / goal, 1)
    }

    var auraProgress: Double {
        (stepsProgress + caloriesProgress) / 2
    }

    var progressPercentText: String {
        "\(Int((auraProgress * 100).rounded()))%"
    }

    func onAppear() async {
        goals = GoalsStore.shared.current
        let snapshot = await provider.fetchTodayActivity()
        ingest(todaySteps: snapshot.steps, todayCalories: snapshot.calories)
    }

    func ingest(todaySteps: Int, todayCalories: Double) {
        stepsToday = max(0, todaySteps)
        caloriesToday = max(0, todayCalories)
        upsertTodayRecord()
    }

    func updateStepsGoal(_ value: Int) {
        goals.steps = max(1000, value)
        persistGoals()
    }

    func updateCaloriesGoal(_ value: Int) {
        goals.activeCalories = Double(max(100, value))
        persistGoals()
    }

    func progress(for record: DailyRecord) -> Double {
        let s = min(Double(record.steps) / Double(max(goals.steps, 1)), 1)
        let c = min(record.calories / max(goals.activeCalories, 1), 1)
        return (s + c) / 2
    }

    var last14Days: [DailyRecord] {
        let calendar = Calendar.current
        let formatter = Self.storageFormatter
        let today = calendar.startOfDay(for: Date())

        return (0..<14).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = formatter.string(from: day)
            if let existing = historyByDay[key] {
                return existing
            }
            return DailyRecord(dateKey: key, steps: 0, calories: 0)
        }
    }

    func displayDate(for key: String) -> String {
        guard let date = Self.storageFormatter.date(from: key) else { return key }
        return Self.uiFormatter.string(from: date)
    }

    private func persistGoals() {
        GoalsStore.shared.current = goals
    }

    private func upsertTodayRecord() {
        let key = Self.storageFormatter.string(from: Date())
        historyByDay[key] = DailyRecord(dateKey: key, steps: stepsToday, calories: caloriesToday)
        Self.saveHistory(historyByDay, defaults: defaults, key: historyKey)
    }

    private static var storageFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static var uiFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE, MMM d")
        return formatter
    }

    private static func loadHistory(defaults: UserDefaults, key: String) -> [String: DailyRecord] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: DailyRecord].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveHistory(_ history: [String: DailyRecord], defaults: UserDefaults, key: String) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: key)
    }
}
