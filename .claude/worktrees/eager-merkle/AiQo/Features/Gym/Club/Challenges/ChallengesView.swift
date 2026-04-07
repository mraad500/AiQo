import SwiftUI

struct ChallengesView: View {
    @ObservedObject var questEngine: QuestEngine

    var body: some View {
        BattleChallengesView(questEngine: questEngine)
    }
}
