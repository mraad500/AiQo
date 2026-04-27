import XCTest
@testable import AiQo

/// Locks in the Gemini response decoder's awareness of `finishReason` and
/// `usageMetadata`, the signals that drive the truncation flag and the
/// `gemini_finish` log line. Without these, the app cannot tell when Gemini
/// hit `MAX_TOKENS` and the chat silently delivers a partial reply.
final class HybridBrainResponseDecodingTests: XCTestCase {

    // MARK: - finishReason

    func testFinishReasonDecodes() throws {
        let json = """
        {
          "candidates": [
            {
              "content": {
                "parts": [{ "text": "partial reply" }]
              },
              "finishReason": "MAX_TOKENS",
              "safetyRatings": [
                { "category": "HARM_CATEGORY_HARASSMENT", "probability": "NEGLIGIBLE" }
              ]
            }
          ],
          "usageMetadata": {
            "promptTokenCount": 800,
            "candidatesTokenCount": 1400,
            "totalTokenCount": 2200
          }
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)

        XCTAssertEqual(decoded.finishReason, "MAX_TOKENS")
        XCTAssertTrue(decoded.didHitMaxTokens)
        XCTAssertEqual(decoded.outputText, "partial reply")
        XCTAssertEqual(decoded.usageMetadata?.promptTokenCount, 800)
        XCTAssertEqual(decoded.usageMetadata?.candidatesTokenCount, 1400)
        XCTAssertEqual(decoded.usageMetadata?.totalTokenCount, 2200)
        XCTAssertEqual(decoded.candidates?.first?.safetyRatings?.first?.category, "HARM_CATEGORY_HARASSMENT")
    }

    func testFinishReasonStop_doesNotMarkTruncated() throws {
        let json = """
        {
          "candidates": [
            {
              "content": { "parts": [{ "text": "complete reply." }] },
              "finishReason": "STOP"
            }
          ]
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)

        XCTAssertEqual(decoded.finishReason, "STOP")
        XCTAssertFalse(decoded.didHitMaxTokens)
    }

    func testMissingFinishReason_decodesAsNil() throws {
        // Older Gemini responses or partial captures may omit finishReason.
        // The decoder must tolerate the absence rather than throw.
        let json = """
        {
          "candidates": [
            {
              "content": { "parts": [{ "text": "hi" }] }
            }
          ]
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)

        XCTAssertNil(decoded.finishReason)
        XCTAssertFalse(decoded.didHitMaxTokens)
        XCTAssertEqual(decoded.outputText, "hi")
    }
}
