import SwiftUI

struct WatchActiveWorkoutView: View {
    let workoutType: WatchWorkoutType
    @EnvironmentObject var manager: WatchWorkoutManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if manager.isActive {
                activeContent
            } else {
                startContent
            }
        }
        .background(
            LinearGradient(
                colors: [AiQoWatch.darkBackgroundTop, AiQoWatch.darkBackgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .environment(\.layoutDirection, WatchText.layoutDirection(for: locale))
        .navigationBarBackButtonHidden(manager.isActive)
    }

    private var startContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: workoutType.sfSymbol)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(AiQoWatch.accent)
                .frame(width: 66, height: 66)
                .background(workoutType.cardColor.opacity(0.18))
                .clipShape(Circle())

            Text(workoutType.localizedName(locale: locale))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AiQoWatch.darkTextPrimary)

            Button {
                manager.startWorkout(type: workoutType)
            } label: {
                Text(WatchText.localized(ar: "ابدأ", en: "Start", locale: locale))
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

    private var activeContent: some View {
        ScrollView {
            VStack(spacing: 5) {
                Text(workoutType.localizedName(locale: locale))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AiQoWatch.accent)

                Text(manager.formattedTime)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(AiQoWatch.darkTextPrimary)
                    .monospacedDigit()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                    ActiveMetricCard(
                        value: WatchText.number(Int(manager.activeCalories), locale: locale),
                        unit: WatchText.localized(ar: "سعرة", en: "kcal", locale: locale),
                        label: WatchText.localized(ar: "السعرات", en: "Calories", locale: locale),
                        bg: AiQoWatch.sandCard
                    )
                    ActiveMetricCard(
                        value: WatchText.number(Int(manager.heartRate), locale: locale),
                        unit: WatchText.localized(ar: "نب/د", en: "bpm", locale: locale),
                        label: WatchText.localized(ar: "النبض", en: "Heart", locale: locale),
                        bg: AiQoWatch.pinkCard
                    )
                    ActiveMetricCard(
                        value: WatchText.number(manager.distance, locale: locale, minimumFractionDigits: 2, maximumFractionDigits: 2),
                        unit: WatchText.localized(ar: "كم", en: "km", locale: locale),
                        label: WatchText.localized(ar: "المسافة", en: "Distance", locale: locale),
                        bg: AiQoWatch.mintCard
                    )
                    ActiveMetricCard(
                        value: manager.elapsedSeconds > 0
                            ? WatchText.number(
                                manager.activeCalories / (manager.elapsedSeconds / 60),
                                locale: locale,
                                minimumFractionDigits: 1,
                                maximumFractionDigits: 1
                            )
                            : WatchText.number(0, locale: locale),
                        unit: WatchText.localized(ar: "/د", en: "/min", locale: locale),
                        label: WatchText.localized(ar: "المعدل", en: "Rate", locale: locale),
                        bg: workoutType.cardColor
                    )
                }

                HStack(spacing: 14) {
                    Button {
                        manager.isPaused ? manager.resumeWorkout() : manager.pauseWorkout()
                    } label: {
                        Image(systemName: manager.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AiQoWatch.darkTextPrimary)
                            .frame(width: 46, height: 46)
                            .background(AiQoWatch.darkSurfaceRaised)
                            .overlay(
                                Circle()
                                    .stroke(AiQoWatch.darkBorder, lineWidth: 1)
                            )
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
                    .foregroundColor(AiQoWatch.darkTextPrimary)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(AiQoWatch.darkTextSecondary)
            }
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(AiQoWatch.darkTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(bg.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: AiQoWatch.smallRadius, style: .continuous)
                .stroke(bg.opacity(0.32), lineWidth: 1)
        )
        .cornerRadius(AiQoWatch.smallRadius)
    }
}
