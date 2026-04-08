import Foundation
import os.log

// MARK: - Supabase

enum K {
    enum Supabase {
        private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
            category: "K.Supabase"
        )

        private static let infoURLKey = "SUPABASE_URL"
        private static let infoAnonKeyKey = "SUPABASE_ANON_KEY"

        static let url: String = {
            guard let resolved = resolvedBaseURL() else {
                logger.fault("supabase_url_missing — configure SUPABASE_URL in Secrets.xcconfig")
                return ""
            }
            return resolved.absoluteString
        }()

        static let anonKey: String = {
            guard let key = resolvedValue(for: infoAnonKeyKey) else {
                logger.fault("supabase_anon_key_missing — configure SUPABASE_ANON_KEY in Secrets.xcconfig")
                return ""
            }
            return key
        }()

        static let functionsURL: URL? = {
            guard let base = resolvedBaseURL(),
                  var components = URLComponents(url: base, resolvingAgainstBaseURL: false),
                  let host = components.host,
                  host.hasSuffix(".supabase.co")
            else {
                return nil
            }

            components.host = host.replacingOccurrences(of: ".supabase.co", with: ".functions.supabase.co")
            return components.url
        }()

        private static func resolvedBaseURL() -> URL? {
            guard let configuredValue = resolvedValue(for: infoURLKey) else { return nil }
            return URL(string: configuredValue)
        }

        private static func resolvedValue(for key: String) -> String? {
            let environment = normalized(ProcessInfo.processInfo.environment[key])
            let info = normalized(Bundle.main.object(forInfoDictionaryKey: key) as? String)
            return environment ?? info
        }

        private static func normalized(_ value: String?) -> String? {
            guard let value else { return nil }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let unquoted = if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") {
                String(trimmed.dropFirst().dropLast())
            } else {
                trimmed
            }
            let normalized = unquoted.replacingOccurrences(of: "\\/", with: "/")

            guard !normalized.isEmpty else { return nil }
            guard !(normalized.hasPrefix("$(") && normalized.hasSuffix(")")) else { return nil }

            return normalized
        }
    }
}
