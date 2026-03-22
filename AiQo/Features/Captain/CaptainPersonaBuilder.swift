import Foundation

/// مرجع واحد لشخصية الكابتن — يُستخدم في cloud + local + fallback
enum CaptainPersonaBuilder {

    // MARK: - Banned Phrases

    /// عبارات محظورة — إذا صدرت من الـ LLM تُمسح أو تُستبدل
    static let bannedPhrases = [
        "بالتأكيد",
        "بكل سرور",
        "كمساعد ذكاء اصطناعي",
        "لا أستطيع",
        "يسعدني مساعدتك",
        "هل يمكنني مساعدتك",
        "كيف يمكنني مساعدتك اليوم",
        "بصفتي نموذج لغوي",
        "As an AI",
        "I'm happy to help",
        "How can I assist you",
        "Certainly!",
        "Of course!",
        "I'd be happy to"
    ]

    /// Strips banned phrases from a Captain response
    static func sanitizeResponse(_ text: String) -> String {
        var result = text
        for phrase in bannedPhrases {
            result = result.replacingOccurrences(of: phrase, with: "")
        }
        // Collapse double spaces left behind
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Persona Prompt Fragment

    /// Banned-phrases directive to append to any system prompt
    static func bannedPhrasesDirective() -> String {
        let joined = bannedPhrases.map { "「\($0)」" }.joined(separator: ", ")
        return """
        === STRICTLY BANNED PHRASES ===
        You must NEVER use any of these phrases or close variants:
        \(joined)
        These are generic AI filler. Captain Hamoudi speaks like a real person, not a chatbot.
        """
    }

    /// Response length rules
    static func responseLengthRules() -> String {
        """
        === RESPONSE LENGTH RULES ===
        - Simple question → 2-3 sentences max
        - Workout/meal plan request → structured plan with clear bullet points
        - Emotional support → one warm sentence then a follow-up question
        - NEVER ramble without reason. Brevity is strength.
        - Max 3 actionable points per response. Never a list of 10.
        """
    }

    /// Full captain persona instructions combining all directives
    static func buildInstructions() -> String {
        """
        \(bannedPhrasesDirective())

        \(responseLengthRules())
        """
    }
}
