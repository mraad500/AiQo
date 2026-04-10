import Foundation
import HealthKit

struct WorkoutQuickSummary {
    let activityType: HKWorkoutActivityType
    let calories: Double
    let startDate: Date
    let endDate: Date
}

extension HealthKitManager {

    /// Sum of step count from start of today to now, in user's local timezone.
    func todayStepCount() async -> Int? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let count = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: count.map { Int($0.rounded()) })
            }
            HKHealthStore().execute(query)
        }
    }

    /// Active energy burned today in kcal.
    func todayActiveCalories() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: .kilocalorie()))
            }
            HKHealthStore().execute(query)
        }
    }

    /// Most recent resting heart rate sample value in bpm. nil if none in last 7 days.
    func latestRestingHeartRate() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: value)
            }
            HKHealthStore().execute(query)
        }
    }

    /// Total sleep hours from the last completed sleep session ending today.
    func lastNightSleepHours() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: Date(), options: .strictEndDate)

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
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600.0 }

                continuation.resume(returning: totalHours > 0 ? totalHours : nil)
            }
            HKHealthStore().execute(query)
        }
    }

    /// Total workout minutes and count for today.
    func todayWorkoutSummary() async -> (minutes: Int, count: Int) {
        guard HKHealthStore.isHealthDataAvailable() else { return (0, 0) }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: (0, 0))
                    return
                }
                let totalMinutes = workouts.reduce(0) { $0 + Int(($1.duration / 60).rounded()) }
                continuation.resume(returning: (totalMinutes, workouts.count))
            }
            HKHealthStore().execute(query)
        }
    }

    /// Walking pace in km/h over the last `windowSeconds` from now.
    func recentWalkingPaceKmH(window windowSeconds: TimeInterval) async -> Double? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return nil }

        let start = Date().addingTimeInterval(-windowSeconds)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                guard let distance = result?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) else {
                    continuation.resume(returning: nil)
                    return
                }
                let hours = windowSeconds / 3600.0
                guard hours > 0, distance > 0.01 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: distance / hours)
            }
            HKHealthStore().execute(query)
        }
    }

    /// Seconds since the most recent step sample. nil if no samples today.
    func secondsSinceLastStepSample() async -> TimeInterval? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: stepType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let latest = samples?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: Date().timeIntervalSince(latest.endDate))
            }
            HKHealthStore().execute(query)
        }
    }

    /// Latest workout summary (activity type + calories + start/end). nil if none today.
    func latestWorkoutSummary() async -> WorkoutQuickSummary? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(returning: nil)
                    return
                }
                let calories: Double
                if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                   let quantity = workout.statistics(for: energyType)?.sumQuantity() {
                    calories = quantity.doubleValue(for: .kilocalorie())
                } else {
                    calories = 0
                }
                continuation.resume(returning: WorkoutQuickSummary(
                    activityType: workout.workoutActivityType,
                    calories: calories,
                    startDate: workout.startDate,
                    endDate: workout.endDate
                ))
            }
            HKHealthStore().execute(query)
        }
    }

    /// User-configured daily step goal. Read from existing preferences/UserDefaults.
    var dailyStepGoal: Int {
        let goal = UserDefaults.standard.integer(forKey: "aiqo.dailyStepGoal")
        return goal > 0 ? goal : 8000
    }
}
