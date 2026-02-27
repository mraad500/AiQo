import Foundation
import SwiftUI
import UIKit
internal import Combine

extension Notification.Name {
    static let questKitchenPlanSaved = Notification.Name("aiqo.quest.kitchen.plan.saved")
}

#if DEBUG
struct QuestDebugOverrides {
    var extraStepsToday: Double = 0
    var extraDistanceKmToday: Double = 0
    var extraActiveKcalToday: Double = 0
    var extraSleepHoursToday: Double = 0
    var extraWaterLitersToday: Double = 0
    var extraZone2MinutesToday: Double = 0
    var extraCardioMinutesToday: Double = 0
}
#endif

@MainActor
final class QuestEngine: ObservableObject {
    static let shared = QuestEngine()

    @Published private(set) var stages: [QuestStageViewModel]
    @Published private(set) var progressByQuestId: [String: QuestProgressRecord]
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastRefreshDate: Date?
    @Published private(set) var isHealthAuthorized: Bool = false
    @Published private(set) var hasSleepDataInOvernightWindow: Bool = true

    #if DEBUG
    @Published private(set) var debugOverrides = QuestDebugOverrides()
    #endif

    private let evaluator: QuestEvaluator
    private var progressStore: QuestProgressStore
    private let healthDataSource: HealthKitDataSource
    private let waterDataSource: WaterDataSource
    private let cameraDataSource: CameraVisionDataSource
    private let timerDataSource: TimerSessionDataSource
    private let workoutDataSource: WorkoutLogDataSource
    private let socialDataSource: SocialArenaDataSource
    private let kitchenDataSource: KitchenDataSource
    private let shareDataSource: ShareDataSource

    private var definitionById: [String: QuestDefinition]

    private var observers: [NSObjectProtocol] = []

    private let moveGoalKcal: Double = {
        let fallback = 400.0
        guard let data = UserDefaults.standard.data(forKey: "aiqo.dailyGoals") else {
            return fallback
        }

        struct GoalsPayload: Decodable {
            let activeCalories: Double
        }

        guard
            let payload = try? JSONDecoder().decode(GoalsPayload.self, from: data),
            payload.activeCalories > 0
        else {
            return fallback
        }

        return payload.activeCalories
    }()

    init(
        evaluator: QuestEvaluator? = nil,
        progressStore: QuestProgressStore? = nil,
        healthDataSource: HealthKitDataSource? = nil,
        waterDataSource: WaterDataSource? = nil,
        cameraDataSource: CameraVisionDataSource? = nil,
        timerDataSource: TimerSessionDataSource? = nil,
        workoutDataSource: WorkoutLogDataSource? = nil,
        socialDataSource: SocialArenaDataSource? = nil,
        kitchenDataSource: KitchenDataSource? = nil,
        shareDataSource: ShareDataSource? = nil
    ) {
        let resolvedEvaluator = evaluator ?? QuestEvaluator()
        let resolvedProgressStore = progressStore ?? UserDefaultsQuestProgressStore()
        let resolvedHealthDataSource = healthDataSource ?? QuestHealthKitDataSource()
        let resolvedWaterDataSource = waterDataSource ?? QuestWaterDataSource()
        let resolvedCameraDataSource = cameraDataSource ?? QuestCameraVisionPlaceholderDataSource()
        let resolvedTimerDataSource = timerDataSource ?? QuestTimerSessionDataSource()
        let resolvedWorkoutDataSource = workoutDataSource ?? QuestWorkoutLogDataSource()
        let resolvedSocialDataSource = socialDataSource ?? QuestSocialArenaDataSource()
        let resolvedKitchenDataSource = kitchenDataSource ?? QuestKitchenDataSource()
        let resolvedShareDataSource = shareDataSource ?? QuestShareDataSource()

        self.evaluator = resolvedEvaluator
        self.progressStore = resolvedProgressStore
        self.healthDataSource = resolvedHealthDataSource
        self.waterDataSource = resolvedWaterDataSource
        self.cameraDataSource = resolvedCameraDataSource
        self.timerDataSource = resolvedTimerDataSource
        self.workoutDataSource = resolvedWorkoutDataSource
        self.socialDataSource = resolvedSocialDataSource
        self.kitchenDataSource = resolvedKitchenDataSource
        self.shareDataSource = resolvedShareDataSource

        let stages = QuestDefinitions.stageModels()
        self.stages = stages

        let definitions = stages.flatMap(\.quests)
        self.definitionById = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0) })

        self.progressByQuestId = [:]
        hydrateProgress(from: resolvedProgressStore.load(), now: Date())

        observeEvents()

        refreshAllProgress(reason: .appLaunch)
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func definitions(for stageIndex: Int) -> [QuestDefinition] {
        stages.first(where: { $0.id == stageIndex })?.quests ?? []
    }

    func definition(for questId: String) -> QuestDefinition? {
        definitionById[questId]
    }

    func configure(progressStore: QuestProgressStore) {
        self.progressStore = progressStore
        hydrateProgress(from: progressStore.load(), now: Date())
        persist()
        refreshAllProgress(reason: .appLaunch)
    }

    func getProgress(for quest: QuestDefinition) -> QuestProgressRecord {
        progressByQuestId[quest.id] ?? evaluator.initialRecord(for: quest.id, now: Date())
    }

    func cardProgress(for quest: QuestDefinition) -> QuestCardProgressModel {
        evaluator.cardProgressModel(definition: quest, record: getProgress(for: quest))
    }

    func isStageUnlocked(_ stageIndex: Int) -> Bool {
        if stageIndex <= 2 {
            return true
        }

        let previous = stageIndex - 1
        let previousQuests = definitions(for: previous)

        guard !previousQuests.isEmpty else {
            return false
        }

        return previousQuests.allSatisfy { getProgress(for: $0).currentTier >= 3 }
    }

    func stageCompletion(stageIndex: Int) -> Double {
        let quests = definitions(for: stageIndex)
        guard !quests.isEmpty else { return 0 }

        let completed = quests.reduce(0) { partial, quest in
            partial + (getProgress(for: quest).currentTier >= 3 ? 1 : 0)
        }

        return Double(completed) / Double(quests.count)
    }

    func startQuestSession(questId: String) {
        guard let definition = definitionById[questId] else { return }

        var record = progressByQuestId[questId] ?? evaluator.initialRecord(for: questId, now: Date())
        evaluator.applyPeriodResets(definition: definition, record: &record, now: Date())

        record.isStarted = true
        record.startedAt = Date()
        record.lastUpdated = Date()

        if definition.source == .timer {
            timerDataSource.startSession(questId: questId, at: Date())
        }

        progressByQuestId[questId] = record
        persist()
    }

    func cancelQuestSession(questId: String) {
        guard var record = progressByQuestId[questId] else { return }
        record.isStarted = false
        record.startedAt = nil
        record.lastUpdated = Date()
        progressByQuestId[questId] = record
        persist()
    }

    func finishQuestSession(questId: String, sessionResult: QuestSessionResult) {
        guard let definition = definitionById[questId] else { return }
        let now = Date()

        var record = progressByQuestId[questId] ?? evaluator.initialRecord(for: questId, now: now)
        evaluator.applyPeriodResets(definition: definition, record: &record, now: now)

        if definition.isStageOneBooleanQuest, record.isCompleted {
            record.isStarted = false
            record.startedAt = nil
            evaluator.evaluateAndAssignTier(definition: definition, record: &record, now: now)
            progressByQuestId[questId] = record
            persist()
            return
        }

        switch sessionResult {
        case let .manualConfirmed(count):
            if definition.isStageOneBooleanQuest {
                guard count > 0 else { break }
                record.metricAValue = 1
                record.isCompleted = true
                record.completedAt = record.completedAt ?? now
            } else {
                record.metricAValue += max(count, 0)
            }

        case let .waterLogged(liters):
            if definition.type == .streak {
                let threshold = streakThresholdA(definition: definition, currentTier: record.currentTier)
                let qualified = liters >= threshold
                evaluator.updateStreak(definition: definition, record: &record, qualifiedToday: qualified, now: now)
            } else {
                record.metricAValue += max(liters, 0)
            }

        case let .timerFinished(seconds):
            let valueA: Double
            if definition.metricAKey == .timerMinutes {
                valueA = seconds / 60.0
            } else {
                valueA = seconds
            }

            if definition.type == .streak {
                let threshold = streakThresholdA(definition: definition, currentTier: record.currentTier)
                evaluator.updateStreak(definition: definition, record: &record, qualifiedToday: valueA >= threshold, now: now)
            } else if definition.type == .cumulative {
                record.metricAValue += max(valueA, 0)
            } else {
                record.metricAValue = max(record.metricAValue, valueA)
            }

        case let .cameraFinished(reps, accuracy):
            record.metricAValue = max(record.metricAValue, Double(reps))
            record.metricBValue = max(record.metricBValue, accuracy)

        case let .workoutLogged(minutes):
            let kind = workoutKind(for: definition)
            workoutDataSource.addSession(kind: kind, minutes: minutes, date: now)
            let total = definition.type == .daily
                ? workoutDataSource.fetchMinutes(kind: kind, on: now)
                : workoutDataSource.fetchTotalMinutes(kind: kind)
            record.metricAValue = total

            if definition.type == .streak {
                let threshold = streakThresholdA(definition: definition, currentTier: record.currentTier)
                evaluator.updateStreak(definition: definition, record: &record, qualifiedToday: total >= threshold, now: now)
            }

        case let .socialInteraction(count):
            socialDataSource.addInteraction(count: count, date: now)
            if definition.type == .daily {
                record.metricAValue = Double(socialDataSource.fetchDailyInteractions(date: now))
            } else {
                record.metricAValue = Double(socialDataSource.fetchTotalInteractions())
            }

        case .kitchenPlanSaved:
            kitchenDataSource.markPlanSaved(date: now)
            if definition.isStageOneBooleanQuest {
                record.metricAValue = kitchenDataSource.hasMealPlanSaved() ? 1 : 0
                record.isCompleted = record.metricAValue >= 1
                if record.isCompleted {
                    record.completedAt = record.completedAt ?? now
                }
            } else {
                record.metricAValue = Double(kitchenDataSource.fetchTotalPlansSaved())
            }

        case .shared:
            shareDataSource.markShared(date: now)
            record.metricAValue = Double(shareDataSource.fetchTotalShares())
        }

        record.isStarted = false
        record.startedAt = nil
        evaluator.evaluateAndAssignTier(definition: definition, record: &record, now: now)

        progressByQuestId[questId] = record
        persist()

        refreshAllProgress(reason: .dataChanged)
    }

    func refreshAllProgress(reason: QuestRefreshReason) {
        Task {
            await performRefresh(reason: reason)
        }
    }

    func refreshNow(reason: QuestRefreshReason) async {
        await performRefresh(reason: reason)
    }

    func requestHealthAuthorization() async -> Bool {
        let granted = await healthDataSource.requestAuthorization()
        let alreadyAuthorized = await healthDataSource.hasAuthorization()
        isHealthAuthorized = granted || alreadyAuthorized
        await performRefresh(reason: .dataChanged)
        return granted
    }

    func logWaterAndApply(questId: String, liters: Double) async {
        _ = await waterDataSource.addWater(liters: liters)
        finishQuestSession(questId: questId, sessionResult: .waterLogged(liters: liters))
    }

    func activeTimerSessionStart(for questId: String) -> Date? {
        timerDataSource.activeSessionStart(questId: questId)
    }

    func finishTimerSessionIfRunning(for questId: String) -> TimeInterval {
        let duration = timerDataSource.finishSession(questId: questId, at: Date()) ?? 0
        return max(duration, 0)
    }

    private func performRefresh(reason: QuestRefreshReason) async {
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date()
        var next = progressByQuestId

        for definition in definitionById.values where next[definition.id] == nil {
            next[definition.id] = evaluator.initialRecord(for: definition.id, now: now)
        }

        isHealthAuthorized = await healthDataSource.hasAuthorization()

        let todaySteps = await healthDataSource.fetchDailySteps(date: now) + debugSteps
        let todayDistanceKm = await healthDataSource.fetchDailyDistanceKM(date: now) + debugDistance
        let todayActiveKcal = await healthDataSource.fetchDailyActiveEnergy(date: now) + debugKcal
        let todayMovePercent: Double = {
            guard moveGoalKcal > 0 else { return 0 }
            return (todayActiveKcal / moveGoalKcal) * 100
        }()
        let sleepSummary = await healthDataSource.fetchSleepSummary(date: now)
        let todaySleep = sleepSummary.hours + debugSleep
        hasSleepDataInOvernightWindow = sleepSummary.hasData || debugSleep > 0
        let todayWater = await waterDataSource.fetchDailyWaterLiters(date: now) + debugWater

        let todayZone2 = workoutDataSource.fetchMinutes(kind: .zone2, on: now) + debugZone2
        let todayCardio = workoutDataSource.fetchMinutes(kind: .cardio, on: now) + debugCardio
        let totalZone2 = workoutDataSource.fetchTotalMinutes(kind: .zone2) + debugZone2
        let totalCardio = workoutDataSource.fetchTotalMinutes(kind: .cardio) + debugCardio

        let totalSocial = Double(socialDataSource.fetchTotalInteractions())
        let todaySocial = Double(socialDataSource.fetchDailyInteractions(date: now))

        let hasMealPlan = kitchenDataSource.hasMealPlanSaved()
        let totalPlans = hasMealPlan ? 1.0 : Double(kitchenDataSource.fetchTotalPlansSaved())
        let todayPlan = kitchenDataSource.fetchDailyPlanSaved(date: now) ? 1.0 : 0.0

        let totalShares = Double(shareDataSource.fetchTotalShares())
        let todayShares = Double(shareDataSource.fetchDailyShares(date: now))

        var weeklyStepDays: Double = 0
        let weeklyDates = evaluator.weeklyRange(for: now)
        for day in weeklyDates where day <= now {
            let daySteps = await healthDataSource.fetchDailySteps(date: day)
            if daySteps >= 10000 {
                weeklyStepDays += 1
            }
        }

        for definition in definitionById.values {
            var record = next[definition.id] ?? evaluator.initialRecord(for: definition.id, now: now)
            evaluator.applyPeriodResets(definition: definition, record: &record, now: now)

            switch definition.source {
            case .healthkit:
                switch definition.metricAKey {
                case .steps:
                    record.metricAValue = todaySteps
                case .distanceKM:
                    record.metricAValue = todayDistanceKm
                case .movePercent:
                    record.metricAValue = todayMovePercent
                case .sleepHours:
                    record.metricAValue = todaySleep
                case .stepDaysInWeek:
                    record.metricAValue = weeklyStepDays
                default:
                    break
                }

                if definition.type == .streak {
                    let threshold = streakThresholdA(definition: definition, currentTier: record.currentTier)
                    let qualified = resolvedMetricValueForStreak(definition: definition, valueFromToday: (steps: todaySteps, distance: todayDistanceKm, move: todayMovePercent, sleep: todaySleep)) >= threshold
                    evaluator.updateStreak(definition: definition, record: &record, qualifiedToday: qualified, now: now)
                } else if definition.type == .combo {
                    let sleepThreshold = streakThresholdA(definition: definition, currentTier: record.currentTier)
                    let waterThreshold = streakThresholdB(definition: definition, currentTier: record.currentTier)
                    let qualified = todaySleep >= sleepThreshold && todayWater >= waterThreshold
                    evaluator.updateStreak(definition: definition, record: &record, qualifiedToday: qualified, now: now)
                }

            case .water:
                if definition.type == .streak {
                    let threshold = streakThresholdA(definition: definition, currentTier: record.currentTier)
                    evaluator.updateStreak(definition: definition, record: &record, qualifiedToday: todayWater >= threshold, now: now)
                } else {
                    record.metricAValue = todayWater
                }

            case .workout:
                let kind = workoutKind(for: definition)
                let today = (kind == .zone2 ? todayZone2 : todayCardio)
                let total = (kind == .zone2 ? totalZone2 : totalCardio)

                if definition.type == .streak {
                    let threshold = streakThresholdA(definition: definition, currentTier: record.currentTier)
                    evaluator.updateStreak(definition: definition, record: &record, qualifiedToday: today >= threshold, now: now)
                } else if definition.type == .daily {
                    record.metricAValue = today
                } else {
                    record.metricAValue = total
                }

            case .social:
                if definition.type == .daily {
                    record.metricAValue = todaySocial
                } else {
                    record.metricAValue = totalSocial
                }

            case .kitchen:
                if definition.isStageOneBooleanQuest {
                    record.metricAValue = hasMealPlan ? 1.0 : 0.0
                    record.isCompleted = hasMealPlan
                    if hasMealPlan {
                        record.completedAt = record.completedAt ?? now
                    }
                } else if definition.type == .daily {
                    record.metricAValue = todayPlan
                } else {
                    record.metricAValue = totalPlans
                }

            case .share:
                if definition.type == .daily {
                    record.metricAValue = todayShares
                } else {
                    record.metricAValue = totalShares
                }

            case .camera, .timer, .manual:
                break
            }

            evaluator.evaluateAndAssignTier(definition: definition, record: &record, now: now)
            next[definition.id] = record
        }

        progressByQuestId = next
        persist()
        lastRefreshDate = now

        _ = reason
    }

    private func workoutKind(for definition: QuestDefinition) -> WorkoutLogKind {
        definition.metricAKey == .cardioMinutes ? .cardio : .zone2
    }

    private func resolvedMetricValueForStreak(
        definition: QuestDefinition,
        valueFromToday: (steps: Double, distance: Double, move: Double, sleep: Double)
    ) -> Double {
        switch definition.metricAKey {
        case .steps:
            return valueFromToday.steps
        case .distanceKM:
            return valueFromToday.distance
        case .movePercent:
            return valueFromToday.move
        case .sleepHours:
            return valueFromToday.sleep
        default:
            return 0
        }
    }

    private func streakThresholdA(definition: QuestDefinition, currentTier: Int) -> Double {
        let index = min(max(currentTier, 0), 2)
        if let tierTargets = definition.streakTierTargetsA,
           tierTargets.indices.contains(index) {
            return tierTargets[index]
        }

        return definition.streakDailyTargetA ?? 0
    }

    private func streakThresholdB(definition: QuestDefinition, currentTier: Int) -> Double {
        let index = min(max(currentTier, 0), 2)
        if let tierTargets = definition.streakTierTargetsB,
           tierTargets.indices.contains(index) {
            return tierTargets[index]
        }

        return definition.streakDailyTargetB ?? 0
    }

    private static func migrateStageOneBooleanQuests(
        in records: inout [String: QuestProgressRecord],
        definitions: [QuestDefinition],
        now: Date,
        evaluator: QuestEvaluator
    ) {
        for definition in definitions where definition.isStageOneBooleanQuest {
            var record = records[definition.id] ?? evaluator.initialRecord(for: definition.id, now: now)
            let completed = record.isCompleted || record.metricAValue >= 1

            record.isCompleted = completed
            if completed {
                record.metricAValue = 1
                record.metricBValue = 0
                record.currentTier = 3
                record.completedAt = record.completedAt ?? record.lastCompletionDate ?? now
                record.lastCompletionDate = record.lastCompletionDate ?? Calendar.current.startOfDay(for: now)
            } else {
                record.metricAValue = 0
                record.metricBValue = 0
                record.currentTier = 0
                record.completedAt = nil
            }

            record.isStarted = false
            record.startedAt = nil
            record.lastUpdated = now
            records[definition.id] = record
        }
    }

    private func observeEvents() {
        let foreground = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllProgress(reason: .foreground)
            }
        }

        let kitchen = NotificationCenter.default.addObserver(
            forName: .questKitchenPlanSaved,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.kitchenDataSource.markPlanSaved(date: Date())
                self?.refreshAllProgress(reason: .dataChanged)
            }
        }

        observers = [foreground, kitchen]
    }

    private func hydrateProgress(from loaded: [String: QuestProgressRecord], now: Date) {
        var hydrated = loaded
        let definitions = Array(definitionById.values)

        for definition in definitions where hydrated[definition.id] == nil {
            hydrated[definition.id] = evaluator.initialRecord(for: definition.id, now: now)
        }

        QuestEngine.migrateStageOneBooleanQuests(
            in: &hydrated,
            definitions: definitions,
            now: now,
            evaluator: evaluator
        )

        progressByQuestId = hydrated
    }

    private func persist() {
        progressStore.save(progressByQuestId)
    }

    #if DEBUG
    func debugAddWater(_ liters: Double) {
        debugOverrides.extraWaterLitersToday += liters
        refreshAllProgress(reason: .manualPull)
    }

    func debugAddSteps(_ steps: Double) {
        debugOverrides.extraStepsToday += steps
        refreshAllProgress(reason: .manualPull)
    }

    func debugAddDistance(_ km: Double) {
        debugOverrides.extraDistanceKmToday += km
        refreshAllProgress(reason: .manualPull)
    }

    func debugAddSleep(_ hours: Double) {
        debugOverrides.extraSleepHoursToday += hours
        refreshAllProgress(reason: .manualPull)
    }

    func debugAddWorkoutMinutes(_ minutes: Double, kind: WorkoutLogKind) {
        if kind == .zone2 {
            debugOverrides.extraZone2MinutesToday += minutes
        } else {
            debugOverrides.extraCardioMinutesToday += minutes
        }
        refreshAllProgress(reason: .manualPull)
    }

    func debugSimulateCameraResult(questId: String, reps: Int, accuracy: Double) {
        finishQuestSession(questId: questId, sessionResult: .cameraFinished(reps: reps, accuracy: accuracy))
    }

    func debugResetToday() {
        for definition in definitionById.values {
            guard var record = progressByQuestId[definition.id] else { continue }
            record.resetKeyDaily = nil
            record.isStarted = false
            record.startedAt = nil
            if definition.type == .daily {
                record.metricAValue = 0
                record.metricBValue = 0
                record.currentTier = 0
            }
            progressByQuestId[definition.id] = record
        }
        refreshAllProgress(reason: .manualPull)
    }

    func debugResetWeek() {
        for definition in definitionById.values {
            guard var record = progressByQuestId[definition.id] else { continue }
            record.resetKeyWeekly = nil
            if definition.type == .weekly {
                record.metricAValue = 0
                record.metricBValue = 0
                record.currentTier = 0
            }
            progressByQuestId[definition.id] = record
        }
        refreshAllProgress(reason: .manualPull)
    }

    var debugCameraQuestIDs: [String] {
        definitionById.values
            .filter { $0.source == .camera }
            .sorted(by: { $0.id < $1.id })
            .map(\.id)
    }

    private var debugSteps: Double { debugOverrides.extraStepsToday }
    private var debugDistance: Double { debugOverrides.extraDistanceKmToday }
    private var debugKcal: Double { debugOverrides.extraActiveKcalToday }
    private var debugSleep: Double { debugOverrides.extraSleepHoursToday }
    private var debugWater: Double { debugOverrides.extraWaterLitersToday }
    private var debugZone2: Double { debugOverrides.extraZone2MinutesToday }
    private var debugCardio: Double { debugOverrides.extraCardioMinutesToday }
    #else
    private var debugSteps: Double { 0 }
    private var debugDistance: Double { 0 }
    private var debugKcal: Double { 0 }
    private var debugSleep: Double { 0 }
    private var debugWater: Double { 0 }
    private var debugZone2: Double { 0 }
    private var debugCardio: Double { 0 }
    #endif
}
