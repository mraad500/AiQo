import Foundation
import ActivityKit

@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()

    private var activity: Activity<WorkoutActivityAttributes>?
    private var startedAt: Date?
    private var lastPushTime: Date = .distantPast

    private init() {}

    func start(
        title: String,
        zone2State: WorkoutActivityAttributes.HeartRateState = .neutral,
        activeBuffs: [WorkoutActivityAttributes.Buff] = []
    ) {
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
            phase: .running,
            heartRateState: zone2State,
            activeBuffs: normalizedBuffs(activeBuffs)
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
        zone2State: WorkoutActivityAttributes.HeartRateState = .neutral,
        activeBuffs: [WorkoutActivityAttributes.Buff] = [],
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
            phase: phase,
            heartRateState: zone2State,
            activeBuffs: normalizedBuffs(activeBuffs)
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
        distanceMeters: Double,
        zone2State: WorkoutActivityAttributes.HeartRateState = .neutral,
        activeBuffs: [WorkoutActivityAttributes.Buff] = []
    ) {
        guard let activity else { return }

        let finalState = WorkoutActivityAttributes.ContentState(
            title: title,
            elapsedSeconds: max(0, elapsedSeconds),
            heartRate: max(0, Int(heartRate.rounded())),
            activeCalories: max(0, Int(activeCalories.rounded())),
            distanceMeters: max(0, distanceMeters),
            phase: .ending,
            heartRateState: zone2State,
            activeBuffs: normalizedBuffs(activeBuffs)
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

    private func normalizedBuffs(_ buffs: [WorkoutActivityAttributes.Buff]) -> [WorkoutActivityAttributes.Buff] {
        var seen = Set<String>()
        var normalized: [WorkoutActivityAttributes.Buff] = []

        for buff in buffs where seen.insert(buff.id).inserted {
            normalized.append(buff)
            if normalized.count == 3 {
                break
            }
        }

        return normalized
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
        var heartRateState: HeartRateState
        var activeBuffs: [Buff]

        var isZone2Active: Bool {
            heartRateState == .zone2
        }
    }

    enum WorkoutPhase: String, Codable, Hashable {
        case running
        case paused
        case ending
    }

    enum HeartRateState: String, Codable, Hashable {
        case neutral
        case warmingUp
        case zone2
        case belowZone2
        case aboveZone2
    }

    struct Buff: Codable, Hashable, Identifiable {
        var id: String
        var label: String
        var systemImage: String
        var tone: BuffTone

        init(id: String, label: String, systemImage: String, tone: BuffTone) {
            self.id = id
            self.label = label
            self.systemImage = systemImage
            self.tone = tone
        }
    }

    enum BuffTone: String, Codable, Hashable {
        case mint
        case amber
        case sky
        case rose
        case lavender
    }

    var workoutID: String
    var startedAt: Date
}
#endif
