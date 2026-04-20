import Foundation

/// Final safety net over outbound notification copy.
enum PersonaGuard {

    struct Result: Sendable {
        let passed: Bool
        let violations: [String]

        nonisolated init(passed: Bool, violations: [String]) {
            self.passed = passed
            self.violations = violations
        }
    }

    nonisolated static func validate(
        title: String,
        body: String,
        kind: NotificationKind
    ) -> Result {
        var violations: [String] = []
        let combined = (title + " " + body).lowercased()

        for pattern in CaptainIdentity.forbiddenPatterns {
            if combined.contains(pattern.lowercased()) {
                violations.append("forbidden_pattern:\(pattern)")
            }
        }

        if !CaptainIdentity.canUseEmoji(for: kind),
           (containsEmoji(title) || containsEmoji(body)) {
            violations.append("emoji_on_non_celebration")
        }

        if title.count > 65 {
            violations.append("title_too_long:\(title.count)")
        }
        if body.count > 180 {
            violations.append("body_too_long:\(body.count)")
        }

        let profanity = ["fuck", "shit", "damn"]
        if profanity.contains(where: { combined.contains($0) }) {
            violations.append("profanity")
        }

        let haramContent = [
            "alcohol", "beer", "wine", "vodka", "casino", "gambling", "porn",
            "خمر", "كحول", "قمار", "مراهنة", "اباحي", "إباحي"
        ]
        if haramContent.contains(where: { combined.contains($0) }) {
            violations.append("haram_content")
        }

        return Result(passed: violations.isEmpty, violations: violations)
    }

    nonisolated private static func containsEmoji(_ value: String) -> Bool {
        value.unicodeScalars.contains(where: isRenderedEmoji)
    }

    nonisolated private static func isRenderedEmoji(_ scalar: UnicodeScalar) -> Bool {
        scalar.properties.isEmojiPresentation ||
        (scalar.properties.isEmoji && scalar.value > 0x238C)
    }
}
