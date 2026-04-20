import Foundation

/// A trigger evaluates context and nominates a notification intent.
/// Returns nil if this trigger has nothing to fire.
///
/// Access is internal because TriggerContext exposes internal types
/// (BioSnapshot, CulturalContextEngine.State, EmotionalReading).
protocol Trigger: Sendable {
    nonisolated var id: String { get }
    nonisolated var kind: NotificationKind { get }

    /// Evaluate this trigger against the shared context.
    /// - Returns: a `TriggerResult` with score ≥ 0 and a nominated intent, or nil
    ///   if this trigger should stay silent right now.
    func evaluate(context: TriggerContext) async -> TriggerResult?
}

/// Shared snapshot of observable state passed to every trigger on each cycle.
struct TriggerContext: Sendable {
    let bio: BioSnapshot
    let capturedAt: Date
    let cultural: CulturalContextEngine.State
    let emotion: EmotionalReading
    let pendingIntents: [UUID]
    let recentDeliveryKinds: [NotificationKind]

    nonisolated init(
        bio: BioSnapshot,
        capturedAt: Date = Date(),
        cultural: CulturalContextEngine.State,
        emotion: EmotionalReading,
        pendingIntents: [UUID] = [],
        recentDeliveryKinds: [NotificationKind] = []
    ) {
        self.bio = bio
        self.capturedAt = capturedAt
        self.cultural = cultural
        self.emotion = emotion
        self.pendingIntents = pendingIntents
        self.recentDeliveryKinds = recentDeliveryKinds
    }
}

/// A trigger's nomination. Score is 0–1; evaluator picks the winner by
/// priority × score.
struct TriggerResult: Sendable {
    let score: Double
    let intent: NotificationIntent
    let reason: String
}
