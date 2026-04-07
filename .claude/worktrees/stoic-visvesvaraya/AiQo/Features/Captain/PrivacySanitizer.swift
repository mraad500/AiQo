import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Privacy-first sanitizer that enforces Apple's privacy guidelines before any data leaves the device.
///
/// Guarantees:
/// - PII (emails, phones, UUIDs, IPs) redacted to "[REDACTED]"
/// - User names normalized to "User" in cloud payloads
/// - Conversation truncated to LAST 4 messages only (prevents hallucination, saves tokens)
/// - Health data bucketed: steps by 50, calories by 10
/// - Kitchen images stripped of EXIF/GPS metadata
struct PrivacySanitizer: Sendable {

    // MARK: - Constants

    private let genericUserToken = "User"
    private let redactionToken = "[REDACTED]"
    private let redactedProfileToken = "[REDACTED_PROFILE]"
    private let maxConversationMessages = 4
    private let maximumKitchenImageDimension = 1280
    private let kitchenImageCompressionQuality: CGFloat = 0.78
    private let stepsBucketSize = 50
    private let caloriesBucketSize = 10
    private let maximumSteps = 100_000
    private let maximumCalories = 10_000
    private let maximumLevel = 100

    // MARK: - PII Redaction Rules

    private static let piiRedactionRules: [RedactionRule] = [
        // Email addresses
        RedactionRule(
            pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            template: "[REDACTED]"
        ),
        // Phone numbers (7+ digits with optional separators)
        RedactionRule(
            pattern: #"(?<!\d)(?:\+?\d[\d\-\s\(\)]{7,}\d)"#,
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
        RedactionRule(
            pattern: #"\b(?:\d[ -]?){10,}\b"#,
            template: "[REDACTED]"
        ),
        // IP addresses
        RedactionRule(
            pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#,
            template: "[REDACTED]"
        ),
        // Long base64-like tokens
        RedactionRule(
            pattern: #"\b[a-z0-9]{24,}\b"#,
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

        let safeProfile = cloudSafeMemories.trimmingCharacters(in: .whitespacesAndNewlines)

        return HybridBrainRequest(
            conversation: sanitizedConversation,
            screenContext: request.screenContext,
            language: request.language,
            contextData: sanitizedContext,
            userProfileSummary: safeProfile,
            attachedImageData: sanitizedImageData
        )
    }

    // MARK: - Text Sanitization

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
        for rule in Self.piiRedactionRules {
            sanitized = replacingMatches(
                in: sanitized,
                pattern: rule.pattern,
                with: rule.template,
                options: rule.options
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

    // MARK: - Name Injection (post-generation, into Captain's reply)

    func injectUserName(into response: String, userName: String) -> String {
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedResponse.isEmpty, !trimmedName.isEmpty else {
            return trimmedResponse
        }

        let firstName = trimmedName.components(separatedBy: " ").first ?? trimmedName

        // Replace explicit placeholders
        let placeholders = ["[USER_NAME]", "{{userName}}", "{{user_name}}", "%USER_NAME%"]
        for placeholder in placeholders where trimmedResponse.contains(placeholder) {
            return trimmedResponse.replacingOccurrences(of: placeholder, with: firstName)
        }

        // Don't double-prepend if name already present
        let lowercasedResponse = trimmedResponse.lowercased()
        let lowercasedFirstName = firstName.lowercased()
        let prefixTokens = ["،", ",", ":", " "]

        if prefixTokens.contains(where: { lowercasedResponse.hasPrefix(lowercasedFirstName + $0) }) {
            return trimmedResponse
        }
        if trimmedResponse.hasPrefix("يا \(firstName)") {
            return trimmedResponse
        }

        let separator = containsArabicCharacters(in: trimmedResponse) ? "، " : ", "
        return "\(firstName)\(separator)\(trimmedResponse)"
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

        init(
            pattern: String,
            template: String,
            options: NSRegularExpression.Options = [.caseInsensitive]
        ) {
            self.pattern = pattern
            self.template = template
            self.options = options
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
            let sanitizedContent = sanitizeText(message.content, knownUserName: knownUserName)

            if !sanitizedContent.isEmpty {
                sanitized.append(CaptainConversationMessage(role: message.role, content: sanitizedContent))
                continue
            }

            // Preserve user messages even if fully redacted
            guard message.role == .user else { continue }
            sanitized.append(CaptainConversationMessage(role: .user, content: "User request."))
        }

        #if DEBUG
        print("PrivacySanitizer — Cloud payload: \(sanitized.count) messages (truncated from \(conversation.count)).")
        #endif

        if sanitized.contains(where: { $0.role == .user }) {
            return sanitized
        }

        return [CaptainConversationMessage(role: .user, content: "User request.")]
    }

    // MARK: - Health Data Bucketing

    func sanitizeHealthContext(_ context: CaptainContextData) -> CaptainContextData {
        CaptainContextData(
            steps: bucketedNonNegativeInt(context.steps, bucketSize: stepsBucketSize, maximum: maximumSteps),
            calories: bucketedNonNegativeInt(context.calories, bucketSize: caloriesBucketSize, maximum: maximumCalories),
            vibe: "General",
            level: clamp(context.level, minimum: 1, maximum: maximumLevel)
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

    func bucketedNonNegativeInt(_ value: Int, bucketSize: Int, maximum: Int) -> Int {
        let clamped = clamp(value, minimum: 0, maximum: maximum)
        guard bucketSize > 1 else { return clamped }
        return Int((Double(clamped) / Double(bucketSize)).rounded()) * bucketSize
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
