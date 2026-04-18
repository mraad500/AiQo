import Foundation

/// Mines `EmotionalMemory` entries from recent episodic data.
/// Runs on a tier-gated cadence: Pro = daily, Max = weekly, free = never.
actor EmotionalMiner {
    static let shared = EmotionalMiner()

    private init() {}

    /// Mine emotional content from episodes since `since`.
    /// Persists new `EmotionalMemory` entries to the store.
    /// Returns the count of new entries created.
    @discardableResult
    func mine(since: Date) async -> Int {
        let tier = TierGate.shared.currentTier
        let cadence = TierGate.shared.emotionalMiningCadence
        guard cadence != .never else {
            diag.info("EmotionalMiner: cadence=never (tier=\(tier)) — skipping")
            return 0
        }

        diag.info("EmotionalMiner: starting (tier=\(tier), cadence=\(cadence))")

        let episodes = await EpisodicStore.shared.entries(from: since, to: Date())
        guard !episodes.isEmpty else {
            diag.info("EmotionalMiner: no episodes since \(since)")
            return 0
        }

        var createdCount = 0

        for episode in episodes {
            let text = episode.userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let result = SentimentDetector.shared.detect(message: text)
            let score = signedScore(for: result)
            let intensity = abs(score)

            guard intensity >= 0.4 else { continue }

            let emotion = emotion(forScore: score)
            let trigger = String(text.prefix(60))
            let context = episode.timestamp.formatted(date: .abbreviated, time: .shortened)

            let createdID = await EmotionalStore.shared.record(
                trigger: trigger,
                emotion: emotion,
                intensity: intensity,
                contextSnapshot: context,
                associatedFactIDs: [],
                bioContext: episode.bioContext
            )
            if createdID != nil {
                createdCount += 1
            }
        }

        diag.info("EmotionalMiner: created \(createdCount) emotional entries from \(episodes.count) episodes")
        return createdCount
    }

    // MARK: - Helpers

    /// Map SentimentDetector result to a signed score in [-1, 1].
    private func signedScore(for result: SentimentResult) -> Double {
        switch result.sentiment {
        case .positive: return result.confidence
        case .negative: return -result.confidence
        case .neutral, .question: return 0
        }
    }

    private func emotion(forScore score: Double) -> EmotionKind {
        if score >= 0.6 {
            return .joy
        } else if score >= 0.3 {
            return .gratitude
        } else if score <= -0.6 {
            return .grief
        } else if score <= -0.3 {
            return .frustration
        } else {
            return .peace
        }
    }
}
