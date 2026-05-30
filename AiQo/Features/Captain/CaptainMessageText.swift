import SwiftUI

/// Renders a chat-bubble message string with inline `**bold**` styling.
///
/// We hand-walk the `**` markers and build an `AttributedString` ourselves
/// with explicit per-run fonts. Two earlier approaches failed:
///
/// 1. `AttributedString(markdown:)` — Apple's CommonMark parser silently
///    drops emphasis around RTL Arabic content because the
///    left/right-flanking-delimiter rules misfire on mixed-script runs,
///    so the bubble showed literal `**` characters.
/// 2. `Text + Text` with `.bold()` — works correctly, but the `+`
///    operator was deprecated in iOS 26 / macOS 26 in favour of Text
///    string interpolation. With dynamic content we can't compose
///    interpolation literals, so we settled on AttributedString with
///    explicit `.font` per run instead. That sidesteps the deprecation
///    AND survives outer `.font()` modifiers (a per-run font wins over
///    an environment font).
///
/// Scope: only `**bold**` is recognized. Single-`*` italic is intentionally
/// skipped because the model emits `*` as a bullet marker and inside
/// arithmetic expressions ("3 * 4"), and treating those as italic would
/// mangle the reply. Block-level markdown is forbidden upstream by the
/// system prompt.
///
/// `font` parameter: pass the base font you'd otherwise apply with
/// `.font(...)`. The helper paints plain runs in that font and bold runs
/// in `.weight(.bold)` of the same family/size. Call sites should NOT
/// also call `.font(...)` afterwards — that would re-set the environment
/// font and could undermine the per-run weight. (Tests showed the per-run
/// font wins in practice, but removing the outer modifier keeps intent
/// crystal-clear at the call site.)
///
/// Edge cases:
///   - Unclosed `**foo`  → rendered as literal "**foo" in the base font.
///     A visible artifact is preferable to silent loss — tells us the
///     model emitted malformed bold so the prompt can be tightened.
///   - Empty `****`      → no bold run emitted.
///   - Multiple bolds    → each gets its own bold-weight run.
extension Text {
    static func captainMessage(
        _ raw: String,
        font: Font = .system(size: 15, weight: .medium, design: .rounded)
    ) -> Text {
        guard !raw.isEmpty else { return Text(verbatim: "") }
        guard raw.contains("**") else {
            var run = AttributedString(raw)
            run.font = font
            return Text(run)
        }

        var attributed = AttributedString()
        let plainFont = font
        let boldFont = font.weight(.bold)
        var cursor = raw.startIndex

        while cursor < raw.endIndex {
            guard
                let openRange = raw.range(of: "**", range: cursor..<raw.endIndex),
                let closeRange = raw.range(of: "**", range: openRange.upperBound..<raw.endIndex)
            else {
                let rest = String(raw[cursor..<raw.endIndex])
                if !rest.isEmpty {
                    var run = AttributedString(rest)
                    run.font = plainFont
                    attributed.append(run)
                }
                break
            }

            let beforeBold = String(raw[cursor..<openRange.lowerBound])
            if !beforeBold.isEmpty {
                var run = AttributedString(beforeBold)
                run.font = plainFont
                attributed.append(run)
            }

            let boldContent = String(raw[openRange.upperBound..<closeRange.lowerBound])
            if !boldContent.isEmpty {
                var run = AttributedString(boldContent)
                run.font = boldFont
                attributed.append(run)
            }

            cursor = closeRange.upperBound
        }

        return Text(attributed)
    }
}
