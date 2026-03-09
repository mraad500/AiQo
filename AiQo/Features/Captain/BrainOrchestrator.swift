import Foundation

struct BrainOrchestrator: Sendable {
    private enum Route {
        case local
        case cloud
    }

    private let localService: LocalIntelligenceService
    private let cloudService: CloudBrainService
    private let sanitizer: PrivacySanitizer

    init(
        localService: LocalIntelligenceService = LocalIntelligenceService(),
        cloudService: CloudBrainService = CloudBrainService(),
        sanitizer: PrivacySanitizer = PrivacySanitizer()
    ) {
        self.localService = localService
        self.cloudService = cloudService
        self.sanitizer = sanitizer
    }

    func generateReply(
        request: HybridBrainRequest,
        userName: String?
    ) async throws -> HybridBrainServiceReply {
        let resolvedRequest = requestByInterceptingIntent(request)
        let baseReply: HybridBrainServiceReply
        switch route(for: resolvedRequest) {
        case .local:
            baseReply = try await localService.generateReply(request: resolvedRequest)
        case .cloud:
            baseReply = try await cloudService.generateReply(
                request: resolvedRequest,
                userName: userName
            )
        }

        let personalizedMessage: String
        if let userName, !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            personalizedMessage = sanitizer.injectUserName(
                into: baseReply.message,
                userName: userName
            )
        } else {
            personalizedMessage = baseReply.message
        }

        let structuredResponse = CaptainStructuredResponse(
            message: personalizedMessage,
            workoutPlan: baseReply.workoutPlan,
            mealPlan: baseReply.mealPlan
        )
        let rawText = try encode(structuredResponse)

        return HybridBrainServiceReply(
            message: structuredResponse.message,
            workoutPlan: structuredResponse.workoutPlan,
            mealPlan: structuredResponse.mealPlan,
            rawText: rawText
        )
    }

    func startStreamingReply(
        request: HybridBrainRequest,
        userName: String?
    ) async throws -> HybridBrainStreamingSession {
        let reply = try await generateReply(
            request: request,
            userName: userName
        )
        let fallbackResponse = CaptainStructuredResponse(
            message: reply.message,
            workoutPlan: reply.workoutPlan,
            mealPlan: reply.mealPlan
        )

        return HybridBrainStreamingSession(
            tokens: tokenStream(for: reply.rawText),
            fallbackResponse: fallbackResponse
        )
    }
}

private extension BrainOrchestrator {
    static let sleepIntentPatterns: [String] = [
        #"\b(?:sleep|sleeping|slept|nap|napping)\b"#,
        #"(?<![\p{L}\p{N}_])نوم(?:ي|ك|ه|ها|نا|كم|هم)?(?![\p{L}\p{N}_])"#,
        #"(?<![\p{L}\p{N}_])نمت(?![\p{L}\p{N}_])"#,
        #"(?<![\p{L}\p{N}_])نايم(?:ة|ين)?(?![\p{L}\p{N}_])"#
    ]

    // Sensitive sleep prompts must stay on-device even when they originate from main chat.
    func requestByInterceptingIntent(_ request: HybridBrainRequest) -> HybridBrainRequest {
        guard containsSleepIntent(in: latestUserMessage(in: request)),
              request.screenContext != .sleepAnalysis else {
            return request
        }

        return HybridBrainRequest(
            conversation: request.conversation,
            screenContext: ScreenContext.sleepAnalysis,
            language: request.language,
            contextData: request.contextData,
            userProfileSummary: request.userProfileSummary,
            hasAttachedImage: request.hasAttachedImage
        )
    }

    private func route(for request: HybridBrainRequest) -> Route {
        let latestUserMessage = latestUserMessage(in: request)

        if request.screenContext == .sleepAnalysis || containsSensitiveHealthSignals(in: latestUserMessage) {
            return .local
        }

        switch request.screenContext {
        case .gym, .kitchen, .peaks:
            return .cloud
        case .mainChat, .myVibe:
            return requiresCloudPlanning(for: latestUserMessage) ? .cloud : .local
        case .sleepAnalysis:
            return .local
        }
    }

    func latestUserMessage(in request: HybridBrainRequest) -> String {
        request.conversation.last(where: { $0.role == .user })?.content ?? ""
    }

    func requiresCloudPlanning(for message: String) -> Bool {
        containsAny(message, keywords: [
            "workout", "training", "plan", "meal", "diet", "recipe", "challenge", "discipline",
            "تمرين", "خطة", "وجبة", "اكل", "أكل", "وصفة", "تحدي", "انضباط"
        ])
    }

    func containsSensitiveHealthSignals(in message: String) -> Bool {
        if containsSleepIntent(in: message) {
            return true
        }

        return containsAny(message, keywords: [
            "sleep", "insomnia", "nap", "recovery", "heart", "pulse", "healthkit", "diagnosis",
            "نوم", "أرق", "استشفاء", "نبض", "قلب", "صحة", "طبي", "تشخيص"
        ])
    }

    func containsSleepIntent(in message: String) -> Bool {
        let normalizedMessage = normalizedIntentText(message)

        return Self.sleepIntentPatterns.contains { pattern in
            normalizedMessage.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    func containsAny(_ text: String, keywords: [String]) -> Bool {
        let normalizedText = normalizedIntentText(text)
        return keywords.contains { keyword in
            normalizedText.contains(normalizedIntentText(keyword))
        }
    }

    func normalizedIntentText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "ـ", with: "")
    }

    func encode(_ response: CaptainStructuredResponse) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(response)

        guard let rawText = String(data: data, encoding: .utf8) else {
            throw LocalIntelligenceServiceError.invalidStructuredResponse
        }

        return rawText
    }

    func tokenStream(for rawText: String) -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                for chunk in Self.chunked(rawText, size: 24) {
                    guard !Task.isCancelled else { break }
                    continuation.yield(chunk)
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    nonisolated static func chunked(_ text: String, size: Int) -> [String] {
        guard size > 0, !text.isEmpty else { return [text] }

        var chunks: [String] = []
        var startIndex = text.startIndex

        while startIndex < text.endIndex {
            let endIndex = text.index(startIndex, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[startIndex..<endIndex]))
            startIndex = endIndex
        }

        return chunks
    }
}
