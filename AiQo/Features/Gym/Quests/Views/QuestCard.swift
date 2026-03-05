import SwiftUI

struct QuestCard: View {
    let quest: QuestDefinition
    let progress: QuestCardProgressModel
    let isLocked: Bool
    let referenceDate: Date
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            Image(quest.rewardImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 108, height: 108)

            VStack(alignment: .leading, spacing: 8) {
                Text(quest.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)

                if quest.source == .camera {
                    Text(questLocalizedText("quests.card.camera_required"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.40, blue: 0.96))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.25, green: 0.40, blue: 0.96).opacity(0.12), in: Capsule())
                }

                Text(levelsLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary)

                Text(questLevelsText(for: quest))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.82))

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

                if let nextTargetText {
                    Text(nextTargetText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }

                if let contextText {
                    Text(contextText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.9))
                        .lineLimit(quest.id == "s1q3" ? 1 : nil)
                }

                ProgressView(value: min(progress.completionFraction, 1))
                    .tint(Color(red: 0.35, green: 0.43, blue: 0.95))
                    .scaleEffect(y: 1.1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 166)
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

    private var levelsLabel: String {
        quest.stageIndex == 1 ? "المراكز" : questLocalizedText("quests.card.levels")
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

    private var nextTargetText: String? {
        guard quest.stageIndex == 1 else { return nil }
        return questStageOneNextTargetText(for: quest, progress: progress)
    }

    private var contextText: String? {
        guard quest.stageIndex == 1 else { return nil }
        return questStageOneContextText(for: quest, now: referenceDate)
    }

    private var cardTint: Color {
        quest.stageIndex.isMultiple(of: 2) ? GymTheme.beige : GymTheme.mint
    }
}
