import Foundation

/// Aggregates bio + behavioral + temporal signals into a single struct for downstream
/// consumers (retriever, orchestrator, triggers).
struct CapturedContext: Sendable {
    let bio: BioSnapshot
    let timeOfDay: BioSnapshot.TimeOfDay
    let dayOfWeek: Int
    let recentEventCount: Int
    let needsRecovery: Bool
    let capturedAt: Date
}

/// Reads from `BioStateEngine` + `BehavioralObserver` to produce a `CapturedContext`.
/// Pure read-only; never mutates the sources.
actor ContextSensor {
    static let shared = ContextSensor()

    private let bioEngine: BioStateEngine
    private let behavioralObserver: BehavioralObserver
    private let clock: @Sendable () -> Date

    init(
        bioEngine: BioStateEngine = .shared,
        behavioralObserver: BehavioralObserver = .shared,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.bioEngine = bioEngine
        self.behavioralObserver = behavioralObserver
        self.clock = clock
    }

    func capture() async -> CapturedContext {
        let bio = await bioEngine.current()
        let needsRecovery = await bioEngine.needsRecovery()
        let eventCount = await behavioralObserver.bufferedEventCount()

        return CapturedContext(
            bio: bio,
            timeOfDay: bio.timeOfDay,
            dayOfWeek: bio.dayOfWeek,
            recentEventCount: eventCount,
            needsRecovery: needsRecovery,
            capturedAt: clock()
        )
    }
}
