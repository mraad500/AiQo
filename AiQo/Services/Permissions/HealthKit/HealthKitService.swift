import Foundation
import HealthKit
import WidgetKit

// MARK: - Unified HealthKit service (Today + All Time + Write + Workouts)

actor HealthKitService {

    // Singleton
    static let shared = HealthKitService()

    let store = HKHealthStore()
    private var isAuthorized = false

    // MARK: - Authorization

    @discardableResult
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        // ===== Read Types =====
        let quantityIds: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .heartRate,
            .restingHeartRate,
            .heartRateVariabilitySDNN,
            .walkingHeartRateAverage,
            .activeEnergyBurned,
            .distanceWalkingRunning,
            .dietaryWater,
            .vo2Max
        ]

        let categoryIds: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis,
            .appleStandHour
        ]

        var readTypes = Set<HKObjectType>()

        for id in quantityIds {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                readTypes.insert(type)
            }
        }
        for id in categoryIds {
            if let type = HKObjectType.categoryType(forIdentifier: id) {
                readTypes.insert(type)
            }
        }
        readTypes.insert(HKObjectType.workoutType())

        // ===== Write Types =====
        var writeTypes = Set<HKSampleType>()

        if let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) {
            writeTypes.insert(waterType)
        }
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            writeTypes.insert(heartRateType)
        }
        if let restingType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            writeTypes.insert(restingType)
        }
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            writeTypes.insert(hrvType)
        }
        if let vo2Type = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            writeTypes.insert(vo2Type)
        }
        if let distType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            writeTypes.insert(distType)
        }

        // Workouts
        writeTypes.insert(HKObjectType.workoutType())

        // طلب الأذونات
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)

        // نتحقق إذا أكو أي نوع واحد على الأقل مسموح قراءته
        var anyReadable = false
        for type in readTypes {
            let status = store.authorizationStatus(for: type)
            if status == .sharingAuthorized {
                anyReadable = true
                break
            }
        }

        isAuthorized = anyReadable
        return anyReadable
    }

    // Helper داخلي: يتأكد من الأذون قبل أي قراءة
    private func ensureAuthorization() async -> Bool {
        if isAuthorized { return true }
        do {
            return try await requestAuthorization()
        } catch {
            return false
        }
    }

    // MARK: - Widget (Write + Reload)

    private struct WidgetGoalsPayload: Decodable {
        let steps: Int
        let activeCalories: Double
    }

    private func currentWidgetGoals(
        stepsGoalOverride: Int? = nil,
        caloriesGoalOverride: Int? = nil
    ) -> (stepsGoal: Int, caloriesGoal: Int) {
        let defaults = UserDefaults.standard
        let fallbackSteps = 8000
        let fallbackCalories = 400

        var storedSteps = fallbackSteps
        var storedCalories = fallbackCalories

        if let data = defaults.data(forKey: "aiqo.dailyGoals"),
           let saved = try? JSONDecoder().decode(WidgetGoalsPayload.self, from: data) {
            storedSteps = saved.steps
            storedCalories = Int(saved.activeCalories.rounded())
        }

        let stepsGoal = max(stepsGoalOverride ?? storedSteps, 1)
        let caloriesGoal = max(caloriesGoalOverride ?? storedCalories, 1)
        return (stepsGoal, caloriesGoal)
    }

    /// يكتب بيانات "اليوم" إلى App Group ويعمل Reload للـ Widget
    private func updateWidget(
        steps: Int,
        calories: Int,
        standPercent: Int,
        stepsGoal: Int,
        caloriesGoal: Int
    ) {
        let shared = UserDefaults(suiteName: "group.aiqo")!
        shared.set(steps, forKey: "aiqo_steps")
        shared.set(calories, forKey: "aiqo_active_cal")
        shared.set(stepsGoal, forKey: "aiqo_steps_goal")
        shared.set(caloriesGoal, forKey: "aiqo_active_cal_goal")
        shared.set(standPercent, forKey: "aiqo_stand_percent")

        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoWidget")
    }

    /// نداء جاهز: يحدث الويدجت من Today Summary (أفضل مكان للبيانات الصحيحة)
    func refreshWidgetFromToday(goal: Int? = nil, caloriesGoal: Int? = nil) async {
        let resolvedGoals = currentWidgetGoals(
            stepsGoalOverride: goal,
            caloriesGoalOverride: caloriesGoal
        )
        do {
            let summary = try await fetchTodaySummary()
            let steps = Int(summary.steps)
            let cal = Int(summary.activeKcal)
            let stand = Int(summary.standPercent)
            updateWidget(
                steps: steps,
                calories: cal,
                standPercent: stand,
                stepsGoal: resolvedGoals.stepsGoal,
                caloriesGoal: resolvedGoals.caloriesGoal
            )
        } catch {
            // إذا فشلنا بالقراءة، لا نكتب أرقام وهمية
            updateWidget(
                steps: 0,
                calories: 0,
                standPercent: 0,
                stepsGoal: resolvedGoals.stepsGoal,
                caloriesGoal: resolvedGoals.caloriesGoal
            )
        }
    }

    // MARK: - Public API (Today Summary)

    func fetchTodaySummary() async throws -> TodaySummary {
        guard await ensureAuthorization() else { return await .zero }

        async let steps = sumToday(.stepCount, unit: .count())
        async let kcal  = sumToday(.activeEnergyBurned, unit: .kilocalorie())
        async let distM = sumToday(.distanceWalkingRunning, unit: .meter())
        async let water = sumToday(.dietaryWater, unit: .literUnit(with: .milli))
        async let sleepH = sleepHoursToday()
        async let standP = standPercentToday()

        return TodaySummary(
            steps: await steps,
            activeKcal: await kcal,
            standPercent: Double(await standP),
            waterML: await water,
            sleepHours: await sleepH,
            distanceMeters: await distM
        )
    }

    func getTodaySteps() async -> Int {
        let resolvedGoals = currentWidgetGoals()
        do {
            let summary = try await fetchTodaySummary()
            // ✅ هنا نخلي الويدجت يتحدث من بيانات اليوم
            updateWidget(
                steps: Int(summary.steps),
                calories: Int(summary.activeKcal),
                standPercent: Int(summary.standPercent),
                stepsGoal: resolvedGoals.stepsGoal,
                caloriesGoal: resolvedGoals.caloriesGoal
            )
            return Int(summary.steps)
        } catch {
            return 0
        }
    }

    func getActiveCalories() async -> Double {
        let resolvedGoals = currentWidgetGoals()
        do {
            let summary = try await fetchTodaySummary()
            // ✅ هنا هم يحدث
            updateWidget(
                steps: Int(summary.steps),
                calories: Int(summary.activeKcal),
                standPercent: Int(summary.standPercent),
                stepsGoal: resolvedGoals.stepsGoal,
                caloriesGoal: resolvedGoals.caloriesGoal
            )
            return summary.activeKcal
        } catch {
            return 0
        }
    }

    func getWaterIntake() async -> Double {
        do {
            let summary = try await fetchTodaySummary()
            return summary.waterML
        } catch {
            return 0
        }
    }

    // MARK: - Public API (All-time / Lifetime Summary)

    /// يجلب كل الداتا المسجلة في Apple Health طوال حياة المستخدم
    func fetchAllTimeSummary() async throws -> AllTimeSummary {
        guard await ensureAuthorization() else { return await .zero }

        async let steps = sumAllTime(.stepCount, unit: .count())
        async let kcal  = sumAllTime(.activeEnergyBurned, unit: .kilocalorie())
        async let distM = sumAllTime(.distanceWalkingRunning, unit: .meter())
        async let water = sumAllTime(.dietaryWater, unit: .literUnit(with: .milli))
        async let sleepH = sleepHoursAllTime()
        async let standH = standHoursAllTime()

        return AllTimeSummary(
            steps: await steps,
            activeKcal: await kcal,
            distanceMeters: await distM,
            waterML: await water,
            sleepHours: await sleepH,
            standHours: await standH
        )
    }

    /// shortcuts للشاشات (All time) — ❌ بدون تحديث ويدجت
    func getAllTimeSteps() async -> Double {
        let summary = try? await fetchAllTimeSummary()
        return summary?.steps ?? 0
    }

    func getAllTimeDistanceKm() async -> Double {
        let summary = try? await fetchAllTimeSummary()
        let m = summary?.distanceMeters ?? 0
        return m / 1000.0
    }

    // MARK: - Public API (Workouts)

    func fetchWorkouts(
        limit: Int = 60,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [HKWorkout] {
        guard await ensureAuthorization() else { return [] }

        let type = HKObjectType.workoutType()
        let predicate: NSPredicate?

        if startDate != nil || endDate != nil {
            predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        } else {
            predicate = nil
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKWorkout], Error>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                cont.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    // MARK: - Public API (Write Helpers)

    /// تسجيل شرب الماء بالملّي داخل Apple Health
    func logWater(ml: Double, date: Date = Date()) async throws {
        guard let type = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            store.save(sample) { _, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }

    /// Legacy compatibility: save water in liters
    func saveWater(liters: Double, date: Date = Date()) async throws {
        try await logWater(ml: liters * 1000.0, date: date)
    }

    /// حفظ قياس نبض القلب
    func saveHeartRateSample(bpm: Double, date: Date = Date()) async throws {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let unit = HKUnit.count().unitDivided(by: .minute())
        let quantity = HKQuantity(unit: unit, doubleValue: bpm)

        let sample = HKQuantitySample(type: type,
                                      quantity: quantity,
                                      start: date,
                                      end: date)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            store.save(sample) { _, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }

    // MARK: - Simple workout saving (running)

    func saveSimpleWorkout(
        start: Date,
        end: Date,
        distanceMeters: Double? = nil,
        activeKcal: Double? = nil
    ) async throws {
        var metadata: [String: Any] = [:]
        if distanceMeters != nil {
            metadata[HKMetadataKeyIndoorWorkout] = false
        }

        if #available(iOS 17.0, *) {
            let config = HKWorkoutConfiguration()
            config.activityType = .running
            config.locationType = .outdoor

            let builder = HKWorkoutBuilder(
                healthStore: store,
                configuration: config,
                device: .local()
            )

            // begin collection
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                builder.beginCollection(withStart: start) { success, error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else if success {
                        cont.resume(returning: ())
                    } else {
                        cont.resume(throwing: NSError(
                            domain: "AiQo.HealthKit",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "beginCollection failed"]
                        ))
                    }
                }
            }

            var samples: [HKSample] = []

            if let activeKcal,
               let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
                let qty = HKQuantity(unit: .kilocalorie(), doubleValue: activeKcal)
                let sample = HKQuantitySample(type: energyType,
                                              quantity: qty,
                                              start: start,
                                              end: end)
                samples.append(sample)
            }

            if let distanceMeters,
               let distType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
                let qty = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
                let sample = HKQuantitySample(type: distType,
                                              quantity: qty,
                                              start: start,
                                              end: end)
                samples.append(sample)
            }

            if !metadata.isEmpty {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    builder.addMetadata(metadata) { success, error in
                        if let error = error {
                            cont.resume(throwing: error)
                        } else if success {
                            cont.resume(returning: ())
                        } else {
                            cont.resume(throwing: NSError(
                                domain: "AiQo.HealthKit",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "addMetadata failed"]
                            ))
                        }
                    }
                }
            }

            if !samples.isEmpty {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    builder.add(samples) { success, error in
                        if let error = error {
                            cont.resume(throwing: error)
                        } else if success {
                            cont.resume(returning: ())
                        } else {
                            cont.resume(throwing: NSError(
                                domain: "AiQo.HealthKit",
                                code: 3,
                                userInfo: [NSLocalizedDescriptionKey: "addSamples failed"]
                            ))
                        }
                    }
                }
            }

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                builder.endCollection(withEnd: end) { success, error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else if success {
                        cont.resume(returning: ())
                    } else {
                        cont.resume(throwing: NSError(
                            domain: "AiQo.HealthKit",
                            code: 4,
                            userInfo: [NSLocalizedDescriptionKey: "endCollection failed"]
                        ))
                    }
                }
            }

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                builder.finishWorkout { _, error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
        } else {
            let workout = HKWorkout(
                activityType: .running,
                start: start,
                end: end,
                workoutEvents: nil,
                totalEnergyBurned: activeKcal.map {
                    HKQuantity(unit: .kilocalorie(), doubleValue: $0)
                },
                totalDistance: distanceMeters.map {
                    HKQuantity(unit: .meter(), doubleValue: $0)
                },
                metadata: metadata
            )

            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                store.save(workout) { _, error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
        }
    }

    // MARK: - Helpers (Quantities) — Today

    private func sumToday(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }

        let (start, end) = todayBounds()
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                let val = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: val)
            }
            store.execute(query)
        }
    }

    // MARK: - Helpers (Quantities) — All Time

    /// Apple-style lifetime sum: HKStatisticsQuery بدون predicate حتى يشمل كل الداتا
    private func sumAllTime(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return 0 }

        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: nil,   // كل الداتا عبر الزمن
                options: .cumulativeSum
            ) { _, stats, _ in
                let val = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: val)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep (Today)

    private func sleepHoursToday() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let (dayStart, dayEnd) = todayBounds()

        // نطاق أكبر شوي حتى نمسك نوم الليل اللي يقطع منتصف الليل
        let startFetch = Calendar.current.date(byAdding: .hour, value: -18, to: dayStart) ?? dayStart
        let endFetch   = Calendar.current.date(byAdding: .hour, value: 6, to: dayEnd) ?? dayEnd

        let predicate = HKQuery.predicateForSamples(
            withStart: startFetch,
            end: endFetch,
            options: []
        )

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in

                let relevant = (samples as? [HKCategorySample])?.filter {
                    if #available(iOS 16.0, *) {
                        return $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue  ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    } else {
                        return $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                } ?? []

                let seconds = relevant.reduce(0.0) { acc, sample in
                    let s = max(sample.startDate, dayStart)
                    let e = min(sample.endDate, dayEnd)
                    return e > s ? acc + e.timeIntervalSince(s) : acc
                }

                cont.resume(returning: seconds / 3600.0)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep (All Time)

    private func sleepHoursAllTime() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,                 // كل الداتا
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let all = (samples as? [HKCategorySample]) ?? []

                let relevant = all.filter {
                    if #available(iOS 16.0, *) {
                        return $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue  ||
                               $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    } else {
                        return $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                    }
                }

                let seconds = relevant.reduce(0.0) { acc, s in
                    acc + s.endDate.timeIntervalSince(s.startDate)
                }

                cont.resume(returning: seconds / 3600.0)
            }
            store.execute(query)
        }
    }

    // MARK: - Stand % (Today)

    private func standPercentToday() async -> Int {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return 0 }

        let (start, end) = todayBounds()
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let stoodHours = (samples as? [HKCategorySample])?
                    .filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
                    .count ?? 0

                let percent = min(100, Int((Double(stoodHours) / 12.0) * 100.0))
                cont.resume(returning: percent)
            }
            store.execute(query)
        }
    }

    // MARK: - Stand Hours (All Time)

    private func standHoursAllTime() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .appleStandHour) else { return 0 }

        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,                 // كل السنين
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let all = (samples as? [HKCategorySample]) ?? []
                let stoodCount = all.filter {
                    $0.value == HKCategoryValueAppleStandHour.stood.rawValue
                }.count

                cont.resume(returning: Double(stoodCount))
            }
            store.execute(query)
        }
    }

    // MARK: - Day bounds

    private func todayBounds() -> (Date, Date) {
        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }
}
