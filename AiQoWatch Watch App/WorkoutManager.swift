import Foundation
import HealthKit
import Combine
import WatchKit // ⚠️ ضروري للاهتزاز في الساعة

class WorkoutManager: NSObject, ObservableObject {
    
    static let shared = WorkoutManager()

    let healthStore = HKHealthStore()
    var session: HKWorkoutSession?
    var builder: HKLiveWorkoutBuilder?
    
    // لتتبع الكيلومترات المسجلة محلياً في الساعة
    private var lastRecordedKm: Int = 0
    
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
    
    // البيانات الحية
    @Published var averageHeartRate: Double = 0
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var elapsedSeconds: TimeInterval = 0
    
    override init() {
        super.init()
        // ✅ ربط المدير بمدير الاتصال
        WatchConnectivityManager.shared.workoutManager = self
        requestAuthorization()
    }
    
    // MARK: - Workout Lifecycle
    
    func startWorkout(workoutType: HKWorkoutActivityType, locationType: HKWorkoutSessionLocationType) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = locationType
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            session?.delegate = self
            builder?.delegate = self
            
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { (success, error) in
                if success {
                    DispatchQueue.main.async {
                        self.running = true
                        self.lastRecordedKm = 0 // تصفير العداد عند البدء
                    }
                }
            }
        } catch {
            print("Failed to start workout: \(error)")
        }
    }
    
    func startDefaultWorkout() {
        startWorkout(workoutType: .running, locationType: .indoor)
    }
    
    func togglePause() {
        if running {
            session?.pause()
        } else {
            session?.resume()
        }
    }
    
    func stopWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { (success, error) in
            if success {
                self.builder?.finishWorkout { (workout, error) in
                    DispatchQueue.main.async {
                        self.workout = workout
                        self.selectedWorkout = nil
                        self.showingSummaryView = true
                    }
                }
            }
        }
    }
    
    func resetWorkout() {
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
    }
    
    func requestAuthorization() {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { _, _ in }
    }
    
    // MARK: - Update Statistics
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
                
            case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), HKQuantityType.quantityType(forIdentifier: .distanceCycling):
                let meterUnit = HKUnit.meter()
                let totalMeters = statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0
                self.distance = totalMeters
                
                // ✅ فحص المسافة وتشغيل الاهتزاز في الساعة
                self.checkForMilestone(totalMeters: totalMeters)
                
            default:
                return
            }
        }
    }
    
    // دالة الاهتزاز الخاصة بالساعة
    private func checkForMilestone(totalMeters: Double) {
        let currentKm = Int(totalMeters / 1000)
        
        // عند قطع كيلومتر جديد (1، 2، 3...)
        if currentKm > 0 && currentKm > lastRecordedKm {
            lastRecordedKm = currentKm
            
            // تشغيل اهتزاز النجاح (Haptic Success)
            // هذا يعطي "نقرة" مميزة على اليد بدون تشغيل ملف صوتي
            WKInterfaceDevice.current().play(.success)
            print("⌚️ Watch Vibrated: \(currentKm) km")
        }
    }
    
    // إرسال البيانات
    private func sendDataToPhone() {
        let data: [String: Any] = [
            "heartRate": heartRate,
            "activeEnergy": activeEnergy,
            "distance": distance,
            "duration": builder?.elapsedTime ?? 0
        ]
        WatchConnectivityManager.shared.sendLiveData(data: data)
    }
}

// MARK: - Delegates
extension WorkoutManager: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.running = (toState == .running)
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            let statistics = workoutBuilder.statistics(for: quantityType)
            updateForStatistics(statistics)
        }
        
        sendDataToPhone()
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
