import Foundation

/// Tracks user response to notifications and updates per-kind weights over time.
/// Weights are bounded [0.3, 1.5]; they never collapse to zero.
public actor FeedbackLearner {
    public static let shared = FeedbackLearner()

    public enum Signal: Sendable {
        case opened(intentID: UUID)
        case dismissed(intentID: UUID)
        case snoozed(intentID: UUID)
        case appOpenedAfter(intentID: UUID, withinSeconds: Int)
    }

    private static let minWeight: Double = 0.3
    private static let maxWeight: Double = 1.5
    private static let defaultWeight: Double = 1.0

    private var kindWeights: [NotificationKind: Double] = [:]

    private init() {}

    public func record(_ signal: Signal, kind: NotificationKind) {
        let current = kindWeights[kind] ?? Self.defaultWeight
        var next = current
        switch signal {
        case .opened:
            next = min(Self.maxWeight, current + 0.05)
        case .dismissed:
            next = max(Self.minWeight, current - 0.05)
        case .snoozed:
            next = max(0.5, current - 0.02)
        case .appOpenedAfter(_, let seconds) where seconds < 30:
            next = min(Self.maxWeight, current + 0.08)
        case .appOpenedAfter:
            break
        }
        kindWeights[kind] = next
        diag.info("FeedbackLearner: \(kind.rawValue) weight \(current) -> \(next)")
    }

    public func weight(for kind: NotificationKind) -> Double {
        kindWeights[kind] ?? Self.defaultWeight
    }

    public func resetAll() {
        kindWeights.removeAll()
    }
}
