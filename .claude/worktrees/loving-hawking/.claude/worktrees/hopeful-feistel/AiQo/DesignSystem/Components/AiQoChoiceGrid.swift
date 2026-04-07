import SwiftUI

struct AiQoChoiceGrid<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let systemImage: (Option) -> String
    let accent: (Option) -> Color

    private let columns = [
        GridItem(.flexible(), spacing: AiQoSpacing.sm),
        GridItem(.flexible(), spacing: AiQoSpacing.sm)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: AiQoSpacing.sm) {
            ForEach(options) { option in
                let isSelected = option == selection
                let optionAccent = accent(option)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selection = option
                    }
                } label: {
                    VStack(alignment: .leading, spacing: AiQoSpacing.sm) {
                        Image(systemName: systemImage(option))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? optionAccent : AiQoTheme.Colors.textSecondary)

                        Spacer(minLength: 0)

                        Text(title(option))
                            .font(AiQoTheme.Typography.body.weight(.semibold))
                            .foregroundStyle(AiQoTheme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(AiQoSpacing.md)
                    .frame(minHeight: 104)
                    .background(
                        RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous)
                            .fill(isSelected ? AiQoTheme.Colors.surface : AiQoTheme.Colors.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous)
                            .stroke(isSelected ? optionAccent.opacity(0.7) : AiQoTheme.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    struct PreviewChoice: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let icon: String
        let tint: Color
    }

    let options = [
        PreviewChoice(name: "Action", icon: "bolt.fill", tint: .orange),
        PreviewChoice(name: "Comedy", icon: "face.smiling.fill", tint: .yellow),
        PreviewChoice(name: "Inspiration", icon: "figure.run", tint: .mint),
        PreviewChoice(name: "Chill", icon: "moon.stars.fill", tint: .blue)
    ]

    return StatefulPreviewWrapper(options[0]) { selection in
        AiQoChoiceGrid(
            options: options,
            selection: selection,
            title: { $0.name },
            systemImage: { $0.icon },
            accent: { $0.tint }
        )
        .padding()
        .background(AiQoTheme.Colors.primaryBackground)
    }
}
