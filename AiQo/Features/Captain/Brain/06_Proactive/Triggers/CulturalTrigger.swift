import Foundation

/// Cultural-aware trigger. Respects precedence: Eid > Ramadan > Jumu'ah.
struct CulturalTrigger: Trigger {
    let id = "cultural"
    let kind = NotificationKind.ramadanMindful

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        switch context.cultural.isEid {
        case .eidFitr, .eidAdha:
            let intent = NotificationIntent(
                kind: .eidCelebration,
                priority: .high,
                requestedBy: id
            )
            return TriggerResult(score: 0.9, intent: intent, reason: "Eid")
        case .none:
            break
        }

        if context.cultural.isRamadan && context.cultural.isFastingHour {
            let intent = NotificationIntent(
                kind: .ramadanMindful,
                priority: .low,
                requestedBy: id
            )
            return TriggerResult(
                score: 0.4,
                intent: intent,
                reason: "Ramadan fasting hour"
            )
        }

        if context.cultural.isJumuah && context.bio.timeOfDay == .midday {
            let intent = NotificationIntent(
                kind: .jumuahSpecial,
                priority: .low,
                requestedBy: id
            )
            return TriggerResult(score: 0.45, intent: intent, reason: "Jumu'ah midday")
        }

        return nil
    }
}
