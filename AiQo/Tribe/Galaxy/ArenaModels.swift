import SwiftData
import Foundation

// MARK: - القبيلة

@Model
final class ArenaTribe {
    @Attribute(.unique) var id: UUID
    var name: String
    var creatorUserID: String
    var inviteCode: String
    var members: [ArenaTribeMember]
    var createdAt: Date
    var isActive: Bool
    var isFrozen: Bool
    var frozenAt: Date?

    init(name: String, creatorUserID: String) {
        self.id = UUID()
        self.name = name
        self.creatorUserID = creatorUserID
        self.inviteCode = ArenaTribe.generateInviteCode()
        self.members = []
        self.createdAt = Date()
        self.isActive = true
        self.isFrozen = false
        self.frozenAt = nil
    }

    static func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let random = (0..<4).map { _ in chars.randomElement() ?? Character("A") }
        return "AQ-\(String(random))"
    }

    var isFull: Bool { members.count >= 5 }
}

// MARK: - عضو القبيلة

@Model
final class ArenaTribeMember {
    @Attribute(.unique) var id: UUID
    var userID: String
    var displayName: String
    var initials: String
    var joinedAt: Date
    var isCreator: Bool

    var tribe: ArenaTribe?

    init(userID: String, displayName: String, initials: String, isCreator: Bool = false) {
        self.id = UUID()
        self.userID = userID
        self.displayName = displayName
        self.initials = initials
        self.joinedAt = Date()
        self.isCreator = isCreator
    }
}

// MARK: - نوع معيار التحدي

enum ArenaChallengeMetric: String, Codable, CaseIterable {
    case avgWorkoutDays = "avg_workout_days"
    case avgSteps = "avg_steps"
    case avgSleepScore = "avg_sleep_score"
    case consistency = "consistency"
    case avgCalories = "avg_calories"

    var displayName: String {
        switch self {
        case .avgWorkoutDays: return "معدل أيام التمرين"
        case .avgSteps: return "معدل الخطوات"
        case .avgSleepScore: return "معدل جودة النوم"
        case .consistency: return "أكثر التزام"
        case .avgCalories: return "معدل السعرات المحروقة"
        }
    }

    var icon: String {
        switch self {
        case .avgWorkoutDays: return "figure.run"
        case .avgSteps: return "figure.walk"
        case .avgSleepScore: return "moon.zzz.fill"
        case .consistency: return "flame.fill"
        case .avgCalories: return "bolt.fill"
        }
    }
}

// MARK: - التحدي الأسبوعي

@Model
final class ArenaWeeklyChallenge {
    @Attribute(.unique) var id: UUID
    var title: String
    var descriptionText: String
    var metric: ArenaChallengeMetric
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    var participations: [ArenaTribeParticipation]

    init(title: String, descriptionText: String, metric: ArenaChallengeMetric, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.title = title
        self.descriptionText = descriptionText
        self.metric = metric
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = true
        self.participations = []
    }

    var timeRemaining: TimeInterval { endDate.timeIntervalSince(Date()) }
    var isExpired: Bool { Date() > endDate }
}

// MARK: - مشاركة القبيلة بالتحدي

@Model
final class ArenaTribeParticipation {
    @Attribute(.unique) var id: UUID
    var tribe: ArenaTribe?
    var challenge: ArenaWeeklyChallenge?
    var currentScore: Double
    var rank: Int
    var joinedAt: Date

    init(currentScore: Double = 0, rank: Int = 0) {
        self.id = UUID()
        self.currentScore = currentScore
        self.rank = rank
        self.joinedAt = Date()
    }
}

// MARK: - قادة الإمارة

@Model
final class ArenaEmirateLeaders {
    @Attribute(.unique) var id: UUID
    var tribe: ArenaTribe?
    var challenge: ArenaWeeklyChallenge?
    var weekNumber: Int
    var startDate: Date
    var endDate: Date
    var isDefending: Bool

    init(weekNumber: Int, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.weekNumber = weekNumber
        self.startDate = startDate
        self.endDate = endDate
        self.isDefending = false
    }
}

// MARK: - سجل الأمجاد

@Model
final class ArenaHallOfFameEntry {
    @Attribute(.unique) var id: UUID
    var weekNumber: Int
    var tribeName: String
    var challengeTitle: String
    var date: Date

    init(weekNumber: Int, tribeName: String, challengeTitle: String, date: Date) {
        self.id = UUID()
        self.weekNumber = weekNumber
        self.tribeName = tribeName
        self.challengeTitle = challengeTitle
        self.date = date
    }
}
