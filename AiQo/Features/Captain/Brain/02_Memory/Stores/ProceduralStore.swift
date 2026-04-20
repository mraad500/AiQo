import Foundation
import SwiftData

nonisolated struct PatternObservation: Codable, Sendable {
    let timestamp: Date
    let numericValue: Double?
    let textValue: String?
    let bioSnapshot: BioSnapshot?

    init(
        timestamp: Date = Date(),
        numericValue: Double? = nil,
        textValue: String? = nil,
        bioSnapshot: BioSnapshot? = nil
    ) {
        self.timestamp = timestamp
        self.numericValue = numericValue
        self.textValue = textValue
        self.bioSnapshot = bioSnapshot
    }
}

nonisolated struct ProceduralPatternSnapshot: Identifiable, Sendable {
    let id: UUID
    let kind: PatternKind
    let kindRaw: String
    let patternDescription: String
    let strength: Double
    let observationCount: Int
    let firstObservedAt: Date
    let lastObservedAt: Date
    let exceptionsCount: Int
    let observationLog: [PatternObservation]

    init(pattern: ProceduralPattern) {
        id = pattern.id
        kind = pattern.kind
        kindRaw = pattern.kindRaw
        patternDescription = pattern.patternDescription
        strength = pattern.strength
        observationCount = pattern.observationCount
        firstObservedAt = pattern.firstObservedAt
        lastObservedAt = pattern.lastObservedAt
        exceptionsCount = pattern.exceptionsCount
        observationLog = pattern.observationLog ?? []
    }
}

actor ProceduralStore {
    static let shared = ProceduralStore()

    private enum Constants {
        static let defaultFetchLimit = 50
        static let maxObservationLog = 100
        static let reinforceDelta = 0.02
        static let exceptionDelta = 0.05
        static let initialStrength = 0.3
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
        await logInfo("ProceduralStore configured")
    }

    // MARK: - Upsert / Reinforce

    func upsert(
        kind: PatternKind,
        description: String,
        observation: PatternObservation
    ) async -> UUID? {
        guard let context = await makeContext() else { return nil }

        let kindRaw = kind.rawValue
        let now = nowProvider()

        do {
            if let existing = try fetchByKind(kindRaw, in: context) {
                existing.observationCount += 1
                existing.lastObservedAt = now
                existing.strength = clamp(existing.strength + Constants.reinforceDelta)

                var log = existing.observationLog ?? []
                if log.count < Constants.maxObservationLog {
                    log.append(observation)
                    existing.contextualDataJSON = try? JSONEncoder().encode(log)
                }

                try context.save()
                return existing.id
            }

            let pattern = ProceduralPattern(
                kind: kind,
                description: description,
                strength: Constants.initialStrength,
                firstObservedAt: now
            )
            pattern.contextualDataJSON = try? JSONEncoder().encode([observation])
            context.insert(pattern)
            try context.save()
            return pattern.id
        } catch {
            await logError("ProceduralStore.upsert failed", error: error)
            return nil
        }
    }

    func recordException(for kind: PatternKind) async {
        guard let context = await makeContext() else { return }

        do {
            guard let pattern = try fetchByKind(kind.rawValue, in: context) else { return }
            pattern.exceptionsCount += 1
            pattern.strength = clamp(pattern.strength - Constants.exceptionDelta)
            try context.save()
        } catch {
            await logError("ProceduralStore.recordException failed", error: error)
        }
    }

    // MARK: - Read

    func patterns(
        minStrength: Double = 0.5,
        kinds: [PatternKind]? = nil,
        limit: Int = Constants.defaultFetchLimit
    ) async -> [ProceduralPatternSnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            var descriptor = FetchDescriptor<ProceduralPattern>(
                predicate: #Predicate<ProceduralPattern> { $0.strength >= minStrength },
                sortBy: [SortDescriptor(\.strength, order: .reverse)]
            )
            descriptor.fetchLimit = max(1, limit)

            var results = try context.fetch(descriptor)
            if let kinds {
                let rawKinds = Set(kinds.map { $0.rawValue })
                results = results.filter { rawKinds.contains($0.kindRaw) }
            }
            return results.map { ProceduralPatternSnapshot(pattern: $0) }
        } catch {
            await logError("ProceduralStore.patterns failed", error: error)
            return []
        }
    }

    func pattern(kind: PatternKind) async -> ProceduralPatternSnapshot? {
        guard let context = await makeContext() else { return nil }

        do {
            guard let pattern = try fetchByKind(kind.rawValue, in: context) else { return nil }
            return ProceduralPatternSnapshot(pattern: pattern)
        } catch {
            await logError("ProceduralStore.pattern failed", error: error)
            return nil
        }
    }

    func count() async -> Int {
        guard let context = await makeContext() else { return 0 }

        do {
            return try context.fetchCount(FetchDescriptor<ProceduralPattern>())
        } catch {
            await logError("ProceduralStore.count failed", error: error)
            return 0
        }
    }

    // MARK: - Delete

    func deleteAll() async {
        guard let context = await makeContext() else { return }

        do {
            let all = try context.fetch(FetchDescriptor<ProceduralPattern>())
            for pattern in all {
                context.delete(pattern)
            }
            try context.save()
        } catch {
            await logError("ProceduralStore.deleteAll failed", error: error)
        }
    }

    // MARK: - Helpers

    private func makeContext() async -> ModelContext? {
        guard let container else {
            await logWarning("ProceduralStore used before configure(container:)")
            return nil
        }
        return ModelContext(container)
    }

    private func fetchByKind(_ kindRaw: String, in context: ModelContext) throws -> ProceduralPattern? {
        var descriptor = FetchDescriptor<ProceduralPattern>(
            predicate: #Predicate<ProceduralPattern> { $0.kindRaw == kindRaw }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func clamp(_ value: Double) -> Double {
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

extension ProceduralPattern {
    var observationLog: [PatternObservation]? {
        guard let contextualDataJSON else { return nil }
        return try? JSONDecoder().decode([PatternObservation].self, from: contextualDataJSON)
    }
}
