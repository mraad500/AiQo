import SwiftUI

// MARK: - ButtonStyle (preferred — works with ScrollView)

/// Use this on `Button` / `NavigationLink` instead of `.buttonStyle(.plain)`.
/// It gives the same 0.96 scale-down without blocking scroll gestures.
struct AiQoPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(
                .spring(response: 0.12, dampingFraction: 0.5),
                value: configuration.isPressed
            )
    }
}

// MARK: - Legacy modifier (kept for non-button views)

/// Subtle press-down scale effect. Prefer `AiQoPressButtonStyle` inside ScrollView.
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
                LongPressGesture(minimumDuration: 0.15)
                    .updating($isPressed) { value, state, _ in
                        state = value
                    }
            )
    }
}

extension View {
    func aiQoPressEffect() -> some View {
        modifier(AiQoPressEffect())
    }
}
