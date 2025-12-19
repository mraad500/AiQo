import SwiftUI
import HealthKit

struct ExerciseListView: View {
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {

                    // ✅ مهم: نحدد id حتى ForEach ما يتحول إلى Range<Int>
                    ForEach(ExerciseKind.allCases, id: \.self) { ex in
                        ExerciseCard(exercise: ex) {
                            startWorkout(for: ex)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            .navigationTitle("Gym")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.black.ignoresSafeArea())
            .navigationDestination(isPresented: Binding(
                get: { workout.isRunning },
                set: { _ in }
            )) {
                WorkoutView()
            }
            .task {
                // ✅ دالتك مو async، فلا تستخدم await
                workout.requestAuthorization()
            }
        }
    }

    // MARK: - Start workout on Watch (Watch is source of truth)
    private func startWorkout(for ex: ExerciseKind) {
        let (activityRaw, locationRaw) = mapToHK(ex)
        let wid = UUID().uuidString

        // ✅ هذا يبدأ HKWorkoutSession على الساعة فعلياً
        workout.startFromPhone(
            workoutID: wid,
            activityTypeRaw: activityRaw,
            locationTypeRaw: locationRaw
        )
    }

    // MARK: - Mapping (adjust cases حسب ExerciseKind عندك)
    private func mapToHK(_ ex: ExerciseKind) -> (activityRaw: Int, locationRaw: Int) {
        // ملاحظة: rawValue لـ HKWorkoutActivityType هو UInt
        // وملاحظة ثانية: locationType rawValue هو Int
        switch ex {
        case .walkOutside:
            return (Int(HKWorkoutActivityType.walking.rawValue), HKWorkoutSessionLocationType.outdoor.rawValue)

        case .walkInside:
            return (Int(HKWorkoutActivityType.walking.rawValue), HKWorkoutSessionLocationType.indoor.rawValue)

        case .runIndoor:
            return (Int(HKWorkoutActivityType.running.rawValue), HKWorkoutSessionLocationType.indoor.rawValue)

        case .gratitude:
            // إذا gratitude شي غير رياضي، نخليه “other”
            return (Int(HKWorkoutActivityType.other.rawValue), HKWorkoutSessionLocationType.unknown.rawValue)
        }
    }
}

private struct ExerciseCard: View {
    let exercise: ExerciseKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: exercise.symbol)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text(exercise.subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.55))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardColor(for: exercise))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
            }
        }
        .buttonStyle(.plain)
    }

    private func cardColor(for ex: ExerciseKind) -> Color {
        switch ex {
        case .gratitude, .walkOutside:
            return Color(red: 0.96, green: 0.84, blue: 0.66) // sand-ish
        case .walkInside, .runIndoor:
            return Color(red: 0.78, green: 0.95, blue: 0.87) // mint-ish
        }
    }
}
