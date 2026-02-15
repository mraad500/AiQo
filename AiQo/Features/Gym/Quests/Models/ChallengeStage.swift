import Foundation

struct ChallengeStage: Identifiable, Hashable {
    let number: Int

    var id: Int { number }

    static let all: [ChallengeStage] = (1...6).map { ChallengeStage(number: $0) }
}
