import Foundation

/// Deterministic cleaner for the FREE on-device Captain's raw output.
///
/// The small on-device model occasionally derails in two specific ways that look
/// terrible to a user (observed live):
///   1. It continues the chat as a *script* — emitting role labels ("Captain:",
///      "User:", "المستخدم:") and even writing the user's side of the turn.
///   2. It degenerates into a repetition loop — one letter ("هههههه…×200") or one
///      word repeated to fill the token budget.
///
/// This guard runs AFTER generation and is pure string work — NO model, NO
/// network — so it can never introduce new content, only remove machine noise.
/// It is `nonisolated` so it can run inside the engine actor.
nonisolated struct OnDeviceReplySanitizer: Sendable {

    /// A hallucinated *user* turn — drop it and everything after it (never ours
    /// to show).
    static let userTurnMarkers = ["User:", "USER:", "المستخدم:", "مستخدم:", "أنت:"]

    /// The model's own role labels — strip the label, keep the words after it.
    static let selfLabels = ["Captain:", "CAPTAIN:", "كابتن:", "حمودي:", "Assistant:", "System:"]

    func clean(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "*", with: "")

        // 1) Cut a fake "user turn" (and everything trailing it).
        s = truncateAtFirstMarker(s, markers: Self.userTurnMarkers)

        // 2) Remove the model's own role labels but keep their text.
        for label in Self.selfLabels {
            s = s.replacingOccurrences(of: label, with: " ", options: [.caseInsensitive])
        }

        // 3) Collapse a degenerate single-character run ("هههه…") to 3 copies.
        s = collapseCharacterRuns(s)

        // 4) Collapse an immediately-repeated word loop ("ما واصلني ما واصلني…").
        s = collapseRepeatedWords(s)

        // 5) Tidy whitespace the cuts may have left behind.
        s = s.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " *\\n", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Steps

    private func truncateAtFirstMarker(_ text: String, markers: [String]) -> String {
        var cut = text.endIndex
        for marker in markers {
            if let range = text.range(of: marker, options: [.caseInsensitive]),
               range.lowerBound < cut {
                cut = range.lowerBound
            }
        }
        return String(text[..<cut])
    }

    /// Any single character repeated 6+ times in a row → 3 copies. Leaves short,
    /// legitimate emphasis/laughter ("هههه") untouched; kills runaway loops.
    private func collapseCharacterRuns(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "(.)\\1{5,}") else { return text }
        let ns = text as NSString
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: ns.length),
            withTemplate: "$1$1$1"
        )
    }

    /// Collapse an immediately-repeated phrase loop: any 1–4 word phrase that
    /// repeats 3+ times back-to-back ("ما واصلني ما واصلني ما واصلني…") is reduced
    /// to a single occurrence. Longest phrase length first so a multi-word loop is
    /// caught before its single words are. Unicode-safe (Arabic-friendly).
    private func collapseRepeatedWords(_ text: String) -> String {
        var tokens = text.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard tokens.count > 2 else { return text }

        for phraseLength in stride(from: 4, through: 1, by: -1) {
            tokens = collapseNGramLoops(tokens, phraseLength: phraseLength)
        }
        return tokens.joined(separator: " ")
    }

    private func collapseNGramLoops(_ tokens: [String], phraseLength n: Int) -> [String] {
        guard n >= 1, tokens.count >= n * 3 else { return tokens }

        var result: [String] = []
        var index = 0
        while index < tokens.count {
            guard index + n <= tokens.count else {
                result.append(tokens[index]); index += 1; continue
            }
            let window = Array(tokens[index..<index + n])
            var repeats = 1
            var probe = index + n
            while probe + n <= tokens.count, Array(tokens[probe..<probe + n]) == window {
                repeats += 1
                probe += n
            }
            let isBlank = window.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            if repeats >= 3, !isBlank {
                result.append(contentsOf: window) // keep one copy of the looped phrase
                index = probe
            } else {
                result.append(tokens[index]); index += 1
            }
        }
        return result
    }
}
