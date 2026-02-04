/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The paging view to switch between controls, metrics, and now playing views.
*/

import SwiftUI
import WatchKit
import HealthKit

struct SessionPagingView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    @State private var selection: Tab = .metrics

    enum Tab {
        case controls, metrics, nowPlaying
    }

    var body: some View {
        TabView(selection: $selection) {
            ControlsView().tag(Tab.controls)
            MetricsView().tag(Tab.metrics)
            NowPlayingView().tag(Tab.nowPlaying)
        }
        .navigationTitle(workoutManager.selectedWorkout.map { $0.displayName } ?? "")
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(selection == .nowPlaying)
        .onChange(of: workoutManager.running) {
            displayMetricsView()
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: isLuminanceReduced ? .never : .automatic))
        .onChange(of: isLuminanceReduced) {
            displayMetricsView()
        }
    }

    private func displayMetricsView() {
        withAnimation {
            selection = .metrics
        }
    }
}

// Provide a human-readable display name for common workout activity types.
// This keeps the UI friendly when `selectedWorkout` is an `HKWorkoutActivityType`.
extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return NSLocalizedString("Running", comment: "Workout activity")
        case .walking: return NSLocalizedString("Walking", comment: "Workout activity")
        case .cycling: return NSLocalizedString("Cycling", comment: "Workout activity")
        case .hiking: return NSLocalizedString("Hiking", comment: "Workout activity")
        case .swimming: return NSLocalizedString("Swimming", comment: "Workout activity")
        case .yoga: return NSLocalizedString("Yoga", comment: "Workout activity")
        case .functionalStrengthTraining: return NSLocalizedString("Functional Strength", comment: "Workout activity")
        case .traditionalStrengthTraining: return NSLocalizedString("Strength Training", comment: "Workout activity")
        case .coreTraining: return NSLocalizedString("Core Training", comment: "Workout activity")
        case .dance: return NSLocalizedString("Dance", comment: "Workout activity")
        case .rowing: return NSLocalizedString("Rowing", comment: "Workout activity")
        case .elliptical: return NSLocalizedString("Elliptical", comment: "Workout activity")
        case .stairClimbing: return NSLocalizedString("Stair Climbing", comment: "Workout activity")
        default: return NSLocalizedString("Workout", comment: "Default workout activity name")
        }
    }
}

struct PagingView_Previews: PreviewProvider {
    static var previews: some View {
        SessionPagingView().environmentObject(WorkoutManager())
    }
}
