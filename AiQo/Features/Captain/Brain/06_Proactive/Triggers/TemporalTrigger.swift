import Foundation

// Temporal / circadian triggers — time-of-day anchored nudges.

// MARK: - MorningKickoffTrigger

struct MorningKickoffTrigger: Trigger {
    let id = "morning_kickoff"
    let kind = NotificationKind.morningKickoff

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        guard context.bio.timeOfDay == .morning else { return nil }
        guard !context.recentDeliveryKinds.contains(.morningKickoff) else { return nil }

        let intent = NotificationIntent(
            kind: kind,
            priority: .medium,
            requestedBy: id
        )
        return TriggerResult(score: 0.7, intent: intent, reason: "morning start")
    }
}

// MARK: - CircadianNudgeTrigger

struct CircadianNudgeTrigger: Trigger {
    let id = "circadian_nudge"
    let kind = NotificationKind.circadianNudge

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        guard context.bio.timeOfDay == .night ||
              context.bio.timeOfDay == .lateNight else { return nil }
        guard let sleep = context.bio.sleepHoursBucketed, sleep < 6.5 else { return nil }

        let intent = NotificationIntent(
            kind: kind,
            priority: .low,
            requestedBy: id
        )
        return TriggerResult(
            score: 0.5,
            intent: intent,
            reason: "evening, sleep debt building"
        )
    }
}
