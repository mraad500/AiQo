import Foundation
import HealthKit

@MainActor
final class MorningHabitOrchestrator: NSObject {
    static let shared = MorningHabitOrchestrator()

    struct MorningInsight: Codable, Equatable, Sendable {
        let wakeTimestamp: TimeInterval
        let message: String
        var isRead: Bool
        let createdAtTimestamp: TimeInterval

        var wakeDate: Date {
            Date(timeIntervalSince1970: wakeTimestamp)
        }
    }

    static let notificationIdentifier = "aiqo.morningHabit.notification"
    static let notificationSource = "morning_habit"

    private enum DefaultsKeys {
        static let scheduledWakeTimestamp = "aiqo.morningHabit.scheduledWakeTimestamp"
        static let cachedInsight = "aiqo.morningHabit.cachedInsight"
    }

    private let healthStore: HKHealthStore
    private let healthManager: HealthKitManager
    private let userDefaults: UserDefaults

    private let stepThreshold = 25
    private let monitoringWindow: TimeInterval = 6 * 60 * 60

    private var stepObserverQuery: HKObserverQuery?
    private var hasStartedStepObserver = false

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        healthManager: HealthKitManager? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.healthStore = healthStore
        self.healthManager = healthManager ?? .shared
        self.userDefaults = userDefaults
        super.init()
    }

    func start() {
        Task { @MainActor [weak self] in
            await self?.startStepObservationIfPossible()
            await self?.refreshMonitoringState()
        }
    }

    func configureScheduledWake(at wakeDate: Date) {
        let previousWakeDate = scheduledWakeDate
        let hasWakeChanged = previousWakeDate?.timeIntervalSince1970 != wakeDate.timeIntervalSince1970

        userDefaults.set(wakeDate.timeIntervalSince1970, forKey: DefaultsKeys.scheduledWakeTimestamp)

        if hasWakeChanged {
            clearCachedInsight()
        }

        start()
    }

    func refreshMonitoringState(now: Date = Date()) async {
        guard let wakeDate = scheduledWakeDate else { return }
        guard isInsideMonitoringWindow(now: now, wakeDate: wakeDate) else { return }

        do {
            let stepsSinceWake = try await stepCountSinceWake(from: wakeDate, to: now)
            guard stepsSinceWake >= stepThreshold else { return }

            let insight = try await ensureEphemeralInsight(
                for: wakeDate,
                stepsSinceWake: stepsSinceWake
            )
            guard !insight.isRead else { return }

            // Notification delivery removed — Phase 2 CaptainBriefingScheduler handles morning slot
        } catch {
            print("MorningHabitOrchestrator refresh failed:", error.localizedDescription)
        }
    }

    func consumeEphemeralInsightIfNeeded(now: Date = Date()) async -> MorningInsight? {
        guard let wakeDate = scheduledWakeDate else { return nil }
        guard isInsideMonitoringWindow(now: now, wakeDate: wakeDate) else { return nil }

        do {
            return try await ensureEphemeralInsight(
                for: wakeDate,
                stepsSinceWake: nil
            )
        } catch {
            print("MorningHabitOrchestrator insight generation failed:", error.localizedDescription)
            return nil
        }
    }

    func markEphemeralInsightRead() {
        guard var insight = cachedInsight else { return }
        guard !insight.isRead else { return }

        insight.isRead = true
        saveCachedInsight(insight)
    }

    func deleteReadEphemeralInsightIfNeeded() {
        guard let insight = cachedInsight, insight.isRead else { return }
        clearCachedInsight()
    }

    /// Returns the scheduled wake date, if any.
    var scheduledWakeDate: Date? {
        date(forKey: DefaultsKeys.scheduledWakeTimestamp)
    }
}

private extension MorningHabitOrchestrator {
    var cachedInsight: MorningInsight? {
        guard let data = userDefaults.data(forKey: DefaultsKeys.cachedInsight) else { return nil }
        return try? JSONDecoder().decode(MorningInsight.self, from: data)
    }

    func startStepObservationIfPossible() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !hasStartedStepObserver else { return }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        guard scheduledWakeDate != nil else { return }
        guard await ensureStepReadAuthorization(for: stepType) else { return }

        do {
            try await healthStore.enableBackgroundDelivery(
                for: stepType,
                frequency: .immediate
            )
        } catch {
            print("MorningHabitOrchestrator background delivery failed:", error.localizedDescription)
        }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }

            if let error {
                print("MorningHabitOrchestrator observer failed:", error.localizedDescription)
                completionHandler()
                return
            }

            Task { @MainActor [weak self] in
                defer { completionHandler() }
                await self?.refreshMonitoringState()
            }
        }

        stepObserverQuery = query
        healthStore.execute(query)
        hasStartedStepObserver = true
    }

    func ensureEphemeralInsight(
        for wakeDate: Date,
        stepsSinceWake: Int?
    ) async throws -> MorningInsight {
        if let cachedInsight, cachedInsight.wakeTimestamp == wakeDate.timeIntervalSince1970 {
            return cachedInsight
        }

        let generatedMessage = generateDefaultInsightMessage(
            for: wakeDate,
            stepsSinceWake: stepsSinceWake
        )
        let insight = MorningInsight(
            wakeTimestamp: wakeDate.timeIntervalSince1970,
            message: generatedMessage,
            isRead: false,
            createdAtTimestamp: Date().timeIntervalSince1970
        )
        saveCachedInsight(insight)
        return insight
    }

    func generateDefaultInsightMessage(
        for wakeDate: Date,
        stepsSinceWake: Int?
    ) -> String {
        if let steps = stepsSinceWake, steps >= stepThreshold {
            return "صباح الخير بطل، بديت يومك بـ\(steps) خطوة، استمر!"
        }
        return "صباح الخير بطل، قوم وابدأ يومك بقوة!"
    }

    func sleepSession(from stages: [SleepStageData]) -> SleepSession? {
        guard !stages.isEmpty else { return nil }

        var deepSleep: TimeInterval = 0
        var remSleep: TimeInterval = 0
        var coreSleep: TimeInterval = 0
        var awakeTime: TimeInterval = 0

        for stage in stages {
            switch stage.stage {
            case .deep:
                deepSleep += stage.duration
            case .rem:
                remSleep += stage.duration
            case .core:
                coreSleep += stage.duration
            case .awake:
                awakeTime += stage.duration
            }
        }

        let totalSleep = deepSleep + remSleep + coreSleep
        guard totalSleep > 0 else { return nil }

        return SleepSession(
            totalSleep: totalSleep,
            deepSleep: deepSleep,
            remSleep: remSleep,
            coreSleep: coreSleep,
            awake: awakeTime
        )
    }

    func stepCountSinceWake(from startDate: Date, to endDate: Date) async throws -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let count = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count.rounded()))
            }

            healthStore.execute(query)
        }
    }

    func saveCachedInsight(_ insight: MorningInsight) {
        if let data = try? JSONEncoder().encode(insight) {
            userDefaults.set(data, forKey: DefaultsKeys.cachedInsight)
        }
    }

    func clearCachedInsight() {
        userDefaults.removeObject(forKey: DefaultsKeys.cachedInsight)
    }

    func isInsideMonitoringWindow(now: Date, wakeDate: Date) -> Bool {
        let windowEnd = wakeDate.addingTimeInterval(monitoringWindow)
        return now >= wakeDate && now <= windowEnd
    }

    func date(forKey key: String) -> Date? {
        let timestamp = userDefaults.double(forKey: key)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func ensureStepReadAuthorization(
        for stepType: HKQuantityType
    ) async -> Bool {
        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: Set([stepType])
            )
            return true
        } catch {
            print("MorningHabitOrchestrator step authorization failed:", error.localizedDescription)
            return false
        }
    }
}

private enum MorningHabitOrchestratorError: LocalizedError {
    case noSleepData

    var errorDescription: String? {
        switch self {
        case .noSleepData:
            return "No sleep data was available for the morning habit loop."
        }
    }
}
