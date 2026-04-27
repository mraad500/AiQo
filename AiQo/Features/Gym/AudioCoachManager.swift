import Foundation

@MainActor
final class AudioCoachManager {
    struct Zone2Target: Equatable {
        let lowerBoundBPM: Int
        let upperBoundBPM: Int

        nonisolated static let captainHamoudiDefault = Zone2Target(lowerBoundBPM: 118, upperBoundBPM: 137)
    }

    private enum Zone2State: Equatable {
        case unknown
        case belowRange
        case inRange
        case aboveRange
    }

    static let warmUpDurationSeconds = 360
    static let feedbackCooldown: TimeInterval = 120

    private var currentWorkout: GymWorkoutKind = .standard
    private var zone2Target: Zone2Target = .captainHamoudiDefault
    private var lastZone2CueAt: Date?
    private var lastZone2State: Zone2State = .unknown

    func reset(
        for currentWorkout: GymWorkoutKind,
        zone2Target: Zone2Target = .captainHamoudiDefault
    ) {
        self.currentWorkout = currentWorkout
        self.zone2Target = zone2Target
        lastZone2CueAt = nil
        lastZone2State = .unknown
    }

    func handleDynamicZone2Coaching(
        heartRate: Double,
        distanceMeters: Double,
        isRunning: Bool
    ) {
        guard currentWorkout == .cardioWithCaptainHamoudi else { return }
        guard isRunning else { return }
        guard heartRate > 0 else { return }

        let bpm = Int(heartRate.rounded())
        let now = Date()
        let distanceKM = max(0, distanceMeters) / 1000.0
        let zoneBounds = zone2Target.lowerBoundBPM...zone2Target.upperBoundBPM
        let nextZone2State = resolvedZone2State(for: bpm)
        let didTransition = nextZone2State != lastZone2State

        if lastZone2State == .unknown, nextZone2State == .inRange {
            lastZone2State = nextZone2State
            return
        }

        if !didTransition,
           nextZone2State != .inRange,
           let lastZone2CueAt,
           now.timeIntervalSince(lastZone2CueAt) < Self.feedbackCooldown {
            return
        }

        if nextZone2State == .inRange, lastZone2State == .inRange {
            return
        }

        lastZone2State = nextZone2State
        lastZone2CueAt = now

        Task { @MainActor in
            let prompt = await CaptainVoiceService.shared.makeWorkoutPromptText(
                liveHR: bpm,
                zoneBounds: zoneBounds,
                distance: distanceKM
            )
            await CaptainVoiceRouter.shared.speak(text: prompt, tier: .premium)
        }
    }

    private func resolvedZone2State(for bpm: Int) -> Zone2State {
        if bpm < zone2Target.lowerBoundBPM {
            return .belowRange
        }

        if bpm > zone2Target.upperBoundBPM {
            return .aboveRange
        }

        return .inRange
    }

    func stop() {
        CaptainVoiceRouter.shared.stop()
    }
}
