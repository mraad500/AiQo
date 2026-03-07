import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

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
    let mealPlan: MealPlan?
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
        context: CaptainPromptContext,
        image: UIImage? = nil
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

        let requestMessages = try await buildRequestMessages(
            from: normalizedConversation,
            context: context,
            image: image
        )

        let payload = OpenAIChatCompletionsRequest(
            model: model,
            responseFormat: .init(type: "json_object"),
            messages: requestMessages
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
            mealPlan: structuredReply.mealPlan?.isMeaningful == true ? structuredReply.mealPlan : nil,
            rawText: content
        )
    }

    private func buildRequestMessages(
        from conversation: [CaptainConversationMessage],
        context: CaptainPromptContext,
        image: UIImage?
    ) async throws -> [OpenAIChatCompletionMessage] {
        let lastUserIndex = conversation.lastIndex(where: { $0.role == .user })
        var requestMessages: [OpenAIChatCompletionMessage] = [
            .init(role: .system, content: .text(Self.systemPrompt(for: context)))
        ]
        requestMessages.reserveCapacity(conversation.count + 1)

        for (index, message) in conversation.enumerated() {
            if let image, index == lastUserIndex {
                requestMessages.append(
                    .init(
                        role: message.role,
                        content: .parts(
                            try await Self.makeMultimodalContent(
                                text: message.content,
                                image: image
                            )
                        )
                    )
                )
            } else {
                requestMessages.append(.init(role: message.role, content: .text(message.content)))
            }
        }

        return requestMessages
    }

    private static func makeMultimodalContent(
        text: String,
        image: UIImage
    ) async throws -> [OpenAIChatCompletionContentPart] {
        let dataURL = try await makeVisionImageDataURL(from: image)

        return [
            .text(text),
            .imageURL(dataURL)
        ]
    }

    private static func makeVisionImageDataURL(from image: UIImage) async throws -> String {
        let imageBox = CaptainUnsafeUIImageBox(image: image)
        let processingRequest = try await MainActor.run {
            try makeImageProcessingRequest(from: imageBox.image)
        }

        return try await Task.detached(priority: .userInitiated) {
            let processedData = try downsampledJPEGData(
                from: processingRequest.cgImage,
                orientation: processingRequest.orientation,
                maxDimension: processingRequest.maxDimension,
                compressionQuality: processingRequest.compressionQuality
            )
            return "data:image/jpeg;base64,\(processedData.base64EncodedString())"
        }.value
    }

    @MainActor
    private static func makeImageProcessingRequest(from image: UIImage) throws -> CaptainImageProcessingRequest {
        guard let cgImage = image.cgImage else {
            throw CaptainServiceError.invalidImageData
        }

        return CaptainImageProcessingRequest(
            cgImage: cgImage,
            orientation: CaptainImageOrientation(image.imageOrientation),
            maxDimension: 800,
            compressionQuality: 0.3
        )
    }

    nonisolated private static func downsampledJPEGData(
        from cgImage: CGImage,
        orientation: CaptainImageOrientation,
        maxDimension: CGFloat,
        compressionQuality: CGFloat
    ) throws -> Data {
        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let targetSize = scaledImageSize(
            for: sourceSize,
            orientation: orientation,
            maxDimension: maxDimension
        )

        let width = max(Int(targetSize.width.rounded(.up)), 1)
        let height = max(Int(targetSize.height.rounded(.up)), 1)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw CaptainServiceError.imageResizingFailed
        }

        context.interpolationQuality = .high
        context.concatenate(orientationTransform(for: orientation, targetSize: targetSize))

        let drawRect: CGRect
        if usesTransposedCanvas(for: orientation) {
            drawRect = CGRect(origin: .zero, size: CGSize(width: targetSize.height, height: targetSize.width))
        } else {
            drawRect = CGRect(origin: .zero, size: targetSize)
        }

        context.draw(cgImage, in: drawRect)

        guard let resizedImage = context.makeImage() else {
            throw CaptainServiceError.imageResizingFailed
        }

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw CaptainServiceError.imageEncodingFailed
        }

        let properties = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ] as CFDictionary

        CGImageDestinationAddImage(destination, resizedImage, properties)

        guard CGImageDestinationFinalize(destination) else {
            throw CaptainServiceError.imageEncodingFailed
        }

        return destinationData as Data
    }

    nonisolated private static func scaledImageSize(
        for sourceSize: CGSize,
        orientation: CaptainImageOrientation,
        maxDimension: CGFloat
    ) -> CGSize {
        let orientedSize: CGSize

        if usesTransposedCanvas(for: orientation) {
            orientedSize = CGSize(width: sourceSize.height, height: sourceSize.width)
        } else {
            orientedSize = sourceSize
        }

        let longestSide = max(orientedSize.width, orientedSize.height)
        guard longestSide > maxDimension else { return orientedSize }

        let scale = maxDimension / longestSide
        return CGSize(
            width: max(orientedSize.width * scale, 1),
            height: max(orientedSize.height * scale, 1)
        )
    }

    nonisolated private static func usesTransposedCanvas(for orientation: CaptainImageOrientation) -> Bool {
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return true
        default:
            return false
        }
    }

    nonisolated private static func orientationTransform(
        for orientation: CaptainImageOrientation,
        targetSize: CGSize
    ) -> CGAffineTransform {
        var transform = CGAffineTransform.identity

        switch orientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: targetSize.width, y: targetSize.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: targetSize.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: targetSize.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }

        switch orientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: targetSize.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: targetSize.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }

        return transform
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
        - If you receive an image, it is the user's fridge. Identify visible ingredients and populate `mealPlan` with Breakfast, Lunch, and Dinner suggestions plus estimated calories based on those ingredients.
        - If the user asks for food, meals, diet, cooking ideas, or fridge analysis, populate `mealPlan`.
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
          },
          "mealPlan": {
            "meals": [
              {
                "type": "Breakfast",
                "description": "Meal suggestion based on the fridge ingredients",
                "calories": 320
              },
              {
                "type": "Lunch",
                "description": "Meal suggestion based on the fridge ingredients",
                "calories": 540
              },
              {
                "type": "Dinner",
                "description": "Meal suggestion based on the fridge ingredients",
                "calories": 430
              }
            ]
          }
        }

        JSON contract:
        - `message` must always be a non-empty string.
        - `workoutPlan` must always be either `null` or an object.
        - `mealPlan` must always be either `null` or an object.
        - If `workoutPlan` is present, `title` must be a non-empty string.
        - If `workoutPlan` is present, `exercises` must be a non-empty array.
        - Each exercise must contain exactly `name` as a string, `sets` as an integer, and `repsOrDuration` as a string.
        - If `mealPlan` is present, `meals` must be a non-empty array.
        - Each meal must contain exactly `type` as a string, `description` as a string, and `calories` as an integer.
        - If an image is present, `mealPlan` must not be null and it must include Breakfast, Lunch, and Dinner suggestions.
        - If no workout plan is needed, set `workoutPlan` to `null`.
        - If no meal plan is needed, set `mealPlan` to `null`.
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
    let content: OpenAIChatCompletionMessageContent

    init(role: CaptainConversationRole, content: OpenAIChatCompletionMessageContent) {
        self.role = role.rawValue
        self.content = content
    }
}

private enum OpenAIChatCompletionMessageContent: Encodable {
    case text(String)
    case parts([OpenAIChatCompletionContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .text(text):
            try container.encode(text)
        case let .parts(parts):
            try container.encode(parts)
        }
    }
}

private struct OpenAIChatCompletionContentPart: Encodable {
    let type: String
    let text: String?
    let imageURL: OpenAIChatCompletionImageURL?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    static func text(_ value: String) -> Self {
        Self(type: "text", text: value, imageURL: nil)
    }

    static func imageURL(_ value: String) -> Self {
        Self(type: "image_url", text: nil, imageURL: .init(url: value))
    }
}

private struct OpenAIChatCompletionImageURL: Encodable {
    let url: String
}

private struct CaptainImageProcessingRequest: @unchecked Sendable {
    let cgImage: CGImage
    let orientation: CaptainImageOrientation
    let maxDimension: CGFloat
    let compressionQuality: CGFloat
}

private enum CaptainImageOrientation: Sendable {
    case up
    case upMirrored
    case down
    case downMirrored
    case left
    case leftMirrored
    case right
    case rightMirrored

    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

private final class CaptainUnsafeUIImageBox: @unchecked Sendable {
    let image: UIImage

    init(image: UIImage) {
        self.image = image
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
    case invalidImageData
    case imageResizingFailed
    case imageEncodingFailed

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
        case .invalidImageData:
            return "Captain could not read the selected image data."
        case .imageResizingFailed:
            return "Captain could not resize the selected image for upload."
        case .imageEncodingFailed:
            return "Captain could not compress the selected image for upload."
        }
    }
}
