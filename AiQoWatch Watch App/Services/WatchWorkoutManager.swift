import Foundation
import Combine
import HealthKit
import WatchConnectivity

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

    private(set) var currentType: WatchWorkoutType?

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

        // Watch for summary view trigger
        core.$showingSummaryView
            .receive(on: RunLoop.main)
            .sink { [weak self] showing in
                guard let self else { return }
                if showing {
                    // Capture summary data before resetting
                    self.summaryCalories = Int(self.core.activeEnergy)
                    self.summaryDuration = self.core.displayElapsedTime
                    self.summaryAvgHeartRate = Int(self.core.averageHeartRate)
                    self.summaryDistance = self.core.distance / 1000.0

                    // Send workout completion to iPhone for XP processing
                    if WCSession.isSupported() {
                        let data: [String: Any] = [
                            "event": "workout_completed",
                            "calories": Double(self.summaryCalories),
                            "duration_minutes": self.summaryDuration / 60.0,
                            "workout_type": self.currentType?.rawValue ?? "other",
                            "distance_km": self.summaryDistance,
                            "timestamp": Date().timeIntervalSince1970
                        ]
                        let wcSession = WCSession.default
                        if wcSession.isReachable {
                            wcSession.sendMessage(data, replyHandler: nil, errorHandler: nil)
                        } else {
                            wcSession.transferUserInfo(data)
                        }
                    }
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
