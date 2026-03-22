import SwiftUI
import Combine

/// سجل التحديات المكتملة — يعرض إنجازات المستخدم
@MainActor
struct ArenaChallengeHistoryView: View {
    @StateObject private var historyStore = ChallengeHistoryStore.shared

    var body: some View {
        TribeGlassCard(cornerRadius: 28, padding: 16, tint: Color.white.opacity(0.02)) {
            VStack(alignment: .leading, spacing: 14) {
                // الهيدر
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.orange)

                    Text("إنجازاتي")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    // العدد الكلي
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(historyStore.completedChallenges.count)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("تحدي")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                if historyStore.completedChallenges.isEmpty {
                    // فارغ
                    VStack(spacing: 10) {
                        Image(systemName: "trophy")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.2))

                        Text("لا توجد تحديات مكتملة بعد")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))

                        Text("أكمل تحدي أول وشوف إنجازاتك هنا!")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    // قائمة الإنجازات
                    ForEach(historyStore.completedChallenges.prefix(5)) { entry in
                        historyRow(entry)
                    }
                }

                // بادجات سريعة
                if !historyStore.earnedBadges.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.1))

                    Text("البادجات")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(historyStore.earnedBadges) { badge in
                                badgeView(badge)
                            }
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ entry: CompletedChallengeEntry) -> some View {
        HStack(spacing: 12) {
            // الأيقونة
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hue: entry.metricHue, saturation: 0.4, brightness: 0.3))
                    .frame(width: 40, height: 40)

                Image(systemName: entry.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hue: entry.metricHue, saturation: 0.6, brightness: 0.9))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(entry.completedDate.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            // النتيجة
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.finalValue)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.green)

                Text(entry.unit)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 4)
    }

    private func badgeView(_ badge: ArenaBadge) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [badge.color, badge.color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text(badge.emoji)
                    .font(.system(size: 24))
            }
            .shadow(color: badge.color.opacity(0.4), radius: 8, y: 4)

            Text(badge.name)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }
}

// MARK: - Data Models

struct CompletedChallengeEntry: Identifiable, Codable {
    let id: String
    let title: String
    let icon: String
    let metricHue: Double
    let finalValue: Int
    let unit: String
    let completedDate: Date
    let scope: String
}

struct ArenaBadge: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let color: Color
    let requirement: String
}

// MARK: - Challenge History Store

@MainActor
final class ChallengeHistoryStore: ObservableObject {
    static let shared = ChallengeHistoryStore()

    @Published private(set) var completedChallenges: [CompletedChallengeEntry] = []

    private let defaults = UserDefaults.standard
    private let key = "aiqo.arena.completedChallenges"

    private init() {
        loadHistory()
    }

    func recordCompletion(challenge: TribeChallenge) {
        let entry = CompletedChallengeEntry(
            id: challenge.id + "_\(Date().timeIntervalSince1970)",
            title: challenge.title,
            icon: challenge.metricType.iconName,
            metricHue: challenge.metricType.accentHue,
            finalValue: challenge.targetValue,
            unit: challenge.metricType.unitLabel,
            completedDate: Date(),
            scope: challenge.scope.title
        )

        completedChallenges.insert(entry, at: 0)

        // نحتفظ بآخر 50 فقط
        if completedChallenges.count > 50 {
            completedChallenges = Array(completedChallenges.prefix(50))
        }

        saveHistory()
    }

    var earnedBadges: [ArenaBadge] {
        var badges: [ArenaBadge] = []
        let count = completedChallenges.count

        if count >= 1 {
            badges.append(ArenaBadge(id: "first", name: "البداية", emoji: "🌱", color: .green, requirement: "أول تحدي"))
        }
        if count >= 5 {
            badges.append(ArenaBadge(id: "five", name: "المثابر", emoji: "💪", color: .blue, requirement: "5 تحديات"))
        }
        if count >= 10 {
            badges.append(ArenaBadge(id: "ten", name: "المحارب", emoji: "⚔️", color: .purple, requirement: "10 تحديات"))
        }
        if count >= 25 {
            badges.append(ArenaBadge(id: "twentyfive", name: "الأسطورة", emoji: "🏆", color: .orange, requirement: "25 تحدي"))
        }
        if count >= 50 {
            badges.append(ArenaBadge(id: "fifty", name: "الخالد", emoji: "👑", color: .yellow, requirement: "50 تحدي"))
        }

        // بادجات خاصة
        let hasSteps = completedChallenges.contains { $0.icon == "figure.walk" }
        if hasSteps {
            badges.append(ArenaBadge(id: "walker", name: "الماشي", emoji: "🚶", color: .mint, requirement: "تحدي خطوات"))
        }

        let hasWater = completedChallenges.contains { $0.icon == "drop.fill" }
        if hasWater {
            badges.append(ArenaBadge(id: "hydrated", name: "المرطّب", emoji: "💧", color: .cyan, requirement: "تحدي ماء"))
        }

        return badges
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(completedChallenges) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadHistory() {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([CompletedChallengeEntry].self, from: data) else { return }
        completedChallenges = entries
    }
}
