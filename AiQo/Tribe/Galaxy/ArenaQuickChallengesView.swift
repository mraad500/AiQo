import SwiftUI

/// تحديات سريعة جاهزة — يختار المستخدم وحدة ويبدأ فوراً
@MainActor
struct ArenaQuickChallengesView: View {
    @ObservedObject var viewModel: ArenaViewModel
    let onSelect: (QuickChallengeTemplate) -> Void

    var body: some View {
        TribeGlassCard(cornerRadius: 28, padding: 16, tint: Color.white.opacity(0.02)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.orange)
                    Text("تحديات سريعة")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("اختر تحدي وابدأ فوراً!")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    ForEach(QuickChallengeTemplate.allTemplates) { template in
                        quickChallengeCard(template)
                    }
                }
            }
        }
    }

    private func quickChallengeCard(_ template: QuickChallengeTemplate) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(template)
        } label: {
            VStack(spacing: 8) {
                // الأيقونة
                ZStack {
                    Circle()
                        .fill(template.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Text(template.emoji)
                        .font(.system(size: 22))
                }

                Text(template.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(template.subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)

                // مدة التحدي
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8))
                    Text(template.durationText)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                }
                .foregroundStyle(template.color.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(template.color.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Challenge Template

struct QuickChallengeTemplate: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let subtitle: String
    let metricType: ChallengeGoalType
    let target: Int
    let durationHours: Int
    let color: Color

    var durationText: String {
        if durationHours >= 24 {
            return "\(durationHours / 24) يوم"
        }
        return "\(durationHours) ساعة"
    }

    static let allTemplates: [QuickChallengeTemplate] = [
        QuickChallengeTemplate(
            emoji: "🏃",
            title: "ماراثون قصير",
            subtitle: "10K خطوة",
            metricType: .steps,
            target: 10_000,
            durationHours: 24,
            color: .green
        ),
        QuickChallengeTemplate(
            emoji: "💧",
            title: "يوم رطب",
            subtitle: "8 أكواب ماء",
            metricType: .water,
            target: 8,
            durationHours: 24,
            color: .blue
        ),
        QuickChallengeTemplate(
            emoji: "🚫",
            title: "بدون سكر",
            subtitle: "24 ساعة",
            metricType: .sugarFree,
            target: 1,
            durationHours: 24,
            color: .red
        ),
        QuickChallengeTemplate(
            emoji: "🧘",
            title: "لحظة هدوء",
            subtitle: "15 دقيقة تأمل",
            metricType: .calmMinutes,
            target: 15,
            durationHours: 4,
            color: .purple
        ),
        QuickChallengeTemplate(
            emoji: "😴",
            title: "نوم مبكر",
            subtitle: "8 ساعات نوم",
            metricType: .sleep,
            target: 8,
            durationHours: 24,
            color: .indigo
        ),
        QuickChallengeTemplate(
            emoji: "⚡️",
            title: "سبرنت الخطوات",
            subtitle: "5K خلال 3 ساعات",
            metricType: .steps,
            target: 5_000,
            durationHours: 3,
            color: .orange
        ),
    ]
}
