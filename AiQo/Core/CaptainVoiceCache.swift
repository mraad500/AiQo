import Foundation
import CryptoKit
import os.log

/// Common Iraqi Arabic phrases Captain Hamoudi uses frequently.
/// Pre-cached as ElevenLabs audio so they play instantly offline.
enum CachedPhrase: String, CaseIterable, Sendable {
    // Movement
    case getUp = "يلا قوم تحرّك شوية"
    case greatWorkout = "تمرين قوي، أحسنت يا بطل"
    case keepGoing = "كمّل كمّل لا توقف"
    case almostThere = "باقيلك شوية، لا تستسلم"

    // Water
    case drinkWater = "شربت ماي؟ يلا اشرب كوب"
    case waterGoalDone = "خلّصت هدف الماي، تمام"

    // Food
    case mealTimeBreakfast = "وقت الفطور، خل ناكل صحّي"
    case mealTimeLunch = "وقت الغداء"
    case mealTimeDinner = "وقت العشاء"

    // Sleep
    case sleepTime = "يلا نام بدري اليوم، جسمك يحتاج راحة"
    case goodMorning = "صباح الخير، يلا نبدأ يومنا"

    // Motivation
    case dailyMotivation = "كل يوم أحسن من اللي قبله، كمّل"
    case streakCongrats = "سلسلة قوية، لا تكطعها"

    nonisolated var cacheFileName: String {
        let key = CaptainVoiceCache.cacheKey(for: rawValue)
        return "hamoudi_\(key).mp3"
    }
}

/// Manages cached ElevenLabs audio for common Captain Hamoudi phrases.
/// Saves API calls, works offline, and provides zero-latency playback.
actor CaptainVoiceCache {
    static let shared = CaptainVoiceCache()

    private let cacheDirectory: URL
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "CaptainVoiceCache"
    )

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = docs.appendingPathComponent("HamoudiVoiceCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        Task { await clearStaleCache() }
    }

    // MARK: - Deterministic Cache Key

    /// Generates a deterministic SHA256-based cache key for the given text.
    /// This is `static` and `nonisolated` so `CachedPhrase.cacheFileName` can use it without `await`.
    nonisolated static func cacheKey(for text: String) -> String {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let data = normalized.data(using: .utf8) else {
            return UUID().uuidString
        }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Removes cache files that don't match the new SHA256 naming convention.
    /// SHA256 hex strings are 64 characters, so valid filenames are `hamoudi_<64 hex chars>.mp3`.
    private func clearStaleCache() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        let hexPattern = try? NSRegularExpression(pattern: "^hamoudi_[0-9a-f]{64}\\.mp3$")

        for fileURL in files {
            let fileName = fileURL.lastPathComponent
            let range = NSRange(fileName.startIndex..., in: fileName)
            let isValid = hexPattern?.firstMatch(in: fileName, range: range) != nil
            if !isValid {
                try? FileManager.default.removeItem(at: fileURL)
                logger.notice("stale_cache_removed file=\(fileName, privacy: .public)")
            }
        }
    }

    // MARK: - Query

    func isCached(_ phrase: CachedPhrase) -> Bool {
        FileManager.default.fileExists(atPath: cacheURL(for: phrase).path)
    }

    func audioData(for phrase: CachedPhrase) -> Data? {
        let url = cacheURL(for: phrase)
        return try? Data(contentsOf: url)
    }

    /// Returns cached audio for a response if the text matches a known phrase.
    func matchedAudio(for text: String) -> Data? {
        for phrase in CachedPhrase.allCases {
            if text.contains(phrase.rawValue), let data = audioData(for: phrase) {
                return data
            }
        }
        return nil
    }

    // MARK: - Store

    func store(audio: Data, for phrase: CachedPhrase) {
        let url = cacheURL(for: phrase)
        do {
            try audio.write(to: url)
        } catch {
            logger.error("voice_cache_store_failed phrase=\(phrase.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Pre-cache all phrases (call on WiFi after first login)

    func preCacheAllPhrases() async {
        guard await CaptainVoiceAPI.isConfigured else {
            logger.notice("voice_cache_skipped reason=api_not_configured")
            return
        }

        for phrase in CachedPhrase.allCases {
            guard !isCached(phrase) else { continue }

            do {
                let audioData = try await CaptainVoiceAPI.synthesizeSpeech(for: phrase.rawValue)
                store(audio: audioData, for: phrase)
                logger.notice("voice_cache_stored phrase=\(phrase.cacheFileName, privacy: .public)")
            } catch {
                logger.error("voice_cache_failed phrase=\(phrase.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            }

            // Rate limit protection
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    // MARK: - Cache management

    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    var cacheSizeBytes: Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    // MARK: - Helpers

    private func cacheURL(for phrase: CachedPhrase) -> URL {
        cacheDirectory.appendingPathComponent(phrase.cacheFileName)
    }
}
