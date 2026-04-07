import SwiftUI

/// Consistent card shadow that adapts to light/dark mode.
struct AiQoShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.shadow(
            color: scheme == .dark
                ? .black.opacity(0.18)
                : .black.opacity(0.06),
            radius: 16,
            x: 0,
            y: 7
        )
    }
}

extension View {
    func aiQoShadow() -> some View {
        modifier(AiQoShadow())
    }
}
