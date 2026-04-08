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
    private enum GeminiModel {
        static let fast = "gemini-2.5-flash"
        static let reasoning = "gemini-3.1-pro"
    }

    private let transport: HybridBrainService
    private let sanitizer: PrivacySanitizer
    private let activeTierProvider: @Sendable () async -> SubscriptionTier

    init(
        transport: HybridBrainService = HybridBrainService(),
        sanitizer: PrivacySanitizer = PrivacySanitizer(),
        activeTierProvider: @escaping @Sendable () async -> SubscriptionTier = {
            await MainActor.run { AccessManager.shared.activeTier }
        }
    ) {
        self.transport = transport
        self.sanitizer = sanitizer
        self.activeTierProvider = activeTierProvider
    }

    /// **Fix (2026-04-08):** Collapsed two sequential `MainActor.run` hops into a single hop.
    /// Before: two separate `await MainActor.run` calls serialized behind the MainActor queue,
    /// each waiting for SwiftUI's render cycle to yield. If the UI was busy (scroll, animation),
    /// this could block for 100ms+ per hop. Now both values are fetched in one MainActor round-trip.
    ///
    /// The subsequent sanitization (`sanitizeForCloud`) runs on the caller's cooperative pool
    /// thread — never on MainActor — so regex processing cannot block the UI.
    func generateReply(
        request: HybridBrainRequest,
        userName: String?
    ) async throws -> HybridBrainServiceReply {
        // Single MainActor hop — fetch both values at once to minimize main-thread contention
        let (activeTier, cloudSafeMemories) = await MainActor.run {
            let tier = AccessManager.shared.activeTier
            let budget = tier == .intelligencePro ? 700 : 400
            let memories = MemoryStore.shared.buildCloudSafeContext(maxTokens: budget)
            return (tier, memories)
        }

        // All sanitization runs off-MainActor (on the cooperative thread pool).
        // This is where the regex-heavy PII redaction happens — it must never block the UI.
        let sanitizedRequest = sanitizer.sanitizeForCloud(
            request,
            knownUserName: userName,
            cloudSafeMemories: cloudSafeMemories
        )

        let aiModel = activeTier == .intelligencePro
            ? GeminiModel.reasoning
            : GeminiModel.fast

        return try await transport.generateReply(
            request: sanitizedRequest,
            model: aiModel
        )
    }
}
