import Foundation

/// Read-only snapshot of the user's current emotional state.
/// Produced by EmotionalEngine; consumed by PromptComposer + NotificationBrain.
struct EmotionalReading: Sendable, Codable {
    let primary: EmotionKind
    let intensity: Double        // 0-1
    let confidence: Double       // 0-1
    let trend: Trend             // over the last 24h
    let signals: [Signal]        // what contributed
    let capturedAt: Date

    enum Trend: String, Sendable, Codable {
        case improving
        case declining
        case stable
        case volatile
        case unknown
    }

    enum Signal: Sendable, Codable {
        case sentiment(score: Double)
        case hrv(direction: String)     // "up", "down", "flat"
        case sleep(hoursBucketed: Double)
        case disengagement(daysSinceLastOpen: Int)
        case workoutIntensity(vsBaseline: Double)
    }

    nonisolated init(
        primary: EmotionKind = .peace,
        intensity: Double = 0,
        confidence: Double = 0,
        trend: Trend = .unknown,
        signals: [Signal] = [],
        capturedAt: Date = Date()
    ) {
        self.primary = primary
        self.intensity = max(0, min(1, intensity))
        self.confidence = max(0, min(1, confidence))
        self.trend = trend
        self.signals = signals
        self.capturedAt = capturedAt
    }
}
