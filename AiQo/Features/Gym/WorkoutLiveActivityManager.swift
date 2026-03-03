import Foundation
import ActivityKit

@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()

    private var activity: Activity<WorkoutActivityAttributes>?
    private var startedAt: Date?
    private var runningElapsedAnchorDate: Date?
    private var lastRenderedState: WorkoutActivityAttributes.ContentState?
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
            elapsedAnchorDate: startedAt,
            heartRate: 0,
            activeCalories: 0,
            distanceMeters: 0,
            phase: .running,
            heartRateState: zone2State,
            activeBuffs: normalizedBuffs(activeBuffs)
        )
        runningElapsedAnchorDate = startedAt
        lastRenderedState = initialState

        Task {
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: initialState, staleDate: nil),
                    pushType: nil
                )
            } catch {
                self.activity = nil
                self.startedAt = nil
                self.runningElapsedAnchorDate = nil
                self.lastRenderedState = nil
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

        let sanitizedElapsedSeconds = max(0, elapsedSeconds)
        let sanitizedDistanceMeters = max(0, (distanceMeters / 10).rounded() * 10)
        let normalizedBuffs = normalizedBuffs(activeBuffs)

        if phase == .running {
            let shouldResetAnchor =
                runningElapsedAnchorDate == nil ||
                lastRenderedState?.phase != .running ||
                force

            if shouldResetAnchor {
                runningElapsedAnchorDate = Date().addingTimeInterval(-TimeInterval(sanitizedElapsedSeconds))
            }
        } else {
            runningElapsedAnchorDate = nil
        }

        let updatedState = WorkoutActivityAttributes.ContentState(
            title: title,
            elapsedSeconds: sanitizedElapsedSeconds,
            elapsedAnchorDate: phase == .running ? runningElapsedAnchorDate : nil,
            heartRate: max(0, Int(heartRate.rounded())),
            activeCalories: max(0, Int(activeCalories.rounded())),
            distanceMeters: sanitizedDistanceMeters,
            phase: phase,
            heartRateState: zone2State,
            activeBuffs: normalizedBuffs
        )

        guard updatedState != lastRenderedState else { return }

        let now = Date()
        let lastPhase = lastRenderedState?.phase
        let minimumInterval: TimeInterval

        if force {
            minimumInterval = lastPhase != updatedState.phase ? 0 : 0.75
        } else {
            minimumInterval = 5.0
        }

        guard now.timeIntervalSince(lastPushTime) >= minimumInterval else { return }

        lastPushTime = now
        lastRenderedState = updatedState

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
            elapsedAnchorDate: nil,
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
        self.runningElapsedAnchorDate = nil
        self.lastRenderedState = nil
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
        var elapsedAnchorDate: Date?
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
