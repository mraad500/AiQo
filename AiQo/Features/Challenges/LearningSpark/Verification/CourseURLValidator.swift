import Foundation

/// Classifies a raw URL string for the certificate-link input on the proof submission
/// view. Used to drive a live badge (✅ / ⚠️ / ❌). Pure, synchronous, no network.
enum CourseURLValidator {
    enum Badge: Equatable {
        /// URL parses AND the host is in `trustedDomains`.
        case trusted
        /// URL parses but host is not in the trusted allowlist.
        case untrusted
        /// URL fails basic parse (missing scheme/host/malformed).
        case invalid
        /// Empty input — no badge rendered.
        case empty
    }

    static let trustedDomains: Set<String> = [
        "edraak.org",
        "coursera.org",
        "edx.org",
        "rwaq.org",
        "maharah.net",
        "udemy.com"
    ]

    static func classify(_ raw: String) -> Badge {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host?.lowercased(),
              !host.isEmpty
        else {
            return .invalid
        }

        if trustedDomains.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
            return .trusted
        }
        return .untrusted
    }
}
