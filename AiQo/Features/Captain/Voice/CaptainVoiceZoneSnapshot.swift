import Foundation

/// Payload pushed through `LiveWorkoutSession.captainVoiceZoneTransitions`
/// on every Zone 2 transition. Bundles the new zone state with the BPM
/// and zone bounds so subscribers — notably `ZoneCoachingVoiceService` —
/// can construct rich coaching events (e.g.
/// `aboveZone(currentBPM, targetMax)`) without holding a reference to
/// the per-workout `LiveWorkoutSession` instance.
struct CaptainVoiceZoneSnapshot {
    let state: WorkoutActivityAttributes.HeartRateState
    let currentBPM: Int
    let zone2LowerBPM: Int
    let zone2UpperBPM: Int
}
