import SwiftUI

struct MessageBubble<Content: View>: View {
    let isUser: Bool
    private let content: Content

    init(
        isUser: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.isUser = isUser
        self.content = content()
    }

    // CHANGED: Captain bubble now uses sand/beige #EBCF97 at 35% opacity; user bubble uses mint #B7E5D2
    private var bubbleColor: Color {
        if isUser {
            return Color(hex: "B7E5D2")
        }

        return Color(hex: "EBCF97").opacity(0.35)
    }

    private var textColor: Color {
        Color.black.opacity(0.85)
    }

    // CHANGED: Corner radius 20pt with bottom-leading corner at 4pt for captain (RTL: bottom-leading = tail side)
    private var bubbleCorners: UnevenRoundedRectangle {
        if isUser {
            // User bubble: small corner on bottom-trailing (user's tail side in RTL)
            return UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 20,
                bottomTrailingRadius: 4,
                topTrailingRadius: 20
            )
        } else {
            // Captain bubble: small corner on bottom-leading (captain's tail side in RTL)
            return UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 4,
                bottomTrailingRadius: 20,
                topTrailingRadius: 20
            )
        }
    }

    var body: some View {
        content
            .foregroundStyle(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                // CHANGED: Use uneven rounded rectangle for directional tail corners
                bubbleCorners
                    .fill(bubbleColor)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
