import Foundation
import HealthKit
import Combine
import os

@MainActor
final class WorkoutManager: NSObject, ObservableObject {

    static let shared = WorkoutManager()

    private let log = Logger(subsystem: "com.aiqo.app.watch", category: "WorkoutManager")

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    @Published private(set) var workoutID: String?
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var sessionState: HKWorkoutSessionState = .notStarted

    @Published private(set) var heartRateBPM: Double = 0
    @Published private(set) var activeEnergyKcal: Double = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var elapsed: TimeInterval = 0

    private var startDate: Date?
    private var tickerCancellable: AnyCancellable?

    private override init() { super.init() }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }

        let types: Set<HKQuantityType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]

        Task {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: Set(types))
                self.isAuthorized = true
            } catch {
                self.isAuthorized = false
                WatchConnectivityManager.shared.publishError("HealthKit auth failed: \(error.localizedDescription)")
            }
        }
    }

    func startFromPhone(workoutID: String, activityTypeRaw: Int, locationTypeRaw: Int) {
        if isRunning, self.workoutID == workoutID { return }
        
        if isRunning {
            stop()
        }

        self.workoutID = workoutID

        let activity = HKWorkoutActivityType(rawValue: UInt(activityTypeRaw)) ?? .running
        let location = HKWorkoutSessionLocationType(rawValue: locationTypeRaw) ?? .outdoor

        startWorkout(activityType: activity, locationType: location)
    }

    private func startWorkout(activityType: HKWorkoutActivityType, locationType: HKWorkoutSessionLocationType) {
        guard isAuthorized else {
            WatchConnectivityManager.shared.publishError("Not authorized for HealthKit.")
            return
        }
        
        // تصفير العدادات
        heartRateBPM = 0
        activeEnergyKcal = 0
        distanceMeters = 0
        elapsed = 0

        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = locationType

        do {
            let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let newBuilder = newSession.associatedWorkoutBuilder()

            newSession.delegate = self
            newBuilder.delegate = self
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            session = newSession
            builder = newBuilder

            let sd = Date()
            startDate = sd
            isRunning = true
            sessionState = .running

            newSession.startActivity(with: sd)

            Task {
                do {
                    try await newBuilder.beginCollection(at: sd)
                } catch {
                    WatchConnectivityManager.shared.publishError("beginCollection failed: \(error.localizedDescription)")
                }
            }

            WatchConnectivityManager.shared.publishWorkoutState(workoutID: self.workoutID ?? UUID().uuidString, state: "running")
            startTicker()

        } catch {
            WatchConnectivityManager.shared.publishError("HKWorkoutSession create failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        // ✅ هذا الـ Guard يمنع خطأ Error 3
        guard sessionState == .running || sessionState == .paused else { return }

        guard let session else { return }
        session.stopActivity(with: .now)
        session.end()
        stopTicker()
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    private func startTicker() {
        stopTicker()
        tickerCancellable = Timer
            .publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.updateElapsedAndBroadcast()
            }
    }

    private func stopTicker() {
        tickerCancellable?.cancel()
        tickerCancellable = nil
    }

    private func updateElapsedAndBroadcast() {
        if let sd = startDate {
            elapsed = Date().timeIntervalSince(sd)
        }

        guard let wid = workoutID else { return }
        
        let metrics = LiveMetricsPayload(
            heartRate: heartRateBPM,
            activeEnergy: activeEnergyKcal,
            elapsed: elapsed,
            distance: distanceMeters,
            timestamp: Date()
        )
        WatchConnectivityManager.shared.publishLiveMetrics(workoutID: wid, metrics: metrics)
    }

    private func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics else { return }

        let quantityType = statistics.quantityType

        switch quantityType {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            if let q = statistics.mostRecentQuantity() {
                heartRateBPM = q.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }

        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            if let q = statistics.sumQuantity() {
                activeEnergyKcal = q.doubleValue(for: .kilocalorie())
            }
            
        case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
            if let q = statistics.sumQuantity() {
                distanceMeters = q.doubleValue(for: .meter())
            }

        default:
            break
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {

        // ✅ هذا الـ Task يحل المشكلة البنفسجية
        Task { @MainActor in
            self.sessionState = toState
            if toState == .ended || toState == .stopped {
                await self.finishWorkout(date: date)
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            WatchConnectivityManager.shared.publishError("Workout session failed: \(error.localizedDescription)")
        }
    }

    private func finishWorkout(date: Date) async {
        guard let builder else {
            teardown()
            return
        }

        do {
            try await builder.endCollection(at: date)
            _ = try await builder.finishWorkout()
        } catch {
            WatchConnectivityManager.shared.publishError("finishWorkout failed: \(error.localizedDescription)")
        }

        WatchConnectivityManager.shared.publishWorkoutState(workoutID: workoutID ?? UUID().uuidString, state: "stopped")
        teardown()
    }

    private func teardown() {
        stopTicker()

        session?.delegate = nil
        builder?.delegate = nil

        session = nil
        builder = nil

        isRunning = false
        sessionState = .notStarted

        startDate = nil
        workoutID = nil
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        
        // ✅ هذا الـ Task هو الحل الجذري للتحذير البنفسجي
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }
                let stats = workoutBuilder.statistics(for: quantityType)
                self.updateForStatistics(stats)
            }
            // بث التحديثات فوراً
            self.updateElapsedAndBroadcast()
        }
    }
}
