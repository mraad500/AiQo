import Foundation

/// Computes 0–1 importance from content + context signals.
/// Higher score = more worth surfacing in callbacks.
public enum SalienceScorer {

    public struct Signals: Sendable {
        public let textLength: Int
        public let hasQuestion: Bool
        public let hasProperNoun: Bool
        public let emotionalIntensity: Double
        public let bioIntensity: Double
        public let isUserExplicit: Bool
        public let isPR: Bool
        public let mentionCount: Int

        public init(
            textLength: Int = 0,
            hasQuestion: Bool = false,
            hasProperNoun: Bool = false,
            emotionalIntensity: Double = 0,
            bioIntensity: Double = 0,
            isUserExplicit: Bool = false,
            isPR: Bool = false,
            mentionCount: Int = 0
        ) {
            self.textLength = max(0, textLength)
            self.hasQuestion = hasQuestion
            self.hasProperNoun = hasProperNoun
            self.emotionalIntensity = max(0, min(1, emotionalIntensity))
            self.bioIntensity = max(0, min(1, bioIntensity))
            self.isUserExplicit = isUserExplicit
            self.isPR = isPR
            self.mentionCount = max(0, mentionCount)
        }
    }

    public static func score(_ signals: Signals) -> Double {
        var s: Double = 0

        s += min(Double(signals.textLength) / 200.0, 1.0) * 0.10
        s += signals.hasQuestion ? 0.08 : 0
        s += signals.hasProperNoun ? 0.12 : 0
        s += signals.emotionalIntensity * 0.25
        s += signals.bioIntensity * 0.10
        s += signals.isUserExplicit ? 0.25 : 0
        s += signals.isPR ? 0.20 : 0

        if signals.mentionCount > 0 {
            let mentionBoost = min(log(Double(signals.mentionCount) + 1) / log(11), 1.0)
            s += mentionBoost * 0.15
        }

        return max(0, min(1, s))
    }
}
