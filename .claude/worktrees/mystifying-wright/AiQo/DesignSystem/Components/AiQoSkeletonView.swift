import SwiftUI

/// Branded shimmer skeleton placeholder matching the real content shape.
struct AiQoSkeletonView: View {
    var width: CGFloat = .infinity
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(.systemGray5),
                        Color(.systemGray6),
                        Color(.systemGray5)
                    ],
                    startPoint: UnitPoint(x: phase - 1, y: 0),
                    endPoint: UnitPoint(x: phase, y: 0)
                )
            )
            .frame(maxWidth: width == .infinity ? .infinity : width, minHeight: height, maxHeight: height)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 2
                }
            }
    }
}

/// A skeleton card matching AiQo metric card proportions.
struct AiQoMetricCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AiQoSkeletonView(width: 80, height: 14, cornerRadius: 6)
            AiQoSkeletonView(width: 120, height: 28, cornerRadius: 8)
            AiQoSkeletonView(width: 60, height: 12, cornerRadius: 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .modifier(AiQoShadow())
    }
}
