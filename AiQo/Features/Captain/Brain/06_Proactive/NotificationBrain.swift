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

    /// Primary entry point. Legacy senders (BATCH 6) funnel through here.
    ///
    /// Optional overrides let legacy senders preserve behavior they can't get
    /// from the template layer yet:
    /// - `fireDate`: schedule for a future time instead of firing immediately.
    /// - `precomposedTitle` / `precomposedBody`: bypass MessageComposer when the
    ///   caller has its own localized copy (e.g., trial-journey copy).
    /// - `categoryIdentifier`: override the kind-based default (e.g., the legacy
    ///   captain category).
    /// - `userInfo`: preserve legacy payload keys (source, deepLink, trialKind…)
    ///   so AppDelegate routing keeps working.
    /// - `identifier`: preserve named identifiers for dedup / cancellation.
    @discardableResult
    public func request(
        _ intent: NotificationIntent,
        fireDate: Date? = nil,
        precomposedTitle: String? = nil,
        precomposedBody: String? = nil,
        categoryIdentifier: String? = nil,
        userInfo: [String: String] = [:],
        identifier: String? = nil
    ) async -> DeliveryResult {
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

        // Gate 2: compose message. Precomposed override wins; else MessageComposer.
        let rawTitle: String
        let rawBody: String
        if let t = precomposedTitle, let b = precomposedBody {
            rawTitle = t
            rawBody = b
        } else {
            let composed = await MessageComposer.shared.compose(intent: intent)
            rawTitle = precomposedTitle ?? composed.title
            rawBody = precomposedBody ?? composed.body
        }
        let category = categoryIdentifier ?? self.categoryIdentifier(for: intent.kind)

        // Gate 3: privacy scrub (defensive — composer shouldn't emit PII, but double-check).
        // PrivacySanitizer is MainActor-isolated in this project; hop over to run.
        let (scrubbedTitle, scrubbedBody) = await MainActor.run {
            let sanitizer = PrivacySanitizer()
            return (
                sanitizer.sanitizeText(rawTitle, knownUserName: nil),
                sanitizer.sanitizeText(rawBody, knownUserName: nil)
            )
        }

        // Gate 4: schedule with iOS
        let requestID = identifier ?? intent.id.uuidString
        let content = UNMutableNotificationContent()
        content.title = scrubbedTitle
        content.body = scrubbedBody
        content.sound = .default
        content.categoryIdentifier = category
        if !userInfo.isEmpty {
            content.userInfo = userInfo
        }
        if #available(iOS 15.0, *) {
            switch intent.priority {
            case .ambient, .low: content.interruptionLevel = .passive
            case .medium, .high: content.interruptionLevel = .active
            case .critical:      content.interruptionLevel = .timeSensitive
            }
        }

        let timeInterval: TimeInterval = {
            guard let fireDate else { return 1 }
            return max(1, fireDate.timeIntervalSinceNow)
        }()
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )
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
