import Foundation

/// Reusable `URLProtocol` stub for deterministic networking tests.
///
/// Register on a `URLSessionConfiguration` (or globally via
/// `URLProtocol.registerClass`) and set `requestHandler` to return a canned
/// `(HTTPURLResponse, Data)` or throw to simulate a transport failure. Lets
/// service/contract tests exercise real request-building + response-mapping
/// without a live backend.
final class MockURLProtocol: URLProtocol {

    /// Set per test. Receives the outgoing request, returns the response to
    /// feed back, or throws to simulate a network error.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() { requestHandler = nil }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
