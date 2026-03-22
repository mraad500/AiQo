import SwiftUI

/// Subtle press-down scale effect for all tappable AiQo elements.
struct AiQoPressEffect: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(
                .spring(response: 0.12, dampingFraction: 0.5),
                value: isPressed
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

extension View {
    func aiQoPressEffect() -> some View {
        modifier(AiQoPressEffect())
    }
}
