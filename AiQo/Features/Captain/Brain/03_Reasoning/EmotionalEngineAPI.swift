import Foundation

/// Thin façade that produces EmotionalReading snapshots from SentimentDetector + BioStateEngine + EmotionalStore.
/// Kept separate from the legacy `EmotionalStateEngine` so downstream (PromptComposer, NotificationBrain)
/// consumes a single unified reading.
actor EmotionalEngine {
    static let shared = EmotionalEngine()

    private let sentimentDetector: SentimentDetector
    private let bioEngine: BioStateEngine
    private let emotionalStore: EmotionalStore
    private let clock: @Sendable () -> Date

    init(
        sentimentDetector: SentimentDetector = .shared,
        bioEngine: BioStateEngine = .shared,
        emotionalStore: EmotionalStore = .shared,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.sentimentDetector = sentimentDetector
        self.bioEngine = bioEngine
        self.emotionalStore = emotionalStore
        self.clock = clock
    }

    /// Compute an EmotionalReading from current state + recent message.
    /// If `message` is nil, sentiment signal is omitted.
    func currentReading(message: String? = nil) async -> EmotionalReading {
        var signals: [EmotionalReading.Signal] = []
        var intensity: Double = 0
        var confidence: Double = 0.5
        var primary: EmotionKind = .peace

        // 1. Sentiment from message
        if let msg = message, !msg.isEmpty {
            let result = sentimentDetector.detect(message: msg)
            let score = signedScore(for: result.sentiment)
            signals.append(.sentiment(score: score))

            if score > 0.4 {
                primary = .joy
                intensity = score
            } else if score < -0.4 {
                primary = .frustration
                intensity = abs(score)
            }
            confidence = 0.6
        }

        // 2. Bio signals
        let bio = await bioEngine.current()
        if let sleep = bio.sleepHoursBucketed {
            signals.append(.sleep(hoursBucketed: sleep))
            if sleep < 5.0 {
                // Low sleep nudges toward frustration/anxiety
                intensity = max(intensity, 0.5)
                if primary == .peace { primary = .frustration }
            }
        }

        // 3. Trend over recent emotional memory
        let since = clock().addingTimeInterval(-24 * 3600)
        let recentEmotions = await emotionalStore.emotions(since: since, limit: 20)
        let trend = computeTrend(from: recentEmotions)

        return EmotionalReading(
            primary: primary,
            intensity: intensity,
            confidence: confidence,
            trend: trend,
            signals: signals,
            capturedAt: clock()
        )
    }

    // MARK: - Helpers

    private func signedScore(for sentiment: MessageSentiment) -> Double {
        switch sentiment {
        case .positive: return 0.6
        case .negative: return -0.6
        case .neutral:  return 0.0
        case .question: return 0.0
        }
    }

    private func computeTrend(from memories: [EmotionalMemorySnapshot]) -> EmotionalReading.Trend {
        guard memories.count >= 3 else { return .unknown }
        let sorted = memories.sorted { $0.date < $1.date }
        let half = max(1, sorted.count / 2)
        let first = sorted.prefix(half)
        let second = sorted.suffix(half)

        let firstPositive = first.filter { Self.isPositive($0.emotion) }.count
        let secondPositive = second.filter { Self.isPositive($0.emotion) }.count

        let delta = secondPositive - firstPositive
        if delta >= 2 { return .improving }
        if delta <= -2 { return .declining }

        // Volatility: count mood flips within window
        var flips = 0
        for i in 1..<sorted.count {
            if Self.isPositive(sorted[i].emotion) != Self.isPositive(sorted[i - 1].emotion) {
                flips += 1
            }
        }
        if flips >= max(3, sorted.count / 3) { return .volatile }
        return .stable
    }

    private static func isPositive(_ emotion: EmotionKind) -> Bool {
        switch emotion {
        case .joy, .gratitude, .pride, .peace, .hope, .love, .relief, .contentment:
            return true
        case .grief, .anxiety, .shame, .frustration, .fear, .longing, .guilt, .anger:
            return false
        }
    }
}
