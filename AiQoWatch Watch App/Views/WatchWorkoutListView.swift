import SwiftUI

struct WatchWorkoutListView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AiQoWatch.gridSpacing) {
                    Text(WatchText.localized(ar: "التمارين", en: "Workouts", locale: locale))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AiQoWatch.darkTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                    // Tapping a row starts the workout immediately.
                    // AiQoWatchApp's root switches to WatchActiveWorkoutView
                    // when workoutManager.isActive becomes true, so no
                    // NavigationLink is needed (avoids duplicate view instances).
                    ForEach(WatchWorkoutType.allCases) { workout in
                        Button {
                            workoutManager.startWorkout(type: workout)
                        } label: {
                            WatchWorkoutRow(workout: workout)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 12)
            }
            .background(
                LinearGradient(
                    colors: [AiQoWatch.darkBackgroundTop, AiQoWatch.darkBackgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .environment(\.layoutDirection, WatchText.layoutDirection(for: locale))
        }
    }
}

struct WatchWorkoutRow: View {
    let workout: WatchWorkoutType
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: workout.sfSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AiQoWatch.darkTextPrimary)
                .frame(width: 30, height: 30)
                .background(workout.iconBgColor.opacity(0.9))
                .clipShape(Circle())

            Text(workout.localizedName(locale: locale))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AiQoWatch.darkTextPrimary)

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AiQoWatch.darkTextLight)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(AiQoWatch.darkSurface)
        .overlay(
            RoundedRectangle(cornerRadius: AiQoWatch.cardRadius, style: .continuous)
                .stroke(workout.cardColor.opacity(0.28), lineWidth: 1)
        )
        .cornerRadius(AiQoWatch.cardRadius)
    }
}
