import Foundation

// MARK: - Supabase

enum K {
    enum Supabase {
        private static let defaultURLString = "https://zidbsrepqpbucqzxnwgk.supabase.co"
        private static let defaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppZGJzcmVwcXBidWNxenhud2drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3OTc0NjAsImV4cCI6MjA3ODM3MzQ2MH0.bZYBbhHS90Leb84Ijnq1BV5XZx6uk6-DCNEPmBFnn5M"
        private static let infoURLKey = "SUPABASE_URL"
        private static let infoAnonKeyKey = "SUPABASE_ANON_KEY"

        static let url: String = resolvedBaseURL().absoluteString

        static let anonKey: String = {
            resolvedValue(for: infoAnonKeyKey, defaultValue: defaultAnonKey)
        }()

        static let functionsURL: URL = {
            guard var components = URLComponents(url: resolvedBaseURL(), resolvingAgainstBaseURL: false),
                  let host = components.host,
                  host.hasSuffix(".supabase.co")
            else {
                return URL(string: "https://zidbsrepqpbucqzxnwgk.functions.supabase.co")!
            }

            components.host = host.replacingOccurrences(of: ".supabase.co", with: ".functions.supabase.co")
            return components.url ?? URL(string: "https://zidbsrepqpbucqzxnwgk.functions.supabase.co")!
        }()

        private static func resolvedBaseURL() -> URL {
            let configuredValue = resolvedValue(for: infoURLKey, defaultValue: defaultURLString)
            return URL(string: configuredValue) ?? URL(string: defaultURLString)!
        }

        private static func resolvedValue(for key: String, defaultValue: String) -> String {
            let environment = normalized(ProcessInfo.processInfo.environment[key])
            let info = normalized(Bundle.main.object(forInfoDictionaryKey: key) as? String)
            return environment ?? info ?? defaultValue
        }

        private static func normalized(_ value: String?) -> String? {
            guard let value else { return nil }

            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            guard !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }

            return trimmed
        }
    }
}
