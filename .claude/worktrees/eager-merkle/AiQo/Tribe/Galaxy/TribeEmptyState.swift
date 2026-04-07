import SwiftUI

struct TribeEmptyState: View {
    var onCreateTribe: () -> Void = {}
    var onJoinTribe: () -> Void = {}

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // أيقونة
            Image(systemName: "person.3.fill")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.aiqoMint)

            // النص
            VStack(spacing: 8) {
                Text("القبائل تتنافس — وأنت وين؟")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(TribePalette.textPrimary)

                Text("أنشئ قبيلتك مع الاشتراك العائلي\nأو انضم لقبيلة صديقك برمز الدعوة")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(TribePalette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // الأزرار
            VStack(spacing: 12) {
                Button(action: onCreateTribe) {
                    Text("أنشئ قبيلتك")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(hex: "2D6B4A"))
                        )
                        .shadow(color: Color(hex: "2D6B4A").opacity(0.25), radius: 10, y: 4)
                }

                Button(action: onJoinTribe) {
                    Text("انضم برمز دعوة")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color(hex: "2D6B4A"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(hex: "2D6B4A").opacity(0.4), lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, 24)

            // Feature cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                TribeFeatureCard(icon: "trophy.fill", title: "نافس قبائل", subtitle: "تحديات أسبوعية")
                TribeFeatureCard(icon: "crown.fill", title: "صير قائد", subtitle: "الإمارة")
                TribeFeatureCard(icon: "chart.bar.fill", title: "تابع تقدم", subtitle: "فريقك")
                TribeFeatureCard(icon: "flame.fill", title: "حفّز ربعك", subtitle: "يلتزمون")
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }
}

private struct TribeFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.aiqoSand)

            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(TribePalette.textPrimary)

            Text(subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(TribePalette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}
