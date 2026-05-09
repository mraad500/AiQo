import Foundation

/// Resolves the MiniMax voice configuration from runtime inputs.
///
/// Priority order:
/// 1. Keychain (for API key only, if previously persisted)
/// 2. Info.plist values populated from xcconfig
/// 3. Process environment (useful for CI / debug launches)
///
/// The normalizers are intentionally forgiving so the app still works when
/// local config contains common setup mistakes:
/// - unescaped xcconfig URL values becoming `https:`
/// - docs page URLs instead of the real API endpoint
/// - model labels copied with UI suffixes like `speech-2.8-hd New`
enum MiniMaxVoiceConfiguration {
    struct Resolved: Equatable {
        let apiKey: String
        let endpointURL: URL
        let modelID: String
        let voiceID: String
    }

    private static let defaultEndpointString = "https://api.minimax.io/v1/t2a_v2"
    private static let supportedModels: Set<String> = [
        "speech-2.8-hd",
        "speech-2.8-turbo",
        "speech-2.6-hd",
        "speech-2.6-turbo",
        "speech-02-hd",
        "speech-02-turbo",
        "speech-01-hd",
        "speech-01-turbo",
    ]

    static func resolved() -> Resolved? {
        guard let apiKey = resolvedAPIKey(),
              let modelID = resolvedModelID(),
              let voiceID = resolvedVoiceID()
        else {
            return nil
        }

        return Resolved(
            apiKey: apiKey,
            endpointURL: resolvedEndpointURL(),
            modelID: modelID,
            voiceID: voiceID
        )
    }

    static func resolvedAPIKey() -> String? {
        // Build-time key (Secrets.xcconfig → Info.plist) takes precedence
        // over the Keychain cache. Earlier behavior preferred the cached
        // copy, which silently kept rotated keys alive after a re-build.
        // The Keychain remains a fallback for IPAs without xcconfig
        // (CI / TestFlight builds where a runtime provisioning step writes
        // the key).
        if let buildKey = rawValue(for: "CAPTAIN_VOICE_API_KEY"),
           isUsable(buildKey) {
            if CaptainVoiceKeychain.miniMaxAPIKey() != buildKey {
                CaptainVoiceKeychain.setMiniMaxAPIKey(buildKey)
            }
            return buildKey
        }

        if let stored = CaptainVoiceKeychain.miniMaxAPIKey(),
           isUsable(stored) {
            return stored
        }

        return nil
    }

    static func resolvedEndpointURL() -> URL {
        normalizedEndpointURL(from: rawValue(for: "CAPTAIN_VOICE_API_URL"))
            ?? URL(string: defaultEndpointString)!
    }

    static func resolvedModelID() -> String? {
        normalizedModelID(from: rawValue(for: "CAPTAIN_VOICE_MODEL_ID"))
    }

    static func resolvedVoiceID() -> String? {
        normalizedVoiceID(from: rawValue(for: "CAPTAIN_VOICE_VOICE_ID"))
    }

    static func normalizedModelID(from raw: String?) -> String? {
        guard let raw, isUsable(raw) else { return nil }

        let trimmed = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if supportedModels.contains(trimmed) {
            return trimmed
        }

        let firstToken = trimmed
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)

        if let firstToken, supportedModels.contains(firstToken) {
            return firstToken
        }

        let withoutSuffix = trimmed
            .replacingOccurrences(of: " New", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if supportedModels.contains(withoutSuffix) {
            return withoutSuffix
        }

        return nil
    }

    static func normalizedVoiceID(from raw: String?) -> String? {
        guard let raw, isUsable(raw) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedEndpointURL(from raw: String?) -> URL? {
        let defaultURL = URL(string: defaultEndpointString)

        guard let raw, isUsable(raw) else {
            return defaultURL
        }

        let normalized = raw
            .replacingOccurrences(of: #"\/"#, with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Common xcconfig failure when `https://` isn't escaped.
        if normalized == "https:" || normalized == "http:" {
            return defaultURL
        }

        // User copied the website/docs URL instead of the HTTP API endpoint.
        if normalized.contains("www.minimax.io/audio/text-to-speech")
            || normalized.contains("platform.minimax.io/docs/api-reference/speech-t2a-http") {
            return defaultURL
        }

        guard let url = URL(string: normalized),
              let scheme = url.scheme,
              let host = url.host,
              !scheme.isEmpty,
              !host.isEmpty
        else {
            return defaultURL
        }

        return url
    }

    private static func rawValue(for key: String) -> String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           isUsable(value) {
            return value
        }

        if let value = ProcessInfo.processInfo.environment[key],
           isUsable(value) {
            return value
        }

        return nil
    }

    private static func isUsable(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && !trimmed.hasPrefix("$(")
            && trimmed != "YOUR_API_KEY_HERE"
            && trimmed != "YOUR_MODEL_ID_HERE"
            && trimmed != "YOUR_VOICE_ID_HERE"
            && trimmed != "YOUR_API_URL_HERE"
    }
}
