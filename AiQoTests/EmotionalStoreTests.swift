import XCTest
import SwiftData
@testable import AiQo

@MainActor
final class EmotionalStoreTests: XCTestCase {

    func testRecordAndFetchByKindAndSince() async throws {
        let store = try await makeStore()

        _ = await store.record(
            trigger: "Missed deadline",
            emotion: .frustration,
            intensity: 0.7,
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        _ = await store.record(
            trigger: "Family dinner",
            emotion: .joy,
            intensity: 0.8,
            date: Date(timeIntervalSince1970: 1_700_100_000)
        )
        _ = await store.record(
            trigger: "Late delivery",
            emotion: .frustration,
            intensity: 0.4,
            date: Date(timeIntervalSince1970: 1_700_200_000)
        )

        let frustrations = await store.emotions(kind: .frustration, limit: 10)
        XCTAssertEqual(frustrations.count, 2)
        XCTAssertEqual(frustrations.first?.trigger, "Late delivery")

        let sinceRecent = await store.emotions(
            since: Date(timeIntervalSince1970: 1_700_050_000),
            limit: 10
        )
        XCTAssertEqual(sinceRecent.count, 2)
    }

    func testUnresolvedEmotionsFiltersByAgeAndIntensity() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = try await makeStore(now: now)

        _ = await store.record(
            trigger: "Old unresolved heavy",
            emotion: .grief,
            intensity: 0.9,
            date: now.addingTimeInterval(-7 * 86_400)
        )
        _ = await store.record(
            trigger: "Old unresolved light",
            emotion: .anxiety,
            intensity: 0.3,
            date: now.addingTimeInterval(-7 * 86_400)
        )
        _ = await store.record(
            trigger: "Recent heavy",
            emotion: .grief,
            intensity: 0.9,
            date: now.addingTimeInterval(-86_400)
        )

        let unresolved = await store.unresolvedEmotions(olderThan: 3, minIntensity: 0.5)
        XCTAssertEqual(unresolved.count, 1)
        XCTAssertEqual(unresolved.first?.trigger, "Old unresolved heavy")
    }

    func testMarkResolvedRemovesFromUnresolvedFetch() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = try await makeStore(now: now)

        let id = await store.record(
            trigger: "Burnout",
            emotion: .frustration,
            intensity: 0.85,
            date: now.addingTimeInterval(-10 * 86_400)
        )

        XCTAssertNotNil(id)

        let before = await store.unresolvedEmotions(olderThan: 3, minIntensity: 0.5)
        XCTAssertEqual(before.count, 1)

        await store.markResolved(id!)

        let after = await store.unresolvedEmotions(olderThan: 3, minIntensity: 0.5)
        XCTAssertTrue(after.isEmpty)
    }

    func testDeleteAllRemovesEverything() async throws {
        let store = try await makeStore()
        _ = await store.record(trigger: "x", emotion: .hope, intensity: 0.5)
        _ = await store.record(trigger: "y", emotion: .peace, intensity: 0.5)
        await store.deleteAll()
        let count = await store.count()
        XCTAssertEqual(count, 0)
    }

    private func makeStore(now: Date = Date()) async throws -> EmotionalStore {
        let container = try makeInMemoryContainer()
        let store = EmotionalStore(nowProvider: { now })
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
