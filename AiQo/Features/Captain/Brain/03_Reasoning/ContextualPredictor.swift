import Foundation

/// Predicts the likely next user need based on bio + time-of-day + recent patterns.
/// Informs notification triggers.
actor ContextualPredictor {
    static let shared = ContextualPredictor()

    private let contextSensor: ContextSensor

    init(contextSensor: ContextSensor = .shared) {
        self.contextSensor = contextSensor
    }

    struct Prediction: Sendable {
        let likelyNeed: LikelyNeed
        let confidence: Double

        enum LikelyNeed: String, Sendable {
            case hydration
            case movement
            case recovery
            case nutrition
            case sleepPrep
            case motivation
            case celebration
            case none
        }
    }

    func predict() async -> Prediction {
        let context = await contextSensor.capture()
        let bio = context.bio
        let tod = context.timeOfDay

        // Recovery need trumps everything
        if context.needsRecovery {
            return Prediction(likelyNeed: .recovery, confidence: 0.85)
        }

        switch tod {
        case .dawn, .morning:
            // Morning + low recent steps → movement nudge likely
            if bio.stepsBucketed < 1000 {
                return Prediction(likelyNeed: .movement, confidence: 0.7)
            }
            return Prediction(likelyNeed: .motivation, confidence: 0.5)

        case .midday:
            return Prediction(likelyNeed: .hydration, confidence: 0.5)

        case .afternoon:
            // Afternoon slump → movement
            if bio.stepsBucketed < 4000 {
                return Prediction(likelyNeed: .movement, confidence: 0.6)
            }
            return Prediction(likelyNeed: .nutrition, confidence: 0.4)

        case .evening:
            // Evening with high steps → celebration
            if bio.stepsBucketed > 8000 {
                return Prediction(likelyNeed: .celebration, confidence: 0.7)
            }
            return Prediction(likelyNeed: .nutrition, confidence: 0.4)

        case .night, .lateNight:
            return Prediction(likelyNeed: .sleepPrep, confidence: 0.7)
        }
    }
}
