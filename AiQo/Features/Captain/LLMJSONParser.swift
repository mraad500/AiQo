import Foundation

/// Robust JSON parser for LLM responses.
///
/// Handles common LLM output issues:
/// - Strips markdown code fences (```json ... ```)
/// - Extracts balanced JSON objects from mixed text
/// - Normalizes smart quotes and null bytes
/// - Removes trailing commas before } or ]
/// - Falls back gracefully if JSON decode fails
struct LLMJSONParser: Sendable {
    private struct CaptainResponse: Decodable {
        let message: String
    }

    // MARK: - Public API

    func decode(_ rawText: String, fallback: CaptainStructuredResponse) -> CaptainStructuredResponse {
        decode(rawText: rawText, fallback: fallback)
    }

    func decode(rawText: String, fallback: CaptainStructuredResponse) -> CaptainStructuredResponse {
        parsedStructuredResponse(from: rawText) ?? plainTextResponse(from: rawText) ?? fallback
    }

    func cleanDisplayText(from rawText: String, fallback: String) -> String {
        let fallbackResponse = CaptainStructuredResponse(message: fallback)
        return decode(rawText: rawText, fallback: fallbackResponse).message
    }

    // MARK: - Streaming Support

    func appendStreamingToken(_ token: String, into rawText: inout String) -> String {
        rawText.append(token)
        return currentMessagePreview(from: rawText)
    }

    func currentMessagePreview(from rawText: String) -> String {
        let normalized = normalize(rawText)

        guard let messageStart = normalized.range(
            of: #""message"\s*:\s*""#,
            options: .regularExpression
        ) else { return "" }

        let tail = normalized[messageStart.upperBound...]
        return unescapedJSONStringPrefix(from: String(tail))
    }

    func hasCompleteJSONObject(in rawText: String) -> Bool {
        balancedJSONObject(in: normalize(rawText)) != nil
    }

    func decodeCompletedStream(
        _ rawText: String,
        fallback: CaptainStructuredResponse
    ) -> CaptainStructuredResponse {
        decode(rawText: rawText, fallback: fallback)
    }

    func accumulate(_ stream: AsyncStream<String>) async -> String {
        var rawText = ""
        for await token in stream {
            rawText.append(token)
        }
        return rawText
    }
}

// MARK: - Private Implementation

private extension LLMJSONParser {

    func parsedStructuredResponse(from rawText: String) -> CaptainStructuredResponse? {
        let sources = expandedSources(from: rawText)

        for candidate in jsonCandidates(from: sources) {
            if let decoded = decodeCandidate(candidate) {
                return decoded
            }
            if let recovered = recoverCandidate(candidate) {
                return recovered
            }
        }

        for source in sources {
            if let message = recoveredMessage(from: source) {
                return CaptainStructuredResponse(message: message)
            }
        }

        return nil
    }

    func plainTextResponse(from rawText: String) -> CaptainStructuredResponse? {
        let cleaned = stripMarkdownCodeFences(from: normalize(rawText))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, !looksLikeStructuredPayload(cleaned) else { return nil }
        return CaptainStructuredResponse(message: cleaned)
    }

    /// Generates candidate JSON strings in priority order
    func jsonCandidates(from sources: [String]) -> [String] {
        var seen = Set<String>()
        var candidates: [String] = []

        for source in sources {
            candidates.append(source)

            let unfenced = stripMarkdownCodeFences(from: source)
            if unfenced != source {
                candidates.append(unfenced)
            }

            if let fencedJSON = firstCapture(
                using: #"```(?:json)?\s*([\s\S]*?)\s*```"#,
                in: source
            ) {
                candidates.append(fencedJSON)
            }

            candidates.append(contentsOf: matches(using: #"\{[\s\S]*\}"#, in: source))

            if let balanced = balancedJSONObject(in: source) {
                candidates.append(balanced)
            }
        }

        return candidates.compactMap { candidate in
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    func expandedSources(from rawText: String) -> [String] {
        var seen = Set<String>()
        var sources: [String] = []

        func append(_ text: String?) {
            guard let text else { return }
            let normalized = normalize(text)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return }
            sources.append(normalized)
        }

        append(rawText)

        if let unwrapped = unwrapJSONStringLiteral(from: rawText) {
            append(unwrapped)
            append(stripMarkdownCodeFences(from: unwrapped))

            if let doubleUnwrapped = unwrapJSONStringLiteral(from: unwrapped) {
                append(doubleUnwrapped)
                append(stripMarkdownCodeFences(from: doubleUnwrapped))
            }
        }

        return sources
    }

    /// Normalizes smart quotes, null bytes, and whitespace
    func normalize(_ rawText: String) -> String {
        rawText
            .replacingOccurrences(of: "\u{0000}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{201C}", with: "\"") // "
            .replacingOccurrences(of: "\u{201D}", with: "\"") // "
            .replacingOccurrences(of: "\u{2018}", with: "'")  // '
            .replacingOccurrences(of: "\u{2019}", with: "'")  // '
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func stripMarkdownCodeFences(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```"), trimmed.hasSuffix("```") else { return trimmed }

        var lines = trimmed.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return trimmed }

        let openingFence = lines.removeFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        guard openingFence.hasPrefix("```") else { return trimmed }

        if let lastIndex = lines.lastIndex(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == "```"
        }) {
            lines.remove(at: lastIndex)
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func unwrapJSONStringLiteral(from text: String) -> String? {
        let normalized = normalize(text)
        guard let data = normalized.data(using: .utf8),
              let unwrapped = try? JSONDecoder().decode(String.self, from: data) else {
            return nil
        }

        let cleaned = normalize(unwrapped)
        return cleaned == normalized ? nil : cleaned
    }

    func looksLikeStructuredPayload(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.first == "{" || trimmed.first == "[" {
            return true
        }

        return trimmed.contains("\"message\"")
            || trimmed.contains("```json")
            || trimmed.contains("```JSON")
    }

    /// Attempts strict Codable decode
    func decodeCandidate(_ candidate: String) -> CaptainStructuredResponse? {
        guard let data = sanitizedJSONData(from: candidate) else { return nil }
        let decoder = JSONDecoder()

        if let structured = try? decoder.decode(CaptainStructuredResponse.self, from: data) {
            return structured
        }

        guard let envelope = try? decoder.decode(CaptainResponse.self, from: data) else {
            return nil
        }

        return CaptainStructuredResponse(message: envelope.message)
    }

    /// Partial recovery: extract known fields from a JSON object
    func recoverCandidate(_ candidate: String) -> CaptainStructuredResponse? {
        guard let data = sanitizedJSONData(from: candidate),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let message = normalizedMessage(from: object["message"]) else { return nil }
        let workoutPlan = decodePlan(WorkoutPlan.self, from: object["workoutPlan"])
        let mealPlan = decodePlan(MealPlan.self, from: object["mealPlan"])
        let spotifyRecommendation = decodePlan(SpotifyRecommendation.self, from: object["spotifyRecommendation"])
        let quickReplies = decodeQuickReplies(from: object["quickReplies"])

        return CaptainStructuredResponse(
            message: message,
            quickReplies: quickReplies,
            workoutPlan: workoutPlan,
            mealPlan: mealPlan,
            spotifyRecommendation: spotifyRecommendation
        )
    }

    /// Removes trailing commas before } or ] to fix common LLM JSON errors
    func sanitizedJSONData(from candidate: String) -> Data? {
        let cleaned = candidate.replacingOccurrences(
            of: #",(\s*[}\]])"#,
            with: "$1",
            options: .regularExpression
        )
        return cleaned.data(using: .utf8)
    }

    func normalizedMessage(from value: Any?) -> String? {
        guard let rawMessage = value as? String else { return nil }
        let normalized = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    func decodeQuickReplies(from value: Any?) -> [String]? {
        guard let values = value as? [Any] else { return nil }
        let normalized = values
            .compactMap { $0 as? String }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return normalized.isEmpty ? nil : normalized
    }

    func decodePlan<T: Decodable>(_ type: T.Type, from value: Any?) -> T? {
        guard let value, !(value is NSNull),
              JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func recoveredMessage(from text: String) -> String? {
        let preview = currentMessagePreview(from: text)
        if !preview.isEmpty {
            return preview
        }

        let patterns = [
            #""message"\s*:\s*"((?:\\.|[^"\\])*)""#,
            #"\\\"message\\\"\s*:\s*\\\"((?:\\\\.|[^"\\])*)\\\""#,
        ]

        for pattern in patterns {
            guard let capture = firstCapture(using: pattern, in: text),
                  let message = decodeJSONStringFragment(capture) else {
                continue
            }

            let normalized = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                return normalized
            }
        }

        return nil
    }

    func decodeJSONStringFragment(_ value: String) -> String? {
        let sanitized = value
            .replacingOccurrences(of: "\\\\\"", with: "\\\"")
            .replacingOccurrences(of: "\\\\n", with: "\\n")
            .replacingOccurrences(of: "\\\\t", with: "\\t")

        guard let data = "\"\(sanitized)\"".data(using: .utf8),
              let decoded = try? JSONDecoder().decode(String.self, from: data) else {
            return nil
        }

        return decoded
    }

    // MARK: - Balanced JSON Object Extraction

    /// Extracts the first balanced { ... } object from text
    func balancedJSONObject(in text: String) -> String? {
        var startIndex: String.Index?
        var depth = 0
        var isInsideString = false
        var isEscaping = false

        for index in text.indices {
            let character = text[index]

            if isInsideString {
                if isEscaping {
                    isEscaping = false
                    continue
                }

                if character == "\\" {
                    isEscaping = true
                    continue
                }

                if character == "\"" {
                    isInsideString = false
                }
                continue
            }

            if character == "\"" {
                isInsideString = true
                continue
            }

            if character == "{" {
                if depth == 0 { startIndex = index }
                depth += 1
            } else if character == "}" {
                guard depth > 0 else { continue }
                depth -= 1
                if depth == 0, let startIndex {
                    return String(text[startIndex...index])
                }
            }
        }

        return nil
    }

    // MARK: - Streaming JSON String Extraction

    func unescapedJSONStringPrefix(from value: String) -> String {
        var result = ""
        var isEscaping = false

        for character in value {
            if isEscaping {
                switch character {
                case "n":  result.append("\n")
                case "t":  result.append("\t")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default:   result.append(character)
                }
                isEscaping = false
                continue
            }

            if character == "\\" { isEscaping = true; continue }
            if character == "\"" { break }

            result.append(character)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Regex Helpers

    func firstCapture(using pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    func matches(using pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }
}
