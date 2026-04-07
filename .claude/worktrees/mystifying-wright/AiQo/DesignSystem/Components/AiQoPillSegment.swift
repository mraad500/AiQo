import SwiftUI

struct AiQoPillSegment<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let subtitle: ((Option) -> String?)?
    let accent: Color

    @Namespace private var selectionAnimation

    init(
        options: [Option],
        selection: Binding<Option>,
        accent: Color = AiQoTheme.Colors.accent,
        title: @escaping (Option) -> String,
        subtitle: ((Option) -> String?)? = nil
    ) {
        self.options = options
        _selection = selection
        self.accent = accent
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AiQoSpacing.sm) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selection

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selection = option
                        }
                    } label: {
                        HStack(spacing: AiQoSpacing.xs) {
                            Text(title(option))
                                .font(AiQoTheme.Typography.sectionTitle)
                                .foregroundStyle(isSelected ? AiQoTheme.Colors.textPrimary : AiQoTheme.Colors.textSecondary)

                            if let subtitle = subtitle?(option), !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(AiQoTheme.Typography.caption.weight(.medium))
                                    .foregroundStyle(AiQoTheme.Colors.textSecondary)
                            }
                        }
                        .frame(minHeight: 48)
                        .padding(.horizontal, AiQoSpacing.md)
                        .background(
                            Capsule()
                                .fill(isSelected ? AiQoTheme.Colors.surface : AiQoTheme.Colors.surfaceSecondary)
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? accent.opacity(0.7) : AiQoTheme.Colors.border, lineWidth: 1)
                        )
                        .overlay {
                            if isSelected {
                                Capsule()
                                    .stroke(accent.opacity(0.22), lineWidth: 4)
                                    .blur(radius: 10)
                                    .matchedGeometryEffect(id: "selectionGlow", in: selectionAnimation)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    StatefulPreviewWrapper(45) { selection in
        AiQoPillSegment(
            options: [30, 45, 60],
            selection: selection,
            title: { "\($0)" },
            subtitle: { _ in "min" }
        )
        .padding()
        .background(AiQoTheme.Colors.primaryBackground)
    }
}
