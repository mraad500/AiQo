import SwiftUI

struct AiQoPlatformPicker<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let subtitle: (Option) -> String
    let systemImage: (Option) -> String
    let accent: (Option) -> Color

    var body: some View {
        HStack(spacing: AiQoSpacing.sm) {
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
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isSelected ? optionAccent : AiQoTheme.Colors.textSecondary)

                        Text(title(option))
                            .font(AiQoTheme.Typography.sectionTitle)
                            .foregroundStyle(AiQoTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(subtitle(option))
                            .font(AiQoTheme.Typography.caption)
                            .foregroundStyle(AiQoTheme.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(AiQoSpacing.md)
                    .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                            .fill(isSelected ? AiQoTheme.Colors.surface : AiQoTheme.Colors.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                            .stroke(isSelected ? optionAccent.opacity(0.8) : AiQoTheme.Colors.border, lineWidth: 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(optionAccent)
                                .padding(AiQoSpacing.sm)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    struct PreviewPlatform: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let subtitleText: String
        let icon: String
        let tint: Color
    }

    let options = [
        PreviewPlatform(name: "Netflix", subtitleText: "Movies and series", icon: "play.rectangle.fill", tint: .red),
        PreviewPlatform(name: "YouTube", subtitleText: "Creators and mixes", icon: "play.tv.fill", tint: .blue)
    ]

    return StatefulPreviewWrapper(options[0]) { selection in
        AiQoPlatformPicker(
            options: options,
            selection: selection,
            title: { $0.name },
            subtitle: { $0.subtitleText },
            systemImage: { $0.icon },
            accent: { $0.tint }
        )
        .padding()
        .background(AiQoTheme.Colors.primaryBackground)
    }
}
