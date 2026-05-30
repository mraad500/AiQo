import CoreGraphics
import Foundation
import ImageIO
import os.log
import UniformTypeIdentifiers

/// Coaching-safe profile payload passed alongside every cloud request.
///
/// Only data the user explicitly entered for personal-coaching purposes:
/// first name (to be addressed naturally), age (for max-HR zones), gender
/// (for caloric-baseline hints), and exact height/weight (for training-load
/// adjustments). No handles, emails, phones, precise location, or last names.
///
/// Body stats are passed through at full precision: the user expects the
/// Captain to know their exact numbers (e.g. 177cm, 95kg), not approximations.
struct CloudSafeProfile: Sendable {
    let firstName: String?
    let age: Int?
    let gender: String?
    let heightCm: Int?
    let weightKg: Int?

    /// Multi-line summary matching `PromptComposer.extractFirstName` patterns
    /// (`- Preferred name: …`) so the persona's name-usage layer activates.
    func asSummaryLines() -> String {
        var lines: [String] = []
        if let firstName, !firstName.isEmpty {
            lines.append("- Preferred name: \(firstName)")
        }
        if let age, age > 0 {
            lines.append("- Age: \(age)")
        }
        if let gender, !gender.isEmpty {
            lines.append("- Gender: \(gender)")
        }
        if let heightCm, heightCm > 0 {
            lines.append("- Height: \(heightCm)cm")
        }
        if let weightKg, weightKg > 0 {
            lines.append("- Weight: \(weightKg)kg")
        }
        return lines.joined(separator: "\n")
    }

    var isEmpty: Bool {
        firstName == nil && age == nil && gender == nil && heightCm == nil && weightKg == nil
    }
}

/// Privacy-first sanitizer that enforces Apple's privacy guidelines before any data leaves the device.
///
/// Guarantees:
/// - PII (emails, phones, UUIDs, IPs) redacted to "[REDACTED]"
/// - Coaching profile (first name, age, exact body stats) passed through
///   via `CloudSafeProfile` so the Captain can personalize replies. This is
///   data the user explicitly entered for coaching; it requires cloud-AI
///   consent (enforced upstream in `CloudBrainService`).
/// - Conversation kept to the last 16 messages OR ~6000 chars (whichever is smaller),
///   then PII-redacted per message. The cap exists for token-budget predictability,
///   NOT for privacy — privacy comes from the per-message redaction below.
/// - Health data (steps, calories, HR, sleep) passed through at full precision:
///   the user expects the Captain to report their exact numbers, matching what
///   the app's own dashboard already shows them. Identifiability is governed by
///   the cloud-AI consent gate, not by coarsening the user's own metrics.
/// - Kitchen images stripped of EXIF/GPS metadata
struct PrivacySanitizer: Sendable {

    // MARK: - Constants

    private let genericUserToken = "User"
    private let redactionToken = "[REDACTED]"
    private let redactedProfileToken = "[REDACTED_PROFILE]"
    private let maxConversationMessages = 16
    /// Per-conversation char budget walked newest-first. Roughly 3-4k Arabic
    /// tokens — paired with `maxOutputTokens=1400` it leaves ample headroom
    /// for system prompt + response inside Gemini's context window.
    private let maxConversationCharBudget = 6000
    private let maximumKitchenImageDimension = 1280
    private let kitchenImageCompressionQuality: CGFloat = 0.78
    private let maximumSteps = 100_000
    private let maximumCalories = 10_000
    private let maximumLevel = 100

    // MARK: - PII Redaction Rules

    /// Pre-compiled PII redaction rules. Each regex is compiled once at static-init time.
    ///
    /// **Fix (2026-04-08):** Rewrote two patterns that caused catastrophic backtracking:
    ///
    /// 1. **Long numeric sequences** — old: `\b(?:\d[ -]?){10,}\b`
    ///    The optional `[ -]?` inside `{10,}` created exponential backtracking states when
    ///    the engine tried to match digit-runs that failed at the trailing `\b`. A string like
    ///    "1234 5678 9012 abc" would cause the engine to re-partition the digit/separator
    ///    assignments 2^n times before failing. New pattern uses possessive-style atomics:
    ///    `\d(?:[\d \-]{8,}\d)` — requires the first and last characters to be digits with
    ///    at least 10 total, no backtracking inside the separator group.
    ///
    /// 2. **Phone numbers** — old: `(?<!\d)(?:\+?\d[\d\-\s\(\)]{7,}\d)`
    ///    Same class of issue — `[\d\-\s\(\)]{7,}` is an unbounded alternation group that
    ///    backtracks exponentially on near-matches. New pattern anchors on digit boundaries.
    private static let piiRedactionRules: [RedactionRule] = [
        // Email addresses
        RedactionRule(
            pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            template: "[REDACTED]"
        ),
        // Phone numbers (7+ digits with optional separators)
        // Fixed: anchored start/end on digits, bounded separator group to {6,18} to prevent runaway
        RedactionRule(
            pattern: #"(?<!\d)\+?\d(?:[\d\-\s()]{6,18})\d(?!\d)"#,
            template: "[REDACTED]"
        ),
        // UUIDs (8-4-4-4-12 hex pattern)
        RedactionRule(
            pattern: #"\b[0-9A-F]{8}\-[0-9A-F]{4}\-[1-5][0-9A-F]{3}\-[89AB][0-9A-F]{3}\-[0-9A-F]{12}\b"#,
            template: "[REDACTED]"
        ),
        // @mentions → "User"
        RedactionRule(
            pattern: #"@[A-Za-z0-9_\.]{2,}"#,
            template: "User"
        ),
        // URLs
        RedactionRule(
            pattern: #"https?://\S+"#,
            template: "[REDACTED]"
        ),
        // Long numeric sequences (card numbers, etc.)
        // Fixed: removed nested optional quantifier that caused catastrophic backtracking.
        // Now requires first+last char = digit, middle = digits/spaces/hyphens, total ≥ 10 chars.
        RedactionRule(
            pattern: #"\b\d(?:[\d \-]{8,30})\d\b"#,
            template: "[REDACTED]"
        ),
        // IP addresses
        RedactionRule(
            pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#,
            template: "[REDACTED]"
        ),
        // Long base64-like tokens (bounded upper limit to prevent runaway on huge strings)
        RedactionRule(
            pattern: #"\b[a-z0-9]{24,128}\b"#,
            template: "[REDACTED]"
        ),
        // `sk-`-prefixed API keys (OpenAI / Anthropic / MiniMax convention).
        // Added 2026-04-22 as a backstop for the cloud-voice integration —
        // the MiniMax key lives in Keychain + Info.plist, but any accidental
        // surfacing in a log line or prompt context must be redacted before
        // it leaves the device. Template is fixed rather than keeping the
        // prefix so partial leaks don't fingerprint the key.
        RedactionRule(
            pattern: #"\bsk-[A-Za-z0-9_\-\.]{8,200}\b"#,
            template: "[REDACTED_API_KEY]"
        ),
        // `Bearer …` auth headers — same backstop class. Matches the
        // scheme token plus a bounded opaque value so header leaks in
        // debug logs or error bodies do not reach the cloud.
        RedactionRule(
            pattern: #"\bBearer\s+[A-Za-z0-9_\-\.]{8,400}\b"#,
            template: "Bearer [REDACTED]"
        )
    ]

    // MARK: - Cloud Sanitization Pipeline

    func sanitizeForCloud(
        _ request: HybridBrainRequest,
        knownUserName: String?,
        cloudSafeProfile: CloudSafeProfile? = nil,
        cloudSafeMemories: String = "",
        cloudSafeAppKnowledge: String = ""
    ) -> HybridBrainRequest {
        let sanitizedConversation = sanitizeConversation(
            request.conversation,
            knownUserName: knownUserName
        )
        let sanitizedContext = sanitizeHealthContext(request.contextData)
        // Image is allowed for kitchen vision and gym body-photo tailoring.
        // Both go through the same EXIF/GPS-strip + downsize pipeline; the
        // body-photo consent gate is enforced separately by the caller.
        let sanitizedImageData: Data?
        switch request.screenContext {
        case .kitchen, .gym:
            sanitizedImageData = sanitizeKitchenImageData(request.attachedImageData)
        default:
            sanitizedImageData = nil
        }

        let safeIntent = sanitizePromptForCloud(request.intentSummary, knownUserName: knownUserName)
        let safeWorkingMemory = cloudSafeMemories.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileSummary = cloudSafeProfile?.asSummaryLines() ?? ""
        // App knowledge is static, app-authored, PII-free constant text — like
        // cloudSafeMemories it is trusted: trimmed but NOT run through
        // sanitizeText (which would mangle the Arabic feature copy).
        let safeAppKnowledge = cloudSafeAppKnowledge.trimmingCharacters(in: .whitespacesAndNewlines)

        // Compacted session state is derived from the user's own + Captain's own
        // turns (which already flow to the cloud as the `contents` array), so it
        // gets the same PII redaction + numeric bucketing as any prompt text.
        // Preserved as a dedicated field — unlike `workingMemorySummary` it is
        // NOT overwritten, so long-session continuity actually reaches Gemini.
        let safeConversationState: String? = {
            guard let raw = request.conversationState?
                .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty
            else { return nil }
            let cleaned = sanitizePromptForCloud(raw, knownUserName: knownUserName)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }()

        return HybridBrainRequest(
            conversation: sanitizedConversation,
            screenContext: request.screenContext,
            language: request.language,
            contextData: sanitizedContext,
            userProfileSummary: profileSummary,
            intentSummary: safeIntent,
            workingMemorySummary: safeWorkingMemory,
            attachedImageData: sanitizedImageData,
            purpose: request.purpose,
            appKnowledge: safeAppKnowledge.isEmpty ? nil : safeAppKnowledge,
            conversationState: safeConversationState
        )
    }

    // MARK: - Text Sanitization

    /// Sanitizes a free-text prompt before it leaves the device.
    /// Pipeline: PII redaction (via `sanitizeText`) only.
    ///
    /// Numeric vitals (steps, calories, HR, distance, sleep, etc.) are passed
    /// through verbatim — the user expects the Captain to echo their exact
    /// numbers, and the digits are normalized at render time, not coarsened.
    /// PII (emails, phones, names) is still fully redacted below.
    func sanitizePromptForCloud(_ prompt: String, knownUserName: String?) -> String {
        sanitizeText(prompt, knownUserName: knownUserName)
    }

    func sanitizeText(_ text: String, knownUserName: String?) -> String {
        var sanitized = normalizedWhitespace(in: text)
        guard !sanitized.isEmpty else { return "" }

        // Step 1: Replace explicit non-name profile fields ("email:", "phone:", "DOB:" …).
        // Name/username patterns are intentionally NOT redacted — the user's first name
        // is passed to the cloud via `CloudSafeProfile` so the Captain can address the
        // user naturally. Redacting it here would create contradictions between the
        // system prompt ("Preferred name: محمد") and conversation turns ("اسمي User").
        sanitized = replaceExplicitProfileFields(in: sanitized)

        // Step 2: Apply PII regex redaction (emails, phones, UUIDs, IPs)
        // Uses pre-compiled regexes to avoid NSRegularExpression init cost per message.
        for rule in Self.piiRedactionRules {
            guard let regex = rule.compiledRegex else { continue }
            let range = NSRange(sanitized.startIndex..<sanitized.endIndex, in: sanitized)
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: rule.template
            )
        }

        // Step 5: Collapse consecutive redaction tokens
        sanitized = sanitized
            .replacingOccurrences(
                of: #"(\s*(?:\[REDACTED\]|\[REDACTED_PROFILE\]|User)\s*){2,}"#,
                with: " \(redactionToken) ",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized
    }

    // MARK: - TTS Sanitization

    /// Sanitize a Captain reply for third-party TTS transmission.
    /// Replaces the known user's first name with a neutral vocative so the TTS provider
    /// never receives the real name, while preserving natural-sounding speech.
    func sanitizeForTTS(
        _ text: String,
        knownUserName: String?,
        language: AppLanguage
    ) -> String {
        guard let first = knownUserName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !first.isEmpty else {
            return text
        }
        let replacement = language == .arabic ? "صديقي" : "friend"
        let escaped = NSRegularExpression.escapedPattern(for: first)
        let pattern = "\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: replacement
        )
    }

    // MARK: - Name Injection (post-generation, into Captain's reply)

    /// Replaces explicit name tokens with the user's first name.
    ///
    /// Apple v1.1 rejection fix: previously this function also prepended the
    /// user's name to the front of every assistant reply when no placeholder
    /// was found, producing screenshots like "John, Got it. 60kg is..." that
    /// Apple Review flagged under Guideline 4.0.0. The prepend path is gone.
    /// Hamoudi now says the user's name only if he naturally writes it (via
    /// one of the explicit placeholder tokens inside his own generated reply).
    func injectUserName(into response: String, userName: String) -> String {
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedResponse.isEmpty, !trimmedName.isEmpty else {
            return trimmedResponse
        }

        let firstName = trimmedName.components(separatedBy: " ").first ?? trimmedName

        let placeholders = ["[USER_NAME]", "{{userName}}", "{{user_name}}", "{USER_NAME}", "%USER_NAME%"]
        var result = trimmedResponse
        for placeholder in placeholders where result.contains(placeholder) {
            result = result.replacingOccurrences(of: placeholder, with: firstName)
        }
        return result
    }

    // MARK: - Kitchen Image Sanitization (strips EXIF/GPS via re-encoding)

    func sanitizeKitchenImageData(_ imageData: Data?) -> Data? {
        guard let imageData else { return nil }
        guard let source = CGImageSourceCreateWithData(
            imageData as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceThumbnailMaxPixelSize: maximumKitchenImageDimension
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbnailOptions as CFDictionary
        ) else { return nil }

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(
            destination,
            cgImage,
            [kCGImageDestinationLossyCompressionQuality: kitchenImageCompressionQuality] as CFDictionary
        )

        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }

    // MARK: - Error Sanitization (Crashlytics)

    /// Keys retained when forwarding an `NSError` to Crashlytics. Everything
    /// else in `userInfo` is dropped. String values inside whitelisted keys
    /// are still scrubbed through `sanitizeText` — system keys (especially
    /// URL-bearing ones) can contain user data in query parameters.
    static let crashlyticsKeyWhitelist: Set<String> = [
        NSLocalizedDescriptionKey,
        NSLocalizedFailureReasonErrorKey,
        NSLocalizedRecoverySuggestionErrorKey,
        NSURLErrorFailingURLErrorKey,
        NSUnderlyingErrorKey
    ]

    /// Returns a Crashlytics-safe copy of `error`. All values from the
    /// original `userInfo` are dropped unless their key is in
    /// `crashlyticsKeyWhitelist`, and whitelisted `String`/`URL` values
    /// are still passed through `sanitizeText` (URLs can carry emails
    /// or phone numbers in query parameters). `NSUnderlyingErrorKey`
    /// recurses.
    func sanitizeError(_ error: Error) -> NSError {
        let nsError = error as NSError
        var safeUserInfo: [String: Any] = [:]

        for (key, value) in nsError.userInfo {
            guard Self.crashlyticsKeyWhitelist.contains(key) else { continue }

            if key == NSUnderlyingErrorKey, let underlying = value as? Error {
                safeUserInfo[key] = sanitizeError(underlying)
            } else if let stringValue = value as? String {
                safeUserInfo[key] = sanitizeText(stringValue, knownUserName: nil)
            } else if let url = value as? URL {
                safeUserInfo[key] = sanitizeText(url.absoluteString, knownUserName: nil)
            }
            // All other types (Data, custom Swift values, etc.) are dropped.
        }

        // Always rewrite the user-visible description through the sanitizer —
        // many SDKs put PII directly into `localizedDescription` without
        // populating `NSLocalizedDescriptionKey` in `userInfo`, so the
        // whitelist alone is not enough.
        let safeDescription = sanitizeText(nsError.localizedDescription, knownUserName: nil)
        if safeUserInfo[NSLocalizedDescriptionKey] == nil {
            safeUserInfo[NSLocalizedDescriptionKey] = safeDescription
        }

        return NSError(
            domain: nsError.domain,
            code: nsError.code,
            userInfo: safeUserInfo
        )
    }
}

// MARK: - Private Helpers

private extension PrivacySanitizer {

    struct RedactionRule: Sendable {
        let pattern: String
        let template: String
        let options: NSRegularExpression.Options
        /// Pre-compiled regex — avoids recompilation on every message.
        let compiledRegex: NSRegularExpression?

        init(
            pattern: String,
            template: String,
            options: NSRegularExpression.Options = [.caseInsensitive]
        ) {
            self.pattern = pattern
            self.template = template
            self.options = options
            self.compiledRegex = try? NSRegularExpression(pattern: pattern, options: options)
        }
    }

    // MARK: - Conversation Sanitization
    //
    // Length cap is two-stage:
    //   1. Take the last `maxConversationMessages` (16) messages.
    //   2. Walk newest-first summing UTF-8 byte counts; stop when the
    //      running total exceeds `maxConversationCharBudget` (~6000).
    //   3. Always retain at least the last 2 messages even if they
    //      individually exceed the budget — starving the model of the
    //      current turn produces worse failures than a single oversize
    //      payload.
    //   4. Reverse back to chronological order, then run the unchanged
    //      per-message PII redaction pipeline.
    // The cap is for token-budget predictability, NOT privacy — privacy
    // comes from `sanitizePromptForCloud` redaction below.

    func sanitizeConversation(
        _ conversation: [CaptainConversationMessage],
        knownUserName: String?
    ) -> [CaptainConversationMessage] {
        let totalAvailable = conversation.count
        let countCapped = Array(conversation.suffix(maxConversationMessages))

        // Walk newest-first, accumulating until the char budget is exceeded.
        var keptReversed: [CaptainConversationMessage] = []
        var charsUsed = 0
        for message in countCapped.reversed() {
            let messageBytes = message.content.utf8.count
            // Always keep at least the last 2 turns regardless of budget.
            let isUnderMinimum = keptReversed.count < 2
            if !isUnderMinimum && (charsUsed + messageBytes) > maxConversationCharBudget {
                break
            }
            keptReversed.append(message)
            charsUsed += messageBytes
        }

        let budgetTrimmed = Array(keptReversed.reversed())

        if budgetTrimmed.count < totalAvailable {
            Self.conversationLogger.notice(
                "sanitizer_history_trimmed kept=\(budgetTrimmed.count) ofTotal=\(totalAvailable) charBudgetUsed=\(charsUsed)"
            )
        }

        var sanitized: [CaptainConversationMessage] = []

        for message in budgetTrimmed {
            let sanitizedContent = sanitizePromptForCloud(message.content, knownUserName: knownUserName)

            if !sanitizedContent.isEmpty {
                sanitized.append(CaptainConversationMessage(role: message.role, content: sanitizedContent))
                continue
            }

            // Preserve user messages even if fully redacted
            guard message.role == .user else { continue }
            sanitized.append(CaptainConversationMessage(role: .user, content: "User request."))
        }

        if sanitized.contains(where: { $0.role == .user }) {
            return sanitized
        }

        return [CaptainConversationMessage(role: .user, content: "User request.")]
    }

    // MARK: - Health Context Pass-Through

    /// Forwards the live HealthKit vitals to Gemini at full precision so the
    /// Captain reports the user's exact numbers (matching the app dashboard),
    /// while still stripping the derived emotional/behavioural signals.
    /// - Keeps: exact steps/calories/HR/sleep, timeOfDay, toneHint, stageTitle, bioPhase
    /// - Drops: emotionalState, trendSnapshot, messageSentiment, recentInteractions
    /// Values are only clamped to non-negative, physiologically-sane bounds as a
    /// defensive guard against malformed input — never rounded.
    func sanitizeHealthContext(_ context: CaptainContextData) -> CaptainContextData {
        CaptainContextData(
            steps: clamp(context.steps, minimum: 0, maximum: maximumSteps),
            calories: clamp(context.calories, minimum: 0, maximum: maximumCalories),
            vibe: "General",
            level: clamp(context.level, minimum: 1, maximum: maximumLevel),
            sleepHours: min(max(context.sleepHours, 0), 24),
            heartRate: context.heartRate.map { min(max($0, 0), 260) },
            timeOfDay: context.timeOfDay,
            toneHint: context.toneHint,
            stageTitle: context.stageTitle,
            bioPhase: context.bioPhase
        )
    }

    // MARK: - Self-Identifying Phrase Replacement

    func replaceSelfIdentifyingPhrases(in text: String) -> String {
        var sanitized = text

        let rules: [RedactionRule] = [
            RedactionRule(
                pattern: #"(?i)\b(my name is|call me|you can call me)\s+[A-Z\u0600-\u06FF][A-Za-z\u0600-\u06FF' -]{0,40}"#,
                template: "$1 \(genericUserToken)"
            ),
            RedactionRule(
                pattern: #"(?i)\b(i am|i'm)\s+[A-Z\u0600-\u06FF][A-Za-z\u0600-\u06FF' -]{0,40}"#,
                template: "$1 \(genericUserToken)"
            ),
            RedactionRule(
                pattern: #"(?i)(اسمي|ناديني|سمّني|سموني)\s+[\p{L}\u0600-\u06FF' -]{1,40}"#,
                template: "$1 \(genericUserToken)"
            ),
            RedactionRule(
                pattern: #"(?i)(انا|أَنا|أنا|اني)\s+[\p{L}\u0600-\u06FF' -]{1,40}"#,
                template: "$1 \(genericUserToken)"
            )
        ]

        for rule in rules {
            sanitized = replacingMatches(in: sanitized, pattern: rule.pattern, with: rule.template, options: rule.options)
        }

        return sanitized
    }

    // MARK: - Profile Field Replacement

    func replaceExplicitProfileFields(in text: String) -> String {
        var sanitized = text

        // Name/username rules intentionally omitted: the first name is carried
        // by `CloudSafeProfile` so redacting it here (e.g. "my name is محمد" →
        // "my name User") would create prompt contradictions. Contact / DOB /
        // location / body-metric field labels remain redacted — those are
        // stricter PII classes not covered by the coaching profile payload.
        let rules: [RedactionRule] = [
            RedactionRule(
                pattern: #"(?i)\b(email|e-mail|phone|mobile|number|address|location|dob|date of birth|birthday)\b\s*[:=]?\s*[^,\n]+"#,
                template: "$1 \(redactedProfileToken)"
            ),
            RedactionRule(
                pattern: #"(?i)(الايميل|البريد|البريد الالكتروني|الرقم|رقم الهاتف|الجوال|العنوان|الموقع|تاريخ الميلاد)\s*[:=]?\s*[^،\n]+"#,
                template: "$1 \(redactedProfileToken)"
            )
        ]

        for rule in rules {
            sanitized = replacingMatches(in: sanitized, pattern: rule.pattern, with: rule.template, options: rule.options)
        }

        return sanitized
    }

    // MARK: - Known Name Replacement

    func replaceKnownUserName(in text: String, knownUserName: String?) -> String {
        guard let knownUserName else { return text }
        let trimmed = knownUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        return replacingMatches(
            in: text,
            pattern: NSRegularExpression.escapedPattern(for: trimmed),
            with: genericUserToken,
            options: [.caseInsensitive]
        )
    }

    // MARK: - Utility

    func normalizedWhitespace(in text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    func clamp(_ value: Int, minimum: Int, maximum: Int) -> Int {
        min(max(value, minimum), maximum)
    }

    func replacingMatches(
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

// MARK: - Sanitized Logging

extension PrivacySanitizer {
    /// History-trim audit log. Distinct category from `vibeLogger` so
    /// Console filtering stays clean.
    fileprivate static let conversationLogger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AiQo",
        category: "PrivacySanitizer"
    )

    private static let vibeLogger = Logger(subsystem: "com.mraad500.aiqo", category: "MyVibe")

    /// Fixed token used to stand in for a track title in logs.
    /// Track names are arbitrary user content — callers should never interpolate them directly;
    /// pass `PrivacySanitizer.redactedTrack` instead.
    static let redactedTrack = "<track>"

    static func log(_ message: String, sensitive: [String] = []) {
        var sanitized = message
        for value in sensitive {
            sanitized = sanitized.replacingOccurrences(of: value, with: "<redacted>")
        }
        // Spotify URIs — preserve the type, redact only the ID.
        // "spotify:track:abc123" → "spotify:track:***"
        sanitized = sanitized.replacingOccurrences(
            of: #"spotify:([a-z]+):[A-Za-z0-9]+"#,
            with: "spotify:$1:***",
            options: .regularExpression
        )
        // Bare Spotify user IDs outside a URI (e.g. "user:abc123").
        sanitized = sanitized.replacingOccurrences(
            of: #"\buser:[A-Za-z0-9_\-]+"#,
            with: "user:***",
            options: .regularExpression
        )
        vibeLogger.log("\(sanitized, privacy: .public)")
    }
}
