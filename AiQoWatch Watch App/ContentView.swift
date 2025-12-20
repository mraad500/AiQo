import SwiftUI
import HealthKit

struct ContentView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        if workoutManager.session != nil {
            SessionView()
        } else {
            MenuView()
        }
    }
}

struct MenuView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Gym").font(.system(size: 34, weight: .bold, design: .rounded))
                
                WorkoutCard(title: "Gratitude", subtitle: "Breathing", color: .brandSand) {
                    workoutManager.startWorkout(workoutType: .mindAndBody)
                }
                
                WorkoutCard(title: "Walk inside", subtitle: "Indoor", color: .brandMint) {
                    workoutManager.startWorkout(workoutType: .walking, location: .indoor)
                }
                
                WorkoutCard(title: "Walking outside", subtitle: "Outdoor", color: .brandSand) {
                    workoutManager.startWorkout(workoutType: .walking, location: .outdoor)
                }
            }
        }
    }
}

struct WorkoutCard: View {
    let title: String, subtitle: String, color: Color, action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading) {
                Text(title).font(.headline).foregroundColor(.black)
                Text(subtitle).font(.caption).foregroundColor(.black.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding().background(color).cornerRadius(16)
        }.buttonStyle(.plain)
    }
}

struct SessionView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var workoutName: String {
        switch workoutManager.selectedWorkout {
        case .walking: return workoutManager.sessionLocation == .indoor ? "Indoor Walk" : "Outdoor Walk"
        case .mindAndBody: return "Gratitude"
        default: return "Workout"
        }
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            VStack {
                Text(workoutName).font(.headline)
                Spacer()
                Text("\(Int(workoutManager.heartRate)) bpm").font(.largeTitle)
                Text("\(Int(workoutManager.activeEnergy)) kcal")
                
                // ✅ التغيير هنا: استخدام startDate ليقوم العداد بالعد التصاعدي بشكل صحيح
                Text(workoutManager.startDate ?? Date(), style: .timer)
                    .font(.title)
                
                Spacer()
                Button("End") { workoutManager.endWorkout() }
                    .padding().background(Color.red).cornerRadius(20)
            }
        }
    }
}
