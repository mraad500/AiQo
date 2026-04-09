import Foundation

struct SleepAnalysisQualityEvaluator: Sendable {
    func isUseful(message: String, session: SleepSession) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let sentenceCount = meaningfulSentenceCount(in: trimmed)
        let hasAction = containsAny(trimmed, keywords: actionKeywords)
        let hasImpact = containsAny(trimmed, keywords: impactKeywords)
        let hasMetricMention = containsMetricMention(in: trimmed, session: session)
        let isVeryShort = trimmed.count < 55

        if isVeryShort { return false }
        if sentenceCount < 2 { return false }
        if !hasAction { return false }
        if !hasMetricMention { return false }

        return hasImpact || sentenceCount >= 3
    }
}

private extension SleepAnalysisQualityEvaluator {
    var actionKeywords: [String] {
        [
            "حاول", "خل", "خفف", "وقف", "ثبت", "نام", "سوي", "سو", "ابعد", "قلل",
            "افصل", "اهدى", "sleep earlier", "reduce", "avoid", "try", "keep"
        ]
    }

    var impactKeywords: [String] {
        [
            "تعافي", "تركيز", "طاقة", "ذاكرة", "عضلات", "جسمك", "مزاج", "recovery", "focus", "energy", "memory"
        ]
    }

    func meaningfulSentenceCount(in text: String) -> Int {
        let separators = CharacterSet(charactersIn: ".!?\n،؛")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 12 }
            .count
    }

    func containsMetricMention(in text: String, session: SleepSession) -> Bool {
        if text.range(of: #"\d+"#, options: .regularExpression) != nil {
            return true
        }

        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        var keywords = ["ساعة", "ساعات", "دقيقة", "عميق", "rem", "ريم", "استيقاظ", "صحيت"]

        if session.deepMinutes > 0 {
            keywords.append("عميق")
        }
        if session.remMinutes > 0 {
            keywords.append(contentsOf: ["rem", "ريم"])
        }
        if session.awakeMinutes > 0 {
            keywords.append(contentsOf: ["استيقاظ", "صحيت"])
        }

        return containsAny(normalized, keywords: keywords)
    }

    func containsAny(_ text: String, keywords: [String]) -> Bool {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased()
        return keywords.contains { normalized.contains($0.lowercased()) }
    }
}
