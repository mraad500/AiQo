import Foundation

/// Handles saving and loading the blend queue to UserDefaults.
/// Only stores Spotify URIs and source tags — NEVER track names, artist names, or cover art.
enum BlendQueuePersistence {

    private static let key = "aiqo.blend.persistedQueue"

    // MARK: - Save

    /// Saves a blend queue after a successful build.
    static func save(_ tracks: [BlendTrackItem], currentIndex: Int = 0) {
        let sourceMap = Dictionary(
            tracks.map { ($0.uri, $0.source) },
            uniquingKeysWith: { _, last in last }
        )
        let persisted = PersistedBlendQueue(
            uris: tracks.map(\.uri),
            sourceMap: sourceMap,
            builtDate: Date(),
            currentIndex: currentIndex
        )

        guard let data = try? JSONEncoder().encode(persisted) else {
            PrivacySanitizer.log("BlendQueuePersistence: failed to encode queue.")
            return
        }

        UserDefaults.standard.set(data, forKey: key)
        PrivacySanitizer.log("BlendQueuePersistence: saved \(tracks.count) track URIs.")
    }

    // MARK: - Load

    /// Loads a persisted blend queue if it was built today.
    /// Returns `nil` if no queue exists or if the queue is from a different day.
    static func load() -> (tracks: [BlendTrackItem], currentIndex: Int)? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let persisted = try? JSONDecoder().decode(PersistedBlendQueue.self, from: data) else {
            return nil
        }

        // Only restore same-day queues
        guard Calendar.current.isDateInToday(persisted.builtDate) else {
            PrivacySanitizer.log("BlendQueuePersistence: stale queue from \(persisted.builtDate) — discarding.")
            clear()
            return nil
        }

        let tracks = persisted.uris.map { uri in
            BlendTrackItem(
                uri: uri,
                source: persisted.sourceMap[uri] ?? .user
            )
        }

        guard !tracks.isEmpty else {
            clear()
            return nil
        }

        // Clamp index to valid range
        let index = min(max(persisted.currentIndex, 0), tracks.count - 1)

        PrivacySanitizer.log("BlendQueuePersistence: restored \(tracks.count) tracks (index \(index)).")
        return (tracks, index)
    }

    // MARK: - Clear

    /// Clears the persisted queue (e.g. when user taps "مزيج جديد").
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        PrivacySanitizer.log("BlendQueuePersistence: cleared.")
    }
}
