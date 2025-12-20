import SwiftUI

@main
struct AiQoWatchApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .environmentObject(workoutManager)
            .onAppear {
                // 1. تفعيل الاتصال
                let wcManager = WatchConnectivityManager.shared
                wcManager.workoutDelegate = workoutManager
                wcManager.activate()
                
                // 2. طلب إذن HealthKit (مهم جداً!) ✅
                workoutManager.requestAuthorization()
            }
        }
    }
}
