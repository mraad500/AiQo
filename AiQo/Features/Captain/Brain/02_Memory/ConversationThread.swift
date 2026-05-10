// ===============================================
// File: ConversationThread.swift
// Phase 2 — Captain Hamoudi Brain V2
// SwiftData model that logs ALL interactions
// between Captain Hamoudi and the user.
// ===============================================

import Foundation
import SwiftData

// MARK: - Entry Type

enum ThreadEntryType: String, Codable {
    case notification
    case userMessage
    case captainResponse
    case workoutDetected
    case goalCompleted
    case appOpened
    case notificationDismissed
    case notificationOpened
}

// MARK: - SwiftData Model

@Model
final class ConversationThreadEntry {
    var id: UUID
    var entryType: String
    var content: String
    var timestamp: Date
    var metadata: String?

    init(
        id: UUID = UUID(),
        entryType: String,
        content: String,
        timestamp: Date = Date(),
        metadata: String? = nil
    ) {
        self.id = id
        self.entryType = entryType
        self.content = content
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

// MARK: - Manager

@MainActor
final class ConversationThreadManager {

    static let shared = ConversationThreadManager()
    private var modelContext: ModelContext?

    private init() {}

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Logging Methods

    func logNotificationSent(content: String, category: String? = nil) {
        var meta: [String: String]? = nil
        if let category {
            meta = ["category": category]
        }
        insert(type: .notification, content: String(content.prefix(100)), metadata: meta)
    }

    func logNotificationOpened(content: String, actionTaken: String? = nil) {
        var meta: [String: String]? = nil
        if let actionTaken {
            meta = ["action": actionTaken]
        }
        insert(type: .notificationOpened, content: String(content.prefix(100)), metadata: meta)
    }

    func logNotificationDismissed(content: String) {
        insert(type: .notificationDismissed, content: String(content.prefix(100)), metadata: nil)
    }

    func logUserMessage(content: String) {
        insert(type: .userMessage, content: content, metadata: nil)
    }

    func logCaptainResponse(content: String) {
        insert(type: .captainResponse, content: content, metadata: nil)
    }

    func logWorkoutDetected(workoutType: String, started: Bool) {
        let meta: [String: String] = [
            "workoutType": workoutType,
            "started": started ? "true" : "false"
        ]
        insert(type: .workoutDetected, content: workoutType, metadata: meta)
    }

    func logGoalCompleted() {
        insert(type: .goalCompleted, content: "daily_ring_completed", metadata: nil)
    }

    func logAppOpened() {
        insert(type: .appOpened, content: "app_opened", metadata: nil)
    }

    // MARK: - Retrieval

    func recentEntries(limit: Int = 10) -> [ConversationThreadEntry] {
        guard let modelContext else { return [] }
        var descriptor = FetchDescriptor<ConversationThreadEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func recentNotifications(withinHours hours: Int = 24) -> [ConversationThreadEntry] {
        guard let modelContext else { return [] }
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        let notifTypes = [
            ThreadEntryType.notification.rawValue,
            ThreadEntryType.notificationOpened.rawValue,
            ThreadEntryType.notificationDismissed.rawValue
        ]
        let predicate = #Predicate<ConversationThreadEntry> { entry in
            entry.timestamp >= cutoff && notifTypes.contains(entry.entryType)
        }
        var descriptor = FetchDescriptor<ConversationThreadEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Compiles a prompt-friendly snapshot of recent thread entries.
    ///
    /// Brain Refactor §35 — Replaces the v1 50-char-truncation log with a
    /// two-section output:
    ///   1. **Structured tags** — `[workoutDetected: walking]`, `[goal ✓]`,
    ///      etc. — pulled from typed entries with full metadata. Lossless
    ///      so the prompt can reason about *what* happened, not just that
    ///      *something* happened.
    ///   2. **Recent timeline** — chronological list of the last N entries
    ///      with longer content (110 chars vs 50) so user messages aren't
    ///      cut mid-thought.
    ///
    /// The empty-state string is preserved verbatim so existing prompts
    /// don't drift.
    func buildPromptSummary(maxEntries: Int = 5) -> String {
        let entries = recentEntries(limit: maxEntries)
        guard !entries.isEmpty else { return "لا توجد تفاعلات سابقة" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "h:mma"

        // 1) Structured-tag block — surface high-value entry types as
        //    machine-readable facts. Captain reasons better when "user
        //    completed a walk" is a tag, not a chat-log line.
        var tagLines: [String] = []
        for entry in entries.reversed() {
            guard let type = ThreadEntryType(rawValue: entry.entryType) else { continue }
            switch type {
            case .workoutDetected:
                if let metadata = decodeMetadata(entry.metadata),
                   let workoutType = metadata["workoutType"] {
                    let started = metadata["started"] == "true"
                    let stateLabel = started ? "بدأ" : "خلّص"
                    tagLines.append("• \(stateLabel) تمرين \(workoutType) (\(formatter.string(from: entry.timestamp)))")
                }
            case .goalCompleted:
                tagLines.append("• ✅ كمّل الحلقة اليومية (\(formatter.string(from: entry.timestamp)))")
            case .notificationOpened:
                if let metadata = decodeMetadata(entry.metadata),
                   let action = metadata["action"] {
                    tagLines.append("• فتح إشعار وسوّى: \(action) (\(formatter.string(from: entry.timestamp)))")
                } else {
                    tagLines.append("• فتح إشعار: \(String(entry.content.prefix(60))) (\(formatter.string(from: entry.timestamp)))")
                }
            default:
                break  // covered in the timeline section below
            }
        }

        // 2) Timeline block — preserve chronological order, but with longer
        //    content so user messages survive intact.
        let timelineLines = entries.reversed().map { entry -> String in
            let type = localizeType(entry.entryType)
            let time = formatter.string(from: entry.timestamp)
            let truncated = String(entry.content.prefix(110))
            return "[\(type) \(time)] \(truncated)"
        }

        var sections: [String] = []
        if !tagLines.isEmpty {
            sections.append("--- وقائع منظمة ---\n" + tagLines.joined(separator: "\n"))
        }
        sections.append("--- تسلسل التفاعلات ---\n" + timelineLines.joined(separator: "\n"))
        return sections.joined(separator: "\n\n")
    }

    // MARK: - Cleanup

    func pruneOldEntries() {
        guard let modelContext else { return }
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let predicate = #Predicate<ConversationThreadEntry> { entry in
            entry.timestamp < cutoff
        }
        let descriptor = FetchDescriptor<ConversationThreadEntry>(predicate: predicate)
        guard let oldEntries = try? modelContext.fetch(descriptor) else { return }
        for entry in oldEntries {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    // MARK: - Private Helpers

    private func insert(type: ThreadEntryType, content: String, metadata: [String: String]?) {
        guard let modelContext else { return }
        let metadataJSON: String?
        if let metadata,
           let data = try? JSONSerialization.data(withJSONObject: metadata),
           let json = String(data: data, encoding: .utf8) {
            metadataJSON = json
        } else {
            metadataJSON = nil
        }

        let entry = ConversationThreadEntry(
            entryType: type.rawValue,
            content: content,
            metadata: metadataJSON
        )
        modelContext.insert(entry)
        // Defer the disk save so the caller (often mid-send) is not blocked by fsync.
        Task { @MainActor in
            try? modelContext.save()
        }
    }

    /// Decodes the JSON-stringified metadata back into a flat string map.
    /// Returns `nil` when the entry has no metadata (the common case for
    /// plain user/captain messages).
    private func decodeMetadata(_ raw: String?) -> [String: String]? {
        guard let raw,
              let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return parsed
    }

    private func localizeType(_ rawType: String) -> String {
        guard let type = ThreadEntryType(rawValue: rawType) else { return rawType }
        switch type {
        case .notification:           return "إشعار"
        case .userMessage:            return "رسالة"
        case .captainResponse:        return "رد"
        case .notificationOpened:     return "إشعار ✓"
        case .notificationDismissed:  return "إشعار ✗"
        case .workoutDetected:        return "تمرين"
        case .goalCompleted:          return "هدف ✓"
        case .appOpened:              return "فتح التطبيق"
        }
    }
}
