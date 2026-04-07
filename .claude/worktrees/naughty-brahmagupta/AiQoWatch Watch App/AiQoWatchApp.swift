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

    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var healthManager = WatchHealthKitManager()
    @StateObject private var workoutManager = WatchWorkoutManager()
    @StateObject private var connectivity = WatchConnectivityService()

    @SceneBuilder var body: some Scene {
        WindowGroup {
            Group {
                if workoutManager.isActive {
                    // Workout is active (started from Watch or iPhone) — show active view
                    WatchActiveWorkoutView(
                        workoutType: workoutManager.currentType ?? .runOutdoor
                    )
                } else {
                    TabView {
                        WatchHomeView()
                        WatchWorkoutListView()
                    }
                    .tabViewStyle(.verticalPage)
                }
            }
            .environmentObject(healthManager)
            .environmentObject(workoutManager)
            .environmentObject(connectivity)
            .sheet(isPresented: $workoutManager.showingSummary) {
                WatchWorkoutSummaryView(
                    calories: workoutManager.summaryCalories,
                    duration: workoutManager.summaryDuration,
                    avgHeartRate: workoutManager.summaryAvgHeartRate,
                    distance: workoutManager.summaryDistance,
                    workoutType: workoutManager.currentType ?? .runOutdoor
                )
                .onDisappear {
                    workoutManager.dismissSummary()
                }
            }
            .onAppear {
                healthManager.requestAuthorization()
            }
        }

        WKNotificationScene(
            controller: WorkoutNotificationController.self,
            category: WorkoutNotificationCenter.categoryIdentifier
        )
    }
}

// MARK: - WKApplicationDelegate Implementation (watchOS 9+)
/// This delegate handles the workout configuration sent from iPhone via startWatchApp(with:completion:)
class AppDelegate: NSObject, WKApplicationDelegate {

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching() {
        print("⌚️ [AppDelegate] Watch app launched")
        _ = WatchConnectivityManager.shared
    }

    func applicationDidBecomeActive() {
        print("⌚️ [AppDelegate] Watch app became active")
    }

    func applicationWillResignActive() {
        print("⌚️ [AppDelegate] Watch app will resign active")
    }

    // MARK: - Handle Workout Configuration from iPhone
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        print("⌚️ [AppDelegate] Received workout configuration from iPhone!")
        print("   Activity Type: \(workoutConfiguration.activityType.rawValue)")
        print("   Location Type: \(workoutConfiguration.locationType.rawValue)")

        DispatchQueue.main.async {
            WorkoutManager.shared.startWorkout(
                workoutType: workoutConfiguration.activityType,
                locationType: workoutConfiguration.locationType
            )
        }
    }

    // MARK: - Handle User Activity

    func handleUserActivity(_ userInfo: [AnyHashable : Any]?) {
        guard let userInfo = userInfo else { return }

        print("⌚️ [AppDelegate] Handling user activity: \(userInfo)")

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
