import SwiftUI

struct WatchActiveWorkoutView: View {
    let workoutType: WatchWorkoutType
    @EnvironmentObject var manager: WatchWorkoutManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if manager.isActive {
                activeContent
            } else {
                startContent
            }
        }
        .background(AiQoWatch.background)
        .environment(\.layoutDirection, .rightToLeft)
        .navigationBarBackButtonHidden(manager.isActive)
    }

    // MARK: - Pre-Start
    private var startContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: workoutType.sfSymbol)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(AiQoWatch.accent)

            Text(workoutType.nameArabic)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AiQoWatch.textPrimary)

            Button {
                manager.startWorkout(type: workoutType)
            } label: {
                Text("ابدأ")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AiQoWatch.accent)
                    .cornerRadius(AiQoWatch.cardRadius)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Active Workout
    private var activeContent: some View {
        ScrollView {
            VStack(spacing: 5) {
                // Workout type label
                Text(workoutType.nameArabic)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AiQoWatch.accent)

                // Timer
                Text(manager.formattedTime)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(AiQoWatch.textPrimary)
                    .monospacedDigit()

                // 2×2 Metrics
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                    ActiveMetricCard(
                        value: "\(Int(manager.activeCalories))",
                        unit: "kcal",
                        label: "السعرات",
                        bg: AiQoWatch.sandCard
                    )
                    ActiveMetricCard(
                        value: "\(Int(manager.heartRate))",
                        unit: "bpm",
                        label: "النبض",
                        bg: AiQoWatch.pinkCard
                    )
                    ActiveMetricCard(
                        value: String(format: "%.2f", manager.distance),
                        unit: "km",
                        label: "المسافة",
                        bg: AiQoWatch.mintCard
                    )
                    ActiveMetricCard(
                        value: manager.elapsedSeconds > 0
                            ? String(format: "%.1f", manager.activeCalories / (manager.elapsedSeconds / 60))
                            : "0",
                        unit: "/min",
                        label: "المعدل",
                        bg: workoutType.cardColor
                    )
                }

                // Controls
                HStack(spacing: 14) {
                    Button {
                        manager.isPaused ? manager.resumeWorkout() : manager.pauseWorkout()
                    } label: {
                        Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AiQoWatch.textPrimary)
                            .frame(width: 46, height: 46)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        manager.endWorkout()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 46, height: 46)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 8)
        }
    }
}

struct ActiveMetricCard: View {
    let value: String
    let unit: String
    let label: String
    let bg: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(AiQoWatch.textPrimary)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(AiQoWatch.textSecondary)
            }
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(AiQoWatch.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(bg)
        .cornerRadius(AiQoWatch.smallRadius)
    }
}
