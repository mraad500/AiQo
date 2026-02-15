import SwiftUI

struct QuestWinsGridView: View {
    @ObservedObject var winsStore: WinsStore

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        let visibleWins = winsStore.wins.filter { !isHiddenWin($0) }

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.t("wins.title"))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))

                if visibleWins.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(visibleWins) { win in
                            WinAwardCard(win: win)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text(L10n.t("quests.wins.empty_title"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(L10n.t("quests.wins.empty_subtitle"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(GymTheme.mint.opacity(0.16))
                )
        )
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(GymTheme.beige.opacity(0.19))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.34), lineWidth: 0.6)
                )
        )
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
            let ratio = extractedRatio ?? (Int((numericValue ?? 0).rounded()), Challenge.stage2Daily.count)
            return "\(L10n.t("quests.metric.stage2")): \(ratio.0)/\(ratio.1) \(L10n.t("quests.unit.quests"))"
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
