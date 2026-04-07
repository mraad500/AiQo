import Foundation
import HealthKit
import Combine

/// يجمع بيانات الأسبوع الحالي والماضي من HealthKit
@MainActor
final class WeeklyReportViewModel: ObservableObject {

    @Published var reportData: WeeklyReportData?
    @Published var isLoading = true
    @Published var metrics: [ReportMetricItem] = []

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    // MARK: - Public

    func loadReport() async {
        isLoading = true

        let now = Date()
        // بداية هالأسبوع (السبت أو الأحد حسب الـ locale)
        let thisWeekEnd = calendar.startOfDay(for: now)
        let thisWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekEnd)!
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart)!

        async let thisSteps = fetchSum(.stepCount, unit: .count(), from: thisWeekStart, to: thisWeekEnd)
        async let lastSteps = fetchSum(.stepCount, unit: .count(), from: lastWeekStart, to: thisWeekStart)

        async let thisCal = fetchSum(.activeEnergyBurned, unit: .kilocalorie(), from: thisWeekStart, to: thisWeekEnd)
        async let lastCal = fetchSum(.activeEnergyBurned, unit: .kilocalorie(), from: lastWeekStart, to: thisWeekStart)

        async let thisDist = fetchSum(.distanceWalkingRunning, unit: .meter(), from: thisWeekStart, to: thisWeekEnd)
        async let lastDist = fetchSum(.distanceWalkingRunning, unit: .meter(), from: lastWeekStart, to: thisWeekStart)

        async let thisSleep = fetchSleepHours(from: thisWeekStart, to: thisWeekEnd)
        async let lastSleep = fetchSleepHours(from: lastWeekStart, to: thisWeekStart)

        async let thisWater = fetchSum(.dietaryWater, unit: .literUnit(with: .milli), from: thisWeekStart, to: thisWeekEnd)
        async let lastWater = fetchSum(.dietaryWater, unit: .literUnit(with: .milli), from: lastWeekStart, to: thisWeekStart)

        async let thisStand = fetchStandHours(from: thisWeekStart, to: thisWeekEnd)
        async let lastStand = fetchStandHours(from: lastWeekStart, to: thisWeekStart)

        async let thisWorkouts = fetchWorkouts(from: thisWeekStart, to: thisWeekEnd)
        async let lastWorkouts = fetchWorkouts(from: lastWeekStart, to: thisWeekStart)

        async let dailyStepsArr = fetchDailySeries(.stepCount, unit: .count(), from: thisWeekStart, days: 7)
        async let dailyCalArr = fetchDailySeries(.activeEnergyBurned, unit: .kilocalorie(), from: thisWeekStart, days: 7)

        let steps = await thisSteps
        let pSteps = await lastSteps
        let cal = await thisCal
        let pCal = await lastCal
        let dist = await thisDist
        let pDist = await lastDist
        let sleep = await thisSleep
        let pSleep = await lastSleep
        let water = await thisWater
        let pWater = await lastWater
        let stand = await thisStand
        let pStand = await lastStand
        let workouts = await thisWorkouts
        let pWorkouts = await lastWorkouts
        let dSteps = await dailyStepsArr
        let dCal = await dailyCalArr

        let distKm = dist / 1000.0
        let pDistKm = pDist / 1000.0
        let waterL = water / 1000.0
        let pWaterL = pWater / 1000.0

        let totalWorkoutMin = workouts.reduce(0) { $0 + Int($1.duration / 60) }
        let pTotalWorkoutMin = pWorkouts.reduce(0) { $0 + Int($1.duration / 60) }

        let data = WeeklyReportData(
            weekStartDate: thisWeekStart,
            weekEndDate: thisWeekEnd,
            totalSteps: Int(steps),
            totalCalories: Int(cal),
            totalDistanceKm: distKm,
            totalSleepHours: sleep,
            totalWaterLiters: waterL,
            totalStandHours: Int(stand),
            workoutCount: workouts.count,
            totalWorkoutMinutes: totalWorkoutMin,
            previousSteps: Int(pSteps),
            previousCalories: Int(pCal),
            previousDistanceKm: pDistKm,
            previousSleepHours: pSleep,
            previousWaterLiters: pWaterL,
            previousStandHours: Int(pStand),
            previousWorkoutCount: pWorkouts.count,
            previousWorkoutMinutes: pTotalWorkoutMin,
            dailySteps: dSteps.map { Int($0) },
            dailyCalories: dCal.map { Int($0) }
        )

        reportData = data
        metrics = buildMetrics(from: data)
        isLoading = false
    }

    // MARK: - Metrics Builder

    private func buildMetrics(from data: WeeklyReportData) -> [ReportMetricItem] {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        return [
            ReportMetricItem(
                title: "الخطوات",
                value: formatter.string(from: NSNumber(value: data.totalSteps)) ?? "\(data.totalSteps)",
                unit: "خطوة",
                icon: "figure.walk",
                changePercent: data.stepsChange,
                tint: .mint
            ),
            ReportMetricItem(
                title: "السعرات",
                value: formatter.string(from: NSNumber(value: data.totalCalories)) ?? "\(data.totalCalories)",
                unit: "kcal",
                icon: "flame.fill",
                changePercent: data.caloriesChange,
                tint: .sand
            ),
            ReportMetricItem(
                title: "المسافة",
                value: String(format: "%.1f", data.totalDistanceKm),
                unit: "كم",
                icon: "figure.run",
                changePercent: data.distanceChange,
                tint: .mint
            ),
            ReportMetricItem(
                title: "النوم",
                value: String(format: "%.1f", data.totalSleepHours),
                unit: "ساعة",
                icon: "moon.fill",
                changePercent: data.sleepChange,
                tint: .sand
            ),
            ReportMetricItem(
                title: "الماء",
                value: String(format: "%.1f", data.totalWaterLiters),
                unit: "لتر",
                icon: "drop.fill",
                changePercent: data.waterChange,
                tint: .mint
            ),
            ReportMetricItem(
                title: "التمارين",
                value: "\(data.workoutCount)",
                unit: "تمرين",
                icon: "dumbbell.fill",
                changePercent: data.workoutChange,
                tint: .sand
            )
        ]
    }

    // MARK: - HealthKit Queries

    private func fetchSum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepHours(from startDate: Date, to endDate: Date) async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let totalSeconds = (samples as? [HKCategorySample])?.reduce(0.0) { total, sample in
                    let value = sample.value
                    // نحسب بس النوم الفعلي (مو الوقت اللي بالسرير فقط)
                    let isSleep = value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                                  value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                                  value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                                  value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    guard isSleep else { return total }
                    return total + sample.endDate.timeIntervalSince(sample.startDate)
                } ?? 0
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            healthStore.execute(query)
        }
    }

    private func fetchStandHours(from startDate: Date, to endDate: Date) async -> Double {
        guard let standType = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: standType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let count = (samples as? [HKCategorySample])?.filter {
                    $0.value == HKCategoryValueAppleStandHour.stood.rawValue
                }.count ?? 0
                continuation.resume(returning: Double(count))
            }
            healthStore.execute(query)
        }
    }

    private func fetchWorkouts(from startDate: Date, to endDate: Date) async -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchDailySeries(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date,
        days: Int
    ) async -> [Double] {
        var results: [Double] = []
        for day in 0..<days {
            let dayStart = calendar.date(byAdding: .day, value: day, to: startDate)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let value = await fetchSum(identifier, unit: unit, from: dayStart, to: dayEnd)
            results.append(value)
        }
        return results
    }
}
