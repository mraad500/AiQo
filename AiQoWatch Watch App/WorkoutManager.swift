// ===============================================
// File: WorkoutManager.swift
// Target: WatchOS
// ===============================================

import Foundation
import HealthKit
import Combine
#if canImport(WatchKit)
import WatchKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

class WorkoutManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = WorkoutManager()

    // MARK: - HealthKit
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    // MARK: - Kilometer Tracking (for haptic feedback)
    private var lastRecordedKm: Int = 0
    private var livePushTimer: Timer?
    private var lastWeeklySyncAt: Date?
    private let widgetSuiteName = "group.aiqo"
    
    // MARK: - Published Properties
    
    @Published var selectedWorkout: HKWorkoutActivityType? {
        didSet {
            guard let selectedWorkout = selectedWorkout else { return }
            startWorkout(workoutType: selectedWorkout, locationType: .indoor)
        }
    }
    
    @Published var showingSummaryView: Bool = false {
        didSet {
            if showingSummaryView == false {
                resetWorkout()
            }
        }
    }
    
    @Published var running = false
    @Published var workout: HKWorkout?
    
    // Live workout data
    @Published var averageHeartRate: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var elapsedSeconds: TimeInterval = 0
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Connect to WatchConnectivityManager
        WatchConnectivityManager.shared.workoutManager = self
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("⌚️ [WorkoutManager] Authorization error: \(error.localizedDescription)")
            } else {
                print("⌚️ [WorkoutManager] HealthKit authorization: \(success)")
                if success {
                    self.refreshWeeklyWidgetData(force: true)
                }
            }
        }
    }
    
    // MARK: - ✅ Start Workout (Main Entry Point)
    /// This method is called either from:
    /// 1. WKExtensionDelegate.handle(_:) when iPhone uses startWatchApp
    /// 2. WatchConnectivityManager when receiving WCSession message
    /// 3. User selecting workout directly on Watch
    
    func startWorkout(workoutType: HKWorkoutActivityType, locationType: HKWorkoutSessionLocationType) {
        // Prevent duplicate starts
        guard session == nil else {
            print("⌚️ [WorkoutManager] Workout already in progress, ignoring start request")
            return
        }
        
        print("⌚️ [WorkoutManager] Starting workout - Type: \(workoutType.rawValue), Location: \(locationType.rawValue)")
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = locationType
        
        do {
            // Create the workout session
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            // Set delegates
            session?.delegate = self
            builder?.delegate = self
            
            // Configure the data source
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            // Start the session
            let startDate = Date()
            session?.startActivity(with: startDate)
            
            builder?.beginCollection(withStart: startDate) { [weak self] success, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if success {
                        self.running = true
                        self.lastRecordedKm = 0
                        self.startLivePushTimer()
                        print("⌚️ [WorkoutManager] Workout collection started successfully")
                    } else if let error = error {
                        print("⌚️ [WorkoutManager] Failed to begin collection: \(error.localizedDescription)")
                    }
                }
            }
            
        } catch {
            print("⌚️ [WorkoutManager] Failed to create workout session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - ✅ Start Workout with Configuration (Direct Configuration Support)
    /// Alternative method that accepts a pre-built HKWorkoutConfiguration
    /// Useful when receiving configuration directly from WKExtensionDelegate
    
    func startWorkout(with configuration: HKWorkoutConfiguration) {
        startWorkout(
            workoutType: configuration.activityType,
            locationType: configuration.locationType
        )
    }
    
    // MARK: - Default Workout (Fallback)
    
    func startDefaultWorkout() {
        startWorkout(workoutType: .running, locationType: .indoor)
    }
    
    // MARK: - Pause/Resume
    
    func togglePause() {
        if running {
            pause()
        } else {
            resume()
        }
    }
    
    func pause() {
        session?.pause()
        print("⌚️ [WorkoutManager] Workout paused")
    }
    
    func resume() {
        session?.resume()
        print("⌚️ [WorkoutManager] Workout resumed")
    }
    
    // MARK: - Stop Workout
    
    func stopWorkout() {
        print("⌚️ [WorkoutManager] Stopping workout...")
        stopLivePushTimer()
        let finalDuration = Int((builder?.elapsedTime ?? elapsedSeconds).rounded())
        let finalDistance = distance
        let finalCalories = Int(activeEnergy.rounded())
        
        session?.end()
        
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                self.builder?.finishWorkout { [weak self] workout, error in
                    DispatchQueue.main.async {
                        self?.workout = workout
                        self?.selectedWorkout = nil
                        self?.showingSummaryView = true
                        WorkoutNotificationCenter.scheduleSummary(
                            elapsedSeconds: finalDuration,
                            distanceMeters: finalDistance,
                            calories: finalCalories
                        )
                        self?.updateSharedWidgetSnapshot(
                            heartRate: self?.heartRate ?? 0,
                            activeEnergy: Double(finalCalories),
                            distanceMeters: finalDistance,
                            duration: TimeInterval(finalDuration)
                        )
                        self?.refreshWeeklyWidgetData(force: true)
                        print("⌚️ [WorkoutManager] Workout finished and saved")
                    }
                }
            } else if let error = error {
                print("⌚️ [WorkoutManager] Failed to end collection: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Reset
    
    func resetWorkout() {
        stopLivePushTimer()
        selectedWorkout = nil
        builder = nil
        session = nil
        workout = nil
        activeEnergy = 0
        averageHeartRate = 0
        heartRate = 0
        distance = 0
        elapsedSeconds = 0
        lastRecordedKm = 0
        running = false
        
        print("⌚️ [WorkoutManager] Workout state reset")
    }
    
    // MARK: - Haptic Feedback for Milestones
    
    private func checkForMilestone(totalMeters: Double) {
        let currentKm = Int(totalMeters / 1000)
        
        // Trigger when a NEW kilometer is completed
        if currentKm > 0 && currentKm > lastRecordedKm {
            lastRecordedKm = currentKm
            
            // Haptic feedback on Watch
            WKInterfaceDevice.current().play(.success)
            WorkoutNotificationCenter.scheduleMilestone(
                km: currentKm,
                heartRate: Int(heartRate.rounded()),
                calories: Int(activeEnergy.rounded()),
                elapsedSeconds: Int(elapsedSeconds.rounded()),
                distanceMeters: totalMeters
            )
            print("⌚️ [WorkoutManager] Milestone reached: \(currentKm) km - Haptic triggered")
        }
    }
    
    // MARK: - Send Live Data to iPhone
    
    private func startLivePushTimer() {
        stopLivePushTimer()
        let timer = Timer(timeInterval: 0.75, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.running else { return }
            self.sendDataToPhone(
                heartRate: self.heartRate,
                activeEnergy: self.activeEnergy,
                distance: self.distance,
                duration: self.builder?.elapsedTime ?? self.elapsedSeconds
            )
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        livePushTimer = timer
    }
    
    private func stopLivePushTimer() {
        livePushTimer?.invalidate()
        livePushTimer = nil
    }
    
    private func sendDataToPhone(
        heartRate: Double,
        activeEnergy: Double,
        distance: Double,
        duration: TimeInterval
    ) {
        let data: [String: Any] = [
            "heartRate": heartRate,
            "activeEnergy": activeEnergy,
            "distance": distance,
            "duration": duration
        ]
        WatchConnectivityManager.shared.sendLiveData(data: data)
    }

    private func updateSharedWidgetSnapshot(
        heartRate: Double,
        activeEnergy: Double,
        distanceMeters: Double,
        duration: TimeInterval
    ) {
        guard let shared = UserDefaults(suiteName: widgetSuiteName) else { return }

        let calories = max(0, Int(activeEnergy.rounded()))
        let bpm = max(0, Int(heartRate.rounded()))
        let km = max(0, distanceMeters) / 1000.0
        let standPercent = min(100, max(0, Int((duration / (13 * 3600.0)) * 100)))

        shared.set(calories, forKey: "aiqo_active_cal")
        shared.set(bpm, forKey: "aiqo_bpm")
        shared.set(standPercent, forKey: "aiqo_stand_percent")
        shared.set(km, forKey: "aiqo_km_current")
        shared.set(km, forKey: "aiqo_km")
        reloadWatchWidgets()
    }

    private func refreshWeeklyWidgetData(force: Bool = false) {
        if !force, let last = lastWeeklySyncAt, Date().timeIntervalSince(last) < 120 {
            return
        }
        lastWeeklySyncAt = Date()

        queryWeeklyDistanceKm { [weak self] dailyKm in
            guard let self else { return }
            guard let shared = UserDefaults(suiteName: self.widgetSuiteName) else { return }

            let normalized = Array(dailyKm.prefix(7))
            let padded = normalized.count < 7 ? normalized + Array(repeating: 0, count: 7 - normalized.count) : normalized
            shared.set(padded, forKey: "aiqo_week_daily_km")
            shared.set(padded.reduce(0, +), forKey: "aiqo_week_km_total")
            self.reloadWatchWidgets()
        }
    }

    private func queryWeeklyDistanceKm(completion: @escaping ([Double]) -> Void) {
        let calendar = Calendar.current
        let endDate = Date()
        let todayStart = calendar.startOfDay(for: endDate)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart),
              let walkingType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let cyclingType = HKQuantityType.quantityType(forIdentifier: .distanceCycling) else {
            completion([])
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: endDate, options: .strictStartDate)
        let interval = DateComponents(day: 1)
        let anchor = todayStart

        func executeDailyQuery(for type: HKQuantityType, done: @escaping ([Double]) -> Void) {
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                var values = Array(repeating: 0.0, count: 7)
                guard let results else {
                    done(values)
                    return
                }

                results.enumerateStatistics(from: weekStart, to: endDate) { stats, _ in
                    let day = calendar.startOfDay(for: stats.startDate)
                    let index = calendar.dateComponents([.day], from: weekStart, to: day).day ?? -1
                    guard index >= 0 && index < values.count else { return }
                    let km = stats.sumQuantity()?.doubleValue(for: HKUnit.meterUnit(with: .kilo)) ?? 0
                    values[index] = max(0, km)
                }

                done(values)
            }

            healthStore.execute(query)
        }

        executeDailyQuery(for: walkingType) { walking in
            executeDailyQuery(for: cyclingType) { cycling in
                let merged = zip(walking, cycling).map(+)
                completion(merged)
            }
        }
    }

    private func reloadWatchWidgets() {
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoWatchWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "AiQoWeeklyWidget")
#endif
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.running = (toState == .running)
            
            if toState == .running {
                self?.startLivePushTimer()
            } else {
                self?.stopLivePushTimer()
            }
        }
        
        print("⌚️ [WorkoutManager] Session state changed: \(fromState.rawValue) -> \(toState.rawValue)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("⌚️ [WorkoutManager] Session failed with error: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        var latestHeartRate = heartRate
        var latestAverageHeartRate = averageHeartRate
        var latestActiveEnergy = activeEnergy
        var latestDistance = distance
        
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            switch quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let unit = HKUnit.count().unitDivided(by: .minute())
                latestHeartRate = statistics?.mostRecentQuantity()?.doubleValue(for: unit) ?? latestHeartRate
                latestAverageHeartRate = statistics?.averageQuantity()?.doubleValue(for: unit) ?? latestAverageHeartRate
                
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let unit = HKUnit.kilocalorie()
                latestActiveEnergy = statistics?.sumQuantity()?.doubleValue(for: unit) ?? latestActiveEnergy
                
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
                 HKQuantityType.quantityType(forIdentifier: .distanceCycling):
                let unit = HKUnit.meter()
                latestDistance = statistics?.sumQuantity()?.doubleValue(for: unit) ?? latestDistance
                
            default:
                break
            }
        }
        
        let latestElapsed = workoutBuilder.elapsedTime
        
        // Send the freshest snapshot immediately to iPhone.
        sendDataToPhone(
            heartRate: latestHeartRate,
            activeEnergy: latestActiveEnergy,
            distance: latestDistance,
            duration: latestElapsed
        )
        
        // Update local published properties for Watch UI.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.heartRate = latestHeartRate
            self.averageHeartRate = latestAverageHeartRate
            self.activeEnergy = latestActiveEnergy
            self.distance = latestDistance
            self.elapsedSeconds = latestElapsed
            self.checkForMilestone(totalMeters: latestDistance)
            self.updateSharedWidgetSnapshot(
                heartRate: latestHeartRate,
                activeEnergy: latestActiveEnergy,
                distanceMeters: latestDistance,
                duration: latestElapsed
            )
            self.refreshWeeklyWidgetData()
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events (e.g., pause, resume markers)
        print("⌚️ [WorkoutManager] Workout event collected")
    }
}
