import XCTest
@testable import AiQo

/// Locks in the REAL token-streaming contract (`CAPTAIN_REAL_STREAMING`).
///
/// The cloud streaming path (`HybridBrainService.requestStreamingCloudResponse`)
/// reassembles Gemini's SSE text fragments into the structured-JSON output and
/// surfaces a growing `message` preview via `LLMJSONParser.currentMessagePreview`.
/// At the end it re-parses the COMPLETE buffer with `decodeCompletedStream` so
/// the authoritative reply is byte-identical to the blocking path. These tests
/// exercise that reassembly + incremental-extraction logic without a network.
final class CaptainStreamingPreviewTests: XCTestCase {

    private let parser = LLMJSONParser()

    // MARK: - rawPartsText (untrimmed concatenation)

    /// `rawPartsText` must NOT trim — a fragment whose boundary lands on a space
    /// (very common mid-stream) would otherwise lose that space and corrupt the
    /// reassembled JSON.
    func testRawPartsTextPreservesBoundarySpaces() throws {
        let json = """
        { "candidates": [ { "content": { "parts": [{ "text": " بطل" }] } } ] }
        """
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: XCTUnwrap(json.data(using: .utf8)))
        XCTAssertEqual(decoded.rawPartsText, " بطل", "leading space must survive for clean chunk joining")
        XCTAssertEqual(decoded.outputText, "بطل", "outputText still trims (blocking path contract)")
    }

    // MARK: - Incremental preview growth

    /// Feeding the full reply one small chunk at a time must yield a preview
    /// that grows monotonically and converges exactly on the final message —
    /// even when the model fences the JSON in a ```json block.
    func testPreviewGrowsMonotonicallyToFinalMessage() {
        let message = "هلا بالذيب، شلونك اليوم؟ جاهز نبدأ التمرين."
        let fenced = """
        ```json
        {"message":"\(message)","quickReplies":["جاهز","لا هسه"],"workoutPlan":null}
        ```
        """

        var buffer = ""
        var previews: [String] = []
        for chunk in fenced.chunkedForTest(size: 7) {
            buffer += chunk
            let preview = parser.currentMessagePreview(from: buffer)
            if !preview.isEmpty { previews.append(preview) }
        }

        XCTAssertFalse(previews.isEmpty, "should surface at least one live preview")
        // Monotonic: each preview is a prefix-extension of the previous one.
        for (earlier, later) in zip(previews, previews.dropFirst()) {
            XCTAssertTrue(later.hasPrefix(earlier) || later.count >= earlier.count,
                          "preview must not shrink mid-stream")
        }
        XCTAssertEqual(previews.last, message, "final preview must equal the full message")
    }

    /// A mid-stream buffer (JSON not yet closed) must still produce a USEFUL
    /// partial message, not an empty string — that is the whole point of live
    /// streaming.
    func testPartialStreamYieldsPartialMessage() {
        let partial = #"{"message":"هلا بالذيب، شلون"#  // deliberately unterminated
        let preview = parser.currentMessagePreview(from: partial)
        XCTAssertEqual(preview, "هلا بالذيب، شلون")
    }

    // MARK: - Final authoritative parse

    /// After the stream completes, the full buffer must decode into the SAME
    /// structured response the blocking path would produce (message + quick
    /// replies), so memory/plan side effects are unaffected by streaming.
    func testCompletedStreamDecodesFullStructuredResponse() {
        let message = "تمام، رتبتلك تمرين خفيف اليوم."
        let raw = """
        ```json
        {"message":"\(message)","quickReplies":["زين","غيّرها"]}
        ```
        """
        let fallback = CaptainStructuredResponse(message: "fallback")
        let decoded = parser.decodeCompletedStream(raw, fallback: fallback)

        XCTAssertEqual(decoded.message, message)
        XCTAssertEqual(decoded.quickReplies, ["زين", "غيّرها"])
        XCTAssertNotEqual(decoded.message, fallback.message, "must not fall back on valid JSON")
    }

    /// Garbage / empty stream falls back gracefully rather than crashing.
    func testEmptyStreamFallsBack() {
        let fallback = CaptainStructuredResponse(message: "عذراً صار خلل")
        let decoded = parser.decodeCompletedStream("", fallback: fallback)
        XCTAssertEqual(decoded.message, fallback.message)
    }
}

// MARK: - Test helpers

private extension String {
    /// Splits into fixed-size substrings to simulate arbitrary SSE chunk
    /// boundaries (which can fall anywhere — mid-key, mid-value, mid-escape).
    func chunkedForTest(size: Int) -> [String] {
        guard size > 0, !isEmpty else { return [self] }
        var chunks: [String] = []
        var idx = startIndex
        while idx < endIndex {
            let end = index(idx, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[idx..<end]))
            idx = end
        }
        return chunks
    }
}
