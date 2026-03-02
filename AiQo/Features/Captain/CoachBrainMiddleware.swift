import Foundation
import os.log
import SwiftUI
internal import Combine

protocol CoachBrainTranslating: Sendable {
    func translate(_ text: String, systemPrompt: String) async throws -> String
}

struct CoachBrainLLMTranslator: CoachBrainTranslating {
    private struct Configuration {
        let endpointURL: URL
        let apiKey: String
    }

    private struct ChatCompletionsRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
        }
    }

    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct ChatCompletionsResponse: Decodable {
        struct Choice: Decodable {
            struct ResponseMessage: Decodable {
                let content: String
            }

            let message: ResponseMessage
        }

        let choices: [Choice]
    }

    enum Error: LocalizedError {
        case invalidEndpoint
        case missingAPIKey
        case badStatusCode(Int)
        case invalidResponse
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Coach Brain translation endpoint is invalid."
            case .missingAPIKey:
                return "Coach Brain translation API key is missing."
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
    private let model: String

    init(
        session: URLSession = .shared,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        model: String = "gpt-4o-mini"
    ) {
        self.session = session
        self.bundle = bundle
        self.processInfo = processInfo
        self.model = model
    }

    func translate(_ text: String, systemPrompt: String) async throws -> String {
        let payload = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else {
            throw Error.emptyResponse
        }

        let configuration = try resolveConfiguration()
        var request = URLRequest(url: configuration.endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatCompletionsRequest(
            model: model,
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: payload)
            ],
            temperature: 0.2,
            maxTokens: 180
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw Error.badStatusCode(httpResponse.statusCode)
        }

        let decoded: ChatCompletionsResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        } catch {
            throw Error.invalidResponse
        }

        guard let translated = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !translated.isEmpty else {
            throw Error.emptyResponse
        }

        return translated
    }

    private func resolveConfiguration() throws -> Configuration {
        let info = bundle.infoDictionary ?? [:]
        let endpointString = normalized(
            info["COACH_BRAIN_LLM_API_URL"] as? String
        ) ?? normalized(
            info["SPIRITUAL_WHISPERS_LLM_API_URL"] as? String
        ) ?? "https://api.openai.com/v1/chat/completions"

        guard let endpointURL = URL(string: endpointString) else {
            throw Error.invalidEndpoint
        }

        let apiKey = normalized(info["COACH_BRAIN_LLM_API_KEY"] as? String)
            ?? normalized(info["SPIRITUAL_WHISPERS_LLM_API_KEY"] as? String)
            ?? normalized(processInfo.environment["COACH_BRAIN_LLM_API_KEY"])
            ?? normalized(processInfo.environment["SPIRITUAL_WHISPERS_LLM_API_KEY"])
            ?? normalized(processInfo.environment["OPENAI_API_KEY"])

        guard let apiKey else {
            throw Error.missingAPIKey
        }

        return Configuration(endpointURL: endpointURL, apiKey: apiKey)
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }

        return trimmed
    }
}

enum CoachBrainMiddlewareError: LocalizedError {
    case emptyUserInput
    case emptyEnglishIntent
    case emptyAppleReply

    var errorDescription: String? {
        switch self {
        case .emptyUserInput:
            return "The user message was empty."
        case .emptyEnglishIntent:
            return "The translated English intent was empty."
        case .emptyAppleReply:
            return "The on-device coach returned an empty reply."
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

    private let translator: any CoachBrainTranslating
    private let intelligenceManager: CaptainIntelligenceManager
    private let contextBuilder: CaptainContextBuilder
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CoachBrainMiddleware"
    )

    private let inputTranslationPrompt = "Translate this user message to clear English so a fitness AI coach can understand the intent perfectly."
    private let outputTranslationPrompt = "Translate this to a friendly, motivational Iraqi Arabic dialect. You are Captain Hamoudi, a smart and caring fitness coach."
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
            let normalizedEnglishIntent = await resolveEnglishIntent(for: message)
            guard !normalizedEnglishIntent.isEmpty else {
                throw CoachBrainMiddlewareError.emptyEnglishIntent
            }

            lastResolvedEnglishIntent = normalizedEnglishIntent
            let reasoningContext = buildReasoningContext(
                systemPrefix: systemContext.systemPrefix,
                englishIntent: normalizedEnglishIntent
            )

            try Task.checkCancellation()
            await transition(to: .thinking, minimumDuration: 0)

            let englishReply = try await generateAppleIntelligenceReply(
                context: reasoningContext
            )
            let normalizedEnglishReply = englishReply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedEnglishReply.isEmpty else {
                throw CoachBrainMiddlewareError.emptyAppleReply
            }

            try Task.checkCancellation()
            let finalReply = await resolveArabicReply(
                from: normalizedEnglishReply,
                originalMessage: message
            )
            await transition(to: .preparingReply, minimumDuration: 0)
            return finalReply
        } catch is CancellationError {
            lastPipelineError = "The coach analysis was cancelled."
            return gracefulFallback
        } catch {
            logger.error("Coach brain pipeline failed: \(error.localizedDescription, privacy: .public)")
            lastPipelineError = error.localizedDescription
            return gracefulFallback
        }
    }

    /// Mock stand-in for the Apple Intelligence on-device brain.
    /// The middleware always feeds it English context so the local reasoning stays single-track.
    func generateAppleIntelligenceReply(context: String) async throws -> String {
        let normalizedContext = context
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let intent = extractUserIntent(from: normalizedContext) ?? normalizedContext

        guard !normalizedContext.isEmpty else {
            throw CoachBrainMiddlewareError.emptyEnglishIntent
        }

        try Task.checkCancellation()

        if isGreetingIntent(intent) {
            return "Good to have you here. I am fully with you. Tell me what you want to tune today: training, food, recovery, or energy."
        }

        if isTimeIntent(intent) {
            return englishCurrentTimeReply()
        }

        if isDateIntent(intent) {
            return englishCurrentDateReply()
        }

        if intent.contains("sleep") || intent.contains("tired") || intent.contains("exhausted") {
            return "Your body needs smart energy today. Keep the intensity light, walk for 12 minutes, hydrate now, and protect tonight's recovery."
        }

        if intent.contains("health data") || intent.contains("steps") || intent.contains("heart rate") || intent.contains("recovery data") {
            return healthAwareReply(from: normalizedContext)
        }

        if intent.contains("aiqo") || intent.contains("application") || intent.contains("app") || intent.contains("explain the app") {
            return "AiQo is your bio-digital coach. It reads your health context, tracks your lifestyle habits, and turns fitness, recovery, and daily discipline into guided actions."
        }

        if intent.contains("weight") || intent.contains("fat loss") || intent.contains("lose weight") {
            return "Focus on one clean win first: hit a protein-rich meal, take a brisk 15-minute walk, and stay consistent instead of chasing extremes."
        }

        if intent.contains("muscle") || intent.contains("strength") || intent.contains("gym") {
            return "Build momentum with quality reps today. Start with your main lift, control the tempo, and finish with one extra set you can own."
        }

        if intent.contains("stress") || intent.contains("anxious") || intent.contains("overwhelmed") {
            return "Calm the system first. Take five slow breaths, loosen your shoulders, and do a short walk so your body can reset and think clearly."
        }

        if intent.contains("food") || intent.contains("meal") || intent.contains("nutrition") {
            return "Keep it simple: choose a balanced plate with protein, fiber, and water first, then let the next healthy choice come from that win."
        }

        return "You already have enough energy to move forward. Take one deliberate action in the next 10 minutes and let that small win lead the day."
    }

    private func resolveEnglishIntent(for rawMessage: String) async -> String {
        await transition(to: .translatingInput, minimumDuration: 0)

        do {
            let translated = try await translator.translate(
                rawMessage,
                systemPrompt: inputTranslationPrompt
            )
            let normalized = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                return normalized
            }
        } catch {
            logger.error("Arabic input translation failed: \(error.localizedDescription, privacy: .public)")
        }

        return await localEnglishIntentFallback(for: rawMessage)
    }

    private func resolveArabicReply(from englishReply: String, originalMessage: String) async -> String {
        await transition(to: .translatingOutput, minimumDuration: 0)

        do {
            let arabicReply = try await translator.translate(
                englishReply,
                systemPrompt: outputTranslationPrompt
            )
            let normalizedArabicReply = arabicReply.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedArabicReply.isEmpty {
                return normalizedArabicReply
            }
        } catch {
            logger.error("Arabic output translation failed: \(error.localizedDescription, privacy: .public)")
        }

        return await localArabicReplyFallback(
            for: englishReply,
            originalMessage: originalMessage
        )
    }

    private func localEnglishIntentFallback(for rawMessage: String) async -> String {
        let normalized = rawMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return "The user wants practical, motivational coaching with one clear next action."
        }

        if let intent = detectLocalIntent(in: normalized) {
            return await localEnglishIntentDescription(for: intent)
        }

        return "The user wants supportive fitness guidance in Arabic. Give one clear next action that is easy to start in the next 10 minutes."
    }

    private func localArabicReplyFallback(for englishReply: String, originalMessage: String) async -> String {
        let normalizedOriginal = originalMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedEnglishReply = englishReply.lowercased()

        if let intent = detectLocalIntent(in: normalizedOriginal),
           let deterministicReply = await deterministicArabicReply(for: intent) {
            return deterministicReply
        }

        if normalizedEnglishReply.contains("aiqo") || normalizedEnglishReply.contains("bio-digital coach") || normalizedEnglishReply.contains("application") || normalizedEnglishReply.contains("lifestyle habits") {
            return "AiQo هو نظامك الذكي للحياة واللياقة. يقرأ مؤشراتك الصحية، يتابع عاداتك، ويحوّل يومك إلى خطوات عملية للتمرين، التعافي، والانضباط."
        }

        if normalizedEnglishReply.contains("protein") || normalizedEnglishReply.contains("meal") || normalizedEnglishReply.contains("balanced plate") {
            return "خلّينا نبدي صح: اختَر وجبة بيها بروتين ومَي هسه، وبعدها نبني باقي يومك على هذا الفوز."
        }

        if normalizedEnglishReply.contains("walk") || normalizedEnglishReply.contains("hydrate") {
            return "أحسن خطوة إلك هسه: امشِ 10 إلى 12 دقيقة، واشرب مي، وخلي جسمك يرجع يدخل مود النشاط."
        }

        if normalizedEnglishReply.contains("breaths") || normalizedEnglishReply.contains("calm") || normalizedEnglishReply.contains("stress") {
            return "هدّي جسمك أولاً: خذ خمس أنفاس بطيئة، حرّك كتوفك، وامشِ دقيقتين حتى ترجع ماسك زمامك."
        }

        if normalizedEnglishReply.contains("lift") || normalizedEnglishReply.contains("set") || normalizedEnglishReply.contains("reps") {
            return "يلا بطل، نبدي بإحماء خفيف 5 دقايق، وبعدها أول تمرين أساسي بثبات، وخلي أول سِت تكون نظيفة."
        }

        return await fallbackReply(for: originalMessage)
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

    private func healthSnapshotSummaryForEnglishIntent() async -> String? {
        guard let metrics = await loadHealthMetrics() else { return nil }

        var parts: [String] = [
            "Today steps: \(max(0, metrics.stepCount)).",
            "Sleep: \(String(format: "%.1f", max(0, metrics.sleepHours))) hours."
        ]

        if let heartRate = metrics.averageOrCurrentHeartRateBPM {
            parts.append("Current or average heart rate: \(max(0, heartRate)) bpm.")
        }

        return parts.joined(separator: " ")
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
        [USER INTENT IN ENGLISH: \(englishIntent)]
        [COACH DIRECTIVE: If the user is only greeting you, greet them naturally and invite the next topic. Otherwise reply with one concise, high-agency coaching response in English before Arabic translation.]
        """
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

    private func isGreetingIntent(_ text: String) -> Bool {
        containsAny(
            of: [
                "the user is greeting the coach",
                "greeting the coach",
                "hello",
                "hi",
                "hey",
                "good morning",
                "good evening",
                "how are you"
            ],
            in: text
        )
    }

    private func isTimeIntent(_ text: String) -> Bool {
        containsAny(
            of: [
                "current time",
                "what time",
                "time now",
                "the user is asking for the current time"
            ],
            in: text
        )
    }

    private func isDateIntent(_ text: String) -> Bool {
        containsAny(
            of: [
                "current date",
                "today's date",
                "what date",
                "what day is it",
                "the user is asking for today's date"
            ],
            in: text
        )
    }

    private func extractUserIntent(from normalizedContext: String) -> String? {
        extractSegment(
            in: normalizedContext,
            prefix: "[user intent in english:"
        )
    }

    private func extractSegment(in text: String, prefix: String) -> String? {
        guard let startRange = text.range(of: prefix) else { return nil }
        let trailingText = text[startRange.upperBound...]
        guard let closingBracket = trailingText.firstIndex(of: "]") else { return nil }

        let extracted = trailingText[..<closingBracket]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return extracted.isEmpty ? nil : String(extracted)
    }

    private func healthAwareReply(from normalizedContext: String) -> String {
        let steps = extractIntMetric(after: "steps:", in: normalizedContext)
        let heartRate = extractIntMetric(after: "heart rate:", in: normalizedContext)
        let sleepHours = extractDoubleMetric(after: "sleep:", in: normalizedContext)

        if let sleepHours, sleepHours > 0.25, sleepHours < 5.8 {
            return "Your sleep looks light today. Lead with recovery: keep training easy, walk for 10 minutes, hydrate now, and protect tonight's reset."
        }

        if let heartRate, heartRate > 96 {
            return "Your body looks a little activated right now. Slow the system first: take one calm minute of breathing, then do a gentle walk before any hard effort."
        }

        if let steps, steps < 2200 {
            return "Your momentum is still waking up. The smartest move now is 10 to 12 minutes of walking, one full glass of water, then we reassess your energy."
        }

        if let steps, steps >= 8500 {
            return "You already built solid momentum today. Keep the next move clean: short mobility, water, and one disciplined meal so you finish strong."
        }

        return "Your body data is steady enough for a smart next move. Start with a brisk 10-minute walk, hydrate well, and build from that clean baseline."
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

    private func localEnglishIntentDescription(for intent: LocalCaptainIntent) async -> String {
        switch intent {
        case .greeting:
            return "The user is greeting the coach and wants help deciding what to focus on today."
        case .healthOverview:
            if let metricsSummary = await healthSnapshotSummaryForEnglishIntent() {
                return "The user wants the best next action based on today's health data. \(metricsSummary) Recommend one clear next step."
            }
            return "The user wants the best next action based on their current health data and energy. Recommend one clear next step."
        case .explainAiQo:
            return "The user wants a simple explanation of what AiQo is and how it helps with fitness, energy, and lifestyle."
        case .currentTime:
            return "The user is asking for the current time. Answer clearly with the current local time."
        case .currentDate:
            return "The user is asking for today's date. Answer clearly with the exact local date."
        case .recovery:
            return "The user feels tired and needs recovery-focused coaching. Give one simple action that protects recovery."
        case .nutrition:
            return "The user wants nutrition guidance. Give one practical food-related action that is easy to start right now."
        case .workout:
            return "The user wants workout coaching. Give one practical exercise-focused action that builds momentum."
        case .stress:
            return "The user feels stressed. Give one calming physical action that reduces stress and restores control."
        }
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

    private func englishCurrentTimeReply() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "h:mm a"
        return "Your local time right now is \(formatter.string(from: Date()))."
    }

    private func englishCurrentDateReply() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return "Today's local date is \(formatter.string(from: Date()))."
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

    private func extractIntMetric(after label: String, in text: String) -> Int? {
        guard let metricSlice = extractMetricSlice(after: label, in: text) else { return nil }
        let digits = metricSlice.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }

    private func extractDoubleMetric(after label: String, in text: String) -> Double? {
        guard let metricSlice = extractMetricSlice(after: label, in: text) else { return nil }
        let valueString = metricSlice.prefix { character in
            character.isNumber || character == "."
        }
        guard !valueString.isEmpty else { return nil }
        return Double(valueString)
    }

    private func extractMetricSlice(after label: String, in text: String) -> Substring? {
        guard let range = text.range(of: label) else { return nil }
        let trailingText = text[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trailingText.isEmpty else { return nil }

        let endIndex = trailingText.firstIndex { character in
            character == "," || character == "." || character == "]"
        } ?? trailingText.endIndex

        return trailingText[..<endIndex]
    }
}
