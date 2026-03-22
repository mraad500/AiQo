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
        // Fetch cloud-safe memories on MainActor before sanitizing
        let cloudSafeMemories = await MainActor.run {
            MemoryStore.shared.buildCloudSafeContext(maxTokens: 400)
        }

        let sanitizedRequest = sanitizer.sanitizeForCloud(
            request,
            knownUserName: userName,
            cloudSafeMemories: cloudSafeMemories
        )

        return try await transport.generateReply(request: sanitizedRequest)
    }
}
