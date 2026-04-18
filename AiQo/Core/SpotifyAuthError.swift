import Foundation

/// User-safe classification of Spotify SDK / auth errors.
/// Maps raw NSError / URLError into a short set of kinds with a matching
/// dialect-correct Arabic string (+ English equivalent) so no SDK jargon
/// leaks to the UI.
struct SpotifyAuthError {
    enum Kind {
        case notInstalled
        case cancelled
        case devMode
        case network
        case tokenExpired
        case generic
    }

    let kind: Kind
    let code: String

    var localizedMessage: String {
        switch kind {
        case .notInstalled: return NSLocalizedString("spotify.err.notInstalled", comment: "")
        case .cancelled:    return NSLocalizedString("spotify.err.cancelled", comment: "")
        case .devMode:      return NSLocalizedString("spotify.err.devMode", comment: "")
        case .network:      return NSLocalizedString("spotify.err.network", comment: "")
        case .tokenExpired: return NSLocalizedString("spotify.err.tokenExpired", comment: "")
        case .generic:      return NSLocalizedString("spotify.err.generic", comment: "")
        }
    }

    static let notInstalled = SpotifyAuthError(kind: .notInstalled, code: "spotify_not_installed")
    static let tokenExpired = SpotifyAuthError(kind: .tokenExpired, code: "spotify_token_expired")
    static let generic      = SpotifyAuthError(kind: .generic,      code: "spotify_generic")

    /// Map an underlying error into a user-safe category.
    /// Always log the raw domain/code separately for diagnostics — never show it.
    static func classify(_ error: Error) -> SpotifyAuthError {
        let ns = error as NSError
        let domain = ns.domain

        // ASWebAuthenticationSession user cancellation
        if domain == "com.apple.AuthenticationServices.WebAuthenticationSession", ns.code == 1 {
            return SpotifyAuthError(kind: .cancelled, code: "spotify_cancelled")
        }

        // Spotify iOS SDK — auth / login failures.
        //
        // `com.spotify.sdk.login code=1` is the SDK's catch-all "non-recoverable"
        // error. It fires for (a) genuine dev-mode allowlist rejections AND
        // (b) transient issues like the Spotify app being suspended,
        // `spotify-action://` URL schemes denied by iOS, or network blips
        // during the authorize redirect. Classifying all of them as dev-mode
        // is misleading — we'd tell allowlisted users "your account isn't on
        // the list" every time Spotify hiccups.
        //
        // Dev-mode errors carry a distinctive description phrase. Match on
        // that; otherwise fall through to a neutral "generic" message.
        if domain.hasPrefix("com.spotify") {
            let description = (ns.userInfo[NSLocalizedDescriptionKey] as? String)
                ?? ns.localizedDescription
            let lower = description.lowercased()
            let looksLikeDevMode = lower.contains("whitelist")
                || lower.contains("white list")
                || lower.contains("allowed users")
                || lower.contains("development mode")
                || lower.contains("not registered")
                || lower.contains("not on the user")
            if looksLikeDevMode {
                return SpotifyAuthError(kind: .devMode, code: "spotify_dev_mode")
            }
            return SpotifyAuthError(kind: .generic, code: "spotify_sdk_\(ns.code)")
        }

        // Network family
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                 .internationalRoamingOff, .dataNotAllowed:
                return SpotifyAuthError(kind: .network, code: "spotify_network")
            case .userCancelledAuthentication:
                return SpotifyAuthError(kind: .cancelled, code: "spotify_cancelled")
            default:
                break
            }
        }
        if domain == NSURLErrorDomain {
            return SpotifyAuthError(kind: .network, code: "spotify_network")
        }

        return SpotifyAuthError(kind: .generic, code: "spotify_generic")
    }
}
