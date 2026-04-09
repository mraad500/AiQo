import Foundation
import SwiftData
import os.log

/// مدير ذاكرة الكابتن حمّودي — يحفظ ويسترجع الذكريات عبر الجلسات
@MainActor
@Observable
final class MemoryStore {
    static let shared = MemoryStore()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AiQo", category: "MemoryStore")
    private var container: ModelContainer?
    private var context: ModelContext?
    private var promptContextCache: [Int: String] = [:]
    private var cloudSafeContextCache: [Int: String] = [:]
    private var persistedMessageWriteCount = 0
    private var maxMemories: Int {
        AccessManager.shared.captainMemoryLimit
    }

    /// هل ذاكرة الكابتن مفعّلة
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "captain_memory_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "captain_memory_enabled") }
    }

    private init() {
        // isEnabled defaults to true on first launch
        if UserDefaults.standard.object(forKey: "captain_memory_enabled") == nil {
            UserDefaults.standard.set(true, forKey: "captain_memory_enabled")
        }
    }

    /// ربط الـ ModelContainer — يُستدعى من نقطة الدخول
    func configure(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        invalidateMemoryContextCaches()
        persistedMessageWriteCount = 0
    }

    // MARK: - CRUD

    /// حفظ أو تحديث ذاكرة
    func set(_ key: String, value: String, category: String, source: String, confidence: Double = 0.7) {
        guard isEnabled, let context else { return }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.key == key }
            )
            let existing = try context.fetch(descriptor)

            if let memory = existing.first {
                memory.value = value
                memory.updatedAt = Date()
                memory.confidence = min(memory.confidence + 0.05, 1.0)
                if memory.source != "user_explicit" || source == "user_explicit" {
                    memory.source = source
                }
            } else {
                // تحقق من الحد الأقصى
                let countDescriptor = FetchDescriptor<CaptainMemory>()
                let count = (try? context.fetchCount(countDescriptor)) ?? 0
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
        } catch {
            logger.error("memory_store_set_error key=\(key) error=\(error.localizedDescription)")
        }
    }

    /// استرجاع قيمة بالمفتاح
    func get(_ key: String) -> String? {
        guard let context else { return nil }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.key == key }
            )
            return try context.fetch(descriptor).first?.value
        } catch {
            logger.error("memory_store_get_error key=\(key) error=\(error.localizedDescription)")
            return nil
        }
    }

    /// استرجاع كل الذكريات بتصنيف معين
    func getByCategory(_ category: String) -> [CaptainMemory] {
        guard let context else { return [] }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.category == category },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            logger.error("memory_store_category_error category=\(category) error=\(error.localizedDescription)")
            return []
        }
    }

    /// كل الذكريات مرتبة بالتصنيف
    func allMemories() -> [CaptainMemory] {
        guard let context else { return [] }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                sortBy: [SortDescriptor(\.category), SortDescriptor(\.updatedAt, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            logger.error("memory_store_all_error error=\(error.localizedDescription)")
            return []
        }
    }

    /// يرجّع الذكريات الأكثر صلة برسالة المستخدم الحالية بدل ضخ كل الذاكرة دفعة وحدة
    func retrieveRelevantMemories(
        for message: String,
        screenContext: ScreenContext,
        limit: Int = 8,
        allowedCategories: Set<String>? = nil
    ) -> [CaptainMemorySnapshot] {
        guard isEnabled, let context else { return [] }

        let intent = CaptainMessageIntent.detect(message: message, screenContext: screenContext)
        let messageTokens = CaptainCognitiveTextAnalyzer.tokens(from: message)

        do {
            let descriptor = FetchDescriptor<CaptainMemory>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            let memories = try context.fetch(descriptor)
            let filtered = memories.filter { memory in
                guard let allowedCategories else { return true }
                return allowedCategories.contains(memory.category)
            }

            let ranked = filtered
                .compactMap { memory -> (CaptainMemory, Double)? in
                    let score = relevanceScore(
                        for: memory,
                        messageTokens: messageTokens,
                        intent: intent,
                        screenContext: screenContext
                    )
                    guard score > 0 else { return nil }
                    return (memory, score)
                }
                .sorted { lhs, rhs in
                    if lhs.1 == rhs.1 {
                        return lhs.0.updatedAt > rhs.0.updatedAt
                    }
                    return lhs.1 > rhs.1
                }

            let selected = Array(ranked.prefix(limit))
            guard !selected.isEmpty else { return [] }

            selected.forEach { item in
                item.0.accessCount += 1
            }
            try? context.save()

            return selected.map { CaptainMemorySnapshot(memory: $0.0) }
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

    /// بناء سياق الذكريات للـ system prompt
    func buildPromptContext(maxTokens: Int = 800) -> String {
        guard isEnabled, let context else { return "" }
        if let cached = promptContextCache[maxTokens] {
            return cached
        }

        do {
            // جيب مشاريع نشطة أولاً (عددها قليل دايماً)
            var projectDescriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.category == "active_record_project" },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            projectDescriptor.fetchLimit = 5
            let projectMemories = try context.fetch(projectDescriptor)

            // جيب آخر 30 ذاكرة عامة — مرتبة بالثقة + الحداثة عبر SwiftData
            var otherDescriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.category != "active_record_project" },
                sortBy: [SortDescriptor(\.confidence, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
            )
            otherDescriptor.fetchLimit = 30
            let otherMemories = try context.fetch(otherDescriptor)

            var lines: [String] = []
            var estimatedTokens = 0

            for memory in projectMemories + otherMemories {
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

    /// Builds a privacy-safe memory context suitable for cloud (no PII, no exact measurements)
    func buildCloudSafeContext(maxTokens: Int = 400) -> String {
        guard isEnabled, let context else { return "" }
        if let cached = cloudSafeContextCache[maxTokens] {
            return cached
        }

        let cloudSafeCategories: Set<String> = ["goal", "preference", "mood", "injury", "nutrition", "insight"]

        do {
            var descriptor = FetchDescriptor<CaptainMemory>(
                sortBy: [SortDescriptor(\.confidence, order: .reverse), SortDescriptor(\.updatedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 40

            let allResults = try context.fetch(descriptor)
            let filtered = allResults.filter { cloudSafeCategories.contains($0.category) }
            let limited = Array(filtered.prefix(15))

            var lines: [String] = []
            var budget = maxTokens

            for memory in limited {
                let line = "- \(memory.key): \(memory.value)"
                let cost = line.count / 4
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

    /// تنظيف الذكريات القديمة واللي confidence قليل
    func removeStale(olderThan days: Int = 90, belowConfidence: Double = 0.3) {
        guard let context else { return }

        do {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
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
        } catch {
            logger.error("memory_store_cleanup_error error=\(error.localizedDescription)")
        }
    }

    /// حذف ذاكرة بالمفتاح
    func remove(_ key: String) {
        guard let context else { return }

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
        } catch {
            logger.error("memory_store_remove_error key=\(key) error=\(error.localizedDescription)")
        }
    }

    /// مسح كل الذاكرة
    func clearAll() {
        guard let context else { return }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>()
            let all = try context.fetch(descriptor)
            for memory in all {
                context.delete(memory)
            }
            try context.save()
            if !all.isEmpty {
                invalidateMemoryContextCaches()
            }
            logger.info("memory_store_clear_all")
        } catch {
            logger.error("memory_store_clear_error error=\(error.localizedDescription)")
        }
    }

    /// ملخص للـ debug
    func summary() -> String {
        guard let context else { return "MemoryStore: not configured" }

        do {
            let descriptor = FetchDescriptor<CaptainMemory>()
            let count = try context.fetchCount(descriptor)
            return "MemoryStore: \(count) memories, enabled=\(isEnabled)"
        } catch {
            return "MemoryStore: error reading count"
        }
    }

    // MARK: - Chat History Persistence

    private static let maxPersistedMessages = 200
    private static let trimCheckInterval = 12

    /// حفظ رسالة محادثة جديدة — يُستدعى فوراً عند الإرسال أو الاستقبال
    func persistMessage(_ chatMessage: ChatMessage, sessionID: UUID) {
        guard let context else { return }

        // تجاهل الرسائل المؤقتة (ephemeral) والفارغة
        guard !chatMessage.isEphemeral,
              !chatMessage.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        do {
            context.insert(PersistentChatMessage(chatMessage: chatMessage, sessionID: sessionID))
            try context.save()
            persistedMessageWriteCount += 1
            if persistedMessageWriteCount >= Self.trimCheckInterval {
                persistedMessageWriteCount = 0
                trimChatHistoryIfNeeded()
            }
        } catch {
            logger.error("chat_persist_error id=\(chatMessage.id) error=\(error.localizedDescription)")
        }
    }

    /// يؤجل حفظ الرسالة إلى دورة MainActor التالية حتى ما تتعطل الواجهة وقت الإرسال.
    func persistMessageAsync(_ chatMessage: ChatMessage, sessionID: UUID) {
        Task(priority: .utility) { @MainActor [chatMessage, sessionID] in
            self.persistMessage(chatMessage, sessionID: sessionID)
        }
    }

    /// استرجاع رسائل جلسة محددة مرتبة من الأقدم للأحدث
    func fetchMessages(for sessionID: UUID) -> [ChatMessage] {
        guard let context else { return [] }

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
    }

    /// استرجاع كل الجلسات مرتبة من الأحدث للأقدم — خفيف على الذاكرة
    func fetchSessions() -> [ChatSession] {
        guard let context else { return [] }

        do {
            // نجيب آخر 500 رسالة بس — كافي لعرض الجلسات الأخيرة بدون ما نثقل الذاكرة
            var descriptor = FetchDescriptor<PersistentChatMessage>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            descriptor.fetchLimit = 500

            // بدل ما نخزن كل الـ objects، نمر عليهم مرة وحدة ونجمع metadata بس
            struct SessionMeta {
                var firstTimestamp: Date
                var firstText: String
                var firstUserText: String?
                var count: Int
            }

            var metaMap: [UUID: SessionMeta] = [:]

            // نستخدم enumeration بدل fetch عشان ما نحمّل الكل بالذاكرة
            let messages = try context.fetch(descriptor)
            for msg in messages {
                if var meta = metaMap[msg.sessionID] {
                    meta.count += 1
                    if meta.firstUserText == nil && msg.isUser {
                        meta.firstUserText = msg.text
                    }
                    metaMap[msg.sessionID] = meta
                } else {
                    metaMap[msg.sessionID] = SessionMeta(
                        firstTimestamp: msg.timestamp,
                        firstText: msg.text,
                        firstUserText: msg.isUser ? msg.text : nil,
                        count: 1
                    )
                }
            }

            // بناء الجلسات — نتخطى الجلسات اللي فيها رسالة وحدة بس (الترحيبية)
            let sessions: [ChatSession] = metaMap.compactMap { sessionID, meta in
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

            return sessions.sorted { $0.timestamp > $1.timestamp }
        } catch {
            logger.error("chat_fetch_sessions_error error=\(error.localizedDescription)")
            return []
        }
    }

    /// مسح كل محادثات الكابتن
    func clearChatHistory() {
        guard let context else { return }

        do {
            let descriptor = FetchDescriptor<PersistentChatMessage>()
            let all = try context.fetch(descriptor)
            for msg in all {
                context.delete(msg)
            }
            try context.save()
            persistedMessageWriteCount = 0
            logger.info("chat_history_cleared count=\(all.count)")
        } catch {
            logger.error("chat_clear_error error=\(error.localizedDescription)")
        }
    }

    /// حذف الرسائل القديمة إذا تجاوزنا الحد الأقصى — "Zero Digital Pollution"
    private func trimChatHistoryIfNeeded() {
        guard let context else { return }

        do {
            let countDescriptor = FetchDescriptor<PersistentChatMessage>()
            let total = try context.fetchCount(countDescriptor)
            guard total > Self.maxPersistedMessages else { return }

            let excess = total - Self.maxPersistedMessages
            var oldestDescriptor = FetchDescriptor<PersistentChatMessage>(
                sortBy: [SortDescriptor(\.timestamp, order: .forward)]
            )
            oldestDescriptor.fetchLimit = excess

            let toDelete = try context.fetch(oldestDescriptor)
            for msg in toDelete {
                context.delete(msg)
            }
            try context.save()
            logger.info("chat_trim removed=\(toDelete.count) total_was=\(total)")
        } catch {
            logger.error("chat_trim_error error=\(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func invalidateMemoryContextCaches() {
        promptContextCache.removeAll()
        cloudSafeContextCache.removeAll()
    }

    func relevanceScore(
        for memory: CaptainMemory,
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

        var score = memory.confidence * 3.0
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
            score += 4.0
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
            return 4.0
        case (.workout, "goal"), (.nutrition, "goal"), (.challenge, "goal"):
            return 2.5
        case (.nutrition, "nutrition"):
            return 4.0
        case (.vibe, "mood"), (.emotionalSupport, "mood"):
            return 3.5
        case (.challenge, "active_record_project"):
            return 5.0
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
            case "goal", "preference", "insight": return 1.0
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
            return 1.0
        case ..<30:
            return 0.5
        default:
            return 0
        }
    }

    private func removeLowestConfidence() {
        guard let context else { return }

        do {
            var descriptor = FetchDescriptor<CaptainMemory>(
                predicate: #Predicate { $0.category != "active_record_project" },
                sortBy: [SortDescriptor(\.confidence)]
            )
            descriptor.fetchLimit = 1
            if let lowest = try context.fetch(descriptor).first {
                context.delete(lowest)
            }
        } catch {
            logger.error("memory_store_remove_lowest_error error=\(error.localizedDescription)")
        }
    }
}
