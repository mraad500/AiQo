import Foundation
import SwiftData

/// A standing instruction the user explicitly taught the Captain
/// ("after every workout, analyze it and compare it to the previous one and
/// notify me"). Unlike `SemanticFact` (a passive remembered fact) and
/// `ProceduralPattern` (a silently observed habit), a `LearnedDirective` is an
/// *executable* rule: it is persisted durably, surfaced back to the Captain so
/// it never forgets it, and fired automatically by `DirectiveEngine` when its
/// trigger condition occurs.
///
/// Added in Memory Schema V5 (purely additive over V4 → lightweight migration).
@Model
final class LearnedDirective {
    @Attribute(.unique) var id: UUID

    /// The user's original wording, verbatim. Shown in Captain Memory and fed
    /// back into the prompt so the Captain can reference the exact promise it made.
    var rawInstruction: String

    /// `DirectiveTrigger.rawValue` — the event that fires this directive.
    var triggerRaw: String

    /// `DirectiveAction.rawValue` — what the Captain does when it fires.
    var actionRaw: String

    /// JSON-encoded `[String: String]` free-form parameters (e.g. a custom
    /// notification body for `.notify`). Optional; nil for parameterless actions.
    var paramsJSON: Data?

    /// User can pause a directive without deleting it.
    var isEnabled: Bool

    var createdAt: Date
    var updatedAt: Date

    /// Last time the engine executed this directive (nil until first fire).
    var lastFiredAt: Date?

    /// How many times this directive has fired — used for observability and so
    /// the Captain can say "this is the 5th workout I'm comparing for you".
    var fireCount: Int

    /// Provenance. Currently always `user_explicit` (the user taught it directly).
    var sourceRaw: String

    /// Language the instruction was given in ("ar" / "en"). Drives the dialect
    /// of the text the engine produces when the directive fires.
    var localeCode: String

    init(
        id: UUID = UUID(),
        rawInstruction: String,
        triggerRaw: String,
        actionRaw: String,
        paramsJSON: Data? = nil,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        sourceRaw: String = "user_explicit",
        localeCode: String = "ar"
    ) {
        self.id = id
        self.rawInstruction = rawInstruction
        self.triggerRaw = triggerRaw
        self.actionRaw = actionRaw
        self.paramsJSON = paramsJSON
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.lastFiredAt = nil
        self.fireCount = 0
        self.sourceRaw = sourceRaw
        self.localeCode = localeCode
    }

    var trigger: DirectiveTrigger {
        DirectiveTrigger(rawValue: triggerRaw) ?? .afterWorkout
    }

    var action: DirectiveAction {
        DirectiveAction(rawValue: actionRaw) ?? .analyzeAndCompareWorkout
    }

    var params: [String: String] {
        guard let paramsJSON else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: paramsJSON)) ?? [:]
    }
}
