import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Pulls `SemanticFact` candidates from a conversation turn.
/// On-device only. Never touches cloud.
actor FactExtractor {
    static let shared = FactExtractor()

    private init() {}

    struct CandidateFact: Sendable {
        let content: String
        let category: FactCategory
        let confidence: Double
        let sensitive: Bool
    }

    /// Extract up to `maxFacts` from a conversation exchange.
    /// If Foundation Models unavailable, falls back to heuristic regex extraction.
    func extract(
        userMessage: String,
        captainResponse: String = "",
        maxFacts: Int = 5
    ) async -> [CandidateFact] {
        let trimmed = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let heuristic = heuristicExtract(from: userMessage)
        if heuristic.count >= maxFacts {
            return Array(heuristic.prefix(maxFacts))
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let llmResults = await llmExtract(from: userMessage, maxFacts: maxFacts) {
                return dedupeMerge(heuristic: heuristic, llm: llmResults, limit: maxFacts)
            }
        }
        #endif

        return Array(heuristic.prefix(maxFacts))
    }

    // MARK: - Heuristic fallback

    private struct HeuristicMarker {
        let prefix: String
        let category: FactCategory
    }

    private static let markers: [HeuristicMarker] = [
        HeuristicMarker(prefix: "my name is ", category: .other),
        HeuristicMarker(prefix: "i am ", category: .other),
        HeuristicMarker(prefix: "i'm ", category: .other),
        HeuristicMarker(prefix: "اسمي ", category: .other),
        HeuristicMarker(prefix: "أنا ", category: .other),
        HeuristicMarker(prefix: "i love ", category: .preference),
        HeuristicMarker(prefix: "i like ", category: .preference),
        HeuristicMarker(prefix: "i prefer ", category: .preference),
        HeuristicMarker(prefix: "أحب ", category: .preference),
        HeuristicMarker(prefix: "أفضل ", category: .preference),
        HeuristicMarker(prefix: "i want to ", category: .goal),
        HeuristicMarker(prefix: "my goal is ", category: .goal),
        HeuristicMarker(prefix: "هدفي ", category: .goal),
        HeuristicMarker(prefix: "أبي ", category: .goal),
        HeuristicMarker(prefix: "i don't ", category: .other),
        HeuristicMarker(prefix: "i can't ", category: .other),
        HeuristicMarker(prefix: "i have ", category: .health),
        HeuristicMarker(prefix: "ما أحب ", category: .preference),
        HeuristicMarker(prefix: "ما أقدر ", category: .other),
        HeuristicMarker(prefix: "عندي ", category: .health)
    ]

    private static let sensitiveKeywords = [
        "pain", "depression", "anxiety", "medication", "trauma", "grief",
        "ألم", "اكتئاب", "قلق", "دواء", "حزن"
    ]

    private func heuristicExtract(from text: String) -> [CandidateFact] {
        let lower = text.lowercased()
        var results: [CandidateFact] = []
        var seenPrefixes = Set<String>()

        for marker in Self.markers {
            guard let range = lower.range(of: marker.prefix) else { continue }
            let key = marker.prefix.trimmingCharacters(in: .whitespaces)
            guard seenPrefixes.insert(key).inserted else { continue }

            let startIdx = range.upperBound
            let remaining = String(lower[startIdx...])
            let snippet = remaining.split(separator: ".").first.map(String.init) ?? remaining
            let cleaned = String(snippet.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count >= 2 else { continue }

            let content = "\(key) \(cleaned)"
            results.append(.init(
                content: content,
                category: marker.category,
                confidence: 0.6,
                sensitive: containsSensitive(cleaned)
            ))
        }
        return results
    }

    private func containsSensitive(_ text: String) -> Bool {
        let lower = text.lowercased()
        return Self.sensitiveKeywords.contains(where: { lower.contains($0) })
    }

    // MARK: - On-device LLM

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func llmExtract(from text: String, maxFacts: Int) async -> [CandidateFact]? {
        guard SystemLanguageModel.default.availability == .available else { return nil }

        let instructions = """
        You extract atomic, memorable facts from a user message.
        For each fact, output one line: CATEGORY|CONFIDENCE|FACT
        Categories: health, preference, goal, relationship, work, habit, aspiration, fear, accomplishment, other.
        Confidence is 0.1 to 1.0. Output up to \(maxFacts) lines. No other text.
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: text)
            return parseLLMResponse(response.content)
        } catch {
            diag.warning("FactExtractor LLM failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func parseLLMResponse(_ text: String) -> [CandidateFact] {
        var facts: [CandidateFact] = []
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3 else { continue }

            let rawCategory = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let rawConfidence = parts[1].trimmingCharacters(in: .whitespaces)
            let content = parts[2].trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty else { continue }

            let category = FactCategory(rawValue: rawCategory) ?? .other
            let confidence = max(0.1, min(1.0, Double(rawConfidence) ?? 0.5))
            facts.append(.init(
                content: content,
                category: category,
                confidence: confidence,
                sensitive: containsSensitive(content)
            ))
        }
        return facts
    }
    #endif

    // MARK: - Dedupe

    private func dedupeMerge(
        heuristic: [CandidateFact],
        llm: [CandidateFact],
        limit: Int
    ) -> [CandidateFact] {
        var seen = Set<String>()
        var result: [CandidateFact] = []
        for fact in heuristic + llm {
            let key = String(fact.content.prefix(30)).lowercased()
            if seen.insert(key).inserted {
                result.append(fact)
                if result.count >= limit { break }
            }
        }
        return result
    }
}
