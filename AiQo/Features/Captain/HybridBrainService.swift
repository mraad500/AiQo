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
    let promptID: String
    let promptVersion: String
}

private enum HybridBrainServiceConfig {
    static let apiKeyName = "CAPTAIN_API_KEY"
    static let fallbackAPIKeyName = "COACH_BRAIN_LLM_API_KEY"
    // SECURITY TODO: Route through a backend proxy before v2.0
    // Direct client→OpenAI exposes the API key in the binary and sends user data
    // without an intermediary. For v1.0 this is an accepted risk documented in the audit.
    static let endpoint = "https://api.openai.com/v1/responses"
    static let promptID = "pmpt_6989314757d48190b10842e9b852048d0f4dbc957002f486"
    static let promptVersion = "9"

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
        guard let endpointURL = URL(string: endpoint) else {
            throw HybridBrainServiceConfigurationError.invalidEndpoint
        }

        return HybridBrainServiceConfiguration(
            endpointURL: endpointURL,
            apiKey: apiKey,
            promptID: promptID,
            promptVersion: promptVersion
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

private struct HybridBrainResponsesResponse: Decodable {
    struct Output: Decodable {
        struct Content: Decodable {
            let type: String?
            let text: String?
        }

        let type: String?
        let content: [Content]?
    }

    let output: [Output]?
    let outputTextValue: String?

    enum CodingKeys: String, CodingKey {
        case output
        case outputTextValue = "output_text"
    }

    var outputText: String {
        if let outputTextValue {
            let trimmed = outputTextValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private struct HybridBrainAPIErrorEnvelope: Decodable {
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
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONSerialization.data(
            withJSONObject: makeRequestBody(
                configuration: configuration,
                request: request
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw isNetworkUnavailable(error)
                ? HybridBrainServiceError.networkUnavailable
                : HybridBrainServiceError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HybridBrainServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let envelope = try? JSONDecoder().decode(HybridBrainAPIErrorEnvelope.self, from: data),
               let message = envelope.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !message.isEmpty {
                logger.error(
                    "hybrid_brain_bad_status status=\(httpResponse.statusCode) message=\(message, privacy: .public)"
                )
            }
            throw HybridBrainServiceError.badStatusCode(httpResponse.statusCode)
        }

        let decoded: HybridBrainResponsesResponse
        do {
            decoded = try JSONDecoder().decode(HybridBrainResponsesResponse.self, from: data)
        } catch {
            throw HybridBrainServiceError.invalidResponse
        }

        let outputText = decoded.outputText
        guard !outputText.isEmpty else {
            throw HybridBrainServiceError.emptyResponse
        }

        return try decodeStructuredResponse(from: outputText)
    }

    func makeRequestBody(
        configuration: HybridBrainServiceConfiguration,
        request: HybridBrainRequest
    ) -> [String: Any] {
        [
            "prompt": [
                "id": configuration.promptID,
                "version": configuration.promptVersion
            ],
            "input": makeInputMessages(for: request),
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "captain_structured_response",
                    "description": "Captain Hamoudi structured reply for the AiQo chat UI.",
                    "strict": true,
                    "schema": structuredResponseSchema()
                ]
            ],
            "max_output_tokens": 900,
            "store": false
        ]
    }

    func makeInputMessages(for request: HybridBrainRequest) -> [[String: Any]] {
        var messages: [[String: Any]] = [
            [
                "role": "developer",
                "content": [
                    [
                        "type": "input_text",
                        "text": developerContextMessage(for: request)
                    ]
                ]
            ]
        ]

        let lastUserIndex = request.conversation.lastIndex(where: { $0.role == .user })

        for index in request.conversation.indices {
            let message = request.conversation[index]
            let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Responses API: assistant messages use "output_text", all others use "input_text"
            let textType = message.role == .assistant ? "output_text" : "input_text"

            var content: [[String: Any]] = [
                [
                    "type": textType,
                    "text": trimmed
                ]
            ]

            if index == lastUserIndex,
               request.screenContext == .kitchen,
               let attachedImageData = request.attachedImageData {
                content.append(
                    [
                        "type": "input_image",
                        "image_url": makeDataURL(for: attachedImageData),
                        "detail": "low"
                    ]
                )
            }

            messages.append(
                [
                    "role": roleLabel(for: message.role),
                    "content": content
                ]
            )
        }

        return messages
    }

    func roleLabel(for role: CaptainConversationRole) -> String {
        switch role {
        case .system:
            return "developer"
        case .user:
            return "user"
        case .assistant:
            return "assistant"
        }
    }

    func developerContextMessage(for request: HybridBrainRequest) -> String {
        promptBuilder.build(for: request)
    }

    func structuredResponseSchema() -> [String: Any] {
        let exerciseSchema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["name", "sets", "repsOrDuration"],
            "properties": [
                "name": [
                    "type": "string",
                    "minLength": 1
                ],
                "sets": [
                    "type": "integer",
                    "minimum": 1
                ],
                "repsOrDuration": [
                    "type": "string",
                    "minLength": 1
                ]
            ]
        ]

        let workoutPlanSchema: [String: Any] = [
            "type": ["object", "null"],
            "additionalProperties": false,
            "required": ["title", "exercises"],
            "properties": [
                "title": [
                    "type": "string",
                    "minLength": 1
                ],
                "exercises": [
                    "type": "array",
                    "minItems": 1,
                    "items": exerciseSchema
                ]
            ]
        ]

        let mealSchema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["type", "description", "calories"],
            "properties": [
                "type": [
                    "type": "string",
                    "minLength": 1
                ],
                "description": [
                    "type": "string",
                    "minLength": 1
                ],
                "calories": [
                    "type": "integer",
                    "minimum": 1
                ]
            ]
        ]

        let mealPlanSchema: [String: Any] = [
            "type": ["object", "null"],
            "additionalProperties": false,
            "required": ["meals"],
            "properties": [
                "meals": [
                    "type": "array",
                    "minItems": 1,
                    "items": mealSchema
                ]
            ]
        ]

        let spotifyRecommendationSchema: [String: Any] = [
            "type": ["object", "null"],
            "additionalProperties": false,
            "required": ["vibeName", "description", "spotifyURI"],
            "properties": [
                "vibeName": [
                    "type": "string",
                    "minLength": 1
                ],
                "description": [
                    "type": "string",
                    "minLength": 1
                ],
                "spotifyURI": [
                    "type": "string",
                    "minLength": 1
                ]
            ]
        ]

        let quickRepliesSchema: [String: Any] = [
            "type": ["array", "null"],
            "items": [
                "type": "string"
            ]
        ]

        return [
            "type": "object",
            "additionalProperties": false,
            "required": ["message", "quickReplies", "workoutPlan", "mealPlan", "spotifyRecommendation"],
            "properties": [
                "message": [
                    "type": "string",
                    "minLength": 1
                ],
                "quickReplies": quickRepliesSchema,
                "workoutPlan": workoutPlanSchema,
                "mealPlan": mealPlanSchema,
                "spotifyRecommendation": spotifyRecommendationSchema
            ]
        ]
    }

    func makeDataURL(for data: Data) -> String {
        "data:image/jpeg;base64,\(data.base64EncodedString())"
    }

    func decodeStructuredResponse(from rawText: String) throws -> CaptainStructuredResponse {
        guard let data = rawText.data(using: .utf8) else {
            throw HybridBrainServiceError.invalidStructuredResponse
        }

        do {
            return try JSONDecoder().decode(CaptainStructuredResponse.self, from: data)
        } catch {
            throw HybridBrainServiceError.invalidStructuredResponse
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
