import Foundation
import HealthKit
import os.log

// MARK: - Sync Result

/// نتيجة المزامنة التاريخية — أرقام خام + نقاط محسوبة + المستوى الابتدائي
struct HistoricalHealthSyncResult: Sendable {
    let totalSteps: Int
    let totalActiveCalories: Int
    let totalDistanceKm: Double
    let totalSleepHours: Double

    let aiqoPoints: Int
    let startingLevel: Int
    let shieldTier: ShieldTier

    /// هل البيانات جاية من HealthKit فعلاً أو fallback
    let hasRealData: Bool
}

// MARK: - Scoring

/// خوارزمية التسجيل — "Zero Digital Pollution": حسابات بسيطة بدون allocations
enum HistoricalHealthScoring {
    /// 1000 خطوة = 1 نقطة، 1000 كالوري = 10 نقاط، 1 كم = 2 نقطة، 1 ساعة نوم = 5 نقاط
    static func calculatePoints(
        steps: Int,
        activeCalories: Int,
        distanceKm: Double,
        sleepHours: Double
    ) -> Int {
        let stepPoints = steps / 1000
        let caloriePoints = (activeCalories / 1000) * 10
        let distancePoints = Int(distanceKm) * 2
        let sleepPoints = Int(sleepHours) * 5
        return stepPoints + caloriePoints + distancePoints + sleepPoints
    }

    /// من مجموع النقاط نحسب المستوى باستخدام نفس معادلة LevelStore (baseXP=1000, multiplier=1.2)
    static func levelFromPoints(_ totalPoints: Int) -> Int {
        guard totalPoints > 0 else { return 1 }

        let baseXP = 1000.0
        let multiplier = 1.2
        var remaining = totalPoints
        var level = 1

        while remaining > 0 {
            let xpNeeded = Int(baseXP * pow(multiplier, Double(level - 1)))
            if remaining < xpNeeded { break }
            remaining -= xpNeeded
            level += 1
        }

        return max(1, level)
    }
}

// MARK: - Engine

/// محرك مزامنة البيانات التاريخية من HealthKit — يستخدم HKStatisticsQuery فقط للأرقام الكمية
/// والنوم يُجلب بدفعات شهرية عشان ما نفجّر الذاكرة
final class HistoricalHealthSyncEngine: Sendable {

    private let healthStore: HKHealthStore
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "HistoricalHealthSync"
    )

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    // MARK: - Public API

    /// المزامنة الكاملة — تُستدعى مرة واحدة بالأونبوردنغ
    func sync() async -> HistoricalHealthSyncResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.notice("healthkit_unavailable returning_empty_result")
            return emptyResult()
        }

        // الكميات الثلاث بالتوازي (HKStatisticsQuery — صفر ذاكرة إضافية)
        async let stepsValue = fetchAllTimeCumulative(.stepCount, unit: .count())
        async let caloriesValue = fetchAllTimeCumulative(.activeEnergyBurned, unit: .kilocalorie())
        async let distanceValue = fetchAllTimeCumulative(.distanceWalkingRunning, unit: .meterUnit(with: .kilo))

        // النوم بدفعات شهرية — آخر سنة فقط
        async let sleepValue = fetchSleepHoursBatched(lookbackMonths: 12)

        let steps = await stepsValue
        let calories = await caloriesValue
        let distanceKm = await distanceValue
        let sleepHours = await sleepValue

        let hasRealData = steps > 0 || calories > 0

        let points = HistoricalHealthScoring.calculatePoints(
            steps: Int(steps),
            activeCalories: Int(calories),
            distanceKm: distanceKm,
            sleepHours: sleepHours
        )
        let level = HistoricalHealthScoring.levelFromPoints(points)
        let tier = LevelStore.shared.getShieldTier(for: level)

        logger.info(
            "sync_complete steps=\(Int(steps)) cal=\(Int(calories)) dist_km=\(String(format: "%.1f", distanceKm)) sleep_h=\(String(format: "%.1f", sleepHours)) points=\(points) level=\(level)"
        )

        return HistoricalHealthSyncResult(
            totalSteps: Int(steps),
            totalActiveCalories: Int(calories),
            totalDistanceKm: distanceKm,
            totalSleepHours: sleepHours,
            aiqoPoints: points,
            startingLevel: level,
            shieldTier: tier,
            hasRealData: hasRealData
        )
    }

    /// تطبيق النتيجة على LevelStore — يُستدعى بعد موافقة المستخدم
    @MainActor
    func applyToLevelStore(_ result: HistoricalHealthSyncResult) {
        guard result.aiqoPoints > 0 else { return }
        LevelStore.shared.addXP(result.aiqoPoints)
    }

    // MARK: - Quantity Fetches (HKStatisticsQuery — Memory-Safe)

    /// جلب المجموع الكلي لنوع كمي — HKStatisticsQuery يحسب على مستوى الـ OS بدون تحميل samples
    private func fetchAllTimeCumulative(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        // من أول يوم ممكن لحد هسه
        let predicate = HKQuery.predicateForSamples(
            withStart: Date.distantPast,
            end: Date(),
            options: .strictStartDate
        )

        do {
            return try await withCheckedThrowingContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                    continuation.resume(returning: value)
                }
                self.healthStore.execute(query)
            }
        } catch {
            logger.error("cumulative_fetch_failed type=\(identifier.rawValue) error=\(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Sleep Fetch (Batched Monthly — Memory-Safe)

    /// جلب ساعات النوم بدفعات شهرية — كل شهر يجلب، يُحسب، ويُحرر من الذاكرة
    private func fetchSleepHoursBatched(lookbackMonths: Int) async -> Double {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 0
        }

        let calendar = Calendar.current
        let now = Date()
        var totalSeconds: Double = 0

        for monthOffset in 0..<lookbackMonths {
            guard let monthEnd = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let monthStart = calendar.date(byAdding: .month, value: -(monthOffset + 1), to: now) else {
                continue
            }

            let predicate = HKQuery.predicateForSamples(
                withStart: monthStart,
                end: monthEnd,
                options: .strictStartDate
            )

            let monthSeconds = await fetchSleepSecondsForPeriod(
                sleepType: sleepType,
                predicate: predicate,
                periodStart: monthStart,
                periodEnd: monthEnd
            )
            totalSeconds += monthSeconds
        }

        return totalSeconds / 3600.0
    }

    /// جلب النوم لفترة واحدة — محدود بـ 200 sample عشان ما نفجّر الذاكرة
    private func fetchSleepSecondsForPeriod(
        sleepType: HKCategoryType,
        predicate: NSPredicate,
        periodStart: Date,
        periodEnd: Date
    ) async -> Double {
        do {
            let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: sleepType,
                    predicate: predicate,
                    limit: 200,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                ) { _, results, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
                }
                self.healthStore.execute(query)
            }

            // حساب الوقت النائم فقط (مو InBed)
            return samples.reduce(0.0) { partial, sample in
                guard isAsleepSample(sample) else { return partial }
                let clampedStart = max(sample.startDate, periodStart)
                let clampedEnd = min(sample.endDate, periodEnd)
                guard clampedEnd > clampedStart else { return partial }
                return partial + clampedEnd.timeIntervalSince(clampedStart)
            }
        } catch {
            logger.error("sleep_batch_failed error=\(error.localizedDescription)")
            return 0
        }
    }

    private func isAsleepSample(_ sample: HKCategorySample) -> Bool {
        if #available(iOS 16.0, *) {
            return sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                || sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        } else {
            return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
        }
    }

    // MARK: - Fallback

    private func emptyResult() -> HistoricalHealthSyncResult {
        HistoricalHealthSyncResult(
            totalSteps: 0,
            totalActiveCalories: 0,
            totalDistanceKm: 0,
            totalSleepHours: 0,
            aiqoPoints: 0,
            startingLevel: 1,
            shieldTier: .wood,
            hasRealData: false
        )
    }
}
