import SwiftUI

struct AiQoBottomCTA: View {
    let title: String
    let systemImage: String?
    let isEnabled: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        VStack(spacing: AiQoSpacing.sm) {
            Button(action: action) {
                HStack(spacing: AiQoSpacing.sm) {
                    if let systemImage {
                        Image(systemName: systemImage)
                    }
                    Text(title)
                }
                .font(AiQoTheme.Typography.cta)
                .foregroundStyle(.black.opacity(isEnabled ? 0.88 : 0.45))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .background(
                    LinearGradient(
                        colors: [AiQoTheme.Colors.ctaGradientLeading, AiQoTheme.Colors.ctaGradientTrailing],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.7)
        }
        .padding(AiQoSpacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AiQoRadius.ctaContainer, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AiQoRadius.ctaContainer, style: .continuous)
                .stroke(AiQoTheme.Colors.borderStrong, lineWidth: 1)
        )
        .padding(.horizontal, AiQoSpacing.md)
        .padding(.top, AiQoSpacing.xs)
        .padding(.bottom, AiQoSpacing.sm)
    }
}

#Preview {
    AiQoBottomCTA(title: "ابدأ الغرايند", systemImage: "play.fill") {}
        .background(AiQoTheme.Colors.primaryBackground)
}
