import SwiftUI

struct AiQoCard: View {
    enum IconPlacement {
        case visualLeading
        case leading
        case trailing
    }

    @Environment(\.layoutDirection) private var layoutDirection

    let title: String
    let subtitle: String?
    let badge: String?
    let systemImage: String?
    let accent: Color
    let iconPlacement: IconPlacement
    let action: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        systemImage: String? = nil,
        accent: Color = AiQoTheme.Colors.accent,
        iconPlacement: IconPlacement = .visualLeading,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.systemImage = systemImage
        self.accent = accent
        self.iconPlacement = iconPlacement
        self.action = action
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var content: some View {
        HStack(spacing: AiQoSpacing.md) {
            if shouldShowIconFirst {
                iconView
            }

            VStack(alignment: .leading, spacing: AiQoSpacing.xs) {
                HStack(spacing: AiQoSpacing.sm) {
                    Text(title)
                        .font(AiQoTheme.Typography.cardTitle)
                        .foregroundStyle(AiQoTheme.Colors.textPrimary)
                        .lineLimit(2)

                    if let badge {
                        Text(badge)
                            .font(AiQoTheme.Typography.caption.weight(.semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, AiQoSpacing.xs)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.12), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(accent.opacity(0.2), lineWidth: 1)
                            )
                            .fixedSize()
                    }
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AiQoTheme.Typography.body)
                        .foregroundStyle(AiQoTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !shouldShowIconFirst {
                iconView
            }
        }
        .padding(AiQoSpacing.md)
        .frame(minHeight: 96)
        .background(AiQoTheme.Colors.surface, in: RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous)
                .stroke(AiQoTheme.Colors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: AiQoRadius.card, style: .continuous))
    }

    @ViewBuilder
    private var iconView: some View {
        if let systemImage {
            ZStack {
                RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous)
                    .fill(AiQoTheme.Colors.iconBackground)

                RoundedRectangle(cornerRadius: AiQoRadius.control, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .flipsForRightToLeftLayoutDirection(false)
            }
            .frame(width: 52, height: 52)
            .accessibilityHidden(true)
        }
    }

    private var shouldShowIconFirst: Bool {
        switch iconPlacement {
        case .leading:
            return true
        case .trailing:
            return false
        case .visualLeading:
            return layoutDirection == .leftToRight
        }
    }

    private var accessibilityLabel: Text {
        var parts = [title]

        if let subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }

        if let badge, !badge.isEmpty {
            parts.append(badge)
        }

        return Text(parts.joined(separator: ", "))
    }
}

#Preview("Card LTR") {
    AiQoCard(
        title: "Cinema Cardio",
        subtitle: "Zone 2 while watching",
        badge: "Cinema",
        systemImage: "popcorn.fill",
        accent: .mint
    )
    .padding()
    .background(AiQoTheme.Colors.primaryBackground)
}

#Preview("Card RTL") {
    AiQoCard(
        title: "سينماتك غرايند",
        subtitle: "زون 2 وإنت تشوف",
        badge: "سينما",
        systemImage: "popcorn.fill",
        accent: .mint
    )
    .padding()
    .background(AiQoTheme.Colors.primaryBackground)
    .environment(\.layoutDirection, .rightToLeft)
}
