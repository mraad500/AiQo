import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PrivacySanitizer: Sendable {
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

    func sanitizeForCloud(
        _ request: HybridBrainRequest,
        knownUserName: String?
    ) -> HybridBrainRequest {
        let sanitizedConversation = sanitizeConversation(
            request.conversation,
            knownUserName: knownUserName
        )
        let sanitizedContext = sanitizeHealthContext(request.contextData)
        let sanitizedImageData = request.screenContext == .kitchen
            ? sanitizeKitchenImageData(request.attachedImageData)
            : nil

        return HybridBrainRequest(
            conversation: sanitizedConversation,
            screenContext: request.screenContext,
            language: request.language,
            contextData: sanitizedContext,
            userProfileSummary: "",
            attachedImageData: sanitizedImageData
        )
    }

    func sanitizeText(_ text: String, knownUserName: String?) -> String {
        var sanitized = normalizedWhitespace(in: text)
        guard !sanitized.isEmpty else { return "" }

        sanitized = replaceSelfIdentifyingPhrases(in: sanitized)
        sanitized = replaceExplicitProfileFields(in: sanitized)
        sanitized = replaceKnownUserName(in: sanitized, knownUserName: knownUserName)

        for rule in Self.directRedactionRules {
            sanitized = replacingMatches(
                in: sanitized,
                pattern: rule.pattern,
                with: rule.template,
                options: rule.options
            )
        }

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

    func sanitizeKitchenImageData(_ imageData: Data?) -> Data? {
        guard let imageData else { return nil }
        guard let source = CGImageSourceCreateWithData(
            imageData as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceThumbnailMaxPixelSize: maximumKitchenImageDimension
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            return nil
        }

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destinationData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let destinationOptions: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: kitchenImageCompressionQuality
        ]

        // Re-encoding a fresh CGImage drops source metadata such as EXIF and GPS.
        CGImageDestinationAddImage(destination, cgImage, destinationOptions as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return destinationData as Data
    }
}

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

    static let directRedactionRules: [RedactionRule] = [
        RedactionRule(pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, template: "[REDACTED]"),
        RedactionRule(pattern: #"(?<!\d)(?:\+?\d[\d\-\s\(\)]{7,}\d)"#, template: "[REDACTED]"),
        RedactionRule(pattern: #"\b[0-9A-F]{8}\-[0-9A-F]{4}\-[1-5][0-9A-F]{3}\-[89AB][0-9A-F]{3}\-[0-9A-F]{12}\b"#, template: "[REDACTED]"),
        RedactionRule(pattern: #"@[A-Za-z0-9_\.]{2,}"#, template: "User"),
        RedactionRule(pattern: #"https?://\S+"#, template: "[REDACTED]"),
        RedactionRule(pattern: #"\b(?:\d[ -]?){10,}\b"#, template: "[REDACTED]"),
        RedactionRule(pattern: #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, template: "[REDACTED]"),
        RedactionRule(pattern: #"\b[a-z0-9]{24,}\b"#, template: "[REDACTED]")
    ]

    func sanitizeConversation(
        _ conversation: [CaptainConversationMessage],
        knownUserName: String?
    ) -> [CaptainConversationMessage] {
        let truncatedConversation = Array(conversation.suffix(maxConversationMessages))
        var sanitizedConversation: [CaptainConversationMessage] = []

        for message in truncatedConversation {
            let sanitizedContent = sanitizeText(message.content, knownUserName: knownUserName)

            if !sanitizedContent.isEmpty {
                sanitizedConversation.append(
                    CaptainConversationMessage(
                        role: message.role,
                        content: sanitizedContent
                    )
                )
                continue
            }

            guard message.role == .user else { continue }
            sanitizedConversation.append(
                CaptainConversationMessage(
                    role: .user,
                    content: "User request."
                )
            )
        }

        if sanitizedConversation.contains(where: { $0.role == .user }) {
            return sanitizedConversation
        }

        return [
            CaptainConversationMessage(
                role: .user,
                content: "User request."
            )
        ]
    }

    func sanitizeHealthContext(_ context: CaptainContextData) -> CaptainContextData {
        let currentSteps = bucketedNonNegativeInt(
            context.steps,
            bucketSize: stepsBucketSize,
            maximum: maximumSteps
        )
        let currentCalories = bucketedNonNegativeInt(
            context.calories,
            bucketSize: caloriesBucketSize,
            maximum: maximumCalories
        )

        return CaptainContextData(
            steps: currentSteps,
            calories: currentCalories,
            vibe: "General",
            level: clamp(context.level, minimum: 1, maximum: maximumLevel)
        )
    }

    func replaceSelfIdentifyingPhrases(in text: String) -> String {
        var sanitized = text

        let semanticRules: [RedactionRule] = [
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

        for rule in semanticRules {
            sanitized = replacingMatches(
                in: sanitized,
                pattern: rule.pattern,
                with: rule.template,
                options: rule.options
            )
        }

        return sanitized
    }

    func replaceExplicitProfileFields(in text: String) -> String {
        var sanitized = text

        let profileFieldRules: [RedactionRule] = [
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

        for rule in profileFieldRules {
            sanitized = replacingMatches(
                in: sanitized,
                pattern: rule.pattern,
                with: rule.template,
                options: rule.options
            )
        }

        return sanitized
    }

    func replaceKnownUserName(in text: String, knownUserName: String?) -> String {
        guard let knownUserName else { return text }

        let trimmedName = knownUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return text }

        return replacingMatches(
            in: text,
            pattern: NSRegularExpression.escapedPattern(for: trimmedName),
            with: genericUserToken,
            options: [.caseInsensitive]
        )
    }

    func normalizedWhitespace(in text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    func bucketedNonNegativeInt(
        _ value: Int,
        bucketSize: Int,
        maximum: Int
    ) -> Int {
        let clampedValue = clamp(value, minimum: 0, maximum: maximum)
        guard bucketSize > 1 else { return clampedValue }
        return Int((Double(clampedValue) / Double(bucketSize)).rounded()) * bucketSize
    }

    func clamp(
        _ value: Int,
        minimum: Int,
        maximum: Int
    ) -> Int {
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
