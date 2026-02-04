import SwiftUI
import HealthKit

struct StartView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    // تعريف نوع بيانات بسيط للقائمة داخل هذا الملف
    struct WatchExercise: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let color: Color
        let type: HKWorkoutActivityType
        let location: HKWorkoutSessionLocationType
    }
    
    // ✅ نفس القائمة الموجودة في الهاتف
    let exercises: [WatchExercise] = [
        WatchExercise(title: "Gratitude", icon: "sparkles", color: Color(red: 0.85, green: 0.75, blue: 0.60), type: .mindAndBody, location: .indoor),
        
        WatchExercise(title: "Walk Inside", icon: "figure.walk", color: Color(red: 0.60, green: 0.80, blue: 0.70), type: .walking, location: .indoor),
        
        WatchExercise(title: "Walk Outside", icon: "figure.walk", color: Color(red: 0.95, green: 0.85, blue: 0.65), type: .walking, location: .outdoor),
        
        WatchExercise(title: "Run Indoor", icon: "figure.run", color: Color(red: 0.70, green: 0.90, blue: 0.80), type: .running, location: .indoor),
        
        WatchExercise(title: "Run Outside", icon: "figure.run", color: Color(red: 0.95, green: 0.85, blue: 0.65), type: .running, location: .outdoor)
    ]

    var body: some View {
        List {
            ForEach(exercises) { exercise in
                Button {
                    // ✅ استدعاء الدالة الجديدة التي تقبل الموقع
                    workoutManager.startWorkout(workoutType: exercise.type, locationType: exercise.location)
                } label: {
                    HStack {
                        Image(systemName: exercise.icon)
                            .font(.title2)
                            .foregroundColor(.black)
                            .padding(8)
                            .background(exercise.color)
                            .clipShape(Circle())
                        
                        Text(exercise.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.carousel) // ستايل دائري جميل للساعة
        .navigationBarTitle("AiQo Gym")
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView()
            .environmentObject(WorkoutManager.shared)
    }
}
