import Foundation
import os.log

/// The Routing Engine — routes requests between local (on-device) and cloud (Gemini API).
///
/// Routing Rules:
/// - `.sleepAnalysis` → ALWAYS local (raw sleep stages NEVER leave the device)
/// - `.gym`, `.kitchen`, `.peaks`, `.myVibe`, `.mainChat` → Cloud (Gemini)
///
/// Fallback Chain: Cloud fails → Local fallback → Localized error message
struct BrainOrchestrator: Sendable {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "BrainOrchestrator"
    )

    private let localService: LocalBrainService
    private let cloudService: CloudBrainService
    private let sanitizer: PrivacySanitizer
    private let sleepAgent: AppleIntelligenceSleepAgent

    init(
        localService: LocalBrainService = LocalBrainService(),
        cloudService: CloudBrainService = CloudBrainService(),
        sanitizer: PrivacySanitizer = PrivacySanitizer(),
        sleepAgent: AppleIntelligenceSleepAgent = AppleIntelligenceSleepAgent()
    ) {
        self.localService = localService
        self.cloudService = cloudService
        self.sanitizer = sanitizer
        self.sleepAgent = sleepAgent
    }

    // MARK: - Public API

    func processMessage(
        request: HybridBrainRequest,
        userName: String?
    ) async throws -> HybridBrainServiceReply {
        let routedRequest = interceptSleepIntent(request)
        let baseReply: HybridBrainServiceReply

        switch route(for: routedRequest) {
        case .local:
            baseReply = await processLocalRoute(request: routedRequest, userName: userName)

        case .cloud:
            baseReply = await processCloudRoute(request: routedRequest, userName: userName)
        }

        return personalizeReply(baseReply, userName: userName)
    }

    func startStreamingReply(
        request: HybridBrainRequest,
        userName: String?
    ) async throws -> HybridBrainStreamingSession {
        let reply = try await processMessage(request: request, userName: userName)
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

// MARK: - Routing Logic

private extension BrainOrchestrator {

    enum Route {
        case local
        case cloud
    }

    /// Strict routing: sleep → local, everything else → cloud
    func route(for request: HybridBrainRequest) -> Route {
        switch request.screenContext {
        case .sleepAnalysis:
            return .local
        case .gym, .kitchen, .peaks, .myVibe, .mainChat:
            return .cloud
        }
    }

    // MARK: - Sleep Intent Interception

    /// Detects sleep-related queries and forces them to the local route
    func interceptSleepIntent(_ request: HybridBrainRequest) -> HybridBrainRequest {
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
            intentSummary: request.intentSummary,
            workingMemorySummary: request.workingMemorySummary,
            attachedImageData: nil
        )
    }

    // MARK: - Local Route Processing

    func processLocalRoute(
        request: HybridBrainRequest,
        userName: String?
    ) async -> HybridBrainServiceReply {
        do {
            return try await generateLocalReply(for: request)
        } catch let error as AppleIntelligenceSleepAgentError {
            return await handleSleepAgentError(error, request: request, userName: userName)
        } catch {
            logger.error("local_route_failed error=\(error.localizedDescription, privacy: .public)")
            return makeLocalizedErrorReply(language: request.language)
        }
    }

    func handleSleepAgentError(
        _ error: AppleIntelligenceSleepAgentError,
        request: HybridBrainRequest,
        userName: String?
    ) async -> HybridBrainServiceReply {
        switch error {
        case .modelUnavailable(let sleepSummary, let session):
            // Apple Intelligence unavailable → try cloud with aggregated summary → computed fallback
            do {
                return try await generateCloudSleepReply(
                    originalRequest: request,
                    sleepSummary: sleepSummary,
                    userName: userName
                )
            } catch {
                logger.error("cloud_sleep_fallback_failed error=\(error.localizedDescription, privacy: .public)")
                return makeComputedSleepReply(session: session, language: request.language)
            }

        case .emptyResponse(let session):
            do {
                let summary = sleepAgent.buildArabicSummary(for: session)
                return try await generateCloudSleepReply(
                    originalRequest: request,
                    sleepSummary: summary,
                    userName: userName
                )
            } catch {
                logger.error("cloud_sleep_fallback_failed error=\(error.localizedDescription, privacy: .public)")
                return makeComputedSleepReply(session: session, language: request.language)
            }
        case .lowQualityResponse(let sleepSummary, let session, let message):
            logger.notice("sleep_agent_low_quality_fallback message=\(message, privacy: .public)")
            do {
                return try await generateCloudSleepReply(
                    originalRequest: request,
                    sleepSummary: sleepSummary,
                    userName: userName
                )
            } catch {
                logger.error("cloud_sleep_fallback_failed error=\(error.localizedDescription, privacy: .public)")
                return makeComputedSleepReply(session: session, language: request.language)
            }
        }
    }

    // MARK: - Cloud Route Processing

    func processCloudRoute(
        request: HybridBrainRequest,
        userName: String?
    ) async -> HybridBrainServiceReply {
        do {
            logger.notice("cloud_request_started")
            let reply = try await cloudService.generateReply(request: request, userName: userName)
            logger.notice("cloud_request_succeeded")
            return reply
        } catch {
            logger.error("cloud_request_failed error=\(error.localizedDescription, privacy: .public)")

            // If the cloud call itself failed with a network-level error (bad status, no connection)
            // we SKIP the Apple Intelligence local fallback entirely — it will also fail due to
            // language mismatch (ar-SA vs en) and throw "GenerativeModelsAvailability is unavailable".
            // Return the hardcoded offline message directly to avoid a second crash.
            if isAppleIntelligenceSkippableError(error) || isNetworkError(error) {
                logger.notice("apple_intelligence_skipped reason=cloud_error_implies_local_unavailable")
                return makeNetworkErrorReply(language: request.language)
            }

            // Otherwise try Apple Intelligence as a local fallback
            do {
                return try await generateLocalReply(for: request)
            } catch {
                logger.error("local_fallback_failed error=\(error.localizedDescription, privacy: .public)")
                return makeNetworkErrorReply(language: request.language)
            }
        }
    }

    // MARK: - Local Reply Generation

    func generateLocalReply(for request: HybridBrainRequest) async throws -> HybridBrainServiceReply {
        let promptRouter = PromptRouter(language: request.language)
        let localRequest = LocalBrainRequest(
            conversation: request.conversation.map {
                LocalConversationMessage(role: localRole(for: $0.role), content: $0.content)
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

    // MARK: - Cloud Sleep Fallback (aggregated summary only — no raw stages)

    func generateCloudSleepReply(
        originalRequest: HybridBrainRequest,
        sleepSummary: String,
        userName: String?
    ) async throws -> HybridBrainServiceReply {
        let sleepUserMessage = buildCloudSleepPrompt(
            language: originalRequest.language,
            lastUserMessage: latestUserMessage(in: originalRequest),
            sleepSummary: sleepSummary
        )

        var modifiedConversation = originalRequest.conversation
        if let lastUserIndex = modifiedConversation.lastIndex(where: { $0.role == .user }) {
            modifiedConversation[lastUserIndex] = CaptainConversationMessage(
                role: .user,
                content: sleepUserMessage
            )
        } else {
            modifiedConversation.append(CaptainConversationMessage(role: .user, content: sleepUserMessage))
        }

        let cloudRequest = HybridBrainRequest(
            conversation: modifiedConversation,
            screenContext: .sleepAnalysis,
            language: originalRequest.language,
            contextData: originalRequest.contextData,
            userProfileSummary: originalRequest.userProfileSummary,
            intentSummary: originalRequest.intentSummary,
            workingMemorySummary: originalRequest.workingMemorySummary,
            attachedImageData: nil
        )

        return try await cloudService.generateReply(request: cloudRequest, userName: userName)
    }

    // MARK: - Computed Sleep Reply (fully on-device, no AI)

    func makeComputedSleepReply(
        session: SleepSession,
        language: AppLanguage
    ) -> HybridBrainServiceReply {
        let message = sleepAgent.availabilityFallback(
            for: session,
            reasonDescription: "cloud_and_local_unavailable"
        )
        let sanitizedMessage = CaptainPersonaBuilder.sanitizeResponse(message)
        let structuredResponse = CaptainStructuredResponse(message: sanitizedMessage)
        let rawText = (try? encode(structuredResponse)) ?? sanitizedMessage

        return HybridBrainServiceReply(
            message: sanitizedMessage,
            quickReplies: nil,
            workoutPlan: nil,
            mealPlan: nil,
            spotifyRecommendation: nil,
            rawText: rawText
        )
    }

    // MARK: - Network / Offline Error Reply

    /// Returns a warm, human-readable offline message in the user's language.
    /// Used when both cloud AND local Apple Intelligence are unavailable.
    func makeNetworkErrorReply(language: AppLanguage) -> HybridBrainServiceReply {
        let message = language == .arabic
            ? CaptainFallbackPolicy.networkErrorArabic()
            : CaptainFallbackPolicy.networkErrorEnglish()

        let structuredResponse = CaptainStructuredResponse(message: message)
        let rawText = (try? encode(structuredResponse)) ?? message

        return HybridBrainServiceReply(
            message: message,
            quickReplies: nil,
            workoutPlan: nil,
            mealPlan: nil,
            spotifyRecommendation: nil,
            rawText: rawText
        )
    }

    // MARK: - Localized Error Fallback (final safety net)

    func makeLocalizedErrorReply(language: AppLanguage) -> HybridBrainServiceReply {
        let message: String
        if language == .arabic {
            message = CaptainFallbackPolicy.genericArabicFallback()
        } else {
            message = CaptainFallbackPolicy.genericEnglishFallback()
        }

        let structuredResponse = CaptainStructuredResponse(message: message)
        let rawText = (try? encode(structuredResponse)) ?? message

        return HybridBrainServiceReply(
            message: message,
            quickReplies: nil,
            workoutPlan: nil,
            mealPlan: nil,
            spotifyRecommendation: nil,
            rawText: rawText
        )
    }

    // MARK: - Error Classification Helpers

    /// Returns true for any HybridBrainServiceError that implies the local Apple Intelligence
    /// path will also fail (network down, bad status, etc.).
    func isAppleIntelligenceSkippableError(_ error: Error) -> Bool {
        guard let brainError = error as? HybridBrainServiceError else { return false }
        switch brainError {
        case .networkUnavailable, .badStatusCode, .requestFailed, .emptyResponse, .invalidResponse:
            return true
        case .emptyConversation, .missingUserMessage, .invalidStructuredResponse,
             .missingAPIKey, .invalidEndpoint:
            return false
        }
    }

    /// Returns true for low-level NSURLError network failures.
    func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else {
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                return isNetworkError(underlying)
            }
            return false
        }
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost:
            return true
        default:
            return false
        }
    }

    // MARK: - Personalization

    func personalizeReply(
        _ reply: HybridBrainServiceReply,
        userName: String?
    ) -> HybridBrainServiceReply {
        let personalizedMessage: String
        if let userName, !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            personalizedMessage = sanitizer.injectUserName(into: reply.message, userName: userName)
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

    // MARK: - Helpers

    func localRole(for role: CaptainConversationRole) -> LocalConversationRole {
        switch role {
        case .system:    return .system
        case .user:      return .user
        case .assistant: return .assistant
        }
    }

    func latestUserMessage(in request: HybridBrainRequest) -> String {
        request.conversation.last(where: { $0.role == .user })?.content ?? ""
    }

    func buildCloudSleepPrompt(
        language: AppLanguage,
        lastUserMessage: String,
        sleepSummary: String
    ) -> String {
        let userQuestion = lastUserMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (language == .arabic ? "حلل نومي." : "Analyze my sleep.")
            : lastUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        if language == .english {
            return """
            Analyze the user's sleep using ONLY the following aggregated data.

            User question:
            \(userQuestion)

            Sleep data:
            \(sleepSummary)

            Write exactly 3 short English sentences:
            1. Give a clear verdict: good, average, or poor sleep, and say why.
            2. Mention the most important number or sleep stage and what it means for recovery, focus, or energy.
            3. Give one practical action for tonight.

            Rules:
            - Use only the provided numbers.
            - Be direct and useful, not vague.
            - If total sleep is under 7 hours, say clearly that it is not enough.
            """
        }

        return """
        حلل نوم المستخدم اعتماداً على البيانات التالية فقط.

        سؤال المستخدم:
        \(userQuestion)

        بيانات النوم:
        \(sleepSummary)

        اكتب 3 جمل قصيرة بالعراقي:
        1. احكم بصراحة إذا النوم زين لو متوسط لو مو زين وليش.
        2. اذكر أهم رقم أو مرحلة نوم وشنو معناها على التعافي أو التركيز أو الطاقة.
        3. أعطِ خطوة وحدة عملية يسويها الليلة.

        قواعد:
        - استخدم الأرقام الموجودة فقط.
        - لا تكن عام ولا ضبابي.
        - إذا النوم أقل من 7 ساعات كولها بوضوح إنه مو كافي.
        """
    }

    func encode(_ response: CaptainStructuredResponse) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(response)
        guard let rawText = String(data: data, encoding: .utf8) else {
            throw HybridBrainServiceError.invalidStructuredResponse
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
            continuation.onTermination = { _ in task.cancel() }
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

    // MARK: - Sleep Intent Detection

    static let sleepTopicPatterns: [String] = [
        #"\b(?:sleep|slept|sleeping|sleep quality|deep sleep|rem|nap|last night)\b"#,
        #"(?<![\p{L}\p{N}_])(?:نوم|نمت|نومي|نومتك|نومتـي)(?![\p{L}\p{N}_])"#,
        #"(?<![\p{L}\p{N}_])(?:نوم البارحة|مرحلة النوم|مراحل النوم|النوم العميق|ريم)(?![\p{L}\p{N}_])"#
    ]

    static let sleepDataPatterns: [String] = [
        #"\b(?:analy[sz]e|analysis|how much|show me|read|track|score|data|metrics|stages?|healthkit)\b"#,
        #"\b(?:did i sleep well|how did i sleep|how much did i sleep)\b"#,
        #"(?<![\p{L}\p{N}_])(?:تحليل|حلل|شكد|قديش|بيانات|داتا|مراحل|اقرأ|قراية|سكرين|سكور|صحة|هيلث)(?![\p{L}\p{N}_])"#,
        #"(?<![\p{L}\p{N}_])(?:تحليل نومي|بيانات نومي|شلون نمت|شكد نمت|اقرأ نومي|مراحل نومي)(?![\p{L}\p{N}_])"#
    ]

    func isStrictSleepDataRequest(_ message: String) -> Bool {
        let normalized = message
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "ـ", with: "")

        let hasSleepTopic = Self.sleepTopicPatterns.contains { pattern in
            normalized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        guard hasSleepTopic else { return false }

        return Self.sleepDataPatterns.contains { pattern in
            normalized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
