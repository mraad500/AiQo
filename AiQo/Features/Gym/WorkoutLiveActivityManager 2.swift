import Foundation
import ActivityKit

@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()

    private var activity: Activity<WorkoutActivityAttributes>?
    private var startedAt: Date?
    private var lastPushTime: Date = .distantPast

    private init() {}

    func start(title: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if activity != nil {
            return
        }

        let workoutID = UUID().uuidString
        let startedAt = Date()
        self.startedAt = startedAt

        let attributes = WorkoutActivityAttributes(workoutID: workoutID, startedAt: startedAt)
        let initialState = WorkoutActivityAttributes.ContentState(
            title: title,
            elapsedSeconds: 0,
            heartRate: 0,
            activeCalories: 0,
            distanceMeters: 0,
            phase: .running
        )

        Task {
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: initialState, staleDate: nil),
                    pushType: nil
                )
            } catch {
                #if DEBUG
                print("[WorkoutLiveActivity] request failed: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func update(
        title: String,
        elapsedSeconds: Int,
        heartRate: Double,
        activeCalories: Double,
        distanceMeters: Double,
        phase: WorkoutActivityAttributes.WorkoutPhase,
        force: Bool = false
    ) {
        guard let activity else { return }

        if !force {
            let now = Date()
            guard now.timeIntervalSince(lastPushTime) >= 1.0 else { return }
            lastPushTime = now
        }

        let updatedState = WorkoutActivityAttributes.ContentState(
            title: title,
            elapsedSeconds: max(0, elapsedSeconds),
            heartRate: max(0, Int(heartRate.rounded())),
            activeCalories: max(0, Int(activeCalories.rounded())),
            distanceMeters: max(0, distanceMeters),
            phase: phase
        )

        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
        }
    }

    func end(
        title: String,
        elapsedSeconds: Int,
        heartRate: Double,
        activeCalories: Double,
        distanceMeters: Double
    ) {
        guard let activity else { return }

        let finalState = WorkoutActivityAttributes.ContentState(
            title: title,
            elapsedSeconds: max(0, elapsedSeconds),
            heartRate: max(0, Int(heartRate.rounded())),
            activeCalories: max(0, Int(activeCalories.rounded())),
            distanceMeters: max(0, distanceMeters),
            phase: .ending
        )

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: Date().addingTimeInterval(60)),
                dismissalPolicy: .immediate
            )
        }

        self.activity = nil
        self.startedAt = nil
        self.lastPushTime = .distantPast
    }
}

#if canImport(ActivityKit)
struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var elapsedSeconds: Int
        var heartRate: Int
        var activeCalories: Int
        var distanceMeters: Double
        var phase: WorkoutPhase
    }

    enum WorkoutPhase: String, Codable, Hashable {
        case running
        case paused
        case ending
    }

    var workoutID: String
    var startedAt: Date
}
#endif
