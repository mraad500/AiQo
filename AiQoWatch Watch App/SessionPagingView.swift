/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The paging view to switch between controls, metrics, and now playing views.
*/

import SwiftUI
import HealthKit
#if canImport(WatchKit)
import WatchKit
#endif

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
#if os(watchOS)
            NowPlayingView().tag(Tab.nowPlaying)
#else
            Color.clear.tag(Tab.nowPlaying)
#endif
        }
        .navigationTitle(workoutManager.displayWorkoutTitle)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(selection == .nowPlaying)
        .onChange(of: workoutManager.running) { _, _ in
            displayMetricsView()
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: isLuminanceReduced ? .never : .automatic))
        .onChange(of: isLuminanceReduced) { _, _ in
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
        let locale = Locale.autoupdatingCurrent
        switch self {
        case .running: return WatchText.localized(ar: "ركض", en: "Running", locale: locale)
        case .walking: return WatchText.localized(ar: "مشي", en: "Walking", locale: locale)
        case .cycling: return WatchText.localized(ar: "دراجة", en: "Cycling", locale: locale)
        case .hiking: return WatchText.localized(ar: "هايكنغ", en: "Hiking", locale: locale)
        case .swimming: return WatchText.localized(ar: "سباحة", en: "Swimming", locale: locale)
        case .yoga: return WatchText.localized(ar: "يوغا", en: "Yoga", locale: locale)
        case .functionalStrengthTraining: return WatchText.localized(ar: "قوة وظيفية", en: "Functional Strength", locale: locale)
        case .traditionalStrengthTraining: return WatchText.localized(ar: "تمارين القوة", en: "Strength Training", locale: locale)
        case .coreTraining: return WatchText.localized(ar: "تمارين الوسط", en: "Core Training", locale: locale)
        case .dance: return WatchText.localized(ar: "رقص", en: "Dance", locale: locale)
        case .rowing: return WatchText.localized(ar: "تجديف", en: "Rowing", locale: locale)
        case .elliptical: return WatchText.localized(ar: "إليبتيكال", en: "Elliptical", locale: locale)
        case .stairClimbing: return WatchText.localized(ar: "صعود الدرج", en: "Stair Climbing", locale: locale)
        default: return WatchText.localized(ar: "تمرين", en: "Workout", locale: locale)
        }
    }
}

struct PagingView_Previews: PreviewProvider {
    static var previews: some View {
        SessionPagingView().environmentObject(WorkoutManager())
    }
}
