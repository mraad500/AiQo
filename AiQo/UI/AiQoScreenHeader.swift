import SwiftUI

enum AiQoScreenHeaderMetrics {
    static let horizontalInset: CGFloat = 20
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 10
    static let itemSpacing: CGFloat = 12
    static let profileLaneWidth: CGFloat = AiQoProfileButtonLayout.reservedLaneWidth
}

struct AiQoScreenTopChrome<Content: View>: View {
    private let leadingReservedWidth: CGFloat
    private let itemSpacing: CGFloat
    private let horizontalInset: CGFloat
    private let topPadding: CGFloat
    private let bottomPadding: CGFloat
    private let contentMaxWidth: CGFloat?
    private let contentAlignment: Alignment
    private let onProfileTap: () -> Void
    private let content: Content

    init(
        leadingReservedWidth: CGFloat = 0,
        itemSpacing: CGFloat = AiQoScreenHeaderMetrics.itemSpacing,
        horizontalInset: CGFloat = AiQoScreenHeaderMetrics.horizontalInset,
        topPadding: CGFloat = AiQoScreenHeaderMetrics.topPadding,
        bottomPadding: CGFloat = AiQoScreenHeaderMetrics.bottomPadding,
        contentMaxWidth: CGFloat? = nil,
        contentAlignment: Alignment = .leading,
        onProfileTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.leadingReservedWidth = leadingReservedWidth
        self.itemSpacing = itemSpacing
        self.horizontalInset = horizontalInset
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.contentMaxWidth = contentMaxWidth
        self.contentAlignment = contentAlignment
        self.onProfileTap = onProfileTap
        self.content = content()
    }

    var body: some View {
        HStack(spacing: itemSpacing) {
            if leadingReservedWidth > 0 {
                Color.clear
                    .frame(width: leadingReservedWidth, height: 1)
            }

            content
                .frame(maxWidth: contentMaxWidth ?? .infinity, alignment: contentAlignment)
                .frame(maxWidth: .infinity, alignment: contentAlignment)

            AiQoProfileButton(action: onProfileTap)
                .frame(width: AiQoScreenHeaderMetrics.profileLaneWidth, alignment: .trailing)
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, horizontalInset)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }
}
