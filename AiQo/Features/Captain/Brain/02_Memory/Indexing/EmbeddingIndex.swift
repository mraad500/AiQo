import Foundation
import NaturalLanguage

/// On-device embedding generator via Apple's `NLEmbedding`.
/// Never calls cloud. Never leaves the device.
public actor EmbeddingIndex {
    public static let shared = EmbeddingIndex()

    private let arabicEmbedding: NLEmbedding?
    private let englishEmbedding: NLEmbedding?
    private var cache: [String: [Double]] = [:]
    private let cacheLimit = 500

    private init() {
        self.arabicEmbedding = NLEmbedding.wordEmbedding(for: .arabic)
        self.englishEmbedding = NLEmbedding.wordEmbedding(for: .english)
    }

    /// Returns a normalized vector for the text, or `nil` if embedding is unavailable.
    /// Cached per exact (trimmed, lowercased) content string.
    public func embed(_ text: String) async -> [Double]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        if let cached = cache[trimmed] { return cached }

        let embedding = detectArabic(trimmed) ? arabicEmbedding : englishEmbedding
        guard let emb = embedding else { return nil }

        let words = trimmed.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)
        guard !words.isEmpty else { return nil }

        var sum = [Double](repeating: 0, count: emb.dimension)
        var count = 0
        for word in words {
            guard let vec = emb.vector(for: word) else { continue }
            for i in 0..<emb.dimension {
                sum[i] += vec[i]
            }
            count += 1
        }
        guard count > 0 else { return nil }

        let averaged = sum.map { $0 / Double(count) }
        let normalized = normalize(averaged)

        if cache.count >= cacheLimit, let randomKey = cache.keys.randomElement() {
            cache.removeValue(forKey: randomKey)
        }
        cache[trimmed] = normalized
        return normalized
    }

    /// Cosine similarity between two pre-normalized vectors. Returns -1 to 1.
    public nonisolated static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0
        for i in 0..<a.count { dot += a[i] * b[i] }
        return dot
    }

    private func detectArabic(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if (0x0600...0x06FF).contains(scalar.value) ||
               (0x0750...0x077F).contains(scalar.value) ||
               (0xFB50...0xFDFF).contains(scalar.value) ||
               (0xFE70...0xFEFF).contains(scalar.value) {
                return true
            }
        }
        return false
    }

    private func normalize(_ v: [Double]) -> [Double] {
        let magnitude = sqrt(v.map { $0 * $0 }.reduce(0, +))
        guard magnitude > 0 else { return v }
        return v.map { $0 / magnitude }
    }

    #if DEBUG
    public func _cacheSize() -> Int { cache.count }
    public func _clearCache() { cache.removeAll() }
    #endif
}
