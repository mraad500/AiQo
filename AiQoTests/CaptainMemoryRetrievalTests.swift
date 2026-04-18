import XCTest
import SwiftData
@testable import AiQo

@MainActor
final class CaptainMemoryRetrievalTests: XCTestCase {
    private var store: MemoryStore!
    private var originalIsEnabled = true

    override func setUpWithError() throws {
        try super.setUpWithError()

        originalIsEnabled = MemoryStore.shared.isEnabled

        let schema = Schema([CaptainMemory.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )

        store = MemoryStore.shared
        store.configure(container: container, storageMode: .legacyV3)
        store.isEnabled = true
        store.clearAll()
    }

    override func tearDownWithError() throws {
        store.clearAll()
        store.isEnabled = originalIsEnabled
        store = nil
        try super.tearDownWithError()
    }

    func testRetrieveRelevantMemoriesPrioritizesSleepContext() {
        store.set("bedtime_preference", value: "10:40 PM", category: "sleep", source: "user_explicit", confidence: 1.0)
        store.set("wake_time_preference", value: "6:20 AM", category: "sleep", source: "user_explicit", confidence: 1.0)
        store.set("goal", value: "Build Muscle", category: "goal", source: "user_explicit", confidence: 1.0)
        store.set("preferred_training_time", value: "Evening", category: "preference", source: "user_explicit", confidence: 1.0)

        let memories = store.retrieveRelevantMemories(
            for: "شلون أرتب نومي الليلة ووقت الاستيقاظ؟",
            screenContext: .sleepAnalysis,
            limit: 3
        )

        XCTAssertEqual(memories.first?.category, "sleep")
        XCTAssertTrue(memories.prefix(2).contains(where: { $0.key == "bedtime_preference" }))
        XCTAssertFalse(memories.prefix(1).contains(where: { $0.key == "goal" }))
    }

    func testBuildCloudSafeRelevantContextOmitsBodyMemories() {
        store.set("weight", value: "88", category: "body", source: "user_explicit", confidence: 1.0)
        store.set("goal", value: "Build Muscle", category: "goal", source: "user_explicit", confidence: 1.0)
        store.set("preferred_workout", value: "Gym / Resistance", category: "preference", source: "user_explicit", confidence: 1.0)

        let context = store.buildCloudSafeRelevantContext(
            for: "أريد تمرين جيم اليوم",
            screenContext: .gym,
            maxTokens: 200
        )

        XCTAssertTrue(context.contains("goal"))
        XCTAssertTrue(context.contains("preferred_workout"))
        XCTAssertFalse(context.contains("weight"))
    }
}
