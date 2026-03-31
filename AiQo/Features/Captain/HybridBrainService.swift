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

struct HybridBrainRequest: Sendable {
    let conversation: [CaptainConversationMessage]
    let screenContext: ScreenContext
    let language: AppLanguage
    let contextData: CaptainContextData
    let userProfileSummary: String
    let attachedImageData: Data?

    var hasAttachedImage: Bool { attachedImageData != nil }
}

struct HybridBrainServiceReply: Sendable {
    let message: String
    let quickReplies: [String]?
    let workoutPlan: WorkoutPlan?
    let mealPlan: MealPlan?
    let spotifyRecommendation: SpotifyRecommendation?
    let rawText: String
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
    static let model = "gemini-flash-latest"
    static let baseEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"
    static let requestTimeoutSeconds: TimeInterval = 35

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

    static func endpointURL() throws -> URL {
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

private struct GeminiResponse: Decodable {
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

// MARK: - HybridBrainService (Gemini 3 Flash Cloud Transport)

struct HybridBrainService: Sendable {
    private let session: URLSession
    private let promptBuilder: CaptainPromptBuilder
    private let jsonParser: LLMJSONParser
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "HybridBrainService"
    )

    init(
        session: URLSession = .shared,
        promptBuilder: CaptainPromptBuilder = CaptainPromptBuilder(),
        jsonParser: LLMJSONParser = LLMJSONParser()
    ) {
        self.session = session
        self.promptBuilder = promptBuilder
        self.jsonParser = jsonParser
    }

    // MARK: - Public API

    func generateReply(request: HybridBrainRequest) async throws -> HybridBrainServiceReply {
        try validate(request)

        let structuredResponse = try await requestCloudResponse(request: request)
        let rawText = try encodeStructuredResponse(structuredResponse)

        return HybridBrainServiceReply(
            message: CaptainPersonaBuilder.sanitizeResponse(structuredResponse.message),
            quickReplies: structuredResponse.quickReplies,
            workoutPlan: structuredResponse.workoutPlan,
            mealPlan: structuredResponse.mealPlan,
            spotifyRecommendation: structuredResponse.spotifyRecommendation,
            rawText: rawText
        )
    }

    func startStreamingReply(request: HybridBrainRequest) async throws -> HybridBrainStreamingSession {
        let reply = try await generateReply(request: request)
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

    func requestCloudResponse(request: HybridBrainRequest) async throws -> CaptainStructuredResponse {
        let apiKey = try GeminiConfig.resolvedAPIKey()
        var urlRequest = URLRequest(url: try GeminiConfig.endpointURL())
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = GeminiConfig.requestTimeoutSeconds
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        urlRequest.httpBody = try JSONSerialization.data(
            withJSONObject: makeRequestBody(request: request)
        )

        logger.notice("gemini_request model=\(GeminiConfig.model, privacy: .public)")

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
            let rawBody = String(data: data, encoding: .utf8) ?? "nil"
            logger.error("gemini_bad_status status=\(httpResponse.statusCode) body=\(rawBody.prefix(500), privacy: .public)")
            throw HybridBrainServiceError.badStatusCode(httpResponse.statusCode)
        }

        let decoded: GeminiResponse
        do {
            decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8) ?? "nil"
            logger.error("gemini_decode_error body=\(rawBody.prefix(500), privacy: .public)")
            throw HybridBrainServiceError.invalidResponse
        }

        let outputText = decoded.outputText
        logger.notice("gemini_output length=\(outputText.count)")
        guard !outputText.isEmpty else {
            throw HybridBrainServiceError.emptyResponse
        }

        // Use LLMJSONParser for robust extraction
        let fallback = CaptainStructuredResponse(message: outputText)
        return jsonParser.decode(outputText, fallback: fallback)
    }

    // MARK: - Request Body

    func makeRequestBody(request: HybridBrainRequest) -> [String: Any] {
        let maxOutputTokens: Int = {
            switch request.screenContext {
            case .mainChat, .myVibe, .sleepAnalysis:
                return 600
            case .gym, .kitchen, .peaks:
                return 900
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
}
