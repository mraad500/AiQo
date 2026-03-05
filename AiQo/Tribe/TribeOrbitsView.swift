import SwiftUI

struct TribeOrbitsView: View {
    var memberProgresses: [CGFloat]
    var orbitColors: [Color] = [
        Color(red: 0.98, green: 0.94, blue: 0.08),
        Color(red: 0.66, green: 0.54, blue: 0.95),
        Color(red: 0.55, green: 0.91, blue: 0.82),
        Color(red: 0.09, green: 0.40, blue: 0.98),
        Color(red: 0.93, green: 0.84, blue: 0.67)
    ]

    private let innerOrbitLineWidth: CGFloat = 8
    private let outerRingLineWidth: CGFloat = 8
    private let outerRingSize: CGFloat = 260

    // Mapping is kept consistent with member card border colors:
    // 0: Yellow, 1: Purple, 2: Mint, 3: Blue, 4: Beige(outer energy ring)
    private let innerSpecs: [(index: Int, rotation: Double, trimStart: Double, width: CGFloat, height: CGFloat)] = [
        (2, 90, -96, 208, 76),   // Mint vertical
        (1, -35, -36, 230, 78),  // Purple diagonal
        (0, 35, 38, 230, 78),    // Yellow diagonal
        (3, 0, 2, 244, 72)       // Blue horizontal
    ]

    var body: some View {
        ZStack(alignment: .center) {
            // Fifth member: outer beige orbit ring.
            Circle()
                .stroke(
                    color(at: 4).opacity(0.22),
                    style: StrokeStyle(lineWidth: outerRingLineWidth, lineCap: .round, dash: [58, 44])
                )
                .rotationEffect(.degrees(-90))
                .frame(width: outerRingSize, height: outerRingSize)

            Circle()
                .trim(from: 0, to: progress(at: 4))
                .stroke(
                    color(at: 4).opacity(0.96),
                    style: StrokeStyle(lineWidth: outerRingLineWidth, lineCap: .round, dash: [58, 44])
                )
                .rotationEffect(.degrees(-90))
                .frame(width: outerRingSize, height: outerRingSize)

            // Small aura dots around the outer ring.
            ForEach(0..<8, id: \.self) { idx in
                Circle()
                    .fill(color(at: 4).opacity(0.96))
                    .frame(width: 9, height: 9)
                    .offset(y: -outerRingSize / 2)
                    .rotationEffect(.degrees(Double(idx) * 45 + 22.5))
            }

            // Inner four member orbits.
            ForEach(Array(innerSpecs.enumerated()), id: \.offset) { _, spec in
                let progress = progress(at: spec.index)
                let color = color(at: spec.index)

                Ellipse()
                    .stroke(
                        color.opacity(0.10),
                        style: StrokeStyle(lineWidth: innerOrbitLineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: spec.width, height: spec.height, alignment: .center)
                    .rotationEffect(.degrees(spec.rotation))

                Ellipse()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: innerOrbitLineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(spec.trimStart))
                    .frame(width: spec.width, height: spec.height, alignment: .center)
                    .rotationEffect(.degrees(spec.rotation))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 92
                    )
                )
                .frame(width: 176, height: 176)
        }
        .frame(width: 276, height: 276)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: normalizedProgresses)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tribe progress orbits")
        .accessibilityValue("\(Int((averageProgress * 100).rounded())) percent")
    }

    private var normalizedProgresses: [CGFloat] {
        (0..<5).map { progress(at: $0) }
    }

    private var averageProgress: CGFloat {
        let values = normalizedProgresses
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / CGFloat(values.count)
    }

    private func progress(at index: Int) -> CGFloat {
        guard memberProgresses.indices.contains(index) else { return 0 }
        return memberProgresses[index].clampedToUnitInterval
    }

    private func color(at index: Int) -> Color {
        guard orbitColors.indices.contains(index) else { return .gray }
        return orbitColors[index]
    }
}

#Preview {
    TribeOrbitsView(
        memberProgresses: [0.87, 0.72, 0.64, 0.81, 0.55]
    )
    .padding()
    .background(Color(red: 0.95, green: 0.98, blue: 0.97))
}

private extension CGFloat {
    var clampedToUnitInterval: CGFloat {
        Swift.min(Swift.max(self, 0), 1)
    }
}
