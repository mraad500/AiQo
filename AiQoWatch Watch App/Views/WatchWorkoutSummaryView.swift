import SwiftUI

struct WatchWorkoutSummaryView: View {
    let calories: Int
    let duration: TimeInterval
    let avgHeartRate: Int
    let distance: Double
    let workoutType: WatchWorkoutType
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) private var locale

    private var xpEarned: Int {
        Int(Double(calories) * 0.8 + (duration / 60) * 2)
    }

    @State private var showXP = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text(WatchText.localized(ar: "تمرين مكتمل", en: "Workout Complete", locale: locale))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AiQoWatch.darkTextLight)
                    .tracking(1)

                Text("+\(xpEarned)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundColor(AiQoWatch.accent)
                    .scaleEffect(showXP ? 1.0 : 0.5)
                    .opacity(showXP ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showXP)

                Text(WatchText.localized(ar: "الخبرة", en: "XP", locale: locale))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AiQoWatch.darkTextSecondary)

                HStack(spacing: 4) {
                    SummaryStatPill(
                        value: formatDuration(duration),
                        label: WatchText.localized(ar: "المدة", en: "Duration", locale: locale),
                        bg: AiQoWatch.mintCard
                    )
                    SummaryStatPill(
                        value: WatchText.number(calories, locale: locale),
                        label: WatchText.localized(ar: "السعرات", en: "Calories", locale: locale),
                        bg: AiQoWatch.sandCard
                    )
                    SummaryStatPill(
                        value: WatchText.number(avgHeartRate, locale: locale),
                        label: WatchText.localized(ar: "النبض", en: "Heart", locale: locale),
                        bg: AiQoWatch.pinkCard
                    )
                }

                HStack(spacing: 4) {
                    Text(WatchText.localized(ar: "المسافة", en: "Distance", locale: locale))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AiQoWatch.darkTextSecondary)
                    Spacer()
                    Text(
                        "\(WatchText.number(distance, locale: locale, minimumFractionDigits: 2, maximumFractionDigits: 2)) \(WatchText.localized(ar: "كم", en: "km", locale: locale))"
                    )
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AiQoWatch.darkTextPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AiQoWatch.mintCard.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: AiQoWatch.smallRadius, style: .continuous)
                        .stroke(AiQoWatch.mintCard.opacity(0.30), lineWidth: 1)
                )
                .cornerRadius(AiQoWatch.smallRadius)

                Button {
                    dismiss()
                } label: {
                    Text(WatchText.localized(ar: "تم", en: "Done", locale: locale))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AiQoWatch.accent)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 10)
        }
        .background(
            LinearGradient(
                colors: [AiQoWatch.darkBackgroundTop, AiQoWatch.darkBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .environment(\.layoutDirection, WatchText.layoutDirection(for: locale))
        .onAppear { showXP = true }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct SummaryStatPill: View {
    let value: String
    let label: String
    let bg: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(AiQoWatch.darkTextPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(AiQoWatch.darkTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(bg.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: AiQoWatch.smallRadius, style: .continuous)
                .stroke(bg.opacity(0.30), lineWidth: 1)
        )
        .cornerRadius(AiQoWatch.smallRadius)
    }
}
