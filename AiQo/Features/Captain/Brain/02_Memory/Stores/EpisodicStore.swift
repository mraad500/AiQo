import Foundation
import SwiftData

nonisolated struct EpisodicEntrySnapshot: Identifiable, Sendable {
    let id: UUID
    let sessionID: UUID
    let timestamp: Date
    let captainResponseTimestamp: Date?
    let userMessageID: UUID
    let captainResponseMessageID: UUID?
    let userMessage: String
    let captainResponse: String
    let captainSpotifyRecommendation: SpotifyRecommendation?
    let emotionalContext: EmotionalSnapshot?
    let bioContext: BioSnapshot?
    let extractedFactIDs: [UUID]
    let extractedEmotionIDs: [UUID]
    let salienceScore: Double
    let accessCount: Int
    let lastAccessedAt: Date?
    let isConsolidated: Bool
    let consolidationDigest: String?

    init(entry: EpisodicEntry) {
        id = entry.id
        sessionID = entry.sessionID
        timestamp = entry.timestamp
        captainResponseTimestamp = entry.captainResponseTimestamp
        userMessageID = entry.userMessageID
        captainResponseMessageID = entry.captainResponseMessageID
        userMessage = entry.userMessage
        captainResponse = entry.captainResponse
        captainSpotifyRecommendation = entry.captainSpotifyRecommendation
        emotionalContext = entry.emotionalContext
        bioContext = entry.bioContext
        extractedFactIDs = entry.extractedFactIDs
        extractedEmotionIDs = entry.extractedEmotionIDs
        salienceScore = entry.salienceScore
        accessCount = entry.accessCount
        lastAccessedAt = entry.lastAccessedAt
        isConsolidated = entry.isConsolidated
        consolidationDigest = entry.consolidationDigest
    }
}

actor EpisodicStore {
    static let shared = EpisodicStore()

    private enum Constants {
        static let defaultRecentLimit = 20
        static let defaultWindowLimit = 100
        static let defaultSalienceLimit = 10
        static let pendingMatchWindow = 20
        static let deleteBatchSize = 250
    }

    private var container: ModelContainer?
    private let nowProvider: @Sendable () -> Date
    private let fetchLimitProvider: @Sendable (_ requested: Int, _ fallback: Int) async -> Int

    init(
        container: ModelContainer? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        fetchLimitProvider: @escaping @Sendable (_ requested: Int, _ fallback: Int) async -> Int = { requested, fallback in
            await TierGate.shared.cappedMemoryFetchLimit(requested: requested, fallback: fallback)
        }
    ) {
        self.container = container
        self.nowProvider = nowProvider
        self.fetchLimitProvider = fetchLimitProvider
    }

    func configure(container: ModelContainer) async {
        self.container = container
        await logInfo("EpisodicStore configured")
    }

    // MARK: - Create

    func record(
        sessionID: UUID = UUID(),
        timestamp: Date = Date(),
        captainResponseTimestamp: Date? = nil,
        userMessageID: UUID? = nil,
        captainResponseMessageID: UUID? = nil,
        userMessage: String,
        captainResponse: String,
        captainSpotifyRecommendation: SpotifyRecommendation? = nil,
        bioContext: BioSnapshot? = nil,
        emotionalContext: EmotionalSnapshot? = nil,
        initialSalience: Double = 0.5
    ) async -> UUID? {
        let normalizedUserMessage = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCaptainResponse = captainResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedUserMessage.isEmpty || !normalizedCaptainResponse.isEmpty else {
            await logWarning("EpisodicStore.record ignored empty exchange")
            return nil
        }

        guard let context = await makeContext() else { return nil }

        do {
            if let existingEntry = try findMatchingEntry(
                in: context,
                sessionID: sessionID,
                userMessageID: userMessageID,
                captainResponseMessageID: captainResponseMessageID,
                normalizedUserMessage: normalizedUserMessage,
                normalizedCaptainResponse: normalizedCaptainResponse
            ) {
                applyUpdate(
                    to: existingEntry,
                    sessionID: sessionID,
                    timestamp: timestamp,
                    captainResponseTimestamp: captainResponseTimestamp,
                    userMessageID: userMessageID,
                    captainResponseMessageID: captainResponseMessageID,
                    userMessage: userMessage,
                    captainResponse: captainResponse,
                    captainSpotifyRecommendation: captainSpotifyRecommendation,
                    bioContext: bioContext,
                    emotionalContext: emotionalContext,
                    salience: initialSalience
                )
                try context.save()
                return existingEntry.id
            }

            let entry = makeEntry(
                sessionID: sessionID,
                timestamp: timestamp,
                captainResponseTimestamp: captainResponseTimestamp,
                userMessageID: userMessageID,
                captainResponseMessageID: captainResponseMessageID,
                userMessage: userMessage,
                captainResponse: captainResponse,
                captainSpotifyRecommendation: captainSpotifyRecommendation,
                bioContext: bioContext,
                emotionalContext: emotionalContext,
                salience: initialSalience
            )
            context.insert(entry)
            try context.save()
            return entry.id
        } catch {
            await logError("EpisodicStore.record failed", error: error)
            return nil
        }
    }

    func record(
        message: ChatMessage,
        sessionID: UUID,
        bioContext: BioSnapshot? = nil,
        emotionalContext: EmotionalSnapshot? = nil,
        initialSalience: Double = 0.5
    ) async -> UUID? {
        if message.isUser {
            return await record(
                sessionID: sessionID,
                timestamp: message.timestamp,
                userMessageID: message.id,
                captainResponseMessageID: nil,
                userMessage: message.text,
                captainResponse: "",
                bioContext: bioContext,
                emotionalContext: emotionalContext,
                initialSalience: initialSalience
            )
        }

        return await record(
            sessionID: sessionID,
            timestamp: message.timestamp,
            captainResponseTimestamp: message.timestamp,
            userMessageID: nil,
            captainResponseMessageID: message.id,
            userMessage: "",
            captainResponse: message.text,
            captainSpotifyRecommendation: message.spotifyRecommendation,
            bioContext: bioContext,
            emotionalContext: emotionalContext,
            initialSalience: initialSalience
        )
    }

    // MARK: - Read

    func recentEntries(limit: Int = Constants.defaultRecentLimit) async -> [EpisodicEntrySnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            var descriptor = FetchDescriptor<EpisodicEntry>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = await cappedLimit(limit, fallback: Constants.defaultRecentLimit)
            return try context.fetch(descriptor).map { EpisodicEntrySnapshot(entry: $0) }
        } catch {
            await logError("EpisodicStore.recentEntries failed", error: error)
            return []
        }
    }

    func entries(
        from startDate: Date,
        to endDate: Date,
        limit: Int = Constants.defaultWindowLimit
    ) async -> [EpisodicEntrySnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            var descriptor = FetchDescriptor<EpisodicEntry>(
                predicate: #Predicate<EpisodicEntry> {
                    $0.timestamp >= startDate && $0.timestamp <= endDate
                },
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            descriptor.fetchLimit = await cappedLimit(limit, fallback: Constants.defaultWindowLimit)
            return try context.fetch(descriptor).map { EpisodicEntrySnapshot(entry: $0) }
        } catch {
            await logError("EpisodicStore.entries failed", error: error)
            return []
        }
    }

    func entriesBySalience(
        min minimumSalience: Double = 0.6,
        limit: Int = Constants.defaultSalienceLimit
    ) async -> [EpisodicEntrySnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            var descriptor = FetchDescriptor<EpisodicEntry>(
                predicate: #Predicate<EpisodicEntry> {
                    $0.salienceScore >= minimumSalience && $0.isConsolidated == false
                },
                sortBy: [
                    SortDescriptor(\.salienceScore, order: .reverse),
                    SortDescriptor(\.timestamp, order: .reverse)
                ]
            )
            descriptor.fetchLimit = await cappedLimit(limit, fallback: Constants.defaultSalienceLimit)
            return try context.fetch(descriptor).map { EpisodicEntrySnapshot(entry: $0) }
        } catch {
            await logError("EpisodicStore.entriesBySalience failed", error: error)
            return []
        }
    }

    func entry(id: UUID) async -> EpisodicEntrySnapshot? {
        guard let context = await makeContext() else { return nil }

        do {
            return try fetchEntry(id: id, in: context).map { EpisodicEntrySnapshot(entry: $0) }
        } catch {
            await logError("EpisodicStore.entry failed", error: error)
            return nil
        }
    }

    func count() async -> Int {
        guard let context = await makeContext() else { return 0 }

        do {
            return try context.fetchCount(FetchDescriptor<EpisodicEntry>())
        } catch {
            await logError("EpisodicStore.count failed", error: error)
            return 0
        }
    }

    // MARK: - Update

    func markAccessed(_ id: UUID) async {
        guard let context = await makeContext() else { return }

        do {
            guard let entry = try fetchEntry(id: id, in: context) else { return }
            entry.accessCount += 1
            entry.lastAccessedAt = nowProvider()
            try context.save()
        } catch {
            await logError("EpisodicStore.markAccessed failed", error: error)
        }
    }

    func updateSalience(_ id: UUID, to newSalience: Double) async {
        guard let context = await makeContext() else { return }

        do {
            guard let entry = try fetchEntry(id: id, in: context) else { return }
            entry.salienceScore = clamp(newSalience)
            try context.save()
        } catch {
            await logError("EpisodicStore.updateSalience failed", error: error)
        }
    }

    func setExtractedFactIDs(_ ids: [UUID], for entryID: UUID) async {
        guard let context = await makeContext() else { return }

        do {
            guard let entry = try fetchEntry(id: entryID, in: context) else { return }
            entry.setExtractedFactIDs(ids)
            try context.save()
        } catch {
            await logError("EpisodicStore.setExtractedFactIDs failed", error: error)
        }
    }

    func markConsolidated(_ ids: [UUID], digest: String) async {
        guard let context = await makeContext() else { return }

        do {
            var didUpdate = false

            for id in ids {
                if let entry = try fetchEntry(id: id, in: context) {
                    entry.isConsolidated = true
                    entry.consolidationDigest = digest
                    didUpdate = true
                }
            }

            if didUpdate {
                try context.save()
            }
        } catch {
            await logError("EpisodicStore.markConsolidated failed", error: error)
        }
    }

    // MARK: - Delete / Prune

    func prune(olderThan cutoff: Date, onlyConsolidated: Bool = true) async -> Int {
        guard let context = await makeContext() else { return 0 }

        do {
            var totalPruned = 0

            while true {
                var descriptor: FetchDescriptor<EpisodicEntry>

                if onlyConsolidated {
                    descriptor = FetchDescriptor<EpisodicEntry>(
                        predicate: #Predicate<EpisodicEntry> {
                            $0.timestamp < cutoff && $0.isConsolidated == true
                        },
                        sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                    )
                } else {
                    descriptor = FetchDescriptor<EpisodicEntry>(
                        predicate: #Predicate<EpisodicEntry> {
                            $0.timestamp < cutoff
                        },
                        sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                    )
                }

                descriptor.fetchLimit = Constants.deleteBatchSize
                let batch = try context.fetch(descriptor)
                guard !batch.isEmpty else { break }

                for entry in batch {
                    context.delete(entry)
                }

                try context.save()
                totalPruned += batch.count
            }

            if totalPruned > 0 {
                await logInfo("EpisodicStore pruned \(totalPruned) entries older than \(cutoff)")
            }

            return totalPruned
        } catch {
            await logError("EpisodicStore.prune failed", error: error)
            return 0
        }
    }

    func deleteAll() async {
        guard let context = await makeContext() else { return }

        do {
            while true {
                var descriptor = FetchDescriptor<EpisodicEntry>(
                    sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                )
                descriptor.fetchLimit = Constants.deleteBatchSize
                let batch = try context.fetch(descriptor)
                guard !batch.isEmpty else { break }

                for entry in batch {
                    context.delete(entry)
                }

                try context.save()
            }
        } catch {
            await logError("EpisodicStore.deleteAll failed", error: error)
        }
    }

    // MARK: - Helpers

    private func makeContext() async -> ModelContext? {
        guard let container else {
            await logWarning("EpisodicStore used before configure(container:)")
            return nil
        }

        return ModelContext(container)
    }

    private func cappedLimit(_ requested: Int, fallback: Int) async -> Int {
        await fetchLimitProvider(requested, fallback)
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private func makeEntry(
        sessionID: UUID,
        timestamp: Date,
        captainResponseTimestamp: Date?,
        userMessageID: UUID?,
        captainResponseMessageID: UUID?,
        userMessage: String,
        captainResponse: String,
        captainSpotifyRecommendation: SpotifyRecommendation?,
        bioContext: BioSnapshot?,
        emotionalContext: EmotionalSnapshot?,
        salience: Double
    ) -> EpisodicEntry {
        let normalizedCaptainResponse = captainResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        return EpisodicEntry(
            sessionID: sessionID,
            timestamp: timestamp,
            captainResponseTimestamp: captainResponseTimestamp ?? (normalizedCaptainResponse.isEmpty ? nil : timestamp),
            userMessageID: userMessageID ?? UUID(),
            captainResponseMessageID: captainResponseMessageID,
            userMessage: userMessage,
            captainResponse: captainResponse,
            captainSpotifyRecommendation: captainSpotifyRecommendation,
            emotionalContext: emotionalContext,
            bioContext: bioContext,
            salienceScore: clamp(salience)
        )
    }

    private func applyUpdate(
        to entry: EpisodicEntry,
        sessionID: UUID,
        timestamp: Date,
        captainResponseTimestamp: Date?,
        userMessageID: UUID?,
        captainResponseMessageID: UUID?,
        userMessage: String,
        captainResponse: String,
        captainSpotifyRecommendation: SpotifyRecommendation?,
        bioContext: BioSnapshot?,
        emotionalContext: EmotionalSnapshot?,
        salience: Double
    ) {
        entry.sessionID = sessionID

        if !userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry.userMessage = userMessage
            if let userMessageID {
                entry.userMessageID = userMessageID
            }
            entry.timestamp = timestamp
        }

        if !captainResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry.captainResponse = captainResponse
            entry.captainResponseTimestamp = captainResponseTimestamp ?? timestamp
            if let captainResponseMessageID {
                entry.captainResponseMessageID = captainResponseMessageID
            }
            if captainSpotifyRecommendation != nil || entry.captainSpotifyRecommendationData == nil {
                entry.setCaptainSpotifyRecommendation(captainSpotifyRecommendation)
            }
        }

        if let bioContext {
            entry.setBioContext(bioContext)
        }

        if let emotionalContext {
            entry.setEmotionalContext(emotionalContext)
        }

        entry.salienceScore = max(entry.salienceScore, clamp(salience))
    }

    private func findMatchingEntry(
        in context: ModelContext,
        sessionID: UUID,
        userMessageID: UUID?,
        captainResponseMessageID: UUID?,
        normalizedUserMessage: String,
        normalizedCaptainResponse: String
    ) throws -> EpisodicEntry? {
        if let userMessageID,
           let existing = try fetchByUserMessageID(userMessageID, in: context) {
            return existing
        }

        if let captainResponseMessageID,
           let existing = try fetchByCaptainResponseMessageID(captainResponseMessageID, in: context) {
            return existing
        }

        guard normalizedUserMessage.isEmpty != normalizedCaptainResponse.isEmpty else {
            return nil
        }

        var descriptor = FetchDescriptor<EpisodicEntry>(
            predicate: #Predicate<EpisodicEntry> { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = Constants.pendingMatchWindow

        let recentEntries = try context.fetch(descriptor)

        if normalizedCaptainResponse.isEmpty {
            return recentEntries.first {
                $0.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !$0.captainResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }

        return recentEntries.first {
            !$0.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.captainResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func fetchEntry(id: UUID, in context: ModelContext) throws -> EpisodicEntry? {
        var descriptor = FetchDescriptor<EpisodicEntry>(
            predicate: #Predicate<EpisodicEntry> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchByUserMessageID(_ userMessageID: UUID, in context: ModelContext) throws -> EpisodicEntry? {
        var descriptor = FetchDescriptor<EpisodicEntry>(
            predicate: #Predicate<EpisodicEntry> { $0.userMessageID == userMessageID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchByCaptainResponseMessageID(
        _ captainResponseMessageID: UUID,
        in context: ModelContext
    ) throws -> EpisodicEntry? {
        var descriptor = FetchDescriptor<EpisodicEntry>(
            predicate: #Predicate<EpisodicEntry> { $0.captainResponseMessageID == captainResponseMessageID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func logInfo(_ message: String) async {
        await MainActor.run {
            diag.info(message)
        }
    }

    private func logWarning(_ message: String) async {
        await MainActor.run {
            diag.warning(message)
        }
    }

    private func logError(_ message: String, error: Error) async {
        await MainActor.run {
            diag.error(message, error: error)
        }
    }
}
