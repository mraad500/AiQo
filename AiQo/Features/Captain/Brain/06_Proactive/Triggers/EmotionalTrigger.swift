import Foundation

// Emotional-category triggers — follow-up on unresolved emotions, mood shifts.

// MARK: - EmotionalFollowUpTrigger

struct EmotionalFollowUpTrigger: Trigger {
    let id = "emotional_follow_up"
    let kind = NotificationKind.emotionalFollowUp

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        let unresolved = await EmotionalStore.shared.unresolvedEmotions(
            olderThan: 2,
            minIntensity: 0.6,
            limit: 1
        )
        guard let emo = unresolved.first else { return nil }

        let intent = NotificationIntent(
            kind: kind,
            priority: .medium,
            signals: IntentSignals(
                emotionSummary: "\(emo.emotion.rawValue) from \(emo.trigger)"
            ),
            requestedBy: id
        )
        return TriggerResult(score: 0.65, intent: intent, reason: "unresolved emotion")
    }
}

// MARK: - MoodShiftTrigger

struct MoodShiftTrigger: Trigger {
    let id = "mood_shift"
    let kind = NotificationKind.moodShift

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        guard context.emotion.trend == .declining else { return nil }
        guard context.emotion.intensity > 0.5 else { return nil }

        let intent = NotificationIntent(
            kind: kind,
            priority: .high,
            requestedBy: id
        )
        return TriggerResult(score: 0.7, intent: intent, reason: "declining mood detected")
    }
}
