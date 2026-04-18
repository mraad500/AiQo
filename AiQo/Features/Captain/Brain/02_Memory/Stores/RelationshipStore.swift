import Foundation
import SwiftData

nonisolated struct RelationshipSnapshot: Identifiable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let kind: RelationshipKind
    let kindRaw: String
    let sentiment: Double
    let emotionalWeight: Double
    let lastMentionedAt: Date
    let mentionedEntryIDs: [UUID]
    let contextTags: [String]

    init(relationship: Relationship) {
        id = relationship.id
        name = relationship.name
        displayName = relationship.displayName
        kind = relationship.kind
        kindRaw = relationship.kindRaw
        sentiment = relationship.sentiment
        emotionalWeight = relationship.emotionalWeight
        lastMentionedAt = relationship.lastMentionedAt
        mentionedEntryIDs = relationship.mentionedEntryIDs
        contextTags = relationship.contextTags
    }
}

actor RelationshipStore {
    static let shared = RelationshipStore()

    private enum Constants {
        static let defaultFetchLimit = 50
        static let secondsPerDay: TimeInterval = 86_400
        static let reinforceWeightDelta = 0.02
        static let sentimentScale = 0.1
    }

    private var container: ModelContainer?
    private let nowProvider: @Sendable () -> Date

    init(
        container: ModelContainer? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.container = container
        self.nowProvider = nowProvider
    }

    func configure(container: ModelContainer) async {
        self.container = container
        await logInfo("RelationshipStore configured")
    }

    // MARK: - Upsert

    func upsert(
        name: String,
        kind: RelationshipKind,
        sentimentDelta: Double = 0
    ) async -> UUID? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            await logWarning("RelationshipStore.upsert ignored empty name")
            return nil
        }

        guard let context = await makeContext() else { return nil }

        let now = nowProvider()

        do {
            if let existing = try fetchByName(trimmedName, in: context) {
                existing.lastMentionedAt = now
                existing.sentiment = clampSentiment(
                    existing.sentiment + sentimentDelta * Constants.sentimentScale
                )
                existing.emotionalWeight = clampWeight(
                    existing.emotionalWeight + Constants.reinforceWeightDelta
                )
                try context.save()
                return existing.id
            }

            let relationship = Relationship(
                name: trimmedName,
                kind: kind,
                lastMentionedAt: now
            )
            relationship.sentiment = clampSentiment(sentimentDelta)
            context.insert(relationship)
            try context.save()
            return relationship.id
        } catch {
            await logError("RelationshipStore.upsert failed", error: error)
            return nil
        }
    }

    // MARK: - Read

    func recentlyMentioned(
        in text: String,
        within days: Int = 90
    ) async -> [RelationshipSnapshot] {
        guard let context = await makeContext() else { return [] }

        let clampedDays = max(0, days)
        let cutoff = nowProvider().addingTimeInterval(-Double(clampedDays) * Constants.secondsPerDay)

        do {
            let descriptor = FetchDescriptor<Relationship>(
                predicate: #Predicate<Relationship> { $0.lastMentionedAt >= cutoff }
            )
            let candidates = try context.fetch(descriptor)
            return candidates
                .filter { text.contains($0.name) }
                .map { RelationshipSnapshot(relationship: $0) }
        } catch {
            await logError("RelationshipStore.recentlyMentioned failed", error: error)
            return []
        }
    }

    func all(limit: Int = Constants.defaultFetchLimit) async -> [RelationshipSnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            var descriptor = FetchDescriptor<Relationship>(
                sortBy: [SortDescriptor(\.emotionalWeight, order: .reverse)]
            )
            descriptor.fetchLimit = max(1, limit)
            return try context.fetch(descriptor).map { RelationshipSnapshot(relationship: $0) }
        } catch {
            await logError("RelationshipStore.all failed", error: error)
            return []
        }
    }

    func count() async -> Int {
        guard let context = await makeContext() else { return 0 }

        do {
            return try context.fetchCount(FetchDescriptor<Relationship>())
        } catch {
            await logError("RelationshipStore.count failed", error: error)
            return 0
        }
    }

    // MARK: - Delete

    func deleteAll() async {
        guard let context = await makeContext() else { return }

        do {
            let all = try context.fetch(FetchDescriptor<Relationship>())
            for relationship in all {
                context.delete(relationship)
            }
            try context.save()
        } catch {
            await logError("RelationshipStore.deleteAll failed", error: error)
        }
    }

    // MARK: - Helpers

    private func makeContext() async -> ModelContext? {
        guard let container else {
            await logWarning("RelationshipStore used before configure(container:)")
            return nil
        }
        return ModelContext(container)
    }

    private func fetchByName(_ name: String, in context: ModelContext) throws -> Relationship? {
        var descriptor = FetchDescriptor<Relationship>(
            predicate: #Predicate<Relationship> { $0.name == name }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func clampSentiment(_ value: Double) -> Double {
        min(1, max(-1, value))
    }

    private func clampWeight(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private func logInfo(_ message: String) async {
        await MainActor.run { diag.info(message) }
    }

    private func logWarning(_ message: String) async {
        await MainActor.run { diag.warning(message) }
    }

    private func logError(_ message: String, error: Error) async {
        await MainActor.run { diag.error(message, error: error) }
    }
}
