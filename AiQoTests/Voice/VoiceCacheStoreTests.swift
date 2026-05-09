import XCTest
@testable import AiQo

/// Unit coverage for the MiniMax audio cache. Every test instantiates the
/// store in a unique temporary directory so production data on the
/// simulator is never touched.
final class VoiceCacheStoreTests: XCTestCase {

    // MARK: - Key hashing

    func test_cacheKey_stableForSameInputs() {
        let a = VoiceCacheStore.cacheKey(voiceID: "v1", model: "m1", text: "hello")
        let b = VoiceCacheStore.cacheKey(voiceID: "v1", model: "m1", text: "hello")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 32, "Cache key should be 32 hex chars.")
    }

    func test_cacheKey_differsOnAnyField() {
        let base = VoiceCacheStore.cacheKey(voiceID: "v1", model: "m1", text: "hello")
        XCTAssertNotEqual(base, VoiceCacheStore.cacheKey(voiceID: "v2", model: "m1", text: "hello"))
        XCTAssertNotEqual(base, VoiceCacheStore.cacheKey(voiceID: "v1", model: "m2", text: "hello"))
        XCTAssertNotEqual(base, VoiceCacheStore.cacheKey(voiceID: "v1", model: "m1", text: "world"))
    }

    func test_cacheKey_separatorPreventsFieldCollisions() {
        // Without the pipe separator, ("foo", "bar") and ("foob", "ar")
        // would hash the same string. Verify the separator actually
        // disambiguates them.
        let a = VoiceCacheStore.cacheKey(voiceID: "foo", model: "bar", text: "t")
        let b = VoiceCacheStore.cacheKey(voiceID: "foob", model: "ar", text: "t")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Store / lookup

    func test_store_writesFileAndLookupReturnsIt() async throws {
        let store = makeStore()
        let data = Data("audio-bytes".utf8)

        let url = try await store.store(key: "abc", data: data)

        let exists = FileManager.default.fileExists(atPath: url.path)
        XCTAssertTrue(exists, "store() should have written the file.")

        let looked = await store.lookup(key: "abc")
        XCTAssertNotNil(looked)
        XCTAssertEqual(looked, url)
    }

    func test_lookup_returnsNilWhenMissing() async {
        let store = makeStore()
        let looked = await store.lookup(key: "missing")
        XCTAssertNil(looked)
    }

    func test_lookup_touchesModificationDate() async throws {
        let store = makeStore()
        _ = try await store.store(key: "k", data: Data("a".utf8))

        // Artificially age the file a minute.
        let url = try await store.store(key: "k", data: Data("a".utf8))
        let past = Date().addingTimeInterval(-60)
        try FileManager.default.setAttributes(
            [.modificationDate: past],
            ofItemAtPath: url.path
        )

        _ = await store.lookup(key: "k")

        let refreshed = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        XCTAssertNotNil(refreshed)
        XCTAssertGreaterThan(
            refreshed!.timeIntervalSince1970,
            past.timeIntervalSince1970,
            "lookup() must refresh modification date for LRU promotion."
        )
    }

    // MARK: - Eviction

    func test_evict_withinLimits_keepsEverything() async throws {
        let store = makeStore(maxFileCount: 10, maxBytes: 10_000)

        _ = try await store.store(key: "a", data: Data(repeating: 0xAA, count: 100))
        _ = try await store.store(key: "b", data: Data(repeating: 0xBB, count: 100))

        await store.evict()

        let count = await store.fileCount()
        XCTAssertEqual(count, 2)
    }

    func test_evict_overFileLimit_evictsOldestFirst() async throws {
        let store = makeStore(maxFileCount: 2, maxBytes: 1_000_000)

        let first = try await store.store(key: "oldest", data: Data("1".utf8))
        // Age the first entry deterministically so eviction can pick it.
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-120)],
            ofItemAtPath: first.path
        )

        let second = try await store.store(key: "middle", data: Data("2".utf8))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-60)],
            ofItemAtPath: second.path
        )

        _ = try await store.store(key: "newest", data: Data("3".utf8))

        await store.evict()

        let survivors = await store.fileCount()
        XCTAssertEqual(survivors, 2)

        let evictedStillPresent = await store.lookup(key: "oldest")
        XCTAssertNil(evictedStillPresent, "Oldest entry must be evicted first.")
        let newestStillPresent = await store.lookup(key: "newest")
        XCTAssertNotNil(newestStillPresent, "Newest entry must survive eviction.")
    }

    func test_evict_overByteLimit_evictsUntilUnderBudget() async throws {
        let store = makeStore(maxFileCount: 10, maxBytes: 150)

        let big = try await store.store(key: "oldest", data: Data(repeating: 0xAA, count: 100))
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-60)],
            ofItemAtPath: big.path
        )
        _ = try await store.store(key: "newer", data: Data(repeating: 0xBB, count: 100))

        await store.evict()

        let total = await store.totalBytes()
        XCTAssertLessThanOrEqual(total, 150, "Eviction must bring total bytes under maxBytes.")
        let oldestGone = await store.lookup(key: "oldest")
        XCTAssertNil(oldestGone)
    }

    // MARK: - Wipe

    func test_wipeAll_removesEverything() async throws {
        let store = makeStore()
        _ = try await store.store(key: "a", data: Data("x".utf8))
        _ = try await store.store(key: "b", data: Data("y".utf8))

        await store.wipeAll()

        let count = await store.fileCount()
        XCTAssertEqual(count, 0)
        let lookedA = await store.lookup(key: "a")
        XCTAssertNil(lookedA)
    }

    // MARK: - Helpers

    private func makeStore(
        maxFileCount: Int = 500,
        maxBytes: Int = 100 * 1024 * 1024
    ) -> VoiceCacheStore {
        let uniqueDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceCacheStoreTests-\(UUID().uuidString)", isDirectory: true)
        return VoiceCacheStore(
            cacheDirectory: uniqueDir,
            maxFileCount: maxFileCount,
            maxBytes: maxBytes
        )
    }
}
