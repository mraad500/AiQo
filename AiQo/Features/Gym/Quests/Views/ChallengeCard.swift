import SwiftUI

struct ChallengeCard: View {
    let challenge: Challenge
    @ObservedObject var questsStore: QuestDailyStore

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(challenge.awardImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .scaleEffect(1.34)
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
                                .frame(width: geometry.size.width * questsStore.progressFraction(for: challenge))
                        }
                    }
                    .frame(height: 7)
                }
                .padding(.top, 4)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(14)
        .background(cardBackground)
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
        if questsStore.isCompleted(challenge) {
            return L10n.t("quests.status.completed")
        }
        if questsStore.isTracking(challenge) {
            return L10n.t("quests.status.tracking")
        }
        return L10n.t("quests.status.ready")
    }

    private var statusColor: Color {
        if questsStore.isCompleted(challenge) {
            return Color.green
        }
        if questsStore.isTracking(challenge) {
            return Color.orange
        }
        return Color.blue
    }

    private var challengeTint: Color {
        switch challenge.metricType {
        case .steps:
            return GymTheme.mint
        case .plankSeconds:
            return GymTheme.beige
        case .pushups:
            return Color(red: 1.0, green: 0.72, blue: 0.54)
        case .sleepHours:
            return Color(red: 0.74, green: 0.80, blue: 1.0)
        case .activeCalories:
            return Color(red: 0.98, green: 0.64, blue: 0.52)
        case .distanceKilometers:
            return Color(red: 0.64, green: 0.86, blue: 0.98)
        case .questCompletions:
            return GymTheme.gold
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
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(placeholderTint.opacity(0.26))
                    .frame(width: 70, height: 70)

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(placeholderTint)
            }
            .frame(width: 82, height: 82)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Stage \(stageNumber) Quest")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("Coming Soon")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }

                Text("Coming Soon")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(cardBackground)
    }

    private var placeholderTint: Color {
        let palette: [Color] = [
            GymTheme.mint,
            GymTheme.beige,
            Color(red: 1.0, green: 0.72, blue: 0.54),
            Color(red: 0.74, green: 0.80, blue: 1.0),
            Color(red: 0.98, green: 0.64, blue: 0.52)
        ]
        return palette[index % palette.count]
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(placeholderTint.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.34), lineWidth: 0.6)
            )
            .shadow(color: placeholderTint.opacity(0.14), radius: 10, x: 0, y: 6)
    }
}
