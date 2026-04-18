import XCTest
@testable import AiQo

final class EmbeddingIndexTests: XCTestCase {

    override func setUp() async throws {
        #if DEBUG
        await EmbeddingIndex.shared._clearCache()
        #endif
    }

    func testEmbedEnglishReturnsVector() async {
        let vec = await EmbeddingIndex.shared.embed("hello world")
        XCTAssertNotNil(vec)
        XCTAssertFalse(vec?.isEmpty ?? true)
    }

    func testEmbedArabicReturnsVector() async {
        let vec = await EmbeddingIndex.shared.embed("مرحبا صديقي")
        if vec != nil {
            XCTAssertGreaterThan(vec!.count, 50)
        } else {
            print("Arabic NLEmbedding unavailable on this runtime — expected on some simulators")
        }
    }

    func testCosineSelfIsOne() async {
        guard let v = await EmbeddingIndex.shared.embed("workout") else {
            throw XCTSkip("English embedding unavailable on this runtime")
        }
        let sim = EmbeddingIndex.cosine(v, v)
        XCTAssertEqual(sim, 1.0, accuracy: 0.01)
    }

    func testCosineOrthogonalSize() {
        let a = [1.0, 0.0, 0.0]
        let b = [0.0, 1.0, 0.0]
        XCTAssertEqual(EmbeddingIndex.cosine(a, b), 0.0, accuracy: 0.0001)
    }

    func testCacheHitDoesNotGrow() async {
        guard await EmbeddingIndex.shared.embed("running") != nil else {
            throw XCTSkip("English embedding unavailable on this runtime")
        }
        #if DEBUG
        let size1 = await EmbeddingIndex.shared._cacheSize()
        _ = await EmbeddingIndex.shared.embed("running")
        let size2 = await EmbeddingIndex.shared._cacheSize()
        XCTAssertEqual(size1, size2, "identical query should hit cache")
        #endif
    }

    func testEmptyOrWhitespaceReturnsNil() async {
        let blank = await EmbeddingIndex.shared.embed("   ")
        XCTAssertNil(blank)
        let empty = await EmbeddingIndex.shared.embed("")
        XCTAssertNil(empty)
    }
}

final class SalienceScorerTests: XCTestCase {

    func testAllZeroSignalsReturnsZero() {
        let s = SalienceScorer.score(.init())
        XCTAssertEqual(s, 0, accuracy: 0.01)
    }

    func testExplicitMemoryScoresHigh() {
        let s = SalienceScorer.score(.init(
            textLength: 50,
            isUserExplicit: true,
            mentionCount: 1
        ))
        XCTAssertGreaterThan(s, 0.3)
    }

    func testPRMomentScoresHigh() {
        let s = SalienceScorer.score(.init(
            textLength: 30,
            emotionalIntensity: 0.8,
            isPR: true
        ))
        XCTAssertGreaterThan(s, 0.4)
    }

    func testScoreCappedAtOne() {
        let s = SalienceScorer.score(.init(
            textLength: 500,
            hasQuestion: true,
            hasProperNoun: true,
            emotionalIntensity: 1.0,
            bioIntensity: 1.0,
            isUserExplicit: true,
            isPR: true,
            mentionCount: 20
        ))
        XCTAssertLessThanOrEqual(s, 1.0)
        XCTAssertGreaterThan(s, 0.9)
    }

    func testNegativeInputsAreClamped() {
        let s = SalienceScorer.score(.init(
            textLength: -100,
            emotionalIntensity: -0.5,
            bioIntensity: -0.5,
            mentionCount: -5
        ))
        XCTAssertEqual(s, 0, accuracy: 0.01)
    }
}

final class TemporalIndexTests: XCTestCase {

    override func setUp() async throws {
        await TemporalIndex.shared.invalidate()
    }

    func testResolverRunsOnFirstLookup() async {
        var calls = 0
        let ids = await TemporalIndex.shared.entryIDs(in: .today) {
            calls += 1
            return [UUID()]
        }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(ids.count, 1)
    }

    func testSecondLookupUsesCache() async {
        var calls = 0
        _ = await TemporalIndex.shared.entryIDs(in: .lastNDays(7)) {
            calls += 1
            return [UUID(), UUID()]
        }
        _ = await TemporalIndex.shared.entryIDs(in: .lastNDays(7)) {
            calls += 1
            return []
        }
        XCTAssertEqual(calls, 1, "cached window should skip resolver")
    }

    func testInvalidateForcesResolve() async {
        var calls = 0
        _ = await TemporalIndex.shared.entryIDs(in: .today) { calls += 1; return [] }
        await TemporalIndex.shared.invalidate(.today)
        _ = await TemporalIndex.shared.entryIDs(in: .today) { calls += 1; return [] }
        XCTAssertEqual(calls, 2)
    }
}
