/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The workout controls.
*/

import SwiftUI

struct ControlsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        HStack {
            VStack {
                Button {
                    workoutManager.endWorkout()
                } label: {
                    Image(systemName: workoutManager.workoutPhase == .stopping ? "hourglass" : "xmark")
                }
                .tint(.red)
                .font(.title2)
                .disabled(workoutManager.workoutPhase == .stopping)
                Text(workoutManager.workoutPhase == .stopping ? "Ending" : "End")
            }
            VStack {
                Button {
                    workoutManager.togglePause()
                } label: {
                    Image(systemName: workoutManager.running ? "pause" : "play")
                }
                .tint(.yellow)
                .font(.title2)
                .disabled(workoutManager.workoutPhase == .stopping)
                Text(workoutManager.running ? "Pause" : "Resume")
            }
        }
    }
}

struct ControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ControlsView().environmentObject(WorkoutManager())
    }
}
