import SwiftUI

struct QuestCardView: View {
    let challenge: Challenge
    let state: QuestCardState
    @ObservedObject var questsStore: QuestDailyStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(challenge.awardImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .scaleEffect(awardImageScale)
                .clipped()
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(challenge.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    statusBadge
                }

                Text(challenge.subtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(challenge.description)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if challenge.showsProgressOnCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(questsStore.progressText(for: challenge))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.35))

                                Capsule()
                                    .fill(challengeTint)
                                    .frame(width: geometry.size.width * progressFraction)
                            }
                        }
                        .frame(height: 7)
                    }
                    .padding(.top, 4)
                }
            }

            Image(systemName: state == .locked ? "lock.fill" : "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var progressFraction: Double {
        if state == .locked {
            return 0
        }
        return questsStore.progressFraction(for: challenge)
    }

    private var statusBadge: some View {
        Text(statusText)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.16), in: Capsule())
    }

    private var statusText: String {
        switch state {
        case .locked:
            return L10n.t("quests.status.locked")
        case .ready:
            return L10n.t("quests.status.ready")
        case .tracking:
            return L10n.t("quests.status.tracking")
        case .completed:
            return L10n.t("quests.status.completed")
        }
    }

    private var statusColor: Color {
        switch state {
        case .locked:
            return Color.gray
        case .ready:
            return Color.blue
        case .tracking:
            return Color.orange
        case .completed:
            return Color.green
        }
    }

    private var challengeTint: Color {
        switch challenge.metricType {
        case .steps, .kindnessActs:
            return GymTheme.mint
        case .plankSeconds:
            return GymTheme.beige
        case .pushups:
            return Color(red: 1.0, green: 0.72, blue: 0.54)
        case .sleepHours, .sleepStreakDays:
            return Color(red: 0.74, green: 0.80, blue: 1.0)
        case .activeCalories:
            return Color(red: 0.98, green: 0.64, blue: 0.52)
        case .distanceKilometers:
            return Color(red: 0.64, green: 0.86, blue: 0.98)
        case .questCompletions:
            return GymTheme.gold
        case .zone2Minutes:
            return Color(red: 0.45, green: 0.80, blue: 0.62)
        case .mindfulnessSessions:
            return Color(red: 0.64, green: 0.78, blue: 0.94)
        }
    }

    private var awardImageScale: CGFloat {
        switch challenge.id {
        case "s1_help_3_strangers", "s1_zone2_guardian", "s1_recovery_boss":
            return 1.0
        default:
            return 1.36
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(challengeTint.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 0.6)
            )
            .shadow(color: challengeTint.opacity(0.16), radius: 10, x: 0, y: 6)
    }
}

struct ChallengePlaceholderCard: View {
    let stageNumber: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(GymTheme.mint)
                .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 6) {
                Text(
                    String(
                        format: L10n.t("quests.placeholder.stage_title"),
                        locale: Locale.current,
                        stageNumber
                    )
                )
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(L10n.t("quests.placeholder.empty"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(GymTheme.mint.opacity(0.16))
                )
        )
    }
}
