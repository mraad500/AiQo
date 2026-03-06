import Foundation
import os.log

struct CoachBrainTranslationServiceConfiguration: Sendable {
    let endpointURL: URL
    let apiKey: String
}

enum CoachBrainTranslationConfigurationError: LocalizedError {
    case invalidEndpoint
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Coach Brain translation endpoint is invalid."
        case .missingAPIKey:
            return "Coach Brain translation API key is missing."
        }
    }
}

enum CoachBrainTranslationConfig {
    static let apiKeyName = "COACH_BRAIN_LLM_API_KEY"
    static let endpointName = "COACH_BRAIN_LLM_API_URL"

    private static let defaultEndpoint = "https://api.openai.com/v1/responses"
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CoachBrainTranslationConfig"
    )

    static func resolve(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) throws -> CoachBrainTranslationServiceConfiguration {
        let info = bundle.infoDictionary ?? [:]
        let endpointFromEnvironment = normalized(processInfo.environment[endpointName])
        let endpointFromInfo = normalized(info[endpointName] as? String)
        let endpointString = endpointFromEnvironment ?? endpointFromInfo ?? defaultEndpoint

        let keyFromEnvironment = normalized(processInfo.environment[apiKeyName])
        let keyFromInfo = normalized(info[apiKeyName] as? String)
        let apiKey = keyFromEnvironment ?? keyFromInfo

        let keyPresence = apiKey == nil ? "missing" : "present"
        let endpointSource: String
        if endpointFromEnvironment != nil {
            endpointSource = "environment"
        } else if endpointFromInfo != nil {
            endpointSource = "info_plist"
        } else {
            endpointSource = "default"
        }

        logger.notice(
            "translation_config key=\(keyPresence, privacy: .public) endpoint_source=\(endpointSource, privacy: .public)"
        )

        guard let endpointURL = URL(string: endpointString) else {
            throw CoachBrainTranslationConfigurationError.invalidEndpoint
        }

        guard let apiKey else {
            throw CoachBrainTranslationConfigurationError.missingAPIKey
        }

        return CoachBrainTranslationServiceConfiguration(
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
