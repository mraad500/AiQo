import Foundation

struct CloudBrainService: Sendable {
    private let transport: HybridBrainService
    private let sanitizer: PrivacySanitizer

    init(
        transport: HybridBrainService = HybridBrainService(),
        sanitizer: PrivacySanitizer = PrivacySanitizer()
    ) {
        self.transport = transport
        self.sanitizer = sanitizer
    }

    func generateReply(
        request: HybridBrainRequest,
        userName: String?
    ) async throws -> HybridBrainServiceReply {
        let sanitizedRequest = sanitizer.sanitizeForCloud(
            request,
            knownUserName: userName
        )

        return try await transport.generateReply(request: sanitizedRequest)
    }
}
