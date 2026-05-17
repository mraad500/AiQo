import Foundation

// ===============================================
// Brain OS — 11_Directives
// The Learning & Standing-Order layer.
//
// This layer is what lets the user TEACH the Captain durable, executable
// instructions ("after every workout, analyze it and compare it to the
// previous one and notify me"). The Captain learns it (DirectiveLearner),
// saves it (DirectiveStore → LearnedDirective in Memory Schema V5),
// remembers it (surfaced into the prompt + Captain Memory), and executes it
// automatically (DirectiveEngine), and never forgets it.
// ===============================================

/// When a directive fires. Extensible — only `.afterWorkout` is fully wired
/// end-to-end today; the rest are recognized so the taxonomy can grow without
/// a schema change (the trigger is stored as a raw string).
enum DirectiveTrigger: String, Sendable, Codable, CaseIterable {
    /// Immediately after any workout completes (HealthKit-wide: Watch,
    /// external, or in-app). This is the flagship trigger.
    case afterWorkout

    /// Reserved for future wiring — recognized by the learner so the user can
    /// teach them now and we can light them up incrementally.
    case beforeBedtime
    case everyMorning
    case afterPoorSleep
    case weeklyReview

    var displayAr: String {
        switch self {
        case .afterWorkout:   return "بعد كل تمرين"
        case .beforeBedtime:  return "قبل النوم"
        case .everyMorning:   return "كل صباح"
        case .afterPoorSleep: return "بعد نوم قليل"
        case .weeklyReview:   return "مراجعة أسبوعية"
        }
    }

    /// Whether the engine can actually execute this trigger today. Recognized
    /// but not-yet-wired triggers are still saved (so the promise is kept) and
    /// surfaced to the Captain, but won't auto-fire until wired.
    var isExecutable: Bool { self == .afterWorkout }
}

/// What the Captain does when a directive fires.
enum DirectiveAction: String, Sendable, Codable, CaseIterable {
    /// Analyze the just-finished workout and compare it to the previous one,
    /// then deliver the result as a Captain notification. The flagship action.
    case analyzeAndCompareWorkout

    /// Send a fixed reminder/notification the user dictated. The text lives in
    /// `params["text"]`.
    case notify

    var displayAr: String {
        switch self {
        case .analyzeAndCompareWorkout: return "حلّل التمرين وقارنه بالسابق وأرسل إشعار"
        case .notify:                   return "أرسل تذكير"
        }
    }

    var displayEn: String {
        switch self {
        case .analyzeAndCompareWorkout: return "analyze the workout, compare it to the previous one, and send a notification"
        case .notify:                   return "send a reminder"
        }
    }
}

/// A parsed-but-not-yet-persisted directive produced by `DirectiveLearner`
/// from a user message. Sendable so it can cross the chat Task boundary.
nonisolated struct LearnedDirectiveDraft: Sendable, Equatable {
    let rawInstruction: String
    let trigger: DirectiveTrigger
    let action: DirectiveAction
    let params: [String: String]
    let localeCode: String
}

/// An immutable, `Sendable` view of a persisted `LearnedDirective` for use
/// outside the `DirectiveStore` actor (mirrors `ProceduralPatternSnapshot`).
nonisolated struct LearnedDirectiveSnapshot: Identifiable, Sendable, Equatable {
    let id: UUID
    let rawInstruction: String
    let trigger: DirectiveTrigger
    let action: DirectiveAction
    let params: [String: String]
    let isEnabled: Bool
    let createdAt: Date
    let updatedAt: Date
    let lastFiredAt: Date?
    let fireCount: Int
    let localeCode: String

    init(directive: LearnedDirective) {
        id = directive.id
        rawInstruction = directive.rawInstruction
        trigger = directive.trigger
        action = directive.action
        params = directive.params
        isEnabled = directive.isEnabled
        createdAt = directive.createdAt
        updatedAt = directive.updatedAt
        lastFiredAt = directive.lastFiredAt
        fireCount = directive.fireCount
        localeCode = directive.localeCode
    }
}

/// A `Sendable` snapshot of a just-completed workout, handed to the
/// `DirectiveEngine` so the after-workout action can analyze + compare without
/// reaching back into HealthKit.
nonisolated struct DirectiveWorkoutSnapshot: Sendable, Equatable {
    let workoutType: String
    let durationSeconds: Int
    let activeCalories: Double
    let averageHeartRate: Double
    let distanceKm: Double
    let zone2Percent: Double
    let peakPercent: Double
    let endedAt: Date
}
