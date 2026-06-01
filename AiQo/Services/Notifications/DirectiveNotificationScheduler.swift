import Foundation
import UserNotifications

/// Schedules REPEATING daily local notifications for user-taught time-based
/// standing directives (`.everyMorning` / `.beforeBedtime` with the `.notify`
/// action). This is the offline execution arm of the directive layer's
/// "remember + execute, never forget" promise for non-workout triggers:
/// `UNCalendarNotificationTrigger(repeats: true)` means iOS re-fires every day
/// even if the app is never opened and there is no network — exactly the
/// reliability a "every morning, do X" standing order demands.
///
/// Like `CaptainReminderScheduler`, this deliberately bypasses the
/// `NotificationBrain` budget / cooldown / quiet-hours and the
/// `.captainNotifications` tier gate. Rationale (product decision,
/// 2026-05-18): a standing order the user explicitly taught is a basic
/// utility they asked for, not a proactive AI nudge. The directive *feature*
/// itself stays `.captainDirectives`-gated at learn time (see
/// `DirectiveCoordinator`); only the delivery channel is un-budgeted.
///
/// Fire time is derived from the user's own personalization (wake time for
/// morning, 30 min before bedtime for evening) so the notification lands when
/// it is actually meaningful, with sensible fallbacks when unset.
@MainActor
enum DirectiveNotificationScheduler {

    /// Identifier namespace, keyed by directive id so a relaunch reconcile is
    /// idempotent and independent of the brain-managed notification space.
    static let identifierPrefix = "aiqo.captain.directive."

    /// Pure, testable resolution of the daily fire clock for a time-based
    /// trigger. Returns `nil` for triggers that are not time-scheduled here.
    static func fireClock(
        trigger: DirectiveTrigger,
        wakeTime: Date?,
        bedtime: Date?,
        calendar: Calendar = .current
    ) -> (hour: Int, minute: Int)? {
        switch trigger {
        case .everyMorning:
            if let wakeTime {
                let c = calendar.dateComponents([.hour, .minute], from: wakeTime)
                if let h = c.hour, let m = c.minute { return (h, m) }
            }
            return (8, 0)
        case .beforeBedtime:
            if let bedtime,
               let pre = calendar.date(byAdding: .minute, value: -30, to: bedtime) {
                let c = calendar.dateComponents([.hour, .minute], from: pre)
                if let h = c.hour, let m = c.minute { return (h, m) }
            }
            return (21, 30)
        case .afterWorkout, .afterPoorSleep, .weeklyReview:
            return nil
        }
    }

    /// Cancels every pending directive notification, then re-adds one repeating
    /// request per enabled, time-based, `.notify` directive. Reconciling from
    /// the `DirectiveStore` source of truth (rather than diffing) keeps the
    /// promise intact across relaunch, reinstall, enable/disable and delete.
    ///
    /// - Parameter requestAuthorization: `true` for the learn path (the user
    ///   just deliberately taught a directive — appropriate to prompt); `false`
    ///   for the cold-launch reconcile (never prompt unexpectedly on startup).
    static func reschedule(
        directives: [LearnedDirectiveSnapshot],
        personalization: CaptainPersonalizationSnapshot?,
        requestAuthorization: Bool
    ) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        if !ours.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }

        let timeBased = directives.filter { directive -> Bool in
            guard directive.isEnabled, directive.action == .notify else { return false }
            return directive.trigger == .everyMorning || directive.trigger == .beforeBedtime
        }
        guard !timeBased.isEmpty else { return }

        let authorized: Bool
        if requestAuthorization {
            authorized = await NotificationService.shared.ensureAuthorizationIfNeeded()
        } else {
            authorized = await center.notificationSettings().authorizationStatus == .authorized
        }
        guard authorized else { return }

        for directive in timeBased {
            guard
                let body = directive.params["text"]?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !body.isEmpty,
                let clock = fireClock(
                    trigger: directive.trigger,
                    wakeTime: personalization?.wakeTime,
                    bedtime: personalization?.bedtime
                )
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = directive.localeCode == "en" ? "Captain Hamoudi" : "الكابتن حمّودي"
            content.body = body
            content.sound = .default
            content.userInfo = [
                "notification_type": "captain_directive",
                "source": "captain_hamoudi",
                "deepLink": "aiqo://captain"
            ]

            var components = DateComponents()
            components.hour = clock.hour
            components.minute = clock.minute
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: identifierPrefix + directive.id.uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Cancels a single directive's repeating notification (for a future
    /// directive-management surface; the launch reconcile also self-heals).
    static func cancel(directiveID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [identifierPrefix + directiveID.uuidString]
            )
    }
}
