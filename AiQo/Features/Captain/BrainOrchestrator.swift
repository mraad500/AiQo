import Foundation
import os.log

struct BrainOrchestrator: Sendable {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "BrainOrchestrator"
    )
    private enum Route {
        case local
        case cloud
    }

    private let localService: LocalBrainService
    private let cloudService: CloudBrainService
    private let sanitizer: PrivacySanitizer

    init(
        localService: LocalBrainService = LocalBrainService(),
        cloudService: CloudBrainService = CloudBrainService(),
        sanitizer: PrivacySanitizer = PrivacySanitizer()
    ) {
        self.localService = localService
        self.cloudService = cloudService
        self.sanitizer = sanitizer
    }

    func processMessage(
        request: HybridBrainRequest,
        userName: String?
    ) async throws -> HybridBrainServiceReply {
        let routedRequest = requestByInterceptingStrictSleepDataIntent(request)
        let baseReply: HybridBrainServiceReply

        switch route(for: routedRequest) {
        case .local:
            do {
                baseReply = try await generateLocalReply(for: routedRequest)
            } catch let error as AppleIntelligenceSleepAgentError {
                // Apple Intelligence مو متاح — نرسل ملخص النوم (أرقام مجمّعة فقط) للـ cloud
                if case .modelUnavailable(let sleepSummary) = error {
                    baseReply = try await generateCloudSleepReply(
                        originalRequest: routedRequest,
                        sleepSummary: sleepSummary,
                        userName: userName
                    )
                } else {
                    throw error
                }
            }
        case .cloud:
            do {
                logger.notice("cloud_request_started")
                baseReply = try await cloudService.generateReply(
                    request: routedRequest,
                    userName: userName
                )
                logger.notice("cloud_request_succeeded")
            } catch {
                logger.error("cloud_request_failed error=\(error.localizedDescription, privacy: .public)")
                baseReply = try await generateLocalReply(for: routedRequest)
            }
        }

        return makePersonalizedReply(baseReply, userName: userName)
    }

    func startStreamingReply(
        request: HybridBrainRequest,
        userName: String?
    ) async throws -> HybridBrainStreamingSession {
        let reply = try await processMessage(
            request: request,
            userName: userName
        )
        let fallbackResponse = CaptainStructuredResponse(
            message: reply.message,
            quickReplies: reply.quickReplies,
            workoutPlan: reply.workoutPlan,
            mealPlan: reply.mealPlan,
            spotifyRecommendation: reply.spotifyRecommendation
        )

        return HybridBrainStreamingSession(
            tokens: tokenStream(for: reply.rawText),
            fallbackResponse: fallbackResponse
        )
    }
}

private extension BrainOrchestrator {
    static let strictSleepTopicPatterns: [String] = [
        #"\b(?:sleep|slept|sleeping|sleep quality|deep sleep|rem|nap|last night)\b"#,
        #"(?<![\p{L}\p{N}_])(?:نوم|نمت|نومي|نومتك|نومتـي|نومي)(?![\p{L}\p{N}_])"#,
        #"(?<![\p{L}\p{N}_])(?:نوم البارحة|مرحلة النوم|مراحل النوم|النوم العميق|ريم)(?![\p{L}\p{N}_])"#
    ]

    static let strictSleepDataPatterns: [String] = [
        #"\b(?:analy[sz]e|analysis|how much|show me|read|track|score|data|metrics|stages?|healthkit)\b"#,
        #"\b(?:did i sleep well|how did i sleep|how much did i sleep)\b"#,
        #"(?<![\p{L}\p{N}_])(?:تحليل|حلل|شكد|قديش|بيانات|داتا|مراحل|اقرأ|قراية|سكرين|سكور|صحة|هيلث)(?![\p{L}\p{N}_])"#,
        #"(?<![\p{L}\p{N}_])(?:تحليل نومي|بيانات نومي|شلون نمت|شكد نمت|اقرأ نومي|مراحل نومي)(?![\p{L}\p{N}_])"#
    ]

    func requestByInterceptingStrictSleepDataIntent(_ request: HybridBrainRequest) -> HybridBrainRequest {
        guard request.screenContext != .sleepAnalysis,
              isStrictSleepDataRequest(latestUserMessage(in: request)) else {
            return request
        }

        return HybridBrainRequest(
            conversation: request.conversation,
            screenContext: .sleepAnalysis,
            language: request.language,
            contextData: request.contextData,
            userProfileSummary: request.userProfileSummary,
            attachedImageData: nil
        )
    }

    private func route(for request: HybridBrainRequest) -> Route {
        switch request.screenContext {
        case .sleepAnalysis:
            return .local
        case .gym, .kitchen, .peaks, .myVibe, .mainChat:
            return .cloud
        }
    }

    func generateLocalReply(for request: HybridBrainRequest) async throws -> HybridBrainServiceReply {
        let promptRouter = PromptRouter(language: request.language)
        let localRequest = LocalBrainRequest(
            conversation: request.conversation.map {
                LocalConversationMessage(
                    role: localRole(for: $0.role),
                    content: $0.content
                )
            },
            screenContext: request.screenContext,
            language: request.language,
            systemPrompt: promptRouter.generateSystemPrompt(
                for: request.screenContext,
                data: request.contextData
            ),
            contextData: request.contextData,
            userProfileSummary: request.userProfileSummary,
            hasAttachedImage: request.hasAttachedImage
        )

        let reply = try await localService.generateReply(request: localRequest)
        return HybridBrainServiceReply(
            message: CaptainPersonaBuilder.sanitizeResponse(reply.message),
            quickReplies: nil,
            workoutPlan: reply.workoutPlan,
            mealPlan: reply.mealPlan,
            spotifyRecommendation: reply.spotifyRecommendation,
            rawText: reply.rawText
        )
    }

    /// لمّا Apple Intelligence مو متاح، نرسل ملخص النوم المجمّع (بدون بيانات خام) للـ OpenAI API
    func generateCloudSleepReply(
        originalRequest: HybridBrainRequest,
        sleepSummary: String,
        userName: String?
    ) async throws -> HybridBrainServiceReply {
        // نستبدل رسالة المستخدم الأخيرة بالـ sleep context + طلب التحليل
        // هيچي ما تضيع بالـ sanitizer أو الـ truncation
        let sleepUserMessage = """
        حلل نومي.

        بيانات نومي:
        \(sleepSummary)

        اكتب 3 جمل بس بالعراقي. استخدم الأرقام الدقيقة من البيانات. لا تكتب أكثر من 3 جمل.
        """

        var modifiedConversation = originalRequest.conversation
        // نشيل رسالة المستخدم الأخيرة ونحطها بدالها وحدة فيها الـ sleep data
        if let lastUserIndex = modifiedConversation.lastIndex(where: { $0.role == .user }) {
            modifiedConversation[lastUserIndex] = CaptainConversationMessage(
                role: .user,
                content: sleepUserMessage
            )
        } else {
            modifiedConversation.append(CaptainConversationMessage(
                role: .user,
                content: sleepUserMessage
            ))
        }

        let cloudRequest = HybridBrainRequest(
            conversation: modifiedConversation,
            screenContext: .mainChat,
            language: originalRequest.language,
            contextData: originalRequest.contextData,
            userProfileSummary: originalRequest.userProfileSummary,
            attachedImageData: nil
        )

        return try await cloudService.generateReply(
            request: cloudRequest,
            userName: userName
        )
    }

    func makePersonalizedReply(
        _ reply: HybridBrainServiceReply,
        userName: String?
    ) -> HybridBrainServiceReply {
        let personalizedMessage: String
        if let userName, !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            personalizedMessage = sanitizer.injectUserName(
                into: reply.message,
                userName: userName
            )
        } else {
            personalizedMessage = reply.message
        }

        let structuredResponse = CaptainStructuredResponse(
            message: personalizedMessage,
            quickReplies: reply.quickReplies,
            workoutPlan: reply.workoutPlan,
            mealPlan: reply.mealPlan,
            spotifyRecommendation: reply.spotifyRecommendation
        )
        let rawText = try? encode(structuredResponse)

        return HybridBrainServiceReply(
            message: structuredResponse.message,
            quickReplies: structuredResponse.quickReplies,
            workoutPlan: structuredResponse.workoutPlan,
            mealPlan: structuredResponse.mealPlan,
            spotifyRecommendation: structuredResponse.spotifyRecommendation,
            rawText: rawText ?? reply.rawText
        )
    }

    func localRole(for role: CaptainConversationRole) -> LocalConversationRole {
        switch role {
        case .system:
            return .system
        case .user:
            return .user
        case .assistant:
            return .assistant
        }
    }

    func latestUserMessage(in request: HybridBrainRequest) -> String {
        request.conversation.last(where: { $0.role == .user })?.content ?? ""
    }

    func requiresCloudPlanning(for message: String) -> Bool {
        containsAny(message, keywords: [
            "plan", "routine", "program", "meal plan", "workout plan", "weekly", "schedule",
            "split", "macros", "recipe", "challenge", "build me", "create me",
            "خطة", "برنامج", "روتين", "جدول", "اسبوع", "أسبوع", "وجبات", "تمرين", "تمارين",
            "ماكروز", "وصفة", "تحدي", "رتبلي", "سوّيلي", "سويلي", "ابنيلي"
        ])
    }

    func isStrictSleepDataRequest(_ message: String) -> Bool {
        let normalized = normalizedIntentText(message)
        let hasSleepTopic = Self.strictSleepTopicPatterns.contains { pattern in
            normalized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        guard hasSleepTopic else { return false }

        return Self.strictSleepDataPatterns.contains { pattern in
            normalized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
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
            throw LocalBrainServiceError.invalidStructuredResponse
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
