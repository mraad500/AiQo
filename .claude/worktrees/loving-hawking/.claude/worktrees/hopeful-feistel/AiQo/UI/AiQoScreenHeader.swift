import SwiftUI

enum AiQoScreenHeaderMetrics {
    static let horizontalInset: CGFloat = 20
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 10
    static let itemSpacing: CGFloat = 12
    static let profileLaneWidth: CGFloat = AiQoProfileButtonLayout.reservedLaneWidth
}

struct AiQoScreenTopChrome<Content: View, Trailing: View>: View {
    private let leadingReservedWidth: CGFloat
    private let itemSpacing: CGFloat
    private let horizontalInset: CGFloat
    private let topPadding: CGFloat
    private let bottomPadding: CGFloat
    private let profileVerticalOffset: CGFloat
    private let contentMaxWidth: CGFloat?
    private let contentAlignment: Alignment
    private let trailing: Trailing
    private let content: Content

    init(
        leadingReservedWidth: CGFloat = 0,
        itemSpacing: CGFloat = AiQoScreenHeaderMetrics.itemSpacing,
        horizontalInset: CGFloat = AiQoScreenHeaderMetrics.horizontalInset,
        topPadding: CGFloat = AiQoScreenHeaderMetrics.topPadding,
        bottomPadding: CGFloat = AiQoScreenHeaderMetrics.bottomPadding,
        profileVerticalOffset: CGFloat = 0,
        contentMaxWidth: CGFloat? = nil,
        contentAlignment: Alignment = .leading,
        onProfileTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) where Trailing == AiQoProfileButton {
        self.leadingReservedWidth = leadingReservedWidth
        self.itemSpacing = itemSpacing
        self.horizontalInset = horizontalInset
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.profileVerticalOffset = profileVerticalOffset
        self.contentMaxWidth = contentMaxWidth
        self.contentAlignment = contentAlignment
        self.trailing = AiQoProfileButton(action: onProfileTap)
        self.content = content()
    }

    init(
        leadingReservedWidth: CGFloat = 0,
        itemSpacing: CGFloat = AiQoScreenHeaderMetrics.itemSpacing,
        horizontalInset: CGFloat = AiQoScreenHeaderMetrics.horizontalInset,
        topPadding: CGFloat = AiQoScreenHeaderMetrics.topPadding,
        bottomPadding: CGFloat = AiQoScreenHeaderMetrics.bottomPadding,
        profileVerticalOffset: CGFloat = 0,
        contentMaxWidth: CGFloat? = nil,
        contentAlignment: Alignment = .leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.leadingReservedWidth = leadingReservedWidth
        self.itemSpacing = itemSpacing
        self.horizontalInset = horizontalInset
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.profileVerticalOffset = profileVerticalOffset
        self.contentMaxWidth = contentMaxWidth
        self.contentAlignment = contentAlignment
        self.trailing = trailing()
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

            trailing
                .offset(y: profileVerticalOffset)
                .frame(width: AiQoScreenHeaderMetrics.profileLaneWidth, alignment: .trailing)
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, horizontalInset)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }
}
