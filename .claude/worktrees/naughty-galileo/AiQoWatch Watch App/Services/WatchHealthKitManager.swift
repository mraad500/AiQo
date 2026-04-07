import Foundation
import Combine
import HealthKit

@MainActor
class WatchHealthKitManager: ObservableObject {
    private let store = HKHealthStore()

    @Published var todaySteps: Int = 0
    @Published var todayCalories: Int = 0
    @Published var todayDistanceKm: Double = 0.0
    @Published var todaySleepHours: Double = 0.0

    func requestAuthorization() {
        let read: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRate),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType()
        ]
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]

        store.requestAuthorization(toShare: share, read: read) { ok, _ in
            guard ok else { return }
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func refresh() {
        fetchSum(.stepCount, unit: .count()) { [weak self] v in self?.todaySteps = Int(v) }
        fetchSum(.activeEnergyBurned, unit: .kilocalorie()) { [weak self] v in self?.todayCalories = Int(v) }
        fetchSum(.distanceWalkingRunning, unit: .meter()) { [weak self] v in self?.todayDistanceKm = v / 1000.0 }
        fetchSleep()
    }

    private func fetchSum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, handler: @escaping @MainActor (Double) -> Void) {
        let type = HKQuantityType(id)
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, _ in
            let val = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
            Task { @MainActor in handler(val) }
        }
        store.execute(q)
    }

    private func fetchSleep() {
        let type = HKCategoryType(.sleepAnalysis)
        let start = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let total = (samples as? [HKCategorySample])?.reduce(0.0) { sum, s in
                if s.value != HKCategoryValueSleepAnalysis.awake.rawValue {
                    return sum + s.endDate.timeIntervalSince(s.startDate)
                }
                return sum
            } ?? 0
            Task { @MainActor [weak self] in
                self?.todaySleepHours = total / 3600.0
            }
        }
        store.execute(q)
    }

    var healthStore: HKHealthStore { store }
}
