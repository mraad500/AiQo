import Foundation

// Behavioral-category triggers — streak defense, engagement momentum, disengagement.

// MARK: - StreakRiskTrigger

struct StreakRiskTrigger: Trigger {
    let id = "streak_risk"
    let kind = NotificationKind.streakRisk

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        guard context.bio.timeOfDay == .evening ||
              context.bio.timeOfDay == .night else { return nil }
        guard context.bio.stepsBucketed < 3000 else { return nil }

        let intent = NotificationIntent(
            kind: kind,
            priority: .medium,
            requestedBy: id
        )
        return TriggerResult(score: 0.7, intent: intent, reason: "evening with low steps")
    }
}

// MARK: - DisengagementTrigger

struct DisengagementTrigger: Trigger {
    let id = "disengagement"
    let kind = NotificationKind.disengagement

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        // Needs BehavioralObserver signals (dismiss streaks, days-since-open).
        // Wired properly in BATCH 8.
        return nil
    }
}

// MARK: - EngagementMomentumTrigger

struct EngagementMomentumTrigger: Trigger {
    let id = "engagement_momentum"
    let kind = NotificationKind.engagementMomentum

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        guard let sleep = context.bio.sleepHoursBucketed, sleep >= 7.0 else { return nil }
        guard context.bio.stepsBucketed > 7000 else { return nil }
        guard context.emotion.primary == .joy ||
              context.emotion.primary == .gratitude else { return nil }

        let intent = NotificationIntent(
            kind: kind,
            priority: .medium,
            requestedBy: id
        )
        return TriggerResult(score: 0.6, intent: intent, reason: "user on a hot streak")
    }
}
