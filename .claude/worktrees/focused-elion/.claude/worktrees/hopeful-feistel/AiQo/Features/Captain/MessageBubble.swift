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

    private var bubbleColor: Color {
        if isUser {
            return Color(hex: "BCE2C6")
        }

        return Color(hex: "EEDCB2")
    }

    private var textColor: Color {
        Color.black.opacity(0.85)
    }

    var body: some View {
        content
            .foregroundStyle(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(bubbleColor)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}
