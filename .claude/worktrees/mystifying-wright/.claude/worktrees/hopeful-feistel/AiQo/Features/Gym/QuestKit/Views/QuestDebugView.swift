#if DEBUG
import SwiftUI

struct QuestDebugView: View {
    @ObservedObject var engine: QuestEngine

    @State private var cameraQuestId: String = "s2q1"
    @State private var cameraReps: Double = 20
    @State private var cameraAccuracy: Double = 85

    var body: some View {
        NavigationStack {
            Form {
                Section("Simulate Metrics") {
                    Button("+ 0.5L Water") {
                        engine.debugAddWater(0.5)
                    }
                    Button("+ 2,000 Steps") {
                        engine.debugAddSteps(2000)
                    }
                    Button("+ 1.0 KM Distance") {
                        engine.debugAddDistance(1)
                    }
                    Button("+ 1.0h Sleep") {
                        engine.debugAddSleep(1)
                    }
                    Button("+ 20m Zone2") {
                        engine.debugAddWorkoutMinutes(20, kind: .zone2)
                    }
                    Button("+ 20m Cardio") {
                        engine.debugAddWorkoutMinutes(20, kind: .cardio)
                    }
                }

                Section("Camera Simulator") {
                    Picker("Quest", selection: $cameraQuestId) {
                        ForEach(engine.debugCameraQuestIDs, id: \.self) { id in
                            Text(id).tag(id)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reps: \(Int(cameraReps))")
                        Slider(value: $cameraReps, in: 0...120, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accuracy: \(Int(cameraAccuracy))%")
                        Slider(value: $cameraAccuracy, in: 0...100, step: 1)
                    }

                    Button("Apply Camera Result") {
                        engine.debugSimulateCameraResult(
                            questId: cameraQuestId,
                            reps: Int(cameraReps),
                            accuracy: cameraAccuracy
                        )
                    }
                }

                Section("Resets") {
                    Button("Reset Today") {
                        engine.debugResetToday()
                    }
                    Button("Reset Week") {
                        engine.debugResetWeek()
                    }
                }
            }
            .navigationTitle("Quest Debug")
            .onAppear {
                cameraQuestId = engine.debugCameraQuestIDs.first ?? "s2q1"
            }
        }
    }
}
#endif
