import Foundation

// MARK: - Blend Source

enum BlendSourceTag: String, Codable, Equatable {
    case user
    case hamoudi
}

// MARK: - Blend Track (URI only — no metadata stored)

struct BlendTrackItem: Identifiable, Equatable {
    let id = UUID()
    let uri: String
    let source: BlendSourceTag
}

// MARK: - Blend Error

enum BlendError: LocalizedError, Equatable {
    case spotifyAppNotInstalled
    case requiresPremium
    case authExpired
    case noUserTracks
    case noMasterTracks
    case networkUnavailable
    case rateLimited
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .spotifyAppNotInstalled: return NSLocalizedString("blend.error.no_spotify_app", comment: "")
        case .requiresPremium:        return NSLocalizedString("blend.error.requires_premium", comment: "")
        case .authExpired:            return NSLocalizedString("blend.error.auth_expired", comment: "")
        case .noUserTracks:           return NSLocalizedString("blend.error.no_user_tracks", comment: "")
        case .noMasterTracks:         return NSLocalizedString("blend.error.no_master_tracks", comment: "")
        case .networkUnavailable:     return NSLocalizedString("blend.error.no_network", comment: "")
        case .rateLimited:            return NSLocalizedString("blend.error.rate_limited", comment: "")
        case .unknown(let msg):       return msg
        }
    }
}

// MARK: - Persisted Blend Queue (URIs + source only — no metadata)

struct PersistedBlendQueue: Codable {
    let uris: [String]
    let sourceMap: [String: String] // uri → "user" or "hamoudi"
    let builtDate: TimeInterval     // Date().timeIntervalSince1970
}

// MARK: - Blend Configuration

struct BlendConfiguration: Sendable {
    let userShare: Double
    let totalTracks: Int
    let masterPlaylistId: String

    static let `default` = BlendConfiguration(
        userShare: 0.6,
        totalTracks: 10,
        masterPlaylistId: "14YVMyaZsefyZMgEIIicao"
    )
}
