import Foundation
import HealthKit
import UserNotifications

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
        static let notificationWakeTimestamp = "aiqo.morningHabit.notificationWakeTimestamp"
        static let cachedInsight = "aiqo.morningHabit.cachedInsight"
    }

    private let healthStore: HKHealthStore
    private let healthManager: HealthKitManager
    private let notificationCenter: UNUserNotificationCenter
    private let userDefaults: UserDefaults
    private let notificationComposer: CaptainBackgroundNotificationComposer

    private let stepThreshold = 25
    private let monitoringWindow: TimeInterval = 6 * 60 * 60

    private var stepObserverQuery: HKObserverQuery?
    private var hasStartedStepObserver = false

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        healthManager: HealthKitManager? = nil,
        notificationCenter: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults = .standard,
        notificationComposer: CaptainBackgroundNotificationComposer? = nil
    ) {
        self.healthStore = healthStore
        self.healthManager = healthManager ?? .shared
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        self.notificationComposer = notificationComposer ?? CaptainBackgroundNotificationComposer()
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
            cancelMorningNotification()
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
            guard !insight.isRead else {
                cancelMorningNotification()
                return
            }

            guard !hasScheduledNotification(for: wakeDate) else { return }

            await scheduleMorningNotification(
                for: wakeDate,
                stepsSinceWake: stepsSinceWake,
                body: insight.message
            )
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
        guard !insight.isRead else {
            cancelMorningNotification()
            return
        }

        insight.isRead = true
        saveCachedInsight(insight)
        cancelMorningNotification()
    }

    func deleteReadEphemeralInsightIfNeeded() {
        guard let insight = cachedInsight, insight.isRead else { return }
        clearCachedInsight()
    }

    func cancelMorningNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
        userDefaults.removeObject(forKey: DefaultsKeys.notificationWakeTimestamp)
    }
}

private extension MorningHabitOrchestrator {
    var scheduledWakeDate: Date? {
        date(forKey: DefaultsKeys.scheduledWakeTimestamp)
    }

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

        let generatedMessage = try await generateEphemeralInsightMessage(
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

    func generateEphemeralInsightMessage(
        for wakeDate: Date,
        stepsSinceWake: Int?
    ) async throws -> String {
        if let stepsSinceWake {
            return await notificationComposer.composeMorningSleepNotification(
                wakeDate: wakeDate,
                stepsSinceWake: stepsSinceWake,
                language: AppSettingsStore.shared.appLanguage,
                level: max(LevelStore.shared.level, 1)
            )
        }

        return await notificationComposer.composeSleepCompletionNotification(
            sessionEndedAt: wakeDate,
            language: AppSettingsStore.shared.appLanguage,
            level: max(LevelStore.shared.level, 1)
        )
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

    func scheduleMorningNotification(
        for wakeDate: Date,
        stepsSinceWake: Int,
        body: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Captain Hamoudi"
        content.body = body
        content.sound = nil
        content.categoryIdentifier = CaptainSmartNotificationService.categoryIdentifier
        content.userInfo = [
            "source": Self.notificationSource,
            "destination": "captain_chat",
            "wakeTimestamp": wakeDate.timeIntervalSince1970,
            "stepsSinceWake": stepsSinceWake
        ]

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .passive
        }

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await notificationCenter.add(request)
            userDefaults.set(wakeDate.timeIntervalSince1970, forKey: DefaultsKeys.notificationWakeTimestamp)
        } catch {
            print("MorningHabitOrchestrator notification scheduling failed:", error.localizedDescription)
        }
    }

    func hasScheduledNotification(for wakeDate: Date) -> Bool {
        userDefaults.double(forKey: DefaultsKeys.notificationWakeTimestamp) == wakeDate.timeIntervalSince1970
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
