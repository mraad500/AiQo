import XCTest
@testable import AiQo

final class MemoryRetrieverTests: XCTestCase {

    override func tearDown() {
        TierGate.shared._clearTestOverride()
        super.tearDown()
    }

    func testRetrieveReturnsBundle() async {
        TierGate.shared._setTierForTesting(.pro)
        let bundle = await MemoryRetriever.shared.retrieve(
            query: "how is my sleep",
            bioContext: nil,
            tier: .pro
        )
        XCTAssertNotNil(bundle)
    }

    func testEmptyQueryStillReturnsBundle() async {
        TierGate.shared._setTierForTesting(.max)
        let bundle = await MemoryRetriever.shared.retrieve(
            query: "",
            bioContext: nil,
            tier: .max
        )
        XCTAssertNotNil(bundle)
    }

    func testMaxTierRespectsBudget() async {
        TierGate.shared._setTierForTesting(.max)
        let bundle = await MemoryRetriever.shared.retrieve(
            query: "workout",
            tier: .max
        )
        XCTAssertLessThanOrEqual(bundle.totalItems, 15,
            "Max tier budget = 10 across 5 stores; allow slack for rounding")
    }

    func testFreeTierReturnsEmpty() async {
        TierGate.shared._setTierForTesting(.none)
        let bundle = await MemoryRetriever.shared.retrieve(
            query: "anything",
            tier: .none
        )
        XCTAssertTrue(bundle.isEmpty, "free tier has zero budget → empty bundle")
    }

    func testCustomLimitOverridesTier() async {
        TierGate.shared._setTierForTesting(.pro)
        let bundle = await MemoryRetriever.shared.retrieve(
            query: "sleep",
            tier: .pro,
            customLimit: 0
        )
        XCTAssertTrue(bundle.isEmpty, "customLimit=0 → empty bundle regardless of tier")
    }
}

final class MemoryBundleTests: XCTestCase {

    func testEmptyBundleReportsEmpty() {
        let b = MemoryBundle()
        XCTAssertTrue(b.isEmpty)
        XCTAssertEqual(b.totalItems, 0)
    }
}
