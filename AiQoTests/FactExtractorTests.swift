import XCTest
@testable import AiQo

final class FactExtractorTests: XCTestCase {

    func testExtractsExplicitPreference() async {
        let facts = await FactExtractor.shared.extract(
            userMessage: "I love running in the morning",
            maxFacts: 5
        )
        XCTAssertFalse(facts.isEmpty)
        XCTAssertTrue(facts.contains { $0.category == .preference },
                      "'I love …' should map to .preference")
    }

    func testExtractsArabicName() async {
        let facts = await FactExtractor.shared.extract(
            userMessage: "اسمي محمد",
            maxFacts: 3
        )
        XCTAssertFalse(facts.isEmpty, "heuristic should catch Arabic name marker")
    }

    func testExtractsGoal() async {
        let facts = await FactExtractor.shared.extract(
            userMessage: "I want to lose 10 pounds this summer.",
            maxFacts: 3
        )
        XCTAssertTrue(facts.contains { $0.category == .goal },
                      "'I want to …' should map to .goal")
    }

    func testEmptyMessageReturnsEmpty() async {
        let facts = await FactExtractor.shared.extract(userMessage: "", maxFacts: 5)
        XCTAssertTrue(facts.isEmpty)
    }

    func testWhitespaceMessageReturnsEmpty() async {
        let facts = await FactExtractor.shared.extract(userMessage: "   \n\t  ", maxFacts: 5)
        XCTAssertTrue(facts.isEmpty)
    }

    func testFlagsSensitive() async {
        let facts = await FactExtractor.shared.extract(
            userMessage: "I have anxiety sometimes",
            maxFacts: 3
        )
        XCTAssertTrue(facts.contains { $0.sensitive },
                      "'anxiety' is a sensitive keyword")
    }

    func testNoGenericSentenceExtractsNothing() async {
        let facts = await FactExtractor.shared.extract(
            userMessage: "The weather is nice today.",
            maxFacts: 5
        )
        XCTAssertTrue(facts.isEmpty,
                      "sentence without explicit memory markers should yield no heuristic facts")
    }
}

final class EmotionalMinerTests: XCTestCase {

    override func tearDown() {
        TierGate.shared._clearTestOverride()
        super.tearDown()
    }

    func testMineWithFutureDateReturnsZero() async {
        TierGate.shared._setTierForTesting(.pro)
        let count = await EmotionalMiner.shared.mine(since: Date().addingTimeInterval(10_000))
        XCTAssertEqual(count, 0, "no episodes in the future → zero created")
    }

    func testMineOnFreeTierSkipsWork() async {
        TierGate.shared._setTierForTesting(.none)
        let count = await EmotionalMiner.shared.mine(since: Date().addingTimeInterval(-86_400))
        XCTAssertEqual(count, 0, "free tier cadence=.never → skip entirely")
    }
}
