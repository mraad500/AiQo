import SwiftUI
import UIKit

struct ExercisesView: View {
    var onSelect: (GymExercise) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                ForEach(Array(GymExercise.samples.enumerated()), id: \.element.id) { index, exercise in
                    let baseTint: Color = index.isMultiple(of: 2) ? .aiqoMint : .aiqoBeige
                    let tint = baseTint.balancedWorkoutTint()

                    OriginalWorkoutCardView(exercise: exercise, tint: tint) {
                        onSelect(exercise)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 110)
        }
    }
}

#Preview("Workouts LTR Light") {
    ExercisesView { exercise in
        print(exercise.title)
    }
}

#Preview("Workouts RTL Dark") {
    ExercisesView { exercise in
        print(exercise.title)
    }
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}
