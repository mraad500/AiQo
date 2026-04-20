import Foundation
import SwiftData

nonisolated struct SemanticFactSnapshot: Identifiable, Sendable {
    let id: UUID
    let storageKey: String
    let content: String
    let category: FactCategory
    let categoryRaw: String
    let confidence: Double
    let salience: Double
    let source: FactSource
    let sourceRaw: String
    let firstMentionedAt: Date
    let lastConfirmedAt: Date
    let lastReferencedAt: Date?
    let mentionCount: Int
    let referenceCount: Int
    let relatedEntryIDs: [UUID]
    let isPII: Bool
    let isSensitive: Bool
    let userHidden: Bool
    let effectiveConfidence: Double
    let isCloudSafe: Bool

    init(fact: SemanticFact) {
        id = fact.id
        storageKey = fact.storageKey
        content = fact.content
        category = fact.category
        categoryRaw = fact.categoryRaw
        confidence = fact.confidence
        salience = fact.salience
        source = fact.source
        sourceRaw = fact.sourceRaw
        firstMentionedAt = fact.firstMentionedAt
        lastConfirmedAt = fact.lastConfirmedAt
        lastReferencedAt = fact.lastReferencedAt
        mentionCount = fact.mentionCount
        referenceCount = fact.referenceCount
        relatedEntryIDs = fact.relatedEntryIDs
        isPII = fact.isPII
        isSensitive = fact.isSensitive
        userHidden = fact.userHidden
        effectiveConfidence = fact.effectiveConfidence
        isCloudSafe = fact.isCloudSafe
    }
}

actor SemanticStore {
    static let shared = SemanticStore()

    private enum Constants {
        static let defaultFactLimit = 100
        static let protectedCategoryRaw = "active_record_project"
    }

    private var container: ModelContainer?
    private let nowProvider: @Sendable () -> Date
    private let factLimitProvider: @Sendable () async -> Int
    private let fetchLimitProvider: @Sendable (_ requested: Int, _ fallback: Int) async -> Int

    init(
        container: ModelContainer? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        factLimitProvider: @escaping @Sendable () async -> Int = {
            await TierGate.shared.memoryFactLimit()
        },
        fetchLimitProvider: @escaping @Sendable (_ requested: Int, _ fallback: Int) async -> Int = { requested, fallback in
            await TierGate.shared.cappedMemoryFetchLimit(requested: requested, fallback: fallback)
        }
    ) {
        self.container = container
        self.nowProvider = nowProvider
        self.factLimitProvider = factLimitProvider
        self.fetchLimitProvider = fetchLimitProvider
    }

    func configure(container: ModelContainer) async {
        self.container = container
        await logInfo("SemanticStore configured")
    }

    // MARK: - Add / Reinforce

    func addOrReinforce(
        content: String,
        category: FactCategory,
        confidence: Double,
        salience: Double = 0.5,
        source: FactSource,
        isPII: Bool = false,
        isSensitive: Bool = false,
        relatedEntryIDs: [UUID] = []
    ) async -> UUID? {
        let normalizedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedContent.isEmpty else {
            await logWarning("SemanticStore.addOrReinforce ignored empty content")
            return nil
        }

        guard let context = await makeContext() else { return nil }

        do {
            if let existing = try fetchExactMatch(
                content: normalizedContent,
                categoryRaw: category.rawValue,
                in: context
            ) {
                reinforce(
                    existing,
                    confidence: confidence,
                    salience: salience,
                    relatedEntryIDs: relatedEntryIDs,
                    isPII: isPII,
                    isSensitive: isSensitive
                )
                try context.save()
                return existing.id
            }

            let limit = await normalizedFactLimit()
            guard try await makeRoomIfNeeded(in: context, limit: limit) else { return nil }

            let now = nowProvider()
            let fact = SemanticFact(
                content: normalizedContent,
                category: category,
                confidence: clamp(confidence),
                salience: clamp(salience),
                source: source,
                firstMentionedAt: now,
                lastConfirmedAt: now,
                mentionCount: 1,
                referenceCount: 0,
                isPII: isPII,
                isSensitive: isSensitive
            )

            if !relatedEntryIDs.isEmpty {
                fact.setRelatedEntryIDs(Array(Set(relatedEntryIDs)).sorted { $0.uuidString < $1.uuidString })
            }

            context.insert(fact)
            try context.save()
            return fact.id
        } catch {
            await logError("SemanticStore.addOrReinforce failed", error: error)
            return nil
        }
    }

    func syncFact(
        storageKey: String,
        content: String,
        category: FactCategory,
        rawCategory: String,
        confidence: Double,
        salience: Double = 0.5,
        source: FactSource,
        rawSource: String,
        isPII: Bool = false,
        isSensitive: Bool = false,
        relatedEntryIDs: [UUID] = [],
        incrementMentionCount: Bool
    ) async -> UUID? {
        let normalizedKey = storageKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedKey.isEmpty, !normalizedContent.isEmpty else {
            await logWarning("SemanticStore.syncFact ignored empty storageKey/content")
            return nil
        }

        guard let context = await makeContext() else { return nil }

        do {
            if let existing = try fetchByStorageKey(normalizedKey, in: context) {
                existing.content = normalizedContent
                existing.categoryRaw = rawCategory
                existing.confidence = clamp(confidence)
                existing.salience = max(existing.salience, clamp(salience))
                existing.lastConfirmedAt = nowProvider()
                existing.isPII = existing.isPII || isPII
                existing.isSensitive = existing.isSensitive || isSensitive

                if existing.sourceRaw != "user_explicit" || rawSource == "user_explicit" {
                    existing.sourceRaw = rawSource
                }

                if incrementMentionCount {
                    existing.mentionCount += 1
                } else {
                    existing.mentionCount = max(existing.mentionCount, 1)
                }

                if !relatedEntryIDs.isEmpty {
                    existing.setRelatedEntryIDs(mergedUUIDs(existing.relatedEntryIDs, relatedEntryIDs))
                }

                try context.save()
                return existing.id
            }

            let limit = await normalizedFactLimit()
            guard try await makeRoomIfNeeded(in: context, limit: limit) else { return nil }

            let now = nowProvider()
            let fact = SemanticFact(
                storageKey: normalizedKey,
                content: normalizedContent,
                category: category,
                categoryRawOverride: rawCategory,
                confidence: clamp(confidence),
                salience: clamp(salience),
                source: source,
                sourceRawOverride: rawSource,
                firstMentionedAt: now,
                lastConfirmedAt: now,
                mentionCount: 1,
                referenceCount: 0,
                isPII: isPII,
                isSensitive: isSensitive
            )

            if !relatedEntryIDs.isEmpty {
                fact.setRelatedEntryIDs(Array(Set(relatedEntryIDs)).sorted { $0.uuidString < $1.uuidString })
            }

            context.insert(fact)
            try context.save()
            return fact.id
        } catch {
            await logError("SemanticStore.syncFact failed", error: error)
            return nil
        }
    }

    // MARK: - Read

    func all(
        minConfidence: Double = 0,
        includeHidden: Bool = false,
        limit: Int = Constants.defaultFactLimit
    ) async -> [SemanticFactSnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            let includeHiddenValue = includeHidden
            var descriptor = FetchDescriptor<SemanticFact>(
                predicate: #Predicate<SemanticFact> {
                    $0.confidence >= minConfidence && (includeHiddenValue || $0.userHidden == false)
                },
                sortBy: [SortDescriptor(\.confidence, order: .reverse)]
            )
            descriptor.fetchLimit = await cappedLimit(limit, fallback: Constants.defaultFactLimit)
            return try context.fetch(descriptor).map { SemanticFactSnapshot(fact: $0) }
        } catch {
            await logError("SemanticStore.all failed", error: error)
            return []
        }
    }

    func facts(
        in category: FactCategory,
        minConfidence: Double = 0.5,
        limit: Int = Constants.defaultFactLimit
    ) async -> [SemanticFactSnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            let rawCategory = category.rawValue
            var descriptor = FetchDescriptor<SemanticFact>(
                predicate: #Predicate<SemanticFact> {
                    $0.categoryRaw == rawCategory &&
                    $0.confidence >= minConfidence &&
                    $0.userHidden == false
                },
                sortBy: [SortDescriptor(\.confidence, order: .reverse)]
            )
            descriptor.fetchLimit = await cappedLimit(limit, fallback: Constants.defaultFactLimit)
            return try context.fetch(descriptor).map { SemanticFactSnapshot(fact: $0) }
        } catch {
            await logError("SemanticStore.facts(in:) failed", error: error)
            return []
        }
    }

    func factsNotReferencedFor(
        days: Int,
        minConfidence: Double = 0.7,
        limit: Int = Constants.defaultFactLimit
    ) async -> [SemanticFactSnapshot] {
        guard let context = await makeContext() else { return [] }

        let capped = await cappedLimit(limit, fallback: Constants.defaultFactLimit)
        let cutoff = nowProvider().addingTimeInterval(-Double(max(days, 0)) * 86_400)

        do {
            var descriptor = FetchDescriptor<SemanticFact>(
                predicate: #Predicate<SemanticFact> {
                    $0.confidence >= minConfidence && $0.userHidden == false
                },
                sortBy: [SortDescriptor(\.lastConfirmedAt, order: .forward)]
            )
            descriptor.fetchLimit = capped

            return try context.fetch(descriptor)
                .filter { fact in
                    guard let lastReferencedAt = fact.lastReferencedAt else { return true }
                    return lastReferencedAt < cutoff
                }
                .prefix(capped)
                .map { SemanticFactSnapshot(fact: $0) }
        } catch {
            await logError("SemanticStore.factsNotReferencedFor failed", error: error)
            return []
        }
    }

    func fact(id: UUID) async -> SemanticFactSnapshot? {
        guard let context = await makeContext() else { return nil }

        do {
            return try fetchFact(id: id, in: context).map { SemanticFactSnapshot(fact: $0) }
        } catch {
            await logError("SemanticStore.fact(id:) failed", error: error)
            return nil
        }
    }

    func count() async -> Int {
        guard let context = await makeContext() else { return 0 }

        do {
            return try context.fetchCount(FetchDescriptor<SemanticFact>())
        } catch {
            await logError("SemanticStore.count failed", error: error)
            return 0
        }
    }

    func cloudSafeFacts(limit: Int) async -> [SemanticFactSnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            var descriptor = FetchDescriptor<SemanticFact>(
                predicate: #Predicate<SemanticFact> {
                    $0.isPII == false &&
                    $0.isSensitive == false &&
                    $0.userHidden == false &&
                    $0.confidence >= 0.6
                },
                sortBy: [SortDescriptor(\.salience, order: .reverse)]
            )
            descriptor.fetchLimit = await cappedLimit(limit, fallback: Constants.defaultFactLimit)
            return try context.fetch(descriptor).map { SemanticFactSnapshot(fact: $0) }
        } catch {
            await logError("SemanticStore.cloudSafeFacts failed", error: error)
            return []
        }
    }

    // MARK: - Update

    func markReferenced(_ id: UUID) async {
        guard let context = await makeContext() else { return }

        do {
            guard let fact = try fetchFact(id: id, in: context) else { return }
            fact.lastReferencedAt = nowProvider()
            fact.referenceCount += 1
            try context.save()
        } catch {
            await logError("SemanticStore.markReferenced failed", error: error)
        }
    }

    func updateConfidence(_ id: UUID, to newConfidence: Double) async {
        guard let context = await makeContext() else { return }

        do {
            guard let fact = try fetchFact(id: id, in: context) else { return }
            fact.confidence = clamp(newConfidence)
            try context.save()
        } catch {
            await logError("SemanticStore.updateConfidence failed", error: error)
        }
    }

    func setUserHidden(_ id: UUID, hidden: Bool) async {
        guard let context = await makeContext() else { return }

        do {
            guard let fact = try fetchFact(id: id, in: context) else { return }
            fact.userHidden = hidden
            try context.save()
        } catch {
            await logError("SemanticStore.setUserHidden failed", error: error)
        }
    }

    // MARK: - Delete / Decay

    func delete(_ id: UUID) async {
        guard let context = await makeContext() else { return }

        do {
            guard let fact = try fetchFact(id: id, in: context) else { return }
            context.delete(fact)
            try context.save()
        } catch {
            await logError("SemanticStore.delete(id:) failed", error: error)
        }
    }

    func delete(storageKey: String) async {
        guard let context = await makeContext() else { return }

        do {
            guard let fact = try fetchByStorageKey(storageKey, in: context) else { return }
            context.delete(fact)
            try context.save()
        } catch {
            await logError("SemanticStore.delete(storageKey:) failed", error: error)
        }
    }

    func deleteAll() async {
        guard let context = await makeContext() else { return }

        do {
            let fetchLimit = await normalizedFactLimit()
            var descriptor = FetchDescriptor<SemanticFact>(
                sortBy: [SortDescriptor(\.lastConfirmedAt, order: .forward)]
            )
            descriptor.fetchLimit = fetchLimit

            let allFacts = try context.fetch(descriptor)
            for fact in allFacts {
                context.delete(fact)
            }

            if !allFacts.isEmpty {
                try context.save()
            }
        } catch {
            await logError("SemanticStore.deleteAll failed", error: error)
        }
    }

    func applyDecay() async {
        guard let context = await makeContext() else { return }

        do {
            let fetchLimit = await normalizedFactLimit()
            var descriptor = FetchDescriptor<SemanticFact>(
                sortBy: [SortDescriptor(\.lastConfirmedAt, order: .forward)]
            )
            descriptor.fetchLimit = fetchLimit

            let allFacts = try context.fetch(descriptor)
            guard !allFacts.isEmpty else { return }

            for fact in allFacts {
                fact.confidence = clamp(fact.effectiveConfidence)
            }

            try context.save()
        } catch {
            await logError("SemanticStore.applyDecay failed", error: error)
        }
    }

    func pruneStale(
        olderThan cutoff: Date,
        belowConfidence threshold: Double = 0.3,
        excludedCategoryRaw: Set<String> = [Constants.protectedCategoryRaw]
    ) async -> Int {
        guard let context = await makeContext() else { return 0 }

        do {
            let fetchLimit = await normalizedFactLimit()
            var descriptor = FetchDescriptor<SemanticFact>(
                predicate: #Predicate<SemanticFact> { $0.lastConfirmedAt < cutoff },
                sortBy: [SortDescriptor(\.lastConfirmedAt, order: .forward)]
            )
            descriptor.fetchLimit = fetchLimit

            let candidates = try context.fetch(descriptor)
            let deletable = candidates.filter {
                $0.confidence < threshold && !excludedCategoryRaw.contains($0.categoryRaw)
            }

            guard !deletable.isEmpty else { return 0 }

            for fact in deletable {
                context.delete(fact)
            }

            try context.save()
            return deletable.count
        } catch {
            await logError("SemanticStore.pruneStale failed", error: error)
            return 0
        }
    }

    // MARK: - Private

    private func makeContext() async -> ModelContext? {
        guard let container else {
            await logWarning("SemanticStore used before configure(container:)")
            return nil
        }

        return ModelContext(container)
    }

    private func cappedLimit(_ requested: Int, fallback: Int) async -> Int {
        await fetchLimitProvider(requested, fallback)
    }

    private func normalizedFactLimit() async -> Int {
        max(1, await factLimitProvider())
    }

    private func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private func mergedUUIDs(_ lhs: [UUID], _ rhs: [UUID]) -> [UUID] {
        Array(Set(lhs).union(rhs)).sorted { $0.uuidString < $1.uuidString }
    }

    private func reinforce(
        _ fact: SemanticFact,
        confidence: Double,
        salience: Double,
        relatedEntryIDs: [UUID],
        isPII: Bool,
        isSensitive: Bool
    ) {
        fact.confidence = min(1, max(fact.confidence, clamp(confidence)) + 0.05)
        fact.salience = max(fact.salience, clamp(salience))
        fact.lastConfirmedAt = nowProvider()
        fact.mentionCount += 1
        fact.isPII = fact.isPII || isPII
        fact.isSensitive = fact.isSensitive || isSensitive

        if !relatedEntryIDs.isEmpty {
            fact.setRelatedEntryIDs(mergedUUIDs(fact.relatedEntryIDs, relatedEntryIDs))
        }
    }

    private func makeRoomIfNeeded(in context: ModelContext, limit: Int) async throws -> Bool {
        let currentCount = try context.fetchCount(FetchDescriptor<SemanticFact>())
        guard currentCount >= limit else { return true }

        var descriptor = FetchDescriptor<SemanticFact>(
            sortBy: [SortDescriptor(\.confidence, order: .forward)]
        )
        descriptor.fetchLimit = limit

        let candidates = try context.fetch(descriptor)
        guard let lowest = candidates.first(where: { $0.categoryRaw != Constants.protectedCategoryRaw }) else {
            await logWarning("SemanticStore could not evict a fact because all facts are protected")
            return false
        }

        context.delete(lowest)
        try context.save()
        await logInfo("SemanticStore evicted 1 fact to honor tier limit \(limit)")
        return true
    }

    private func fetchFact(id: UUID, in context: ModelContext) throws -> SemanticFact? {
        var descriptor = FetchDescriptor<SemanticFact>(
            predicate: #Predicate<SemanticFact> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchByStorageKey(_ storageKey: String, in context: ModelContext) throws -> SemanticFact? {
        var descriptor = FetchDescriptor<SemanticFact>(
            predicate: #Predicate<SemanticFact> { $0.storageKey == storageKey }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchExactMatch(
        content: String,
        categoryRaw: String,
        in context: ModelContext
    ) throws -> SemanticFact? {
        var descriptor = FetchDescriptor<SemanticFact>(
            predicate: #Predicate<SemanticFact> {
                $0.content == content && $0.categoryRaw == categoryRaw
            }
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
