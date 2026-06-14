import Foundation
import Combine
import HealthKit

/// Thin bridge over `WorkoutManager.shared` that exposes the same API
/// used by the new AiQo Watch views while preserving the full iPhone ↔ Watch
/// sync infrastructure (mirroring, snapshots, WatchConnectivity, sequence numbers).
@MainActor
class WatchWorkoutManager: NSObject, ObservableObject {
    private let core = WorkoutManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published properties (forwarded from core)
    @Published var isActive = false
    @Published var isPaused = false
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var activeCalories: Double = 0
    @Published var heartRate: Double = 0
    @Published var distance: Double = 0
    @Published var showingSummary = false

    /// The active workout's type. Set directly when the workout is started from
    /// the watch (exact, preserves indoor/outdoor); otherwise derived from the
    /// core engine when the iPhone launches the workout. Published so the root
    /// view re-renders with the correct type once it resolves.
    @Published private(set) var currentType: WatchWorkoutType?

    var formattedTime: String {
        let m = Int(elapsedSeconds) / 60
        let s = Int(elapsedSeconds) % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Summary data captured when workout ends
    private(set) var summaryCalories: Int = 0
    private(set) var summaryDuration: TimeInterval = 0
    private(set) var summaryAvgHeartRate: Int = 0
    private(set) var summaryDistance: Double = 0

    override init() {
        super.init()
        bindToCore()
    }

    // MARK: - Bind to WorkoutManager.shared

    private func bindToCore() {
        // Forward `running` → `isActive` + `isPaused`
        core.$running
            .receive(on: RunLoop.main)
            .sink { [weak self] running in
                guard let self else { return }
                // Active means we have a session that hasn't ended
                self.isActive = self.core.hasActiveSession
                self.isPaused = self.core.workoutPhase == .paused
            }
            .store(in: &cancellables)

        core.$workoutPhase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                guard let self else { return }
                self.isActive = self.core.hasActiveSession
                self.isPaused = phase == .paused
            }
            .store(in: &cancellables)

        // Forward live metrics
        core.$heartRate
            .receive(on: RunLoop.main)
            .assign(to: &$heartRate)

        core.$activeEnergy
            .receive(on: RunLoop.main)
            .assign(to: &$activeCalories)

        // Distance from core is in meters; convert to km
        core.$distance
            .receive(on: RunLoop.main)
            .map { $0 / 1000.0 }
            .assign(to: &$distance)

        core.$elapsedSeconds
            .receive(on: RunLoop.main)
            .assign(to: &$elapsedSeconds)

        // Keep `currentType` in sync with the engine. This matters when the
        // iPhone launches the workout — the companion only hands the core an
        // HKWorkoutActivityType + location, so we recover the watch-facing type
        // from the authoritative pair. Deriving from (activity, exact location)
        // round-trips losslessly, so it also reaffirms a watch-initiated type
        // without clobbering its indoor/outdoor choice. The nil that
        // `resetWorkout` publishes is ignored so the type survives into the
        // summary and the completion message.
        core.$selectedWorkout
            .receive(on: RunLoop.main)
            .sink { [weak self] activity in
                guard let self, let activity else { return }
                self.currentType = WatchWorkoutType(
                    hkType: activity,
                    locationType: self.core.currentLocationType
                )
            }
            .store(in: &cancellables)

        // Watch for summary view trigger
        core.$showingSummaryView
            .receive(on: RunLoop.main)
            .sink { [weak self] showing in
                guard let self else { return }
                if showing {
                    // Capture the authoritative end-of-workout values (the core
                    // froze these before finishing the builder).
                    self.summaryCalories = Int(self.core.activeEnergy)
                    self.summaryDuration = self.core.elapsedSeconds
                    self.summaryAvgHeartRate = Int(self.core.averageHeartRate)
                    self.summaryDistance = self.core.distance / 1000.0

                    // Report completion to the iPhone for XP. Keyed by the active
                    // session id so the phone awards XP exactly once even when the
                    // message arrives over both WatchConnectivity transports.
                    WatchConnectivityManager.shared.sendWorkoutCompleted(
                        workoutId: self.core.activeSessionID ?? UUID().uuidString,
                        calories: self.summaryCalories,
                        durationMinutes: self.summaryDuration / 60.0,
                        workoutType: self.currentType?.rawValue ?? "other",
                        distanceKm: self.summaryDistance
                    )
                }
                self.showingSummary = showing
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions (delegated to core)

    func startWorkout(type: WatchWorkoutType) {
        currentType = type
        core.startWorkout(
            workoutType: type.hkType,
            locationType: type.locationType
        )
    }

    func pauseWorkout() {
        core.pause()
    }

    func resumeWorkout() {
        core.resume()
    }

    func endWorkout() {
        core.endWorkout()
    }

    func reset() {
        currentType = nil
        core.resetWorkout()
    }

    /// Dismiss the summary view (triggers core reset)
    func dismissSummary() {
        core.showingSummaryView = false
    }
}
