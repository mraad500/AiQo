import SwiftUI

/// Standard AiQo sheet presentation style.
struct AiQoSheetStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
    }
}

extension View {
    func aiQoSheetStyle() -> some View {
        modifier(AiQoSheetStyle())
    }
}
