import SwiftUI

struct ImpactSummaryView: View {
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil

    var body: some View {
        RecapView(onScrollOffsetChange: onScrollOffsetChange)
    }
}
