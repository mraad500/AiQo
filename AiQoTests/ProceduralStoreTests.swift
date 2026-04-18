import XCTest
import SwiftData
@testable import AiQo

@MainActor
final class ProceduralStoreTests: XCTestCase {

    func testUpsertReinforcesExistingPatternAndAppendsObservation() async throws {
        let store = try await makeStore()

        let firstID = await store.upsert(
            kind: .workoutTime,
            description: "Usually trains between 6am and 8am",
            observation: PatternObservation(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                numericValue: 6.5,
                textValue: "early"
            )
        )

        let secondID = await store.upsert(
            kind: .workoutTime,
            description: "Usually trains between 6am and 8am",
            observation: PatternObservation(
                timestamp: Date(timeIntervalSince1970: 1_700_100_000),
                numericValue: 7.0,
                textValue: "early"
            )
        )

        XCTAssertNotNil(firstID)
        XCTAssertEqual(firstID, secondID)

        let patterns = await store.patterns(minStrength: 0.0, limit: 10)
        XCTAssertEqual(patterns.count, 1)
        let pattern = try XCTUnwrap(patterns.first)
        XCTAssertEqual(pattern.observationCount, 2)
        XCTAssertEqual(pattern.observationLog.count, 2)
        XCTAssertGreaterThan(pattern.strength, 0.3)
        XCTAssertLessThanOrEqual(pattern.strength, 1.0)
    }

    func testRecordExceptionWeakensPatternAndClampsAtZero() async throws {
        let store = try await makeStore()

        _ = await store.upsert(
            kind: .sleepSchedule,
            description: "Sleeps before midnight",
            observation: PatternObservation()
        )

        for _ in 0..<10 {
            await store.recordException(for: .sleepSchedule)
        }

        let pattern = await store.pattern(kind: .sleepSchedule)
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.exceptionsCount, 10)
        XCTAssertGreaterThanOrEqual(pattern?.strength ?? -1, 0.0)
        XCTAssertLessThan(pattern?.strength ?? 1, 0.3)
    }

    func testPatternsFiltersByMinStrengthAndKind() async throws {
        let store = try await makeStore()

        _ = await store.upsert(
            kind: .workoutTime,
            description: "Morning workouts",
            observation: PatternObservation()
        )
        _ = await store.upsert(
            kind: .socialHours,
            description: "Evening social time",
            observation: PatternObservation()
        )

        let allLowBar = await store.patterns(minStrength: 0.0, limit: 10)
        XCTAssertEqual(allLowBar.count, 2)

        let highBar = await store.patterns(minStrength: 0.9, limit: 10)
        XCTAssertTrue(highBar.isEmpty)

        let filteredToWorkout = await store.patterns(
            minStrength: 0.0,
            kinds: [.workoutTime],
            limit: 10
        )
        XCTAssertEqual(filteredToWorkout.count, 1)
        XCTAssertEqual(filteredToWorkout.first?.kind, .workoutTime)
    }

    func testDeleteAllRemovesEverything() async throws {
        let store = try await makeStore()

        _ = await store.upsert(
            kind: .workoutTime,
            description: "test",
            observation: PatternObservation()
        )
        _ = await store.upsert(
            kind: .eatingWindow,
            description: "test",
            observation: PatternObservation()
        )

        await store.deleteAll()
        let count = await store.count()
        XCTAssertEqual(count, 0)
    }

    private func makeStore() async throws -> ProceduralStore {
        let container = try makeInMemoryContainer()
        let store = ProceduralStore()
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
