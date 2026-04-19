import Foundation

/// Runs all registered triggers in parallel, picks the single winner.
///
/// Access is internal because Trigger / TriggerContext reference internal types.
actor TriggerEvaluator {
    static let shared = TriggerEvaluator()

    private var triggers: [Trigger] = []
    private let minScoreToFire: Double = 0.5

    private init() {}

    func register(_ trigger: Trigger) {
        triggers.append(trigger)
    }

    func registerAll(_ list: [Trigger]) {
        triggers.append(contentsOf: list)
    }

    func registeredCount() -> Int { triggers.count }

    /// Build a fresh `TriggerContext` and evaluate every registered trigger in parallel.
    /// Returns the highest-ranked `TriggerResult`, or nil if no trigger fires above threshold.
    func evaluateAll(recentDeliveryKinds: [NotificationKind] = []) async -> TriggerResult? {
        let bio = await BioStateEngine.shared.current()
        let cultural = CulturalContextEngine.current()
        let emotion = await EmotionalEngine.shared.currentReading()

        let context = TriggerContext(
            bio: bio,
            cultural: cultural,
            emotion: emotion,
            recentDeliveryKinds: recentDeliveryKinds
        )

        let localTriggers = triggers

        var results: [TriggerResult] = []
        await withTaskGroup(of: TriggerResult?.self) { group in
            for trigger in localTriggers {
                group.addTask {
                    await trigger.evaluate(context: context)
                }
            }
            for await result in group {
                if let r = result { results.append(r) }
            }
        }

        let scored = results.filter { $0.score >= minScoreToFire }
        guard !scored.isEmpty else { return nil }

        let sorted = scored.sorted { a, b in
            let aRank = Double(a.intent.priority.rawValue) * 0.5 + a.score * 0.5
            let bRank = Double(b.intent.priority.rawValue) * 0.5 + b.score * 0.5
            return aRank > bRank
        }

        diag.info(
            "TriggerEvaluator: \(results.count) scored, winner=\(sorted.first?.intent.kind.rawValue ?? "none")"
        )
        return sorted.first
    }
}
