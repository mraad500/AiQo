import SwiftUI

struct PremiumPaywallView: View {
    var onUnlocked: (() -> Void)? = nil

    var body: some View {
        PaywallView(onPurchaseSuccess: onUnlocked)
    }
}

#Preview {
    PremiumPaywallView()
}
