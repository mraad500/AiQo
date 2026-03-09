import Foundation

struct PrivacySanitizer: Sendable {
    private let redactionToken = "[REDACTED]"

    func sanitizeForCloud(
        _ request: HybridBrainRequest,
        knownUserName: String?
    ) -> HybridBrainRequest {
        let sanitizedConversation = Array(request.conversation.suffix(6)).compactMap { message in
            let sanitizedContent = sanitizeText(message.content, knownUserName: knownUserName)
            guard !sanitizedContent.isEmpty else { return Optional<CaptainConversationMessage>.none }
            return CaptainConversationMessage(role: message.role, content: sanitizedContent)
        }

        let sanitizedContext = CaptainContextData(
            steps: max(0, request.contextData.steps),
            calories: max(0, request.contextData.calories),
            vibe: "Anonymized",
            level: max(1, request.contextData.level)
        )

        return HybridBrainRequest(
            conversation: sanitizedConversation,
            screenContext: request.screenContext,
            language: request.language,
            contextData: sanitizedContext,
            userProfileSummary: "",
            hasAttachedImage: request.hasAttachedImage
        )
    }

    func sanitizeText(_ text: String, knownUserName: String?) -> String {
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return "" }

        let patterns: [String] = [
            #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            #"(?<!\d)(?:\+?\d[\d\-\s\(\)]{7,}\d)"#,
            #"@[A-Za-z0-9_\.]+"#,
            #"https?://\S+"#,
            #"\b\d{6,}\b"#,
            #"(?i)\b(my name is|i am|i'm|call me)\s+[A-Z\u0600-\u06FF][A-Za-z\u0600-\u06FF' -]{1,30}"#,
            #"(?i)(اسمي|اني|أنا)\s+[A-Z\u0600-\u06FF][A-Za-z\u0600-\u06FF' -]{1,30}"#
        ]

        for pattern in patterns {
            sanitized = replacingMatches(
                in: sanitized,
                pattern: pattern,
                with: redactionToken,
                options: [.caseInsensitive]
            )
        }

        if let knownUserName {
            let trimmedName = knownUserName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                sanitized = replacingMatches(
                    in: sanitized,
                    pattern: NSRegularExpression.escapedPattern(for: trimmedName),
                    with: redactionToken,
                    options: [.caseInsensitive]
                )
            }
        }

        return sanitized
            .replacingOccurrences(of: #"(\s*\[REDACTED\]\s*){2,}"#, with: " \(redactionToken) ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func injectUserName(into response: String, userName: String) -> String {
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedResponse.isEmpty, !trimmedName.isEmpty else {
            return trimmedResponse
        }

        let placeholders = ["[USER_NAME]", "{{userName}}", "{{user_name}}", "%USER_NAME%"]
        for placeholder in placeholders where trimmedResponse.contains(placeholder) {
            return trimmedResponse.replacingOccurrences(of: placeholder, with: trimmedName)
        }

        let lowercasedResponse = trimmedResponse.lowercased()
        let lowercasedName = trimmedName.lowercased()
        let prefixTokens = ["،", ",", ":", " "]
        if prefixTokens.contains(where: { lowercasedResponse.hasPrefix(lowercasedName + $0) }) {
            return trimmedResponse
        }

        let separator = containsArabicCharacters(in: trimmedResponse) ? "، " : ", "
        return "\(trimmedName)\(separator)\(trimmedResponse)"
    }

    private func replacingMatches(
        in text: String,
        pattern: String,
        with template: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    func containsArabicCharacters(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }
}
