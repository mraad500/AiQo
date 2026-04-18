import Foundation
import SwiftData

enum PatternKind: String, Codable {
    case workoutTime
    case sleepSchedule
    case eatingWindow
    case disengagementCycle
    case socialHours
    case moodByDayOfWeek
    case preferredIntensity
    case recoveryRhythm
    case stressResponse
    case celebrationStyle
}

@Model
final class ProceduralPattern {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var patternDescription: String
    var strength: Double
    var observationCount: Int
    var firstObservedAt: Date
    var lastObservedAt: Date
    var contextualDataJSON: Data?
    var exceptionsCount: Int

    init(
        id: UUID = UUID(),
        kind: PatternKind,
        description: String,
        strength: Double,
        observationCount: Int = 1,
        firstObservedAt: Date = Date()
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.patternDescription = description
        self.strength = strength
        self.observationCount = observationCount
        self.firstObservedAt = firstObservedAt
        self.lastObservedAt = firstObservedAt
        self.exceptionsCount = 0
    }

    var kind: PatternKind {
        PatternKind(rawValue: kindRaw) ?? .workoutTime
    }
}
