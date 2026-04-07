import StoreKit
import SwiftUI

struct PremiumPaywallView: View {
    @StateObject private var premiumStore = PremiumStore.shared

    var onUnlocked: (() -> Void)? = nil

    var body: some View {
        TribeGlassCard(cornerRadius: 30, padding: 18, tint: Color.white.opacity(0.03)) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("premium.title".localized)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("premium.subtitle".localized)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(PremiumPlan.allCases) { plan in
                    paywallCard(for: plan)
                }

                Button {
                    Task {
                        await premiumStore.restore()
                    }
                } label: {
                    Text("premium.restore".localized)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                if let statusMessage = premiumStore.statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .task {
            premiumStore.start()
        }
        .onChange(of: premiumStore.hasAnyPremiumAccess) {
            guard premiumStore.hasAnyPremiumAccess else { return }
            onUnlocked?()
        }
    }

    private func paywallCard(for plan: PremiumPlan) -> some View {
        let product = premiumStore.product(for: plan)

        return TribeGlassCard(cornerRadius: 24, padding: 16, tint: Color.white.opacity(0.025)) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(plan.description)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(product?.displayPrice ?? fallbackPrice(for: plan))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer(minLength: 12)

                Button {
                    Task {
                        await premiumStore.purchase(plan)
                    }
                } label: {
                    if premiumStore.isLoading {
                        ProgressView()
                            .tint(.black)
                            .frame(width: 88, height: 42)
                    } else {
                        Text("premium.buy".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(width: 88, height: 42)
                    }
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                )
                .disabled(premiumStore.isLoading)
            }
        }
    }

    private func fallbackPrice(for plan: PremiumPlan) -> String {
        switch plan {
        case .individual:
            return SubscriptionProductIDs.fallbackDisplayPrice(for: plan.canonicalProductID)
        case .family:
            return SubscriptionProductIDs.fallbackDisplayPrice(for: plan.canonicalProductID)
        }
    }
}

#Preview {
    ZStack {
        TribeGalaxyBackground()
            .ignoresSafeArea()

        PremiumPaywallView()
            .padding(16)
    }
    .environment(\.layoutDirection, .rightToLeft)
}
