import Foundation
import HealthKit
import os.log

/// يربط بيانات HealthKit بذاكرة الكابتن
struct HealthKitMemoryBridge {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "HealthKitMemoryBridge"
    )

    /// يحدّث الذاكرة ببيانات HealthKit الأخيرة
    @MainActor
    static func syncHealthDataToMemory() async {
        let store = MemoryStore.shared
        guard store.isEnabled else { return }

        let healthStore = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else { return }

        // الوزن الأخير
        if let weight = await fetchLatestSample(
            healthStore: healthStore,
            type: HKQuantityType(.bodyMass),
            unit: .gramUnit(with: .kilo)
        ) {
            store.set("weight", value: String(format: "%.1f", weight), category: "body", source: "healthkit", confidence: 1.0)
        }

        // معدل النبض
        if let hr = await fetchLatestSample(
            healthStore: healthStore,
            type: HKQuantityType(.restingHeartRate),
            unit: HKUnit.count().unitDivided(by: .minute())
        ) {
            store.set("resting_heart_rate", value: String(format: "%.0f", hr), category: "body", source: "healthkit", confidence: 1.0)
        }

        // معدل الخطوات آخر 7 أيام
        if let steps = await fetchWeeklyAverage(
            healthStore: healthStore,
            type: HKQuantityType(.stepCount),
            unit: .count()
        ) {
            store.set("steps_avg", value: String(format: "%.0f", steps), category: "body", source: "healthkit", confidence: 1.0)
        }

        // معدل السعرات آخر 7 أيام
        if let cals = await fetchWeeklyAverage(
            healthStore: healthStore,
            type: HKQuantityType(.activeEnergyBurned),
            unit: .kilocalorie()
        ) {
            store.set("active_calories_avg", value: String(format: "%.0f", cals), category: "body", source: "healthkit", confidence: 1.0)
        }

        // معدل النوم آخر 7 أيام
        if let sleep = await fetchWeeklySleepAverage(healthStore: healthStore) {
            store.set("sleep_avg", value: String(format: "%.1f", sleep), category: "sleep", source: "healthkit", confidence: 1.0)
        }

        logger.info("healthkit_memory_sync_complete")
    }

    // MARK: - Private Helpers

    private static func fetchLatestSample(
        healthStore: HKHealthStore,
        type: HKQuantityType,
        unit: HKUnit
    ) async -> Double? {
        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
            end: Date(),
            options: .strictEndDate
        )
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                if let sample = samples?.first as? HKQuantitySample {
                    continuation.resume(returning: sample.quantity.doubleValue(for: unit))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }

    private static func fetchWeeklyAverage(
        healthStore: HKHealthStore,
        type: HKQuantityType,
        unit: HKUnit
    ) async -> Double? {
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: .strictEndDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                if let sum = statistics?.sumQuantity() {
                    let total = sum.doubleValue(for: unit)
                    continuation.resume(returning: total / 7.0)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }

    private static func fetchWeeklySleepAverage(healthStore: HKHealthStore) async -> Double? {
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: .strictEndDate
        )
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let sleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]

                let totalHours = categorySamples
                    .filter { sleepValues.contains($0.value) }
                    .reduce(0.0) { total, sample in
                        total + sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                    }

                if totalHours > 0 {
                    continuation.resume(returning: totalHours / 7.0)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            healthStore.execute(query)
        }
    }
}
