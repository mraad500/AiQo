import Foundation
import SwiftData

nonisolated struct EmotionalMemorySnapshot: Identifiable, Sendable {
    let id: UUID
    let trigger: String
    let emotion: EmotionKind
    let emotionRaw: String
    let intensity: Double
    let date: Date
    let contextSnapshot: String
    let resolved: Bool
    let resolutionDate: Date?
    let associatedFactIDs: [UUID]
    let bioContext: BioSnapshot?

    init(entry: EmotionalMemory) {
        id = entry.id
        trigger = entry.trigger
        emotion = entry.emotion
        emotionRaw = entry.emotionRaw
        intensity = entry.intensity
        date = entry.date
        contextSnapshot = entry.contextSnapshot
        resolved = entry.resolved
        resolutionDate = entry.resolutionDate
        associatedFactIDs = entry.associatedFactIDs
        bioContext = entry.bioContext
    }
}

actor EmotionalStore {
    static let shared = EmotionalStore()

    private enum Constants {
        static let defaultFetchLimit = 50
        static let secondsPerDay: TimeInterval = 86_400
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
        await logInfo("EmotionalStore configured")
    }

    // MARK: - Record

    func record(
        trigger: String,
        emotion: EmotionKind,
        intensity: Double,
        contextSnapshot: String = "",
        associatedFactIDs: [UUID] = [],
        bioContext: BioSnapshot? = nil,
        date: Date? = nil
    ) async -> UUID? {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty else {
            await logWarning("EmotionalStore.record ignored empty trigger")
            return nil
        }

        guard let context = await makeContext() else { return nil }

        do {
            let entry = EmotionalMemory(
                trigger: trimmedTrigger,
                emotion: emotion,
                intensity: clampIntensity(intensity),
                date: date ?? nowProvider(),
                contextSnapshot: contextSnapshot
            )
            if !associatedFactIDs.isEmpty {
                entry.setAssociatedFactIDs(associatedFactIDs)
            }
            if let bioContext {
                entry.setBioContext(bioContext)
            }
            context.insert(entry)
            try context.save()
            return entry.id
        } catch {
            await logError("EmotionalStore.record failed", error: error)
            return nil
        }
    }

    // MARK: - Read

    func unresolvedEmotions(
        olderThan days: Int = 3,
        minIntensity: Double = 0.5,
        limit: Int = Constants.defaultFetchLimit
    ) async -> [EmotionalMemorySnapshot] {
        guard let context = await makeContext() else { return [] }

        let clampedDays = max(0, days)
        let clampedIntensity = clampIntensity(minIntensity)
        let cutoff = nowProvider().addingTimeInterval(-Double(clampedDays) * Constants.secondsPerDay)

        do {
            var descriptor = FetchDescriptor<EmotionalMemory>(
                predicate: #Predicate<EmotionalMemory> {
                    $0.resolved == false && $0.intensity >= clampedIntensity && $0.date <= cutoff
                },
                sortBy: [SortDescriptor(\.intensity, order: .reverse)]
            )
            descriptor.fetchLimit = max(1, limit)
            return try context.fetch(descriptor).map { EmotionalMemorySnapshot(entry: $0) }
        } catch {
            await logError("EmotionalStore.unresolvedEmotions failed", error: error)
            return []
        }
    }

    func emotions(
        kind: EmotionKind? = nil,
        since: Date? = nil,
        limit: Int = Constants.defaultFetchLimit
    ) async -> [EmotionalMemorySnapshot] {
        guard let context = await makeContext() else { return [] }

        do {
            var descriptor: FetchDescriptor<EmotionalMemory>

            if let kind, let since {
                let kindRaw = kind.rawValue
                descriptor = FetchDescriptor<EmotionalMemory>(
                    predicate: #Predicate<EmotionalMemory> {
                        $0.emotionRaw == kindRaw && $0.date >= since
                    }
                )
            } else if let kind {
                let kindRaw = kind.rawValue
                descriptor = FetchDescriptor<EmotionalMemory>(
                    predicate: #Predicate<EmotionalMemory> { $0.emotionRaw == kindRaw }
                )
            } else if let since {
                descriptor = FetchDescriptor<EmotionalMemory>(
                    predicate: #Predicate<EmotionalMemory> { $0.date >= since }
                )
            } else {
                descriptor = FetchDescriptor<EmotionalMemory>()
            }

            descriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
            descriptor.fetchLimit = max(1, limit)
            return try context.fetch(descriptor).map { EmotionalMemorySnapshot(entry: $0) }
        } catch {
            await logError("EmotionalStore.emotions failed", error: error)
            return []
        }
    }

    func count() async -> Int {
        guard let context = await makeContext() else { return 0 }

        do {
            return try context.fetchCount(FetchDescriptor<EmotionalMemory>())
        } catch {
            await logError("EmotionalStore.count failed", error: error)
            return 0
        }
    }

    // MARK: - Update

    func markResolved(_ id: UUID) async {
        guard let context = await makeContext() else { return }

        do {
            guard let entry = try fetchByID(id, in: context) else { return }
            entry.resolved = true
            entry.resolutionDate = nowProvider()
            try context.save()
        } catch {
            await logError("EmotionalStore.markResolved failed", error: error)
        }
    }

    // MARK: - Delete

    func deleteAll() async {
        guard let context = await makeContext() else { return }

        do {
            let all = try context.fetch(FetchDescriptor<EmotionalMemory>())
            for entry in all {
                context.delete(entry)
            }
            try context.save()
        } catch {
            await logError("EmotionalStore.deleteAll failed", error: error)
        }
    }

    // MARK: - Helpers

    private func makeContext() async -> ModelContext? {
        guard let container else {
            await logWarning("EmotionalStore used before configure(container:)")
            return nil
        }
        return ModelContext(container)
    }

    private func fetchByID(_ id: UUID, in context: ModelContext) throws -> EmotionalMemory? {
        var descriptor = FetchDescriptor<EmotionalMemory>(
            predicate: #Predicate<EmotionalMemory> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func clampIntensity(_ value: Double) -> Double {
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
