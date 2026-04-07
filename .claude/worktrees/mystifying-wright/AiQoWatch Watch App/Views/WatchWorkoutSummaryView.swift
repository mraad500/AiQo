import SwiftUI

struct WatchWorkoutSummaryView: View {
    let calories: Int
    let duration: TimeInterval
    let avgHeartRate: Int
    let distance: Double
    let workoutType: WatchWorkoutType
    @Environment(\.dismiss) var dismiss

    // Simple XP formula matching iPhone: (calories * 0.8) + (duration_minutes * 2)
    private var xpEarned: Int {
        Int(Double(calories) * 0.8 + (duration / 60) * 2)
    }

    @State private var showXP = false

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Header
                Text("تمرين مكتمل ✓")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AiQoWatch.textLight)
                    .tracking(1)

                // XP with spring animation
                Text("+\(xpEarned)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundColor(AiQoWatch.accent)
                    .scaleEffect(showXP ? 1.0 : 0.5)
                    .opacity(showXP ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showXP)

                Text("XP")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AiQoWatch.textSecondary)

                // Stats — 3-column row
                HStack(spacing: 4) {
                    SummaryStatPill(
                        value: formatDuration(duration),
                        label: "المدة",
                        bg: AiQoWatch.mintCard
                    )
                    SummaryStatPill(
                        value: "\(calories)",
                        label: "سعرة",
                        bg: AiQoWatch.sandCard
                    )
                    SummaryStatPill(
                        value: "\(avgHeartRate)",
                        label: "نبض",
                        bg: AiQoWatch.pinkCard
                    )
                }

                // Distance bar
                HStack(spacing: 4) {
                    Text("المسافة")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AiQoWatch.textSecondary)
                    Spacer()
                    Text(String(format: "%.2f km", distance))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AiQoWatch.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AiQoWatch.mintCard)
                .cornerRadius(AiQoWatch.smallRadius)

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("تم")
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
        .background(AiQoWatch.background)
        .environment(\.layoutDirection, .rightToLeft)
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
                .foregroundColor(AiQoWatch.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(AiQoWatch.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(bg)
        .cornerRadius(AiQoWatch.smallRadius)
    }
}
