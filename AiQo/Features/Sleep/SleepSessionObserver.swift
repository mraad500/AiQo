import Foundation
import HealthKit
import UserNotifications

@MainActor
final class SleepSessionObserver: NSObject {
    static let shared = SleepSessionObserver()

    private enum DefaultsKeys {
        static let anchorData = "aiqo.sleepObserver.anchorData"
        static let lastNotifiedSleepEnd = "aiqo.sleepObserver.lastNotifiedSleepEnd"
    }

    private let healthStore: HKHealthStore
    private let notificationCenter: UNUserNotificationCenter
    private let userDefaults: UserDefaults
    private let notificationComposer: CaptainBackgroundNotificationComposer

    private var sleepObserverQuery: HKObserverQuery?
    private var sleepAnchor: HKQueryAnchor?
    private var hasStartedObserver = false

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        notificationCenter: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults = .standard,
        notificationComposer: CaptainBackgroundNotificationComposer? = nil
    ) {
        self.healthStore = healthStore
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        self.notificationComposer = notificationComposer ?? CaptainBackgroundNotificationComposer()
        self.sleepAnchor = Self.loadAnchor(from: userDefaults)
        super.init()
    }

    func start() {
        Task { @MainActor [weak self] in
            await self?.startSleepObservationIfNeeded()
        }
    }
}

private extension SleepSessionObserver {
    func startSleepObservationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !hasStartedObserver else { return }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        guard await ensureSleepReadAuthorization(for: sleepType) else { return }

        do {
            try await healthStore.enableBackgroundDelivery(
                for: sleepType,
                frequency: .immediate
            )
        } catch {
            diag.error("SleepSessionObserver background delivery failed", error: error)
        }

        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }

            if let error {
                diag.error("SleepSessionObserver observer failed", error: error)
                completionHandler()
                return
            }

            Task { @MainActor [weak self] in
                defer { completionHandler() }
                await self?.syncSleepUpdates(shouldNotify: true)
            }
        }

        sleepObserverQuery = query
        healthStore.execute(query)
        hasStartedObserver = true

        // Establish the anchor without sending a historical notification on first launch.
        await syncSleepUpdates(shouldNotify: false)
    }

    func syncSleepUpdates(shouldNotify: Bool) async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let (samples, newAnchor) = await fetchAnchoredSleepSamples(type: sleepType, anchor: sleepAnchor)
        let notificationsAllowed = DevOverride.unlockAllFeatures || TierGate.shared.canAccess(.captainNotifications)
        if shouldNotify && !notificationsAllowed {
            diag.info("SleepSessionObserver.syncSleepUpdates blocked by TierGate(.captainNotifications)")
        }
        let actuallyNotify = shouldNotify && notificationsAllowed

        if let newAnchor {
            sleepAnchor = newAnchor
            persistAnchor(newAnchor)
        }

        guard actuallyNotify else { return }
        guard let latestEndDate = latestRelevantSleepEndDate(in: samples) else { return }
        guard shouldNotifyForSleepSessionEnding(at: latestEndDate) else { return }

        let body = await notificationComposer.composeSleepCompletionNotification(
            sessionEndedAt: latestEndDate,
            language: AppSettingsStore.shared.appLanguage,
            level: max(LevelStore.shared.level, 1)
        )
        await scheduleSleepNotification(
            body: body,
            sessionEndedAt: latestEndDate
        )
    }

    func fetchAnchoredSleepSamples(
        type: HKCategoryType,
        anchor: HKQueryAnchor?
    ) async -> ([HKCategorySample], HKQueryAnchor?) {
        await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, _, newAnchor, error in
                if let error {
                    diag.error("SleepSessionObserver anchored query failed", error: error)
                    continuation.resume(returning: ([], newAnchor))
                    return
                }

                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: (sleepSamples, newAnchor))
            }

            healthStore.execute(query)
        }
    }

    func latestRelevantSleepEndDate(in samples: [HKCategorySample]) -> Date? {
        guard let latestEndDate = samples.map(\.endDate).max() else { return nil }
        guard latestEndDate <= Date() else { return nil }
        guard Date().timeIntervalSince(latestEndDate) <= 4 * 60 * 60 else { return nil }
        return latestEndDate
    }

    func shouldNotifyForSleepSessionEnding(at endDate: Date) -> Bool {
        let lastNotifiedTimestamp = userDefaults.double(forKey: DefaultsKeys.lastNotifiedSleepEnd)
        return endDate.timeIntervalSince1970 > lastNotifiedTimestamp + 60
    }

    func scheduleSleepNotification(
        body: String,
        sessionEndedAt: Date
    ) async {
        let fireDate = SmartNotificationScheduler.shared.adjustedAutomationDate(for: Date().addingTimeInterval(1))
        let content = UNMutableNotificationContent()
        content.title = "Captain Hamoudi"
        content.body = body
        content.sound = .default
        content.categoryIdentifier = CaptainSmartNotificationService.categoryIdentifier
        content.userInfo = [
            "notification_type": "sleep_complete",
            "source": "captain_hamoudi",
            "messageText": body,
            "deepLink": "aiqo://captain",
            "sleepSessionEndTimestamp": sessionEndedAt.timeIntervalSince1970
        ]

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .passive
        }

        let request = UNNotificationRequest(
            identifier: "aiqo.sleepObserver.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, fireDate.timeIntervalSinceNow),
                repeats: false
            )
        )

        do {
            if !DevOverride.unlockAllFeatures {
                guard TierGate.shared.canAccess(.captainNotifications) else {
                    diag.info("SleepSessionObserver notification add blocked by TierGate(.captainNotifications)")
                    return
                }
            }
            try await notificationCenter.add(request)
            userDefaults.set(sessionEndedAt.timeIntervalSince1970, forKey: DefaultsKeys.lastNotifiedSleepEnd)
        } catch {
            diag.error("SleepSessionObserver notification scheduling failed", error: error)
        }
    }

    func ensureSleepReadAuthorization(
        for sleepType: HKCategoryType
    ) async -> Bool {
        do {
            try await healthStore.requestAuthorization(
                toShare: [],
                read: Set([sleepType])
            )
            return true
        } catch {
            diag.error("SleepSessionObserver authorization failed", error: error)
            return false
        }
    }

    func persistAnchor(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: anchor,
            requiringSecureCoding: true
        ) else {
            return
        }
        userDefaults.set(data, forKey: DefaultsKeys.anchorData)
    }

    static func loadAnchor(from userDefaults: UserDefaults) -> HKQueryAnchor? {
        guard let data = userDefaults.data(forKey: DefaultsKeys.anchorData) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: HKQueryAnchor.self,
            from: data
        )
    }
}
