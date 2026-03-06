import Foundation

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

struct CaptainPromptContext: Sendable {
    let runtime: CaptainSystemContextSnapshot
    let userProfileSummary: String
}

struct CaptainServiceReply: Sendable {
    let message: String
    let workoutPlan: WorkoutPlan?
    let rawText: String
}

protocol CaptainAPIKeyProviding: Sendable {
    func openAIAPIKey() throws -> String
}

enum CaptainSecretsError: LocalizedError {
    case missingOpenAIAPIKey

    var errorDescription: String? {
        switch self {
        case .missingOpenAIAPIKey:
            return "OpenAI API key is missing. Set OPENAI_API_KEY or CAPTAIN_OPENAI_API_KEY in the app environment."
        }
    }
}

struct CaptainSecretsManager: CaptainAPIKeyProviding {
    static let shared = CaptainSecretsManager()

    private let bundle: Bundle
    private let processInfo: ProcessInfo

    init(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) {
        self.bundle = bundle
        self.processInfo = processInfo
    }

    func openAIAPIKey() throws -> String {
        let info = bundle.infoDictionary ?? [:]
        let candidates = [
            normalized(processInfo.environment["OPENAI_API_KEY"]),
            normalized(processInfo.environment["CAPTAIN_OPENAI_API_KEY"]),
            normalized(processInfo.environment["COACH_BRAIN_LLM_API_KEY"]),
            normalized(info["OPENAI_API_KEY"] as? String),
            normalized(info["CAPTAIN_OPENAI_API_KEY"] as? String),
            normalized(info["COACH_BRAIN_LLM_API_KEY"] as? String)
        ]

        if let apiKey = candidates.compactMap({ $0 }).first {
            return apiKey
        }

        throw CaptainSecretsError.missingOpenAIAPIKey
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }

        return trimmed
    }
}

/// Unified OpenAI-backed Captain network service.
final class CaptainService: @unchecked Sendable {
    static let defaultEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    static let defaultModel = "gpt-5-mini"
    static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()

    private let apiKeyProvider: any CaptainAPIKeyProviding
    private let session: URLSession
    private let endpoint: URL
    private let model: String

    init(
        apiKeyProvider: (any CaptainAPIKeyProviding)? = nil,
        session: URLSession = CaptainService.defaultSession,
        endpoint: URL = CaptainService.defaultEndpoint,
        model: String = CaptainService.defaultModel
    ) {
        self.apiKeyProvider = apiKeyProvider ?? CaptainSecretsManager.shared
        self.session = session
        self.endpoint = endpoint
        self.model = model
    }

    func generateReply(
        conversation: [CaptainConversationMessage],
        context: CaptainPromptContext
    ) async throws -> CaptainServiceReply {
        let normalizedConversation = conversation.compactMap { message -> CaptainConversationMessage? in
            let trimmedContent = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty else { return nil }
            return CaptainConversationMessage(role: message.role, content: trimmedContent)
        }

        guard !normalizedConversation.isEmpty else {
            throw CaptainServiceError.emptyConversation
        }

        let apiKey: String
        do {
            apiKey = try apiKeyProvider.openAIAPIKey()
        } catch {
            throw CaptainServiceError.missingAPIKey
        }
        let payload = OpenAIChatCompletionsRequest(
            model: model,
            responseFormat: .init(type: "json_object"),
            messages: [
                .init(role: .system, content: Self.systemPrompt(for: context))
            ] + normalizedConversation.map {
                .init(role: $0.role, content: $0.content)
            }
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        let httpResponse = try validateHTTPResponse(response)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw decodeHTTPError(statusCode: httpResponse.statusCode, data: data)
        }

        let completion: OpenAIChatCompletionsResponse
        do {
            completion = try JSONDecoder().decode(OpenAIChatCompletionsResponse.self, from: data)
        } catch {
            throw CaptainServiceError.decodingFailed(underlying: error)
        }

        guard let content = completion.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !content.isEmpty else {
            throw CaptainServiceError.emptyAssistantContent
        }

        let structuredReply = try decodeStructuredReply(from: content)
        return CaptainServiceReply(
            message: structuredReply.message,
            workoutPlan: structuredReply.workoutPlan?.isMeaningful == true ? structuredReply.workoutPlan : nil,
            rawText: content
        )
    }

    private func validateHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CaptainServiceError.invalidResponse
        }

        return httpResponse
    }

    private func decodeHTTPError(statusCode: Int, data: Data) -> CaptainServiceError {
        let apiMessage = try? JSONDecoder().decode(OpenAIErrorEnvelope.self, from: data).error.message
        return .httpError(statusCode: statusCode, message: apiMessage)
    }

    private func decodeStructuredReply(from content: String) throws -> CaptainStructuredResponse {
        guard let data = content.data(using: .utf8) else {
            throw CaptainServiceError.invalidStructuredResponse
        }

        do {
            return try JSONDecoder().decode(CaptainStructuredResponse.self, from: data)
        } catch {
            throw CaptainServiceError.invalidStructuredResponse
        }
    }

    private static func systemPrompt(for context: CaptainPromptContext) -> String {
        let runtime = context.runtime
        let heartRate = runtime.heartRate.map(String.init) ?? "unknown"

        return """
        You are Captain Hamoudi, the unified global AI brain of AiQo.

        Identity:
        - You are an Iraqi fitness coach, spiritual guide, and practical operator for a Bio-Digital OS.
        - Your tone is grounded, sharp, encouraging, and human.
        - You speak in natural Iraqi Arabic unless the user clearly writes in English and expects English.

        Runtime context:
        - Stage: \(runtime.stageNumber) - \(runtime.stageTitle)
        - Time of day: \(runtime.timeOfDay)
        - Current vibe: \(runtime.vibeTitle)
        - Tone hint: \(runtime.toneHint)
        - Steps today: \(runtime.steps)
        - Sleep hours today: \(String(format: "%.1f", runtime.sleepHours))
        - Calories today: \(runtime.calories)
        - Heart rate bpm: \(heartRate)

        User profile:
        \(context.userProfileSummary)

        Behavior rules:
        - Use the live context above when it is relevant.
        - Never invent health metrics beyond the provided context.
        - Keep `message` concise, specific, and actionable.
        - If the user asks for a workout, or if you suggest one based on their health data, populate `workoutPlan`.
        - Never output markdown, explanations, prose outside JSON, or code fences.

        You MUST ALWAYS return a valid JSON object with exactly this top-level structure:
        {
          "message": "The Iraqi response",
          "workoutPlan": {
            "title": "Workout title",
            "exercises": [
              {
                "name": "Exercise name",
                "sets": 3,
                "repsOrDuration": "12 reps"
              }
            ]
          }
        }

        JSON contract:
        - `message` must always be a non-empty string.
        - `workoutPlan` must always be either `null` or an object.
        - If `workoutPlan` is present, `title` must be a non-empty string.
        - If `workoutPlan` is present, `exercises` must be a non-empty array.
        - Each exercise must contain exactly `name` as a string, `sets` as an integer, and `repsOrDuration` as a string.
        - If no workout plan is needed, set `workoutPlan` to `null`.
        """
    }
}

private struct OpenAIChatCompletionsRequest: Encodable {
    let model: String
    let responseFormat: OpenAIChatCompletionsResponseFormat
    let messages: [OpenAIChatCompletionMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case responseFormat = "response_format"
        case messages
    }
}

private struct OpenAIChatCompletionsResponseFormat: Encodable {
    let type: String
}

private struct OpenAIChatCompletionMessage: Encodable {
    let role: String
    let content: String

    init(role: CaptainConversationRole, content: String) {
        self.role = role.rawValue
        self.content = content
    }
}

private struct OpenAIChatCompletionsResponse: Decodable {
    let choices: [OpenAIChatCompletionChoice]
    let usage: OpenAIUsage?
}

private struct OpenAIChatCompletionChoice: Decodable {
    let message: OpenAIChatCompletionResponseMessage
}

private struct OpenAIChatCompletionResponseMessage: Decodable {
    let role: String
    let content: String?
}

private struct OpenAIUsage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

private struct OpenAIErrorEnvelope: Decodable {
    let error: OpenAIErrorDetail
}

private struct OpenAIErrorDetail: Decodable {
    let message: String
    let type: String?
    let param: String?
    let code: String?
}

enum CaptainServiceError: LocalizedError {
    case missingAPIKey
    case emptyConversation
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingFailed(underlying: Error)
    case emptyAssistantContent
    case invalidStructuredResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Set OPENAI_API_KEY or CAPTAIN_OPENAI_API_KEY before launching AiQo."
        case .emptyConversation:
            return "Captain conversation history is empty."
        case .invalidResponse:
            return "Invalid server response."
        case let .httpError(statusCode, message):
            if let message, !message.isEmpty {
                return "OpenAI request failed (\(statusCode)): \(message)"
            }
            return "OpenAI request failed with status code \(statusCode)."
        case let .decodingFailed(underlying):
            return "Failed to decode OpenAI response: \(underlying.localizedDescription)"
        case .emptyAssistantContent:
            return "OpenAI returned empty assistant content."
        case .invalidStructuredResponse:
            return "OpenAI returned JSON that does not match Captain's required schema."
        }
    }
}
