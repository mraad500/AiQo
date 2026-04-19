import XCTest
@testable import AiQo

final class ProfessionalReferralTests: XCTestCase {

    func testUAEResourcesExist() {
        let resources = ProfessionalReferral.resources(for: .uae)

        XCTAssertGreaterThanOrEqual(resources.count, 2)
        XCTAssertTrue(resources.contains { $0.phone == "04-5192519" })
        XCTAssertTrue(resources.contains { $0.phone == "8001717" })
    }

    func testSaudiResourcesExist() {
        let resources = ProfessionalReferral.resources(for: .saudi)

        XCTAssertEqual(resources.count, 1)
        XCTAssertEqual(resources.first?.phone, "920033360")
    }

    func testGlobalResourcesAlwaysAvailable() {
        let resources = ProfessionalReferral.resources(for: .global)

        XCTAssertEqual(resources.count, 2)
        XCTAssertTrue(resources.allSatisfy { $0.website != nil })
    }

    func testIraqFallsBackToDirectoryResources() {
        let resources = ProfessionalReferral.resources(for: .iraq)

        XCTAssertFalse(resources.isEmpty)
        XCTAssertTrue(resources.contains { $0.website?.contains("findahelpline.com/countries/iq") == true })
    }

    func testDetectRegionFromLocale() {
        XCTAssertEqual(ProfessionalReferral.detectRegion(locale: Locale(identifier: "en_AE")), .uae)
        XCTAssertEqual(ProfessionalReferral.detectRegion(locale: Locale(identifier: "en_SA")), .saudi)
        XCTAssertEqual(ProfessionalReferral.detectRegion(locale: Locale(identifier: "en_IQ")), .iraq)
    }

    func testImmediateEnglishSupportMessageIncludesEmergencyLanguage() {
        let message = ProfessionalReferral.supportMessage(
            language: .english,
            urgency: .immediate,
            region: .uae
        )

        XCTAssertTrue(message.contains("local emergency services"))
        XCTAssertTrue(message.contains("998"))
        XCTAssertTrue(message.contains("04-5192519"))
    }
}
