import Foundation

/// Privacy wrapper over HybridBrainService.
///
/// Before any data reaches the Gemini API, this service:
/// 1. Fetches cloud-safe memories (no PII — only goals/preferences)
/// 2. Sanitizes conversation (truncates to last 4 messages)
/// 3. Redacts all PII (emails, phones, UUIDs, IPs)
/// 4. Normalizes user names to "User"
/// 5. Buckets health data (steps by 50, calories by 10)
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
