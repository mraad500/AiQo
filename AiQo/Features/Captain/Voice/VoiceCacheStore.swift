import CryptoKit
import Foundation

/// On-device cache for MiniMax-synthesized MP3 audio. Keyed by a stable
/// SHA256 digest of `voiceID + model + text` so the same utterance under
/// the same voice/model configuration never hits the network twice.
///
/// Capacity bounds — whichever trips first wins eviction:
/// - `maxFileCount = 500` — protects against pathological fill from
///   many-short-phrases workloads (e.g. Zone 2 coaching catch-all if we
///   ever route it through this tier).
/// - `maxBytes = 100 MB` — protects against few-long-phrases workloads.
///
/// Eviction strategy: LRU by file modification date. `lookup(key:)`
/// touches the `.modificationDate` attribute on a hit so recently-played
/// audio moves to the front.
///
/// File protection: every cached file is written with
/// `.completeFileProtectionUntilFirstUserAuthentication` so it stays
/// encrypted at rest until the device is unlocked at least once after
/// a reboot. Matches the protection level of the MiniMax API key in
/// Keychain.
///
/// Threading: `actor` keeps file-manager access serialized without an
/// explicit queue. Callers `await` every operation; only `wipeAll()`
/// is guaranteed idempotent.
actor VoiceCacheStore {
    static let shared = VoiceCacheStore()

    /// Default capacity bounds. Overridable via init for tests.
    let maxFileCount: Int
    let maxBytes: Int

    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let fileExtension: String

    init(
        fileManager: FileManager = .default,
        cacheDirectory: URL? = nil,
        maxFileCount: Int = 500,
        maxBytes: Int = 100 * 1024 * 1024,
        fileExtension: String = "mp3"
    ) {
        self.fileManager = fileManager
        self.maxFileCount = maxFileCount
        self.maxBytes = maxBytes
        self.fileExtension = fileExtension

        let resolved: URL
        if let provided = cacheDirectory {
            resolved = provided
        } else {
            let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            resolved = base.appendingPathComponent("AiQo/VoiceCache", isDirectory: true)
        }
        self.cacheDirectory = resolved
        try? fileManager.createDirectory(at: resolved, withIntermediateDirectories: true)
    }

    /// Stable SHA256-based key for cache lookups. First 32 hex chars of
    /// the digest — collision-safe for the request volume we expect
    /// (hundreds per user per month), and short enough to keep file
    /// paths readable for debugging.
    ///
    /// Pipe separator between fields prevents `voiceID=foo, model=bartext` from
    /// colliding with `voiceID=foobar, model=text`.
    static func cacheKey(voiceID: String, model: String, text: String) -> String {
        let composite = "\(voiceID)|\(model)|\(text)"
        let digest = SHA256.hash(data: Data(composite.utf8))
        let fullHex = digest.map { String(format: "%02x", $0) }.joined()
        return String(fullHex.prefix(32))
    }

    /// Return the URL of a cached audio file for `key` if one exists, `nil`
    /// otherwise. Touches the file's modification date on hit so LRU
    /// eviction keeps recently-used audio around.
    func lookup(key: String) -> URL? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        // Promote to MRU by refreshing the modification date. Non-fatal
        // if the attribute write fails — we still return the URL.
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: url.path
        )
        return url
    }

    /// Write `data` to the cache under `key` and return the resulting
    /// file URL. Atomic write + `.completeFileProtectionUntilFirstUserAuthentication`.
    /// Throws any underlying `FileManager` / `Data.write` error so the
    /// caller can surface configuration problems (full disk, sandbox
    /// misalignment) rather than silently skipping the cache.
    @discardableResult
    func store(key: String, data: Data) throws -> URL {
        let url = fileURL(for: key)
        try data.write(
            to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        return url
    }

    /// Prune the cache until it fits within `maxFileCount` and `maxBytes`.
    /// Sorts entries by modification date ascending so the oldest get
    /// evicted first.
    func evict() {
        guard let entries = sortedEntriesOldestFirst() else { return }

        var survivors = entries
        var totalSize = survivors.reduce(0) { $0 + $1.size }

        while survivors.count > maxFileCount || totalSize > maxBytes {
            guard let oldest = survivors.first else { break }
            try? fileManager.removeItem(at: oldest.url)
            totalSize -= oldest.size
            survivors.removeFirst()
        }
    }

    /// Remove every cached file. Called from `CaptainVoiceConsent.revoke()`
    /// and from the logout hook in `AppFlowController.logout()`.
    func wipeAll() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Test/inspection helper. Returns the current number of cached files.
    func fileCount() -> Int {
        (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil))?.count ?? 0
    }

    /// Test/inspection helper. Returns the current total byte size.
    func totalBytes() -> Int {
        sortedEntriesOldestFirst()?.reduce(0) { $0 + $1.size } ?? 0
    }

    // MARK: - Private

    private func fileURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).\(fileExtension)")
    }

    private struct Entry {
        let url: URL
        let modifiedAt: Date
        let size: Int
    }

    private func sortedEntriesOldestFirst() -> [Entry]? {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let entries: [Entry] = contents.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return Entry(
                url: url,
                modifiedAt: values?.contentModificationDate ?? .distantPast,
                size: values?.fileSize ?? 0
            )
        }
        return entries.sorted { $0.modifiedAt < $1.modifiedAt }
    }
}
