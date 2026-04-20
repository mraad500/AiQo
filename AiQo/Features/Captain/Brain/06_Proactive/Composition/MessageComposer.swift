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

extension MessageComposer {

    /// Rich compose: uses persona directive to personalize template output.
    func composeRich(
        intent: NotificationIntent,
        persona: RichDirective,
        dialect: DialectLibrary.Dialect = .iraqi,
        language: String = "ar"
    ) async -> Composed {
        let template = TemplateLibrary.template(for: intent.kind, language: language)
        var title = template.title
        var body = template.body

        if let factName = intent.signals.customPayload["relationship_name"] {
            body = (language == "ar")
                ? "شلون \(factName) اليوم؟"
                : "How is \(factName) today?"
        }
        if let stepsStr = intent.signals.customPayload["steps"] {
            body = body.replacingOccurrences(of: "{steps}", with: stepsStr)
        }

        switch intent.kind {
        case .morningKickoff:
            title = DialectLibrary.phrase(dialect: dialect, context: .greeting)
        case .relationshipCheckIn:
            if let name = intent.signals.customPayload["relationship_name"] {
                body = (language == "ar")
                    ? "شلون \(name) اليوم؟"
                    : "How is \(name) today?"
            }
        case .personalRecord:
            let celebration = DialectLibrary.phrase(dialect: dialect, context: .celebration)
            body = (language == "ar")
                ? "\(celebration) كسرت رقمك اليوم."
                : "\(celebration) You broke your record today."
        case .inactivityNudge:
            title = DialectLibrary.phrase(dialect: dialect, context: .gentleReminder)
        case .recoveryReminder:
            title = DialectLibrary.phrase(dialect: dialect, context: .recovery)
        default:
            break
        }

        if let toneLead = toneLead(for: persona.base.tone, language: language),
           shouldPrefixBody(for: intent.kind) {
            body = prefixed(body: body, with: toneLead, maxLength: 180)
        }

        if persona.base.humorAllowed,
           persona.humorIntensity == .playful,
           celebratoryKinds.contains(intent.kind),
           let flourish = HumorEngine.playfulFlourish(dialect: dialect) {
            body = appended(body: body, with: flourish, separator: " ", maxLength: 180)
        }

        if intent.priority == .high,
           let wisdom = persona.wisdomCandidate,
           intent.kind == .weeklyInsight || intent.kind == .jumuahSpecial {
            body = appended(body: body, with: wisdom.text, separator: "\n\n", maxLength: 180)
        }

        if persona.humorIntensity == .off || !CaptainIdentity.canUseEmoji(for: intent.kind) {
            title = stripEmoji(title)
            body = stripEmoji(body)
        }

        return Composed(title: title, body: body)
    }

    private var celebratoryKinds: Set<NotificationKind> {
        [.personalRecord, .achievementUnlocked, .eidCelebration]
    }

    private func shouldPrefixBody(for kind: NotificationKind) -> Bool {
        switch kind {
        case .sleepDebtAcknowledgment,
             .inactivityNudge,
             .recoveryReminder,
             .circadianNudge,
             .emotionalFollowUp,
             .moodShift,
             .weeklyInsight,
             .jumuahSpecial:
            return true
        default:
            return false
        }
    }

    private func toneLead(
        for tone: PersonaDirective.Tone,
        language: String
    ) -> String? {
        switch (tone, language) {
        case (.warm, _):
            return nil
        case (.gentle, "ar"):
            return "على مهلك."
        case (.gentle, _):
            return "Easy."
        case (.celebratory, "ar"):
            return "كفو."
        case (.celebratory, _):
            return "Nice."
        case (.concerned, "ar"):
            return "أنا وياك."
        case (.concerned, _):
            return "I'm with you."
        case (.reflective, "ar"):
            return "خذها بهدوء."
        case (.reflective, _):
            return "Take it calmly."
        case (.encouraging, "ar"):
            return "خطوة خطوة."
        case (.encouraging, _):
            return "One step at a time."
        }
    }

    private func prefixed(body: String, with prefix: String, maxLength: Int) -> String {
        let candidate = "\(prefix) \(body)"
        return candidate.count <= maxLength ? candidate : body
    }

    private func appended(
        body: String,
        with addition: String,
        separator: String,
        maxLength: Int
    ) -> String {
        let candidate = body + separator + addition
        return candidate.count <= maxLength ? candidate : body
    }

    private func stripEmoji(_ value: String) -> String {
        value.unicodeScalars
            .filter { !isRenderedEmoji($0) }
            .map(String.init)
            .joined()
    }

    private func isRenderedEmoji(_ scalar: UnicodeScalar) -> Bool {
        scalar.properties.isEmojiPresentation ||
        (scalar.properties.isEmoji && scalar.value > 0x238C)
    }
}
