import XCTest
import SwiftData
@testable import AiQo

@MainActor
final class MemorySchemaV4Tests: XCTestCase {

    func testFreshV4ContainerEmpty() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Schema(versionedSchema: MemorySchemaV4.self),
            configurations: [config]
        )
        XCTAssertNotNil(container)
    }

    func testInsertSemanticFact() throws {
        let container = try makeInMemory()
        let context = ModelContext(container)
        let fact = SemanticFact(
            storageKey: "test_fact",
            content: "test fact",
            category: .health,
            categoryRawOverride: "health",
            confidence: 0.8,
            source: .extracted,
            sourceRawOverride: "extracted"
        )
        context.insert(fact)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SemanticFact>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.content, "test fact")
        XCTAssertEqual(fetched.first?.storageKey, "test_fact")
    }

    func testInsertEpisodicEntry() throws {
        let container = try makeInMemory()
        let context = ModelContext(container)
        let sessionID = UUID()
        let episode = EpisodicEntry(
            id: UUID(),
            sessionID: sessionID,
            timestamp: Date(),
            userMessageID: UUID(),
            userMessage: "Hi",
            captainResponse: "Hello"
        )
        context.insert(episode)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<EpisodicEntry>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sessionID, sessionID)
    }

    func testFactConfidenceDecay() {
        let fact = SemanticFact(
            storageKey: "decay",
            content: "test",
            category: .health,
            categoryRawOverride: "health",
            confidence: 1,
            source: .extracted,
            sourceRawOverride: "extracted",
            firstMentionedAt: Date().addingTimeInterval(-60 * 86_400)
        )

        XCTAssertEqual(fact.effectiveConfidence, 0.81, accuracy: 0.05)
    }

    func testAllEmotionKindsCodable() {
        for kind in EmotionKind.allCases {
            XCTAssertEqual(EmotionKind(rawValue: kind.rawValue), kind)
        }
    }

    func testRelationshipCreation() throws {
        let container = try makeInMemory()
        let context = ModelContext(container)
        let relationship = Relationship(name: "أمي", kind: .mother, emotionalWeight: 0.95)
        context.insert(relationship)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Relationship>())
        XCTAssertEqual(fetched.first?.name, "أمي")
        XCTAssertEqual(fetched.first?.kind, .mother)
    }

    func testSyntheticV3ToV4MigrationPreservesCounts() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let storeURL = tempDirectory.appendingPathComponent("captain_memory.store")
        let sessionID = UUID()
        let spotify = SpotifyRecommendation(
            vibeName: "Night Focus",
            description: "Keeps the energy steady.",
            spotifyURI: "spotify:playlist:focus"
        )
        let spotifyData = try JSONEncoder().encode(spotify)

        do {
            let schema = Schema(versionedSchema: CaptainSchemaV3.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration(
                        "CaptainMemoryStore",
                        schema: schema,
                        url: storeURL
                    )
                ]
            )
            let context = ModelContext(container)

            let goal = CaptainMemory(
                key: "goal",
                value: "Build Muscle",
                category: "goal",
                source: "user_explicit",
                confidence: 1
            )
            goal.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
            goal.updatedAt = Date(timeIntervalSince1970: 1_700_000_100)

            let sleep = CaptainMemory(
                key: "sleep_avg",
                value: "7.5",
                category: "sleep",
                source: "healthkit",
                confidence: 1
            )

            context.insert(goal)
            context.insert(sleep)
            context.insert(
                PersistentChatMessage(
                    messageID: UUID(),
                    text: "Hi Captain",
                    isUser: true,
                    timestamp: Date(timeIntervalSince1970: 1_700_000_010),
                    sessionID: sessionID
                )
            )
            context.insert(
                PersistentChatMessage(
                    messageID: UUID(),
                    text: "Let's lock in.",
                    isUser: false,
                    timestamp: Date(timeIntervalSince1970: 1_700_000_020),
                    spotifyRecommendationData: spotifyData,
                    sessionID: sessionID
                )
            )
            context.insert(
                PersistentChatMessage(
                    messageID: UUID(),
                    text: "What about sleep?",
                    isUser: true,
                    timestamp: Date(timeIntervalSince1970: 1_700_000_030),
                    sessionID: sessionID
                )
            )
            context.insert(
                PersistentChatMessage(
                    messageID: UUID(),
                    text: "Aim for 7.5 hours tonight.",
                    isUser: false,
                    timestamp: Date(timeIntervalSince1970: 1_700_000_040),
                    sessionID: sessionID
                )
            )
            try context.save()
        }

        let migratedSchema = Schema(versionedSchema: MemorySchemaV4.self)
        let migratedContainer = try ModelContainer(
            for: migratedSchema,
            migrationPlan: CaptainSchemaMigrationPlan.self,
            configurations: [
                ModelConfiguration(
                    "CaptainMemoryStore",
                    schema: migratedSchema,
                    url: storeURL
                )
            ]
        )
        let migratedContext = ModelContext(migratedContainer)

        let facts = try migratedContext.fetch(FetchDescriptor<SemanticFact>())
        let episodes = try migratedContext.fetch(FetchDescriptor<EpisodicEntry>())

        XCTAssertEqual(facts.count, 2)
        XCTAssertEqual(episodes.count, 2)

        let factKeys = Set(facts.map(\.storageKey))
        XCTAssertEqual(factKeys, ["goal", "sleep_avg"])

        let migratedSessionIDs = Set(episodes.map(\.sessionID))
        XCTAssertEqual(migratedSessionIDs, [sessionID])
        XCTAssertTrue(episodes.contains { $0.captainSpotifyRecommendation?.spotifyURI == spotify.spotifyURI })
    }

    private func makeInMemory() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: MemorySchemaV4.self),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    /// Re-opening the V4 store after a successful migration must not duplicate
    /// the migrated facts/episodes. SwiftData's own version check prevents
    /// re-running the stage, and `didMigrate` carries an `existingFactIDs`
    /// dedupe guard for the case where it would run anyway.
    func testV3ToV4MigrationIdempotent() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("captain_memory.store")
        let sessionID = UUID()

        // Seed V3
        do {
            let schema = Schema(versionedSchema: CaptainSchemaV3.self)
            let container = try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration("CaptainMemoryStore", schema: schema, url: storeURL)
                ]
            )
            let context = ModelContext(container)
            context.insert(CaptainMemory(
                key: "k1", value: "v1", category: "goal",
                source: "user_explicit", confidence: 1
            ))
            context.insert(PersistentChatMessage(
                messageID: UUID(),
                text: "Hi",
                isUser: true,
                timestamp: Date(timeIntervalSince1970: 1_700_000_010),
                sessionID: sessionID
            ))
            context.insert(PersistentChatMessage(
                messageID: UUID(),
                text: "Hello",
                isUser: false,
                timestamp: Date(timeIntervalSince1970: 1_700_000_020),
                sessionID: sessionID
            ))
            try context.save()
        }

        // First V4 open → migration runs
        let v4Schema = Schema(versionedSchema: MemorySchemaV4.self)
        let firstCounts: (facts: Int, episodes: Int)
        do {
            let container = try ModelContainer(
                for: v4Schema,
                migrationPlan: CaptainSchemaMigrationPlan.self,
                configurations: [
                    ModelConfiguration("CaptainMemoryStore", schema: v4Schema, url: storeURL)
                ]
            )
            let ctx = ModelContext(container)
            firstCounts = (
                try ctx.fetch(FetchDescriptor<SemanticFact>()).count,
                try ctx.fetch(FetchDescriptor<EpisodicEntry>()).count
            )
        }

        XCTAssertEqual(firstCounts.facts, 1)
        XCTAssertEqual(firstCounts.episodes, 1)

        // Second V4 open → no migration should run, counts unchanged
        let secondCounts: (facts: Int, episodes: Int)
        do {
            let container = try ModelContainer(
                for: v4Schema,
                migrationPlan: CaptainSchemaMigrationPlan.self,
                configurations: [
                    ModelConfiguration("CaptainMemoryStore", schema: v4Schema, url: storeURL)
                ]
            )
            let ctx = ModelContext(container)
            secondCounts = (
                try ctx.fetch(FetchDescriptor<SemanticFact>()).count,
                try ctx.fetch(FetchDescriptor<EpisodicEntry>()).count
            )
        }

        XCTAssertEqual(secondCounts.facts, firstCounts.facts, "second open must not duplicate facts")
        XCTAssertEqual(secondCounts.episodes, firstCounts.episodes, "second open must not duplicate episodes")
    }

    /// Migration failure path: recordMigrationFailure must set the fallback flag,
    /// which forces MemoryV4Gate.isOn to false on subsequent reads even when the
    /// underlying Info.plist flag is true.
    func testMemoryV4GateFallbackFlag() {
        let key = MemoryV4Gate.fallbackUserDefaultsKey
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        XCTAssertFalse(UserDefaults.standard.bool(forKey: key), "precondition: fallback flag must start clear")

        let error = NSError(domain: "test.memoryV4", code: 42)
        MemoryV4Gate.recordMigrationFailure(error, context: "unit_test")

        XCTAssertTrue(UserDefaults.standard.bool(forKey: key), "fallback flag must be set after recordMigrationFailure")
        XCTAssertFalse(MemoryV4Gate.isOn, "MemoryV4Gate.isOn must return false when fallback is set, regardless of Info.plist flag")
    }

    /// RemoteFlags must default to "kill switch OFF" when no cache is present.
    /// Verifies a missing Supabase row / first-launch / never-refreshed device
    /// does not unintentionally disable V4 globally.
    func testRemoteFlagsDefaultsToKillSwitchOff() {
        let key = "aiqo.remoteflags.memory_v4_globally_disabled"
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        XCTAssertFalse(
            RemoteFlags.shared.memoryV4GloballyDisabled,
            "When no cached value exists, kill switch must default to OFF (V4 enabled)"
        )
    }
}
