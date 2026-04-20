import Foundation
import UserNotifications

/// Enforces the full outbound budget: iOS 64-pending + daily cap + cooldown + quiet hours.
public actor GlobalBudget {
    public static let shared = GlobalBudget()

    private var sentToday: Int = 0
    private var sentTodayDate: Date = Calendar.current.startOfDay(for: Date())

    private let iosPendingBufferReserve = 4   // leave 4 slots free of the 64 cap

    private init() {}

    /// Top-level budget check. Produces a `BudgetDecision`.
    public func evaluate(_ intent: NotificationIntent, now: Date = Date()) async -> BudgetDecision {
        // 1. Expired intent — silent drop
        if intent.isExpired(now: now) {
            return .rejected(.expired)
        }

        // 2. Reset daily counter if midnight crossed
        rolloverIfNeeded(now: now)

        // 3. iOS 64-pending limit — reserve buffer
        let pending = await pendingNotificationCount()
        if pending >= (64 - iosPendingBufferReserve) {
            return .rejected(.pendingLimitReached)
        }

        // 4. Daily cap per tier
        let (tier, cap) = await MainActor.run { () -> (SubscriptionTier, Int) in
            let t = TierGate.shared.currentTier
            return (t, t.dailyNotificationBudget)
        }
        if sentToday >= cap {
            // Critical priority can override ONE above the cap
            if intent.priority == .critical && sentToday < cap + 1 {
                return .allowedWithOverride(reason: "critical_override_daily_cap")
            }
            return .rejected(.dailyLimitReached)
        }

        // 5. Quiet hours — defer if not critical
        let isQuiet = await QuietHoursManager.shared.isQuietNow(now: now)
        if isQuiet && intent.priority != .critical {
            return .deferredToMorning
        }

        // 6. Cooldown — both global and per-kind
        let onCooldown = await CooldownManager.shared.isOnCooldown(intent.kind, now: now)
        if onCooldown && intent.priority != .critical {
            return .rejected(.cooldown)
        }

        // 7. Tier disables specific kinds (monthlyReflection is Pro-only)
        if intent.kind == .monthlyReflection && tier != .pro && tier != .trial {
            return .rejected(.tierDisabled)
        }

        // All gates passed
        return .allowed
    }

    /// Record that a notification was delivered. Called after scheduling succeeds.
    public func recordDelivered(_ intent: NotificationIntent) async {
        rolloverIfNeeded()
        sentToday += 1
        await CooldownManager.shared.recordDelivery(intent.kind)
    }

    public func sentTodayCount() -> Int { sentToday }

    // MARK: - Private

    private func rolloverIfNeeded(now: Date = Date()) {
        let today = Calendar.current.startOfDay(for: now)
        if today > sentTodayDate {
            sentToday = 0
            sentTodayDate = today
        }
    }

    private func pendingNotificationCount() async -> Int {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.count)
            }
        }
    }

    /// Testing aid.
    #if DEBUG
    public func _resetForTesting() {
        sentToday = 0
        sentTodayDate = Calendar.current.startOfDay(for: Date())
    }
    #endif
}
