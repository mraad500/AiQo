import Foundation
import UserNotifications

/// THE SINGLE DOOR: every outbound user-facing notification in AiQo
/// funnels through `NotificationBrain.shared.request(intent:)`.
///
/// Responsibilities:
/// - Budget check via GlobalBudget
/// - Cooldown record via CooldownManager
/// - Privacy scrub via PrivacySanitizer
/// - Delivery via UNUserNotificationCenter
/// - Audit log via AuditLogger
public actor NotificationBrain {
    public static let shared = NotificationBrain()

    public struct DeliveryResult: Sendable {
        public let intentID: UUID
        public let decision: BudgetDecision
        public let deliveredAt: Date?
        public let systemRequestID: String?    // UN identifier
    }

    private init() {}

    /// Primary entry point. Legacy senders (BATCH 6) will call this.
    @discardableResult
    public func request(_ intent: NotificationIntent) async -> DeliveryResult {
        let now = Date()

        // Gate 1: budget check
        let decision = await GlobalBudget.shared.evaluate(intent, now: now)
        await diag.info("NotificationBrain: intent=\(intent.kind.rawValue) decision=\(String(describing: decision)) by=\(intent.requestedBy)")

        guard decision.isAllowed else {
            await AuditLogger.shared.record(
                event: .notificationRejected,
                kind: intent.kind.rawValue,
                requestedBy: intent.requestedBy
            )
            return DeliveryResult(
                intentID: intent.id,
                decision: decision,
                deliveredAt: nil,
                systemRequestID: nil
            )
        }

        // Gate 2: compose message via MessageComposer (BATCH 6)
        let composed = await MessageComposer.shared.compose(intent: intent)
        let category = categoryIdentifier(for: intent.kind)

        // Gate 3: privacy scrub (defensive — composer shouldn't emit PII, but double-check).
        // PrivacySanitizer is MainActor-isolated in this project; hop over to run.
        let (scrubbedTitle, scrubbedBody) = await MainActor.run {
            let sanitizer = PrivacySanitizer()
            return (
                sanitizer.sanitizeText(composed.title, knownUserName: nil),
                sanitizer.sanitizeText(composed.body, knownUserName: nil)
            )
        }

        // Gate 4: schedule with iOS
        let requestID = intent.id.uuidString
        let content = UNMutableNotificationContent()
        content.title = scrubbedTitle
        content.body = scrubbedBody
        content.sound = .default
        content.categoryIdentifier = category

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestID,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            await GlobalBudget.shared.recordDelivered(intent)
            await AuditLogger.shared.record(
                event: .notificationDelivered,
                kind: intent.kind.rawValue,
                requestedBy: intent.requestedBy
            )
            return DeliveryResult(
                intentID: intent.id,
                decision: decision,
                deliveredAt: Date(),
                systemRequestID: requestID
            )
        } catch {
            await diag.error("NotificationBrain: UN add failed: \(error.localizedDescription)")
            return DeliveryResult(
                intentID: intent.id,
                decision: decision,
                deliveredAt: nil,
                systemRequestID: nil
            )
        }
    }

    // MARK: - Category mapping

    private func categoryIdentifier(for kind: NotificationKind) -> String {
        switch kind {
        case .morningKickoff:          return "CAPTAIN_MORNING"
        case .inactivityNudge:         return "CAPTAIN_INACTIVITY"
        case .memoryCallback:          return "CAPTAIN_MEMORY"
        case .sleepDebtAcknowledgment: return "CAPTAIN_SLEEP"
        case .personalRecord:          return "CAPTAIN_PR"
        case .recoveryReminder:        return "CAPTAIN_RECOVERY"
        case .ramadanMindful,
             .eidCelebration,
             .jumuahSpecial:           return "CAPTAIN_CULTURAL"
        case .emotionalFollowUp,
             .moodShift:               return "CAPTAIN_EMOTIONAL"
        case .relationshipCheckIn:     return "CAPTAIN_RELATIONSHIP"
        case .streakRisk,
             .streakSave:              return "CAPTAIN_STREAK"
        case .circadianNudge:          return "CAPTAIN_CIRCADIAN"
        default:                       return "CAPTAIN_DEFAULT"
        }
    }
}

/// Minimal audit event for notification delivery.
extension AuditLogger {
    public enum NotificationAuditEvent {
        case notificationDelivered
        case notificationRejected
    }

    /// Lightweight audit record for notification events. Log-only;
    /// does not touch AuditLogger's persisted cloud-request ring.
    public nonisolated func record(
        event: NotificationAuditEvent,
        kind: String,
        requestedBy: String
    ) async {
        let verb: String
        switch event {
        case .notificationDelivered: verb = "delivered"
        case .notificationRejected:  verb = "rejected"
        }
        await diag.info("AUDIT [notification]: \(verb) kind=\(kind) by=\(requestedBy)")
    }
}
