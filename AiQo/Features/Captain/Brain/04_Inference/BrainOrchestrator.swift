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
    private let sleepQualityEvaluator = SleepAnalysisQualityEvaluator()

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
        let safetyDecision = await wellbeingDecision(for: routedRequest)

        if case .professionalReferral(let urgency) = safetyDecision {
            return makeSafetyReferralReply(
                language: routedRequest.language,
                urgency: urgency
            )
        }

        if !DevOverride.unlockAllFeatures,
           route(for: routedRequest) == .cloud,
           !TierGate.shared.canAccess(.captainChat) {
            diag.info("BrainOrchestrator.processMessage blocked by TierGate(.captainChat)")
            return makeTierRequiredReply(
                language: routedRequest.language,
                requiredTier: TierGate.shared.requiredTier(for: .captainChat)
            )
        }
        let baseReply: HybridBrainServiceReply

        switch route(for: routedRequest) {
        case .local:
            baseReply = await processLocalRoute(request: routedRequest, userName: userName)

        case .cloud:
            baseReply = await processCloudRoute(request: routedRequest, userName: userName)
        }

        let personalizedReply = personalizeReply(
            baseReply,
            userName: userName,
            screenContext: routedRequest.screenContext
        )

        return applySafetyDecision(
            safetyDecision,
            to: personalizedReply,
            language: routedRequest.language
        )
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
            attachedImageData: nil,
            purpose: request.purpose
        )
    }

    // MARK: - Wellbeing Intervention

    func wellbeingDecision(for request: HybridBrainRequest) async -> InterventionPolicy.Decision {
        let message = latestUserMessage(in: request).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return .doNothing }

        let signal = await CrisisDetector.shared.evaluate(message: message)
        await SafetyNet.shared.record(signal)
        return await SafetyNet.shared.shouldIntervene(
            for: signal,
            language: request.language
        )
    }

    // MARK: - Local Route Processing

    func processLocalRoute(
        request: HybridBrainRequest,
        userName: String?
    ) async -> HybridBrainServiceReply {
        do {
            let reply = try await generateLocalReply(for: request)
            await persistIfMemoryEnabled(request: request, reply: reply)
            return reply
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
        case .modelUnavailable(_, let session):
            // Apple Intelligence unavailable → try cloud with aggregated summary → computed fallback
            do {
                return try await generateCloudSleepReply(
                    originalRequest: request,
                    session: session,
                    userName: userName
                )
            } catch {
                logger.error("cloud_sleep_fallback_failed error=\(error.localizedDescription, privacy: .public)")
                return makeComputedSleepReply(session: session, language: request.language)
            }

        case .emptyResponse(let session):
            do {
                return try await generateCloudSleepReply(
                    originalRequest: request,
                    session: session,
                    userName: userName
                )
            } catch {
                logger.error("cloud_sleep_fallback_failed error=\(error.localizedDescription, privacy: .public)")
                return makeComputedSleepReply(session: session, language: request.language)
            }
        case .lowQualityResponse(_, let session, let message):
            logger.notice("sleep_agent_low_quality_fallback message=\(message, privacy: .public)")
            do {
                return try await generateCloudSleepReply(
                    originalRequest: request,
                    session: session,
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
            await persistIfMemoryEnabled(request: request, reply: reply)
            return reply
        } catch {
            if let brainError = error as? BrainError,
               case .tierRequired(let requiredTier) = brainError {
                logger.notice("cloud_request_blocked_by_tier")
                return makeTierRequiredReply(
                    language: request.language,
                    requiredTier: requiredTier
                )
            }
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
                let reply = try await generateLocalReply(for: request)
                await persistIfMemoryEnabled(request: request, reply: reply)
                return reply
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
        session: SleepSession,
        userName: String?
    ) async throws -> HybridBrainServiceReply {
        let sleepSummary = buildCloudSleepSummary(
            for: session,
            language: originalRequest.language
        )
        let primaryPrompt = buildCloudSleepPrompt(
            language: originalRequest.language,
            lastUserMessage: latestUserMessage(in: originalRequest),
            sleepSummary: sleepSummary,
            isRetry: false
        )
        let primaryReply = try await cloudService.generateReply(
            request: makeCloudSleepRequest(
                originalRequest: originalRequest,
                prompt: primaryPrompt
            ),
            userName: userName
        )

        guard sleepQualityEvaluator.isUseful(message: primaryReply.message, session: session) else {
            logger.notice("cloud_sleep_low_quality_primary")

            let retryPrompt = buildCloudSleepPrompt(
                language: originalRequest.language,
                lastUserMessage: latestUserMessage(in: originalRequest),
                sleepSummary: sleepSummary,
                isRetry: true
            )
            let retryReply = try await cloudService.generateReply(
                request: makeCloudSleepRequest(
                    originalRequest: originalRequest,
                    prompt: retryPrompt
                ),
                userName: userName
            )

            guard sleepQualityEvaluator.isUseful(message: retryReply.message, session: session) else {
                logger.notice("cloud_sleep_low_quality_retry")
                return makeComputedSleepReply(session: session, language: originalRequest.language)
            }

            await persistIfMemoryEnabled(request: originalRequest, reply: retryReply)
            return retryReply
        }

        await persistIfMemoryEnabled(request: originalRequest, reply: primaryReply)
        return primaryReply
    }

    func makeCloudSleepRequest(
        originalRequest: HybridBrainRequest,
        prompt: String
    ) -> HybridBrainRequest {
        HybridBrainRequest(
            conversation: [
                CaptainConversationMessage(
                    role: .user,
                    content: prompt
                )
            ],
            screenContext: .sleepAnalysis,
            language: originalRequest.language,
            contextData: originalRequest.contextData,
            userProfileSummary: originalRequest.userProfileSummary,
            intentSummary: originalRequest.intentSummary,
            workingMemorySummary: originalRequest.workingMemorySummary,
            attachedImageData: nil,
            purpose: originalRequest.purpose
        )
    }

    // MARK: - Computed Sleep Reply (fully on-device, no AI)

    func makeComputedSleepReply(
        session: SleepSession,
        language: AppLanguage
    ) -> HybridBrainServiceReply {
        let message = sleepAgent.availabilityFallback(
            for: session,
            reasonDescription: "cloud_and_local_unavailable",
            language: language
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

    func makeTierRequiredReply(
        language: AppLanguage,
        requiredTier: SubscriptionTier
    ) -> HybridBrainServiceReply {
        let message = language == .arabic
            ? "هاي الميزة تحتاج \(requiredTier.displayName)."
            : "This feature requires \(requiredTier.displayName)."

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

    func makeSafetyReferralReply(
        language: AppLanguage,
        urgency: InterventionPolicy.Decision.Urgency
    ) -> HybridBrainServiceReply {
        let message = ProfessionalReferral.supportMessage(
            language: language,
            urgency: urgency
        )

        let structuredResponse = CaptainStructuredResponse(message: message)
        let rawText = (try? encode(structuredResponse)) ?? message

        return HybridBrainServiceReply(
            message: structuredResponse.message,
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
        userName: String?,
        screenContext: ScreenContext
    ) -> HybridBrainServiceReply {
        let personalizedMessage: String
        if screenContext == .sleepAnalysis {
            personalizedMessage = reply.message
        } else if let userName, !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            personalizedMessage = sanitizer.injectUserName(into: reply.message, userName: userName)
        } else {
            personalizedMessage = reply.message
        }

        let structuredResponse = CaptainStructuredResponse(
            message: personalizedMessage,
            quickReplies: screenContext == .sleepAnalysis ? nil : reply.quickReplies,
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

    func applySafetyDecision(
        _ decision: InterventionPolicy.Decision,
        to reply: HybridBrainServiceReply,
        language: AppLanguage
    ) -> HybridBrainServiceReply {
        let safetyPrefix: String?

        switch decision {
        case .doNothing:
            safetyPrefix = nil

        case .gentleCheckIn:
            safetyPrefix = language == .arabic
                ? "بس قبل ما نكمل: شلونك اليوم؟"
                : "Before we continue: how are you doing today?"

        case .reflectiveMessage(let text):
            safetyPrefix = text

        case .professionalReferral(let urgency):
            return makeSafetyReferralReply(language: language, urgency: urgency)
        }

        guard let safetyPrefix,
              !safetyPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return reply
        }

        let message = "\(safetyPrefix)\n\n\(reply.message)"
        let structuredResponse = CaptainStructuredResponse(
            message: message,
            quickReplies: reply.quickReplies,
            workoutPlan: reply.workoutPlan,
            mealPlan: reply.mealPlan,
            spotifyRecommendation: reply.spotifyRecommendation
        )
        let rawText = (try? encode(structuredResponse)) ?? message

        return HybridBrainServiceReply(
            message: structuredResponse.message,
            quickReplies: structuredResponse.quickReplies,
            workoutPlan: structuredResponse.workoutPlan,
            mealPlan: structuredResponse.mealPlan,
            spotifyRecommendation: structuredResponse.spotifyRecommendation,
            rawText: rawText
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
        sleepSummary: String,
        isRetry: Bool
    ) -> String {
        let userQuestion = lastUserMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (language == .arabic ? "حلل نومي." : "Analyze my sleep.")
            : lastUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        if language == .english {
            return """
            Analyze the user's sleep using ONLY the following aggregated data.
            \(isRetry ? "Your previous analysis was too generic. Rewrite it with concrete evidence from the data below." : "")

            Original user question:
            \(userQuestion)

            Sleep data:
            \(sleepSummary)

            Return JSON only in this exact shape:
            {"message":"...","quickReplies":null,"workoutPlan":null,"mealPlan":null,"spotifyRecommendation":null}

            Message rules:
            1. Write exactly 4 short English sentences.
            2. Sentence 1: clear verdict (good, average, or poor) and why.
            3. Sentence 2: explain deep sleep % and core sleep % using the real numbers, and what they mean for physical recovery.
            4. Sentence 3: explain REM sleep % using the real number, and mention awake time only if it adds value for focus, mood, or mental recovery.
            5. Sentence 4: end with one practical action for tonight specifically to improve sleep-stage quality.

            Rules:
            - Use only the provided numbers.
            - Be direct, specific, and useful.
            - If total sleep is under 7 hours, say clearly that it is not enough.
            - Generic replies like "sleep is important" or "your body needs rest" are failures.
            - Mention stage percentages explicitly when stage data exists.
            - Do not mention any number that is not present in the data.
            """
        }

        return """
        حلل نوم المستخدم اعتماداً على البيانات التالية فقط.
        \(isRetry ? "تحليلك السابق كان عام وضعيف. أعد كتابته بصورة أدق واعتمد على الأرقام نفسها فقط." : "")

        سؤال المستخدم الأصلي:
        \(userQuestion)

        بيانات النوم:
        \(sleepSummary)

        أرجع JSON فقط بهذا الشكل:
        {"message":"...","quickReplies":null,"workoutPlan":null,"mealPlan":null,"spotifyRecommendation":null}

        قواعد حقل message:
        1. اكتب بالضبط 4 جمل قصيرة بالعراقي.
        2. الجملة الأولى: احكم بصراحة إذا النوم زين لو متوسط لو مو زين وليش.
        3. الجملة الثانية: اشرح نسبة النوم العميق ونسبة النوم الأساسي من البيانات وشنو تعني على التعافي الجسدي.
        4. الجملة الثالثة: اشرح نسبة REM من البيانات، واذكر الاستيقاظ إذا كان مؤثر على التركيز أو المزاج.
        5. الجملة الرابعة: اختم بنصيحة وحدة عملية مخصوصة لتحسين جودة مراحل النوم الليلة.

        قواعد:
        - استخدم الأرقام الموجودة فقط.
        - كن واضح ومحدد، مو عام.
        - إذا النوم أقل من 7 ساعات كولها بوضوح إنه مو كافي.
        - الردود العامة مثل "النوم مهم" أو "جسمك يحتاج راحة" تعتبر فشل.
        - إذا موجودة بيانات مراحل النوم، لازم تذكر نسب المراحل بشكل صريح.
        - ممنوع تذكر أي رقم مو موجود بالبيانات.
        """
    }

    func buildCloudSleepSummary(
        for session: SleepSession,
        language: AppLanguage
    ) -> String {
        let totalHours = session.totalMinutes / 60
        let totalMinutes = session.totalMinutes % 60
        let deepPercent = String(format: "%.1f", session.deepPercentage)
        let corePercent = String(format: "%.1f", session.corePercentage)
        let remPercent = String(format: "%.1f", session.remPercentage)

        if language == .english {
            var parts = [
                "Total sleep: \(totalHours)h \(totalMinutes)m. Recommended range: 7-9h."
            ]

            if session.deepMinutes > 0 || session.remMinutes > 0 || session.coreMinutes > 0 {
                parts.append("Deep sleep: \(session.deepMinutes) minutes (\(deepPercent)%). Recommended: 15-25%.")
                parts.append("Core sleep: \(session.coreMinutes) minutes (\(corePercent)%). Typical range: about 45-55%.")
                parts.append("REM sleep: \(session.remMinutes) minutes (\(remPercent)%). Recommended: 20-25%.")
            }

            if session.awakeMinutes > 0 {
                parts.append("Awake during the night: \(session.awakeMinutes) minutes.")
            }

            return parts.joined(separator: "\n")
        }

        var parts = [
            "إجمالي النوم: \(totalHours) ساعة و\(totalMinutes) دقيقة. المدى الموصى به: 7-9 ساعات."
        ]

        if session.deepMinutes > 0 || session.remMinutes > 0 || session.coreMinutes > 0 {
            parts.append("النوم العميق: \(session.deepMinutes) دقيقة (\(deepPercent)٪). الموصى به: 15-25٪.")
            parts.append("النوم الأساسي: \(session.coreMinutes) دقيقة (\(corePercent)٪). الطبيعي تقريباً 45-55٪.")
            parts.append("نوم REM: \(session.remMinutes) دقيقة (\(remPercent)٪). الموصى به: 20-25٪.")
        }

        if session.awakeMinutes > 0 {
            parts.append("الاستيقاظ أثناء الليل: \(session.awakeMinutes) دقيقة.")
        }

        return parts.joined(separator: "\n")
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

// MARK: - Memory Persistence Hook (BATCH 3a)

private extension BrainOrchestrator {
    /// Persists a successful LLM exchange to EpisodicStore and kicks off non-blocking
    /// fact extraction into SemanticStore. Only runs when MEMORY_V4_ENABLED.
    /// Never called on error / fallback paths — we don't poison memory with canned replies.
    func persistIfMemoryEnabled(
        request: HybridBrainRequest,
        reply: HybridBrainServiceReply
    ) async {
        guard FeatureFlags.memoryV4Enabled else { return }

        let userMessage = latestUserMessage(in: request)
        let captainResponse = reply.message
        guard !userMessage.isEmpty, !captainResponse.isEmpty else { return }

        let episodeID = await EpisodicStore.shared.record(
            userMessage: userMessage,
            captainResponse: captainResponse
        )

        Task.detached(priority: .utility) {
            let candidates = await FactExtractor.shared.extract(
                userMessage: userMessage,
                captainResponse: captainResponse,
                maxFacts: 3
            )
            let persistable = candidates.filter { !$0.sensitive }
            guard !persistable.isEmpty else { return }

            let related: [UUID] = episodeID.map { [$0] } ?? []
            for candidate in persistable {
                _ = await SemanticStore.shared.addOrReinforce(
                    content: candidate.content,
                    category: candidate.category,
                    confidence: candidate.confidence,
                    source: .extracted,
                    isPII: false,
                    isSensitive: false,
                    relatedEntryIDs: related
                )
            }
            diag.info("BrainOrchestrator.persistIfMemoryEnabled: wrote \(persistable.count) facts (episode=\(episodeID?.uuidString ?? "nil"))")
        }
    }
}
