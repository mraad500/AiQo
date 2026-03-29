import Foundation
import os.log

enum CaptainConversationRole: String, Sendable {
    case system
    case user
    case assistant
}

struct CaptainConversationMessage: Sendable {
    let role: CaptainConversationRole
    let content: String

    init(role: CaptainConversationRole, content: String) {
        self.role = role
        self.content = content
    }
}

struct HybridBrainRequest: Sendable {
    let conversation: [CaptainConversationMessage]
    let screenContext: ScreenContext
    let language: AppLanguage
    let contextData: CaptainContextData
    let userProfileSummary: String
    let attachedImageData: Data?

    var hasAttachedImage: Bool {
        attachedImageData != nil
    }
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

enum HybridBrainServiceError: LocalizedError {
    case emptyConversation
    case missingUserMessage
    case invalidStructuredResponse
    case invalidResponse
    case emptyResponse
    case badStatusCode(Int)
    case networkUnavailable
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .emptyConversation:
            return "Captain hybrid generation cannot run with an empty conversation."
        case .missingUserMessage:
            return "Captain hybrid generation requires a user message."
        case .invalidStructuredResponse:
            return "Captain hybrid generation produced invalid structured JSON."
        case .invalidResponse:
            return "Captain hybrid generation returned an invalid response."
        case .emptyResponse:
            return "Captain hybrid generation returned an empty response."
        case .badStatusCode(let statusCode):
            return "Captain hybrid generation returned status code \(statusCode)."
        case .networkUnavailable:
            return "Captain hybrid generation is temporarily unavailable."
        case .requestFailed:
            return "Captain hybrid generation request failed."
        }
    }
}

enum HybridBrainServiceConfigurationError: LocalizedError {
    case missingAPIKey
    case invalidEndpoint

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Captain API key is missing from configuration."
        case .invalidEndpoint:
            return "Captain prompt endpoint is invalid."
        }
    }
}

private struct HybridBrainServiceConfiguration: Sendable {
    let endpointURL: URL
    let apiKey: String
}

private enum HybridBrainServiceConfig {
    static let apiKeyName = "CAPTAIN_API_KEY"
    static let fallbackAPIKeyName = "COACH_BRAIN_LLM_API_KEY"
    static let model = "gemini-3-flash-preview"
    static let baseEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"

    static func resolve(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) throws -> HybridBrainServiceConfiguration {
        let info = bundle.infoDictionary ?? [:]
        let apiKey = normalized(processInfo.environment[apiKeyName])
            ?? normalized(info[apiKeyName] as? String)
            ?? normalized(processInfo.environment[fallbackAPIKeyName])
            ?? normalized(info[fallbackAPIKeyName] as? String)

        guard let apiKey else {
            throw HybridBrainServiceConfigurationError.missingAPIKey
        }
        guard let endpointURL = URL(string: "\(baseEndpoint)/\(model):generateContent?key=\(apiKey)") else {
            throw HybridBrainServiceConfigurationError.invalidEndpoint
        }

        return HybridBrainServiceConfiguration(
            endpointURL: endpointURL,
            apiKey: apiKey
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }

        return trimmed
    }
}

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

private struct GeminiAPIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String?
    }

    let error: APIError?
}

struct HybridBrainService: Sendable {
    private let session: URLSession
    private let bundle: Bundle
    private let promptBuilder: CaptainPromptBuilder
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "HybridBrainService"
    )

    init(
        session: URLSession = .shared,
        bundle: Bundle = .main,
        promptBuilder: CaptainPromptBuilder = CaptainPromptBuilder()
    ) {
        self.session = session
        self.bundle = bundle
        self.promptBuilder = promptBuilder
    }

    func generateReply(request: HybridBrainRequest) async throws -> HybridBrainServiceReply {
        try validate(request)

        let configuration = try HybridBrainServiceConfig.resolve(bundle: bundle)
        let structuredResponse = try await requestCloudResponse(
            configuration: configuration,
            request: request
        )
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

private extension HybridBrainService {
    func validate(_ request: HybridBrainRequest) throws {
        let normalizedConversation = request.conversation.compactMap { message -> CaptainConversationMessage? in
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return CaptainConversationMessage(role: message.role, content: trimmed)
        }

        guard !normalizedConversation.isEmpty else {
            throw HybridBrainServiceError.emptyConversation
        }
        guard normalizedConversation.contains(where: { $0.role == .user }) else {
            throw HybridBrainServiceError.missingUserMessage
        }
    }

    func requestCloudResponse(
        configuration: HybridBrainServiceConfiguration,
        request: HybridBrainRequest
    ) async throws -> CaptainStructuredResponse {
        var urlRequest = URLRequest(url: configuration.endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 35
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = try JSONSerialization.data(
            withJSONObject: makeRequestBody(
                configuration: configuration,
                request: request
            )
        )

        logger.notice("gemini_request url=\(configuration.endpointURL.absoluteString.prefix(80), privacy: .public)")

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
            logger.error(
                "gemini_bad_status status=\(httpResponse.statusCode) body=\(rawBody.prefix(500), privacy: .public)"
            )
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

        return try decodeStructuredResponse(from: outputText)
    }

    func makeRequestBody(
        configuration: HybridBrainServiceConfiguration,
        request: HybridBrainRequest
    ) -> [String: Any] {
        return [
            "systemInstruction": [
                "parts": [
                    ["text": developerContextMessage(for: request)]
                ]
            ],
            "contents": makeGeminiContents(for: request),
            "generationConfig": [
                "maxOutputTokens": 900,
                "temperature": 0.7
            ]
        ]
    }

    func makeGeminiContents(for request: HybridBrainRequest) -> [[String: Any]] {
        let lastUserIndex = request.conversation.lastIndex(where: { $0.role == .user })

        // Build raw entries first, then merge consecutive same-role messages
        // because Gemini requires strictly alternating user/model roles.
        struct Entry {
            let role: String
            var parts: [[String: Any]]
        }

        var entries: [Entry] = []

        for index in request.conversation.indices {
            let message = request.conversation[index]
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard message.role != .system else { continue }

            let role = message.role == .assistant ? "model" : "user"
            var parts: [[String: Any]] = [["text": trimmed]]

            if index == lastUserIndex,
               request.screenContext == .kitchen,
               let attachedImageData = request.attachedImageData {
                parts.append([
                    "inlineData": [
                        "mimeType": "image/jpeg",
                        "data": attachedImageData.base64EncodedString()
                    ]
                ])
            }

            // Merge with previous entry if same role (Gemini requires alternating roles)
            if let last = entries.last, last.role == role {
                entries[entries.count - 1].parts.append(contentsOf: parts)
            } else {
                entries.append(Entry(role: role, parts: parts))
            }
        }

        // Gemini requires the first content to be "user" role
        if let first = entries.first, first.role == "model" {
            entries.insert(Entry(role: "user", parts: [["text": "..."]]), at: 0)
        }

        return entries.map { ["role": $0.role, "parts": $0.parts] }
    }

    func developerContextMessage(for request: HybridBrainRequest) -> String {
        promptBuilder.build(for: request)
    }

    func decodeStructuredResponse(from rawText: String) throws -> CaptainStructuredResponse {
        // Strip markdown code fences Gemini sometimes wraps JSON in
        let cleaned = rawText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw HybridBrainServiceError.invalidStructuredResponse
        }

        do {
            return try JSONDecoder().decode(CaptainStructuredResponse.self, from: data)
        } catch {
            // If structured parsing fails, wrap the raw text as a simple message response
            let fallback = CaptainStructuredResponse(
                message: cleaned,
                quickReplies: nil,
                workoutPlan: nil,
                mealPlan: nil,
                spotifyRecommendation: nil
            )
            return fallback
        }
    }

    func encodeStructuredResponse(_ response: CaptainStructuredResponse) throws -> String {
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
                    try? await Task.sleep(nanoseconds: 18_000_000)
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
