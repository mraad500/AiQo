import Foundation

struct ChallengeStage: Identifiable, Hashable {
    let number: Int

    var id: Int { number }

    static var all: [ChallengeStage] {
        Challenge.availableStageNumbers.map { ChallengeStage(number: $0) }
    }
}
