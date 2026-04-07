import Foundation
import HealthKit

@MainActor
final class SleepSessionObserver: NSObject {
    static let shared = SleepSessionObserver()

    private enum DefaultsKeys {
        static let anchorData = "aiqo.sleepObserver.anchorData"
        static let lastNotifiedSleepEnd = "aiqo.sleepObserver.lastNotifiedSleepEnd"
    }

    private let healthStore: HKHealthStore
    private let userDefaults: UserDefaults

    private var sleepObserverQuery: HKObserverQuery?
    private var sleepAnchor: HKQueryAnchor?
    private var hasStartedObserver = false

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.healthStore = healthStore
        self.userDefaults = userDefaults
        self.sleepAnchor = Self.loadAnchor(from: userDefaults)
        super.init()
    }

    func start() {
        Task { @MainActor [weak self] in
            await self?.startSleepObservationIfNeeded()
        }
    }

    /// Returns the latest sleep session end date, if available within the last 4 hours.
    func latestSleepEndDate() async -> Date? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let (samples, _) = await fetchAnchoredSleepSamples(type: sleepType, anchor: nil)
        return latestRelevantSleepEndDate(in: samples)
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
            print("SleepSessionObserver background delivery failed:", error.localizedDescription)
        }

        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }

            if let error {
                print("SleepSessionObserver observer failed:", error.localizedDescription)
                completionHandler()
                return
            }

            Task { @MainActor [weak self] in
                defer { completionHandler() }
                await self?.syncSleepUpdates()
            }
        }

        sleepObserverQuery = query
        healthStore.execute(query)
        hasStartedObserver = true

        // Establish the anchor without sending a notification on first launch.
        await syncSleepUpdates()
    }

    func syncSleepUpdates() async {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let (_, newAnchor) = await fetchAnchoredSleepSamples(type: sleepType, anchor: sleepAnchor)

        if let newAnchor {
            sleepAnchor = newAnchor
            persistAnchor(newAnchor)
        }

        // Notification delivery removed — Phase 2 CaptainBriefingScheduler handles sleep-related briefings
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
                    print("SleepSessionObserver anchored query failed:", error.localizedDescription)
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
            print("SleepSessionObserver authorization failed:", error.localizedDescription)
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
