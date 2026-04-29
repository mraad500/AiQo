import Foundation
import os.log

// MARK: - Conversation Types

enum CaptainConversationRole: String, Sendable {
    case system
    case user
    case assistant
}

struct CaptainConversationMessage: Sendable {
    let role: CaptainConversationRole
    let content: String
}

// MARK: - Request / Reply

/// Coarse classification of why a request is going to the cloud.
/// Used by `AuditLogger` to attribute usage and by AccessManager gating.
/// Keep values stable — they're persisted to `brain_audit.log.json`.
enum RequestPurpose: String, Sendable, Codable {
    case captainChat
    case kitchen
    case voice
    case memoryConsolidation
}

struct HybridBrainRequest: Sendable {
    let conversation: [CaptainConversationMessage]
    let screenContext: ScreenContext
    let language: AppLanguage
    let contextData: CaptainContextData
    let userProfileSummary: String
    let intentSummary: String
    let workingMemorySummary: String
    let attachedImageData: Data?
    let purpose: RequestPurpose

    var hasAttachedImage: Bool { attachedImageData != nil }

    init(
        conversation: [CaptainConversationMessage],
        screenContext: ScreenContext,
        language: AppLanguage,
        contextData: CaptainContextData,
        userProfileSummary: String,
        intentSummary: String,
        workingMemorySummary: String,
        attachedImageData: Data?,
        purpose: RequestPurpose = .captainChat
    ) {
        self.conversation = conversation
        self.screenContext = screenContext
        self.language = language
        self.contextData = contextData
        self.userProfileSummary = userProfileSummary
        self.intentSummary = intentSummary
        self.workingMemorySummary = workingMemorySummary
        self.attachedImageData = attachedImageData
        self.purpose = purpose
    }
}

struct HybridBrainServiceReply: Sendable {
    let message: String
    let quickReplies: [String]?
    let workoutPlan: WorkoutPlan?
    let mealPlan: MealPlan?
    let spotifyRecommendation: SpotifyRecommendation?
    let rawText: String
    /// True when Gemini reported `finishReason: "MAX_TOKENS"` for the cloud
    /// response that produced this reply. Local / fallback / persona replies
    /// always pass `false`. Surfaced to the UI so the bubble can mark the
    /// truncation; analytics tracks it for capacity tuning.
    let truncatedAtMaxTokens: Bool
}

struct HybridBrainStreamingSession: Sendable {
    let tokens: AsyncStream<String>
    let fallbackResponse: CaptainStructuredResponse
}

// MARK: - Errors

enum HybridBrainServiceError: LocalizedError {
    case emptyConversation
    case missingUserMessage
    case invalidStructuredResponse
    case invalidResponse
    case emptyResponse
    case badStatusCode(Int)
    case networkUnavailable
    case requestFailed
    case missingAPIKey       // Secrets.xcconfig not set or key is empty
    case invalidEndpoint     // URL construction failed

    var errorDescription: String? {
        switch self {
        case .emptyConversation:
            return NSLocalizedString("captain.error.emptyConversation", comment: "")
        case .missingUserMessage:
            return NSLocalizedString("captain.error.missingUserMessage", comment: "")
        case .invalidStructuredResponse:
            return NSLocalizedString("captain.error.invalidJSON", comment: "")
        case .invalidResponse:
            return NSLocalizedString("captain.error.invalidResponse", comment: "")
        case .emptyResponse:
            return NSLocalizedString("captain.error.emptyResponse", comment: "")
        case .badStatusCode(let code):
            return String(format: NSLocalizedString("captain.error.badStatus", comment: ""), code)
        case .networkUnavailable:
            return NSLocalizedString("captain.error.networkUnavailable", comment: "")
        case .requestFailed:
            return NSLocalizedString("captain.error.requestFailed", comment: "")
        case .missingAPIKey:
            return "Captain API key is missing. Add CAPTAIN_API_KEY to Secrets.xcconfig."
        case .invalidEndpoint:
            return "Captain API endpoint URL could not be constructed."
        }
    }
}

// MARK: - Gemini API Configuration

private enum GeminiConfig {
    static let baseEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"
    static let requestTimeoutSeconds: TimeInterval = 35
    static let resourceTimeoutSeconds: TimeInterval = 40

    /// Resolves the API key at runtime from Info.plist (populated by Secrets.xcconfig).
    /// The key is NEVER hardcoded here — it flows via:
    ///   Secrets.xcconfig  →  Build Settings  →  Info.plist $(CAPTAIN_API_KEY)  →  here
    static func resolvedAPIKey() throws -> String {
        // 1) Info.plist (primary — set via Secrets.xcconfig build variable)
        if let key = Bundle.main.object(forInfoDictionaryKey: "CAPTAIN_API_KEY") as? String,
           isValid(key) {
            return key
        }
        // 2) Environment variable (CI / TestFlight builds)
        if let key = ProcessInfo.processInfo.environment["CAPTAIN_API_KEY"],
           isValid(key) {
            return key
        }
        throw HybridBrainServiceError.missingAPIKey
    }

    static func endpointURL(for model: String) throws -> URL {
        guard let url = URL(string: "\(baseEndpoint)/\(model):generateContent") else {
            throw HybridBrainServiceError.invalidEndpoint
        }
        return url
    }

    /// Rejects empty strings and unexpanded Xcode placeholders like "$(CAPTAIN_API_KEY)".
    private static func isValid(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && !trimmed.hasPrefix("$(")
            && trimmed != "YOUR_API_KEY_HERE"
    }
}

// MARK: - Gemini Response Decoding

struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        struct SafetyRating: Decodable {
            let category: String
            let probability: String
        }
        let content: Content?
        let finishReason: String?
        let safetyRatings: [SafetyRating]?
    }

    struct UsageMetadata: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
        let totalTokenCount: Int?
    }

    let candidates: [Candidate]?
    let usageMetadata: UsageMetadata?

    var outputText: String {
        candidates?
            .compactMap { $0.content }
            .flatMap { $0.parts ?? [] }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Gemini's reason for ending generation on the first candidate
    /// (e.g. `STOP`, `MAX_TOKENS`, `SAFETY`, `RECITATION`). `nil` when the
    /// response had no candidates or the field was absent.
    var finishReason: String? {
        candidates?.first?.finishReason
    }

    /// Convenience flag — true only when Gemini hit the output-token cap.
    var didHitMaxTokens: Bool {
        finishReason == "MAX_TOKENS"
    }
}

// MARK: - HybridBrainService (Gemini Cloud Transport)

struct HybridBrainService: Sendable {
    private let session: URLSession
    private let promptBuilder: PromptComposer
    private let jsonParser: LLMJSONParser
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "HybridBrainService"
    )

    /// Dedicated session so `timeoutIntervalForResource` is honored — `URLSession.shared`
    /// uses a 7-day resource timeout by default, which lets stalled streams hang the chat.
    private static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = GeminiConfig.requestTimeoutSeconds
        config.timeoutIntervalForResource = GeminiConfig.resourceTimeoutSeconds
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    init(
        session: URLSession = HybridBrainService.defaultSession,
        promptBuilder: PromptComposer = PromptComposer(),
        jsonParser: LLMJSONParser = LLMJSONParser()
    ) {
        self.session = session
        self.promptBuilder = promptBuilder
        self.jsonParser = jsonParser
    }

    // MARK: - Public API

    func generateReply(
        request: HybridBrainRequest,
        model: String
    ) async throws -> HybridBrainServiceReply {
        try validate(request)

        let cloudResult = try await requestCloudResponse(
            request: request,
            model: model
        )
        let rawText = try encodeStructuredResponse(cloudResult.response)

        return HybridBrainServiceReply(
            message: CaptainPersonaBuilder.sanitizeResponse(cloudResult.response.message),
            quickReplies: cloudResult.response.quickReplies,
            workoutPlan: cloudResult.response.workoutPlan,
            mealPlan: cloudResult.response.mealPlan,
            spotifyRecommendation: cloudResult.response.spotifyRecommendation,
            rawText: rawText,
            truncatedAtMaxTokens: cloudResult.truncatedAtMaxTokens
        )
    }

    func startStreamingReply(
        request: HybridBrainRequest,
        model: String
    ) async throws -> HybridBrainStreamingSession {
        let reply = try await generateReply(request: request, model: model)
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

// MARK: - Private Implementation

private extension HybridBrainService {

    func validate(_ request: HybridBrainRequest) throws {
        let nonEmpty = request.conversation.filter {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !nonEmpty.isEmpty else { throw HybridBrainServiceError.emptyConversation }
        guard nonEmpty.contains(where: { $0.role == .user }) else {
            throw HybridBrainServiceError.missingUserMessage
        }
    }

    // MARK: - Network

    /// Result of a single Gemini request — the parsed structured response plus
    /// the `MAX_TOKENS` flag derived from `finishReason`. Truncation is NOT
    /// thrown — Gemini still returns useful partial text and the UI is
    /// responsible for marking it.
    struct CloudCallResult {
        let response: CaptainStructuredResponse
        let truncatedAtMaxTokens: Bool
    }

    func requestCloudResponse(
        request: HybridBrainRequest,
        model: String
    ) async throws -> CloudCallResult {
        let urlRequest = try await makeGeminiURLRequest(request: request, model: model)

        logger.notice("gemini_request model=\(model, privacy: .public) via=\(CaptainProxyConfig.isChatEnabled ? "proxy" : "direct", privacy: .public)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("gemini_network_error error=\(error.localizedDescription, privacy: .public)")
            throw isNetworkUnavailable(error)
                ? HybridBrainServiceError.networkUnavailable
                : HybridBrainServiceError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HybridBrainServiceError.invalidResponse
        }

        logger.notice("gemini_response status=\(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("gemini_bad_status status=\(httpResponse.statusCode) bytes=\(data.count)")
            throw HybridBrainServiceError.badStatusCode(httpResponse.statusCode)
        }

        let decoded: GeminiResponse
        do {
            decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            logger.error("gemini_decode_error bytes=\(data.count)")
            throw HybridBrainServiceError.invalidResponse
        }

        let outputText = decoded.outputText
        logger.notice("gemini_output length=\(outputText.count)")

        let finishReason = decoded.finishReason ?? "unknown"
        let inputTokens = decoded.usageMetadata?.promptTokenCount ?? 0
        let outputTokens = decoded.usageMetadata?.candidatesTokenCount ?? 0
        let totalTokens = decoded.usageMetadata?.totalTokenCount ?? 0
        logger.notice("gemini_finish reason=\(finishReason, privacy: .public) inputTokens=\(inputTokens) outputTokens=\(outputTokens) totalTokens=\(totalTokens)")

        let truncatedAtMaxTokens = decoded.didHitMaxTokens
        if truncatedAtMaxTokens {
            logger.error("gemini_max_tokens_hit screen=\(request.screenContext.rawValue, privacy: .public) outputTokens=\(outputTokens)")
        }

        guard !outputText.isEmpty else {
            throw HybridBrainServiceError.emptyResponse
        }

        let fallback = CaptainStructuredResponse(
            message: parsingFallbackMessage(for: request.language)
        )
        let parsedResponse = jsonParser.decode(rawText: outputText, fallback: fallback)

        if parsedResponse.message == fallback.message {
            logger.error("gemini_parse_fallback_applied output_length=\(outputText.count)")
        }

        return CloudCallResult(
            response: parsedResponse,
            truncatedAtMaxTokens: truncatedAtMaxTokens
        )
    }

    // MARK: - URL Request Construction (proxy vs direct)

    /// Routes the Gemini request through the Supabase Edge Function proxy when
    /// `USE_CLOUD_PROXY` is on, otherwise hits Gemini directly with the
    /// client-embedded API key (legacy path).
    private func makeGeminiURLRequest(
        request: HybridBrainRequest,
        model: String
    ) async throws -> URLRequest {
        let geminiBody = makeRequestBody(request: request)

        if CaptainProxyConfig.isChatEnabled {
            return try await makeProxiedGeminiRequest(
                model: model,
                geminiBody: geminiBody
            )
        }

        return try makeDirectGeminiRequest(
            model: model,
            geminiBody: geminiBody
        )
    }

    private func makeDirectGeminiRequest(
        model: String,
        geminiBody: [String: Any]
    ) throws -> URLRequest {
        let apiKey = try GeminiConfig.resolvedAPIKey()
        var urlRequest = URLRequest(url: try GeminiConfig.endpointURL(for: model))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = GeminiConfig.requestTimeoutSeconds
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: geminiBody)
        return urlRequest
    }

    /// Wraps the Gemini body as `{ model, payload }` and POSTs to the
    /// Supabase `captain-chat` Edge Function with the user's session JWT.
    /// The function validates the JWT, forwards to Gemini with the
    /// server-held key, and streams the response straight back — the
    /// existing `GeminiResponse` decoder works unchanged.
    private func makeProxiedGeminiRequest(
        model: String,
        geminiBody: [String: Any]
    ) async throws -> URLRequest {
        guard let endpoint = CaptainProxyConfig.endpointURL(for: .chat) else {
            throw HybridBrainServiceError.invalidEndpoint
        }
        guard let jwt = await CaptainProxyConfig.currentSessionJWT() else {
            // No active Supabase session — caller will see this as a missing-key
            // error, which already maps to the "sign in again" path in the UI.
            throw HybridBrainServiceError.missingAPIKey
        }
        let anonKey = CaptainProxyConfig.anonKey ?? ""

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = GeminiConfig.requestTimeoutSeconds
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        if !anonKey.isEmpty {
            urlRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        }

        let wrapped: [String: Any] = [
            "model": model,
            "payload": geminiBody,
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: wrapped)
        return urlRequest
    }

    // MARK: - Request Body

    func makeRequestBody(request: HybridBrainRequest) -> [String: Any] {
        // Arabic tokenizes inefficiently in Gemini's BPE (~1.5–2× English).
        // The structured reply envelope (greeting + per-metric line + advice +
        // follow-up + quickReplies) plus the JSON wrapper itself eats budget
        // fast — multi-metric questions ("how are my steps + calories + sleep
        // + water today?") were hitting MAX_TOKENS at 1400 and clipping mid-
        // sentence. 2048 gives ~1000–1300 Arabic words of headroom while the
        // tightened conciseness rules in PromptComposer prevent rambling.
        // finishReason=MAX_TOKENS is decoded in GeminiResponse — watch the
        // gemini_max_tokens_hit log; if it still fires we tune per-screen.
        let maxOutputTokens: Int = {
            switch request.screenContext {
            case .mainChat, .myVibe:
                return 2048
            case .sleepAnalysis:
                return 1200
            case .gym, .kitchen, .peaks:
                return 2048
            }
        }()

        return [
            "systemInstruction": [
                "parts": [
                    ["text": promptBuilder.build(for: request)]
                ]
            ],
            "contents": makeGeminiContents(for: request),
            "generationConfig": [
                "maxOutputTokens": maxOutputTokens,
                "temperature": 0.7
            ]
        ]
    }

    func makeGeminiContents(for request: HybridBrainRequest) -> [[String: Any]] {
        let lastUserIndex = request.conversation.lastIndex(where: { $0.role == .user })

        // Gemini requires strictly alternating user/model roles
        struct Entry {
            let role: String
            var parts: [[String: Any]]
        }

        var entries: [Entry] = []

        for index in request.conversation.indices {
            let message = request.conversation[index]
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, message.role != .system else { continue }

            let role = message.role == .assistant ? "model" : "user"
            var parts: [[String: Any]] = [["text": trimmed]]

            // Attach kitchen image to the last user message only
            if index == lastUserIndex,
               request.screenContext == .kitchen,
               let imageData = request.attachedImageData {
                parts.append([
                    "inlineData": [
                        "mimeType": "image/jpeg",
                        "data": imageData.base64EncodedString()
                    ]
                ])
            }

            // Merge consecutive same-role messages
            if let last = entries.last, last.role == role {
                entries[entries.count - 1].parts.append(contentsOf: parts)
            } else {
                entries.append(Entry(role: role, parts: parts))
            }
        }

        // Gemini requires first content to be "user"
        if let first = entries.first, first.role == "model" {
            entries.insert(Entry(role: "user", parts: [["text": "..."]]), at: 0)
        }

        return entries.map { ["role": $0.role, "parts": $0.parts] }
    }

    // MARK: - Response Encoding

    func encodeStructuredResponse(_ response: CaptainStructuredResponse) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(response)

        guard let rawText = String(data: data, encoding: .utf8) else {
            throw HybridBrainServiceError.invalidStructuredResponse
        }

        return rawText
    }

    // MARK: - Token Streaming

    func tokenStream(for rawText: String) -> AsyncStream<String> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .utility) {
                for chunk in Self.chunked(rawText, size: 24) {
                    guard !Task.isCancelled else { break }
                    continuation.yield(chunk)
                    try? await Task.sleep(nanoseconds: 18_000_000)
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

    // MARK: - Network Availability

    func isNetworkUnavailable(_ error: Error) -> Bool {
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
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isNetworkUnavailable(underlying)
        }
        return false
    }

    func parsingFallbackMessage(for language: AppLanguage) -> String {
        if language == .english {
            return "Sorry, something went wrong with the connection. Could you say that again?"
        }

        return "عذراً، صار خلل بالاتصال، تكدر تعيد كلامك؟"
    }
}
