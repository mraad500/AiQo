import SwiftUI

struct WorkoutView: View {

    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        ZStack {
            Color(red: 0.75, green: 0.95, blue: 0.87).ignoresSafeArea()

            VStack(spacing: 10) {
                header

                Spacer(minLength: 0)

                Text("\(Int(workout.heartRateBPM.rounded())) bpm")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.black)

                HStack(spacing: 8) {
                    Text("🔥").font(.system(size: 16))
                    Text("\(Int(workout.activeEnergyKcal.rounded())) kcal")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.black.opacity(0.85))
                }

                Text(timeString(workout.elapsed))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.black.opacity(0.85))

                Spacer(minLength: 0)

                Button { workout.stop() } label: {
                    Text("End")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Color.red)
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                                }
                        }
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Workout")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 4)

            Text(Date(), style: .time)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
