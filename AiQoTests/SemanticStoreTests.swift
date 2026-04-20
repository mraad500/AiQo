import XCTest
import SwiftData
@testable import AiQo

@MainActor
final class SemanticStoreTests: XCTestCase {

    func testAddOrReinforceAndFetchByCategory() async throws {
        let store = try await makeStore(limit: 10)

        let firstID = await store.addOrReinforce(
            content: "User likes early workouts",
            category: .preference,
            confidence: 0.7,
            source: .explicit
        )
        let secondID = await store.addOrReinforce(
            content: "User likes early workouts",
            category: .preference,
            confidence: 0.7,
            source: .explicit
        )

        XCTAssertNotNil(firstID)
        XCTAssertEqual(firstID, secondID)
        let count = await store.count()
        XCTAssertEqual(count, 1)

        let facts = await store.facts(in: .preference, minConfidence: 0.5, limit: 10)
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts.first?.mentionCount, 2)
        XCTAssertGreaterThanOrEqual(facts.first?.confidence ?? 0, 0.75)
    }

    func testTierLimitEvictsLowestConfidenceFact() async throws {
        let store = try await makeStore(limit: 3)

        _ = await store.addOrReinforce(content: "fact-a", category: .goal, confidence: 0.2, source: .explicit)
        _ = await store.addOrReinforce(content: "fact-b", category: .goal, confidence: 0.8, source: .explicit)
        _ = await store.addOrReinforce(content: "fact-c", category: .goal, confidence: 0.6, source: .explicit)
        _ = await store.addOrReinforce(content: "fact-d", category: .goal, confidence: 0.9, source: .explicit)

        let facts = await store.all(limit: 10)
        XCTAssertEqual(facts.count, 3)
        XCTAssertFalse(facts.contains(where: { $0.content == "fact-a" }))
    }

    func testApplyDecayReducesConfidenceForOldFacts() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let oldFact = SemanticFact(
            storageKey: "old_fact",
            content: "Old fact",
            category: .health,
            confidence: 1.0,
            source: .explicit,
            firstMentionedAt: Date().addingTimeInterval(-120 * 86_400),
            lastConfirmedAt: Date().addingTimeInterval(-120 * 86_400)
        )
        context.insert(oldFact)
        try context.save()

        let store = SemanticStore(
            factLimitProvider: { 10 },
            fetchLimitProvider: { requested, fallback in
                max(1, requested > 0 ? requested : fallback)
            }
        )
        await store.configure(container: container)
        await store.applyDecay()

        let facts = await store.all(limit: 10)
        XCTAssertEqual(facts.count, 1)
        XCTAssertLessThan(facts[0].confidence, 1.0)
    }

    func testMarkReferencedHideAndDelete() async throws {
        let store = try await makeStore(limit: 10)
        let factID = await store.addOrReinforce(
            content: "Prefers evening walks",
            category: .habit,
            confidence: 0.8,
            source: .inferred
        )

        XCTAssertNotNil(factID)

        await store.markReferenced(factID!)
        await store.setUserHidden(factID!, hidden: true)

        let visibleHabitFacts = await store.facts(in: .habit, minConfidence: 0.5, limit: 10)
        let allFacts = await store.all(includeHidden: true, limit: 10)
        XCTAssertEqual(visibleHabitFacts.count, 0)
        XCTAssertEqual(allFacts.first?.referenceCount, 1)

        await store.delete(factID!)
        let remainingCount = await store.count()
        XCTAssertEqual(remainingCount, 0)
    }

    private func makeStore(limit: Int) async throws -> SemanticStore {
        let container = try makeInMemoryContainer()
        let store = SemanticStore(
            factLimitProvider: { limit },
            fetchLimitProvider: { requested, fallback in
                max(1, requested > 0 ? requested : fallback)
            }
        )
        await store.configure(container: container)
        return store
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: MemorySchemaV4.self),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }
}
