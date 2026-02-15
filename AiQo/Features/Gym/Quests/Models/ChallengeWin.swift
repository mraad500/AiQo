import Foundation

struct ChallengeWin: Identifiable, Codable, Hashable {
    let id: UUID
    let challengeId: String
    let title: String
    let completedAt: Date
    let proofValue: String
    let awardImageName: String

    init(
        id: UUID = UUID(),
        challengeId: String,
        title: String,
        completedAt: Date,
        proofValue: String,
        awardImageName: String
    ) {
        self.id = id
        self.challengeId = challengeId
        self.title = title
        self.completedAt = completedAt
        self.proofValue = proofValue
        self.awardImageName = awardImageName
    }
}

struct PendingChallengeReward: Identifiable, Hashable {
    let id = UUID()
    let challenge: Challenge
    let completedAt: Date
    let proofValue: String
}
