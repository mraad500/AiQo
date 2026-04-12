import Foundation

/// Thread-safe blend engine that builds an in-memory track queue.
/// Never creates playlists in the user's Spotify account.
/// Never stores track names, artist names, or cover art.
actor BlendEngine {

    // MARK: - Build

    func build(
        userTopURIs: [String],
        masterURIs: [String],
        config: BlendConfiguration
    ) throws -> [BlendTrackItem] {
        guard !masterURIs.isEmpty || !userTopURIs.isEmpty else {
            throw BlendError.noMasterTracks
        }

        let userCount = min(
            userTopURIs.count,
            Int(round(Double(config.totalTracks) * config.userShare))
        )
        let hamoudiCount = config.totalTracks - userCount

        let daySeed = Self.daySeed()

        // Pick hamoudi tracks using seeded shuffle for daily stability
        let shuffledMaster = Self.seededShuffle(masterURIs, seed: daySeed)
        let hamoudiPicks = Array(shuffledMaster.prefix(hamoudiCount))
        let userPicks = Array(userTopURIs.prefix(userCount))

        var queue: [BlendTrackItem] = []
        queue += userPicks.map { BlendTrackItem(uri: $0, source: .user) }
        queue += hamoudiPicks.map { BlendTrackItem(uri: $0, source: .hamoudi) }

        // Seeded Fisher-Yates for daily-stable interleaving
        queue = Self.seededShuffle(queue, seed: daySeed)

        return queue
    }

    // MARK: - Seeded Shuffle (LCG-based)

    private static func daySeed() -> Int {
        Int(Date().timeIntervalSince1970 / 86400)
    }

    static func seededShuffle<T>(_ array: [T], seed: Int) -> [T] {
        guard array.count > 1 else { return array }
        var result = array
        var rng = UInt64(bitPattern: Int64(seed))
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(rng >> 33) % (i + 1)
            if i != j {
                result.swapAt(i, j)
            }
        }
        return result
    }
}
