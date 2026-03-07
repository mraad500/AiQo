import Foundation
import HealthKit
import UserNotifications
internal import Combine

@MainActor
final class MorningRoutineManager: NSObject, ObservableObject {
    static let shared = MorningRoutineManager()

    struct MorningSession: Sendable {
        let wakeDate: Date
    }

    static let notificationIdentifier = "aiqo.morningRoutine.notification"
    static let notificationSource = "morning_routine"

    private enum DefaultsKeys {
        static let scheduledWakeTimestamp = "aiqo.morningRoutine.scheduledWakeTimestamp"
        static let notificationWakeTimestamp = "aiqo.morningRoutine.notificationWakeTimestamp"
        static let readWakeTimestamp = "aiqo.morningRoutine.readWakeTimestamp"
    }

    private let healthStore: HKHealthStore
    private let notificationCenter: UNUserNotificationCenter
    private let userDefaults: UserDefaults
    private let stepThreshold = 20
    private let monitoringWindow: TimeInterval = 6 * 60 * 60

    private var stepObserverQuery: HKObserverQuery?
    private var hasStartedStepObserver = false

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        notificationCenter: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults = .standard
    ) {
        self.healthStore = healthStore
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        super.init()
    }

    func start() {
        startStepObservationIfPossible()

        Task {
            await refreshMonitoringState()
        }
    }

    func configureScheduledWake(at wakeDate: Date) {
        let previousWakeDate = scheduledWakeDate
        let hasWakeChanged = previousWakeDate?.timeIntervalSince1970 != wakeDate.timeIntervalSince1970

        userDefaults.set(wakeDate.timeIntervalSince1970, forKey: DefaultsKeys.scheduledWakeTimestamp)

        if hasWakeChanged {
            userDefaults.removeObject(forKey: DefaultsKeys.notificationWakeTimestamp)
            userDefaults.removeObject(forKey: DefaultsKeys.readWakeTimestamp)
            cancelMorningNotification()
        }

        start()
    }

    func refreshMonitoringState(now: Date = Date()) async {
        guard let wakeDate = scheduledWakeDate else { return }
        guard isInsideMonitoringWindow(now: now, wakeDate: wakeDate) else { return }
        guard !hasReadMorningMessage(for: wakeDate) else { return }
        guard !hasScheduledNotification(for: wakeDate) else { return }

        do {
            let stepsSinceWake = try await stepCountSinceWake(from: wakeDate, to: now)
            guard stepsSinceWake >= stepThreshold else { return }
            scheduleMorningNotification(for: wakeDate, stepsSinceWake: stepsSinceWake)
        } catch {
            print("MorningRoutineManager step evaluation failed:", error.localizedDescription)
        }
    }

    func prepareMorningAnalysisIfNeeded(now: Date = Date()) -> MorningSession? {
        guard let wakeDate = scheduledWakeDate else { return nil }
        guard isInsideMonitoringWindow(now: now, wakeDate: wakeDate) else { return nil }
        guard !hasReadMorningMessage(for: wakeDate) else { return nil }

        cancelMorningNotification()
        return MorningSession(wakeDate: wakeDate)
    }

    func markMorningMessageRead() {
        guard let wakeDate = scheduledWakeDate else { return }

        userDefaults.set(wakeDate.timeIntervalSince1970, forKey: DefaultsKeys.readWakeTimestamp)
        cancelMorningNotification()
    }

    func cancelMorningNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
        userDefaults.removeObject(forKey: DefaultsKeys.notificationWakeTimestamp)
    }
}

private extension MorningRoutineManager {
    var scheduledWakeDate: Date? {
        date(forKey: DefaultsKeys.scheduledWakeTimestamp)
    }

    func startStepObservationIfPossible() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !hasStartedStepObserver else { return }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        guard healthStore.authorizationStatus(for: stepType) == .sharingAuthorized else { return }

        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, error in
            if let error {
                print("MorningRoutineManager background delivery failed:", error.localizedDescription)
            }
        }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }

            if let error {
                print("MorningRoutineManager observer failed:", error.localizedDescription)
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

    func scheduleMorningNotification(for wakeDate: Date, stepsSinceWake: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Captain Hamoudi"
        content.body = "صباح الخير يا خيرر"
        content.sound = nil
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

        notificationCenter.add(request) { [weak self] error in
            if let error {
                print("MorningRoutineManager notification scheduling failed:", error.localizedDescription)
                return
            }

            Task { @MainActor [weak self] in
                self?.userDefaults.set(
                    wakeDate.timeIntervalSince1970,
                    forKey: DefaultsKeys.notificationWakeTimestamp
                )
            }
        }
    }

    func isInsideMonitoringWindow(now: Date, wakeDate: Date) -> Bool {
        let windowEnd = wakeDate.addingTimeInterval(monitoringWindow)
        return now >= wakeDate && now <= windowEnd
    }

    func hasScheduledNotification(for wakeDate: Date) -> Bool {
        userDefaults.double(forKey: DefaultsKeys.notificationWakeTimestamp) == wakeDate.timeIntervalSince1970
    }

    func hasReadMorningMessage(for wakeDate: Date) -> Bool {
        userDefaults.double(forKey: DefaultsKeys.readWakeTimestamp) == wakeDate.timeIntervalSince1970
    }

    func date(forKey key: String) -> Date? {
        let timestamp = userDefaults.double(forKey: key)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}
