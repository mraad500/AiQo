import SwiftUI

@MainActor
struct WorkoutSessionSheetView: View {
    @ObservedObject private var session: LiveWorkoutSession
    @StateObject private var viewModel: WorkoutSessionViewModel

    init(
        session: LiveWorkoutSession,
        watchConnectivityService: WatchConnectivityService? = nil
    ) {
        let resolvedWatchConnectivityService = watchConnectivityService ?? WatchConnectivityService()

        _session = ObservedObject(wrappedValue: session)
        _viewModel = StateObject(
            wrappedValue: WorkoutSessionViewModel(
                session: session,
                watchConnectivityService: resolvedWatchConnectivityService
            )
        )
    }

    var body: some View {
        WorkoutSessionScreen(
            session: session,
            viewModel: viewModel
        )
    }
}
