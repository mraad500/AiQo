import Foundation
import HealthKit

struct QuestSleepSummary {
    let hours: Double
    let hasData: Bool
}

protocol HealthKitDataSource {
    func requestAuthorization() async -> Bool
    func hasAuthorization() async -> Bool
    func fetchDailySteps(date: Date) async -> Double
    func fetchDailyDistanceKM(date: Date) async -> Double
    func fetchDailyActiveEnergy(date: Date) async -> Double
    func fetchDailyMovePercent(date: Date, dailyGoal: Double) async -> Double
    func fetchSleepHours(date: Date) async -> Double
    func fetchSleepSummary(date: Date) async -> QuestSleepSummary
}

protocol CameraVisionDataSource {
    func runSession() async -> (reps: Int, accuracy: Double)
}

protocol WaterDataSource {
    func fetchDailyWaterLiters(date: Date) async -> Double
    func addWater(liters: Double) async -> Bool
}

protocol TimerSessionDataSource {
    func startSession(questId: String, at: Date)
    func finishSession(questId: String, at: Date) -> TimeInterval?
    func activeSessionStart(questId: String) -> Date?
}

enum WorkoutLogKind: String, Codable {
    case zone2
    case cardio
}

protocol WorkoutLogDataSource {
    func addSession(kind: WorkoutLogKind, minutes: Double, date: Date)
    func fetchMinutes(kind: WorkoutLogKind, on date: Date) -> Double
    func fetchTotalMinutes(kind: WorkoutLogKind) -> Double
}

protocol SocialArenaDataSource {
    func addInteraction(count: Int, date: Date)
    func fetchDailyInteractions(date: Date) -> Int
    func fetchTotalInteractions() -> Int
}

protocol KitchenDataSource {
    func markPlanSaved(date: Date)
    func hasMealPlanSaved() -> Bool
    func fetchDailyPlanSaved(date: Date) -> Bool
    func fetchTotalPlansSaved() -> Int
}

protocol ShareDataSource {
    func markShared(date: Date)
    func fetchDailyShares(date: Date) -> Int
    func fetchTotalShares() -> Int
}

actor QuestHealthKitDataSource: HealthKitDataSource {
    private let store = HKHealthStore()
    private var isAuthorized = false

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }
        let readTypes = readTypesSet()

        do {
            try await store.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes)
            isAuthorized = true
            return true
        } catch {
            isAuthorized = false
            return false
        }
    }

    func hasAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return false
        }

        if isAuthorized {
            return true
        }

        let readTypes = readTypesSet()
        let status = await withCheckedContinuation { continuation in
            store.getRequestStatusForAuthorization(
                toShare: Set<HKSampleType>(),
                read: readTypes
            ) { status, _ in
                continuation.resume(returning: status)
            }
        }

        isAuthorized = status == .unnecessary
        return isAuthorized
    }

    func fetchDailySteps(date: Date) async -> Double {
        await sumQuantity(.stepCount, unit: .count(), date: date)
    }

    func fetchDailyDistanceKM(date: Date) async -> Double {
        let meters = await sumQuantity(.distanceWalkingRunning, unit: .meter(), date: date)
        return meters / 1000.0
    }

    func fetchDailyActiveEnergy(date: Date) async -> Double {
        await sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), date: date)
    }

    func fetchDailyMovePercent(date: Date, dailyGoal: Double) async -> Double {
        let kcal = await fetchDailyActiveEnergy(date: date)
        guard dailyGoal > 0 else { return 0 }
        return (kcal / dailyGoal) * 100
    }

    func fetchSleepHours(date: Date) async -> Double {
        (await fetchSleepSummary(date: date)).hours
    }

    func fetchSleepSummary(date: Date) async -> QuestSleepSummary {
        await sleepSummary(for: date)
    }

    private func ensureAuthorization() async -> Bool {
        await hasAuthorization()
    }

    private func sumQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async -> Double {
        guard await ensureAuthorization() else {
            return 0
        }

        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            self.store.execute(query)
        }
    }

    private func sleepSummary(for date: Date) async -> QuestSleepSummary {
        guard await ensureAuthorization() else {
            return QuestSleepSummary(hours: 0, hasData: false)
        }

        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return QuestSleepSummary(hours: 0, hasData: false)
        }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .hour, value: -6, to: startOfToday) ?? startOfToday
        let end = calendar.date(byAdding: .hour, value: 12, to: startOfToday) ?? date

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let categorySamples = samples as? [HKCategorySample] ?? []
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]

                let totalSeconds = categorySamples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { partial, sample in
                        partial + sample.endDate.timeIntervalSince(sample.startDate)
                    }

                continuation.resume(
                    returning: QuestSleepSummary(
                        hours: totalSeconds / 3600.0,
                        hasData: categorySamples.contains { asleepValues.contains($0.value) }
                    )
                )
            }

            self.store.execute(query)
        }
    }

    private func readTypesSet() -> Set<HKObjectType> {
        let quantityIds: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .distanceWalkingRunning,
            .activeEnergyBurned,
            .dietaryWater
        ]

        let categoryIds: [HKCategoryTypeIdentifier] = [.sleepAnalysis]

        var readTypes = Set<HKObjectType>()

        for id in quantityIds {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                readTypes.insert(type)
            }
        }

        for id in categoryIds {
            if let type = HKObjectType.categoryType(forIdentifier: id) {
                readTypes.insert(type)
            }
        }

        return readTypes
    }
}

struct QuestCameraVisionPlaceholderDataSource: CameraVisionDataSource {
    func runSession() async -> (reps: Int, accuracy: Double) {
        // TODO: Real execution is driven by QuestPushupChallengeView + Vision pipeline.
        return (0, 0)
    }
}

final class QuestWaterDataSource: WaterDataSource {
    private let healthService: HealthKitService
    private let defaults: UserDefaults

    init(healthService: HealthKitService = .shared, defaults: UserDefaults = .standard) {
        self.healthService = healthService
        self.defaults = defaults
    }

    func fetchDailyWaterLiters(date: Date) async -> Double {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let key = "aiqo.quest.water.fallback.\(formatter.string(from: date))"

        let fallback = defaults.double(forKey: key)

        do {
            let ml = try await healthService.fetchTodaySummary().waterML
            let liters = max(ml / 1000.0, fallback)
            return liters
        } catch {
            return fallback
        }
    }

    func addWater(liters: Double) async -> Bool {
        guard liters > 0 else { return false }

        do {
            try await healthService.logWater(ml: liters * 1000.0)
            persistFallback(liters: liters)
            return true
        } catch {
            persistFallback(liters: liters)
            return false
        }
    }

    private func persistFallback(liters: Double) {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let key = "aiqo.quest.water.fallback.\(formatter.string(from: Date()))"
        let current = defaults.double(forKey: key)
        defaults.set(current + liters, forKey: key)
    }
}

final class QuestTimerSessionDataSource: TimerSessionDataSource {
    private let defaults: UserDefaults
    private let key = "aiqo.quest.timer.sessions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func startSession(questId: String, at: Date) {
        var sessions = loadSessions()
        sessions[questId] = at.timeIntervalSince1970
        saveSessions(sessions)
    }

    func finishSession(questId: String, at: Date) -> TimeInterval? {
        var sessions = loadSessions()
        guard let start = sessions[questId] else {
            return nil
        }

        sessions[questId] = nil
        saveSessions(sessions)

        let duration = at.timeIntervalSince1970 - start
        return max(0, duration)
    }

    func activeSessionStart(questId: String) -> Date? {
        guard let value = loadSessions()[questId] else {
            return nil
        }
        return Date(timeIntervalSince1970: value)
    }

    private func loadSessions() -> [String: Double] {
        defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
    }

    private func saveSessions(_ sessions: [String: Double]) {
        defaults.set(sessions, forKey: key)
    }
}

private struct QuestWorkoutLogEntry: Codable {
    let date: Date
    let kind: WorkoutLogKind
    let minutes: Double
}

final class QuestWorkoutLogDataSource: WorkoutLogDataSource {
    private let defaults: UserDefaults
    private let key = "aiqo.quest.workout.logs"
    private let calendar = Calendar.current

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func addSession(kind: WorkoutLogKind, minutes: Double, date: Date) {
        guard minutes > 0 else { return }

        var entries = loadEntries()
        entries.append(.init(date: date, kind: kind, minutes: minutes))
        saveEntries(entries)
    }

    func fetchMinutes(kind: WorkoutLogKind, on date: Date) -> Double {
        let start = calendar.startOfDay(for: date)
        return loadEntries()
            .filter { $0.kind == kind && calendar.isDate($0.date, inSameDayAs: start) }
            .reduce(0) { $0 + $1.minutes }
    }

    func fetchTotalMinutes(kind: WorkoutLogKind) -> Double {
        loadEntries()
            .filter { $0.kind == kind }
            .reduce(0) { $0 + $1.minutes }
    }

    private func loadEntries() -> [QuestWorkoutLogEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([QuestWorkoutLogEntry].self, from: data)) ?? []
    }

    private func saveEntries(_ entries: [QuestWorkoutLogEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}

private struct QuestSimpleCounterEntry: Codable {
    let date: Date
    let count: Int
}

final class QuestSocialArenaDataSource: SocialArenaDataSource {
    private let defaults: UserDefaults
    private let key = "aiqo.quest.social.logs"
    private let calendar = Calendar.current

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func addInteraction(count: Int, date: Date) {
        guard count > 0 else { return }

        var entries = loadEntries()
        entries.append(.init(date: date, count: count))
        saveEntries(entries)

        // TODO: Hook this to real Arena interactions when Arena event stream exists.
    }

    func fetchDailyInteractions(date: Date) -> Int {
        loadEntries()
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.count }
    }

    func fetchTotalInteractions() -> Int {
        loadEntries().reduce(0) { $0 + $1.count }
    }

    private func loadEntries() -> [QuestSimpleCounterEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([QuestSimpleCounterEntry].self, from: data)) ?? []
    }

    private func saveEntries(_ entries: [QuestSimpleCounterEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}

final class QuestKitchenDataSource: KitchenDataSource {
    private let defaults: UserDefaults
    private let logsKey = "aiqo.quest.kitchen.logs"
    private let hasMealPlanKey = "aiqo.quest.kitchen.hasMealPlan"
    private let savedAtKey = "aiqo.quest.kitchen.savedAt"
    private let calendar = Calendar.current

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func markPlanSaved(date: Date) {
        defaults.set(true, forKey: hasMealPlanKey)
        defaults.set(date.timeIntervalSince1970, forKey: savedAtKey)

        var entries = loadEntries()
        entries.append(.init(date: date, count: 1))
        saveEntries(entries)
    }

    func hasMealPlanSaved() -> Bool {
        if defaults.bool(forKey: hasMealPlanKey) {
            return true
        }

        let legacyHasEntries = !loadEntries().isEmpty
        if legacyHasEntries {
            defaults.set(true, forKey: hasMealPlanKey)
        }
        return legacyHasEntries
    }

    func fetchDailyPlanSaved(date: Date) -> Bool {
        let timestamp = defaults.double(forKey: savedAtKey)
        if timestamp > 0 {
            let savedAt = Date(timeIntervalSince1970: timestamp)
            if calendar.isDate(savedAt, inSameDayAs: date) {
                return true
            }
        }

        return loadEntries().contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func fetchTotalPlansSaved() -> Int {
        hasMealPlanSaved() ? 1 : 0
    }

    private func loadEntries() -> [QuestSimpleCounterEntry] {
        guard let data = defaults.data(forKey: logsKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([QuestSimpleCounterEntry].self, from: data)) ?? []
    }

    private func saveEntries(_ entries: [QuestSimpleCounterEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        defaults.set(data, forKey: logsKey)
    }
}

final class QuestShareDataSource: ShareDataSource {
    private let defaults: UserDefaults
    private let key = "aiqo.quest.share.logs"
    private let calendar = Calendar.current

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func markShared(date: Date) {
        var entries = loadEntries()
        entries.append(.init(date: date, count: 1))
        saveEntries(entries)
    }

    func fetchDailyShares(date: Date) -> Int {
        loadEntries()
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.count }
    }

    func fetchTotalShares() -> Int {
        loadEntries().reduce(0) { $0 + $1.count }
    }

    private func loadEntries() -> [QuestSimpleCounterEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([QuestSimpleCounterEntry].self, from: data)) ?? []
    }

    private func saveEntries(_ entries: [QuestSimpleCounterEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
