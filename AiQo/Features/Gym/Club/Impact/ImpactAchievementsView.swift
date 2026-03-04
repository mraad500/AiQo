import SwiftUI

struct ImpactAchievementsView: View {
    @ObservedObject var winsStore: WinsStore
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil

    var body: some View {
        QuestWinsGridView(
            winsStore: winsStore,
            onScrollOffsetChange: onScrollOffsetChange
        )
    }
}
