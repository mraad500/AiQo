import SwiftUI

struct ImpactAchievementsView: View {
    @ObservedObject var winsStore: WinsStore

    var body: some View {
        QuestWinsGridView(winsStore: winsStore)
    }
}
