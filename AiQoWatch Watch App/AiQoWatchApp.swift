import SwiftUI

@main
struct AiQoWatchApp: App {

    @StateObject private var workoutManager = WorkoutManager.shared
    @StateObject private var connectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .environmentObject(connectivity)
                .onAppear {
                    connectivity.activate()
                    workoutManager.requestAuthorization()
                }
        }
    }
}
