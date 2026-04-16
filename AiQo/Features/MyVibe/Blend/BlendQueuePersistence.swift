import Foundation

/// Handles saving and loading the blend queue to UserDefaults.
/// Only stores Spotify URIs and source tags — NEVER track names, artist names, or cover art.
enum BlendQueuePersistence {

    private static let key = "aiqo.blend.queue.v2"

    // MARK: - Save

    static func save(_ queue: [BlendTrackItem]) {
        let uris = queue.map { $0.uri }
        let sourceMap = Dictionary(
            uniqueKeysWithValues: queue.map {
                ($0.uri, $0.source == .user ? "user" : "hamoudi")
            }
        )
        let persisted = PersistedBlendQueue(
            uris: uris,
            sourceMap: sourceMap,
            builtDate: Date().timeIntervalSince1970
        )
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: key)
            PrivacySanitizer.log("BlendQueuePersistence: saved \(uris.count) track URIs.")
        }
    }

    // MARK: - Load

    static func load() -> [BlendTrackItem]? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let persisted = try? JSONDecoder().decode(PersistedBlendQueue.self, from: data)
        else { return nil }

        // Only use same-day queue
        let builtDate = Date(timeIntervalSince1970: persisted.builtDate)
        guard Calendar.current.isDateInToday(builtDate) else {
            PrivacySanitizer.log("BlendQueuePersistence: stale queue — discarding.")
            clear()
            return nil
        }

        let tracks = persisted.uris.map { uri in
            let source: BlendSourceTag = persisted.sourceMap[uri] == "user" ? .user : .hamoudi
            return BlendTrackItem(uri: uri, source: source)
        }

        guard !tracks.isEmpty else {
            clear()
            return nil
        }

        PrivacySanitizer.log("BlendQueuePersistence: restored \(tracks.count) tracks.")
        return tracks
    }

    // MARK: - Clear

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        PrivacySanitizer.log("BlendQueuePersistence: cleared.")
    }
}
