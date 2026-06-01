import Foundation
import UserNotifications

struct CaptainReminderSchedule: Equatable, Sendable {
    let identifier: String
    let fireDate: Date
}

enum CaptainReminderSchedulingResult: Sendable {
    case scheduled(CaptainReminderSchedule)
    case notAuthorized
    case invalidTime
    case failed
}

/// Schedules ONE-OFF, user-requested local notifications coming straight out
/// of a Captain chat turn ("ذكّرني الساعة 8 أشرب ماي").
///
/// This deliberately bypasses `NotificationBrain` (budget / cooldown / quiet
/// hours) and the `.captainNotifications` tier gate. Rationale (product
/// decision, 2026-05-18): a reminder the user explicitly asked for in the
/// moment is a basic utility, available to ALL tiers including free — it is
/// not a proactive "smart" nudge. Proactive/AI-initiated notifications stay
/// gated and budgeted where they already are.
@MainActor
enum CaptainReminderScheduler {
    /// Identifier namespace so pending requests can be listed/cancelled
    /// independently of the brain-managed notification space.
    static let identifierPrefix = "aiqo.captain.userreminder."

    static func schedule(
        _ reminder: CaptainReminder,
        language: AppLanguage
    ) async -> CaptainReminderSchedulingResult {
        guard let fireDate = resolveFireDate(for: reminder) else {
            return .invalidTime
        }

        let authorized = await NotificationService.shared.ensureAuthorizationIfNeeded()
        guard authorized else { return .notAuthorized }

        let content = UNMutableNotificationContent()
        content.title = language == .english ? "Captain Hamoudi" : "الكابتن حمّودي"
        content.body = reminder.body
        content.sound = .default
        content.userInfo = [
            "notification_type": "captain_user_reminder",
            "source": "captain_hamoudi",
            "deepLink": "aiqo://captain"
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = identifierPrefix + UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return .scheduled(
                CaptainReminderSchedule(identifier: identifier, fireDate: fireDate)
            )
        } catch {
            return .failed
        }
    }

    /// Cancels a previously scheduled reminder (used when the user deletes the
    /// row from the Saved Memories screen).
    static func cancel(identifier: String) {
        guard identifier.hasPrefix(identifierPrefix) else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Resolves the next future fire date for a reminder.
    ///
    /// - Uses `reminder.date` (local `yyyy-MM-dd`) when provided and still in
    ///   the future.
    /// - Otherwise schedules the next occurrence of `time`: today when it is
    ///   more than 60s away, else the same time tomorrow.
    static func resolveFireDate(
        for reminder: CaptainReminder,
        now: Date = Date()
    ) -> Date? {
        guard let clock = reminder.clock else { return nil }
        let calendar = Calendar.current

        if let dateString = reminder.date {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            if let day = formatter.date(from: dateString),
               let candidate = calendar.date(
                   bySettingHour: clock.hour,
                   minute: clock.minute,
                   second: 0,
                   of: day
               ),
               candidate > now.addingTimeInterval(30) {
                return candidate
            }
        }

        if let todayCandidate = calendar.date(
            bySettingHour: clock.hour,
            minute: clock.minute,
            second: 0,
            of: now
        ), todayCandidate > now.addingTimeInterval(60) {
            return todayCandidate
        }

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
            return nil
        }
        return calendar.date(
            bySettingHour: clock.hour,
            minute: clock.minute,
            second: 0,
            of: tomorrow
        )
    }
}
