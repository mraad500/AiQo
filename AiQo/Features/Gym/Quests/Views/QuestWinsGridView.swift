import SwiftUI

struct QuestWinsGridView: View {
    @ObservedObject var winsStore: WinsStore
    var onScrollOffsetChange: ((CGFloat) -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 0)
    ]
    private let railScrollOffsetSpaceName = "QuestWinsRailScroll"
    @State private var questAchievements: [QuestEarnedAchievement] = []

    var body: some View {
        let visibleWins = winsStore.wins.filter { !isHiddenWin($0) }

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("wins.title"))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))

                // Quest achievements section
                if !questAchievements.isEmpty {
                    ForEach(questAchievements) { achievement in
                        QuestAchievementCard(achievement: achievement)
                    }
                }

                if visibleWins.isEmpty, questAchievements.isEmpty {
                    emptyState
                } else if !visibleWins.isEmpty {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Array(visibleWins.enumerated()), id: \.element.id) { index, win in
                            WinAwardCard(win: win, useMint: index.isMultiple(of: 2))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
            .background(alignment: .top) {
                RailScrollOffsetReader(coordinateSpaceName: railScrollOffsetSpaceName)
            }
        }
        .coordinateSpace(name: railScrollOffsetSpaceName)
        .onPreferenceChange(RailScrollOffsetPreferenceKey.self) { offset in
            onScrollOffsetChange?(offset)
        }
        .task {
            questAchievements = QuestAchievementStore.load().sorted(by: { $0.earnedDate > $1.earnedDate })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "DDDDDD"))
            Text("ما عندك إنجازات بعد")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: "999999"))
            Text("أكمل تحديات قِمَم عشان تحصل على جوائز")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "AAAAAA"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func isHiddenWin(_ win: WinRecord) -> Bool {
        if win.challengeId == "sleep_8h" {
            return true
        }
        if win.challengeId == "active_kcal_600" {
            return true
        }
        guard let challenge = Challenge.all.first(where: { $0.id == win.challengeId }) else {
            return false
        }
        return challenge.metricType == .sleepHours
    }
}

private struct WinAwardCard: View {
    let win: WinRecord
    var useMint: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(win.awardImageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 142)
                .scaleEffect(1.22)
                .clipped()

            Text(localizedTitle)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .lineLimit(2)

            Text(Self.dateFormatter.string(from: win.completedAt))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(localizedProofValue)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 234, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    useMint
                        ? LinearGradient(colors: [Color(hex: "E8F7F0"), Color(hex: "D4F0E3")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(hex: "F7EDD8"), Color(hex: "EBCF97"), Color(hex: "F0DFB8")], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var localizedTitle: String {
        Challenge.all.first(where: { $0.id == win.challengeId })?.title ?? win.title
    }

    private var localizedProofValue: String {
        guard let challenge = Challenge.all.first(where: { $0.id == win.challengeId }) else {
            return win.proofValue
        }

        let numericValue = extractedNumericValue

        switch challenge.metricType {
        case .sleepHours:
            let value = numericValue ?? 0
            return "\(L10n.t("quests.metric.sleep")): \(String(format: "%.1f", locale: Locale.current, value)) \(L10n.t("quests.unit.h"))"
        case .steps:
            return "\(L10n.t("quests.metric.steps")): \(Int((numericValue ?? 0).rounded()))"
        case .plankSeconds:
            return "\(L10n.t("quests.metric.plank")): \(Int((numericValue ?? 0).rounded())) \(L10n.t("quests.unit.sec"))"
        case .pushups:
            return "\(L10n.t("quests.metric.pushups")): \(Int((numericValue ?? 0).rounded())) \(L10n.t("quests.unit.reps"))"
        case .activeCalories:
            return "\(L10n.t("quests.metric.active")): \(Int((numericValue ?? 0).rounded())) \(L10n.t("quests.unit.kcal"))"
        case .distanceKilometers:
            let value = numericValue ?? 0
            return "\(L10n.t("quests.metric.distance")): \(String(format: "%.1f", locale: Locale.current, value)) \(L10n.t("quests.unit.km"))"
        case .questCompletions:
            let fallbackTarget = max(Challenge.nonBossChallenges(forStage: challenge.stageNumber).count, Int(challenge.goalValue.rounded()))
            let ratio = extractedRatio ?? (Int((numericValue ?? 0).rounded()), fallbackTarget)
            return "\(L10n.t("quests.metric.stage2")): \(ratio.0)/\(ratio.1) \(L10n.t("quests.unit.quests"))"
        case .kindnessActs:
            return "\(L10n.t("quests.metric.kindness")): \(Int((numericValue ?? 0).rounded())) \(L10n.t("quests.unit.helps"))"
        case .zone2Minutes:
            return "\(L10n.t("quests.metric.zone2")): \(Int((numericValue ?? 0).rounded())) \(L10n.t("quests.unit.min"))"
        case .mindfulnessSessions:
            return "\(L10n.t("quests.metric.mindfulness")): \(Int((numericValue ?? 0).rounded())) \(L10n.t("quests.unit.sessions"))"
        case .sleepStreakDays:
            return "\(L10n.t("quests.metric.sleep_streak")): \(Int((numericValue ?? 0).rounded()))/\(Int(challenge.goalValue.rounded())) \(L10n.t("quests.unit.days"))"
        }
    }

    private var extractedNumericValue: Double? {
        let normalized = win.proofValue.replacingOccurrences(of: ",", with: ".")
        let pattern = #"[0-9]+(?:\.[0-9]+)?"#
        guard let range = normalized.range(of: pattern, options: .regularExpression) else { return nil }
        return Double(String(normalized[range]))
    }

    private var extractedRatio: (Int, Int)? {
        let pattern = #"([0-9]+)\s*/\s*([0-9]+)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: win.proofValue,
                range: NSRange(win.proofValue.startIndex..., in: win.proofValue)
            ),
            match.numberOfRanges == 3,
            let lhsRange = Range(match.range(at: 1), in: win.proofValue),
            let rhsRange = Range(match.range(at: 2), in: win.proofValue),
            let lhs = Int(win.proofValue[lhsRange]),
            let rhs = Int(win.proofValue[rhsRange])
        else {
            return nil
        }
        return (lhs, rhs)
    }
}

private struct QuestAchievementCard: View {
    let achievement: QuestEarnedAchievement

    var body: some View {
        HStack(spacing: 14) {
            // Badge image
            Image(achievement.badgeImageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.questName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1A1A"))

                Text("المرحلة \(achievement.stageNumber)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "666666"))

                Text(achievement.formattedDate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: "999999"))
            }

            Spacer()

            // Checkmark
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: "B7E5D2"))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "E8F7F0"), Color(hex: "D4F0E3")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}
