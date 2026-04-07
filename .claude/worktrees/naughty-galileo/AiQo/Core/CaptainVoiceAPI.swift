import Foundation

enum CaptainVoiceAPI {
    private static let apiKeyName = "CAPTAIN_VOICE_API_KEY"
    private static let voiceIDName = "CAPTAIN_VOICE_VOICE_ID"
    private static let apiURLName = "CAPTAIN_VOICE_API_URL"
    private static let modelIDName = "CAPTAIN_VOICE_MODEL_ID"
    private static let defaultAPIURL = "https://api.elevenlabs.io/v1/text-to-speech"
    private static let defaultModelID = "eleven_multilingual_v2"

    struct Configuration: Sendable {
        let apiKey: String
        let voiceID: String
        let apiURL: URL
        let modelID: String
    }

    struct VoiceSettings: Encodable {
        let stability: Double
        let similarityBoost: Double
        let style: Double
        let useSpeakerBoost: Bool

        enum CodingKeys: String, CodingKey {
            case stability
            case similarityBoost = "similarity_boost"
            case style
            case useSpeakerBoost = "use_speaker_boost"
        }
    }

    struct SpeechRequest: Encodable {
        let text: String
        let modelID: String
        let voiceSettings: VoiceSettings

        enum CodingKeys: String, CodingKey {
            case text
            case modelID = "model_id"
            case voiceSettings = "voice_settings"
        }
    }

    enum Error: LocalizedError {
        case missingConfiguration
        case invalidEndpoint
        case unexpectedResponse
        case server(statusCode: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Captain voice API configuration is missing."
            case .invalidEndpoint:
                return "Captain voice API endpoint is invalid."
            case .unexpectedResponse:
                return "Captain voice API returned an invalid response."
            case let .server(statusCode, message):
                return "Captain voice API error \(statusCode): \(message)"
            }
        }
    }

    static var isConfigured: Bool {
        configuration() != nil
    }

    static func synthesizeSpeech(for text: String) async throws -> Data {
        guard let configuration = configuration() else {
            throw Error.missingConfiguration
        }

        guard var components = URLComponents(
            url: configuration.apiURL.appendingPathComponent(configuration.voiceID),
            resolvingAgainstBaseURL: false
        ) else {
            throw Error.invalidEndpoint
        }

        components.queryItems = [
            URLQueryItem(name: "output_format", value: "mp3_44100_128")
        ]

        guard let requestURL = components.url else {
            throw Error.invalidEndpoint
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "xi-api-key")
        request.httpBody = try JSONEncoder().encode(
            SpeechRequest(
                text: text,
                modelID: configuration.modelID,
                voiceSettings: VoiceSettings(
                    stability: 0.34,
                    similarityBoost: 0.88,
                    style: 0.18,
                    useSpeakerBoost: true
                )
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.unexpectedResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw Error.server(
                statusCode: httpResponse.statusCode,
                message: errorMessage(from: data)
            )
        }

        return data
    }

    private static func configuration(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> Configuration? {
        let info = bundle.infoDictionary ?? [:]

        let apiKey = normalized(processInfo.environment[apiKeyName])
            ?? normalized(info[apiKeyName] as? String)
        let voiceID = normalized(processInfo.environment[voiceIDName])
            ?? normalized(info[voiceIDName] as? String)
        let configuredAPIURLString = normalized(processInfo.environment[apiURLName])
            ?? normalized(info[apiURLName] as? String)
        let modelID = normalized(processInfo.environment[modelIDName])
            ?? normalized(info[modelIDName] as? String)
            ?? defaultModelID
        let apiURL = resolvedAPIURL(from: configuredAPIURLString)

        guard
            let apiKey,
            let voiceID,
            let apiURL
        else {
            return nil
        }

        return Configuration(
            apiKey: apiKey,
            voiceID: voiceID,
            apiURL: apiURL,
            modelID: modelID
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private static func resolvedAPIURL(from configuredValue: String?) -> URL? {
        if
            let configuredValue,
            let configuredURL = URL(string: configuredValue),
            let host = configuredURL.host,
            !host.isEmpty
        {
            return configuredURL
        }

        return URL(string: defaultAPIURL)
    }

    private static func errorMessage(from data: Data) -> String {
        guard !data.isEmpty else { return "No response body" }

        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = json["detail"] as? [String: Any],
            let message = detail["message"] as? String
        {
            return message
        }

        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = json["message"] as? String
        {
            return message
        }

        return String(decoding: data, as: UTF8.self)
    }
}
