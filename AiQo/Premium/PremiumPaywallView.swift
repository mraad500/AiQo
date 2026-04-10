import SwiftUI

struct PremiumPaywallView: View {
    var source: PaywallSource = .featureGate
    var onUnlocked: (() -> Void)? = nil

    var body: some View {
        PaywallView(source: source, onPurchaseSuccess: onUnlocked)
    }
}

#Preview {
    PremiumPaywallView()
}
