import SwiftUI

struct TribeRingView: View {
    let tribeName: String
    let memberCount: Int

    static let memberColors: [Color] = [
        Color(hex: "8AE3D1"),   // Mint/Teal — العضو 1
        Color(hex: "F5D5A6"),   // Sand/Gold — العضو 2
        Color(hex: "B8C5F2"),   // Lavender — العضو 3
        Color(hex: "F5B5B5"),   // Rose/Peach — العضو 4
        Color(hex: "A8D8EA"),   // Sky Blue — العضو 5
    ]

    private let lineWidth: CGFloat = 10
    private let ringSize: CGFloat = 160
    private let gapDegrees: Double = 4

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let startAngle = Double(index) * 72.0 - 90.0 + gapDegrees / 2
                let endAngle = startAngle + 72.0 - gapDegrees

                Circle()
                    .trim(
                        from: CGFloat((startAngle + 90) / 360),
                        to: CGFloat((endAngle + 90) / 360)
                    )
                    .stroke(
                        colorForSegment(index),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
            }

            VStack(spacing: 4) {
                Text(tribeName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(TribePalette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: ringSize - 40)
        }
        .frame(width: ringSize + 20, height: ringSize + 20)
    }

    private func colorForSegment(_ index: Int) -> Color {
        if index < memberCount {
            return Self.memberColors[index]
        } else {
            return Color.gray.opacity(0.15)
        }
    }
}
