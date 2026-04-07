// DO NOT CHANGE VISUALS (approved design)

import SwiftUI
import UIKit

struct OriginalWorkoutCardView: View {
    let exercise: GymExercise
    let tint: Color
    var onTap: () -> Void

    @State private var tapScale: CGFloat = 1.0
    @State private var tapRotation: Double = 0.0

    private let cardHeight: CGFloat = 110
    private let corner: CGFloat = 30

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .lineLimit(1)

                if let subtitle = exercise.subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.72))
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: exercise.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black.opacity(0.85))
        }
        .padding(.horizontal, 22)
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 8)
        .scaleEffect(tapScale)
        .rotation3DEffect(.degrees(tapRotation), axis: (x: 1, y: 0, z: 0))
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .onTapGesture {
            triggerWaveAnimation()
            onTap()
        }
    }

    private func triggerWaveAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
            tapScale = 0.92
            tapRotation = 8.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4, blendDuration: 0)) {
                tapScale = 1.0
                tapRotation = 0.0
            }
        }
    }
}

extension Color {
    func balancedWorkoutTint() -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self
        }

        let newS = min(max(s * 1.08, 0), 1)
        let newB = min(max(b * 0.98, 0), 1)

        return Color(UIColor(hue: h, saturation: newS, brightness: newB, alpha: a))
    }
}

#Preview("Original Workout Card") {
    OriginalWorkoutCardView(
        exercise: GymExercise.samples[0],
        tint: Color.aiqoMint.balancedWorkoutTint(),
        onTap: {}
    )
    .padding()
}
