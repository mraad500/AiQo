import Foundation

/// Unified crisis detection that combines immediate text intent, recent
/// emotional-memory patterns, and severe bio-state signals.
actor CrisisDetector {
    static let shared = CrisisDetector()

    struct Signal: Sendable, Equatable {
        let severity: Severity
        let source: Source
        let context: String
        let detectedAt: Date

        enum Severity: Int, Sendable, Comparable {
            case noConcern = 0
            case watchful = 1
            case concerning = 2
            case acute = 3

            static func < (lhs: Severity, rhs: Severity) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

        enum Source: String, Sendable {
            case text
            case emotionalPattern
            case bioSignal
        }
    }

    private enum Constants {
        static let emotionalWindow: TimeInterval = 24 * 60 * 60
        static let emotionalThreshold = 3
        static let highIntensityThreshold = 0.6
        static let sleepEmergencyThreshold = 3.0
    }

    private let emotionalStore: EmotionalStore
    private let bioStateEngine: BioStateEngine
    private let nowProvider: @Sendable () -> Date

    init(
        emotionalStore: EmotionalStore = .shared,
        bioStateEngine: BioStateEngine = .shared,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.emotionalStore = emotionalStore
        self.bioStateEngine = bioStateEngine
        self.nowProvider = nowProvider
    }

    func evaluate(message: String) async -> Signal {
        let detectedAt = nowProvider()

        if let textSignal = signalFromText(message, detectedAt: detectedAt) {
            return textSignal
        }

        if let emotionalSignal = await signalFromEmotionalPattern(detectedAt: detectedAt) {
            return emotionalSignal
        }

        if let bioSignal = await signalFromBioState(detectedAt: detectedAt) {
            return bioSignal
        }

        return Signal(
            severity: .noConcern,
            source: .text,
            context: "no crisis indicators",
            detectedAt: detectedAt
        )
    }

    private func signalFromText(_ message: String, detectedAt: Date) -> Signal? {
        let reading = IntentClassifier.classify(message)
        guard reading.primary == .crisis else { return nil }

        return Signal(
            severity: .acute,
            source: .text,
            context: "crisis language detected in message",
            detectedAt: detectedAt
        )
    }

    private func signalFromEmotionalPattern(detectedAt: Date) async -> Signal? {
        let recentEmotions = await emotionalStore.emotions(
            since: detectedAt.addingTimeInterval(-Constants.emotionalWindow),
            limit: 50
        )
        let highNegatives = recentEmotions.filter { memory in
            isNegative(memory.emotion) && memory.intensity >= Constants.highIntensityThreshold
        }

        guard highNegatives.count >= Constants.emotionalThreshold else { return nil }

        return Signal(
            severity: .concerning,
            source: .emotionalPattern,
            context: "\(highNegatives.count) high-intensity negative emotions in 24h",
            detectedAt: detectedAt
        )
    }

    private func signalFromBioState(detectedAt: Date) async -> Signal? {
        let bio = await bioStateEngine.current()
        guard let sleep = bio.sleepHoursBucketed,
              sleep < Constants.sleepEmergencyThreshold else {
            return nil
        }

        return Signal(
            severity: .watchful,
            source: .bioSignal,
            context: "extreme sleep deprivation: \(sleep)h",
            detectedAt: detectedAt
        )
    }

    private func isNegative(_ emotion: EmotionKind) -> Bool {
        switch emotion {
        case .grief, .frustration, .shame, .anxiety, .fear, .guilt, .anger:
            return true
        default:
            return false
        }
    }
}
