import Foundation
import UIKit

#if !targetEnvironment(simulator)
import SpotifyiOS

// MARK: - Hamoudi Blend Engine (In-Memory Queue, No Playlist Creation)

extension SpotifyVibeManager {

    /// Master playlist used for Hamoudi picks in the blend engine
    static let blendMasterPlaylistID = "14YVMyaZsefyZMgEIIicao"

    // MARK: - Blend Queue Build

    /// Builds an in-memory blend queue: 60% user top tracks, 40% Hamoudi master picks.
    /// Uses seeded Fisher-Yates so the order is stable per session but changes daily.
    /// Does NOT create any playlist in the user's Spotify account.
    func buildBlendQueue(userRatio: Double = 0.6, completion: @escaping (Result<[BlendTrackItem], Error>) -> Void) {
        guard let token = webAPIToken, !token.isEmpty else {
            log("No Web API token for blend queue — starting PKCE auth.")
            authorizeWebAPI()
            completion(.failure(NSError(domain: "BlendEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authorized"])))
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.isGeneratingBlend = true
            self?.blendError = nil
        }

        let group = DispatchGroup()
        var masterURIs: [String] = []
        var userURIs: [String] = []
        var fetchError: Error?

        group.enter()
        fetchTrackURIs(
            url: "https://api.spotify.com/v1/playlists/\(Self.blendMasterPlaylistID)/tracks?limit=50&fields=items(track(uri))",
            token: token
        ) { result in
            switch result {
            case .success(let uris): masterURIs = uris
            case .failure(let error): fetchError = error
            }
            group.leave()
        }

        group.enter()
        fetchTrackURIs(
            url: "https://api.spotify.com/v1/me/top/tracks?limit=10&time_range=short_term",
            token: token,
            isTopTracks: true
        ) { result in
            switch result {
            case .success(let uris): userURIs = uris
            case .failure(let error): fetchError = fetchError ?? error
            }
            group.leave()
        }

        group.notify(queue: .global(qos: .userInitiated)) { [weak self] in
            guard let self else { return }

            if userURIs.isEmpty && masterURIs.isEmpty {
                DispatchQueue.main.async {
                    self.isGeneratingBlend = false
                    self.blendError = fetchError?.localizedDescription ?? "No tracks available"
                }
                completion(.failure(fetchError ?? NSError(domain: "BlendEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "No tracks found"])))
                return
            }

            let effectiveUserRatio = userURIs.isEmpty ? 0.0 : userRatio
            let totalCount = min(20, masterURIs.count + userURIs.count)
            let userCount = min(userURIs.count, Int(round(Double(totalCount) * effectiveUserRatio)))
            let hamoudiCount = totalCount - userCount

            let hamoudiPicks = Array(masterURIs.shuffled().prefix(hamoudiCount))
            let userPicks = Array(userURIs.prefix(userCount))

            var queue: [BlendTrackItem] = []
            queue += userPicks.map { BlendTrackItem(uri: $0, source: .user) }
            queue += hamoudiPicks.map { BlendTrackItem(uri: $0, source: .hamoudi) }

            // Seeded Fisher-Yates: stable per day, changes daily
            let daySeed = Self.daySeed()
            queue = Self.seededShuffle(queue, seed: daySeed)

            DispatchQueue.main.async {
                self.isGeneratingBlend = false
                self.blendError = nil
            }

            self.log("Built blend queue: \(userPicks.count) user + \(hamoudiPicks.count) hamoudi = \(queue.count) total.")
            completion(.success(queue))
        }
    }

    /// Fetches only track URIs (no metadata stored).
    private func fetchTrackURIs(url urlString: String, token: String, isTopTracks: Bool = false, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "BlendEngine", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            if statusCode == 401 || statusCode == 403 {
                DispatchQueue.main.async { [weak self] in
                    self?.webAPIToken = nil
                    self?.isWebAPIAuthorized = false
                }
            }

            guard (200...299).contains(statusCode), let data else {
                completion(.failure(self?.spotifyAPIError(from: data, response: response, fallback: "Track URI fetch failed") ?? NSError(domain: "SpotifyAPI", code: statusCode, userInfo: nil)))
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let uris: [String]

                if isTopTracks {
                    let items = json?["items"] as? [[String: Any]] ?? []
                    uris = items.compactMap { $0["uri"] as? String }
                } else {
                    let items = json?["items"] as? [[String: Any]] ?? []
                    uris = items.compactMap { item in
                        (item["track"] as? [String: Any])?["uri"] as? String
                    }
                }

                completion(.success(uris))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Blend Playback via Spotify Connect

    /// Plays a blend queue through Spotify Connect.
    /// First track via play(), remaining via queue() with 0.3s delay between calls.
    func playBlendQueue(_ queue: [BlendTrackItem]) {
        guard appRemote.isConnected else {
            reportError("Connect Spotify before playing the blend.", code: "blend_not_connected")
            return
        }

        guard !queue.isEmpty else {
            reportError("Blend queue is empty.", code: "blend_empty")
            return
        }

        // Store the source lookup in memory only
        blendSourceLookup = [:]
        for track in queue {
            blendSourceLookup[track.uri] = track.source
        }
        currentBlendQueue = queue

        clearError()
        let firstURI = queue[0].uri

        appRemote.playerAPI?.play(firstURI, callback: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.reportError("Couldn't start blend playback: \(error.localizedDescription)", code: "blend_play_failed")
                return
            }

            self.wasStoppedManually = false
            self.setPausedState(false)
            self.setPlaybackState(.playing)
            self.setCurrentVibeTitle("Hamoudi+you+DJ 🎧")

            DispatchQueue.main.async {
                self.currentBlendSource = queue[0].source
            }

            // Queue remaining tracks with throttle (max 1 call/sec per Spotify TOS)
            let remaining = Array(queue.dropFirst())
            self.enqueueTracksThrottled(remaining, index: 0)

            self.log("Started blend playback with \(queue.count) tracks.")
        })
    }

    /// Enqueue tracks one at a time with 1-second delay between calls.
    private func enqueueTracksThrottled(_ tracks: [BlendTrackItem], index: Int) {
        guard index < tracks.count, appRemote.isConnected else { return }

        let track = tracks[index]
        appRemote.playerAPI?.enqueueTrackUri(track.uri, callback: { [weak self] _, error in
            guard let self else { return }

            if let error {
                self.log("Queue track failed at index \(index): \(error.localizedDescription)")
            }

            if index + 1 < tracks.count {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    self.enqueueTracksThrottled(tracks, index: index + 1)
                }
            }
        })
    }

    // MARK: - Source Tracking

    /// Maps the currently playing track URI to its BlendSourceTag.
    /// Called from playerStateDidChange to update the badge.
    func resolveBlendSource(for trackURI: String) -> BlendSourceTag? {
        blendSourceLookup[trackURI]
    }

    // MARK: - Async Fetch (Blend Engine)

    /// Fetches the user's top track URIs. Returns only URIs — no metadata.
    func fetchTopTrackURIs(limit: Int = 10) async throws -> [String] {
        guard let token = webAPIToken, !token.isEmpty else {
            throw BlendError.authExpired
        }

        let urlString = "https://api.spotify.com/v1/me/top/tracks?limit=\(limit)&time_range=short_term"
        guard let url = URL(string: urlString) else {
            throw BlendError.unknown("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if statusCode == 401 {
            DispatchQueue.main.async { [weak self] in
                self?.webAPIToken = nil
                self?.isWebAPIAuthorized = false
            }
            throw BlendError.authExpired
        }
        if statusCode == 429 { throw BlendError.rateLimited }
        guard (200...299).contains(statusCode) else {
            throw BlendError.unknown("HTTP \(statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]] ?? []
        let uris = items.compactMap { $0["uri"] as? String }

        PrivacySanitizer.log("Fetched \(uris.count) user top track URIs.")
        return uris
    }

    /// Fetches track URIs from a playlist. Returns only URIs — no metadata.
    func fetchMasterPlaylistURIs(playlistId: String) async throws -> [String] {
        guard let token = webAPIToken, !token.isEmpty else {
            throw BlendError.authExpired
        }

        let urlString = "https://api.spotify.com/v1/playlists/\(playlistId)/tracks?fields=items(track(uri))&limit=50"
        guard let url = URL(string: urlString) else {
            throw BlendError.unknown("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        if statusCode == 401 {
            DispatchQueue.main.async { [weak self] in
                self?.webAPIToken = nil
                self?.isWebAPIAuthorized = false
            }
            throw BlendError.authExpired
        }
        if statusCode == 403 {
            PrivacySanitizer.log("Master playlist 403 — playlist is private or inaccessible.")
            throw BlendError.noMasterTracks
        }
        if statusCode == 429 { throw BlendError.rateLimited }
        guard (200...299).contains(statusCode) else {
            throw BlendError.unknown("HTTP \(statusCode)")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = json?["items"] as? [[String: Any]] ?? []
        let uris = items.compactMap { item in
            (item["track"] as? [String: Any])?["uri"] as? String
        }

        PrivacySanitizer.log("Fetched \(uris.count) master playlist URIs.")
        return uris
    }

    // MARK: - Blend V2 Token Helper

    /// Tries the in-memory webAPIToken first, falls back to Keychain.
    /// This avoids failures from race conditions where the @Published
    /// property hasn't been set yet but the token exists in Keychain.
    private func getWebAPIToken() -> String? {
        if let token = webAPIToken, !token.isEmpty { return token }
        return KeychainStore.get("aiqo.spotify.webapi.token")
    }

    // MARK: - Blend V2 Fetch

    /// Fetch Hamoudi's playlist tracks via Web API (hardcoded public playlist).
    /// Automatically refreshes the token and retries once on 401.
    func fetchHamoudiPlaylistTracks() async throws -> [String] {
        let playlistId = "14YVMyaZsefyZMgEIIicao"

        for attempt in 0..<2 {
            guard let token = getWebAPIToken() else {
                throw BlendError.authExpired
            }

            var request = URLRequest(
                url: URL(string: "https://api.spotify.com/v1/playlists/\(playlistId)/tracks?limit=100&fields=items(track(uri))")!
            )
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 403 {
                    PrivacySanitizer.log("Aura Vibe: Hamoudi playlist fetch failed — check playlist is public (403)")
                    throw BlendError.noMasterTracks
                }
                if httpResponse.statusCode == 401 {
                    if attempt == 0 {
                        log("Hamoudi playlist fetch got 401 — attempting token refresh...")
                        try await refreshWebAPIToken()
                        continue
                    }
                    throw BlendError.authExpired
                }
            }

            struct TracksResponse: Decodable {
                struct Item: Decodable {
                    struct Track: Decodable { let uri: String }
                    let track: Track?
                }
                let items: [Item]
            }

            let decoded = try JSONDecoder().decode(TracksResponse.self, from: data)
            let uris = decoded.items.compactMap { $0.track?.uri }
            PrivacySanitizer.log("Aura Vibe: fetched \(uris.count) Hamoudi tracks")
            return uris
        }

        throw BlendError.authExpired
    }

    /// Fetch user's top tracks via Web API.
    /// Automatically refreshes the token and retries once on 401.
    func fetchUserTopTracks(limit: Int = 50) async throws -> [String] {
        for attempt in 0..<2 {
            guard let token = getWebAPIToken() else {
                throw BlendError.authExpired
            }

            var request = URLRequest(
                url: URL(string: "https://api.spotify.com/v1/me/top/tracks?limit=\(limit)&time_range=medium_term")!
            )
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                if attempt == 0 {
                    log("User top tracks fetch got 401 — attempting token refresh...")
                    try await refreshWebAPIToken()
                    continue
                }
                throw BlendError.authExpired
            }

            struct TopTracksResponse: Decodable {
                struct Track: Decodable { let uri: String }
                let items: [Track]
            }

            let decoded = try JSONDecoder().decode(TopTracksResponse.self, from: data)
            let uris = decoded.items.map { $0.uri }
            PrivacySanitizer.log("Aura Vibe: fetched \(uris.count) user top tracks")
            return uris
        }

        throw BlendError.authExpired
    }

    /// Enqueue a URI (after first track is playing).
    func enqueueTrack(uri: String) {
        guard isConnected, let playerAPI = appRemote.playerAPI else { return }
        playerAPI.enqueueTrackUri(uri, callback: { _, _ in })
    }

    // MARK: - Seeded Shuffle

    static func daySeed() -> UInt64 {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        let dayValue = UInt64(components.year ?? 2026) * 10000 + UInt64(components.month ?? 1) * 100 + UInt64(components.day ?? 1)
        return dayValue
    }

    static func seededShuffle<T>(_ array: [T], seed: UInt64) -> [T] {
        guard array.count > 1 else { return array }
        var result = array
        var rng = seed
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            // Simple LCG PRNG
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(rng >> 33) % (i + 1)
            if i != j {
                result.swapAt(i, j)
            }
        }
        return result
    }
}
#endif
