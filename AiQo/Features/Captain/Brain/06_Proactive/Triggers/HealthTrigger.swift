import Foundation

// Health-category triggers. Each is a small Sendable struct conforming to `Trigger`.
// Registered at launch; evaluated in parallel by TriggerEvaluator.

// MARK: - SleepDebtTrigger

struct SleepDebtTrigger: Trigger {
    let id = "sleep_debt"
    let kind = NotificationKind.sleepDebtAcknowledgment

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        guard let sleep = context.bio.sleepHoursBucketed else { return nil }
        guard sleep < 5.5 else { return nil }

        let score = min((5.5 - sleep) / 5.5, 1.0)
        let intent = NotificationIntent(
            kind: kind,
            priority: .high,
            signals: IntentSignals(
                customPayload: ["sleep_hours": String(format: "%.1f", sleep)]
            ),
            requestedBy: id
        )
        return TriggerResult(score: score, intent: intent, reason: "sleep<5.5h: \(sleep)")
    }
}

// MARK: - InactivityTrigger

struct InactivityTrigger: Trigger {
    let id = "inactivity"
    let kind = NotificationKind.inactivityNudge

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        guard context.bio.timeOfDay == .midday ||
              context.bio.timeOfDay == .afternoon else { return nil }

        let steps = context.bio.stepsBucketed
        guard steps < 2000 else { return nil }

        let score = min(Double(2000 - steps) / 2000.0, 1.0)
        let intent = NotificationIntent(
            kind: kind,
            priority: .medium,
            signals: IntentSignals(
                customPayload: ["steps": "\(steps)"]
            ),
            requestedBy: id
        )
        return TriggerResult(
            score: score,
            intent: intent,
            reason: "steps<2000 at \(context.bio.timeOfDay.rawValue)"
        )
    }
}

// MARK: - PRTrigger

struct PRTrigger: Trigger {
    let id = "personal_record"
    let kind = NotificationKind.personalRecord

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        guard context.bio.stepsBucketed >= 10000 else { return nil }
        guard !context.recentDeliveryKinds.contains(.personalRecord) else { return nil }

        let intent = NotificationIntent(
            kind: kind,
            priority: .high,
            signals: IntentSignals(customPayload: ["achievement": "10k_steps"]),
            requestedBy: id
        )
        return TriggerResult(score: 0.9, intent: intent, reason: "steps >= 10000")
    }
}

// MARK: - RecoveryTrigger

struct RecoveryTrigger: Trigger {
    let id = "recovery"
    let kind = NotificationKind.recoveryReminder

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        let needsRecovery = await BioStateEngine.shared.needsRecovery()
        guard needsRecovery else { return nil }
        guard !context.recentDeliveryKinds.contains(.recoveryReminder) else { return nil }

        let intent = NotificationIntent(
            kind: kind,
            priority: .high,
            requestedBy: id
        )
        return TriggerResult(score: 0.8, intent: intent, reason: "bio indicates recovery need")
    }
}
