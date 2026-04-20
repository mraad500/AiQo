import XCTest
import SwiftData
@testable import AiQo

@MainActor
final class RelationshipStoreTests: XCTestCase {

    func testUpsertCreatesThenReinforces() async throws {
        let store = try await makeStore()

        let firstID = await store.upsert(name: "Ali", kind: .friend, sentimentDelta: 0.4)
        let secondID = await store.upsert(name: "Ali", kind: .friend, sentimentDelta: 0.4)

        XCTAssertNotNil(firstID)
        XCTAssertEqual(firstID, secondID)

        let all = await store.all(limit: 10)
        XCTAssertEqual(all.count, 1)
        let relationship = try XCTUnwrap(all.first)
        XCTAssertGreaterThan(relationship.emotionalWeight, 0.5)
        XCTAssertGreaterThan(relationship.sentiment, 0.0)
        XCTAssertLessThanOrEqual(relationship.sentiment, 1.0)
    }

    func testSentimentIsClampedBetweenNegativeOneAndOne() async throws {
        let store = try await makeStore()

        _ = await store.upsert(name: "Noor", kind: .sibling, sentimentDelta: 5.0)
        for _ in 0..<30 {
            _ = await store.upsert(name: "Noor", kind: .sibling, sentimentDelta: 5.0)
        }

        let all = await store.all(limit: 10)
        let noor = try XCTUnwrap(all.first { $0.name == "Noor" })
        XCTAssertLessThanOrEqual(noor.sentiment, 1.0)
        XCTAssertGreaterThanOrEqual(noor.sentiment, -1.0)

        for _ in 0..<60 {
            _ = await store.upsert(name: "Noor", kind: .sibling, sentimentDelta: -5.0)
        }

        let afterNegative = await store.all(limit: 10)
        let negative = try XCTUnwrap(afterNegative.first { $0.name == "Noor" })
        XCTAssertGreaterThanOrEqual(negative.sentiment, -1.0)
        XCTAssertLessThanOrEqual(negative.sentiment, 1.0)
    }

    func testRecentlyMentionedMatchesNameInText() async throws {
        let store = try await makeStore()

        _ = await store.upsert(name: "Ali", kind: .friend)
        _ = await store.upsert(name: "Sara", kind: .colleague)
        _ = await store.upsert(name: "Omar", kind: .mentor)

        let mentions = await store.recentlyMentioned(
            in: "I met Ali today and had coffee with Sara",
            within: 90
        )

        XCTAssertEqual(Set(mentions.map { $0.name }), ["Ali", "Sara"])
    }

    func testDeleteAllRemovesEverything() async throws {
        let store = try await makeStore()
        _ = await store.upsert(name: "Ali", kind: .friend)
        _ = await store.upsert(name: "Sara", kind: .colleague)
        await store.deleteAll()
        let count = await store.count()
        XCTAssertEqual(count, 0)
    }

    private func makeStore(now: Date = Date()) async throws -> RelationshipStore {
        let container = try makeInMemoryContainer()
        let store = RelationshipStore(nowProvider: { now })
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
