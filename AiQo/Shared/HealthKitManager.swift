// ===============================================
// File: HealthKitManager.swift
// Target: iOS (Shared logic for HealthKit)
// ===============================================

import Foundation
import HealthKit
internal import Combine

final class HealthKitManager {

    struct BioMetrics {
        let weight: String?
        let bodyFatPercentage: String?
        let leanBodyMass: String?

        static let empty = BioMetrics(
            weight: nil,
            bodyFatPercentage: nil,
            leanBodyMass: nil
        )
    }

    // MARK: - Singleton
    static let shared = HealthKitManager()
    
    private let service = HealthKitService.shared
    private let store = HKHealthStore()

    // MARK: - Published Properties for Live Observation
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Double = 0
    @Published var todayDistanceKm: Double = 0
    private var lastObservedSteps: Int = 0
    
    private init() {}

    // MARK: - 1. Authorization
    
    /// Request authorization for all required HealthKit data types
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, NSError(domain: "HealthKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"]))
            return
        }
        
        // Types to share (write)
        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]
        
        // Types to read
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKQuantityType.quantityType(forIdentifier: .leanBodyMass)!,
            HKObjectType.activitySummaryType()
        ]
        
        store.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    // MARK: - 2. Start Watch Workout (NEW - Core Feature)
    
    /// Launches the Watch app and starts a workout session with the given configuration.
    /// This is the RELIABLE way to wake the Watch app from background/suspended state.
    ///
    /// - Parameters:
    ///   - activityType: The type of workout (e.g., .running, .cycling, .functionalStrengthTraining)
    ///   - locationType: The location type (.indoor or .outdoor)
    ///   - completion: Callback with success status and optional error
    func startWatchWorkout(
        activityType: HKWorkoutActivityType,
        locationType: HKWorkoutSessionLocationType,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = NSError(domain: "HealthKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available"])
            completion(false, error)
            return
        }
        
        // Create the workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = locationType
        
        // Call the Apple API to wake the Watch app
        // This is the KEY API that wakes the Watch even from suspended/background state
        store.startWatchApp(with: configuration) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [HealthKitManager] startWatchApp failed: \(error.localizedDescription)")
                    completion(false, error)
                } else if success {
                    print("✅ [HealthKitManager] Watch app launched successfully with config: \(activityType.rawValue)")
                    completion(true, nil)
                } else {
                    let error = NSError(domain: "HealthKit", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "startWatchApp returned false without error"])
                    print("⚠️ [HealthKitManager] startWatchApp returned false")
                    completion(false, error)
                }
            }
        }
    }
    
    /// Convenience method with HKWorkoutConfiguration parameter
    func startWatchWorkout(
        workoutConfiguration: HKWorkoutConfiguration,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = NSError(domain: "HealthKit", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available"])
            completion(false, error)
            return
        }
        
        store.startWatchApp(with: workoutConfiguration) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [HealthKitManager] startWatchApp failed: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("✅ [HealthKitManager] Watch app launched: \(success)")
                    completion(success, nil)
                }
            }
        }
    }

    // MARK: - 3. Background Observer
    
    func startBackgroundObserver() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
            if let error = error {
                print("❌ [AiQo HK] Bg Delivery Error: \(error)")
            } else {
                print("✅ [AiQo HK] Background Delivery Enabled")
            }
        }
        
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("❌ [AiQo HK] Observer Error: \(error)")
                return
            }
            
            print("👣 [AiQo HK] Steps changed detected!")
            Task {
                await self?.processNewHealthData()
                completionHandler()
            }
        }
        
        store.execute(query)
    }
    
    /// Public method to trigger a manual fetch (used by ProfileViewController, etc.)
    func fetchSteps() {
        Task {
            await processNewHealthData()
        }
    }

    func fetchMostRecentQuantitySample(
        for identifier: HKQuantityTypeIdentifier
    ) async throws -> HKQuantitySample? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }

            store.execute(query)
        }
    }

    func fetchBioMetrics() async -> BioMetrics {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .empty
        }

        async let weightSample = try? fetchMostRecentQuantitySample(for: .bodyMass)
        async let bodyFatSample = try? fetchMostRecentQuantitySample(for: .bodyFatPercentage)
        async let leanBodyMassSample = try? fetchMostRecentQuantitySample(for: .leanBodyMass)

        let resolvedWeightSample = await weightSample
        let resolvedBodyFatSample = await bodyFatSample
        let resolvedLeanBodyMassSample = await leanBodyMassSample

        return BioMetrics(
            weight: formatMassSample(resolvedWeightSample),
            bodyFatPercentage: formatBodyFatSample(resolvedBodyFatSample),
            leanBodyMass: formatMassSample(resolvedLeanBodyMassSample)
        )
    }

    // MARK: - 4. Data Processing (The Brain Loop) 🔄
    
    private func processNewHealthData() async {
        let summary = try? await service.fetchTodaySummary()
        guard let data = summary else { return }
        let stepCount = Int(data.steps)

        await MainActor.run {
            self.todaySteps = stepCount
            self.todayCalories = data.activeKcal
            self.todayDistanceKm = data.distanceMeters / 1000.0
        }

        if stepCount > lastObservedSteps {
            InactivityTracker.shared.markActive()
        }
        lastObservedSteps = stepCount

        print("📊 [AiQo HK] Updated: \(stepCount) steps")

        calculateAndAwardCoins(
            currentSteps: stepCount,
            currentActiveKcal: data.activeKcal,
            currentDistanceKm: data.distanceMeters / 1000.0
        )
        
        let appLanguage = AppSettingsStore.shared.appLanguage
        let notifLanguage: ActivityNotificationLanguage = appLanguage == .english ? .english : .arabic

        ActivityNotificationEngine.shared.evaluateAndSendIfNeeded(
            steps: stepCount,
            calories: data.activeKcal,
            stepsGoal: 10000,
            caloriesGoal: 500,
            gender: .male,
            language: notifLanguage
        )

        await CaptainSmartNotificationService.shared.evaluateInactivityAndNotifyIfNeeded()
    }
    
    // MARK: - 5. Mining Logic ⛏️
    
    private func calculateAndAwardCoins(currentSteps: Int, currentActiveKcal: Double, currentDistanceKm: Double) {
        let defaults = UserDefaults.standard
        let lastDateKey = "aiqo.mining.lastDate"
        let lastAwardedCoinsKey = "aiqo.mining.lastAwardedCoins"

        // Mining rates (tuned for Bio-Digital pricing: 30 coins / 15 min, 100 coins / 60 min)
        let stepsPerCoin = 100               // 10k steps ≈ 100 coins
        let kcalPerCoin = 5.0               // 500 kcal ≈ 100 coins
        let distanceKmPerCoin = 0.1         // 10 km ≈ 100 coins

        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = defaults.object(forKey: lastDateKey) as? Date ?? Date.distantPast

        if !Calendar.current.isDate(today, inSameDayAs: lastDate) {
            defaults.set(today, forKey: lastDateKey)
            defaults.set(0, forKey: lastAwardedCoinsKey)
        }

        let stepsCoinsTotal = currentSteps / stepsPerCoin
        let kcalCoinsTotal = Int(currentActiveKcal / kcalPerCoin)
        let distanceCoinsTotal = Int(currentDistanceKm / distanceKmPerCoin)

        // Use the best activity metric to avoid double counting
        let totalCoins = max(stepsCoinsTotal, kcalCoinsTotal, distanceCoinsTotal)
        let lastAwarded = defaults.integer(forKey: lastAwardedCoinsKey)
        let deltaCoins = totalCoins - lastAwarded

        if deltaCoins > 0 {
            CoinManager.shared.addCoins(deltaCoins)
            defaults.set(totalCoins, forKey: lastAwardedCoinsKey)
            print("💰 Earned \(deltaCoins) coins (total today: \(totalCoins))")
        }
    }

    private func formatMassSample(_ sample: HKQuantitySample?) -> String? {
        guard let sample else { return nil }

        let kilograms = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        return formattedQuantityString(kilograms, unitSuffix: "kg")
    }

    private func formatBodyFatSample(_ sample: HKQuantitySample?) -> String? {
        guard let sample else { return nil }

        let percentValue = sample.quantity.doubleValue(for: .percent()) * 100.0
        return formattedQuantityString(percentValue, unitSuffix: "%")
    }

    private func formattedQuantityString(
        _ value: Double,
        unitSuffix: String,
        maximumFractionDigits: Int = 1
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits

        let formattedValue = formatter.string(from: NSNumber(value: value))
            ?? String(format: "%.\(maximumFractionDigits)f", value)

        return "\(formattedValue) \(unitSuffix)"
    }
}
