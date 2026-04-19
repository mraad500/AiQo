import Foundation

/// Composes the final title + body for a notification intent.
/// Template-based today; on-device Foundation-Models pass wires in BATCH 7.
public actor MessageComposer {
    public static let shared = MessageComposer()

    public struct Composed: Sendable {
        public let title: String
        public let body: String
    }

    private init() {}

    /// Compose the final message. Returns localized template copy with
    /// light signal injection (relationship names, step counts).
    public func compose(
        intent: NotificationIntent,
        language: String = "ar"
    ) async -> Composed {
        let template = TemplateLibrary.template(for: intent.kind, language: language)
        var body = template.body

        if let factName = intent.signals.customPayload["relationship_name"] {
            body = (language == "ar")
                ? "شلون \(factName) اليوم؟"
                : "How is \(factName) today?"
        }
        if let stepsStr = intent.signals.customPayload["steps"] {
            body = body.replacingOccurrences(of: "{steps}", with: stepsStr)
        }

        return Composed(title: template.title, body: body)
    }
}
