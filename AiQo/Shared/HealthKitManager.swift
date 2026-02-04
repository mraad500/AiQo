import Foundation
import HealthKit
internal import Combine // ✅ (1) هذا كان ناقص

final class HealthKitManager {

    // Singleton
    static let shared = HealthKitManager()
    
    private let service = HealthKitService.shared
    private let store = HKHealthStore()

    // متغيرات للمراقبة الحية
    @Published var todaySteps: Int = 0
    @Published var todayCalories: Double = 0
    @Published var todayDistanceKm: Double = 0
    
    private init() {}

    // MARK: - 1. البداية (Start)
    
    func startBackgroundObserver() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
            if let error = error { print("❌ [AiQo HK] Bg Delivery Error: \(error)") }
            else { print("✅ [AiQo HK] Background Delivery Enabled") }
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
    
    // ✅ (2) رجعنا هاي الدالة عشان تصلح الخطأ بملف ProfileViewController
    func fetchSteps() {
        Task {
            await processNewHealthData()
        }
    }

    // MARK: - 2. المعالجة (The Brain Loop) 🔄
    
    private func processNewHealthData() async {
        let summary = await try? service.fetchTodaySummary()
        guard let data = summary else { return }
        
        await MainActor.run {
            self.todaySteps = Int(data.steps)
            self.todayCalories = data.activeKcal
            self.todayDistanceKm = data.distanceMeters / 1000.0
        }
        
        print("📊 [AiQo HK] Updated: \(Int(data.steps)) steps")

        calculateAndAwardCoins(currentSteps: Int(data.steps))
        
        ActivityNotificationEngine.shared.evaluateAndSendIfNeeded(
            steps: Int(data.steps),
            calories: data.activeKcal,
            stepsGoal: 10000,
            caloriesGoal: 500,
            gender: .male,
            language: .arabic
        )
    }
    
    // MARK: - 3. منطق التعدين (Mining Logic) ⛏️
    
    private func calculateAndAwardCoins(currentSteps: Int) {
        let defaults = UserDefaults.standard
        let savedStepsKey = "lastProcessedStepsForMining"
        let lastDateKey = "lastMiningDate"
        
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = defaults.object(forKey: lastDateKey) as? Date ?? Date.distantPast
        
        var previousSteps = defaults.integer(forKey: savedStepsKey)
        
        if !Calendar.current.isDate(today, inSameDayAs: lastDate) {
            previousSteps = 0
            defaults.set(today, forKey: lastDateKey)
            defaults.set(0, forKey: savedStepsKey)
        }
        
        let deltaSteps = currentSteps - previousSteps
        
        if deltaSteps > 0 {
             // ضيف منطق اضافة العملات هنا
            if deltaSteps >= 100 { // مثال
                 print("💰 Earned coins logic here")
            }
            defaults.set(currentSteps, forKey: savedStepsKey)
        } else {
             if currentSteps != previousSteps {
                 defaults.set(currentSteps, forKey: savedStepsKey)
             }
        }
    }
}
