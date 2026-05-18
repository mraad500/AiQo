import XCTest
@testable import AiQo

/// Proves the reusable `MockURLProtocol` networking seam works end-to-end, so
/// future service/contract tests can trust it. (Agent audit flagged zero
/// networking test infrastructure; this is the foundation.)
final class MockURLProtocolTests: XCTestCase {

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testInterceptsRequestAndReturnsStubbedResponse() async throws {
        let url = URL(string: "https://api.example.test/v1/ping")!
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, url)
            let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data(#"{"ok":true}"#.utf8))
        }

        let (data, response) = try await makeSession().data(from: url)

        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Bool]
        )
        XCTAssertEqual(json["ok"], true)
    }

    func testSimulatesTransportFailure() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await makeSession().data(from: URL(string: "https://x.test")!)
            XCTFail("Expected the simulated transport error to throw")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Expected URLError, got \(error)")
        }
    }
}
