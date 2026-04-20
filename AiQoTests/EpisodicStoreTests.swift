import XCTest
import SwiftData
@testable import AiQo

@MainActor
final class EpisodicStoreTests: XCTestCase {

    func testRecordAndFetchRecentEntries() async throws {
        let store = try await makeStore()

        let firstID = await store.record(
            sessionID: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            userMessageID: UUID(),
            captainResponseMessageID: UUID(),
            userMessage: "Hello",
            captainResponse: "Hi there",
            initialSalience: 0.7
        )

        let secondID = await store.record(
            sessionID: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_700_000_100),
            userMessageID: UUID(),
            captainResponseMessageID: UUID(),
            userMessage: "Need a plan",
            captainResponse: "Let's build one",
            initialSalience: 0.9
        )

        XCTAssertNotNil(firstID)
        XCTAssertNotNil(secondID)

        let recent = await store.recentEntries(limit: 10)
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent.first?.userMessage, "Need a plan")
        XCTAssertEqual(recent.first?.captainResponse, "Let's build one")

        let salient = await store.entriesBySalience(min: 0.8, limit: 10)
        XCTAssertEqual(salient.map { $0.userMessage }, ["Need a plan"])
    }

    func testRecordMessagePairsUserAndCaptainReplies() async throws {
        let store = try await makeStore()
        let sessionID = UUID()
        let userMessage = ChatMessage(
            id: UUID(),
            text: "What's the move?",
            isUser: true,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let captainMessage = ChatMessage(
            id: UUID(),
            text: "Gym first, then protein.",
            isUser: false,
            timestamp: Date(timeIntervalSince1970: 1_700_000_030)
        )

        _ = await store.record(message: userMessage, sessionID: sessionID)
        _ = await store.record(message: captainMessage, sessionID: sessionID)

        let recent = await store.recentEntries(limit: 10)
        XCTAssertEqual(recent.count, 1)
        XCTAssertEqual(recent.first?.userMessage, "What's the move?")
        XCTAssertEqual(recent.first?.captainResponse, "Gym first, then protein.")
        XCTAssertEqual(recent.first?.captainResponseMessageID, captainMessage.id)
    }

    func testConcurrentWritesPreserveAllEntries() async throws {
        let store = try await makeStore()

        await withTaskGroup(of: UUID?.self) { group in
            for index in 0..<10 {
                group.addTask {
                    await store.record(
                        sessionID: UUID(),
                        timestamp: Date(timeIntervalSince1970: 1_700_000_000 + TimeInterval(index)),
                        userMessageID: UUID(),
                        captainResponseMessageID: UUID(),
                        userMessage: "User \(index)",
                        captainResponse: "Captain \(index)"
                    )
                }
            }

            for await _ in group {}
        }

        let count = await store.count()
        XCTAssertEqual(count, 10)
    }

    func testPruneRemovesOnlyOldConsolidatedEntries() async throws {
        let store = try await makeStore()
        let oldDate = Date(timeIntervalSince1970: 1_699_000_000)
        let newDate = Date(timeIntervalSince1970: 1_701_000_000)

        let oldID = await store.record(
            sessionID: UUID(),
            timestamp: oldDate,
            userMessageID: UUID(),
            captainResponseMessageID: UUID(),
            userMessage: "Old exchange",
            captainResponse: "Old response"
        )
        let recentID = await store.record(
            sessionID: UUID(),
            timestamp: newDate,
            userMessageID: UUID(),
            captainResponseMessageID: UUID(),
            userMessage: "Recent exchange",
            captainResponse: "Recent response"
        )

        XCTAssertNotNil(oldID)
        XCTAssertNotNil(recentID)

        await store.markConsolidated([oldID!], digest: "weekly")
        let pruned = await store.prune(
            olderThan: Date(timeIntervalSince1970: 1_700_000_000),
            onlyConsolidated: true
        )

        XCTAssertEqual(pruned, 1)
        let remainingCount = await store.count()
        let remainingEntries = await store.recentEntries(limit: 10)
        XCTAssertEqual(remainingCount, 1)
        XCTAssertEqual(remainingEntries.first?.userMessage, "Recent exchange")
    }

    private func makeStore() async throws -> EpisodicStore {
        let container = try makeInMemoryContainer()
        let store = EpisodicStore(
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
