import Foundation
import HealthKit
internal import Combine

class WorkoutManager: NSObject, ObservableObject {
    @Published var selectedWorkout: HKWorkoutActivityType?
    @Published var sessionLocation: HKWorkoutSessionLocationType = .unknown
    @Published var showingSummaryView: Bool = false {
        didSet {
            if showingSummaryView == false {
                resetWorkout()
            }
        }
    }
    
    // Live Data
    @Published var averageHeartRate: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var workout: HKWorkout?
    
    // ✅ التعديل هنا: جعلناه @Published ليتم قراءته من الـ View لتشغيل العداد
    @Published var startDate: Date?
    
    // Internal State
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    // معرّف الجلسة للمزامنة
    private var currentWorkoutID: String = UUID().uuidString
    
    func requestAuthorization() {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.activitySummaryType()
        ]
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in }
    }
    
    // Start Workout
    func startWorkout(workoutType: HKWorkoutActivityType, location: HKWorkoutSessionLocationType = .unknown) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = location
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            return
        }
        
        session?.delegate = self
        builder?.delegate = self
        builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
        
        let now = Date()
        session?.startActivity(with: now)
        builder?.beginCollection(withStart: now) { (success, error) in
            DispatchQueue.main.async {
                self.selectedWorkout = workoutType
                self.sessionLocation = location
                // إعادة تعيين المعرف عند كل بداية جديدة
                self.currentWorkoutID = UUID().uuidString
            }
        }
    }
    
    // End Workout
    func endWorkout() {
        session?.end()
    }
    
    // دالة إرسال البيانات للآيفون
    private func sendLiveMetrics() {
        guard let start = startDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        
        let payload = LiveMetricsPayload(
            heartRate: self.heartRate,
            activeEnergy: self.activeEnergy,
            distance: self.distance,
            elapsed: elapsed,
            timestamp: Date().timeIntervalSince1970
        )
        
        WatchConnectivityManager.shared.publishLiveMetrics(workoutID: currentWorkoutID, metrics: payload)
    }
    
    func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }
        
        DispatchQueue.main.async {
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                self.averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                
            case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                let energyUnit = HKUnit.kilocalorie()
                self.activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
                
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
                let meterUnit = HKUnit.meter()
                self.distance = statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0
                
            default:
                return
            }
            
            self.sendLiveMetrics()
        }
    }
    
    func resetWorkout() {
        selectedWorkout = nil
        sessionLocation = .unknown
        builder = nil
        workout = nil
        session = nil
        activeEnergy = 0
        averageHeartRate = 0
        heartRate = 0
        distance = 0
        startDate = nil
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
        DispatchQueue.main.async {
            if toState == .running {
                self.startDate = date
                WatchConnectivityManager.shared.publishWorkoutState(workoutID: self.currentWorkoutID, state: "started")
            }
            
            if toState == .ended {
                self.builder?.endCollection(withEnd: date) { (success, error) in
                    self.builder?.finishWorkout { (workout, error) in
                        DispatchQueue.main.async {
                            self.workout = workout
                            self.showingSummaryView = true
                            WatchConnectivityManager.shared.publishWorkoutState(workoutID: self.currentWorkoutID, state: "ended")
                        }
                    }
                }
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { return }
            let statistics = workoutBuilder.statistics(for: quantityType)
            updateForStatistics(statistics)
        }
    }
}
