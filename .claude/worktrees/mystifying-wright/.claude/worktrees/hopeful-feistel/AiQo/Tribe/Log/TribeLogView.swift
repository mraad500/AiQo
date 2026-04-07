import SwiftUI

struct TribeLogView: View {
    let events: [TribeEvent]
    let presentationMode: Bool

    private var visibleEvents: [TribeEvent] {
        Array(events.prefix(presentationMode ? 6 : 10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("tribe.log.title".localized)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(TribePalette.textPrimary)

            ForEach(visibleEvents) { event in
                TribeGlassCard(cornerRadius: 24, padding: 14, tint: TribePalette.surfaceMint) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(TribePalette.iconBadge)
                                .frame(width: 38, height: 38)

                            Image(systemName: iconName(for: event.type))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(TribePalette.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.message)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(TribePalette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(event.timestamp, style: .relative)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(TribePalette.textSecondary)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(event.message)
            }
        }
    }

    private func iconName(for type: TribeEventType) -> String {
        switch type {
        case .memberJoined, .join:
            return "person.badge.plus"
        case .spark, .sparkSent:
            return "sparkles"
        case .challengeCompleted, .missionCompleted:
            return "checkmark.seal.fill"
        case .leadChanged:
            return "crown.fill"
        case .challengeSuggested:
            return "lightbulb.max.fill"
        case .contribution:
            return "bolt.fill"
        case .shieldUnlocked:
            return "shield.lefthalf.filled"
        }
    }
}
