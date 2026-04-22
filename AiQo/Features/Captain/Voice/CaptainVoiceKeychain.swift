import Foundation
import Security

/// Keychain-backed storage for the MiniMax API key used by the cloud voice
/// provider. The key is written once via `setMiniMaxAPIKey(_:)` (typically
/// from a build-time setup step or a debug-only settings surface), retrieved
/// at runtime in `MiniMaxTTSProvider`, and wiped on logout via
/// `deleteMiniMaxAPIKey()`.
///
/// Security posture:
/// - `kSecAttrAccessibleAfterFirstUnlock` — survives reboots but requires
///   the device to have been unlocked at least once since boot. This
///   matches the app's threat model: we need the key available in
///   background refresh scenarios, not while locked.
/// - Never logged. When the key is supplied at build time it is copied
///   into the Keychain on first use so later reads can come from a single
///   runtime store.
enum CaptainVoiceKeychain {
    private static let service = "com.mraad500.aiqo.voice"
    private static let account = "com.mraad500.aiqo.minimax.apikey"

    /// Returns the stored MiniMax API key, or `nil` if none is stored or the
    /// Keychain query fails. `MiniMaxTTSProvider` treats `nil` as a
    /// configuration error and falls back silently to Apple TTS.
    static func miniMaxAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else {
            return nil
        }
        return key
    }

    /// Persist a new API key, replacing any previous value.
    static func setMiniMaxAPIKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }

        // Replace-if-exists: delete first so a fresh `SecItemAdd` cannot
        // collide with an existing record.
        deleteMiniMaxAPIKey()

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    /// Remove the stored key. Called on logout flows that want to clear
    /// cached voice credentials from the device.
    static func deleteMiniMaxAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
