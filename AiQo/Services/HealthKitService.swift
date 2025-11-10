import Foundation
import HealthKit

actor HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()
    private var authorized = false

    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if authorized { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        authorized = true
    }

    func todaySteps() async throws -> Int {
        try await requestAuthorization()
        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sum = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Double, Error>) in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .cumulativeSum) { _, stats, err in
                if let err { cont.resume(throwing: err); return }
                let val = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: val)
            }
            store.execute(q)
        }
        return Int(sum)
    }
}
