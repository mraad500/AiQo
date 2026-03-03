import SwiftUI

struct BodyView: View {
    let onSelectExercise: (GymExercise) -> Void

    var body: some View {
        ExercisesView(onSelect: onSelectExercise)
    }
}
