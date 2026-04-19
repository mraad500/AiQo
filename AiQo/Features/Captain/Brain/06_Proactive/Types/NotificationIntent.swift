import Foundation

/// Request to NotificationBrain for a user-facing notification.
/// Every source (legacy or new) funnels through this type.
public struct NotificationIntent: Sendable, Identifiable {
    public let id: UUID
    public let kind: NotificationKind
    public let priority: Priority
    public let signals: IntentSignals
    public let requestedBy: String       // caller identifier for debugging
    public let requestedAt: Date
    public let expiresAt: Date?          // null = no expiration

    public init(
        id: UUID = UUID(),
        kind: NotificationKind,
        priority: Priority = .medium,
        signals: IntentSignals = .empty,
        requestedBy: String,
        requestedAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.priority = priority
        self.signals = signals
        self.requestedBy = requestedBy
        self.requestedAt = requestedAt
        self.expiresAt = expiresAt
    }

    /// True if the intent has expired and should be dropped silently.
    public func isExpired(now: Date = Date()) -> Bool {
        if let exp = expiresAt, now > exp { return true }
        return false
    }
}

public enum NotificationKind: String, Sendable, Codable, CaseIterable {
    // Health
    case morningKickoff
    case sleepDebtAcknowledgment
    case inactivityNudge
    case personalRecord
    case recoveryReminder

    // Behavioral
    case streakRisk
    case streakSave
    case disengagement
    case engagementMomentum

    // Memory (the magic)
    case memoryCallback

    // Emotional
    case emotionalFollowUp
    case moodShift
    case relationshipCheckIn

    // Temporal / Cultural
    case weeklyInsight
    case monthlyReflection
    case ramadanMindful
    case eidCelebration
    case jumuahSpecial
    case circadianNudge
    case weatherAdaptive

    // Lifecycle
    case trialDay
    case achievementUnlocked

    // Workout
    case workoutSummary
}

public enum Priority: Int, Sendable, Codable, Comparable {
    case ambient  = 0    // background info
    case low      = 1    // streak reminder
    case medium   = 2    // normal nudges
    case high     = 3    // memory callback, PR
    case critical = 4    // wellbeing / safety

    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Optional signals attached to an intent for ranking and composition.
public struct IntentSignals: Sendable, Codable {
    public let memoryFactID: UUID?       // which fact to callback
    public let bioSnapshotSummary: String?
    public let emotionSummary: String?
    public let customPayload: [String: String]

    public init(
        memoryFactID: UUID? = nil,
        bioSnapshotSummary: String? = nil,
        emotionSummary: String? = nil,
        customPayload: [String: String] = [:]
    ) {
        self.memoryFactID = memoryFactID
        self.bioSnapshotSummary = bioSnapshotSummary
        self.emotionSummary = emotionSummary
        self.customPayload = customPayload
    }

    public static let empty = IntentSignals()
}
