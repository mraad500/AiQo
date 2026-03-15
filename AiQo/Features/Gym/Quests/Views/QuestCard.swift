import SwiftUI

struct QuestCard: View {
    let quest: QuestDefinition
    let progress: QuestCardProgressModel
    let isLocked: Bool
    let referenceDate: Date
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(quest.rewardImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 102, height: 102)

            VStack(alignment: .leading, spacing: 7) {
                Text(quest.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)

                Text(questLevelsText(for: quest))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(pillText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())

                    Text(progressText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.78))
                }

                ProgressView(value: min(progress.completionFraction, 1))
                    .tint(Color(red: 0.35, green: 0.43, blue: 0.95))
                    .scaleEffect(y: 1.1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 158)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardTint)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 0.9)
                )
                .shadow(
                    color: colorScheme == .dark ? .clear : cardTint.opacity(0.14),
                    radius: 10,
                    x: 0,
                    y: 6
                )
        )
        .overlay(alignment: .topTrailing) {
            if isLocked {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                    Text(questLocalizedText("quests.common.locked"))
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(uiColor: .systemBackground).opacity(0.94), in: Capsule())
                .overlay(Capsule().stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1))
                .padding(12)
            }
        }
        .opacity(isLocked ? 0.78 : 1)
    }

    private var progressText: String {
        questProgressText(for: quest, progress: progress)
    }

    private var pillText: String {
        if quest.stageIndex == 1 {
            return questStageOneCenterPillText(for: progress)
        }

        return String(
            format: L10n.t("quests.common.tier_format"),
            locale: Locale.current,
            progress.tier
        )
    }

    private var cardTint: Color {
        quest.stageIndex.isMultiple(of: 2) ? GymTheme.beige : GymTheme.mint
    }
}
