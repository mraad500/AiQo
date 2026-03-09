import Foundation

struct LLMJSONParser: Sendable {
    func decode(_ rawText: String, fallback: CaptainStructuredResponse) -> CaptainStructuredResponse {
        decode(rawText: rawText, fallback: fallback)
    }

    func decode(rawText: String, fallback: CaptainStructuredResponse) -> CaptainStructuredResponse {
        for candidate in jsonCandidates(from: rawText) {
            if let decoded = decodeCandidate(candidate) {
                return decoded
            }

            if let recovered = recoverCandidate(candidate, fallback: fallback) {
                return recovered
            }
        }

        return fallback
    }

    func appendStreamingToken(
        _ token: String,
        into rawText: inout String
    ) -> String {
        rawText.append(token)
        return currentMessagePreview(from: rawText)
    }

    func currentMessagePreview(from rawText: String) -> String {
        let normalized = normalize(rawText)

        guard let messageStart = normalized.range(
            of: #""message"\s*:\s*""#,
            options: .regularExpression
        ) else {
            return ""
        }

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

private extension LLMJSONParser {
    func jsonCandidates(from rawText: String) -> [String] {
        let normalized = normalize(rawText)
        var candidates = [normalized]

        if let fencedJSON = firstCapture(
            using: #"```(?:json)?\s*([\s\S]*?)\s*```"#,
            in: normalized
        ) {
            candidates.append(fencedJSON)
        }

        candidates.append(contentsOf: matches(using: #"\{[\s\S]*\}"#, in: normalized))

        if let balancedObject = balancedJSONObject(in: normalized) {
            candidates.append(balancedObject)
        }

        var seen = Set<String>()
        return candidates.compactMap { candidate in
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { return nil }
            return trimmed
        }
    }

    func normalize(_ rawText: String) -> String {
        rawText
            .replacingOccurrences(of: "\u{0000}", with: "")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func decodeCandidate(_ candidate: String) -> CaptainStructuredResponse? {
        guard let data = sanitizedJSONData(from: candidate) else { return nil }
        return try? JSONDecoder().decode(CaptainStructuredResponse.self, from: data)
    }

    func recoverCandidate(
        _ candidate: String,
        fallback: CaptainStructuredResponse
    ) -> CaptainStructuredResponse? {
        guard let data = sanitizedJSONData(from: candidate),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let message = normalizedMessage(from: object["message"]) ?? fallback.message
        let workoutPlan = decodePlan(WorkoutPlan.self, from: object["workoutPlan"])
        let mealPlan = decodePlan(MealPlan.self, from: object["mealPlan"])

        return CaptainStructuredResponse(
            message: message,
            workoutPlan: workoutPlan,
            mealPlan: mealPlan
        )
    }

    func sanitizedJSONData(from candidate: String) -> Data? {
        let cleaned = candidate
            .replacingOccurrences(
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

    func decodePlan<T: Decodable>(_ type: T.Type, from value: Any?) -> T? {
        guard let value, !(value is NSNull),
              JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: data)
    }

    func unescapedJSONStringPrefix(from value: String) -> String {
        var result = ""
        var isEscaping = false

        for character in value {
            if isEscaping {
                switch character {
                case "n":
                    result.append("\n")
                case "t":
                    result.append("\t")
                case "\"":
                    result.append("\"")
                case "\\":
                    result.append("\\")
                default:
                    result.append(character)
                }
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                continue
            }

            if character == "\"" {
                break
            }

            result.append(character)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func firstCapture(using pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[captureRange])
    }

    func matches(using pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    func balancedJSONObject(in text: String) -> String? {
        var startIndex: String.Index?
        var depth = 0

        for index in text.indices {
            let character = text[index]

            if character == "{" {
                if depth == 0 {
                    startIndex = index
                }
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
}
