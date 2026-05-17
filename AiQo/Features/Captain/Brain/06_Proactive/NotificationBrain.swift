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

    /// Defensive hard cap on TOP of GlobalBudget. Prevents the 15-trigger proactive
    /// cascade from spamming a user in their first session (v1.0.4 enables Memory V4
    /// globally — all triggers register at once).
    /// Tightening these is fine; loosening should be a deliberate decision.
    /// Conservative free-tier (`.none`) floor. Paid tiers get more headroom via
    /// `hardCapLimits()`; the trial lane bypasses the cap entirely.
    public static let hardCapInterval: TimeInterval = 4 * 3600   // 4 hours between deliveries
    public static let hardCapDailyLimit = 3                       // 3 deliveries per calendar day

    private enum HardCapKeys {
        static let lastDelivered = "aiqo.notif.brain.hardcap.lastDelivered"
        static let dailyCount = "aiqo.notif.brain.hardcap.dailyCount"
        static let dailyCountDate = "aiqo.notif.brain.hardcap.dailyCountDate"
    }

    private var hasSubscribed = false
    private var observerTokens: [NSObjectProtocol] = []

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

        // The 7-day trial runs in its own lane: TrialJourneyOrchestrator already
        // governs cadence (per-day caps 1/2/3 + 90-min cooldown), so the generic
        // anti-spam stack would only suppress the very moments that make a trial
        // user fall in love with the app. Trial intents skip the hard cap and the
        // GlobalBudget daily-cap/cooldown (they still respect quiet hours, the
        // iOS 64-pending limit, PersonaGuard, and privacy scrubbing).
        let isTrialLane = intent.kind == .trialDay

        // Gate 0 (v1.0.4): hard cap, tier-scaled. Defensive layer on top of
        // GlobalBudget. Skipped entirely for the trial lane.
        if !isTrialLane, let cappedReason = hardCapRejection(now: now) {
            await AuditLogger.shared.record(
                event: .notificationRejected,
                kind: intent.kind.rawValue,
                requestedBy: intent.requestedBy
            )
            diag.info("NotificationBrain hardCap skip kind=\(intent.kind.rawValue) reason=\(cappedReason.rawValue)")
            return DeliveryResult(
                intentID: intent.id,
                decision: .rejected(cappedReason),
                deliveredAt: nil,
                systemRequestID: nil
            )
        }

        // Gate 1: budget check
        let decision = await GlobalBudget.shared.evaluate(intent, now: now)
        diag.info("NotificationBrain: intent=\(intent.kind.rawValue) decision=\(String(describing: decision)) by=\(intent.requestedBy)")

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
            let cultural = CulturalContextEngine.current(now: now)
            let emotion = emotionalReading(for: intent)
            let userDialect = intent.signals.customPayload["dialect"] ?? "iraqi"
            let language = intent.signals.customPayload["language"] ?? "ar"
            let dialect = DialectLibrary.Dialect(rawValue: userDialect) ?? .iraqi
            let persona = await PersonaAdapter.shared.richDirective(
                emotion: emotion,
                cultural: cultural,
                userDialect: userDialect
            )
            let composed = await MessageComposer.shared.composeRich(
                intent: intent,
                persona: persona,
                dialect: dialect,
                language: language
            )
            rawTitle = precomposedTitle ?? composed.title
            rawBody = precomposedBody ?? composed.body
        }
        let category = categoryIdentifier ?? self.categoryIdentifier(for: intent.kind)

        let guardResult = PersonaGuard.validate(
            title: rawTitle,
            body: rawBody,
            kind: intent.kind
        )
        if !guardResult.passed {
            diag.error(
                "NotificationBrain: PersonaGuard BLOCKED \(intent.kind.rawValue): \(guardResult.violations.joined(separator: ","))"
            )
            return DeliveryResult(
                intentID: intent.id,
                decision: .rejected(.tierDisabled),
                deliveredAt: nil,
                systemRequestID: nil
            )
        }

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
            if !isTrialLane {
                recordHardCapDelivery(now: Date())
            }
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
            diag.error("NotificationBrain: UN add failed: \(error.localizedDescription)")
            return DeliveryResult(
                intentID: intent.id,
                decision: decision,
                deliveredAt: nil,
                systemRequestID: nil
            )
        }
    }

    // MARK: - v1.0.4: Subscriptions for XP / Streak events

    /// Wired from `AppDelegate.didFinishLaunchingWithOptions` when
    /// `NOTIFICATION_BRAIN_ENABLED` is true. Idempotent: safe to call twice.
    public func subscribe() {
        guard !hasSubscribed else { return }
        hasSubscribed = true

        let center = NotificationCenter.default

        let xpToken = center.addObserver(
            forName: .aiqoXPGranted, object: nil, queue: nil
        ) { note in
            let payload = note.userInfo
            Task { await NotificationBrain.shared.handleXPGranted(payload: payload) }
        }
        let streakToken = center.addObserver(
            forName: .aiqoStreakIncremented, object: nil, queue: nil
        ) { note in
            let payload = note.userInfo
            Task { await NotificationBrain.shared.handleStreakIncremented(payload: payload) }
        }
        let riskToken = center.addObserver(
            forName: .aiqoStreakRisk, object: nil, queue: nil
        ) { note in
            let payload = note.userInfo
            Task { await NotificationBrain.shared.handleStreakRisk(payload: payload) }
        }

        observerTokens = [xpToken, streakToken, riskToken]
        diag.info("NotificationBrain: subscribed to XP + streak NotificationCenter events")
    }

    private func handleXPGranted(payload: [AnyHashable: Any]?) async {
        // Only notify on a level-up; raw XP grants alone would be too noisy.
        guard let didLevelUp = payload?["didLevelUp"] as? Bool, didLevelUp else { return }
        let amount = payload?["amount"] as? Int ?? 0
        let level = payload?["level"] as? Int ?? 0

        let intent = NotificationIntent(
            kind: .achievementUnlocked,
            priority: .high,
            signals: IntentSignals(customPayload: [
                "xpAmount": "\(amount)",
                "newLevel": "\(level)"
            ]),
            requestedBy: "NotificationBrain.XPLevelUp"
        )
        _ = await request(intent)
    }

    private func handleStreakIncremented(payload: [AnyHashable: Any]?) async {
        // Milestone-only — we don't ping on every single day.
        let streak = payload?["streak"] as? Int ?? 0
        let milestones: Set<Int> = [3, 7, 14, 30, 60, 90, 180, 365]
        guard milestones.contains(streak) else { return }

        let intent = NotificationIntent(
            kind: .streakSave,
            priority: .medium,
            signals: IntentSignals(customPayload: ["streak": "\(streak)"]),
            requestedBy: "NotificationBrain.StreakMilestone"
        )
        _ = await request(intent)
    }

    private func handleStreakRisk(payload: [AnyHashable: Any]?) async {
        let streak = payload?["streak"] as? Int ?? 0
        guard streak > 0 else { return }

        let intent = NotificationIntent(
            kind: .streakRisk,
            priority: .high,
            signals: IntentSignals(customPayload: ["streak": "\(streak)"]),
            requestedBy: "NotificationBrain.StreakRisk"
        )
        _ = await request(intent)
    }

    // MARK: - Hard cap helpers

    /// Tier-scaled hard cap. The free-tier (`.none`) floor stays conservative;
    /// paid tiers get more headroom so a Pro user isn't silenced after 3 pings.
    /// Trial never reaches here (bypassed in `request`).
    private func hardCapLimits() -> (interval: TimeInterval, dailyLimit: Int) {
        switch TierGate.shared.currentTier.effectiveAccessTier {
        case .pro:  return (2 * 3600, 6)
        case .max:  return (3 * 3600, 5)
        default:    return (Self.hardCapInterval, Self.hardCapDailyLimit)
        }
    }

    private func hardCapRejection(now: Date) -> BudgetDecision.Reason? {
        let defaults = UserDefaults.standard
        let limits = hardCapLimits()
        if let last = defaults.object(forKey: HardCapKeys.lastDelivered) as? Date,
           now.timeIntervalSince(last) < limits.interval {
            return .cooldown
        }
        if let countDate = defaults.object(forKey: HardCapKeys.dailyCountDate) as? Date,
           Calendar.current.isDate(countDate, inSameDayAs: now) {
            let count = defaults.integer(forKey: HardCapKeys.dailyCount)
            if count >= limits.dailyLimit {
                return .dailyLimitReached
            }
        }
        return nil
    }

    private func recordHardCapDelivery(now: Date) {
        let defaults = UserDefaults.standard
        let nextCount: Int
        if let countDate = defaults.object(forKey: HardCapKeys.dailyCountDate) as? Date,
           Calendar.current.isDate(countDate, inSameDayAs: now) {
            nextCount = defaults.integer(forKey: HardCapKeys.dailyCount) + 1
        } else {
            nextCount = 1
        }
        defaults.set(now, forKey: HardCapKeys.lastDelivered)
        defaults.set(nextCount, forKey: HardCapKeys.dailyCount)
        defaults.set(now, forKey: HardCapKeys.dailyCountDate)
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
        case .hydrationReminder:       return "CAPTAIN_HYDRATION"
        default:                       return "CAPTAIN_DEFAULT"
        }
    }

    private func emotionalReading(for intent: NotificationIntent) -> EmotionalReading {
        if let summary = intent.signals.emotionSummary?.lowercased(),
           let primary = EmotionKind.allCases.first(where: { summary.contains($0.rawValue) }) {
            let trend = trend(from: summary)
            let intensity: Double
            if summary.contains("high") {
                intensity = 0.8
            } else if summary.contains("moderate") {
                intensity = 0.5
            } else {
                intensity = 0.3
            }
            return EmotionalReading(
                primary: primary,
                intensity: intensity,
                confidence: 0.6,
                trend: trend
            )
        }

        switch intent.kind {
        case .personalRecord, .achievementUnlocked, .eidCelebration:
            return EmotionalReading(primary: .joy, intensity: 0.8, confidence: 0.8, trend: .improving)
        case .emotionalFollowUp, .moodShift, .disengagement, .streakRisk:
            return EmotionalReading(primary: .frustration, intensity: 0.6, confidence: 0.7, trend: .declining)
        case .relationshipCheckIn, .memoryCallback:
            return EmotionalReading(primary: .love, intensity: 0.4, confidence: 0.6, trend: .stable)
        case .weeklyInsight, .monthlyReflection, .jumuahSpecial, .ramadanMindful:
            return EmotionalReading(primary: .peace, intensity: 0.3, confidence: 0.7, trend: .stable)
        case .sleepDebtAcknowledgment, .recoveryReminder, .circadianNudge:
            return EmotionalReading(primary: .peace, intensity: 0.2, confidence: 0.7, trend: .stable)
        default:
            return EmotionalReading()
        }
    }

    private func trend(from summary: String) -> EmotionalReading.Trend {
        if summary.contains("declining") { return .declining }
        if summary.contains("improving") { return .improving }
        if summary.contains("stable") { return .stable }
        if summary.contains("volatile") { return .volatile }
        return .unknown
    }
}

/// Event names consumed by `NotificationBrain.subscribe()`.
/// `nonisolated` so the actor-isolated `subscribe()` can reference them without
/// a Sendable warning under Swift 6 strict concurrency.
public extension Notification.Name {
    /// Posted by `LevelStore.addXP(_:)` whenever XP is granted. UserInfo:
    /// `amount: Int`, `totalXP: Int`, `level: Int`, `didLevelUp: Bool`.
    nonisolated static let aiqoXPGranted = Notification.Name("aiqo.xp.granted")
    /// Posted by `StreakManager.markTodayAsActive()` on streak increment.
    /// UserInfo: `streak: Int`, `longest: Int`.
    nonisolated static let aiqoStreakIncremented = Notification.Name("aiqo.streak.incremented")
    /// Posted by `StreakManager.checkStreakContinuity()` when 22h+ have elapsed
    /// since the user's last active day and they haven't completed today yet.
    /// UserInfo: `streak: Int`.
    nonisolated static let aiqoStreakRisk = Notification.Name("aiqo.streak.risk")
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
        diag.info("AUDIT [notification]: \(verb) kind=\(kind) by=\(requestedBy)")
    }
}
