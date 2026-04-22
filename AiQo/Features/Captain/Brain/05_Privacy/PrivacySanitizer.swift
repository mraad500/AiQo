import CoreGraphics
import Foundation
import ImageIO
import os.log
import UniformTypeIdentifiers

/// Privacy-first sanitizer that enforces Apple's privacy guidelines before any data leaves the device.
///
/// Guarantees:
/// - PII (emails, phones, UUIDs, IPs) redacted to "[REDACTED]"
/// - User names normalized to "User" in cloud payloads
/// - Conversation truncated to LAST 4 messages only (prevents hallucination, saves tokens)
/// - Health data bucketed: steps by 500, calories by 10, HR by 5, sleep by 0.5h
/// - Kitchen images stripped of EXIF/GPS metadata
struct PrivacySanitizer: Sendable {

    // MARK: - Constants

    private let genericUserToken = "User"
    private let redactionToken = "[REDACTED]"
    private let redactedProfileToken = "[REDACTED_PROFILE]"
    private let maxConversationMessages = 4
    private let maximumKitchenImageDimension = 1280
    private let kitchenImageCompressionQuality: CGFloat = 0.78
    private let stepsBucketSize = 500
    private let caloriesBucketSize = 10
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
        )
    ]

    // MARK: - Cloud Sanitization Pipeline

    func sanitizeForCloud(
        _ request: HybridBrainRequest,
        knownUserName: String?,
        cloudSafeMemories: String = ""
    ) -> HybridBrainRequest {
        let sanitizedConversation = sanitizeConversation(
            request.conversation,
            knownUserName: knownUserName
        )
        let sanitizedContext = sanitizeHealthContext(request.contextData)
        let sanitizedImageData = request.screenContext == .kitchen
            ? sanitizeKitchenImageData(request.attachedImageData)
            : nil

        let safeIntent = sanitizePromptForCloud(request.intentSummary, knownUserName: knownUserName)
        let safeWorkingMemory = cloudSafeMemories.trimmingCharacters(in: .whitespacesAndNewlines)

        return HybridBrainRequest(
            conversation: sanitizedConversation,
            screenContext: request.screenContext,
            language: request.language,
            contextData: sanitizedContext,
            userProfileSummary: "",
            intentSummary: safeIntent,
            workingMemorySummary: safeWorkingMemory,
            attachedImageData: sanitizedImageData,
            purpose: request.purpose
        )
    }

    // MARK: - Text Sanitization

    /// Sanitizes a free-text prompt before it leaves the device.
    /// Pipeline: PII redaction (via `sanitizeText`) + numeric bucketing for HealthKit vitals.
    /// Input may contain Arabic, English, or mixed numerics; Arabic digits are normalized first.
    func sanitizePromptForCloud(_ prompt: String, knownUserName: String?) -> String {
        var result = sanitizeText(prompt, knownUserName: knownUserName)
        result = convertArabicDigits(in: result)
        result = bucketHeartRateMentions(in: result)
        result = bucketStepMentions(in: result)
        result = bucketDistanceMentions(in: result)
        result = bucketCalorieMentions(in: result)
        result = bucketDurationMentions(in: result)
        result = bucketSleepMentions(in: result)
        result = bucketZonePercentMentions(in: result)
        return result
    }

    func sanitizeText(_ text: String, knownUserName: String?) -> String {
        var sanitized = normalizedWhitespace(in: text)
        guard !sanitized.isEmpty else { return "" }

        // Step 1: Replace self-identifying phrases ("my name is X")
        sanitized = replaceSelfIdentifyingPhrases(in: sanitized)

        // Step 2: Replace explicit profile fields ("name:", "email:", etc.)
        sanitized = replaceExplicitProfileFields(in: sanitized)

        // Step 3: Replace known user name globally → "User"
        sanitized = replaceKnownUserName(in: sanitized, knownUserName: knownUserName)

        // Step 4: Apply PII regex redaction (emails, phones, UUIDs, IPs)
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

    // MARK: - Conversation Sanitization (truncate to last 4 messages)

    func sanitizeConversation(
        _ conversation: [CaptainConversationMessage],
        knownUserName: String?
    ) -> [CaptainConversationMessage] {
        let truncated = Array(conversation.suffix(maxConversationMessages))
        var sanitized: [CaptainConversationMessage] = []

        for message in truncated {
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

    // MARK: - Health Data Bucketing

    /// Preserves Brain V2 signals at coarse granularity so Gemini can reason about
    /// energy/recovery state without ever receiving raw HealthKit values.
    /// - Keeps: steps/calories/HR/sleep (bucketed), timeOfDay, toneHint, stageTitle, bioPhase
    /// - Drops: emotionalState, trendSnapshot, messageSentiment, recentInteractions
    func sanitizeHealthContext(_ context: CaptainContextData) -> CaptainContextData {
        CaptainContextData(
            steps: bucketedNonNegativeInt(context.steps, bucketSize: stepsBucketSize, maximum: maximumSteps),
            calories: bucketedNonNegativeInt(context.calories, bucketSize: caloriesBucketSize, maximum: maximumCalories),
            vibe: "General",
            level: clamp(context.level, minimum: 1, maximum: maximumLevel),
            sleepHours: bucketedSleep(context.sleepHours),
            heartRate: bucketedHeartRate(context.heartRate),
            timeOfDay: context.timeOfDay,
            toneHint: context.toneHint,
            stageTitle: context.stageTitle,
            bioPhase: context.bioPhase
        )
    }

    func bucketedHeartRate(_ hr: Int?) -> Int? {
        guard let hr, hr > 0 else { return nil }
        let clamped = min(max(hr, 0), 260)
        return (clamped / 5) * 5
    }

    func bucketedSleep(_ hours: Double) -> Double {
        guard hours > 0 else { return 0 }
        let clamped = min(max(hours, 0), 24)
        return ((clamped * 2).rounded() / 2)
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

        let rules: [RedactionRule] = [
            RedactionRule(
                pattern: #"(?i)\b(name|full name|username|user name)\b\s*[:=]?\s*[^,\n]+"#,
                template: "$1 \(genericUserToken)"
            ),
            RedactionRule(
                pattern: #"(?i)\b(email|e-mail|phone|mobile|number|address|location|dob|date of birth|birthday|age|height|weight)\b\s*[:=]?\s*[^,\n]+"#,
                template: "$1 \(redactedProfileToken)"
            ),
            RedactionRule(
                pattern: #"(?i)(الاسم|اسم المستخدم|اليوزر|المستخدم)\s*[:=]?\s*[^،\n]+"#,
                template: "$1 \(genericUserToken)"
            ),
            RedactionRule(
                pattern: #"(?i)(الايميل|البريد|البريد الالكتروني|الرقم|رقم الهاتف|الجوال|العنوان|الموقع|تاريخ الميلاد|العمر|الطول|الوزن)\s*[:=]?\s*[^،\n]+"#,
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

    /// Floor-bucketing: matches the free-text int-bucketing direction so structured
    /// and free-text vitals have identical privacy granularity.
    func bucketedNonNegativeInt(_ value: Int, bucketSize: Int, maximum: Int) -> Int {
        let clamped = clamp(value, minimum: 0, maximum: maximum)
        guard bucketSize > 1 else { return clamped }
        return (clamped / bucketSize) * bucketSize
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

    // MARK: - Numeric Bucketing for Free-Text Vitals

    /// Arabic-Indic digits (٠-٩) and Extended Arabic-Indic digits (۰-۹) → ASCII 0-9.
    /// Must run before any numeric regex so bucketing catches Arabic numbers too.
    func convertArabicDigits(in text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0660...0x0669:
                result.append(Character(Unicode.Scalar(scalar.value - 0x0660 + 0x30)!))
            case 0x06F0...0x06F9:
                result.append(Character(Unicode.Scalar(scalar.value - 0x06F0 + 0x30)!))
            default:
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    func bucketHeartRateMentions(in text: String) -> String {
        bucketNumericMatches(
            in: text,
            pattern: #"(\d+)\s*(bpm|نبضة/دقيقة|نبضة|ن/د)"#,
            bucket: 5,
            isDouble: false
        )
    }

    func bucketStepMentions(in text: String) -> String {
        bucketNumericMatches(
            in: text,
            pattern: #"(\d+)\s*(steps?|خطوات|خطوة|خطوه)"#,
            bucket: 500,
            isDouble: false
        )
    }

    func bucketDistanceMentions(in text: String) -> String {
        bucketNumericMatches(
            in: text,
            pattern: #"(\d+(?:\.\d+)?)\s*(km|كيلومتر|كم|كيلو)"#,
            bucket: 0.1,
            isDouble: true
        )
    }

    func bucketCalorieMentions(in text: String) -> String {
        bucketNumericMatches(
            in: text,
            pattern: #"(\d+)\s*(kcal|cal|سعرة\s*حرارية|سعر\s*حراري|سعرات|سعرة)"#,
            bucket: 10,
            isDouble: false
        )
    }

    func bucketDurationMentions(in text: String) -> String {
        // English units anchored with \b to avoid matching "mints", "minor", etc.
        // Arabic alternatives can't use \b reliably (NSRegularExpression's word-boundary
        // semantics require ASCII word chars on at least one side).
        bucketNumericMatches(
            in: text,
            pattern: #"(\d+)\s*(?:(?:minutes?|mins?|min)\b|دقيقة|دقائق)"#,
            bucket: 5,
            isDouble: false
        )
    }

    func bucketSleepMentions(in text: String) -> String {
        bucketNumericMatches(
            in: text,
            pattern: #"(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|ساعة|ساعات)\b"#,
            bucket: 0.5,
            isDouble: true
        )
    }

    func bucketZonePercentMentions(in text: String) -> String {
        bucketNumericMatches(
            in: text,
            pattern: #"(\d+)\s*%\s*(zone\s*\d|زون|peak|below|منطقة)"#,
            bucket: 5,
            isDouble: false
        )
    }

    /// Walks matches right-to-left so replacements don't invalidate NSRange offsets of earlier matches.
    ///
    /// Bucketing semantics:
    /// - Integer buckets (e.g. 5, 10, 500) use **floor** — privacy-friendly: "487 kcal" → "480",
    ///   never rounds UP to reveal a higher bound.
    /// - Float buckets (e.g. 0.1, 0.5) use **round-half-to-nearest-or-even** — preserves
    ///   signal for small numbers like distance/sleep where floor would lose too much precision.
    func bucketNumericMatches(
        in text: String,
        pattern: String,
        bucket: Double,
        isDouble: Bool
    ) -> String {
        guard bucket > 0,
              let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        var result = text
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let digitRange = match.range(at: 1)
            guard digitRange.location != NSNotFound,
                  let digitSwiftRange = Range(digitRange, in: result) else { continue }

            let raw = String(result[digitSwiftRange])
            guard let rawValue = Double(raw) else { continue }

            let scaled = rawValue / bucket
            let bucketed: Double
            let replacement: String
            if isDouble {
                bucketed = scaled.rounded() * bucket
                replacement = String(format: "%.1f", bucketed)
            } else {
                bucketed = scaled.rounded(.down) * bucket
                replacement = String(Int(bucketed))
            }
            result.replaceSubrange(digitSwiftRange, with: replacement)
        }
        return result
    }
}

// MARK: - Sanitized Logging

extension PrivacySanitizer {
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
