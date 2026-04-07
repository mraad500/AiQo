import Foundation
import os.log
import SwiftUI
import Combine

protocol CoachBrainTranslating: Sendable {
    func translate(_ text: String, systemPrompt: String) async throws -> String
}

struct CoachBrainLLMTranslator: CoachBrainTranslating {
    private struct GeminiTranslationResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String?
                }

                let parts: [Part]?
            }

            let content: Content?
        }

        let candidates: [Candidate]?

        var outputText: String {
            candidates?
                .compactMap { $0.content }
                .flatMap { $0.parts ?? [] }
                .compactMap(\.text)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
    }

    enum Error: LocalizedError, Equatable {
        case networkUnavailable
        case requestFailed
        case badStatusCode(Int)
        case invalidResponse
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .networkUnavailable:
                return "Coach Brain translation service is unavailable."
            case .requestFailed:
                return "Coach Brain translation request failed."
            case let .badStatusCode(statusCode):
                return "Coach Brain translation API returned status code \(statusCode)."
            case .invalidResponse:
                return "Coach Brain translation API returned an invalid response."
            case .emptyResponse:
                return "Coach Brain translation API returned an empty response."
            }
        }
    }

    private let session: URLSession
    private let bundle: Bundle
    private let processInfo: ProcessInfo
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CoachBrainTranslator"
    )

    init(
        session: URLSession = .shared,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) {
        self.session = session
        self.bundle = bundle
        self.processInfo = processInfo
    }

    func translate(_ text: String, systemPrompt: String) async throws -> String {
        let payload = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else {
            throw Error.emptyResponse
        }

        let configuration = try CoachBrainTranslationConfig.resolve(
            bundle: bundle,
            processInfo: processInfo
        )

        let endpointWithKey = appendAPIKey(
            to: configuration.endpointURL,
            apiKey: configuration.apiKey
        )

        var request = URLRequest(url: endpointWithKey)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": payload]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 180
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let networkUnavailable = isNetworkUnavailable(error)
            let category = networkUnavailable ? "network_unavailable" : "request_failed"
            logger.error("translation_request_failed category=\(category, privacy: .public)")
            throw networkUnavailable
                ? CoachBrainLLMTranslator.Error.networkUnavailable
                : CoachBrainLLMTranslator.Error.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw Error.badStatusCode(httpResponse.statusCode)
        }

        let decoded: GeminiTranslationResponse
        do {
            decoded = try JSONDecoder().decode(GeminiTranslationResponse.self, from: data)
        } catch {
            throw Error.invalidResponse
        }

        let translated = decoded.outputText
        guard !translated.isEmpty else {
            throw Error.emptyResponse
        }

        return translated
    }

    private func appendAPIKey(to url: URL, apiKey: String) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        components.queryItems = queryItems
        return components.url ?? url
    }

    private func isNetworkUnavailable(_ error: Swift.Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost:
                return true
            default:
                break
            }
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Swift.Error {
            return isNetworkUnavailable(underlying)
        }

        return false
    }
}

enum CoachBrainMiddlewareError: LocalizedError {
    case emptyUserInput
    case emptyEnglishIntent
    case emptyAppleReply
    case emptyArabicReply

    var errorDescription: String? {
        switch self {
        case .emptyUserInput:
            return "The user message was empty."
        case .emptyEnglishIntent:
            return "The translated English intent was empty."
        case .emptyAppleReply:
            return "The on-device coach returned an empty reply."
        case .emptyArabicReply:
            return "The translated Arabic reply was empty."
        }
    }
}

enum CoachBrainPhase: Equatable, Sendable {
    case idle
    case reading
    case translatingInput
    case thinking
    case translatingOutput
    case preparingReply
}

private enum LocalCaptainIntent: Equatable, Sendable {
    case greeting
    case healthOverview
    case explainAiQo
    case currentTime
    case currentDate
    case recovery
    case nutrition
    case workout
    case stress
}

@MainActor
final class CoachBrainMiddleware: ObservableObject {
    @Published var isAnalyzingEnergy: Bool = false
    @Published private(set) var lastResolvedEnglishIntent: String?
    @Published private(set) var lastPipelineError: String?
    @Published private(set) var lastInjectedSystemContext: String?
    @Published private(set) var phase: CoachBrainPhase = .idle
    @Published private(set) var liveStatusText: String?
#if DEBUG
    @Published private(set) var debugDiagnosticMessage: String?
#endif

    private let translator: any CoachBrainTranslating
    private let intelligenceManager: CaptainIntelligenceManager
    private let contextBuilder: CaptainContextBuilder
    private let sanitizer = PrivacySanitizer()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CoachBrainMiddleware"
    )

    private let inputTranslationPrompt = "Translate the user's Arabic message to clear English only. Return plain English text with no Arabic and no commentary."
    private let outputTranslationPrompt = "Translate the text to clear, friendly Iraqi Arabic only. Return Iraqi Arabic only with no English and no extra commentary."
    private let genericFallbackArabicMessage = "أنا حاضر وياك. احچيلي شنو تريد بالضبط، وأنا أرتبه إلك بشكل واضح وعملي."

    init(
        translator: (any CoachBrainTranslating)? = nil,
        intelligenceManager: CaptainIntelligenceManager? = nil,
        contextBuilder: CaptainContextBuilder? = nil
    ) {
        self.translator = translator ?? CoachBrainLLMTranslator()
        self.intelligenceManager = intelligenceManager ?? .shared
        self.contextBuilder = contextBuilder ?? .shared
    }

    func processArabicMessage(_ rawMessage: String) async -> String {
        let message = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !message.isEmpty else {
            lastPipelineError = CoachBrainMiddlewareError.emptyUserInput.localizedDescription
            return genericFallbackArabicMessage
        }

        logInputLanguageDetection(isArabic: true)
#if DEBUG
        debugDiagnosticMessage = nil
#endif
        let systemContext = await contextBuilder.buildSystemContext()
        let gracefulFallback = await fallbackReply(for: message)
        lastInjectedSystemContext = systemContext.systemPrefix

        defer {
            phase = .idle
            liveStatusText = nil
            isAnalyzingEnergy = false
        }

        await transition(to: .reading, minimumDuration: 0.35)
        isAnalyzingEnergy = true
        lastPipelineError = nil

        do {
            try Task.checkCancellation()
            let normalizedEnglishIntent: String
            do {
                normalizedEnglishIntent = try await resolveEnglishIntent(for: message)
            } catch let error as CancellationError {
                throw error
            } catch {
                return handleTranslationUnavailable(
                    for: message,
                    stage: "input",
                    error: error
                )
            }

            lastResolvedEnglishIntent = normalizedEnglishIntent
            let reasoningContext = buildReasoningContext(
                systemPrefix: systemContext.systemPrefix,
                englishIntent: normalizedEnglishIntent
            )
            lastInjectedSystemContext = reasoningContext

            try Task.checkCancellation()
            await transition(to: .thinking, minimumDuration: 0)

            logger.notice("on_device_generation_started language=english_from_arabic")
            let englishReply: String
            do {
                englishReply = try await intelligenceManager.generateOnDeviceReply(
                    prompt: reasoningContext,
                    instructions: englishOnlyCaptainInstructions()
                )
            } catch let error as CancellationError {
                throw error
            } catch {
                let category = onDeviceErrorCategory(error)
                logger.error(
                    "on_device_generation_failed category=\(category, privacy: .public)"
                )
                lastPipelineError = error.localizedDescription
                recordDebugDiagnostic("arabic_on_device_failed: \(category)")
                let fallbackReply = await resolveOnDeviceFailureFallback(for: message)
                await transition(to: .preparingReply, minimumDuration: 0)
                return fallbackReply
            }
            logger.notice("on_device_generation_succeeded language=english_from_arabic")

            let normalizedEnglishReply = englishReply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedEnglishReply.isEmpty else {
                throw CoachBrainMiddlewareError.emptyAppleReply
            }

            try Task.checkCancellation()
            let finalReply: String
            do {
                finalReply = try await resolveArabicReply(from: normalizedEnglishReply)
            } catch let error as CancellationError {
                throw error
            } catch {
                return handleTranslationUnavailable(
                    for: message,
                    stage: "output",
                    error: error
                )
            }

            await transition(to: .preparingReply, minimumDuration: 0)
            return finalReply
        } catch is CancellationError {
            lastPipelineError = "The coach analysis was cancelled."
            return gracefulFallback
        } catch {
            let category = pipelineErrorCategory(error)
            logger.error(
                "coach_brain_pipeline_failed category=\(category, privacy: .public)"
            )
            lastPipelineError = error.localizedDescription
            recordDebugDiagnostic("pipeline_failed: \(category)")
            return gracefulFallback
        }
    }

    private func resolveEnglishIntent(for rawMessage: String) async throws -> String {
        await transition(to: .translatingInput, minimumDuration: 0)
        logger.notice("translation_started stage=input")

        // Privacy-first: sanitize user text before sending to external translation API
        let sanitizedInput = sanitizer.sanitizeText(rawMessage, knownUserName: nil)
        let translated = try await translator.translate(
            sanitizedInput,
            systemPrompt: inputTranslationPrompt
        )
        let normalized = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw CoachBrainMiddlewareError.emptyEnglishIntent
        }

        logger.notice("translation_succeeded stage=input")
        return normalized
    }

    private func resolveArabicReply(from englishReply: String) async throws -> String {
        await transition(to: .translatingOutput, minimumDuration: 0)
        logger.notice("translation_started stage=output")

        let arabicReply = try await translator.translate(
            englishReply,
            systemPrompt: outputTranslationPrompt
        )
        let normalizedArabicReply = arabicReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedArabicReply.isEmpty else {
            throw CoachBrainMiddlewareError.emptyArabicReply
        }

        logger.notice("translation_succeeded stage=output")
        return normalizedArabicReply
    }

    private func fallbackReply(for rawMessage: String) async -> String {
        let normalized = rawMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return genericFallbackArabicMessage
        }

        if let intent = detectLocalIntent(in: normalized),
           let deterministicReply = await deterministicArabicReply(for: intent) {
            return deterministicReply
        }

        return genericFallbackArabicMessage
    }

    private func loadHealthMetrics() async -> CaptainDailyHealthMetrics? {
        do {
            return try await intelligenceManager.fetchTodayEssentialMetrics()
        } catch {
            logger.error("Health metrics unavailable for coach fallback: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func arabicHealthReply(from metrics: CaptainDailyHealthMetrics) -> String {
        let steps = max(0, metrics.stepCount)
        let sleepHours = max(0, metrics.sleepHours)
        let sleepText = String(format: "%.1f", sleepHours)

        if sleepHours > 0.25, sleepHours < 6 {
            return "من وضعك الحالي، نومك تقريباً \(sleepText) ساعة. الأفضل إلك اليوم تخفف الضغط: امشِ 10 دقايق، اشرب مي، وخلك على إيقاع هادئ."
        }

        if steps < 3000 {
            return "من مؤشراتك الحالية، خطواتك اليوم \(steps). الأفضل إلك هسه تمشي 10 إلى 15 دقيقة حتى ترفع طاقتك وتفتح يومك صح."
        }

        if steps >= 8000 {
            return "شغلك حلو اليوم، واصل تقريباً \(steps) خطوة. الأفضل إلك هسه دفعة خفيفة إضافية 5 إلى 10 دقايق وتختم يومك بقوة."
        }

        if let heartRate = metrics.averageOrCurrentHeartRateBPM, heartRate > 95 {
            return "نبضك حالياً حوالين \(heartRate)، فالأفضل تبدي بهدوء: تنفّس ببطء دقيقة، وبعدها امشِ مشي خفيف حتى تنتظم الطاقة."
        }

        return "وضعك الحالي جيد، والأفضل إلك هسه خطوة ذكية بسيطة: امشِ 10 دقايق بثبات، وبعدها نقرر إذا نرفع الشدة أو لا."
    }

    private func buildReasoningContext(systemPrefix: String, englishIntent: String) -> String {
        """
        \(systemPrefix)
        User original language: Arabic.
        User message translated to English: \(englishIntent)
        Respond in English only so the final answer can be translated to Iraqi Arabic.
        """
    }

    private func resolveOnDeviceFailureFallback(for originalMessage: String) async -> String {
        let englishFallback = CaptainFallbackPolicy.englishOnDeviceFallback(for: originalMessage)

        do {
            logger.notice("translation_started stage=fallback_output")
            let translatedFallback = try await translator.translate(
                englishFallback,
                systemPrompt: outputTranslationPrompt
            )
            let normalized = translatedFallback.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.notice("translation_succeeded stage=fallback_output")
            return CaptainFallbackPolicy.arabicOnDeviceFallback(
                for: originalMessage,
                translatedFallback: normalized
            )
        } catch _ as CancellationError {
            logger.error("translation_failed stage=fallback_output category=cancelled")
            return CaptainFallbackPolicy.arabicOnDeviceFallback(
                for: originalMessage,
                translatedFallback: nil
            )
        } catch {
            let category = translationErrorCategory(error)
            logger.error(
                "translation_failed stage=fallback_output category=\(category, privacy: .public)"
            )
            recordDebugDiagnostic("fallback_output_translation_failed: \(category)")
            return CaptainFallbackPolicy.arabicOnDeviceFallback(
                for: originalMessage,
                translatedFallback: nil
            )
        }
    }

    private func handleTranslationUnavailable(
        for message: String,
        stage: String,
        error: Error
    ) -> String {
        let category = translationErrorCategory(error)
        logger.error("translation_failed stage=\(stage, privacy: .public) category=\(category, privacy: .public)")
        lastPipelineError = error.localizedDescription
        recordDebugDiagnostic("translation_failed[\(stage)]: \(category)")
        return CaptainFallbackPolicy.translationUnavailableArabic(for: message)
    }

    private func englishOnlyCaptainInstructions() -> String {
        """
        \(CaptainPersonaBuilder.buildInstructions())
        Respond ONLY in English. Do not include Arabic.
        """
    }

    private func logInputLanguageDetection(isArabic: Bool) {
        let detected = isArabic ? "arabic" : "non_arabic"
        logger.notice("input_language_detected value=\(detected, privacy: .public)")
    }

    private func translationErrorCategory(_ error: Error) -> String {
        switch error {
        case is CoachBrainTranslationConfigurationError:
            return "configuration"
        case let translatorError as CoachBrainLLMTranslator.Error:
            switch translatorError {
            case .networkUnavailable:
                return "network"
            case .requestFailed:
                return "transport"
            case .badStatusCode:
                return "http_status"
            case .invalidResponse:
                return "invalid_response"
            case .emptyResponse:
                return "empty_response"
            }
        case is URLError:
            return "network"
        default:
            return "other"
        }
    }

    private func onDeviceErrorCategory(_ error: Error) -> String {
        if let captainError = error as? CaptainIntelligenceError {
            switch captainError {
            case .foundationModelsUnavailable:
                return "foundation_models_unavailable"
            case .onDeviceModelUnavailable:
                return "model_unavailable"
            case .unsupportedDeviceLanguage:
                return "unsupported_language"
            case .emptyModelResponse:
                return "empty_response"
            default:
                return "other"
            }
        }

        return "other"
    }

    private func pipelineErrorCategory(_ error: Error) -> String {
        if error is CoachBrainMiddlewareError {
            return "middleware"
        }

        if error is CoachBrainTranslationConfigurationError || error is CoachBrainLLMTranslator.Error {
            return "translation"
        }

        if error is CaptainIntelligenceError {
            return "on_device"
        }

        return "other"
    }

    private func recordDebugDiagnostic(_ message: String) {
#if DEBUG
        debugDiagnosticMessage = message
#else
        _ = message
#endif
    }

    private func transition(to newPhase: CoachBrainPhase, minimumDuration: TimeInterval) async {
        phase = newPhase
        liveStatusText = statusText(for: newPhase)
    }

    private func statusText(for phase: CoachBrainPhase) -> String? {
        switch phase {
        case .idle:
            return nil
        case .reading:
            return "الكابتن يقرا رسالتك"
        case .translatingInput:
            return "الكابتن يترجم نيتك"
        case .thinking:
            return "الكابتن يفكر بأفضل رد"
        case .translatingOutput:
            return "الكابتن يصيغ الرد بالعراقي"
        case .preparingReply:
            return "الكابتن يكتب الرد"
        }
    }

    private func containsAny(of terms: [String], in text: String) -> Bool {
        terms.contains { text.contains($0) }
    }

    private func detectLocalIntent(in normalizedText: String) -> LocalCaptainIntent? {
        let normalized = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        if isArabicTimeQuery(normalized) {
            return .currentTime
        }

        if isArabicDateQuery(normalized) {
            return .currentDate
        }

        if containsAny(
            of: ["هلا", "هلو", "هلاو", "مرحبا", "سلام", "شونك", "شلونك", "هلا بيك", "hello", "hi"],
            in: normalized
        ) {
            return .greeting
        }

        if containsAny(
            of: ["بياناتي", "بيانات", "حالتي", "صحتي", "خطواتي", "نومي", "نبضي", "health", "data", "metrics"],
            in: normalized
        ) {
            return .healthOverview
        }

        if containsAny(
            of: ["aiqo", "تطبيق", "برنامج", "شنو هذا", "اشرح", "اشرحلي", "شنو هاذا"],
            in: normalized
        ) {
            return .explainAiQo
        }

        if containsAny(
            of: ["تعبان", "نعسان", "مرهق", "نوم", "sleep", "tired", "exhausted"],
            in: normalized
        ) {
            return .recovery
        }

        if containsAny(
            of: ["أكل", "وجبة", "اكل", "دايت", "nutrition", "food", "meal"],
            in: normalized
        ) {
            return .nutrition
        }

        if containsAny(
            of: ["تمرين", "جيم", "عضل", "قوة", "gym", "workout", "muscle", "strength"],
            in: normalized
        ) {
            return .workout
        }

        if containsAny(
            of: ["توتر", "مضغوط", "قلق", "stress", "anxious", "overwhelmed"],
            in: normalized
        ) {
            return .stress
        }

        return nil
    }

    private func isArabicTimeQuery(_ normalized: String) -> Bool {
        let directMarkers = [
            "كم الساعة",
            "شكد الساعة",
            "الساعة شكد",
            "الوقت شكد",
            "شنو الوقت",
            "شنو الساعة",
            "ساعة بيش",
            "بيش الساعة",
            "التوقيت"
        ]

        if containsAny(of: directMarkers, in: normalized) {
            return true
        }

        return normalized.contains("ساعة")
            && containsAny(
                of: ["هسه", "الآن", "الان", "حاليًا", "حاليا", "كم", "شكد", "بيش", "ليش"],
                in: normalized
            )
    }

    private func isArabicDateQuery(_ normalized: String) -> Bool {
        if containsAny(
            of: ["شنو التاريخ", "تاريخ اليوم", "اليوم شنو تاريخ", "اليوم شنو يوم", "شنو يوم اليوم"],
            in: normalized
        ) {
            return true
        }

        return normalized.contains("تاريخ") && normalized.contains("اليوم")
    }

    private func deterministicArabicReply(for intent: LocalCaptainIntent) async -> String? {
        switch intent {
        case .greeting:
            return "هلا بيك بطل، أنا حاضر وياك. احچيلي شتريد نضبط اليوم: تمرين، أكل، لو طاقة ونشاط؟"
        case .healthOverview:
            if let metrics = await loadHealthMetrics() {
                return arabicHealthReply(from: metrics)
            }
            return "أقدر أختار لك الأفضل بخطوة آمنة وذكية: امشِ 10 دقايق، اشرب مي، وبعدها نرفع الجودة بالتدريج."
        case .explainAiQo:
            return "AiQo هو رفيقك الذكي للياقة ونمط الحياة. يساعدك تفهم جسمك، ينظم يومك، ويحوّل بياناتك إلى خطوات عملية للتمرين، الأكل، والطاقة."
        case .currentTime:
            return arabicCurrentTimeReply()
        case .currentDate:
            return arabicCurrentDateReply()
        case .recovery:
            return "واضح جسمك محتاج هدوء ذكي. اشرب مي، خذ نفس عميق، وابدأ بمشي خفيف 10 دقايق."
        case .nutrition:
            return "خلّينا نبسّطها: ابدأ بوجبة بيها بروتين ومَي، وبعدها نرتب باقي يومك خطوة خطوة."
        case .workout:
            return "تمام بطل، نبدي بإحماء 5 دقايق، وبعدها أول تمرين أساسي بثبات، وخلي البداية نظيفة وقوية."
        case .stress:
            return "أهدأ أولاً، خذ خمس أنفاس بطيئة، حرّك جسمك دقيقتين، وبعدها نحول الضغط إلى خطوة مفيدة."
        }
    }

    private func arabicCurrentTimeReply() -> String {
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let hour24 = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let period = hour24 >= 12 ? "مساءً" : "صباحاً"

        return "هسه الساعة \(localizedArabicNumber(hour12)):\(localizedArabicMinute(minute)) \(period). إذا تريد، أرتب لك الخطوة الأنسب لهذا الوقت."
    }

    private func arabicCurrentDateReply() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_IQ")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return "اليوم \(formatter.string(from: Date())). إذا تريد، أبني لك الخطة المناسبة لليوم."
    }

    private func localizedArabicNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar_IQ")
        formatter.numberStyle = .none
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func localizedArabicMinute(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar_IQ")
        formatter.numberStyle = .none
        formatter.minimumIntegerDigits = 2
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%02d", value)
    }

}
