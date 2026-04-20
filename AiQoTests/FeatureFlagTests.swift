import XCTest
@testable import AiQo

final class FeatureFlagTests: XCTestCase {

    func testMemoryV4FlagMirrorsInfoPlistValue() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "MEMORY_V4_ENABLED") as? Bool
        let defaulted = raw ?? false
        XCTAssertEqual(FeatureFlags.memoryV4Enabled, defaulted)
    }

    func testUnknownKeyFallsBackToDefault() {
        @FeatureFlag("AIQO_TEST_NONEXISTENT_FLAG_\(UUID().uuidString)", default: false) var disabled
        @FeatureFlag("AIQO_TEST_NONEXISTENT_FLAG_\(UUID().uuidString)", default: true) var enabled
        XCTAssertFalse(disabled)
        XCTAssertTrue(enabled)
    }

    func testLegacyValueAccessorStillWorks() {
        // Back-compat: some call sites used `FeatureFlag(key:defaultValue:).value` directly.
        let flag = FeatureFlag("MEMORY_V4_ENABLED", default: false)
        XCTAssertEqual(flag.value, flag.wrappedValue)
    }
}
