import Foundation
import SwiftData
import os.log

@MainActor
@Observable
final class MemoryStore {
    enum StorageMode: String {
        case legacyV3
        case schemaV4
    }

    private struct MemoryRecord {
        let id: UUID
        let key: String
        let value: String
        let category: String
        let confidence: Double
        let source: String
        let createdAt: Date
        let updatedAt: Date
        let accessCount: Int
        let isCloudSafe: Bool
    }

    static let shared = MemoryStore()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AiQo", category: "MemoryStore")
    private var container: ModelContainer?
    private var context: ModelContext?
    private var storageMode: StorageMode = .legacyV3
    private var promptContextCache: [Int: String] = [:]
    private var cloudSafeContextCache: [Int: String] = [:]
    private var persistedMessageWriteCount = 0
    private var maxMemories: Int {
        TierGate.shared.memoryFactLimit
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "captain_memory_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "captain_memory_enabled") }
    }

    private init() {
        if UserDefaults.standard.object(forKey: "captain_memory_enabled") == nil {
            UserDefaults.standard.set(true, forKey: "captain_memory_enabled")
        }
    }

    func configure(container: ModelContainer, storageMode: StorageMode) {
        self.container = container
        self.context = ModelContext(container)
        self.storageMode = storageMode
        invalidateMemoryContextCaches()
        persistedMessageWriteCount = 0
    }

    func set(_ key: String, value: String, category: String, source: String, confidence: Double = 0.7) {
        guard isEnabled, let context else { return }

        switch storageMode {
        case .legacyV3:
            do {
                var persistedConfidence = confidence
                let descriptor = FetchDescriptor<CaptainMemory>(
                    predicate: #Predicate { $0.key == key }
                )
                let existing = try context.fetch(descriptor)

                if let memory = existing.first {
                    memory.value = value
                    memory.updatedAt = Date()
                    memory.confidence = min(memory.confidence + 0.05, 1)
                    persistedConfidence = memory.confidence
                    if memory.source != "user_explicit" || source == "user_explicit" {
                        memory.source = source
                    }
                } else {
                    let count = try context.fetchCount(FetchDescriptor<CaptainMemory>())
                    if count >= maxMemories {
                        removeLowestConfidence()
                    }

                    let memory = CaptainMemory(
                        key: key,
                        value: value,
                        category: category,
                        source: source,
                        confidence: confidence
                    )
                    context.insert(memory)
                }

                try context.save()
                invalidateMemoryContextCaches()
                shadowWriteSemanticFact(
                    key: key,
                    value: value,
                    category: category,
                    source: source,
                    confidence: persistedConfidence,
                    salience: max(0.5, persistedConfidence),
                    storageMode: .legacyV3
                )
            } catch {
                logger.error("memory_store_set_error key=\(key) error=\(error.localizedDescription)")
            }
        case .schemaV4:
            do {
                var persistedConfidence = confidence
                var persistedSalience = 0.5
                let descriptor = FetchDescriptor<SemanticFact>(
                    predicate: #Predicate { $0.storageKey == key }
                )
                let existing = try context.fetch(descriptor)

                if let fact = existing.first {
                    fact.content = value
                    fact.categoryRaw = category
                    fact.lastConfirmedAt = Date()
                    fact.confidence = min(fact.confidence + 0.05, 1)
                    fact.salience = max(fact.salience, confidence)
                    fact.mentionCount += 1
                    fact.isPII = fact.isPII || Self.isPII(key: key, category: category)
                    fact.isSensitive = fact.isSensitive || Self.isSensitive(category: category)
                    persistedConfidence = fact.confidence
                    persistedSalience = fact.salience
                    if fact.sourceRaw != "user_explicit" || source == "user_explicit" {
                        fact.sourceRaw = source
                    }
                } else {
                    let count = try context.fetchCount(FetchDescriptor<SemanticFact>())
                    if count >= maxMemories {
                        removeLowestConfidence()
                    }

                    let fact = SemanticFact(
                        storageKey: key,
                        content: value,
                        category: Self.factCategory(for: category),
                        categoryRawOverride: category,
                        confidence: confidence,
                        salience: 0.5,
                        source: Self.factSource(for: source),
                        sourceRawOverride: source,
                        firstMentionedAt: Date(),
                        mentionCount: 1,
                        referenceCount: 0,
                        isPII: Self.isPII(key: key, category: category),
                        isSensitive: Self.isSensitive(category: category)
                    )
                    context.insert(fact)
                    persistedConfidence = fact.confidence
                    persistedSalience = fact.salience
                }

                try context.save()
                invalidateMemoryContextCaches()
                shadowWriteSemanticFact(
                    key: key,
                    value: value,
                    category: category,
                    source: source,
                    confidence: persistedConfidence,
                    salience: persistedSalience,
                    storageMode: .schemaV4
                )
            } catch {
                logger.error("memory_store_set_v4_error key=\(key) error=\(error.localizedDescription)")
            }
        }
    }

    func get(_ key: String) -> String? {
        guard let context else { return nil }

        switch storageMode {
        case .legacyV3:
            do {
                let descriptor = FetchDescriptor<CaptainMemory>(
                    predicate: #Predicate { $0.key == key }
                )
                return try context.fetch(descriptor).first?.value
            } catch {
                logger.error("memory_store_get_error key=\(key) error=\(error.localizedDescription)")
                return nil
            }
        case .schemaV4:
            do {
                let descriptor = FetchDescriptor<SemanticFact>(
                    predicate: #Predicate { $0.storageKey == key }
                )
                return try context.fetch(descriptor).first?.content
            } catch {
                logger.error("memory_store_get_v4_error key=\(key) error=\(error.localizedDescription)")
                return nil
            }
        }
    }

    func getByCategory(_ category: String) -> [CaptainMemorySnapshot] {
        let records = (try? fetchAllMemoryRecords()) ?? []
        return records
            .filter { $0.category == category }
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.key < rhs.key
                }
                return lhs.updatedAt > rhs.updatedAt
            }
            .map(snapshot(from:))
    }

    func allMemories() -> [CaptainMemorySnapshot] {
        let records = (try? fetchAllMemoryRecords()) ?? []
        return records
            .sorted { lhs, rhs in
                if lhs.category == rhs.category {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.category < rhs.category
            }
            .map(snapshot(from:))
    }

    func retrieveRelevantMemories(
        for message: String,
        screenContext: ScreenContext,
        limit: Int = 8,
        allowedCategories: Set<String>? = nil
    ) -> [CaptainMemorySnapshot] {
        guard isEnabled else { return [] }

        let intent = CaptainMessageIntent.detect(message: message, screenContext: screenContext)
        let messageTokens = CaptainCognitiveTextAnalyzer.tokens(from: message)

        do {
            let filtered = try fetchAllMemoryRecords()
                .filter { record in
                    guard let allowedCategories else { return true }
                    return allowedCategories.contains(record.category)
                }

            let ranked = filtered
                .compactMap { record -> (MemoryRecord, Double)? in
                    let score = relevanceScore(
                        for: record,
                        messageTokens: messageTokens,
                        intent: intent,
                        screenContext: screenContext
                    )
                    guard score > 0 else { return nil }
                    return (record, score)
                }
                .sorted { lhs, rhs in
                    if lhs.1 == rhs.1 {
                        return lhs.0.updatedAt > rhs.0.updatedAt
                    }
                    return lhs.1 > rhs.1
                }

            let selected = Array(ranked.prefix(limit))
            guard !selected.isEmpty else { return [] }

            bumpAccessCounts(for: selected.map(\.0.id))

            return selected.map { snapshot(from: $0.0) }
        } catch {
            logger.error("memory_store_relevant_error error=\(error.localizedDescription)")
            return []
        }
    }

    func buildCloudSafeRelevantContext(
        for message: String,
        screenContext: ScreenContext,
        maxTokens: Int = 400
    ) -> String {
        let allowedCategories: Set<String> = ["goal", "preference", "mood", "injury", "nutrition", "insight"]
        let memories = retrieveRelevantMemories(
            for: message,
            screenContext: screenContext,
            limit: 10,
            allowedCategories: allowedCategories
        )

        guard !memories.isEmpty else { return "" }

        var lines: [String] = []
        var budget = maxTokens

        for memory in memories {
            let line = "- \(memory.key): \(memory.value)"
            let cost = max(1, line.count / 4)
            guard budget - cost > 0 else { break }
            budget -= cost
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    func buildPromptContext(maxTokens: Int = 800) -> String {
        guard isEnabled else { return "" }
        if let cached = promptContextCache[maxTokens] {
            return cached
        }

        do {
            let records = try fetchAllMemoryRecords()
            let projectRecords = records
                .filter { $0.category == "active_record_project" }
                .sorted { $0.updatedAt > $1.updatedAt }
            let otherRecords = records
                .filter { $0.category != "active_record_project" }
                .sorted { lhs, rhs in
                    if lhs.confidence == rhs.confidence {
                        return lhs.updatedAt > rhs.updatedAt
                    }
                    return lhs.confidence > rhs.confidence
                }

            var lines: [String] = []
            var estimatedTokens = 0

            for memory in Array(projectRecords.prefix(5)) + Array(otherRecords.prefix(30)) {
                let line = "- \(memory.key): \(memory.value)"
                let lineTokens = line.count / 4
                if estimatedTokens + lineTokens > maxTokens { break }

                lines.append(line)
                estimatedTokens += lineTokens
            }

            let promptContext = lines.joined(separator: "\n")
            promptContextCache[maxTokens] = promptContext
            return promptContext
        } catch {
            logger.error("memory_store_prompt_error error=\(error.localizedDescription)")
            return ""
        }
    }

    func buildCloudSafeContext(maxTokens: Int = 400) -> String {
        guard isEnabled else { return "" }
        if let cached = cloudSafeContextCache[maxTokens] {
            return cached
        }

        let cloudSafeCategories: Set<String> = ["goal", "preference", "mood", "injury", "nutrition", "insight"]

        do {
            let records = try fetchAllMemoryRecords()
                .filter { cloudSafeCategories.contains($0.category) && $0.isCloudSafe }
                .sorted { lhs, rhs in
                    if lhs.confidence == rhs.confidence {
                        return lhs.updatedAt > rhs.updatedAt
                    }
                    return lhs.confidence > rhs.confidence
                }

            var lines: [String] = []
            var budget = maxTokens

            for memory in records.prefix(15) {
                let line = "- \(memory.key): \(memory.value)"
                let cost = max(1, line.count / 4)
                guard budget - cost > 0 else { break }
                budget -= cost
                lines.append(line)
            }

            let safeContext = lines.joined(separator: "\n")
            cloudSafeContextCache[maxTokens] = safeContext
            return safeContext
        } catch {
            logger.error("memory_store_cloud_safe_error error=\(error.localizedDescription)")
            return ""
        }
    }

    func removeStale(olderThan days: Int = 90, belowConfidence: Double = 0.3) {
        guard let context else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        switch storageMode {
        case .legacyV3:
            do {
                let descriptor = FetchDescriptor<CaptainMemory>(
                    predicate: #Predicate {
                        $0.updatedAt < cutoff && $0.confidence < belowConfidence && $0.category != "active_record_project"
                    }
                )
                let stale = try context.fetch(descriptor)
                for memory in stale {
                    context.delete(memory)
                }
                try context.save()
                if !stale.isEmpty {
                    invalidateMemoryContextCaches()
                }
                logger.info("memory_store_cleanup removed=\(stale.count)")
                shadowPruneSemanticFacts(olderThan: cutoff, belowConfidence: belowConfidence)
            } catch {
                logger.error("memory_store_cleanup_error error=\(error.localizedDescription)")
            }
        case .schemaV4:
            do {
                let descriptor = FetchDescriptor<SemanticFact>(
                    predicate: #Predicate {
                        $0.lastConfirmedAt < cutoff && $0.confidence < belowConfidence && $0.categoryRaw != "active_record_project"
                    }
                )
                let stale = try context.fetch(descriptor)
                for fact in stale {
                    context.delete(fact)
                }
                try context.save()
                if !stale.isEmpty {
                    invalidateMemoryContextCaches()
                }
                logger.info("memory_store_cleanup_v4 removed=\(stale.count)")
                shadowPruneSemanticFacts(olderThan: cutoff, belowConfidence: belowConfidence)
            } catch {
                logger.error("memory_store_cleanup_v4_error error=\(error.localizedDescription)")
            }
        }
    }

    func remove(_ key: String) {
        guard let context else { return }

        switch storageMode {
        case .legacyV3:
            do {
                let descriptor = FetchDescriptor<CaptainMemory>(
                    predicate: #Predicate { $0.key == key }
                )
                let results = try context.fetch(descriptor)
                for memory in results {
                    context.delete(memory)
                }
                try context.save()
                if !results.isEmpty {
                    invalidateMemoryContextCaches()
                }
                shadowRemoveSemanticFact(key)
            } catch {
                logger.error("memory_store_remove_error key=\(key) error=\(error.localizedDescription)")
            }
        case .schemaV4:
            do {
                let descriptor = FetchDescriptor<SemanticFact>(
                    predicate: #Predicate { $0.storageKey == key }
                )
                let results = try context.fetch(descriptor)
                for fact in results {
                    context.delete(fact)
                }
                try context.save()
                if !results.isEmpty {
                    invalidateMemoryContextCaches()
                }
                shadowRemoveSemanticFact(key)
            } catch {
                logger.error("memory_store_remove_v4_error key=\(key) error=\(error.localizedDescription)")
            }
        }
    }

    func clearAll() {
        guard let context else { return }

        switch storageMode {
        case .legacyV3:
            do {
                let all = try context.fetch(FetchDescriptor<CaptainMemory>())
                for memory in all {
                    context.delete(memory)
                }
                try context.save()
                if !all.isEmpty {
                    invalidateMemoryContextCaches()
                }
                logger.info("memory_store_clear_all")
                shadowClearSemanticFacts()
            } catch {
                logger.error("memory_store_clear_error error=\(error.localizedDescription)")
            }
        case .schemaV4:
            do {
                let all = try context.fetch(FetchDescriptor<SemanticFact>())
                for fact in all {
                    context.delete(fact)
                }
                try context.save()
                if !all.isEmpty {
                    invalidateMemoryContextCaches()
                }
                logger.info("memory_store_clear_all_v4")
                shadowClearSemanticFacts()
            } catch {
                logger.error("memory_store_clear_v4_error error=\(error.localizedDescription)")
            }
        }
    }

    func summary() -> String {
        do {
            let count = try fetchAllMemoryRecords().count
            return "MemoryStore: \(count) memories, enabled=\(isEnabled), mode=\(storageMode.rawValue)"
        } catch {
            return "MemoryStore: error reading count"
        }
    }

    private static let maxPersistedMessages = 200
    private static let trimCheckInterval = 12

    func persistMessage(_ chatMessage: ChatMessage, sessionID: UUID) {
        guard let context else { return }
        guard !chatMessage.isEphemeral,
              !chatMessage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        switch storageMode {
        case .legacyV3:
            do {
                context.insert(PersistentChatMessage(chatMessage: chatMessage, sessionID: sessionID))
                try context.save()
                persistedMessageWriteCount += 1
                if persistedMessageWriteCount >= Self.trimCheckInterval {
                    persistedMessageWriteCount = 0
                    trimChatHistoryIfNeeded()
                }
                shadowRecordEpisode(from: chatMessage, sessionID: sessionID)
            } catch {
                logger.error("chat_persist_error id=\(chatMessage.id) error=\(error.localizedDescription)")
            }
        case .schemaV4:
            do {
                try persistMessageV4(chatMessage, sessionID: sessionID)
                try context.save()
                persistedMessageWriteCount += 1
                if persistedMessageWriteCount >= Self.trimCheckInterval {
                    persistedMessageWriteCount = 0
                    trimChatHistoryIfNeeded()
                }
                shadowRecordEpisode(from: chatMessage, sessionID: sessionID)
            } catch {
                logger.error("chat_persist_v4_error id=\(chatMessage.id) error=\(error.localizedDescription)")
            }
        }
    }

    func persistMessageAsync(_ chatMessage: ChatMessage, sessionID: UUID) {
        Task(priority: .utility) { @MainActor [chatMessage, sessionID] in
            self.persistMessage(chatMessage, sessionID: sessionID)
        }
    }

    func fetchMessages(for sessionID: UUID) -> [ChatMessage] {
        guard let context else { return [] }

        switch storageMode {
        case .legacyV3:
            do {
                let descriptor = FetchDescriptor<PersistentChatMessage>(
                    predicate: #Predicate { $0.sessionID == sessionID },
                    sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                )
                return try context.fetch(descriptor).map { $0.toChatMessage() }
            } catch {
                logger.error("chat_fetch_session_error session=\(sessionID) error=\(error.localizedDescription)")
                return []
            }
        case .schemaV4:
            do {
                let descriptor = FetchDescriptor<EpisodicEntry>(
                    predicate: #Predicate { $0.sessionID == sessionID },
                    sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                )
                let episodes = try context.fetch(descriptor)
                return messages(from: episodes)
            } catch {
                logger.error("chat_fetch_session_v4_error session=\(sessionID) error=\(error.localizedDescription)")
                return []
            }
        }
    }

    func fetchSessions() -> [ChatSession] {
        guard let context else { return [] }

        switch storageMode {
        case .legacyV3:
            do {
                var descriptor = FetchDescriptor<PersistentChatMessage>(
                    sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                )
                descriptor.fetchLimit = 500
                let messages = try context.fetch(descriptor)

                struct SessionMeta {
                    var firstTimestamp: Date
                    var firstText: String
                    var firstUserText: String?
                    var count: Int
                }

                var metaMap: [UUID: SessionMeta] = [:]

                for message in messages {
                    if var meta = metaMap[message.sessionID] {
                        meta.count += 1
                        if meta.firstUserText == nil && message.isUser {
                            meta.firstUserText = message.text
                        }
                        metaMap[message.sessionID] = meta
                    } else {
                        metaMap[message.sessionID] = SessionMeta(
                            firstTimestamp: message.timestamp,
                            firstText: message.text,
                            firstUserText: message.isUser ? message.text : nil,
                            count: 1
                        )
                    }
                }

                return metaMap.compactMap { sessionID, meta in
                    guard meta.count > 1 else { return nil }
                    let preview = meta.firstUserText ?? meta.firstText
                    let trimmed = preview.count > 60 ? String(preview.prefix(60)) + "…" : preview
                    return ChatSession(
                        id: sessionID,
                        preview: trimmed,
                        timestamp: meta.firstTimestamp,
                        messageCount: meta.count
                    )
                }
                .sorted { $0.timestamp > $1.timestamp }
            } catch {
                logger.error("chat_fetch_sessions_error error=\(error.localizedDescription)")
                return []
            }
        case .schemaV4:
            do {
                var descriptor = FetchDescriptor<EpisodicEntry>(
                    sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                )
                descriptor.fetchLimit = 250
                let episodes = try context.fetch(descriptor)

                struct SessionMeta {
                    var firstTimestamp: Date
                    var preview: String
                    var count: Int
                }

                var metaMap: [UUID: SessionMeta] = [:]

                for episode in episodes {
                    let messages = messages(from: [episode])
                    guard !messages.isEmpty else { continue }
                    let preview = messages.first(where: \.isUser)?.text ?? messages[0].text
                    let count = messages.count

                    if var meta = metaMap[episode.sessionID] {
                        meta.count += count
                        metaMap[episode.sessionID] = meta
                    } else {
                        metaMap[episode.sessionID] = SessionMeta(
                            firstTimestamp: messages.first?.timestamp ?? episode.timestamp,
                            preview: preview,
                            count: count
                        )
                    }
                }

                return metaMap.compactMap { sessionID, meta in
                    guard meta.count > 1 else { return nil }
                    let trimmed = meta.preview.count > 60 ? String(meta.preview.prefix(60)) + "…" : meta.preview
                    return ChatSession(
                        id: sessionID,
                        preview: trimmed,
                        timestamp: meta.firstTimestamp,
                        messageCount: meta.count
                    )
                }
                .sorted { $0.timestamp > $1.timestamp }
            } catch {
                logger.error("chat_fetch_sessions_v4_error error=\(error.localizedDescription)")
                return []
            }
        }
    }

    func clearChatHistory() {
        guard let context else { return }

        switch storageMode {
        case .legacyV3:
            do {
                let all = try context.fetch(FetchDescriptor<PersistentChatMessage>())
                for message in all {
                    context.delete(message)
                }
                try context.save()
                persistedMessageWriteCount = 0
                logger.info("chat_history_cleared count=\(all.count)")
            } catch {
                logger.error("chat_clear_error error=\(error.localizedDescription)")
            }
        case .schemaV4:
            do {
                let all = try context.fetch(FetchDescriptor<EpisodicEntry>())
                for episode in all {
                    context.delete(episode)
                }
                try context.save()
                persistedMessageWriteCount = 0
                logger.info("chat_history_cleared_v4 count=\(all.count)")
            } catch {
                logger.error("chat_clear_v4_error error=\(error.localizedDescription)")
            }
        }
    }

    private func trimChatHistoryIfNeeded() {
        guard let context else { return }

        switch storageMode {
        case .legacyV3:
            do {
                let total = try context.fetchCount(FetchDescriptor<PersistentChatMessage>())
                guard total > Self.maxPersistedMessages else { return }

                let excess = total - Self.maxPersistedMessages
                var oldestDescriptor = FetchDescriptor<PersistentChatMessage>(
                    sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                )
                oldestDescriptor.fetchLimit = excess

                let toDelete = try context.fetch(oldestDescriptor)
                for message in toDelete {
                    context.delete(message)
                }
                try context.save()
                logger.info("chat_trim removed=\(toDelete.count) total_was=\(total)")
            } catch {
                logger.error("chat_trim_error error=\(error.localizedDescription)")
            }
        case .schemaV4:
            do {
                let descriptor = FetchDescriptor<EpisodicEntry>(
                    sortBy: [SortDescriptor(\.timestamp, order: .forward)]
                )
                let episodes = try context.fetch(descriptor)
                var totalMessages = episodes.reduce(0) { $0 + messageCount(for: $1) }
                guard totalMessages > Self.maxPersistedMessages else { return }

                var toDelete: [EpisodicEntry] = []
                for episode in episodes {
                    guard totalMessages > Self.maxPersistedMessages else { break }
                    totalMessages -= max(1, messageCount(for: episode))
                    toDelete.append(episode)
                }

                for episode in toDelete {
                    context.delete(episode)
                }
                try context.save()
                logger.info("chat_trim_v4 removed=\(toDelete.count)")
            } catch {
                logger.error("chat_trim_v4_error error=\(error.localizedDescription)")
            }
        }
    }

    private func invalidateMemoryContextCaches() {
        promptContextCache.removeAll()
        cloudSafeContextCache.removeAll()
    }

    private func relevanceScore(
        for memory: MemoryRecord,
        messageTokens: Set<String>,
        intent: CaptainMessageIntent,
        screenContext: ScreenContext
    ) -> Double {
        let normalizedMemory = CaptainCognitiveTextAnalyzer.normalizedText(
            "\(memory.key) \(memory.value) \(memory.category)"
        )

        let overlappingTokenCount = messageTokens.reduce(into: 0) { partialResult, token in
            if normalizedMemory.contains(token) {
                partialResult += 1
            }
        }

        var score = memory.confidence * 3
        score += intent.retrievalCategoryWeights[memory.category] ?? 0
        score += screenMemoryWeight(for: memory.category, screenContext: screenContext)
        score += directCategoryBoost(for: memory.category, intent: intent)
        score += Double(overlappingTokenCount) * 2.6
        score += sourceWeight(for: memory.source)
        score += recencyWeight(for: memory.updatedAt)
        score -= min(Double(memory.accessCount) * 0.08, 1.2)

        if overlappingTokenCount == 0,
           memory.source != "user_explicit",
           (intent.retrievalCategoryWeights[memory.category] ?? 0) < 2.5 {
            score -= 1.2
        }

        if memory.category == "active_record_project",
           (intent == .challenge || screenContext == .peaks) {
            score += 4
        }

        return score
    }

    func directCategoryBoost(
        for category: String,
        intent: CaptainMessageIntent
    ) -> Double {
        switch (intent, category) {
        case (.sleep, "sleep"):
            return 4.5
        case (.workout, "injury"), (.recovery, "injury"):
            return 4
        case (.workout, "goal"), (.nutrition, "goal"), (.challenge, "goal"):
            return 2.5
        case (.nutrition, "nutrition"):
            return 4
        case (.vibe, "mood"), (.emotionalSupport, "mood"):
            return 3.5
        case (.challenge, "active_record_project"):
            return 5
        default:
            return 0
        }
    }

    func screenMemoryWeight(
        for category: String,
        screenContext: ScreenContext
    ) -> Double {
        switch screenContext {
        case .gym:
            switch category {
            case "injury": return 2.8
            case "goal": return 2.2
            case "preference": return 1.8
            case "sleep": return 1.1
            default: return 0
            }
        case .kitchen:
            switch category {
            case "nutrition": return 2.8
            case "goal": return 1.8
            case "body": return 1.5
            default: return 0
            }
        case .sleepAnalysis:
            return category == "sleep" ? 3.2 : 0
        case .peaks:
            switch category {
            case "active_record_project": return 3.5
            case "goal": return 1.8
            default: return 0
            }
        case .myVibe:
            return category == "mood" ? 2.8 : 0
        case .mainChat:
            switch category {
            case "goal", "preference", "insight": return 1
            default: return 0
            }
        }
    }

    func sourceWeight(for source: String) -> Double {
        switch source {
        case "user_explicit":
            return 1.8
        case "llm_extracted":
            return 0.9
        case "extracted":
            return 0.6
        default:
            return 0.2
        }
    }

    func recencyWeight(for updatedAt: Date) -> Double {
        let days = max(0, Date().timeIntervalSince(updatedAt) / 86_400)
        switch days {
        case ..<1:
            return 1.5
        case ..<7:
            return 1
        case ..<30:
            return 0.5
        default:
            return 0
        }
    }

    private func removeLowestConfidence() {
        guard let context else { return }

        switch storageMode {
        case .legacyV3:
            do {
                let memories = try context.fetch(FetchDescriptor<CaptainMemory>())
                if let lowest = memories
                    .filter({ $0.category != "active_record_project" })
                    .sorted(by: { $0.confidence < $1.confidence })
                    .first {
                    context.delete(lowest)
                }
            } catch {
                logger.error("memory_store_remove_lowest_error error=\(error.localizedDescription)")
            }
        case .schemaV4:
            do {
                let facts = try context.fetch(FetchDescriptor<SemanticFact>())
                if let lowest = facts
                    .filter({ $0.categoryRaw != "active_record_project" })
                    .sorted(by: { $0.confidence < $1.confidence })
                    .first {
                    context.delete(lowest)
                }
            } catch {
                logger.error("memory_store_remove_lowest_v4_error error=\(error.localizedDescription)")
            }
        }
    }

    private func fetchAllMemoryRecords() throws -> [MemoryRecord] {
        guard let context else { return [] }

        switch storageMode {
        case .legacyV3:
            let memories = try context.fetch(FetchDescriptor<CaptainMemory>())
            return memories.map {
                MemoryRecord(
                    id: $0.id,
                    key: $0.key,
                    value: $0.value,
                    category: $0.category,
                    confidence: $0.confidence,
                    source: $0.source,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt,
                    accessCount: $0.accessCount,
                    isCloudSafe: !Self.isPII(key: $0.key, category: $0.category) && !Self.isSensitive(category: $0.category)
                )
            }
        case .schemaV4:
            let facts = try context.fetch(FetchDescriptor<SemanticFact>())
            return facts
                .filter { !$0.userHidden }
                .map {
                    MemoryRecord(
                        id: $0.id,
                        key: $0.storageKey,
                        value: $0.content,
                        category: $0.categoryRaw,
                        confidence: $0.confidence,
                        source: $0.sourceRaw,
                        createdAt: $0.firstMentionedAt,
                        updatedAt: $0.lastConfirmedAt,
                        accessCount: $0.referenceCount,
                        isCloudSafe: $0.isCloudSafe
                    )
                }
        }
    }

    private func snapshot(from record: MemoryRecord) -> CaptainMemorySnapshot {
        CaptainMemorySnapshot(
            id: record.id,
            key: record.key,
            value: record.value,
            category: record.category,
            confidence: record.confidence,
            source: record.source,
            updatedAt: record.updatedAt,
            accessCount: record.accessCount
        )
    }

    private func bumpAccessCounts(for ids: [UUID]) {
        guard let context else { return }
        guard !ids.isEmpty else { return }

        switch storageMode {
        case .legacyV3:
            do {
                let memories = try context.fetch(FetchDescriptor<CaptainMemory>())
                let idSet = Set(ids)
                for memory in memories where idSet.contains(memory.id) {
                    memory.accessCount += 1
                }
                Task { @MainActor in
                    try? context.save()
                }
            } catch {
                logger.error("memory_store_access_bump_error error=\(error.localizedDescription)")
            }
        case .schemaV4:
            do {
                let facts = try context.fetch(FetchDescriptor<SemanticFact>())
                let idSet = Set(ids)
                for fact in facts where idSet.contains(fact.id) {
                    fact.referenceCount += 1
                    fact.lastReferencedAt = Date()
                }
                Task { @MainActor in
                    try? context.save()
                }
            } catch {
                logger.error("memory_store_access_bump_v4_error error=\(error.localizedDescription)")
            }
        }
    }

    private func persistMessageV4(_ chatMessage: ChatMessage, sessionID: UUID) throws {
        guard let context else { return }

        if chatMessage.isUser {
            let episode = EpisodicEntry(
                id: chatMessage.id,
                sessionID: sessionID,
                timestamp: chatMessage.timestamp,
                userMessageID: chatMessage.id,
                userMessage: chatMessage.text,
                captainResponse: "",
                salienceScore: 0.5
            )
            context.insert(episode)
            return
        }

        var descriptor = FetchDescriptor<EpisodicEntry>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 5
        let candidates = try context.fetch(descriptor)

        if let episode = candidates.first(where: {
            $0.captainResponseMessageID == nil && $0.captainResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            episode.captainResponse = chatMessage.text
            episode.captainResponseMessageID = chatMessage.id
            episode.captainResponseTimestamp = chatMessage.timestamp
            episode.setCaptainSpotifyRecommendation(chatMessage.spotifyRecommendation)
        } else {
            let episode = EpisodicEntry(
                id: chatMessage.id,
                sessionID: sessionID,
                timestamp: chatMessage.timestamp,
                captainResponseTimestamp: chatMessage.timestamp,
                userMessageID: UUID(),
                captainResponseMessageID: chatMessage.id,
                userMessage: "",
                captainResponse: chatMessage.text,
                captainSpotifyRecommendation: chatMessage.spotifyRecommendation,
                salienceScore: 0.5
            )
            context.insert(episode)
        }
    }

    private func messages(from episodes: [EpisodicEntry]) -> [ChatMessage] {
        let messages = episodes.flatMap { episode -> [ChatMessage] in
            var result: [ChatMessage] = []

            let userText = episode.userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            if !userText.isEmpty {
                result.append(
                    ChatMessage(
                        id: episode.userMessageID,
                        text: episode.userMessage,
                        isUser: true,
                        timestamp: episode.timestamp
                    )
                )
            }

            let captainText = episode.captainResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            if !captainText.isEmpty {
                result.append(
                    ChatMessage(
                        id: episode.captainResponseMessageID ?? episode.id,
                        text: episode.captainResponse,
                        isUser: false,
                        timestamp: episode.captainResponseTimestamp ?? episode.timestamp,
                        spotifyRecommendation: episode.captainSpotifyRecommendation
                    )
                )
            }

            return result
        }

        return messages.sorted { $0.timestamp < $1.timestamp }
    }

    private func messageCount(for episode: EpisodicEntry) -> Int {
        var count = 0
        if !episode.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            count += 1
        }
        if !episode.captainResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            count += 1
        }
        return count
    }

    private static func factCategory(for rawCategory: String) -> FactCategory {
        switch rawCategory.lowercased() {
        case "health", "health_condition", "body", "sleep", "injury", "nutrition":
            return .health
        case "preference":
            return .preference
        case "goal", "objective", "active_record_project":
            return .goal
        case "relationship", "family":
            return .relationship
        case "work", "career":
            return .work
        case "habit":
            return .habit
        case "aspiration":
            return .aspiration
        case "fear":
            return .fear
        case "accomplishment", "insight", "workout_history":
            return .accomplishment
        default:
            return .other
        }
    }

    private static func factSource(for rawSource: String) -> FactSource {
        switch rawSource.lowercased() {
        case "user_explicit", "explicit":
            return .explicit
        case "inferred":
            return .inferred
        default:
            return .extracted
        }
    }

    private static func isPII(key: String, category: String) -> Bool {
        let piiKeys: Set<String> = ["user_name", "weight", "height", "age"]
        return piiKeys.contains(key.lowercased()) || category.lowercased() == "identity"
    }

    private static func isSensitive(category: String) -> Bool {
        let sensitiveCategories: Set<String> = [
            "health",
            "health_condition",
            "mental_health",
            "medical",
            "body",
            "sleep",
            "injury"
        ]
        return sensitiveCategories.contains(category.lowercased())
    }

    // MARK: - Shadow Writes

    private func shadowWriteSemanticFact(
        key: String,
        value: String,
        category: String,
        source: String,
        confidence: Double,
        salience: Double,
        storageMode: StorageMode
    ) {
        guard FeatureFlags.memoryV4Enabled.value else { return }

        let factCategory = Self.factCategory(for: category)
        let factSource = Self.factSource(for: source)
        let isPII = Self.isPII(key: key, category: category)
        let isSensitive = Self.isSensitive(category: category)

        Task(priority: .utility) {
            _ = await SemanticStore.shared.syncFact(
                storageKey: key,
                content: value,
                category: factCategory,
                rawCategory: category,
                confidence: confidence,
                salience: salience,
                source: factSource,
                rawSource: source,
                isPII: isPII,
                isSensitive: isSensitive,
                incrementMentionCount: storageMode == .legacyV3
            )
        }
    }

    private func shadowRemoveSemanticFact(_ key: String) {
        guard FeatureFlags.memoryV4Enabled.value else { return }

        Task(priority: .utility) {
            await SemanticStore.shared.delete(storageKey: key)
        }
    }

    private func shadowClearSemanticFacts() {
        guard FeatureFlags.memoryV4Enabled.value else { return }

        Task(priority: .utility) {
            await SemanticStore.shared.deleteAll()
        }
    }

    private func shadowPruneSemanticFacts(olderThan cutoff: Date, belowConfidence threshold: Double) {
        guard FeatureFlags.memoryV4Enabled.value else { return }

        Task(priority: .utility) {
            _ = await SemanticStore.shared.pruneStale(
                olderThan: cutoff,
                belowConfidence: threshold
            )
        }
    }

    private func shadowRecordEpisode(from chatMessage: ChatMessage, sessionID: UUID) {
        guard FeatureFlags.memoryV4Enabled.value else { return }

        Task(priority: .utility) {
            let snapshots = await currentShadowSnapshots(for: chatMessage)
            _ = await EpisodicStore.shared.record(
                message: chatMessage,
                sessionID: sessionID,
                bioContext: snapshots.bio,
                emotionalContext: snapshots.emotional
            )
        }
    }

    private func currentShadowSnapshots(for chatMessage: ChatMessage) async -> (bio: BioSnapshot?, emotional: EmotionalSnapshot?) {
        let context = await CaptainContextBuilder.shared.buildContextData()
        let bio = BioSnapshot(
            timestamp: chatMessage.timestamp,
            stepsBucketed: max(0, context.steps),
            heartRateBucketed: context.heartRate,
            hrvBucketed: nil,
            sleepHoursBucketed: context.sleepHours > 0 ? context.sleepHours : nil,
            caloriesBucketed: max(0, context.calories),
            timeOfDay: Self.bioSnapshotTimeOfDay(from: context.bioPhase),
            dayOfWeek: Calendar.current.component(.weekday, from: chatMessage.timestamp),
            isFasting: false
        )

        guard let emotionalState = context.emotionalState else {
            return (bio, nil)
        }

        let emotional = EmotionalSnapshot(
            primaryMood: Self.emotionKind(for: emotionalState.estimatedMood),
            intensity: min(1, max(0.2, Double(emotionalState.signals.count) * 0.18)),
            confidence: emotionalState.confidence,
            signals: emotionalState.signals.map { MoodSignalSummary(kind: $0, value: 1) }
        )

        return (bio, emotional)
    }

    private static func bioSnapshotTimeOfDay(from phase: BioTimePhase) -> BioSnapshot.TimeOfDay {
        switch phase {
        case .awakening:
            return .morning
        case .energy:
            return .midday
        case .focus:
            return .afternoon
        case .recovery:
            return .evening
        case .zen:
            return .night
        }
    }

    private static func emotionKind(for mood: EstimatedMood) -> EmotionKind {
        switch mood {
        case .highEnergy:
            return .joy
        case .neutral:
            return .peace
        case .lowEnergy:
            return .contentment
        case .stressed:
            return .anxiety
        case .recovering:
            return .hope
        }
    }
}
