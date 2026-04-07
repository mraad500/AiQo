import SwiftUI

struct WatchWorkoutListView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AiQoWatch.gridSpacing) {
                    Text("التمارين")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AiQoWatch.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)

                    ForEach(WatchWorkoutType.allCases) { workout in
                        NavigationLink {
                            WatchActiveWorkoutView(workoutType: workout)
                                .environmentObject(workoutManager)
                        } label: {
                            WatchWorkoutRow(workout: workout)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 12)
            }
            .background(AiQoWatch.background)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

struct WatchWorkoutRow: View {
    let workout: WatchWorkoutType

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: workout.sfSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AiQoWatch.textSecondary)
                .frame(width: 30, height: 30)
                .background(workout.iconBgColor)
                .clipShape(Circle())

            // Name
            Text(workout.nameArabic)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AiQoWatch.textPrimary)

            Spacer()

            // RTL chevron
            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AiQoWatch.textLight)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(workout.cardColor)
        .cornerRadius(AiQoWatch.cardRadius)
    }
}
