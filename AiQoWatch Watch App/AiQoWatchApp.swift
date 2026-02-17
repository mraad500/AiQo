// ===============================================
// File: AiQoWatchApp.swift
// Target: WatchOS 9+
// ===============================================

import SwiftUI
import HealthKit
#if canImport(WatchKit)
import WatchKit
#endif

#if !canImport(WatchKit)
protocol WKApplicationDelegate: NSObjectProtocol {}

@propertyWrapper
struct WKApplicationDelegateAdaptor<DelegateType: NSObject>: DynamicProperty {
    let wrappedValue: DelegateType
    init(_ type: DelegateType.Type) {
        wrappedValue = type.init()
    }
}

enum WKHapticType {
    case success
    case click
}

final class WKInterfaceDevice {
    static func current() -> WKInterfaceDevice { WKInterfaceDevice() }
    func play(_ type: WKHapticType) {}
}

struct WKNotificationScene<ControllerType: NSObject>: Scene {
    init(controller: ControllerType.Type, category: String) {}

    var body: some Scene {
        WindowGroup {
            EmptyView()
        }
    }
}
#endif

// MARK: - Main App Entry Point
@main
struct AiQoWatchApp: App {
    
    // ✅ FIXED: Use WKApplicationDelegateAdaptor instead of WKExtensionDelegateAdaptor for watchOS 9+
    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Keep WorkoutManager alive for the app's lifetime
    @StateObject private var workoutManager = WorkoutManager.shared
    
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                // Show different views based on workout state
                if workoutManager.running || workoutManager.selectedWorkout != nil {
                    // Workout is active - show the session controls
                    SessionPagingView()
                        .environmentObject(workoutManager)
                } else {
                    // No active workout - show the start menu
                    StartView()
                        .environmentObject(workoutManager)
                }
            }
            // Summary sheet after workout ends
            .sheet(isPresented: $workoutManager.showingSummaryView) {
                SummaryView()
                    .environmentObject(workoutManager)
            }
            .onAppear {
                workoutManager.requestAuthorization()
                WorkoutNotificationCenter.configure()
            }
        }

        WKNotificationScene(
            controller: WorkoutNotificationController.self,
            category: WorkoutNotificationCenter.categoryIdentifier
        )
    }
}

// MARK: - ✅ WKApplicationDelegate Implementation (watchOS 9+)
/// This delegate handles the workout configuration sent from iPhone via startWatchApp(with:completion:)
class AppDelegate: NSObject, WKApplicationDelegate {
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching() {
        print("⌚️ [AppDelegate] Watch app launched")
        
        // Ensure connectivity manager is initialized
        _ = WatchConnectivityManager.shared
    }
    
    func applicationDidBecomeActive() {
        print("⌚️ [AppDelegate] Watch app became active")
    }
    
    func applicationWillResignActive() {
        print("⌚️ [AppDelegate] Watch app will resign active")
    }
    
    // MARK: - ✅ Handle Workout Configuration from iPhone
    /// This is the KEY method that receives the workout configuration from HKHealthStore.startWatchApp
    /// Called when the iPhone uses HKHealthStore.startWatchApp(with:completion:)
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("⌚️ [AppDelegate] Received workout configuration from iPhone!")
        print("   Activity Type: \(workoutConfiguration.activityType.rawValue)")
        print("   Location Type: \(workoutConfiguration.locationType.rawValue)")
        
        // Start the workout immediately using WorkoutManager
        // This is done on the main thread to ensure UI updates properly
        DispatchQueue.main.async {
            WorkoutManager.shared.startWorkout(
                workoutType: workoutConfiguration.activityType,
                locationType: workoutConfiguration.locationType
            )
        }
    }
    
    // MARK: - Handle User Activity (For Complications, etc.)
    
    func handleUserActivity(_ userInfo: [AnyHashable : Any]?) {
        guard let userInfo = userInfo else { return }
        
        print("⌚️ [AppDelegate] Handling user activity: \(userInfo)")
        
        // Check if this is a workout-related activity
        if let activityTypeRaw = userInfo["activityType"] as? UInt,
           let activityType = HKWorkoutActivityType(rawValue: activityTypeRaw) {
            
            let locationTypeRaw = userInfo["locationType"] as? Int ?? 1
            let locationType = HKWorkoutSessionLocationType(rawValue: locationTypeRaw) ?? .indoor
            
            DispatchQueue.main.async {
                WorkoutManager.shared.startWorkout(
                    workoutType: activityType,
                    locationType: locationType
                )
            }
        }
    }
}
