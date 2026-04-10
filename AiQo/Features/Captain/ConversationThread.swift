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

    func buildPromptSummary(maxEntries: Int = 5) -> String {
        let entries = recentEntries(limit: maxEntries)
        guard !entries.isEmpty else { return "لا توجد تفاعلات سابقة" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "h:mma"

        return entries.reversed().map { entry in
            let type = localizeType(entry.entryType)
            let time = formatter.string(from: entry.timestamp)
            let truncated = String(entry.content.prefix(50))
            return "[\(type) \(time)] \(truncated)"
        }.joined(separator: "\n")
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
        try? modelContext.save()
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
