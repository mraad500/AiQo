import Foundation
import SwiftData

/// Durable store for user-taught standing instructions (`LearnedDirective`).
///
/// Mirrors `ProceduralStore`'s actor/persistence conventions exactly: a single
/// shared actor, a per-call `ModelContext`, `#Predicate` fetches, graceful
/// no-op when used before `configure(container:)` (so the V3 fallback path —
/// which has no V5 store — degrades silently instead of crashing).
actor DirectiveStore {
    static let shared = DirectiveStore()

    private enum Constants {
        static let defaultFetchLimit = 50
        /// Hard ceiling so a user can't accumulate an unbounded rule set that
        /// would bloat the prompt. Oldest disabled directive is evicted first.
        static let maxDirectives = 40
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
        await logInfo("DirectiveStore configured")
    }

    // MARK: - Upsert

    /// Persists a learned directive. If an enabled directive with the same
    /// trigger+action already exists, it is refreshed in place (re-teaching the
    /// same rule updates wording instead of piling up duplicates) and its id
    /// returned. Otherwise a new directive is inserted.
    @discardableResult
    func upsert(draft: LearnedDirectiveDraft) async -> UUID? {
        guard let context = await makeContext() else { return nil }

        let triggerRaw = draft.trigger.rawValue
        let actionRaw = draft.action.rawValue
        let now = nowProvider()

        do {
            if let existing = try fetchByTriggerAction(
                triggerRaw: triggerRaw,
                actionRaw: actionRaw,
                in: context
            ) {
                existing.rawInstruction = draft.rawInstruction
                existing.paramsJSON = encodeParams(draft.params)
                existing.localeCode = draft.localeCode
                existing.isEnabled = true
                existing.updatedAt = now
                try context.save()
                await logInfo("DirectiveStore refreshed directive trigger=\(triggerRaw) action=\(actionRaw)")
                return existing.id
            }

            try evictIfAtCapacity(in: context)

            let directive = LearnedDirective(
                rawInstruction: draft.rawInstruction,
                triggerRaw: triggerRaw,
                actionRaw: actionRaw,
                paramsJSON: encodeParams(draft.params),
                createdAt: now,
                localeCode: draft.localeCode
            )
            context.insert(directive)
            try context.save()
            await logInfo("DirectiveStore inserted directive trigger=\(triggerRaw) action=\(actionRaw)")
            return directive.id
        } catch {
            await logError("DirectiveStore.upsert failed", error: error)
            return nil
        }
    }

    // MARK: - Read

    func directives(
        trigger: DirectiveTrigger? = nil,
        enabledOnly: Bool = true,
        limit: Int = Constants.defaultFetchLimit
    ) async -> [LearnedDirectiveSnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            var descriptor = FetchDescriptor<LearnedDirective>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            descriptor.fetchLimit = max(1, limit)

            var results = try context.fetch(descriptor)
            if enabledOnly {
                results = results.filter { $0.isEnabled }
            }
            if let trigger {
                let triggerRaw = trigger.rawValue
                results = results.filter { $0.triggerRaw == triggerRaw }
            }
            return results.map { LearnedDirectiveSnapshot(directive: $0) }
        } catch {
            await logError("DirectiveStore.directives failed", error: error)
            return []
        }
    }

    /// All enabled directives — used to surface standing orders back into the
    /// prompt so the Captain never forgets what it was told to do.
    func activeDirectives() async -> [LearnedDirectiveSnapshot] {
        await directives(trigger: nil, enabledOnly: true, limit: Constants.maxDirectives)
    }

    func count() async -> Int {
        guard let context = await makeContext() else { return 0 }
        do {
            return try context.fetchCount(FetchDescriptor<LearnedDirective>())
        } catch {
            await logError("DirectiveStore.count failed", error: error)
            return 0
        }
    }

    // MARK: - Mutate

    func recordFired(id: UUID) async {
        guard let context = await makeContext() else { return }
        do {
            guard let directive = try fetchByID(id, in: context) else { return }
            directive.fireCount += 1
            directive.lastFiredAt = nowProvider()
            try context.save()
        } catch {
            await logError("DirectiveStore.recordFired failed", error: error)
        }
    }

    func setEnabled(id: UUID, enabled: Bool) async {
        guard let context = await makeContext() else { return }
        do {
            guard let directive = try fetchByID(id, in: context) else { return }
            directive.isEnabled = enabled
            directive.updatedAt = nowProvider()
            try context.save()
        } catch {
            await logError("DirectiveStore.setEnabled failed", error: error)
        }
    }

    // MARK: - Delete

    func delete(id: UUID) async {
        guard let context = await makeContext() else { return }
        do {
            guard let directive = try fetchByID(id, in: context) else { return }
            context.delete(directive)
            try context.save()
        } catch {
            await logError("DirectiveStore.delete failed", error: error)
        }
    }

    func deleteAll() async {
        guard let context = await makeContext() else { return }
        do {
            let all = try context.fetch(FetchDescriptor<LearnedDirective>())
            for directive in all {
                context.delete(directive)
            }
            try context.save()
        } catch {
            await logError("DirectiveStore.deleteAll failed", error: error)
        }
    }

    // MARK: - Helpers

    private func makeContext() async -> ModelContext? {
        guard let container else {
            await logWarning("DirectiveStore used before configure(container:)")
            return nil
        }
        return ModelContext(container)
    }

    private func fetchByID(_ id: UUID, in context: ModelContext) throws -> LearnedDirective? {
        var descriptor = FetchDescriptor<LearnedDirective>(
            predicate: #Predicate<LearnedDirective> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchByTriggerAction(
        triggerRaw: String,
        actionRaw: String,
        in context: ModelContext
    ) throws -> LearnedDirective? {
        var descriptor = FetchDescriptor<LearnedDirective>(
            predicate: #Predicate<LearnedDirective> {
                $0.triggerRaw == triggerRaw && $0.actionRaw == actionRaw
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Evicts the oldest disabled directive (or, if none disabled, the oldest
    /// directive) when at capacity, so inserts never exceed `maxDirectives`.
    private func evictIfAtCapacity(in context: ModelContext) throws {
        let total = try context.fetchCount(FetchDescriptor<LearnedDirective>())
        guard total >= Constants.maxDirectives else { return }

        let all = try context.fetch(
            FetchDescriptor<LearnedDirective>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        let victim = all.first(where: { !$0.isEnabled }) ?? all.first
        if let victim {
            context.delete(victim)
        }
    }

    private func encodeParams(_ params: [String: String]) -> Data? {
        guard !params.isEmpty else { return nil }
        return try? JSONEncoder().encode(params)
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
