import SwiftUI

// MARK: - Floating Profile Button (Unified)

struct FloatingProfileButton: View {
    var size: CGFloat = 50
    var action: () -> Void
    @State private var feedbackTrigger = 0

    var body: some View {
        Button {
            feedbackTrigger += 1
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.12), Color.gray.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size - 6, height: size - 6)

                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .buttonStyle(FloatingPressStyle())
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
    }
}

struct FloatingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.snappy(duration: 0.25, extraBounce: 0.06), value: configuration.isPressed)
    }
}
