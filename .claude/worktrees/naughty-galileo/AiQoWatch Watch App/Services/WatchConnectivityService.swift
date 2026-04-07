import Foundation
import Combine
import WatchConnectivity

/// Thin wrapper that exposes phone reachability from the existing
/// `WatchConnectivityManager.shared` for the new SwiftUI views.
/// All actual connectivity work is handled by `WatchConnectivityManager`.
@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    @Published var isPhoneReachable = false

    private var timer: Timer?

    override init() {
        super.init()
        _ = WatchConnectivityManager.shared
        refreshReachability()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.refreshReachability()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func refreshReachability() {
        guard WCSession.isSupported() else { return }
        isPhoneReachable = WCSession.default.isReachable
    }

    /// Send workout result to iPhone for XP processing.
    func sendWorkoutCompleted(calories: Double, durationMinutes: Double, workoutType: String, distance: Double) {
        guard WCSession.isSupported() else { return }

        let data: [String: Any] = [
            "event": "workout_completed",
            "calories": calories,
            "duration_minutes": durationMinutes,
            "workout_type": workoutType,
            "distance_km": distance,
            "timestamp": Date().timeIntervalSince1970
        ]

        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(data, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(data)
        }
    }
}
