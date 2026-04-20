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
        static let reasoning = "gemini-3-flash-preview"
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
        if !DevOverride.unlockAllFeatures {
            guard TierGate.shared.canAccess(.captainChat) else {
                diag.info("CloudBrainService.generateReply blocked by TierGate(.captainChat)")
                throw BrainError.tierRequired(TierGate.shared.requiredTier(for: .captainChat))
            }
        }
        let startedAt = Date()
        let latestUserMessage = request.conversation.last(where: { $0.role == .user })?.content ?? ""

        // Single MainActor hop — tier, memories, and consent state in one round-trip.
        let (activeTier, cloudSafeMemories, consentGranted) = await MainActor.run {
            let tier = AccessManager.shared.activeTier
            let budget = tier.effectiveAccessTier == .pro ? 700 : 400
            let memories = MemoryStore.shared.buildCloudSafeRelevantContext(
                for: latestUserMessage,
                screenContext: request.screenContext,
                maxTokens: budget
            )
            let consent = AIDataConsentManager.shared.hasUserConsented
            return (tier, memories, consent)
        }

        guard consentGranted else {
            await AuditLogger.shared.record(AuditLogger.Entry(
                id: UUID(),
                timestamp: startedAt,
                destination: "none",
                tier: activeTier.auditLabel,
                promptBytes: 0,
                responseBytes: 0,
                latencyMs: 0,
                consentGranted: false,
                sanitizationApplied: false,
                purpose: request.purpose.rawValue,
                outcome: .consentDenied
            ))
            throw AIDataConsentError.consentRequired
        }

        // All sanitization runs off-MainActor (on the cooperative thread pool).
        // This is where the regex-heavy PII redaction happens — it must never block the UI.
        let sanitizedRequest = sanitizer.sanitizeForCloud(
            request,
            knownUserName: userName,
            cloudSafeMemories: cloudSafeMemories
        )

        let aiModel = activeTier.effectiveAccessTier == .pro
            ? GeminiModel.reasoning
            : GeminiModel.fast
        let promptBytes = Self.estimatedPromptBytes(of: sanitizedRequest)

        do {
            let reply = try await transport.generateReply(
                request: sanitizedRequest,
                model: aiModel
            )
            let latencyMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            await AuditLogger.shared.record(AuditLogger.Entry(
                id: UUID(),
                timestamp: startedAt,
                destination: aiModel,
                tier: activeTier.auditLabel,
                promptBytes: promptBytes,
                responseBytes: reply.message.utf8.count,
                latencyMs: latencyMs,
                consentGranted: true,
                sanitizationApplied: true,
                purpose: request.purpose.rawValue,
                outcome: .success
            ))
            return reply
        } catch {
            let latencyMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            await AuditLogger.shared.record(AuditLogger.Entry(
                id: UUID(),
                timestamp: startedAt,
                destination: aiModel,
                tier: activeTier.auditLabel,
                promptBytes: promptBytes,
                responseBytes: 0,
                latencyMs: latencyMs,
                consentGranted: true,
                sanitizationApplied: true,
                purpose: request.purpose.rawValue,
                outcome: .failure
            ))
            throw error
        }
    }

    private static func estimatedPromptBytes(of request: HybridBrainRequest) -> Int {
        var total = 0
        for msg in request.conversation {
            total += msg.content.utf8.count
        }
        total += request.intentSummary.utf8.count
        total += request.workingMemorySummary.utf8.count
        total += request.userProfileSummary.utf8.count
        return total
    }
}
