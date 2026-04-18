import SwiftUI

/// Shown in place of `CaptainScreen` when the active tier can't access Captain.
///
/// The existing paywall flow (`PremiumPaywallView`) handles trial-start + purchase,
/// so this view is a thin CTA wrapper that presents the paywall as a sheet. It
/// deliberately avoids any logic beyond "show paywall" — TierGate's
/// `@Published currentTier` will flip the parent back to `CaptainScreen` as soon
/// as the purchase / trial completes.
struct CaptainLockedView: View {
    let requiredTier: TierGate.EffectiveTier

    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("الكابتن حمودي")
                    .font(.title2.weight(.bold))

                Text("ابدأ تجربتك المجانية 7 أيام")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showPaywall = true }) {
                Text("جرّب مجاناً")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.aiqoAccent)
                    )
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView(source: .featureGate)
        }
    }
}

#Preview {
    CaptainLockedView(requiredTier: .max)
}
