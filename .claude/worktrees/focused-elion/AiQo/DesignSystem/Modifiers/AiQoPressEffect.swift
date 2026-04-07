import SwiftUI

// MARK: - ButtonStyle (preferred — works with ScrollView)

/// Use this on `Button` / `NavigationLink` instead of `.buttonStyle(.plain)`.
/// It gives the same 0.92 scale-down + 3D tilt from top without blocking scroll gestures.
/// Matches the workout session StatCard press behavior.
struct AiQoPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .rotation3DEffect(
                .degrees(configuration.isPressed ? 8.0 : 0.0),
                axis: (x: 1, y: 0, z: 0)
            )
            .animation(
                configuration.isPressed
                    ? .spring(response: 0.10, dampingFraction: 0.5)
                    : .spring(response: 1.2, dampingFraction: 0.85),
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
