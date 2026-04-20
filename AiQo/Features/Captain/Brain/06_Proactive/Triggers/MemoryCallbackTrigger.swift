import Foundation

/// The magic trigger. References a past fact when context aligns.
///
/// Example: user told Captain "my mom is sick" 3 weeks ago. Today, a quiet
/// evening with no other notifications — Captain reaches out with a callback.
///
/// Hard guards:
/// - Never fires during distressing emotional state
/// - Never fires when other notifications are competing
struct MemoryCallbackTrigger: Trigger {
    let id = "memory_callback"
    let kind = NotificationKind.memoryCallback

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        guard !context.emotion.primary.isDistressing else { return nil }
        guard context.recentDeliveryKinds.count < 2 else { return nil }

        let bundle = await MemoryRetriever.shared.retrieve(
            query: "relationships",
            bioContext: context.bio,
            customLimit: 10
        )

        let now = Date()
        let candidate = bundle.relationships.first { rel in
            let daysSince = now.timeIntervalSince(rel.lastMentionedAt) / 86400
            return daysSince > 14 && rel.emotionalWeight > 0.5
        }
        guard let rel = candidate else { return nil }

        let daysSince = Int(now.timeIntervalSince(rel.lastMentionedAt) / 86400)
        let intent = NotificationIntent(
            kind: kind,
            priority: .high,
            signals: IntentSignals(
                customPayload: [
                    "relationship_name": rel.displayName,
                    "days_since_mention": "\(daysSince)"
                ]
            ),
            requestedBy: id
        )
        return TriggerResult(
            score: 0.75,
            intent: intent,
            reason: "memory callback: \(rel.displayName)"
        )
    }
}

fileprivate extension EmotionKind {
    /// Distressing emotions block memory callbacks — we never dredge up the past
    /// when the user is already hurting.
    var isDistressing: Bool {
        switch self {
        case .grief, .frustration, .shame, .anger, .fear, .anxiety, .guilt:
            return true
        default:
            return false
        }
    }
}
