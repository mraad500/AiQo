import Foundation
import HealthKit

final class HealthKitManager {

    // Singleton
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    // Today summary
    private(set) var todaySteps: Int = 0
    private(set) var todayDistanceKm: Double = 0
    private(set) var todayCalories: Double = 0

    // Live HR من الآيفون
    private(set) var liveHeartRateBPM: Double = 0

    // Live metrics جاية من الساعة
    private(set) var liveMetricsFromWatch: WorkoutLiveMetrics?

    private init() {}

    // MARK: - Permissions (AppDelegate يستخدمها)

    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let toShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        let toRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.workoutType()
        ]

        store.requestAuthorization(toShare: toShare, read: toRead) { _, error in
            if let error {
                print("HealthKit auth error (iOS): \(error)")
            }
        }
    }

    // MARK: - Today summary (AppDelegate يناديها باسم fetchSteps)

    func fetchSteps() {
        let group = DispatchGroup()

        var stepsValue: Double = 0
        var kcalValue: Double = 0
        var distanceValue: Double = 0

        group.enter()
        fetchCumulativeQuantity(
            identifier: .stepCount,
            unit: .count()
        ) { value in
            stepsValue = value
            group.leave()
        }

        group.enter()
        fetchCumulativeQuantity(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie()
        ) { value in
            kcalValue = value
            group.leave()
        }

        group.enter()
        fetchCumulativeQuantity(
            identifier: .distanceWalkingRunning,
            unit: .meter()
        ) { value in
            distanceValue = value
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.todaySteps = Int(stepsValue)
            self.todayCalories = kcalValue
            self.todayDistanceKm = distanceValue / 1000.0
        }
    }

    // MARK: - Live Heart Rate من الآيفون

    func liveHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil)

        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.updateHeartRate(from: samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.updateHeartRate(from: samples)
        }

        store.execute(query)
    }

    private func updateHeartRate(from samples: [HKSample]?) {
        guard
            let sample = samples?.last as? HKQuantitySample
        else { return }

        let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))

        DispatchQueue.main.async { [weak self] in
            self?.liveHeartRateBPM = bpm
        }
    }

    // MARK: - تحديث من الساعة (PhoneConnectivityManager يستعملها)

    func updateFromWatch(metrics: WorkoutLiveMetrics) {
        DispatchQueue.main.async {
            self.liveMetricsFromWatch = metrics
        }
    }

    // MARK: - Helpers

    private func fetchCumulativeQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        completion: @escaping (Double) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            completion(0)
            return
        }

        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, stats, _ in
            let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
            completion(value)
        }

        store.execute(query)
    }
}
