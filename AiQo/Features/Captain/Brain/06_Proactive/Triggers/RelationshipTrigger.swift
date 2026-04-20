import Foundation

/// Relationship check-in — broader than MemoryCallback; surfaces any relationship
/// mentioned within the 90-day window but not in the last 30 days.
struct RelationshipCheckInTrigger: Trigger {
    let id = "relationship_checkin"
    let kind = NotificationKind.relationshipCheckIn

    func evaluate(context: TriggerContext) async -> TriggerResult? {
        let relationships = await RelationshipStore.shared.recentlyMentioned(
            in: "",
            within: 90
        )
        let now = Date()
        let aged = relationships.filter {
            now.timeIntervalSince($0.lastMentionedAt) > 30 * 86400
        }
        guard let rel = aged.first else { return nil }

        let intent = NotificationIntent(
            kind: kind,
            priority: .medium,
            signals: IntentSignals(
                customPayload: ["relationship_name": rel.displayName]
            ),
            requestedBy: id
        )
        return TriggerResult(
            score: 0.55,
            intent: intent,
            reason: "relationship check-in: \(rel.displayName)"
        )
    }
}
