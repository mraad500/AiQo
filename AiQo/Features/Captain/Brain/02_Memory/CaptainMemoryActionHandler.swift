import Foundation

/// Persisted shape of a Captain-scheduled reminder. Stored as the JSON
/// `value` of a `category == "saved"` memory row whose key is
/// `reminder_<notificationID>`, so the Saved Memories screen can render the
/// scheduled time and cancel the pending notification on delete.
struct CaptainReminderRecord: Codable, Equatable, Sendable {
    let body: String
    let fireAt: Date
    let notificationID: String
}

/// Bridges a Captain chat turn's structured `savedMemory` / `reminder`
/// payloads into real side effects:
///  - `savedMemory` → a high-confidence, user-pinned row in the "Saved
///    Memories" section (`category == "saved"`, `source == "user_explicit"`).
///  - `reminder`    → a real one-off local notification (all tiers) plus a
///    matching pinned row so the user can see and cancel it.
///
/// This is what makes the Captain stop lying: it can only *claim* it saved or
/// scheduled something when the model emitted the corresponding object, and
/// that object now produces an actual, visible effect.
@MainActor
enum CaptainMemoryActionHandler {
    static let savedCategory = "saved"
    static let reminderKeyPrefix = "reminder_"
    static let noteKeyPrefix = "saved_"

    /// Applies any actions present on a reply. Safe to call with both nil.
    static func apply(
        savedMemory: CaptainSavedMemory?,
        reminder: CaptainReminder?,
        language: AppLanguage
    ) async {
        if let savedMemory {
            persist(savedMemory: savedMemory)
        }
        if let reminder {
            await scheduleReminder(reminder, language: language)
        }
    }

    // MARK: - Saved note

    static func persist(savedMemory: CaptainSavedMemory) {
        guard MemoryStore.shared.isEnabled else { return }
        let key = noteKeyPrefix + UUID().uuidString
        MemoryStore.shared.set(
            key,
            value: savedMemory.note,
            category: savedCategory,
            source: "user_explicit",
            confidence: 1.0
        )
    }

    // MARK: - Reminder

    static func scheduleReminder(
        _ reminder: CaptainReminder,
        language: AppLanguage
    ) async {
        let result = await CaptainReminderScheduler.schedule(reminder, language: language)

        guard case .scheduled(let schedule) = result else {
            // Not authorized / invalid time / failed: the Captain's spoken
            // message is responsible for setting honest expectations. We do
            // not persist a row for a reminder that will never fire.
            return
        }

        guard MemoryStore.shared.isEnabled else { return }

        let record = CaptainReminderRecord(
            body: reminder.body,
            fireAt: schedule.fireDate,
            notificationID: schedule.identifier
        )
        guard let data = try? JSONEncoder().encode(record),
              let json = String(data: data, encoding: .utf8) else { return }

        MemoryStore.shared.set(
            reminderKeyPrefix + schedule.identifier,
            value: json,
            category: savedCategory,
            source: "user_explicit",
            confidence: 1.0
        )
    }

    // MARK: - Read helpers (used by the Saved Memories screen)

    /// Decodes a reminder row's JSON value, or nil if the row is a plain note.
    static func reminderRecord(forKey key: String, value: String) -> CaptainReminderRecord? {
        guard key.hasPrefix(reminderKeyPrefix),
              let data = value.data(using: .utf8),
              let record = try? JSONDecoder().decode(CaptainReminderRecord.self, from: data) else {
            return nil
        }
        return record
    }
}
