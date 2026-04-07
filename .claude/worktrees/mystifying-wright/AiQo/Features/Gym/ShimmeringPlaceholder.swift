import SwiftUI

struct ShimmeringSkeletonModifier: ViewModifier {
    @State private var shimmerOffset: CGFloat = -1.1
    @State private var breathingOpacity: Double = 0.66

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .opacity(breathingOpacity)
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(12))
                    .offset(x: shimmerOffset * proxy.size.width)
                    .blendMode(.screen)
                }
                .clipped()
            }
            .onAppear {
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.25
                }

                withAnimation(.spring(duration: 1.2, bounce: 0).repeatForever(autoreverses: true)) {
                    breathingOpacity = 0.94
                }
            }
    }
}

extension View {
    func shimmeringSkeleton() -> some View {
        modifier(ShimmeringSkeletonModifier())
    }
}

struct MatchSkeletonCard: View {
    let compact: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.24))
                    .frame(width: compact ? 92 : 108, height: 14)

                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 44, height: 44)

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                        .frame(width: compact ? 54 : 70, height: compact ? 26 : 34)

                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 44, height: 44)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 10) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 58, height: 18)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: compact ? 66 : 82, height: 12)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 108 : 122)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 10)
        .shimmeringSkeleton()
    }
}
