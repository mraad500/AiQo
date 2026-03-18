import SwiftUI

struct ChallengesView: View {
    @ObservedObject var questEngine: QuestEngine

    var body: some View {
        QuestsView(engine: questEngine)
    }
}
