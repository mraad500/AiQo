import Foundation

struct WinRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let challengeId: String
    let title: String
    let completedAt: Date
    let completedDayKey: String
    let proofValue: String
    let awardImageName: String
    let isBoss: Bool

    init(
        id: UUID = UUID(),
        challengeId: String,
        title: String,
        completedAt: Date,
        completedDayKey: String? = nil,
        proofValue: String,
        awardImageName: String,
        isBoss: Bool = false
    ) {
        self.id = id
        self.challengeId = challengeId
        self.title = title
        self.completedAt = completedAt
        self.completedDayKey = completedDayKey ?? Self.dayKey(for: completedAt)
        self.proofValue = proofValue
        self.awardImageName = awardImageName
        self.isBoss = isBoss
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case challengeId
        case title
        case completedAt
        case completedDayKey
        case proofValue
        case awardImageName
        case isBoss
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        challengeId = try container.decode(String.self, forKey: .challengeId)
        title = try container.decode(String.self, forKey: .title)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        completedDayKey = try container.decodeIfPresent(String.self, forKey: .completedDayKey)
            ?? Self.dayKey(for: completedAt)
        proofValue = try container.decode(String.self, forKey: .proofValue)
        awardImageName = try container.decode(String.self, forKey: .awardImageName)
        isBoss = try container.decodeIfPresent(Bool.self, forKey: .isBoss) ?? false
    }

    private static func dayKey(for date: Date) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startOfDay)
    }
}

struct PendingChallengeReward: Identifiable, Hashable {
    let id = UUID()
    let challenge: Challenge
    let completedAt: Date
    let completedDayKey: String
    let proofValue: String
    let isBoss: Bool
}
