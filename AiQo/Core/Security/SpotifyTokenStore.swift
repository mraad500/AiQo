import Foundation
import Security

struct SpotifyToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

enum SpotifyTokenStore {
    private static let service = "com.mraad500.aiqo.spotify"
    private static let account = "webapi"
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlock

    static func save(_ token: SpotifyToken) {
        guard let data = try? JSONEncoder().encode(token) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = accessibility
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load() -> SpotifyToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = try? JSONDecoder().decode(SpotifyToken.self, from: data) else {
            return nil
        }
        return token
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
