import XCTest
@testable import AiQo

final class MiniMaxVoiceConfigurationTests: XCTestCase {
    func test_normalizedModelID_stripsUISuffix() {
        XCTAssertEqual(
            MiniMaxVoiceConfiguration.normalizedModelID(from: "speech-2.8-hd New"),
            "speech-2.8-hd"
        )
    }

    func test_normalizedEndpointURL_fallsBackForDocsURL() {
        let url = MiniMaxVoiceConfiguration.normalizedEndpointURL(
            from: "https://www.minimax.io/audio/text-to-speech"
        )

        XCTAssertEqual(url?.absoluteString, "https://api.minimax.io/v1/t2a_v2")
    }

    func test_normalizedEndpointURL_fallsBackForTruncatedXCConfigURL() {
        let url = MiniMaxVoiceConfiguration.normalizedEndpointURL(from: "https:")

        XCTAssertEqual(url?.absoluteString, "https://api.minimax.io/v1/t2a_v2")
    }

    func test_normalizedEndpointURL_keepsValidAPIEndpoint() {
        let url = MiniMaxVoiceConfiguration.normalizedEndpointURL(
            from: "https://api.minimax.io/v1/t2a_v2"
        )

        XCTAssertEqual(url?.absoluteString, "https://api.minimax.io/v1/t2a_v2")
    }
}
