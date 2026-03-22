import StoreKit
import SwiftUI

struct PremiumPaywallView: View {
    @StateObject private var premiumStore = PremiumStore.shared
    @ObservedObject private var trialManager = FreeTrialManager.shared

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

                // Free Trial Banner
                if !trialManager.hasUsedTrial {
                    freeTrialBanner
                } else if trialManager.isTrialActive {
                    trialActiveBanner
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

                if let expiresAt = EntitlementStore.shared.expiresAt {
                    TribeGlassCard(cornerRadius: 18, padding: 12, tint: Color.white.opacity(0.04)) {
                        HStack(spacing: 8) {
                            Image(systemName: EntitlementStore.shared.isActive ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(EntitlementStore.shared.isActive ? .green.opacity(0.8) : .orange.opacity(0.8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(EntitlementStore.shared.isActive ? "premium.active".localized : "premium.expired".localized)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(String(format: "premium.expires.date".localized, Self.expiryFormatter.string(from: expiresAt)))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                        }
                    }
                }

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
            AnalyticsService.shared.track(.paywallViewed)
        }
        .onChange(of: premiumStore.hasAnyPremiumAccess) {
            guard premiumStore.hasAnyPremiumAccess else { return }
            onUnlocked?()
        }
    }

    // MARK: - Free Trial Banner

    private var freeTrialBanner: some View {
        Button {
            trialManager.startTrialIfNeeded()
            onUnlocked?()
        } label: {
            TribeGlassCard(cornerRadius: 24, padding: 16, tint: Color.green.opacity(0.08)) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("premium.trial.title".localized)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("premium.trial.subtitle".localized)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Text("premium.trial.start".localized)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.green.opacity(0.85))
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibleButton(
            label: "premium.trial.title".localized,
            hint: "premium.trial.subtitle".localized
        )
    }

    private var trialActiveBanner: some View {
        TribeGlassCard(cornerRadius: 24, padding: 16, tint: Color.blue.opacity(0.08)) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue.opacity(0.8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("premium.trial.active.title".localized)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(String(format: "premium.trial.active.days".localized, trialManager.daysRemaining))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()
            }
        }
    }

    // MARK: - Paywall Card

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

                    HStack(spacing: 4) {
                        Text(product?.displayPrice ?? fallbackPrice(for: plan))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))

                        Text("premium.perMonth".localized)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.50))
                    }
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
        SubscriptionProductIDs.fallbackDisplayPrice(for: plan.canonicalProductID)
    }

    private static let expiryFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
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
