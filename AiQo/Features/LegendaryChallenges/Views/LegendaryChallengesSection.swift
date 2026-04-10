import SwiftUI

// MARK: - Legendary Challenges Section (embedded in قِمَم tab)

struct LegendaryChallengesSection: View {
    @ObservedObject var viewModel: LegendaryChallengesViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            // DESIGN: Section header — bold Arabic + sparkle icon, matching existing قِمَم headers
            HStack(spacing: 6) {
                Text("✦")
                    .font(.system(size: 14))
                    .foregroundStyle(GymTheme.beige)

                Text("التحدّيات الأسطورية")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 4)

            if AccessManager.shared.canAccessPeaks || AccessManager.shared.legendaryChallengeAccess == .viewOnly {
                // DESIGN: Horizontal ScrollView of record cards (viewOnly for Core tier)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(viewModel.records.enumerated()), id: \.element.id) { index, record in
                            NavigationLink(value: record) {
                                RecordCard(record: record, index: index)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                PeaksUpgradePromptView()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Peaks Upgrade Prompt

private struct PeaksUpgradePromptView: View {
    @State private var showPaywall = false

    private let mint = Color(hex: "5ECDB7")

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 28))
                .foregroundStyle(mint.opacity(0.7))

            Text("قمم متاحة في AiQo Intelligence Pro")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            Text("اكسر أرقام قياسية عالمية مع ميزة القمم وذكاء الكابتن الأعمق")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                showPaywall = true
            } label: {
                Text("الترقية إلى AiQo Intelligence Pro")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(mint)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView(source: .legendaryChallenges)
        }
    }
}

#Preview {
    NavigationStack {
        LegendaryChallengesSection(viewModel: LegendaryChallengesViewModel())
            .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
